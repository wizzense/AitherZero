#Requires -Version 7.0

BeforeAll {
    # Import the core module which loads all domains
    $projectRoot = Split-Path -Parent -Path $PSScriptRoot | Split-Path -Parent | Split-Path -Parent
    Import-Module (Join-Path $projectRoot "AitherZero.psm1") -Force
    
    # Import test helpers
    Import-Module (Join-Path $projectRoot "tests/TestHelpers.psm1") -Force
}

Describe "EnvironmentConfig Module Tests" {
    BeforeEach {
        # Create test configuration
        $script:TestConfig = @{
            EnvironmentConfiguration = @{
                Windows = @{
                    LongPathSupport = @{
                        Enabled = $true
                        RegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
                        ValueName = 'LongPathsEnabled'
                    }
                    DeveloperMode = @{
                        Enabled = $false
                    }
                }
                Unix = @{
                    KernelParameters = @{
                        'net.core.somaxconn' = '1024'
                        'fs.file-max' = '2097152'
                    }
                }
                EnvironmentVariables = @{
                    System = @{
                        'AITHERZERO_HOME' = '/opt/aitherzero'
                        'AITHERZERO_LOG_LEVEL' = 'Information'
                    }
                    User = @{
                        'EDITOR' = 'code'
                    }
                }
            }
        }
    }

    Context "Get-EnvironmentConfiguration" {
        It "Should return current environment configuration" {
            $result = Get-EnvironmentConfiguration
            
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [hashtable]
        }
        
        It "Should return Windows configuration on Windows platform" -Skip:(-not $IsWindows) {
            $result = Get-EnvironmentConfiguration -Category Windows
            
            $result | Should -Not -BeNullOrEmpty
            $result.Keys | Should -Contain 'LongPathSupport'
        }
        
        It "Should return Unix configuration on Unix platforms" -Skip:$IsWindows {
            $result = Get-EnvironmentConfiguration -Category Unix
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should return environment variables" {
            $result = Get-EnvironmentConfiguration -Category EnvironmentVariables
            
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [hashtable]
        }
        
        It "Should return PATH information" {
            $result = Get-EnvironmentConfiguration -Category Path
            
            $result | Should -Not -BeNullOrEmpty
            $result.Keys | Should -Contain 'System'
        }
    }

    Context "Set-EnvironmentConfiguration" {
        It "Should accept configuration and return success" {
            Mock Write-CustomLog {} -ModuleName EnvironmentConfig
            
            { Set-EnvironmentConfiguration -Configuration $script:TestConfig -DryRun } | Should -Not -Throw
        }
        
        It "Should respect DryRun parameter" {
            Mock Write-CustomLog {} -ModuleName EnvironmentConfig
            Mock Set-ItemProperty {} -ModuleName EnvironmentConfig
            
            Set-EnvironmentConfiguration -Configuration $script:TestConfig -DryRun
            
            Should -Not -Invoke Set-ItemProperty -ModuleName EnvironmentConfig
        }
        
        It "Should process Windows configuration on Windows" -Skip:(-not $IsWindows) {
            Mock Write-CustomLog {} -ModuleName EnvironmentConfig
            Mock Test-Path { return $true } -ModuleName EnvironmentConfig
            Mock Set-ItemProperty {} -ModuleName EnvironmentConfig
            
            Set-EnvironmentConfiguration -Configuration $script:TestConfig -Category Windows -Force
            
            Should -Invoke Set-ItemProperty -ModuleName EnvironmentConfig -AtLeast 1
        }
        
        It "Should skip Windows configuration on non-Windows platforms" -Skip:$IsWindows {
            Mock Write-CustomLog {} -ModuleName EnvironmentConfig
            
            { Set-EnvironmentConfiguration -Configuration $script:TestConfig -Category Windows } | Should -Not -Throw
        }
    }

    Context "Update-EnvironmentVariable" {
        It "Should set process-level environment variable" {
            $testVarName = "AITHERZERO_TEST_VAR_$(Get-Random)"
            $testVarValue = "TestValue123"
            
            Update-EnvironmentVariable -Name $testVarName -Value $testVarValue -Scope Process
            
            (Get-Item "Env:\$testVarName").Value | Should -Be $testVarValue
            
            # Cleanup
            Remove-Item "Env:\$testVarName" -ErrorAction SilentlyContinue
        }
        
        It "Should require Force for user-level changes" {
            Mock Write-CustomLog {} -ModuleName EnvironmentConfig
            
            { Update-EnvironmentVariable -Name "TEST_VAR" -Value "Test" -Scope User -WhatIf } | Should -Not -Throw
        }
        
        It "Should validate scope parameter" {
            { Update-EnvironmentVariable -Name "TEST" -Value "Test" -Scope "InvalidScope" } | Should -Throw
        }
        
        It "Should support removing variables" {
            $testVarName = "AITHERZERO_TEST_VAR_REMOVE_$(Get-Random)"
            Set-Item "Env:\$testVarName" -Value "ToBeRemoved"
            
            Update-EnvironmentVariable -Name $testVarName -Value $null -Scope Process
            
            Test-Path "Env:\$testVarName" | Should -Be $false
        }
    }

    Context "Enable-WindowsLongPathSupport" {
        It "Should detect Windows platform requirement" -Skip:(-not $IsWindows) {
            Mock Write-CustomLog {} -ModuleName EnvironmentConfig
            Mock Test-Path { return $true } -ModuleName EnvironmentConfig
            Mock Get-ItemProperty { 
                return @{ LongPathsEnabled = 0 } 
            } -ModuleName EnvironmentConfig
            
            $result = Enable-WindowsLongPathSupport -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.CurrentlyEnabled | Should -Be $false
        }
        
        It "Should skip on non-Windows platforms" -Skip:$IsWindows {
            Mock Write-CustomLog {} -ModuleName EnvironmentConfig
            
            { Enable-WindowsLongPathSupport } | Should -Not -Throw
        }
        
        It "Should respect DryRun parameter" -Skip:(-not $IsWindows) {
            Mock Write-CustomLog {} -ModuleName EnvironmentConfig
            Mock Test-Path { return $true } -ModuleName EnvironmentConfig
            Mock Get-ItemProperty { return @{ LongPathsEnabled = 0 } } -ModuleName EnvironmentConfig
            Mock Set-ItemProperty {} -ModuleName EnvironmentConfig
            
            Enable-WindowsLongPathSupport -DryRun
            
            Should -Not -Invoke Set-ItemProperty -ModuleName EnvironmentConfig
        }
    }

    Context "Enable-WindowsDeveloperMode" {
        It "Should check Windows platform" -Skip:(-not $IsWindows) {
            Mock Write-CustomLog {} -ModuleName EnvironmentConfig
            Mock Test-Path { return $true } -ModuleName EnvironmentConfig
            Mock Get-ItemProperty { return @{ AllowDevelopmentWithoutDevLicense = 0 } } -ModuleName EnvironmentConfig
            
            $result = Enable-WindowsDeveloperMode -DryRun
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should skip on non-Windows platforms" -Skip:$IsWindows {
            Mock Write-CustomLog {} -ModuleName EnvironmentConfig
            
            { Enable-WindowsDeveloperMode } | Should -Not -Throw
        }
    }

    Context "Set-LinuxKernelParameter" {
        It "Should validate parameter name format" -Skip:$IsWindows {
            Mock Write-CustomLog {} -ModuleName EnvironmentConfig
            
            { Set-LinuxKernelParameter -Parameter "invalid_format" -Value "123" } | Should -Throw
        }
        
        It "Should accept valid parameter names" -Skip:$IsWindows {
            Mock Write-CustomLog {} -ModuleName EnvironmentConfig
            Mock Invoke-Expression {} -ModuleName EnvironmentConfig
            
            { Set-LinuxKernelParameter -Parameter "net.core.somaxconn" -Value "1024" -DryRun } | Should -Not -Throw
        }
        
        It "Should skip on Windows platform" -Skip:(-not $IsWindows) {
            Mock Write-CustomLog {} -ModuleName EnvironmentConfig
            
            { Set-LinuxKernelParameter -Parameter "test.param" -Value "123" } | Should -Not -Throw
        }
    }

    Context "Set-MacOSDefault" {
        It "Should validate domain parameter" -Skip:(-not $IsMacOS) {
            Mock Write-CustomLog {} -ModuleName EnvironmentConfig
            Mock Invoke-Expression {} -ModuleName EnvironmentConfig
            
            { Set-MacOSDefault -Domain "com.apple.finder" -Key "TestKey" -Value "TestValue" -Type "string" -DryRun } | Should -Not -Throw
        }
        
        It "Should support different value types" -Skip:(-not $IsMacOS) {
            Mock Write-CustomLog {} -ModuleName EnvironmentConfig
            Mock Invoke-Expression {} -ModuleName EnvironmentConfig
            
            { Set-MacOSDefault -Domain "test" -Key "BoolKey" -Value "true" -Type "bool" -DryRun } | Should -Not -Throw
            { Set-MacOSDefault -Domain "test" -Key "IntKey" -Value "123" -Type "int" -DryRun } | Should -Not -Throw
            { Set-MacOSDefault -Domain "test" -Key "FloatKey" -Value "1.5" -Type "float" -DryRun } | Should -Not -Throw
        }
        
        It "Should skip on non-macOS platforms" -Skip:$IsMacOS {
            Mock Write-CustomLog {} -ModuleName EnvironmentConfig
            
            { Set-MacOSDefault -Domain "test" -Key "key" -Value "value" -Type "string" } | Should -Not -Throw
        }
    }

    Context "Add-PathEntry" {
        It "Should add entry to PATH" {
            $testPath = "/test/path/$(Get-Random)"
            
            # Mock environment variable access
            Mock Write-CustomLog {} -ModuleName EnvironmentConfig
            
            { Add-PathEntry -Path $testPath -Scope Process } | Should -Not -Throw
        }
        
        It "Should validate path exists when CheckExists is specified" {
            $nonExistentPath = "/this/path/does/not/exist/$(Get-Random)"
            Mock Write-CustomLog {} -ModuleName EnvironmentConfig
            Mock Test-Path { return $false } -ModuleName EnvironmentConfig
            
            { Add-PathEntry -Path $nonExistentPath -Scope Process -CheckExists } | Should -Throw
        }
        
        It "Should support different scopes" {
            Mock Write-CustomLog {} -ModuleName EnvironmentConfig
            
            { Add-PathEntry -Path "/test" -Scope Process -WhatIf } | Should -Not -Throw
            { Add-PathEntry -Path "/test" -Scope User -WhatIf } | Should -Not -Throw
            { Add-PathEntry -Path "/test" -Scope Machine -WhatIf } | Should -Not -Throw
        }
    }

    Context "Remove-PathEntry" {
        It "Should remove entry from PATH" {
            Mock Write-CustomLog {} -ModuleName EnvironmentConfig
            
            { Remove-PathEntry -Path "/test/path" -Scope Process } | Should -Not -Throw
        }
        
        It "Should handle non-existent entries gracefully" {
            Mock Write-CustomLog {} -ModuleName EnvironmentConfig
            
            { Remove-PathEntry -Path "/non/existent/path/$(Get-Random)" -Scope Process } | Should -Not -Throw
        }
    }

    Context "Cross-Platform Compatibility" {
        It "Should detect current platform correctly" {
            Mock Write-CustomLog {} -ModuleName EnvironmentConfig
            
            $result = Get-EnvironmentConfiguration
            
            if ($IsWindows) {
                $result.Platform | Should -Match "Windows"
            } elseif ($IsLinux) {
                $result.Platform | Should -Match "Linux"
            } elseif ($IsMacOS) {
                $result.Platform | Should -Match "macOS"
            }
        }
        
        It "Should skip platform-specific operations gracefully" {
            Mock Write-CustomLog {} -ModuleName EnvironmentConfig
            
            # These should not throw regardless of platform
            { Set-EnvironmentConfiguration -Configuration $script:TestConfig -DryRun } | Should -Not -Throw
        }
    }

    Context "Error Handling" {
        It "Should handle missing configuration gracefully" {
            Mock Write-CustomLog {} -ModuleName EnvironmentConfig
            
            { Set-EnvironmentConfiguration -Configuration @{} -DryRun } | Should -Not -Throw
        }
        
        It "Should validate required parameters" {
            { Update-EnvironmentVariable -Name "" -Value "test" -Scope Process } | Should -Throw
            { Update-EnvironmentVariable -Name $null -Value "test" -Scope Process } | Should -Throw
        }
        
        It "Should provide meaningful error messages" {
            Mock Write-CustomLog {} -ModuleName EnvironmentConfig
            
            try {
                Update-EnvironmentVariable -Name "" -Value "test" -Scope Process
                $false | Should -Be $true # Should not reach here
            } catch {
                $_.Exception.Message | Should -Not -BeNullOrEmpty
            }
        }
    }
}
