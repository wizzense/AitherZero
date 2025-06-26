#!/usr/bin/env pwsh
<#
.SYNOPSIS
<<<<<<< HEAD
    Tests for launcher functionality
.DESCRIPTION
    This test validates that the main launcher and core script work correctly.
=======
    Tests for launcher functionality and basic execution paths
.DESCRIPTION
    This test validates that all launcher scripts work correctly and can find their dependencies.
    These tests should catch basic functionality issues before they reach users.
>>>>>>> origin/main
#>

[CmdletBinding()]
param()

<<<<<<< HEAD
=======
# Import the TestingFramework if available
>>>>>>> origin/main
$ErrorActionPreference = 'Stop'

# Initialize test environment
$TestResults = @{
    Passed = 0
    Failed = 0
    Errors = @()
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
<<<<<<< HEAD
        [string]$ErrorMsg = ''
=======
        [string]$ErrorMessage = ""
>>>>>>> origin/main
    )

    if ($Passed) {
        Write-Host "✅ $TestName" -ForegroundColor Green
        $script:TestResults.Passed++
    } else {
        Write-Host "❌ $TestName" -ForegroundColor Red
<<<<<<< HEAD
        if ($ErrorMsg) {
            Write-Host "   Error: $ErrorMsg" -ForegroundColor Yellow
        }
        $script:TestResults.Failed++
        $script:TestResults.Errors += "$TestName`: $ErrorMsg"
=======
        if ($ErrorMessage) {
            Write-Host "   Error: $ErrorMessage" -ForegroundColor Yellow
        }
        $script:TestResults.Failed++
        $script:TestResults.Errors += "$TestName`: $ErrorMessage"
    }
}

function Test-BatchFileSyntax {
    param([string]$BatFilePath)

    try {
        # Test basic batch file syntax by parsing it
        $content = Get-Content $BatFilePath -Raw

        # Check for common syntax errors
        $errors = @()

        # Check for unmatched parentheses in if statements
        $ifBlocks = $content | Select-String -Pattern 'if\s+.*\s+\(' -AllMatches
        $endParens = $content | Select-String -Pattern '^\s*\)' -AllMatches

        # Check for else without proper if structure
        if ($content -match 'else was unexpected') {
            $errors += "Contains 'else was unexpected' pattern"
        }

        # Check for basic batch syntax patterns
        if ($content -match '(?m)^else\s*$' -and $content -notmatch '(?m)^\s*\)\s+else\s+\(') {
            $errors += "Standalone 'else' statement found - likely syntax error"
        }

        # Simulate execution by checking the structure
        $lines = $content -split "`n"
        $inIfBlock = $false
        $parenLevel = 0

        foreach ($line in $lines) {
            $line = $line.Trim()
            if ($line -match '^if\s+.*\s+\(') {
                $inIfBlock = $true
                $parenLevel++
            }
            elseif ($line -eq ')') {
                $parenLevel--
                if ($parenLevel -eq 0) {
                    $inIfBlock = $false
                }
            }
            elseif ($line -match '^else\s+\(' -and -not $inIfBlock) {
                $errors += "else block without matching if statement at line: $line"
            }
        }

        if ($errors.Count -eq 0) {
            return @{ Success = $true; Error = "" }
        } else {
            return @{ Success = $false; Error = ($errors -join "; ") }
        }

    } catch {
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Test-PowerShellSyntax {
    param([string]$PS1FilePath)

    try {
        # Parse the PowerShell file for syntax errors
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $PS1FilePath -Raw), [ref]$null)
        return @{ Success = $true; Error = "" }
    } catch {
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Test-LauncherPathResolution {
    param([string]$LauncherPath)

    try {
        # Test the path resolution logic without actually executing
        $content = Get-Content $LauncherPath -Raw

        # Check if the script has proper path resolution
        if ($content -match 'PSScriptRoot') {
            # Look for the core script resolution patterns
            if ($content -match 'aither-core\.ps1' -or $content -match 'aither-core/aither-core\.ps1') {
                return @{ Success = $true; Error = "" }
            } else {
                return @{ Success = $false; Error = "No core script path resolution found" }
            }
        } else {
            return @{ Success = $false; Error = "No PSScriptRoot-based path resolution found" }
        }
    } catch {
        return @{ Success = $false; Error = $_.Exception.Message }
>>>>>>> origin/main
    }
}

function Test-LauncherHelp {
    param([string]$LauncherPath)

    try {
<<<<<<< HEAD
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = "pwsh"
        $processInfo.Arguments = "-ExecutionPolicy Bypass -File `"$LauncherPath`" -Help"
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $process.Start() | Out-Null

        $finished = $process.WaitForExit(5000)

        if (-not $finished) {
            $process.Kill()
            return @{ Success = $false; ErrorMsg = "Help command timed out" }
        }

        $output = $process.StandardOutput.ReadToEnd()
        $exitCode = $process.ExitCode

        if ($exitCode -eq 0 -and $output -match 'Usage|Help|Options|AitherZero') {
            return @{ Success = $true; ErrorMsg = '' }
        } else {
            return @{ Success = $false; ErrorMsg = "Help output failed. Exit code: $exitCode" }
        }
    } catch {
        return @{ Success = $false; ErrorMsg = $_.Exception.Message }
    }
}

function Test-ParameterMapping {
    param([string]$LauncherPath)

    try {
        $content = Get-Content $LauncherPath -Raw

        # Check for hashtable initialization
        if ($content -match '\$coreArgs\s*=\s*@\{\}') {
            return $true
        } else {
            return $false
        }
    } catch {
        return $false
=======
        # Test that -Help parameter works without errors
        $output = & pwsh -ExecutionPolicy Bypass -File $LauncherPath -Help 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0 -and $output -match 'Usage|Help|Options') {
            return @{ Success = $true; Error = "" }
        } else {
            return @{ Success = $false; Error = "Help output failed or didn't contain expected content. Exit code: $exitCode" }
        }
    } catch {
        return @{ Success = $false; Error = $_.Exception.Message }
>>>>>>> origin/main
    }
}

# Main test execution
<<<<<<< HEAD
Write-Host '🧪 Launcher Tests' -ForegroundColor Cyan
Write-Host '=================' -ForegroundColor Cyan

$projectRoot = Split-Path $PSScriptRoot -Parent
$mainLauncher = Join-Path $projectRoot 'templates/launchers/Start-AitherZero.ps1'
$coreScript = Join-Path $projectRoot 'aither-core/aither-core.ps1'

# Test 1: File exists
$existsLauncher = Test-Path $mainLauncher
Write-TestResult "Main launcher exists" $existsLauncher

$existsCoreScript = Test-Path $coreScript
Write-TestResult "Core script exists" $existsCoreScript

if ($existsLauncher) {
    # Test 2: Help works
    $helpResult = Test-LauncherHelp $mainLauncher
    Write-TestResult "Help parameter works" $helpResult.Success $helpResult.ErrorMsg

    # Test 3: Parameter mapping
    $mappingResult = Test-ParameterMapping $mainLauncher
    Write-TestResult "Parameter mapping correct" $mappingResult
}

# Results
Write-Host "`n📊 Results:" -ForegroundColor Cyan
=======
Write-Host "🧪 Running Launcher Functionality Tests" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# Find launcher files
$projectRoot = Split-Path $PSScriptRoot -Parent
$launcherTemplates = @{
    "BatchLauncher" = Join-Path $projectRoot "templates/launchers/AitherZero.bat"
    "PowerShellLauncher" = Join-Path $projectRoot "templates/launchers/Start-AitherZero.ps1"
}

# Also check for fixed launchers in root
$rootLaunchers = @{
    "FixedBatchLauncher" = Join-Path $projectRoot "AitherZero-Fixed.bat"
    "FixedPowerShellLauncher" = Join-Path $projectRoot "Start-AitherZero-Fixed.ps1"
    "HotfixLauncher" = Join-Path $projectRoot "HOTFIX-Launcher.ps1"
}

# Test 1: File Existence
Write-Host "📂 Testing launcher file existence..." -ForegroundColor Yellow

foreach ($launcher in $launcherTemplates.GetEnumerator()) {
    $exists = Test-Path $launcher.Value
    Write-TestResult "Template $($launcher.Key) exists" $exists $(if (-not $exists) { "File not found: $($launcher.Value)" } else { "" })
}

foreach ($launcher in $rootLaunchers.GetEnumerator()) {
    $exists = Test-Path $launcher.Value
    if ($exists) {
        Write-TestResult "Root $($launcher.Key) exists" $true
    }
}

# Test 2: Syntax Validation
Write-Host "`n🔍 Testing syntax validation..." -ForegroundColor Yellow

foreach ($launcher in $launcherTemplates.GetEnumerator()) {
    if (Test-Path $launcher.Value) {
        if ($launcher.Value -like "*.bat") {
            $result = Test-BatchFileSyntax $launcher.Value
            Write-TestResult "$($launcher.Key) batch syntax" $result.Success $result.Error
        } elseif ($launcher.Value -like "*.ps1") {
            $result = Test-PowerShellSyntax $launcher.Value
            Write-TestResult "$($launcher.Key) PowerShell syntax" $result.Success $result.Error
        }
    }
}

foreach ($launcher in $rootLaunchers.GetEnumerator()) {
    if (Test-Path $launcher.Value) {
        if ($launcher.Value -like "*.bat") {
            $result = Test-BatchFileSyntax $launcher.Value
            Write-TestResult "Root $($launcher.Key) batch syntax" $result.Success $result.Error
        } elseif ($launcher.Value -like "*.ps1") {
            $result = Test-PowerShellSyntax $launcher.Value
            Write-TestResult "Root $($launcher.Key) PowerShell syntax" $result.Success $result.Error
        }
    }
}

# Test 3: Path Resolution Logic
Write-Host "`n🗂️ Testing path resolution logic..." -ForegroundColor Yellow

foreach ($launcher in $launcherTemplates.GetEnumerator()) {
    if ((Test-Path $launcher.Value) -and $launcher.Value -like "*.ps1") {
        $result = Test-LauncherPathResolution $launcher.Value
        Write-TestResult "$($launcher.Key) path resolution" $result.Success $result.Error
    }
}

# Test 4: Help Parameter Functionality
Write-Host "`n❓ Testing help parameter functionality..." -ForegroundColor Yellow

foreach ($launcher in $launcherTemplates.GetEnumerator()) {
    if ((Test-Path $launcher.Value) -and $launcher.Value -like "*.ps1") {
        $result = Test-LauncherHelp $launcher.Value
        Write-TestResult "$($launcher.Key) help parameter" $result.Success $result.Error
    }
}

foreach ($launcher in $rootLaunchers.GetEnumerator()) {
    if ((Test-Path $launcher.Value) -and $launcher.Value -like "*.ps1") {
        $result = Test-LauncherHelp $launcher.Value
        Write-TestResult "Root $($launcher.Key) help parameter" $result.Success $result.Error
    }
}

# Test 5: Core Dependencies
Write-Host "`n🔧 Testing core dependencies..." -ForegroundColor Yellow

$coreScript = Join-Path $projectRoot "aither-core/aither-core.ps1"
$coreScriptExists = Test-Path $coreScript
Write-TestResult "Core script exists (aither-core.ps1)" $coreScriptExists $(if (-not $coreScriptExists) { "File not found: $coreScript" } else { "" })

$modulesDir = Join-Path $projectRoot "aither-core/modules"
$modulesDirExists = Test-Path $modulesDir
Write-TestResult "Modules directory exists" $modulesDirExists $(if (-not $modulesDirExists) { "Directory not found: $modulesDir" } else { "" })

# Final Results
Write-Host "`n📊 Test Results Summary" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan
>>>>>>> origin/main
Write-Host "✅ Passed: $($TestResults.Passed)" -ForegroundColor Green
Write-Host "❌ Failed: $($TestResults.Failed)" -ForegroundColor Red

if ($TestResults.Failed -gt 0) {
<<<<<<< HEAD
    exit 1
} else {
    Write-Host "`n🎉 All tests passed!" -ForegroundColor Green
    Write-Host "All launcher tests passed" -ForegroundColor Green
=======
    Write-Host "`n🚨 Failed Tests:" -ForegroundColor Red
    foreach ($error in $TestResults.Errors) {
        Write-Host "  - $error" -ForegroundColor Yellow
    }
    Write-Host "`n💡 These issues should be fixed before release!" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "`n🎉 All launcher tests passed!" -ForegroundColor Green
>>>>>>> origin/main
    exit 0
}
