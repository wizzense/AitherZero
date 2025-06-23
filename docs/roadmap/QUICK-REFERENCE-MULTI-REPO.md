# Quick Reference: Multi-Repository Workflow

## ✅ Correct Git Remote Setup

### AitherZero (Your Development Fork)
```text
origin      https://github.com/wizzense/AitherZero.git (fetch/push)
upstream    https://github.com/Aitherium/AitherLabs.git (fetch/push)
aitherium   https://github.com/Aitherium/Aitherium.git (fetch/push)
```

### Repository Purposes

| Repository | Purpose | Development Role |
|------------|---------|------------------|
| **AitherZero** | Personal development fork | ✅ Primary development location |
| **AitherLabs** | Public staging/testing | 📋 Testing, staging, community |
| **Aitherium** | Premium/enterprise | 🎯 Production, enterprise features |

## 🚀 Quick Commands

### Start New Feature
```powershell
cd "c:/Users/alexa/OneDrive/Documents/0. wizzense/AitherZero"
git checkout main
git pull upstream main
git checkout -b feature/your-feature-name
# ... develop ...
git add .
git commit -m "Your feature description"
git push origin feature/your-feature-name
```

### Create PR to Public Staging
```powershell
gh pr create --repo Aitherium/AitherLabs --base main --head wizzense:feature/your-feature-name
```

### Sync Your Fork
```powershell
git fetch --all
git checkout main
git pull upstream main
git push origin main
```

### Create Premium Feature
```powershell
git checkout main
git pull upstream main
git checkout -b premium/enterprise-feature
# ... add enterprise enhancements ...
git add .
git commit -m "Add enterprise version of feature"
git push origin premium/enterprise-feature
gh pr create --repo Aitherium/Aitherium --base main --head wizzense:premium/enterprise-feature
```

## 📁 Directory Structure

```text
c:/Users/alexa/OneDrive/Documents/0. wizzense/
├── AitherZero/     ← 🎯 PRIMARY DEVELOPMENT (work here)
├── AitherLabs/     ← 📋 Staging/testing (reference only)
└── Aitherium/      ← 🔒 Premium (reference/review only)
```

## 🔧 Enhanced Kicker-Git Usage

From your **AitherZero** directory:

```powershell
# Quick status check
./kicker-git-enhanced.ps1 -Mode Lightweight

# Full multi-repo sync
./kicker-git-enhanced.ps1 -Mode Full

# Development mode with verbose output
./kicker-git-enhanced.ps1 -Mode Dev
```

## ⚠️ Important Rules

1. **Always develop in AitherZero** - never directly in AitherLabs or Aitherium
2. **All PRs originate from AitherZero** branches
3. **Sync regularly** with upstream (AitherLabs) to stay current
4. **Premium features** get their own branches and separate PRs
5. **Use descriptive branch names** that indicate the target (feature/, premium/, etc.)

## 🎯 Current Status: ✅ CORRECTLY CONFIGURED

Your multi-repository workflow is now properly set up and tested!
