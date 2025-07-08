#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive test suite for the RemoteConnection module.

.DESCRIPTION
    This test suite validates all functionality of the RemoteConnection module,
    including connection management, protocol support, and integration with
    other AitherZero modules.
#>

# Import required modules for testing
BeforeAll {
    # Find project root
    $projectRoot = $PSScriptRoot
    while ($projectRoot -and -not (Test-Path (Join-Path $projectRoot 'Start-AitherZero.ps1'))) {
        $projectRoot = Split-Path $projectRoot -Parent
    }

    if (-not $projectRoot) {
        throw "Could not find project root"
    }

    # Import modules
    $loggingModule = Join-Path $projectRoot 'aither-core/modules/Logging/Logging.psm1'
    $secureCredentialsModule = Join-Path $projectRoot 'aither-core/modules/SecureCredentials/SecureCredentials.psm1'
    $remoteConnectionModule = Join-Path $projectRoot 'aither-core/modules/RemoteConnection/RemoteConnection.psm1'

    if (Test-Path $loggingModule) { Import-Module $loggingModule -Force }
    if (Test-Path $secureCredentialsModule) { Import-Module $secureCredentialsModule -Force }
    if (Test-Path $remoteConnectionModule) { Import-Module $remoteConnectionModule -Force }

    # Test configuration
    $script:testConnectionName = "Test-Connection-$(Get-Random)"
    $script:testHostName = "localhost"
    $script:testPort = 22
    $script:testCredentialName = "Test-Credential-$(Get-Random)"
}

Describe "RemoteConnection Module Tests" {

    Context "Module Import and Structure" {

        It "Should import the RemoteConnection module successfully" {
            Get-Module RemoteConnection | Should -Not -BeNullOrEmpty
        }

        It "Should export all required functions" {
            $expectedFunctions = @(
                'New-RemoteConnection',
                'Get-RemoteConnection',
                'Remove-RemoteConnection',
                'Test-RemoteConnection',
                'Connect-RemoteEndpoint',
                'Disconnect-RemoteEndpoint',
                'Invoke-RemoteCommand'
            )

            $exportedFunctions = (Get-Module RemoteConnection).ExportedFunctions.Keys
            foreach ($function in $expectedFunctions) {
                $exportedFunctions | Should -Contain $function
            }
        }

        It "Should have proper help documentation for each function" {
            $functions = (Get-Module RemoteConnection).ExportedFunctions.Keys
            foreach ($function in $functions) {
                $help = Get-Help $function -ErrorAction SilentlyContinue
                $help | Should -Not -BeNullOrEmpty
                $help.Synopsis | Should -Not -BeNullOrEmpty
                $help.Description | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Connection Configuration Management" {

        BeforeEach {
            # Clean up any existing test connections
            $existingConnection = Get-RemoteConnection -ConnectionName $script:testConnectionName -ErrorAction SilentlyContinue
            if ($existingConnection) {
                Remove-RemoteConnection -ConnectionName $script:testConnectionName -Force
            }
        }

        AfterEach {
            # Clean up test connections
            $existingConnection = Get-RemoteConnection -ConnectionName $script:testConnectionName -ErrorAction SilentlyContinue
            if ($existingConnection) {
                Remove-RemoteConnection -ConnectionName $script:testConnectionName -Force
            }
        }

        It "Should create a new SSH connection configuration" {
            $result = New-RemoteConnection -ConnectionName $script:testConnectionName -EndpointType "SSH" -HostName $script:testHostName -Port $script:testPort

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.ConnectionName | Should -Be $script:testConnectionName
            $result.EndpointType | Should -Be "SSH"
            $result.HostName | Should -Be $script:testHostName
            $result.Port | Should -Be $script:testPort
        }

        It "Should create a new WinRM connection configuration" {
            $result = New-RemoteConnection -ConnectionName $script:testConnectionName -EndpointType "WinRM" -HostName $script:testHostName -EnableSSL

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.EndpointType | Should -Be "WinRM"
            $result.Port | Should -Be 5986  # SSL port
        }

        It "Should retrieve an existing connection configuration" {
            # Create a connection first
            New-RemoteConnection -ConnectionName $script:testConnectionName -EndpointType "SSH" -HostName $script:testHostName -Port $script:testPort

            # Retrieve it
            $result = Get-RemoteConnection -ConnectionName $script:testConnectionName

            $result | Should -Not -BeNullOrEmpty
            $result.ConnectionName | Should -Be $script:testConnectionName
            $result.EndpointType | Should -Be "SSH"
            $result.HostName | Should -Be $script:testHostName
            $result.Port | Should -Be $script:testPort
        }

        It "Should retrieve all connection configurations" {
            # Create multiple connections
            New-RemoteConnection -ConnectionName "$($script:testConnectionName)-1" -EndpointType "SSH" -HostName $script:testHostName -Port 22
            New-RemoteConnection -ConnectionName "$($script:testConnectionName)-2" -EndpointType "WinRM" -HostName $script:testHostName -Port 5985

            # Retrieve all
            $results = Get-RemoteConnection

            $results | Should -Not -BeNullOrEmpty
            $results.Count | Should -BeGreaterThan 1

            # Clean up
            Remove-RemoteConnection -ConnectionName "$($script:testConnectionName)-1" -Force
            Remove-RemoteConnection -ConnectionName "$($script:testConnectionName)-2" -Force
        }

        It "Should filter connections by endpoint type" {
            # Create connections of different types
            New-RemoteConnection -ConnectionName "$($script:testConnectionName)-SSH" -EndpointType "SSH" -HostName $script:testHostName -Port 22
            New-RemoteConnection -ConnectionName "$($script:testConnectionName)-WinRM" -EndpointType "WinRM" -HostName $script:testHostName -Port 5985

            # Filter by SSH
            $sshConnections = Get-RemoteConnection -EndpointType "SSH"
            $sshConnections | Should -Not -BeNullOrEmpty
            $sshConnections | Where-Object { $_.EndpointType -eq "SSH" } | Should -Not -BeNullOrEmpty

            # Clean up
            Remove-RemoteConnection -ConnectionName "$($script:testConnectionName)-SSH" -Force
            Remove-RemoteConnection -ConnectionName "$($script:testConnectionName)-WinRM" -Force
        }

        It "Should remove a connection configuration" {
            # Create a connection first
            New-RemoteConnection -ConnectionName $script:testConnectionName -EndpointType "SSH" -HostName $script:testHostName -Port $script:testPort

            # Verify it exists
            $connection = Get-RemoteConnection -ConnectionName $script:testConnectionName
            $connection | Should -Not -BeNullOrEmpty

            # Remove it
            $result = Remove-RemoteConnection -ConnectionName $script:testConnectionName -Force
            $result.Success | Should -Be $true

            # Verify it's gone
            $connection = Get-RemoteConnection -ConnectionName $script:testConnectionName
            $connection | Should -BeNullOrEmpty
        }

        It "Should handle WhatIf parameter correctly" {
            $result = New-RemoteConnection -ConnectionName $script:testConnectionName -EndpointType "SSH" -HostName $script:testHostName -Port $script:testPort -WhatIf

            $result | Should -Not -BeNullOrEmpty
            $result.WhatIf | Should -Be $true

            # Verify connection was not actually created
            $connection = Get-RemoteConnection -ConnectionName $script:testConnectionName
            $connection | Should -BeNullOrEmpty
        }
    }

    Context "Connection Testing" {

        BeforeEach {
            # Create a test connection
            New-RemoteConnection -ConnectionName $script:testConnectionName -EndpointType "SSH" -HostName $script:testHostName -Port $script:testPort
        }

        AfterEach {
            # Clean up test connection
            $existingConnection = Get-RemoteConnection -ConnectionName $script:testConnectionName -ErrorAction SilentlyContinue
            if ($existingConnection) {
                Remove-RemoteConnection -ConnectionName $script:testConnectionName -Force
            }
        }

        It "Should test connection by name" {
            $result = Test-RemoteConnection -ConnectionName $script:testConnectionName

            $result | Should -Not -BeNullOrEmpty
            $result.ConnectionName | Should -Be $script:testConnectionName
            $result.HostName | Should -Be $script:testHostName
            $result.Port | Should -Be $script:testPort
        }

        It "Should test connection by hostname and port" {
            $result = Test-RemoteConnection -HostName $script:testHostName -Port $script:testPort

            $result | Should -Not -BeNullOrEmpty
            $result.HostName | Should -Be $script:testHostName
            $result.Port | Should -Be $script:testPort
        }

        It "Should support quiet mode" {
            $result = Test-RemoteConnection -ConnectionName $script:testConnectionName -Quiet

            $result | Should -BeOfType [bool]
        }

        It "Should handle invalid connection names" {
            $result = Test-RemoteConnection -ConnectionName "NonExistent-Connection" -Quiet

            $result | Should -Be $false
        }
    }

    Context "Protocol-Specific Features" {

        It "Should set correct default ports for each protocol" {
            # SSH
            $sshResult = New-RemoteConnection -ConnectionName "Test-SSH-$(Get-Random)" -EndpointType "SSH" -HostName "test.example.com"
            $sshResult.Port | Should -Be 22
            Remove-RemoteConnection -ConnectionName $sshResult.ConnectionName -Force

            # WinRM HTTP
            $winrmResult = New-RemoteConnection -ConnectionName "Test-WinRM-$(Get-Random)" -EndpointType "WinRM" -HostName "test.example.com"
            $winrmResult.Port | Should -Be 5985
            Remove-RemoteConnection -ConnectionName $winrmResult.ConnectionName -Force

            # WinRM HTTPS
            $winrmSslResult = New-RemoteConnection -ConnectionName "Test-WinRM-SSL-$(Get-Random)" -EndpointType "WinRM" -HostName "test.example.com" -EnableSSL
            $winrmSslResult.Port | Should -Be 5986
            Remove-RemoteConnection -ConnectionName $winrmSslResult.ConnectionName -Force

            # Docker
            $dockerResult = New-RemoteConnection -ConnectionName "Test-Docker-$(Get-Random)" -EndpointType "Docker" -HostName "test.example.com"
            $dockerResult.Port | Should -Be 2375
            Remove-RemoteConnection -ConnectionName $dockerResult.ConnectionName -Force

            # Docker TLS
            $dockerTlsResult = New-RemoteConnection -ConnectionName "Test-Docker-TLS-$(Get-Random)" -EndpointType "Docker" -HostName "test.example.com" -EnableSSL
            $dockerTlsResult.Port | Should -Be 2376
            Remove-RemoteConnection -ConnectionName $dockerTlsResult.ConnectionName -Force
        }

        It "Should support all endpoint types" {
            $endpointTypes = @('SSH', 'WinRM', 'VMware', 'Hyper-V', 'Docker', 'Kubernetes')

            foreach ($type in $endpointTypes) {
                $connName = "Test-$type-$(Get-Random)"
                $result = New-RemoteConnection -ConnectionName $connName -EndpointType $type -HostName "test.example.com"

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $true
                $result.EndpointType | Should -Be $type

                Remove-RemoteConnection -ConnectionName $connName -Force
            }
        }

        It "Should add protocol-specific options" {
            # SSH options
            $sshResult = New-RemoteConnection -ConnectionName "Test-SSH-Options-$(Get-Random)" -EndpointType "SSH" -HostName "test.example.com"
            $sshConnection = Get-RemoteConnection -ConnectionName $sshResult.ConnectionName
            $sshConnection | Should -Not -BeNullOrEmpty
            # SSH options would be in the stored configuration
            Remove-RemoteConnection -ConnectionName $sshResult.ConnectionName -Force

            # WinRM options
            $winrmResult = New-RemoteConnection -ConnectionName "Test-WinRM-Options-$(Get-Random)" -EndpointType "WinRM" -HostName "test.example.com" -EnableSSL
            $winrmConnection = Get-RemoteConnection -ConnectionName $winrmResult.ConnectionName
            $winrmConnection | Should -Not -BeNullOrEmpty
            Remove-RemoteConnection -ConnectionName $winrmResult.ConnectionName -Force
        }
    }

    Context "Error Handling" {

        It "Should handle invalid endpoint types" {
            { New-RemoteConnection -ConnectionName "Test-Invalid" -EndpointType "InvalidType" -HostName "test.example.com" } | Should -Throw
        }

        It "Should handle invalid port ranges" {
            { New-RemoteConnection -ConnectionName "Test-InvalidPort" -EndpointType "SSH" -HostName "test.example.com" -Port 0 } | Should -Throw
            { New-RemoteConnection -ConnectionName "Test-InvalidPort" -EndpointType "SSH" -HostName "test.example.com" -Port 65536 } | Should -Throw
        }

        It "Should handle empty or null parameters" {
            { New-RemoteConnection -ConnectionName "" -EndpointType "SSH" -HostName "test.example.com" } | Should -Throw
            { New-RemoteConnection -ConnectionName "Test" -EndpointType "SSH" -HostName "" } | Should -Throw
        }

        It "Should handle duplicate connection names" {
            # Create first connection
            New-RemoteConnection -ConnectionName $script:testConnectionName -EndpointType "SSH" -HostName $script:testHostName -Port $script:testPort

            # Try to create duplicate
            { New-RemoteConnection -ConnectionName $script:testConnectionName -EndpointType "SSH" -HostName $script:testHostName -Port $script:testPort } | Should -Throw

            # Clean up
            Remove-RemoteConnection -ConnectionName $script:testConnectionName -Force
        }

        It "Should allow overwriting with Force parameter" {
            # Create first connection
            New-RemoteConnection -ConnectionName $script:testConnectionName -EndpointType "SSH" -HostName $script:testHostName -Port $script:testPort

            # Overwrite with Force
            $result = New-RemoteConnection -ConnectionName $script:testConnectionName -EndpointType "WinRM" -HostName "different.example.com" -Port 5985 -Force

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.EndpointType | Should -Be "WinRM"

            # Clean up
            Remove-RemoteConnection -ConnectionName $script:testConnectionName -Force
        }
    }

    Context "Integration Tests" {

        BeforeAll {
            # Only run integration tests if SecureCredentials module is available
            $script:hasSecureCredentials = Get-Module SecureCredentials -ErrorAction SilentlyContinue
        }

        It "Should integrate with SecureCredentials module" -Skip:(-not $script:hasSecureCredentials) {
            # Create a test credential
            if (Get-Command New-SecureCredential -ErrorAction SilentlyContinue) {
                $securePassword = ConvertTo-SecureString "TestPassword123!" -AsPlainText -Force
                New-SecureCredential -CredentialName $script:testCredentialName -Username "testuser" -Password $securePassword

                # Create connection with credential
                $result = New-RemoteConnection -ConnectionName $script:testConnectionName -EndpointType "SSH" -HostName $script:testHostName -CredentialName $script:testCredentialName

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $true
                $result.CredentialName | Should -Be $script:testCredentialName

                # Clean up
                Remove-RemoteConnection -ConnectionName $script:testConnectionName -Force
                if (Get-Command Remove-SecureCredential -ErrorAction SilentlyContinue) {
                    Remove-SecureCredential -CredentialName $script:testCredentialName -Force
                }
            }
        }

        It "Should validate credentials when specified" -Skip:(-not $script:hasSecureCredentials) {
            # Try to create connection with non-existent credential
            $result = New-RemoteConnection -ConnectionName $script:testConnectionName -EndpointType "SSH" -HostName $script:testHostName -CredentialName "NonExistent-Credential"

            # Should still create the connection but log a warning
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true

            # Clean up
            Remove-RemoteConnection -ConnectionName $script:testConnectionName -Force
        }
    }

    Context "Cross-Platform Compatibility" {

        It "Should handle different path separators" {
            # Test that path handling works on different platforms
            $result = New-RemoteConnection -ConnectionName $script:testConnectionName -EndpointType "SSH" -HostName $script:testHostName -Port $script:testPort

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.ConfigFile | Should -Not -BeNullOrEmpty

            # Verify the config file was created
            Test-Path $result.ConfigFile | Should -Be $true

            # Clean up
            Remove-RemoteConnection -ConnectionName $script:testConnectionName -Force
        }

        It "Should use correct storage locations for different platforms" {
            # This is tested implicitly by the successful creation and retrieval of connections
            # The Get-ConnectionStoragePath function handles platform-specific paths
            $result = New-RemoteConnection -ConnectionName $script:testConnectionName -EndpointType "SSH" -HostName $script:testHostName -Port $script:testPort
            $connection = Get-RemoteConnection -ConnectionName $script:testConnectionName

            $connection | Should -Not -BeNullOrEmpty
            $connection.ConnectionName | Should -Be $script:testConnectionName

            # Clean up
            Remove-RemoteConnection -ConnectionName $script:testConnectionName -Force
        }
    }

    Context "Performance Tests" {

        It "Should handle creating multiple connections efficiently" {
            $connectionCount = 10
            $connectionNames = @()

            # Create multiple connections
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            for ($i = 1; $i -le $connectionCount; $i++) {
                $connName = "Perf-Test-$i-$(Get-Random)"
                $connectionNames += $connName
                New-RemoteConnection -ConnectionName $connName -EndpointType "SSH" -HostName "test$i.example.com" -Port $script:testPort
            }
            $stopwatch.Stop()

            # Should complete in reasonable time (less than 30 seconds)
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 30000

            # Verify all connections were created
            $allConnections = Get-RemoteConnection
            foreach ($connName in $connectionNames) {
                $allConnections | Where-Object { $_.ConnectionName -eq $connName } | Should -Not -BeNullOrEmpty
            }

            # Clean up
            foreach ($connName in $connectionNames) {
                Remove-RemoteConnection -ConnectionName $connName -Force
            }
        }

        It "Should handle retrieving many connections efficiently" {
            $connectionCount = 5
            $connectionNames = @()

            # Create multiple connections
            for ($i = 1; $i -le $connectionCount; $i++) {
                $connName = "Perf-Retrieve-$i-$(Get-Random)"
                $connectionNames += $connName
                New-RemoteConnection -ConnectionName $connName -EndpointType "SSH" -HostName "test$i.example.com" -Port $script:testPort
            }

            # Retrieve all connections
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $allConnections = Get-RemoteConnection
            $stopwatch.Stop()

            # Should complete quickly
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000
            $allConnections.Count | Should -BeGreaterOrEqual $connectionCount

            # Clean up
            foreach ($connName in $connectionNames) {
                Remove-RemoteConnection -ConnectionName $connName -Force
            }
        }
    }
}

# Cleanup function
AfterAll {
    # Clean up any remaining test connections
    try {
        $allConnections = Get-RemoteConnection -ErrorAction SilentlyContinue
        if ($allConnections) {
            foreach ($connection in $allConnections) {
                if ($connection.ConnectionName -like "*Test*" -or $connection.ConnectionName -like "*Perf*") {
                    Remove-RemoteConnection -ConnectionName $connection.ConnectionName -Force -ErrorAction SilentlyContinue
                }
            }
        }
    } catch {
        # Ignore cleanup errors
    }

    # Clean up test credentials
    try {
        if (Get-Command Remove-SecureCredential -ErrorAction SilentlyContinue) {
            Remove-SecureCredential -CredentialName $script:testCredentialName -Force -ErrorAction SilentlyContinue
        }
    } catch {
        # Ignore cleanup errors
    }
}
