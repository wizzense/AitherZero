# How to Republish a Failed Release with Proper Release Assets

## 📋 Background

Sometimes a release workflow may be cancelled or fail before it can upload release assets (ZIP/TAR.GZ packages). This guide shows you how to re-trigger the release process to attach the missing assets.

**Example:** The v1.0.0.0 release was created successfully, but the workflow was cancelled before it could upload release assets.

## ✅ The Release Workflow is Working

Good news: The release automation workflow (`release-automation.yml`) is correctly configured and functional. It creates:
- ✅ `AitherZero-v{version}.zip` - Windows compatible package
- ✅ `AitherZero-v{version}.tar.gz` - Unix/Linux/macOS compatible package
- ✅ `build-info.json` - Build metadata and version information
- ✅ Comprehensive release notes with changelog and installation instructions

## 🚀 Solution: Re-trigger the Release Workflow

You have **three options** to republish the release with proper assets:

### Option 1: Manual Workflow Trigger ⭐ RECOMMENDED

This is the **easiest and safest** method:

1. **Navigate to GitHub Actions**
   - Go to https://github.com/wizzense/AitherZero/actions
   - Click on **"Release Automation"** workflow

2. **Trigger the workflow**
   - Click the **"Run workflow"** button (top right)
   - Fill in the form:
     - **Use workflow from:** Select the release tag (e.g., `v1.0.0.0`) **NOT** `main`
       - ⚠️ **IMPORTANT**: You must select the tag to ensure the release assets match the tagged code
     - **Release version:** Enter the version number without 'v' prefix (e.g., `1.0.0.0`)
     - **Mark as pre-release:** `false` (unchecked for stable releases)
     - **Run comprehensive tests:** `false` (unchecked - code already validated)

3. **Click "Run workflow"**

4. **Monitor the workflow**
   - The workflow will take ~5-10 minutes
   - It will create packages and attach them to the existing release
   - Check the "Actions" tab to see progress

**Why this works:**
- The `softprops/action-gh-release@v2` action automatically updates existing releases
- Running from the tag ensures artifacts match the tagged code
- No need to delete/recreate tags
- Preserves the original release timestamp and description

**Critical Note:**
> ⚠️ Always run the workflow from the release tag (e.g., `v1.0.0.0`), not from `main`. Running from `main` will package the current state of main, which may include changes made after the tag was created, resulting in mislabeled release assets.

---

### Option 2: Use GitHub CLI

If you have the GitHub CLI installed:

```bash
# Run workflow from the specific tag (IMPORTANT!)
gh workflow run release-automation.yml \
  --ref vX.Y.Z \
  -f version=X.Y.Z \
  -f prerelease=false \
  -f run_full_tests=false
```

Replace `X.Y.Z` with your version number (e.g., `1.0.0.0`).

**Important:** The `--ref vX.Y.Z` flag ensures the workflow runs from the tagged commit, not from main.

Then monitor the workflow:
```bash
gh run watch
```

---

### Option 3: Delete and Recreate Tag

If you prefer the traditional approach:

```bash
# Ensure you're on main and up to date
git checkout main
git pull

# Delete existing tag (local and remote)
# Replace vX.Y.Z with your version (e.g., v1.0.0.0)
git tag -d vX.Y.Z
git push origin --delete vX.Y.Z

# Recreate the tag
git tag -a vX.Y.Z -m "Release vX.Y.Z"

# Push the tag to trigger the workflow
git push origin vX.Y.Z
```

The workflow will automatically trigger and create a new release with all assets.

**Note:** This will create a new release with a new timestamp.

---

## 📦 What Will Be Created

Once the workflow completes successfully, the release will have:

### Release Assets:
```
AitherZero-vX.Y.Z.zip           (~12-15 MB)  - Windows package
AitherZero-vX.Y.Z.tar.gz        (~4-5 MB)    - Unix/Linux/macOS package  
build-info.json                  (~1 KB)      - Build metadata
```

### Release Notes:
- Build information (version, commit, build date)
- Feature highlights
- Installation instructions (one-liner + manual)
- Quick start commands
- System requirements
- Full changelog link
- Support links

## ✅ Verification Steps

After the workflow completes:

1. **Check the release page:**
   ```
   https://github.com/wizzense/AitherZero/releases/tag/vX.Y.Z
   ```
   (Replace `vX.Y.Z` with your version, e.g., `v1.0.0.0`)

2. **Verify assets are attached:**
   - Should see 3 files (ZIP, TAR.GZ, JSON)
   - Each should have a download link

3. **Test installation (optional):**
   ```powershell
   # Windows
   $version = "1.0.0.0"  # Replace with your version
   $url = "https://github.com/wizzense/AitherZero/releases/download/v$version/AitherZero-v$version.zip"
   Invoke-WebRequest -Uri $url -OutFile "AitherZero-v$version.zip"
   Expand-Archive -Path "AitherZero-v$version.zip" -DestinationPath ./test
   ```

   ```bash
   # Linux/macOS
   VERSION="1.0.0.0"  # Replace with your version
   curl -LO "https://github.com/wizzense/AitherZero/releases/download/v${VERSION}/AitherZero-v${VERSION}.tar.gz"
   tar -xzf "AitherZero-v${VERSION}.tar.gz"
   cd "AitherZero-v${VERSION}"
   ./bootstrap.sh
   ```

## 🔍 Understanding the Issue

**What happened:**
- The release tag was created and pushed successfully
- The release automation workflow was triggered
- The workflow started but was **cancelled before completion**
- This left the GitHub release created but with no assets attached

**Why it happened:**
- Workflow was manually cancelled, OR
- Another workflow conflicted and caused cancellation, OR
- GitHub Actions runner timeout/failure

**Why it's not a code problem:**
- The workflow code is correct and functional
- The workflow has completed successfully for other releases
- The workflow will work when run to completion

## 📚 Additional Resources

- **Full Release Process:** See [docs/RELEASE-PROCESS.md](docs/RELEASE-PROCESS.md)
- **Comment-Triggered Releases:** See [docs/COMMENT-RELEASE.md](docs/COMMENT-RELEASE.md)
- **Workflow Details:** See [.github/workflows/release-automation.yml](.github/workflows/release-automation.yml)

## 🎯 Expected Timeline

- **Workflow execution:** 5-10 minutes
- **Package creation:** 2-3 minutes
- **Asset upload:** 1-2 minutes
- **Total:** ~10 minutes from trigger to completion

## ❓ Questions or Issues?

If you encounter problems:

1. **Check workflow logs:**
   ```bash
   https://github.com/wizzense/AitherZero/actions/workflows/release-automation.yml
   ```

2. **Verify workflow file:**
   - The workflow should have `workflow_dispatch` inputs configured
   - The workflow should use `softprops/action-gh-release@v2`

3. **Common issues:**
   - **Validation errors:** Set `run_full_tests=false` for re-runs
   - **Permission errors:** Check GitHub token permissions
   - **Asset conflicts:** The workflow will overwrite existing assets

4. **Get help:**
   - Open an issue: https://github.com/wizzense/AitherZero/issues
   - Check existing issues for similar problems

---

**Last Updated:** 2025-10-30  
**Status:** General guide for any failed release
