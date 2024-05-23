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
    echo "    Directly in CLI - run the script with sudo:"
    echo "        sudo $0"
    echo "    From WEB:"
    echo "        To run the script from the internet use:"
    echo "        curl:"
    echo "            curl -Ls https://raw.githubusercontent.com/voiduin/linux-host-setup/main/fail2ban_install.bash | sudo bash -s"
    echo "        wget:"
    echo "            wget -qO - https://raw.githubusercontent.com/voiduin/linux-host-setup/main/fail2ban_install.bash | sudo bash -s"
    echo -e "\n"
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
    echo -e "\n"
    echo -e "${BLUE}* * Info: Creating configuration file at ${file_path}... * *${NC}"
    echo -e "\n"
    echo "$config_data" | sudo tee "${file_path}" > /dev/null
}

# Function to activate and start Fail2Ban
start_fail2ban() {
    echo -e "\n"
    echo -e "${BLUE}* * Info: Activating and starting Fail2Ban... * *${NC}"
    echo -e "\n"
    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban
}

# Function to check the status of Fail2Ban and sshd jail
check_status() {
    echo "Checking Fail2Ban status..."
    sudo systemctl is-active --quiet fail2ban

    # For correct work this check always we need setup in file
    # vim /etc/systemd/journald.conf
    # [Journal]
    # Storage=auto
    # Storage=persistent
    # Source: https://stackoverflow.com/questions/30783134/systemd-user-journals-not-being-created
    if [ $? -ne 0 ]; then
        echo -e "\n"
        echo -e "${RED}* * Error: Fail2Ban service is not running properly * *${NC}"
        echo -e "${YELLOW}"
        echo "    [START of output] Possible reason described in journalctl:"
        sudo journalctl -u fail2ban | grep fail2ban
        echo "    [END of output]"
        echo -e "${NC}"
        return 1
    fi

    echo "Checking Fail2Ban jail for SSH..."
    sudo fail2ban-client status sshd
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
    # Wait while f2b started
    # Without wait we get error: Failed to access socket path: /var/run/fail2ban/fail2ban.sock. Is fail2ban running?
    sleep 2
    check_status
}

main "$@"
