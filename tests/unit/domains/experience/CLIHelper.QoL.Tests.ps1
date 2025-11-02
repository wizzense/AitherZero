#Requires -Version 7.0

BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot "../../../../domains/experience/CLIHelper.psm1"
    Import-Module $modulePath -Force
}

Describe "Quality of Life Features" {
    
    Context "Smart Search" {
        It "Should search and find scripts" {
            $results = Search-AitherZeroResources -Query "040" -MaxResults 5
            $results | Should -Not -BeNullOrEmpty
            $results[0].Type | Should -BeIn @('Script', 'Playbook')
        }
        
        It "Should limit results to MaxResults" {
            $results = Search-AitherZeroResources -Query "test" -MaxResults 3
            $results.Count | Should -BeLessOrEqual 3
        }
        
        It "Should handle no results gracefully" {
            $results = Search-AitherZeroResources -Query "XyZzZqQqQ12345"
            $results | Should -BeNullOrEmpty
        }
    }
    
    Context "Recent Actions" {
        It "Should add action to history" {
            { Add-RecentAction -Name "Test Action" -Command "./Start-AitherZero.ps1 -Mode Run -Target 0402" -Type "Script" } | Should -Not -Throw
        }
        
        It "Should retrieve recent actions" {
            Add-RecentAction -Name "Test Action 1" -Command "./Start-AitherZero.ps1 -Mode Run -Target 0402" -Type "Script"
            Add-RecentAction -Name "Test Action 2" -Command "./Start-AitherZero.ps1 -Mode Run -Target 0404" -Type "Script"
            
            $recent = Get-RecentActions -Count 5
            $recent | Should -Not -BeNullOrEmpty
            $recent.Count | Should -BeGreaterThan 0
        }
    }
    
    Context "Script Metadata" {
        It "Should retrieve metadata for valid script" {
            $metadata = Get-ScriptMetadata -ScriptNumber "0402"
            $metadata | Should -Not -BeNullOrEmpty
            $metadata.Number | Should -Be "0402"
            $metadata.Category | Should -Not -BeNullOrEmpty
        }
        
        It "Should return null for invalid script" {
            $metadata = Get-ScriptMetadata -ScriptNumber "8888"
            $metadata | Should -BeNullOrEmpty
        }
        
        It "Should parse script properties" {
            $metadata = Get-ScriptMetadata -ScriptNumber "0402"
            $metadata.Name | Should -Match "\.ps1$"
            $metadata.Path | Should -Exist
            $metadata.Category | Should -Be "Testing & Validation"
        }
    }
    
    Context "Quick Jump" {
        It "Should display script info without throwing" {
            { Invoke-QuickJump -ScriptNumber "0402" -ShowInfo 6>$null } | Should -Not -Throw
        }
        
        It "Should return metadata for valid script" {
            $result = Invoke-QuickJump -ScriptNumber "0402" -ShowInfo 6>$null
            $result | Should -Not -BeNullOrEmpty
            $result.Number | Should -Be "0402"
        }
        
        It "Should handle invalid script gracefully" {
            $result = Invoke-QuickJump -ScriptNumber "8888" -ShowInfo 6>$null
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context "Inline Help" {
        It "Should display help without throwing" {
            { Show-InlineHelp -Topic "Test" -Type "Menu" 6>$null } | Should -Not -Throw
        }
        
        It "Should support different help types" {
            { Show-InlineHelp -Topic "0402" -Type "Script" 6>$null } | Should -Not -Throw
            { Show-InlineHelp -Topic "Interactive" -Type "Command" 6>$null } | Should -Not -Throw
            { Show-InlineHelp -Topic "General" -Type "Menu" 6>$null } | Should -Not -Throw
        }
    }
    
    Context "Module Exports" {
        It "Should export Search-AitherZeroResources" {
            Get-Command Search-AitherZeroResources -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Get-RecentActions" {
            Get-Command Get-RecentActions -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Add-RecentAction" {
            Get-Command Add-RecentAction -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Get-ScriptMetadata" {
            Get-Command Get-ScriptMetadata -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Invoke-QuickJump" {
            Get-Command Invoke-QuickJump -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Show-InlineHelp" {
            Get-Command Show-InlineHelp -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Quality of Life Integration" {
    
    Context "Search Integration" {
        It "Should find scripts by number pattern" {
            $results = Search-AitherZeroResources -Query "040" -Type "Scripts"
            $results | Should -Not -BeNullOrEmpty
            $results[0].Type | Should -Be "Script"
        }
        
        It "Should search only specified type" {
            $scriptResults = Search-AitherZeroResources -Query "test" -Type "Scripts" -MaxResults 5
            $scriptResults | ForEach-Object { $_.Type | Should -Be "Script" }
        }
    }
    
    Context "Metadata Integration" {
        It "Should provide complete script information" {
            $metadata = Get-ScriptMetadata -ScriptNumber "0402"
            $metadata.Name | Should -Not -BeNullOrEmpty
            $metadata.Category | Should -Not -BeNullOrEmpty
            $metadata.Path | Should -Exist
        }
    }
    
    Context "History Integration" {
        It "Should persist actions across calls" {
            Add-RecentAction -Name "Integration Test" -Command "./Start-AitherZero.ps1 -Mode Run -Target 0402" -Type "Script"
            
            $actions = Get-RecentActions -Count 1
            $actions[0].Name | Should -Be "Integration Test"
        }
    }
}
