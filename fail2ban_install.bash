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

# Ensure that systemd is installed
assert_systemd_installed() {
    if [ ! -d "/run/systemd/system" ]; then
        exit_with_err "Systemd is not installed. Fail2Ban with backend=systemd cannot be used"
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
install_app_quietly() {
    local app_name="$1"
    assert_not_installed "${app_name}"
    echo "  - Installing new app \"${app_name}\" from standart repository..."
    sudo apt-get update > /dev/null
    sudo apt-get install "${app_name}" -y > /dev/null
}

# Function to create configuration file for Fail2Ban
create_config_file() {
    local file_path="/etc/fail2ban/jail.local"
    local config_data="
[sshd]
enabled = true
port = ssh
filter = sshd
backend = systemd
maxretry = 4
bantime = 6000
"
    echo "  - Creating configuration file at ${file_path}..."
    echo "$config_data" | sudo tee "${file_path}" > /dev/null
}

# Function to activate and start Fail2Ban
start_fail2ban() {
    echo "  - Enable unit Fail2Ban..."
    sudo systemctl enable fail2ban > /dev/null 2>&1
    echo "  - Starting unit Fail2Ban..."
    sudo systemctl start fail2ban > /dev/null
}

# Function to check the status of Fail2Ban and sshd jail
check_status() {
    echo "  - Checking Fail2Ban status..."
    sudo systemctl is-active --quiet fail2ban

    # For correct work this check always we need setup in file
    # vim /etc/systemd/journald.conf
    # [Journal]
    # Storage=auto
    # Storage=persistent
    # Source: https://stackoverflow.com/questions/30783134/systemd-user-journals-not-being-created
    if [ $? -ne 0 ]; then
        echo -e "\n"
        echo -e "${RED}* * Error: Fail2Ban service is not running properly${NC}"
        echo -e "${YELLOW}"
        echo "    [START of output] Possible reason described in journalctl:"
        sudo journalctl -u fail2ban | grep fail2ban
        echo "    [END of output]"
        echo -e "${NC}"
        return 1
    fi

    echo "  - Checking Fail2Ban jail for SSH..."
    sudo fail2ban-client status sshd > /dev/null
    if [ $? -ne 0 ]; then
        echo "Error: SSH jail is not active in Fail2Ban."
        return 1
    fi

    echo "  - SUCCESS: Fail2Ban and SSH jail are active and running."
    return 0
}

main() {
    assert_run_as_root
    assert_file_not_exists "/etc/fail2ban/jail.local"
    assert_systemd_installed
    install_app_quietly "fail2ban"
    create_config_file
    start_fail2ban
    # Wait while f2b started
    # Without wait we get error: Failed to access socket path: /var/run/fail2ban/fail2ban.sock. Is fail2ban running?
    sleep 2
    check_status
}

main "$@"
