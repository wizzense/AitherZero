#!/bin/bash

# AitherZero MCP Server Setup Script for Claude Code
# This script configures the MCP server for use with Claude Code

echo "🚀 AitherZero MCP Server Setup for Claude Code"
echo "============================================"

# Check if we're in the correct directory
if [ ! -f "claude-code-mcp-server.js" ]; then
    echo "❌ Error: claude-code-mcp-server.js not found!"
    echo "Please run this script from the mcp-server directory."
    exit 1
fi

# Function to display usage
usage() {
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help       Show this help message"
    echo "  -p, --project    Add server to project scope (.mcp.json)"
    echo "  -u, --user       Add server to user scope"
    echo "  -r, --remove     Remove the MCP server configuration"
    echo "  -l, --list       List configured MCP servers"
    echo ""
    echo "Default: Adds server to local scope"
}

# Parse command line arguments
SCOPE="local"
ACTION="add"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) usage; exit 0 ;;
        -p|--project) SCOPE="project" ;;
        -u|--user) SCOPE="user" ;;
        -r|--remove) ACTION="remove" ;;
        -l|--list) ACTION="list" ;;
        *) echo "Unknown parameter: $1"; usage; exit 1 ;;
    esac
    shift
done

# Check if claude command is available
if ! command -v claude &> /dev/null; then
    echo "❌ Error: Claude Code CLI not found!"
    echo "Please install Claude Code first: https://claude.ai/code"
    exit 1
fi

# Perform the requested action
case $ACTION in
    "add")
        echo "📦 Adding AitherZero MCP server to $SCOPE scope..."
        
        if [ "$SCOPE" == "project" ]; then
            claude mcp add aitherzero --project -- node "$(pwd)/claude-code-mcp-server.js"
        elif [ "$SCOPE" == "user" ]; then
            claude mcp add aitherzero --user -- node "$(pwd)/claude-code-mcp-server.js"
        else
            claude mcp add aitherzero -- node "$(pwd)/claude-code-mcp-server.js"
        fi
        
        if [ $? -eq 0 ]; then
            echo "✅ Successfully configured AitherZero MCP server!"
            echo ""
            echo "🎯 Available tools:"
            echo "  - aither_patch_workflow      : Git workflow automation"
            echo "  - aither_testing_framework   : Bulletproof validation"
            echo "  - aither_dev_environment     : Development setup"
            echo "  - aither_lab_automation      : Lab orchestration"
            echo "  - aither_backup_management   : Backup operations"
            echo "  - aither_infrastructure_deployment : OpenTofu/Terraform"
            echo "  - aither_iso_management      : ISO handling"
            echo "  - aither_remote_connection   : Multi-protocol connections"
            echo "  - aither_credential_management : Secure credentials"
            echo "  - aither_logging_system      : Centralized logging"
            echo "  - aither_parallel_execution  : Parallel tasks"
            echo "  - aither_script_management   : Script repository"
            echo "  - aither_maintenance_operations : Maintenance tasks"
            echo "  - aither_repo_sync          : Repository synchronization"
            echo ""
            echo "💡 To test the setup, run: node test-mcp-working.js"
        else
            echo "❌ Failed to configure MCP server"
            exit 1
        fi
        ;;
        
    "remove")
        echo "🗑️  Removing AitherZero MCP server..."
        claude mcp remove aitherzero
        if [ $? -eq 0 ]; then
            echo "✅ Successfully removed AitherZero MCP server"
        else
            echo "❌ Failed to remove MCP server"
            exit 1
        fi
        ;;
        
    "list")
        echo "📋 Configured MCP servers:"
        claude mcp list
        ;;
esac

echo ""
echo "Done! 🎉"