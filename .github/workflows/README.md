# AitherZero GitHub Actions Workflows

This directory contains the GitHub Actions workflows for AitherZero.

## Workflows

### 🚀 Manual Release Creator (`manual-release.yml`)
**Recommended method for creating releases**
- Triggers: Manual dispatch only
- Uses PatchManager's `Invoke-ReleaseWorkflow` internally
- Handles version updates, PR creation, tag creation automatically
- Options for auto-merge and waiting for merge

### 📦 Build & Release Pipeline (`build-release.yml`)
- Triggers: Version tags (v*) and manual dispatch
- Creates release artifacts for all platforms and profiles
- Automatically publishes GitHub releases with artifacts

### 🧪 Intelligent CI/CD Pipeline (`intelligent-ci.yml`)
- Triggers: Push to main/develop, PRs, manual dispatch
- Smart change detection and targeted testing
- Cross-platform validation
- Security analysis

### 🏷️ PR Auto-Labeling (`pr-labels.yml`)
- Triggers: PR opened/edited/synchronized  
- Automatically labels PRs based on title and content
- Adds size labels based on change count

### 📚 Documentation & Sync Pipeline (`documentation.yml`)
- Triggers: Documentation changes, daily schedule, manual dispatch
- API documentation generation
- Repository synchronization

## Creating Releases

The recommended way to create releases is:

1. **Via Command Line:**
   ```powershell
   Import-Module ./aither-core/modules/PatchManager -Force
   Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Bug fixes"
   ```

2. **Via GitHub Actions UI:**
   - Go to Actions → Manual Release Creator
   - Click "Run workflow"
   - Select release type and enter description

## Important Notes

- Do NOT manually update VERSION files or create tags
- Always use the automated workflows to ensure consistency
- The old `auto-release-on-merge.yml` has been removed to simplify the process
- All releases should go through `Invoke-ReleaseWorkflow`