# AitherZero Style Guide

This guide defines coding standards, naming conventions, and best practices for the AitherZero project.

## Table of Contents

- [PowerShell Cmdlet Naming](#powershell-cmdlet-naming)
- [Code Organization](#code-organization)
- [Error Handling](#error-handling)
- [Documentation](#documentation)
- [Testing](#testing)

## PowerShell Cmdlet Naming

### Singular Noun Principle

**ALWAYS use singular nouns for PowerShell cmdlets:**

All AitherZero cmdlets follow the singular noun design pattern to enable pipeline processing, parallel execution, and composability.

#### ❌ Wrong - Plural Nouns

```powershell
Get-Items
Update-Files
Remove-Logs
Get-Submodules
Export-Results
```

#### ✅ Correct - Singular Nouns

```powershell
Get-Item        # Processes one, supports pipeline
Update-File     # Updates one, supports pipeline
Remove-Log      # Removes one, supports pipeline
Get-Submodule   # Returns submodules one at a time
Export-Result   # Exports one result
```

### Key Principles

1. **Cmdlets process ONE object at a time**
   - Use `Begin/Process/End` blocks
   - Process objects in the `process` block

2. **Support pipeline input**
   - Add `ValueFromPipeline` parameter attribute
   - Accept `InputObject` parameter

3. **Enable parallel processing**
   - Works with `ForEach-Object -Parallel`
   - Stream objects for efficiency

4. **Return processed objects**
   - Use `Write-Output` to return objects
   - Enable pipeline chaining

5. **Use parameter sets**
   - Support multiple ways to target objects (ByName, ByPath, ByObject)
   - Use `DefaultParameterSetName` attribute

### Implementation Template

```powershell
function Verb-SingularNoun {
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParameterSetName = 'ByName'
    )]
    [OutputType('AitherZero.TypeName')]
    param(
        # Pipeline input - accepts single object
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ParameterSetName = 'ByObject'
        )]
        [PSCustomObject]$InputObject,

        # Alternative: By name
        [Parameter(
            Mandatory,
            ParameterSetName = 'ByName',
            ValueFromPipelineByPropertyName
        )]
        [string]$Name,

        # Alternative: By path
        [Parameter(
            Mandatory,
            ParameterSetName = 'ByPath',
            ValueFromPipelineByPropertyName
        )]
        [string]$Path,

        # Optional parameters
        [Parameter()]
        [switch]$Force
    )

    begin {
        # One-time initialization
        Write-Verbose "Starting $($MyInvocation.MyCommand.Name)"
        $config = Get-Configuration -ErrorAction SilentlyContinue
    }

    process {
        # Process ONE object at a time
        try {
            # Determine target based on parameter set
            $target = switch ($PSCmdlet.ParameterSetName) {
                'ByObject' { $InputObject }
                'ByName'   { Get-TargetByName -Name $Name }
                'ByPath'   { Get-TargetByPath -Path $Path }
            }

            if ($PSCmdlet.ShouldProcess($target.Name, "Perform operation")) {
                # Process single object
                # ... operation logic ...
                
                # Return object for pipeline chaining
                Write-Output $target
            }
        }
        catch {
            Write-Error "Failed to process $($target.Name): $_"
            if (-not $Force) {
                throw
            }
        }
    }

    end {
        Write-Verbose "Completed $($MyInvocation.MyCommand.Name)"
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

# Chain operations
Get-InfrastructureSubmodule |
    Update-InfrastructureSubmodule -Remote |
    Where-Object { $_.Status -eq 'Updated' } |
    Export-Result
```

### When to Keep Plural Nouns

Some operations are inherently batch-oriented and should remain plural:

#### Coordination/Sync Operations
```powershell
Sync-InfrastructureSubmodule  # Compares config with reality
Initialize-Environment         # Sets up multiple components
Test-Configuration            # Validates entire config
```

#### Explicit Collection Returns
```powershell
Get-AllLogFiles              # Explicit "all" operation
Get-AuditLogs                # Audit log is a collection
Get-HistoricalMetrics        # Time-series data
```

#### Batch Operations
```powershell
Analyze-Changes              # Analyzes git changeset as whole
Copy-ExistingReports         # Batch copy operation
Fix-UnicodeIssues            # Batch fix operation
```

### Approved Verbs

Use PowerShell approved verbs only. Check with:

```powershell
Get-Verb
```

Common approved verbs:
- **Get**: Retrieve data
- **Set**: Assign or replace data
- **New**: Create new resource
- **Remove**: Delete resource
- **Update**: Modify existing data
- **Test**: Verify or validate
- **Invoke**: Execute or run
- **Export**: Output to external format
- **Import**: Load from external format

## Code Organization

### Module Structure

```
aithercore/
├── domain-name/
│   ├── DomainName.psm1          # Module file
│   ├── Public/                  # Public functions
│   │   ├── Get-Item.ps1
│   │   └── Update-Item.ps1
│   └── Private/                 # Private functions
│       └── Get-ItemInternal.ps1
```

### Function File Organization

- One function per file in Public/Private directories
- File name matches function name: `Get-Item.ps1`
- Use dot-sourcing to load functions in `.psm1`

### Export Functions

Always explicitly export public functions:

```powershell
# At end of module file
Export-ModuleMember -Function @(
    'Get-Item'
    'Update-Item'
    'Remove-Item'
)
```

## Error Handling

### Use Try-Catch-Finally

```powershell
function Do-Something {
    param($Path)
    
    try {
        # Main logic
        $item = Get-Item -Path $Path
        Process-Item -Item $item
    }
    catch {
        # Log error
        Write-CustomLog -Message "Failed to process: $_" -Level 'Error'
        
        # Re-throw or handle
        throw
    }
    finally {
        # Cleanup
        if ($tempFile) {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}
```

### Logging Pattern

Always check for logging availability:

```powershell
if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
    Write-CustomLog -Message "Processing item" -Level 'Information'
} else {
    Write-Verbose "Processing item"
}
```

### Error Messages

- Be specific about what failed
- Include context (file path, item name, etc.)
- Suggest remediation when possible

```powershell
# Good
Write-Error "Failed to update submodule 'myapp': Repository not found at 'C:\repos\myapp'"

# Bad
Write-Error "Update failed"
```

## Documentation

### Comment-Based Help

All public functions must have comment-based help:

```powershell
function Get-Item {
    <#
    .SYNOPSIS
        Gets an item from the repository.

    .DESCRIPTION
        The Get-Item cmdlet retrieves items from the repository one at a time,
        supporting pipeline input and parallel processing.

    .PARAMETER Name
        Specifies the name of the item to retrieve.

    .PARAMETER Path
        Specifies the path to the item to retrieve.

    .PARAMETER InputObject
        Accepts an item object from the pipeline.

    .EXAMPLE
        Get-Item -Name 'myitem'
        
        Gets the item named 'myitem'.

    .EXAMPLE
        Get-Item | Update-Item
        
        Gets all items and updates them through the pipeline.

    .EXAMPLE
        Get-Item | ForEach-Object -Parallel { $_ } -ThrottleLimit 4
        
        Gets items and processes them in parallel with 4 concurrent threads.

    .INPUTS
        PSCustomObject
        You can pipe item objects to this cmdlet.

    .OUTPUTS
        AitherZero.Item
        Returns item objects.

    .NOTES
        This cmdlet follows the singular noun design pattern.
    #>
    [CmdletBinding()]
    param(...)
    
    # Function body
}
```

### Required Help Sections

- `.SYNOPSIS`: One-line description
- `.DESCRIPTION`: Detailed description
- `.PARAMETER`: For each parameter
- `.EXAMPLE`: At least 2 examples showing different usage
- `.INPUTS`: What can be piped in
- `.OUTPUTS`: What is returned

### README Files

- Each module/domain should have a README.md
- Explain purpose, usage, and examples
- Keep updated with code changes

## Testing

### Test File Naming

- Test files end with `.Tests.ps1`
- Match the file being tested: `Get-Item.Tests.ps1`

### Pester Test Structure

```powershell
Describe "Get-Item" {
    BeforeAll {
        # Setup
        Import-Module ./AitherZero.psd1 -Force
    }

    Context "Pipeline Support" {
        It "Should accept pipeline input" {
            $items = @(
                [PSCustomObject]@{ Name = 'item1' }
                [PSCustomObject]@{ Name = 'item2' }
            )
            
            { $items | Get-Item } | Should -Not -Throw
        }

        It "Should process each item individually" {
            $count = 0
            Get-Item | ForEach-Object { $count++ }
            $count | Should -BeGreaterThan 0
        }

        It "Should work with Where-Object" {
            $filtered = Get-Item | Where-Object { $_.Name -like '*test*' }
            $filtered | Should -Not -BeNullOrEmpty
        }
    }

    Context "Parameter Sets" {
        It "Should work with -Name parameter" {
            { Get-Item -Name 'test' } | Should -Not -Throw
        }

        It "Should work with -Path parameter" {
            { Get-Item -Path '/test/path' } | Should -Not -Throw
        }
    }

    AfterAll {
        # Cleanup
    }
}
```

### Test Coverage

- Test each parameter set
- Test pipeline scenarios
- Test error conditions
- Test edge cases

### Mock External Dependencies

```powershell
BeforeEach {
    Mock Get-ExternalData {
        return [PSCustomObject]@{
            Name = 'test'
            Value = 42
        }
    }
}
```

## Cross-Platform Compatibility

### Check Platform Variables

```powershell
$path = if ($IsWindows) {
    'C:\temp\file.txt'
} elseif ($IsLinux) {
    '/tmp/file.txt'
} elseif ($IsMacOS) {
    '/tmp/file.txt'
} else {
    # Fallback
    Join-Path $env:TEMP 'file.txt'
}
```

### Path Handling

Use `Join-Path` for cross-platform compatibility:

```powershell
# Good
$configPath = Join-Path $PSScriptRoot 'config.psd1'

# Avoid
$configPath = "$PSScriptRoot\config.psd1"  # Windows-only
```

### Line Endings

- Use LF (`\n`) line endings
- Configure git to normalize: `git config core.autocrlf input`
- EditorConfig handles this in VS Code

## Formatting

### Indentation

- Use 4 spaces (no tabs)
- Configured in `.editorconfig`

### Braces

Use K&R style (opening brace on same line):

```powershell
# Good
if ($condition) {
    # code
}

# Avoid
if ($condition)
{
    # code
}
```

### Line Length

- Prefer 100-120 characters
- Break long lines for readability

### Comments

```powershell
# Single-line comment for simple explanations

<#
    Multi-line comment block
    for complex explanations
#>
```

## References

- [PowerShell Best Practices](https://docs.microsoft.com/powershell/scripting/developer/cmdlet/cmdlet-development-guidelines)
- [docs/SINGULAR-NOUN-DESIGN.md](./SINGULAR-NOUN-DESIGN.md) - Detailed singular noun design guide
- [docs/REFACTORING-PLAN-SINGULAR-NOUNS.md](./REFACTORING-PLAN-SINGULAR-NOUNS.md) - Refactoring roadmap
- [PowerShell Approved Verbs](https://docs.microsoft.com/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands)

## See Also

- `.github/copilot-instructions.md` - AI agent coding guidelines
- `PSScriptAnalyzerSettings.psd1` - Linter configuration
- `infrastructure/SUBMODULES.md` - Infrastructure submodule guide
