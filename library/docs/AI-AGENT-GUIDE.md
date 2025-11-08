# AI Agent Development Guide

## Purpose

This guide provides specific instructions for GitHub Copilot, custom agents, and AI assistants working on AitherZero to ensure proper code generation, extension creation, and system integration.

## Table of Contents

1. [AI Agent Principles](#ai-agent-principles)
2. [Code Generation Guidelines](#code-generation-guidelines)
3. [Extension Generation](#extension-generation)
4. [Config Manifest Updates](#config-manifest-updates)
5. [UI/CLI Integration](#uicli-integration)
6. [Testing Generation](#testing-generation)
7. [Documentation Generation](#documentation-generation)
8. [Common Patterns](#common-patterns)

---

## AI Agent Principles

### Core Rules for AI Agents

1. **Always validate config.psd1 after changes**
   ```powershell
   ./library/automation-scripts/0413_Validate-ConfigManifest.ps1
   ```

2. **Generate tests for all new code**
   - Unit tests in `tests/unit/`
   - Integration tests in `tests/integration/`
   - Use Pester 5.0+ syntax

3. **Follow naming conventions**
   - Use approved PowerShell verbs (`Get-Verb`)
   - PascalCase for functions and parameters
   - Extensions use 8000-8999 script range

4. **Update documentation**
   - README.md for new components
   - Comment-based help for functions
   - Update relevant guides

5. **Maintain consistency**
   - Match existing code style
   - Use established patterns
   - Follow architecture guidelines

---

## Code Generation Guidelines

### When Generating PowerShell Functions

**Template to use:**

```powershell
function Verb-Noun {
    <#
    .SYNOPSIS
        [BRIEF DESCRIPTION]
    
    .DESCRIPTION
        [DETAILED DESCRIPTION]
    
    .PARAMETER ParameterName
        [PARAMETER DESCRIPTION]
    
    .EXAMPLE
        Verb-Noun -ParameterName "value"
        
        [EXAMPLE DESCRIPTION]
    
    .OUTPUTS
        [OUTPUT TYPE AND DESCRIPTION]
    
    .NOTES
        Author: [AGENT NAME]
        Version: 1.0.0
        Requires: PowerShell 7.0+
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ParameterName,
        
        [Parameter()]
        [string]$OptionalParameter = "default",
        
        [switch]$Force
    )
    
    begin {
        Write-Verbose "Starting $($MyInvocation.MyCommand)"
        # Initialization
    }
    
    process {
        try {
            if ($PSCmdlet.ShouldProcess($ParameterName, "Action description")) {
                # Main logic
            }
        }
        catch {
            Write-Error "Operation failed: $_"
            throw
        }
    }
    
    end {
        Write-Verbose "Completed $($MyInvocation.MyCommand)"
        # Cleanup
    }
}
```

**Checklist:**
- [ ] Use approved verb (Get, Set, New, Remove, Invoke, Test, Show, etc.)
- [ ] PascalCase naming (Verb-Noun)
- [ ] Complete comment-based help
- [ ] Parameter validation attributes
- [ ] SupportsShouldProcess for state changes
- [ ] Error handling with try/catch
- [ ] Verbose logging
- [ ] Cross-platform compatible

### When Generating Script Files

**Template for automation scripts (0000-9999):**

```powershell
#Requires -Version 7.0

<#
.SYNOPSIS
    [BRIEF DESCRIPTION]

.DESCRIPTION
    [DETAILED DESCRIPTION]

.PARAMETER ParameterName
    [PARAMETER DESCRIPTION]

.EXAMPLE
    ./NNNN_Script-Name.ps1
    
.EXAMPLE
    ./NNNN_Script-Name.ps1 -ParameterName "value"

.NOTES
    Stage: [Setup|Validation|Execution|Reporting|Maintenance]
    Dependencies: [List any dependencies]
    Tags: [comma, separated, tags]
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$ParameterName = "default",
    
    [switch]$Force
)

# Import required modules
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
    Write-CustomLog -Message "Starting script" -Level 'Information'
}

# Main script logic
try {
    Write-Host "Starting..." -ForegroundColor Cyan
    
    if ($PSCmdlet.ShouldProcess("Target", "Action")) {
        # Implementation
    }
    
    Write-Host "✅ Completed successfully" -ForegroundColor Green
    exit 0
}
catch {
    Write-Error "Script failed: $_"
    exit 1
}
```

**Script numbering:**
- 0000-0099: Environment setup
- 0100-0199: Infrastructure
- 0200-0299: Development tools
- 0400-0499: Testing & validation
- 0500-0599: Reporting
- 0700-0799: Git/AI automation
- 0800-0899: Issue management
- 0900-0999: Validation
- 8000-8999: **Extensions only**
- 9000-9999: Maintenance

---

## Extension Generation

### When Creating Extensions

**Step-by-step process:**

1. **Create directory structure:**
```
extensions/ExtensionName/
├── ExtensionName.extension.psd1
├── README.md
├── Initialize.ps1
├── Cleanup.ps1
├── modules/
│   └── ExtensionName.psm1
├── scripts/
│   ├── 8000_ExtensionName-Setup.ps1
│   └── 8001_ExtensionName-Status.ps1
└── tests/
    └── ExtensionName.Tests.ps1
```

2. **Generate manifest (ExtensionName.extension.psd1):**
```powershell
@{
    Name = 'ExtensionName'
    Version = '1.0.0'
    Description = 'Description of extension'
    Author = 'Agent Name'
    
    Manifest = @{
        RequiredVersion = '2.0.0'
        Type = 'Feature'  # or 'Integration', 'Tool', 'Domain'
        Category = 'Development'  # or 'Infrastructure', 'Testing', etc.
    }
    
    CLIModes = @(
        @{
            Name = 'ExtensionMode'
            Handler = 'Invoke-ExtensionModeHandler'
            Description = 'Mode description'
            Parameters = @('Target', 'Action')
        }
    )
    
    Modules = @(
        @{
            Path = './modules/ExtensionName.psm1'
            Functions = @('Get-ExtensionData', 'Set-ExtensionConfig')
        }
    )
    
    Scripts = @(
        @{
            Number = 8000
            Name = 'ExtensionName-Setup'
            Path = './scripts/8000_ExtensionName-Setup.ps1'
            Description = 'Setup script'
            Stage = 'Setup'
        }
    )
    
    Initialize = './Initialize.ps1'
    Cleanup = './Cleanup.ps1'
}
```

3. **Generate module (modules/ExtensionName.psm1):**
```powershell
#Requires -Version 7.0

$ExtensionRoot = Split-Path $PSScriptRoot -Parent

function Get-ExtensionData {
    <#
    .SYNOPSIS
        Get data from extension
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Source
    )
    
    # Implementation
}

function Invoke-ExtensionModeHandler {
    <#
    .SYNOPSIS
        Handler for custom CLI mode
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Target,
        
        [Parameter()]
        [string]$Action
    )
    
    # Implementation
}

Export-ModuleMember -Function @(
    'Get-ExtensionData',
    'Invoke-ExtensionModeHandler'
)
```

4. **Generate tests (tests/ExtensionName.Tests.ps1):**
```powershell
#Requires -Module Pester

BeforeAll {
    $ExtensionRoot = Split-Path $PSScriptRoot -Parent
    $ModulePath = Join-Path $ExtensionRoot "modules/ExtensionName.psm1"
    Import-Module $ModulePath -Force
}

Describe "ExtensionName Module" {
    Context "Get-ExtensionData" {
        It "Should return data" {
            $result = Get-ExtensionData -Source "test"
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Invoke-ExtensionModeHandler" {
        It "Should handle mode" {
            { Invoke-ExtensionModeHandler -Target "demo" } | Should -Not -Throw
        }
    }
}

Describe "Extension Integration" {
    It "Extension manifest should be valid" {
        $manifestPath = Join-Path $ExtensionRoot "ExtensionName.extension.psd1"
        $manifestPath | Should -Exist
        
        $manifest = Import-PowerShellDataFile $manifestPath
        $manifest.Name | Should -Be "ExtensionName"
        $manifest.Version | Should -Match '^\d+\.\d+\.\d+$'
    }
}
```

5. **Generate README.md:**
```markdown
# ExtensionName

Brief description

## Installation

\`\`\`powershell
Import-Extension -Name "ExtensionName"
\`\`\`

## Usage

### CLI Mode

\`\`\`powershell
./Start-AitherZero.ps1 -Mode ExtensionMode -Target demo
\`\`\`

### Commands

\`\`\`powershell
Get-ExtensionData -Source "test"
\`\`\`

## Testing

\`\`\`powershell
Invoke-Pester -Path "./tests/ExtensionName.Tests.ps1"
\`\`\`
```

**Validation checklist:**
- [ ] Manifest has all required fields
- [ ] Module exports functions
- [ ] Scripts use 8000-8999 range
- [ ] Tests cover all functions
- [ ] README is complete
- [ ] Passes `Invoke-Pester`

---

## Config Manifest Updates

### When Modifying config.psd1

**ALWAYS follow this sequence:**

1. **Make changes to config.psd1**
2. **Validate immediately:**
   ```powershell
   ./library/automation-scripts/0413_Validate-ConfigManifest.ps1
   ```
3. **If validation fails, fix issues**
4. **Re-validate until successful**
5. **Commit changes**

### Common Config Updates

**Adding a new mode:**
```powershell
# In config.psd1
Manifest = @{
    SupportedModes = @(
        'Interactive',
        'Run',
        'Orchestrate',
        'NewMode'  # Add here
    )
}
```

**Adding extension to enabled list:**
```powershell
Extensions = @{
    EnabledExtensions = @(
        'ExampleExtension',
        'NewExtension'  # Add here
    )
}
```

**Updating script inventory:**
```powershell
# Count actual scripts first
$scriptCount = (Get-ChildItem ./library/automation-scripts/*.ps1).Count

# Update config
Manifest = @{
    ScriptInventory = @{
        Total = $scriptCount  # Must match actual count!
        ByRange = @{
            '0400-0499' = 20  # Count scripts in range
            # ... other ranges
        }
    }
}
```

**Enabling/disabling features:**
```powershell
Features = @{
    FeatureName = @{
        Enabled = $true  # or $false
        Config = @{
            # Feature-specific config
        }
    }
}
```

---

## UI/CLI Integration

### Ensuring Proper Rendering

**When adding CLI modes, ensure UI renders correctly:**

1. **Register mode in config.psd1:**
```powershell
Manifest = @{
    SupportedModes = @('Interactive', 'Run', 'NewMode')
}
```

2. **Verify UI can discover mode:**
```powershell
# UI should call:
$config = Get-Configuration
$modes = $config.Manifest.SupportedModes

# Should include 'NewMode'
```

3. **Add menu item generation:**
```powershell
# In UI code
foreach ($mode in $config.Manifest.SupportedModes) {
    $menuItem = @{
        Name = $mode
        Handler = "Invoke-$mode"
        Emoji = Get-ModeEmoji -Mode $mode
    }
    $menuItems += $menuItem
}
```

4. **Test rendering:**
```powershell
# Should show in menu:
# [1] 🎯 Run
# [2] 📚 Orchestrate
# [3] 🆕 NewMode
```

### Breadcrumb Integration

**When adding navigation levels:**

```powershell
# Push breadcrumb with context
Push-Breadcrumb -Stack $breadcrumbs -Name "Level" -Context @{
    Key = "Value"
    # Include data needed for command building
}

# Verify path displays correctly
$path = Get-BreadcrumbPath -Stack $breadcrumbs
# Should show: AitherZero > Parent > Level
```

### Command Building

**Ensure commands build correctly from navigation:**

```powershell
# Collect contexts from breadcrumb stack
$contexts = $breadcrumbs.Items | ForEach-Object { $_.Context }

# Build command from contexts
$commandParts = @()
foreach ($context in $contexts) {
    if ($context.Mode) { $commandParts += "-Mode $($context.Mode)" }
    if ($context.Target) { $commandParts += "-Target $($context.Target)" }
}

$command = $commandParts -join ' '
# Should produce: -Mode Run -Target 0402
```

---

## Testing Generation

### Auto-Generate Tests for Functions

**Template for function tests:**

```powershell
Describe "FunctionName" {
    Context "Parameter validation" {
        It "Should require mandatory parameters" {
            { FunctionName } | Should -Throw
        }
        
        It "Should validate parameter types" {
            { FunctionName -Parameter 123 } | Should -Throw  # if expects string
        }
        
        It "Should validate parameter values" {
            { FunctionName -Parameter "invalid" } | Should -Throw  # if ValidateSet
        }
    }
    
    Context "Functionality" {
        It "Should return expected output" {
            $result = FunctionName -Parameter "valid"
            $result | Should -Not -BeNullOrEmpty
            $result.Property | Should -Be "expected"
        }
        
        It "Should handle errors gracefully" {
            { FunctionName -Parameter "causes-error" } | Should -Throw
        }
    }
    
    Context "Integration" {
        It "Should integrate with dependent components" {
            # Integration test
        }
    }
}
```

### Auto-Generate Tests for Scripts

**Template for script tests:**

```powershell
Describe "NNNN_Script-Name" {
    Context "Script validation" {
        It "Script file should exist" {
            $scriptPath = "./library/automation-scripts/NNNN_Script-Name.ps1"
            $scriptPath | Should -Exist
        }
        
        It "Script should have valid syntax" {
            $scriptPath = "./library/automation-scripts/NNNN_Script-Name.ps1"
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize(
                (Get-Content $scriptPath -Raw), [ref]$errors
            )
            $errors.Count | Should -Be 0
        }
        
        It "Script should have metadata comments" {
            $scriptPath = "./library/automation-scripts/NNNN_Script-Name.ps1"
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\.SYNOPSIS'
            $content | Should -Match 'Stage:'
        }
    }
    
    Context "Execution" {
        It "Script should execute with -WhatIf" {
            { ./library/automation-scripts/NNNN_Script-Name.ps1 -WhatIf } | Should -Not -Throw
        }
        
        It "Script should handle errors" {
            # Error handling test
        }
    }
}
```

---

## Documentation Generation

### Auto-Generate README Files

**Template for component README:**

```markdown
# Component Name

One-line description

## Overview

Detailed description explaining:
- What it does
- Why it exists
- How it fits into AitherZero

## Features

- Feature 1
- Feature 2
- Feature 3

## Installation

\`\`\`powershell
# If standalone component
Import-Module ./ComponentName.psm1

# If extension
Import-Extension -Name "ComponentName"
\`\`\`

## Usage

### Basic Example

\`\`\`powershell
# Simple usage
Get-ComponentData -Source "example"
\`\`\`

### Advanced Example

\`\`\`powershell
# Advanced usage with explanation
Get-ComponentData -Source "example" -Detailed | 
    Where-Object { $_.Status -eq 'Active' } |
    Export-Csv -Path "./output.csv"
\`\`\`

## API Reference

### Function-Name

Description of function

**Parameters:**
- `Parameter1` (String, Required) - Description
- `Parameter2` (Int, Optional, Default: 10) - Description

**Returns:**
- Type: PSCustomObject
- Properties: Property1, Property2

**Example:**
\`\`\`powershell
$result = Function-Name -Parameter1 "value"
\`\`\`

## Configuration

Describe any configuration options or requirements

## Testing

\`\`\`powershell
# Run tests
Invoke-Pester -Path "./tests/ComponentName.Tests.ps1"

# With coverage
Invoke-Pester -Path "./tests/ComponentName.Tests.ps1" -CodeCoverage "./ComponentName.psm1"
\`\`\`

## Troubleshooting

### Issue 1

**Problem:** Description

**Solution:** How to fix

### Issue 2

**Problem:** Description

**Solution:** How to fix

## Contributing

Guidelines for contributions

## License

License information (typically MIT for AitherZero)
```

---

## Common Patterns

### Pattern: Adding New CLI Mode

```powershell
# 1. Add to config.psd1
Manifest = @{
    SupportedModes = @('Interactive', 'Run', 'NewMode')
}

# 2. Create handler function
function Invoke-NewModeHandler {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Target
    )
    
    # Implementation
}

# 3. Register in CommandParser
# (Automatically picked up from config)

# 4. Add tests
Describe "NewMode" {
    It "Should handle mode" {
        { Invoke-NewModeHandler -Target "test" } | Should -Not -Throw
    }
}

# 5. Validate
./library/automation-scripts/0413_Validate-ConfigManifest.ps1
Invoke-Pester -Path "./tests"
```

### Pattern: Adding Script Range

```powershell
# 1. Create scripts in range (e.g., 0600-0699 for new category)
# ./library/automation-scripts/0600_Category-Setup.ps1
# ./library/automation-scripts/0601_Category-Status.ps1

# 2. Update config.psd1
Manifest = @{
    ScriptInventory = @{
        Total = 132  # Update count
        ByRange = @{
            # ... existing ranges
            '0600-0699' = 2  # Add new range
        }
    }
}

# 3. Create tests
# ./tests/unit/library/automation-scripts/0600-0699/0600.Tests.ps1

# 4. Validate
./library/automation-scripts/0413_Validate-ConfigManifest.ps1
```

### Pattern: Feature Flag

```powershell
# 1. Add to config.psd1
Features = @{
    NewFeature = @{
        Enabled = $true
        Config = @{
            Setting1 = "value"
        }
    }
}

# 2. Check in code
$config = Get-Configuration
if ($config.Features.NewFeature.Enabled) {
    # Feature logic
}

# 3. UI shows/hides based on flag
$capabilities = Get-ManifestCapabilities
if ('NewFeature' -in $capabilities.Features) {
    # Show in menu
}
```

---

## AI Agent Checklist

Before finalizing code generation:

- [ ] Follow PowerShell naming conventions
- [ ] Include comment-based help
- [ ] Add error handling
- [ ] Generate corresponding tests
- [ ] Update config.psd1 if needed
- [ ] Validate config (`0413`)
- [ ] Run tests (`Invoke-Pester`)
- [ ] Update documentation
- [ ] Verify UI/CLI integration
- [ ] Check cross-platform compatibility

---

## Error Recovery

### If Config Validation Fails

```powershell
# 1. Run validation to see errors
./library/automation-scripts/0413_Validate-ConfigManifest.ps1

# 2. Common issues:
# - ScriptInventory count mismatch → Count actual scripts
# - Invalid mode names → Check SupportedModes
# - Missing extension → Remove from EnabledExtensions or add extension

# 3. Fix issues in config.psd1

# 4. Re-validate
./library/automation-scripts/0413_Validate-ConfigManifest.ps1
```

### If Tests Fail

```powershell
# 1. Run tests with detailed output
Invoke-Pester -Path "./tests" -Output Detailed

# 2. Fix failing tests

# 3. Re-run until all pass
Invoke-Pester -Path "./tests"
```

### If UI Doesn't Render

```powershell
# 1. Check config.psd1 has correct modes
# 2. Verify Get-ManifestCapabilities returns modes
# 3. Check menu generation code queries config
# 4. Add integration test for UI rendering
```

---

## Summary

AI agents should:
1. ✅ Follow established patterns
2. ✅ Generate complete code (functions + tests + docs)
3. ✅ Validate config changes immediately
4. ✅ Ensure UI/CLI integration
5. ✅ Use approved verbs and naming
6. ✅ Include error handling
7. ✅ Write cross-platform code
8. ✅ Document everything

**Always validate before committing!**

---

**Version:** 1.0.0  
**Last Updated:** 2025-11-05  
**Maintainer:** AitherZero Team
