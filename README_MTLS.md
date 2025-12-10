# Mutual TLS (mTLS) Implementation in Decamp

This document describes the Mutual TLS (mTLS) implementation between the `decamp-app` (Client) and `decamp-agent` (Server).

## Overview

The system uses mTLS to ensure:
1.  **Server Authentication:** The client verifies the server's identity using a custom Certificate Authority (CA) and strict certificate pinning.
2.  **Client Authentication:** The server verifies the client's identity, ensuring only authorized clients can connect.
3.  **Encryption:** All traffic is encrypted using TLS 1.3.

## Architecture

Instead of relying on filesystem access at runtime (which is complex on mobile devices), certificates are **embedded directly into the source code** during the build process.

### Components

1.  **Certificate Generation Script (`scripts/generate_certs.sh`)**:
    *   Generates a self-signed Root CA.
    *   Generates Server certificates (with `serverAuth` extension and `localhost` SANs).
    *   Generates Client certificates (with `clientAuth` extension).
    *   **Crucially**, it reads these generated files and writes them as `const String` variables into:
        *   `decamp-agent/lib/certs.dart`
        *   `decamp-app/lib/certs.dart`

2.  **Server (`decamp-agent`)**:
    *   Binds to `InternetAddress.anyIPv6` (dual-stack IPv4/IPv6) to support `localhost` reliably.
    *   Initializes a `SecurityContext` with `withTrustedRoots: false`.
    *   Uses the embedded `serverCert` (full chain), `serverKey`, and `caCert`.
    *   Enforces `requestClientCertificate: true`.

3.  **Client (`decamp-app`)**:
    *   Initializes a `SecurityContext` with the embedded `clientCert`, `clientKey`, and `caCert`.
    *   Connects via `wss://` (Secure WebSocket).
    *   **Certificate Pinning:** Implements a strict `badCertificateCallback`. It ignores the system's trust store and compares the received server certificate byte-for-byte against the embedded `serverCert`.

## Setup & Usage

### 1. Generate Certificates

You **must** run this script whenever you want to rotate certificates or set up a new environment. It updates the Dart source files directly.

```bash
cd scripts
./generate_certs.sh
```

*Output:*
*   Creates `scripts/certs/` directory with raw PEM files (for debugging).
*   Updates `decamp-agent/lib/certs.dart`.
*   Updates `decamp-app/lib/certs.dart`.

### 2. Run the Server

The server will automatically use the embedded certificates.

```bash
cd decamp-agent
dart run bin/server.dart
```

You should see logs indicating mTLS initialization:
```
[INFO] Initializing mTLS with embedded certificates
[INFO] SecurityContext initialized successfully...
[INFO] 🚀 Decamp Agent server running on https://:::3123
```

### 3. Run the Client

The client will automatically use the embedded certificates to authenticate.

```bash
cd decamp-app
flutter run -d macos
```

*Note: Since certificates are compiled in, you must perform a full restart (not hot reload) if you regenerate certificates.*

## Troubleshooting

### "Connection closed before full header was received"
*   **Cause:** Usually means the handshake failed.
*   **Check:** Ensure the client certificate has the `clientAuth` extension and the server certificate has `serverAuth`. The `generate_certs.sh` script handles this.
*   **Check:** Ensure the full certificate chain is being sent. The script appends the CA cert to the client/server certs in the Dart files.

### "Certificate verification failed"
*   **Cause:** The client's pinning logic rejected the server's certificate.
*   **Fix:** Ensure you ran `./generate_certs.sh` and then **restarted both** the server and the client app. If they are out of sync (e.g., server has new certs, client has old code), pinning will fail.

### "Connection refused"
*   **Cause:** The server isn't running or isn't reachable on `localhost`.
*   **Fix:** The server binds to `anyIPv6` with `v6Only: false` to cover both `127.0.0.1` and `::1`. Ensure no other process is using port 3123.

## Manual Verification

You can use `openssl` to simulate a client connection:

```bash
# From the root directory
openssl s_client \
  -connect localhost:3123 \
  -cert scripts/certs/client.crt \
  -key scripts/certs/client.key \
  -CAfile scripts/certs/ca.crt \
  -state -debug
```
