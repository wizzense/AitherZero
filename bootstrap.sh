#!/bin/bash
#
# AitherZero Bootstrap Script for Linux/macOS
# 
# Usage:
#   curl -sSL https://raw.githubusercontent.com/yourusername/AitherZero/main/bootstrap.sh | bash
#   wget -qO- https://raw.githubusercontent.com/yourusername/AitherZero/main/bootstrap.sh | bash
#
# Environment Variables:
#   AITHERZERO_PROFILE=minimal|standard|developer|full (default: standard)
#   AITHERZERO_INSTALL_DIR=/custom/path (default: $HOME/.aitherzero)
#   AITHERZERO_BRANCH=main|develop (default: main)
#   AITHERZERO_AUTO_START=true|false (default: true)
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
REPO_OWNER="yourusername"
REPO_NAME="AitherZero"
GITHUB_URL="https://github.com/$REPO_OWNER/$REPO_NAME"

# Functions
print_log() {
    local level=$1
    local message=$2
    case $level in
        "ERROR") echo -e "${RED}[-] $message${NC}" ;;
        "SUCCESS") echo -e "${GREEN}[+] $message${NC}" ;;
        "WARNING") echo -e "${YELLOW}[!] $message${NC}" ;;
        "INFO") echo -e "${CYAN}[*] $message${NC}" ;;
    esac
}

error_exit() {
    print_log "ERROR" "$1"
    exit 1
}

# Check and install PowerShell 7
install_powershell() {
    if command -v pwsh &> /dev/null; then
        print_log "SUCCESS" "PowerShell 7 already installed"
        return 0
    fi
    
    print_log "INFO" "Installing PowerShell 7..."
    
    case "$(uname -s)" in
        Linux*)
            # Detect Linux distribution
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                case "$ID" in
                    ubuntu|debian)
                        # Install PowerShell on Ubuntu/Debian
                        sudo apt-get update
                        sudo apt-get install -y wget apt-transport-https software-properties-common
                        wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"
                        sudo dpkg -i packages-microsoft-prod.deb
                        sudo apt-get update
                        sudo apt-get install -y powershell
                        rm packages-microsoft-prod.deb
                        ;;
                    rhel|centos|fedora)
                        # Install PowerShell on RHEL/CentOS/Fedora
                        curl https://packages.microsoft.com/config/rhel/7/prod.repo | sudo tee /etc/yum.repos.d/microsoft.repo
                        sudo yum install -y powershell
                        ;;
                    *)
                        # Generic installation using Microsoft script
                        wget -q https://aka.ms/install-powershell.sh -O install-powershell.sh
                        chmod +x install-powershell.sh
                        sudo ./install-powershell.sh
                        rm install-powershell.sh
                        ;;
                esac
            else
                error_exit "Cannot determine Linux distribution"
            fi
            ;;
        Darwin*)
            # Install PowerShell on macOS
            if command -v brew &> /dev/null; then
                brew install --cask powershell
            else
                print_log "WARNING" "Homebrew not found. Installing Homebrew first..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                brew install --cask powershell
            fi
            ;;
        *)
            error_exit "Unsupported platform: $(uname -s)"
            ;;
    esac

    # Verify installation
    if command -v pwsh &> /dev/null; then
        print_log "SUCCESS" "PowerShell 7 installed successfully"
    else
        error_exit "PowerShell 7 installation failed"
    fi
}

# Check and install Git
install_git() {
    if command -v git &> /dev/null; then
        print_log "SUCCESS" "Git already installed"
        return 0
    fi
    
    print_log "INFO" "Installing Git..."
    
    case "$(uname -s)" in
        Linux*)
            if command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y git
            elif command -v yum &> /dev/null; then
                sudo yum install -y git
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y git
            else
                error_exit "Cannot determine package manager"
            fi
            ;;
        Darwin*)
            if command -v brew &> /dev/null; then
                brew install git
            else
                error_exit "Please install Xcode Command Line Tools: xcode-select --install"
            fi
            ;;
    esac

    if command -v git &> /dev/null; then
        print_log "SUCCESS" "Git installed successfully"
    else
        error_exit "Git installation failed"
    fi
}

# Main installation
main() {
    print_log "INFO" "AitherZero Bootstrap for Linux/macOS"
    echo "===================================="
    echo

    # Set defaults
    PROFILE="${AITHERZERO_PROFILE:-standard}"
    INSTALL_DIR="${AITHERZERO_INSTALL_DIR:-$HOME/.aitherzero}"
    BRANCH="${AITHERZERO_BRANCH:-main}"
    AUTO_START="${AITHERZERO_AUTO_START:-true}"
    
    print_log "INFO" "Profile: $PROFILE"
    print_log "INFO" "Install directory: $INSTALL_DIR"
    print_log "INFO" "Branch: $BRANCH"

    # Check and install dependencies
    install_git
    install_powershell

    # Clone or update repository
    if [ -d "$INSTALL_DIR/.git" ]; then
        print_log "INFO" "Updating existing installation..."
        cd "$INSTALL_DIR"
        git pull origin "$BRANCH"
    else
        print_log "INFO" "Cloning AitherZero repository..."
        git clone --branch "$BRANCH" "$GITHUB_URL" "$INSTALL_DIR"
        cd "$INSTALL_DIR"
    fi

    # Make scripts executable
    chmod +x *.ps1 2>/dev/null || true

    # Run PowerShell bootstrap
    print_log "INFO" "Running PowerShell bootstrap..."
    pwsh -NoProfile -ExecutionPolicy Bypass -File ./bootstrap.ps1 \
        -Mode New \
        -InstallProfile "$PROFILE" \
        -NonInteractive \
        -SkipAutoStart:$([ "$AUTO_START" = "false" ] && echo "true" || echo "false")

    if [ "$AUTO_START" = "true" ]; then
        print_log "SUCCESS" "AitherZero installed and started!"
    else
        print_log "SUCCESS" "AitherZero installed successfully!"
        echo
        print_log "INFO" "To start AitherZero:"
        echo "  cd $INSTALL_DIR"
        echo "  pwsh ./Start-AitherZero.ps1"
    fi
}

# Run main
main "$@"