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
    echo "  This script configures secure SSH access with a new user, updated sshd settings,"
    echo "  optional public key installation, and optional SSHD restart."
    echo -e "\n"
    echo "    This script is part of the 'linux-host-setup' suite."
    echo -e "\n"
    echo "    Directly in CLI:"
    echo "        $0 --username <name> --port <sshd_port> [--ssh-public-key-url <url>] [--restart-sshd]"
    echo "        Flags:"
    echo "          --username <name>             Required. Username to create (e.g. 'admin')."
    echo "          --port <sshd_port>            Required. Port to set for SSHD (e.g. 2222)."
    echo "          --ssh-public-key-url <url>    Optional. URL to public SSH key (e.g. GitHub raw)."
    echo "          --restart-sshd                Optional. If present, restarts SSHD after configuration."
    echo "          -h, --help                    Show this help message and exit."
    echo "    From WEB:"
    echo "        To run the script from the internet use:"
    echo "        curl:"
    echo "            curl -Ls https://raw.githubusercontent.com/voiduin/linux-host-setup/main/setup_secure_remote_auth.bash | sudo bash -s -- --username <name> --port <sshd_port> --ssh-public-key-url <url> --restart-sshd"
    echo "        wget:"
    echo "            wget -qO - https://raw.githubusercontent.com/voiduin/linux-host-setup/main/setup_secure_remote_auth.bash | sudo bash -s -- --username <name> --port <sshd_port> --ssh-public-key-url <url> --restart-sshd"
    echo "  Requirements:"
    echo "    - Must be run as root (use sudo)"
    echo "    - Internet connection required to fetch remote scripts"
    echo "    - 'curl' must be installed"
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
    # Defaults
    local new_username=""
    local new_sshd_port=""
    local ssh_key_url=""
    local need_restart_sshd="no" # Default to 'no' if not provided

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --username)
                new_username="${2}"
                shift 2
                ;;
            --port)
                new_sshd_port="${2}"
                shift 2
                ;;
            --ssh-public-key-url)
                ssh_key_url="${2}"
                shift 2
                ;;
            --restart-sshd)
                need_restart_sshd="yes"
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                exit_with_err "Unknown argument: ${1}"
                ;;
        esac
    done

    local config_file_path="/etc/ssh/sshd_config"
    local total_errors=0

    if [[ -z "$new_username" ]] || [[ -z "$new_sshd_port" ]]; then
        exit_with_err "Missing required flags --username and --port"
    fi

    assert_run_as_root

    # Configure SSH config file
    create_backup_for_file "${config_file_path}"
    run_rscript sshd_configure.bash --sudo --verbose Port "${new_sshd_port}"
    local sshd_port_status=$?
    ((total_errors += sshd_port_status != 0 ? 1 : 0))

    run_rscript sshd_configure.bash --sudo --verbose PermitRootLogin no
    local sshd_permit_root_status=$?
    ((total_errors += sshd_permit_root_status != 0 ? 1 : 0))

    run_rscript sshd_configure.bash --sudo --verbose PermitEmptyPasswords no
    local sshd_permit_empty_passwords=$?
    ((total_errors += sshd_permit_empty_passwords != 0 ? 1 : 0))

    run_rscript sshd_configure.bash --sudo --verbose LoginGraceTime 50
    local sshd_login_grace_status=$?
    ((total_errors += sshd_login_grace_status != 0 ? 1 : 0))

    # Set verbose SSH server log for a clear audit process
    run_rscript sshd_configure.bash --sudo --verbose LogLevel VERBOSE # Default INFO
    local sshd_loglevel=$?
    ((total_errors += sshd_loglevel != 0 ? 1 : 0))

    # Prevent breaks in non-active terminal connections
    # For example, if you see a terminal command in a browser and you are not using SSH:
    # 60 mean - one packet in 60 seconds
    run_rscript sshd_configure.bash --sudo --verbose ClientAliveInterval 60
    local sshd_client_alive_interval=$?
    ((total_errors += sshd_client_alive_interval != 0 ? 1 : 0))
    # 20 mean - maximum 20 packets in <!ClientAliveInterval!> seconds
    # In case when ClientAliveInterval=60 - 20 is minutes to brake connection
    run_rscript sshd_configure.bash --sudo --verbose ClientAliveCountMax 20
    local sshd_client_alive_count_max=$?
    ((total_errors += sshd_client_alive_count_max != 0 ? 1 : 0))

    # Boost speed auth SSH by disable not used aut methods (Kerberos) and DNS
    run_rscript sshd_configure.bash --sudo --verbose GSSAPIAuthentication no
    local sshd_gssapi=$?
    ((total_errors += sshd_gssapi != 0 ? 1 : 0))
    run_rscript sshd_configure.bash --sudo --verbose KerberosAuthentication no
    local sshd_kerberos=$?
    ((total_errors += sshd_kerberos != 0 ? 1 : 0))
    run_rscript sshd_configure.bash --sudo --verbose UseDNS no
    local sshd_dns=$?
    ((total_errors += sshd_dns != 0 ? 1 : 0))

    # Install fail2ban
    run_rscript fail2ban_install.bash --sudo --verbose
    local fail2ban_status=$?
    ((total_errors += fail2ban_status != 0 ? 1 : 0))

    # Create new user with random password
    run_rscript create_user.bash --sudo --verbose "${new_username}" "--add-to-sudo"
    local user_creation_status=$?
    ((total_errors += user_creation_status != 0 ? 1 : 0))

    # Add SSH public key if provided
    if [[ -n "$ssh_key_url" ]]; then
        run_rscript add_public_ssh_key.bash --verbose "${new_username}" --ssh-public-key-url "${ssh_key_url}"
        local ssh_key_status=$?
        ((total_errors += ssh_key_status != 0 ? 1 : 0))
    fi

    # Restart SSHD if needed
    local sshd_restart_status=0
    if [[ "${need_restart_sshd}" == "yes" ]]; then
        restart_sshd
        sshd_restart_status=$?
        ((total_errors += sshd_restart_status != 0 ? 1 : 0))
    fi

    echo -e "  ${BLUE}Operation Summary${NC} (Status codes: 0 is success, 1 is error):"
    echo -e "  - User Creation:${NC} ${user_creation_status}"
    echo -e "  - SSHD Configuration:"
    echo -e "        Port - ${sshd_port_status}"
    echo -e "        PermitRootLogin - ${sshd_permit_root_status}"
    echo -e "        PermitEmptyPasswords - ${sshd_permit_empty_passwords}"
    echo -e "        LoginGraceTime - ${sshd_login_grace_status}"
    echo -e "        LogLevel - ${sshd_loglevel}"
    echo -e "        ClientAliveInterval - ${sshd_client_alive_interval}"
    echo -e "        ClientAliveCountMax - ${sshd_client_alive_count_max}"
    echo -e "        GSSAPIAuthentication - ${sshd_gssapi}"
    echo -e "        KerberosAuthentication - ${sshd_kerberos}"
    echo -e "        UseDNS - ${sshd_dns}"
    echo -e "  - Fail2Ban Installation: ${fail2ban_status}"
    if [[ -n "$ssh_key_url" ]]; then
        echo -e "  - Public Key Addition: ${ssh_key_status}"
    fi
    if [[ "${need_restart_sshd}" == "yes" ]]; then
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
