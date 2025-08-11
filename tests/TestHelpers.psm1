#Requires -Version 7.0
<#
.SYNOPSIS
    Test helper functions for AitherZero test suite
.DESCRIPTION
    Provides common initialization, mocking, and cleanup utilities for tests
#>

# Get project root
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent

function Initialize-TestEnvironment {
    <#
    .SYNOPSIS
        Initialize test environment with proper module loading
    .DESCRIPTION
        Sets up clean test environment and loads AitherZero modules
    #>
    [CmdletBinding()]
    param(
        [switch]$SkipModuleLoad,
        [string[]]$RequiredModules = @()
    )

    # Clean any conflicting modules
    $conflictingModules = @('AitherRun', 'CoreApp', 'ConfigurationManager', 'AitherZeroCore')
    foreach ($module in $conflictingModules) {
        if (Get-Module -Name $module -ErrorAction SilentlyContinue) {
            Remove-Module -Name $module -Force -ErrorAction SilentlyContinue
        }
    }

    # Set environment variables
    $env:AITHERZERO_ROOT = $script:ProjectRoot
    $env:AITHERZERO_TEST_MODE = "1"
    $env:AITHERZERO_DISABLE_TRANSCRIPT = "1"  # Disable transcript during tests

    if (-not $SkipModuleLoad) {
        # Import main module
        Import-Module (Join-Path $script:ProjectRoot "AitherZero.psm1") -Force -Global

        # Import any additional required modules
        foreach ($moduleName in $RequiredModules) {
            $modulePath = Get-ChildItem -Path (Join-Path $script:ProjectRoot "domains") -Filter "$moduleName.psm1" -Recurse | Select-Object -First 1
            if ($modulePath) {
                Import-Module $modulePath.FullName -Force -Global
            }
        }
    }

    # Return environment info
    return @{
        ProjectRoot = $script:ProjectRoot
        ModulesLoaded = (Get-Module | Where-Object { $_.Path -like "*$script:ProjectRoot*" }).Count
        TestDrive = if ($TestDrive) { $TestDrive } else { $env:TEMP }
    }
}

function New-TestConfiguration {
    <#
    .SYNOPSIS
        Create test configuration object
    .DESCRIPTION
        Creates a standard test configuration for consistent testing
    #>
    [CmdletBinding()]
    param(
        [string]$Profile = 'Standard',
        [hashtable]$Overrides = @{}
    )

    $config = @{
        Core = @{
            Name = "AitherZero-Test"
            Version = "1.0.0"
            Profile = $Profile
            Environment = "Test"
        }
        Automation = @{
            MaxConcurrency = 2
            DryRun = $true
            ValidateBeforeRun = $true
            ScriptsPath = Join-Path $script:ProjectRoot "automation-scripts"
        }
        Logging = @{
            Level = "Debug"
            Path = Join-Path $TestDrive "logs"
            Targets = @("File")
        }
        Testing = @{
            Profile = "CI"
            CoverageEnabled = $true
        }
    }

    # Apply overrides
    foreach ($key in $Overrides.Keys) {
        if ($config.ContainsKey($key)) {
            foreach ($subKey in $Overrides[$key].Keys) {
                $config[$key][$subKey] = $Overrides[$key][$subKey]
            }
        } else {
            $config[$key] = $Overrides[$key]
        }
    }

    return $config
}

function New-MockBootstrapEnvironment {
    <#
    .SYNOPSIS
        Create mock environment for bootstrap testing
    .DESCRIPTION
        Sets up a complete mock environment for testing bootstrap scenarios
    #>
    [CmdletBinding()]
    param(
        [string]$Path = $TestDrive,
        [switch]$WithExistingInstall,
        [switch]$WithConflictingModules,
        [string]$Platform = $(if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } else { 'macOS' })
    )

    $mockEnv = @{
        Path = $Path
        Platform = $Platform
        PowerShellVersion = $PSVersionTable.PSVersion
    }

    # Create directory structure
    $dirs = @('logs', 'config', 'temp', 'domains', 'automation-scripts')
    foreach ($dir in $dirs) {
        New-Item -Path (Join-Path $Path $dir) -ItemType Directory -Force | Out-Null
    }

    if ($WithExistingInstall) {
        # Create files that indicate existing installation
        @'
{
    "Core": {
        "Name": "AitherZero",
        "Version": "0.9.0",
        "Profile": "Standard"
    }
}
'@ | Set-Content (Join-Path $Path "config.json")
        
        # Create dummy module files
        "# Existing module" | Set-Content (Join-Path $Path "AitherZero.psm1")
        "# Existing launcher" | Set-Content (Join-Path $Path "Start-AitherZero.ps1")
    }

    if ($WithConflictingModules) {
        # Set environment variables that would conflict
        $env:AITHERIUM_ROOT = "C:\Conflict\Aitherium"
        $env:PSModulePath = "$env:PSModulePath;C:\Conflict\Aitherium\modules"
    }

    return $mockEnv
}

function Test-ModuleFunction {
    <#
    .SYNOPSIS
        Test if a module function exists and is callable
    .DESCRIPTION
        Verifies that a function from a module is available
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FunctionName,
        
        [string]$ModuleName
    )

    $cmd = Get-Command -Name $FunctionName -ErrorAction SilentlyContinue
    if (-not $cmd) {
        return $false
    }

    if ($ModuleName -and $cmd.ModuleName -ne $ModuleName) {
        return $false
    }

    return $true
}

function Invoke-TestWithRetry {
    <#
    .SYNOPSIS
        Invoke a test with retry logic
    .DESCRIPTION
        Useful for tests that may have timing issues
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [int]$MaxRetries = 3,
        [int]$DelaySeconds = 1
    )

    $attempt = 0
    $lastError = $null

    while ($attempt -lt $MaxRetries) {
        try {
            $result = & $ScriptBlock
            return $result
        }
        catch {
            $lastError = $_
            $attempt++
            if ($attempt -lt $MaxRetries) {
                Start-Sleep -Seconds $DelaySeconds
            }
        }
    }

    throw $lastError
}

function Clear-TestEnvironment {
    <#
    .SYNOPSIS
        Clean up test environment
    .DESCRIPTION
        Removes test artifacts and resets environment
    #>
    [CmdletBinding()]
    param()

    # Remove test environment variables
    Remove-Item env:AITHERZERO_TEST_MODE -ErrorAction SilentlyContinue
    Remove-Item env:AITHERZERO_DISABLE_TRANSCRIPT -ErrorAction SilentlyContinue
    Remove-Item env:AITHERIUM_ROOT -ErrorAction SilentlyContinue

    # Clean module path
    if ($env:PSModulePath) {
        $cleanPaths = $env:PSModulePath -split [IO.Path]::PathSeparator | 
            Where-Object { $_ -notlike "*Conflict*" -and $_ -notlike "*TestDrive*" }
        $env:PSModulePath = $cleanPaths -join [IO.Path]::PathSeparator
    }

    # Remove loaded test modules
    Get-Module | Where-Object { $_.Path -like "*TestDrive*" } | Remove-Module -Force -ErrorAction SilentlyContinue
}

function Assert-FileContent {
    <#
    .SYNOPSIS
        Assert file contains expected content
    .DESCRIPTION
        Helper for validating file content in tests
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter(Mandatory)]
        [string[]]$ExpectedContent,
        
        [switch]$Exact
    )

    $content = Get-Content -Path $Path -Raw

    foreach ($expected in $ExpectedContent) {
        if ($Exact) {
            $content | Should -Be $expected
        } else {
            $content | Should -BeLike "*$expected*"
        }
    }
}

function Get-TestCoverageReport {
    <#
    .SYNOPSIS
        Generate coverage report for test results
    .DESCRIPTION
        Creates detailed coverage report from Pester results
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $PesterResult,
        
        [string]$OutputPath
    )

    $coverage = @{
        TotalLines = 0
        CoveredLines = 0
        MissedLines = 0
        Files = @{}
    }

    if ($PesterResult.CodeCoverage) {
        $coverage.TotalLines = $PesterResult.CodeCoverage.NumberOfCommandsAnalyzed
        $coverage.CoveredLines = $PesterResult.CodeCoverage.NumberOfCommandsExecuted
        $coverage.MissedLines = $coverage.TotalLines - $coverage.CoveredLines
        
        foreach ($file in $PesterResult.CodeCoverage.AnalyzedFiles) {
            $fileName = Split-Path $file -Leaf
            $coverage.Files[$fileName] = @{
                Path = $file
                Coverage = 0
            }
        }
    }

    if ($OutputPath) {
        $coverage | ConvertTo-Json -Depth 10 | Set-Content $OutputPath
    }

    return $coverage
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-TestEnvironment',
    'New-TestConfiguration',
    'New-MockBootstrapEnvironment',
    'Test-ModuleFunction',
    'Invoke-TestWithRetry',
    'Clear-TestEnvironment',
    'Assert-FileContent',
    'Get-TestCoverageReport'
)