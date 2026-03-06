#!/bin/bash

# get.fewshell.com – fewshell agent installer
# Install: curl -LsSf https://get.fewshell.com | bash
#
# Idempotent: safe to run multiple times.

set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

INSTALL_DIR="$HOME/.fewshell"
LIB_DIR="$HOME/lib"
BASE_URL="https://release.few.sh/releases/latest"
RELAY_URL="https://relay.fewshell.com"
SSH_DIR="$HOME/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"
TMP_DIR=""

info()  { echo -e "${GREEN}▸${RESET} $*"; }
warn()  { echo -e "${RED}▸${RESET} $*"; }
step()  { echo -e "${CYAN}${BOLD}→${RESET} $*"; }

detect_arch() {
    local machine
    machine="$(uname -m)"
    case "$machine" in
        x86_64|amd64)   echo "amd64" ;;
        aarch64|arm64)  echo "arm64" ;;
        *)
            warn "Unsupported architecture: $machine"
            exit 1
            ;;
    esac
}

detect_os() {
    local os
    os="$(uname -s)"
    case "$os" in
        Linux)   echo "linux" ;;
        Darwin)  echo "macos" ;;
        *)
            warn "Unsupported OS: $os"
            exit 1
            ;;
    esac
}

main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════╗"
    echo -e "║      ${BOLD}fewshell agent installer${RESET}${CYAN}       ║"
    echo -e "╚══════════════════════════════════════╝${RESET}"
    echo ""

    local os arch
    os="$(detect_os)"
    arch="$(detect_arch)"

    local tgz_name="fewshell-agent-${os}-${arch}.tar.gz"
    local url="${BASE_URL}/${tgz_name}"

    info "OS: ${os}  Architecture: ${arch}"

    # --- Check for required tools ---
    for cmd in curl tar; do
        if ! command -v "$cmd" &>/dev/null; then
            warn "Required command not found: $cmd"
            exit 1
        fi
    done

    # --- Download ---
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT

    step "Downloading ${tgz_name}\u2026"
    if ! curl -fSL --progress-bar -o "${TMP_DIR}/${tgz_name}" "$url"; then
        warn "Download failed. Check your network connection."
        exit 1
    fi

    # --- Install ---
    step "Installing to ${INSTALL_DIR}…"
    mkdir -p "$INSTALL_DIR"
    tar xzf "${TMP_DIR}/${tgz_name}" -C "$INSTALL_DIR"

    chmod +x "${INSTALL_DIR}/fewshell-server"
    chmod 700 "${INSTALL_DIR}/fewshell-server"

    # --- Copy shared library ---
    step "Copying libpty_bridge.so to ${LIB_DIR}…"
    mkdir -p "$LIB_DIR"
    cp -f "${INSTALL_DIR}/libpty_bridge.so" "${LIB_DIR}/libpty_bridge.so"
    chmod 600 "${LIB_DIR}/libpty_bridge.so"

    echo ""
    info "${BOLD}Installation complete!${RESET}"
    echo -e "  ${DIM}Server binary:${RESET}  ${INSTALL_DIR}/fewshell-server"
    echo -e "  ${DIM}Shared library:${RESET} ${LIB_DIR}/libpty_bridge.so"
    echo ""
}

pair_device() {
    echo ""
    step "Device pairing"
    echo ""

    # Detect the current username for relay identification.
    local CURRENT_USER="${USER:-${LOGNAME:-$(whoami 2>/dev/null || echo "")}}"

    # --- Prompt for pairing code and fetch key (retry loop) ---
    local PUBKEY=""
    while [ -z "$PUBKEY" ]; do
        printf "Enter 6-digit pairing code: "
        read -r CODE

        # Validate format
        case "$CODE" in
            [0-9][0-9][0-9][0-9][0-9][0-9]) ;;
            *) warn "Pairing code must be exactly 6 digits."; continue ;;
        esac

        # Build relay URL with optional username parameter.
        local PAIR_URL="${RELAY_URL}/pubkey?id=${CODE}"
        if [ -n "$CURRENT_USER" ]; then
            PAIR_URL="${PAIR_URL}&username=${CURRENT_USER}"
        fi

        # Fetch the public key
        local RESPONSE
        RESPONSE=$(curl -sf "$PAIR_URL") || {
            warn "Failed to retrieve key (invalid code, expired, or network error)."
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
            warn "Response did not contain a public key."
            continue
        fi

        # Basic sanity check
        case "$PUBKEY" in
            ssh-ed25519\ *) ;;
            *) warn "Received key is not a valid ssh-ed25519 key."; PUBKEY=""; continue ;;
        esac
    done

    # --- Set up ~/.ssh and authorized_keys ---
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    touch "$AUTH_KEYS"
    chmod 600 "$AUTH_KEYS"

    # --- Add the key idempotently ---
    if grep -qF "$PUBKEY" "$AUTH_KEYS" 2>/dev/null; then
        info "Key already present in authorized_keys – nothing to do."
    else
        echo "$PUBKEY" >> "$AUTH_KEYS"
        info "Key added to authorized_keys."
    fi
}

# --- Entry point ---
SKIP_PAIRING=false
for arg in "$@"; do
    case "$arg" in
        --skip-pairing) SKIP_PAIRING=true ;;
    esac
done

main
if [ "$SKIP_PAIRING" = false ]; then
    pair_device
fi
