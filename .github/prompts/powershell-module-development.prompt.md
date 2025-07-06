# PowerShell Module Development - AitherZero

You are helping with PowerShell module development in the AitherZero Infrastructure Automation project.

## Module Architecture Standards

This project follows a standardized module architecture with 16+ specialized modules. All modules must follow the established patterns.

### Required Module Structure

```
ModuleName/
├── ModuleName.psd1          # Manifest with proper exports
├── ModuleName.psm1          # Main module loader
├── Public/                  # Exported functions
│   └── *.ps1               # One function per file
├── Private/                 # Internal functions
│   └── *.ps1               # Helper functions
└── README.md               # Module documentation
```

### Module Manifest Template (ModuleName.psd1)

```powershell
@{
    RootModule = 'ModuleName.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'generated-guid'
    Author = 'AitherZero Team'
    CompanyName = 'Unknown'
    Copyright = '(c) AitherZero Team. All rights reserved.'
    Description = 'Module description'
    PowerShellVersion = '7.0'
    FunctionsToExport = @('Public-Function1', 'Public-Function2')
    CmdletsToExport = @()
    VariablesToExport = '*'
    AliasesToExport = @()
    RequiredModules = @('Logging')
    PrivateData = @{
        PSData = @{
            Tags = @('AitherZero', 'Infrastructure', 'Automation')
            ProjectUri = 'https://github.com/wizzense/AitherZero'
        }
    }
}
```

### Module Loader Template (ModuleName.psm1)

```powershell
#Requires -Version 7.0

# Set strict mode for better error handling
Set-StrictMode -Version Latest

# Import shared utilities
$sharedPath = Join-Path $PSScriptRoot ".." "shared"
if (Test-Path $sharedPath) {
    . (Join-Path $sharedPath "Find-ProjectRoot.ps1")
}

# Import private functions
$privatePath = Join-Path $PSScriptRoot "Private"
if (Test-Path $privatePath) {
    Get-ChildItem -Path $privatePath -Filter "*.ps1" | ForEach-Object {
        . $_.FullName
    }
}

# Import public functions
$publicPath = Join-Path $PSScriptRoot "Public"
if (Test-Path $publicPath) {
    Get-ChildItem -Path $publicPath -Filter "*.ps1" | ForEach-Object {
        . $_.FullName
    }
}

# Cross-platform environment setup
$env:MODULE_NAME_ROOT = $PSScriptRoot
if (-not $env:PROJECT_ROOT) {
    $env:PROJECT_ROOT = Find-ProjectRoot
}

Write-Verbose "ModuleName module loaded from: $PSScriptRoot"
```

## Function Development Standards

### Standard Function Template

```powershell
function Verb-Noun {
    <#
    .SYNOPSIS
        Brief description of what the function does

    .DESCRIPTION
        Detailed description of the function's purpose and behavior

    .PARAMETER ParameterName
        Description of the parameter

    .EXAMPLE
        Verb-Noun -ParameterName "value"
        Example of how to use the function

    .NOTES
        Additional notes about the function
    #>

    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.Object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RequiredParameter,

        [Parameter()]
        [ValidateSet('Option1', 'Option2', 'Option3')]
        [string]$OptionalParameter = 'Option1',

        [Parameter()]
        [switch]$SwitchParameter
    )

    begin {
        Write-CustomLog -Level 'DEBUG' -Message "Starting $($MyInvocation.MyCommand.Name)"

        # Validate prerequisites
        if (-not $env:PWSH_MODULES_PATH) {
            throw "PWSH_MODULES_PATH environment variable not set"
        }
    }

    process {
        try {
            if ($PSCmdlet.ShouldProcess($RequiredParameter, "Verb-Noun")) {
                Write-CustomLog -Level 'INFO' -Message "Processing: $RequiredParameter"

                # Main function logic here
                $result = @{
                    Success = $true
                    Data = $RequiredParameter
                    Timestamp = Get-Date
                }

                Write-CustomLog -Level 'SUCCESS' -Message "Completed processing: $RequiredParameter"
                return $result
            }
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error in $($MyInvocation.MyCommand.Name): $($_.Exception.Message)"
            Write-CustomLog -Level 'DEBUG' -Message "Stack trace: $($_.ScriptStackTrace)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'DEBUG' -Message "Completed $($MyInvocation.MyCommand.Name)"
    }
}
```

## Integration Patterns

### Module Dependencies

Always import required modules using environment variables:

```powershell
# In module functions, import dependencies
if (-not (Get-Module -Name Logging)) {
    Import-Module "$env:PWSH_MODULES_PATH/Logging" -Force
}

# Use shared utilities
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot
```

### Cross-Module Integration

```powershell
# Example: Integrating with LabRunner from another module
function Invoke-ModuleWithLabRunner {
    [CmdletBinding()]
    param([string]$LabScript)

    # Import LabRunner
    Import-Module "$env:PWSH_MODULES_PATH/LabRunner" -Force

    # Use LabRunner functionality
    $result = Invoke-LabScript -ScriptName $LabScript
    return $result
}
```

## Testing Integration

### Module Test Structure

```powershell
BeforeAll {
    # Import shared utilities
    . "$PSScriptRoot/../../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot

    # Import module under test
    Import-Module "$projectRoot/aither-core/modules/ModuleName" -Force

    # Mock dependencies
    Mock Write-CustomLog { }
    Mock Invoke-ExternalCommand { return @{ Success = $true } }
}

Describe "ModuleName Module" -Tags @('Unit', 'ModuleName', 'Fast') {
    Context "When module is imported" {
        It "Should import without errors" {
            { Import-Module "$env:PWSH_MODULES_PATH/ModuleName" -Force } | Should -Not -Throw
        }

        It "Should export expected functions" {
            $module = Get-Module ModuleName
            $module.ExportedFunctions.Keys | Should -Contain 'Public-Function1'
        }
    }

    Context "Core functionality" {
        It "Should execute main function successfully" {
            $result = Invoke-MainFunction -Parameter "test"
            $result.Success | Should -Be $true
        }
    }
}
```

## Development Workflow

### Creating a New Module

1. **Create module structure**:
   ```powershell
   New-Item -Path "aither-core/modules/NewModule" -ItemType Directory
   New-Item -Path "aither-core/modules/NewModule/Public" -ItemType Directory
   New-Item -Path "aither-core/modules/NewModule/Private" -ItemType Directory
   ```

2. **Create manifest and loader** using templates above

3. **Implement functions** following the standard template

4. **Add comprehensive tests**:
   ```powershell
   New-Item -Path "tests/unit/modules/NewModule" -ItemType Directory
   # Create test files following the test structure
   ```

5. **Use PatchManager for Git workflow**:
   ```powershell
   Invoke-PatchWorkflow -PatchDescription "Add NewModule for [purpose]" -PatchOperation {
       # Module creation steps
   } -CreatePR -TestCommands @("Import-Module '$env:PWSH_MODULES_PATH/NewModule' -Force")
   ```

### Modifying Existing Modules

1. **Always use PatchManager**:
   ```powershell
   Invoke-PatchWorkflow -PatchDescription "Enhance ModuleName with [feature]" -PatchOperation {
       # Your changes
   } -CreatePR -TestCommands @(
       "pwsh -File tests/Run-Tests.ps1",
       "Invoke-Pester -Path tests/unit/modules/ModuleName -Output Detailed"
   )
   ```

2. **Update manifest** if adding/removing exported functions

3. **Add/update tests** for new functionality

4. **Validate integration** with dependent modules

## Best Practices

### Code Quality

- Always use `[CmdletBinding(SupportsShouldProcess)]`
- Include comprehensive parameter validation
- Use `Write-CustomLog` for all logging
- Follow PowerShell naming conventions (Verb-Noun)
- Include detailed help documentation

### Error Handling

- Use try-catch blocks in all functions
- Log errors with appropriate levels
- Include stack traces in debug logs
- Throw meaningful error messages

### Performance

- Use `[OutputType()]` for better IntelliSense
- Minimize module import overhead
- Use efficient PowerShell patterns
- Test with large datasets when applicable

### Security

- Validate all inputs
- Use secure credential handling
- Log security-relevant operations
- Follow principle of least privilege

### Cross-Platform Compatibility

- Always use `Join-Path` for file paths
- Test on multiple platforms when possible
- Use PowerShell 7.0+ features consistently
- Avoid platform-specific dependencies

Remember: All modules should integrate seamlessly with the existing ecosystem and follow the established patterns for consistency and maintainability.
