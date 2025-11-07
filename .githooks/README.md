# Git Hooks for AitherZero

This directory contains custom Git hooks to help maintain code quality and consistency.

## Installation

To use these hooks, run:

```bash
git config core.hooksPath .githooks
```

This configures Git to use hooks from this directory instead of `.git/hooks/`.

## Available Hooks

### pre-commit

**Purpose:** Validates `config.psd1` before allowing commits that modify it.

**What it checks:**
- Runs `0413_Validate-ConfigManifest.ps1` to ensure:
  - Config syntax is valid
  - All required sections are present
  - Domain/module counts match repository state
  - Script inventory counts are accurate (unique script numbers)
  - All script references are valid

**When it runs:**
- Only when `config.psd1` is being committed
- Automatically as part of `git commit`

**To bypass (not recommended):**
```bash
git commit --no-verify
```

### pre-commit-workflows

**Purpose:** Validates GitHub Actions workflow files before allowing commits that modify them.

**What it checks:**
- Trailing spaces (can cause workflows to disappear from PRs)
- YAML syntax errors
- Valid YAML structure

**When it runs:**
- Only when `.github/workflows/*.yml` files are being committed
- Automatically as part of `git commit`

**Why this is critical:**
- Trailing spaces in YAML can cause GitHub Actions parser to fail silently
- This results in workflow checks disappearing from PRs
- Early detection prevents CI/CD system-wide failures

**Quick fix for trailing spaces:**
```bash
find .github/workflows -name '*.yml' -exec sed -i 's/[[:space:]]*$//' {} \;
```

**To bypass (not recommended):**
```bash
git commit --no-verify
```

## Why Use Hooks?

Git hooks help prevent issues from being committed to the repository:

1. **Early detection** - Catches problems before they reach CI/CD
2. **Fast feedback** - No need to wait for CI to fail
3. **Saves time** - Prevents having to fix issues after pushing
4. **Consistency** - Ensures all contributors follow the same validation rules

## For GitHub Copilot Agents

When making changes to `config.psd1`:

1. **ALWAYS** run validation before committing:
   ```bash
   pwsh -File ./automation-scripts/0413_Validate-ConfigManifest.ps1
   ```

2. **VERIFY** ScriptInventory counts represent unique script NUMBERS, not total files:
   - Count unique numbers with: `ls -1 automation-scripts/*.ps1 | sed 's/.*\///;s/_.*//' | sort -u | wc -l`
   - Total is 130 unique numbers (132 files - scripts 0009 and 0530 have 2 files each)

3. **TEST** both validation scripts:
   ```bash
   # Validate manifest structure and counts
   ./automation-scripts/0413_Validate-ConfigManifest.ps1
   
   # Check sync with automation scripts
   ./automation-scripts/0003_Sync-ConfigManifest.ps1
   ```

## Troubleshooting

**Hook not running:**
- Check if hooks path is configured: `git config core.hooksPath`
- Verify hook is executable: `ls -l .githooks/pre-commit`
- Ensure hook file has no `.sample` extension

**Hook failing unexpectedly:**
- Run the validation script manually to see detailed errors
- Check that PowerShell 7+ is installed and in PATH
- Verify you're in the repository root directory

## CI/CD Integration

These hooks complement the CI/CD validation:
- **Local (hooks):** Fast pre-commit validation
- **CI (GitHub Actions):** Comprehensive validation on all PRs via `validate-config.yml` workflow

Both run the same validation scripts for consistency.
