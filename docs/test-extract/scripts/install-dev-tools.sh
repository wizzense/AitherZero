#!/bin/bash

# AitherZero Development Tools Installer - Unix Script
# Installs Git, GitHub CLI, Node.js/npm, Claude Code, and PowerShell 7
# Supports Linux and macOS

set -e  # Exit on any error

# Script configuration
SCRIPT_VERSION="1.0.0"
SCRIPT_NAME="AitherZero Dev Tools Installer"

# Default settings
FORCE_INSTALL=false
WHATIF_MODE=false
NODE_VERSION="lts"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${CYAN}🔧 $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo -e "${BLUE}📦 $1${NC}"
}

# Usage information
show_usage() {
    echo "$SCRIPT_NAME v$SCRIPT_VERSION"
    echo "Installs essential development tools on Linux and macOS"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --force       Force reinstallation even if tools exist"
    echo "  --whatif      Show what would be installed without making changes"
    echo "  --node-ver    Node.js version to install (default: lts)"
    echo "  --help        Show this help message"
    echo ""
    echo "Tools installed:"
    echo "  - Git (version control)"
    echo "  - GitHub CLI (gh command)"
    echo "  - Node.js and npm (JavaScript runtime and package manager)"
    echo "  - Claude Code (Anthropic AI CLI tool)"
    echo "  - PowerShell 7 (cross-platform shell)"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE_INSTALL=true
                shift
                ;;
            --whatif)
                WHATIF_MODE=true
                shift
                ;;
            --node-ver)
                NODE_VERSION="$2"
                shift 2
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            DISTRO=$ID
            VERSION=$VERSION_ID
        else
            DISTRO="unknown"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        DISTRO="macos"
        VERSION=$(sw_vers -productVersion)
    else
        log_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi

    log_info "Detected OS: $OS ($DISTRO $VERSION)"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if tool is already installed
check_existing_tool() {
    local tool=$1
    local version_flag=${2:-"--version"}

    if command_exists "$tool"; then
        local version=$($tool $version_flag 2>/dev/null || echo "unknown")
        if [[ "$FORCE_INSTALL" == "true" ]]; then
            log_warning "$tool is installed ($version) but will be reinstalled (--force)"
            return 1
        else
            log_success "$tool is already installed: $version"
            return 0
        fi
    fi
    return 1
}

# Install Git
install_git() {
    log_step "Installing Git"

    if check_existing_tool "git"; then
        return 0
    fi

    if [[ "$WHATIF_MODE" == "true" ]]; then
        log_info "[WHATIF] Would install Git"
        return 0
    fi

    case $OS in
        linux)
            case $DISTRO in
                ubuntu|debian)
                    sudo apt-get update
                    sudo apt-get install -y git
                    ;;
                fedora|centos|rhel)
                    if command_exists dnf; then
                        sudo dnf install -y git
                    else
                        sudo yum install -y git
                    fi
                    ;;
                arch)
                    sudo pacman -S --noconfirm git
                    ;;
                *)
                    log_error "Unsupported Linux distribution for Git installation: $DISTRO"
                    return 1
                    ;;
            esac
            ;;
        macos)
            if command_exists brew; then
                brew install git
            else
                log_error "Homebrew not found. Please install Homebrew first."
                return 1
            fi
            ;;
    esac

    if check_existing_tool "git"; then
        log_success "Git installed successfully"
    else
        log_error "Git installation failed"
        return 1
    fi
}

# Install GitHub CLI
install_github_cli() {
    log_step "Installing GitHub CLI"

    if check_existing_tool "gh"; then
        return 0
    fi

    if [[ "$WHATIF_MODE" == "true" ]]; then
        log_info "[WHATIF] Would install GitHub CLI"
        return 0
    fi

    case $OS in
        linux)
            case $DISTRO in
                ubuntu|debian)
                    # Install from GitHub's official repository
                    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
                    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
                    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
                    sudo apt-get update
                    sudo apt-get install -y gh
                    ;;
                fedora|centos|rhel)
                    if command_exists dnf; then
                        sudo dnf install -y 'dnf-command(config-manager)'
                        sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
                        sudo dnf install -y gh
                    else
                        sudo yum install -y yum-utils
                        sudo yum-config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
                        sudo yum install -y gh
                    fi
                    ;;
                arch)
                    sudo pacman -S --noconfirm github-cli
                    ;;
                *)
                    log_warning "Installing GitHub CLI via manual download for $DISTRO"
                    # Fallback to manual installation
                    local gh_version=$(curl -s https://api.github.com/repos/cli/cli/releases/latest | grep '"tag_name"' | cut -d'"' -f4 | sed 's/v//')
                    local download_url="https://github.com/cli/cli/releases/download/v${gh_version}/gh_${gh_version}_linux_amd64.tar.gz"

                    cd /tmp
                    curl -L "$download_url" -o gh.tar.gz
                    tar -xzf gh.tar.gz
                    sudo cp gh_${gh_version}_linux_amd64/bin/gh /usr/local/bin/
                    rm -rf gh.tar.gz gh_${gh_version}_linux_amd64
                    ;;
            esac
            ;;
        macos)
            if command_exists brew; then
                brew install gh
            else
                log_error "Homebrew not found. Please install Homebrew first."
                return 1
            fi
            ;;
    esac

    if check_existing_tool "gh"; then
        log_success "GitHub CLI installed successfully"
    else
        log_error "GitHub CLI installation failed"
        return 1
    fi
}

# Install Node.js and npm via nvm
install_nodejs() {
    log_step "Installing Node.js and npm"

    # Check if Node.js is already installed
    if command_exists node && command_exists npm && [[ "$FORCE_INSTALL" != "true" ]]; then
        local node_version=$(node --version)
        local npm_version=$(npm --version)
        log_success "Node.js already installed: $node_version, npm: $npm_version"
        return 0
    fi

    if [[ "$WHATIF_MODE" == "true" ]]; then
        log_info "[WHATIF] Would install Node.js $NODE_VERSION and npm via nvm"
        return 0
    fi

    # Install nvm if not present
    if [[ ! -d "$HOME/.nvm" ]] || [[ "$FORCE_INSTALL" == "true" ]]; then
        log_info "Installing nvm (Node Version Manager)"
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash

        # Source nvm
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    else
        log_info "nvm already installed, sourcing..."
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    fi

    # Install Node.js
    log_info "Installing Node.js $NODE_VERSION"
    nvm install "$NODE_VERSION"
    nvm use "$NODE_VERSION"
    nvm alias default "$NODE_VERSION"

    # Verify installation
    if command_exists node && command_exists npm; then
        local node_version=$(node --version)
        local npm_version=$(npm --version)
        log_success "Node.js and npm installed successfully: Node $node_version, npm $npm_version"
    else
        log_error "Node.js/npm installation failed"
        return 1
    fi
}

# Install Claude Code
install_claude_code() {
    log_step "Installing Claude Code"

    # Check if claude is already installed
    if command_exists claude && [[ "$FORCE_INSTALL" != "true" ]]; then
        local version=$(claude --version 2>/dev/null || echo "unknown")
        log_success "Claude Code already installed: $version"
        return 0
    fi

    if [[ "$WHATIF_MODE" == "true" ]]; then
        log_info "[WHATIF] Would install Claude Code via npm"
        return 0
    fi

    # Ensure we have npm
    if ! command_exists npm; then
        log_error "npm is required to install Claude Code. Please install Node.js first."
        return 1
    fi

    # Source nvm to ensure npm is in PATH
    if [[ -d "$HOME/.nvm" ]]; then
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    fi

    log_info "Installing Claude Code via npm"
    npm install -g @anthropic-ai/claude-code

    # Verify installation
    if command_exists claude; then
        local version=$(claude --version 2>/dev/null || echo "installed")
        log_success "Claude Code installed successfully: $version"
    else
        log_error "Claude Code installation failed"
        return 1
    fi
}

# Install PowerShell 7
install_powershell() {
    log_step "Installing PowerShell 7"

    if check_existing_tool "pwsh"; then
        return 0
    fi

    if [[ "$WHATIF_MODE" == "true" ]]; then
        log_info "[WHATIF] Would install PowerShell 7"
        return 0
    fi

    case $OS in
        linux)
            case $DISTRO in
                ubuntu|debian)
                    # Install Microsoft repository
                    wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb
                    sudo dpkg -i packages-microsoft-prod.deb
                    rm packages-microsoft-prod.deb

                    # Install PowerShell
                    sudo apt-get update
                    sudo apt-get install -y powershell
                    ;;
                fedora|centos|rhel)
                    # Install Microsoft repository
                    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

                    if [[ "$DISTRO" == "fedora" ]]; then
                        sudo curl -o /etc/yum.repos.d/microsoft.repo https://packages.microsoft.com/config/fedora/35/prod.repo
                    else
                        sudo curl -o /etc/yum.repos.d/microsoft.repo https://packages.microsoft.com/config/rhel/8/prod.repo
                    fi

                    if command_exists dnf; then
                        sudo dnf install -y powershell
                    else
                        sudo yum install -y powershell
                    fi
                    ;;
                arch)
                    # Install from AUR or snap
                    if command_exists yay; then
                        yay -S --noconfirm powershell-bin
                    elif command_exists snap; then
                        sudo snap install powershell --classic
                    else
                        log_warning "Installing PowerShell via manual download for Arch Linux"
                        # Manual installation for Arch
                        local ps_version=$(curl -s https://api.github.com/repos/PowerShell/PowerShell/releases/latest | grep '"tag_name"' | cut -d'"' -f4 | sed 's/v//')
                        local download_url="https://github.com/PowerShell/PowerShell/releases/download/v${ps_version}/powershell-${ps_version}-linux-x64.tar.gz"

                        sudo mkdir -p /opt/microsoft/powershell/7
                        cd /tmp
                        curl -L "$download_url" -o powershell.tar.gz
                        sudo tar -xzf powershell.tar.gz -C /opt/microsoft/powershell/7
                        sudo chmod +x /opt/microsoft/powershell/7/pwsh
                        sudo ln -sf /opt/microsoft/powershell/7/pwsh /usr/local/bin/pwsh
                        rm powershell.tar.gz
                    fi
                    ;;
                *)
                    log_warning "Installing PowerShell via manual download for $DISTRO"
                    # Generic Linux installation
                    local ps_version=$(curl -s https://api.github.com/repos/PowerShell/PowerShell/releases/latest | grep '"tag_name"' | cut -d'"' -f4 | sed 's/v//')
                    local download_url="https://github.com/PowerShell/PowerShell/releases/download/v${ps_version}/powershell-${ps_version}-linux-x64.tar.gz"

                    sudo mkdir -p /opt/microsoft/powershell/7
                    cd /tmp
                    curl -L "$download_url" -o powershell.tar.gz
                    sudo tar -xzf powershell.tar.gz -C /opt/microsoft/powershell/7
                    sudo chmod +x /opt/microsoft/powershell/7/pwsh
                    sudo ln -sf /opt/microsoft/powershell/7/pwsh /usr/local/bin/pwsh
                    rm powershell.tar.gz
                    ;;
            esac
            ;;
        macos)
            if command_exists brew; then
                brew install powershell
            else
                log_error "Homebrew not found. Please install Homebrew first."
                return 1
            fi
            ;;
    esac

    if check_existing_tool "pwsh"; then
        log_success "PowerShell 7 installed successfully"
    else
        log_error "PowerShell 7 installation failed"
        return 1
    fi
}

# Install prerequisites
install_prerequisites() {
    log_step "Installing prerequisites"

    if [[ "$WHATIF_MODE" == "true" ]]; then
        log_info "[WHATIF] Would install prerequisites (curl, wget, etc.)"
        return 0
    fi

    case $OS in
        linux)
            case $DISTRO in
                ubuntu|debian)
                    sudo apt-get update
                    sudo apt-get install -y curl wget apt-transport-https software-properties-common
                    ;;
                fedora|centos|rhel)
                    if command_exists dnf; then
                        sudo dnf install -y curl wget
                    else
                        sudo yum install -y curl wget
                    fi
                    ;;
                arch)
                    sudo pacman -S --noconfirm curl wget
                    ;;
            esac
            ;;
        macos)
            # Prerequisites usually already available on macOS
            if ! command_exists curl; then
                log_error "curl not found. Please install Xcode Command Line Tools: xcode-select --install"
                return 1
            fi
            ;;
    esac

    log_success "Prerequisites installed"
}

# Verify all installations
verify_installations() {
    log_step "Verifying installations"

    local tools=("git" "gh" "node" "npm" "pwsh" "claude")
    local failed=()

    echo ""
    echo "=== Installation Verification ==="

    for tool in "${tools[@]}"; do
        if command_exists "$tool"; then
            local version=""
            case $tool in
                git) version=$(git --version) ;;
                gh) version=$(gh --version | head -n1) ;;
                node) version="Node.js $(node --version)" ;;
                npm) version="npm $(npm --version)" ;;
                pwsh) version="PowerShell $(pwsh --version)" ;;
                claude) version=$(claude --version 2>/dev/null || echo "Claude Code (installed)") ;;
            esac
            echo -e "${GREEN}✅ $tool: $version${NC}"
        else
            echo -e "${RED}❌ $tool: Not found${NC}"
            failed+=("$tool")
        fi
    done

    echo ""

    if [[ ${#failed[@]} -eq 0 ]]; then
        log_success "All tools installed successfully!"
        return 0
    else
        log_error "Some tools failed to install: ${failed[*]}"
        return 1
    fi
}

# Show post-installation instructions
show_post_install_instructions() {
    echo ""
    echo -e "${BLUE}=== Post-Installation Instructions ===${NC}"
    echo ""

    echo -e "${GREEN}Configuration Steps:${NC}"
    echo "1. Configure Git with your information:"
    echo "   git config --global user.name 'Your Name'"
    echo "   git config --global user.email 'your.email@example.com'"
    echo ""
    echo "2. Login to GitHub CLI:"
    echo "   gh auth login"
    echo ""
    echo "3. Configure Claude Code with your API key:"
    echo "   export ANTHROPIC_API_KEY='your-api-key-here'"
    echo "   # Add to your ~/.bashrc or ~/.zshrc to persist"
    echo ""

    echo -e "${GREEN}Getting Started:${NC}"
    echo "- Test Claude Code: claude --help"
    echo "- Create a new repo: gh repo create my-project"
    echo "- Clone a repo: gh repo clone owner/repo"
    echo "- Run PowerShell: pwsh"
    echo ""

    echo -e "${YELLOW}Important Notes:${NC}"
    echo "- For Claude Code, get your API key from: https://console.anthropic.com/"
    echo "- Node.js/npm are installed via nvm in ~/.nvm/"
    echo "- To use Node.js in new shells, run: source ~/.nvm/nvm.sh"
    echo ""

    # Add nvm to shell profile if not already there
    local shell_profile=""
    if [[ -n "$BASH_VERSION" ]]; then
        shell_profile="$HOME/.bashrc"
    elif [[ -n "$ZSH_VERSION" ]]; then
        shell_profile="$HOME/.zshrc"
    fi

    if [[ -n "$shell_profile" ]] && [[ -f "$shell_profile" ]]; then
        if ! grep -q "nvm.sh" "$shell_profile"; then
            echo -e "${YELLOW}Adding nvm to $shell_profile${NC}"
            cat >> "$shell_profile" << 'EOF'

# Node Version Manager (nvm)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF
            echo "Please restart your shell or run: source $shell_profile"
        fi
    fi
}

# Main function
main() {
    echo -e "${BLUE}🚀 $SCRIPT_NAME v$SCRIPT_VERSION${NC}"
    echo "Installing essential development tools for $(uname -s)"
    echo ""

    if [[ "$WHATIF_MODE" == "true" ]]; then
        echo -e "${YELLOW}=== DRY RUN MODE - No changes will be made ===${NC}"
        echo ""
    fi

    # Check for required tools
    if ! command_exists curl && ! command_exists wget; then
        log_error "Either curl or wget is required"
        exit 1
    fi

    # Install everything
    install_prerequisites || exit 1
    install_git || exit 1
    install_github_cli || exit 1
    install_nodejs || exit 1
    install_claude_code || exit 1
    install_powershell || exit 1

    if [[ "$WHATIF_MODE" != "true" ]]; then
        verify_installations || exit 1
        show_post_install_instructions
    else
        echo ""
        log_info "Dry run completed. All tools would be installed successfully."
    fi

    echo ""
    log_success "Development environment setup complete!"
}

# Script entry point
parse_args "$@"
detect_os
main
