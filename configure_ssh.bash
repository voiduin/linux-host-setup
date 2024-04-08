#!/bin/bash

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

# Example of running a script with parameters
run_rscript sshd_configure Port 2221

echo "Config ended"
