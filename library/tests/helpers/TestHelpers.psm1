#Requires -Version 7.0

<#
.SYNOPSIS
    Shared test helper functions for AitherZero test suite

.DESCRIPTION
    Provides common utilities for test setup, teardown, mocking, and assertions
#>

function Get-TestEnvironment {
    <#
    .SYNOPSIS
        Detect test execution environment
    
    .OUTPUTS
        Hashtable with environment information
    #>
    [CmdletBinding()]
    param()
    
    $env = @{
        IsCI = ($env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true')
        IsLocal = ($env:CI -ne 'true' -and $env:GITHUB_ACTIONS -ne 'true')
        IsWindows = $IsWindows
        IsLinux = $IsLinux
        IsMacOS = $IsMacOS
        PowerShellVersion = $PSVersionTable.PSVersion
        OS = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
    }
    
    return $env
}

function Initialize-TestEnvironment {
    <#
    .SYNOPSIS
        Set up test environment with required variables and modules
    #>
    [CmdletBinding()]
    param(
        [switch]$SkipModuleImport
    )
    
    # Set required environment variables
    if (-not $env:AITHERZERO_ROOT) {
        $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $env:AITHERZERO_ROOT = $repoRoot
    }
    
    # Set test-specific variables
    $env:AITHERZERO_CI = 'true'
    $env:AITHERZERO_NONINTERACTIVE = 'true'
    $env:AITHERZERO_SUPPRESS_BANNER = 'true'
    
    # Ensure TERM is set
    if (-not $env:TERM) {
        $env:TERM = 'xterm-256color'
    }
    
    # Import AitherZero module if requested
    if (-not $SkipModuleImport) {
        $manifestPath = Join-Path $env:AITHERZERO_ROOT 'AitherZero.psd1'
        if (Test-Path $manifestPath) {
            Import-Module $manifestPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Clear-TestEnvironment {
    <#
    .SYNOPSIS
        Clean up test environment
    #>
    [CmdletBinding()]
    param()
    
    # Remove test-specific environment variables
    Remove-Item Env:AITHERZERO_CI -ErrorAction SilentlyContinue
    Remove-Item Env:AITHERZERO_NONINTERACTIVE -ErrorAction SilentlyContinue
    Remove-Item Env:AITHERZERO_SUPPRESS_BANNER -ErrorAction SilentlyContinue
}

function Get-TestFilePath {
    <#
    .SYNOPSIS
        Get full path to a file relative to repository root
    
    .PARAMETER RelativePath
        Path relative to repository root
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RelativePath
    )
    
    $repoRoot = $env:AITHERZERO_ROOT
    if (-not $repoRoot) {
        $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    }
    
    return Join-Path $repoRoot $RelativePath
}

function Invoke-WithMockEnvironment {
    <#
    .SYNOPSIS
        Execute script block with mocked environment variables
    
    .PARAMETER ScriptBlock
        Script block to execute
    
    .PARAMETER Variables
        Hashtable of environment variables to set
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [hashtable]$Variables = @{}
    )
    
    # Save current environment
    $savedVars = @{}
    foreach ($key in $Variables.Keys) {
        if (Test-Path "Env:$key") {
            $savedVars[$key] = (Get-Item "Env:$key").Value
        }
        Set-Item "Env:$key" -Value $Variables[$key]
    }
    
    try {
        # Execute script block
        & $ScriptBlock
    }
    finally {
        # Restore environment
        foreach ($key in $Variables.Keys) {
            if ($savedVars.ContainsKey($key)) {
                Set-Item "Env:$key" -Value $savedVars[$key]
            }
            else {
                Remove-Item "Env:$key" -ErrorAction SilentlyContinue
            }
        }
    }
}

function Test-ScriptSyntax {
    <#
    .SYNOPSIS
        Validate PowerShell script syntax
    
    .PARAMETER Path
        Path to script file
    
    .OUTPUTS
        $true if syntax is valid, $false otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        Write-Warning "File not found: $Path"
        return $false
    }
    
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        $Path, [ref]$null, [ref]$errors
    )
    
    return ($errors.Count -eq 0)
}

function Get-ModuleExportedFunctions {
    <#
    .SYNOPSIS
        Get list of functions exported by a module
    
    .PARAMETER ModulePath
        Path to .psm1 or .psd1 file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModulePath
    )
    
    if ($ModulePath -match '\.psd1$') {
        # Module manifest
        $manifest = Import-PowerShellDataFile -Path $ModulePath
        return $manifest.FunctionsToExport
    }
    elseif ($ModulePath -match '\.psm1$') {
        # Parse Export-ModuleMember calls
        $content = Get-Content -Path $ModulePath -Raw
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null)
        
        $exportCalls = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -eq 'Export-ModuleMember'
        }, $true)
        
        $functions = @()
        foreach ($export in $exportCalls) {
            # Extract function names
            $functionParam = $export.CommandElements | Where-Object {
                $_ -is [System.Management.Automation.Language.CommandParameterAst] -and
                $_.ParameterName -eq 'Function'
            }
            
            if ($functionParam) {
                $valueIndex = $export.CommandElements.IndexOf($functionParam) + 1
                if ($valueIndex -lt $export.CommandElements.Count) {
                    $value = $export.CommandElements[$valueIndex]
                    $text = $value.Extent.Text -replace "['\""@()]", ''
                    $functions += $text -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                }
            }
        }
        
        return $functions
    }
}

function Assert-FileExists {
    <#
    .SYNOPSIS
        Assert that a file exists
    
    .PARAMETER Path
        Path to file
    
    .PARAMETER Message
        Custom error message
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [string]$Message = "File should exist: $Path"
    )
    
    if (-not (Test-Path $Path)) {
        throw $Message
    }
}

function Assert-ValidPowerShellSyntax {
    <#
    .SYNOPSIS
        Assert that a file has valid PowerShell syntax
    
    .PARAMETER Path
        Path to PowerShell file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        $Path, [ref]$null, [ref]$errors
    )
    
    if ($errors.Count -gt 0) {
        $errorMessages = $errors | ForEach-Object { "Line $($_.Extent.StartLineNumber): $($_.Message)" }
        throw "Syntax errors found:`n$($errorMessages -join "`n")"
    }
}

function New-TestDirectory {
    <#
    .SYNOPSIS
        Create a temporary test directory
    
    .OUTPUTS
        Path to created directory
    #>
    [CmdletBinding()]
    param(
        [string]$Prefix = 'AitherZero-Test'
    )
    
    $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) "$Prefix-$(Get-Random)"
    New-Item -Path $tempPath -ItemType Directory -Force | Out-Null
    
    return $tempPath
}

function Remove-TestDirectory {
    <#
    .SYNOPSIS
        Remove a test directory
    
    .PARAMETER Path
        Path to directory
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    if (Test-Path $Path) {
        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Get-ScriptNumberRange {
    <#
    .SYNOPSIS
        Get the number range category for a script
    
    .PARAMETER ScriptNumber
        Script number (e.g., 0402)
    
    .OUTPUTS
        Range string (e.g., '0400-0499')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$ScriptNumber
    )
    
    $rangeStart = [math]::Floor($ScriptNumber / 100) * 100
    $rangeEnd = $rangeStart + 99
    
    return "$($rangeStart.ToString().PadLeft(4, '0'))-$($rangeEnd.ToString().PadLeft(4, '0'))"
}

function Get-ScriptCategory {
    <#
    .SYNOPSIS
        Get the category for a script number range
    
    .PARAMETER Range
        Range string (e.g., '0400-0499')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Range
    )
    
    $categories = @{
        '0000-0099' = 'Environment Setup'
        '0100-0199' = 'Infrastructure'
        '0200-0299' = 'Development Tools'
        '0300-0399' = 'Deployment'
        '0400-0499' = 'Testing & Quality'
        '0500-0599' = 'Reporting & Analytics'
        '0700-0799' = 'Git & AI Automation'
        '0800-0899' = 'Issue Management'
        '0900-0999' = 'Validation'
        '9000-9999' = 'Maintenance'
    }
    
    return $categories[$Range]
}

function Test-IsAdministrator {
    <#
    .SYNOPSIS
        Check if running as administrator
    #>
    [CmdletBinding()]
    param()
    
    if ($IsWindows) {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]$identity
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    else {
        return (id -u) -eq 0
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Get-TestEnvironment',
    'Initialize-TestEnvironment',
    'Clear-TestEnvironment',
    'Get-TestFilePath',
    'Invoke-WithMockEnvironment',
    'Test-ScriptSyntax',
    'Get-ModuleExportedFunctions',
    'Assert-FileExists',
    'Assert-ValidPowerShellSyntax',
    'New-TestDirectory',
    'Remove-TestDirectory',
    'Get-ScriptNumberRange',
    'Get-ScriptCategory',
    'Test-IsAdministrator'
)
