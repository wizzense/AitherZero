#!/usr/bin/env bash
# Setup Git merge configuration for AitherZero
# This script configures the custom merge driver for index.md files

set -e

echo "🔧 Configuring Git merge strategy for AitherZero..."

# Configure the merge.ours driver
git config --local merge.ours.name "Always use our version for auto-generated files"
git config --local merge.ours.driver true

echo "✅ Git merge configuration complete!"
echo ""
echo "Verification:"
git config merge.ours.driver
echo ""

# Verify attributes are set
echo "Checking .gitattributes configuration:"
if git check-attr merge automation-scripts/index.md | grep -q "ours"; then
    echo "✅ Merge attribute correctly applied to index.md files"
else
    echo "⚠️  Warning: Merge attribute not found in .gitattributes"
    echo "   Expected: **/index.md merge=ours"
fi

echo ""
echo "📝 Note: This configuration is local to this repository."
echo "   Other contributors should run this script after cloning."
