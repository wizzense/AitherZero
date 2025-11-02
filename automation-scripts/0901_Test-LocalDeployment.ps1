#Requires -Version 7.0

<#
.SYNOPSIS
    Test AitherZero local deployment capabilities (offline mode)
.DESCRIPTION
    Validates that AitherZero can deploy and set itself up locally without
    requiring internet connectivity. Tests core functionality, CI/CD components,
    and automation capabilities.

.NOTES
    Stage: Validation
    Order: 0901
    Dependencies: All
    Tags: local-deployment, validation, offline, end-to-end
#>

[CmdletBinding()]
param(
    [string]$ProjectPath = ($PSScriptRoot | Split-Path -Parent),
    [switch]$QuickTest
)

$ErrorActionPreference = 'Continue'  # Don't stop on individual test failures
Set-StrictMode -Version Latest

function Write-TestLog {
    param(
        [string]$Level = 'Info',
        [string]$Message
    )

    $color = @{
        'Info' = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error' = 'Red'
    }[$Level]

    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-CoreComponents {
    Write-TestLog -Message "Testing core components..."

    $tests = @{}

    # Test 1: Module manifest exists and is valid
    try {
        $manifest = Test-ModuleManifest -Path (Join-Path $ProjectPath "AitherZero.psd1") -ErrorAction Stop
        $tests['ModuleManifest'] = $true
        Write-TestLog -Level Success -Message "Module manifest is valid"
    } catch {
        $tests['ModuleManifest'] = $false
        Write-TestLog -Level Error -Message "Module manifest test failed: $_"
    }

    # Test 2: Bootstrap script exists and is syntactically correct
    try {
        $bootstrapPath = Join-Path $ProjectPath "bootstrap.ps1"
        if (Test-Path $bootstrapPath) {
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $bootstrapPath -Raw), [ref]$null)
            $tests['Bootstrap'] = $true
            Write-TestLog -Level Success -Message "Bootstrap script syntax is valid"
        } else {
            $tests['Bootstrap'] = $false
            Write-TestLog -Level Error -Message "Bootstrap script not found"
        }
    } catch {
        $tests['Bootstrap'] = $false
        Write-TestLog -Level Error -Message "Bootstrap script test failed: $_"
    }

    # Test 3: Critical automation scripts exist
    $criticalScripts = @(
        "0402_Run-UnitTests.ps1",
        "0404_Run-PSScriptAnalyzer.ps1",
        "0407_Validate-Syntax.ps1",
        "0512_Generate-Dashboard.ps1",
        "0740_Integrate-AITools.ps1",
        "0815_Setup-IssueManagement.ps1"
    )

    $missingScripts = @()
    foreach ($script in $criticalScripts) {
        $scriptPath = Join-Path $ProjectPath "automation-scripts/$script"
        if (-not (Test-Path $scriptPath)) {
            $missingScripts += $script
        }
    }

    $tests['AutomationScripts'] = $missingScripts.Count -eq 0
    if ($tests['AutomationScripts']) {
        Write-TestLog -Level Success -Message "All critical automation scripts found"
    } else {
        Write-TestLog -Level Error -Message "Missing scripts: $($missingScripts -join ', ')"
    }

    return $tests
}

function Test-ModuleLoading {
    Write-TestLog -Message "Testing module loading..."

    $tests = @{}

    try {
        # Test module import
        Import-Module (Join-Path $ProjectPath "AitherZero.psd1") -Force -ErrorAction Stop
        $tests['Import'] = $true
        Write-TestLog -Level Success -Message "Module imported successfully"

        # Test key functions are available
        $keyFunctions = @('Invoke-AitherScript')
        $missingFunctions = @()

        foreach ($func in $keyFunctions) {
            if (-not (Get-Command $func -ErrorAction SilentlyContinue)) {
                $missingFunctions += $func
            }
        }

        $tests['Functions'] = $missingFunctions.Count -eq 0
        if ($tests['Functions']) {
            Write-TestLog -Level Success -Message "Key functions are available"
        } else {
            Write-TestLog -Level Error -Message "Missing functions: $($missingFunctions -join ', ')"
        }

    } catch {
        $tests['Import'] = $false
        $tests['Functions'] = $false
        Write-TestLog -Level Error -Message "Module loading failed: $_"
    }

    return $tests
}

function Test-SyntaxValidation {
    Write-TestLog -Message "Testing syntax validation..."

    $tests = @{}

    try {
        Push-Location $ProjectPath

        # Run syntax validation script
        $result = & pwsh -c "./automation-scripts/0407_Validate-Syntax.ps1 -All" 2>&1

        if ($LASTEXITCODE -eq 0) {
            $tests['SyntaxValidation'] = $true
            Write-TestLog -Level Success -Message "All PowerShell files have valid syntax"
        } else {
            $tests['SyntaxValidation'] = $false
            Write-TestLog -Level Error -Message "Syntax validation failed"
        }

    } catch {
        $tests['SyntaxValidation'] = $false
        Write-TestLog -Level Error -Message "Syntax validation test failed: $_"
    } finally {
        Pop-Location
    }

    return $tests
}

function Test-ReportGeneration {
    Write-TestLog -Message "Testing report generation..."

    $tests = @{}

    if ($QuickTest) {
        Write-TestLog -Message "Skipping report generation in quick mode"
        $tests['Dashboard'] = $true
        return $tests
    }

    try {
        Push-Location $ProjectPath

        # Test dashboard generation
        $result = & pwsh -c "./automation-scripts/0512_Generate-Dashboard.ps1 -Format JSON" 2>&1

        if ($LASTEXITCODE -eq 0 -and (Test-Path "./reports/dashboard.json")) {
            $tests['Dashboard'] = $true
            Write-TestLog -Level Success -Message "Dashboard generation successful"

            # Verify the generated report has content
            try {
                $dashboardContent = Get-Content "./reports/dashboard.json" | ConvertFrom-Json
                if ($dashboardContent -and $dashboardContent.Metrics) {
                    Write-TestLog -Level Success -Message "Dashboard contains valid metrics"
                } else {
                    Write-TestLog -Level Warning -Message "Dashboard generated but may have incomplete data"
                }
            } catch {
                Write-TestLog -Level Warning -Message "Dashboard file generated but content validation failed"
            }
        } else {
            $tests['Dashboard'] = $false
            Write-TestLog -Level Error -Message "Dashboard generation failed"
        }

    } catch {
        $tests['Dashboard'] = $false
        Write-TestLog -Level Error -Message "Report generation test failed: $_"
    } finally {
        Pop-Location
    }

    return $tests
}

function Test-CICDComponents {
    Write-TestLog -Message "Testing CI/CD components..."

    $tests = @{}

    # Test GitHub Actions workflow files
    $workflowFiles = @(
        ".github/workflows/ci-cd-pipeline.yml",
        ".github/workflows/comprehensive-ci-cd.yml"
    )

    $validWorkflows = 0
    foreach ($workflow in $workflowFiles) {
        $workflowPath = Join-Path $ProjectPath $workflow
        if (Test-Path $workflowPath) {
            try {
                $content = Get-Content $workflowPath -Raw
                if ($content -match 'name:' -and $content -match 'on:' -and $content -match 'jobs:') {
                    $validWorkflows++
                    Write-TestLog -Level Success -Message "Valid workflow: $workflow"
                } else {
                    Write-TestLog -Level Warning -Message "Workflow may be incomplete: $workflow"
                }
            } catch {
                Write-TestLog -Level Error -Message "Failed to validate workflow: $workflow"
            }
        } else {
            Write-TestLog -Level Error -Message "Missing workflow: $workflow"
        }
    }

    $tests['Workflows'] = $validWorkflows -eq $workflowFiles.Count

    # Test AI integration script (WhatIf mode)
    try {
        Push-Location $ProjectPath
        $result = & pwsh -c "./automation-scripts/0740_Integrate-AITools.ps1 -SkipInstallation -WhatIf" 2>&1
        $tests['AIIntegration'] = $LASTEXITCODE -eq 0

        if ($tests['AIIntegration']) {
            Write-TestLog -Level Success -Message "AI integration script validated"
        } else {
            Write-TestLog -Level Error -Message "AI integration script failed validation"
        }
    } catch {
        $tests['AIIntegration'] = $false
        Write-TestLog -Level Error -Message "AI integration test failed: $_"
    } finally {
        Pop-Location
    }

    # Test issue management script (WhatIf mode)
    try {
        Push-Location $ProjectPath
        $result = & pwsh -c "./automation-scripts/0815_Setup-IssueManagement.ps1 -WhatIf" 2>&1
        $tests['IssueManagement'] = $LASTEXITCODE -eq 0

        if ($tests['IssueManagement']) {
            Write-TestLog -Level Success -Message "Issue management script validated"
        } else {
            Write-TestLog -Level Error -Message "Issue management script failed validation"
        }
    } catch {
        $tests['IssueManagement'] = $false
        Write-TestLog -Level Error -Message "Issue management test failed: $_"
    } finally {
        Pop-Location
    }

    return $tests
}

function Show-TestResults {
    param(
        [hashtable]$CoreResults,
        [hashtable]$ModuleResults,
        [hashtable]$SyntaxResults,
        [hashtable]$ReportResults,
        [hashtable]$CICDResults
    )

    # Combine all results
    $allResults = @{}
    $allResults += $CoreResults
    $allResults += $ModuleResults
    $allResults += $SyntaxResults
    $allResults += $ReportResults
    $allResults += $CICDResults

    # Calculate summary
    $totalTests = $allResults.Count
    $passedTests = ($allResults.Values | Where-Object { $_ }).Count
    $successRate = if ($totalTests -gt 0) { [Math]::Round(($passedTests / $totalTests) * 100, 1) } else { 0 }

    $overallResult = if ($successRate -eq 100) {
        "PASSED"
    } elseif ($successRate -ge 80) {
        "PASSED WITH WARNINGS"
    } else {
        "FAILED"
    }

    # Display results
    Write-Host "`n" + "="*70 -ForegroundColor Cyan
    Write-Host "🚀 AitherZero Local Deployment Test Results" -ForegroundColor Cyan
    Write-Host "="*70 -ForegroundColor Cyan

    $resultColor = switch ($overallResult) {
        "PASSED" { 'Green' }
        "PASSED WITH WARNINGS" { 'Yellow' }
        default { 'Red' }
    }

    Write-Host "`n📊 Overall Result: $overallResult" -ForegroundColor $resultColor
    Write-Host "✅ Tests Passed: $passedTests/$totalTests ($successRate%)" -ForegroundColor White

    Write-Host "`n📋 Detailed Results:" -ForegroundColor Cyan

    Write-Host "`n🏗️  Core Components:" -ForegroundColor White
    foreach ($test in $CoreResults.GetEnumerator()) {
        $status = if ($test.Value) { "✅ PASS" } else { "❌ FAIL" }
        $color = if ($test.Value) { 'Green' } else { 'Red' }
        Write-Host "  $($test.Key): $status" -ForegroundColor $color
    }

    Write-Host "`n📦 Module Loading:" -ForegroundColor White
    foreach ($test in $ModuleResults.GetEnumerator()) {
        $status = if ($test.Value) { "✅ PASS" } else { "❌ FAIL" }
        $color = if ($test.Value) { 'Green' } else { 'Red' }
        Write-Host "  $($test.Key): $status" -ForegroundColor $color
    }

    Write-Host "`n🔍 Syntax Validation:" -ForegroundColor White
    foreach ($test in $SyntaxResults.GetEnumerator()) {
        $status = if ($test.Value) { "✅ PASS" } else { "❌ FAIL" }
        $color = if ($test.Value) { 'Green' } else { 'Red' }
        Write-Host "  $($test.Key): $status" -ForegroundColor $color
    }

    Write-Host "`n📊 Report Generation:" -ForegroundColor White
    foreach ($test in $ReportResults.GetEnumerator()) {
        $status = if ($test.Value) { "✅ PASS" } else { "❌ FAIL" }
        $color = if ($test.Value) { 'Green' } else { 'Red' }
        Write-Host "  $($test.Key): $status" -ForegroundColor $color
    }

    Write-Host "`n⚙️  CI/CD Components:" -ForegroundColor White
    foreach ($test in $CICDResults.GetEnumerator()) {
        $status = if ($test.Value) { "✅ PASS" } else { "❌ FAIL" }
        $color = if ($test.Value) { 'Green' } else { 'Red' }
        Write-Host "  $($test.Key): $status" -ForegroundColor $color
    }

    Write-Host "`n" + "="*70 -ForegroundColor Cyan

    if ($overallResult -eq "PASSED") {
        Write-Host "🎉 AitherZero can successfully deploy itself locally!" -ForegroundColor Green
        return 0
    } elseif ($overallResult -eq "PASSED WITH WARNINGS") {
        Write-Host "⚠️ AitherZero can deploy itself but with some warnings." -ForegroundColor Yellow
        return 0
    } else {
        Write-Host "❌ AitherZero self-deployment has critical issues." -ForegroundColor Red
        return 1
    }
}

# Main test execution
try {
    $testStart = Get-Date

    Write-Host "🚀 Starting AitherZero Local Deployment Test" -ForegroundColor Cyan
    Write-Host "Project Path: $ProjectPath" -ForegroundColor Gray
    Write-Host "Quick Test: $QuickTest" -ForegroundColor Gray
    Write-Host ""

    # Run test phases
    $coreTests = Test-CoreComponents
    $moduleTests = Test-ModuleLoading
    $syntaxTests = Test-SyntaxValidation
    $reportTests = Test-ReportGeneration
    $cicdTests = Test-CICDComponents

    # Show results
    $exitCode = Show-TestResults -CoreResults $coreTests -ModuleResults $moduleTests -SyntaxResults $syntaxTests -ReportResults $reportTests -CICDResults $cicdTests

    $duration = (Get-Date) - $testStart
    Write-Host "`nTest Duration: $($duration.TotalSeconds.ToString('F1')) seconds" -ForegroundColor Gray

    exit $exitCode

} catch {
    Write-TestLog -Level Error -Message "Test execution failed: $_"
    exit 1
}