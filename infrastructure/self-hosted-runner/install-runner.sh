#!/bin/bash
#
# AitherZero Self-Hosted Runner Installation Script
#
# This script installs and configures a self-hosted GitHub Actions runner
# with a persistent deployment of the AitherZero main branch.
#
# Usage: sudo ./install-runner.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Installation directory
INSTALL_DIR="/opt/aitherzero-runner"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   AitherZero Self-Hosted Runner Installation              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ This script must be run as root (use sudo)${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Running as root"

# Check system requirements
echo ""
echo -e "${BLUE}[1/8] Checking System Requirements...${NC}"

# Check OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo -e "${GREEN}✓${NC} Operating System: $PRETTY_NAME"
else
    echo -e "${YELLOW}⚠${NC} Could not determine OS version"
fi

# Check CPU cores
CPU_CORES=$(nproc)
if [ "$CPU_CORES" -lt 2 ]; then
    echo -e "${YELLOW}⚠${NC} Warning: Less than 2 CPU cores detected ($CPU_CORES)"
else
    echo -e "${GREEN}✓${NC} CPU Cores: $CPU_CORES"
fi

# Check memory
MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
if [ "$MEMORY_GB" -lt 4 ]; then
    echo -e "${YELLOW}⚠${NC} Warning: Less than 4GB RAM detected (${MEMORY_GB}GB)"
else
    echo -e "${GREEN}✓${NC} Memory: ${MEMORY_GB}GB"
fi

# Check disk space
DISK_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$DISK_GB" -lt 20 ]; then
    echo -e "${YELLOW}⚠${NC} Warning: Less than 20GB free disk space (${DISK_GB}GB)"
else
    echo -e "${GREEN}✓${NC} Disk Space: ${DISK_GB}GB free"
fi

# Install Docker if not present
echo ""
echo -e "${BLUE}[2/8] Checking Docker Installation...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}⚠${NC} Docker not found. Installing Docker..."
    
    # Update package index
    apt-get update
    
    # Install prerequisites
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start Docker
    systemctl start docker
    systemctl enable docker
    
    echo -e "${GREEN}✓${NC} Docker installed successfully"
else
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | tr -d ',')
    echo -e "${GREEN}✓${NC} Docker is installed (version $DOCKER_VERSION)"
fi

# Check Docker Compose
echo ""
echo -e "${BLUE}[3/8] Checking Docker Compose...${NC}"

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}⚠${NC} Docker Compose not found. Installing..."
    
    # Install docker-compose plugin (v2)
    apt-get update
    apt-get install -y docker-compose-plugin
    
    echo -e "${GREEN}✓${NC} Docker Compose installed successfully"
else
    if docker compose version &> /dev/null; then
        COMPOSE_VERSION=$(docker compose version --short)
        echo -e "${GREEN}✓${NC} Docker Compose is installed (version $COMPOSE_VERSION)"
    else
        COMPOSE_VERSION=$(docker-compose --version | cut -d' ' -f3 | tr -d ',')
        echo -e "${GREEN}✓${NC} Docker Compose is installed (version $COMPOSE_VERSION)"
    fi
fi

# Create installation directory
echo ""
echo -e "${BLUE}[4/8] Creating Installation Directory...${NC}"

if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}⚠${NC} Installation directory already exists: $INSTALL_DIR"
    read -p "Do you want to remove it and reinstall? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Stopping existing services..."
        systemctl stop aitherzero-runner 2>/dev/null || true
        
        echo "Removing existing installation..."
        cd "$INSTALL_DIR"
        docker-compose down -v 2>/dev/null || true
        cd /
        rm -rf "$INSTALL_DIR"
    else
        echo -e "${RED}❌ Installation cancelled${NC}"
        exit 1
    fi
fi

mkdir -p "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/data/runner"
mkdir -p "$INSTALL_DIR/data/deployment"
mkdir -p "$INSTALL_DIR/data/logs"
mkdir -p "$INSTALL_DIR/scripts"

echo -e "${GREEN}✓${NC} Created installation directory: $INSTALL_DIR"

# Copy configuration files
echo ""
echo -e "${BLUE}[5/8] Copying Configuration Files...${NC}"

# Copy docker-compose.yml
if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    cp "$SCRIPT_DIR/docker-compose.yml" "$INSTALL_DIR/"
    echo -e "${GREEN}✓${NC} Copied docker-compose.yml"
else
    echo -e "${RED}❌ docker-compose.yml not found in $SCRIPT_DIR${NC}"
    exit 1
fi

# Copy or create .env file
if [ -f "$SCRIPT_DIR/.env" ]; then
    cp "$SCRIPT_DIR/.env" "$INSTALL_DIR/"
    echo -e "${GREEN}✓${NC} Copied existing .env configuration"
elif [ -f "$SCRIPT_DIR/.env.example" ]; then
    cp "$SCRIPT_DIR/.env.example" "$INSTALL_DIR/.env"
    echo -e "${YELLOW}⚠${NC} Created .env from .env.example"
    echo -e "${YELLOW}⚠${NC} YOU MUST EDIT $INSTALL_DIR/.env WITH YOUR GITHUB TOKEN!${NC}"
else
    echo -e "${RED}❌ No .env or .env.example found${NC}"
    exit 1
fi

# Set secure permissions on .env
chmod 600 "$INSTALL_DIR/.env"
echo -e "${GREEN}✓${NC} Set secure permissions on .env file"

# Copy scripts
if [ -d "$SCRIPT_DIR/scripts" ]; then
    cp -r "$SCRIPT_DIR/scripts"/* "$INSTALL_DIR/scripts/" 2>/dev/null || true
    chmod +x "$INSTALL_DIR/scripts"/*.sh 2>/dev/null || true
    echo -e "${GREEN}✓${NC} Copied management scripts"
fi

# Create systemd service
echo ""
echo -e "${BLUE}[6/8] Creating Systemd Service...${NC}"

cat > /etc/systemd/system/aitherzero-runner.service <<EOF
[Unit]
Description=AitherZero Self-Hosted GitHub Actions Runner
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR
EnvironmentFile=$INSTALL_DIR/.env

# Start containers
ExecStart=/usr/bin/docker compose up -d

# Stop containers
ExecStop=/usr/bin/docker compose down

# Restart on failure
Restart=on-failure
RestartSec=10s

# Logging
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
echo -e "${GREEN}✓${NC} Created systemd service: aitherzero-runner.service"

# Check if .env needs configuration
echo ""
echo -e "${BLUE}[7/8] Checking Configuration...${NC}"

if grep -q "your_github_personal_access_token" "$INSTALL_DIR/.env"; then
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  CONFIGURATION REQUIRED                                    ║${NC}"
    echo -e "${YELLOW}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║  You must configure your GitHub token before starting      ║${NC}"
    echo -e "${YELLOW}║                                                            ║${NC}"
    echo -e "${YELLOW}║  Edit: $INSTALL_DIR/.env                    ║${NC}"
    echo -e "${YELLOW}║                                                            ║${NC}"
    echo -e "${YELLOW}║  Set GITHUB_TOKEN to your personal access token            ║${NC}"
    echo -e "${YELLOW}║  Create token at: https://github.com/settings/tokens/new  ║${NC}"
    echo -e "${YELLOW}║  Required scopes: repo, workflow                           ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
    
    echo ""
    echo "After configuring, start the service with:"
    echo "  sudo systemctl start aitherzero-runner"
    echo "  sudo systemctl enable aitherzero-runner"
    
    NEEDS_CONFIG=true
else
    echo -e "${GREEN}✓${NC} Configuration appears to be complete"
    NEEDS_CONFIG=false
fi

# Enable and start service
echo ""
echo -e "${BLUE}[8/8] Starting Service...${NC}"

if [ "$NEEDS_CONFIG" = false ]; then
    systemctl enable aitherzero-runner
    echo -e "${GREEN}✓${NC} Service enabled for auto-start on boot"
    
    systemctl start aitherzero-runner
    echo -e "${GREEN}✓${NC} Service started"
    
    # Wait for containers to start
    echo ""
    echo "Waiting for containers to start..."
    sleep 10
    
    # Check container status
    if docker ps | grep -q aitherzero-runner; then
        echo -e "${GREEN}✓${NC} Runner container is running"
    else
        echo -e "${YELLOW}⚠${NC} Runner container may not be running yet"
    fi
    
    if docker ps | grep -q aitherzero-main; then
        echo -e "${GREEN}✓${NC} Main deployment container is running"
    else
        echo -e "${YELLOW}⚠${NC} Main deployment container may not be running yet"
    fi
else
    echo -e "${YELLOW}⚠${NC} Service not started - configuration required"
fi

# Display summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Installation Complete!                                    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Installation Directory: $INSTALL_DIR"
echo ""
echo "Management Commands:"
echo "  sudo systemctl start aitherzero-runner    # Start service"
echo "  sudo systemctl stop aitherzero-runner     # Stop service"
echo "  sudo systemctl restart aitherzero-runner  # Restart service"
echo "  sudo systemctl status aitherzero-runner   # Check status"
echo ""
echo "View Logs:"
echo "  sudo journalctl -u aitherzero-runner -f   # Service logs"
echo "  docker logs -f aitherzero-runner          # Runner logs"
echo "  docker logs -f aitherzero-main            # Deployment logs"
echo ""
echo "Access Deployment:"
echo "  http://localhost:8080                     # Web dashboard"
echo ""
echo "Check Runner Status:"
echo "  https://github.com/wizzense/AitherZero/settings/actions/runners"
echo ""

if [ "$NEEDS_CONFIG" = true ]; then
    echo -e "${YELLOW}NEXT STEPS:${NC}"
    echo "  1. Edit $INSTALL_DIR/.env"
    echo "  2. Set your GITHUB_TOKEN"
    echo "  3. Run: sudo systemctl start aitherzero-runner"
    echo ""
fi

echo -e "${GREEN}✓${NC} Installation script completed successfully!"
