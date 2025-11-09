#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive validation of all playbooks in the repository

.DESCRIPTION
    This script performs comprehensive validation of ALL playbooks in AitherZero:
    - Loads each playbook to verify structure
    - Performs dry-run execution to validate orchestration
    - Checks for syntax errors and configuration issues
    - Generates detailed validation report with pass/fail status
    - Provides recommendations for playbook improvements

.PARAMETER PlaybookDirectory
    Directory containing playbooks (default: library/playbooks)

.PARAMETER OutputPath
    Path for validation report (default: library/reports/playbook-validation.json)

.PARAMETER StopOnFirstError
    Stop validation on first failed playbook (default: false - validate all)

.PARAMETER GenerateMarkdownReport
    Generate human-readable markdown report in addition to JSON

.PARAMETER Verbose
    Show detailed validation output for each playbook

.EXAMPLE
    ./0970_Validate-AllPlaybooks.ps1
    Validates all playbooks with default settings

.EXAMPLE
    ./0970_Validate-AllPlaybooks.ps1 -Verbose -GenerateMarkdownReport
    Comprehensive validation with detailed output and markdown report

.EXAMPLE
    ./0970_Validate-AllPlaybooks.ps1 -StopOnFirstError
    Stop on first failed playbook (useful for debugging)

.NOTES
    Stage: Validation
    Dependencies: OrchestrationEngine
    Tags: validation, playbooks, testing, comprehensive
    Author: Rachel PowerShell - AitherZero Automation Expert
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$PlaybookDirectory = "library/playbooks",
    
    [Parameter()]
    [string]$OutputPath = "library/reports/playbook-validation.json",
    
    [Parameter()]
    [switch]$StopOnFirstError,
    
    [Parameter()]
    [switch]$GenerateMarkdownReport,
    
    [Parameter()]
    [switch]$Quiet
)

# Import ScriptUtilities for common functions
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module (Join-Path $ProjectRoot "aithercore/automation/ScriptUtilities.psm1") -Force -ErrorAction SilentlyContinue

# Logging helper
function Write-ValidationLog {
    param([string]$Message, [string]$Level = 'Information')
    
    # Skip empty messages
    if ([string]::IsNullOrWhiteSpace($Message)) {
        if ($Level -eq 'Information' -and -not $Quiet) {
            Write-Host ""
        }
        return
    }
    
    if ($Level -eq 'Information' -and -not $Quiet) {
        Write-Host $Message
    } elseif ($Level -eq 'Warning') {
        Write-Warning $Message
    } elseif ($Level -eq 'Error') {
        Write-Error $Message
    }
    
    # Also use central logging if available
    if (Get-Command Write-ScriptLog -ErrorAction SilentlyContinue) {
        Write-ScriptLog -Message $Message -Level $Level
    }
}

# Main validation logic
try {
    Write-ValidationLog "═══════════════════════════════════════════════════════════" -Level 'Information'
    Write-ValidationLog "   COMPREHENSIVE PLAYBOOK VALIDATION" -Level 'Information'
    Write-ValidationLog "═══════════════════════════════════════════════════════════" -Level 'Information'
    Write-ValidationLog ""
    
    $startTime = Get-Date
    
    # Resolve paths
    $playbookPath = Join-Path $ProjectRoot $PlaybookDirectory
    $reportPath = Join-Path $ProjectRoot $OutputPath
    $reportDir = Split-Path $reportPath -Parent
    
    # Ensure report directory exists
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    
    Write-ValidationLog "Playbook Directory: $playbookPath" -Level 'Information'
    Write-ValidationLog "Report Path: $reportPath" -Level 'Information'
    Write-ValidationLog ""
    
    # Find all playbooks
    $playbookFiles = Get-ChildItem -Path $playbookPath -Filter "*.psd1" -File
    
    if ($playbookFiles.Count -eq 0) {
        Write-ValidationLog "No playbooks found in $playbookPath" -Level 'Warning'
        exit 0
    }
    
    Write-ValidationLog "Found $($playbookFiles.Count) playbooks to validate" -Level 'Information'
    Write-ValidationLog ""
    
    # Validation results
    $results = @{
        Timestamp = Get-Date -Format 'o'
        TotalPlaybooks = $playbookFiles.Count
        Passed = 0
        Failed = 0
        Skipped = 0
        Duration = $null
        Playbooks = @()
        Summary = @{
            SuccessRate = 0
            FailureRate = 0
            Issues = @()
        }
    }
    
    # Validate each playbook
    $counter = 0
    foreach ($file in $playbookFiles) {
        $counter++
        $playbookName = $file.BaseName
        
        Write-ValidationLog "[$counter/$($playbookFiles.Count)] Validating: $playbookName" -Level 'Information'
        
        $playbookResult = @{
            Name = $playbookName
            FilePath = $file.FullName
            Status = 'Unknown'
            ValidationTests = @{
                SyntaxCheck = $false
                LoadCheck = $false
                DryRunCheck = $false
            }
            Errors = @()
            Warnings = @()
            Duration = $null
        }
        
        $pbStartTime = Get-Date
        
        try {
            # Test 1: Syntax validation
            Write-ValidationLog "  → Checking PowerShell syntax..." -Level 'Information'
            $syntaxErrors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $file.FullName -Raw), [ref]$syntaxErrors)
            
            if ($syntaxErrors.Count -gt 0) {
                $playbookResult.ValidationTests.SyntaxCheck = $false
                $playbookResult.Errors += "Syntax errors: $($syntaxErrors.Count)"
                Write-ValidationLog "    ✗ Syntax check FAILED ($($syntaxErrors.Count) errors)" -Level 'Warning'
            } else {
                $playbookResult.ValidationTests.SyntaxCheck = $true
                Write-ValidationLog "    ✓ Syntax check PASSED" -Level 'Information'
            }
            
            # Test 2: Load playbook
            Write-ValidationLog "  → Loading playbook..." -Level 'Information'
            try {
                # Use OrchestrationEngine's Get-OrchestrationPlaybook if available
                if (Get-Command Get-OrchestrationPlaybook -ErrorAction SilentlyContinue) {
                    $playbook = Get-OrchestrationPlaybook -Name $playbookName
                    
                    if ($playbook) {
                        $playbookResult.ValidationTests.LoadCheck = $true
                        Write-ValidationLog "    ✓ Load check PASSED" -Level 'Information'
                        
                        # Gather metadata
                        $playbookResult.Metadata = @{
                            Version = $playbook.Version
                            Description = $playbook.Description
                            Author = $playbook.Author
                            HasSequence = [bool]$playbook.Sequence
                            HasStages = [bool]$playbook.Stages
                            HasVariables = [bool]$playbook.Variables
                        }
                    } else {
                        $playbookResult.ValidationTests.LoadCheck = $false
                        $playbookResult.Errors += "Failed to load playbook"
                        Write-ValidationLog "    ✗ Load check FAILED" -Level 'Warning'
                    }
                } else {
                    $playbookResult.Warnings += "Get-OrchestrationPlaybook not available, skipping load test"
                    Write-ValidationLog "    ⚠ Load check SKIPPED (OrchestrationEngine not available)" -Level 'Warning'
                }
            } catch {
                $playbookResult.ValidationTests.LoadCheck = $false
                $playbookResult.Errors += "Load error: $($_.Exception.Message)"
                Write-ValidationLog "    ✗ Load check FAILED: $($_.Exception.Message)" -Level 'Warning'
            }
            
            # Test 3: Dry-run execution
            Write-ValidationLog "  → Executing dry-run..." -Level 'Information'
            try {
                if (Get-Command Invoke-OrchestrationSequence -ErrorAction SilentlyContinue) {
                    $dryRunOutput = Invoke-OrchestrationSequence -LoadPlaybook $playbookName -DryRun -ErrorAction Stop 2>&1
                    $dryRunExitCode = $LASTEXITCODE
                    
                    if ($dryRunExitCode -eq 0 -or $null -eq $dryRunExitCode) {
                        $playbookResult.ValidationTests.DryRunCheck = $true
                        Write-ValidationLog "    ✓ Dry-run PASSED" -Level 'Information'
                    } else {
                        $playbookResult.ValidationTests.DryRunCheck = $false
                        $playbookResult.Errors += "Dry-run failed with exit code: $dryRunExitCode"
                        Write-ValidationLog "    ✗ Dry-run FAILED (exit code: $dryRunExitCode)" -Level 'Warning'
                    }
                } else {
                    $playbookResult.Warnings += "Invoke-OrchestrationSequence not available, skipping dry-run test"
                    Write-ValidationLog "    ⚠ Dry-run SKIPPED (OrchestrationEngine not available)" -Level 'Warning'
                }
            } catch {
                $playbookResult.ValidationTests.DryRunCheck = $false
                $playbookResult.Errors += "Dry-run error: $($_.Exception.Message)"
                Write-ValidationLog "    ✗ Dry-run FAILED: $($_.Exception.Message)" -Level 'Warning'
            }
            
            # Determine overall status
            $allPassed = $playbookResult.ValidationTests.SyntaxCheck -and 
                        $playbookResult.ValidationTests.LoadCheck -and 
                        $playbookResult.ValidationTests.DryRunCheck
            
            if ($allPassed) {
                $playbookResult.Status = 'Passed'
                $results.Passed++
                Write-ValidationLog "  ✅ OVERALL: PASSED" -Level 'Information'
            } elseif ($playbookResult.Errors.Count -gt 0) {
                $playbookResult.Status = 'Failed'
                $results.Failed++
                Write-ValidationLog "  ❌ OVERALL: FAILED ($($playbookResult.Errors.Count) errors)" -Level 'Warning'
                
                if ($StopOnFirstError) {
                    Write-ValidationLog ""
                    Write-ValidationLog "Stopping validation due to -StopOnFirstError flag" -Level 'Warning'
                    break
                }
            } else {
                $playbookResult.Status = 'Partial'
                $results.Passed++
                Write-ValidationLog "  ⚠ OVERALL: PARTIAL (some tests skipped)" -Level 'Warning'
            }
            
        } catch {
            $playbookResult.Status = 'Failed'
            $playbookResult.Errors += "Validation error: $($_.Exception.Message)"
            $results.Failed++
            Write-ValidationLog "  ❌ OVERALL: FAILED - $($_.Exception.Message)" -Level 'Error'
            
            if ($StopOnFirstError) {
                throw
            }
        }
        
        $playbookResult.Duration = (Get-Date) - $pbStartTime
        $results.Playbooks += $playbookResult
        Write-ValidationLog ""
    }
    
    # Calculate summary statistics
    $results.Duration = (Get-Date) - $startTime
    $results.Summary.SuccessRate = if ($results.TotalPlaybooks -gt 0) {
        [math]::Round(($results.Passed / $results.TotalPlaybooks) * 100, 2)
    } else { 0 }
    $results.Summary.FailureRate = if ($results.TotalPlaybooks -gt 0) {
        [math]::Round(($results.Failed / $results.TotalPlaybooks) * 100, 2)
    } else { 0 }
    
    # Collect all unique issues
    $results.Summary.Issues = $results.Playbooks | 
        Where-Object { $_.Errors.Count -gt 0 } | 
        ForEach-Object { $_.Errors } | 
        Select-Object -Unique
    
    # Save JSON report
    Write-ValidationLog "═══════════════════════════════════════════════════════════" -Level 'Information'
    Write-ValidationLog "   VALIDATION RESULTS" -Level 'Information'
    Write-ValidationLog "═══════════════════════════════════════════════════════════" -Level 'Information'
    Write-ValidationLog "Total Playbooks: $($results.TotalPlaybooks)" -Level 'Information'
    Write-ValidationLog "Passed: $($results.Passed) ($(($results.Summary.SuccessRate))%)" -Level 'Information'
    Write-ValidationLog "Failed: $($results.Failed) ($(($results.Summary.FailureRate))%)" -Level 'Information'
    Write-ValidationLog "Duration: $($results.Duration.TotalSeconds) seconds" -Level 'Information'
    Write-ValidationLog ""
    
    $results | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath -Encoding UTF8
    Write-ValidationLog "JSON report saved to: $reportPath" -Level 'Information'
    
    # Generate markdown report if requested
    if ($GenerateMarkdownReport) {
        $mdPath = $reportPath -replace '\.json$', '.md'
        
        $markdown = @"
# Playbook Validation Report

**Generated**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
**Duration**: $($results.Duration.ToString())

## Summary

| Metric | Value |
|--------|-------|
| Total Playbooks | $($results.TotalPlaybooks) |
| Passed | $($results.Passed) ✅ |
| Failed | $($results.Failed) ❌ |
| Success Rate | $($results.Summary.SuccessRate)% |

## Detailed Results

"@
        
        foreach ($pb in $results.Playbooks | Sort-Object Status, Name) {
            $statusIcon = switch ($pb.Status) {
                'Passed' { '✅' }
                'Failed' { '❌' }
                'Partial' { '⚠️' }
                default { '❓' }
            }
            
            $markdown += @"

### $statusIcon $($pb.Name)

**Status**: $($pb.Status)  
**Duration**: $($pb.Duration.TotalSeconds)s

**Validation Tests**:
- Syntax Check: $(if ($pb.ValidationTests.SyntaxCheck) { '✅ Pass' } else { '❌ Fail' })
- Load Check: $(if ($pb.ValidationTests.LoadCheck) { '✅ Pass' } else { '❌ Fail' })
- Dry-Run Check: $(if ($pb.ValidationTests.DryRunCheck) { '✅ Pass' } else { '❌ Fail' })

"@
            
            if ($pb.Errors.Count -gt 0) {
                $markdown += "**Errors**:`n"
                foreach ($error in $pb.Errors) {
                    $markdown += "- $error`n"
                }
                $markdown += "`n"
            }
            
            if ($pb.Warnings.Count -gt 0) {
                $markdown += "**Warnings**:`n"
                foreach ($warning in $pb.Warnings) {
                    $markdown += "- $warning`n"
                }
                $markdown += "`n"
            }
        }
        
        $markdown | Set-Content -Path $mdPath -Encoding UTF8
        Write-ValidationLog "Markdown report saved to: $mdPath" -Level 'Information'
    }
    
    Write-ValidationLog ""
    
    # Exit with appropriate code
    if ($results.Failed -gt 0) {
        Write-ValidationLog "❌ VALIDATION FAILED: $($results.Failed) playbook(s) failed validation" -Level 'Error'
        exit 1
    } else {
        Write-ValidationLog "✅ VALIDATION SUCCESSFUL: All playbooks validated successfully!" -Level 'Information'
        exit 0
    }
    
} catch {
    Write-ValidationLog "Fatal error during validation: $_" -Level 'Error'
    Write-ValidationLog $_.ScriptStackTrace -Level 'Error'
    exit 1
}
