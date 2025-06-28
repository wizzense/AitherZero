BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot "../../../aither-core/modules/RemoteConnection"
    Import-Module $modulePath -Force
}

Describe "RemoteConnection Module Tests" {
    Context "Module Import" {
        It "Should import RemoteConnection module successfully" {
            Get-Module RemoteConnection | Should -Not -BeNullOrEmpty
        }
        
        It "Should export expected functions" {
            $expectedFunctions = @(
                'Connect-RemoteEndpoint',
                'Disconnect-RemoteEndpoint', 
                'Get-RemoteConnection',
                'Invoke-RemoteCommand',
                'New-RemoteConnection'
            )
            
            $exportedFunctions = (Get-Module RemoteConnection).ExportedFunctions.Keys
            foreach ($func in $expectedFunctions) {
                $exportedFunctions | Should -Contain $func
            }
        }
    }
    
    Context "Get-RemoteConnection Function" {
        It "Should not throw when called without parameters" {
            { Get-RemoteConnection } | Should -Not -Throw
        }
        
        It "Should return array when no specific connection requested" {
            $result = Get-RemoteConnection
            $result | Should -BeOfType [array]
        }
    }
    
    Context "New-RemoteConnection Function" {
        It "Should exist and be callable" {
            Get-Command New-RemoteConnection | Should -Not -BeNullOrEmpty
        }
    }
}