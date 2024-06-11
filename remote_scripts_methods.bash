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

# Function to source and execute a remote script directly in the current shell environment
# source remote script -> source_rscript
# Usage:
#   1. Set environment variable:
#      export RSCRIPT_BASE_URL="https://raw.githubusercontent.com/voiduin/linux-host-setup/main"
#   2. Use source_rscript script_path
#      Example: source_rscript setup.sh
source_rscript() {
    local script_url="${1}"

    # Get base repo URL from environment variable
    local base_url_rawrepo="${RSCRIPT_BASE_URL}"
    if [[ -z "$base_url_rawrepo" ]]; then
        echo "Error: RSCRIPT_BASE_URL is not set. Please set it before running this function." >&2
        return 1
    fi

    # Read remote script content
    local full_script_url="${base_url_rawrepo}/${script_path}"
    local script_content=$(curl -Ls --fail "${full_script_url}")
    local status=$?
    if [[ "$status" -ne 0 ]]; then
        echo -e "       ${RED}Error${NC}: Failed to read the remote script"  >&2
        echo "              From: \"${base_url_rawrepo}/${script_path}\""  >&2
        echo "              Curl exit status: \"${status}\"" >&2
        return "${status}"
    fi

    # Source this script content into current shell
    source <(echo -n "${script_content}")
}


# Function to read and execute a remote script with optional sudo and parameters
# run remote script -> run_rscript
# Usage:
#   1. Set environment variable:
#      export RSCRIPT_BASE_URL="https://raw.githubusercontent.com/voiduin/linux-host-setup/main"
#   2. Use run_rscript script_path [--sudo] [--verbose] [params...]
#      Example: run_rscript setup.sh [--sudo] [--verbose] param1 param2
run_rscript () {
    local script_path="${1}"

    local use_sudo=0  # Default no sudo
    local verbose=0   # Default quiet
    local params=()   # Initialize params array
    
    # Process optional parameters --sudo and --verbose
    shift  # Remove script_path from the parameters list
    while (( "$#" )); do
        case "$1" in
            --sudo)
                use_sudo=1
                shift
                ;;
            --verbose)
                verbose=1
                shift
                ;;
            *) # Assume the rest are script parameters
                params+=("$1")
                shift
                ;;
        esac
    done

    # Get base repo URL from environment variable
    local base_url_rawrepo="${RSCRIPT_BASE_URL}"
    if [[ -z "$base_url_rawrepo" ]]; then
        echo "Error: RSCRIPT_BASE_URL is not set. Please set it before running this function." >&2
        return 1
    fi

    if [[ "${verbose}" -eq 1 ]]; then
        echo -e "  ${BLUE}RUN${NC}: Try load and run script \"${script_path}\":"
        echo "       From base repo url: \"${base_url_rawrepo}\""
        echo "       With parameters: ${params[*]}"
    fi

    # Read remote script content
    local full_script_url="${base_url_rawrepo}/${script_path}"
    local script_content=$(curl -Ls --fail "${full_script_url}")
    local status=$?
    if [[ "$status" -ne 0 ]]; then
        echo -e "       ${RED}Error${NC}: Failed to read the remote script"  >&2
        echo "              From: \"${base_url_rawrepo}/${script_path}\""  >&2
        echo "              Curl exit status: \"${status}\"" >&2
        return "${status}"
    fi

    if [[ "${verbose}" -eq 1 ]]; then
        echo -e "     Remote script read successfully"
    fi

    echo "     Try running readed script..."
    # Execute script
    if [[ "${use_sudo}" -eq 1 ]]; then
        echo "${script_content}" | sudo bash -s -- "${params[@]}"
    else
        echo "${script_content}" | bash -s -- "${params[@]}"
    fi
    status=$?

    if [[ "$status" -ne 0 ]]; then
        echo "Error: Script execution failed. Bash exit status: $status" >&2
        return "$status"
    fi

    # Separate from next terminal output
    echo -ne "\n"

    return "${status}"
}
