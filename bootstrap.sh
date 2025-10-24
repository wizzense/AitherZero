#!/bin/bash
#
# AitherZero Bootstrap Script for Linux/macOS
# Intelligently detects whether to install or just initialize
# 
# Usage:
#   curl -sSL https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.sh | bash
#   wget -qO- https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.sh | bash
#
# Environment Variables:
#   AITHERZERO_PROFILE=minimal|standard|developer|full (default: standard)
#   AITHERZERO_INSTALL_DIR=/custom/path (default: ./AitherZero or current dir if in project)
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
REPO_OWNER="wizzense"
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

# Clean environment
clean_environment() {
    print_log "INFO" "Cleaning environment..."
    
    # Remove conflicting environment variables
    unset AITHERIUM_ROOT
    unset AITHERRUN_ROOT
    unset COREAPP_ROOT
    unset AITHER_CORE_PATH
    unset PWSH_MODULES_PATH
    
    # Set AitherZero environment
    export AITHERZERO_ROOT="$PWD"
    export DISABLE_COREAPP="1"
    export SKIP_AUTO_MODULES="1"
    export AITHERZERO_ONLY="1"
    
    print_log "SUCCESS" "Environment cleaned"
}

# Initialize AitherZero modules
initialize_modules() {
    print_log "INFO" "Initializing AitherZero modules..."
    
    # Run PowerShell bootstrap which handles initialization
    pwsh -NoProfile -ExecutionPolicy Bypass -File ./bootstrap.ps1 \
        -InstallProfile "$PROFILE" \
        -NonInteractive \
        $([ "$AUTO_START" = "false" ] && echo "-SkipAutoStart" || echo "")
    
    print_log "SUCCESS" "Modules initialized"
}

# Check if in AitherZero project
is_aitherzero_project() {
    [ -f "./Start-AitherZero.ps1" ] && [ -d "./domains" ] && [ -f "./AitherZero.psd1" ]
}

# Main installation
main() {
    # Clear screen if clear command is available, otherwise use printf
    if command -v clear &> /dev/null; then
        clear
    else
        printf '\033[2J\033[H'
    fi
    cat << "EOF"
    _    _ _   _               ______               
   / \  (_) |_| |__   ___ _ _|__  /___ _ __ ___  
  / _ \ | | __| '_ \ / _ \ '__/ // _ \ '__/ _ \ 
 / ___ \| | |_| | | |  __/ | / /|  __/ | | (_) |
/_/   \_\_|\__|_| |_|\___|_|/____\___|_|  \___/ 
                                                 
        Infrastructure Automation Platform
        
EOF

    # Set defaults
    PROFILE="${AITHERZERO_PROFILE:-standard}"
    BRANCH="${AITHERZERO_BRANCH:-main}"
    AUTO_START="${AITHERZERO_AUTO_START:-true}"
    
    # Intelligent detection
    if is_aitherzero_project; then
        # Already in an AitherZero project
        print_log "INFO" "Detected existing AitherZero project at: $PWD"
        INSTALL_DIR="$PWD"
        
        # Check if modules are loaded
        if [ -n "$AITHERZERO_INITIALIZED" ]; then
            print_log "INFO" "Environment already initialized - refreshing..."
        fi
        
        # Clean environment and initialize
        clean_environment
        initialize_modules
    else
        # Not in a project, need to install
        INSTALL_DIR="${AITHERZERO_INSTALL_DIR:-./AitherZero}"

        print_log "INFO" "Installing AitherZero to: $INSTALL_DIR"
        print_log "INFO" "Profile: $PROFILE"
        print_log "INFO" "Branch: $BRANCH"
        
        # Check and install dependencies
        install_git
        install_powershell
        
        # Clone or update repository
        if [ -d "$INSTALL_DIR/.git" ]; then
            print_log "INFO" "Updating existing installation..."
            cd "$INSTALL_DIR"
            git pull origin "$BRANCH"
        elif [ -d "$INSTALL_DIR" ]; then
            # Directory exists but not a git repo
            print_log "WARNING" "Directory exists at $INSTALL_DIR but is not a git repository"
            read -p "Overwrite? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm -rf "$INSTALL_DIR"
                git clone --branch "$BRANCH" "$GITHUB_URL" "$INSTALL_DIR"
                cd "$INSTALL_DIR"
            else
                print_log "INFO" "Installation cancelled"
                exit 0
            fi
        else
            print_log "INFO" "Cloning AitherZero repository..."
            git clone --branch "$BRANCH" "$GITHUB_URL" "$INSTALL_DIR"
            cd "$INSTALL_DIR"
        fi
        
        # Make scripts executable
        chmod +x *.ps1 2>/dev/null || true
        chmod +x *.sh 2>/dev/null || true
        
        # Clean environment and initialize
        clean_environment
        initialize_modules
    fi

    if [ "$AUTO_START" = "true" ]; then
        print_log "INFO" "Starting AitherZero..."
        pwsh -NoProfile -File ./Start-AitherZero.ps1
    else
        print_log "SUCCESS" "AitherZero ready!"
        echo
        print_log "INFO" "Available commands:"
        echo "  az <number>     - Run automation script"
        echo "  ./Start-AitherZero.ps1 - Launch interactive UI"
        echo
        print_log "INFO" "To start AitherZero:"
        echo "  cd $INSTALL_DIR"
        echo "  ./Start-AitherZero.ps1"
    fi
}

# Run main
main "$@"