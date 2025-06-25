# Repository Sync Setup Guide

This guide explains how to convert AitherZero from a fork to a standalone repository while maintaining sync capabilities with aitherlab.

## Step 1: Convert to Standalone Repository

1. **Run the conversion script:**
   ```powershell
   .\convert-to-standalone.ps1 -NewOrigin "https://github.com/yourusername/AitherZero.git" -AitherLabRepo "https://github.com/yourusername/aitherlab.git"
   ```

2. **Create new standalone repository on GitHub:**
   - Go to GitHub and create a new repository named "AitherZero" (NOT a fork)
   - Make it public
   - Don't initialize with README (we'll push existing content)

## Step 2: Set Up Sync Secrets

1. **Create Personal Access Token:**
   - Go to GitHub Settings → Developer settings → Personal access tokens
   - Create a token with `repo` scope for both AitherZero and aitherlab
   
2. **Add Secret to AitherZero repository:**
   - Go to AitherZero repository Settings → Secrets and variables → Actions
   - Add new secret: `AITHERLAB_SYNC_TOKEN` with your PAT

## Step 3: Test Sync Operations

### Manual Sync Commands

```powershell
# Check sync status
.\sync-repos.ps1 -Action Status

# Push specific changes to aitherlab
.\sync-repos.ps1 -Action ToAitherLab -Message "Add new feature X" -Files @("module1.ps1", "README.md")

# Pull updates from aitherlab (dry run first)
.\sync-repos.ps1 -Action FromAitherLab -DryRun

# Pull updates from aitherlab (actual)
.\sync-repos.ps1 -Action FromAitherLab
```

### VS Code Tasks

Use Ctrl+Shift+P → Tasks: Run Task → Select:
- **Sync: Push to AitherLab** - Push changes to private repo
- **Sync: Pull from AitherLab** - Pull changes from private repo
- **Sync: Check Status** - View sync status

## Step 4: Automated Workflow

The GitHub Actions workflow will automatically:
- ✅ Create sync PRs in aitherlab when you push to AitherZero main branch
- ✅ Exclude sensitive files (.github/workflows, secrets, etc.)
- ✅ Allow manual triggering with custom files/messages

## Daily Workflow

1. **Work in AitherZero (public)** - normal development
2. **Push to main** - automatic sync PR created in aitherlab
3. **Review and merge PR in aitherlab** - keeps private repo updated
4. **Pull from aitherlab occasionally** - get private-only changes

## Repository Structure After Setup

```
AitherZero (public, standalone)
├── .github/workflows/
│   ├── build-release-simple.yml     # Public CI/CD
│   └── sync-to-aitherlab.yml       # Auto-sync to private
├── aither-core/modules/RepoSync/    # Sync management
└── sync-repos.ps1                   # Manual sync script

aitherlab (private, original)
├── .github/workflows/              # Private CI/CD  
├── [private files]                 # Keep sensitive data here
└── [synced from AitherZero]        # Public code synced here
```

## Security Features

- ✅ **Automatic exclusion** of sensitive files during sync
- ✅ **One-way sync by default** (public → private)
- ✅ **Manual control** over what gets synced
- ✅ **PR-based review** for all sync operations
- ✅ **No secrets exposed** in public repository

## Troubleshooting

### Sync Fails
```powershell
# Check git status and remotes
git status
git remote -v

# Reset sync state
git fetch --all
.\sync-repos.ps1 -Action Status
```

### GitHub Actions Fails
- Check that `AITHERLAB_SYNC_TOKEN` secret is set
- Verify token has access to both repositories
- Check Actions logs for specific error messages

### Merge Conflicts
```powershell
# Manual resolution
git fetch aitherlab
git merge aitherlab/main
# Resolve conflicts, then:
git commit -m "Resolve sync conflicts"
```

## Benefits of This Setup

✅ **Public visibility** for AitherZero without exposing private code  
✅ **Controlled sharing** - choose what to make public/private  
✅ **Easy collaboration** - public repo for community contributions  
✅ **Protected IP** - sensitive code stays in private aitherlab  
✅ **Automated workflows** - minimal manual sync overhead  
✅ **Git history preserved** - no loss of commit history  

This setup gives you the best of both worlds: public collaboration with private code protection.
