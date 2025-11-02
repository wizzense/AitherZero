# CLI Modernization Guide

## Overview

AitherZero's command-line interface has been modernized to provide a better user experience with rich help, clear documentation, and improved discoverability.

## What's New

### 🎯 Enhanced Help System

The help system now provides multiple levels of detail tailored to different use cases:

#### Quick Help
```powershell
./Start-AitherZero.ps1 -Help
```

Shows:
- Quick start commands for immediate productivity
- Most common operations with examples
- Clear, beginner-friendly guidance

#### Full Help
```powershell
Get-Help ./Start-AitherZero.ps1 -Full
```

Provides complete documentation including:
- All parameters and their descriptions
- Comprehensive examples
- Detailed syntax information

### 📊 Modern Version Display

```powershell
./Start-AitherZero.ps1 -Version
```

Now shows:
- AitherZero version
- PowerShell version
- Platform and OS information
- Repository and documentation links

### 📚 Quick Reference Cards

Focused reference cards for specific tasks:

```powershell
# Testing commands
Import-Module ./domains/experience/CLIHelper.psm1
Show-CommandCard -CardType testing

# Git automation
Show-CommandCard -CardType git

# Reporting
Show-CommandCard -CardType reporting

# Deployment
Show-CommandCard -CardType deployment

# All cards
Show-CommandCard -CardType all
```

### 🎨 Consistent Styling

All CLI output now uses consistent, professional formatting with:
- Color-coded output for different message types
- Unicode box-drawing characters for visual structure
- Emoji icons for quick visual identification
- Clear hierarchy and grouping

## Help Types

### Quick Start Help
**Best for**: New users, quick reference
**Content**: Essential commands to get started immediately

```powershell
Show-ModernHelp -HelpType quick
```

### Command Help
**Best for**: Discovering available commands
**Content**: All commands with descriptions and icons

```powershell
Show-ModernHelp -HelpType commands
```

### Examples Help
**Best for**: Learning through real-world usage
**Content**: Common examples grouped by category (Testing, Git, Reporting, Workflows)

```powershell
Show-ModernHelp -HelpType examples
```

### Script Categories Help
**Best for**: Understanding the numbering system
**Content**: Complete breakdown of 0000-9999 script ranges

```powershell
Show-ModernHelp -HelpType scripts
```

## Script Numbering System

AitherZero uses a systematic numbering approach for its 125+ automation scripts:

| Range | Category | Examples |
|-------|----------|----------|
| **0000-0099** | Environment Setup | PowerShell 7, directories, validation |
| **0100-0199** | Infrastructure | Hyper-V, WSL, certificates, networking |
| **0200-0299** | Development Tools | Git, Node, Docker, VS Code, Python |
| **0300-0399** | Deployment & IaC | OpenTofu, infrastructure automation |
| **0400-0499** | Testing & Validation | Unit tests, integration tests, linting |
| **0500-0599** | Reports & Metrics | Dashboards, analytics, project reports |
| **0700-0799** | Git Automation | Branches, commits, PRs, AI coding tools |
| **9000-9999** | Maintenance | Cleanup, system maintenance |

## Common Commands

### Running Scripts

```powershell
# Quick run by number
./Start-AitherZero.ps1 -Mode Run -Target 0402

# Explicit syntax
./Start-AitherZero.ps1 -Mode Run -Target script -ScriptNumber 0402
```

### Orchestration

```powershell
# Run a sequence
./Start-AitherZero.ps1 -Mode Orchestrate -Sequence '0400-0499'

# Run a playbook
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick

# Run with specific profile
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook tech-debt -PlaybookProfile quick
```

### Discovery

```powershell
# List all scripts
./Start-AitherZero.ps1 -Mode List -Target scripts

# List playbooks
./Start-AitherZero.ps1 -Mode List -Target playbooks

# Search
./Start-AitherZero.ps1 -Mode Search -Query security
```

### Interactive Mode

```powershell
# Launch full interactive menu
./Start-AitherZero.ps1 -Mode Interactive
```

## Frequently Used Commands

### Testing & Validation

```powershell
# Run unit tests
./Start-AitherZero.ps1 -Mode Run -Target 0402

# Run PSScriptAnalyzer (linting)
./Start-AitherZero.ps1 -Mode Run -Target 0404

# Validate syntax
./Start-AitherZero.ps1 -Mode Run -Target 0407

# Quick test playbook
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick

# Full test suite
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-full
```

### Reporting

```powershell
# Generate project report
./Start-AitherZero.ps1 -Mode Run -Target 0510 -ShowAll

# View health dashboard
./Start-AitherZero.ps1 -Mode Run -Target 0550
```

### Git Automation

```powershell
# Create feature branch
./Start-AitherZero.ps1 -Mode Run -Target 0701 -Type feature -Name 'my-feature'

# Commit changes
./Start-AitherZero.ps1 -Mode Run -Target 0702 -Type feat -Message 'add feature'

# Create pull request
./Start-AitherZero.ps1 -Mode Run -Target 0703 -Title 'Add feature'
```

## Tab Completion

AitherZero supports intelligent tab completion for:

- **Target**: Script numbers, 'script', 'playbook', 'sequence'
- **Playbook**: Available playbook names
- **ScriptNumber**: Shows numbers with descriptions
- **Query**: Common search terms

Example:
```powershell
./Start-AitherZero.ps1 -Mode Run -Target <Tab>
# Shows: 0000, 0001, 0002, ..., script, playbook, sequence, scripts, playbooks, all
```

## CLI Module Functions

The CLIHelper module exports several functions for custom scripts:

### Show-ModernHelp
Display rich help with various formats.

```powershell
Show-ModernHelp -HelpType quick      # Quick start
Show-ModernHelp -HelpType commands   # Command list
Show-ModernHelp -HelpType examples   # Examples
Show-ModernHelp -HelpType scripts    # Script categories
Show-ModernHelp -HelpType full       # Everything
```

### Show-VersionInfo
Display version with system information.

```powershell
Show-VersionInfo
```

### Show-CommandCard
Display quick reference cards.

```powershell
Show-CommandCard -CardType testing      # Testing commands
Show-CommandCard -CardType deployment   # Deployment commands
Show-CommandCard -CardType git          # Git automation
Show-CommandCard -CardType reporting    # Reporting commands
Show-CommandCard -CardType all          # All cards
```

### Format-CLIOutput
Format output with consistent styling.

```powershell
Format-CLIOutput -Message "Success!" -Type Success
Format-CLIOutput -Message "Error occurred" -Type Error
Format-CLIOutput -Message "Warning: check config" -Type Warning
Format-CLIOutput -Message "Information" -Type Info
Format-CLIOutput -Message "Details" -Type Muted
```

## Tips & Tricks

### 💡 Quick Access to Help

```powershell
# Bookmark this for quick reference
./Start-AitherZero.ps1 -Help | more
```

### 💡 Script Discovery

```powershell
# Find scripts by keyword
./Start-AitherZero.ps1 -Mode Search -Query docker

# List all in a category
./Start-AitherZero.ps1 -Mode List -Target scripts | Select-String "020"
```

### 💡 Dry Run Testing

```powershell
# Preview without executing
./Start-AitherZero.ps1 -Mode Orchestrate -Sequence '0100-0199' -DryRun
```

### 💡 Non-Interactive Mode

```powershell
# For automation/CI
./Start-AitherZero.ps1 -Mode Run -Target 0402 -NonInteractive
```

## Future Enhancements

Planned improvements to the CLI:

### Phase 2: Command Structure
- Git-style subcommands (`az run 0402`, `az test`)
- Command aliases (`az test`, `az deploy`, `az status`)
- Better parameter validation with helpful error messages
- Command history and recent commands

### Phase 3: User Experience
- Progress indicators for long-running commands
- Command execution time tracking
- Interactive command builder/wizard
- Beginner-friendly guided mode

### Phase 4: Developer Experience
- Reusable CLI parsing module
- CLI plugin architecture
- Extensibility patterns
- Enhanced testing framework

## Feedback

We'd love to hear your feedback on the CLI modernization:

- **GitHub Issues**: Report bugs or request features
- **GitHub Discussions**: Share ideas and suggestions
- **Pull Requests**: Contribute improvements

## Examples

See the demo script for a walkthrough of all new features:

```powershell
./examples/cli-modernization-demo.ps1
```

## Migration Notes

### No Breaking Changes

All existing commands and scripts continue to work exactly as before. The modernization adds new features without changing existing behavior.

### Gradual Adoption

You can use the new features immediately or continue using familiar commands. Everything is backwards compatible.

### Environment Variables

New environment variables (optional):
- `AITHERZERO_USE_INTERACTIVE_UI='true'` - Enable interactive menus globally

## Troubleshooting

### Help Not Displaying Correctly

If the modern help doesn't display:
1. Ensure PowerShell 7.0+ is installed
2. Check terminal supports ANSI colors
3. Fallback help will display automatically

### Emoji Not Showing

If emoji icons don't display:
1. Check terminal font supports Unicode
2. Help still functions without emoji
3. All information is available in text form

### Module Import Errors

If CLIHelper module fails to load:
1. The script falls back to classic help automatically
2. Check file permissions on domains/experience/CLIHelper.psm1
3. Try running with `-Verbose` to see diagnostic messages

## Support

For help and support:
- **Documentation**: https://wizzense.github.io/AitherZero
- **Repository**: https://github.com/wizzense/AitherZero
- **Issues**: https://github.com/wizzense/AitherZero/issues
