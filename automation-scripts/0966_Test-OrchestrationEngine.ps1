#Requires -Version 7.0

<#
.SYNOPSIS
    Test OrchestrationEngine functionality
.DESCRIPTION
    Validates OrchestrationEngine before committing changes:
    - Function exports
    - Playbook loading
    - Sequence extraction
    - Dry run execution
.EXAMPLE
    ./automation-scripts/0966_Test-OrchestrationEngine.ps1
#>

[CmdletBinding()]
param()

Write-Host "=== Testing OrchestrationEngine ===" -ForegroundColor Cyan
Write-Host ""

$ErrorCount = 0
$SuccessCount = 0

# Test 1: Module Loading
Write-Host "1. Testing module loading..." -ForegroundColor Yellow
try {
    Import-Module ./AitherZero.psd1 -Force -ErrorAction Stop
    Write-Host "   ✓ Module loaded" -ForegroundColor Green
    $SuccessCount++
} catch {
    Write-Host "   ✗ Module failed to load: $_" -ForegroundColor Red
    $ErrorCount++
    exit 1
}

# Test 2: Function Exports
Write-Host ""
Write-Host "2. Testing function exports..." -ForegroundColor Yellow
$RequiredFunctions = @(
    'Invoke-OrchestrationSequence',
    'Invoke-ParallelOrchestration',
    'Invoke-SequentialOrchestration',
    'Get-OrchestrationPlaybook'
)

foreach ($func in $RequiredFunctions) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        Write-Host "   ✓ $func exported" -ForegroundColor Green
        $SuccessCount++
    } else {
        Write-Host "   ✗ $func NOT exported" -ForegroundColor Red
        $ErrorCount++
    }
}

# Test 3: Playbook Loading
Write-Host ""
Write-Host "3. Testing playbook loading..." -ForegroundColor Yellow
$TestPlaybooks = @('test-orchestration', 'pr-validation-fast')

foreach ($playbookName in $TestPlaybooks) {
    try {
        $playbook = Get-OrchestrationPlaybook -Name $playbookName
        if ($playbook) {
            Write-Host "   ✓ $playbookName loaded" -ForegroundColor Green
            $SuccessCount++
        } else {
            Write-Host "   ✗ $playbookName returned null" -ForegroundColor Red
            $ErrorCount++
        }
    } catch {
        Write-Host "   ✗ $playbookName failed: $_" -ForegroundColor Red
        $ErrorCount++
    }
}

# Test 4: Dry Run Execution
Write-Host ""
Write-Host "4. Testing dry run execution..." -ForegroundColor Yellow
try {
    $result = Invoke-OrchestrationSequence -LoadPlaybook 'test-orchestration' -DryRun -ErrorAction Stop
    Write-Host "   ✓ Dry run completed" -ForegroundColor Green
    $SuccessCount++
} catch {
    Write-Host "   ✗ Dry run failed: $_" -ForegroundColor Red
    $ErrorCount++
}

# Test 5: Sequence Extraction
Write-Host ""
Write-Host "5. Testing sequence extraction..." -ForegroundColor Yellow
try {
    $playbook = Get-OrchestrationPlaybook -Name 'pr-validation-fast'
    # This playbook has script definitions (hashtables), test conversion happens in main function
    if ($playbook.Sequence -and $playbook.Sequence.Count -gt 0) {
        Write-Host "   ✓ Sequence extracted ($($playbook.Sequence.Count) items)" -ForegroundColor Green
        $SuccessCount++
    } else {
        Write-Host "   ✗ Sequence empty or null" -ForegroundColor Red
        $ErrorCount++
    }
} catch {
    Write-Host "   ✗ Sequence extraction failed: $_" -ForegroundColor Red
    $ErrorCount++
}

# Summary
Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Passed: $SuccessCount" -ForegroundColor Green
Write-Host "Failed: $ErrorCount" -ForegroundColor $(if ($ErrorCount -gt 0) { 'Red' } else { 'Green' })

if ($ErrorCount -gt 0) {
    Write-Host ""
    Write-Host "TESTS FAILED - Fix errors before committing" -ForegroundColor Red
    exit 1
} else {
    Write-Host ""
    Write-Host "ALL TESTS PASSED ✓" -ForegroundColor Green
    exit 0
}
