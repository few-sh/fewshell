use axum::{
    body::Body,
    extract::State,
    http::{header, Request, StatusCode},
    middleware::{self, Next},
    response::{IntoResponse, Response},
    routing::post,
    Json, Router,
};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tower_http::trace::TraceLayer;
use tracing::{error, info, warn};

mod apns;
use apns::ApnsClient;

mod pubkey;
use pubkey::PubkeyStore;

#[derive(Clone)]
struct AppState {
    apns_client: Arc<ApnsClient>,
    api_key: Arc<String>,
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

    let pubkey_store: PubkeyStore = Arc::new(RwLock::new(HashMap::new()));

    let state = AppState { apns_client, api_key };

    // Pubkey routes get their own state (just the store) so they
    // don't depend on the full AppState.
    let pubkey_router = Router::new()
        .route(
            "/pubkey",
            axum::routing::get(pubkey::get_pubkey).post(pubkey::post_pubkey),
        )
        .with_state(pubkey_store);

    // Build the router
    let app = Router::new()
        .route("/health", axum::routing::get(health_check))
        .merge(pubkey_router)
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
