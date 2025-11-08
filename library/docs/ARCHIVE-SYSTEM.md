# Documentation Archive System

## Overview

The AitherZero documentation archive system automatically packages and deploys historical documentation to GitHub Pages when new files are added to the archive.

## How It Works

### Automated Workflow

The archive system uses GitHub Actions to:
1. **Detect Changes**: Monitors the `docs/archive/` directory for new or modified files
2. **Create Archive**: Packages all archived markdown files into a dated ZIP file
3. **Generate Index**: Creates a searchable index with file metadata
4. **Deploy**: Publishes to GitHub Pages at `/archives/`

### Workflow Trigger

The workflow runs automatically when:
- Files are added/modified in `docs/archive/` and pushed to `main`
- Manually triggered via GitHub Actions UI

**Note**: The workflow only executes when actual changes are detected in the archive directory.

## Archiving Documentation

### When to Archive

Archive documentation when:
- Feature implementation is complete and documented elsewhere
- Content is superseded by newer documentation
- Information is historical but may be useful for reference
- Document describes a one-time fix or completed work

### How to Archive

1. **Move the file to docs/archive/**:
   ```bash
   git mv docs/OLD-DOCUMENT.md docs/archive/
   ```

2. **Commit and push**:
   ```bash
   git add docs/archive/
   git commit -m "docs: archive completed implementation summary"
   git push
   ```

3. **Workflow triggers automatically** - Archive will be built and deployed within minutes

## Accessing Archived Documentation

### Via GitHub Pages

**Archive Index**: `https://wizzense.github.io/AitherZero/archives/`

This page provides:
- Download link for the complete archive ZIP
- List of all archived files with metadata
- Direct links to individual files on GitHub

### Direct Download

```bash
# Download latest archive
wget https://wizzense.github.io/AitherZero/archives/documentation-archive-YYYYMMDD.zip

# Extract
unzip documentation-archive-YYYYMMDD.zip

# Browse
ls -la
```

### Via GitHub Repository

View files directly on GitHub:
`https://github.com/wizzense/AitherZero/tree/main/docs/archive`

## Archive Structure

### In Repository

```
docs/archive/
├── IMPLEMENTATION-SUMMARY.md
├── TESTING-SYSTEM-SUMMARY.md
├── RELEASE-1.0.0.0-FINAL-SUMMARY.md
└── [other archived docs]
```

### On GitHub Pages

```
archives/
├── index.html                           # Interactive browse page
├── ARCHIVE-INDEX.md                     # Markdown index with metadata
└── documentation-archive-YYYYMMDD.zip   # Complete archive
```

## Finding Specific Documentation

### Search Methods

1. **Archive Index Page**: Browse the web interface at `/archives/`
2. **GitHub Search**: Search within the archive directory
   ```
   repo:wizzense/AitherZero path:docs/archive/ "search term"
   ```
3. **Local Search**: Download and grep through the archive
   ```bash
   unzip documentation-archive-*.zip
   grep -r "search term" .
   ```

### Index File

The `ARCHIVE-INDEX.md` file contains:
- Complete file listing with sizes and dates
- Retrieval instructions
- Direct links to GitHub
- Generation metadata

## Workflow Configuration

### File: `.github/workflows/archive-documentation.yml`

**Triggers**:
- Push to `main` branch with changes in `docs/archive/**`
- Manual dispatch via Actions UI

**Permissions Required**:
- `contents: read` - Read repository content
- `pages: write` - Deploy to GitHub Pages
- `id-token: write` - GitHub Pages deployment token

**Concurrency**: Only one archive deployment at a time (prevents conflicts)

### Workflow Steps

1. **Check Archive** (Job 1)
   - Verifies archive directory exists
   - Counts archived files
   - Detects if changes occurred in latest push
   - Outputs: `has_changes`, `archive_count`

2. **Create Archive** (Job 2, conditional)
   - Runs only if changes detected
   - Generates metadata file with timestamps
   - Creates ZIP archive of all `.md` files (except README/index)
   - Builds HTML interface
   - Uploads to Pages artifact

3. **Deploy** (Job 3, conditional)
   - Deploys artifact to GitHub Pages
   - Reports deployment URL
   - Provides direct download link

## Automation Features

### Smart Execution

- **Change Detection**: Only runs when archive files change
- **Skip Empty Runs**: Doesn't deploy if no archive files exist
- **Idempotent**: Safe to run multiple times
- **Dated Archives**: Each deployment creates a uniquely dated ZIP

### Metadata Tracking

Each archive includes:
- Generation timestamp (UTC)
- Total file count
- Branch and commit SHA
- File sizes and modification dates
- Retrieval instructions

## Integration with Documentation Validation

The archive system works alongside the documentation validator:

```powershell
# Validation script ignores archive directory
az 0425  # Archive files not checked for structure compliance

# Archive files are excluded from:
# - Link validation
# - Structure checks
# - Active documentation standards
```

## Maintenance

### Manual Workflow Run

To manually trigger archive creation:

1. Go to: `https://github.com/wizzense/AitherZero/actions/workflows/archive-documentation.yml`
2. Click "Run workflow"
3. Select branch (usually `main`)
4. Click "Run workflow" button

### Checking Deployment Status

View deployment status:
```bash
gh run list --workflow=archive-documentation.yml --limit 5
```

Or visit: `https://github.com/wizzense/AitherZero/actions/workflows/archive-documentation.yml`

### Archive Storage

- **Location**: GitHub Pages
- **Retention**: Permanent (until manually removed)
- **Size Limit**: GitHub Pages 1GB limit (unlikely to hit with docs)
- **Versions**: Each date creates a new archive (old archives remain)

## Best Practices

### Do's

✅ **Archive completed work** - Implementation summaries, completed roadmaps
✅ **Keep archive organized** - Only move files that are truly historical
✅ **Use descriptive commit messages** - "docs: archive X implementation summary"
✅ **Verify deployment** - Check GitHub Pages after archiving important docs

### Don'ts

❌ **Don't archive active docs** - Only archive superseded content
❌ **Don't delete historical content** - Archive instead
❌ **Don't bypass the workflow** - Let automation handle ZIP creation
❌ **Don't archive non-markdown** - System expects `.md` files

## Troubleshooting

### Archive Workflow Didn't Run

**Possible causes**:
- No changes in `docs/archive/` directory
- Changes pushed to non-main branch
- Workflow file syntax error

**Solutions**:
1. Check: `git log --oneline -- docs/archive/`
2. Verify branch: `git branch --show-current`
3. Manual trigger: Use workflow dispatch

### Archive ZIP Not Found

**Possible causes**:
- Deployment still in progress
- GitHub Pages not enabled
- Permission issues

**Solutions**:
1. Check workflow status in Actions tab
2. Verify Pages enabled: Settings → Pages
3. Wait 2-3 minutes for deployment

### Can't Access Archive Page

**Possible causes**:
- GitHub Pages not configured
- Recent deployment not complete
- Repository visibility settings

**Solutions**:
1. Enable Pages: Settings → Pages → Source: GitHub Actions
2. Check deployment: Actions → archive-documentation
3. Verify repository is public or Pages enabled for private repos

## Example Usage

### Scenario: Archiving a Completed Implementation

```bash
# 1. Identify doc to archive
ls docs/*SUMMARY*.md

# 2. Move to archive
git mv docs/FEATURE-IMPLEMENTATION-SUMMARY.md docs/archive/

# 3. Commit
git add docs/archive/
git commit -m "docs: archive feature implementation summary"

# 4. Push (triggers workflow)
git push origin main

# 5. Wait 2-3 minutes for deployment

# 6. Access archive
open https://wizzense.github.io/AitherZero/archives/
```

### Scenario: Retrieving Old Documentation

```bash
# Download archive
wget https://wizzense.github.io/AitherZero/archives/documentation-archive-20251030.zip

# Extract
unzip documentation-archive-20251030.zip

# Find specific content
grep -r "feature name" .

# View file
cat FEATURE-IMPLEMENTATION-SUMMARY.md
```

## Related Documentation

- [Documentation Structure](README.md) - Main documentation index
- [Documentation Automation](DOCUMENTATION-AUTOMATION.md) - Validation system
- [GitHub Pages Deployment](../GITHUB-PAGES-DEPLOYMENT-GUIDE.md) - Pages setup

## Support

### Getting Help

- **Archive Issues**: Check workflow logs in Actions tab
- **Access Issues**: Verify GitHub Pages settings
- **Content Questions**: Review archive index at `/archives/`

### Reporting Problems

When reporting issues with the archive system:
1. Workflow run URL
2. Expected vs actual behavior
3. Archive directory contents: `ls -la docs/archive/`
4. Recent commits: `git log --oneline -5 -- docs/archive/`

---

*Last updated: 2025-10-30*
*Workflow: `.github/workflows/archive-documentation.yml`*
*System version: 1.0*
