use axum::{
    body::Body,
    extract::{Query, State},
    http::{header, Request, StatusCode},
    middleware::{self, Next},
    response::{IntoResponse, Response},
    routing::post,
    Json, Router,
};
use rand::Rng;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tower_http::trace::TraceLayer;
use tracing::{error, info, warn};

mod apns;
use apns::ApnsClient;

/// How long a pubkey entry lives before automatic removal (in seconds).
const PUBKEY_TTL_SECS: u64 = 30;

#[derive(Clone)]
struct AppState {
    apns_client: Arc<ApnsClient>,
    api_key: Arc<String>,
    pubkey_store: Arc<RwLock<HashMap<String, String>>>,
}

#[derive(Debug, Deserialize)]
struct NotificationRequest {
    device_tokens: Vec<String>,
    #[serde(default)]
    title: Option<String>,
    body: String,
    #[serde(default)]
    badge: Option<u32>,
    #[serde(default)]
    sound: Option<String>,
    #[serde(default)]
    data: Option<serde_json::Value>,
}

#[derive(Debug, Serialize)]
struct NotificationResponse {
    success: Vec<String>,
    failed: Vec<FailedNotification>,
}

#[derive(Debug, Serialize)]
struct FailedNotification {
    device_token: String,
    error: String,
}

#[derive(Debug, Deserialize)]
struct PostPubkeyRequest {
    public_key: String,
}

#[derive(Debug, Serialize)]
struct PostPubkeyResponse {
    id: String,
}

#[derive(Debug, Deserialize)]
struct GetPubkeyParams {
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

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Load .env file if present
    let _ = dotenvy::dotenv();

    // Initialize tracing
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "decamp_relay=debug,tower_http=debug".into()),
        )
        .init();

    // Initialize APNs client
    let apns_client = Arc::new(ApnsClient::new().await?);

    // Load API key
    let api_key = Arc::new(
        std::env::var("API_KEY").expect("API_KEY environment variable must be set"),
    );

    let pubkey_store = Arc::new(RwLock::new(HashMap::new()));

    let state = AppState { apns_client, api_key, pubkey_store };

    // Build the router
    let app = Router::new()
        .route("/health", axum::routing::get(health_check))
        .route(
            "/pubkey",
            axum::routing::get(get_pubkey).post(post_pubkey),
        )
        .route("/send", post(send_notification))
        .route_layer(middleware::from_fn_with_state(state.clone(), api_key_auth))
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    let port = std::env::var("PORT").unwrap_or_else(|_| "8080".to_string());
    let addr = format!("0.0.0.0:{}", port);
    let listener = tokio::net::TcpListener::bind(&addr).await?;

    info!("Server listening on {}", addr);

    axum::serve(listener, app).await?;

    Ok(())
}

async fn health_check() -> &'static str {
    "OK"
}

async fn api_key_auth(
    State(state): State<AppState>,
    req: Request<Body>,
    next: Next,
) -> Result<Response, StatusCode> {
    // Skip auth for health check and pubkey exchange
    let path = req.uri().path();
    if path == "/health" || path == "/pubkey" {
        return Ok(next.run(req).await);
    }

    let auth_header = req
        .headers()
        .get(header::AUTHORIZATION)
        .and_then(|h| h.to_str().ok());

    match auth_header {
        Some(auth) if auth.strip_prefix("Bearer ").map_or(false, |token| token == state.api_key.as_str()) => {
            Ok(next.run(req).await)
        }
        Some(_) => {
            warn!("Invalid API key provided");
            Err(StatusCode::UNAUTHORIZED)
        }
        None => {
            warn!("Missing Authorization header");
            Err(StatusCode::UNAUTHORIZED)
        }
    }
}

async fn send_notification(
    State(state): State<AppState>,
    Json(payload): Json<NotificationRequest>,
) -> Result<Json<NotificationResponse>, AppError> {
    info!(
        "Sending notification to {} devices",
        payload.device_tokens.len()
    );

    let mut success = Vec::new();
    let mut failed = Vec::new();

    for token in payload.device_tokens {
        match state
            .apns_client
            .send_notification(
                &token,
                payload.title.as_deref(),
                &payload.body,
                payload.badge,
                payload.sound.as_deref(),
                payload.data.clone(),
            )
            .await
        {
            Ok(_) => {
                info!("Successfully sent notification to {}", token);
                success.push(token);
            }
            Err(e) => {
                error!("Failed to send notification to {}: {}", token, e);
                failed.push(FailedNotification {
                    device_token: token,
                    error: e.to_string(),
                });
            }
        }
    }

    Ok(Json(NotificationResponse { success, failed }))
}

// ----- Pubkey handlers -----

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

async fn post_pubkey(
    State(state): State<AppState>,
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

    let id = {
        let mut store = state.pubkey_store.write().await;
        let mut rng = rand::thread_rng();
        let id = loop {
            let candidate = rng.gen_range(100_000u32..1_000_000);
            let candidate_str = candidate.to_string();
            if !store.contains_key(&candidate_str) {
                break candidate_str;
            }
        };
        store.insert(id.clone(), payload.public_key);
        id
    };

    // Schedule automatic removal after TTL
    let store = state.pubkey_store.clone();
    let id_clone = id.clone();
    tokio::spawn(async move {
        tokio::time::sleep(std::time::Duration::from_secs(PUBKEY_TTL_SECS)).await;
        store.write().await.remove(&id_clone);
    });

    info!("Stored pubkey with id {} (expires in {}s)", id, PUBKEY_TTL_SECS);
    Json(PostPubkeyResponse { id }).into_response()
}

async fn get_pubkey(
    State(state): State<AppState>,
    Query(params): Query<GetPubkeyParams>,
) -> Response {
    let store = state.pubkey_store.read().await;
    match store.get(&params.id) {
        Some(key) => Json(GetPubkeyResponse {
            public_key: key.clone(),
        })
        .into_response(),
        None => (
            StatusCode::NOT_FOUND,
            Json(ErrorResponse {
                error: "Key not found or expired".to_string(),
            }),
        )
            .into_response(),
    }
}

// ----- Error handling -----
struct AppError(anyhow::Error);

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        error!("Application error: {:?}", self.0);
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("Internal server error: {}", self.0),
        )
            .into_response()
    }
}

impl<E> From<E> for AppError
where
    E: Into<anyhow::Error>,
{
    fn from(err: E) -> Self {
        Self(err.into())
    }
}
