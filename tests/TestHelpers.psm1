#Requires -Version 7.0
<#
.SYNOPSIS
    Test helper functions for AitherZero test suite
.DESCRIPTION
    Provides common initialization, mocking, and cleanup utilities for tests
#>

# Get project root
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent

# ============================================================================
# Environment Detection Functions
# ============================================================================

function Test-IsCI {
    <#
    .SYNOPSIS
        Detects if tests are running in a CI/CD environment
    .DESCRIPTION
        Checks multiple environment variables to reliably detect CI environments
        including GitHub Actions, GitLab CI, Azure Pipelines, CircleCI, and others
    .OUTPUTS
        Boolean indicating whether the current environment is CI
    .EXAMPLE
        if (Test-IsCI) {
            # Use CI-specific test behavior
        }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Check common CI environment variables
    # Convert non-empty string variables to boolean to ensure proper detection
    # Note: Storing each check in a variable first ensures proper array construction
    $check1 = $env:CI -eq 'true'
    $check2 = $env:GITHUB_ACTIONS -eq 'true'
    $check3 = $env:GITLAB_CI -eq 'true'
    $check4 = $env:CIRCLECI -eq 'true'
    $check5 = $env:TF_BUILD -eq 'true'
    $check6 = [bool]$env:JENKINS_URL
    $check7 = $env:TRAVIS -eq 'true'
    $check8 = $env:APPVEYOR -eq 'true'
    $check9 = [bool]$env:TEAMCITY_VERSION
    $check10 = $env:AITHERZERO_CI -eq 'true'
    
    $ciIndicators = @($check1, $check2, $check3, $check4, $check5, $check6, $check7, $check8, $check9, $check10)

    return ($ciIndicators -contains $true)
}

function Get-TestEnvironment {
    <#
    .SYNOPSIS
        Gets detailed information about the test execution environment
    .DESCRIPTION
        Returns a hashtable containing environment details useful for
        environment-aware test execution and debugging
    .OUTPUTS
        Hashtable with environment details
    .EXAMPLE
        $env = Get-TestEnvironment
        if ($env.IsCI) {
            # Adjust test timeouts for CI
        }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $isCI = Test-IsCI
    $ciProvider = Get-CIProvider

    return @{
        IsCI = $isCI
        IsLocal = -not $isCI
        CIProvider = $ciProvider
        Platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
        PowerShellVersion = $PSVersionTable.PSVersion
        IsTestMode = $env:AITHERZERO_TEST_MODE -eq '1'
        ProjectRoot = $script:ProjectRoot
        HasInteractiveConsole = [Environment]::UserInteractive -and -not $isCI
        ParallelizationSupported = $isCI -or $PSVersionTable.PSVersion.Major -ge 7
    }
}

function Get-CIProvider {
    <#
    .SYNOPSIS
        Identifies which CI/CD provider is running the tests
    .DESCRIPTION
        Returns the name of the CI provider or 'Local' if not in CI
    .OUTPUTS
        String indicating the CI provider name
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if ($env:GITHUB_ACTIONS -eq 'true') { return 'GitHubActions' }
    if ($env:GITLAB_CI -eq 'true') { return 'GitLabCI' }
    if ($env:CIRCLECI -eq 'true') { return 'CircleCI' }
    if ($env:TF_BUILD -eq 'true') { return 'AzurePipelines' }
    if ($env:JENKINS_URL) { return 'Jenkins' }
    if ($env:TRAVIS -eq 'true') { return 'TravisCI' }
    if ($env:APPVEYOR -eq 'true') { return 'AppVeyor' }
    if ($env:TEAMCITY_VERSION) { return 'TeamCity' }
    if ($env:AITHERZERO_CI -eq 'true') { return 'AitherZeroCI' }

    return 'Local'
}

function Get-TestTimeout {
    <#
    .SYNOPSIS
        Gets appropriate timeout values based on environment
    .DESCRIPTION
        Returns timeout values that are adjusted for CI vs local environments.
        CI environments typically need longer timeouts due to resource constraints.
    .PARAMETER Operation
        The operation type (e.g., 'Short', 'Medium', 'Long', 'VeryLong')
    .OUTPUTS
        Integer representing timeout in seconds
    .EXAMPLE
        $timeout = Get-TestTimeout -Operation 'Medium'
        Invoke-Command -ScriptBlock { ... } -TimeoutSeconds $timeout
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter()]
        [ValidateSet('Short', 'Medium', 'Long', 'VeryLong')]
        [string]$Operation = 'Medium'
    )

    $isCI = Test-IsCI

    # Define timeout multipliers for CI
    $ciMultiplier = 2.0

    $baseTimeouts = @{
        Short = 30      # 30 seconds
        Medium = 120    # 2 minutes
        Long = 300      # 5 minutes
        VeryLong = 600  # 10 minutes
    }

    $timeout = $baseTimeouts[$Operation]

    if ($isCI) {
        $timeout = [int]($timeout * $ciMultiplier)
    }

    return $timeout
}

function Skip-IfCI {
    <#
    .SYNOPSIS
        Determines if a test should be skipped in CI environments
    .DESCRIPTION
        Returns a skip directive for Pester tests that should only run locally
    .PARAMETER Reason
        Reason for skipping in CI
    .OUTPUTS
        Boolean indicating whether to skip
    .EXAMPLE
        It 'Should test interactive feature' -Skip:(Skip-IfCI -Reason 'Requires interactive console') {
            # Test code
        }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$Reason = 'Not supported in CI environment'
    )

    $isCI = Test-IsCI
    if ($isCI) {
        Write-Verbose "Skipping test in CI: $Reason"
    }
    return $isCI
}

function Skip-IfLocal {
    <#
    .SYNOPSIS
        Determines if a test should be skipped in local environments
    .DESCRIPTION
        Returns a skip directive for Pester tests that should only run in CI
    .PARAMETER Reason
        Reason for skipping locally
    .OUTPUTS
        Boolean indicating whether to skip
    .EXAMPLE
        It 'Should test CI-specific configuration' -Skip:(Skip-IfLocal -Reason 'CI-only validation') {
            # Test code
        }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$Reason = 'Only runs in CI environment'
    )

    $isLocal = -not (Test-IsCI)
    if ($isLocal) {
        Write-Verbose "Skipping test locally: $Reason"
    }
    return $isLocal
}

function Get-TestResourcePath {
    <#
    .SYNOPSIS
        Gets environment-appropriate paths for test resources
    .DESCRIPTION
        Returns paths that adapt based on CI vs local environment,
        useful for test data, temp files, and output directories
    .PARAMETER ResourceType
        Type of resource (TempDir, TestData, Output, Cache)
    .OUTPUTS
        String path to the resource
    .EXAMPLE
        $tempPath = Get-TestResourcePath -ResourceType 'TempDir'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('TempDir', 'TestData', 'Output', 'Cache', 'Logs')]
        [string]$ResourceType
    )

    $isCI = Test-IsCI
    $projectRoot = $script:ProjectRoot

    switch ($ResourceType) {
        'TempDir' {
            # Cross-platform temp directory detection
            $temp = if ($isCI -and $env:RUNNER_TEMP) {
                $env:RUNNER_TEMP
            } elseif ($env:TEMP) {
                $env:TEMP
            } elseif ($env:TMP) {
                $env:TMP
            } elseif ($env:TMPDIR) {
                $env:TMPDIR
            } elseif ($IsWindows) {
                'C:\Windows\Temp'
            } else {
                '/tmp'
            }
            return $temp
        }
        'TestData' {
            return Join-Path $projectRoot 'tests/data'
        }
        'Output' {
            $basePath = Join-Path $projectRoot 'tests/results'
            if ($isCI) {
                return Join-Path $basePath 'ci'
            } else {
                return Join-Path $basePath 'local'
            }
        }
        'Cache' {
            # Cross-platform cache directory
            $temp = if ($isCI -and $env:RUNNER_TEMP) {
                $env:RUNNER_TEMP
            } elseif ($env:TEMP) {
                $env:TEMP
            } elseif ($env:TMP) {
                $env:TMP
            } elseif ($env:TMPDIR) {
                $env:TMPDIR
            } elseif ($IsWindows) {
                'C:\Windows\Temp'
            } else {
                '/tmp'
            }
            
            if ($isCI) {
                return Join-Path $temp 'test-cache'
            } else {
                return Join-Path $projectRoot '.cache/tests'
            }
        }
        'Logs' {
            $basePath = Join-Path $projectRoot 'logs'
            if ($isCI) {
                return Join-Path $basePath 'ci-tests'
            } else {
                return Join-Path $basePath 'local-tests'
            }
        }
    }
}

function Initialize-TestEnvironment {
    <#
    .SYNOPSIS
        Initialize test environment with proper module loading
    .DESCRIPTION
        Sets up clean test environment and loads AitherZero modules.
        Automatically detects CI vs local environment and adjusts configuration.
    #>
    [CmdletBinding()]
    param(
        [switch]$SkipModuleLoad,
        [string[]]$RequiredModules = @()
    )

    # Detect environment
    $testEnv = Get-TestEnvironment

    # Clean any conflicting modules
    $conflictingModules = @('AitherRun', 'CoreApp', 'ConfigurationManager', 'aitherzero')
    foreach ($module in $conflictingModules) {
        if (Get-Module -Name $module -ErrorAction SilentlyContinue) {
            Remove-Module -Name $module -Force -ErrorAction SilentlyContinue
        }
    }

    # Set environment variables
    $env:AITHERZERO_ROOT = $script:ProjectRoot
    $env:AITHERZERO_TEST_MODE = "1"
    $env:AITHERZERO_DISABLE_TRANSCRIPT = "1"  # Disable transcript during tests
    
    # Set CI flag if detected
    if ($testEnv.IsCI -and -not $env:AITHERZERO_CI) {
        $env:AITHERZERO_CI = "true"
    }

    if (-not $SkipModuleLoad) {
        # Import main module
        Import-Module (Join-Path $script:ProjectRoot "AitherZero.psm1") -Force -Global

        # Import any additional required modules
        foreach ($moduleName in $RequiredModules) {
            $modulePath = Get-ChildItem -Path (Join-Path $script:ProjectRoot "aithercore") -Filter "$moduleName.psm1" -Recurse | Select-Object -First 1
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
        IsCI = $testEnv.IsCI
        CIProvider = $testEnv.CIProvider
        Platform = $testEnv.Platform
    }
}

function New-TestConfiguration {
    <#
    .SYNOPSIS
        Create test configuration object
    .DESCRIPTION
        Creates a standard test configuration for consistent testing.
        Automatically adapts configuration based on CI vs local environment.
    #>
    [CmdletBinding()]
    param(
        [string]$ProfileName = 'Standard',
        [hashtable]$Overrides = @{}
    )

    $testEnv = Get-TestEnvironment
    
    # Adjust profile based on environment if not explicitly set
    if (-not $PSBoundParameters.ContainsKey('ProfileName') -and $testEnv.IsCI) {
        $ProfileName = 'CI'
    }

    $config = @{
        Core = @{
            Name = "AitherZero-Test"
            Version = "1.0.0"
            Profile = $ProfileName
            Environment = if ($testEnv.IsCI) { "CI" } else { "Test" }
        }
        Automation = @{
            MaxConcurrency = if ($testEnv.IsCI) { 1 } else { 2 }  # CI: sequential, Local: parallel
            DryRun = $true
            ValidateBeforeRun = $true
            ScriptsPath = Join-Path $script:ProjectRoot "library/automation-scripts"
        }
        Logging = @{
            Level = if ($testEnv.IsCI) { "Information" } else { "Debug" }
            Path = Get-TestResourcePath -ResourceType 'Logs'
            Targets = @("File")
        }
        Testing = @{
            Profile = if ($testEnv.IsCI) { "CI" } else { "Standard" }
            CoverageEnabled = $testEnv.IsCI
            Timeouts = @{
                Short = Get-TestTimeout -Operation 'Short'
                Medium = Get-TestTimeout -Operation 'Medium'
                Long = Get-TestTimeout -Operation 'Long'
            }
        }
        Environment = @{
            IsCI = $testEnv.IsCI
            CIProvider = $testEnv.CIProvider
            Platform = $testEnv.Platform
            TempPath = Get-TestResourcePath -ResourceType 'TempDir'
            CachePath = Get-TestResourcePath -ResourceType 'Cache'
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
    $dirs = @('logs', 'config', 'temp', 'domains', 'library/automation-scripts')
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
'@ | Set-Content (Join-Path $Path "config.psd1")

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
    # Environment Detection
    'Test-IsCI',
    'Get-TestEnvironment',
    'Get-CIProvider',
    'Get-TestTimeout',
    'Skip-IfCI',
    'Skip-IfLocal',
    'Get-TestResourcePath',
    # Test Setup & Utilities
    'Initialize-TestEnvironment',
    'New-TestConfiguration',
    'New-MockBootstrapEnvironment',
    'Test-ModuleFunction',
    'Invoke-TestWithRetry',
    'Clear-TestEnvironment',
    'Assert-FileContent',
    'Get-TestCoverageReport'
)