# Branch Strategy and Release Management

## Overview

AitherZero uses a **dual-branch strategy** to protect the production `main` branch from broken merges while maintaining a smooth development workflow.

## Branch Roles

### `dev` - Development/Integration Branch
- **Purpose**: Primary integration branch for all development work
- **Protection**: Standard branch protection (require PR reviews, CI checks)
- **Merges From**: Feature branches, bug fixes, documentation updates
- **Merges To**: `main` (for releases)
- **Deployments**: 
  - ✅ Docker preview containers for PRs
  - ✅ CI/CD validation
  - ✅ Automated testing
  - ❌ No production deployments

### `main` - Production Branch
- **Purpose**: Stable, production-ready code
- **Protection**: Strict branch protection (require PR from `dev`, require reviews, all checks must pass)
- **Merges From**: `dev` branch only (via PR)
- **Merges To**: None (terminal branch)
- **Deployments**:
  - ✅ Docker `latest` tag published to registry
  - ✅ GitHub Pages documentation deployed
  - ✅ GitHub Releases created (when tagged)
  - ✅ All production artifacts

## Development Workflow

```
feature/my-feature → dev → main
     ↓                ↓      ↓
  Local Dev    Integration  Production
  Testing      Testing      Release
```

### Daily Development Flow

1. **Developer creates feature branch from `dev`**
   ```bash
   git checkout dev
   git pull origin dev
   git checkout -b feature/my-feature
   ```

2. **Developer creates PR to `dev`**
   - Automated checks run
   - Docker preview environment deployed
   - Code review happens
   - Tests validated

3. **PR merged to `dev`**
   - Integration testing continues
   - Multiple features can accumulate
   - Team validates integrated changes

4. **When ready for release, create PR from `dev` to `main`**
   - Full validation suite runs
   - Production deployment preparation
   - Final review by maintainers

5. **PR merged to `main`**
   - Automatic production release
   - Docker container published
   - Documentation deployed
   - Release notes generated

## GitHub Settings Configuration

### `dev` Branch Settings

**Branch Protection Rules:**
- [x] Require a pull request before merging
  - [x] Require approvals: 1
  - [x] Dismiss stale pull request approvals when new commits are pushed
- [x] Require status checks to pass before merging
  - [x] Require branches to be up to date before merging
  - Required checks:
    - PR Validation
    - Quality Validation
    - Syntax Check
- [x] Require conversation resolution before merging
- [ ] Do not allow bypassing the above settings (maintainers can merge if needed)

**Settings:**
- [x] Set as default branch (for new PRs)

### `main` Branch Settings

**Branch Protection Rules:**
- [x] Require a pull request before merging
  - [x] Require approvals: 2 (stricter than dev)
  - [x] Dismiss stale pull request approvals when new commits are pushed
  - [x] Require review from Code Owners
- [x] Require status checks to pass before merging
  - [x] Require branches to be up to date before merging
  - Required checks:
    - PR Validation
    - Quality Validation
    - Release Validation
    - All tests
- [x] Require conversation resolution before merging
- [x] Do not allow bypassing the above settings (strict enforcement)
- [x] Restrict who can push to matching branches
  - Only: Maintainers team

**Settings:**
- [ ] Not the default branch (dev is default)

## Automation Behavior

### Workflow Triggers

**PRs to `dev` branch:**
- ✅ Syntax validation
- ✅ Unit tests
- ✅ Code quality checks
- ✅ Docker preview deployment
- ✅ Security scanning

**PRs to `main` branch:**
- ✅ All checks from `dev` PRs
- ✅ Integration tests
- ✅ Release validation
- ✅ Changelog generation
- ⚠️ No preview deployment (production ready only)

**Push to `main` branch:**
- ✅ Build production Docker container
- ✅ Push to registry with `latest` tag
- ✅ Deploy documentation to GitHub Pages
- ✅ Generate artifacts

**Push to `dev` branch:**
- ✅ Integration validation
- ✅ Documentation updates (no deployment)
- ✅ Index regeneration
- ❌ No production deployments

### Script Defaults

- `0701_Create-FeatureBranch.ps1` - Branches from `dev`
- `0703_Create-PullRequest.ps1` - Targets `dev` by default
- GitHub CLI `gh pr create` - Should target `dev` (configured in repo settings)

## Release Management

### Regular Release (Recommended)

```bash
# 1. Ensure dev is ready
git checkout dev
git pull origin dev

# 2. Run validation
./az.ps1 0402  # Tests
./az.ps1 0404  # Quality

# 3. Update version if needed
echo "1.2.3" > VERSION

# 4. Create release PR
gh pr create --base main --title "Release v1.2.3" --body "$(cat CHANGELOG.md)"

# 5. Wait for approval and merge
# (Automatic deployment will trigger)
```

### Tagged Release

For versioned releases with full release notes:

```bash
# 1. After merging to main
git checkout main
git pull origin main

# 2. Tag the release
git tag -a v1.2.3 -m "Release v1.2.3"
git push origin v1.2.3

# 3. Release workflow automatically:
#    - Creates GitHub Release
#    - Generates release notes
#    - Builds versioned Docker container
#    - Publishes artifacts
```

### Hotfix Process

For critical production issues only:

```bash
# 1. Create hotfix from main
git checkout main
git pull origin main
git checkout -b hotfix/critical-fix

# 2. Make minimal fix
# ... edit files ...
git commit -m "fix: critical production issue"

# 3. Create PR to main (requires maintainer override)
gh pr create --base main --title "Hotfix: Critical production issue"

# 4. After merge to main, backport to dev
git checkout dev
git pull origin dev
git merge main
git push origin dev
```

## Monitoring

### Key Metrics

- **PR Merge Rate**: Track how quickly PRs are reviewed and merged
- **Build Success Rate**: Monitor CI/CD pipeline health
- **Test Coverage**: Ensure coverage doesn't decrease
- **Deployment Frequency**: Track releases to production

### Health Checks

Weekly review:
- [ ] Are PRs targeting `dev` by default?
- [ ] Is `main` only receiving merges from `dev`?
- [ ] Are all CI checks passing on both branches?
- [ ] Are preview deployments working for `dev` PRs?
- [ ] Are production deployments successful from `main`?

## Troubleshooting

### "Cannot create PR - base branch is main instead of dev"

**Solution**: Update local configuration or use automation scripts:
```bash
./az.ps1 0703 -Title "My Feature"  # Automatically targets dev
```

### "Merge conflict when promoting dev to main"

**Solution**: This should rarely happen. If it does:
1. Create a sync branch: `git checkout -b sync-dev-to-main dev`
2. Merge main: `git merge main`
3. Resolve conflicts
4. Create PR to main

### "Hotfix needed but dev has unreleased features"

**Solution**: Use hotfix process (branch from main, merge to main, backport to dev)

### "Preview deployment failed for dev PR"

**Solution**: Check workflow logs, ensure PR is not a draft, verify no conflicts

## Migration Notes

### Initial Setup

When first implementing this strategy:

1. **Create `dev` branch from current `main`**
   ```bash
   git checkout main
   git pull origin main
   git checkout -b dev
   git push origin dev
   ```

2. **Update GitHub repo settings**
   - Set `dev` as default branch
   - Apply branch protection rules (see above)

3. **Notify team**
   - Share CONTRIBUTING.md
   - Update README with new workflow
   - Train on automation scripts

4. **Monitor first week**
   - Ensure PRs go to correct branch
   - Check automation works as expected
   - Address any issues quickly

### Transitioning Existing PRs

For open PRs targeting `main`:
1. Ask contributors to retarget to `dev`
2. Or: Merge to `main`, then sync `dev` from `main`
3. Update PR description templates to mention `dev`

## Benefits of This Strategy

1. **Protected Production**: `main` stays stable, broken code can't reach production
2. **Integration Testing**: `dev` serves as integration branch before release
3. **Flexible Releases**: Multiple features can be tested together before releasing
4. **Easy Rollback**: Can revert changes in `dev` without affecting production
5. **Clear Process**: Simple mental model - develop in `dev`, release from `main`

## See Also

- [CONTRIBUTING.md](CONTRIBUTING.md) - Contributor guide
- [.github/workflows/](. github/workflows/) - CI/CD workflow definitions
- [automation-scripts/070x](automation-scripts/) - Git automation scripts
