#!/bin/bash
#
# AitherZero Bootstrap Script v3.0 for Linux/macOS
# 
# Usage:
#   curl -sSL https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.sh | bash
#   wget -qO- https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.sh | bash
#
# Environment Variables for Automation:
#   AITHER_INSTALL_DIR=/custom/path (default: $HOME/AitherZero)
#   AITHER_AUTO_START=true|false (default: true)
#
# New in v3.0:
#   - Simplified: One package per platform, no profile selection
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Functions
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

error_exit() {
    print_message "$RED" "❌ Error: $1"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    print_message "$CYAN" "🔍 Checking prerequisites..."
    
    # Check for curl or wget
    if command -v curl &> /dev/null; then
        DOWNLOADER="curl -sSL"
        DOWNLOADER_OUTPUT="-o"
    elif command -v wget &> /dev/null; then
        DOWNLOADER="wget -q"
        DOWNLOADER_OUTPUT="-O"
    else
        error_exit "Neither curl nor wget found. Please install one of them."
    fi
    
    # Check for unzip or tar
    if command -v unzip &> /dev/null; then
        EXTRACTOR="unzip"
        ARCHIVE_EXT="zip"
    elif command -v tar &> /dev/null; then
        EXTRACTOR="tar"
        ARCHIVE_EXT="tar.gz"
    else
        error_exit "Neither unzip nor tar found. Please install one of them."
    fi
    
    # Check for PowerShell
    if command -v pwsh &> /dev/null; then
        PWSH_CMD="pwsh"
        print_message "$GREEN" "  ✓ PowerShell Core (pwsh) found"
    elif command -v powershell &> /dev/null; then
        PWSH_CMD="powershell"
        print_message "$GREEN" "  ✓ PowerShell found"
    else
        error_exit "PowerShell not found. Please install PowerShell Core: https://aka.ms/powershell"
    fi
}


# Get latest release info
get_latest_release() {
    print_message "$CYAN" "🚀 Getting latest AitherZero release..."
    
    # Get release info from GitHub API
    RELEASE_INFO=$($DOWNLOADER https://api.github.com/repos/wizzense/AitherZero/releases/latest 2>/dev/null)
    
    if [ -z "$RELEASE_INFO" ]; then
        error_exit "Failed to get latest release information"
    fi
    
    # Determine platform
    case "$(uname -s)" in
        Linux*)     PLATFORM="linux" ;;
        Darwin*)    PLATFORM="macos" ;;
        *)          error_exit "Unsupported platform: $(uname -s)" ;;
    esac
    
    # Find platform-specific package (format: AitherZero-v{version}-{platform}.tar.gz)
    ASSET_URL=$(echo "$RELEASE_INFO" | grep -o "https://[^\"]*AitherZero[^\"]*${PLATFORM}[^\"]*\.tar\.gz" | head -1)
    
    if [ -z "$ASSET_URL" ]; then
        error_exit "No ${PLATFORM} release package found"
    fi
    
    ASSET_NAME=$(basename "$ASSET_URL")
    print_message "$GREEN" "📦 Found release: $ASSET_NAME"
}

# Download and extract
download_and_extract() {
    print_message "$YELLOW" "⬇️  Downloading $ASSET_NAME..."
    
    # Create directory if it doesn't exist
    INSTALL_DIR="${AITHER_INSTALL_DIR:-$HOME/AitherZero}"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Download
    $DOWNLOADER "$ASSET_URL" $DOWNLOADER_OUTPUT "$ASSET_NAME"
    
    if [ ! -f "$ASSET_NAME" ]; then
        error_exit "Download failed"
    fi
    
    print_message "$YELLOW" "📂 Extracting..."
    
    # Create temp directory for extraction
    TEMP_DIR="aitherzero-temp-$$"
    mkdir -p "$TEMP_DIR"
    
    # Extract based on format
    if [ "$ARCHIVE_EXT" = "zip" ]; then
        unzip -q "$ASSET_NAME" -d "$TEMP_DIR"
    else
        tar -xzf "$ASSET_NAME" -C "$TEMP_DIR"
    fi
    
    # Find the extracted directory
    EXTRACTED_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "AitherZero*" | head -1)
    
    if [ -n "$EXTRACTED_DIR" ]; then
        # Move contents from extracted directory to current directory
        print_message "$YELLOW" "📁 Moving files to $INSTALL_DIR..."
        mv "$EXTRACTED_DIR"/* . 2>/dev/null || true
        mv "$EXTRACTED_DIR"/.* . 2>/dev/null || true
    else
        # No nested directory, move everything from temp
        mv "$TEMP_DIR"/* . 2>/dev/null || true
        mv "$TEMP_DIR"/.* . 2>/dev/null || true
    fi
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    rm -f "$ASSET_NAME"
    
    print_message "$GREEN" "✅ Extracted to: $INSTALL_DIR"
}

# Start AitherZero
start_aitherzero() {
    print_message "$CYAN" "🚀 Starting AitherZero..."
    
    cd "$INSTALL_DIR"
    
    # Make scripts executable
    chmod +x *.ps1 2>/dev/null || true
    chmod +x *.sh 2>/dev/null || true
    
    # Try different startup methods
    if [ -f "Start-AitherZero.ps1" ]; then
        if [ "${AITHER_AUTO_START:-true}" = "true" ]; then
            $PWSH_CMD -File "./Start-AitherZero.ps1"
        else
            print_message "$GREEN" "✅ AitherZero installed successfully!"
            print_message "$YELLOW" "💡 To start AitherZero, run:"
            print_message "$YELLOW" "   cd $INSTALL_DIR"
            print_message "$YELLOW" "   $PWSH_CMD ./Start-AitherZero.ps1"
        fi
    else
        print_message "$YELLOW" "⚠️  Start script not found. Please check installation."
    fi
}

# Main execution
main() {
    print_message "$CYAN" "🚀 AitherZero Bootstrap for Linux/macOS v3.0"
    print_message "$CYAN" "============================================="
    echo
    
    check_prerequisites
    get_latest_release
    download_and_extract
    start_aitherzero
}

# Handle errors
trap 'error_exit "Installation failed on line $LINENO"' ERR

# Run main function
main "$@"