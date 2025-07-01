BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot "../../../aither-core/modules/PatchManager"
    Import-Module $modulePath -Force
}

Describe "PatchManager Module Tests" {
    Context "Module Import" {
        It "Should import PatchManager module successfully" {
            Get-Module PatchManager | Should -Not -BeNullOrEmpty
        }
        
        It "Should export core PatchManager functions" {
            $expectedFunctions = @(
                'Invoke-PatchWorkflow',
                'Invoke-PatchRollback',
                'New-PatchIssue',
                'New-PatchPR',
                'Show-GitStatusGuidance'
            )
            
            $exportedFunctions = (Get-Module PatchManager).ExportedFunctions.Keys
            foreach ($func in $expectedFunctions) {
                $exportedFunctions | Should -Contain $func -Because "Function $func should be exported"
            }
        }
    }
    
    Context "Show-GitStatusGuidance Function" {
        It "Should not throw when called" {
            { Show-GitStatusGuidance } | Should -Not -Throw
        }
        
        It "Should return boolean value" {
            $result = Show-GitStatusGuidance
            $result | Should -BeOfType [bool]
        }
    }
    
    Context "Git Integration" {
        It "Should handle git commands gracefully when not in git repo" {
            Push-Location $env:TEMP
            try {
                { Show-GitStatusGuidance } | Should -Not -Throw
            } finally {
                Pop-Location
            }
        }
    }
}