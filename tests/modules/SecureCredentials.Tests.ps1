#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive tests for the SecureCredentials module
.DESCRIPTION
    Tests all functionality of the SecureCredentials module including:
    - Credential creation, storage, and retrieval
    - Modern encryption and decryption
    - Export and import operations
    - Integrity validation and security checks
    - Cross-platform compatibility
#>

# Import the module under test
$ModulePath = Join-Path $PSScriptRoot "../../aither-core/modules/SecureCredentials"
Import-Module $ModulePath -Force

# Import logging for test output
$LoggingPath = Join-Path $PSScriptRoot "../../aither-core/modules/Logging"
Import-Module $LoggingPath -Force

Describe "SecureCredentials Module Tests" {
    BeforeAll {
        # Set up test environment
        $TestCredentials = @{
            UserPassword = @{
                Name = "TestUser-$(Get-Random)"
                Username = "testuser"
                Password = ConvertTo-SecureString "TestP@ssw0rd123!" -AsPlainText -Force
                Description = "Test user credential"
            }
            APIKey = @{
                Name = "TestAPIKey-$(Get-Random)"
                APIKey = "test-api-key-$(Get-Random)"
                Description = "Test API key credential"
            }
            ServiceAccount = @{
                Name = "TestSvcAccount-$(Get-Random)"
                Username = "svc-test"
                Description = "Test service account"
            }
        }
        
        # Create temporary certificate for testing
        $TempCertPath = [System.IO.Path]::GetTempFileName() + ".pfx"
        $TestCredentials.Certificate = @{
            Name = "TestCert-$(Get-Random)"
            CertificatePath = $TempCertPath
            Description = "Test certificate credential"
        }
        
        # Create a dummy certificate file
        "Dummy certificate content for testing" | Set-Content -Path $TempCertPath
        
        Write-CustomLog -Level 'INFO' -Message "Test environment prepared"
    }
    
    AfterAll {
        # Clean up test credentials
        foreach ($credType in $TestCredentials.Keys) {
            $credName = $TestCredentials[$credType].Name
            try {
                if (Test-SecureCredential -CredentialName $credName -Quiet) {
                    Remove-SecureCredential -CredentialName $credName -Force
                    Write-CustomLog -Level 'INFO' -Message "Cleaned up test credential: $credName"
                }
            }
            catch {
                Write-CustomLog -Level 'WARN' -Message "Failed to clean up credential $credName : $($_.Exception.Message)"
            }
        }
        
        # Clean up temporary certificate file
        if (Test-Path $TempCertPath) {
            Remove-Item $TempCertPath -Force
        }
        
        Write-CustomLog -Level 'INFO' -Message "Test cleanup completed"
    }
    
    Context "Module Loading and Structure" {
        It "Should load the module successfully" {
            $module = Get-Module SecureCredentials
            $module | Should -Not -BeNullOrEmpty
            $module.Name | Should -Be "SecureCredentials"
        }
        
        It "Should export all required functions" {
            $module = Get-Module SecureCredentials
            $exportedFunctions = $module.ExportedFunctions.Keys
            
            $requiredFunctions = @(
                'New-SecureCredential',
                'Get-SecureCredential',
                'Remove-SecureCredential',
                'Test-SecureCredential',
                'Export-SecureCredential',
                'Import-SecureCredential',
                'Get-AllSecureCredentials',
                'Test-SecureCredentialStore',
                'Backup-SecureCredentialStore'
            )
            
            foreach ($function in $requiredFunctions) {
                $exportedFunctions | Should -Contain $function
            }
        }
    }
    
    Context "Credential Creation and Storage" {
        It "Should create UserPassword credential successfully" {
            $cred = $TestCredentials.UserPassword
            
            $result = New-SecureCredential -CredentialName $cred.Name `
                -CredentialType "UserPassword" `
                -Username $cred.Username `
                -Password $cred.Password `
                -Description $cred.Description
                
            $result.Success | Should -Be $true
            $result.CredentialName | Should -Be $cred.Name
        }
        
        It "Should create APIKey credential successfully" {
            $cred = $TestCredentials.APIKey
            
            $result = New-SecureCredential -CredentialName $cred.Name `
                -CredentialType "APIKey" `
                -APIKey $cred.APIKey `
                -Description $cred.Description
                
            $result.Success | Should -Be $true
            $result.CredentialName | Should -Be $cred.Name
        }
        
        It "Should create ServiceAccount credential successfully" {
            $cred = $TestCredentials.ServiceAccount
            
            $result = New-SecureCredential -CredentialName $cred.Name `
                -CredentialType "ServiceAccount" `
                -Username $cred.Username `
                -Description $cred.Description
                
            $result.Success | Should -Be $true
            $result.CredentialName | Should -Be $cred.Name
        }
        
        It "Should create Certificate credential successfully" {
            $cred = $TestCredentials.Certificate
            
            $result = New-SecureCredential -CredentialName $cred.Name `
                -CredentialType "Certificate" `
                -CertificatePath $cred.CertificatePath `
                -Description $cred.Description
                
            $result.Success | Should -Be $true
            $result.CredentialName | Should -Be $cred.Name
        }
        
        It "Should reject invalid credential types" {
            { New-SecureCredential -CredentialName "InvalidTest" -CredentialType "InvalidType" } | Should -Throw
        }
        
        It "Should validate required parameters for UserPassword" {
            { New-SecureCredential -CredentialName "TestUser" -CredentialType "UserPassword" -Username "test" } | Should -Throw
            { New-SecureCredential -CredentialName "TestUser" -CredentialType "UserPassword" -Password (ConvertTo-SecureString "test" -AsPlainText -Force) } | Should -Throw
        }
    }
    
    Context "Credential Retrieval and Validation" {
        It "Should retrieve UserPassword credential correctly" {
            $originalCred = $TestCredentials.UserPassword
            $retrievedCred = Get-SecureCredential -CredentialName $originalCred.Name
            
            $retrievedCred | Should -Not -BeNullOrEmpty
            $retrievedCred.Name | Should -Be $originalCred.Name
            $retrievedCred.Type | Should -Be "UserPassword"
            $retrievedCred.Username | Should -Be $originalCred.Username
            $retrievedCred.Password | Should -BeOfType [SecureString]
        }
        
        It "Should retrieve APIKey credential correctly" {
            $originalCred = $TestCredentials.APIKey
            $retrievedCred = Get-SecureCredential -CredentialName $originalCred.Name
            
            $retrievedCred | Should -Not -BeNullOrEmpty
            $retrievedCred.Name | Should -Be $originalCred.Name
            $retrievedCred.Type | Should -Be "APIKey"
            $retrievedCred.APIKey | Should -Be $originalCred.APIKey
        }
        
        It "Should return null for non-existent credential" {
            $result = Get-SecureCredential -CredentialName "NonExistentCredential-$(Get-Random)"
            $result | Should -BeNullOrEmpty
        }
        
        It "Should validate credential existence" {
            Test-SecureCredential -CredentialName $TestCredentials.UserPassword.Name | Should -Be $true
            Test-SecureCredential -CredentialName "NonExistent-$(Get-Random)" | Should -Be $false
        }
        
        It "Should validate credential content" {
            Test-SecureCredential -CredentialName $TestCredentials.UserPassword.Name -ValidateContent | Should -Be $true
            Test-SecureCredential -CredentialName $TestCredentials.APIKey.Name -ValidateContent | Should -Be $true
        }
    }
    
    Context "Encryption and Security" {
        It "Should use modern encryption methods" {
            $testString = "Test encryption string $(Get-Random)"
            $encrypted = Protect-String -PlainText $testString
            $decrypted = Unprotect-String -EncryptedText $encrypted
            
            $encrypted | Should -Not -Be $testString
            $decrypted | Should -Be $testString
        }
        
        It "Should handle encryption errors gracefully" {
            { Unprotect-String -EncryptedText "InvalidEncryptedData" } | Should -Throw
        }
        
        It "Should store credentials with proper security metadata" {
            $cred = Get-SecureCredential -CredentialName $TestCredentials.UserPassword.Name
            $cred.SecurityInfo | Should -Not -BeNullOrEmpty
            $cred.SecurityInfo.Version | Should -Be "2.0"
            $cred.SecurityInfo.EncryptionMethod | Should -Not -BeNullOrEmpty
            $cred.SecurityInfo.IntegrityHash | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Export and Import Operations" {
        It "Should export credential metadata successfully" {
            $tempExportPath = [System.IO.Path]::GetTempFileName()
            
            try {
                $result = Export-SecureCredential -CredentialName $TestCredentials.UserPassword.Name -ExportPath $tempExportPath
                
                $result.Success | Should -Be $true
                Test-Path $tempExportPath | Should -Be $true
                
                $exportData = Get-Content $tempExportPath | ConvertFrom-Json
                $exportData.ExportInfo | Should -Not -BeNullOrEmpty
                $exportData.Credentials | Should -HaveCount 1
                $exportData.Credentials[0].Name | Should -Be $TestCredentials.UserPassword.Name
            }
            finally {
                if (Test-Path $tempExportPath) {
                    Remove-Item $tempExportPath -Force
                }
            }
        }
        
        It "Should import credential successfully" {
            # First export a credential
            $tempExportPath = [System.IO.Path]::GetTempFileName()
            $tempCredName = "TempImportTest-$(Get-Random)"
            
            try {
                # Create a temporary credential for import testing
                New-SecureCredential -CredentialName $tempCredName `
                    -CredentialType "UserPassword" `
                    -Username "importtest" `
                    -Password (ConvertTo-SecureString "ImportP@ss!" -AsPlainText -Force)
                
                Export-SecureCredential -CredentialName $tempCredName -ExportPath $tempExportPath
                
                # Remove the original
                Remove-SecureCredential -CredentialName $tempCredName -Force
                
                # Import it back
                $importResult = Import-SecureCredential -ImportPath $tempExportPath
                
                $importResult.Success | Should -Be $true
                $importResult.ImportedCredentials | Should -Contain $tempCredName
                
                # Verify it was imported correctly
                Test-SecureCredential -CredentialName $tempCredName | Should -Be $true
            }
            finally {
                # Cleanup
                if (Test-SecureCredential -CredentialName $tempCredName -Quiet) {
                    Remove-SecureCredential -CredentialName $tempCredName -Force
                }
                if (Test-Path $tempExportPath) {
                    Remove-Item $tempExportPath -Force
                }
            }
        }
    }
    
    Context "Credential Management Operations" {
        It "Should list all credentials" {
            $allCredentials = Get-AllSecureCredentials
            $allCredentials | Should -Not -BeNullOrEmpty
            
            # Should include our test credentials
            $credentialNames = $allCredentials | ForEach-Object { $_.Name }
            $credentialNames | Should -Contain $TestCredentials.UserPassword.Name
            $credentialNames | Should -Contain $TestCredentials.APIKey.Name
        }
        
        It "Should filter credentials by type" {
            $userPasswordCreds = Get-AllSecureCredentials -FilterType "UserPassword"
            $userPasswordCreds | ForEach-Object { $_.Type | Should -Be "UserPassword" }
            
            $apiKeyCreds = Get-AllSecureCredentials -FilterType "APIKey"
            $apiKeyCreds | ForEach-Object { $_.Type | Should -Be "APIKey" }
        }
        
        It "Should validate credential store integrity" {
            $validationResult = Test-SecureCredentialStore
            
            $validationResult | Should -Not -BeNullOrEmpty
            $validationResult.TotalCredentials | Should -BeGreaterThan 0
            $validationResult.ValidCredentials | Should -BeGreaterThan 0
            $validationResult.StoragePathExists | Should -Be $true
        }
        
        It "Should create credential store backup" {
            $tempBackupPath = [System.IO.Path]::GetTempFileName()
            
            try {
                $backupResult = Backup-SecureCredentialStore -BackupPath $tempBackupPath
                
                $backupResult.Success | Should -Be $true
                $backupResult.CredentialCount | Should -BeGreaterThan 0
                Test-Path $tempBackupPath | Should -Be $true
                
                $backupData = Get-Content $tempBackupPath | ConvertFrom-Json
                $backupData.BackupInfo | Should -Not -BeNullOrEmpty
                $backupData.Credentials | Should -Not -BeNullOrEmpty
            }
            finally {
                if (Test-Path $tempBackupPath) {
                    Remove-Item $tempBackupPath -Force
                }
            }
        }
    }
    
    Context "Error Handling and Edge Cases" {
        It "Should handle duplicate credential names" {
            $duplicateName = "DuplicateTest-$(Get-Random)"
            
            # Create first credential
            New-SecureCredential -CredentialName $duplicateName `
                -CredentialType "UserPassword" `
                -Username "test1" `
                -Password (ConvertTo-SecureString "test1" -AsPlainText -Force)
            
            try {
                # Attempt to create duplicate should succeed (overwrite)
                $result = New-SecureCredential -CredentialName $duplicateName `
                    -CredentialType "UserPassword" `
                    -Username "test2" `
                    -Password (ConvertTo-SecureString "test2" -AsPlainText -Force)
                
                $result.Success | Should -Be $true
                
                # Verify the credential was updated
                $retrieved = Get-SecureCredential -CredentialName $duplicateName
                $retrieved.Username | Should -Be "test2"
            }
            finally {
                Remove-SecureCredential -CredentialName $duplicateName -Force
            }
        }
        
        It "Should handle removal of non-existent credentials gracefully" {
            { Remove-SecureCredential -CredentialName "NonExistent-$(Get-Random)" -Force } | Should -Throw
        }
        
        It "Should handle corrupted credential files" {
            $corruptedCredName = "CorruptedTest-$(Get-Random)"
            $storagePath = Get-CredentialStoragePath
            $corruptedFile = Join-Path $storagePath "$corruptedCredName.json"
            
            try {
                # Create a corrupted file
                "{ invalid json content }" | Set-Content -Path $corruptedFile
                
                # Should handle gracefully
                $result = Get-SecureCredential -CredentialName $corruptedCredName
                $result | Should -BeNullOrEmpty
                
                Test-SecureCredential -CredentialName $corruptedCredName | Should -Be $false
            }
            finally {
                if (Test-Path $corruptedFile) {
                    Remove-Item $corruptedFile -Force
                }
            }
        }
    }
    
    Context "Cross-Platform Compatibility" {
        It "Should work on current platform" {
            $platformInfo = @{
                IsWindows = $IsWindows
                IsLinux = $IsLinux
                IsMacOS = $IsMacOS
                PSEdition = $PSVersionTable.PSEdition
            }
            
            Write-CustomLog -Level 'INFO' -Message "Testing on platform" -Context $platformInfo
            
            # Basic functionality should work on all platforms
            $testCredName = "PlatformTest-$(Get-Random)"
            
            try {
                $result = New-SecureCredential -CredentialName $testCredName `
                    -CredentialType "UserPassword" `
                    -Username "platformtest" `
                    -Password (ConvertTo-SecureString "PlatformP@ss!" -AsPlainText -Force)
                
                $result.Success | Should -Be $true
                
                $retrieved = Get-SecureCredential -CredentialName $testCredName
                $retrieved | Should -Not -BeNullOrEmpty
                $retrieved.Username | Should -Be "platformtest"
                
                Test-SecureCredential -CredentialName $testCredName -ValidateContent | Should -Be $true
            }
            finally {
                if (Test-SecureCredential -CredentialName $testCredName -Quiet) {
                    Remove-SecureCredential -CredentialName $testCredName -Force
                }
            }
        }
        
        It "Should use appropriate encryption method for platform" {
            $testString = "Platform encryption test"
            $encrypted = Protect-String -PlainText $testString
            
            $encryptedData = $encrypted | ConvertFrom-Json
            
            if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') {
                $encryptedData.Method | Should -Be "DPAPI"
            } else {
                $encryptedData.Method | Should -Be "AES-256-CBC"
            }
        }
    }
    
    Context "Performance and Scalability" {
        It "Should handle multiple credentials efficiently" {
            $credentialCount = 10
            $testCredentials = @()
            
            try {
                # Create multiple credentials
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                
                for ($i = 1; $i -le $credentialCount; $i++) {
                    $credName = "PerfTest-$i-$(Get-Random)"
                    $testCredentials += $credName
                    
                    New-SecureCredential -CredentialName $credName `
                        -CredentialType "UserPassword" `
                        -Username "user$i" `
                        -Password (ConvertTo-SecureString "Pass$i!" -AsPlainText -Force)
                }
                
                $stopwatch.Stop()
                $creationTime = $stopwatch.ElapsedMilliseconds
                
                Write-CustomLog -Level 'INFO' -Message "Created $credentialCount credentials in $creationTime ms"
                
                # Test retrieval performance
                $stopwatch.Restart()
                $allCreds = Get-AllSecureCredentials
                $stopwatch.Stop()
                $retrievalTime = $stopwatch.ElapsedMilliseconds
                
                Write-CustomLog -Level 'INFO' -Message "Retrieved all credentials in $retrievalTime ms"
                
                # Performance should be reasonable (less than 5 seconds for 10 credentials)
                $creationTime | Should -BeLessThan 5000
                $retrievalTime | Should -BeLessThan 2000
                
                $allCreds.Count | Should -BeGreaterOrEqual $credentialCount
            }
            finally {
                # Cleanup
                foreach ($credName in $testCredentials) {
                    try {
                        if (Test-SecureCredential -CredentialName $credName -Quiet) {
                            Remove-SecureCredential -CredentialName $credName -Force
                        }
                    }
                    catch {
                        Write-CustomLog -Level 'WARN' -Message "Failed to cleanup credential $credName"
                    }
                }
            }
        }
    }
}

Write-CustomLog -Level 'SUCCESS' -Message "SecureCredentials module tests completed"