#!/bin/bash
#
# Update AitherZero Main Branch Deployment
#
# This script updates the main deployment container with the latest code from GitHub

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="/opt/aitherzero-runner"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Updating AitherZero Main Deployment                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Change to script directory
cd "$SCRIPT_DIR" || exit 1

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Stop the deployment container
echo -e "${BLUE}[1/5] Stopping deployment container...${NC}"
docker-compose stop aitherzero-main
echo -e "${GREEN}✓${NC} Container stopped"

# Pull latest code (rebuild will happen with latest code from context)
echo ""
echo -e "${BLUE}[2/5] Pulling latest main branch...${NC}"

# Get the repository root (two directories up from script location)
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

if [ -d "$REPO_ROOT/.git" ]; then
    cd "$REPO_ROOT"
    echo "Repository: $(pwd)"
    
    # Fetch latest changes
    git fetch origin main
    
    # Get current and latest commits
    CURRENT_COMMIT=$(git rev-parse HEAD)
    LATEST_COMMIT=$(git rev-parse origin/main)
    
    if [ "$CURRENT_COMMIT" = "$LATEST_COMMIT" ]; then
        echo -e "${GREEN}✓${NC} Already on latest commit: ${CURRENT_COMMIT:0:8}"
    else
        echo "Current: ${CURRENT_COMMIT:0:8}"
        echo "Latest:  ${LATEST_COMMIT:0:8}"
        
        # Pull latest changes
        git pull origin main
        echo -e "${GREEN}✓${NC} Updated to latest commit"
    fi
else
    echo -e "${YELLOW}⚠${NC} Repository not found at $REPO_ROOT"
    echo "Will rebuild with existing code"
fi

cd "$SCRIPT_DIR"

# Rebuild the Docker image with latest code
echo ""
echo -e "${BLUE}[3/5] Rebuilding Docker image...${NC}"
docker-compose build --no-cache aitherzero-main
echo -e "${GREEN}✓${NC} Image rebuilt"

# Start the deployment container
echo ""
echo -e "${BLUE}[4/5] Starting deployment container...${NC}"
docker-compose up -d aitherzero-main
echo -e "${GREEN}✓${NC} Container started"

# Wait for container to be healthy
echo ""
echo -e "${BLUE}[5/5] Waiting for container to be healthy...${NC}"
RETRIES=30
COUNT=0

while [ $COUNT -lt $RETRIES ]; do
    if docker ps | grep -q aitherzero-main; then
        HEALTH=$(docker inspect --format='{{.State.Health.Status}}' aitherzero-main 2>/dev/null || echo "unknown")
        
        if [ "$HEALTH" = "healthy" ]; then
            echo -e "${GREEN}✓${NC} Container is healthy"
            break
        elif [ "$HEALTH" = "starting" ]; then
            echo -n "."
        elif [ "$HEALTH" = "unknown" ]; then
            # No healthcheck defined, just check if running
            if docker ps | grep -q aitherzero-main; then
                echo -e "${GREEN}✓${NC} Container is running"
                break
            fi
        fi
    fi
    
    sleep 2
    COUNT=$((COUNT + 1))
done

if [ $COUNT -eq $RETRIES ]; then
    echo ""
    echo -e "${YELLOW}⚠${NC} Container may not be fully healthy yet"
    echo "Check logs with: docker logs aitherzero-main"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Update Complete!                                          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Container Status:"
docker ps --filter name=aitherzero-main --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "Access Dashboard: http://localhost:8080"
echo "View Logs: docker logs -f aitherzero-main"
echo ""
