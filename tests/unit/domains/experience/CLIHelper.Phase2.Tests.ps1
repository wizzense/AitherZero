#Requires -Version 7.0

BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot "../../../../domains/experience/CLIHelper.psm1"
    Import-Module $modulePath -Force
}

Describe "Quality of Life Features - Phase 2 (Features 6-10)" {
    
    Context "Prerequisites Check (Feature 6)" {
        It "Should check prerequisites for a script" {
            $prereqs = Test-Prerequisites -ScriptNumber "0402"
            $prereqs | Should -Not -BeNullOrEmpty
            $prereqs.Overall | Should -BeOfType [bool]
            $prereqs.Checks | Should -Not -BeNullOrEmpty
        }
        
        It "Should validate PowerShell version" {
            $prereqs = Test-Prerequisites -ScriptNumber "0402"
            $psCheck = $prereqs.Checks | Where-Object { $_.Name -match "PowerShell" }
            $psCheck | Should -Not -BeNullOrEmpty
            $psCheck.Status | Should -Be $true
        }
        
        It "Should display prerequisite status without throwing" {
            { Show-PrerequisiteStatus -ScriptNumber "0402" 6>$null } | Should -Not -Throw
        }
    }
    
    Context "Execution History (Feature 7)" {
        It "Should add execution to history" {
            $start = Get-Date
            $end = $start.AddSeconds(5)
            
            { Add-ExecutionHistory -ScriptNumber "0402" -ScriptName "Test Script" -StartTime $start -EndTime $end -Status "Success" } | Should -Not -Throw
        }
        
        It "Should retrieve execution history" {
            $start = Get-Date
            $end = $start.AddSeconds(3)
            
            Add-ExecutionHistory -ScriptNumber "0404" -ScriptName "Test Script 2" -StartTime $start -EndTime $end -Status "Success"
            
            $history = Get-ExecutionHistory -Count 5
            $history | Should -Not -BeNullOrEmpty
        }
        
        It "Should filter history by script number" {
            $start = Get-Date
            $end = $start.AddSeconds(2)
            
            Add-ExecutionHistory -ScriptNumber "0407" -ScriptName "Test Script 3" -StartTime $start -EndTime $end -Status "Success"
            
            $history = Get-ExecutionHistory -ScriptNumber "0407" -Count 5
            $history | Should -Not -BeNullOrEmpty
            $history[0].ScriptNumber | Should -Be "0407"
        }
        
        It "Should display execution history without throwing" {
            { Show-ExecutionHistory -ScriptNumber "0402" -Count 3 6>$null } | Should -Not -Throw
        }
    }
    
    Context "Command History Export (Feature 9)" {
        BeforeAll {
            $testFile = Join-Path $TestDrive "test-export.ps1"
        }
        
        It "Should export command history to file" {
            # Add some test actions first
            Add-RecentAction -Name "Test 1" -Command "./Start-AitherZero.ps1 -Mode Run -Target 0402" -Type "Script"
            Add-RecentAction -Name "Test 2" -Command "./Start-AitherZero.ps1 -Mode Run -Target 0404" -Type "Script"
            
            $result = Export-CommandHistory -OutputPath $testFile -Count 5
            $result | Should -Be $true
            Test-Path $testFile | Should -Be $true
        }
        
        It "Should include commands in exported file" {
            $testFile2 = Join-Path $TestDrive "test-export2.ps1"
            Add-RecentAction -Name "Test 3" -Command "./Start-AitherZero.ps1 -Mode Run -Target 0407" -Type "Script"
            
            Export-CommandHistory -OutputPath $testFile2 -Count 5 | Out-Null
            
            $content = Get-Content $testFile2 -Raw
            $content | Should -Match "Start-AitherZero.ps1"
        }
        
        It "Should include comments when requested" {
            $testFile3 = Join-Path $TestDrive "test-export3.ps1"
            
            Export-CommandHistory -OutputPath $testFile3 -Count 5 -IncludeComments | Out-Null
            
            $content = Get-Content $testFile3 -Raw
            $content | Should -Match "#"
        }
    }
    
    Context "Profile Switcher (Feature 10)" {
        It "Should get current profile" {
            $profile = Get-AitherZeroProfile
            $profile | Should -Not -BeNullOrEmpty
            $profile | Should -BeIn @('Minimal', 'Standard', 'Developer', 'Full', 'Unknown')
        }
        
        It "Should validate profile names" {
            { Switch-AitherZeroProfile -Profile "InvalidProfile" } | Should -Throw
        }
        
        It "Should accept valid profile names" {
            $validProfiles = @('Minimal', 'Standard', 'Developer', 'Full')
            foreach ($prof in $validProfiles) {
                { [void](Switch-AitherZeroProfile -Profile $prof -ErrorAction SilentlyContinue) } | Should -Not -Throw
            }
        }
    }
    
    Context "Module Exports" {
        It "Should export Test-Prerequisites" {
            Get-Command Test-Prerequisites -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Show-PrerequisiteStatus" {
            Get-Command Show-PrerequisiteStatus -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Get-ExecutionHistory" {
            Get-Command Get-ExecutionHistory -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Add-ExecutionHistory" {
            Get-Command Add-ExecutionHistory -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Show-ExecutionHistory" {
            Get-Command Show-ExecutionHistory -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Export-CommandHistory" {
            Get-Command Export-CommandHistory -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Switch-AitherZeroProfile" {
            Get-Command Switch-AitherZeroProfile -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Get-AitherZeroProfile" {
            Get-Command Get-AitherZeroProfile -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Phase 2 Integration Tests" {
    
    Context "Prerequisites Integration" {
        It "Should return structured prerequisite data" {
            $prereqs = Test-Prerequisites -ScriptNumber "0402"
            $prereqs.PSObject.Properties.Name | Should -Contain "Overall"
            $prereqs.PSObject.Properties.Name | Should -Contain "Checks"
        }
        
        It "Should include required checks" {
            $prereqs = Test-Prerequisites -ScriptNumber "0402"
            $requiredChecks = $prereqs.Checks | Where-Object { $_.Required }
            $requiredChecks | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "History Tracking Integration" {
        It "Should persist history across calls" {
            $start = Get-Date
            $end = $start.AddSeconds(1)
            
            Add-ExecutionHistory -ScriptNumber "0510" -ScriptName "Report Test" -StartTime $start -EndTime $end -Status "Success"
            
            $history = Get-ExecutionHistory -ScriptNumber "0510" -Count 1
            $history[0].ScriptNumber | Should -Be "0510"
            $history[0].Status | Should -Be "Success"
        }
        
        It "Should calculate duration correctly" {
            $start = Get-Date
            $end = $start.AddSeconds(10)
            
            Add-ExecutionHistory -ScriptNumber "0520" -ScriptName "Duration Test" -StartTime $start -EndTime $end -Status "Success"
            
            $history = Get-ExecutionHistory -ScriptNumber "0520" -Count 1
            $history[0].Duration | Should -BeGreaterThan 9
            $history[0].Duration | Should -BeLessThan 11
        }
    }
    
    Context "End-to-End Workflow" {
        It "Should support complete workflow: check→execute→track→export" {
            # 1. Check prerequisites
            $prereqs = Test-Prerequisites -ScriptNumber "0402"
            $prereqs | Should -Not -BeNullOrEmpty
            
            # 2. Track execution
            $start = Get-Date
            $end = $start.AddSeconds(2)
            Add-ExecutionHistory -ScriptNumber "0402" -ScriptName "Workflow Test" -StartTime $start -EndTime $end -Status "Success"
            
            # 3. Add to recent actions
            Add-RecentAction -Name "Workflow Test" -Command "./Start-AitherZero.ps1 -Mode Run -Target 0402" -Type "Script"
            
            # 4. Export history
            $exportFile = Join-Path $TestDrive "workflow-test.ps1"
            $result = Export-CommandHistory -OutputPath $exportFile -Count 5
            
            # Verify all steps
            $result | Should -Be $true
            Test-Path $exportFile | Should -Be $true
        }
    }
}
