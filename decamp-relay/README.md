# Decamp Relay

A simple Rust web service for sending Apple Push Notifications (APNs) using token-based authentication.

## Features

- Token-based APNs authentication (p8 key)
- Send notifications to multiple device tokens
- REST API for easy integration
- Configurable via environment variables
- Support for both sandbox and production environments

## Setup

1. **Get your APNs credentials** from Apple Developer Portal:
   - Download your `.p8` key file
   - Note your Key ID (10 characters)
   - Note your Team ID (10 characters)
   - Know your app's Bundle ID

2. **Configure environment variables**:
   ```bash
   cp .env.example .env
   # Edit .env with your credentials
   ```

3. **Build and run**:
   ```bash
   cargo build --release
   cargo run --release
   ```

## API Usage

### Health Check

```bash
curl http://localhost:8080/health
```

### Send Notification

```bash
curl -X POST http://localhost:8080/send \
  -H "Content-Type: application/json" \
  -d '{
    "device_tokens": ["your-device-token-here"],
    "title": "Hello",
    "body": "This is a test notification",
    "badge": 1,
    "sound": "default",
    "data": {
      "custom_key": "custom_value"
    }
  }'
```

**Request Body:**
- `device_tokens` (required): Array of device tokens to send to
- `body` (required): The notification message body
- `title` (optional): The notification title
- `badge` (optional): Badge number to display on app icon
- `sound` (optional): Sound to play (defaults to "default")
- `data` (optional): Custom data payload (JSON object)

**Response:**
```json
{
  "success": ["token1", "token2"],
  "failed": [
    {
      "device_token": "token3",
      "error": "BadDeviceToken"
    }
  ]
}
```

## Configuration

All configuration is done via environment variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `APNS_KEY_PATH` | Path to your .p8 key file | `/path/to/AuthKey_ABC123XYZ.p8` |
| `APNS_KEY_ID` | Your APNs Key ID | `ABC123XYZ` |
| `APNS_TEAM_ID` | Your Apple Team ID | `DEF456UVW` |
| `APNS_BUNDLE_ID` | Your app's Bundle ID | `com.fewsh.decamp` |
| `APNS_USE_SANDBOX` | Use sandbox environment | `true` or `false` |
| `PORT` | Server port | `8080` |
| `RUST_LOG` | Logging level | `decamp_relay=debug` |

## Development

```bash
# Run in development mode
cargo run

# Run tests
cargo test

# Build release binary
cargo build --release
```

## Production Deployment

1. Set `APNS_USE_SANDBOX=false` in your environment
2. Build the release binary: `cargo build --release`
3. Run the binary: `./target/release/decamp-relay`

## Integration with Decamp Server

The Decamp server (decamp-agent) can call this relay service to send push notifications to mobile clients when important events occur.
