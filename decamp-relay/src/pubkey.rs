use axum::{
    extract::{Query, State},
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use rand::Rng;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::info;

/// How long a pubkey entry lives before automatic removal (in seconds).
const PUBKEY_TTL_SECS: u64 = 30;

pub type PubkeyStore = Arc<RwLock<HashMap<String, String>>>;

#[derive(Debug, Deserialize)]
pub struct PostPubkeyRequest {
    public_key: String,
}

#[derive(Debug, Serialize)]
struct PostPubkeyResponse {
    id: String,
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

    let id = {
        let mut map = store.write().await;
        let mut rng = rand::thread_rng();
        let id = loop {
            let candidate = rng.gen_range(100_000u32..1_000_000);
            let candidate_str = candidate.to_string();
            if !map.contains_key(&candidate_str) {
                break candidate_str;
            }
        };
        map.insert(id.clone(), payload.public_key);
        id
    };

    // Schedule automatic removal after TTL
    let store_clone = store.clone();
    let id_clone = id.clone();
    tokio::spawn(async move {
        tokio::time::sleep(std::time::Duration::from_secs(PUBKEY_TTL_SECS)).await;
        store_clone.write().await.remove(&id_clone);
    });

    info!("Stored pubkey with id {} (expires in {}s)", id, PUBKEY_TTL_SECS);
    Json(PostPubkeyResponse { id }).into_response()
}

pub async fn get_pubkey(
    State(store): State<PubkeyStore>,
    Query(params): Query<GetPubkeyParams>,
) -> Response {
    let map = store.read().await;
    match map.get(&params.id) {
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
