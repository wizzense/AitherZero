# Documentation Automation System

## Overview

This document describes the automated documentation validation and organization system for AitherZero.

## Purpose

The documentation automation system ensures that:
1. Documentation follows consistent organizational standards
2. The root directory remains clean with only essential files
3. Documentation is properly categorized in subdirectories
4. Internal links remain valid as files are moved or renamed
5. Documentation structure can be validated in CI/CD pipelines

## Components

### Validation Script: 0425_Validate-DocumentationStructure.ps1

**Location**: `automation-scripts/0425_Validate-DocumentationStructure.ps1`

**Purpose**: Validates documentation organization and structure

**Features**:
- Checks required directories exist (`docs/`, `docs/strategic/`, `docs/archive/`, `docs/guides/`, `docs/troubleshooting/`)
- Verifies obsolete directories are removed (`generated-issues/`, `legacy-to-migrate/`)
- Validates root directory contains only essential markdown files
- Checks for broken internal documentation links (optional)
- Generates validation reports in JSON format
- Supports strict mode for CI/CD environments

**Usage**:
```powershell
# Basic validation
./automation-scripts/0425_Validate-DocumentationStructure.ps1

# Or using the az shortcut
az 0425

# With link checking
az 0425 -CheckLinks

# Strict mode (fail on warnings, for CI/CD)
az 0425 -Strict

# View results
cat ./reports/documentation-validation.json
```

**Exit Codes**:
- `0` - Validation passed
- `1` - Validation failed (errors found, or warnings in strict mode)

## Documentation Structure Rules

### Required Root Files

Only these files should exist in the root directory:

| File | Purpose |
|------|---------|
| `README.md` | Main project README |
| `QUICK-REFERENCE.md` | Quick reference guide for users |
| `DOCKER.md` | Docker usage guide |
| `FUNCTIONALITY-INDEX.md` | Auto-generated functionality index |
| `index.md` | Auto-generated directory index |

**Any other markdown files in root should be moved to appropriate subdirectories.**

### Required Directory Structure

```
docs/
├── README.md                      # Main documentation index
├── strategic/                     # Strategic planning documents
│   ├── README.md
│   ├── STRATEGIC-ROADMAP.md
│   ├── NEXT-STEPS-SUMMARY.md
│   ├── NEXT-ACTIONS.md
│   └── VISUAL-GUIDE.md
├── guides/                        # Technical guides
│   ├── README.md
│   └── [various technical guides]
├── archive/                       # Archived/historical docs
│   ├── README.md
│   └── [old summaries and completed work]
├── troubleshooting/              # Troubleshooting guides
│   └── [troubleshooting docs]
├── integrations/                 # Integration guides
├── templates/                    # Documentation templates
└── generated/                    # Auto-generated API docs
```

### Forbidden Directories

These directories should NOT exist (they were removed during cleanup):
- `generated-issues/` - Old issue generation directory
- `legacy-to-migrate/` - Old migration code

## Validation Checks

The validator performs these checks:

### 1. Required Directories Check
Verifies that all required documentation directories exist.

**Result**: ERROR if missing

### 2. Forbidden Directories Check
Ensures obsolete directories don't exist.

**Result**: WARNING if found

### 3. Root Directory Check
Validates that root only contains essential markdown files.

**Result**: WARNING if unexpected files found

### 4. Required Files Check
Ensures essential root files exist (README.md, etc.).

**Result**: ERROR if missing

### 5. Subdirectory README Check
Verifies each major subdirectory has a README.md file.

**Result**: WARNING if missing

### 6. Broken Links Check (Optional)
Scans all markdown files for broken internal links.

**Result**: WARNING for each broken link

## CI/CD Integration

### GitHub Actions

Add to `.github/workflows/validation.yml`:

```yaml
- name: Validate Documentation Structure
  run: |
    pwsh -File ./automation-scripts/0425_Validate-DocumentationStructure.ps1 -Strict
```

The `-Strict` flag treats warnings as errors, failing the CI build if documentation issues are found.

### Pre-commit Hook

Add to `.git/hooks/pre-commit`:

```bash
#!/bin/sh
pwsh -File ./automation-scripts/0425_Validate-DocumentationStructure.ps1
if [ $? -ne 0 ]; then
    echo "Documentation validation failed. Please fix issues before committing."
    exit 1
fi
```

## Maintenance Workflow

### When Adding New Documentation

1. Determine the correct location based on content type:
   - **Strategic planning** → `docs/strategic/`
   - **Technical guides** → `docs/guides/`
   - **Troubleshooting** → `docs/troubleshooting/`
   - **Integration guides** → `docs/integrations/`
   - **Templates** → `docs/templates/`

2. Add the file to the appropriate directory

3. Update the relevant README.md with a link

4. Run validation:
   ```powershell
   az 0425 -CheckLinks
   ```

5. Fix any broken links or validation issues

### When Moving Documentation

1. Move the file to its new location

2. Update all references in other documentation files

3. Run link validation:
   ```powershell
   az 0425 -CheckLinks
   ```

4. Fix any broken links reported

5. Update any automation scripts that reference the moved file

### When Archiving Documentation

1. Move the file to `docs/archive/`

2. Update `docs/archive/README.md` to list the archived file

3. Remove or update links from active documentation

4. Run validation to ensure no broken links remain

## Validation Report Format

The validator creates `reports/documentation-validation.json` with this structure:

```json
{
    "Passed": 16,
    "Warnings": 0,
    "Errors": 0,
    "Issues": [
        {
            "Type": "BrokenLink",
            "Message": "Broken link to 'old-file.md'",
            "File": "docs/some-doc.md",
            "Severity": "Warning"
        }
    ]
}
```

## Issue Types

| Type | Description | Severity |
|------|-------------|----------|
| `MissingDirectory` | Required directory doesn't exist | Error |
| `ForbiddenDirectory` | Obsolete directory found | Warning |
| `MisplacedFile` | File should be in subdirectory | Warning |
| `UnexpectedRootFile` | Unexpected markdown in root | Warning |
| `MissingFile` | Required root file missing | Error |
| `MissingReadme` | Subdirectory missing README | Warning |
| `BrokenLink` | Internal link is broken | Warning |

## Best Practices

### Documentation Organization

1. **Keep root clean** - Only essential user-facing files in root
2. **Use subdirectories** - Organize by purpose (strategic, guides, archive)
3. **Maintain READMEs** - Each subdirectory should have a descriptive README
4. **Archive old docs** - Don't delete, move to `docs/archive/`
5. **Update links** - When moving files, update all references

### Validation Workflow

1. **Run validation locally** before committing
2. **Use `-CheckLinks`** when moving or renaming files
3. **Fix issues immediately** to prevent accumulation
4. **Check CI results** for validation failures
5. **Update automation** if structure changes

### Link Management

1. **Use relative paths** for internal links
2. **Test links** after moving files
3. **Update all references** when restructuring
4. **Document link changes** in commit messages

## Troubleshooting

### Validation Fails with Missing Directories

**Solution**: Create missing directories:
```powershell
mkdir -p docs/strategic docs/archive docs/guides docs/troubleshooting
```

### Many Broken Links After Moving Files

**Solution**: 
1. Check the validation report for patterns
2. Use find/replace to update common references
3. Re-run validation to confirm fixes

### Forbidden Directory Still Exists

**Solution**: Remove the obsolete directory:
```powershell
git rm -r generated-issues/
git rm -r legacy-to-migrate/
```

### Validation Script Fails to Run

**Solution**: Ensure PowerShell 7+ is installed and script is executable:
```bash
pwsh --version  # Should be 7.0 or higher
chmod +x automation-scripts/0425_Validate-DocumentationStructure.ps1
```

## Future Enhancements

Potential improvements to the automation system:

1. **Auto-fix capability** - Automatically update common broken links
2. **Link suggestion** - Suggest correct paths for moved files
3. **Duplicate detection** - Find duplicate content across files
4. **Freshness checking** - Warn about docs not updated recently
5. **Format validation** - Check markdown formatting standards
6. **Cross-reference mapping** - Generate map of documentation relationships

## Related Documentation

- [Documentation Structure README](../docs/README.md) - Complete documentation map
- [Strategic Planning README](../docs/strategic/README.md) - Strategic docs
- [Archive README](../docs/archive/README.md) - Archived documentation
- [Guides README](../docs/guides/README.md) - Technical guides

## Maintenance

This automation system is maintained by:
- **Documentation team** - Structure and standards
- **DevOps team** - CI/CD integration
- **Contributors** - Running validation before commits

---

*Last updated: 2025-10-30*  
*Script version: 1.0*  
*Maintained by: Olivia (Documentation Agent)*
