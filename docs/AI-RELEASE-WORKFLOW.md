# AI Agent Guide: Automatic Release Workflow

## Overview
AitherZero now supports automatic releases when PRs are merged. This guide helps AI agents understand and use the release workflow effectively.

## Quick Reference

### Creating Features with Releases
```powershell
# Patch release (bug fixes) - DEFAULT
New-Feature -Description "Fix null reference bug" -Changes { ... }
New-Patch -Description "Update error handling" -Changes { ... }

# Minor release (new features)
New-Feature -Description "Add OAuth authentication" -ReleaseType "minor" -Changes { ... }

# Major release (breaking changes) - USE CAREFULLY
New-Feature -Description "Rewrite API v2.0" -ReleaseType "major" -Changes { ... }
```

### Release Type Selection Guide

| Scenario | Release Type | Version Change | Example |
|----------|--------------|----------------|---------|
| Bug fixes, typos | `patch` (default) | 0.5.4 → 0.5.5 | Fix null reference |
| New features | `minor` | 0.5.4 → 0.6.0 | Add new module |
| Breaking changes | `major` | 0.5.4 → 1.0.0 | Change API structure |

## AI Decision Tree

```
Is this a breaking change?
├─ YES → Use ReleaseType "major"
└─ NO → Does it add new functionality?
    ├─ YES → Use ReleaseType "minor"
    └─ NO → Use ReleaseType "patch" (or omit for default)
```

## Examples for Common Scenarios

### 1. Fixing a Bug
```powershell
New-Patch -Description "Fix PowerShell 5.1 compatibility issue" -Changes {
    # Fix code here
}
# Creates PR with release:patch label → 0.5.4 → 0.5.5
```

### 2. Adding a Feature
```powershell
New-Feature -Description "Add progress tracking to setup wizard" -ReleaseType "minor" -Changes {
    # Add new feature
}
# Creates PR with release:minor label → 0.5.4 → 0.6.0
```

### 3. Emergency Hotfix
```powershell
New-Hotfix -Description "Fix critical security vulnerability" -Changes {
    # Security fix
}
# Creates PR with release:patch label (default for hotfixes)
```

### 4. Breaking Change (Rare)
```powershell
New-Feature -Description "Migrate to new configuration format" -ReleaseType "major" -Changes {
    # Breaking changes
}
# Creates PR with release:major label → 0.5.4 → 1.0.0
```

## How It Works

1. **You create PR** with release label using PatchManager functions
2. **User reviews and merges** the PR
3. **GitHub Action triggers** automatically on merge
4. **Version bumps** according to release type
5. **Tag created** triggering build pipeline
6. **Release artifacts** built and published

## Best Practices for AI Agents

### DO:
- ✅ Default to patch releases (safest)
- ✅ Use minor for new features that don't break existing code
- ✅ Include clear descriptions of changes
- ✅ Let the user review before merge

### DON'T:
- ❌ Use major releases without explicit user request
- ❌ Skip ReleaseType when user mentions version changes
- ❌ Create multiple PRs for related changes

## Understanding User Intent

| User Says | Likely Means | Use |
|-----------|--------------|-----|
| "fix this bug" | Patch release | `patch` or default |
| "add this feature" | Minor release | `minor` |
| "implement X support" | Minor release | `minor` |
| "redesign the API" | Major release | `major` |
| "quick fix" | No release | `New-QuickFix` |

## Workflow Commands

### Check Current Version
```powershell
Get-Content VERSION
```

### See Recent Releases
```bash
git tag -l "v*" | tail -5
```

### Manual Release (if needed)
```powershell
Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Manual release"
```

## Common Patterns

### Pattern 1: Feature Development
```powershell
# User: "Add support for JSON configuration files"
New-Feature -Description "Add JSON configuration support" -ReleaseType "minor" -Changes {
    Add-JsonConfigSupport
}
```

### Pattern 2: Bug Fix
```powershell
# User: "The module loader is broken on Linux"
New-Patch -Description "Fix module loader on Linux" -Changes {
    Fix-LinuxModuleLoader
}
```

### Pattern 3: Multiple Related Changes
```powershell
# User: "Update all error handling"
New-Feature -Description "Overhaul error handling system" -ReleaseType "minor" -Changes {
    Update-ErrorHandling
    Add-ErrorLogging
    Improve-ErrorMessages
}
```

## Release Label Reference

- `release:patch` - Bug fixes, minor improvements (0.0.X)
- `release:minor` - New features, enhancements (0.X.0)
- `release:major` - Breaking changes (X.0.0)

## Troubleshooting

**Q: What if I forgot to add ReleaseType?**
A: Default is patch (safe). User can change label before merging.

**Q: Can I change release type after PR creation?**
A: Yes, labels can be edited on GitHub before merge.

**Q: What about multiple PRs with different release types?**
A: Highest release type wins (major > minor > patch).

## Integration with IDEs

VS Code tasks support ReleaseType:
- "Create Feature PR (Minor Release)"
- "Create Patch PR (Bug Fix)"
- "Create Major Release PR"

---

Remember: When in doubt, use patch release or ask the user!