# Comment-Triggered Releases

## Overview

You can now create releases directly from pull requests using simple comments! No need to manually push tags or run workflows.

## Quick Start

Simply comment on any pull request with:

```
/release v1.2.3
```

That's it! The system will automatically:
1. ✅ Validate the version
2. 📝 Update version files
3. 🏷️ Create and push the git tag
4. 🚀 Trigger release workflows
5. 🐳 Build Docker images
6. 📦 Create GitHub Release

## Commands

### Stable Release
```
/release v1.2.3
```
or
```
@copilot release v1.2.3
```

### Pre-release
```
/release v1.2.3 --pre
```
or
```
/release v1.2.3 --prerelease
```

### Version Formats
All of these work:
- `/release v1.2.3` (recommended)
- `/release 1.2.3` (without 'v' prefix)
- `/release v1.2.3-beta.1` (with pre-release suffix)

## What Happens

### Step 1: Comment Detection
When you post a comment starting with `/release` or `@copilot release`, the workflow activates.

### Step 2: Version Validation
The system checks:
- ✅ Version follows semantic versioning (X.Y.Z)
- ✅ Tag doesn't already exist
- ✅ Version format is valid

### Step 3: Automatic Updates
The workflow:
- Updates `VERSION` file
- Updates `AitherZero.psd1` ModuleVersion
- Commits changes to the PR branch
- Creates annotated git tag
- Pushes tag to trigger releases

### Step 4: Release Automation
Two workflows automatically trigger:
- **release-automation.yml**: Creates GitHub Release with packages
- **docker-publish.yml**: Builds and publishes Docker images

### Step 5: Notifications
You'll receive a comment with:
- ✅ Success confirmation
- 🔗 Links to workflow runs
- 🔗 Link to the release page
- 🐳 Docker pull command

## Examples

### Example 1: Standard Release
```
/release v1.3.0
```

**Result:**
- VERSION updated to `1.3.0`
- Tag `v1.3.0` created
- GitHub Release created
- Docker images: `ghcr.io/wizzense/aitherzero:v1.3.0`, `:1.3`, `:1`, `:latest`

### Example 2: Pre-release
```
/release v1.4.0-beta.1 --pre
```

**Result:**
- VERSION updated to `1.4.0-beta.1`
- Tag `v1.4.0-beta.1` created
- GitHub Release marked as pre-release
- Docker images: `ghcr.io/wizzense/aitherzero:v1.4.0-beta.1`

### Example 3: Using @copilot
```
@copilot release v2.0.0
```

**Result:**
Same as `/release v2.0.0` - both syntaxes work!

## Workflow Integration

### Workflow: comment-release.yml

**Triggers:**
- Pull request comments containing `/release` or `@copilot release`

**Permissions Required:**
- `contents: write` - For creating tags and updating files
- `pull-requests: write` - For posting comments
- `issues: write` - For reacting to comments

**Jobs:**
1. **check-release-command**: Parses comment and validates format
2. **trigger-release**: Creates tag and triggers release workflows
3. **show-usage**: Shows help if command format is wrong

### Integration with Existing Workflows

The comment-triggered release seamlessly integrates with:
- `release-automation.yml` - Triggered by the created tag
- `docker-publish.yml` - Triggered by the created tag
- All existing pre-release validation and packaging

## Error Handling

### Invalid Version Format
```
/release invalid
```
**Error:** "Invalid version format: invalid"
**Solution:** Use semantic versioning (X.Y.Z)

### Tag Already Exists
```
/release v1.0.0
```
**Error:** "Tag v1.0.0 already exists"
**Solution:** Use a new version number

### No Version Specified
```
/release
```
**Response:** Usage instructions posted as comment

## Security

### Who Can Trigger Releases?

- Only users with write access to the repository
- Comments on pull requests from forks require approval
- GitHub Actions permission model enforces security

### What's Protected?

- ✅ Version validation prevents invalid versions
- ✅ Duplicate tag check prevents overwrites
- ✅ Git configuration uses bot account
- ✅ Token permissions are scoped appropriately

## Monitoring

### Watch Release Progress

After triggering a release, monitor:

1. **Workflow Runs:**
   - Go to Actions tab
   - Look for "Comment-Triggered Release"
   - Check "Release Automation"
   - Check "Docker Publishing"

2. **Release Page:**
   - Navigate to Releases
   - Find your version
   - Download artifacts or pull Docker images

3. **PR Comments:**
   - Success/failure notification posted automatically
   - Links provided to relevant resources

## Troubleshooting

### Release Didn't Trigger

**Check:**
1. Is the comment on a pull request (not an issue)?
2. Does the comment start with `/release` or `@copilot release`?
3. Is the version format correct (X.Y.Z)?

### Version Not Updated

**Check:**
1. Does the PR branch have conflicts?
2. Are the VERSION and AitherZero.psd1 files present?
3. Check workflow logs for specific errors

### Tag Created But Release Failed

**Solution:**
- The tag exists, so release workflows should have triggered
- Check the release-automation.yml workflow logs
- If validation failed, the pre-release checks may have issues

## Comparison: Manual vs Comment-Triggered

### Manual Process (Old Way)
```bash
# 1. Update version files manually
vim VERSION
vim AitherZero.psd1

# 2. Commit changes
git add VERSION AitherZero.psd1
git commit -m "chore: bump version to v1.2.3"
git push

# 3. Create and push tag
git tag -a v1.2.3 -m "Release v1.2.3"
git push origin v1.2.3

# 4. Wait for workflows
# 5. Monitor multiple places
```

**Time:** ~5-10 minutes  
**Steps:** 5-7 commands  
**Complexity:** Medium

### Comment-Triggered (New Way)
```
/release v1.2.3
```

**Time:** ~30 seconds  
**Steps:** 1 comment  
**Complexity:** Low

## Benefits

✅ **Faster:** One comment vs multiple commands  
✅ **Simpler:** No git expertise required  
✅ **Safer:** Validation prevents mistakes  
✅ **Transparent:** All actions logged and commented  
✅ **Integrated:** Works with existing PR workflow  
✅ **Flexible:** Supports both stable and pre-releases

## Best Practices

### Before Triggering Release

1. ✅ Ensure PR is approved and ready to merge
2. ✅ All CI checks are passing
3. ✅ Documentation is updated
4. ✅ CHANGELOG is ready (or will be auto-generated)
5. ✅ Version number follows semantic versioning

### After Triggering Release

1. 👀 Monitor the comment for confirmation
2. 🔍 Check workflow runs complete successfully
3. ✅ Verify release appears on Releases page
4. 🐳 Test Docker image: `docker pull ghcr.io/wizzense/aitherzero:vX.Y.Z`
5. 📝 Optionally update release notes on GitHub

### Versioning Guidelines

- **Patch (X.Y.Z):** Bug fixes, no new features
- **Minor (X.Y.0):** New features, backward compatible
- **Major (X.0.0):** Breaking changes, incompatible API changes
- **Pre-release:** Use `-beta.N`, `-rc.N`, `-alpha.N` suffixes

## FAQ

**Q: Can I trigger releases from any branch?**  
A: No, only from pull request comments. The tag is created on the PR's branch.

**Q: What if I make a typo in the version?**  
A: The workflow validates the version. If invalid, you'll get an error comment with instructions.

**Q: Can I cancel a release?**  
A: Once the tag is pushed, the release workflows trigger. You'd need to delete the tag and release manually if needed.

**Q: Does this work with forks?**  
A: Comments from fork PRs require approval from maintainers with write access.

**Q: Can I see a history of comment-triggered releases?**  
A: Yes, check the Actions tab for "Comment-Triggered Release" workflow runs.

**Q: Is this secure?**  
A: Yes, GitHub's permission model ensures only authorized users can trigger releases.

## Related Documentation

- [Release Process Guide](RELEASE-PROCESS.md) - Complete release procedures
- [Docker Publishing](.github/workflows/docker-publish.yml) - Docker image workflow
- [Release Automation](.github/workflows/release-automation.yml) - Release workflow

---

**Last Updated:** 2025-10-29  
**Feature Added:** v1.1.0
