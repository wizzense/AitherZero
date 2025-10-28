#!/bin/bash
#
# Health Check Script for AitherZero Self-Hosted Runner
#
# This script checks the health of the runner and deployment containers

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="/opt/aitherzero-runner"
DEPLOYMENT_PORT=8080

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   AitherZero Self-Hosted Runner Health Check              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

EXIT_CODE=0

# Check systemd service
echo -e "${BLUE}[1/6] Checking Systemd Service...${NC}"
if systemctl is-active --quiet aitherzero-runner; then
    echo -e "${GREEN}✓${NC} Service is active"
else
    echo -e "${RED}❌ Service is not active${NC}"
    EXIT_CODE=1
fi

# Check runner container
echo ""
echo -e "${BLUE}[2/6] Checking Runner Container...${NC}"
if docker ps | grep -q aitherzero-runner; then
    echo -e "${GREEN}✓${NC} Runner container is running"
    
    # Check runner logs for errors
    RECENT_ERRORS=$(docker logs --since 5m aitherzero-runner 2>&1 | grep -iE 'error|fatal|failed' | wc -l)
    if [ "$RECENT_ERRORS" -gt 0 ]; then
        echo -e "${YELLOW}⚠${NC} Found $RECENT_ERRORS recent errors in logs"
    else
        echo -e "${GREEN}✓${NC} No recent errors in logs"
    fi
else
    echo -e "${RED}❌ Runner container is not running${NC}"
    EXIT_CODE=1
fi

# Check deployment container
echo ""
echo -e "${BLUE}[3/6] Checking Deployment Container...${NC}"
if docker ps | grep -q aitherzero-main; then
    echo -e "${GREEN}✓${NC} Deployment container is running"
    
    # Check health status
    HEALTH=$(docker inspect --format='{{.State.Health.Status}}' aitherzero-main 2>/dev/null || echo "unknown")
    case $HEALTH in
        healthy)
            echo -e "${GREEN}✓${NC} Container is healthy"
            ;;
        starting)
            echo -e "${YELLOW}⚠${NC} Container is starting up"
            ;;
        unhealthy)
            echo -e "${RED}❌ Container is unhealthy${NC}"
            EXIT_CODE=1
            ;;
        *)
            echo -e "${YELLOW}⚠${NC} Health status: $HEALTH"
            ;;
    esac
else
    echo -e "${RED}❌ Deployment container is not running${NC}"
    EXIT_CODE=1
fi

# Check web interface
echo ""
echo -e "${BLUE}[4/6] Checking Web Interface...${NC}"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:$DEPLOYMENT_PORT | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✓${NC} Web interface is accessible on port $DEPLOYMENT_PORT"
else
    echo -e "${RED}❌ Web interface is not accessible${NC}"
    EXIT_CODE=1
fi

# Check GitHub connectivity
echo ""
echo -e "${BLUE}[5/6] Checking GitHub Connectivity...${NC}"
if docker exec aitherzero-runner curl -s -o /dev/null -w "%{http_code}" https://api.github.com | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✓${NC} GitHub API is reachable"
else
    echo -e "${RED}❌ Cannot reach GitHub API${NC}"
    EXIT_CODE=1
fi

# Check disk space
echo ""
echo -e "${BLUE}[6/6] Checking Disk Space...${NC}"
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 90 ]; then
    echo -e "${GREEN}✓${NC} Disk usage: ${DISK_USAGE}%"
else
    echo -e "${RED}❌ Disk usage is high: ${DISK_USAGE}%${NC}"
    EXIT_CODE=1
fi

# Summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}║  All Health Checks Passed ✓                                ║${NC}"
else
    echo -e "${RED}║  Some Health Checks Failed ✗                               ║${NC}"
fi
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"

echo ""
echo "Container Status:"
docker ps --filter name=aitherzero --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "Recent Container Logs (last 10 lines):"
echo "--- Runner ---"
docker logs --tail 10 aitherzero-runner 2>&1 | head -10
echo ""
echo "--- Deployment ---"
docker logs --tail 10 aitherzero-main 2>&1 | head -10

echo ""
echo "For detailed logs, use:"
echo "  docker logs -f aitherzero-runner"
echo "  docker logs -f aitherzero-main"
echo ""

exit $EXIT_CODE
