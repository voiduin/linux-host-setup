#!/bin/bash

# Set bash execution flags:
# - Treat unset variables as an error when substituting
# - Exit immediately if a command exits with a non-zero status
# - Print each command to stdout before executing it (useful for debugging)
set -u
# set -e
# set -x

# Show usage instructions
# Usage example: show_usage
show_usage() {
    echo "Usage: $0 username [password]"
    echo "username: Name of the user to be created."
    echo "password: (Optional) Password for the new user. If not provided, a random password will be generated."
    echo
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
    echo "Error: $message"
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

    echo "User creation successful:"
    echo "  - Username: $username"
    echo -n "  - Password: $password"
    if [[ $password_generated == "yes" ]]; then
        echo " (randomly generated)"
    else
        echo " (set by user)"
    fi
}

# Main function to handle script logic
main() {
    assert_run_as_root

    if [[ $# -lt 1 ]]; then
        exit_with_err "Invalid number of arguments"
    fi
    local username="$1"
    local password="${2:-}"

    create_user "$username" "$password"
}

main "$@"