# Quick Start: Make v1.0.0.0 the Official Release

This guide provides the fastest way to clean up all old releases and tags, making v1.0.0.0 the official first release of AitherZero.

## 🎯 Goal

- **Keep**: v1.0.0.0 only
- **Remove**: 45 tags and 39 releases (all versions before and after v1.0.0.0)

## ⚡ Quick Start (2 minutes)

### Step 1: Preview Changes (Dry Run)

1. Go to: https://github.com/wizzense/AitherZero/actions/workflows/release-cleanup-v1.yml
2. Click the **"Run workflow"** button (top right)
3. Leave **"Dry run mode"** ✅ checked
4. Click **"Run workflow"** button
5. Wait ~30 seconds for completion
6. Review the output to see what would be deleted

### Step 2: Execute Cleanup

1. Click **"Run workflow"** button again
2. **Uncheck** "Dry run mode" ❌
3. Type **`CONFIRM`** in the "confirm" field
4. Click **"Run workflow"** button
5. Wait ~1-2 minutes for completion
6. Verify success ✅

### Step 3: Verify Results

Check that only v1.0.0.0 remains:

```bash
# View releases
https://github.com/wizzense/AitherZero/releases

# View tags
https://github.com/wizzense/AitherZero/tags
```

## 📊 What Gets Removed

**45 Tags:**
```
v0.0.0.0, v0.5-beta, v0.5.1, v0.5.2, v0.5.3
v0.6.1 through v0.6.31 (21 tags)
v0.7.0, v0.7.1, v0.7.3, v0.7.4
v1.0.4, v1.0.7
vdev-9ad2748, vdev-0727a8b, vdev-ce297e2, vdev-da820a7, vdev-e781469, vdev-fd8f282
```

**39 GitHub Releases:**
All releases corresponding to the above tags.

## 🛡️ Safety Features

✅ **Dry run first** - See exactly what will be deleted
✅ **Explicit confirmation** - Must type "CONFIRM" to proceed
✅ **Reversible** - Tags can be recreated if needed (releases cannot)
✅ **No code changes** - Commit history remains unchanged

## 🔧 Alternative: PowerShell Script

If you prefer local execution or the workflow fails:

```powershell
# Preview changes
./tools/Invoke-ReleaseCleanup.ps1 -DryRun

# Execute cleanup
./tools/Invoke-ReleaseCleanup.ps1
```

**Requirements**: PowerShell 7+, GitHub CLI (`gh`) authenticated

## 📚 Full Documentation

For complete details, see: [`docs/RELEASE-1.0.0-CLEANUP.md`](./RELEASE-1.0.0-CLEANUP.md)

## ❓ Troubleshooting

**Q: Workflow not appearing in Actions tab?**
- Wait a few minutes after PR merge for GitHub to index the new workflow

**Q: Workflow fails with permission error?**
- Ensure you have write access to the repository
- Check that Actions has write permissions in repository settings

**Q: Want to undo the cleanup?**
- Tags can be recreated: `git tag v0.x.x <commit-sha> && git push origin v0.x.x`
- Releases cannot be restored (draft releases might be recoverable)

## ✅ Success Criteria

After completion, you should see:
- ✅ Only 1 tag: `v1.0.0.0`
- ✅ Only 1 release: `v1.0.0.0`
- ✅ Workflow shows "CLEANUP COMPLETE" message
- ✅ No errors in workflow logs

---

**Estimated time**: 2-3 minutes total (including dry run verification)
