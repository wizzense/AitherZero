#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Pester tests for the SecureCredentials module.

.DESCRIPTION
    Comprehensive unit tests for the SecureCredentials module functionality
    using the project's TestingFramework.
#>

BeforeAll {
    # Import required modules
    Import-Module './aither-core/modules/Logging/Logging.psm1' -Force
    Import-Module './aither-core/modules/TestingFramework/TestingFramework.psm1' -Force
    Import-Module './aither-core/modules/SecureCredentials/SecureCredentials.psm1' -Force

    # Import test credential helper
    . "$PSScriptRoot/../../../helpers/Test-Credentials.ps1"

    # Set test environment
    $TestCredentialName = "Test-SecureCredentials-$(Get-Random)"
}

Describe "SecureCredentials Module" {
    Context "Module Loading" {
        It "Should load the SecureCredentials module successfully" {
            Get-Module SecureCredentials | Should -Not -BeNullOrEmpty
        }

        It "Should export required functions" {
            $expectedFunctions = @(
                'New-SecureCredential',
                'Get-SecureCredential',
                'Remove-SecureCredential',
                'Test-SecureCredential',
                'Export-SecureCredential',
                'Import-SecureCredential'
            )

            foreach ($function in $expectedFunctions) {
                Get-Command $function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }        }
    }

    Context "New-SecureCredential Function" {
        It "Should create a UserPassword credential with WhatIf" {
            $testPassword = Get-TestSecurePassword -Purpose 'UserPassword'
            $result = New-SecureCredential -CredentialName $TestCredentialName -CredentialType UserPassword -Username "testuser" -Password $testPassword -WhatIf

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }

        It "Should validate required parameters" {
            { New-SecureCredential -CredentialName "" -CredentialType UserPassword -Username "test" } | Should -Throw
        }

        It "Should support different credential types" {
            # Test UserPassword type with required parameters
            { New-SecureCredential -CredentialName "Test-UserPassword" -CredentialType UserPassword -Username "testuser" -Password (Get-TestSecurePassword -Purpose 'UserPassword') -WhatIf } | Should -Not -Throw

            # Test ServiceAccount type with required username
            { New-SecureCredential -CredentialName "Test-ServiceAccount" -CredentialType ServiceAccount -Username "service@example.com" -WhatIf } | Should -Not -Throw

            # Test APIKey type with required API key
            { New-SecureCredential -CredentialName "Test-APIKey" -CredentialType APIKey -APIKey "$(Get-TestCredential -CredentialType "ApiKey")" -WhatIf } | Should -Not -Throw

            # Test Certificate type with required certificate path
            { New-SecureCredential -CredentialName "Test-Certificate" -CredentialType Certificate -CertificatePath "C:\test\cert.pfx" -WhatIf } | Should -Not -Throw
        }
    }

    Context "Get-SecureCredential Function" {
        It "Should handle non-existent credentials gracefully" {
            $result = Get-SecureCredential -CredentialName "NonExistent-$(Get-Random)"

            $result | Should -BeNullOrEmpty
        }

        It "Should validate credential name parameter" {
            { Get-SecureCredential -CredentialName "" } | Should -Throw
        }
    }

    Context "Test-SecureCredential Function" {
        It "Should validate credential existence" {
            $result = Test-SecureCredential -CredentialName "NonExistent-$(Get-Random)"

            $result | Should -Be $false
        }

        It "Should handle empty credential names" {
            { Test-SecureCredential -CredentialName "" } | Should -Throw
        }
    }

    Context "Remove-SecureCredential Function" {
        It "Should handle WhatIf parameter" {
            $result = Remove-SecureCredential -CredentialName "Test-Remove" -WhatIf

            $result | Should -Not -BeNullOrEmpty
        }

        It "Should validate credential name parameter" {
            { Remove-SecureCredential -CredentialName "" } | Should -Throw
        }
    }

    Context "Export-SecureCredential Function" {
        It "Should support WhatIf mode" {
            $tempPath = Join-Path $env:TEMP "test-export-$(Get-Random).json"

            $result = Export-SecureCredential -CredentialName "Test-Export" -ExportPath $tempPath -WhatIf

            $result | Should -Not -BeNullOrEmpty
        }

        It "Should validate export path parameter" {
            { Export-SecureCredential -CredentialName "Test" -ExportPath "" } | Should -Throw
        }
    }

    Context "Import-SecureCredential Function" {
        It "Should validate import file existence" {
            $nonExistentFile = Join-Path $env:TEMP "nonexistent-$(Get-Random).json"

            { Import-SecureCredential -ImportPath $nonExistentFile } | Should -Throw
        }

        It "Should validate import path parameter" {
            { Import-SecureCredential -ImportPath "" } | Should -Throw
        }
    }
}

Describe "SecureCredentials Integration" {
    Context "Cross-Platform Compatibility" {
        It "Should work on Windows PowerShell" {
            if ($PSVersionTable.PSEdition -eq 'Desktop') {
                Get-Module SecureCredentials | Should -Not -BeNullOrEmpty
            }
        }

        It "Should work on PowerShell Core" {
            if ($PSVersionTable.PSEdition -eq 'Core') {
                Get-Module SecureCredentials | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Error Handling" {
        It "Should handle logging integration" {
            # Test that functions can call Write-CustomLog without errors
            $result = Test-SecureCredential -CredentialName "Test-Logging" -Verbose

            # Should not throw even if credential doesn't exist
            $result | Should -Be $false
        }
    }
}
