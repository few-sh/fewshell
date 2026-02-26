#!/bin/sh
set -e

RELAY_URL="https://relay.fewshell.com"
SSH_DIR="$HOME/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

# --- Prompt for pairing code and fetch key (retry loop) ---
PUBKEY=""
while [ -z "$PUBKEY" ]; do
  printf "Enter 6-digit pairing code: "
  read -r CODE

  # Validate format
  case "$CODE" in
    [0-9][0-9][0-9][0-9][0-9][0-9]) ;;
    *) echo "Error: pairing code must be exactly 6 digits." >&2; continue ;;
  esac

  # Fetch the public key
  RESPONSE=$(curl -sf "${RELAY_URL}/pubkey?id=${CODE}") || {
    echo "Error: failed to retrieve key (invalid code, expired, or network error)." >&2
    continue
  }

  # Extract public_key value (works with or without jq)
  if command -v jq >/dev/null 2>&1; then
    PUBKEY=$(echo "$RESPONSE" | jq -r '.public_key // empty')
  else
    # Minimal JSON extraction fallback
    PUBKEY=$(echo "$RESPONSE" | sed -n 's/.*"public_key" *: *"\([^"]*\)".*/\1/p')
  fi

  if [ -z "$PUBKEY" ]; then
    echo "Error: response did not contain a public key." >&2
    continue
  fi

  # Basic sanity check
  case "$PUBKEY" in
    ssh-ed25519\ *) ;;
    *) echo "Error: received key is not a valid ssh-ed25519 key." >&2; PUBKEY=""; continue ;;
  esac
done

# --- Set up ~/.ssh and authorized_keys ---
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
touch "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"

# --- Add the key idempotently ---
if grep -qF "$PUBKEY" "$AUTH_KEYS" 2>/dev/null; then
  echo "Key already present in authorized_keys – nothing to do."
else
  echo "$PUBKEY" >> "$AUTH_KEYS"
  echo "Key added to authorized_keys."
fi
