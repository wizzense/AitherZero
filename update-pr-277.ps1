$newTitle = "Release v0.5.4 + Automatic Release Workflow"
$newBody = @"
## 🚀 Release v0.5.4 + Automatic Release Workflow Implementation

This PR combines:
1. **Version 0.5.4 Release** - Includes all PatchManager v3.0 fixes
2. **Automatic Release Workflow** - Complete implementation of automatic versioning on PR merge

### Release v0.5.4 Changes
- ✅ Fixed PatchManager v3.0 PR/Issue creation  
- ✅ Fixed cross-platform git detection
- ✅ Connected TODO placeholders to actual functions
- ✅ Added git push functionality
- ✅ Fixed branch name extraction

### Automatic Release Workflow Features
- ✅ Added ReleaseType parameter to PatchManager functions
- ✅ PRs now include release metadata and labels
- ✅ Created auto-release-on-merge.yml GitHub Action
- ✅ Comprehensive AI-friendly documentation

### How It Works
1. Create PR with release type: ``New-Feature -ReleaseType "minor"``
2. PR gets labeled with ``release:minor``
3. When merged, GitHub Action automatically:
   - Bumps VERSION file
   - Creates release tag
   - Triggers build pipeline

### Files Changed
- PatchManager modules (New-Feature, New-Patch, New-Hotfix)
- New-PatchPR (adds release labels and metadata)
- .github/workflows/auto-release-on-merge.yml (new)
- docs/AI-RELEASE-WORKFLOW.md (new)
- VERSION (bumped to 0.5.4)

### Testing
- ✅ Tested ReleaseType parameter integration
- ✅ Verified PR label creation
- ✅ Confirmed release metadata in PR body

---
**Note**: This PR replaces #273 and includes all its changes.
"@

gh pr edit 277 --title $newTitle --body $newBody