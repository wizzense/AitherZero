# Multi-Repository Development Workflow Guide

## Repository Hierarchy

```
┌─────────────────────────────────────────┐
│       wizzense/AitherZero.git           │  ← YOUR DEVELOPMENT FORK
│  - GitHub Copilot enabled              │
│  - Private development                 │
│  - Feature branches                    │
│  - Experimental code                   │
└─────────────────┬───────────────────────┘
                  │ fork relationship
                  ↓
┌─────────────────────────────────────────┐
│     Aitherium/AitherLabs.git           │  ← PUBLIC STAGING/TEST
│  - Open source community version      │
│  - Stable, tested features            │
│  - Community contributions            │
│  - CI/CD testing                      │
└─────────────────┬───────────────────────┘
                  │ fork relationship
                  ↓
┌─────────────────────────────────────────┐
│      Aitherium/Aitherium.git           │  ← PRIVATE PREMIUM/PROD
│  - Enterprise features                │
│  - Premium functionality              │
│  - Customer deployments               │
│  - Advanced integrations              │
└─────────────────────────────────────────┘
```

## Setting Up the Workflow

### 1. Initial Repository Setup

```bash
# Clone your personal development fork
git clone https://github.com/wizzense/AitherZero.git
cd AitherZero

# Add the upstream repositories with proper naming
git remote add AitherLabs https://github.com/Aitherium/AitherLabs.git
git remote add Aitherium https://github.com/Aitherium/Aitherium.git

# Verify remotes (should match repository names)
git remote -v
# AitherZero   https://github.com/wizzense/AitherZero.git (fetch)
# AitherZero   https://github.com/wizzense/AitherZero.git (push)
# AitherLabs   https://github.com/Aitherium/AitherLabs.git (fetch)
# AitherLabs   https://github.com/Aitherium/AitherLabs.git (push)
# Aitherium    https://github.com/Aitherium/Aitherium.git (fetch)
# Aitherium    https://github.com/Aitherium/Aitherium.git (push)
```

### 1.1. Fixing Git Remote Issues on Windows

If you encounter deletion errors when managing remotes:

```bash
# Answer 'n' to deletion prompts, then manually edit .git/config
# Open .git/config in a text editor and ensure it looks like:

[remote "AitherZero"]
    url = https://github.com/wizzense/AitherZero.git
    fetch = +refs/heads/*:refs/remotes/AitherZero/*

[remote "AitherLabs"]
    url = https://github.com/Aitherium/AitherLabs.git
    fetch = +refs/heads/*:refs/remotes/AitherLabs/*

[remote "Aitherium"]
    url = https://github.com/Aitherium/Aitherium.git
    fetch = +refs/heads/*:refs/remotes/Aitherium/*

# Then manually clean up the .git/logs/refs/remotes/ directory if needed
# Remove any unwanted remote tracking directories
```

### 2. Development Workflow

#### A. Feature Development (in your fork)
```bash
# Start new feature in your fork
git checkout -b feature/new-awesome-feature
# ... develop and test ...
git add .
git commit -m "Add awesome new feature"
git push origin feature/new-awesome-feature

# Create PR within your fork for testing
gh pr create --repo wizzense/AitherZero --base main --head feature/new-awesome-feature
```

#### B. Promote to Public (AitherLabs)
```bash
# When ready for public release
git checkout main
git pull AitherZero main

# Create branch for public PR
git checkout -b public/new-awesome-feature

# Push to your fork first
git push AitherZero public/new-awesome-feature

# Create PR to public repo
gh pr create --repo Aitherium/AitherLabs --base main --head wizzense:public/new-awesome-feature --title "Add awesome new feature" --body "Promotes feature from development fork"
```

#### C. Promote to Premium (Aitherium)
```bash
# After feature is merged to AitherLabs, promote to premium
git fetch AitherLabs
git checkout -b premium/new-awesome-feature AitherLabs/main

# Add premium-specific enhancements
# ... add enterprise features ...
git add .
git commit -m "Add enterprise enhancements to awesome feature"

# Push to your fork for tracking
git push AitherZero premium/new-awesome-feature

# Create PR to premium repo
gh pr create --repo Aitherium/Aitherium --base main --head wizzense:premium/new-awesome-feature --title "Add enterprise version of awesome feature"
```

### 3. Staying Synchronized

#### Sync your fork with public repo
```bash
git fetch upstream-public
git checkout main
git merge upstream-public/main
git push origin main
```

#### Sync public repo with premium repo (if changes flow back)
```bash
git fetch upstream-premium
git checkout main
git merge upstream-premium/main --allow-unrelated-histories
git push upstream-public main
```

## Enhanced Kicker-Git Configuration

Update the enhanced kicker-git script to support this workflow:

```powershell
# Repository configurations
$script:Repositories = @{
    'dev' = @{
        Name = 'wizzense/AitherZero'
        Url = 'https://github.com/wizzense/AitherZero.git'
        RawBaseUrl = 'https://raw.githubusercontent.com/wizzense/AitherZero'
        Description = 'Personal development fork with GitHub Copilot'
        Upstreams = @(
            'https://github.com/Aitherium/AitherLabs.git',
            'https://github.com/Aitherium/Aitherium.git'
        )
    }
    'public' = @{
        Name = 'Aitherium/AitherLabs'
        Url = 'https://github.com/Aitherium/AitherLabs.git'
        RawBaseUrl = 'https://raw.githubusercontent.com/Aitherium/AitherLabs'
        Description = 'Public open-source staging/test environment'
        Upstreams = @('https://github.com/Aitherium/Aitherium.git')
    }
    'premium' = @{
        Name = 'Aitherium/Aitherium'
        Url = 'https://github.com/Aitherium/Aitherium.git'
        RawBaseUrl = 'https://raw.githubusercontent.com/Aitherium/Aitherium'
        Description = 'Private premium/enterprise production environment'
        Upstreams = @()
    }
}
```

## Automation Scripts

### Sync Script
```powershell
# sync-repositories.ps1
param(
    [ValidateSet('dev-to-public', 'public-to-premium', 'full-sync')]
    [string]$SyncType = 'full-sync'
)

switch ($SyncType) {
    'dev-to-public' {
        # Sync your development work to public staging
        git fetch origin
        git checkout main
        git pull origin main
        gh pr create --repo Aitherium/AitherLabs --base main --head wizzense:main
    }
    'public-to-premium' {
        # Sync public releases to premium
        git fetch upstream-public
        git checkout premium-sync
        git merge upstream-public/main
        gh pr create --repo Aitherium/Aitherium --base main --head wizzense:premium-sync
    }
    'full-sync' {
        # Keep everything in sync
        Write-Host "Syncing all repositories..."
        # Implementation for full sync
    }
}
```

### Branch Management
```powershell
# manage-branches.ps1
param(
    [string]$FeatureName,
    [ValidateSet('start', 'promote-public', 'promote-premium')]
    [string]$Action
)

switch ($Action) {
    'start' {
        git checkout -b "feature/$FeatureName"
        Write-Host "Started feature branch: feature/$FeatureName"
    }
    'promote-public' {
        git checkout -b "public/$FeatureName"
        Write-Host "Created public promotion branch: public/$FeatureName"
    }
    'promote-premium' {
        git checkout -b "premium/$FeatureName"
        Write-Host "Created premium promotion branch: premium/$FeatureName"
    }
}
```

## Benefits of This Workflow

### For Development
- **GitHub Copilot** fully available in your personal fork
- **Private experimentation** without exposing incomplete work
- **Full control** over your development environment

### For Release Management
- **Staged releases** through public → premium
- **Community feedback** on public features before premium
- **Feature gating** for premium customers

### For Collaboration
- **Clear separation** of concerns
- **Proper attribution** through fork relationships
- **Audit trail** of feature progression

## VS Code Integration

Add these VS Code tasks for the workflow:

```json
{
    "label": "Git: Sync with Public Upstream",
    "type": "shell",
    "command": "git",
    "args": ["fetch", "upstream-public", "&&", "git", "merge", "upstream-public/main"],
    "group": "build"
},
{
    "label": "Git: Create Public PR",
    "type": "shell",
    "command": "gh",
    "args": ["pr", "create", "--repo", "Aitherium/AitherLabs", "--base", "main", "--head", "wizzense:${input:branchName}"],
    "group": "build"
}
```

This workflow gives you the best of all worlds: private development with Copilot, public community engagement, and premium enterprise features.
