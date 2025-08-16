#!/bin/bash

# Claude CLI wrapper script
# This wrapper ensures proper NODE_PATH is set and modules can be resolved

# Set NODE_PATH to include the Claude module directory
export NODE_PATH="/usr/local/share/nvm/versions/node/v22.17.0/lib/node_modules/@anthropic-ai/claude-code:/usr/local/share/nvm/versions/node/v22.17.0/lib/node_modules"

# Set NODE_OPTIONS to help with module resolution
export NODE_OPTIONS="--experimental-wasm-modules"

# Change to the Claude module directory to ensure relative paths work
cd /usr/local/share/nvm/versions/node/v22.17.0/lib/node_modules/@anthropic-ai/claude-code 2>/dev/null || true

# Execute Claude with all passed arguments
/usr/local/share/nvm/versions/node/v22.17.0/bin/claude "$@"