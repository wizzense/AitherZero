#!/bin/bash
#
# AitherZero Modern Bootstrap Script v4.0 for Linux/macOS
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.sh | bash
#   wget -qO- https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.sh | bash
#
# This script ensures PowerShell 7+ is used and directly invokes the main
# Start-AitherZero.ps1 script from the repository.
#

set -e

# --- Colors for Output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- Helper Functions ---
print_message() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

error_exit() {
    print_message "$RED" "❌ ERROR: $1"
    exit 1
}

# --- Prerequisite Check ---
check_prerequisites() {
    print_message "$CYAN" "🔍 Checking for PowerShell..."

    if ! command -v pwsh &> /dev/null; then
        error_exit "PowerShell (pwsh) not found. Please install PowerShell 7+ from https://aka.ms/powershell"
    fi

    print_message "$GREEN" "✅ PowerShell is available."
}

# --- Main Execution ---
main() {
    print_message "$CYAN" "🚀 AitherZero Modern Bootstrap for Linux/macOS v4.0"
    print_message "$CYAN" "==================================================="
    echo

    check_prerequisites

    print_message "$YELLOW" "⬇️  Downloading and executing the AitherZero start script..."

    # Determine the downloader
    if command -v curl &> /dev/null; then
        DOWNLOADER="curl -sSL"
    elif command -v wget &> /dev/null; then
        DOWNLOADER="wget -qO-"
    else
        error_exit "Neither curl nor wget found. Please install one and try again."
    fi

    # Construct the URL to the main bootstrap script
    START_SCRIPT_URL="https://raw.githubusercontent.com/wizzense/AitherZero/main/Start-AitherZero.ps1"

    # Download and execute the script via pwsh
    # The script is piped directly into pwsh for execution.
    # All command-line arguments passed to this bootstrap.sh script ($@) are forwarded.
    if ! $DOWNLOADER "$START_SCRIPT_URL" | pwsh -NoProfile -ExecutionPolicy Bypass -Command "-"; then
        error_exit "AitherZero script failed to execute."
    fi

    print_message "$GREEN" "✅ AitherZero bootstrap process completed."
}

# --- Error Handling and Execution ---
trap 'error_exit "An unexpected error occurred. Please check your network and permissions."' ERR

main "$@"
