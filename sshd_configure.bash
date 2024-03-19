#!/bin/bash

# Usage example: show_usage
show_usage() {
    echo "= = Usage = ="
    echo "    Directly in CLI:"
    echo "        $0 [new_ssh_port]"
    echo "        Example: $0 2222"
    echo "    From WEB:"
    echo "        To run the script from the internet use:"
    echo "        curl:"
    echo "            curl -Ls https://raw.githubusercontent.com/voiduin/sshd-set-port/main/sshd_configure.bash | sudo bash -s [PORT]"
    echo "        wget:"
    echo "            wget -qO - https://raw.githubusercontent.com/voiduin/sshd-set-port/main/sshd_configure.bash | sudo bash -s [PORT]"
    echo -e "\n"
    echo "Requirements:"
    echo "    - Run as root"
    echo -e "\n"
    echo "Config file requirements:"
    echo "    - The file must contain one active or commented 'Port' line"
    echo -e "\n"
    echo "Script created by \"Voiduin\""
    echo "Source available at https://github.com/voiduin/sshd-set-port"
}

# Usage example: exit_with_err "Error message"
exit_with_err() {
    local message="$1"
    echo "Error: $message"
    echo -e "\n"
    show_usage
    exit 1
}


# Usage example: check_root_privileges
check_root_privileges() {
    if [[ $EUID -ne 0 ]]; then
        exit_with_err "This script must be run as root"
    fi
}

# Usage example: check_file_exists "/path/to/file"
check_file_exists() {
    local file_path="$1"
    if [[ ! -f "$file_path" ]]; then
        exit_with_err "The specified file does not exist: $file_path"
    fi
}

# Check SSHD configuration for a specified setting
#   check_sshd_config_setting <!config_file!> <!setting_name!>
# Usage example:
#   check_sshd_config_setting "/etc/ssh/sshd_config" "Port"
check_sshd_config_setting() {
    local config_file="$1"
    local setting_name="$2"

    # Find active setting lines and their line numbers.
    # This line must catch incorrect lines, e.g., lines with non-digit value:
    #     Port new_port # Changed by root on 2024-03-18, 12:24:41
    local setting_lines_info=$(grep -nE "^[[:blank:]]*${setting_name}[[:blank:]]" "${config_file}")

    # Count the number of active setting lines
    # Calculate active lines only if 'setting_lines_info' is not empty
    local active_lines
    if [[ -n "${setting_lines_info}" ]]; then
        active_lines=$(echo "${setting_lines_info}" | wc -l)
    else
        active_lines=0
    fi

    if [[ $active_lines -eq 1 ]]; then
        # OK
        local line_info=$(echo "$setting_lines_info" | awk -F ":" '{printf "%s\n%s\n", "    Line number " $1 ":", "        "$2}')
        echo "One active '$setting_name' line found in \"$config_file\":"
        echo "$line_info"
    elif [[ $active_lines -gt 1 ]]; then
        # ERR
        echo "Multiple active '$setting_name' lines found in \"$config_file\":"
        echo "$setting_lines_info" | awk -F ":" '{printf "%s\n%s\n", "    Line number " $1 ":", "        "$2}'
        exit_with_err "Multiple active '$setting_name' lines found. Please clean up the file."
    else
        echo "No active '$setting_name' line found in \"$config_file\". A new one will be added."
    fi
}

# Usage example: new_port=$(get_new_port_val "$@")
get_new_port_val() {
    if [[ $# -gt 1 ]]; then
        exit_with_err "Too many arguments. Please provide only one argument for the port or none."
    fi

    local new_port="$1"
    if [[ -z "$new_port" ]]; then
        read -p "Enter new SSH port number between [1024 and 65535].: " new_port
    fi

    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1024 ] || [ "$new_port" -gt 65535 ]; then
        exit_with_err "Invalid port number: $new_port. Please specify a number between 1024 and 65535."
    fi
    echo "$new_port"
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

# Usage example: set_new_sshd_port "/etc/ssh/sshd_config" 2222
set_new_sshd_port() {
    local config_file="$1"
    local new_port="$2"

    local modifying_user="${SUDO_USER:-$(whoami)}"
    # Time delimiter set as "-" for easy AWK processing of "grep -n" output, which has the line number format "256:<string_value>"
    local modifying_time="$(date +'%Y-%m-%d, %H-%M-%S')"
    local original_line_val=$(grep -nE '^[[:blank:]]*Port[[:blank:]]+[0-9]+' "$config_file")
    local original_line_number=$(echo "$original_line_val" | cut -d':' -f1)
    local original_port=$(echo "$original_line_val" | grep -Po '(?<=Port\s)\d+')

    if [[ ! -z "${original_line_number}" ]]; then
        sed -i "${original_line_number}s/.*/Port $new_port # Changed by script on ${modifying_time} by user \"${modifying_user}\"/" "$config_file"
        echo "SSH port changed to $new_port on line ${original_line_number} in $config_file."
    else
        echo "Port $new_port # Added by script on $(date +%Y-%m-%d) by $modifying_user" >> "$config_file"
        echo "SSH port added to $new_port in $config_file."
    fi
}

main() {
    local config_file_path="/etc/ssh/sshd_config"
    local new_port

    check_root_privileges
    check_file_exists "${config_file_path}"
    check_sshd_config_setting "${config_file_path}" "Port"
    new_port=$(get_new_port_val "$@")
    create_backup_for_file "$config_file_path"
    set_new_sshd_port "$config_file_path" "$new_port"
}

main "$@"
