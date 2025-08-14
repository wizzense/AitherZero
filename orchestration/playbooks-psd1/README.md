# AitherZero PSD1 Playbooks

## Overview

AitherZero playbooks have been rebuilt from scratch using PowerShell Data Files (PSD1) format. This provides better readability for both humans and AI agents, native PowerShell support, and improved IDE integration.

## Why PSD1?

- **Native PowerShell** - No external dependencies required
- **IntelliSense Support** - Full IDE support with syntax highlighting and validation
- **Type Safety** - PowerShell validates structure automatically
- **Consistency** - Matches existing config.psd1 pattern
- **Comments** - Supports inline and block comments for documentation
- **Secure** - Cannot execute arbitrary code like .ps1 files

## Directory Structure

```
playbooks-psd1/
├── testing/          # Test automation playbooks
│   ├── test-quick.psd1
│   └── test-full.psd1
├── setup/            # Environment setup playbooks
│   └── dev-environment.psd1
├── git/              # Git workflow playbooks
│   └── git-workflow.psd1
├── ops/              # Operations playbooks
└── analysis/         # Code analysis playbooks
```

## Playbook Structure

Each PSD1 playbook follows this structure:

```powershell
@{
    # Metadata
    Name = 'playbook-name'
    Description = 'What this playbook does'
    Version = '2.0.0'
    Author = 'Team/Author name'
    Created = 'ISO 8601 timestamp'
    
    # Categorization
    Tags = @('tag1', 'tag2')
    Category = 'Category name'
    
    # Requirements
    Requirements = @{
        Modules = @('Module1', 'Module2')
        MinimumVersion = '7.0'
        EstimatedDuration = '5-10 minutes'
    }
    
    # Variables
    Variables = @{
        VariableName = 'value'
        BooleanVar = $true
        ArrayVar = @('item1', 'item2')
    }
    
    # Execution Stages
    Stages = @(
        @{
            Name = 'Stage Name'
            Description = 'What this stage does'
            Sequence = @('0000', '0001')  # Script numbers to execute
            Variables = @{}  # Stage-specific variables
            ContinueOnError = $false
            Timeout = 300  # seconds
        }
    )
    
    # Notifications
    Notifications = @{
        OnSuccess = @{
            Message = 'Success message'
            Level = 'Information'
        }
        OnFailure = @{
            Message = 'Failure message'
            Level = 'Error'
        }
    }
}
```

## Using Playbooks

### Command Line

```powershell
# Execute a playbook
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick

# Execute with custom variables
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-full -Variables @{RunCoverage=$true}

# Dry run to see what would execute
Import-Module ./AitherZero.psd1
Invoke-OrchestrationSequence -LoadPlaybook 'test-quick' -DryRun
```

### Interactive Mode

```powershell
# Start interactive UI
./Start-AitherZero.ps1

# Select "Orchestration" -> "Execute Playbook"
# Choose from available PSD1 playbooks
```

### Creating New Playbooks

```powershell
# Using the Save function
Import-Module ./AitherZero.psd1
Save-OrchestrationPlaybook -Name 'my-playbook' -Sequence @('0402','0404') -Description 'My custom playbook' -Format PSD1

# Or copy an existing template and modify
Copy-Item ./orchestration/playbooks-psd1/testing/test-quick.psd1 ./orchestration/playbooks-psd1/testing/my-test.psd1
```

## Available Playbooks

### Testing

- **test-quick.psd1** - Fast validation (5-10 min)
  - Unit tests without coverage
  - Quick static analysis
  - Syntax validation
  
- **test-full.psd1** - Comprehensive testing (30-45 min)
  - Unit tests with coverage
  - Integration tests
  - Full static analysis
  - Performance benchmarks
  - Report generation

### Setup

- **dev-environment.psd1** - Developer environment setup
  - Core development tools
  - PowerShell modules
  - VS Code configuration
  - AI tools setup

### Git Workflows

- **git-workflow.psd1** - Standard Git workflow
  - Branch creation
  - Conventional commits
  - Push and PR creation
  - Pre-commit hooks

## Advanced Features

### Stage Variables

Variables can be defined at multiple levels:
1. Playbook defaults
2. Stage-specific overrides
3. Command-line overrides

```powershell
# Stage with custom variables
@{
    Name = 'Run Tests'
    Sequence = @('0402')
    Variables = @{
        RunCoverage = $true
        FailFast = $false
    }
}
```

### Conditional Execution

```powershell
# Stage with conditional
@{
    Name = 'Create PR'
    Sequence = @('0703')
    Conditional = @{
        When = 'Variables.CreatePR -eq $true'
    }
}
```

### Quality Gates

```powershell
# Define quality requirements
QualityGates = @{
    Coverage = @{
        Threshold = 80
        FailBuild = $true
    }
    Tests = @{
        MinimumPassRate = 100
    }
}
```

### Profiles

Playbooks can define multiple execution profiles:

```powershell
Profiles = @{
    Minimal = @{
        Description = 'Minimal execution'
        Variables = @{
            RunTests = $false
        }
    }
    Full = @{
        Description = 'Full execution'
        Variables = @{
            RunTests = $true
            RunCoverage = $true
        }
    }
}
```

## Migration from JSON

The project maintains backward compatibility with JSON playbooks. When both formats exist, PSD1 takes precedence. JSON playbooks are marked with "(JSON)" suffix in the UI.

To convert a JSON playbook to PSD1:
1. Load the JSON playbook
2. Save it with Format='PSD1' parameter
3. Manually enhance with PSD1-specific features

## Best Practices

1. **Keep playbooks focused** - Each playbook should have a single, clear purpose
2. **Use descriptive names** - Playbook names should explain what they do
3. **Document stages** - Each stage should have a clear description
4. **Set appropriate timeouts** - Prevent hanging executions
5. **Use variables** - Make playbooks configurable and reusable
6. **Test incrementally** - Use dry-run mode to verify before executing

## Troubleshooting

### Playbook Not Found
- Ensure the playbook is in the `playbooks-psd1` directory
- Check file extension is `.psd1`
- Verify the Name property matches the filename

### Syntax Errors
- Use PowerShell ISE or VS Code to validate PSD1 syntax
- Run `Import-PowerShellDataFile` to test loading

### Variable Issues
- Remember that PSD1 files use PowerShell syntax for booleans: `$true`/`$false`
- Arrays use `@()` syntax
- Strings should be quoted

## Support

For issues or questions about PSD1 playbooks:
- Check existing playbooks for examples
- Review this documentation
- Test with dry-run mode first
- Check logs in `./logs` directory