#!/bin/bash
# Quick MCP server setup script for VS Code tasks
# Can be called from tasks.json or manually

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MCP_SERVER_DIR="$SCRIPT_DIR/mcp-server"

echo "════════════════════════════════════════════════════════"
echo "  Building AitherZero MCP Server"
echo "════════════════════════════════════════════════════════"
echo ""

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found. Install from https://nodejs.org/"
    exit 1
fi

NODE_VERSION=$(node --version)
echo "✓ Node.js $NODE_VERSION detected"

# Build MCP server
cd "$MCP_SERVER_DIR"
echo ""
echo "📦 Installing dependencies..."
npm install --silent

if [ -f "dist/index.js" ]; then
    echo "✓ MCP server built successfully"
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "  Next Steps:"
    echo "════════════════════════════════════════════════════════"
    echo ""
    echo "  1. Reload VS Code: Ctrl+Shift+P → 'Developer: Reload Window'"
    echo "  2. Check Output panel: View → Output → 'GitHub Copilot'"
    echo "  3. Test: @workspace List all automation scripts"
    echo ""
else
    echo "❌ Build failed - dist/index.js not created"
    exit 1
fi
