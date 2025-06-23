# Development Workflow Setup Guide

## The Aitherium Repository Hierarchy

```text
AitherZero (Personal Fork) → AitherLabs (Public Staging) → Aitherium (Premium/Enterprise)
```

## Problem: Working in Wrong Repository

If you're currently working in the **AitherLabs** directory but want to develop in your **personal fork**, you need to:

1. **Clone your personal fork separately**
2. **Work from the AitherZero directory**
3. **Push changes to AitherZero first**
4. **Create PRs from AitherZero → AitherLabs → Aitherium**

## Solution: Clone AitherZero for Development

### Step 1: Clone Your Personal Fork

```powershell
# Navigate to your development directory
cd "c:/Users/alexa/OneDrive/Documents/0. wizzense/"

# Clone your personal fork
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero

# Set up remotes with correct naming convention
git remote add upstream https://github.com/Aitherium/AitherLabs.git
git remote add aitherium https://github.com/Aitherium/Aitherium.git

# Verify remotes - should show:
# origin      → wizzense/AitherZero.git (your development fork)
# upstream    → Aitherium/AitherLabs.git (public staging)
# aitherium   → Aitherium/Aitherium.git (premium/enterprise)
git remote -v
```

### Current Correct Setup ✅

Your **AitherZero** repository now has the correct remotes:

```text
origin      https://github.com/wizzense/AitherZero.git (fetch/push)
upstream    https://github.com/Aitherium/AitherLabs.git (fetch/push)
aitherium   https://github.com/Aitherium/Aitherium.git (fetch/push)
```

### Step 2: Sync with Latest Changes

```powershell
# Fetch all remote changes
git fetch --all

# Merge any changes from upstream (AitherLabs) into your main branch
git checkout main
git pull upstream main
git push origin main  # Push updates to your fork

# Optional: Sync with premium (Aitherium) features
git fetch aitherium
# Note: Usually you won't merge from aitherium directly
```

## Repository Workflow Explained

### 1. Development Flow (AitherZero → AitherLabs)

```powershell
# Work in your development fork
cd "c:/Users/alexa/OneDrive/Documents/0. wizzense/AitherZero"

# Create feature branch
git checkout -b feature/awesome-new-feature

# Develop and commit
git add .
git commit -m "Add awesome new feature"
git push origin feature/awesome-new-feature

# Create PR to AitherLabs (public staging)
gh pr create --repo Aitherium/AitherLabs --base main --head wizzense:feature/awesome-new-feature
```

### 2. Promotion Flow (AitherLabs → Aitherium)

```powershell
# After feature is merged to AitherLabs, fetch the latest
git fetch upstream
git checkout main
git pull upstream main

# Create branch for premium promotion
git checkout -b premium/awesome-new-feature

# Add enterprise-specific enhancements
# ... make premium modifications ...
git add .
git commit -m "Add enterprise enhancements for awesome feature"
git push origin premium/awesome-new-feature

# Create PR to Aitherium (premium)
gh pr create --repo Aitherium/Aitherium --base main --head wizzense:premium/awesome-new-feature
```

## About the Aitherium Directory

The `c:/Users/alexa/OneDrive/Documents/0. wizzense/Aitherium` directory you have is a **direct clone** of the premium repository. This is fine for:

- **Reviewing** premium features
- **Testing** enterprise functionality
- **Syncing** with production changes

However, for **development**, you should always work from **AitherZero** and create PRs from there.

### Step 3: Work from AitherZero Directory

```powershell
# Always work from your personal fork
cd "c:/Users/alexa/OneDrive/Documents/0. wizzense/AitherZero"

# Create feature branches
git checkout -b feature/your-new-feature

# Make changes, commit, and push to your fork
git add .
git commit -m "Your changes"
git push origin feature/your-new-feature

# Create PR to public staging (AitherLabs)
gh pr create --repo Aitherium/AitherLabs --base main --head wizzense:feature/your-new-feature
```

## Current Status

✅ **Changes committed to AitherZero** (your personal fork)
✅ **Multi-repo workflow documentation complete**
✅ **Enhanced kicker-git script tested and working**

## Next Steps

1. **Clone AitherZero separately** for development work
2. **Continue all development from the AitherZero directory**
3. **Use the enhanced kicker-git script** from your fork for multi-repo operations

## Enhanced Kicker-Git Script Usage

From your AitherZero directory, use the enhanced script:

```powershell
# Lightweight sync (just remotes and status)
./kicker-git-enhanced.ps1 -Mode Lightweight

# Full sync with all remotes
./kicker-git-enhanced.ps1 -Mode Full

# Development mode (verbose output)
./kicker-git-enhanced.ps1 -Mode Dev
```

## Directory Structure

```text
c:/Users/alexa/OneDrive/Documents/0. wizzense/
├── AitherLabs/          # ← Current location (staging repo)
├── AitherZero/          # ← Clone this for development
└── Aitherium/           # ← Premium repo (optional local copy)
```

## Important Notes

- **AitherLabs directory**: Use for testing/staging, not primary development
- **AitherZero directory**: Primary development location
- **All PRs**: Should originate from AitherZero branches
- **Commits**: Should go to AitherZero first, then promote through pipeline

This ensures proper separation of development, staging, and production environments.
