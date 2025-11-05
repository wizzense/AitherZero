# AitherZero Style Guide

## Purpose

This guide ensures consistency across all AitherZero components: CLI, UI, extensions, and configurations. Following these standards guarantees proper integration, rendering, and functionality.

## Table of Contents

1. [PowerShell Code Style](#powershell-code-style)
2. [Extension Development](#extension-development)
3. [Configuration Manifests](#configuration-manifests)
4. [CLI Command Structure](#cli-command-structure)
5. [UI Rendering](#ui-rendering)
6. [Testing Requirements](#testing-requirements)
7. [Documentation Standards](#documentation-standards)

---

## PowerShell Code Style

### Naming Conventions

**Functions:**
```powershell
# ✅ CORRECT - Approved verb, PascalCase noun
Get-ConfigurationData
Set-ExtensionMode
Invoke-CommandParser

# ❌ WRONG - Unapproved verb, wrong case
Fetch-ConfigurationData  # Use Get-
set-extensionMode        # Use Set- and PascalCase
Run-CommandParser        # Use Invoke-
```

**Approved Verbs:** Use `Get-Verb` to check. Common: `Get`, `Set`, `New`, `Remove`, `Invoke`, `Test`, `Show`

**Variables:**
```powershell
# ✅ CORRECT - PascalCase for important variables
$ConfigPath = "./config.psd1"
$ExtensionName = "MyExtension"

# ✅ CORRECT - camelCase for local/temporary variables
$configData = Get-Content $ConfigPath
$tempFile = Join-Path $env:TEMP "output.txt"
```

**Parameters:**
```powershell
# ✅ CORRECT - PascalCase with full names
param(
    [Parameter(Mandatory)]
    [string]$ConfigurationName,
    
    [Parameter()]
    [string]$OutputPath = "./output",
    
    [switch]$Force
)
```

### Function Structure

**Standard Template:**
```powershell
function Get-ExampleData {
    <#
    .SYNOPSIS
        Brief one-line description
    
    .DESCRIPTION
        Detailed multi-line description of what the function does
    
    .PARAMETER Source
        Description of the Source parameter
    
    .PARAMETER Force
        Description of the Force switch
    
    .EXAMPLE
        Get-ExampleData -Source "test"
        
        Gets example data from the test source
    
    .EXAMPLE
        Get-ExampleData -Source "prod" -Force
        
        Forces retrieval from production source
    
    .OUTPUTS
        PSCustomObject with example data
    
    .NOTES
        Author: Team Name
        Version: 1.0.0
        Requires: PowerShell 7.0+
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('test', 'dev', 'prod')]
        [string]$Source,
        
        [switch]$Force
    )
    
    begin {
        # Initialization - runs once
        Write-Verbose "Starting $($MyInvocation.MyCommand)"
        $results = @()
    }
    
    process {
        # Main logic - runs per pipeline input
        try {
            # Your logic here
            $data = Get-DataFromSource -Source $Source -Force:$Force
            $results += $data
        }
        catch {
            Write-Error "Failed to get data: $_"
            throw
        }
    }
    
    end {
        # Cleanup - runs once
        Write-Verbose "Completed with $($results.Count) items"
        return $results
    }
}
```

### Error Handling

```powershell
# ✅ CORRECT - Proper try/catch with meaningful errors
try {
    $config = Get-Content $ConfigPath -ErrorAction Stop | ConvertFrom-Json
}
catch [System.IO.FileNotFoundException] {
    Write-Error "Config file not found: $ConfigPath"
    throw
}
catch {
    Write-Error "Failed to parse config: $_"
    throw
}

# ❌ WRONG - Empty catch or swallowing errors
try {
    $config = Get-Content $ConfigPath | ConvertFrom-Json
}
catch {
    # Silent failure - BAD!
}
```

### Logging

```powershell
# ✅ CORRECT - Use Write-CustomLog if available
if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
    Write-CustomLog -Message "Processing config" -Level 'Information'
    Write-CustomLog -Message "Warning detected" -Level 'Warning'
    Write-CustomLog -Message "Error occurred" -Level 'Error'
}
else {
    # Fallback to standard cmdlets
    Write-Verbose "Processing config"
    Write-Warning "Warning detected"
    Write-Error "Error occurred"
}
```

### Cross-Platform Code

```powershell
# ✅ CORRECT - Check platform variables
$configDir = if ($IsWindows) {
    "$env:USERPROFILE\.aitherzero"
}
elseif ($IsLinux -or $IsMacOS) {
    "$HOME/.aitherzero"
}
else {
    throw "Unsupported platform"
}

# Use forward slashes (works on all platforms)
$scriptPath = Join-Path $PSScriptRoot "scripts/example.ps1"

# ❌ WRONG - Windows-only paths
$configDir = "C:\Users\$env:USERNAME\.aitherzero"
$scriptPath = "$PSScriptRoot\scripts\example.ps1"
```

---

## Extension Development

### Extension Manifest Structure

**File:** `MyExtension.extension.psd1`

```powershell
@{
    # Required fields
    Name = 'MyExtension'
    Version = '1.0.0'
    Description = 'Brief description of extension'
    Author = 'Your Name'
    
    # Extension metadata
    Manifest = @{
        # Minimum AitherZero version required
        RequiredVersion = '2.0.0'
        
        # Extension type (values: 'Feature', 'Integration', 'Tool', 'Domain')
        Type = 'Feature'
        
        # Extension category for organization
        Category = 'Development'
    }
    
    # CLI modes this extension provides
    CLIModes = @(
        @{
            Name = 'MyMode'
            Handler = 'Invoke-MyModeHandler'
            Description = 'Description of mode'
            Parameters = @('Target', 'Action', 'Options')
        }
    )
    
    # PowerShell modules to load
    Modules = @(
        @{
            Path = './modules/MyExtension.psm1'
            Functions = @('Get-MyData', 'Set-MyConfig')
        }
    )
    
    # Automation scripts (8000-8999 range)
    Scripts = @(
        @{
            Number = 8000
            Name = 'MyExtension-Setup'
            Path = './scripts/8000_MyExtension-Setup.ps1'
            Description = 'Setup script'
            Stage = 'Setup'
        },
        @{
            Number = 8001
            Name = 'MyExtension-Status'
            Path = './scripts/8001_MyExtension-Status.ps1'
            Description = 'Status check'
            Stage = 'Validation'
        }
    )
    
    # Dependencies on other extensions
    Dependencies = @(
        @{
            Name = 'CoreExtension'
            MinVersion = '1.0.0'
        }
    )
    
    # Initialization hook (optional)
    Initialize = './Initialize.ps1'
    
    # Cleanup hook (optional)
    Cleanup = './Cleanup.ps1'
    
    # Configuration schema (optional)
    ConfigSchema = @{
        ApiEndpoint = @{
            Type = 'String'
            Required = $true
            Default = 'https://api.example.com'
        }
        EnableFeature = @{
            Type = 'Boolean'
            Required = $false
            Default = $true
        }
    }
}
```

### Extension Directory Structure

```
extensions/MyExtension/
├── MyExtension.extension.psd1  # Manifest (required)
├── README.md                    # Documentation (required)
├── Initialize.ps1               # Init hook (optional)
├── Cleanup.ps1                  # Cleanup hook (optional)
├── modules/
│   └── MyExtension.psm1        # PowerShell module
├── scripts/
│   ├── 8000_MyExtension-Setup.ps1
│   └── 8001_MyExtension-Status.ps1
└── tests/
    └── MyExtension.Tests.ps1    # Pester tests (required)
```

### Extension Module Template

**File:** `modules/MyExtension.psm1`

```powershell
#Requires -Version 7.0

<#
.SYNOPSIS
    MyExtension PowerShell module

.DESCRIPTION
    Provides functionality for MyExtension integration
#>

# Get extension root
$ExtensionRoot = Split-Path $PSScriptRoot -Parent

# Import dependencies if needed
# Import-Module SomeDependency -ErrorAction Stop

function Get-MyData {
    <#
    .SYNOPSIS
        Get data from MyExtension
    
    .PARAMETER Source
        Data source to query
    
    .EXAMPLE
        Get-MyData -Source "api"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('api', 'local', 'cache')]
        [string]$Source
    )
    
    # Implementation
    Write-Verbose "Getting data from $Source"
    
    # Return data
    return @{
        Source = $Source
        Data = "Sample data"
    }
}

function Set-MyConfig {
    <#
    .SYNOPSIS
        Configure MyExtension settings
    
    .PARAMETER Setting
        Setting name
    
    .PARAMETER Value
        Setting value
    
    .EXAMPLE
        Set-MyConfig -Setting "ApiKey" -Value "abc123"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Setting,
        
        [Parameter(Mandatory)]
        [string]$Value
    )
    
    if ($PSCmdlet.ShouldProcess($Setting, "Set configuration")) {
        # Implementation
        Write-Verbose "Setting $Setting = $Value"
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Get-MyData',
    'Set-MyConfig'
)
```

### Extension Script Template

**File:** `scripts/8000_MyExtension-Setup.ps1`

```powershell
#Requires -Version 7.0

<#
.SYNOPSIS
    Setup script for MyExtension

.DESCRIPTION
    Performs initial setup and configuration for MyExtension

.PARAMETER Force
    Force setup even if already configured

.EXAMPLE
    ./8000_MyExtension-Setup.ps1
    
.EXAMPLE
    ./8000_MyExtension-Setup.ps1 -Force

.NOTES
    Stage: Setup
    Dependencies: None
    Tags: setup, initialization
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Force
)

# Import extension module
$ExtensionRoot = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $ExtensionRoot "modules/MyExtension.psm1") -Force

# Script logic
try {
    Write-Host "Setting up MyExtension..." -ForegroundColor Cyan
    
    if ($PSCmdlet.ShouldProcess("MyExtension", "Setup")) {
        # Setup logic here
        Set-MyConfig -Setting "Initialized" -Value $true
        
        Write-Host "✅ Setup completed successfully" -ForegroundColor Green
    }
}
catch {
    Write-Error "Setup failed: $_"
    exit 1
}
```

### Extension Testing

**File:** `tests/MyExtension.Tests.ps1`

```powershell
#Requires -Module Pester

BeforeAll {
    $ExtensionRoot = Split-Path $PSScriptRoot -Parent
    $ModulePath = Join-Path $ExtensionRoot "modules/MyExtension.psm1"
    Import-Module $ModulePath -Force
}

Describe "MyExtension Module" {
    Context "Get-MyData" {
        It "Should return data from specified source" {
            $result = Get-MyData -Source "api"
            $result | Should -Not -BeNullOrEmpty
            $result.Source | Should -Be "api"
        }
        
        It "Should validate source parameter" {
            { Get-MyData -Source "invalid" } | Should -Throw
        }
    }
    
    Context "Set-MyConfig" {
        It "Should set configuration value" {
            { Set-MyConfig -Setting "test" -Value "value" } | Should -Not -Throw
        }
        
        It "Should support -WhatIf" {
            { Set-MyConfig -Setting "test" -Value "value" -WhatIf } | Should -Not -Throw
        }
    }
}

Describe "Extension Integration" {
    It "Extension manifest should exist" {
        $manifestPath = Join-Path $ExtensionRoot "MyExtension.extension.psd1"
        $manifestPath | Should -Exist
    }
    
    It "Extension manifest should be valid" {
        $manifestPath = Join-Path $ExtensionRoot "MyExtension.extension.psd1"
        $manifest = Import-PowerShellDataFile $manifestPath
        $manifest.Name | Should -Be "MyExtension"
        $manifest.Version | Should -Match '^\d+\.\d+\.\d+$'
    }
}
```

---

## Configuration Manifests

### Config.psd1 Structure

```powershell
@{
    # Core settings
    Core = @{
        Version = '2.0.0'
        Profile = 'Standard'  # Minimal, Standard, Developer, Full
        Environment = 'Development'  # Development, Staging, Production
    }
    
    # Manifest section - drives UI/CLI capabilities
    Manifest = @{
        # CLI modes available
        SupportedModes = @(
            'Interactive',
            'Run',
            'Orchestrate',
            'List',
            'Search',
            'Test',
            'Validate'
        )
        
        # Script inventory (must be accurate!)
        ScriptInventory = @{
            Total = 130
            ByRange = @{
                '0000-0099' = 8   # Environment
                '0100-0199' = 12  # Infrastructure
                '0200-0299' = 15  # Development
                '0400-0499' = 20  # Testing
                '0500-0599' = 10  # Reports
                '0700-0799' = 15  # Git/AI
                '0800-0899' = 5   # Issues
                '0900-0999' = 10  # Validation
                '9000-9999' = 35  # Maintenance
            }
        }
    }
    
    # Features section - controls visibility
    Features = @{
        Git = @{
            Enabled = $true
            Config = @{
                DefaultBranch = 'main'
                AutoCommit = $false
            }
        }
        Docker = @{
            Enabled = $true
            Config = @{
                Registry = 'local'
            }
        }
    }
    
    # Extensions section
    Extensions = @{
        Enabled = $true
        SearchPaths = @(
            './extensions',
            "$HOME/.aitherzero/extensions"
        )
        EnabledExtensions = @(
            'ExampleExtension'
        )
    }
    
    # Automation settings
    Automation = @{
        MaxConcurrency = 4
        TimeoutSeconds = 600
        RetryCount = 3
    }
    
    # Testing configuration
    Testing = @{
        Profile = 'Standard'  # Quick, Standard, Full, CI
        Coverage = @{
            Enabled = $true
            Threshold = 80
        }
    }
}
```

### Config Validation Rules

1. **Version must be semantic:** `X.Y.Z`
2. **Profile must be valid:** `Minimal`, `Standard`, `Developer`, `Full`
3. **ScriptInventory must match actual scripts** (validate with `0413_Validate-ConfigManifest.ps1`)
4. **SupportedModes must be consistent** with Start-AitherZero.ps1
5. **Extensions must exist** if listed in EnabledExtensions

---

## CLI Command Structure

### Command Pattern

All CLI commands follow this structure:

```
./Start-AitherZero.ps1 -Mode <Mode> -Target <Target> [-Action <Action>] [-Options <Options>]
```

### Mode Definitions

**Standard Modes:**
- `Interactive` - Interactive menu
- `Run` - Execute script(s)
- `Orchestrate` - Run playbook
- `List` - List available scripts
- `Search` - Search scripts
- `Test` - Run tests
- `Validate` - Validate configuration

**Extension Modes:**
Extensions register custom modes via manifest

### Parameter Guidelines

```powershell
# ✅ CORRECT - Standard parameter names
-Mode Run -Target 0402
-Mode Orchestrate -Target test-quick
-Mode Example -Target demo -Action run

# ❌ WRONG - Non-standard names
-Type Run -Script 0402
-Mode Orchestrate -Playbook test-quick
```

### Shortcuts

```powershell
# These shortcuts are parsed by CommandParser
test        → -Mode Run -Target 0402,0404,0407
lint        → -Mode Run -Target 0404
quick-test  → -Mode Orchestrate -Target test-quick
0402        → -Mode Run -Target 0402
```

---

## UI Rendering

### Menu Hierarchy

```
Main Menu
├── Mode Selection (Run, Orchestrate, etc.)
│   ├── Category Selection (if Mode = Run)
│   │   ├── Script Selection
│   │   └── Execution Confirmation
│   └── Target Selection (if other modes)
└── Direct Command Input
```

### Breadcrumb Format

```
AitherZero > Mode > Category > Target
```

Examples:
```
AitherZero > _
AitherZero > Run > _
AitherZero > Run > Testing & Validation > _
AitherZero > Run > Testing & Validation > [0402] Run Unit Tests
```

### Command Display

```
Current Command: -Mode Run -Target 0402
```

### Menu Item Format

```
► [1] 🎯 Mode Name - Description
  [2] 📚 Mode Name - Description
```

- `►` indicates current selection
- Emoji provides visual distinction
- Number in brackets for selection
- Clear description

### Color Scheme

```powershell
# Use these colors consistently
Cyan       # Headers, titles
Green      # Success, completion
Yellow     # Warnings, prompts
Red        # Errors, failures
White      # Normal text
Gray       # Secondary text, hints
```

---

## Testing Requirements

### Test File Naming

```
{ComponentName}.Tests.ps1
```

Examples:
- `BreadcrumbNavigation.Tests.ps1`
- `CommandParser.Tests.ps1`
- `MyExtension.Tests.ps1`

### Test Structure

```powershell
#Requires -Module Pester

BeforeAll {
    # Module imports
    $ModulePath = Join-Path $PSScriptRoot "../ComponentName.psm1"
    Import-Module $ModulePath -Force
}

Describe "Component Name" {
    Context "Function Name" {
        It "Should do expected behavior" {
            $result = Invoke-Function -Parameter "value"
            $result | Should -Be "expected"
        }
        
        It "Should handle invalid input" {
            { Invoke-Function -Parameter "" } | Should -Throw
        }
    }
}

Describe "Integration" {
    It "Should integrate with system" {
        # Integration test
    }
}
```

### Coverage Requirements

- **Minimum coverage:** 80%
- **Critical paths:** 100%
- **Error handling:** Must be tested
- **Cross-platform:** Test on Windows + Linux

### Test Execution

```powershell
# Single test file
Invoke-Pester -Path "./ComponentName.Tests.ps1" -Output Detailed

# With coverage
Invoke-Pester -Path "./ComponentName.Tests.ps1" -CodeCoverage "./ComponentName.psm1"

# All tests
Invoke-Pester -Path "./tests"
```

---

## Documentation Standards

### README.md Template

```markdown
# Component/Extension Name

Brief one-line description

## Overview

Detailed description of what this component does and why it exists.

## Features

- Feature 1
- Feature 2
- Feature 3

## Installation

\`\`\`powershell
# Installation steps
\`\`\`

## Usage

### Basic Usage

\`\`\`powershell
# Example 1
Get-Example -Parameter "value"
\`\`\`

### Advanced Usage

\`\`\`powershell
# Example 2 with explanation
Get-Example -Parameter "value" -Advanced
\`\`\`

## Configuration

Describe any configuration options

## API Reference

### Function-Name

Description

**Parameters:**
- `Parameter1` (String, Required) - Description
- `Parameter2` (Switch, Optional) - Description

**Returns:** Description of return value

**Example:**
\`\`\`powershell
Function-Name -Parameter1 "value"
\`\`\`

## Testing

\`\`\`powershell
# Run tests
Invoke-Pester -Path "./tests"
\`\`\`

## Troubleshooting

Common issues and solutions

## Contributing

How to contribute to this component

## License

License information
```

### Comment-Based Help

Always include for public functions:

```powershell
<#
.SYNOPSIS
    Brief description

.DESCRIPTION
    Detailed description

.PARAMETER ParameterName
    Parameter description

.EXAMPLE
    Example-Function -Parameter "value"
    
    Example description

.OUTPUTS
    Output type description

.NOTES
    Additional notes
#>
```

---

## Validation Checklist

Before committing changes, verify:

### Code Quality
- [ ] PowerShell code follows naming conventions
- [ ] Functions have comment-based help
- [ ] Error handling is implemented
- [ ] Cross-platform compatibility checked
- [ ] PSScriptAnalyzer passes (`az 0404`)
- [ ] Syntax validation passes (`az 0407`)

### Extension Integration
- [ ] Extension manifest is valid
- [ ] Extension tests pass
- [ ] CLI modes register correctly
- [ ] Scripts use 8000-8999 range
- [ ] README.md is complete

### Configuration
- [ ] Config.psd1 syntax is valid
- [ ] ScriptInventory matches actual scripts
- [ ] SupportedModes are consistent
- [ ] Config validation passes (`az 0413`)

### UI/CLI Rendering
- [ ] Breadcrumbs display correctly
- [ ] Menu items format properly
- [ ] Commands build correctly
- [ ] Navigation works smoothly

### Testing
- [ ] Unit tests written and passing
- [ ] Integration tests added
- [ ] Coverage meets threshold (80%+)
- [ ] Tests run on multiple platforms

### Documentation
- [ ] README.md updated
- [ ] API reference complete
- [ ] Examples provided
- [ ] Comments are clear

---

## Quick Reference

### Common Commands

```powershell
# Validate code
aitherzero 0404  # PSScriptAnalyzer
aitherzero 0407  # Syntax check

# Run tests
aitherzero 0402  # Unit tests
aitherzero 0403  # Integration tests

# Validate config
aitherzero 0413  # Config manifest validation

# Create extension
New-ExtensionTemplate -Name "MyExt" -Path "./extensions"

# Load extension
Import-Extension -Name "MyExt"

# Switch config
Show-ConfigurationSelector
```

### File Locations

```
Code Style:           docs/STYLE-GUIDE.md (this file)
Copilot Instructions: .github/copilot-instructions.md
Architecture:         docs/CONFIG-DRIVEN-ARCHITECTURE.md
Extensions:           docs/EXTENSIONS.md
Testing:              docs/TESTING-GUIDE.md (to be created)
```

---

## Getting Help

- **Style questions:** Check this guide first
- **Architecture questions:** See `docs/CONFIG-DRIVEN-ARCHITECTURE.md`
- **Extension help:** See `docs/EXTENSIONS.md`
- **Copilot guidance:** See `.github/copilot-instructions.md`

---

**Version:** 1.0.0  
**Last Updated:** 2025-11-05  
**Maintainer:** AitherZero Team
