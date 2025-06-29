#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:modulePath = Join-Path $PSScriptRoot '../../../../aither-core/modules/SetupWizard'
    $script:moduleName = 'SetupWizard'
}

Describe 'SetupWizard Module Tests' {
    BeforeAll {
        # Import the module
        Import-Module $script:modulePath -Force
        
        # Mock external dependencies
        Mock Write-Host { } -ModuleName $script:moduleName
        Mock Clear-Host { } -ModuleName $script:moduleName
        Mock Start-Sleep { } -ModuleName $script:moduleName
    }
    
    Context 'Start-IntelligentSetup' {
        It 'Should complete setup successfully with no issues' {
            # Mock all test functions to return success
            Mock Test-PlatformRequirements {
                @{
                    Name = 'Platform Detection'
                    Status = 'Passed'
                    Details = @('✓ Windows 10', '✓ PowerShell 7.4')
                    Data = @{OS = 'Windows'; Version = '10.0.19045.0'}
                }
            } -ModuleName $script:moduleName
            
            Mock Test-PowerShellVersion {
                @{
                    Name = 'PowerShell Version'
                    Status = 'Passed'
                    Details = @('✓ PowerShell 7.4.0 - Full compatibility')
                }
            } -ModuleName $script:moduleName
            
            Mock Test-GitInstallation {
                @{
                    Name = 'Git Installation'
                    Status = 'Passed'
                    Details = @('✓ git version 2.43.0')
                }
            } -ModuleName $script:moduleName
            
            Mock Test-InfrastructureTools {
                @{
                    Name = 'Infrastructure Tools'
                    Status = 'Passed'
                    Details = @('✓ OpenTofu v1.6.0 installed')
                }
            } -ModuleName $script:moduleName
            
            Mock Test-ModuleDependencies {
                @{
                    Name = 'Module Dependencies'
                    Status = 'Passed'
                    Details = @('✓ All 5 core modules found')
                }
            } -ModuleName $script:moduleName
            
            Mock Test-NetworkConnectivity {
                @{
                    Name = 'Network Connectivity'
                    Status = 'Passed'
                    Details = @('✓ GitHub reachable')
                }
            } -ModuleName $script:moduleName
            
            Mock Test-SecuritySettings {
                @{
                    Name = 'Security Settings'
                    Status = 'Passed'
                    Details = @('✓ Windows Defender is active')
                }
            } -ModuleName $script:moduleName
            
            Mock Initialize-Configuration {
                @{
                    Name = 'Configuration Files'
                    Status = 'Passed'
                    Details = @('✓ Created configuration directory')
                }
            } -ModuleName $script:moduleName
            
            Mock Generate-QuickStartGuide {
                @{
                    Name = 'Quick Start Guide'
                    Status = 'Passed'
                    Details = @('✓ Generated quick start guide')
                }
            } -ModuleName $script:moduleName
            
            Mock Test-SetupCompletion {
                @{
                    Name = 'Final Validation'
                    Status = 'Passed'
                    Details = @('✅ Setup completed successfully!')
                }
            } -ModuleName $script:moduleName
            
            # Run setup
            $result = Start-IntelligentSetup -SkipOptional
            
            # Verify results
            $result | Should -Not -BeNullOrEmpty
            $result.Steps | Should -HaveCount 10
            $result.Errors | Should -HaveCount 0
            $result.Warnings | Should -HaveCount 0
            ($result.Steps | Where-Object { $_.Status -eq 'Passed' }).Count | Should -Be 10
        }
        
        It 'Should handle minimal setup mode' {
            # Mock minimal responses
            Mock Test-PlatformRequirements {
                @{
                    Name = 'Platform Detection'
                    Status = 'Passed'
                    Details = @('✓ Platform detected')
                }
            } -ModuleName $script:moduleName -ParameterFilter { $SetupState.MinimalSetup -eq $true }
            
            # Run minimal setup
            $result = Start-IntelligentSetup -MinimalSetup
            
            # Should complete but may have fewer steps
            $result | Should -Not -BeNullOrEmpty
        }
        
        It 'Should continue when non-critical steps fail with SkipOptional' {
            # Mock a failure in optional step
            Mock Test-NetworkConnectivity {
                @{
                    Name = 'Network Connectivity'
                    Status = 'Failed'
                    Details = @('❌ No network connection')
                }
            } -ModuleName $script:moduleName
            
            # Run with skip optional
            $result = Start-IntelligentSetup -SkipOptional
            
            # Should complete despite failure
            $result | Should -Not -BeNullOrEmpty
            ($result.Steps | Where-Object { $_.Status -eq 'Failed' }).Count | Should -BeGreaterThan 0
        }
    }
    
    Context 'Get-PlatformInfo' {
        It 'Should detect Windows platform correctly' {
            Mock Test-Path { $false } -ParameterFilter { $Path -eq '/etc/os-release' }
            $IsWindows = $true
            $IsLinux = $false
            $IsMacOS = $false
            
            $platform = Get-PlatformInfo
            
            $platform.OS | Should -Be 'Windows'
            $platform.PowerShell | Should -Not -BeNullOrEmpty
            $platform.Architecture | Should -Not -BeNullOrEmpty
        }
        
        It 'Should detect Linux platform correctly' {
            Mock Test-Path { $true } -ParameterFilter { $Path -eq '/etc/os-release' }
            Mock Get-Content { 'VERSION="22.04.3 LTS (Jammy Jellyfish)"' } -ParameterFilter { $Path -eq '/etc/os-release' }
            $IsWindows = $false
            $IsLinux = $true
            $IsMacOS = $false
            
            $platform = Get-PlatformInfo
            
            $platform.OS | Should -Be 'Linux'
        }
        
        It 'Should detect macOS platform correctly' {
            Mock sw_vers { '14.2.1' } -ParameterFilter { $args[0] -eq '-productVersion' }
            $IsWindows = $false
            $IsLinux = $false
            $IsMacOS = $true
            
            $platform = Get-PlatformInfo
            
            $platform.OS | Should -Be 'macOS'
        }
    }
    
    Context 'Test-PowerShellVersion' {
        It 'Should pass for PowerShell 7+' {
            Mock Get-Variable {
                @{
                    Value = @{
                        PSVersion = [Version]'7.4.0'
                    }
                }
            } -ParameterFilter { $Name -eq 'PSVersionTable' }
            
            $result = Test-PowerShellVersion -SetupState @{Recommendations = @()}
            
            $result.Status | Should -Be 'Passed'
            $result.Details | Should -Contain '✓ PowerShell 7.4.0 - Full compatibility'
        }
        
        It 'Should warn for PowerShell 5.1' {
            Mock Get-Variable {
                @{
                    Value = @{
                        PSVersion = [Version]'5.1.19041.0'
                    }
                }
            } -ParameterFilter { $Name -eq 'PSVersionTable' }
            
            $setupState = @{Recommendations = @()}
            $result = Test-PowerShellVersion -SetupState $setupState
            
            $result.Status | Should -Be 'Warning'
            $result.Details | Should -Match 'Limited compatibility'
            $setupState.Recommendations.Count | Should -BeGreaterThan 0
        }
        
        It 'Should fail for PowerShell < 5.1' {
            Mock Get-Variable {
                @{
                    Value = @{
                        PSVersion = [Version]'4.0'
                    }
                }
            } -ParameterFilter { $Name -eq 'PSVersionTable' }
            
            $result = Test-PowerShellVersion -SetupState @{Recommendations = @()}
            
            $result.Status | Should -Be 'Failed'
            $result.Details | Should -Match 'Not supported'
        }
    }
    
    Context 'Test-GitInstallation' {
        It 'Should detect Git when installed' {
            Mock git { 'git version 2.43.0.windows.1' } -ParameterFilter { $args[0] -eq '--version' }
            Mock git { 'John Doe' } -ParameterFilter { $args -contains 'user.name' }
            Mock git { 'john@example.com' } -ParameterFilter { $args -contains 'user.email' }
            
            $result = Test-GitInstallation -SetupState @{Platform = @{OS = 'Windows'}; Recommendations = @()}
            
            $result.Status | Should -Be 'Passed'
            $result.Details | Should -Match 'git version 2.43.0'
            $result.Details | Should -Match 'Git configured for'
        }
        
        It 'Should warn when Git is not configured' {
            Mock git { 'git version 2.43.0' } -ParameterFilter { $args[0] -eq '--version' }
            Mock git { $null } -ParameterFilter { $args -contains 'user.name' }
            Mock git { $null } -ParameterFilter { $args -contains 'user.email' }
            
            $setupState = @{Platform = @{OS = 'Windows'}; Recommendations = @()}
            $result = Test-GitInstallation -SetupState $setupState
            
            $result.Status | Should -Be 'Passed'
            $result.Details | Should -Match 'Git user configuration incomplete'
            $setupState.Recommendations.Count | Should -Be 2
        }
        
        It 'Should handle Git not installed' {
            Mock git { throw "Git not found" }
            
            $setupState = @{Platform = @{OS = 'Windows'}; Recommendations = @()}
            $result = Test-GitInstallation -SetupState $setupState
            
            $result.Status | Should -Be 'Warning'
            $result.Details | Should -Match 'Git not found'
            $setupState.Recommendations | Should -Contain 'Install Git: winget install Git.Git'
        }
    }
    
    Context 'Test-InfrastructureTools' {
        It 'Should prefer OpenTofu over Terraform' {
            Mock Get-Command { @{Name = 'tofu'} } -ParameterFilter { $Name -eq 'tofu' }
            Mock tofu { 'OpenTofu v1.6.0' }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'terraform' }
            
            $result = Test-InfrastructureTools -SetupState @{Recommendations = @()}
            
            $result.Status | Should -Be 'Passed'
            $result.Details | Should -Match 'OpenTofu v1.6.0 installed'
        }
        
        It 'Should warn when only Terraform is available' {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'tofu' }
            Mock Get-Command { @{Name = 'terraform'} } -ParameterFilter { $Name -eq 'terraform' }
            Mock terraform { 'Terraform v1.6.0' }
            
            $setupState = @{Recommendations = @()}
            $result = Test-InfrastructureTools -SetupState $setupState
            
            $result.Status | Should -Be 'Warning'
            $result.Details | Should -Match 'Terraform v1.6.0 found'
            $setupState.Recommendations | Should -Match 'Consider migrating to OpenTofu'
        }
        
        It 'Should detect additional tools like Docker' {
            Mock Get-Command { @{Name = 'docker'} } -ParameterFilter { $Name -eq 'docker' }
            Mock Get-Command { @{Name = 'tofu'} } -ParameterFilter { $Name -eq 'tofu' }
            Mock tofu { 'OpenTofu v1.6.0' }
            
            $result = Test-InfrastructureTools -SetupState @{Recommendations = @()}
            
            $result.Details | Should -Contain '✓ Docker available for container infrastructure'
        }
    }
    
    Context 'Generate-QuickStartGuide' {
        It 'Should generate platform-specific guide' {
            Mock Set-Content { } -Verifiable
            
            $setupState = @{
                Platform = @{
                    OS = 'Windows'
                    Version = '10.0.19045.0'
                }
                Steps = @(
                    @{Name = 'Platform Detection'; Status = 'Passed'},
                    @{Name = 'Git Installation'; Status = 'Passed'}
                )
                Warnings = @()
                Recommendations = @('Install PowerShell 7')
            }
            
            $result = Generate-QuickStartGuide -SetupState $setupState
            
            $result.Status | Should -Be 'Passed'
            $result.Details | Should -Match 'Generated quick start guide'
            
            Should -InvokeVerifiable
        }
        
        It 'Should include warnings and recommendations in guide' {
            Mock Set-Content { 
                $Value | Should -Match 'Things to Consider'
                $Value | Should -Match 'Recommendations'
                $Value | Should -Match 'Install Homebrew'
            } -Verifiable
            
            $setupState = @{
                Platform = @{OS = 'macOS'; Version = '14.2'}
                Steps = @()
                Warnings = @('Limited network access')
                Recommendations = @('Install Homebrew for easier package management')
            }
            
            Generate-QuickStartGuide -SetupState $setupState
            
            Should -InvokeVerifiable
        }
    }
    
    Context 'Initialize-Configuration' {
        It 'Should create configuration directory and files' {
            Mock Test-Path { $false } -ParameterFilter { $Path -match 'AitherZero$' }
            Mock New-Item { @{FullName = 'C:\Users\Test\AppData\Roaming\AitherZero'} }
            Mock Set-Content { }
            
            $setupState = @{
                Platform = @{OS = 'Windows'}
            }
            
            $result = Initialize-Configuration -SetupState $setupState
            
            $result.Status | Should -Be 'Passed'
            $result.Details | Should -Match 'Created configuration directory'
            
            Should -Invoke New-Item -Times 1
            Should -Invoke Set-Content -Times 2  # config.json and setup-state.json
        }
        
        It 'Should use correct paths for different platforms' {
            # Test Linux path
            Mock Test-Path { $false }
            Mock New-Item { }
            Mock Set-Content { }
            
            $env:HOME = '/home/user'
            $setupState = @{Platform = @{OS = 'Linux'}}
            
            Initialize-Configuration -SetupState $setupState
            
            Should -Invoke New-Item -ParameterFilter { $Path -eq '/home/user/.config/aitherzero' }
        }
    }
}

Describe 'SetupWizard Integration Tests' {
    BeforeAll {
        Import-Module $script:modulePath -Force
        
        # Don't mock console output for integration tests
        Mock Start-Sleep { } -ModuleName $script:moduleName
    }
    
    It 'Should complete full setup workflow' {
        # This is an integration test that runs the actual setup
        # In a real environment, this would interact with the system
        
        # For testing, we'll mock the system checks but let the flow run
        Mock Get-Command { $null } -ModuleName $moduleName
        Mock Test-Path { $false } -ModuleName $moduleName
        Mock New-Item { } -ModuleName $moduleName
        Mock Set-Content { } -ModuleName $moduleName
        Mock git { throw "Not installed" } -ModuleName $moduleName
        
        # Run setup in minimal mode to avoid prompts
        $result = Start-IntelligentSetup -MinimalSetup -SkipOptional
        
        # Basic validation
        $result | Should -Not -BeNullOrEmpty
        $result.Steps.Count | Should -BeGreaterThan 0
        $result.Platform | Should -Not -BeNullOrEmpty
    }
}