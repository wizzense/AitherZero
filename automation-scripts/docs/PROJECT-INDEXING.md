# Project Indexing System

## Overview

The AitherZero Project Indexing System automatically generates and maintains navigable `index.md` files throughout the entire project structure. This creates a comprehensive, GitHub-friendly navigation system that makes it easy to explore the codebase directly in the browser.

## Features

### 🗂️ Automatic Index Generation
- Generates `index.md` files for every directory in the project
- Updates incrementally - only changed directories are processed
- Smart content analysis extracts synopses from PowerShell scripts
- Categorizes files by type with appropriate icons

### 🧭 Hierarchical Navigation
- **Breadcrumb navigation**: Shows full path from root to current directory
- **Parent links**: Quick navigation to parent directory
- **Child links**: Browse subdirectories with descriptions
- **Bidirectional**: Easy navigation both up and down the tree

### ⚡ Performance & Efficiency
- **Content hashing**: Detects changes via SHA256 hashing
- **Incremental updates**: Only processes directories with changes
- **Cache system**: Stores hashes to avoid redundant processing
- **Fast execution**: Processes 100+ directories in under 5 seconds

### 🔄 GitHub Integration
- **Automatic updates**: GitHub Actions workflow runs on push/PR
- **Auto-commit**: Commits index updates on main/develop branches
- **PR comments**: Reports statistics and changes on pull requests
- **Skip CI**: Uses `[skip ci]` to avoid recursive builds

## Architecture

### Components

```
domains/documentation/
├── ProjectIndexer.psm1          # Core indexing module
└── README.md                    # Domain documentation

automation-scripts/
└── 0745_Generate-ProjectIndexes.ps1  # CLI automation script

.github/workflows/
└── index-automation.yml         # GitHub Actions workflow

.aitherzero-index-cache.json    # Content hash cache (gitignored)
```

### Module: ProjectIndexer.psm1

**Exported Functions:**
- `Initialize-ProjectIndexer` - Initialize with configuration
- `New-ProjectIndexes` - Generate indexes for entire project
- `New-DirectoryIndex` - Generate index for single directory
- `Get-DirectoryContent` - Analyze directory contents
- `Get-ContentHash` - Calculate SHA256 hash of directory
- `Test-ContentChanged` - Check if directory has changed
- `Get-NavigationPath` - Get breadcrumb path for directory
- `Get-IndexerConfig` - Get current configuration

### Script: 0745_Generate-ProjectIndexes.ps1

**Modes:**
- `Full` - Regenerate all indexes (use with `-Force`)
- `Incremental` - Update only changed directories (default)
- `Verify` - Check which directories need updates

**Parameters:**
- `-Mode <Full|Incremental|Verify>` - Generation mode
- `-RootPath <path>` - Root directory (defaults to project root)
- `-Force` - Force regeneration even if unchanged
- `-UpdateManifest` - Update AitherZero.psd1 with functions

## Usage

### Manual Execution

```powershell
# Incremental update (recommended)
./automation-scripts/0745_Generate-ProjectIndexes.ps1

# Full regeneration
./automation-scripts/0745_Generate-ProjectIndexes.ps1 -Mode Full -Force

# Verify what needs updating
./automation-scripts/0745_Generate-ProjectIndexes.ps1 -Mode Verify

# Update specific directory tree
./automation-scripts/0745_Generate-ProjectIndexes.ps1 -RootPath ./domains
```

### Programmatic Usage

```powershell
# Import module
Import-Module ./domains/documentation/ProjectIndexer.psm1

# Initialize
Initialize-ProjectIndexer -RootPath $PWD

# Generate indexes for entire project
$results = New-ProjectIndexes -Recursive
Write-Host "Updated $($results.UpdatedIndexes) of $($results.TotalDirectories) directories"

# Generate index for single directory
$result = New-DirectoryIndex -Path ./domains/documentation
if ($result.Updated) {
    Write-Host "Index updated: $($result.Path)"
}

# Check if directory needs update
if (Test-ContentChanged -Path ./domains) {
    Write-Host "Directory has changed, needs reindexing"
}
```

### Automatic Execution

The GitHub Actions workflow `.github/workflows/index-automation.yml` automatically:

1. **On Pull Request**:
   - Runs incremental index generation
   - Posts comment with statistics
   - Uploads indexes as artifacts
   - Does NOT auto-commit (avoids conflicts)

2. **On Push to main/develop** (post-merge):
   - Runs **Full regeneration** with Force flag
   - Resolves any merge conflicts from feature branches
   - Commits updated indexes with `[skip ci]`
   - Pushes changes back to branch

3. **Manual Trigger** (workflow_dispatch):
   - Choose mode: Full, Incremental, or Verify
   - Run on-demand from Actions tab

**Post-Merge Behavior**: When a PR is merged to `main` or `develop`, the workflow automatically triggers with Full mode to regenerate all indexes. This ensures any index.md conflicts from the merge are resolved and all navigation is consistent.

## Index File Structure

Each generated `index.md` file contains:

### 1. Navigation Header
```markdown
# directory-name

**Navigation**: 🏠 Root → parent → **current**

⬆️ **Parent**: [parent-name](../index.md)
```

### 2. Overview Section
- Links to README.md if present
- Summary of directory contents
- Statistics (subdirectories, files, scripts)

### 3. Subdirectories Section
```markdown
## 📁 Subdirectories

- [📂 **subdir1**](./subdir1/index.md)
  - *Brief description from README*
- [📂 **subdir2**](./subdir2/index.md)
```

### 4. Files Section
Categorized by extension with icons:
```markdown
## 📄 Files

### .ps1 Files

- ⚙️ [script.ps1](./script.ps1)
  - *Synopsis extracted from comment-based help*

### .md Files

- 📝 [README.md](./README.md)
```

### 5. Footer
```markdown
---
*Generated by AitherZero Project Indexer* • Last updated: 2025-10-28 16:10:54 UTC
```

## Configuration

### Initialization Options

```powershell
Initialize-ProjectIndexer `
    -RootPath $PWD `
    -ExcludePaths @('.git', 'node_modules', '.vscode', 'bin', 'obj', 'dist', 'build') `
    -EnableAI  # Future: AI-powered content analysis
```

### Default Exclusions

The following directories are automatically excluded:
- `.git` - Git repository data
- `node_modules` - Node.js dependencies
- `.vscode` - VS Code settings
- `bin`, `obj` - Build output
- `dist`, `build` - Distribution artifacts

### Content Hash Cache

Location: `.aitherzero-index-cache.json` (gitignored)

Format:
```json
{
  "Version": "1.0",
  "LastUpdate": "2025-10-28T16:10:57.0000000Z",
  "Hashes": {
    "/path/to/dir1": "ABC123...",
    "/path/to/dir2": "DEF456..."
  }
}
```

## Navigation Examples

### Root Directory
```markdown
# AitherZero

## 📖 Overview
See [README.md](./README.md) for detailed information.

### 📊 Contents
- **Subdirectories**: 16
- **Files**: 30
- **PowerShell Scripts**: 10

## 📁 Subdirectories
- [📂 **domains**](./domains/index.md)
  - *This directory contains all domain modules...*
```

### Nested Directory
```markdown
# documentation

**Navigation**: [🏠 Root](../../index.md) → [domains](../index.md) → **documentation**

⬆️ **Parent**: [domains](../index.md)

## 📁 Subdirectories
(none)

## 📄 Files
- ⚙️ [ProjectIndexer.psm1](./ProjectIndexer.psm1)
  - *AitherZero Project Indexer - Automated index and navigation generation*
```

## Testing

### Unit Tests

Location: `tests/unit/domains/documentation/ProjectIndexer.Tests.ps1`

Run tests:
```powershell
Invoke-Pester -Path ./tests/unit/domains/documentation/ProjectIndexer.Tests.ps1
```

**Test Coverage:**
- ✅ Initialization and configuration
- ✅ Directory content analysis
- ✅ Content hashing and change detection
- ✅ Navigation path generation
- ✅ Index generation and updates
- ✅ Project-wide recursive indexing
- ✅ Edge cases and error handling

All 26 tests pass successfully.

### Manual Testing

```powershell
# Create test directory
mkdir test-indexing
cd test-indexing

# Initialize
Initialize-ProjectIndexer -RootPath $PWD

# Create some structure
mkdir domain1, domain2
"# Script" | Out-File domain1/script.ps1

# Generate indexes
New-ProjectIndexes -Recursive

# Verify
ls -Recurse -Filter index.md
```

## Performance

**Benchmarks** (measured on 118-directory project):
- Initial full generation: ~4.2 seconds
- Incremental update (no changes): ~1.5 seconds
- Incremental update (10 changed): ~2.3 seconds

**Scalability:**
- Linear scaling with directory count
- Efficient change detection via hashing
- Minimal I/O with cache system

## Troubleshooting

### Issue: Merge conflicts in index.md files

**Solution:**
The workflow automatically handles this! When you merge a PR to `main` or `develop`, the GitHub Actions workflow:
1. Detects it's a push event to main/develop
2. Runs Full regeneration with Force flag
3. Resolves all conflicts by regenerating from current state
4. Auto-commits the updated indexes

**Manual resolution (if needed):**
```powershell
# After resolving merge conflicts, regenerate
./automation-scripts/0745_Generate-ProjectIndexes.ps1 -Mode Full -Force
git add **/index.md
git commit -m "docs: regenerate indexes post-merge"
```

### Issue: Indexes not updating

**Solution:**
```powershell
# Delete cache and regenerate
Remove-Item .aitherzero-index-cache.json
./automation-scripts/0745_Generate-ProjectIndexes.ps1 -Mode Full -Force
```

### Issue: Missing parent links

**Cause:** Navigation calculation error
**Solution:** Regenerate with Force flag

### Issue: Wrong file icons

**Cause:** File extension not recognized
**Solution:** Add extension mapping in `New-NavigationMarkdown` function

### Issue: Excluded directory still indexed

**Cause:** Exclusion pattern doesn't match
**Solution:** Update ExcludePaths in initialization:
```powershell
Initialize-ProjectIndexer -ExcludePaths @('.git', 'custom-dir')
```

## Future Enhancements

### Planned Features
- [ ] AI-powered content descriptions (via GitHub Copilot API)
- [ ] Automatic README.md generation for empty directories
- [ ] Mermaid diagram generation for directory structure
- [ ] Search index generation for documentation site
- [ ] Custom template support for different index styles
- [ ] Multi-language support for international projects

### Integration Opportunities
- Pre-commit hooks for automatic local indexing
- VS Code extension for real-time index updates
- Integration with documentation generators (Docusaurus, MkDocs)
- API endpoint for programmatic index queries

## Best Practices

### 1. Commit Indexes with Code Changes
Run indexing before committing significant structural changes:
```bash
./automation-scripts/0745_Generate-ProjectIndexes.ps1
git add **/index.md
git commit -m "Update project indexes"
```

### 2. Maintain README Files
While indexes auto-generate, maintaining README.md files provides better context:
- Each directory should have a README.md
- Include purpose, usage, and examples
- Index files will reference and link to them

### 3. Review Generated Indexes
Periodically review indexes for:
- Correct breadcrumb navigation
- Accurate file categorization
- Broken links (run link checker)

### 4. Use Verify Mode Before Large Changes
Before major restructuring:
```powershell
./automation-scripts/0745_Generate-ProjectIndexes.ps1 -Mode Verify
```

## Contributing

When contributing to the indexing system:

1. **Test thoroughly**: Run all unit tests
2. **Document changes**: Update this README
3. **Maintain compatibility**: Keep existing index format
4. **Performance**: Profile any new features
5. **Cross-platform**: Test on Windows, Linux, macOS

## Support

For issues or questions:
- Check troubleshooting section above
- Review unit tests for usage examples
- Open GitHub issue with `documentation` label
- Reference automation script 0745 in questions

---

*Part of the AitherZero Infrastructure Automation Platform*
*Copyright © 2025 Aitherium Corporation*
