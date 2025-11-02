# AitherZero OSS Projects Workspace

This directory contains external open-source projects managed by AitherZero.

## Directory Structure

Each project in this workspace has:
- Project files (source code, tests, documentation)
- `.aitherzero/` directory with:
  - `config.psd1` - Project-specific configuration
  - `workspace.psd1` - Workspace metadata

## Usage

```powershell
# List all workspace projects
az 0603

# Switch to a project
az 0602 -Project "project-name"

# Use AitherZero tools on the active project
az 0402  # Run tests
az 0404  # PSScriptAnalyzer
az 0510  # Generate report
```

## Managed by AitherZero

This workspace is managed by AitherZero.
See https://github.com/wizzense/AitherZero for more information.
