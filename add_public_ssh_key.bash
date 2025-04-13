#!/bin/bash

# Set bash execution flags:
# - Treat unset variables as an error when substituting
# - Exit immediately if a command exits with a non-zero status
# - Print each command to stdout before executing it (useful for debugging)
set -u
# set -e
# set -x

# ANSI Colors
RED='\033[0;31m' # Error
GREEN='\033[0;32m' # Success
BLUE='\033[0;34m' # Info
YELLOW='\033[0;93m' # Warning/Useful info
NC='\033[0m' # No Color

# Show usage instructions
# Usage example: show_usage
show_usage() {
    echo "= = Usage = ="
    echo "    Directly in CLI:"
    echo "        ${0} <username> --ssh-public-key-url https://example.com/mykey.pub"
    echo "    From WEB:"
    echo "        To run the script from the internet use:"
    echo "        curl:"
    echo "            curl -Ls https://raw.githubusercontent.com/voiduin/linux-host-setup/main/add_public_ssh_key.bash | bash -s -- <username> --ssh-public-key-url https://example.com/mykey.pub"
    echo "        wget:"
    echo "            wget -qO - https://raw.githubusercontent.com/voiduin/linux-host-setup/main/add_public_ssh_key.bash | bash -s -- <username> --ssh-public-key-url https://example.com/mykey.pub"
    echo -e "\n"
    echo "Parameters:"
    echo "    username               Required. The user to add the SSH key to."
    echo "    --ssh-public-key-url   Required. URL to the public SSH key."
    echo -e "\n"
    echo "Requirements:"
    echo "    - No dependencies required (only bash and curl)"
    echo -e "\n"
    echo "This script downloads a public SSH key and adds it to a user's authorized_keys file."
}

# Exit with an error message and show usage
# Usage example: exit_with_err "Error message"
exit_with_err() {
    local message="${1}"
    echo -e "${RED}Error: ${message}${NC}"
    echo -e "\n"
    show_usage
    exit 1
}

# Adds a public SSH key from a given URL to the user's authorized_keys file
add_ssh_key_from_url() {
    local target_user="${1}"
    local key_url="${2}"
    local target_home

    target_home=$(eval echo "~${target_user}")
    echo -e "  - Adding SSH public key from URL: ${key_url}"
    echo -e "  - Target user: ${target_user}, home: ${target_home}"

    local pubkey
    pubkey=$(curl -fsSL "${key_url}") || exit_with_err "Failed to download key from ${key_url}"

    # Abort if this looks like a private key
    if echo "$pubkey" | grep -qE '^\s*-----BEGIN'; then
        exit_with_err "Detected potential private key. Aborting."
    fi

    # Validate the public key format
    if ! echo "$pubkey" | grep -qE '^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp|ssh-dss) '; then
        exit_with_err "Invalid SSH public key format. Public keys should start with ssh-rsa, ssh-ed25519, ecdsa-sha2-nistp, or ssh-dss."
    fi

    local ssh_dir="$target_home/.ssh"
    local auth_file="$ssh_dir/authorized_keys"

    # Ensure .ssh directory exists
    if [[ -d "$ssh_dir" ]]; then
        echo "  - SSH directory already exists: $ssh_dir"
    else
        echo "  - Creating SSH directory: $ssh_dir"
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
        chown "${target_user}:${target_user}" "$ssh_dir"
    fi

    # Extract only the key type and base64 part (ignore comment)
    pubkey_main=$(echo "$pubkey" | awk '{print $1, $2}')

    # Avoid duplicate key insertion
    if [[ -f "${auth_file}" ]] && grep -qF "$pubkey_main" "${auth_file}"; then
        echo -e "  - ${YELLOW}[WARN] Public key already present in ${auth_file}. Skipping.${NC}"
        return
    fi

    # Append key to authorized_keys
    echo "$pubkey" >> "${auth_file}"
    chmod 600 "${auth_file}"
    chown "${target_user}:${target_user}" "${auth_file}"

    echo "  - SSH public key added to ${auth_file} for user ${target_user}"
}

main() {
    # Argument parsing and function call
    local SSH_KEY_URL=""
    local TARGET_USER=""

    # Check if at least one argument is provided
    if [[ $# -lt 1 ]]; then
        exit_with_err "No arguments provided. Username is required."
    fi

    # First argument should be the username
    TARGET_USER="${1}"
    shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ssh-public-key-url)
                SSH_KEY_URL="${2}"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                exit_with_err "Unknown argument: $1"
                ;;
        esac
    done

    # Verify we have the required SSH key URL
    if [[ -z "${SSH_KEY_URL}" ]]; then
        exit_with_err "No --ssh-public-key-url provided"
    fi

    # Verify the target user exists
    if ! id "$TARGET_USER" &>/dev/null; then
        exit_with_err "User '$TARGET_USER' does not exist"
    fi

    # Add the SSH key
    add_ssh_key_from_url "$TARGET_USER" "$SSH_KEY_URL"
}

main "$@"
