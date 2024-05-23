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
    echo "        $0 [new_username] [new_sshd_port]"
    echo "            - new_username: Name of the user to be created."
    echo "            - new_sshd_port: Change SSHD port from default 22 to [new_sshd_port]."
    echo "    From WEB:"
    echo "        To run the script from the internet use:"
    echo "        curl:"
    echo "            curl -Ls https://raw.githubusercontent.com/voiduin/linux-host-setup/main/setup_secure_remote_auth.bash | sudo bash -s [new_username] [new_sshd_port]"
    echo "        wget:"
    echo "            wget -qO - https://raw.githubusercontent.com/voiduin/linux-host-setup/main/setup_secure_remote_auth.bash | sudo bash -s [new_username] [new_sshd_port]"
}

# Usage example: exit_with_err "Error message"
exit_with_err() {
    local message="$1"
    echo "Error: $message"
    echo -e "\n"
    show_usage
    exit 1
}

# Usage example: assert_run_as_root
assert_run_as_root() {
    if [[ $EUID -ne 0 ]]; then
        exit_with_err "This script must be run as root"
    fi
}

# Function to download and execute a remote script with parameters "run_remote_script"
run_rscript () {
    local script="${1}"
    local status=$?
    local base_repo_url="https://raw.githubusercontent.com/voiduin/linux-host-setup/main"
    
    shift  # Remove script name from the parameters list
    params=("$@")  # Remaining arguments are parameters for the script

    echo -e "\n"
    echo -e "${BLUE}* * Info: Load and run ${script} with parameters: ${params[*]}... * *${NC}"
    curl -Ls "${base_repo_url}/${script}.bash" | sudo bash -s -- "${params[@]}"

    return $status
}

# Usage example: create_backup_for_file "/etc/ssh/sshd_config"
create_backup_for_file() {
    local file_path="${1}"
    local backup_dir="${2:-$(dirname "${file_path}")}"
    local old_filename="$(basename -- "${file_path}")"
    local backup_path="${backup_dir}/${old_filename}.$(date +%y%m%d_%H%M%Sms).bac"
    cp "${file_path}" "${backup_path}" || exit_with_err "Failed to create backup file: ${backup_path}."
    echo "Backup created: ${backup_path}"
}

# Main function to handle script logic
main() {
    local new_username="${1}"
    local new_sshd_port="${2}"

    local config_file_path="/etc/ssh/sshd_config"

    if [[ -z "$new_username" ]] || [[ -z "$new_sshd_port" ]]; then
        exit_with_err "Missing arguments. Please specify a [new_username] and a [new_sshd_port]."
    fi

    assert_run_as_root

    # Create new user with random password
    run_rscript create_user ${new_username}
    local user_creation_status=$?

    # Configure SSH config file
    create_backup_for_file "${config_file_path}"
    run_rscript sshd_configure Port ${new_sshd_port}
    local sshd_config_status=$?
   
    # Install fail2ban
    run_rscript fail2ban_install
    local fail2ban_status=$?

    echo -e "\n${BLUE}Operation Summary (0 - success, 1 - error):${NC}"
    echo -e "  - ${GREEN}User Creation:${NC} ${user_creation_status}"
    echo -e "  - ${GREEN}SSHD Configuration:${NC} ${sshd_config_status}"
    echo -e "  - ${GREEN}Fail2Ban Installation:${NC} ${fail2ban_status}"


    echo "Config ended"
}

main "$@"
