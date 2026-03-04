use axum::{
    extract::{Query, State},
    http::StatusCode,
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
use tokio::sync::{Notify, RwLock};
use tokio_stream::wrappers::ReceiverStream;
use tracing::info;

/// How often the pubkey ID rotates (in seconds).
const PUBKEY_ROTATION_SECS: u64 = 30;

/// An entry in the pubkey store, linking an ID to a public key and
/// a notification handle used to signal when the key is consumed.
pub struct PubkeyEntry {
    public_key: String,
    consumed: Arc<Notify>,
}

pub type PubkeyStore = Arc<RwLock<HashMap<String, PubkeyEntry>>>;

#[derive(Debug, Deserialize)]
pub struct PostPubkeyRequest {
    public_key: String,
}

#[derive(Debug, Deserialize)]
pub struct GetPubkeyParams {
    id: String,
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
    let parts: Vec<&str> = key.split_whitespace().collect();
    if parts.len() < 2 || parts.len() > 3 {
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
/// retrieves the key, the stream closes.
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

    let consumed = Arc::new(Notify::new());
    let public_key = payload.public_key;

    let initial_id = {
        let mut map = store.write().await;
        let id = generate_id(&map);
        map.insert(
            id.clone(),
            PubkeyEntry {
                public_key: public_key.clone(),
                consumed: consumed.clone(),
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

        let notified = consumed.notified();
        tokio::pin!(notified);

        let mut current_id = initial_id;

        let consumed_by_get = loop {
            tokio::select! {
                _ = &mut notified => {
                    // Key was consumed via GET — stop streaming.
                    info!("Pubkey id {} was consumed, closing SSE stream", current_id);
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
                                consumed: consumed.clone(),
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

/// GET /pubkey?id=… — consumes the key, notifies the SSE stream to close.
pub async fn get_pubkey(
    State(store): State<PubkeyStore>,
    Query(params): Query<GetPubkeyParams>,
) -> Response {
    let mut map = store.write().await;
    match map.remove(&params.id) {
        Some(entry) => {
            entry.consumed.notify_one();
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
