# AitherZero Configuration Guide

## Overview

AitherZero uses a hierarchical configuration system that enables zero-parameter operation in CI/CD environments while providing flexibility for local development and customization.

## Quick Start

### For CI/CD Environments

No configuration needed! AitherZero automatically detects CI environments and applies appropriate defaults:

```yaml
# GitHub Actions - Works automatically
- name: Run AitherZero
  run: |
    ./bootstrap.ps1           # Auto-detects CI, uses Full profile
    ./Start-AitherZero.ps1     # Runs non-interactively
```

```yaml
# Azure DevOps - Works automatically
- powershell: |
    ./bootstrap.ps1
    ./Start-AitherZero.ps1
```

### For Local Development

1. **Use defaults** - Just run scripts, they have sensible defaults:
   ```powershell
   ./bootstrap.ps1
   ./Start-AitherZero.ps1
   ```

2. **Customize via parameters**:
   ```powershell
   ./bootstrap.ps1 -InstallProfile Developer
   ./Start-AitherZero.ps1 -Profile Full
   ```

3. **Create local overrides** (optional):
   ```powershell
   # Copy example and customize
   Copy-Item config.example.psd1 config.local.psd1
   # Edit config.local.psd1 as needed
   ```

## Configuration Files

### File Types and Precedence

AitherZero checks for configuration in this order (highest priority first):

1. **Command-line parameters** - Direct script parameters
2. **Environment variables** - `AITHERZERO_*` prefixed variables
3. **config.local.psd1** - Local overrides (gitignored)
4. **config.psd1** - Main configuration file
5. **CI defaults** - Automatically applied in CI environments
6. **Script defaults** - Fallback values in scripts

### Configuration Files

| File | Purpose | In Git | When to Use |
|------|---------|--------|-------------|
| `config.example.psd1` | Documented template | ✅ Yes | Reference/starting point |
| `config.psd1` | Main configuration | ✅ Yes | Shared team settings |
| `config.local.psd1` | Local overrides | ❌ No | Personal preferences |
| `.env` | Environment variables | ❌ No | Secrets/credentials |

## Configuration Format

AitherZero uses PowerShell Data Files (`.psd1`) for configuration:

```powershell
@{
    Core = @{
        Profile = 'Standard'          # Minimal, Standard, Developer, Full
        Environment = 'Development'   # Development, Testing, Production, CI
        DebugMode = $false           # Enable debug output
    }
    
    Automation = @{
        NonInteractive = $false      # No prompts (auto-true in CI)
        WhatIf = $false             # Preview mode
        MaxConcurrency = 4          # Parallel execution limit
    }
    
    Testing = @{
        Profile = 'Standard'         # Quick, Standard, Full, CI
        RunCoverage = $true         # Generate coverage reports
        CoverageThreshold = 80      # Minimum coverage %
    }
}
```

## Using Configuration in Scripts

### Get-ConfiguredValue Function

The recommended way to use configuration in scripts:

```powershell
# Import the Configuration module
Import-Module ./domains/configuration/Configuration.psm1

# Simple usage with default
$ProfileName = Get-ConfiguredValue -Name 'Profile' -Default 'Standard'

# With section specification
$debug = Get-ConfiguredValue -Name 'DebugMode' -Section 'Core' -Default $false

# In script parameters
param(
    [string]$ProfileName = (Get-ConfiguredValue -Name 'Profile' -Default 'Standard'),
    [switch]$WhatIf = (Get-ConfiguredValue -Name 'WhatIf' -Section 'Automation' -Default $false)
)
```

### Direct Configuration Access

```powershell
# Get entire configuration
$config = Get-Configuration

# Get specific section
$coreConfig = Get-Configuration -Section Core

# Access values
$ProfileName = $config.Core.Profile
$nonInteractive = $config.Automation.NonInteractive
```

## Environment Variables

### Setting Environment Variables

Environment variables override configuration file settings:

```powershell
# PowerShell
$env:AITHERZERO_PROFILE = "Full"
$env:AITHERZERO_DEBUGMODE = "true"
$env:AITHERZERO_NONINTERACTIVE = "true"

# Bash/Linux
export AITHERZERO_PROFILE="Full"
export AITHERZERO_DEBUGMODE="true"
export AITHERZERO_NONINTERACTIVE="true"

# Windows Command Prompt
set AITHERZERO_PROFILE=Full
set AITHERZERO_DEBUGMODE=true
set AITHERZERO_NONINTERACTIVE=true
```

### Environment Variable Naming

- Prefix: `AITHERZERO_`
- Section separator: `_` (underscore)
- Name format: `UPPERCCASE`

Examples:
- `AITHERZERO_PROFILE` → `Core.Profile`
- `AITHERZERO_AUTOMATION_WHATIF` → `Automation.WhatIf`
- `AITHERZERO_TESTING_PROFILE` → `Testing.Profile`

## CI/CD Integration

### Automatic CI Detection

AitherZero detects these CI environments automatically:

- GitHub Actions (`GITHUB_ACTIONS=true`)
- Azure DevOps (`TF_BUILD=true`)
- GitLab CI (`GITLAB_CI=true`)
- Jenkins (`JENKINS_URL` exists)
- CircleCI (`CIRCLECI=true`)
- Travis CI (`TRAVIS=true`)
- AppVeyor (`APPVEYOR=true`)
- Generic CI (`CI=true`)

### CI Default Behaviors

When CI is detected, these defaults are applied:

| Setting | CI Default | Reason |
|---------|------------|---------|
| Profile | Full | Ensure all components available |
| NonInteractive | true | No user prompts in CI |
| Environment | CI | Identify as CI environment |
| WhatIf | false | Execute real actions |
| SkipPrerequisites | false | Always validate prerequisites |
| StopOnError | true | Fail fast in CI |
| LogLevel | Information | Detailed logging |
| RunCoverage | true | Generate coverage reports |

### GitHub Actions Example

```yaml
name: CI Pipeline
on: [push, pull_request]

jobs:
  test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Bootstrap AitherZero
        run: ./bootstrap.ps1
        # Automatically uses Full profile, NonInteractive mode
      
      - name: Run Tests
        run: ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-ci
        # Uses CI defaults automatically
      
      - name: Custom Configuration
        env:
          AITHERZERO_TESTING_PROFILE: Full
          AITHERZERO_TESTING_COVERAGETHRESHOLD: 90
        run: |
          az 0402  # Run tests with 90% coverage requirement
```

### Azure DevOps Example

```yaml
trigger:
- main
- develop

pool:
  vmImage: 'windows-latest'

steps:
- powershell: |
    # Bootstrap automatically detects Azure DevOps
    ./bootstrap.ps1
    
    # Run with CI defaults
    ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-full
  displayName: 'Run AitherZero Tests'

- powershell: |
    # Override specific settings
    $env:AITHERZERO_REPORTING_OUTPUTFORMAT = "XML"
    az 0510  # Generate report in XML format
  displayName: 'Generate Reports'
```

## Configuration Profiles

### Core Profiles

| Profile | Use Case | Components Installed |
|---------|----------|---------------------|
| **Minimal** | CI validation, quick checks | Core modules only |
| **Standard** | Regular development | Core + common tools |
| **Developer** | Full development | Standard + dev tools |
| **Full** | Complete environment | Everything |

### Testing Profiles

| Profile | Duration | Coverage | Use Case |
|---------|----------|----------|----------|
| **Quick** | 5-10 sec | Unit tests only | Local development |
| **Standard** | 1-2 min | Unit + Integration | Pre-commit |
| **Full** | 5-10 min | All tests | Pre-release |
| **CI** | 2-5 min | Optimized suite | CI pipelines |

## Common Scenarios

### 1. Local Development Setup

```powershell
# Create local configuration
Copy-Item config.example.psd1 config.local.psd1

# Edit to enable development tools
# In config.local.psd1:
@{
    Core = @{
        Profile = 'Developer'
        DebugMode = $true
    }
    InstallationOptions = @{
        VSCode = @{ Install = $true }
        DockerDesktop = @{ Install = $true }
    }
}

# Run bootstrap
./bootstrap.ps1
```

### 2. CI Pipeline Configuration

```powershell
# No configuration needed! Just run:
./bootstrap.ps1
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-ci
```

### 3. Custom Test Coverage Requirements

```powershell
# Via environment variable
$env:AITHERZERO_TESTING_COVERAGETHRESHOLD = "90"
az 0402

# Via parameter
./automation-scripts/0402_Run-UnitTests.ps1 -CoverageThreshold 90

# Via config file (config.local.psd1)
@{
    Testing = @{
        CoverageThreshold = 90
    }
}
```

### 4. Production Deployment

```powershell
# Set production defaults
$env:AITHERZERO_ENVIRONMENT = "Production"
$env:AITHERZERO_AUTOMATION_STOPTONERROR = "true"
$env:AITHERZERO_AUTOMATION_WHATIF = "true"  # Preview first

# Preview changes
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook deploy-prod

# If preview looks good, execute
$env:AITHERZERO_AUTOMATION_WHATIF = "false"
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook deploy-prod
```

## Troubleshooting

### Configuration Not Loading

1. **Check file exists**:
   ```powershell
   Test-Path ./config.psd1
   Test-Path ./config.local.psd1
   ```

2. **Validate syntax**:
   ```powershell
   $config = Import-PowerShellDataFile ./config.psd1
   ```

3. **Check module loaded**:
   ```powershell
   Import-Module ./domains/configuration/Configuration.psm1 -Force
   Get-Configuration
   ```

### Environment Variables Not Working

1. **Verify naming**:
   ```powershell
   # Correct
   $env:AITHERZERO_PROFILE = "Full"
   
   # Wrong (missing prefix)
   $env:PROFILE = "Full"
   ```

2. **Check case sensitivity** (Linux/macOS):
   ```bash
   # Linux/macOS are case-sensitive
   export AITHERZERO_PROFILE="Full"  # Correct
   export aitherzero_profile="Full"  # Wrong
   ```

3. **Verify in PowerShell**:
   ```powershell
   Get-ChildItem env:AITHERZERO_*
   ```

### CI Detection Not Working

Force CI mode manually:

```powershell
# Option 1: Set CI environment variable
$env:CI = "true"

# Option 2: Use NonInteractive parameter
./bootstrap.ps1 -NonInteractive

# Option 3: Set in config
@{
    Core = @{
        Environment = 'CI'
    }
    Automation = @{
        NonInteractive = $true
    }
}
```

## Best Practices

### 1. Use Get-ConfiguredValue in Scripts

```powershell
# Good - Uses configuration system
param(
    [string]$ProfileName = (Get-ConfiguredValue -Name 'Profile' -Default 'Standard')
)

# Bad - Hardcoded default
param(
    [string]$ProfileName = 'Standard'
)
```

### 2. Document Configuration Dependencies

```powershell
<#
.SYNOPSIS
    Runs unit tests
.NOTES
    Configuration:
    - Testing.Profile: Determines test scope
    - Testing.RunCoverage: Enables coverage reporting
    - Testing.CoverageThreshold: Minimum coverage required
#>
```

### 3. Provide Sensible Defaults

```powershell
# Always provide a fallback default
$value = Get-ConfiguredValue -Name 'SomeSetting' -Default 'safe-default'

# Not just
$value = Get-ConfiguredValue -Name 'SomeSetting'  # May return $null
```

### 4. Use Sections for Organization

```powershell
# Good - Organized by section
$debugMode = Get-ConfiguredValue -Name 'DebugMode' -Section 'Core'
$whatIf = Get-ConfiguredValue -Name 'WhatIf' -Section 'Automation'

# Less clear - No section context
$debugMode = Get-ConfiguredValue -Name 'CoreDebugMode'
```

### 5. Keep Secrets Out of Config Files

```powershell
# Bad - Secret in config
@{
    AI = @{
        APIKey = 'sk-abc123...'  # Never do this!
    }
}

# Good - Use environment variable
@{
    AI = @{
        APIKey = ''  # Set via $env:AITHERZERO_AI_APIKEY
    }
}
```

## Migration from config.json

If you have an existing `config.json`:

```powershell
# 1. Run the conversion script
./Convert-ConfigToPsd1.ps1 -Backup

# 2. Review the generated config.psd1
code ./config.psd1

# 3. Test configuration loading
Import-Module ./domains/configuration/Configuration.psm1 -Force
$config = Get-Configuration
$config | ConvertTo-Json -Depth 10

# 4. Remove old config.json when satisfied
# (Already backed up as config.json.backup.*)
```

## Advanced Topics

### Custom Configuration Sections

Add your own configuration sections:

```powershell
# In config.psd1 or config.local.psd1
@{
    # ... standard sections ...
    
    MyCustomApp = @{
        DatabaseConnection = 'Server=localhost;Database=myapp'
        MaxRetries = 5
        EnableFeatureX = $true
    }
}

# Access in scripts
$dbConn = Get-ConfiguredValue -Name 'DatabaseConnection' -Section 'MyCustomApp'
```

### Dynamic Configuration

Load configuration based on environment:

```powershell
# Determine environment
$env = Get-ConfiguredValue -Name 'Environment' -Section 'Core' -Default 'Development'

# Load environment-specific config
$envConfig = "./config.$env.psd1"
if (Test-Path $envConfig) {
    $config = Import-PowerShellDataFile $envConfig
}
```

### Configuration Validation

```powershell
# Create validation function
function Test-Configuration {
    $config = Get-Configuration
    
    # Validate required settings
    if (-not $config.Core.Profile) {
        throw "Core.Profile is required"
    }
    
    if ($config.Core.Profile -notin @('Minimal', 'Standard', 'Developer', 'Full')) {
        throw "Invalid Profile: $($config.Core.Profile)"
    }
    
    # Validate numeric ranges
    if ($config.Testing.CoverageThreshold -lt 0 -or $config.Testing.CoverageThreshold -gt 100) {
        throw "CoverageThreshold must be between 0 and 100"
    }
    
    return $true
}

# Use in scripts
if (-not (Test-Configuration)) {
    exit 1
}
```

## Reference

### Configuration Schema

See `config.example.psd1` for the complete schema with all available settings and their descriptions.

### Related Documentation

- [README.md](../README.md) - Project overview
- [CLAUDE.md](../CLAUDE.md) - AI assistant instructions
- [orchestration/README.md](../orchestration/README.md) - Orchestration system
- [docs/TESTING.md](TESTING.md) - Testing framework

### Module Source

- [domains/configuration/Configuration.psm1](../domains/configuration/Configuration.psm1) - Configuration module implementation

## Support

For issues or questions about configuration:

1. Check this documentation
2. Review `config.example.psd1` for examples
3. Check existing issues on GitHub
4. Create a new issue with the `configuration` label