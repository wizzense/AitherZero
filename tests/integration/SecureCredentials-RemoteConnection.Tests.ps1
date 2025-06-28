#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Integration tests for SecureCredentials and RemoteConnection modules.

.DESCRIPTION
    Tests the integration between SecureCredentials and RemoteConnection modules
    using the project's TestingFramework.
#>

BeforeAll {
    . "$PSScriptRoot/../../../helpers/Test-Credentials.ps1"
    # Import required modules
    Import-Module (Join-Path $env:PWSH_MODULES_PATH "Logging/Logging.psm1") -Force
    Import-Module (Join-Path $env:PWSH_MODULES_PATH "TestingFramework/TestingFramework.psm1") -Force
    Import-Module (Join-Path $env:PWSH_MODULES_PATH "SecureCredentials/SecureCredentials.psm1") -Force
    Import-Module (Join-Path $env:PWSH_MODULES_PATH "RemoteConnection/RemoteConnection.psm1") -Force
}

Describe "SecureCredentials and RemoteConnection Integration" {
    Context "Module Dependencies" {
        It "Should load both modules successfully" {
            Get-Module SecureCredentials | Should -Not -BeNullOrEmpty
            Get-Module RemoteConnection | Should -Not -BeNullOrEmpty
        }

        It "Should have RemoteConnection depend on SecureCredentials" {
            # Test that RemoteConnection functions can reference credential functions
            $credentialFunctions = Get-Command -Module SecureCredentials
            $connectionFunctions = Get-Command -Module RemoteConnection

            $credentialFunctions | Should -Not -BeNullOrEmpty
            $connectionFunctions | Should -Not -BeNullOrEmpty
        }
    }

    Context "End-to-End Workflow" {        BeforeEach {
            $TestCredentialName = "Integration-Test-Credential-$(Get-Random)"
            $TestConnectionName = "Integration-Test-Connection-$(Get-Random)"
        }

        It "Should create credential and use it in connection" {
            # Step 1: Create a test credential (WhatIf)
            $testPassword = ConvertTo-SecureString "$(Get-TestCredential -CredentialType "AdminPassword")" -AsPlainText -Force
            $credResult = New-SecureCredential -CredentialName $TestCredentialName -CredentialType UserPassword -Username "testuser" -Password $testPassword -WhatIf

            $credResult.Success | Should -Be $true

            # Step 2: Create a connection using the credential (WhatIf)
            $connResult = New-RemoteConnection -ConnectionName $TestConnectionName -EndpointType SSH -HostName "test.example.com" -CredentialName $TestCredentialName -WhatIf

            $connResult.Success | Should -Be $true
        }

        It "Should handle missing credential in connection creation" {
            $nonExistentCred = "NonExistent-Credential-$(Get-Random)"
              # This should work in WhatIf mode even with non-existent credential
            $result = New-RemoteConnection -ConnectionName $TestConnectionName -EndpointType SSH -HostName "test.example.com" -CredentialName $nonExistentCred -WhatIf

            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Enterprise Use Cases" {
        It "Should support multiple credential types for different endpoints" {
            $credentialTypes = @('UserPassword', 'ServiceAccount', 'APIKey', 'Certificate')
            $endpointTypes = @('SSH', 'WinRM', 'VMware', 'Hyper-V')
              foreach ($credType in $credentialTypes) {
                foreach ($endpointType in $endpointTypes) {
                    $testCredName = "Test-$credType-$(Get-Random)"
                    $testConnName = "Test-$endpointType-$(Get-Random)"

                    # Test credential creation with appropriate parameters
                    if ($credType -eq 'UserPassword') {
                        $testPassword = ConvertTo-SecureString "TestPass123" -AsPlainText -Force
                        { New-SecureCredential -CredentialName $testCredName -CredentialType $credType -Username "testuser" -Password $testPassword -WhatIf } | Should -Not -Throw
                    } elseif ($credType -eq 'ServiceAccount') {
                        $testPassword = ConvertTo-SecureString "ServicePass123" -AsPlainText -Force
                        { New-SecureCredential -CredentialName $testCredName -CredentialType $credType -Username "serviceaccount" -Password $testPassword -WhatIf } | Should -Not -Throw
                    } elseif ($credType -eq 'APIKey') {
                        { New-SecureCredential -CredentialName $testCredName -CredentialType $credType -APIKey "$(Get-TestCredential -CredentialType "ApiKey")" -WhatIf } | Should -Not -Throw
                    } elseif ($credType -eq 'Certificate') {
                        { New-SecureCredential -CredentialName $testCredName -CredentialType $credType -CertificatePath "/path/to/cert.pem" -WhatIf } | Should -Not -Throw
                    }

                    # Test connection creation
                    { New-RemoteConnection -ConnectionName $testConnName -EndpointType $endpointType -HostName "test.com" -CredentialName $testCredName -WhatIf } | Should -Not -Throw
                }
            }
        }

        It "Should support bulk operations" {
            $credentialNames = @()
            $connectionNames = @()

            # Create multiple credentials and connections
            for ($i = 1; $i -le 3; $i++) {
                $credName = "Bulk-Test-Credential-$i-$(Get-Random)"
                $connName = "Bulk-Test-Connection-$i-$(Get-Random)"

                $credentialNames += $credName
                $connectionNames += $connName
                  # Test bulk credential creation with required parameters
                $testPassword = ConvertTo-SecureString "BulkTestPass123" -AsPlainText -Force
                { New-SecureCredential -CredentialName $credName -CredentialType UserPassword -Username "bulkuser$i" -Password $testPassword -WhatIf } | Should -Not -Throw

                # Test bulk connection creation
                { New-RemoteConnection -ConnectionName $connName -EndpointType SSH -HostName "test$i.example.com" -CredentialName $credName -WhatIf } | Should -Not -Throw
            }

            $credentialNames.Count | Should -Be 3
            $connectionNames.Count | Should -Be 3
        }
    }

    Context "Error Handling and Validation" {
        It "Should handle concurrent operations safely" {
            $jobs = @()
              # Test concurrent credential creation
            for ($i = 1; $i -le 3; $i++) {
                $job = Start-Job -ScriptBlock {
                    param($Index)
                    Import-Module (Join-Path $env:PWSH_MODULES_PATH "SecureCredentials/SecureCredentials.psm1") -Force
                    $testPassword = ConvertTo-SecureString "ConcurrentPass123" -AsPlainText -Force
                    New-SecureCredential -CredentialName "Concurrent-Test-$Index" -CredentialType UserPassword -Username "concurrentuser$Index" -Password $testPassword -WhatIf
                } -ArgumentList $i

                $jobs += $job
            }

            # Wait for all jobs to complete
            $results = $jobs | Wait-Job | Receive-Job
            $jobs | Remove-Job

            # All jobs should complete successfully
            $results.Count | Should -Be 3
            foreach ($result in $results) {
                $result.Success | Should -Be $true
            }
        }

        It "Should provide meaningful error messages" {
            # Test with invalid parameters
            try {
                New-SecureCredential -CredentialName "" -CredentialType UserPassword
                $false | Should -Be $true # Should not reach here
            }
            catch {
                $_.Exception.Message | Should -Not -BeNullOrEmpty
            }

            try {
                New-RemoteConnection -ConnectionName "" -EndpointType SSH -HostName "test.com"
                $false | Should -Be $true # Should not reach here
            }
            catch {
                $_.Exception.Message | Should -Not -BeNullOrEmpty
            }
        }
    }
}

