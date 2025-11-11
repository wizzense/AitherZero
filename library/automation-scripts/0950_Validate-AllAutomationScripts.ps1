#Requires -Version 7.0

<#
.SYNOPSIS
    Validates all automation scripts (0000-9999) with the new module architecture
.DESCRIPTION
    Comprehensive validation of all automation scripts to ensure they work
    with the consolidated module architecture. Tests syntax, module dependencies,
    and basic execution.
    
    Exit Codes:
    0   - Success
    1   - Validation failures found
    2   - Critical error
    
.NOTES
    Stage: Validation
    Order: 0950
    Dependencies: None
    Tags: validation, automation, testing, architecture
    AllowParallel: false
#>

[CmdletBinding()]
param(
    [switch]$Fast,
    [switch]$DetailedReport,
    [switch]$CI
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Ensure TERM is set for terminal operations
if (-not $env:TERM) {
    $env:TERM = 'xterm-256color'
}

# Initialize
$script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:StartTime = Get-Date
$script:ValidationResults = @()

# Logging helper
function Write-ValidationLog {
    param(
        [string]$Message,
        [ValidateSet('Information', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Information'
    )
    
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $color = switch ($Level) {
        'Information' { 'Cyan' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Success' { 'Green' }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

# Get all automation scripts
function Get-AutomationScripts {
    $scriptPaths = @(
        Join-Path $script:ProjectRoot 'library/automation-scripts'
        Join-Path $script:ProjectRoot 'automation-scripts'
    )
    
    $scripts = foreach ($path in $scriptPaths) {
        if (Test-Path $path) {
            Get-ChildItem -Path $path -Filter '*.ps1' -File | 
                Where-Object { $_.Name -match '^\d{4}_' }
        }
    }
    
    return $scripts | Sort-Object Name -Unique
}

# Parse script metadata
function Get-ScriptMetadata {
    param([string]$ScriptPath)
    
    $content = Get-Content $ScriptPath -Raw
    $metadata = @{
        Stage = 'Unknown'
        Dependencies = @()
        RequiresModules = @()
    }
    
    # Extract stage
    if ($content -match 'Stage:\s*(.+)') {
        $metadata.Stage = $matches[1].Trim()
    }
    
    # Extract dependencies
    if ($content -match 'Dependencies:\s*(.+)') {
        $deps = $matches[1].Trim() -split ',' | ForEach-Object { $_.Trim() }
        $metadata.Dependencies = $deps | Where-Object { $_ }
    }
    
    # Extract module imports (matches string literals and variables, but not complex expressions)
    # Limitation: This will not detect modules imported via complex expressions (e.g., concatenation, function calls).
    $moduleMatches = [regex]::Matches($content, "Import-Module\s+(['\`"]?([^'\`"\s]+)['\`"]?|\$[A-Za-z_][A-Za-z0-9_]*)")
    $metadata.RequiresModules = $moduleMatches | ForEach-Object {
        # If match is a variable (starts with $), include as-is; otherwise, extract the module name
        if ($_.Groups[2].Success) { $_.Groups[2].Value } else { $_.Groups[1].Value }
    }
    
    return $metadata
}

# Validate script syntax
function Test-ScriptSyntax {
    param([string]$ScriptPath)
    
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        $ScriptPath, [ref]$null, [ref]$errors
    )
    
    return @{
        Valid = ($null -eq $errors -or $errors.Count -eq 0)
        Errors = $errors
    }
}

# Check for obsolete module references
function Test-ObsoleteModuleReferences {
    param([string]$ScriptPath)
    
    $content = Get-Content $ScriptPath -Raw
    $found = [System.Collections.ArrayList]::new()
    
    # Pattern: $variableName = Join-Path ... "path/to/Module.psm1"
    # We want to find module paths that don't exist
    # Avoid matching escaped variables like `$ModuleName (backtick escapes)
    $modulePathPattern = '(?<!`)\$(\w+(?:Module|Path))\s*=\s*Join-Path\s+[^\r\n]+?["'']([^"'']+\.psm1)["'']'
    $pathVarMatches = [regex]::Matches($content, $modulePathPattern)
    
    foreach ($match in $pathVarMatches) {
        $varName = $match.Groups[1].Value
        $relativePath = $match.Groups[2].Value
        
        # Skip if this looks like it's in a template/string (contains unescaped $)
        if ($relativePath -match '\$') {
            continue
        }
        
        # Build potential paths to check
        $potentialPaths = @(
            $relativePath,
            (Join-Path $script:ProjectRoot $relativePath)
        )
        
        # Check if module exists
        $moduleExists = $false
        foreach ($path in $potentialPaths) {
            if (Test-Path $path) {
                $moduleExists = $true
                break
            }
        }
        
        # If module path doesn't exist, extract module name and add to findings
        if (-not $moduleExists) {
            if ($relativePath -match '([^/\\]+)\.psm1$') {
                $moduleName = $matches[1]
                if ($moduleName -notin $found) {
                    $null = $found.Add($moduleName)
                }
            }
        }
    }
    
    return $found.ToArray()
}

# Main validation logic
try {
    Write-ValidationLog "Starting automation script validation" -Level 'Information'
    Write-ValidationLog "Project Root: $script:ProjectRoot" -Level 'Information'
    
    # Get all scripts
    $scripts = Get-AutomationScripts
    Write-ValidationLog "Found $($scripts.Count) automation scripts to validate" -Level 'Success'
    
    # Validate each script
    $totalScripts = $scripts.Count
    $currentScript = 0
    $passedCount = 0
    $failedCount = 0
    
    foreach ($script in $scripts) {
        $currentScript++
        $scriptName = $script.Name
        
        if (-not $Fast) {
            Write-Progress -Activity "Validating Scripts" -Status "Processing $scriptName" `
                -PercentComplete (($currentScript / $totalScripts) * 100)
        }
        
        $result = @{
            Script = $scriptName
            Path = $script.FullName
            SyntaxValid = $true
            ObsoleteModules = @()
            Metadata = $null
            Status = 'Pass'
            Issues = @()
        }
        
        # Test syntax
        $syntaxResult = Test-ScriptSyntax -ScriptPath $script.FullName
        $result.SyntaxValid = $syntaxResult.Valid
        
        if (-not $syntaxResult.Valid) {
            $result.Status = 'Fail'
            $result.Issues += "Syntax errors: $($syntaxResult.Errors.Count)"
            Write-ValidationLog "  ✗ $scriptName - Syntax errors" -Level 'Error'
        }
        
        # Check for obsolete module references
        $obsoleteRefs = @(Test-ObsoleteModuleReferences -ScriptPath $script.FullName)
        if ($obsoleteRefs.Length -gt 0) {
            $result.ObsoleteModules = $obsoleteRefs
            $result.Status = 'Warn'
            $result.Issues += "References obsolete modules: $($obsoleteRefs -join ', ')"
            Write-ValidationLog "  ⚠ $scriptName - Obsolete module refs: $($obsoleteRefs -join ', ')" -Level 'Warning'
        }
        
        # Get metadata
        if ($syntaxResult.Valid) {
            $result.Metadata = Get-ScriptMetadata -ScriptPath $script.FullName
        }
        
        # Track results
        if ($result.Status -eq 'Pass') {
            $passedCount++
            if (-not $Fast) {
                Write-ValidationLog "  ✓ $scriptName" -Level 'Success'
            }
        } elseif ($result.Status -eq 'Fail') {
            $failedCount++
        }
        
        $script:ValidationResults += [PSCustomObject]$result
    }
    
    # Summary
    Write-ValidationLog "`n=== VALIDATION SUMMARY ===" -Level 'Information'
    Write-ValidationLog "Total Scripts: $totalScripts" -Level 'Information'
    Write-ValidationLog "Passed: $passedCount" -Level 'Success'
    Write-ValidationLog "Failed: $failedCount" -Level $(if ($failedCount -eq 0) { 'Success' } else { 'Error' })
    
    $warnItems = @($script:ValidationResults | Where-Object { $_.Status -eq 'Warn' })
    $warnCount = $warnItems.Count
    if ($warnCount -gt 0) {
        Write-ValidationLog "Warnings: $warnCount" -Level 'Warning'
    }
    
    # Detailed report
    if ($DetailedReport -or $failedCount -gt 0 -or $warnCount -gt 0) {
        Write-ValidationLog "`n=== ISSUES FOUND ===" -Level 'Information'
        
        $issueScripts = @($script:ValidationResults | Where-Object { $_.Issues -and $_.Issues.Count -gt 0 })
        foreach ($item in $issueScripts) {
            Write-ValidationLog "`n$($item.Script):" -Level 'Warning'
            foreach ($issue in $item.Issues) {
                Write-ValidationLog "  - $issue" -Level 'Warning'
            }
        }
    }
    
    # Export results
    $reportPath = Join-Path $script:ProjectRoot 'reports/validation-results.json'
    $reportDir = Split-Path $reportPath -Parent
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    
    $script:ValidationResults | ConvertTo-Json -Depth 10 | Out-File $reportPath -Encoding utf8
    Write-ValidationLog "`nResults saved to: $reportPath" -Level 'Success'
    
    # Performance metrics
    $duration = (Get-Date) - $script:StartTime
    Write-ValidationLog "Validation completed in $([Math]::Round($duration.TotalSeconds, 2)) seconds" -Level 'Success'
    
    # Exit code
    if ($failedCount -gt 0) {
        exit 1
    } else {
        exit 0
    }
    
} catch {
    Write-ValidationLog "Critical error during validation: $_" -Level 'Error'
    Write-ValidationLog $_.ScriptStackTrace -Level 'Error'
    exit 2
}
