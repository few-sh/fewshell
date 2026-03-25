use anyhow::{Context, Result};
use jsonwebtoken::{encode, Algorithm, EncodingKey, Header};
use reqwest::Client;
use serde::Serialize;
use serde_json::json;
use std::sync::Mutex;
use std::time::{SystemTime, UNIX_EPOCH};
use tracing::{debug, info};

const PRODUCTION_URL: &str = "https://api.push.apple.com";
const SANDBOX_URL: &str = "https://api.sandbox.push.apple.com";
/// APNs tokens are valid for 60 minutes; refresh after 50 to avoid edge cases.
const TOKEN_REFRESH_SECS: u64 = 50 * 60;

#[derive(Serialize)]
struct Claims {
    iss: String,
    iat: u64,
}

struct CachedToken {
    token: String,
    issued_at: u64,
}

pub struct ApnsClient {
    http: Client,
    signing_key: EncodingKey,
    key_id: String,
    team_id: String,
    bundle_id: String,
    base_url: &'static str,
    cached_token: Mutex<Option<CachedToken>>,
}

impl ApnsClient {
    pub async fn new() -> Result<Self> {
        let key_path = std::env::var("APNS_KEY_PATH")
            .context("APNS_KEY_PATH environment variable not set")?;
        let key_id = std::env::var("APNS_KEY_ID")
            .context("APNS_KEY_ID environment variable not set")?;
        let team_id = std::env::var("APNS_TEAM_ID")
            .context("APNS_TEAM_ID environment variable not set")?;
        let bundle_id = std::env::var("APNS_BUNDLE_ID")
            .context("APNS_BUNDLE_ID environment variable not set")?;

        let use_sandbox = std::env::var("APNS_USE_SANDBOX")
            .unwrap_or_else(|_| "false".to_string())
            .parse::<bool>()
            .unwrap_or(false);

        info!("Initializing APNs client");
        debug!("Key ID: {}", key_id);
        debug!("Team ID: {}", team_id);
        debug!("Bundle ID: {}", bundle_id);
        debug!("Sandbox: {}", use_sandbox);

        let key_pem = std::fs::read(&key_path)
            .with_context(|| format!("Failed to read APNs key file: {}", key_path))?;
        let signing_key = EncodingKey::from_ec_pem(&key_pem)
            .context("Failed to parse APNs .p8 key")?;

        let base_url = if use_sandbox { SANDBOX_URL } else { PRODUCTION_URL };

        let http = Client::builder()
            .http2_prior_knowledge()
            .build()
            .context("Failed to build HTTP/2 client")?;

        Ok(Self {
            http,
            signing_key,
            key_id,
            team_id,
            bundle_id,
            base_url,
            cached_token: Mutex::new(None),
        })
    }

    fn bearer_token(&self) -> Result<String> {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        // Return cached token if still fresh
        {
            let cache = self.cached_token.lock().unwrap();
            if let Some(ref ct) = *cache {
                if now - ct.issued_at < TOKEN_REFRESH_SECS {
                    return Ok(ct.token.clone());
                }
            }
        }

        let header = Header {
            alg: Algorithm::ES256,
            kid: Some(self.key_id.clone()),
            ..Default::default()
        };
        let claims = Claims {
            iss: self.team_id.clone(),
            iat: now,
        };
        let token = encode(&header, &claims, &self.signing_key)
            .context("Failed to sign APNs JWT")?;

        let mut cache = self.cached_token.lock().unwrap();
        *cache = Some(CachedToken {
            token: token.clone(),
            issued_at: now,
        });

        Ok(token)
    }

    pub async fn send_notification(
        &self,
        device_token: &str,
        title: Option<&str>,
        body: &str,
        badge: Option<u32>,
        sound: Option<&str>,
        data: Option<serde_json::Value>,
    ) -> Result<()> {
        let mut alert = json!({ "body": body });
        if let Some(title) = title {
            alert["title"] = json!(title);
        }

        let mut payload = json!({
            "aps": {
                "alert": alert,
                "sound": sound.unwrap_or("default"),
            }
        });

        if let Some(badge) = badge {
            payload["aps"]["badge"] = json!(badge);
        }

        if let Some(data) = data {
            if let Some(obj) = data.as_object() {
                for (key, value) in obj {
                    payload[key] = value.clone();
                }
            }
        }

        debug!("APNs payload: {}", payload);

        let token = self.bearer_token()?;
        let url = format!("{}/3/device/{}", self.base_url, device_token);

        let response = self
            .http
            .post(&url)
            .bearer_auth(&token)
            .header("apns-topic", &self.bundle_id)
            .header("apns-priority", "10")
            .header("apns-push-type", "alert")
            .json(&payload)
            .send()
            .await
            .context("Failed to send APNs request")?;

        let status = response.status();
        if !status.is_success() {
            let body = response.text().await.unwrap_or_default();
            anyhow::bail!("APNs error ({}): {}", status, body);
        }

        Ok(())
    }
}
