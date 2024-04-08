#!/bin/bash

# Set bash execution flags:
# - Treat unset variables as an error when substituting
# - Exit immediately if a command exits with a non-zero status
# - Print each command to stdout before executing it (useful for debugging)
set -u
# set -e
# set -x

# Base URL of the repository
REPO_URL="https://raw.githubusercontent.com/voiduin/linux-host-setup/main"

# Function to download and execute a remote script with parameters "run_remote_script"
run_rscript () {
    script="${1}"
    shift  # Remove script name from the parameters list
    params=("$@")  # Remaining arguments are parameters for the script

    echo "Load and run ${script} with parameters: ${params[*]}..."
    curl -Ls "$REPO_URL/${script}.bash" | sudo bash -s -- "${params[@]}"
}

# Usage example: create_backup_for_file "/etc/ssh/sshd_config"
create_backup_for_file() {
    local file_path="$1"
    local backup_dir="${2:-$(dirname "$file_path")}"
    local old_filename="$(basename -- "$file_path")"
    local backup_path="${backup_dir}/${old_filename}.$(date +%y%m%d_%H%M%Sms).bac"
    cp "$file_path" "$backup_path" || exit_with_err "Failed to create backup file: $backup_path."
    echo "Backup created: $backup_path"
}

main() {
    local config_file_path="/etc/ssh/sshd_config"

    # Create new user
    # TODO:this

    # Configure SSH config file
    create_backup_for_file "${config_file_path}"
    run_rscript sshd_configure Port 2221
   
    # Install fail2ban
    # TODO:this

    echo "Config ended"
}

main "$@"
