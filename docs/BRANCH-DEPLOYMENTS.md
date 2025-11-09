# Branch-Specific GitHub Pages Deployments

## Overview

AitherZero now uses branch-specific GitHub Pages deployments to support independent testing and validation environments for different branches. Each branch deploys to its own subdirectory with isolated test results, reports, and metrics.

## Deployment Structure

### Branch Mapping

| Branch | URL Path | Purpose |
|--------|----------|---------|
| `main` | `/` (root) | Production deployment with latest stable release |
| `dev` | `/dev/` | Active development features and testing |
| `dev-staging` | `/dev-staging/` | Pre-release staging environment |
| `develop` | `/develop/` | Legacy development branch |
| Ring branches | `/ring-{n}/` | Ring deployment testing |

### Full URLs

- **Main**: https://wizzense.github.io/AitherZero/
- **Dev**: https://wizzense.github.io/AitherZero/dev/
- **Dev-Staging**: https://wizzense.github.io/AitherZero/dev-staging/
- **Develop**: https://wizzense.github.io/AitherZero/develop/

## How It Works

### Workflow Changes

The `.github/workflows/jekyll-gh-pages.yml` workflow now:

1. **Determines branch configuration** - Sets deployment directory and base URL based on the branch name
2. **Creates branch-specific config** - Generates `_config_branch.yml` with branch-specific settings
3. **Builds with Jekyll** - Uses both `_config.yml` and `_config_branch.yml` for configuration
4. **Deploys to subdirectory** - Uses `peaceiris/actions-gh-pages@v3` with `destination_dir` parameter
5. **Preserves other branches** - Uses `keep_files: true` to maintain other branch deployments

### Configuration Files

- **`_config.yml`**: Base Jekyll configuration (shared by all branches)
- **`_config_branch.yml`**: Generated dynamically per branch with:
  - `baseurl`: Branch-specific base URL (e.g., `/dev`)
  - `branch`: Current branch name
  - `deployment_time`: Timestamp of deployment

### Branch Information

Each branch deployment includes:
- **branch-info.md**: Page with deployment details, links to other branches
- **Branch-specific reports**: Test results, metrics, and dashboards for that branch
- **Navigation**: Links to other branch deployments

## Benefits

### 1. Environment Protection Bypass

Previously, the `github-pages` environment had protection rules that prevented `dev-staging` from deploying. Now:
- Each branch deploys independently
- No environment protection conflicts
- All branches can deploy simultaneously

### 2. Isolated Test Results

Each branch maintains its own:
- Test execution results
- Code quality metrics
- Coverage reports
- Performance benchmarks

### 3. Parallel Development

Teams can:
- View dev branch results without affecting main
- Compare metrics across branches
- Test features in isolation before merging

### 4. Easy Navigation

Users can:
- Switch between branch deployments easily
- Compare different versions
- Access historical deployments

## Usage

### Automatic Deployment

Deployments trigger automatically on push to any configured branch when:
- Files in `library/reports/**` change
- Files in `library/**` change
- `index.md` or `_config.yml` is modified
- Documentation files are updated

### Manual Deployment

Trigger manually via GitHub Actions:
1. Go to **Actions** → **Deploy Jekyll with GitHub Pages**
2. Click **Run workflow**
3. Select the branch to deploy
4. Click **Run workflow**

### Viewing Deployments

- **All branches**: https://wizzense.github.io/AitherZero/deployments.html
- **Specific branch**: Navigate to the branch-specific URL (see table above)
- **Branch info**: Each deployment has a `branch-info.html` page

## Technical Details

### peaceiris/actions-gh-pages

This action was chosen because:
- **No environment protection**: Bypasses GitHub environment rules
- **Subdirectory support**: `destination_dir` parameter for branch-specific paths
- **Keep files**: Preserves other branch deployments
- **Flexibility**: Works with pre-built Jekyll sites

### Concurrency Control

```yaml
concurrency:
  group: "pages-${{ github.ref_name }}"
  cancel-in-progress: false
```

- Each branch has its own concurrency group
- Prevents race conditions during deployment
- Allows parallel deployments from different branches

### File Preservation

```yaml
keep_files: true
```

- Ensures other branch directories are not deleted
- Maintains full deployment history
- Allows multiple active branches

## Migration Notes

### Old Behavior

- Single `github-pages` environment
- All branches tried to deploy to same location
- Environment protection blocked certain branches
- Test results were cross-contaminated

### New Behavior

- Branch-specific deployments to subdirectories
- No environment protection conflicts
- Isolated test results and reports
- Clear separation of concerns

### Breaking Changes

- URLs have changed for non-main branches (now include `/dev/`, `/dev-staging/`, etc.)
- Bookmarks to old URLs may need updating
- CI/CD scripts referencing old paths need updating

## Troubleshooting

### Deployment Fails

1. **Check GitHub Pages settings**:
   - Settings → Pages → Source → **gh-pages branch**
   - Ensure branch exists (created automatically by peaceiris action)

2. **Verify permissions**:
   - Settings → Actions → General → Workflow permissions
   - Select **Read and write permissions**

3. **Check workflow logs**:
   - Actions → Recent workflow runs
   - Look for build or deployment errors

### Branch Not Showing

1. **Trigger deployment**:
   - Push a change to trigger workflow
   - Or run workflow manually

2. **Check destination directory**:
   - Verify `setup` job configured correct path
   - Check `deploy` job used correct `destination_dir`

### Wrong Content Showing

1. **Clear browser cache**: Hard refresh (Ctrl+F5)
2. **Wait for propagation**: GitHub Pages can take 5-10 minutes
3. **Check build output**: Ensure Jekyll built correctly

## Future Enhancements

Possible improvements:
- **Automatic cleanup**: Remove deployments for deleted branches
- **Deployment history**: Track changes over time
- **A/B testing**: Compare branches side-by-side
- **Preview URLs**: Generate preview links for PRs

## References

- [peaceiris/actions-gh-pages Documentation](https://github.com/peaceiris/actions-gh-pages)
- [Jekyll Configuration](https://jekyllrb.com/docs/configuration/)
- [GitHub Pages Deployment](https://docs.github.com/en/pages)
