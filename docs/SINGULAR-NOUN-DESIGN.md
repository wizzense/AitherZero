# PowerShell Cmdlet Design Guidelines

## Singular Noun Principle

### Philosophy

All AitherZero cmdlets should follow the **singular noun design pattern**:

- Cmdlets process **one object at a time**
- Cmdlets support **pipeline input** using `Begin/Process/End` blocks
- Cmdlets enable **parallel processing** with `ForEach-Object -Parallel`
- Cmdlets compose naturally in **pipeline chains**

### Why Singular Nouns?

**❌ Plural nouns (anti-pattern):**
```powershell
Update-InfrastructureSubmodules  # Implies batch operation
Get-ConfigurationSettings        # Implies returns collection
Remove-TestResults              # Implies deletes all
```

**✅ Singular nouns (correct pattern):**
```powershell
Update-InfrastructureSubmodule   # Processes one submodule
Get-ConfigurationSetting         # Returns individual settings
Remove-TestResult               # Removes one result
```

### Benefits

1. **Pipeline Efficiency**: Process large datasets without loading everything in memory
2. **Parallel Processing**: Each item can be processed concurrently
3. **Composability**: Chain operations naturally with `|` operator
4. **PowerShell Conventions**: Follows official PowerShell best practices
5. **Scriptability**: Easier to write reusable, maintainable scripts

## Implementation Pattern

### Template Structure

```powershell
function Verb-SingularNoun {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ByName')]
    param(
        # Pipeline input - accepts single object
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByObject')]
        [PSCustomObject]$InputObject,

        # Alternative: By name
        [Parameter(ParameterSetName = 'ByName')]
        [string]$Name,

        # Alternative: By path/ID
        [Parameter(ParameterSetName = 'ByPath')]
        [string]$Path,

        # Additional parameters
        [Parameter()]
        [switch]$Force
    )

    begin {
        # One-time initialization
        # Load configuration, validate prerequisites
        Write-Verbose "Starting operation"
        
        # Load shared resources once
        $config = Get-Configuration
    }

    process {
        # Process ONE object at a time
        # This block runs for each pipeline input
        
        try {
            # Determine what to process
            if ($PSCmdlet.ParameterSetName -eq 'ByObject') {
                $target = $InputObject
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'ByName') {
                $target = Get-Something -Name $Name
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'ByPath') {
                $target = Get-Something -Path $Path
            }

            if ($PSCmdlet.ShouldProcess($target.Name, "Perform operation")) {
                # Process single object
                # ... operation logic ...
                
                # Return object for further pipeline processing
                Write-Output $target
            }
        }
        catch {
            Write-Error "Failed to process $($target.Name): $_"
            throw
        }
    }

    end {
        # Cleanup, summary
        Write-Verbose "Operation complete"
    }
}
```

### Usage Examples

```powershell
# Single object
Update-InfrastructureSubmodule -Name 'myapp'

# Pipeline - process multiple objects one at a time
Get-InfrastructureSubmodule | Update-InfrastructureSubmodule

# Pipeline with filtering
Get-InfrastructureSubmodule | 
    Where-Object { $_.Enabled } | 
    Update-InfrastructureSubmodule -Remote

# Parallel processing
Get-InfrastructureSubmodule -Initialized | 
    ForEach-Object -Parallel {
        Update-InfrastructureSubmodule -InputObject $_
    } -ThrottleLimit 4

# Store and reuse
$submodules = Get-InfrastructureSubmodule
$submodules | Update-InfrastructureSubmodule
$submodules | Remove-InfrastructureSubmodule -WhatIf
```

## Parameter Design

### Pipeline Input

**Always support pipeline input:**

```powershell
[Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByObject')]
[PSCustomObject]$InputObject
```

### Parameter Sets

Use parameter sets to allow different ways to target objects:

```powershell
DefaultParameterSetName = 'ByName'  # Most common case

ParameterSetName = 'ByObject'       # Pipeline input
ParameterSetName = 'ByName'         # By string name
ParameterSetName = 'ByPath'         # By file path
ParameterSetName = 'ById'           # By numeric ID
```

### ValueFromPipelineByPropertyName

Allow property binding for convenience:

```powershell
[Parameter(ValueFromPipelineByPropertyName)]
[string]$Name

[Parameter(ValueFromPipelineByPropertyName)]
[string]$Path
```

## Output Design

### Stream Objects

Always output objects one at a time:

```powershell
# ✅ Correct - streams objects
foreach ($item in $collection) {
    Write-Output $item
}

# ❌ Wrong - returns entire collection
return $collection
```

### Typed Output

Use `PSTypeName` for structured objects:

```powershell
[PSCustomObject]@{
    PSTypeName = 'AitherZero.InfrastructureSubmodule'
    Name       = $name
    Path       = $path
    Status     = $status
}
```

### Return for Pipeline

Return processed objects for chaining:

```powershell
if ($PSCmdlet.ShouldProcess($target.Name, "Update")) {
    # ... perform update ...
    
    # Return object for further processing
    Write-Output $target
}
```

## When to Use Batch Operations

Some operations are inherently batch-oriented:

### Sync Operations

```powershell
function Sync-InfrastructureSubmodule {
    # Compares configuration with reality
    # This is a coordination operation, not per-item processing
}
```

### Initialize Operations

```powershell
function Initialize-Something {
    # Sets up multiple related items
    # But internally uses singular cmdlets:
    Get-Thing | Initialize-Thing
}
```

### Test Operations

```powershell
function Test-Configuration {
    # Validates entire configuration
    # Returns single pass/fail result
}
```

## Migration Guide

### Refactoring Plural to Singular

**Before (plural):**
```powershell
function Update-Items {
    param([string]$Name)
    
    $items = Get-AllItems
    foreach ($item in $items) {
        # Update logic
    }
}
```

**After (singular):**
```powershell
function Update-Item {
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByObject')]
        [PSCustomObject]$InputObject,

        [Parameter(ParameterSetName = 'ByName')]
        [string]$Name
    )

    begin {
        # One-time setup
    }

    process {
        # Process ONE item
        $item = if ($InputObject) { $InputObject } else { Get-Item -Name $Name }
        # Update logic for single item
    }

    end {
        # Cleanup
    }
}

# Usage changes from:
Update-Items
# To:
Get-Item | Update-Item
```

## Testing Singular Cmdlets

```powershell
Describe "Update-Item" {
    Context "Pipeline Support" {
        It "Should accept pipeline input" {
            $items = @(
                [PSCustomObject]@{ Name = 'item1' }
                [PSCustomObject]@{ Name = 'item2' }
            )
            
            { $items | Update-Item } | Should -Not -Throw
        }

        It "Should process each item" {
            $processed = @()
            Get-Item | ForEach-Object {
                $processed += $_
                $_
            } | Update-Item
            
            $processed.Count | Should -BeGreaterThan 0
        }
    }

    Context "Parameter Sets" {
        It "Should work with -Name" {
            { Update-Item -Name 'test' } | Should -Not -Throw
        }

        It "Should work with pipeline object" {
            $item = [PSCustomObject]@{ Name = 'test' }
            { $item | Update-Item } | Should -Not -Throw
        }
    }
}
```

## Quick Reference

| Anti-Pattern (Plural) | Correct Pattern (Singular) |
|-----------------------|----------------------------|
| `Get-Items` | `Get-Item` - streams one at a time |
| `Update-Submodules` | `Update-Submodule` - processes one |
| `Remove-Files` | `Remove-File` - removes one |
| `Test-Configurations` | `Test-Configuration` - validates one |
| `Export-Results` | `Export-Result` - exports one |

## See Also

- PowerShell Cmdlet Development Guidelines
- Pipeline Design Patterns
- Parallel Processing with ForEach-Object
- ShouldProcess Implementation Guide

## Examples in AitherZero

- `Get-InfrastructureSubmodule` - Returns submodules one at a time
- `Update-InfrastructureSubmodule` - Updates one submodule per call
- `Remove-InfrastructureSubmodule` - Removes one submodule per call

All infrastructure submodule cmdlets demonstrate this pattern perfectly.
