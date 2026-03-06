use axum::{
    extract::{Query, State},
    http::{HeaderMap, StatusCode},
    response::{
        sse::{Event, KeepAlive, Sse},
        IntoResponse, Response,
    },
    Json,
};
use rand::Rng;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::convert::Infallible;
use std::sync::Arc;
use tokio::sync::{watch, RwLock};
use tokio_stream::wrappers::ReceiverStream;
use tracing::info;

/// How often the pubkey ID rotates (in seconds).
const PUBKEY_ROTATION_SECS: u64 = 30;

/// An entry in the pubkey store, linking an ID to a public key and
/// a channel used to deliver the consumer's IP address when the key
/// is retrieved via GET.
pub struct PubkeyEntry {
    public_key: String,
    /// Sender half — GET writes `Some(ip)` to signal consumption.
    consumed_tx: Arc<watch::Sender<Option<String>>>,
}

pub type PubkeyStore = Arc<RwLock<HashMap<String, PubkeyEntry>>>;

#[derive(Debug, Deserialize)]
pub struct PostPubkeyRequest {
    public_key: String,
}

#[derive(Debug, Deserialize)]
pub struct GetPubkeyParams {
    id: String,
    username: Option<String>,
}

#[derive(Debug, Serialize)]
struct GetPubkeyResponse {
    public_key: String,
}

#[derive(Debug, Serialize)]
struct ErrorResponse {
    error: String,
}

/// Validates that the input is a well-formed SSH ed25519 public key.
///
/// Expected format: `ssh-ed25519 <68-char-base64> [optional comment]`
fn is_valid_ed25519_pubkey(key: &str) -> bool {
    // Reject control characters (newlines, tabs, etc.) which would break
    // authorized_keys format or could be used for injection.
    if key.chars().any(|c| c.is_control()) {
        return false;
    }
    let parts: Vec<&str> = key.splitn(3, ' ').collect();
    if parts.len() < 2 {
        return false;
    }
    if parts[0] != "ssh-ed25519" {
        return false;
    }
    let b64 = parts[1];
    if b64.len() != 68 {
        return false;
    }
    b64.chars()
        .all(|c| c.is_ascii_alphanumeric() || c == '+' || c == '/')
}

/// Generate a unique 6-digit ID that doesn't collide with existing entries.
fn generate_id(map: &HashMap<String, PubkeyEntry>) -> String {
    let mut rng = rand::thread_rng();
    loop {
        let candidate = rng.gen_range(100_000u32..1_000_000);
        let candidate_str = candidate.to_string();
        if !map.contains_key(&candidate_str) {
            return candidate_str;
        }
    }
}

/// POST /pubkey — stores the public key and returns an SSE stream.
///
/// The stream immediately emits the initial ID, then every
/// [`PUBKEY_ROTATION_SECS`] seconds generates a new ID (removing
/// the old one from the store) and emits it. When a GET consumer
/// retrieves the key, the consumer's IP is sent as a final
/// `connected` event before the stream closes.
pub async fn post_pubkey(
    State(store): State<PubkeyStore>,
    Json(payload): Json<PostPubkeyRequest>,
) -> Response {
    if !is_valid_ed25519_pubkey(&payload.public_key) {
        return (
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: "Invalid ed25519 public key format".to_string(),
            }),
        )
            .into_response();
    }

    let (consumed_tx, mut consumed_rx) = watch::channel::<Option<String>>(None);
    let consumed_tx = Arc::new(consumed_tx);
    let public_key = payload.public_key;

    let initial_id = {
        let mut map = store.write().await;
        let id = generate_id(&map);
        map.insert(
            id.clone(),
            PubkeyEntry {
                public_key: public_key.clone(),
                consumed_tx: consumed_tx.clone(),
            },
        );
        id
    };

    info!(
        "Stored pubkey with id {} (rotating every {}s)",
        initial_id, PUBKEY_ROTATION_SECS
    );

    let (tx, rx) = tokio::sync::mpsc::channel::<Result<Event, Infallible>>(2);

    // Spawn a background task that rotates the ID and feeds the SSE stream.
    tokio::spawn(async move {
        // Send initial ID
        if tx
            .send(Ok(Event::default().data(initial_id.as_str())))
            .await
            .is_err()
        {
            store.write().await.remove(&initial_id);
            return;
        }

        let mut current_id = initial_id;

        let consumed_by_get = loop {
            tokio::select! {
                result = consumed_rx.changed() => {
                    if result.is_ok() {
                        let ip = {
                            consumed_rx.borrow_and_update().clone()
                        };
                        if let Some(ip) = ip {
                            info!("Pubkey id {} consumed by {}, sending final event", current_id, ip);
                            let _ = tx.send(Ok(
                                Event::default().event("connected").data(ip)
                            )).await;
                        }
                    }
                    break true;
                }
                _ = tx.closed() => {
                    // POST client disconnected — clean up immediately.
                    info!("POST client disconnected, removing pubkey id {}", current_id);
                    break false;
                }
                _ = tokio::time::sleep(std::time::Duration::from_secs(PUBKEY_ROTATION_SECS)) => {
                    // Rotate: remove old ID, generate new one.
                    let new_id = {
                        let mut map = store.write().await;
                        map.remove(&current_id);
                        let new_id = generate_id(&map);
                        map.insert(
                            new_id.clone(),
                            PubkeyEntry {
                                public_key: public_key.clone(),
                                consumed_tx: consumed_tx.clone(),
                            },
                        );
                        new_id
                    };
                    info!("Rotated pubkey id {} -> {}", current_id, new_id);
                    current_id = new_id;
                    if tx
                        .send(Ok(Event::default().data(current_id.as_str())))
                        .await
                        .is_err()
                    {
                        // Client disconnected — clean up.
                        break false;
                    }
                }
            }
        };

        if !consumed_by_get {
            store.write().await.remove(&current_id);
        }
    });

    let stream = ReceiverStream::new(rx);
    Sse::new(stream)
        .keep_alive(KeepAlive::default())
        .into_response()
}

/// Validates that a username contains only characters valid across
/// Unix, macOS and Windows: letters, digits, dot, underscore, hyphen.
fn is_valid_username(name: &str) -> bool {
    !name.is_empty()
        && name.len() <= 64
        && name
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || c == '.' || c == '_' || c == '-')
}

/// GET /pubkey?id=…&username=… — consumes the key and notifies the SSE stream
/// with the client's identity. The optional `username` parameter, if valid,
/// is included as `username@<ip>` in the connected event.
pub async fn get_pubkey(
    State(store): State<PubkeyStore>,
    Query(params): Query<GetPubkeyParams>,
    headers: HeaderMap,
) -> Response {
    // Validate username if provided.
    if let Some(ref username) = params.username {
        if !is_valid_username(username) {
            return (
                StatusCode::BAD_REQUEST,
                Json(ErrorResponse {
                    error: "Invalid username: only letters, digits, dot, underscore and hyphen are allowed (max 64 chars)".to_string(),
                }),
            )
                .into_response();
        }
    }

    let client_ip = headers
        .get("x-forwarded-for")
        .and_then(|v| v.to_str().ok())
        .and_then(|s| s.split(',').next())
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|| "unknown".to_string());

    // Format: "username@ip" when username is present, otherwise just "ip".
    let identity = match &params.username {
        Some(username) => format!("{}@{}", username, client_ip),
        None => client_ip,
    };

    let mut map = store.write().await;
    match map.remove(&params.id) {
        Some(entry) => {
            // Signal the SSE stream with the consumer's identity.
            let _ = entry.consumed_tx.send(Some(identity));
            Json(GetPubkeyResponse {
                public_key: entry.public_key,
            })
            .into_response()
        }
        None => (
            StatusCode::NOT_FOUND,
            Json(ErrorResponse {
                error: "Key not found or expired".to_string(),
            }),
        )
            .into_response(),
    }
}
