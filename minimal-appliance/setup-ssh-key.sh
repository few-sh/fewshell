#!/bin/bash

# Setup script for provisioning SSH keys for the SSH gateway
# This script sets up key-based authentication in the local default-key directory

set -e

echo "=== SSH Gateway Key Provisioning ==="
echo ""

DEFAULT_KEY_DIR="./default-key"
SSH_KEY_PATH="$DEFAULT_KEY_DIR/id_rsa"
AUTHORIZED_KEYS_FILE="$DEFAULT_KEY_DIR/authorized_keys"

# Create default-key directory if it doesn't exist
mkdir -p "$DEFAULT_KEY_DIR"

# Check if key already exists
if [ -f "$SSH_KEY_PATH" ]; then
    echo "⚠️  SSH key pair already exists in $DEFAULT_KEY_DIR"
    read -p "Do you want to regenerate it? (y/N): " regenerate
    if [[ ! "$regenerate" =~ ^[Yy]$ ]]; then
        echo "Using existing key pair."
        if [ ! -f "$AUTHORIZED_KEYS_FILE" ]; then
            echo "Generating authorized_keys from existing public key..."
            cp "$SSH_KEY_PATH.pub" "$AUTHORIZED_KEYS_FILE"
        fi
        echo ""
        echo "✓ Setup complete!"
        echo ""
        echo "Next steps:"
        echo "1. Build and start the SSH gateway:"
        echo "   docker-compose up -d --build"
        echo ""
        echo "2. Connect using the provisioned key:"
        echo "   ssh -i $SSH_KEY_PATH -p 8222 ubuntu@localhost"
        echo ""
        exit 0
    fi
    rm -f "$SSH_KEY_PATH" "$SSH_KEY_PATH.pub"
fi

echo "Generating new SSH key pair in $DEFAULT_KEY_DIR..."
ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "minimal-appliance-gateway"

echo "Creating authorized_keys file..."
cp "$SSH_KEY_PATH.pub" "$AUTHORIZED_KEYS_FILE"

echo ""
echo "✓ SSH key pair generated successfully!"
echo ""
echo "  Private key: $SSH_KEY_PATH"
echo "  Public key:  $SSH_KEY_PATH.pub"
echo ""
echo "Next steps:"
echo "1. Build and start the SSH gateway:"
echo "   docker-compose up -d --build"
echo ""
echo "2. Connect using the provisioned key:"
echo "   ssh -i $SSH_KEY_PATH -p 8222 ubuntu@localhost"
echo ""
echo "Note: This gateway uses key-based authentication only."
echo "      Password authentication is disabled for security."
