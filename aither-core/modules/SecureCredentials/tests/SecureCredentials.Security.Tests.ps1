#Requires -Modules Pester
# gitguardian:ignore-file

BeforeAll {
    # Import the module
    $ModulePath = Split-Path -Parent $PSScriptRoot
    Import-Module $ModulePath -Force
    
    # Import CredentialHelpers for testing internal functions
    . "$ModulePath/Private/CredentialHelpers.ps1"
    
    # Import test data generator
    $TestHelpersPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "tests" "helpers" "DataGenerator.ps1"
    if (Test-Path $TestHelpersPath) {
        . $TestHelpersPath
    } else {
        # Fallback if helper not found - use simple non-secret-looking data
        function New-TestBase64String { param($Length = 16) [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes([System.Guid]::NewGuid().ToString().Substring(0, $Length))) }
        function New-TestGuid { [System.Guid]::NewGuid().ToString() }
    }
    
    # Test data - using non-secret-looking patterns # gitguardian:ignore
    $script:TestCredentialName = "PesterTest-Security-$(Get-Random)"
    # Use base64 strings and GUIDs instead of password-like patterns
    $script:TestPassword = New-TestBase64String -Length 24
    $script:TestAPIKey = New-TestGuid
    $script:TestUsername = "test-user-$(Get-Random -Maximum 9999)"
}

Describe "SecureCredentials Security Tests" -Tag "Security" {
    
    Context "Encryption Implementation" {
        
        It "Should not use Base64 encoding for encryption" {
            # Test that Protect-String doesn't just do Base64 encoding
            $plainText = New-TestGuid # gitguardian:ignore
            $encrypted = Protect-String -PlainText $plainText
            
            # Base64 decode attempt should fail or produce garbage
            $decoded = $null
            try {
                $bytes = [Convert]::FromBase64String($encrypted)
                $decoded = [System.Text.Encoding]::UTF8.GetString($bytes)
            } catch {
                # Expected - not valid Base64 or doesn't decode to original
            }
            
            $decoded | Should -Not -Be $plainText
        }
        
        It "Should use platform-appropriate encryption" {
            $plainText = New-TestBase64String -Length 16 # gitguardian:ignore
            $encrypted = Protect-String -PlainText $plainText
            
            if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') {
                # On Windows, should use DPAPI format
                # DPAPI encrypted strings are typically longer and have specific patterns
                $encrypted.Length | Should -BeGreaterThan ($plainText.Length * 2)
            } else {
                # On Linux/macOS, should use AES encryption
                # AES with IV should produce consistent length output
                $encrypted | Should -Match '^[A-Za-z0-9+/]+=*$' # Base64 pattern
            }
        }
        
        It "Should properly encrypt and decrypt data" {
            # Use non-secret-looking test data # gitguardian:ignore
            $testData = @(
                (New-TestBase64String -Length 16),
                "$(New-TestGuid)-complex-test-data",
                (New-TestBase64String -Length 64),
                "Unicode🔒$(New-TestGuid)✨With😀Emojis"
            )
            
            foreach ($plainText in $testData) {
                $encrypted = Protect-String -PlainText $plainText
                $decrypted = Unprotect-String -EncryptedText $encrypted
                
                $decrypted | Should -BeExactly $plainText
                $encrypted | Should -Not -Be $plainText
            }
        }
        
        It "Should produce different encrypted output for same input (when using IV/salt)" -Skip:($IsWindows) {
            # Skip on Windows as DPAPI might produce same output for same input
            # This test is relevant for AES encryption with random IV
            
            $plainText = New-TestGuid # gitguardian:ignore
            $encrypted1 = Protect-String -PlainText $plainText
            $encrypted2 = Protect-String -PlainText $plainText
            
            # With proper IV usage, encrypted outputs should differ
            $encrypted1 | Should -Not -Be $encrypted2
            
            # But both should decrypt to same value
            $decrypted1 = Unprotect-String -EncryptedText $encrypted1
            $decrypted2 = Unprotect-String -EncryptedText $encrypted2
            
            $decrypted1 | Should -Be $plainText
            $decrypted2 | Should -Be $plainText
        }
        
        It "Should fail to decrypt with corrupted data" {
            $plainText = New-TestBase64String -Length 20 # gitguardian:ignore
            $encrypted = Protect-String -PlainText $plainText
            
            # Corrupt the encrypted data
            $corruptedData = $encrypted.Substring(0, $encrypted.Length - 5) + "XXXXX"
            
            { Unprotect-String -EncryptedText $corruptedData } | Should -Throw
        }
    }
    
    Context "Credential Storage Security" {
        
        BeforeEach {
            # Clean up any existing test credential
            if (Get-SecureCredential -CredentialName $script:TestCredentialName -ErrorAction SilentlyContinue) {
                Remove-SecureCredential -CredentialName $script:TestCredentialName -Force
            }
        }
        
        AfterEach {
            # Clean up
            if (Get-SecureCredential -CredentialName $script:TestCredentialName -ErrorAction SilentlyContinue) {
                Remove-SecureCredential -CredentialName $script:TestCredentialName -Force
            }
        }
        
        It "Should store passwords as SecureString, not plaintext" {
            # Suppress analyzer warning - this is a test file using dynamically generated test passwords
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Test file using dynamically generated test data')]
            $securePassword = ConvertTo-SecureString $script:TestPassword -AsPlainText -Force
            $cred = New-Object PSCredential($script:TestUsername, $securePassword)
            
            New-SecureCredential -CredentialName $script:TestCredentialName -CredentialType "UserPassword" -Credential $cred
            
            # Check the stored file
            $storagePath = Get-CredentialStoragePath
            $credFile = Join-Path $storagePath "$($script:TestCredentialName).json"
            $fileContent = Get-Content $credFile -Raw
            
            # Password should not appear in plaintext
            $fileContent | Should -Not -Match $script:TestPassword
            
            # Should contain encrypted password field
            $jsonData = $fileContent | ConvertFrom-Json
            $jsonData.EncryptedPassword | Should -Not -BeNullOrEmpty
        }
        
        It "Should encrypt API keys" {
            New-SecureCredential -CredentialName $script:TestCredentialName -CredentialType "APIKey" -APIKey $script:TestAPIKey
            
            # Check the stored file
            $storagePath = Get-CredentialStoragePath
            $credFile = Join-Path $storagePath "$($script:TestCredentialName).json"
            $fileContent = Get-Content $credFile -Raw
            
            # API key should not appear in plaintext
            $fileContent | Should -Not -Match ([regex]::Escape($script:TestAPIKey))
            
            # Should contain encrypted API key field
            $jsonData = $fileContent | ConvertFrom-Json
            $jsonData.EncryptedAPIKey | Should -Not -BeNullOrEmpty
        }
        
        It "Should set appropriate file permissions on credential files" -Skip:($IsWindows) {
            # This test is more relevant for Linux/macOS
            New-SecureCredential -CredentialName $script:TestCredentialName -CredentialType "APIKey" -APIKey $script:TestAPIKey
            
            $storagePath = Get-CredentialStoragePath
            $credFile = Join-Path $storagePath "$($script:TestCredentialName).json"
            
            # Check file permissions (should be readable only by owner)
            if ($IsLinux -or $IsMacOS) {
                $permissions = (Get-Item $credFile).UnixMode
                # Owner should have read/write, others should have no access
                $permissions | Should -Match '^.rw-------'
            }
        }
    }
    
    Context "Export/Import Security" {
        
        BeforeEach {
            # Create a test credential
            # Suppress analyzer warning - this is a test file using dynamically generated test passwords
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Test file using dynamically generated test data')]
            $securePassword = ConvertTo-SecureString $script:TestPassword -AsPlainText -Force
            $cred = New-Object PSCredential($script:TestUsername, $securePassword)
            New-SecureCredential -CredentialName $script:TestCredentialName -CredentialType "UserPassword" -Credential $cred -Force
            
            $script:ExportPath = Join-Path $TestDrive "export-test.json"
        }
        
        AfterEach {
            # Clean up
            if (Get-SecureCredential -CredentialName $script:TestCredentialName -ErrorAction SilentlyContinue) {
                Remove-SecureCredential -CredentialName $script:TestCredentialName -Force
            }
            if (Test-Path $script:ExportPath) {
                Remove-Item $script:ExportPath -Force
            }
        }
        
        It "Should not include secrets in export by default" {
            Export-SecureCredential -CredentialName $script:TestCredentialName -ExportPath $script:ExportPath
            
            $exportContent = Get-Content $script:ExportPath -Raw
            $exportData = $exportContent | ConvertFrom-Json
            
            # Should not contain password
            $exportContent | Should -Not -Match $script:TestPassword
            $exportData.Credentials[0].Password | Should -BeNullOrEmpty
            
            # Should indicate secrets are not included
            $exportData.ExportInfo.IncludesSecrets | Should -Be $false
        }
        
        It "Should include warning when exporting with secrets" {
            # Simulate user confirmation
            Mock Read-Host { return "yes" }
            
            Export-SecureCredential -CredentialName $script:TestCredentialName -ExportPath $script:ExportPath -IncludeSecrets
            
            $exportContent = Get-Content $script:ExportPath -Raw
            $exportData = $exportContent | ConvertFrom-Json
            
            # Should contain warning in the credential
            $exportData.Credentials[0].WARNING | Should -Match "PLAINTEXT"
            
            # Should indicate secrets are included
            $exportData.ExportInfo.IncludesSecrets | Should -Be $true
        }
        
        It "Should require confirmation for plaintext export" {
            Mock Read-Host { return "no" }
            
            Export-SecureCredential -CredentialName $script:TestCredentialName -ExportPath $script:ExportPath -IncludeSecrets
            
            # Export should not exist if user declined
            Test-Path $script:ExportPath | Should -Be $false
        }
    }
    
    Context "Machine-Specific Encryption" -Skip:($IsWindows) {
        
        It "Should generate machine-specific keys" {
            $key1 = Get-MachineSpecificKey
            $key2 = Get-MachineSpecificKey
            
            # Keys should be consistent on same machine
            [Convert]::ToBase64String($key1) | Should -Be ([Convert]::ToBase64String($key2))
            
            # Key should be 256 bits (32 bytes) for AES-256
            $key1.Length | Should -Be 32
        }
        
        It "Should use machine-specific identifiers" {
            Mock Get-Content {
                if ($Path -eq "/etc/machine-id") {
                    return "test-machine-id-12345"
                }
                return $null
            }
            
            $key = Get-MachineSpecificKey
            
            # Key should be deterministic based on machine ID
            $key | Should -Not -BeNullOrEmpty
            $key.Length | Should -Be 32
        }
    }
    
    Context "Error Handling and Logging" {
        
        It "Should log errors when encryption fails" {
            Mock Write-CustomLog {} -Verifiable -ParameterFilter { $Level -eq 'ERROR' }
            
            # Try to decrypt invalid data
            try {
                Unprotect-String -EncryptedText "InvalidEncryptedData"
            } catch {
                # Expected
            }
            
            # Verify error was logged
            Should -InvokeVerifiable
        }
        
        It "Should handle empty or null inputs gracefully" {
            { Protect-String -PlainText "" } | Should -Not -Throw
            { Protect-String -PlainText $null } | Should -Throw
            { Unprotect-String -EncryptedText "" } | Should -Throw
            { Unprotect-String -EncryptedText $null } | Should -Throw
        }
    }
}

Describe "Security Compliance Tests" -Tag "Compliance" {
    
    Context "PSScriptAnalyzer Security Rules" {
        
        It "Should not have plaintext password vulnerabilities" {
            $modulePath = Split-Path -Parent $PSScriptRoot
            $results = Invoke-ScriptAnalyzer -Path $modulePath -Recurse -ExcludeRule PSAvoidUsingConvertToSecureStringWithPlainText |
                Where-Object { $_.RuleName -match "Password|PlainText|Credential" }
            
            # Filter out legitimate suppressions
            $violations = $results | Where-Object {
                -not ($_.ScriptPath -match "Import-SecureCredential" -and $_.Line -match "legitimate use case")
            }
            
            $violations | Should -BeNullOrEmpty
        }
    }
}

AfterAll {
    # Final cleanup
    Get-SecureCredential | Where-Object { $_.Name -like "PesterTest-Security-*" } | ForEach-Object {
        Remove-SecureCredential -CredentialName $_.Name -Force
    }
}