use a2::{Client, ClientConfig, Endpoint, DefaultNotificationBuilder, NotificationBuilder, NotificationOptions, Priority};
use anyhow::{Context, Result};
use serde_json::json;
use std::fs::File;
use tracing::{debug, info};

pub struct ApnsClient {
    client: Client,
    bundle_id: String,
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

        let mut key_file = File::open(&key_path)
            .with_context(|| format!("Failed to open APNs key file: {}", key_path))?;

        let endpoint = if use_sandbox {
            Endpoint::Sandbox
        } else {
            Endpoint::Production
        };

        let config = ClientConfig::new(endpoint);
        let client = Client::token(&mut key_file, &key_id, &team_id, config)
            .context("Failed to create APNs client")?;

        Ok(Self { client, bundle_id })
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
        let mut alert = json!({
            "body": body,
        });

        if let Some(title) = title {
            alert["title"] = json!(title);
        }

        let mut payload = json!({
            "aps": {
                "alert": alert,
            }
        });

        if let Some(badge) = badge {
            payload["aps"]["badge"] = json!(badge);
        }

        if let Some(sound) = sound {
            payload["aps"]["sound"] = json!(sound);
        } else {
            payload["aps"]["sound"] = json!("default");
        }

        // Add custom data if provided
        if let Some(data) = data {
            if let Some(obj) = data.as_object() {
                for (key, value) in obj {
                    payload[key] = value.clone();
                }
            }
        }

        let payload_str =
            serde_json::to_string(&payload).context("Failed to serialize notification payload")?;

        let options = NotificationOptions {
            apns_topic: Some(&self.bundle_id),
            apns_priority: Some(Priority::High),
            ..Default::default()
        };

        let builder = DefaultNotificationBuilder::new()
            .set_body(&payload_str)
            .set_sound("default");

        let notification = builder.build(device_token, options);

        let response = self
            .client
            .send(notification)
            .await
            .context("Failed to send notification")?;

        if response.error.is_some() {
            anyhow::bail!(
                "APNs error: {:?} - {:?}",
                response.error,
                response.code
            );
        }

        Ok(())
    }
}
