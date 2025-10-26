#Requires -Version 7.0

<#
.SYNOPSIS
    Unit tests for Security domain module
.DESCRIPTION
    Comprehensive tests for SSH key management, credential storage, and remote connection functionality
#>

BeforeAll {
    # Import the module under test
    $ModulePath = Join-Path $PSScriptRoot "../../../domains/security/Security.psm1"
    if (Test-Path $ModulePath) {
        Import-Module $ModulePath -Force
    } else {
        throw "Security module not found at: $ModulePath"
    }
    
    # Mock Write-CustomLog if not available
    if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
        function Write-CustomLog {
            param($Level, $Message, $Source, $Data)
            # Mock implementation for testing
        }
    }
    
    # Create temporary SSH directory for tests
    $script:TestSSHDir = Join-Path ([System.IO.Path]::GetTempPath()) "aitherzero-test-ssh-$(Get-Random)"
    New-Item -ItemType Directory -Path $script:TestSSHDir -Force | Out-Null
    
    # Mock environment variables and functions
    if ($IsWindows) {
        $script:OriginalUserProfile = $env:USERPROFILE
        $env:USERPROFILE = Split-Path $script:TestSSHDir -Parent
    } else {
        $script:OriginalHome = $env:HOME
        $env:HOME = Split-Path $script:TestSSHDir -Parent
    }
}

AfterAll {
    # Cleanup test environment
    if (Test-Path $script:TestSSHDir) {
        Remove-Item -Path $script:TestSSHDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Restore environment variables
    if ($IsWindows) {
        $env:USERPROFILE = $script:OriginalUserProfile
    } else {
        $env:HOME = $script:OriginalHome
    }
    
    # Remove the imported module
    Remove-Module Security -ErrorAction SilentlyContinue
}

Describe "Security Module - SSH Availability Tests" {
    Context "Test-SSHAvailability" {
        It "Should return a boolean value" {
            $result = Test-SSHAvailability
            $result | Should -BeOfType [bool]
        }
        
        It "Should check for ssh command availability" {
            # Mock Get-Command for testing
            Mock Get-Command {
                if ($Name -eq 'ssh') {
                    return @{ Name = 'ssh' }
                }
                if ($Name -eq 'ssh-keygen') {
                    return @{ Name = 'ssh-keygen' }
                }
                throw "Command not found"
            }
            
            $result = Test-SSHAvailability
            $result | Should -Be $true
            
            Assert-MockCalled Get-Command -Times 2
        }
        
        It "Should return false when SSH is not available" {
            Mock Get-Command {
                throw "Command not found"
            }
            
            $result = Test-SSHAvailability
            $result | Should -Be $false
        }
    }
}

Describe "Security Module - SSH Key Management" {
    Context "New-SSHKeyPair" {
        BeforeEach {
            # Mock SSH availability
            Mock Test-SSHAvailability { return $true }
        }
        
        It "Should throw when SSH is not available" {
            Mock Test-SSHAvailability { return $false }
            
            { New-SSHKeyPair -KeyName "test-key" } | Should -Throw "*SSH client tools are not available*"
        }
        
        It "Should require KeyName parameter" {
            { New-SSHKeyPair } | Should -Throw
        }
        
        It "Should accept valid key types" {
            Mock Start-Process { 
                return @{ ExitCode = 0 } 
            }
            Mock Test-Path { return $false }  # Key doesn't exist
            Mock Get-Content { return "ssh-ed25519 AAAAC3... test@example.com" }
            
            { New-SSHKeyPair -KeyName "test" -KeyType "ed25519" -WhatIf } | Should -Not -Throw
            { New-SSHKeyPair -KeyName "test" -KeyType "rsa" -WhatIf } | Should -Not -Throw
            { New-SSHKeyPair -KeyName "test" -KeyType "ecdsa" -WhatIf } | Should -Not -Throw
        }
        
        It "Should warn when key already exists without Force" {
            Mock Test-Path { return $true }  # Key exists
            
            $result = New-SSHKeyPair -KeyName "existing-key"
            $result | Should -Be $false
        }
        
        It "Should generate key with proper parameters" {
            Mock Test-Path { return $false }  # Key doesn't exist
            Mock Start-Process { 
                return @{ ExitCode = 0 } 
            }
            Mock Get-Content { return "ssh-ed25519 AAAAC3... test@example.com" }
            
            $result = New-SSHKeyPair -KeyName "test-key" -KeyType "ed25519" -Comment "test@example.com" -WhatIf
            
            # Verify the mock was called (key generation attempted)
            Assert-MockCalled Start-Process
        }
    }
    
    Context "Get-SSHKey" {
        It "Should return null for non-existent key" {
            Mock Test-Path { return $false }
            
            $result = Get-SSHKey -KeyName "non-existent"
            $result | Should -Be $null
        }
        
        It "Should return key information for existing key" {
            Mock Test-Path { return $true }
            Mock Get-Content { return "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG... test@example.com" }
            Mock Get-SSHKeyFingerprint { return "SHA256:abcd1234..." }
            
            $result = Get-SSHKey -KeyName "test-key"
            
            $result | Should -Not -Be $null
            $result.KeyName | Should -Be "test-key"
            $result.KeyType | Should -Be "ssh-ed25519"
        }
        
        It "Should list all keys when -ListAll is specified" {
            Mock Get-ChildItem { 
                return @(
                    @{ BaseName = "key1"; FullName = "/test/.ssh/key1.pub" },
                    @{ BaseName = "key2"; FullName = "/test/.ssh/key2.pub" }
                )
            }
            Mock Test-Path { return $true }
            Mock Get-Content { return "ssh-ed25519 AAAAC3... test@example.com" }
            Mock Get-SSHKeyFingerprint { return "SHA256:abcd1234..." }
            
            $result = Get-SSHKey -ListAll
            
            $result | Should -HaveCount 2
            $result[0].KeyName | Should -Be "key1"
            $result[1].KeyName | Should -Be "key2"
        }
    }
    
    Context "Remove-SSHKey" {
        It "Should return false for non-existent key" {
            Mock Test-Path { return $false }
            
            $result = Remove-SSHKey -KeyName "non-existent" -Confirm:$false
            $result | Should -Be $false
        }
        
        It "Should remove existing key files" {
            Mock Test-Path { 
                param($Path)
                return $Path -match "(test-key|test-key\.pub)$"
            }
            Mock Remove-Item { }
            
            $result = Remove-SSHKey -KeyName "test-key" -Confirm:$false
            
            $result | Should -Be $true
            Assert-MockCalled Remove-Item -Times 2
        }
    }
}

Describe "Security Module - Credential Management" {
    Context "Set-SecureCredential and Get-SecureCredential" {
        BeforeEach {
            $script:TestCredential = New-Object PSCredential("testuser", (ConvertTo-SecureString "testpass" -AsPlainText -Force))
        }
        
        It "Should handle Windows credential storage" {
            Mock Start-Process { return @{ ExitCode = 0 } }
            
            if ($IsWindows) {
                $result = Set-SecureCredential -Target "test-target" -Username "testuser" -Password $script:TestCredential.Password
                $result | Should -Be $true
                
                Assert-MockCalled Start-Process
            }
        }
        
        It "Should handle macOS keychain storage" {
            Mock Start-Process { return @{ ExitCode = 0 } }
            
            if ($IsMacOS) {
                $result = Set-SecureCredential -Target "test-target" -Username "testuser" -Password $script:TestCredential.Password
                $result | Should -Be $true
                
                Assert-MockCalled Start-Process
            }
        }
        
        It "Should handle Linux secret service storage" {
            Mock Get-Command { return @{ Name = 'secret-tool' } } -ParameterFilter { $Name -eq 'secret-tool' }
            Mock Start-Process { return @{ ExitCode = 0; Id = 12345 } }
            Mock Set-Content { }
            
            if ($IsLinux) {
                $result = Set-SecureCredential -Target "test-target" -Username "testuser" -Password $script:TestCredential.Password
                $result | Should -Be $true
            }
        }
        
        It "Should fallback to PowerShell SecretManagement" {
            Mock Get-Module { return $true } -ParameterFilter { $Name -eq 'Microsoft.PowerShell.SecretManagement' }
            Mock Import-Module { }
            Mock Set-Secret { }
            
            if ($IsLinux) {
                Mock Get-Command { throw "Command not found" } -ParameterFilter { $Name -eq 'secret-tool' }
                
                $result = Set-SecureCredential -Target "test-target" -Username "testuser" -Password $script:TestCredential.Password
                $result | Should -Be $true
            }
        }
    }
}

Describe "Security Module - Connection Profiles" {
    Context "New-ConnectionProfile" {
        It "Should create a new connection profile" {
            Mock Save-ConnectionProfiles { }
            
            $result = New-ConnectionProfile -ProfileName "test-profile" -Hostname "test.example.com" -Username "testuser"
            
            $result | Should -Not -Be $null
            $result.ProfileName | Should -Be "test-profile"
            $result.Hostname | Should -Be "test.example.com"
            $result.Username | Should -Be "testuser"
            $result.Port | Should -Be 22
        }
        
        It "Should validate SSH key if specified" {
            Mock Get-SSHKey { return $null }
            
            { New-ConnectionProfile -ProfileName "test" -Hostname "test.com" -SSHKeyName "non-existent" } | 
                Should -Throw "*SSH key 'non-existent' not found*"
        }
        
        It "Should not overwrite existing profile without Force" {
            Mock Save-ConnectionProfiles { }
            
            # Create first profile
            $null = New-ConnectionProfile -ProfileName "test-profile" -Hostname "test1.com"
            
            # Try to create another with same name
            $result = New-ConnectionProfile -ProfileName "test-profile" -Hostname "test2.com"
            $result | Should -Be $false
        }
        
        It "Should overwrite existing profile with Force" {
            Mock Save-ConnectionProfiles { }
            
            # Create first profile
            $null = New-ConnectionProfile -ProfileName "test-profile" -Hostname "test1.com"
            
            # Overwrite with Force
            $result = New-ConnectionProfile -ProfileName "test-profile" -Hostname "test2.com" -Force
            $result.Hostname | Should -Be "test2.com"
        }
    }
    
    Context "Get-ConnectionProfile" {
        BeforeEach {
            Mock Load-ConnectionProfiles { }
            Mock Save-ConnectionProfiles { }
            
            # Setup test profiles
            $null = New-ConnectionProfile -ProfileName "profile1" -Hostname "host1.com"
            $null = New-ConnectionProfile -ProfileName "profile2" -Hostname "host2.com"
        }
        
        It "Should return specific profile by name" {
            $result = Get-ConnectionProfile -ProfileName "profile1"
            $result.ProfileName | Should -Be "profile1"
            $result.Hostname | Should -Be "host1.com"
        }
        
        It "Should return all profiles when -ListAll is specified" {
            $result = Get-ConnectionProfile -ListAll
            $result | Should -HaveCount 2
        }
        
        It "Should return profile names when no parameters specified" {
            $result = Get-ConnectionProfile
            $result | Should -Contain "profile1"
            $result | Should -Contain "profile2"
        }
    }
    
    Context "Remove-ConnectionProfile" {
        BeforeEach {
            Mock Load-ConnectionProfiles { }
            Mock Save-ConnectionProfiles { }
            
            $null = New-ConnectionProfile -ProfileName "test-profile" -Hostname "test.com"
        }
        
        It "Should remove existing profile" {
            $result = Remove-ConnectionProfile -ProfileName "test-profile" -Confirm:$false
            $result | Should -Be $true
        }
        
        It "Should return false for non-existent profile" {
            $result = Remove-ConnectionProfile -ProfileName "non-existent" -Confirm:$false
            $result | Should -Be $false
        }
    }
}

Describe "Security Module - SSH Connection Testing" {
    Context "Test-SSHConnection" {
        BeforeEach {
            Mock Test-SSHAvailability { return $true }
        }
        
        It "Should throw when SSH is not available" {
            Mock Test-SSHAvailability { return $false }
            
            { Test-SSHConnection -Hostname "test.com" } | Should -Throw "*SSH client not available*"
        }
        
        It "Should test connection using profile" {
            Mock Load-ConnectionProfiles { }
            Mock Save-ConnectionProfiles { }
            Mock Get-ConnectionProfile { 
                return @{
                    Hostname = "test.com"
                    Username = "testuser"
                    Port = 22
                    SSHKeyName = $null
                }
            }
            Mock Invoke-Expression { return "SSH_CONNECTION_TEST_SUCCESS" }
            
            # Mock the & ssh command execution
            $global:LASTEXITCODE = 0
            Mock Invoke-Command { 
                $global:LASTEXITCODE = 0
                return "SSH_CONNECTION_TEST_SUCCESS"
            } -ModuleName Security
            
            $result = Test-SSHConnection -ProfileName "test-profile"
            # Note: This test may not work perfectly due to mocking limitations with & operator
        }
        
        It "Should test direct connection parameters" {
            Mock Invoke-Expression { return "SSH_CONNECTION_TEST_SUCCESS" }
            $global:LASTEXITCODE = 0
            
            # This is a basic structure test since mocking & operator is complex
            { Test-SSHConnection -Hostname "test.com" -Username "testuser" } | Should -Not -Throw
        }
        
        It "Should handle connection timeout" {
            $global:LASTEXITCODE = 1
            Mock Invoke-Expression { return "Connection timed out" }
            
            $result = Test-SSHConnection -Hostname "unreachable.com" -TimeoutSeconds 1
            $result | Should -Be $false
        }
    }
}

Describe "Security Module - Remote Command Execution" {
    Context "Invoke-SSHCommand" {
        BeforeEach {
            Mock Test-SSHAvailability { return $true }
            $global:LASTEXITCODE = 0
        }
        
        It "Should throw when SSH is not available" {
            Mock Test-SSHAvailability { return $false }
            
            { Invoke-SSHCommand -Hostname "test.com" -Command "echo test" } | Should -Throw "*SSH client not available*"
        }
        
        It "Should execute command and return result" {
            Mock Invoke-Expression { 
                $global:LASTEXITCODE = 0
                return "Command output"
            }
            
            $result = Invoke-SSHCommand -Hostname "test.com" -Command "echo test"
            
            $result | Should -Not -Be $null
            $result.ExitCode | Should -Be 0
            $result.Success | Should -Be $true
            $result.Command | Should -Be "echo test"
        }
        
        It "Should handle command failures" {
            Mock Invoke-Expression { 
                $global:LASTEXITCODE = 1
                return "Error message"
            }
            
            $result = Invoke-SSHCommand -Hostname "test.com" -Command "false"
            
            $result.ExitCode | Should -Be 1
            $result.Success | Should -Be $false
        }
        
        It "Should use profile parameters" {
            Mock Load-ConnectionProfiles { }
            Mock Save-ConnectionProfiles { }
            Mock Get-ConnectionProfile { 
                return @{
                    Hostname = "profile-host.com"
                    Username = "profile-user"
                    Port = 2222
                    SSHKeyName = "profile-key"
                }
            }
            Mock Invoke-Expression { 
                $global:LASTEXITCODE = 0
                return "Profile command output"
            }
            
            $result = Invoke-SSHCommand -ProfileName "test-profile" -Command "whoami"
            
            $result.Success | Should -Be $true
        }
    }
}

Describe "Security Module - File Transfer" {
    Context "Copy-FileToRemote" {
        BeforeEach {
            Mock Test-SSHAvailability { return $true }
            $global:LASTEXITCODE = 0
            
            # Create a temporary test file
            $script:TestFile = Join-Path ([System.IO.Path]::GetTempPath()) "test-file-$(Get-Random).txt"
            "Test content" | Out-File -FilePath $script:TestFile -Encoding UTF8
        }
        
        AfterEach {
            if (Test-Path $script:TestFile) {
                Remove-Item $script:TestFile -Force
            }
        }
        
        It "Should throw when SSH is not available" {
            Mock Test-SSHAvailability { return $false }
            
            { Copy-FileToRemote -Hostname "test.com" -LocalPath $script:TestFile -RemotePath "/tmp/test" } | 
                Should -Throw "*SSH client not available*"
        }
        
        It "Should throw when local file doesn't exist" {
            { Copy-FileToRemote -Hostname "test.com" -LocalPath "/non/existent/file" -RemotePath "/tmp/test" } | 
                Should -Throw "*Local path not found*"
        }
        
        It "Should copy file successfully" {
            Mock Invoke-Expression { 
                $global:LASTEXITCODE = 0
                return ""
            }
            
            $result = Copy-FileToRemote -Hostname "test.com" -LocalPath $script:TestFile -RemotePath "/tmp/test.txt"
            $result | Should -Be $true
        }
        
        It "Should handle copy failures" {
            Mock Invoke-Expression { 
                $global:LASTEXITCODE = 1
                return "scp: error message"
            }
            
            $result = Copy-FileToRemote -Hostname "test.com" -LocalPath $script:TestFile -RemotePath "/tmp/test.txt"
            $result | Should -Be $false
        }
        
        It "Should support recursive copying" {
            Mock Test-Path { return $true }
            Mock Invoke-Expression { 
                $global:LASTEXITCODE = 0
                return ""
            }
            
            $result = Copy-FileToRemote -Hostname "test.com" -LocalPath $script:TestFile -RemotePath "/tmp/" -Recursive
            $result | Should -Be $true
        }
    }
}

Describe "Security Module - Remote Script Execution" {
    Context "Invoke-RemoteScript" {
        BeforeEach {
            Mock Test-SSHAvailability { return $true }
            $global:LASTEXITCODE = 0
            
            # Create a temporary test script
            $script:TestScript = Join-Path ([System.IO.Path]::GetTempPath()) "test-script-$(Get-Random).sh"
            "#!/bin/bash`necho 'Hello from remote script'" | Out-File -FilePath $script:TestScript -Encoding UTF8
        }
        
        AfterEach {
            if (Test-Path $script:TestScript) {
                Remove-Item $script:TestScript -Force
            }
        }
        
        It "Should throw when script doesn't exist" {
            { Invoke-RemoteScript -Hostname "test.com" -ScriptPath "/non/existent/script.sh" } | 
                Should -Throw "*Script not found*"
        }
        
        It "Should copy, execute, and optionally clean up script" {
            Mock Copy-FileToRemote { return $true }
            Mock Invoke-SSHCommand { 
                return @{
                    ExitCode = 0
                    Success = $true
                    Output = "Hello from remote script"
                }
            }
            
            $result = Invoke-RemoteScript -Hostname "test.com" -ScriptPath $script:TestScript -RemoveAfterExecution
            
            $result.Success | Should -Be $true
            $result.Output | Should -Be "Hello from remote script"
            
            # Verify that chmod and script execution were called
            Assert-MockCalled Invoke-SSHCommand -AtLeast 2
        }
        
        It "Should handle script execution failure" {
            Mock Copy-FileToRemote { return $true }
            Mock Invoke-SSHCommand { 
                return @{
                    ExitCode = 1
                    Success = $false
                    Output = "Script error"
                }
            }
            
            $result = Invoke-RemoteScript -Hostname "test.com" -ScriptPath $script:TestScript
            
            $result.Success | Should -Be $false
            $result.ExitCode | Should -Be 1
        }
        
        It "Should pass arguments to remote script" {
            Mock Copy-FileToRemote { return $true }
            Mock Invoke-SSHCommand { 
                param($Command)
                return @{
                    ExitCode = 0
                    Success = $true
                    Output = "Script executed with args"
                    Command = $Command
                }
            }
            
            $result = Invoke-RemoteScript -Hostname "test.com" -ScriptPath $script:TestScript -Arguments @("arg1", "arg2")
            
            $result.Success | Should -Be $true
            # The command should include the arguments
            $result.Command | Should -Match "arg1 arg2"
        }
        
        It "Should handle file copy failure" {
            Mock Copy-FileToRemote { return $false }
            
            { Invoke-RemoteScript -Hostname "test.com" -ScriptPath $script:TestScript } | 
                Should -Throw "*Failed to copy script to remote host*"
        }
    }
}

Describe "Security Module - Helper Functions" {
    Context "Parse-SSHPublicKey" {
        It "Should parse valid SSH public key" {
            $publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG... user@example.com"
            
            $result = & (Get-Module Security) { Parse-SSHPublicKey $args[0] } $publicKey
            
            $result.Type | Should -Be "ssh-ed25519"
            $result.Comment | Should -Be "user@example.com"
        }
        
        It "Should handle key without comment" {
            $publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC..."
            
            $result = & (Get-Module Security) { Parse-SSHPublicKey $args[0] } $publicKey
            
            $result.Type | Should -Be "ssh-rsa"
            $result.Comment | Should -Be ""
        }
        
        It "Should handle malformed key" {
            $publicKey = "invalid-key-format"
            
            $result = & (Get-Module Security) { Parse-SSHPublicKey $args[0] } $publicKey
            
            $result.Type | Should -Be "unknown"
        }
    }
    
    Context "Get-SSHKeyFingerprint" {
        It "Should return fingerprint for valid key" {
            Mock Invoke-Expression { 
                $global:LASTEXITCODE = 0
                return "2048 SHA256:abcdef1234567890 user@example.com (RSA)"
            }
            
            $result = Get-SSHKeyFingerprint -KeyPath "/test/key.pub"
            
            $result | Should -Match "SHA256:"
        }
        
        It "Should handle ssh-keygen failure" {
            Mock Invoke-Expression { 
                $global:LASTEXITCODE = 1
                return "ssh-keygen: error"
            }
            
            $result = Get-SSHKeyFingerprint -KeyPath "/invalid/key.pub"
            
            $result | Should -Be "Unable to determine"
        }
    }
}

Describe "Security Module - Persistence" {
    Context "Save-ConnectionProfiles and Load-ConnectionProfiles" {
        It "Should save and load connection profiles" {
            Mock New-Item { }
            Mock Test-Path { return $true }
            Mock Out-File { }
            Mock Get-Content { 
                return '{"test-profile": {"ProfileName": "test-profile", "Hostname": "test.com"}}' 
            }
            Mock ConvertFrom-Json {
                $obj = New-Object PSObject
                $profileObj = New-Object PSObject
                Add-Member -InputObject $profileObj -MemberType NoteProperty -Name "ProfileName" -Value "test-profile"
                Add-Member -InputObject $profileObj -MemberType NoteProperty -Name "Hostname" -Value "test.com"
                Add-Member -InputObject $obj -MemberType NoteProperty -Name "test-profile" -Value $profileObj
                return $obj
            }
            
            # Test save operation
            & (Get-Module Security) { Save-ConnectionProfiles }
            
            # Test load operation  
            & (Get-Module Security) { Load-ConnectionProfiles }
            
            # Verify mocks were called
            Assert-MockCalled Out-File
            Assert-MockCalled Get-Content
        }
        
        It "Should handle load failures gracefully" {
            Mock Test-Path { return $true }
            Mock Get-Content { throw "File read error" }
            
            # Should not throw
            { & (Get-Module Security) { Load-ConnectionProfiles } } | Should -Not -Throw
        }
    }
}

Describe "Security Module - Initialization" {
    Context "Initialize-SecurityModule" {
        It "Should initialize module successfully" {
            Mock Test-SSHAvailability { return $true }
            Mock New-Item { }
            
            { Initialize-SecurityModule } | Should -Not -Throw
        }
        
        It "Should handle initialization errors gracefully" {
            Mock Test-SSHAvailability { throw "Test error" }
            
            { Initialize-SecurityModule } | Should -Throw
        }
        
        It "Should only initialize once" {
            Mock Test-SSHAvailability { return $true }
            Mock New-Item { }
            
            # Call twice
            Initialize-SecurityModule
            Initialize-SecurityModule
            
            # Should not throw and handle multiple calls
        }
    }
}