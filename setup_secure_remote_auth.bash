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

export RSCRIPT_BASE_URL='https://raw.githubusercontent.com/voiduin/linux-host-setup/main'
script_path="remote_scripts_methods.bash"
script_content=$(curl -Ls --fail "${RSCRIPT_BASE_URL}/${script_path}" || { echo "Failed to download script from ${RSCRIPT_BASE_URL}/${script_path}" >&2; exit 1; })
source <(echo -n "${script_content}")


# Show usage instructions
# Usage example: show_usage
show_usage() {
    echo "= = Usage = ="
    echo "    Directly in CLI:"
    echo "        $0 [new_username] [new_sshd_port] [--restart-sshd]"
    echo "            - new_username [string]: Name of the user to be created."
    echo "            - new_sshd_port [digit]: Change SSHD port from default 22 to [new_sshd_port]."
    echo "            - --restart-sshd or empty: This argument determines if SSHD needs to be restarted"
    echo "    From WEB:"
    echo "        To run the script from the internet use:"
    echo "        curl:"
    echo "            curl -Ls https://raw.githubusercontent.com/voiduin/linux-host-setup/main/setup_secure_remote_auth.bash | sudo bash -s [new_username] [new_sshd_port] [--restart-sshd]"
    echo "        wget:"
    echo "            wget -qO - https://raw.githubusercontent.com/voiduin/linux-host-setup/main/setup_secure_remote_auth.bash | sudo bash -s [new_username] [new_sshd_port] [--restart-sshd]"
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

# Usage example: assert_run_as_root
assert_run_as_root() {
    if [[ $EUID -ne 0 ]]; then
        exit_with_err "This script must be run as root"
    fi
}

# Usage example: create_backup_for_file "/etc/ssh/sshd_config"
create_backup_for_file() {
    local file_path="${1}"
    local backup_dir="${2:-$(dirname "${file_path}")}"

    echo -e "  ${BLUE}Backup${NC} file \"${file_path}\" start ..."
    local old_filename="$(basename -- "${file_path}")"
    local backup_path="${backup_dir}/${old_filename}.$(date +%y%m%d_%H%M%Sms).bac"
    cp "${file_path}" "${backup_path}" || exit_with_err "Failed to create backup file: ${backup_path}."
    echo "  - Backup created: ${backup_path}"
    echo -ne "\n"
    return 0
}

# Without parameters
restart_sshd() {
    echo -e "  ${BLUE}SSHD${NC} restart start ..."
    systemctl restart sshd
    if [[ $? -ne 0 ]]; then
        echo "  - Failed to restart SSHD."
        return 1
    fi
    echo "  - SSHD restarted successfully."
    echo -ne "\n"
    return 0
}

# Main function to handle script logic
main() {
    local new_username="${1}"
    local new_sshd_port="${2}"
    local need_restart_sshd="${3:-no}"  # Default to no if not provided

    local config_file_path="/etc/ssh/sshd_config"
    local total_errors=0

    if [[ -z "$new_username" ]] || [[ -z "$new_sshd_port" ]]; then
        exit_with_err "Missing arguments. Please specify a [new_username] and a [new_sshd_port]."
    fi

    assert_run_as_root

    # Create new user with random password
    run_rscript create_user.bash --sudo --verbose "${new_username}" "yes"
    local user_creation_status=$?
    ((total_errors += user_creation_status != 0 ? 1 : 0))

    # Configure SSH config file
    create_backup_for_file "${config_file_path}"
    run_rscript sshd_configure.bash --sudo --verbose Port ${new_sshd_port}
    local sshd_port_status=$?
    ((total_errors += sshd_port_status != 0 ? 1 : 0))

    run_rscript sshd_configure.bash --sudo --verbose PermitRootLogin no
    local sshd_permit_root_status=$?
    ((total_errors += sshd_permit_root_status != 0 ? 1 : 0))

    run_rscript sshd_configure.bash --sudo --verbose LoginGraceTime 50
    local sshd_login_grace_status=$?
    ((total_errors += sshd_login_grace_status != 0 ? 1 : 0))
   
    # Install fail2ban
    run_rscript fail2ban_install.bash --sudo --verbose
    local fail2ban_status=$?
    ((total_errors += fail2ban_status != 0 ? 1 : 0))

    # Check if SSHD needs to be restarted
    local sshd_restart_status=0
    if [[ "${need_restart_sshd}" == "--restart-sshd" ]]; then
        restart_sshd
        sshd_restart_status=$?
        ((total_errors += sshd_restart_status != 0 ? 1 : 0))
    fi

    echo -e "  ${BLUE}Operation Summary${NC} (Status codes: 0 is success, 1 is error):"
    echo -e "  - User Creation:${NC} ${user_creation_status}"
    echo -e "  - SSHD Port Configuration: ${sshd_port_status}"
    echo -e "  - SSHD PermitRootLogin Configuration: ${sshd_permit_root_status}"
    echo -e "  - SSHD PermitRootLogin Configuration: ${sshd_login_grace_status}"
    echo -e "  - Fail2Ban Installation: ${fail2ban_status}"
    if [[ "${need_restart_sshd}" == "--restart-sshd" ]]; then
        echo -e "  - SSHD Restart: ${sshd_restart_status}"
    fi
    echo -ne "\n"

    if [[ "${total_errors}" -eq 0 ]]; then
        echo -e "  ${GREEN}SUCCESS${NC}: Configuration process completed successfully."
    else
        echo -e "  ${YELLOW}WARNING${NC}: Configuration process completed:"
        echo -e "           Total errors: ${total_errors}"
    fi
}

main "$@"
