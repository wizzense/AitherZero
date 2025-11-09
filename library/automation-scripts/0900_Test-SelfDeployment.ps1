#Requires -Version 7.0

<#
.SYNOPSIS
    COMPREHENSIVE AitherZero self-deployment validation test
.DESCRIPTION
    Validates that AitherZero can fully deploy and set up itself using its own
    automation pipeline with COMPREHENSIVE testing (no quick modes).
    
    This test performs:
    - Full repository clone
    - Complete bootstrap with Full profile
    - Comprehensive validation playbook with all scripts
    - Full unit test suite with code coverage
    - Complete static code analysis
    - Full deployment report generation

    Exit Codes:
    0   - Self-deployment test passed
    1   - Test failed
    2   - Setup error

.NOTES
    Stage: Validation
    Order: 0900
    Dependencies: All
    Tags: self-deployment, validation, ci-cd, end-to-end, comprehensive
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ProjectPath = ($PSScriptRoot | Split-Path -Parent),
    [string]$TestPath = (Join-Path ([System.IO.Path]::GetTempPath()) "aitherzero-self-deploy-test"),
    [switch]$CleanupOnSuccess,
    [string]$Branch = ""  # Auto-detect from environment or use current branch
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Auto-detect branch if not specified
if ([string]::IsNullOrEmpty($Branch)) {
    # In CI, use GITHUB_HEAD_REF (PR branch) or GITHUB_REF_NAME (branch/tag)
    if ($env:GITHUB_HEAD_REF) {
        $Branch = $env:GITHUB_HEAD_REF
        Write-Verbose "Detected PR branch from GITHUB_HEAD_REF: $Branch"
    } elseif ($env:GITHUB_REF_NAME) {
        $Branch = $env:GITHUB_REF_NAME
        Write-Verbose "Detected branch from GITHUB_REF_NAME: $Branch"
    } else {
        # Try to get current branch from git
        try {
            Push-Location $ProjectPath
            $gitBranch = git rev-parse --abbrev-ref HEAD 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($gitBranch)) {
                $Branch = $gitBranch
                Write-Verbose "Detected branch from git: $Branch"
            } else {
                $Branch = "main"
                Write-Verbose "Falling back to default branch: $Branch"
            }
        } catch {
            $Branch = "main"
            Write-Verbose "Error detecting branch, using default: $Branch"
        } finally {
            Pop-Location
        }
    }
}

# Script metadata
$scriptMetadata = @{
    Stage = 'Validation'
    Order = 0900
    Dependencies = @('All')
    Tags = @('self-deployment', 'validation', 'ci-cd', 'end-to-end', 'comprehensive')
    RequiresAdmin = $false
    SupportsWhatIf = $true
}

# Import required modules
$loggingModule = Join-Path $ProjectPath "aithercore/utilities/Logging.psm1"
if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force
}

$orchestrationModule = Join-Path $ProjectPath "aithercore/automation/OrchestrationEngine.psm1"
if (Test-Path $orchestrationModule) {
    Import-Module $orchestrationModule -Force
}

function Write-ScriptLog {
    param(
        [string]$Level = 'Information',
        [string]$Message,
        [hashtable]$Data = @{}
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "0900_Test-SelfDeployment" -Data $Data
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $color = @{
            'Error' = 'Red'
            'Warning' = 'Yellow'
            'Information' = 'Cyan'
            'Success' = 'Green'
        }[$Level]
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    }
}

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Check prerequisites for self-deployment test
    #>
    Write-ScriptLog -Message "Checking prerequisites for self-deployment test"

    $prerequisites = @{
        Git = Get-Command git -ErrorAction SilentlyContinue
        PowerShell = $PSVersionTable.PSVersion -ge [Version]"7.0"
        Internet = $false
    }

    # Test internet connectivity
    try {
        $null = Invoke-WebRequest -Uri "https://api.github.com" -TimeoutSec 5 -UseBasicParsing
        $prerequisites.Internet = $true
    } catch {
        Write-ScriptLog -Level Warning -Message "Internet connectivity test failed"
    }

    $passed = $prerequisites.Git -and $prerequisites.PowerShell -and $prerequisites.Internet

    Write-ScriptLog -Message "Prerequisites check completed" -Data $prerequisites

    if (-not $passed) {
        $missing = @()
        if (-not $prerequisites.Git) { $missing += "Git" }
        if (-not $prerequisites.PowerShell) { $missing += "PowerShell 7+" }
        if (-not $prerequisites.Internet) { $missing += "Internet connectivity" }

        throw "Missing prerequisites: $($missing -join ', ')"
    }

    return $prerequisites
}

function New-CleanTestEnvironment {
    <#
    .SYNOPSIS
        Create a clean test environment
    #>
    Write-ScriptLog -Message "Creating clean test environment at: $TestPath"

    if (Test-Path $TestPath) {
        Write-ScriptLog -Message "Removing existing test directory"
        Remove-Item -Path $TestPath -Recurse -Force
    }

    if ($PSCmdlet.ShouldProcess($TestPath, "Create test directory")) {
        New-Item -ItemType Directory -Path $TestPath -Force | Out-Null
    }

    Write-ScriptLog -Message "Clean test environment created"
}

function Invoke-SelfClone {
    <#
    .SYNOPSIS
        Clone the repository for self-deployment test
    #>
    Write-ScriptLog -Message "Cloning AitherZero repository for self-deployment test"

    $repoUrl = "https://github.com/wizzense/AitherZero.git"
    $clonePath = Join-Path $TestPath "AitherZero"

    if ($PSCmdlet.ShouldProcess($repoUrl, "Clone repository")) {
        try {
            Push-Location $TestPath

            # Clone the repository
            Write-ScriptLog -Message "Executing: git clone $repoUrl --branch $Branch --depth 1"
            $gitOutput = git clone $repoUrl --branch $Branch --depth 1 2>&1

            if ($LASTEXITCODE -ne 0) {
                throw "Git clone failed: $gitOutput"
            }

            Write-ScriptLog -Message "Repository cloned successfully"

            # Verify clone
            if (-not (Test-Path $clonePath)) {
                throw "Clone directory not found: $clonePath"
            }

            $files = @(Get-ChildItem -Path $clonePath -File -Recurse)
            Write-ScriptLog -Message "Clone verification: $($files.Count) files found"

            return $clonePath

        } finally {
            Pop-Location
        }
    }

    return $clonePath
}

function Test-BootstrapProcess {
    <#
    .SYNOPSIS
        Test the bootstrap process
    #>
    param([string]$ClonePath)

    Write-ScriptLog -Message "Testing bootstrap process"

    if ($PSCmdlet.ShouldProcess($ClonePath, "Run bootstrap")) {
        try {
            Push-Location $ClonePath

            # Test bootstrap script exists
            $bootstrapScript = "./bootstrap.ps1"
            if (-not (Test-Path $bootstrapScript)) {
                throw "Bootstrap script not found: $bootstrapScript"
            }

            # Run bootstrap in non-interactive mode with FULL profile for comprehensive testing
            Write-ScriptLog -Message "Running FULL bootstrap process (comprehensive mode, may take 5-10 minutes)..."
            $startTime = Get-Date

            # Run bootstrap and capture output for better error reporting
            # Don't use Out-Null to avoid blocking - capture to variable instead
            # Use Full profile for comprehensive testing
            $bootstrapOutput = & pwsh -c "$bootstrapScript -Mode New -InstallProfile Full -NonInteractive" 2>&1
            $bootstrapExitCode = $LASTEXITCODE

            $duration = (Get-Date) - $startTime
            
            if ($bootstrapExitCode -ne 0) {
                Write-ScriptLog -Level Error -Message "Bootstrap process failed after $($duration.TotalSeconds.ToString('F1'))s with exit code: $bootstrapExitCode"
                # Log last few lines of output for debugging
                if ($bootstrapOutput) {
                    $lastLines = ($bootstrapOutput | Select-Object -Last 10) -join "`n"
                    Write-ScriptLog -Level Error -Message "Bootstrap output (last 10 lines):`n$lastLines"
                }
                throw "Bootstrap process failed with exit code: $bootstrapExitCode"
            }

            Write-ScriptLog -Level Information -Message "Bootstrap completed successfully in $($duration.TotalSeconds.ToString('F1')) seconds"

            return $true

        } finally {
            Pop-Location
        }
    } else {
        # In WhatIf mode, return false (simulation)
        return $false
    }
}

function Invoke-SelfDeploymentPlaybook {
    <#
    .SYNOPSIS
        Execute the self-deployment test playbook using OrchestrationEngine
    #>
    param([string]$ClonePath)

    Write-ScriptLog -Message "Executing self-deployment test playbook (COMPREHENSIVE - may take 10-20 minutes)"

    if ($PSCmdlet.ShouldProcess($ClonePath, "Run self-deployment playbook")) {
        try {
            Push-Location $ClonePath
            
            $playbookStartTime = Get-Date

            # Import AitherZero module
            Write-ScriptLog -Message "Importing AitherZero module..."
            Import-Module "./AitherZero.psd1" -Force

            # Load global defaults from config.psd1
            $configPath = "./config.psd1"
            $defaultSuccessCriteria = @{
                RequireAllSuccess = $true  # Default to 100% success
                MinimumSuccessCount = 0
                MinimumSuccessPercent = 100
                AllowedFailures = @()
            }
            
            if (Test-Path $configPath) {
                try {
                    $configContent = Get-Content $configPath -Raw
                    $config = & ([scriptblock]::Create($configContent))
                    if ($config.Automation.DefaultSuccessCriteria) {
                        $defaultSuccessCriteria = $config.Automation.DefaultSuccessCriteria
                        Write-ScriptLog -Message "Loaded default success criteria from config.psd1"
                    }
                } catch {
                    Write-ScriptLog -Level Warning -Message "Could not load config defaults: $_"
                }
            }

            # Load playbook to read playbook-specific SuccessCriteria (overrides defaults)
            $playbookPath = "./library/playbooks/self-deployment-test.psd1"
            $playbookSuccessCriteria = $null
            if (Test-Path $playbookPath) {
                try {
                    $playbookContent = Get-Content $playbookPath -Raw
                    $playbookConfig = & ([scriptblock]::Create($playbookContent))
                    if ($playbookConfig.SuccessCriteria) {
                        $playbookSuccessCriteria = $playbookConfig.SuccessCriteria
                        Write-ScriptLog -Message "Loaded playbook-specific success criteria"
                    }
                } catch {
                    Write-ScriptLog -Level Warning -Message "Could not load playbook config: $_"
                }
            }
            
            # Merge: playbook settings override defaults
            # Ensure we have a valid hashtable before cloning
            if ($null -eq $defaultSuccessCriteria -or $defaultSuccessCriteria -isnot [hashtable]) {
                $defaultSuccessCriteria = @{
                    RequireAllSuccess = $true
                    MinimumSuccessCount = 0
                    MinimumSuccessPercent = 100
                    AllowedFailures = @()
                }
            }
            $successCriteria = $defaultSuccessCriteria.Clone()
            if ($playbookSuccessCriteria) {
                foreach ($key in $playbookSuccessCriteria.Keys) {
                    $successCriteria[$key] = $playbookSuccessCriteria[$key]
                }
            }

            # Execute the self-deployment test playbook
            Write-ScriptLog -Message "Running COMPREHENSIVE self-deployment-test playbook via OrchestrationEngine..."
            Write-ScriptLog -Message "  Scripts: 0407 (full syntax), 0413 (config), 0402 (tests+coverage), 0404 (full analyzer), 0512 (report)"
            Write-ScriptLog -Message "  Mode: COMPREHENSIVE - Full bootstrap, all tests with coverage, complete analysis"
            Write-ScriptLog -Message "  Estimated time: 10-20 minutes depending on system performance"
            
            # Run playbook - capture output to validate success
            # Don't use Out-Null - we need the return value to check success
            $result = Invoke-OrchestrationSequence -LoadPlaybook "self-deployment-test" 2>&1
            
            $playbookDuration = New-TimeSpan -Start $playbookStartTime -End (Get-Date)
            Write-ScriptLog -Message "Playbook execution completed in $($playbookDuration.TotalSeconds.ToString('F1')) seconds"
            
            $exitCode = $LASTEXITCODE
            if ($null -eq $exitCode) { $exitCode = 0 }
            
            Write-ScriptLog -Message "Success criteria: RequireAllSuccess=$($successCriteria.RequireAllSuccess), MinimumSuccessCount=$($successCriteria.MinimumSuccessCount)"
            
            # Validate success based on merged SuccessCriteria
            $success = Test-PlaybookSuccess -Result $result -ExitCode $exitCode -SuccessCriteria $successCriteria
            
            if ($success) {
                Write-ScriptLog -Level Information -Message "Self-deployment playbook completed successfully"
                if ($result -and $result -is [PSCustomObject] -and $null -ne $result.Completed) {
                    Write-ScriptLog -Message "Completed: $($result.Completed), Failed: $($result.Failed -or 0)"
                }
                return $true
            } else {
                $failureMsg = "Self-deployment playbook failed"
                if ($exitCode -ne 0) {
                    $failureMsg += " with exit code: $exitCode"
                }
                if ($result -and $result -is [PSCustomObject]) {
                    if ($null -ne $result.Completed) {
                        $failureMsg += " (Completed: $($result.Completed), Failed: $($result.Failed -or 0))"
                    }
                }
                Write-ScriptLog -Level Error -Message $failureMsg
                return $false
            }

        } catch {
            Write-ScriptLog -Level Error -Message "Self-deployment playbook execution error: $_"
            return $false
        } finally {
            Pop-Location
        }
    } else {
        # In WhatIf mode, return false (simulation)
        return $false
    }
}

function Test-PlaybookSuccess {
    <#
    .SYNOPSIS
        Validate playbook success based on SuccessCriteria configuration
    #>
    param(
        $Result,
        [int]$ExitCode,
        [hashtable]$SuccessCriteria
    )
    
    # Method 1: Check if result has explicit Success property
    if ($Result -and $Result -is [PSCustomObject] -and $null -ne $Result.Success) {
        return $Result.Success
    }
    
    # Method 2: Check exit code
    if ($ExitCode -ne 0) {
        return $false
    }
    
    # Method 3: Apply SuccessCriteria rules
    if ($Result -and $Result -is [PSCustomObject] -and $null -ne $Result.Completed) {
        $completed = $Result.Completed
        $failed = $Result.Failed -or 0
        
        # If RequireAllSuccess is true, no failures allowed
        if ($SuccessCriteria.RequireAllSuccess -eq $true) {
            if ($failed -gt 0) {
                Write-ScriptLog -Level Warning -Message "RequireAllSuccess=true but $failed script(s) failed"
                return $false
            }
            return $true
        }
        
        # Check MinimumSuccessCount
        $minRequired = $SuccessCriteria.MinimumSuccessCount -or 0
        if ($completed -lt $minRequired) {
            Write-ScriptLog -Level Warning -Message "Only $completed scripts completed, but MinimumSuccessCount=$minRequired"
            return $false
        }
        
        # Check if failures exceed successes
        if ($failed -gt $completed) {
            Write-ScriptLog -Level Warning -Message "More failures ($failed) than successes ($completed)"
            return $false
        }
        
        # If we have AllowedFailures list, we could check against it here
        # (would require script names in result, which may not be available)
        
        return $true
    }
    
    # Fallback: exit code was 0
    return $true
}

function Show-TestSummary {
    <#
    .SYNOPSIS
        Display test summary
    #>
    param(
        [bool]$BootstrapSuccess,
        [bool]$PlaybookSuccess,
        [string]$ClonePath
    )

    Write-Host "`n" + "="*80 -ForegroundColor Cyan
    Write-Host "🚀 AitherZero Self-Deployment Test Results" -ForegroundColor Cyan
    Write-Host "="*80 -ForegroundColor Cyan

    $overallSuccess = $BootstrapSuccess -and $PlaybookSuccess
    $resultColor = if ($overallSuccess) { 'Green' } else { 'Red' }
    $resultText = if ($overallSuccess) { "PASSED" } else { "FAILED" }

    Write-Host "`n📊 Overall Result: $resultText" -ForegroundColor $resultColor
    Write-Host "   Bootstrap: $(if ($BootstrapSuccess) { '✅ PASSED' } else { '❌ FAILED' })" -ForegroundColor $(if ($BootstrapSuccess) { 'Green' } else { 'Red' })
    Write-Host "   Playbook:  $(if ($PlaybookSuccess) { '✅ PASSED' } else { '❌ FAILED' })" -ForegroundColor $(if ($PlaybookSuccess) { 'Green' } else { 'Red' })

    # Show playbook results if available
    $resultFile = Join-Path $ClonePath "library/reports/self-deployment-result.json"
    if (Test-Path $resultFile) {
        Write-Host "`n📋 Detailed Results: $resultFile" -ForegroundColor White
    }

    Write-Host "`n📁 Test Environment: $TestPath" -ForegroundColor White

    if ($CleanupOnSuccess -and $overallSuccess) {
        Write-Host "`n🧹 Cleaning up test environment..." -ForegroundColor Yellow
        Remove-Item -Path $TestPath -Recurse -Force
        Write-Host "✅ Cleanup completed" -ForegroundColor Green
    }

    Write-Host "`n" + "="*80 -ForegroundColor Cyan

    return $overallSuccess
}

# Main execution
try {
    $script:TestStartTime = Get-Date
    
    Write-ScriptLog -Message "Starting AitherZero COMPREHENSIVE self-deployment test (no quick modes)" -Data @{
        TestPath = $TestPath
        Branch = $Branch
    }

    # Phase 1: Prerequisites
    Write-Host "`n🔍 Checking Prerequisites..." -ForegroundColor Cyan
    $prerequisites = Test-Prerequisites

    # Phase 2: Setup clean environment
    Write-Host "`n🏗️ Setting up test environment..." -ForegroundColor Cyan
    New-CleanTestEnvironment

    # Phase 3: Clone repository
    Write-Host "`n📥 Cloning repository..." -ForegroundColor Cyan
    $clonePath = Invoke-SelfClone

    # Phase 4: Test bootstrap
    Write-Host "`n🚀 Testing bootstrap process..." -ForegroundColor Cyan
    $bootstrapSuccess = Test-BootstrapProcess -ClonePath $clonePath

    # Phase 5: Run self-deployment playbook via OrchestrationEngine
    Write-Host "`n🎯 Running self-deployment validation playbook..." -ForegroundColor Cyan
    $playbookSuccess = Invoke-SelfDeploymentPlaybook -ClonePath $clonePath

    # Phase 6: Show summary
    Write-Host "`n📊 Generating test summary..." -ForegroundColor Cyan
    $overallSuccess = Show-TestSummary -BootstrapSuccess $bootstrapSuccess -PlaybookSuccess $playbookSuccess -ClonePath $clonePath

    # Show total duration
    $totalDuration = New-TimeSpan -Start $script:TestStartTime -End (Get-Date)
    Write-Host "`n⏱️  Total test duration: $($totalDuration.TotalSeconds.ToString('F1')) seconds ($($totalDuration.TotalMinutes.ToString('F1')) minutes)" -ForegroundColor Cyan

    # Exit with appropriate code
    if ($overallSuccess) {
        Write-ScriptLog -Level Information -Message "Self-deployment test PASSED! AitherZero can successfully deploy itself. (Total time: $($totalDuration.TotalSeconds.ToString('F1'))s)"
        exit 0
    } else {
        Write-ScriptLog -Level Error -Message "Self-deployment test FAILED. Critical issues found. (Total time: $($totalDuration.TotalSeconds.ToString('F1'))s)"
        exit 1
    }

} catch {
    $errorMsg = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
    Write-ScriptLog -Level Error -Message "Self-deployment test encountered an error: $_" -Data @{ Exception = $errorMsg }
    exit 1
}
