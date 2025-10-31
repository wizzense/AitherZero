# Automated Checkpoint System

## Overview

The Automated Checkpoint System creates regular, timestamped backups of your repository's main branch to facilitate easy recovery from accidental changes, deletions, or other issues.

## Features

- **Automatic Backups**: Creates checkpoint branches every 15 minutes
- **Timestamped Branches**: Uses clear naming convention `checkpoint/main/YYYYMMDD-HHMMSS`
- **Automatic Cleanup**: Removes checkpoints older than 7 days to prevent clutter
- **Manual Triggers**: Supports on-demand checkpoint creation
- **Easy Recovery**: Simple git commands to restore any directory or file

## How It Works

### Automatic Checkpoints

The system runs every 15 minutes via GitHub Actions and:

1. Checks out the latest `main` branch
2. Creates a new branch with timestamp: `checkpoint/main/YYYYMMDD-HHMMSS`
3. Pushes the checkpoint branch to origin
4. Cleans up checkpoints older than 7 days

### Manual Checkpoints

You can also create checkpoints manually:

1. Go to **Actions** → **Automated Repository Checkpoints**
2. Click **Run workflow**
3. Optionally provide a reason for the checkpoint
4. Click **Run workflow** button

## Recovery Instructions

### Restore Entire Repository

```bash
# List available checkpoints
git fetch origin
git branch -r | grep checkpoint/main/

# Restore from a specific checkpoint
CHECKPOINT_BRANCH="checkpoint/main/20251031-120000"
git checkout $CHECKPOINT_BRANCH
git checkout -b restore-from-checkpoint
git push origin restore-from-checkpoint
```

### Restore Specific Directory

This is particularly useful for recovering workflows or documentation:

```bash
# Restore workflows directory from checkpoint
git fetch origin
CHECKPOINT_BRANCH="checkpoint/main/20251031-120000"
git checkout $CHECKPOINT_BRANCH -- .github/workflows/
git status
git commit -m "Restore workflows from checkpoint $CHECKPOINT_BRANCH"
git push origin HEAD
```

### Restore Specific Files

```bash
# Restore specific file(s)
git fetch origin
CHECKPOINT_BRANCH="checkpoint/main/20251031-120000"
git checkout $CHECKPOINT_BRANCH -- path/to/file.txt path/to/another/file.md
git commit -m "Restore files from checkpoint"
git push origin HEAD
```

### Find Checkpoint by Time

```bash
# Find checkpoint closest to a specific time
# Format: YYYYMMDD-HHMMSS
DATE_TIME="20251031-143000"  # October 31, 2025 at 14:30:00 UTC

git fetch origin
git branch -r | grep checkpoint/main/ | grep -E "checkpoint/main/$DATE_TIME|checkpoint/main/2025103114[234][0-9]" | sort | tail -1
```

## Configuration

### Adjust Checkpoint Frequency

Edit `.github/workflows/automated-checkpoint.yml`:

```yaml
on:
  schedule:
    # Change this cron expression
    - cron: '*/15 * * * *'  # Every 15 minutes
    # - cron: '*/30 * * * *'  # Every 30 minutes
    # - cron: '0 * * * *'     # Every hour
    # - cron: '0 */2 * * *'   # Every 2 hours
```

### Adjust Retention Period

Edit the cleanup step in the workflow:

```yaml
- name: Cleanup old checkpoints
  run: |
    # Change retention period here
    CUTOFF_DATE=$(date -u -d '7 days ago' +"%Y%m%d")  # Keep 7 days
    # CUTOFF_DATE=$(date -u -d '14 days ago' +"%Y%m%d")  # Keep 14 days
    # CUTOFF_DATE=$(date -u -d '30 days ago' +"%Y%m%d")  # Keep 30 days
```

### Checkpoint Other Branches

To create checkpoints for other branches, duplicate the workflow file and change:

```yaml
- name: Checkout repository
  uses: actions/checkout@v4
  with:
    fetch-depth: 0
    ref: develop  # Change branch here
```

And update the branch name pattern:

```bash
BRANCH_NAME="checkpoint/develop/${TIMESTAMP}"
```

## Best Practices

### When to Use Manual Checkpoints

Create manual checkpoints before:

- Major refactoring or restructuring
- Bulk file uploads or changes
- Experimental changes you might want to revert
- Before applying community contributions
- Critical configuration changes

### Monitoring Checkpoints

View all checkpoints in GitHub:

1. Go to your repository
2. Click on the branch dropdown
3. Type `checkpoint/` to filter checkpoint branches
4. Review timestamps to find the checkpoint you need

### Storage Considerations

- Each checkpoint is a lightweight branch reference (minimal storage)
- 7-day retention with 15-minute intervals = ~672 checkpoints maximum
- Adjust frequency and retention based on your repository size and needs

## Troubleshooting

### Checkpoint Creation Failed

Check the workflow run logs:
1. Go to **Actions** → **Automated Repository Checkpoints**
2. Click on the failed run
3. Review the error message

Common issues:
- **Permission denied**: Ensure the workflow has `contents: write` permission
- **Network errors**: Temporary GitHub API issues, will retry on next run
- **Branch conflicts**: Rare, but may occur if branch exists (will be overwritten)

### Checkpoint Cleanup Failed

- Non-critical error - old checkpoints remain but don't impact functionality
- Check workflow logs for specific branches that couldn't be deleted
- Manual cleanup: `git push origin --delete checkpoint/main/YYYYMMDD-HHMMSS`

### Can't Find Recent Checkpoint

- Check if workflow is running: **Actions** → **Automated Repository Checkpoints**
- Verify workflow is enabled (not paused)
- Check workflow run history for errors
- Recent checkpoints may take 1-2 minutes to appear after creation

## Preventing Issues

### Before Major Changes

1. **Create manual checkpoint**: Run workflow manually with descriptive reason
2. **Review PR changes carefully**: Especially for bulk file uploads
3. **Test in feature branch first**: Make changes in a branch before merging to main
4. **Use PR reviews**: Require approvals for sensitive directories like `.github/workflows/`

### GitHub Branch Protection

Add branch protection rules for checkpoint branches:

1. Go to **Settings** → **Branches**
2. Add rule for pattern: `checkpoint/**`
3. Enable: "Restrict who can push to matching branches"
4. Add GitHub Actions as allowed

This prevents accidental deletion of checkpoint branches.

### Workflow Protection

Protect the checkpoint workflow itself:

1. Add to `.github/CODEOWNERS`:
   ```
   .github/workflows/automated-checkpoint.yml @your-team
   ```

2. Require reviews for changes to checkpoint workflow

## Alternative Recovery Methods

### Using Git Reflog (Local)

If you have a local clone:

```bash
git reflog
git checkout HEAD@{n}  # Where n is the entry you want
```

### Using GitHub Compare

Compare states between commits:
```
https://github.com/owner/repo/compare/checkpoint/main/YYYYMMDD-HHMMSS...main
```

### GitHub API

List checkpoint branches via API:
```bash
curl -H "Authorization: token YOUR_TOKEN" \
  https://api.github.com/repos/owner/repo/git/refs/heads/checkpoint/main/
```

## Cost and Performance

- **GitHub Actions minutes**: ~30 seconds per checkpoint = ~0.5 hour/month
- **Storage**: Minimal (branches are references, not duplicates)
- **API rate limits**: Not impacted (uses git operations, not API)
- **Repository performance**: No impact on main branch or development

## See Also

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Git Branch Management](https://git-scm.com/book/en/v2/Git-Branching-Branch-Management)
- [Workflow Protection](./README.md)

---

**Quick Reference Card**

```bash
# List checkpoints
git branch -r | grep checkpoint/main/

# Restore workflows directory
git fetch origin
git checkout checkpoint/main/YYYYMMDD-HHMMSS -- .github/workflows/
git commit -m "Restore workflows from checkpoint"

# Delete old checkpoint manually
git push origin --delete checkpoint/main/YYYYMMDD-HHMMSS

# Create checkpoint manually (GitHub UI)
Actions → Automated Repository Checkpoints → Run workflow
```
