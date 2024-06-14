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
    echo "        $0 username [--add-to-sudo] [password]"
    echo "            - username: Name of the user to be created."
    echo "            - --add-to-sudo: (Optional)"
    echo "            - password: (Optional) Password for the new user.If not provided, a random password will be generated."
    echo "    From WEB:"
    echo "        To run the script from the internet use:"
    echo "        curl:"
    echo "            $ SCRIPT_URL='https://raw.githubusercontent.com/voiduin/linux-host-setup/main/create_user.bash';\\"
    echo "              curl -Ls \"\${SCRIPT_URL}\" | sudo bash -s username [--add-to-sudo] [password]"
    echo "        wget:"
    echo "            $ SCRIPT_URL='https://raw.githubusercontent.com/voiduin/linux-host-setup/main/create_user.bash';\\"
    echo "              wget -qO - \"\${SCRIPT_URL}\" | sudo bash -s username [--add-to-sudo] [password]"
    echo -e "\n"
    echo "This script creates a new user with the specified username and password."
    echo "If the password is not provided, it generates a random password for the user."
}

# Function to ensure a user does not already exist
assert_user_not_exists() {
    local username="$1"
    local user_exists=$(id "$username" &>/dev/null && echo "yes" || echo "no")

    if [[ $user_exists == "yes" ]]; then
        exit_with_err "The user already exists: $username"
    fi
}

# Exit with an error message and show usage
# Usage example: exit_with_err "Error message"
exit_with_err() {
    local message="$1"
    echo -e "${RED}Error: $message${NC}"
    echo -e "\n"
    show_usage
    exit 1
}

# Ensure the script is run as root
# Usage example: assert_run_as_root
assert_run_as_root() {
    if [[ $EUID -ne 0 ]]; then
        exit_with_err "This script must be run as root"
    fi
}

# Function to generate a random password
generate_random_password() {
    local password_length=12
    echo "$(openssl rand -base64 $password_length)"
}

# Function to create a new user with a password
create_user() {
    local username="$1"
    local password="$2"

    assert_user_not_exists "$username"

    if [[ -z $password ]]; then
        password=$(generate_random_password)
        local password_generated="yes"
    else
        local password_generated="no"
    fi

    local hashed_password="$(openssl passwd -1 "$password")"
    sudo useradd -m -p "$hashed_password" "$username"

    echo -en "${YELLOW}"
    echo "    REMEMBER: User creation successful:"
    echo "    - Username: ${username}"
    echo -n "    - Password: ${password}"
    if [[ ${password_generated} == "yes" ]]; then
        echo " (randomly generated)"
    else
        echo " (set by user)"
    fi
    echo -en "${NC}"
}

# Main function to handle script logic
main() {
    assert_run_as_root

    if [[ $# -lt 1 ]]; then
        exit_with_err "ERR: Invalid number of arguments"
    fi
    local username="$1"
    # Default to "no" if the third argument is not provided
    local need_add_to_sudo="${2:-no}"
    local password="${3:-}"

    create_user "${username}" "${password}"

    # Set default user shell - BASH (by default set minimalistic '/bash/sh')
    usermod --shell '/bin/bash' "${username}"

    if [[ "${need_add_to_sudo}" == "--add-to-sudo" ]]; then
        usermod -aG sudo "${username}"
        echo "  - User ${username} has been added to the sudo group."
    else
        echo "  - User ${username} has not been added to the sudo group."
    fi
}

main "$@"
