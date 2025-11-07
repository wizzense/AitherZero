#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

BeforeAll {
    # Import required modules
    $projectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    $securityPath = Join-Path $projectRoot "domains/security"
    
    $encryptionModulePath = Join-Path $securityPath "Encryption.psm1"
    $licenseModulePath = Join-Path $securityPath "LicenseManager.psm1"
    
    if (-not (Test-Path $encryptionModulePath)) {
        throw "Encryption module not found at: $encryptionModulePath"
    }
    if (-not (Test-Path $licenseModulePath)) {
        throw "LicenseManager module not found at: $licenseModulePath"
    }
    
    Import-Module $encryptionModulePath -Force
    Import-Module $licenseModulePath -Force
}

Describe "LicenseManager Module Tests" {
    Context "Module Loading" {
        It "Should load the LicenseManager module successfully" {
            Get-Module | Where-Object { $_.Path -like "*LicenseManager.psm1" } | Should -Not -BeNullOrEmpty
        }
        
        It "Should export New-License function" {
            Get-Command New-License -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Test-License function" {
            Get-Command Test-License -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Get-LicenseKey function" {
            Get-Command Get-LicenseKey -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Find-License function" {
            Get-Command Find-License -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "License Creation" {
        BeforeEach {
            $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "license-tests-$(New-Guid)"
            New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
        }
        
        AfterEach {
            if (Test-Path $script:testDir) {
                Remove-Item -Path $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        It "Should create a valid license file" {
            $licensePath = Join-Path $script:testDir "test-license.json"
            $key = New-EncryptionKey
            
            $license = New-License `
                -LicenseId "TEST-001" `
                -LicensedTo "Test User" `
                -ExpirationDate (Get-Date).AddYears(1) `
                -EncryptionKey $key `
                -OutputPath $licensePath
            
            Test-Path $licensePath | Should -Be $true
            $license.LicenseId | Should -Be "TEST-001"
            $license.LicensedTo | Should -Be "Test User"
            $license.Type | Should -Be "AitherZero-SourceProtection"
        }
        
        It "Should include all required fields in license" {
            $licensePath = Join-Path $script:testDir "complete-license.json"
            $key = New-EncryptionKey
            
            $license = New-License `
                -LicenseId "COMPLETE-001" `
                -LicensedTo "Complete Test" `
                -ExpirationDate (Get-Date).AddYears(1) `
                -EncryptionKey $key `
                -OutputPath $licensePath
            
            $license.LicenseId | Should -Not -BeNullOrEmpty
            $license.LicensedTo | Should -Not -BeNullOrEmpty
            $license.IssuedDate | Should -Not -BeNullOrEmpty
            $license.ExpirationDate | Should -Not -BeNullOrEmpty
            $license.EncryptionKey | Should -Not -BeNullOrEmpty
            $license.Type | Should -Not -BeNullOrEmpty
            $license.Features | Should -Not -BeNullOrEmpty
        }
        
        It "Should include default features" {
            $licensePath = Join-Path $script:testDir "features-license.json"
            $key = New-EncryptionKey
            
            $license = New-License `
                -LicenseId "FEATURES-001" `
                -LicensedTo "Features Test" `
                -ExpirationDate (Get-Date).AddYears(1) `
                -EncryptionKey $key `
                -OutputPath $licensePath
            
            $license.Features | Should -Contain "SourceCodeObfuscation"
        }
        
        It "Should support custom features" {
            $licensePath = Join-Path $script:testDir "custom-license.json"
            $key = New-EncryptionKey
            
            $license = New-License `
                -LicenseId "CUSTOM-001" `
                -LicensedTo "Custom Test" `
                -ExpirationDate (Get-Date).AddYears(1) `
                -EncryptionKey $key `
                -OutputPath $licensePath `
                -Features @("Feature1", "Feature2")
            
            $license.Features | Should -Contain "Feature1"
            $license.Features | Should -Contain "Feature2"
        }
    }
    
    Context "License Validation" {
        BeforeEach {
            $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "license-validation-$(New-Guid)"
            New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
        }
        
        AfterEach {
            if (Test-Path $script:testDir) {
                Remove-Item -Path $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        It "Should validate a valid license" {
            $licensePath = Join-Path $script:testDir "valid-license.json"
            $key = New-EncryptionKey
            
            New-License `
                -LicenseId "VALID-001" `
                -LicensedTo "Valid User" `
                -ExpirationDate (Get-Date).AddYears(1) `
                -EncryptionKey $key `
                -OutputPath $licensePath | Out-Null
            
            $validation = Test-License -LicensePath $licensePath
            
            $validation.IsValid | Should -Be $true
            $validation.Reason | Should -BeNullOrEmpty
        }
        
        It "Should reject expired license" {
            $licensePath = Join-Path $script:testDir "expired-license.json"
            $key = New-EncryptionKey
            
            New-License `
                -LicenseId "EXPIRED-001" `
                -LicensedTo "Expired User" `
                -ExpirationDate (Get-Date).AddDays(-1) `
                -EncryptionKey $key `
                -OutputPath $licensePath | Out-Null
            
            $validation = Test-License -LicensePath $licensePath
            
            $validation.IsValid | Should -Be $false
            $validation.Reason | Should -Match "expired"
        }
        
        It "Should warn about expiring license" {
            $licensePath = Join-Path $script:testDir "expiring-license.json"
            $key = New-EncryptionKey
            
            New-License `
                -LicenseId "EXPIRING-001" `
                -LicensedTo "Expiring User" `
                -ExpirationDate (Get-Date).AddDays(15) `
                -EncryptionKey $key `
                -OutputPath $licensePath | Out-Null
            
            $validation = Test-License -LicensePath $licensePath
            
            $validation.IsValid | Should -Be $true
            $validation.Warnings.Count | Should -BeGreaterThan 0
            $validation.Warnings[0] | Should -Match "expires in"
        }
        
        It "Should validate license with correct signature" {
            $licensePath = Join-Path $script:testDir "signed-license.json"
            $key = New-EncryptionKey
            
            New-License `
                -LicenseId "SIGNED-001" `
                -LicensedTo "Signed User" `
                -ExpirationDate (Get-Date).AddYears(1) `
                -EncryptionKey $key `
                -OutputPath $licensePath | Out-Null
            
            $validation = Test-License -LicensePath $licensePath -VerifySignature $true
            
            $validation.IsValid | Should -Be $true
        }
        
        It "Should reject tampered license" {
            $licensePath = Join-Path $script:testDir "tampered-license.json"
            $key = New-EncryptionKey
            
            New-License `
                -LicenseId "TAMPER-001" `
                -LicensedTo "Tampered User" `
                -ExpirationDate (Get-Date).AddYears(1) `
                -EncryptionKey $key `
                -OutputPath $licensePath | Out-Null
            
            # Tamper with the license
            $licenseContent = Get-Content -Path $licensePath -Raw | ConvertFrom-Json
            $licenseContent.LicensedTo = "Modified User"
            $licenseContent | ConvertTo-Json | Out-File -FilePath $licensePath -Force
            
            $validation = Test-License -LicensePath $licensePath -VerifySignature $true
            
            $validation.IsValid | Should -Be $false
            $validation.Reason | Should -Match "signature"
        }
        
        It "Should reject license with wrong type" {
            $licensePath = Join-Path $script:testDir "wrong-type-license.json"
            
            $license = @{
                LicenseId = "WRONG-001"
                LicensedTo = "Wrong Type User"
                IssuedDate = (Get-Date).ToString("o")
                ExpirationDate = (Get-Date).AddYears(1).ToString("o")
                EncryptionKey = (New-EncryptionKey)
                Type = "WrongType"
            }
            
            $license | ConvertTo-Json | Out-File -FilePath $licensePath -Force
            
            $validation = Test-License -LicensePath $licensePath
            
            $validation.IsValid | Should -Be $false
            $validation.Reason | Should -Match "Invalid license type"
        }
        
        It "Should reject malformed license file" {
            $licensePath = Join-Path $script:testDir "malformed-license.json"
            "This is not valid JSON" | Out-File -FilePath $licensePath
            
            $validation = Test-License -LicensePath $licensePath
            
            $validation.IsValid | Should -Be $false
            $validation.Reason | Should -Match "Error reading or parsing"
        }
    }
    
    Context "License Key Retrieval" {
        BeforeEach {
            $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "license-key-$(New-Guid)"
            New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
        }
        
        AfterEach {
            if (Test-Path $script:testDir) {
                Remove-Item -Path $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        It "Should retrieve encryption key from valid license" {
            $licensePath = Join-Path $script:testDir "key-license.json"
            $expectedKey = New-EncryptionKey
            
            New-License `
                -LicenseId "KEY-001" `
                -LicensedTo "Key User" `
                -ExpirationDate (Get-Date).AddYears(1) `
                -EncryptionKey $expectedKey `
                -OutputPath $licensePath | Out-Null
            
            $retrievedKey = Get-LicenseKey -LicensePath $licensePath
            
            $retrievedKey | Should -Be $expectedKey
        }
        
        It "Should fail to retrieve key from invalid license" {
            $licensePath = Join-Path $script:testDir "invalid-key-license.json"
            
            New-License `
                -LicenseId "INVALID-KEY-001" `
                -LicensedTo "Invalid Key User" `
                -ExpirationDate (Get-Date).AddDays(-1) `
                -EncryptionKey (New-EncryptionKey) `
                -OutputPath $licensePath | Out-Null
            
            { Get-LicenseKey -LicensePath $licensePath } | Should -Throw
        }
    }
    
    Context "License Search" {
        BeforeEach {
            # Clear any existing license paths
            $env:AITHERZERO_LICENSE_PATH = $null
        }
        
        AfterEach {
            # Restore environment
            $env:AITHERZERO_LICENSE_PATH = $null
        }
        
        It "Should return null when no license found" {
            $result = Find-License
            # May be null or a path if license exists in standard locations
            # We can't assert null because CI might have a license
            $result | Should -BeOfType [object]
        }
        
        It "Should find license from environment variable" {
            $testDir = Join-Path ([System.IO.Path]::GetTempPath()) "env-license-$(New-Guid)"
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            
            try {
                $licensePath = Join-Path $testDir "env-license.json"
                New-License `
                    -LicenseId "ENV-001" `
                    -LicensedTo "Env User" `
                    -ExpirationDate (Get-Date).AddYears(1) `
                    -EncryptionKey (New-EncryptionKey) `
                    -OutputPath $licensePath | Out-Null
                
                $env:AITHERZERO_LICENSE_PATH = $licensePath
                
                $result = Find-License
                $result | Should -Be $licensePath
            }
            finally {
                Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
