#!/bin/bash

# get.few.sh
# Install: curl -LsSf get.few.sh | bash

set -u

# Color codes for aesthetics
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# Parse args
LIMIT_KEYS=5
SEARCH_LIMIT=20
for arg in "$@"; do
    if [[ "$arg" == "-a" || "$arg" == "--all-keys" ]]; then
        LIMIT_KEYS=1000
        SEARCH_LIMIT=1000
    fi
done

# Banner
echo -e ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗"
echo -e "║                    ${BOLD}fewshell host setup${RESET}${CYAN}                     ║"
echo -e "║           ${DIM}Secure SSH & API Key QR Code Generator${RESET}${CYAN}           ║"
echo -e "╚════════════════════════════════════════════════════════════╝${RESET}"
echo -e ""
echo -e "${BOLD}This script will:${RESET}"
echo -e "  ${GREEN}1.${RESET} Name your project"
echo -e "  ${GREEN}2.${RESET} Detect the public IP address"
echo -e "  ${GREEN}3.${RESET} Configure LLM provider and API keys"
echo -e "      ${DIM}Optionally you can search for API keys in this host${RESET}"
echo -e "      ${DIM}(Use --all-keys flag to search for more)${RESET}"
echo -e "  ${GREEN}4.${RESET} Create SSH key pair (few.sh)"
echo -e "  ${GREEN}5.${RESET} Generate QR codes with all information"
echo -e ""

# Determine default project name
DEFAULT_NAME="skip"

# Try to get GitHub repo name first
if [ -d .git ]; then
    REPO_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")
    if [ -n "$REPO_URL" ]; then
        # Extract repo name from various URL formats
        DEFAULT_NAME=$(basename "$REPO_URL" .git 2>/dev/null || echo "skip")
    fi
fi

# Fallback to hostname if GitHub repo name not found
if [ "$DEFAULT_NAME" = "skip" ]; then
    HOSTNAME_VAL=$(hostname 2>/dev/null || echo "")
    if [ -n "$HOSTNAME_VAL" ]; then
        DEFAULT_NAME="$HOSTNAME_VAL"
    fi
fi

# Interactive project name prompt
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}📝 Project Name${RESET}"
echo -e ""
read -p "$(echo -e "${YELLOW}Enter project name${RESET} [${GREEN}${DEFAULT_NAME}${RESET}]: ")" PROJECT_NAME < /dev/tty

# Use default if empty
if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME="$DEFAULT_NAME"
fi

echo -e "${GREEN}✓${RESET} Project name: ${BOLD}${PROJECT_NAME}${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# 1. GET IP
echo -e "${BLUE}🌐 Detecting public IP address...${RESET}"
EXTERNAL_IP=$(curl -s --max-time 5 https://ifconfig.me || curl -s --max-time 5 https://api.ipify.org || echo "Unavailable")
echo -e "${GREEN}✓${RESET} IP Address: ${BOLD}${EXTERNAL_IP}${RESET}"
echo ""

# 2. SELECT LLM PROVIDER
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}🤖 LLM Provider Selection${RESET}"
echo -e ""
echo -e "  ${YELLOW}[1]${RESET} ANTHROPIC"
echo -e "  ${YELLOW}[2]${RESET} OPENAI"
echo -e "  ${YELLOW}[3]${RESET} GEMINI"
echo -e "  ${YELLOW}[S]${RESET} SKIP (no API key configuration)"
echo -e ""
read -n 1 -p "$(echo -e "${YELLOW}Select provider${RESET}: ")" provider_opt < /dev/tty
echo ""
echo ""

SELECTED_PROVIDER=""
PROVIDER_KEY_NAME=""
PROVIDER_LABEL=""

case "$provider_opt" in
    1)
        SELECTED_PROVIDER="ANTHROPIC"
        PROVIDER_KEY_NAME="ANTHROPIC_API_KEY"
        PROVIDER_LABEL="anthropic"
        echo -e "${GREEN}✓${RESET} Selected: ${BOLD}ANTHROPIC${RESET}"
        ;;
    2)
        SELECTED_PROVIDER="OPENAI"
        PROVIDER_KEY_NAME="OPENAI_API_KEY"
        PROVIDER_LABEL="openai"
        echo -e "${GREEN}✓${RESET} Selected: ${BOLD}OPENAI${RESET}"
        ;;
    3)
        SELECTED_PROVIDER="GEMINI"
        PROVIDER_KEY_NAME="GEMINI_API_KEY"
        PROVIDER_LABEL="google"
        echo -e "${GREEN}✓${RESET} Selected: ${BOLD}GEMINI${RESET}"
        ;;
    [sS])
        echo -e "${DIM}Skipping API key configuration.${RESET}"
        ;;
    *)
        echo -e "${DIM}Invalid selection. Skipping API key configuration.${RESET}"
        ;;
esac
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# 3. CONFIGURE API KEY
SEL_LABEL=""
SEL_VAL=""

if [ -n "$SELECTED_PROVIDER" ]; then
    echo -e "${BLUE}🔑 API Key Configuration${RESET}"
    echo -e ""
    echo -e "You can either:"
    echo -e "  ${YELLOW}1.${RESET} Enter your API key manually"
    echo -e "  ${YELLOW}2.${RESET} Press ${DIM}Enter${RESET} to search for existing keys on this host"
    echo -e ""
    read -p "$(echo -e "${YELLOW}Enter ${SELECTED_PROVIDER} API key${RESET} (or press Enter to search): ")" manual_key < /dev/tty
    echo ""

    if [ -n "$manual_key" ]; then
        # User provided a manual key
        SEL_VAL="$manual_key"
        SEL_LABEL="${PROVIDER_KEY_NAME} (manual)"
        echo -e "${GREEN}✓${RESET} Using manually entered API key"
    else
        # Search for keys on the host
        echo -e "${BLUE}🔍 Searching for ${SELECTED_PROVIDER} API keys...${RESET}"

        KEYS_LABELS=()
        KEYS_VALUES=()

        # Build pattern based on selected provider
        if [ "$SELECTED_PROVIDER" = "GEMINI" ]; then
            PATTERN="(GEMINI_API_KEY|GOOGLE_API_KEY)="
        else
            PATTERN="${PROVIDER_KEY_NAME}="
        fi

        if command -v rg >/dev/null 2>&1; then
            MATCHES=$(rg -INH --no-heading -m 5 -g '!*.log' "$PATTERN" "$HOME" 2>/dev/null | head -n "$SEARCH_LIMIT")
        else
            MATCHES=$(grep -rIE -m 5 \
                --include="*setting*" --include="*config*" --include="*credential*" \
                --include="*env*" --include="*app*" --include="*secret*" \
                --include="*key*" --include="*rc*" --include="*profile*" \
                --exclude="*.log" \
                --exclude-dir={.git,node_modules,__pycache__,.venv,venv,env,.cache,.npm,.yarn,target,build,dist,.vscode,.idea,.cargo,.go,Library,Pictures,Music,Movies,Downloads,.local} \
                --exclude="$(basename "$0")" "$PATTERN" "$HOME" 2>/dev/null | head -n "$SEARCH_LIMIT")
        fi

        while IFS=: read -r file line; do
            if [ "$SELECTED_PROVIDER" = "GEMINI" ]; then
                # For GEMINI, accept both GEMINI_API_KEY and GOOGLE_API_KEY
                if [[ "$line" =~ (GEMINI_API_KEY|GOOGLE_API_KEY)=[[:space:]]*[\"\']?([^[:space:];\"\']+) ]]; then
                    key="${BASH_REMATCH[1]}"
                    val="${BASH_REMATCH[2]}"
                    if [[ "${#val}" -ge 30 && "$val" != *"your_"* && "$val" != *"YOUR_"* && "$val" != *"123456"* ]]; then
                        if [[ ! " ${KEYS_VALUES[*]:-} " =~ " ${val} " ]]; then
                            KEYS_LABELS+=("$key (file): $file")
                            KEYS_VALUES+=("$val")
                            [ "${#KEYS_VALUES[@]}" -ge "$LIMIT_KEYS" ] && break
                        fi
                    fi
                fi
            else
                # For other providers, use the standard pattern
                if [[ "$line" =~ ${PROVIDER_KEY_NAME}=[[:space:]]*[\"\']?([^[:space:];\"\']+) ]]; then
                    val="${BASH_REMATCH[1]}"
                    if [[ "${#val}" -ge 30 && "$val" != *"your_"* && "$val" != *"YOUR_"* && "$val" != *"123456"* ]]; then
                        if [[ ! " ${KEYS_VALUES[*]:-} " =~ " ${val} " ]]; then
                            KEYS_LABELS+=("$PROVIDER_KEY_NAME (file): $file")
                            KEYS_VALUES+=("$val")
                            [ "${#KEYS_VALUES[@]}" -ge "$LIMIT_KEYS" ] && break
                        fi
                    fi
                fi
            fi
        done <<< "$MATCHES"

        if [ ${#KEYS_LABELS[@]} -gt 0 ]; then
            echo -e "${GREEN}✓${RESET} Found ${BOLD}${#KEYS_LABELS[@]}${RESET} ${SELECTED_PROVIDER} API key(s):"
            echo ""
            for i in "${!KEYS_LABELS[@]}"; do
                echo -e "  ${YELLOW}[$((i+1))]${RESET} ${KEYS_LABELS[$i]}"
            done
            echo ""

            read -n 1 -p "$(echo -e "${YELLOW}Select a key by number${RESET} (or press ${DIM}Enter${RESET} to skip): ")" opt < /dev/tty
            echo ""
            if [[ "$opt" =~ ^[0-9]+$ ]] && [ "$opt" -ge 1 ] && [ "$opt" -le "${#KEYS_LABELS[@]}" ]; then
                idx=$((opt-1))
                SEL_LABEL="${KEYS_LABELS[$idx]}"
                SEL_VAL="${KEYS_VALUES[$idx]}"
                echo -e "${GREEN}✓${RESET} Selected: ${BOLD}$SEL_LABEL${RESET}"
            else
                echo -e "${DIM}No key selected.${RESET}"
            fi
        else
            echo -e "${YELLOW}⚠${RESET}  No ${SELECTED_PROVIDER} API keys found on this host."
        fi
    fi
    echo ""
fi

# 3. SSH CONFIGURATION
echo -e "${BLUE}🔐 Configuring SSH keys...${RESET}"
KEY_FILE="$HOME/.ssh/few.sh"
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"

if [ ! -f "$KEY_FILE" ]; then
    ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -q
    echo -e "${GREEN}✓${RESET} Created new SSH key pair"
else
    echo -e "${GREEN}✓${RESET} Using existing SSH key pair"
fi

grep -qFf "${KEY_FILE}.pub" "$HOME/.ssh/authorized_keys" 2>/dev/null || cat "${KEY_FILE}.pub" >> "$HOME/.ssh/authorized_keys"
chmod 600 "$HOME/.ssh/authorized_keys"
PRIV_KEY=$(cat "$KEY_FILE")
echo ""

# FINAL REPORT
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗"
echo -e "║                       ${BOLD}HOST INFORMATION${RESET}${CYAN}                     ║"
echo -e "╚════════════════════════════════════════════════════════════╝${RESET}"
echo -e ""
echo -e "${BOLD}${MAGENTA}📋 Project Name${RESET}"
echo -e "   ${PROJECT_NAME}"
echo -e ""
echo -e "${BOLD}${BLUE}🌐 External IP Address${RESET}"
echo -e "   ${EXTERNAL_IP}"
echo -e ""
echo -e "${BOLD}${YELLOW}🔑 API Key${RESET}"
if [ -n "$SEL_LABEL" ]; then
    echo -e "   Source: ${SEL_LABEL}"
    echo -e "   Key:    ${SEL_VAL}"
else
    echo -e "   Source: ${DIM}None selected${RESET}"
    echo -e "   Key:    ${DIM}N/A${RESET}"
fi
echo -e ""
echo -e "${BOLD}${GREEN}🔐 SSH Private Key${RESET}"
echo -e "   ${DIM}Copy the block below to your local machine to access this host${RESET}"
echo -e "   ${DIM}Usage: ssh -i <your-key-file> $USER@$EXTERNAL_IP${RESET}"
echo -e ""
echo -e "${DIM}$PRIV_KEY${RESET}"
echo -e ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

# 4. QR CODE GENERATION
if command -v qrencode >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    echo ""
    echo -e "${BLUE}📱 Generating QR Code...${RESET}"
    echo ""

    # Use provider label or extract from selected label and strip SSH headers for compact QR
    if [ -n "$PROVIDER_LABEL" ]; then
        QR_LABEL="$PROVIDER_LABEL"
    else
        QR_LABEL="${SEL_LABEL%% *}"
        QR_LABEL="${QR_LABEL/OPENAI_API_KEY/openai}"
        QR_LABEL="${QR_LABEL/ANTHROPIC_API_KEY/anthropic}"
        QR_LABEL="${QR_LABEL/GEMINI_API_KEY/google}"
        QR_LABEL="${QR_LABEL/GOOGLE_API_KEY/google}"
    fi
    QR_SSH=$(echo "$PRIV_KEY" | grep -v "^-----" | tr -d '\n')

    QR_HOST="$USER@$EXTERNAL_IP"
    export QR_HOST QR_LABEL SEL_VAL QR_SSH PROJECT_NAME

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗"
echo -e "║                         ${BOLD}SCAN QR CODE${RESET}${CYAN}                       ║"
echo -e "╚════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    jq -n '{n: env.PROJECT_NAME, i: env.QR_HOST, l: env.QR_LABEL, k: env.SEL_VAL, s: env.QR_SSH}' | qrencode -m 2 -t UTF8
    echo ""
    echo -e "${GREEN}✓${RESET} QR Code generated successfully!"
    echo -e "${DIM}  Fields: n=${PROJECT_NAME}, i=${QR_HOST}, l=${QR_LABEL}, k=<key>, s=<ssh>${RESET}"
else
    echo ""
    echo -e "${YELLOW}⚠${RESET}  Skipping QR code generation (missing dependencies)"
    echo -e "${DIM}   Install with: ${BOLD}sudo apt-get install -y qrencode jq${RESET}"
fi

echo ""
echo -e "${GREEN}${BOLD}✓ Setup complete!${RESET}"
echo ""
