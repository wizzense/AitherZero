---
applyTo: "aithercore/**/*.psm1"
---

# PowerShell Module Requirements

When creating or modifying PowerShell modules in AitherZero, follow these guidelines:

## Module Structure

1. **Require PowerShell 7.0+** - Use `#Requires -Version 7.0` at the top
2. **Use comment-based help** - Include `.SYNOPSIS`, `.DESCRIPTION`, `.NOTES` sections
3. **Set script variables** - Define module-level variables with `$script:` scope
4. **Export functions explicitly** - Use `Export-ModuleMember -Function` at module end

## Critical Development Patterns

### Singular Noun Cmdlets (HARD REQUIREMENT)

**ALWAYS use singular nouns for cmdlets** to enable pipeline processing:

```powershell
# ✅ CORRECT - Singular noun (pipeline-friendly)
function Get-Item {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$InputObject,
        
        [Parameter()]
        [string]$Name
    )
    
    begin {
        # One-time initialization
    }
    
    process {
        # Process ONE item at a time
        Write-Output $InputObject
    }
    
    end {
        # Cleanup
    }
}

# ❌ WRONG - Plural noun (batch operation)
function Get-Items { }  # Avoid this pattern
```

**Benefits:**
- Memory efficient streaming
- Parallel processing support with `ForEach-Object -Parallel`
- Natural pipeline composition
- PowerShell conventions

### Configuration Loading Pattern

**CRITICAL:** Use `Import-ConfigDataFile` for config.psd1 files, NOT `Import-PowerShellDataFile`:

```powershell
# ✅ CORRECT - Use scriptblock evaluation for config.psd1
$configPath = "./config.psd1"
if (Test-Path $configPath) {
    $configContent = Get-Content -Path $configPath -Raw
    $scriptBlock = [scriptblock]::Create($configContent)
    $config = & $scriptBlock
}

# ❌ WRONG - Import-PowerShellDataFile fails with config.psd1
$config = Import-PowerShellDataFile "./config.psd1"  # Will fail!
```

**Reason:** Config files contain PowerShell expressions (`$true`, `$false`) that Import-PowerShellDataFile treats as "dynamic expressions" and cannot load.

### Module Scope Issues

Functions in scriptblocks may lose module scope. Call functions directly:

```powershell
# ✅ CORRECT - Call functions directly
Write-CustomLog "Processing..."
Show-UISpinner { Start-Process $command }

# ❌ WRONG - May fail in scriptblocks
Show-UISpinner { Write-CustomLog "Processing..." }
```

### Cross-Platform Compatibility

Always check platform variables for OS-specific features:

```powershell
$path = if ($IsWindows) { 
    'C:/temp' 
} else { 
    "$HOME/.aitherzero/temp" 
}

# Check for Windows-only features
if ($IsWindows) {
    # Hyper-V, WSL2, etc.
}
```

### Logging Pattern

Check for command availability before using:

```powershell
if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
    Write-CustomLog -Message "Processing..." -Level 'Information'
} else {
    Write-Verbose "Processing..."
}
```

## Function Requirements

### Parameter Design

1. **Use proper parameter attributes**:
   - `[Parameter(Mandatory)]` for required parameters
   - `[Parameter(ValueFromPipeline)]` for pipeline input
   - `[ValidateNotNullOrEmpty()]` for validation
   - `[AllowEmptyString()]` when empty strings are valid

2. **Support ShouldProcess** for state-changing operations:
   ```powershell
   [CmdletBinding(SupportsShouldProcess)]
   param()
   
   if ($PSCmdlet.ShouldProcess($target, $action)) {
       # Perform operation
   }
   ```

3. **Use parameter sets** for mutually exclusive options:
   ```powershell
   [Parameter(ParameterSetName = 'ByName')]
   [string]$Name
   
   [Parameter(ParameterSetName = 'ByPath')]
   [string]$Path
   ```

### Error Handling

1. **Use try/catch blocks** for error-prone operations
2. **Set ErrorActionPreference** appropriately
3. **Use Write-Error** for non-terminating errors
4. **Use throw** for terminating errors
5. **Log errors** with Write-CustomLog if available

### Comment-Based Help

Every exported function must have:

```powershell
<#
.SYNOPSIS
    Brief description of function
.DESCRIPTION
    Detailed description with usage context
.PARAMETER ParameterName
    Description of parameter
.EXAMPLE
    Example-Command -Parameter Value
    Description of example
.NOTES
    Additional information
    Copyright © 2025 Aitherium Corporation
.OUTPUTS
    Type of output object
#>
```

## Module Dependencies

### Load Order

Modules have load order dependencies (see `AitherZero.psm1`):

1. **Logging** - Must load FIRST (all modules depend on Write-CustomLog)
2. **Configuration** - Second (used by all modules)
3. **BetterMenu** - Before UserInterface
4. **Other modules** - Domain-specific order

### Import Pattern

```powershell
# Import required modules
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module (Join-Path $projectRoot "aithercore/utilities/Logging.psm1") -Force
```

## Export Pattern

At the end of every module:

```powershell
# Export all public functions
Export-ModuleMember -Function @(
    'Get-MyFunction'
    'Set-MyFunction'
    'Remove-MyFunction'
)
```

**CRITICAL:** Functions MUST be in `Export-ModuleMember` to be accessible outside the module.

## Naming Conventions

1. **Use approved PowerShell verbs** - Run `Get-Verb` to see approved verbs
2. **Use singular nouns** - `Get-Item`, not `Get-Items`
3. **Use PascalCase** - `Get-ConfigurationValue`
4. **Prefix with domain** when needed - `Get-InfrastructureSubmodule`

## Performance Considerations

1. **Avoid creating unnecessary objects** - Use `[void]` to suppress output
2. **Use pipeline** - Process items one at a time, not in arrays
3. **Cache expensive operations** - Store results in script variables
4. **Use -ErrorAction SilentlyContinue** sparingly - impacts performance

## Testing Requirements

Every module must have:
1. Unit tests in `/tests/aithercore/<domain>/`
2. Tests for all exported functions
3. Tests for error handling
4. Tests for parameter validation

## Example Module Template

```powershell
#Requires -Version 7.0

<#
.SYNOPSIS
    Module description
.DESCRIPTION
    Detailed module description
.NOTES
    Copyright © 2025 Aitherium Corporation
#>

# Module variables
$script:ModuleCache = @{}

<#
.SYNOPSIS
    Get an item
.DESCRIPTION
    Retrieves an item by name
.PARAMETER Name
    Item name
.EXAMPLE
    Get-MyItem -Name "Example"
#>
function Get-MyItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Name
    )
    
    begin {
        # Initialization
    }
    
    process {
        try {
            # Process one item
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog "Processing: $Name" -Level 'Information'
            }
            
            # Return result
            Write-Output $result
        }
        catch {
            Write-Error "Failed to process $Name: $_"
        }
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Get-MyItem'
)
```

## Reference

- See `docs/SINGULAR-NOUN-DESIGN.md` for cmdlet design patterns
- See `docs/STYLE-GUIDE.md` for comprehensive style guide
- See `.github/copilot-instructions.md` for architecture details
