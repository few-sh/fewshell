#!/bin/bash

# get.few.sh
# This bash script is intentionally stored as index.html
# Cloudflare build command converts index.html.sh to index.html
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

# Global Configuration
LIMIT_KEYS=5
SEARCH_LIMIT=20

# Global State
PROJECT_NAME=""
EXTERNAL_IP=""
SELECTED_PROVIDER=""
PROVIDER_KEY_NAME=""
PROVIDER_LABEL=""
SEL_LABEL=""
SEL_VAL=""
PRIV_KEY=""

print_banner() {
    echo -e ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗"
    echo -e "║                    ${BOLD}fewshell host setup${RESET}${CYAN}                     ║"
    echo -e "║           ${DIM}Secure SSH & API Key QR Code Generator${RESET}${CYAN}           ║"
    echo -e "╚════════════════════════════════════════════════════════════╝${RESET}"
    echo -e ""
    echo -e "This script will transfer credentials to your mobile device."
    echo -e "The information is only used to generate a QR code."
    echo -e "The data will be safely stored in your phone's keychain."
    echo -e "Full contents of this script at https://get.few.sh"
    echo -e "Explanation of script at https://get.few.sh/explain"
    echo -e ""
    echo -e "${BOLD}Steps that follow:${RESET}"
    echo -e "  ${GREEN}1.${RESET} Name your project ${DIM}(auto-detect, manual, or skip)${RESET}"
    echo -e "  ${GREEN}2.${RESET} Configure IP address ${DIM}(auto-detect, manual, or skip)${RESET}"
    echo -e "  ${GREEN}3.${RESET} Configure LLM provider and API keys ${DIM}(search, manual, or skip)${RESET}"
    echo -e "      ${DIM}(Use --all-keys flag to search for more)${RESET}"
    echo -e "  ${GREEN}4.${RESET} Configure SSH key ${DIM}(create, select, paste, or skip)${RESET}"
    echo -e "  ${GREEN}5.${RESET} Generate QR code with selected information"
    echo -e ""
}

get_project_name() {
    # Determine default project name
    local default_name=""

    # Try to get GitHub repo name first
    if [ -d .git ]; then
        local repo_url
        repo_url=$(git config --get remote.origin.url 2>/dev/null || echo "")
        if [ -n "$repo_url" ]; then
            # Extract repo name from various URL formats
            default_name=$(basename "$repo_url" .git 2>/dev/null || echo "")
        fi
    fi

    # Fallback to hostname if GitHub repo name not found
    if [ -z "$default_name" ]; then
        local hostname_val
        hostname_val=$(hostname 2>/dev/null || echo "")
        if [ -n "$hostname_val" ]; then
            default_name="$hostname_val"
        fi
    fi

    # Interactive project name prompt
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}📝 Project Name${RESET}"
    echo -e ""
    echo -e "  ${YELLOW}1.${RESET} Use auto-detected name: ${GREEN}${default_name:-N/A}${RESET}"
    echo -e "  ${YELLOW}2.${RESET} Enter manually"
    echo -e "  ${YELLOW}3.${RESET} Skip (no project name)"
    echo -e ""
    read -p "$(echo -e "${YELLOW}Select option${RESET} [${GREEN}1${RESET}]: ")" name_choice < /dev/tty
    echo ""

    case "${name_choice:-1}" in
        1)
            PROJECT_NAME="$default_name"
            if [ -n "$PROJECT_NAME" ]; then
                echo -e "${GREEN}✓${RESET} Project name: ${BOLD}${PROJECT_NAME}${RESET}"
            else
                echo -e "${DIM}No auto-detected name available, skipping.${RESET}"
            fi
            ;;
        2)
            read -p "$(echo -e "${YELLOW}Enter project name${RESET}: ")" input_name < /dev/tty
            PROJECT_NAME="$input_name"
            if [ -n "$PROJECT_NAME" ]; then
                echo -e "${GREEN}✓${RESET} Project name: ${BOLD}${PROJECT_NAME}${RESET}"
            else
                echo -e "${DIM}No name entered, skipping.${RESET}"
            fi
            ;;
        3)
            PROJECT_NAME=""
            echo -e "${DIM}Skipping project name.${RESET}"
            ;;
        *)
            echo -e "${DIM}Invalid option, skipping.${RESET}"
            PROJECT_NAME=""
            ;;
    esac

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}

get_public_ip() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}🌐 IP Address / Hostname${RESET}"
    echo -e ""
    echo -e "  ${YELLOW}1.${RESET} Auto-detect public IP"
    echo -e "  ${YELLOW}2.${RESET} Enter manually (IP or hostname)"
    echo -e "  ${YELLOW}3.${RESET} Skip (no IP/hostname)"
    echo -e ""
    read -p "$(echo -e "${YELLOW}Select option${RESET} [${GREEN}1${RESET}]: ")" ip_choice < /dev/tty
    echo ""

    case "${ip_choice:-1}" in
        1)
            echo -e "${BLUE}Detecting public IP address...${RESET}"
            EXTERNAL_IP=$(curl -s --max-time 5 https://ifconfig.me || curl -s --max-time 5 https://api.ipify.org || echo "")
            if [ -n "$EXTERNAL_IP" ]; then
                echo -e "${GREEN}✓${RESET} IP Address: ${BOLD}${EXTERNAL_IP}${RESET}"
            else
                echo -e "${YELLOW}⚠${RESET}  Could not detect IP address, skipping."
            fi
            ;;
        2)
            read -p "$(echo -e "${YELLOW}Enter IP address or hostname${RESET}: ")" manual_ip < /dev/tty
            EXTERNAL_IP="$manual_ip"
            if [ -n "$EXTERNAL_IP" ]; then
                echo -e "${GREEN}✓${RESET} IP/Hostname: ${BOLD}${EXTERNAL_IP}${RESET}"
            else
                echo -e "${DIM}No IP/hostname entered, skipping.${RESET}"
            fi
            ;;
        3)
            EXTERNAL_IP=""
            echo -e "${DIM}Skipping IP/hostname.${RESET}"
            ;;
        *)
            echo -e "${DIM}Invalid option, skipping.${RESET}"
            EXTERNAL_IP=""
            ;;
    esac

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}

search_api_keys() {
    echo -e "${BLUE}🔍 Searching for ${SELECTED_PROVIDER} API keys...${RESET}"

    local keys_labels=()
    local keys_values=()
    local pattern
    local matches

    # Build pattern based on selected provider
    if [ "$SELECTED_PROVIDER" = "GEMINI" ]; then
        pattern="(GEMINI_API_KEY|GOOGLE_API_KEY)="
    else
        pattern="${PROVIDER_KEY_NAME}="
    fi

    if command -v rg >/dev/null 2>&1; then
        matches=$(rg -INH --no-heading -m 5 -g '!*.log' "$pattern" "$HOME" 2>/dev/null | head -n "$SEARCH_LIMIT")
    else
        matches=$(grep -rIE -m 5 \
            --include="*setting*" --include="*config*" --include="*credential*" \
            --include="*env*" --include="*app*" --include="*secret*" \
            --include="*key*" --include="*rc*" --include="*profile*" \
            --exclude="*.log" \
            --exclude-dir={.git,node_modules,__pycache__,.venv,venv,env,.cache,.npm,.yarn,target,build,dist,.vscode,.idea,.cargo,.go,Library,Pictures,Music,Movies,Downloads,.local} \
            --exclude="$(basename "$0")" "$pattern" "$HOME" 2>/dev/null | head -n "$SEARCH_LIMIT")
    fi

    while IFS=: read -r file line; do
        if [ "$SELECTED_PROVIDER" = "GEMINI" ]; then
            # For GEMINI, accept both GEMINI_API_KEY and GOOGLE_API_KEY
            if [[ "$line" =~ (GEMINI_API_KEY|GOOGLE_API_KEY)=[[:space:]]*[\"\']?([^[:space:];\"\']+) ]]; then
                local key="${BASH_REMATCH[1]}"
                local val="${BASH_REMATCH[2]}"
                if [[ "${#val}" -ge 30 && "$val" != *"your_"* && "$val" != *"YOUR_"* && "$val" != *"123456"* ]]; then
                    if [[ ! " ${keys_values[*]:-} " =~ " ${val} " ]]; then
                        keys_labels+=("$key (file): $file")
                        keys_values+=("$val")
                        [ "${#keys_values[@]}" -ge "$LIMIT_KEYS" ] && break
                    fi
                fi
            fi
        else
            # For other providers, use the standard pattern
            if [[ "$line" =~ ${PROVIDER_KEY_NAME}=[[:space:]]*[\"\']?([^[:space:];\"\']+) ]]; then
                local val="${BASH_REMATCH[1]}"
                if [[ "${#val}" -ge 30 && "$val" != *"your_"* && "$val" != *"YOUR_"* && "$val" != *"123456"* ]]; then
                    if [[ ! " ${keys_values[*]:-} " =~ " ${val} " ]]; then
                        keys_labels+=("$PROVIDER_KEY_NAME (file): $file")
                        keys_values+=("$val")
                        [ "${#keys_values[@]}" -ge "$LIMIT_KEYS" ] && break
                    fi
                fi
            fi
        fi
    done <<< "$matches"

    if [ ${#keys_labels[@]} -gt 0 ]; then
        echo -e "${GREEN}✓${RESET} Found ${BOLD}${#keys_labels[@]}${RESET} ${SELECTED_PROVIDER} API key(s):"
        echo ""
        for i in "${!keys_labels[@]}"; do
            echo -e "  ${YELLOW}[$((i+1))]${RESET} ${keys_labels[$i]}"
        done
        echo ""

        read -n 1 -p "$(echo -e "${YELLOW}Select a key by number${RESET} (or press ${DIM}Enter${RESET} to cancel): ")" opt < /dev/tty
        echo ""
        if [[ "$opt" =~ ^[0-9]+$ ]] && [ "$opt" -ge 1 ] && [ "$opt" -le "${#keys_labels[@]}" ]; then
            local idx=$((opt-1))
            SEL_LABEL="${keys_labels[$idx]}"
            SEL_VAL="${keys_values[$idx]}"
            echo -e "${GREEN}✓${RESET} Selected: ${BOLD}$SEL_LABEL${RESET}"
            return 0
        else
            echo -e "${DIM}No key selected.${RESET}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠${RESET}  No ${SELECTED_PROVIDER} API keys found on this host."
        return 1
    fi
}

configure_api_key_loop() {
    while true; do
        echo -e "${BLUE}🔑 API Key Configuration${RESET}"
        echo -e ""
        echo -e "You can either:"
        echo -e "  ${YELLOW}1.${RESET} Manually provide API key"
        echo -e "  ${YELLOW}2.${RESET} Automatically search for API key"
        echo -e "  ${YELLOW}b.${RESET} Go back to previous step"
        echo -e ""
        read -p "$(echo -e "${YELLOW}Enter choice${RESET}: ")" key_choice < /dev/tty
        echo ""

        case "$key_choice" in
            1)
                echo -e "${YELLOW}Paste your ${SELECTED_PROVIDER} API key (Press Ctrl+D when done):${RESET}"
                local manual_key
                manual_key=$(cat < /dev/tty)
                echo ""

                if [ -n "$manual_key" ]; then
                    SEL_VAL="$(echo "$manual_key" | tr -d '\n' | tr -d '\r')"
                    SEL_LABEL="${PROVIDER_KEY_NAME} (manual)"
                    echo -e "${GREEN}✓${RESET} Using manually entered API key"
                    return 0
                else
                    echo -e "${RED}Empty key provided.${RESET}"
                fi
                ;;
            2)
                if search_api_keys; then
                    return 0
                fi
                echo ""
                ;;
            b|B)
                return 1
                ;;
            *)
                echo -e "${DIM}Invalid selection.${RESET}"
                ;;
        esac
    done
}

select_provider() {
    local api_key_configured=false

    while [ "$api_key_configured" = false ]; do
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo -e "${BOLD}🤖 LLM Provider Selection${RESET}"
        echo -e ""
        echo -e "  ${YELLOW}1.${RESET} ANTHROPIC"
        echo -e "  ${YELLOW}2.${RESET} OPENAI"
        echo -e "  ${YELLOW}3.${RESET} GEMINI"
        echo -e "  ${YELLOW}4.${RESET} SKIP (no API key configuration)"
        echo -e ""
        read -p "$(echo -e "${YELLOW}Select provider${RESET}: ")" provider_opt < /dev/tty
        echo ""

        SELECTED_PROVIDER=""
        PROVIDER_KEY_NAME=""
        PROVIDER_LABEL=""

        case "$provider_opt" in
            1)
                SELECTED_PROVIDER="ANTHROPIC"
                PROVIDER_KEY_NAME="ANTHROPIC_API_KEY"
                PROVIDER_LABEL="anthropic"
                ;;
            2)
                SELECTED_PROVIDER="OPENAI"
                PROVIDER_KEY_NAME="OPENAI_API_KEY"
                PROVIDER_LABEL="openai"
                ;;
            3)
                SELECTED_PROVIDER="GEMINI"
                PROVIDER_KEY_NAME="GEMINI_API_KEY"
                PROVIDER_LABEL="google"
                ;;
            4)
                echo -e "${DIM}Skipping API key configuration.${RESET}"
                api_key_configured=true
                continue
                ;;
            *)
                echo -e "${DIM}Invalid selection.${RESET}"
                continue
                ;;
        esac

        echo -e "${GREEN}✓${RESET} Selected: ${BOLD}${SELECTED_PROVIDER}${RESET}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo ""

        if configure_api_key_loop; then
            api_key_configured=true
        fi
    done
}

configure_ssh() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}🔐 SSH Key Configuration${RESET}"
    echo -e ""
    echo -e "  ${YELLOW}1.${RESET} Create/use few.sh key (recommended)"
    echo -e "  ${YELLOW}2.${RESET} Select existing key from ~/.ssh/"
    echo -e "  ${YELLOW}3.${RESET} Paste private key manually"
    echo -e "  ${YELLOW}4.${RESET} Skip (no SSH key)"
    echo -e ""
    read -p "$(echo -e "${YELLOW}Select option${RESET} [${GREEN}1${RESET}]: ")" ssh_choice < /dev/tty
    echo ""

    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"

    case "${ssh_choice:-1}" in
        1)
            local key_file="$HOME/.ssh/few.sh"
            if [ ! -f "$key_file" ]; then
                ssh-keygen -t ed25519 -f "$key_file" -N "" -q
                echo -e "${GREEN}✓${RESET} Created new SSH key pair"
            else
                echo -e "${GREEN}✓${RESET} Using existing SSH key pair"
            fi
            grep -qF "$(cat "${key_file}.pub")" "$HOME/.ssh/authorized_keys" 2>/dev/null || cat "${key_file}.pub" >> "$HOME/.ssh/authorized_keys"
            chmod 600 "$HOME/.ssh/authorized_keys"
            PRIV_KEY=$(cat "$key_file")
            ;;
        2)
            # List available private keys
            local ssh_keys=()
            while IFS= read -r key; do
                # Only include files without .pub extension and that are actual private keys
                if [[ ! "$key" =~ \.pub$ ]] && [ -f "$key" ]; then
                    ssh_keys+=("$key")
                fi
            done < <(find "$HOME/.ssh" -maxdepth 1 -type f 2>/dev/null)

            if [ ${#ssh_keys[@]} -eq 0 ]; then
                echo -e "${YELLOW}⚠${RESET}  No SSH keys found in ~/.ssh/"
                echo -e "${DIM}Skipping SSH configuration.${RESET}"
                PRIV_KEY=""
            else
                echo -e "${BLUE}Available SSH keys:${RESET}"
                echo ""
                for i in "${!ssh_keys[@]}"; do
                    echo -e "  ${YELLOW}[$((i+1))]${RESET} $(basename "${ssh_keys[$i]}")"
                done
                echo ""
                read -p "$(echo -e "${YELLOW}Select key by number${RESET}: ")" key_num < /dev/tty
                echo ""
                if [[ "$key_num" =~ ^[0-9]+$ ]] && [ "$key_num" -ge 1 ] && [ "$key_num" -le "${#ssh_keys[@]}" ]; then
                    local selected_key="${ssh_keys[$((key_num-1))]}"
                    PRIV_KEY=$(cat "$selected_key")
                    echo -e "${GREEN}✓${RESET} Selected: ${BOLD}$(basename "$selected_key")${RESET}"
                    # Add to authorized_keys if public key exists
                    if [ -f "${selected_key}.pub" ]; then
                        grep -qF "$(cat "${selected_key}.pub")" "$HOME/.ssh/authorized_keys" 2>/dev/null || cat "${selected_key}.pub" >> "$HOME/.ssh/authorized_keys"
                        chmod 600 "$HOME/.ssh/authorized_keys"
                    fi
                else
                    echo -e "${DIM}Invalid selection, skipping.${RESET}"
                    PRIV_KEY=""
                fi
            fi
            ;;
        3)
            echo -e "${YELLOW}Paste your private key (Press Ctrl+D when done):${RESET}"
            PRIV_KEY=$(cat < /dev/tty)
            echo ""
            if [ -n "$PRIV_KEY" ]; then
                echo -e "${GREEN}✓${RESET} Using manually entered private key"
            else
                echo -e "${DIM}No key entered, skipping.${RESET}"
            fi
            ;;
        4)
            PRIV_KEY=""
            echo -e "${DIM}Skipping SSH configuration.${RESET}"
            ;;
        *)
            echo -e "${DIM}Invalid option, skipping.${RESET}"
            PRIV_KEY=""
            ;;
    esac

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}

print_final_report() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗"
    echo -e "║                       ${BOLD}HOST INFORMATION${RESET}${CYAN}                     ║"
    echo -e "╚════════════════════════════════════════════════════════════╝${RESET}"
    echo -e ""
    
    if [ -n "$PROJECT_NAME" ]; then
        echo -e "${BOLD}${MAGENTA}📋 Project Name${RESET}"
        echo -e "   ${PROJECT_NAME}"
        echo -e ""
    fi
    
    if [ -n "$EXTERNAL_IP" ]; then
        echo -e "${BOLD}${BLUE}🌐 External IP Address${RESET}"
        echo -e "   ${EXTERNAL_IP}"
        echo -e ""
    fi
    
    echo -e "${BOLD}${YELLOW}🔑 API Key${RESET}"
    if [ -n "$SEL_LABEL" ]; then
        echo -e "   Source: ${SEL_LABEL}"
        echo -e "   Key:    $(echo "${SEL_VAL}" | fold -w 50 | sed '1!s/^/           /')"
    else
        echo -e "   Source: ${DIM}None selected${RESET}"
        echo -e "   Key:    ${DIM}N/A${RESET}"
    fi
    echo -e ""
    
    if [ -n "$PRIV_KEY" ]; then
        echo -e "${BOLD}${GREEN}🔐 SSH Private Key${RESET}"
        if [ -n "$EXTERNAL_IP" ]; then
            echo -e "   ${DIM}Copy the block below to your local machine to access this host${RESET}"
            echo -e "   ${DIM}Usage: ssh -i <your-key-file> $USER@$EXTERNAL_IP${RESET}"
        else
            echo -e "   ${DIM}Copy the block below to your local machine${RESET}"
        fi
        echo -e ""
        echo -e "${DIM}$PRIV_KEY${RESET}"
        echo -e ""
    fi
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

generate_qr_code() {
    if command -v qrencode > /dev/null 2>&1 && command -v jq > /dev/null 2>&1; then
        echo ""
        echo -e "${BLUE}📱 Generating QR Code...${RESET}"
        echo ""

        # Build QR code data with only non-empty fields
        local qr_label=""
        local qr_ssh=""
        local qr_host=""
        
        # Prepare label
        if [ -n "$PROVIDER_LABEL" ]; then
            qr_label="$PROVIDER_LABEL"
        elif [ -n "$SEL_LABEL" ]; then
            qr_label="${SEL_LABEL%% *}"
            qr_label="${qr_label/OPENAI_API_KEY/openai}"
            qr_label="${qr_label/ANTHROPIC_API_KEY/anthropic}"
            qr_label="${qr_label/GEMINI_API_KEY/google}"
            qr_label="${qr_label/GOOGLE_API_KEY/google}"
        fi
        
        # Prepare SSH key (strip headers for compact QR)
        if [ -n "$PRIV_KEY" ]; then
            qr_ssh=$(echo "$PRIV_KEY" | grep -v "^-----" | tr -d '\n')
        fi
        
        # Prepare host
        if [ -n "$EXTERNAL_IP" ]; then
            qr_host="$USER@$EXTERNAL_IP"
        fi

        # Build JSON with only non-empty fields
        local jq_filter='{}'
        [ -n "$PROJECT_NAME" ] && jq_filter=$(echo "$jq_filter" | jq '. + {n: env.PROJECT_NAME}')
        [ -n "$qr_host" ] && jq_filter=$(echo "$jq_filter" | jq '. + {i: env.QR_HOST}')
        [ -n "$qr_label" ] && jq_filter=$(echo "$jq_filter" | jq '. + {l: env.QR_LABEL}')
        [ -n "$SEL_VAL" ] && jq_filter=$(echo "$jq_filter" | jq '. + {k: env.SEL_VAL}')
        [ -n "$qr_ssh" ] && jq_filter=$(echo "$jq_filter" | jq '. + {s: env.QR_SSH}')

        # Export variables for jq
        export QR_HOST="$qr_host"
        export QR_LABEL="$qr_label"
        export SEL_VAL
        export QR_SSH="$qr_ssh"
        export PROJECT_NAME

        echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗"
        echo -e "║                         ${BOLD}SCAN QR CODE${RESET}${CYAN}                       ║"
        echo -e "╚════════════════════════════════════════════════════════════╝${RESET}"
        echo ""
        echo "$jq_filter" | qrencode -m 2 -t UTF8
        echo ""
        echo -e "${GREEN}✓${RESET} QR Code generated successfully!"
        
        # Show which fields are included
        local fields=""
        [ -n "$PROJECT_NAME" ] && fields="${fields}n=${PROJECT_NAME}, "
        [ -n "$qr_host" ] && fields="${fields}i=${qr_host}, "
        [ -n "$qr_label" ] && fields="${fields}l=${qr_label}, "
        [ -n "$SEL_VAL" ] && fields="${fields}k=<key>, "
        [ -n "$qr_ssh" ] && fields="${fields}s=<ssh>, "
        fields="${fields%, }"  # Remove trailing comma
        
        if [ -n "$fields" ]; then
            echo -e "${DIM}  Fields: ${fields}${RESET}"
        else
            echo -e "${DIM}  No fields included (all steps were skipped)${RESET}"
        fi
    else
        echo ""
        echo -e "${YELLOW}⚠${RESET}  Skipping QR code generation (missing dependencies)"
        echo -e "${DIM}   Install with: ${BOLD}sudo apt-get install -y qrencode jq${RESET}"
    fi
}

main() {
    # Parse args
    for arg in "$@"; do
        if [[ "$arg" == "-a" || "$arg" == "--all-keys" ]]; then
            LIMIT_KEYS=1000
            SEARCH_LIMIT=1000
        fi
    done

    print_banner
    get_project_name
    get_public_ip
    select_provider
    configure_ssh
    print_final_report
    generate_qr_code

    echo ""
    echo -e "${GREEN}${BOLD}✓ Setup complete!${RESET}"
    echo ""
}

main "$@"
