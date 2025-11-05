#Requires -Version 7.0

<#
.SYNOPSIS
    Tests to verify the infinite loop fix in OrchestrationEngine
.DESCRIPTION
    Regression test for the infinite loop bug where scripts would execute
    indefinitely when succeeding on first attempt with maxRetries=0.
    
    Bug: Scripts would execute infinitely (233+ times in 10 seconds observed)
    Root Cause: while loop condition never exited when script succeeded on first try
    Fix: Modified while loop condition and moved $retryCount increment before try block
#>

BeforeAll {
    # Import the module
    $ProjectRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
    Import-Module (Join-Path $ProjectRoot 'AitherZero.psd1') -Force
}

Describe 'OrchestrationEngine Infinite Loop Fix' {
    
    It 'Should complete playbook execution without infinite loop' {
        # Before fix: Scripts would execute infinitely (233+ times in 10 seconds)
        # After fix: Each script executes exactly once and playbook completes normally
        
        # Act - test-quick has 3 scripts and should complete in < 10 seconds
        $job = Start-ThreadJob -ScriptBlock {
            param($projRoot)
            Import-Module (Join-Path $projRoot 'AitherZero.psd1') -Force
            Invoke-OrchestrationSequence -LoadPlaybook 'test-quick'
        } -ArgumentList $ProjectRoot
        
        # Wait max 30 seconds for test-quick (normally ~5 seconds)
        $completed = Wait-Job -Job $job -Timeout 30
        
        # Assert - job should complete (not timeout)
        $completed | Should -Not -BeNullOrEmpty -Because 'playbook should complete without hanging in infinite loop'
        
        $result = Receive-Job -Job $job
        Remove-Job -Job $job -Force
        
        # Assert - valid result returned
        $result | Should -Not -BeNullOrEmpty
        $result.Total | Should -BeGreaterThan 0
        # All scripts should execute exactly once (Total = Completed + Failed)
        $result.Total | Should -Be ($result.Completed + $result.Failed) -Because 'each script should execute exactly once, not loop infinitely'
    }
}
