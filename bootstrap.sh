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
                        # Modern Ubuntu/Debian installation method
                        print_log "INFO" "Installing PowerShell via Microsoft repository..."
                        
                        # Update package list and install prerequisites
                        sudo apt-get update || error_exit "Failed to update package list"
                        sudo apt-get install -y wget apt-transport-https software-properties-common curl || error_exit "Failed to install prerequisites"
                        
                        # Get Ubuntu version for correct repository
                        UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "20.04")
                        
                        # Download and install Microsoft signing key and repository
                        if ! wget -q "https://packages.microsoft.com/config/ubuntu/${UBUNTU_VERSION}/packages-microsoft-prod.deb" -O packages-microsoft-prod.deb; then
                            print_log "WARNING" "Failed to download specific Ubuntu repository, trying generic method..."
                            install_powershell_generic
                            return $?
                        fi
                        
                        sudo dpkg -i packages-microsoft-prod.deb || error_exit "Failed to install Microsoft repository"
                        sudo apt-get update || error_exit "Failed to update package list after adding Microsoft repository"
                        sudo apt-get install -y powershell || {
                            print_log "WARNING" "Package installation failed, trying generic method..."
                            rm -f packages-microsoft-prod.deb
                            install_powershell_generic
                            return $?
                        }
                        rm -f packages-microsoft-prod.deb
                        ;;
                    rhel|centos|rocky|almalinux)
                        # RHEL/CentOS/Rocky/AlmaLinux installation
                        print_log "INFO" "Installing PowerShell for RHEL-based distribution..."
                        
                        # Determine version number for repository URL
                        VERSION_ID=$(echo "$VERSION_ID" | cut -d. -f1)
                        
                        if command -v dnf &> /dev/null; then
                            # Use dnf for modern RHEL/CentOS
                            curl -sSL "https://packages.microsoft.com/config/rhel/${VERSION_ID}/prod.repo" | sudo tee /etc/yum.repos.d/microsoft.repo > /dev/null || {
                                print_log "WARNING" "Failed to add Microsoft repository, trying generic method..."
                                install_powershell_generic
                                return $?
                            }
                            sudo dnf install -y powershell || {
                                print_log "WARNING" "Package installation failed, trying generic method..."
                                install_powershell_generic
                                return $?
                            }
                        elif command -v yum &> /dev/null; then
                            # Use yum for older systems
                            curl -sSL "https://packages.microsoft.com/config/rhel/${VERSION_ID}/prod.repo" | sudo tee /etc/yum.repos.d/microsoft.repo > /dev/null || {
                                print_log "WARNING" "Failed to add Microsoft repository, trying generic method..."
                                install_powershell_generic
                                return $?
                            }
                            sudo yum install -y powershell || {
                                print_log "WARNING" "Package installation failed, trying generic method..."
                                install_powershell_generic
                                return $?
                            }
                        else
                            error_exit "No suitable package manager found (dnf or yum)"
                        fi
                        ;;
                    fedora)
                        # Fedora installation
                        print_log "INFO" "Installing PowerShell for Fedora..."
                        curl -sSL "https://packages.microsoft.com/config/rhel/8/prod.repo" | sudo tee /etc/yum.repos.d/microsoft.repo > /dev/null || {
                            print_log "WARNING" "Failed to add Microsoft repository, trying generic method..."
                            install_powershell_generic
                            return $?
                        }
                        sudo dnf install -y powershell || {
                            print_log "WARNING" "Package installation failed, trying generic method..."
                            install_powershell_generic
                            return $?
                        }
                        ;;
                    opensuse*|sles)
                        # openSUSE/SLES installation
                        print_log "INFO" "Installing PowerShell for openSUSE/SLES..."
                        sudo zypper refresh || error_exit "Failed to refresh repositories"
                        sudo zypper install -y curl || error_exit "Failed to install curl"
                        install_powershell_generic
                        ;;
                    arch|manjaro)
                        # Arch Linux installation
                        print_log "INFO" "Installing PowerShell for Arch Linux..."
                        if command -v yay &> /dev/null; then
                            yay -S --noconfirm powershell-bin || install_powershell_generic
                        elif command -v paru &> /dev/null; then
                            paru -S --noconfirm powershell-bin || install_powershell_generic
                        else
                            install_powershell_generic
                        fi
                        ;;
                    *)
                        # Unknown distribution - use generic method
                        print_log "INFO" "Unknown Linux distribution '$ID', using generic installation method..."
                        install_powershell_generic
                        ;;
                esac
            else
                print_log "WARNING" "Cannot determine Linux distribution, using generic installation method..."
                install_powershell_generic
            fi
            ;;
        Darwin*)
            # Install PowerShell on macOS
            print_log "INFO" "Installing PowerShell for macOS..."
            if command -v brew &> /dev/null; then
                brew install --cask powershell || {
                    print_log "WARNING" "Homebrew installation failed, trying generic method..."
                    install_powershell_generic
                }
            else
                print_log "INFO" "Homebrew not found. Installing Homebrew first..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || error_exit "Failed to install Homebrew"
                
                # Add Homebrew to PATH for this session
                if [ -f "/opt/homebrew/bin/brew" ]; then
                    export PATH="/opt/homebrew/bin:$PATH"
                elif [ -f "/usr/local/bin/brew" ]; then
                    export PATH="/usr/local/bin:$PATH"
                fi
                
                brew install --cask powershell || {
                    print_log "WARNING" "Homebrew installation failed, trying generic method..."
                    install_powershell_generic
                }
            fi
            ;;
        *)
            error_exit "Unsupported platform: $(uname -s)"
            ;;
    esac

    # Verify installation
    if command -v pwsh &> /dev/null; then
        print_log "SUCCESS" "PowerShell 7 installed successfully"
        pwsh -Version || print_log "WARNING" "PowerShell installed but version check failed"
    else
        error_exit "PowerShell 7 installation failed - pwsh command not found"
    fi
}

# Generic PowerShell installation using Microsoft's official script
install_powershell_generic() {
    print_log "INFO" "Using Microsoft's generic PowerShell installation script..."
    
    # Download and run the official PowerShell installation script
    if command -v curl &> /dev/null; then
        curl -sSL https://aka.ms/install-powershell.sh -o install-powershell.sh || error_exit "Failed to download PowerShell installation script"
    elif command -v wget &> /dev/null; then
        wget -q https://aka.ms/install-powershell.sh -O install-powershell.sh || error_exit "Failed to download PowerShell installation script"
    else
        error_exit "Neither curl nor wget found - cannot download PowerShell installation script"
    fi
    
    chmod +x install-powershell.sh || error_exit "Failed to make installation script executable"
    
    # Run the installation script with error handling
    if sudo ./install-powershell.sh; then
        print_log "SUCCESS" "PowerShell installed using generic method"
    else
        print_log "ERROR" "Generic PowerShell installation failed"
        rm -f install-powershell.sh
        return 1
    fi
    
    rm -f install-powershell.sh
    return 0
}

# Check and install Git
install_git() {
    if command -v git &> /dev/null; then
        print_log "SUCCESS" "Git already installed"
        git --version | head -n1 | print_log "INFO" || true
        return 0
    fi
    
    print_log "INFO" "Installing Git..."
    
    case "$(uname -s)" in
        Linux*)
            # Detect Linux distribution for proper Git installation
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                case "$ID" in
                    ubuntu|debian)
                        sudo apt-get update || error_exit "Failed to update package list"
                        sudo apt-get install -y git || error_exit "Failed to install Git via apt"
                        ;;
                    rhel|centos|rocky|almalinux)
                        if command -v dnf &> /dev/null; then
                            sudo dnf install -y git || error_exit "Failed to install Git via dnf"
                        elif command -v yum &> /dev/null; then
                            sudo yum install -y git || error_exit "Failed to install Git via yum"
                        else
                            error_exit "No suitable package manager found for RHEL-based system"
                        fi
                        ;;
                    fedora)
                        sudo dnf install -y git || error_exit "Failed to install Git via dnf"
                        ;;
                    opensuse*|sles)
                        sudo zypper refresh || error_exit "Failed to refresh repositories"
                        sudo zypper install -y git || error_exit "Failed to install Git via zypper"
                        ;;
                    arch|manjaro)
                        sudo pacman -Sy --noconfirm git || error_exit "Failed to install Git via pacman"
                        ;;
                    alpine)
                        sudo apk update || error_exit "Failed to update package list"
                        sudo apk add git || error_exit "Failed to install Git via apk"
                        ;;
                    *)
                        # Try common package managers
                        if command -v apt-get &> /dev/null; then
                            sudo apt-get update && sudo apt-get install -y git
                        elif command -v dnf &> /dev/null; then
                            sudo dnf install -y git
                        elif command -v yum &> /dev/null; then
                            sudo yum install -y git
                        elif command -v zypper &> /dev/null; then
                            sudo zypper install -y git
                        elif command -v pacman &> /dev/null; then
                            sudo pacman -Sy --noconfirm git
                        elif command -v apk &> /dev/null; then
                            sudo apk add git
                        else
                            error_exit "Cannot determine package manager for distribution: $ID"
                        fi
                        ;;
                esac
            else
                # Generic Linux - try common package managers
                print_log "WARNING" "Cannot determine Linux distribution, trying common package managers..."
                if command -v apt-get &> /dev/null; then
                    sudo apt-get update && sudo apt-get install -y git
                elif command -v dnf &> /dev/null; then
                    sudo dnf install -y git
                elif command -v yum &> /dev/null; then
                    sudo yum install -y git
                elif command -v zypper &> /dev/null; then
                    sudo zypper install -y git
                elif command -v pacman &> /dev/null; then
                    sudo pacman -Sy --noconfirm git
                elif command -v apk &> /dev/null; then
                    sudo apk add git
                else
                    error_exit "No suitable package manager found"
                fi
            fi
            ;;
        Darwin*)
            # macOS Git installation
            if command -v brew &> /dev/null; then
                brew install git || error_exit "Failed to install Git via Homebrew"
            elif command -v port &> /dev/null; then
                sudo port install git || error_exit "Failed to install Git via MacPorts"
            else
                print_log "INFO" "No package manager found. Attempting to install Xcode Command Line Tools..."
                xcode-select --install 2>/dev/null || {
                    print_log "ERROR" "Please install Xcode Command Line Tools manually:"
                    print_log "ERROR" "  xcode-select --install"
                    print_log "ERROR" "Or install Homebrew and run this script again"
                    error_exit "Git installation failed - no package manager available"
                }
                print_log "INFO" "Xcode Command Line Tools installation initiated."
                print_log "INFO" "Please complete the installation and run this script again."
                exit 0
            fi
            ;;
        *)
            error_exit "Unsupported operating system: $(uname -s)"
            ;;
    esac

    # Verify Git installation
    if command -v git &> /dev/null; then
        print_log "SUCCESS" "Git installed successfully"
        git --version | print_log "INFO"
    else
        error_exit "Git installation failed - git command not found"
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
    
    # Detect problematic terminals and enable simple menu mode for better compatibility
    # This helps with Android terminals, Termux, and other limited environments
    if [ -n "$PREFIX" ] && echo "$PREFIX" | grep -q "termux"; then
        # Termux/Android terminal detected
        export AITHERZERO_SIMPLE_MENU="1"
        print_log "INFO" "Detected Termux/Android terminal - enabling simple menu mode"
    elif [ "$TERM" = "linux" ] || [ "$TERM" = "dumb" ] || [ "$TERM" = "unknown" ]; then
        # Basic Linux console or limited terminal
        export AITHERZERO_SIMPLE_MENU="1"
        print_log "INFO" "Detected basic terminal - enabling simple menu mode"
    fi
    
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
        
        # Pre-installation dependency check
        print_log "INFO" "Checking system requirements..."
        MISSING_DEPS=""
        
        if ! command -v git &> /dev/null; then
            MISSING_DEPS="$MISSING_DEPS git"
        fi
        
        if ! command -v pwsh &> /dev/null; then
            MISSING_DEPS="$MISSING_DEPS PowerShell"
        fi
        
        if [ -n "$MISSING_DEPS" ]; then
            print_log "WARNING" "Missing dependencies:$MISSING_DEPS"
            print_log "INFO" "Will attempt to install missing dependencies automatically..."
        else
            print_log "SUCCESS" "All required dependencies are already installed"
        fi
        
        # Check and install dependencies with better error handling
        print_log "INFO" "Checking and installing required dependencies..."
        
        # Check for sudo access early
        if ! sudo -n true 2>/dev/null; then
            print_log "WARNING" "This script requires sudo access to install dependencies"
            print_log "INFO" "You may be prompted for your password during installation"
        fi
        
        # Install dependencies
        if ! install_git; then
            error_exit "Failed to install Git - this is required for AitherZero"
        fi
        
        if ! install_powershell; then
            error_exit "Failed to install PowerShell 7 - this is required for AitherZero"
        fi
        
        # Verify both dependencies are working
        print_log "INFO" "Verifying installed dependencies..."
        git --version >/dev/null 2>&1 || error_exit "Git installation verification failed"
        pwsh -Version >/dev/null 2>&1 || error_exit "PowerShell installation verification failed"
        print_log "SUCCESS" "All dependencies verified and working"
        
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