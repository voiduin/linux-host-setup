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
    echo "= = Usage = ="
    echo "    Run the script with sudo:"
    echo "        sudo $0"
    echo
    echo "Requirements:"
    echo "    - Run as root"
    echo "    - Fail2Ban must be NOT installed"
    echo
    echo "This script installs and configures Fail2Ban to protect SSH."
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

# Ensure a file does not already exist
# Usage example: assert_file_not_exists "/path/to/file"
assert_file_not_exists() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        exit_with_err "The specified file already exists: $file_path"
    fi
}

# Ensure an application is not already installed
assert_not_installed() {
    local app_name="$1"
    # Checking if the package is installed and not marked for removal
    if dpkg-query -W -f='${Status}' "$app_name" 2>/dev/null | grep -q "install ok installed"; then
        exit_with_err "The application is already installed: $app_name"
    fi
}

# Install an application by its name
install_app() {
    local app_name="$1"
    assert_not_installed "$app_name"
    echo "Installing $app_name..."
    sudo apt-get update
    sudo apt-get install "$app_name" -y
}

# Function to create configuration file for Fail2Ban
create_config_file() {
    local file_path="/etc/fail2ban/jail.local"
    local config_data="
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 600
"
    echo "Creating configuration file at $file_path..."
    echo "$config_data" | sudo tee $file_path > /dev/null
}

# Function to activate and start Fail2Ban
start_fail2ban() {
    echo "Activating and starting Fail2Ban..."
    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban
}

# Function to check the status of Fail2Ban and sshd jail
check_status() {
    echo "Checking Fail2Ban status..."
    sudo systemctl status fail2ban > /dev/null
    if [ $? -ne 0 ]; then
        echo "Error: Fail2Ban service is not running properly."
        return 1
    fi

    echo "Checking Fail2Ban jail for SSH..."
    sudo fail2ban-client status sshd > /dev/null
    if [ $? -ne 0 ]; then
        echo "Error: SSH jail is not active in Fail2Ban."
        return 1
    fi

    echo "OK: Fail2Ban and SSH jail are active and running."
}

main() {
    assert_run_as_root
    assert_file_not_exists "/etc/fail2ban/jail.local"
    install_app "fail2ban"
    create_config_file
    start_fail2ban
    check_status
}

main "$@"
