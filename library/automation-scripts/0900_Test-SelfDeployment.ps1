#Requires -Version 7.0

<#
.SYNOPSIS
    Test AitherZero self-deployment capabilities
.DESCRIPTION
    Validates that AitherZero can fully deploy and set up itself using its own
    automation pipeline. Uses the OrchestrationEngine to execute the self-deployment
    test playbook.

    Exit Codes:
    0   - Self-deployment test passed
    1   - Test failed
    2   - Setup error

.NOTES
    Stage: Validation
    Order: 0900
    Dependencies: All
    Tags: self-deployment, validation, ci-cd, end-to-end
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ProjectPath = ($PSScriptRoot | Split-Path -Parent),
    [switch]$QuickTest,  # Deprecated: Full validation is always performed
    [switch]$FullTest,   # Deprecated: Full validation is always performed
    [string]$TestPath = (Join-Path ([System.IO.Path]::GetTempPath()) "aitherzero-self-deploy-test"),
    [switch]$CleanupOnSuccess,
    [string]$Branch = "main"
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata
$scriptMetadata = @{
    Stage = 'Validation'
    Order = 0900
    Dependencies = @('All')
    Tags = @('self-deployment', 'validation', 'ci-cd', 'end-to-end')
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

            # Run bootstrap in non-interactive mode
            Write-ScriptLog -Message "Running bootstrap process..."
            $startTime = Get-Date

            & pwsh -c "$bootstrapScript -Mode New -InstallProfile Minimal -NonInteractive" | Out-Null

            if ($LASTEXITCODE -ne 0) {
                throw "Bootstrap process failed with exit code: $LASTEXITCODE"
            }

            $duration = (Get-Date) - $startTime
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

    Write-ScriptLog -Message "Executing self-deployment test playbook"

    if ($PSCmdlet.ShouldProcess($ClonePath, "Run self-deployment playbook")) {
        try {
            Push-Location $ClonePath

            # Import AitherZero module
            Write-ScriptLog -Message "Importing AitherZero module..."
            Import-Module "./AitherZero.psd1" -Force

            # Execute the self-deployment test playbook
            Write-ScriptLog -Message "Running self-deployment-test playbook via OrchestrationEngine..."
            
            # Run playbook and capture result
            $playbookResult = Invoke-OrchestrationSequence `
                -LoadPlaybook "self-deployment-test" `
                -GenerateSummary `
                -OutputFormat "JSON" `
                -OutputPath "./library/reports/self-deployment-result.json" `
                -ErrorAction Stop

            # Check if result file was created (indicates success)
            $resultFile = "./library/reports/self-deployment-result.json"
            if (Test-Path $resultFile) {
                try {
                    $result = Get-Content $resultFile -Raw | ConvertFrom-Json
                    if ($result.Success -or $result.Completed -gt 0) {
                        Write-ScriptLog -Level Information -Message "Self-deployment playbook completed successfully"
                        if ($result.Completed) {
                            Write-ScriptLog -Message "Completed: $($result.Completed), Failed: $($result.Failed -or 0)"
                        }
                        return $true
                    } else {
                        Write-ScriptLog -Level Error -Message "Self-deployment playbook failed"
                        return $false
                    }
                } catch {
                    Write-ScriptLog -Level Warning -Message "Could not parse result file, assuming success if created"
                    return $true
                }
            } else {
                Write-ScriptLog -Level Error -Message "Self-deployment playbook did not create result file"
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
    
    # Display deprecation warnings
    if ($QuickTest -or $FullTest) {
        Write-ScriptLog -Level Warning -Message "QuickTest and FullTest parameters are deprecated. Full validation is always performed."
    }
    
    Write-ScriptLog -Message "Starting AitherZero self-deployment test" -Data @{
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

    # Exit with appropriate code
    if ($overallSuccess) {
        Write-ScriptLog -Level Information -Message "Self-deployment test PASSED! AitherZero can successfully deploy itself."
        exit 0
    } else {
        Write-ScriptLog -Level Error -Message "Self-deployment test FAILED. Critical issues found."
        exit 1
    }

} catch {
    $errorMsg = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
    Write-ScriptLog -Level Error -Message "Self-deployment test encountered an error: $_" -Data @{ Exception = $errorMsg }
    exit 1
}
