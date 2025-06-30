#!/bin/bash

# Quick Release Script for AitherZero
# Automatically increments patch version and creates release

set -e

# Use Windows Git if available, otherwise fallback to system git
GIT_CMD="${GIT_EXECUTABLE:-git}"
if [[ -n "$GIT_EXECUTABLE" ]]; then
    GIT_CMD="$GIT_EXECUTABLE"
elif command -v "/mnt/c/Program Files/Git/cmd/git.exe" >/dev/null 2>&1; then
    GIT_CMD="/mnt/c/Program Files/Git/cmd/git.exe"
elif command -v git >/dev/null 2>&1; then
    GIT_CMD="git"
else
    echo "❌ Git not found. Please install Git or set GIT_EXECUTABLE."
    exit 1
fi

echo -e "\033[0;32m🚀 Quick Patch Release\033[0m"

# Get current version
if [[ ! -f "VERSION" ]]; then
    echo "❌ VERSION file not found"
    exit 1
fi

current_version=$(cat VERSION)
echo "Current version: $current_version"

# Parse version parts and strip whitespace
current_version=$(echo "$current_version" | tr -d '[:space:]')
IFS='.' read -ra VERSION_PARTS <<< "$current_version"
major=${VERSION_PARTS[0]:-0}
minor=${VERSION_PARTS[1]:-0}
patch=${VERSION_PARTS[2]:-0}

# Increment patch version
new_patch=$((patch + 1))
new_version="$major.$minor.$new_patch"

echo "Bumping $current_version → $new_version"

# Update VERSION file
echo "$new_version" > VERSION

# Create commit
"$GIT_CMD" add VERSION
"$GIT_CMD" commit -m "Release v$new_version - Quick patch release

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Create annotated tag
"$GIT_CMD" tag -a "v$new_version" -m "Release v$new_version"

# Push changes and tags
"$GIT_CMD" push origin main
"$GIT_CMD" push origin "v$new_version"

echo -e "\033[0;32m✅ Release v$new_version created successfully!\033[0m"
echo "🔗 GitHub Actions will build and publish the release"