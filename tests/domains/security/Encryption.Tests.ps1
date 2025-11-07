#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

BeforeAll {
    # Import the Encryption module
    $projectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    $modulePath = Join-Path $projectRoot "domains/security/Encryption.psm1"
    
    if (-not (Test-Path $modulePath)) {
        throw "Encryption module not found at: $modulePath"
    }
    
    Import-Module $modulePath -Force
}

Describe "Encryption Module Tests" {
    Context "Module Loading" {
        It "Should load the Encryption module successfully" {
            Get-Module | Where-Object { $_.Path -like "*Encryption.psm1" } | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Protect-String function" {
            Get-Command Protect-String -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Unprotect-String function" {
            Get-Command Unprotect-String -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Protect-File function" {
            Get-Command Protect-File -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Unprotect-File function" {
            Get-Command Unprotect-File -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export New-EncryptionKey function" {
            Get-Command New-EncryptionKey -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Get-DataHash function" {
            Get-Command Get-DataHash -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Key Generation" {
        It "Should generate a random encryption key" {
            $key = New-EncryptionKey
            $key | Should -Not -BeNullOrEmpty
            $key | Should -BeOfType [string]
        }
        
        It "Should generate keys of specified size" {
            $key = New-EncryptionKey -KeySize 64
            $keyBytes = [Convert]::FromBase64String($key)
            $keyBytes.Length | Should -Be 64
        }
        
        It "Should generate different keys each time" {
            $key1 = New-EncryptionKey
            $key2 = New-EncryptionKey
            $key1 | Should -Not -Be $key2
        }
    }
    
    Context "String Encryption and Decryption" {
        It "Should encrypt a string successfully" {
            $plainText = "This is a test message"
            $key = "TestKey123"
            
            $encrypted = Protect-String -PlainText $plainText -Key $key
            
            $encrypted | Should -Not -BeNullOrEmpty
            $encrypted.EncryptedData | Should -Not -BeNullOrEmpty
            $encrypted.Salt | Should -Not -BeNullOrEmpty
            $encrypted.IV | Should -Not -BeNullOrEmpty
        }
        
        It "Should decrypt an encrypted string successfully" {
            $plainText = "Secret message for testing"
            $key = "SecureKey456"
            
            $encrypted = Protect-String -PlainText $plainText -Key $key
            $decrypted = Unprotect-String -EncryptedData $encrypted.EncryptedData -Key $key -Salt $encrypted.Salt -IV $encrypted.IV
            
            $decrypted | Should -Be $plainText
        }
        
        It "Should produce different encrypted data for same plaintext with different keys" {
            $plainText = "Same message"
            $key1 = "Key1"
            $key2 = "Key2"
            
            $encrypted1 = Protect-String -PlainText $plainText -Key $key1
            $encrypted2 = Protect-String -PlainText $plainText -Key $key2
            
            $encrypted1.EncryptedData | Should -Not -Be $encrypted2.EncryptedData
        }
        
        It "Should fail to decrypt with wrong key" {
            $plainText = "Secret"
            $correctKey = "CorrectKey"
            $wrongKey = "WrongKey"
            
            $encrypted = Protect-String -PlainText $plainText -Key $correctKey
            
            { Unprotect-String -EncryptedData $encrypted.EncryptedData -Key $wrongKey -Salt $encrypted.Salt -IV $encrypted.IV } | 
                Should -Throw
        }
        
        It "Should handle empty strings" {
            $plainText = ""
            $key = "TestKey"
            
            { Protect-String -PlainText $plainText -Key $key } | Should -Throw
        }
        
        It "Should handle multi-line strings" {
            $plainText = @"
Line 1
Line 2
Line 3
"@
            $key = "MultiLineKey"
            
            $encrypted = Protect-String -PlainText $plainText -Key $key
            $decrypted = Unprotect-String -EncryptedData $encrypted.EncryptedData -Key $key -Salt $encrypted.Salt -IV $encrypted.IV
            
            $decrypted | Should -Be $plainText
        }
        
        It "Should handle special characters" {
            $plainText = "Special chars: !@#$%^&*()_+-=[]{}|;:',.<>?/~``"
            $key = "SpecialKey"
            
            $encrypted = Protect-String -PlainText $plainText -Key $key
            $decrypted = Unprotect-String -EncryptedData $encrypted.EncryptedData -Key $key -Salt $encrypted.Salt -IV $encrypted.IV
            
            $decrypted | Should -Be $plainText
        }
    }
    
    Context "File Encryption and Decryption" {
        BeforeEach {
            # Create temp directory for tests
            $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "encryption-tests-$(New-Guid)"
            New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
        }
        
        AfterEach {
            # Cleanup
            if (Test-Path $script:testDir) {
                Remove-Item -Path $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        It "Should encrypt a file successfully" {
            $testFile = Join-Path $script:testDir "test.txt"
            "Test file content" | Out-File -FilePath $testFile -NoNewline
            
            $key = "FileKey123"
            $result = Protect-File -Path $testFile -Key $key
            
            $result.EncryptedFile | Should -Exist
            $result.MetadataFile | Should -Exist
            Test-Path $result.EncryptedFile | Should -Be $true
            Test-Path $result.MetadataFile | Should -Be $true
        }
        
        It "Should decrypt a file successfully" {
            $testFile = Join-Path $script:testDir "original.txt"
            $content = "Original content for decryption test"
            $content | Out-File -FilePath $testFile -NoNewline
            
            $key = "FileKey456"
            $encrypted = Protect-File -Path $testFile -Key $key
            
            $decryptedPath = Unprotect-File -Path $encrypted.EncryptedFile -Key $key
            
            Test-Path $decryptedPath | Should -Be $true
            $decryptedContent = Get-Content -Path $decryptedPath -Raw
            $decryptedContent | Should -Be $content
        }
        
        It "Should preserve file content during encryption/decryption cycle" {
            $testFile = Join-Path $script:testDir "preserve.ps1"
            $scriptContent = @'
#Requires -Version 7.0
function Test-Function {
    param($Value)
    Write-Output "Value: $Value"
}
'@
            $scriptContent | Out-File -FilePath $testFile -NoNewline
            
            $key = New-EncryptionKey
            $encrypted = Protect-File -Path $testFile -Key $key
            $decrypted = Unprotect-File -Path $encrypted.EncryptedFile -Key $key
            
            $finalContent = Get-Content -Path $decrypted -Raw
            $finalContent | Should -Be $scriptContent
        }
        
        It "Should fail to decrypt with wrong key" {
            $testFile = Join-Path $script:testDir "secure.txt"
            "Secure content" | Out-File -FilePath $testFile -NoNewline
            
            $correctKey = "Correct"
            $wrongKey = "Wrong"
            
            $encrypted = Protect-File -Path $testFile -Key $correctKey
            
            { Unprotect-File -Path $encrypted.EncryptedFile -Key $wrongKey } | Should -Throw
        }
        
        It "Should store metadata correctly" {
            $testFile = Join-Path $script:testDir "metadata.txt"
            "Metadata test" | Out-File -FilePath $testFile -NoNewline
            
            $key = "MetaKey"
            $encrypted = Protect-File -Path $testFile -Key $key
            
            $metadata = Get-Content -Path $encrypted.MetadataFile -Raw | ConvertFrom-Json
            
            $metadata.Salt | Should -Not -BeNullOrEmpty
            $metadata.IV | Should -Not -BeNullOrEmpty
            $metadata.OriginalFile | Should -Be "metadata.txt"
            $metadata.Algorithm | Should -Be "AES-256-CBC"
        }
    }
    
    Context "Data Hashing" {
        It "Should compute HMAC-SHA256 hash" {
            $data = "Test data"
            $key = "HashKey"
            
            $hash = Get-DataHash -Data $data -Key $key
            
            $hash | Should -Not -BeNullOrEmpty
            $hash | Should -BeOfType [string]
        }
        
        It "Should produce consistent hashes for same input" {
            $data = "Consistent data"
            $key = "SameKey"
            
            $hash1 = Get-DataHash -Data $data -Key $key
            $hash2 = Get-DataHash -Data $data -Key $key
            
            $hash1 | Should -Be $hash2
        }
        
        It "Should produce different hashes for different keys" {
            $data = "Same data"
            $key1 = "Key1"
            $key2 = "Key2"
            
            $hash1 = Get-DataHash -Data $data -Key $key1
            $hash2 = Get-DataHash -Data $data -Key $key2
            
            $hash1 | Should -Not -Be $hash2
        }
        
        It "Should produce different hashes for different data" {
            $data1 = "Data 1"
            $data2 = "Data 2"
            $key = "SameKey"
            
            $hash1 = Get-DataHash -Data $data1 -Key $key
            $hash2 = Get-DataHash -Data $data2 -Key $key
            
            $hash1 | Should -Not -Be $hash2
        }
    }
}
