#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Example script demonstrating automated test generation for automation scripts
.DESCRIPTION
    Shows how to use the TestGenerator module to auto-generate unit tests
    for any automation script in the automation-scripts directory.
#>

param(
    [string]$ScriptNumber = "0218"
)

# Initialize environment
$ProjectRoot = Split-Path $PSScriptRoot -Parent

# Import the test generator module
Import-Module "$ProjectRoot/domains/testing/TestGenerator.psm1" -Force

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "AitherZero Test Generation Example" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Example 1: Generate test for a single script
Write-Host "Example 1: Generating test for script $ScriptNumber" -ForegroundColor Yellow
Write-Host "------------------------------------------------" -ForegroundColor Yellow

$scriptPath = Get-ChildItem "$ProjectRoot/automation-scripts" -Filter "${ScriptNumber}_*.ps1" | Select-Object -First 1

if ($scriptPath) {
    Write-Host "Found script: $($scriptPath.Name)" -ForegroundColor Green
    
    # Generate unit test with mocks
    $result = New-AutomationScriptTest -ScriptPath $scriptPath.FullName -IncludeMocks -IncludeIntegration
    
    if ($result.Success) {
        Write-Host "`n✓ Unit test generated: $($result.TestPath)" -ForegroundColor Green
        
        if ($result.IntegrationPath) {
            Write-Host "✓ Integration test generated: $($result.IntegrationPath)" -ForegroundColor Green
        }
        
        # Show a preview of the generated test
        Write-Host "`nTest file preview:" -ForegroundColor Cyan
        Write-Host "==================" -ForegroundColor Cyan
        Get-Content $result.TestPath -First 50 | ForEach-Object { Write-Host $_ }
        Write-Host "... (truncated)" -ForegroundColor DarkGray
    }
} else {
    Write-Host "Script not found for number: $ScriptNumber" -ForegroundColor Red
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Example 2: Batch Test Generation" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nTo generate tests for all scripts in a range, run:" -ForegroundColor White
Write-Host '  New-AllAutomationTests -Filter "02*" -IncludeMocks' -ForegroundColor Green
Write-Host "`nThis would generate tests for all 0200-0299 scripts`n" -ForegroundColor DarkGray

Write-Host "To generate tests for ALL automation scripts:" -ForegroundColor White
Write-Host '  New-AllAutomationTests -IncludeMocks -Force' -ForegroundColor Green
Write-Host "`n(Use -Force to overwrite existing tests)`n" -ForegroundColor DarkGray

# Example 3: Run the generated test
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Example 3: Running Generated Tests" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

if ($result -and $result.Success -and (Test-Path $result.TestPath)) {
    Write-Host "`nRunning the generated test..." -ForegroundColor Yellow
    
    # Check if Pester is available
    if (Get-Module -ListAvailable -Name Pester) {
        Import-Module Pester
        
        # Run the test
        $testResult = Invoke-Pester -Path $result.TestPath -PassThru -Show None
        
        Write-Host "`nTest Results:" -ForegroundColor Cyan
        Write-Host "  Total: $($testResult.TotalCount)"
        Write-Host "  Passed: $($testResult.PassedCount)" -ForegroundColor Green
        Write-Host "  Failed: $($testResult.FailedCount)" -ForegroundColor $(if ($testResult.FailedCount -gt 0) { 'Red' } else { 'Green' })
        Write-Host "  Skipped: $($testResult.SkippedCount)" -ForegroundColor Yellow
    } else {
        Write-Host "Pester module not found. Install with: Install-Module -Name Pester -Force" -ForegroundColor Yellow
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Advanced Features" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

Write-Host @"

The TestGenerator module provides intelligent test generation:

1. **Parameter Analysis**: Automatically detects script parameters and generates appropriate tests
2. **Mock Generation**: Creates mocks for external commands (use -IncludeMocks)
3. **Integration Tests**: Generates integration test stubs (use -IncludeIntegration)
4. **Syntax Validation**: Tests for valid PowerShell syntax
5. **Metadata Extraction**: Reads Stage, Dependencies, and Description from script comments
6. **Function Detection**: Identifies internal functions and generates tests for them
7. **External Command Detection**: Identifies external commands that may need mocking

Usage from PowerShell:
"@ -ForegroundColor White

Write-Host @'

# Import the module
Import-Module ./domains/testing/TestGenerator.psm1

# Generate test for single script
New-AutomationScriptTest -ScriptPath "./automation-scripts/0402_Run-UnitTests.ps1" -IncludeMocks

# Generate tests for multiple scripts
Get-ChildItem ./automation-scripts -Filter "04*.ps1" | New-AutomationScriptTest -IncludeMocks

# Generate all tests with overwrite
New-AllAutomationTests -Force -IncludeMocks

'@ -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Integration with CI/CD" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

Write-Host @"

Add to your CI/CD pipeline:

  # Generate missing tests
  Import-Module ./domains/testing/TestGenerator.psm1
  New-AllAutomationTests
  
  # Run all generated tests
  Invoke-Pester -Path "./tests/unit/automation-scripts" -OutputFile TestResults.xml

"@ -ForegroundColor White

Write-Host "`nScript completed successfully!`n" -ForegroundColor Green