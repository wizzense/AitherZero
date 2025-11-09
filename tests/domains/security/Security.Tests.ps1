#Requires -Version 7.0

BeforeAll {
    # Import the AitherZero module to get the Security domain
    $ModuleRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    Import-Module "$ModuleRoot/AitherZero.psd1" -Force
    
    # Import the Security module directly for testing
    Import-Module "$ModuleRoot/domains/security/Security.psm1" -Force
}

Describe "Security Module - Remote Command Execution" {
    Context "Invoke-SSHCommand" {
        It "Should throw when SSH is not available" {
            # Mock the Get-Command for SSH to simulate SSH not being available
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'ssh' } -ModuleName Security
            
            {
                Invoke-SSHCommand -Target "test.com" -Command "echo test"
            } | Should -Throw "*SSH is not available*"
        }
        
        It "Should execute command and return result" {
            # Skip if SSH is not actually available on the system
            $sshAvailable = Get-Command ssh -ErrorAction SilentlyContinue
            if (-not $sshAvailable) {
                Set-ItResult -Skipped -Because "SSH client not available on test system"
                return
            }
            
            # Test with unreachable host - should fail but not timeout
            $result = Invoke-SSHCommand -Target "test.com" -Command "false" -TimeoutSeconds 5 -ConnectTimeoutSeconds 2
            $result.Success | Should -Be $false
            $result.ExitCode | Should -Be 255
        }
        
        It "Should handle connection timeouts gracefully" {
            # Skip if SSH is not available
            $sshAvailable = Get-Command ssh -ErrorAction SilentlyContinue  
            if (-not $sshAvailable) {
                Set-ItResult -Skipped -Because "SSH client not available on test system"
                return
            }
            
            # Test with a non-routable IP - should fail with SSH error
            $result = Invoke-SSHCommand -Target "192.0.2.1" -Command "echo test" -TimeoutSeconds 10 -ConnectTimeoutSeconds 1
            $result.Success | Should -Be $false
            $result.ExitCode | Should -Be 255
        }
        
        It "Should validate required parameters" {
            {
                Invoke-SSHCommand -Target "" -Command "echo test"
            } | Should -Throw
            
            {
                Invoke-SSHCommand -Target "test.com" -Command ""
            } | Should -Throw
        }
        
        It "Should accept optional parameters" {
            # Skip if SSH is not available
            $sshAvailable = Get-Command ssh -ErrorAction SilentlyContinue
            if (-not $sshAvailable) {
                Set-ItResult -Skipped -Because "SSH client not available on test system"
                return
            }
            
            # Test with custom parameters - should fail but parameters should be accepted
            $result = Invoke-SSHCommand -Target "test.com" -Command "echo test" -Port 2222 -Username "testuser" -TimeoutSeconds 15
            $result.Success | Should -Be $false
            $result.ExitCode | Should -Be 255
        }
    }
    
    Context "Test-SSHConnection" {
        It "Should return false for unreachable hosts" {
            # Skip if SSH is not available
            $sshAvailable = Get-Command ssh -ErrorAction SilentlyContinue
            if (-not $sshAvailable) {
                Set-ItResult -Skipped -Because "SSH client not available on test system"
                return
            }
            
            $result = Test-SSHConnection -Target "192.0.2.1" -TimeoutSeconds 2
            $result | Should -Be $false
        }
        
        It "Should handle invalid hostnames gracefully" {
            # Skip if SSH is not available  
            $sshAvailable = Get-Command ssh -ErrorAction SilentlyContinue
            if (-not $sshAvailable) {
                Set-ItResult -Skipped -Because "SSH client not available on test system"
                return
            }
            
            $result = Test-SSHConnection -Target "invalid.hostname.thatdoesnotexist" -TimeoutSeconds 2
            $result | Should -Be $false
        }
    }
    
    Context "ConvertFrom-SecureStringSecurely" {
        It "Should convert SecureString to plain text" {
            $plainText = "MySecretPassword123"
            $secureString = ConvertTo-SecureString -String $plainText -AsPlainText -Force
            
            $result = ConvertFrom-SecureStringSecurely -SecureString $secureString
            
            $result | Should -Be $plainText
        }
        
        It "Should handle empty SecureString" {
            $secureString = ConvertTo-SecureString -String "a" -AsPlainText -Force
            # Clear the secure string by creating an empty one
            $emptySecure = New-Object System.Security.SecureString
            
            $result = ConvertFrom-SecureStringSecurely -SecureString $emptySecure
            
            $result | Should -Be ([string]::Empty)
        }
        
        It "Should properly clean up memory" {
            # This test verifies the function completes without errors
            # Memory cleanup is handled in the finally block
            $secureString = ConvertTo-SecureString -String "TestPassword" -AsPlainText -Force
            
            {
                $result = ConvertFrom-SecureStringSecurely -SecureString $secureString
                $result | Should -Not -BeNullOrEmpty
            } | Should -Not -Throw
        }
        
        It "Should require SecureString parameter" {
            {
                ConvertFrom-SecureStringSecurely -SecureString $null
            } | Should -Throw
        }
        
        It "Should handle special characters" {
            $specialText = "P@ssw0rd!#$%^&*()"
            $secureString = ConvertTo-SecureString -String $specialText -AsPlainText -Force
            
            $result = ConvertFrom-SecureStringSecurely -SecureString $secureString
            
            $result | Should -Be $specialText
        }
        
        It "Should handle Unicode characters" {
            $unicodeText = "密码Пароль🔐"
            $secureString = ConvertTo-SecureString -String $unicodeText -AsPlainText -Force
            
            $result = ConvertFrom-SecureStringSecurely -SecureString $secureString
            
            $result | Should -Be $unicodeText
        }
    }
}

Describe "Security Module - Environment Variable Management" {
    BeforeAll {
        # Set up test environment variables
        [Environment]::SetEnvironmentVariable("AITHERZERO_TEST_VAR1", "TestValue1", "Process")
        [Environment]::SetEnvironmentVariable("AITHERZERO_TEST_VAR2", "TestValue2", "Process")
        [Environment]::SetEnvironmentVariable("AITHERZERO_TEST_TOKEN", "SecretToken123", "Process")
    }
    
    AfterAll {
        # Clean up test environment variables
        [Environment]::SetEnvironmentVariable("AITHERZERO_TEST_VAR1", $null, "Process")
        [Environment]::SetEnvironmentVariable("AITHERZERO_TEST_VAR2", $null, "Process")
        [Environment]::SetEnvironmentVariable("AITHERZERO_TEST_TOKEN", $null, "Process")
    }
    
    Context "Get-AitherEnvironmentVariable" {
        It "Should retrieve a specific environment variable" {
            $result = Get-AitherEnvironmentVariable -Name "AITHERZERO_TEST_VAR1"
            
            $result | Should -Be "TestValue1"
        }
        
        It "Should return null and warn for non-existent variable" {
            $result = Get-AitherEnvironmentVariable -Name "NONEXISTENT_VAR_XYZ123" -WarningAction SilentlyContinue
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should retrieve environment variable as SecureString" {
            $result = Get-AitherEnvironmentVariable -Name "AITHERZERO_TEST_TOKEN" -AsSecureString
            
            $result | Should -BeOfType [System.Security.SecureString]
            
            # Convert back to verify using the Security module's own function
            if (Get-Command ConvertFrom-SecureStringSecurely -ErrorAction SilentlyContinue) {
                $plainText = ConvertFrom-SecureStringSecurely -SecureString $result
                $plainText | Should -Be "SecretToken123"
            }
        }
        
        It "Should support wildcard pattern matching" {
            $result = Get-AitherEnvironmentVariable -Name "AITHERZERO_TEST_*"
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -BeGreaterOrEqual 3
            $result[0] | Should -BeOfType [PSCustomObject]
            $result[0].Name | Should -Not -BeNullOrEmpty
            $result[0].Value | Should -Not -BeNullOrEmpty
        }
        
        It "Should list all variables when called without parameters" {
            $result = Get-AitherEnvironmentVariable
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -BeGreaterThan 10
            $result[0] | Should -BeOfType [PSCustomObject]
        }
        
        It "Should list all variables with explicit wildcard" {
            $result = Get-AitherEnvironmentVariable -Name "*"
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -BeGreaterThan 10
        }
        
        It "Should return sorted results for wildcard queries" {
            $result = Get-AitherEnvironmentVariable -Name "AITHERZERO_TEST_*"
            
            # Verify results are sorted by name
            for ($i = 0; $i -lt ($result.Count - 1); $i++) {
                $result[$i].Name | Should -BeLessOrEqual $result[$i + 1].Name
            }
        }
        
        It "Should support question mark wildcard" {
            # Set a variable with a specific pattern
            [Environment]::SetEnvironmentVariable("AITHERZERO_X", "ValueX", "Process")
            [Environment]::SetEnvironmentVariable("AITHERZERO_Y", "ValueY", "Process")
            
            try {
                $result = Get-AitherEnvironmentVariable -Name "AITHERZERO_?"
                
                $result | Should -Not -BeNullOrEmpty
                $result.Count | Should -BeGreaterOrEqual 2
            }
            finally {
                [Environment]::SetEnvironmentVariable("AITHERZERO_X", $null, "Process")
                [Environment]::SetEnvironmentVariable("AITHERZERO_Y", $null, "Process")
            }
        }
        
        It "Should return empty array when no matches found" {
            $result = Get-AitherEnvironmentVariable -Name "NONEXISTENT_PREFIX_*" -WarningAction SilentlyContinue
            
            # Should return an array (not null) but with zero elements
            $result -is [array] | Should -Be $true
            $result[0].Count | Should -Be 0
        }
        
        It "Should support case-insensitive matching on Windows" {
            if ($IsWindows) {
                $result = Get-AitherEnvironmentVariable -Name "aitherzero_test_var1"
                $result | Should -Be "TestValue1"
            }
            else {
                Set-ItResult -Skipped -Because "Case-insensitive matching is Windows-specific"
            }
        }
        
        It "Should handle wildcard in middle of pattern" {
            $result = Get-AitherEnvironmentVariable -Name "AITHERZERO*VAR1"
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -BeGreaterOrEqual 1
            ($result | Where-Object { $_.Name -eq "AITHERZERO_TEST_VAR1" }) | Should -Not -BeNullOrEmpty
        }
    }
}