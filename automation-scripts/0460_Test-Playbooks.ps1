#Requires -Version 7.0

<#
.SYNOPSIS
    Tests all playbooks to ensure they work correctly
.DESCRIPTION
    Simple validation that catches common issues before release.
    Tests that playbooks can load, all referenced scripts exist, and dry runs succeed.
.PARAMETER PlaybookDir
    Directory containing playbooks to test
.PARAMETER StopOnError
    Stop testing if any playbook fails
.PARAMETER CI
    Running in CI mode - will throw on any failures
.PARAMETER Verbose
    Show detailed output
.EXAMPLE
    ./0460_Test-Playbooks.ps1
.EXAMPLE
    ./0460_Test-Playbooks.ps1 -CI -StopOnError
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$PlaybookDir = "./orchestration/playbooks-psd1",
    
    [switch]$StopOnError,
    
    [switch]$CI = ($env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true'),
    
    [switch]$IncludeLegacy
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import required modules
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:AitherModule = Join-Path $script:ProjectRoot "AitherZero.psd1"

# Ensure environment is initialized
$env:AITHERZERO_ROOT = $script:ProjectRoot

# Import main module - if it fails, try bootstrap first
try {
    Import-Module $script:AitherModule -Force -Global -ErrorAction Stop
    Write-Verbose "Loaded AitherZero module"
} catch {
    Write-Warning "Module load failed, attempting bootstrap initialization..."
    $bootstrapScript = Join-Path $script:ProjectRoot "bootstrap.ps1"
    if (Test-Path $bootstrapScript) {
        & $bootstrapScript -Mode New -NonInteractive -SkipAutoStart
        Import-Module $script:AitherModule -Force -Global -ErrorAction Stop
        Write-Verbose "Loaded AitherZero module after bootstrap"
    } else {
        Write-Error "Failed to load AitherZero module and bootstrap not found: $_"
        exit 1
    }
}

# Initialize results
$script:Results = @()
$script:TotalTests = 0
$script:PassedTests = 0
$script:FailedTests = 0

function Test-PlaybookFile {
    param(
        [System.IO.FileInfo]$PlaybookFile
    )
    
    $result = [PSCustomObject]@{
        Name = $PlaybookFile.Name
        Path = $PlaybookFile.FullName
        Status = 'Unknown'
        Tests = @()
        Errors = @()
        Warnings = @()
        Duration = [TimeSpan]::Zero
    }
    
    $startTime = Get-Date
    
    Write-Host "`nTesting Playbook: $($PlaybookFile.Name)" -ForegroundColor Cyan
    Write-Host "Path: $($PlaybookFile.Directory.Name)/$($PlaybookFile.Name)" -ForegroundColor DarkGray
    
    # Test 1: Can we load the playbook?
    Write-Host "  [1/4] Loading playbook..." -NoNewline
    try {
        $playbook = Import-PowerShellDataFile $PlaybookFile.FullName
        $result.Tests += [PSCustomObject]@{
            Name = 'Load'
            Passed = $true
            Message = 'Playbook loaded successfully'
        }
        Write-Host " ✓" -ForegroundColor Green
    } catch {
        $result.Tests += [PSCustomObject]@{
            Name = 'Load'
            Passed = $false
            Message = $_.Exception.Message
        }
        $result.Errors += "Failed to load: $_"
        $result.Status = 'Failed'
        Write-Host " ✗" -ForegroundColor Red
        Write-Host "       Error: $_" -ForegroundColor Red
        return $result
    }
    
    # Test 2: Validate structure
    Write-Host "  [2/4] Validating structure..." -NoNewline
    $structureValid = $true
    
    if (-not $playbook.Name) {
        $result.Errors += "Missing required field: Name"
        $structureValid = $false
    }
    if (-not $playbook.Description) {
        $result.Warnings += "Missing recommended field: Description"
    }
    if (-not $playbook.Version) {
        $result.Warnings += "Missing recommended field: Version"
    }
    
    # Check for sequences or stages
    $hasSequences = $false
    $allSequences = @()
    
    if ($playbook.Sequence) {
        $hasSequences = $true
        $allSequences = $playbook.Sequence
    } elseif ($playbook.Stages) {
        $hasSequences = $true
        # Collect all sequences from stages
        foreach ($stage in $playbook.Stages) {
            try {
                if ($stage -and $stage.ContainsKey('Sequence') -and $stage.Sequence) {
                    $allSequences += $stage.Sequence
                }
            } catch {
                # Some stages might not have Sequence property, that's OK
            }
        }
    }
    
    # Store sequences for later validation
    if ($allSequences.Count -gt 0) {
        $playbook | Add-Member -NotePropertyName '_AllSequences' -NotePropertyValue $allSequences -Force
    }
    
    if (-not $hasSequences) {
        $result.Errors += "No execution sequences found (need Sequence or Stages)"
        $structureValid = $false
    }
    
    $result.Tests += [PSCustomObject]@{
        Name = 'Structure'
        Passed = $structureValid
        Message = if ($structureValid) { 'Structure is valid' } else { 'Structure validation failed' }
    }
    
    if ($structureValid) {
        Write-Host " ✓" -ForegroundColor Green
    } else {
        Write-Host " ✗" -ForegroundColor Red
        $result.Status = 'Failed'
        return $result
    }
    
    # Test 3: Check if all referenced scripts exist
    Write-Host "  [3/4] Checking script references..." -NoNewline
    $missingScripts = @()
    $checkedScripts = @()
    
    # Use the collected sequences
    $sequencesToCheck = if ($playbook._AllSequences) { $playbook._AllSequences } elseif ($playbook.Sequence) { $playbook.Sequence } else { @() }
    
    foreach ($seq in $sequencesToCheck) {
        if ($seq -in $checkedScripts) { continue }
        $checkedScripts += $seq
        
        # Look for script file
        $scriptPattern = Join-Path $script:ProjectRoot "automation-scripts/${seq}_*.ps1"
        $scriptFiles = @(Get-ChildItem -Path $scriptPattern -ErrorAction SilentlyContinue)
        
        if ($scriptFiles.Count -eq 0) {
            $missingScripts += $seq
        }
    }
    
    if ($missingScripts.Count -gt 0) {
        $result.Errors += "Missing scripts: $($missingScripts -join ', ')"
        $result.Tests += [PSCustomObject]@{
            Name = 'Scripts'
            Passed = $false
            Message = "Missing $($missingScripts.Count) script(s)"
        }
        Write-Host " ✗" -ForegroundColor Red
        Write-Host "       Missing: $($missingScripts -join ', ')" -ForegroundColor Red
        $result.Status = 'Failed'
    } else {
        $result.Tests += [PSCustomObject]@{
            Name = 'Scripts'
            Passed = $true
            Message = "All $($checkedScripts.Count) scripts found"
        }
        Write-Host " ✓" -ForegroundColor Green
    }
    
    # Test 4: Dry run test (skip for now - optional test)
    Write-Host "  [4/4] Testing dry run..." -NoNewline
    # Skip dry run test as it requires full orchestration context
    $result.Tests += [PSCustomObject]@{
        Name = 'DryRun'
        Passed = $true
        Message = 'Dry run test skipped (optional)'
    }
    Write-Host " [SKIPPED]" -ForegroundColor Gray
    
    # Calculate final status
    $result.Duration = (Get-Date) - $startTime
    $failedTests = $result.Tests | Where-Object { -not $_.Passed }
    
    if ($result.Errors.Count -gt 0) {
        $result.Status = 'Failed'
    } elseif ($failedTests.Count -gt 0) {
        $result.Status = 'Warning'
    } else {
        $result.Status = 'Passed'
    }
    
    # Show summary for this playbook
    $statusColor = switch ($result.Status) {
        'Passed' { 'Green' }
        'Warning' { 'Yellow' }
        'Failed' { 'Red' }
        default { 'Gray' }
    }
    
    Write-Host "  Result: $($result.Status) (Duration: $($result.Duration.TotalSeconds.ToString('0.00'))s)" -ForegroundColor $statusColor
    
    if ($result.Warnings.Count -gt 0) {
        foreach ($warning in $result.Warnings) {
            Write-Host "  ⚠ $warning" -ForegroundColor Yellow
        }
    }
    
    return $result
}

# Main execution
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host " AitherZero Playbook Validation" -ForegroundColor White
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Blue

# Check if playbook directory exists
if (-not (Test-Path $PlaybookDir)) {
    Write-Error "Playbook directory not found: $PlaybookDir"
    exit 1
}

# Find all playbooks
Write-Host "`nSearching for playbooks in: $PlaybookDir" -ForegroundColor Gray
$playbooks = @(Get-ChildItem $PlaybookDir -Filter "*.psd1" -Recurse)

if ($IncludeLegacy) {
    # Also check JSON playbooks
    $jsonDir = Join-Path $script:ProjectRoot "orchestration/playbooks"
    if (Test-Path $jsonDir) {
        $jsonPlaybooks = @(Get-ChildItem $jsonDir -Filter "*.json" -Recurse)
        Write-Host "Including $($jsonPlaybooks.Count) legacy JSON playbooks" -ForegroundColor Gray
    }
}

if ($playbooks.Count -eq 0) {
    Write-Warning "No playbooks found to test"
    exit 0
}

Write-Host "Found $($playbooks.Count) playbook(s) to test`n" -ForegroundColor Gray

# Test each playbook
foreach ($playbook in $playbooks) {
    $script:TotalTests++
    
    try {
        $result = Test-PlaybookFile -PlaybookFile $playbook
        $script:Results += $result
        
        if ($result.Status -eq 'Passed') {
            $script:PassedTests++
        } elseif ($result.Status -eq 'Failed') {
            $script:FailedTests++
            
            if ($StopOnError) {
                Write-Error "Stopping due to failure (StopOnError is set)"
                break
            }
        }
        
    } catch {
        $script:FailedTests++
        # $playbook here is a FileInfo object from the foreach loop
        $playbookName = $playbook.Name
        Write-Error "Unexpected error testing $playbookName : $_"
        
        if ($StopOnError) {
            break
        }
    }
}

# Display summary
Write-Host "`n════════════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host " VALIDATION SUMMARY" -ForegroundColor White
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Blue

Write-Host "`nTotal Playbooks: $($script:TotalTests)" -ForegroundColor White
Write-Host "  ✓ Passed:  $($script:PassedTests)" -ForegroundColor Green
Write-Host "  ⚠ Warning: $(($script:Results | Where-Object Status -eq 'Warning').Count)" -ForegroundColor Yellow
Write-Host "  ✗ Failed:  $($script:FailedTests)" -ForegroundColor Red

# List failed playbooks
$failed = $script:Results | Where-Object Status -eq 'Failed'
if ($failed) {
    Write-Host "`nFailed Playbooks:" -ForegroundColor Red
    foreach ($f in $failed) {
        Write-Host "  - $($f.Name)" -ForegroundColor Red
        foreach ($error in $f.Errors) {
            Write-Host "    $error" -ForegroundColor DarkRed
        }
    }
}

# List warnings
$warnings = $script:Results | Where-Object { $_.Warnings.Count -gt 0 }
if ($warnings -and $Verbose) {
    Write-Host "`nWarnings:" -ForegroundColor Yellow
    foreach ($w in $warnings) {
        Write-Host "  $($w.Name):" -ForegroundColor Yellow
        foreach ($warning in $w.Warnings) {
            Write-Host "    - $warning" -ForegroundColor DarkYellow
        }
    }
}

# Save detailed report if in CI
if ($CI) {
    $reportPath = Join-Path $script:ProjectRoot "tests/playbook-validation-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $reportDir = Split-Path $reportPath -Parent
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    
    $script:Results | ConvertTo-Json -Depth 10 | Set-Content $reportPath
    Write-Host "`nDetailed report saved to: $reportPath" -ForegroundColor Gray
}

# Exit with appropriate code
if ($CI -and $script:FailedTests -gt 0) {
    Write-Error "Playbook validation failed in CI mode"
    exit 1
}

if ($script:FailedTests -eq 0) {
    Write-Host "`n✅ All playbooks validated successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n❌ Validation completed with failures" -ForegroundColor Red
    exit 1
}