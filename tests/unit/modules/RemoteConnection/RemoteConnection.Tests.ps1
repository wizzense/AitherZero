#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Pester tests for the RemoteConnection module.

.DESCRIPTION
    Comprehensive unit tests for the RemoteConnection module functionality
    using the project's TestingFramework.
#>

BeforeAll {
    # Import required modules
    Import-Module './aither-core/modules/Logging/Logging.psm1' -Force
    Import-Module './aither-core/modules/TestingFramework/TestingFramework.psm1' -Force
    Import-Module './aither-core/modules/SecureCredentials/SecureCredentials.psm1' -Force
    Import-Module './aither-core/modules/RemoteConnection/RemoteConnection.psm1' -Force
    
    # Set test environment
    $TestConnectionName = "Test-RemoteConnection-$(Get-Random)"
}

Describe "RemoteConnection Module" {
    Context "Module Loading" {
        It "Should load the RemoteConnection module successfully" {
            Get-Module RemoteConnection | Should -Not -BeNullOrEmpty
        }

        It "Should export required functions" {
            $expectedFunctions = @(
                'New-RemoteConnection',
                'Connect-RemoteEndpoint',
                'Disconnect-RemoteEndpoint',
                'Test-RemoteConnection',
                'Get-RemoteConnection',
                'Remove-RemoteConnection'
            )

            foreach ($function in $expectedFunctions) {
                Get-Command $function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }        }
    }

    Context "New-RemoteConnection Function" {
        It "Should create SSH connection with WhatIf" {
            $result = New-RemoteConnection -ConnectionName $TestConnectionName -EndpointType SSH -HostName "test.example.com" -CredentialName "Test-Credential" -WhatIf
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }

        It "Should create WinRM connection with WhatIf" {
            $result = New-RemoteConnection -ConnectionName "Test-WinRM" -EndpointType WinRM -HostName "test.example.com" -CredentialName "Test-Credential" -WhatIf
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }

        It "Should create VMware connection with WhatIf" {
            $result = New-RemoteConnection -ConnectionName "Test-VMware" -EndpointType VMware -HostName "test.example.com" -CredentialName "Test-Credential" -WhatIf
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }

        It "Should validate required parameters" {
            { New-RemoteConnection -ConnectionName "" -EndpointType SSH -HostName "test.com" } | Should -Throw
        }

        It "Should support different endpoint types" {
            $validTypes = @('SSH', 'WinRM', 'VMware', 'Hyper-V', 'Docker', 'Kubernetes')
            
            foreach ($type in $validTypes) {
                { New-RemoteConnection -ConnectionName "Test-$type" -EndpointType $type -HostName "test.com" -WhatIf } | Should -Not -Throw
            }
        }
    }

    Context "Connect-RemoteEndpoint Function" {
        It "Should handle non-existent connections gracefully" {
            $result = Connect-RemoteEndpoint -ConnectionName "NonExistent-$(Get-Random)" -WhatIf
            
            $result.Success | Should -Be $false
        }

        It "Should validate connection name parameter" {
            { Connect-RemoteEndpoint -ConnectionName "" } | Should -Throw
        }
    }

    Context "Test-RemoteConnection Function" {
        It "Should validate connection existence" {
            $result = Test-RemoteConnection -ConnectionName "NonExistent-$(Get-Random)"
            
            $result | Should -Be $false
        }

        It "Should handle empty connection names" {
            { Test-RemoteConnection -ConnectionName "" } | Should -Throw
        }
    }

    Context "Get-RemoteConnection Function" {
        It "Should handle non-existent connections" {
            $result = Get-RemoteConnection -ConnectionName "NonExistent-$(Get-Random)"
            
            $result | Should -BeNullOrEmpty
        }

        It "Should list all connections when no name specified" {
            $result = Get-RemoteConnection
            
            # Should return array even if empty
            $result | Should -BeOfType [System.Array]
        }
    }

    Context "Remove-RemoteConnection Function" {
        It "Should handle WhatIf parameter" {
            $result = Remove-RemoteConnection -ConnectionName "Test-Remove" -WhatIf
            
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should validate connection name parameter" {
            { Remove-RemoteConnection -ConnectionName "" } | Should -Throw
        }
    }

    Context "Disconnect-RemoteEndpoint Function" {
        It "Should handle WhatIf parameter" {
            $result = Disconnect-RemoteEndpoint -ConnectionName "Test-Disconnect" -WhatIf
            
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should validate connection name parameter" {
            { Disconnect-RemoteEndpoint -ConnectionName "" } | Should -Throw
        }
    }
}

Describe "RemoteConnection Integration" {
    Context "SecureCredentials Integration" {        It "Should integrate with SecureCredentials module" {
            # Test that RemoteConnection can reference SecureCredentials functions
            $testSecureCredentialExists = Get-Command -Name "Test-SecureCredential" -ErrorAction SilentlyContinue
            $newSecureCredentialExists = Get-Command -Name "New-SecureCredential" -ErrorAction SilentlyContinue
            
            # At least one SecureCredentials function should be available
            ($testSecureCredentialExists -or $newSecureCredentialExists) | Should -Be $true
            
            # Test that Test-SecureCredential function is available (integration dependency)
            $testSecureCredentialExists | Should -Not -BeNullOrEmpty
        }

        It "Should validate credential references" {
            # Test with non-existent credential
            $result = New-RemoteConnection -ConnectionName "Test-BadCred" -EndpointType SSH -HostName "test.com" -CredentialName "NonExistent-Credential" -WhatIf
            
            # Should still work in WhatIf mode
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Cross-Platform Compatibility" {
        It "Should work on Windows PowerShell" {
            if ($PSVersionTable.PSEdition -eq 'Desktop') {
                Get-Module RemoteConnection | Should -Not -BeNullOrEmpty
            }
        }

        It "Should work on PowerShell Core" {
            if ($PSVersionTable.PSEdition -eq 'Core') {
                Get-Module RemoteConnection | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Error Handling" {
        It "Should handle logging integration" {
            # Test that functions can call Write-CustomLog without errors
            $result = Test-RemoteConnection -ConnectionName "Test-Logging" -Verbose
            
            # Should not throw even if connection doesn't exist
            $result | Should -Be $false
        }
    }
}
