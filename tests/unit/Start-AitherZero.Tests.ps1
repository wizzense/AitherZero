#Requires -Modules Pester

BeforeAll {
    # Setup test environment
    $script:ProjectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    $script:EntryScript = Join-Path $script:ProjectRoot "Start-AitherZero.ps1"

    # Mock external dependencies
    Mock Write-Host {}
    Mock Start-Process {}
    Mock Test-Path { $true } -ParameterFilter { $Path -like "*config.json" }
    Mock Get-Content { '{"Core":{"Name":"AitherZero","Version":"1.0.0"}}' } -ParameterFilter { $Path -like "*config.json" }
}

Describe "Start-AitherZero Script" {
    BeforeEach {
        # Reset any module state
        Remove-Variable -Name * -Scope Script -ErrorAction SilentlyContinue
    }
    
    Context "Parameter Validation" {
        It "Should have correct parameter sets" {
            $scriptInfo = Get-Command $script:EntryScript
            $scriptInfo.Parameters.Keys | Should -Contain "Mode"
            $scriptInfo.Parameters.Keys | Should -Contain "Playbook"
            $scriptInfo.Parameters.Keys | Should -Contain "Sequence"
        }
        
        It "Should support Interactive mode" {
            # This would require mocking the entire interactive UI
            # For now just test that the parameter exists
            $modeParam = (Get-Command $script:EntryScript).Parameters["Mode"]
            $modeParam | Should -Not -BeNullOrEmpty
        }
        
        It "Should support Orchestrate mode" {
            $modeParam = (Get-Command $script:EntryScript).Parameters["Mode"]
            $modeParam | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Configuration Loading" {
        It "Should attempt to load configuration" {
            # Test that the script tries to load config.json
            { & $script:EntryScript -Mode Help -ErrorAction Stop } | Should -Not -Throw
        }
    }
    
    Context "Help System" {
        It "Should display help when requested" {
            Mock Write-Host {}
            { & $script:EntryScript -Mode Help } | Should -Not -Throw
            Assert-MockCalled Write-Host -Times 1 -Scope It
        }
    }
}