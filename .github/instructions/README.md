# Path-Specific Instructions for GitHub Copilot

This directory contains path-specific instruction files that guide GitHub Copilot coding agent when working on different types of files in the AitherZero repository.

## Overview

Path-specific instructions allow Copilot to understand file-specific requirements, coding standards, and best practices automatically based on the files it's working with. These complement the repository-wide instructions in `../.github/copilot-instructions.md`.

## Available Instructions

### 1. Pester Tests (`pester-tests.instructions.md`)
**Applies to:** `**/*.Tests.ps1`

Covers:
- AST-based function extraction (CRITICAL - never duplicate code in tests)
- Test structure with Pester 5.0+
- Mocking external dependencies
- Test organization and naming conventions
- CI/CD integration

**Key Pattern:**
```powershell
# Extract functions from source using AST parsing
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
$functionAst = $ast.FindAll({ ... }, $true)
Invoke-Expression $functionAst.Extent.Text
```

### 2. PowerShell Modules (`powershell-modules.instructions.md`)
**Applies to:** `aithercore/**/*.psm1`

Covers:
- Singular noun cmdlets (pipeline-friendly design)
- Configuration loading patterns (`Import-ConfigDataFile` vs `Import-PowerShellDataFile`)
- Cross-platform compatibility
- Module dependencies and load order
- Parameter design and error handling

**Key Pattern:**
```powershell
# Pipeline-friendly cmdlet with Begin/Process/End
function Get-Item {
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline)] $InputObject)
    begin { } process { } end { }
}
```

### 3. Automation Scripts (`automation-scripts.instructions.md`)
**Applies to:** `library/automation-scripts/**/*.ps1`

Covers:
- Number-based orchestration system (0000-9999)
- Single-purpose scripts with parameters (NO duplicates!)
- ScriptUtilities module usage
- Metadata comments for orchestration
- GitHub issue creation in CI (use actions/github-script)

**Key Pattern:**
```powershell
# Import ScriptUtilities for common functions
Import-Module (Join-Path $projectRoot "aithercore/automation/ScriptUtilities.psm1") -Force
Write-ScriptLog "Starting..." -Source "0402_Script"
```

### 4. GitHub Workflows (`github-workflows.instructions.md`)
**Applies to:** `.github/workflows/**/*.yml`

Covers:
- Bootstrap requirements (ALWAYS run bootstrap.ps1 first)
- PowerShell execution in workflows
- GitHub issue creation (use actions/github-script, NOT gh CLI)
- Environment variables and permissions
- Artifact management and caching

**Key Pattern:**
```yaml
# Use actions/github-script for GitHub API operations
- uses: actions/github-script@v7
  with:
    script: |
      await github.rest.issues.create({...})
```

## How It Works

1. **Copilot detects file type** - When working on a file, Copilot checks the glob patterns
2. **Loads relevant instructions** - Applies the instructions that match the file path
3. **Follows guidelines** - Uses the patterns and best practices automatically
4. **Produces better code** - First-time PRs are more likely to be mergeable

## File Format

Each instruction file follows this format:

```markdown
---
applyTo: "glob/pattern/**/*.ext"
---

# Title

Instructions in Markdown format...
```

### YAML Front Matter

- **applyTo**: Glob pattern matching files these instructions apply to
- Use double quotes around the pattern
- Supports standard glob patterns (`*`, `**`, `?`)

### Content

- Written in Markdown
- Include clear examples and anti-patterns
- Show "DO THIS" and "DON'T DO THIS" patterns
- Reference existing documentation when helpful

## Adding New Instructions

To add path-specific instructions for a new file type:

1. **Create file**: `.github/instructions/<name>.instructions.md`
2. **Add front matter**:
   ```yaml
   ---
   applyTo: "path/pattern/**/*.ext"
   ---
   ```
3. **Write instructions**: Use clear examples, avoid duplication with copilot-instructions.md
4. **Test**: Verify glob pattern matches expected files
5. **Commit**: Add to repository

### Best Practices

- **Be specific**: Target specific file patterns, not broad categories
- **Show examples**: Code examples are more helpful than prose
- **Avoid duplication**: Reference copilot-instructions.md for general patterns
- **Keep focused**: Each file should cover one file type or pattern
- **Use anti-patterns**: Show what NOT to do, not just what to do

## Validation

Validate instruction files with:

```powershell
# Check YAML front matter and content
Get-ChildItem .github/instructions -Filter "*.instructions.md" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    if ($content -match '^---\s*\napplyTo:\s*"([^"]+)"\s*\n---') {
        Write-Host "✅ $($_.Name): $($matches[1])"
    } else {
        Write-Host "❌ $($_.Name): Invalid format"
    }
}
```

## Integration with copilot-setup-steps.yml

The `copilot-setup-steps.yml` file in the parent directory pre-installs dependencies before Copilot starts working:

- PowerShell 7 installation
- AitherZero bootstrap
- Pester and PSScriptAnalyzer
- Environment configuration
- Validation checks

Together, path-specific instructions and setup automation enable Copilot to:
- Understand requirements automatically
- Work in a properly configured environment
- Follow best practices without manual guidance
- Produce high-quality, mergeable PRs

## Related Documentation

- `../.github/copilot-instructions.md` - Repository-wide instructions (1475 lines)
- `../.github/copilot-setup-steps.yml` - Dependency pre-installation
- `../.github/copilot.yaml` - Custom agent routing
- `../../docs/STYLE-GUIDE.md` - Code style guide
- `../../tests/TEST-BEST-PRACTICES.md` - Testing guidelines

## Reference

Based on GitHub Copilot coding agent best practices:
- [GitHub Docs - Best practices for using GitHub Copilot to work on tasks](https://docs.github.com/en/copilot/using-github-copilot/using-github-copilot-code-review/best-practices-for-using-github-copilot-to-work-on-tasks)
- [Adding repository custom instructions for GitHub Copilot](https://docs.github.com/en/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot)
