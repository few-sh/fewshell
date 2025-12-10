# Mutual TLS (mTLS) Setup for Decamp

This document describes how to enable and use Mutual TLS (mTLS) between `decamp-app` and `decamp-agent`.

## Prerequisites

- OpenSSL installed.
- Dart SDK installed.

## 1. Generate Certificates

Run the provided script to generate the CA, server, and client certificates:

```bash
./scripts/generate_certs.sh
```

This will create a `certs` directory containing:
- `ca.crt`, `ca.key`: CA certificate and private key.
- `server.crt`, `server.key`: Server certificate and private key.
- `client.crt`, `client.key`: Client certificate and private key.
- `client.p12`: Client certificate in PKCS#12 format.

## 2. Run the Agent (Server) with mTLS

Set the `ENABLE_MTLS` environment variable to `true` and optionally `CERTS_PATH` (defaults to `certs`).

```bash
export ENABLE_MTLS=true
export CERTS_PATH=./certs
dart decamp-agent/bin/server.dart
```

The server will start on `https://localhost:3123` (or configured port).

## 3. Run the App (Client) with mTLS

The app is configured to look for certificates in the `certs` directory (relative to the execution path) or the path specified by `CERTS_PATH` environment variable, if `ENABLE_MTLS` is set to `true`.

**Note:** For a production mobile app, you would need to bundle the certificates as assets or provide a UI to import them. The current implementation is designed for development/testing environments where the file system is accessible.

```bash
export ENABLE_MTLS=true
export CERTS_PATH=./certs
flutter run -d macos # or linux/windows
```

## Implementation Details

### Server (`decamp-agent`)

- Modified `decamp-agent/bin/server.dart` to load `SecurityContext` from the certificates if `ENABLE_MTLS` is set.
- Uses `shelf_io.serve` with the `securityContext` to enable HTTPS/WSS.
- Requires client authentication (`setClientAuthorities`).

### Client (`decamp-app`)

- Modified `decamp-app/lib/services/sync_service.dart` to use `IOWebSocketChannel.connect` with a custom `HttpClient`.
- The `HttpClient` is configured with a `SecurityContext` loaded from the client certificates and CA.
- Trusts the CA and presents the client certificate during the handshake.
