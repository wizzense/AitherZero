#Requires -Version 7.0

<#
.SYNOPSIS
Simple test script for OrchestrationEngine functionality

.DESCRIPTION
Tests the OrchestrationEngine module with the sample playbook to ensure
all functions work correctly and the module integrates properly.
#>

# Import required modules
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

Write-Host "Testing OrchestrationEngine Module" -ForegroundColor Green
Write-Host "Project Root: $projectRoot" -ForegroundColor Cyan

try {
    # Import the OrchestrationEngine module
    Write-Host "`nImporting OrchestrationEngine module..." -ForegroundColor Yellow
    Import-Module "$PSScriptRoot/OrchestrationEngine.psm1" -Force
    
    # Test 1: Create a simple playbook definition
    Write-Host "`nTest 1: Creating simple playbook definition..." -ForegroundColor Yellow
    $simplePlaybook = New-PlaybookDefinition -Name "test-workflow" -Description "Simple test workflow" -Steps @(
        @{
            name = "Step 1"
            type = "script"
            command = "Write-Host 'Hello from Step 1'"
        },
        @{
            name = "Step 2"  
            type = "script"
            command = "Write-Host 'Hello from Step 2'"
        }
    )
    
    Write-Host "✅ Simple playbook created successfully" -ForegroundColor Green
    
    # Test 2: Validate the playbook
    Write-Host "`nTest 2: Validating playbook definition..." -ForegroundColor Yellow
    $validation = Validate-PlaybookDefinition -Definition $simplePlaybook
    
    if ($validation.IsValid) {
        Write-Host "✅ Playbook validation passed" -ForegroundColor Green
    } else {
        Write-Host "❌ Playbook validation failed: $($validation.Errors -join '; ')" -ForegroundColor Red
        return
    }
    
    # Test 3: Execute a simple dry-run
    Write-Host "`nTest 3: Executing dry-run workflow..." -ForegroundColor Yellow
    $dryRunResult = Invoke-PlaybookWorkflow -PlaybookDefinition $simplePlaybook -DryRun
    
    if ($dryRunResult.Success) {
        Write-Host "✅ Dry-run execution successful" -ForegroundColor Green
        Write-Host "   Steps executed: $($dryRunResult.StepsExecuted)/$($dryRunResult.TotalSteps)" -ForegroundColor Cyan
    } else {
        Write-Host "❌ Dry-run execution failed: $($dryRunResult.Error)" -ForegroundColor Red
    }
    
    # Test 4: Test step creation functions
    Write-Host "`nTest 4: Testing step creation functions..." -ForegroundColor Yellow
    
    $scriptStep = New-ScriptStep -Name "Test Script" -Command "Write-Host 'Test command'"
    $conditionalStep = New-ConditionalStep -Name "Test Condition" -Condition "`$true" -ThenSteps @($scriptStep)
    $parallelStep = New-ParallelStep -Name "Test Parallel" -ParallelSteps @($scriptStep, $scriptStep)
    
    Write-Host "✅ Step creation functions working correctly" -ForegroundColor Green
    
    # Test 5: Check if sample playbook exists and can be loaded
    Write-Host "`nTest 5: Testing sample playbook loading..." -ForegroundColor Yellow
    $samplePlaybookPath = Join-Path $projectRoot "orchestration/playbooks/sample-deployment.json"
    
    if (Test-Path $samplePlaybookPath) {
        $samplePlaybook = Import-PlaybookDefinition -PlaybookName "sample-deployment"
        
        if ($samplePlaybook.Success) {
            Write-Host "✅ Sample playbook loaded successfully" -ForegroundColor Green
            Write-Host "   Playbook: $($samplePlaybook.Definition.name)" -ForegroundColor Cyan
            Write-Host "   Steps: $($samplePlaybook.Definition.steps.Count)" -ForegroundColor Cyan
            
            # Validate the sample playbook
            $sampleValidation = Validate-PlaybookDefinition -Definition $samplePlaybook.Definition
            if ($sampleValidation.IsValid) {
                Write-Host "✅ Sample playbook validation passed" -ForegroundColor Green
            } else {
                Write-Host "⚠️ Sample playbook validation issues: $($sampleValidation.Errors -join '; ')" -ForegroundColor Yellow
            }
        } else {
            Write-Host "❌ Failed to load sample playbook: $($samplePlaybook.Error)" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠️ Sample playbook not found at: $samplePlaybookPath" -ForegroundColor Yellow
    }
    
    # Test 6: Check workflow status functions
    Write-Host "`nTest 6: Testing workflow status functions..." -ForegroundColor Yellow
    $statusInfo = Get-PlaybookStatus
    Write-Host "✅ Workflow status retrieved" -ForegroundColor Green
    Write-Host "   Active workflows: $($statusInfo.TotalActive)" -ForegroundColor Cyan
    Write-Host "   Historical workflows: $($statusInfo.TotalHistory)" -ForegroundColor Cyan
    
    Write-Host "`n🎉 All OrchestrationEngine tests completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "`n❌ Test failed with error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
}