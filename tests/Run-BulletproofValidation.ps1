#Requires -Version 7.0

<#
.SYNOPSIS
    Bulletproof Final Validation - The ultimate test that ALL systems are working

.DESCRIPTION
    This is the final stamp of approval that validates the entire system is healthy and ready.
    - Uses true parallel execution for speed
    - Only runs tests that MUST pass for the system to be considered healthy
    - Fails fast if ANY critical component fails
    - Provides clear pass/fail status for deployment decisions

    This is NOT for debugging individual components - use module-specific tests for that.
    This is the final "go/no-go" decision for production readiness.

.PARAMETER ValidationLevel
    Quick: Core functionality only (2-3 minutes)
    Standard: All critical systems (5-7 minutes)
    Complete: Every system validated (10-15 minutes)

.PARAMETER FailFast
    Stop on first failure instead of running all tests

.PARAMETER MaxParallelJobs
    Maximum number of parallel test jobs (default: 8)

.EXAMPLE
    .\Run-BulletproofValidation.ps1 -ValidationLevel Quick

.EXAMPLE
    .\Run-BulletproofValidation.ps1 -ValidationLevel Complete -FailFast

.NOTES
    This replaces the old bulletproof system with a focused, fast validation approach
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Quick', 'Standard', 'Complete')]
    [string]$ValidationLevel = 'Standard',

    [Parameter()]
    [switch]$FailFast,

    [Parameter()]
    [int]$MaxParallelJobs = 8,

    [Parameter()]
    [switch]$CI,

    [Parameter()]
    [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'

# Initialize environment
if (-not $env:PROJECT_ROOT -or -not (Test-Path "$env:PROJECT_ROOT/aither-core")) {
    $env:PROJECT_ROOT = Split-Path $PSScriptRoot -Parent
}

$projectRoot = $env:PROJECT_ROOT
$startTime = Get-Date

# Import required modules
try {
    Import-Module "$projectRoot/aither-core/modules/Logging" -Force -ErrorAction SilentlyContinue
    Import-Module "$projectRoot/aither-core/modules/ParallelExecution" -Force -ErrorAction Stop
} catch {
    Write-Error "Failed to import required modules: $_"
    exit 1
}

# Enhanced logging
function Write-BulletproofLog {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'HH:mm:ss.fff'
    $color = switch ($Level) {
        'INFO' { 'Cyan' }
        'WARN' { 'Yellow' }
        'ERROR' { 'Red' }
        'SUCCESS' { 'Green' }
    }

    $symbol = switch ($Level) {
        'INFO' { 'ℹ️' }
        'WARN' { '⚠️' }
        'ERROR' { '❌' }
        'SUCCESS' { '✅' }
    }

    Write-Host "[$timestamp] $symbol $Message" -ForegroundColor $color

    # Also use project logging if available
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message
    }
}

# Define validation test suites
$validationSuites = @{
    'Quick'    = @{
        Name        = 'Quick Critical Validation'
        Description = 'Essential systems only - deployment readiness check'
        MaxDuration = 180 # 3 minutes
        Tests       = @(
            @{ Name = 'CoreRunner-Basic'; Type = 'Core'; Critical = $true }
            @{ Name = 'Launcher-Functionality'; Type = 'Core'; Critical = $true }
            @{ Name = 'Logging-System'; Type = 'Module'; Critical = $true }
            @{ Name = 'Module-Loading'; Type = 'System'; Critical = $true }
            @{ Name = 'Configuration-Valid'; Type = 'System'; Critical = $true }
            @{ Name = 'Script-Syntax-Check'; Type = 'Quality'; Critical = $true }
        )
    }
    'Standard' = @{
        Name        = 'Standard Production Validation'
        Description = 'All critical systems validated for production use'
        MaxDuration = 420 # 7 minutes
        Tests       = @(
            @{ Name = 'CoreRunner-Basic'; Type = 'Core'; Critical = $true }
            @{ Name = 'CoreRunner-NonInteractive'; Type = 'Core'; Critical = $true }
            @{ Name = 'CoreRunner-Auto'; Type = 'Core'; Critical = $true }
            @{ Name = 'Launcher-Functionality'; Type = 'Core'; Critical = $true }
            @{ Name = 'Module-Loading'; Type = 'Module'; Critical = $true }
            @{ Name = 'All-Modules-Export'; Type = 'Module'; Critical = $true }
            @{ Name = 'Logging-System'; Type = 'Module'; Critical = $true }
            @{ Name = 'ParallelExecution-Core'; Type = 'Module'; Critical = $true }
            @{ Name = 'TestingFramework-Core'; Type = 'Module'; Critical = $false }
            @{ Name = 'BackupManager-Core'; Type = 'Module'; Critical = $true }
            @{ Name = 'Configuration-Complete'; Type = 'System'; Critical = $true }
            @{ Name = 'FileSystem-Access'; Type = 'System'; Critical = $true }
            @{ Name = 'Performance-Basic'; Type = 'Performance'; Critical = $true }
            @{ Name = 'Script-Syntax-Check'; Type = 'Quality'; Critical = $true }
        )
    }
    'Complete' = @{
        Name        = 'Complete System Validation'
        Description = 'Every component validated - comprehensive health check'
        MaxDuration = 900 # 15 minutes
        Tests       = @(
            @{ Name = 'CoreRunner-Basic'; Type = 'Core'; Critical = $true }
            @{ Name = 'CoreRunner-NonInteractive'; Type = 'Core'; Critical = $true }
            @{ Name = 'CoreRunner-Auto'; Type = 'Core'; Critical = $true }
            @{ Name = 'CoreRunner-Scripts'; Type = 'Core'; Critical = $true }
            @{ Name = 'Launcher-Functionality'; Type = 'Core'; Critical = $true }
            @{ Name = 'All-Modules-Load'; Type = 'Module'; Critical = $true }
            @{ Name = 'All-Modules-Export'; Type = 'Module'; Critical = $true }
            @{ Name = 'All-Modules-Functions'; Type = 'Module'; Critical = $true }
            @{ Name = 'Logging-Complete'; Type = 'Module'; Critical = $true }
            @{ Name = 'ParallelExecution-Complete'; Type = 'Module'; Critical = $true }
            @{ Name = 'TestingFramework-Complete'; Type = 'Module'; Critical = $false }
            @{ Name = 'BackupManager-Core'; Type = 'Module'; Critical = $false }
            @{ Name = 'ScriptManager-Core'; Type = 'Module'; Critical = $false }
            @{ Name = 'DevEnvironment-Core'; Type = 'Module'; Critical = $false }
            @{ Name = 'Configuration-Complete'; Type = 'System'; Critical = $true }
            @{ Name = 'FileSystem-Complete'; Type = 'System'; Critical = $true }
            @{ Name = 'CrossPlatform-Basic'; Type = 'System'; Critical = $true }
            @{ Name = 'Performance-Complete'; Type = 'Performance'; Critical = $true }
            @{ Name = 'Integration-Core'; Type = 'Integration'; Critical = $false }
        )
    }
}

Write-BulletproofLog "🚀 Starting Bulletproof Validation: $ValidationLevel" -Level SUCCESS
Write-BulletproofLog "Project Root: $projectRoot" -Level INFO
Write-BulletproofLog "Max Parallel Jobs: $MaxParallelJobs" -Level INFO
Write-BulletproofLog "Fail Fast: $FailFast" -Level INFO

$selectedSuite = $validationSuites[$ValidationLevel]
Write-BulletproofLog "Validation Suite: $($selectedSuite.Name)" -Level INFO
Write-BulletproofLog "Description: $($selectedSuite.Description)" -Level INFO
Write-BulletproofLog "Max Duration: $($selectedSuite.MaxDuration) seconds" -Level INFO
Write-BulletproofLog "Total Tests: $($selectedSuite.Tests.Count)" -Level INFO

# Execute tests in parallel
Write-BulletproofLog '🔄 Starting parallel test execution...' -Level INFO

$testJobs = @()
$allResults = @()
$criticalFailures = @()

try {
    # Start all tests in parallel
    foreach ($test in $selectedSuite.Tests) {
        $job = Start-Job -ScriptBlock {
            param($TestDefinition, $ProjectRoot)

            # Set up environment in the job
            $env:PROJECT_ROOT = $ProjectRoot

            # Import required modules in the job
            try {
                Import-Module "$ProjectRoot/aither-core/modules/Logging" -Force -ErrorAction SilentlyContinue
                Import-Module "$ProjectRoot/aither-core/modules/ParallelExecution" -Force -ErrorAction SilentlyContinue
            } catch {
                # Ignore import errors in jobs
            }

            # Define the test function within the job scope
            function Invoke-BulletproofTest {
                param(
                    [string]$TestName,
                    [string]$Type,
                    [bool]$Critical
                )

                $testResult = @{
                    Name      = $TestName
                    Type      = $Type
                    Critical  = $Critical
                    Success   = $false
                    Duration  = 0
                    Message   = ''
                    Details   = @()
                    StartTime = Get-Date
                }

                try {
                    switch ($TestName) {
                        'CoreRunner-Basic' {
                            $tempDir = if ($env:TEMP) { $env:TEMP } elseif (Test-Path '/tmp') { '/tmp' } else { $ProjectRoot }                            $tempLog = Join-Path $tempDir 'bulletproof-basic.log'
                            $tempErr = Join-Path $tempDir 'bulletproof-basic-error.log'
                            $coreRunnerPath = Join-Path $ProjectRoot 'aither-core/aither-core.ps1'
                            $process = Start-Process -FilePath 'pwsh' -ArgumentList @(
                                '-File', "`"$coreRunnerPath`"",
                                '-NonInteractive', '-WhatIf', '-Verbosity', 'silent'
                            ) -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tempLog -RedirectStandardError $tempErr

                            $testResult.Success = ($process.ExitCode -eq 0)
                            $testResult.Message = if ($testResult.Success) { 'Core runner executed successfully' } else { "Core runner failed with exit code $($process.ExitCode)" }
                        }
                        'CoreRunner-NonInteractive' {
                            $tempDir = if ($env:TEMP) { $env:TEMP } elseif (Test-Path '/tmp') { '/tmp' } else { $ProjectRoot }
                            $tempLog = Join-Path $tempDir 'bulletproof-ni.log'
                            $tempErr = Join-Path $tempDir 'bulletproof-ni-error.log'
                            $coreRunnerPath = Join-Path $ProjectRoot 'aither-core/aither-core.ps1'
                            $process = Start-Process -FilePath 'pwsh' -ArgumentList @(
                                '-File', "`"$coreRunnerPath`"",
                                '-NonInteractive', '-Scripts', '0200_Get-SystemInfo', '-WhatIf', '-Verbosity', 'silent'
                            ) -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tempLog -RedirectStandardError $tempErr

                            $testResult.Success = ($process.ExitCode -eq 0)
                            $testResult.Message = if ($testResult.Success) { 'Non-interactive mode working' } else { "Non-interactive mode failed with exit code $($process.ExitCode)" }
                        }

                        'CoreRunner-Auto' {
                            $tempDir = if ($env:TEMP) { $env:TEMP } elseif (Test-Path '/tmp') { '/tmp' } else { $ProjectRoot }
                            $tempLog = Join-Path $tempDir 'bulletproof-auto.log'
                            $tempErr = Join-Path $tempDir 'bulletproof-auto-error.log'
                            $coreRunnerPath = Join-Path $ProjectRoot 'aither-core/aither-core.ps1'
                            $process = Start-Process -FilePath 'pwsh' -ArgumentList @(
                                '-File', "`"$coreRunnerPath`"",
                                '-NonInteractive', '-Auto', '-WhatIf', '-Verbosity', 'silent'
                            ) -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tempLog -RedirectStandardError $tempErr

                            $testResult.Success = ($process.ExitCode -eq 0)
                            $testResult.Message = if ($testResult.Success) { 'Auto mode working' } else { "Auto mode failed with exit code $($process.ExitCode)" }
                        }

                        'Module-Loading' {
                            $moduleDir = "$ProjectRoot/aither-core/modules"
                            $modules = Get-ChildItem -Path $moduleDir -Directory
                            $failedModules = @()

                            foreach ($module in $modules) {
                                try {
                                    Import-Module $module.FullName -Force -ErrorAction Stop
                                    $testResult.Details += "✅ $($module.Name)"
                                } catch {
                                    $failedModules += $module.Name
                                    $testResult.Details += "❌ $($module.Name): $($_.Exception.Message)"
                                }
                            }

                            $testResult.Success = ($failedModules.Count -eq 0)
                            $testResult.Message = if ($testResult.Success) { "All $($modules.Count) modules loaded successfully" } else { "$($failedModules.Count) modules failed to load: $($failedModules -join ', ')" }
                        }

                        'All-Modules-Load' {
                            $moduleDir = "$ProjectRoot/aither-core/modules"
                            $modules = Get-ChildItem -Path $moduleDir -Directory
                            $failedModules = @()

                            foreach ($module in $modules) {
                                try {
                                    Import-Module $module.FullName -Force -ErrorAction Stop
                                    $testResult.Details += "✅ $($module.Name)"
                                } catch {
                                    $failedModules += $module.Name
                                    $testResult.Details += "❌ $($module.Name): $($_.Exception.Message)"
                                }
                            }

                            $testResult.Success = ($failedModules.Count -eq 0)
                            $testResult.Message = if ($testResult.Success) { "All $($modules.Count) modules loaded successfully" } else { "$($failedModules.Count) modules failed to load: $($failedModules -join ', ')" }
                        }

                        'All-Modules-Export' {
                            $moduleDir = "$ProjectRoot/aither-core/modules"
                            $modules = Get-ChildItem -Path $moduleDir -Directory
                            $totalFunctions = 0
                            $failedModules = @()

                            foreach ($module in $modules) {
                                try {
                                    Import-Module $module.FullName -Force -ErrorAction Stop
                                    $exportedFunctions = Get-Command -Module $module.Name -ErrorAction Stop
                                    $totalFunctions += $exportedFunctions.Count
                                    $testResult.Details += "✅ $($module.Name): $($exportedFunctions.Count) functions"
                                } catch {
                                    $failedModules += $module.Name
                                    $testResult.Details += "❌ $($module.Name): No functions exported"
                                }
                            }

                            $testResult.Success = ($failedModules.Count -eq 0 -and $totalFunctions -gt 0)
                            $testResult.Message = if ($testResult.Success) { "All modules export functions ($totalFunctions total)" } else { "Some modules don't export functions properly" }
                        }

                        'Logging-System' {
                            try {
                                Import-Module "$ProjectRoot/aither-core/modules/Logging" -Force -ErrorAction Stop

                                # Test basic logging
                                if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                                    Write-CustomLog -Level 'INFO' -Message 'Bulletproof test message'
                                }

                                # Verify essential log functions exist
                                $logFunctions = @('Write-CustomLog', 'Initialize-LoggingSystem')
                                $missingFunctions = @()

                                foreach ($func in $logFunctions) {
                                    if (-not (Get-Command $func -ErrorAction SilentlyContinue)) {
                                        $missingFunctions += $func
                                    }
                                }

                                $testResult.Success = ($missingFunctions.Count -eq 0)
                                $testResult.Message = if ($testResult.Success) { 'Logging system fully functional' } else { "Missing functions: $($missingFunctions -join ', ')" }
                            } catch {
                                $testResult.Success = $false
                                $testResult.Message = "Logging system failed: $($_.Exception.Message)"
                            }
                        }

                        'ParallelExecution-Core' {
                            try {
                                Import-Module "$ProjectRoot/aither-core/modules/ParallelExecution" -Force -ErrorAction Stop

                                # Test basic parallel execution using pipeline input (correct way)
                                $inputs = @(1, 2, 3, 4, 5)
                                $results = $inputs | Invoke-ParallelForEach -ScriptBlock { param($num) return $num * 2 } -ThrottleLimit 3

                                # More robust validation
                                $expectedResults = @(2, 4, 6, 8, 10)
                                $testResult.Details += "Raw results count: $($results.Count)"
                                $testResult.Details += "Expected: $($expectedResults -join ', ')"
                                $testResult.Details += "Actual: $($results -join ', ')"

                                $resultsValid = ($results.Count -eq 5 -and ($results | Sort-Object) -join ',' -eq ($expectedResults | Sort-Object) -join ',')
                                $testResult.Success = $resultsValid
                                $testResult.Message = if ($testResult.Success) { 'Parallel execution working correctly' } else { "Parallel execution failed - expected 5 results (2,4,6,8,10), got $($results.Count) results ($($results -join ','))" }
                            } catch {
                                $testResult.Success = $false
                                $testResult.Message = "Parallel execution failed: $($_.Exception.Message)"
                            }
                        }

                        'Configuration-Valid' {
                            $configFiles = @(
                                "$ProjectRoot/aither-core/default-config.json"
                            )

                            $invalidConfigs = @()
                            foreach ($configFile in $configFiles) {
                                if (Test-Path $configFile) {
                                    try {
                                        $null = Get-Content $configFile -Raw | ConvertFrom-Json -ErrorAction Stop
                                        $testResult.Details += "✅ $configFile"
                                    } catch {
                                        $invalidConfigs += $configFile
                                        $testResult.Details += "❌ ${configFile}: $($_.Exception.Message)"
                                    }
                                } else {
                                    $invalidConfigs += "$configFile (missing)"
                                    $testResult.Details += "❌ ${configFile}: File not found"
                                }
                            }

                            $testResult.Success = ($invalidConfigs.Count -eq 0)
                            $testResult.Message = if ($testResult.Success) { 'All configuration files valid' } else { "Invalid configs: $($invalidConfigs.Count)" }
                        }

                        'TestingFramework-Core' {
                            try {
                                Import-Module "$ProjectRoot/aither-core/modules/TestingFramework" -Force -ErrorAction Stop

                                # Test basic TestingFramework functionality
                                $testFunctions = @('Invoke-PesterTests', 'New-TestReport')
                                $missingFunctions = @()

                                foreach ($func in $testFunctions) {
                                    if (-not (Get-Command $func -ErrorAction SilentlyContinue)) {
                                        $missingFunctions += $func
                                    }
                                }

                                $testResult.Success = ($missingFunctions.Count -eq 0)
                                $testResult.Message = if ($testResult.Success) { 'TestingFramework functional' } else { "Missing functions: $($missingFunctions -join ', ')" }
                            } catch {
                                $testResult.Success = $false
                                $testResult.Message = "TestingFramework failed: $($_.Exception.Message)"
                            }
                        }

                        'Configuration-Complete' {
                            $configFiles = @(
                                "$ProjectRoot/aither-core/default-config.json",
                                "$ProjectRoot/.vscode/tasks.json"
                            )

                            $invalidConfigs = @()
                            foreach ($configFile in $configFiles) {
                                if (Test-Path $configFile) {
                                    try {
                                        if ($configFile -like '*.json') {
                                            $null = Get-Content $configFile -Raw | ConvertFrom-Json -ErrorAction Stop
                                        }
                                        $testResult.Details += "✅ $configFile"
                                    } catch {
                                        $invalidConfigs += $configFile
                                        $testResult.Details += "❌ ${configFile} - $($_.Exception.Message)"
                                    }
                                } else {
                                    $invalidConfigs += "$configFile (missing)"
                                    $testResult.Details += "❌ ${configFile} - File not found"
                                }
                            }

                            $testResult.Success = ($invalidConfigs.Count -eq 0)
                            $testResult.Message = if ($testResult.Success) { 'All configuration files valid' } else { "Invalid configs: $($invalidConfigs.Count)" }
                        }

                        'FileSystem-Access' {
                            $testPaths = @(
                                "$ProjectRoot/aither-core",
                                "$ProjectRoot/tests",
                                "$ProjectRoot/.vscode"
                            )

                            $accessIssues = @()
                            foreach ($path in $testPaths) {
                                try {
                                    if (Test-Path $path) {
                                        $items = Get-ChildItem $path -ErrorAction Stop | Select-Object -First 3
                                        $testResult.Details += "✅ ${path} (accessible)"
                                    } else {
                                        $accessIssues += "$path (missing)"
                                        $testResult.Details += "❌ ${path} - Not found"
                                    }
                                } catch {
                                    $accessIssues += $path
                                    $testResult.Details += "❌ ${path} - $($_.Exception.Message)"
                                }
                            }

                            $testResult.Success = ($accessIssues.Count -eq 0)
                            $testResult.Message = if ($testResult.Success) { 'File system access OK' } else { "Access issues: $($accessIssues.Count)" }
                        }

                        'Performance-Basic' {
                            $startPerfTime = Get-Date

                            # Test basic startup performance
                            $coreRunnerPath = Join-Path $ProjectRoot 'aither-core/aither-core.ps1'
                            $process = Start-Process -FilePath 'pwsh' -ArgumentList @(
                                '-File', "`"$coreRunnerPath`"",
                                '-NonInteractive', '-WhatIf', '-Verbosity', 'silent'
                            ) -NoNewWindow -Wait -PassThru

                            $perfDuration = ((Get-Date) - $startPerfTime).TotalMilliseconds

                            $testResult.Success = ($process.ExitCode -eq 0 -and $perfDuration -lt 15000) # 15 seconds max
                            $testResult.Message = if ($testResult.Success) { "Performance acceptable: $($perfDuration.ToString('F0'))ms" } else { "Performance too slow: $($perfDuration.ToString('F0'))ms" }
                            $testResult.Details += "Execution time: $($perfDuration.ToString('F0'))ms"
                        }

                        'Script-Syntax-Check' {
                            try {
                                # Check if PSScriptAnalyzer is available
                                $psaAvailable = $false
                                try {
                                    Import-Module PSScriptAnalyzer -Force -ErrorAction Stop
                                    $psaAvailable = $true
                                    $testResult.Details += '✅ PSScriptAnalyzer available'
                                } catch {
                                    $testResult.Details += '⚠️ PSScriptAnalyzer not available, using AST parser only'
                                }

                                # Get critical PowerShell files to check
                                $scriptFiles = @()
                                $scriptPaths = @(
                                    "$ProjectRoot/aither-core/*.ps1",
                                    "$ProjectRoot/aither-core/modules/*/*.psm1",
                                    "$ProjectRoot/tests/*.ps1"
                                )

                                foreach ($path in $scriptPaths) {
                                    $files = Get-ChildItem $path -ErrorAction SilentlyContinue
                                    if ($files) {
                                        $scriptFiles += $files
                                    }
                                }

                                $totalFiles = $scriptFiles.Count
                                $syntaxErrors = @()
                                $psaIssues = @()
                                $processedFiles = 0

                                foreach ($file in $scriptFiles) {
                                    $processedFiles++

                                    # AST syntax validation (always run)
                                    try {
                                        $errors = $null
                                        $tokens = $null
                                        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)

                                        if ($errors.Count -gt 0) {
                                            $syntaxErrors += @{
                                                File   = $file.Name
                                                Errors = $errors
                                            }
                                            $testResult.Details += "❌ $($file.Name): $($errors.Count) syntax errors"
                                        }
                                    } catch {
                                        $syntaxErrors += @{
                                            File   = $file.Name
                                            Errors = @("Failed to parse: $($_.Exception.Message)")
                                        }
                                        $testResult.Details += "❌ $($file.Name): Parse failed"
                                    }

                                    # PSScriptAnalyzer validation (if available and no syntax errors)
                                    if ($psaAvailable -and $syntaxErrors.Count -eq 0) {
                                        try {
                                            $issues = Invoke-ScriptAnalyzer -Path $file.FullName -Severity Error, Warning -ErrorAction Stop
                                            if ($issues) {
                                                $criticalIssues = $issues | Where-Object { $_.Severity -eq 'Error' }
                                                if ($criticalIssues) {
                                                    $psaIssues += @{
                                                        File   = $file.Name
                                                        Issues = $criticalIssues
                                                    }
                                                    $testResult.Details += "⚠️ $($file.Name): $($criticalIssues.Count) critical issues"
                                                }
                                            }
                                        } catch {
                                            $testResult.Details += "⚠️ $($file.Name): PSScriptAnalyzer failed"
                                        }
                                    }
                                }

                                $totalIssues = $syntaxErrors.Count + $psaIssues.Count
                                $testResult.Success = ($syntaxErrors.Count -eq 0) # Syntax errors are critical, PSA warnings are not

                                if ($testResult.Success) {
                                    $testResult.Message = "Script syntax validation passed ($processedFiles files checked)"
                                    if ($psaIssues.Count -gt 0) {
                                        $testResult.Message += " - $($psaIssues.Count) code quality issues found"
                                    }
                                } else {
                                    $testResult.Message = "Script syntax validation failed: $($syntaxErrors.Count) files with syntax errors"
                                }

                                $testResult.Details += "Total files checked: $processedFiles"
                                $testResult.Details += "Syntax errors: $($syntaxErrors.Count)"
                                $testResult.Details += "Code quality issues: $($psaIssues.Count)"

                            } catch {
                                $testResult.Success = $false
                                $testResult.Message = "Script syntax check failed: $($_.Exception.Message)"
                            }
                        }

                        'CoreRunner-Scripts' {
                            # Test core runner with specific scripts
                            $coreRunnerPath = Join-Path $ProjectRoot 'aither-core/core-runner.ps1'
                            $testScripts = @('0200_Get-SystemInfo', '0207_Install-Git') # Use scripts that actually exist

                            $scriptsAvailable = 0
                            $scriptsExecuted = 0

                            foreach ($script in $testScripts) {
                                $scriptPath = Join-Path $ProjectRoot "aither-core/scripts/$script.ps1"
                                if (Test-Path $scriptPath) {
                                    $scriptsAvailable++
                                    try {
                                        $process = Start-Process -FilePath 'pwsh' -ArgumentList @(
                                            '-File', "`"$coreRunnerPath`"",
                                            '-NonInteractive', '-Scripts', $script, '-WhatIf', '-Verbosity', 'silent'
                                        ) -NoNewWindow -Wait -PassThru

                                        if ($process.ExitCode -eq 0) {
                                            $scriptsExecuted++
                                            $testResult.Details += "✅ $script executed successfully"
                                        } else {
                                            $testResult.Details += "❌ $script failed with exit code $($process.ExitCode)"
                                        }
                                    } catch {
                                        $testResult.Details += "❌ $script execution failed: $($_.Exception.Message)"
                                    }
                                } else {
                                    $testResult.Details += "⚠️ $script not found"
                                }
                            }

                            $testResult.Success = ($scriptsExecuted -eq $scriptsAvailable -and $scriptsAvailable -gt 0)
                            $testResult.Message = if ($testResult.Success) {
                                "Script execution working ($scriptsExecuted/$scriptsAvailable scripts)"
                            } else {
                                "Script execution issues ($scriptsExecuted/$scriptsAvailable scripts)"
                            }
                        }

                        'All-Modules-Functions' {
                            # Test that modules export expected functions
                            $moduleTestResults = @()
                            $expectedFunctions = @{
                                'Logging'           = @('Write-CustomLog', 'Initialize-LoggingSystem')
                                'ParallelExecution' = @('Invoke-ParallelForEach', 'Start-ParallelJob')
                                'TestingFramework'  = @('Invoke-BulletproofTest', 'Start-TestSuite')
                                'PatchManager'      = @('Invoke-PatchWorkflow', 'New-PatchIssue', 'New-PatchPR')
                                'LabRunner'         = @('Start-LabAutomation', 'Get-LabStatus')
                            }

                            foreach ($moduleName in $expectedFunctions.Keys) {
                                try {
                                    $modulePath = Join-Path $ProjectRoot "aither-core/modules/$moduleName"
                                    if (Test-Path $modulePath) {
                                        Import-Module $modulePath -Force -ErrorAction Stop
                                        $exportedFunctions = (Get-Module $moduleName).ExportedFunctions.Keys

                                        $missingFunctions = @()
                                        foreach ($func in $expectedFunctions[$moduleName]) {
                                            if ($func -notin $exportedFunctions) {
                                                $missingFunctions += $func
                                            }
                                        }
                                        if ($missingFunctions.Count -eq 0) {
                                            $moduleTestResults += "✅ ${moduleName}: All expected functions available"
                                        } else {
                                            $moduleTestResults += "❌ ${moduleName}: Missing functions: $($missingFunctions -join ', ')"
                                        }
                                    } else {
                                        $moduleTestResults += "❌ ${moduleName}: Module not found"
                                    }
                                } catch {
                                    $moduleTestResults += "❌ ${moduleName}: Failed to load - $($_.Exception.Message)"
                                }
                            }

                            $testResult.Details += $moduleTestResults
                            $failedModules = $moduleTestResults | Where-Object { $_ -like '❌*' }
                            $testResult.Success = ($failedModules.Count -eq 0)
                            $testResult.Message = if ($testResult.Success) {
                                'All modules export expected functions'
                            } else {
                                "Function validation failed for $($failedModules.Count) modules"
                            }
                        }

                        'Logging-Complete' {
                            # Comprehensive logging system test
                            try {
                                Import-Module "$ProjectRoot/aither-core/modules/Logging" -Force -ErrorAction Stop

                                # Test all log levels
                                $logLevels = @('INFO', 'WARN', 'ERROR', 'SUCCESS')
                                $logTests = @()

                                foreach ($level in $logLevels) {
                                    try {
                                        Write-CustomLog -Level $level -Message "Test message for level $level"
                                        $logTests += "✅ $level logging works"
                                    } catch {
                                        $logTests += "❌ $level logging failed: $($_.Exception.Message)"
                                    }
                                }

                                # Test log file creation
                                $logDir = Join-Path $ProjectRoot 'logs'
                                if (Test-Path $logDir) {
                                    $logFiles = Get-ChildItem $logDir -Filter '*.log' -ErrorAction SilentlyContinue
                                    if ($logFiles) {
                                        $logTests += "✅ Log files created ($($logFiles.Count) files)"
                                    } else {
                                        $logTests += '⚠️ No log files found'
                                    }
                                } else {
                                    $logTests += '⚠️ Log directory not found'
                                }

                                $testResult.Details += $logTests
                                $failedTests = $logTests | Where-Object { $_ -like '❌*' }
                                $testResult.Success = ($failedTests.Count -eq 0)
                                $testResult.Message = if ($testResult.Success) {
                                    'Complete logging system functional'
                                } else {
                                    'Logging system has issues'
                                }
                            } catch {
                                $testResult.Success = $false
                                $testResult.Message = "Failed to test logging system: $($_.Exception.Message)"
                            }
                        }

                        'ParallelExecution-Complete' {
                            # Complete parallel execution testing
                            try {
                                Import-Module "$ProjectRoot/aither-core/modules/ParallelExecution" -Force -ErrorAction Stop

                                $parallelTests = @()

                                # Test basic parallel execution
                                $testData = @(1, 2, 3, 4, 5)
                                $results = Invoke-ParallelForEach -InputObject $testData -ScriptBlock {
                                    param($number)
                                    return $number * 2
                                } -ThrottleLimit 3

                                if ($results.Count -eq $testData.Count) {
                                    $parallelTests += '✅ Basic parallel execution works'
                                } else {
                                    $parallelTests += '❌ Basic parallel execution failed'
                                }

                                # Test error handling in parallel execution
                                try {
                                    $errorResults = Invoke-ParallelForEach -InputObject @(1, 'invalid', 3) -ScriptBlock {
                                        param($item)
                                        if ($item -is [string]) {
                                            throw 'Invalid input'
                                        }
                                        return $item * 2
                                    } -ThrottleLimit 2 -ErrorAction SilentlyContinue

                                    $parallelTests += '✅ Error handling in parallel execution works'
                                } catch {
                                    $parallelTests += '❌ Error handling in parallel execution failed'
                                }

                                $testResult.Details += $parallelTests
                                $failedTests = $parallelTests | Where-Object { $_ -like '❌*' }
                                $testResult.Success = ($failedTests.Count -eq 0)
                                $testResult.Message = if ($testResult.Success) {
                                    'Complete parallel execution functional'
                                } else {
                                    'Parallel execution has issues'
                                }
                            } catch {
                                $testResult.Success = $false
                                $testResult.Message = "Failed to test parallel execution: $($_.Exception.Message)"
                            }
                        }

                        'TestingFramework-Complete' {
                            # Complete testing framework validation
                            try {
                                Import-Module "$ProjectRoot/aither-core/modules/TestingFramework" -Force -ErrorAction Stop

                                $frameworkTests = @()

                                # Test basic framework functions
                                $functions = @('Invoke-BulletproofTest', 'Start-TestSuite', 'Write-TestLog')
                                foreach ($func in $functions) {
                                    if (Get-Command $func -ErrorAction SilentlyContinue) {
                                        $frameworkTests += "✅ $func available"
                                    } else {
                                        $frameworkTests += "❌ $func not available"
                                    }
                                }

                                # Test Pester integration
                                if (Get-Module Pester -ListAvailable) {
                                    $frameworkTests += '✅ Pester integration available'
                                } else {
                                    $frameworkTests += '⚠️ Pester not available'
                                }

                                $testResult.Details += $frameworkTests
                                $failedTests = $frameworkTests | Where-Object { $_ -like '❌*' }
                                $testResult.Success = ($failedTests.Count -eq 0)
                                $testResult.Message = 'TestingFramework functional'
                            } catch {
                                $testResult.Success = $false
                                $testResult.Message = "Failed to test framework: $($_.Exception.Message)"
                            }
                        }

                        'BackupManager-Core' {
                            # Test BackupManager module
                            try {
                                Import-Module "$ProjectRoot/aither-core/modules/BackupManager" -Force -ErrorAction Stop

                                $backupTests = @()

                                # Test basic functions exist
                                $functions = @('Invoke-BackupMaintenance', 'Invoke-BackupConsolidation', 'Get-BackupStatistics', 'Invoke-PermanentCleanup', 'New-BackupExclusion')
                                foreach ($func in $functions) {
                                    if (Get-Command $func -ErrorAction SilentlyContinue) {
                                        $backupTests += "✅ $func available"
                                    } else {
                                        $backupTests += "❌ $func not available"
                                    }
                                }

                                $testResult.Details += $backupTests
                                $failedTests = $backupTests | Where-Object { $_ -like '❌*' }
                                $testResult.Success = ($failedTests.Count -eq 0)
                                $testResult.Message = if ($testResult.Success) {
                                    'BackupManager core functions available'
                                } else {
                                    'BackupManager missing functions'
                                }
                            } catch {
                                $testResult.Success = $false
                                $testResult.Message = "BackupManager test failed: $($_.Exception.Message)"
                            }
                        }

                        'ScriptManager-Core' {
                            # Test ScriptManager module
                            try {
                                Import-Module "$ProjectRoot/aither-core/modules/ScriptManager" -Force -ErrorAction Stop

                                $scriptTests = @()

                                # Test basic functions exist
                                $functions = @('Get-ScriptRepository', 'Start-ScriptExecution', 'Get-ScriptTemplate')
                                foreach ($func in $functions) {
                                    if (Get-Command $func -ErrorAction SilentlyContinue) {
                                        $scriptTests += "✅ $func available"
                                    } else {
                                        $scriptTests += "❌ $func not available"
                                    }
                                }

                                $testResult.Details += $scriptTests
                                $failedTests = $scriptTests | Where-Object { $_ -like '❌*' }
                                $testResult.Success = ($failedTests.Count -eq 0)
                                $testResult.Message = if ($testResult.Success) {
                                    'ScriptManager core functions available'
                                } else {
                                    'ScriptManager missing functions'
                                }
                            } catch {
                                $testResult.Success = $false
                                $testResult.Message = "ScriptManager test failed: $($_.Exception.Message)"
                            }
                        }

                        'DevEnvironment-Core' {
                            # Test DevEnvironment module
                            try {
                                Import-Module "$ProjectRoot/aither-core/modules/DevEnvironment" -Force -ErrorAction Stop

                                $devTests = @()

                                # Test basic functions exist
                                $functions = @('Initialize-DevEnvironment', 'Test-DevEnvironment', 'Get-DevEnvironmentStatus')
                                foreach ($func in $functions) {
                                    if (Get-Command $func -ErrorAction SilentlyContinue) {
                                        $devTests += "✅ $func available"
                                    } else {
                                        $devTests += "❌ $func not available"
                                    }
                                }

                                # Test environment validation
                                try {
                                    $envStatus = Test-DevEnvironment
                                    if ($envStatus) {
                                        $devTests += '✅ Environment validation working'
                                    } else {
                                        $devTests += '⚠️ Environment validation issues'
                                    }
                                } catch {
                                    $devTests += '❌ Environment validation failed'
                                }

                                $testResult.Details += $devTests
                                $failedTests = $devTests | Where-Object { $_ -like '❌*' }
                                $testResult.Success = ($failedTests.Count -eq 0)
                                $testResult.Message = if ($testResult.Success) {
                                    'DevEnvironment functional'
                                } else {
                                    'DevEnvironment has issues'
                                }
                            } catch {
                                $testResult.Success = $false
                                $testResult.Message = "DevEnvironment test failed: $($_.Exception.Message)"
                            }
                        }

                        'FileSystem-Complete' {
                            # Complete file system testing
                            $fsTests = @()
                            $criticalPaths = @(
                                "$ProjectRoot/aither-core",
                                "$ProjectRoot/aither-core/modules",
                                "$ProjectRoot/tests",
                                "$ProjectRoot/configs",
                                "$ProjectRoot/docs",
                                "$ProjectRoot/logs"
                            )

                            foreach ($path in $criticalPaths) {
                                if (Test-Path $path) {
                                    # Test read access
                                    try {
                                        $items = Get-ChildItem $path -ErrorAction Stop | Select-Object -First 1
                                        $fsTests += "✅ $path - Read access OK"

                                        # Test write access (where appropriate)
                                        if ($path -like '*logs*' -or $path -like '*tests*') {
                                            try {
                                                $testFile = Join-Path $path 'test-write-access.tmp'
                                                'test' | Out-File $testFile -ErrorAction Stop
                                                Remove-Item $testFile -ErrorAction SilentlyContinue
                                                $fsTests += "✅ $path - Write access OK"
                                            } catch {
                                                $fsTests += "⚠️ $path - Limited write access"
                                            }
                                        }
                                    } catch {
                                        $fsTests += "❌ $path - Access denied: $($_.Exception.Message)"
                                    }
                                } else {
                                    $fsTests += "❌ $path - Path not found"
                                }
                            }

                            $testResult.Details += $fsTests
                            $failedTests = $fsTests | Where-Object { $_ -like '❌*' }
                            $testResult.Success = ($failedTests.Count -eq 0)
                            $testResult.Message = if ($testResult.Success) {
                                'Complete file system access validated'
                            } else {
                                'File system access issues detected'
                            }
                        }

                        'CrossPlatform-Basic' {
                            # Basic cross-platform compatibility testing
                            $platformTests = @()

                            # Test platform detection
                            $platform = $PSVersionTable.Platform
                            $platformTests += "✅ Platform detected: $platform"

                            # Test path handling
                            $testPath = Join-Path $ProjectRoot 'aither-core' 'modules'
                            if (Test-Path $testPath) {
                                $platformTests += '✅ Cross-platform path handling works'
                            } else {
                                $platformTests += '❌ Cross-platform path handling failed'
                            }

                            # Test PowerShell version compatibility
                            $psVersion = $PSVersionTable.PSVersion
                            if ($psVersion.Major -ge 7) {
                                $platformTests += "✅ PowerShell version compatible: $psVersion"
                            } else {
                                $platformTests += "❌ PowerShell version incompatible: $psVersion"
                            }

                            # Test environment variables
                            if ($env:PROJECT_ROOT) {
                                $platformTests += '✅ Environment variables set'
                            } else {
                                $platformTests += '⚠️ PROJECT_ROOT not set'
                            }

                            $testResult.Details += $platformTests
                            $failedTests = $platformTests | Where-Object { $_ -like '❌*' }
                            $testResult.Success = ($failedTests.Count -eq 0)
                            $testResult.Message = if ($testResult.Success) {
                                'Cross-platform compatibility validated'
                            } else {
                                'Cross-platform compatibility issues'
                            }
                        }

                        'Performance-Complete' {
                            # Complete performance testing
                            $perfTests = @()
                            $startPerfTime = Get-Date

                            # Test module loading performance
                            $moduleLoadStart = Get-Date
                            try {
                                Import-Module "$ProjectRoot/aither-core/modules/Logging" -Force
                                $moduleLoadTime = ((Get-Date) - $moduleLoadStart).TotalMilliseconds

                                if ($moduleLoadTime -lt 5000) {
                                    # 5 seconds max
                                    $perfTests += "✅ Module loading performance: $($moduleLoadTime.ToString('F0'))ms"
                                } else {
                                    $perfTests += "❌ Module loading too slow: $($moduleLoadTime.ToString('F0'))ms"
                                }
                            } catch {
                                $perfTests += '❌ Module loading failed'
                            }

                            # Test core runner performance
                            $coreRunnerPath = Join-Path $ProjectRoot 'aither-core/aither-core.ps1'
                            $coreRunnerStart = Get-Date
                            try {
                                $process = Start-Process -FilePath 'pwsh' -ArgumentList @(
                                    '-File', "`"$coreRunnerPath`"",
                                    '-NonInteractive', '-WhatIf', '-Verbosity', 'silent'
                                ) -NoNewWindow -Wait -PassThru

                                $coreRunnerTime = ((Get-Date) - $coreRunnerStart).TotalMilliseconds

                                if ($process.ExitCode -eq 0 -and $coreRunnerTime -lt 30000) {
                                    # 30 seconds max
                                    $perfTests += "✅ Core runner performance: $($coreRunnerTime.ToString('F0'))ms"
                                } else {
                                    $perfTests += "❌ Core runner performance issues: $($coreRunnerTime.ToString('F0'))ms"
                                }
                            } catch {
                                $perfTests += '❌ Core runner performance test failed'
                            }

                            # Test memory usage (basic check)
                            $memoryBefore = [GC]::GetTotalMemory($false)
                            Start-Sleep -Milliseconds 100
                            $memoryAfter = [GC]::GetTotalMemory($true)
                            $memoryIncrease = ($memoryAfter - $memoryBefore) / 1MB

                            if ($memoryIncrease -lt 50) {
                                # 50MB max increase
                                $perfTests += "✅ Memory usage acceptable: $($memoryIncrease.ToString('F1'))MB"
                            } else {
                                $perfTests += "⚠️ High memory usage: $($memoryIncrease.ToString('F1'))MB"
                            }

                            $testResult.Details += $perfTests
                            $failedTests = $perfTests | Where-Object { $_ -like '❌*' }
                            $testResult.Success = ($failedTests.Count -eq 0)
                            $testResult.Message = if ($testResult.Success) {
                                'Complete performance validation passed'
                            } else {
                                'Performance issues detected'
                            }
                        }

                        'Integration-Core' {
                            # Core integration testing between modules
                            $integrationTests = @()

                            try {
                                # Test Logging + ParallelExecution integration
                                Import-Module "$ProjectRoot/aither-core/modules/Logging" -Force
                                Import-Module "$ProjectRoot/aither-core/modules/ParallelExecution" -Force

                                $testData = @(1, 2, 3)
                                $results = Invoke-ParallelForEach -InputObject $testData -ScriptBlock {
                                    param($number)
                                    Write-CustomLog -Level 'INFO' -Message "Processing number: $number"
                                    return $number * 2
                                } -ThrottleLimit 2

                                if ($results.Count -eq $testData.Count) {
                                    $integrationTests += '✅ Logging + ParallelExecution integration works'
                                } else {
                                    $integrationTests += '❌ Logging + ParallelExecution integration failed'
                                }

                                # Test TestingFramework integration
                                if (Get-Module TestingFramework -ListAvailable) {
                                    Import-Module "$ProjectRoot/aither-core/modules/TestingFramework" -Force
                                    $integrationTests += '✅ TestingFramework integration available'
                                } else {
                                    $integrationTests += '⚠️ TestingFramework integration limited'
                                }

                                $testResult.Details += $integrationTests
                                $failedTests = $integrationTests | Where-Object { $_ -like '❌*' }
                                $testResult.Success = ($failedTests.Count -eq 0)
                                $testResult.Message = if ($testResult.Success) {
                                    'Core integration working'
                                } else {
                                    'Integration issues detected'
                                }
                            } catch {
                                $testResult.Success = $false
                                $testResult.Message = "Integration test failed: $($_.Exception.Message)"
                            }
                        }

                        'Launcher-Functionality' {
                            # Test all launcher scripts for basic functionality
                            $launcherTestPath = Join-Path $ProjectRoot 'tests/Test-LauncherFunctionality.ps1'

                            if (Test-Path $launcherTestPath) {
                                try {
                                    $tempDir = if ($env:TEMP) { $env:TEMP } elseif (Test-Path '/tmp') { '/tmp' } else { $ProjectRoot }
                                    $tempLog = Join-Path $tempDir 'bulletproof-launcher.log'
                                    $tempErr = Join-Path $tempDir 'bulletproof-launcher-error.log'

                                    $process = Start-Process -FilePath 'pwsh' -ArgumentList @(
                                        '-File', "`"$launcherTestPath`""
                                    ) -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tempLog -RedirectStandardError $tempErr

                                    $testResult.Success = ($process.ExitCode -eq 0)

                                    if (Test-Path $tempLog) {
                                        $output = Get-Content $tempLog -Raw
                                        if ($output -match 'All launcher tests passed') {
                                            $testResult.Message = 'All launcher scripts validated successfully'
                                            $testResult.Details += 'Batch and PowerShell launchers syntax verified'
                                            $testResult.Details += 'Path resolution logic validated'
                                            $testResult.Details += 'Help parameters functional'
                                        } else {
                                            $testResult.Success = $false
                                            $testResult.Message = 'Launcher validation output unexpected'
                                        }
                                    }

                                    if (-not $testResult.Success -and (Test-Path $tempErr)) {
                                        $errorOutput = Get-Content $tempErr -Raw
                                        $testResult.Message += " - Error: $errorOutput"
                                    }
                                } catch {
                                    $testResult.Success = $false
                                    $testResult.Message = "Launcher test execution failed: $($_.Exception.Message)"
                                }
                            } else {
                                $testResult.Success = $false
                                $testResult.Message = "Launcher test script not found: $launcherTestPath"
                            }
                        }

                        default {
                            $testResult.Success = $false
                            $testResult.Message = "Test '$TestName' not implemented"
                        }
                    }
                } catch {
                    $testResult.Success = $false
                    $testResult.Message = "Test failed with exception: $($_.Exception.Message)"
                    $testResult.Details += "Exception: $($_.Exception.ToString())"
                }

                $testResult.Duration = ((Get-Date) - $testResult.StartTime).TotalMilliseconds
                return $testResult
            }

            # Execute the test
            Invoke-BulletproofTest -TestName $TestDefinition.Name -Type $TestDefinition.Type -Critical $TestDefinition.Critical

        } -ArgumentList $test, $projectRoot

        $testJobs += @{
            Job       = $job
            Test      = $test
            StartTime = Get-Date
        }

        Write-BulletproofLog "Started: $($test.Name) ($($test.Type))" -Level INFO

        # Respect parallel job limit
        if ($testJobs.Count -ge $MaxParallelJobs) {
            # Wait for some jobs to complete
            $completedJobs = $testJobs | Where-Object { $_.Job.State -eq 'Completed' }
            if ($completedJobs.Count -eq 0) {
                Start-Sleep -Milliseconds 500
            }
        }
    }

    Write-BulletproofLog 'All tests started, waiting for completion...' -Level INFO

    # Wait for all jobs to complete with timeout
    $timeout = $selectedSuite.MaxDuration
    $startWaitTime = Get-Date

    while ($testJobs | Where-Object { $_.Job.State -eq 'Running' }) {
        $elapsed = ((Get-Date) - $startWaitTime).TotalSeconds
        if ($elapsed -gt $timeout) {
            Write-BulletproofLog "Tests timed out after $timeout seconds!" -Level ERROR
            break
        }

        Start-Sleep -Milliseconds 500

        # Check for completed jobs and fail fast if needed
        $completedJobs = $testJobs | Where-Object { $_.Job.State -eq 'Completed' }
        foreach ($completedJob in $completedJobs) {
            if ($completedJob.Job.Id -notin $allResults.JobId) {
                try {
                    $result = Receive-Job -Job $completedJob.Job -ErrorAction Stop
                    $result | Add-Member -NotePropertyName 'JobId' -NotePropertyValue $completedJob.Job.Id
                    $allResults += $result

                    $status = if ($result.Success) { '✅' } else { '❌' }
                    $duration = [math]::Round($result.Duration)
                    Write-BulletproofLog "$status $($result.Name): $($result.Message) (${duration}ms)" -Level $(if ($result.Success) { 'SUCCESS' } else { 'ERROR' })

                    # Check for critical failures
                    if (-not $result.Success -and $completedJob.Test.Critical) {
                        $criticalFailures += $result
                        if ($FailFast) {
                            Write-BulletproofLog '🚨 Critical test failed, stopping execution (FailFast enabled)' -Level ERROR
                            break
                        }
                    }
                } catch {
                    Write-BulletproofLog "❌ Failed to get result for $($completedJob.Test.Name): $($_.Exception.Message)" -Level ERROR
                }
            }
        }

        if ($FailFast -and $criticalFailures.Count -gt 0) {
            break
        }
    }

} finally {
    # Clean up all jobs
    $testJobs | ForEach-Object {
        try {
            Remove-Job -Job $_.Job -Force -ErrorAction SilentlyContinue
        } catch {
            # Ignore cleanup errors
        }
    }
}

$endTime = Get-Date
$totalDuration = ($endTime - $startTime).TotalSeconds

# Analyze results
$totalTests = $selectedSuite.Tests.Count
$completedTests = $allResults.Count
$passedTests = ($allResults | Where-Object { $_.Success }).Count
$failedTests = $completedTests - $passedTests
$criticalFailureCount = $criticalFailures.Count
$nonCriticalFailures = ($allResults | Where-Object { -not $_.Success -and -not $_.Critical }).Count

$successRate = if ($completedTests -gt 0) { ($passedTests / $completedTests) * 100 } else { 0 }

# Determine bulletproof status
$isBulletproof = ($criticalFailureCount -eq 0 -and $successRate -ge 95)

Write-BulletproofLog '═══════════════════════════════════════════' -Level INFO
Write-BulletproofLog '🎯 BULLETPROOF VALIDATION RESULTS' -Level SUCCESS
Write-BulletproofLog '═══════════════════════════════════════════' -Level INFO
Write-BulletproofLog "Validation Level: $ValidationLevel" -Level INFO
Write-BulletproofLog "Total Duration: $([math]::Round($totalDuration, 1)) seconds" -Level INFO
Write-BulletproofLog "Tests Completed: $completedTests/$totalTests" -Level INFO
Write-BulletproofLog "Tests Passed: $passedTests" -Level $(if ($passedTests -eq $completedTests) { 'SUCCESS' } else { 'WARN' })
Write-BulletproofLog "Tests Failed: $failedTests" -Level $(if ($failedTests -eq 0) { 'SUCCESS' } else { 'ERROR' })
Write-BulletproofLog "Critical Failures: $criticalFailureCount" -Level $(if ($criticalFailureCount -eq 0) { 'SUCCESS' } else { 'ERROR' })
Write-BulletproofLog "Success Rate: $([math]::Round($successRate, 1))%" -Level $(if ($successRate -ge 95) { 'SUCCESS' } elseif ($successRate -ge 80) { 'WARN' } else { 'ERROR' })

# Show failed tests
if ($failedTests -gt 0) {
    Write-BulletproofLog '═══ FAILED TESTS ═══' -Level ERROR
    $allResults | Where-Object { -not $_.Success } | ForEach-Object {
        $criticalTag = if ($_.Critical) { '[CRITICAL]' } else { '[NON-CRITICAL]' }
        Write-BulletproofLog "$criticalTag $($_.Name): $($_.Message)" -Level $(if ($_.Critical) { 'ERROR' } else { 'ERROR' })
        if ($_.Details.Count -gt 0) {
            $_.Details | ForEach-Object { Write-BulletproofLog "  $_" -Level ERROR }
        }
    }
}

# Final status
Write-BulletproofLog '═══════════════════════════════════════════' -Level INFO
if ($isBulletproof) {
    Write-BulletproofLog '🎉 BULLETPROOF STATUS: APPROVED ✅' -Level SUCCESS
    Write-BulletproofLog 'System is healthy and ready for production deployment' -Level SUCCESS
} else {
    Write-BulletproofLog '🚨 BULLETPROOF STATUS: REJECTED ❌' -Level ERROR
    if ($criticalFailureCount -gt 0) {
        Write-BulletproofLog 'Critical systems are failing - deployment not recommended' -Level ERROR
    } else {
        Write-BulletproofLog 'Non-critical issues detected - review required' -Level WARN
    }
}
Write-BulletproofLog '═══════════════════════════════════════════' -Level INFO

# Generate output for CI/CD
$outputData = @{
    ValidationLevel        = $ValidationLevel
    StartTime              = $startTime
    EndTime                = $endTime
    Duration               = $totalDuration
    TotalTests             = $totalTests
    CompletedTests         = $completedTests
    PassedTests            = $passedTests
    FailedTests            = $failedTests
    CriticalFailureCount   = $criticalFailureCount
    NonCriticalFailures    = $nonCriticalFailures
    SuccessRate            = $successRate
    Bulletproof            = $isBulletproof
    Status                 = if ($isBulletproof) { 'APPROVED' } else { 'REJECTED' }
    Results                = $allResults
    CriticalFailureDetails = $criticalFailures
}

if ($CI -or $OutputPath) {
    $outputFile = if ($OutputPath) { $OutputPath } else { "$projectRoot/tests/results/bulletproof-validation.json" }
    $outputData | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputFile -Encoding UTF8
    Write-BulletproofLog "📄 Results saved to: $outputFile" -Level INFO
}

# Set exit code
$exitCode = if ($isBulletproof) { 0 } else { 1 }
Write-BulletproofLog "Exit Code: $exitCode" -Level INFO

exit $exitCode

# LAUNCHER TESTS - CRITICAL FOR USER EXPERIENCE

# Include launcher functionality validation in all test runs
