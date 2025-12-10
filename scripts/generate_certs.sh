#!/bin/bash
set -e

# Create a directory for certificates
mkdir -p certs
cd certs

# 1. Generate CA private key and self-signed certificate
echo "Generating CA..."
openssl genrsa -out ca.key 2048
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt -subj "/CN=Decamp CA"

# 2. Generate Server private key and certificate signing request (CSR)
echo "Generating Server Certs..."
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

# 3. Sign the Server CSR with the CA
echo "Signing Server Cert..."
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -sha256 \
  -extfile <(printf "subjectAltName=DNS:localhost,IP:127.0.0.1")

# 4. Generate Client private key and CSR
echo "Generating Client Certs..."
openssl genrsa -out client.key 2048
openssl req -new -key client.key -out client.csr -subj "/CN=Decamp Client"

# 5. Sign the Client CSR with the CA
echo "Signing Client Cert..."
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 365 -sha256

# 6. Convert Client key and cert to PKCS#12 format (often easier for clients to consume)
echo "Creating Client PKCS#12..."
openssl pkcs12 -export -out client.p12 -inkey client.key -in client.crt -certfile ca.crt -passout pass:decamp

# Clean up intermediate files
rm server.csr client.csr ca.srl

# 7. Update Dart files with embedded certificates

AGENT_CERTS_FILE="../../decamp-agent/lib/certs.dart"
APP_CERTS_FILE="../../decamp-app/lib/certs.dart"

echo "Updating $AGENT_CERTS_FILE..."
cat > "$AGENT_CERTS_FILE" <<EOF
/// Certificate Authority Certificate
const String caCert = r'''
$(cat ca.crt)
''';

/// Server Certificate
const String serverCert = r'''
$(cat server.crt)
''';

/// Server Private Key
const String serverKey = r'''
$(cat server.key)
''';
EOF

echo "Updating $APP_CERTS_FILE..."
cat > "$APP_CERTS_FILE" <<EOF
/// Certificate Authority Certificate
const String caCert = r'''
$(cat ca.crt)
''';

/// Client Certificate
const String clientCert = r'''
$(cat client.crt)
''';

/// Client Private Key
const String clientKey = r'''
$(cat client.key)
''';
EOF

echo "Done! Certificates are in the 'certs' directory and Dart files have been updated."
