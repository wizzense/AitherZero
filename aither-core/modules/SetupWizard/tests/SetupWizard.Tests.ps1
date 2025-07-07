#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.7.1' }

BeforeAll {
    # Find and import the module
    $modulePath = Split-Path -Parent $PSScriptRoot
    $moduleName = Split-Path -Leaf $modulePath
    
    # Remove module if already loaded
    if (Get-Module $moduleName) {
        Remove-Module $moduleName -Force
    }
    
    # Import the module
    Import-Module "$modulePath/$moduleName.psd1" -Force
    
    # Mock external dependencies
    Mock Write-Host {}
    Mock Read-Host { return 'Y' }
    
    # Since SetupWizard now redirects to UserExperience, mock that module
    Mock Import-Module {} -ParameterFilter { $Name -eq 'UserExperience' }
    Mock Get-Module { return @{ Name = 'UserExperience' } } -ParameterFilter { $Name -eq 'UserExperience' }
    
    # Create test environment
    $script:testConfig = @{
        TestPath = Join-Path $TestDrive 'AitherZero'
        ConfigPath = Join-Path $TestDrive 'AitherZero' 'config.json'
        ProfilePath = Join-Path $TestDrive 'AitherZero' 'profiles'
    }
    
    # Create test directories
    New-Item -ItemType Directory -Path $script:testConfig.TestPath -Force | Out-Null
    New-Item -ItemType Directory -Path $script:testConfig.ProfilePath -Force | Out-Null
}

Describe "SetupWizard Module Tests" {
    Context "Module Loading" {
        It "Should export expected functions" {
            $module = Get-Module SetupWizard
            $module | Should -Not -BeNullOrEmpty
            
            # Functions that should be exported for compatibility
            $requiredFunctions = @(
                'Start-IntelligentSetup',
                'Generate-QuickStartGuide',
                'Edit-Configuration',
                'Review-Configuration'
            )
            
            foreach ($function in $requiredFunctions) {
                $module.ExportedFunctions.Keys | Should -Contain $function
            }
        }
    }
    
    Context "Setup Redirection" {
        BeforeEach {
            # Mock UserExperience functions
            Mock Get-Command { 
                return [PSCustomObject]@{ 
                    Name = 'Start-IntelligentSetup'
                    Module = 'UserExperience'
                }
            } -ParameterFilter { $Name -eq 'Start-IntelligentSetup' -and $Module -eq 'UserExperience' }
        }
        
        It "Should redirect Start-IntelligentSetup to UserExperience module" {
            # Mock the UserExperience version of the function
            Mock Invoke-Command -MockWith { 
                return @{ Success = $true; Profile = 'minimal' }
            } -ParameterFilter { $ScriptBlock -like '*UserExperience\Start-IntelligentSetup*' }
            
            Mock UserExperience\Start-IntelligentSetup { 
                return @{ Success = $true; Profile = 'minimal' }
            }
            
            $result = Start-IntelligentSetup -InstallationProfile 'minimal'
            
            # The function should attempt to call UserExperience version
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should pass all parameters to UserExperience version" {
            $capturedParams = $null
            
            Mock UserExperience\Start-IntelligentSetup {
                $capturedParams = $PSBoundParameters
                return @{ Success = $true }
            }
            
            Start-IntelligentSetup -InstallationProfile 'developer' -SkipOptional -Force
            
            # Parameters should be passed through
            $capturedParams | Should -Not -BeNullOrEmpty
            $capturedParams.InstallationProfile | Should -Be 'developer'
            $capturedParams.SkipOptional | Should -Be $true
            $capturedParams.Force | Should -Be $true
        }
        
        It "Should throw error if UserExperience module is not available" {
            Mock Get-Module { return $null } -ParameterFilter { $Name -eq 'UserExperience' }
            Mock Import-Module { throw "Module not found" } -ParameterFilter { $Name -eq 'UserExperience' }
            
            { Start-IntelligentSetup -InstallationProfile 'minimal' } | Should -Throw
        }
    }
    
    Context "Installation Profiles" {
        BeforeEach {
            Mock UserExperience\Start-IntelligentSetup { 
                param($InstallationProfile)
                return @{ 
                    Success = $true
                    Profile = $InstallationProfile
                    Components = switch($InstallationProfile) {
                        'minimal' { @('Core') }
                        'developer' { @('Core', 'DevTools') }
                        'full' { @('Core', 'DevTools', 'AITools', 'Advanced') }
                        default { @('Core') }
                    }
                }
            }
        }
        
        It "Should support minimal profile" {
            $result = Start-IntelligentSetup -InstallationProfile 'minimal'
            
            $result.Profile | Should -Be 'minimal'
            $result.Components | Should -Contain 'Core'
            $result.Components.Count | Should -Be 1
        }
        
        It "Should support developer profile" {
            $result = Start-IntelligentSetup -InstallationProfile 'developer'
            
            $result.Profile | Should -Be 'developer'
            $result.Components | Should -Contain 'Core'
            $result.Components | Should -Contain 'DevTools'
        }
        
        It "Should support full profile" {
            $result = Start-IntelligentSetup -InstallationProfile 'full'
            
            $result.Profile | Should -Be 'full'
            $result.Components | Should -Contain 'Core'
            $result.Components | Should -Contain 'DevTools'
            $result.Components | Should -Contain 'AITools'
        }
        
        It "Should handle custom selections" {
            Mock UserExperience\Start-IntelligentSetup {
                return @{
                    Success = $true
                    Profile = 'interactive'
                    CustomSelections = $true
                }
            }
            
            $result = Start-IntelligentSetup -InstallationProfile 'interactive'
            
            $result.Profile | Should -Be 'interactive'
            $result.CustomSelections | Should -Be $true
        }
    }
    
    Context "Setup Flow" {
        BeforeEach {
            Mock UserExperience\Start-IntelligentSetup {
                return @{
                    Success = $true
                    Profile = 'minimal'
                    SetupSteps = @('Prerequisites', 'Configuration', 'Installation', 'Verification')
                }
            }
        }
        
        It "Should guide through configuration" {
            $result = Start-IntelligentSetup -InstallationProfile 'minimal'
            
            $result.SetupSteps | Should -Contain 'Configuration'
            $result.Success | Should -Be $true
        }
        
        It "Should validate user inputs" {
            Mock UserExperience\Start-IntelligentSetup {
                param($InstallationProfile)
                if ($InstallationProfile -notin @('minimal', 'developer', 'full', 'interactive')) {
                    throw "Invalid profile"
                }
                return @{ Success = $true; Profile = $InstallationProfile }
            }
            
            { Start-IntelligentSetup -InstallationProfile 'invalid' } | Should -Throw
        }
        
        It "Should create initial config files" {
            Mock UserExperience\Start-IntelligentSetup {
                Set-Content -Path $script:testConfig.ConfigPath -Value '{"configured":true}'
                return @{
                    Success = $true
                    ConfigCreated = $true
                    ConfigPath = $script:testConfig.ConfigPath
                }
            }
            
            $result = Start-IntelligentSetup -InstallationProfile 'minimal'
            
            $result.ConfigCreated | Should -Be $true
            Test-Path $script:testConfig.ConfigPath | Should -Be $true
        }
        
        It "Should handle setup failures" {
            Mock UserExperience\Start-IntelligentSetup {
                return @{
                    Success = $false
                    Error = "Prerequisites not met"
                    FailedStep = "Prerequisites"
                }
            }
            
            $result = Start-IntelligentSetup -InstallationProfile 'minimal'
            
            $result.Success | Should -Be $false
            $result.Error | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Configuration Management" {
        BeforeEach {
            # Create a test configuration file
            $testConfig = @{
                Profile = 'developer'
                Modules = @('Core', 'DevTools')
                Settings = @{
                    Theme = 'dark'
                    AutoUpdate = $true
                }
            } | ConvertTo-Json
            
            Set-Content -Path $script:testConfig.ConfigPath -Value $testConfig
        }
        
        It "Should edit configuration" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'Edit-Configuration' -and $Module -eq 'UserExperience' }
            Mock Test-Path { return $true }
            Mock & { $env:EDITOR = 'notepad' }
            Mock Start-Process {}
            
            Edit-Configuration -ConfigPath $script:testConfig.ConfigPath
            
            # Should have attempted to open editor
            $env:EDITOR | Should -Not -BeNullOrEmpty
        }
        
        It "Should review configuration" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'Review-Configuration' -and $Module -eq 'UserExperience' }
            
            Review-Configuration -ConfigPath $script:testConfig.ConfigPath
            
            # Function should complete without error
            Should -Invoke Write-Host -Times -AtLeast 1
        }
        
        It "Should handle missing configuration gracefully" {
            Mock Get-Command { return $null } -ParameterFilter { $Module -eq 'UserExperience' }
            Mock Test-Path { return $false }
            Mock Write-Warning {}
            
            Review-Configuration -ConfigPath "nonexistent.json"
            
            Should -Invoke Write-Warning -Times 1
        }
    }
    
    Context "Quick Start Guide Generation" {
        It "Should generate quick start guide" {
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'Generate-QuickStartGuide' -and $Module -eq 'UserExperience' }
            
            $setupState = @{
                Profile = 'developer'
                ModulesInstalled = @('Core', 'DevTools', 'PatchManager')
                ConfigurationComplete = $true
            }
            
            Generate-QuickStartGuide -SetupState $setupState
            
            Should -Invoke Write-Host -Times -AtLeast 1 -ParameterFilter {
                $Object -like '*Quick Start Guide*'
            }
        }
        
        It "Should redirect to UserExperience version if available" {
            Mock Get-Command { 
                return [PSCustomObject]@{ 
                    Name = 'Generate-QuickStartGuide'
                    Module = 'UserExperience'
                }
            } -ParameterFilter { $Name -eq 'Generate-QuickStartGuide' -and $Module -eq 'UserExperience' }
            
            Mock UserExperience\Generate-QuickStartGuide { return $true }
            
            $result = Generate-QuickStartGuide -SetupState @{}
            
            Should -Invoke UserExperience\Generate-QuickStartGuide -Times 1
        }
    }
    
    Context "Unattended Setup" {
        It "Should support unattended mode" {
            Mock UserExperience\Start-IntelligentSetup {
                param($Unattended)
                return @{
                    Success = $true
                    UnattendedMode = $Unattended
                    NoUserPrompts = $Unattended
                }
            }
            
            $result = Start-IntelligentSetup -InstallationProfile 'minimal' -Unattended
            
            $result.UnattendedMode | Should -Be $true
            $result.NoUserPrompts | Should -Be $true
        }
        
        It "Should skip optional components when requested" {
            Mock UserExperience\Start-IntelligentSetup {
                param($SkipOptional)
                return @{
                    Success = $true
                    SkippedOptional = $SkipOptional
                    Components = if ($SkipOptional) { @('Core') } else { @('Core', 'Optional') }
                }
            }
            
            $result = Start-IntelligentSetup -InstallationProfile 'developer' -SkipOptional
            
            $result.SkippedOptional | Should -Be $true
            $result.Components | Should -Not -Contain 'Optional'
        }
    }
    
    Context "Force Setup" {
        It "Should force setup even if already completed" {
            Mock UserExperience\Start-IntelligentSetup {
                param($Force)
                return @{
                    Success = $true
                    ForcedSetup = $Force
                    OverwriteExisting = $Force
                }
            }
            
            $result = Start-IntelligentSetup -InstallationProfile 'minimal' -Force
            
            $result.ForcedSetup | Should -Be $true
            $result.OverwriteExisting | Should -Be $true
        }
    }
    
    Context "Error Handling" {
        It "Should provide clear error messages" {
            Mock UserExperience\Start-IntelligentSetup {
                throw "UserExperience module not properly configured"
            }
            
            $errorThrown = $false
            try {
                Start-IntelligentSetup -InstallationProfile 'minimal'
            } catch {
                $errorThrown = $true
                $_.Exception.Message | Should -Match "UserExperience"
            }
            
            $errorThrown | Should -Be $true
        }
        
        It "Should handle parameter validation" {
            # The ValidateSet should prevent invalid values
            { Start-IntelligentSetup -InstallationProfile 'invalid' } | Should -Throw
        }
    }
    
    Context "Backward Compatibility" {
        It "Should maintain compatibility with existing scripts" {
            Mock UserExperience\Start-IntelligentSetup {
                return @{ Success = $true }
            }
            
            # Old script might call without parameters
            $result = Start-IntelligentSetup
            
            $result.Success | Should -Be $true
        }
        
        It "Should support all original parameters" {
            $function = Get-Command Start-IntelligentSetup
            
            $function.Parameters.Keys | Should -Contain 'InstallationProfile'
            $function.Parameters.Keys | Should -Contain 'SkipOptional'
            $function.Parameters.Keys | Should -Contain 'ConfigPath'
            $function.Parameters.Keys | Should -Contain 'Unattended'
            $function.Parameters.Keys | Should -Contain 'Force'
        }
    }
}

AfterAll {
    # Clean up
    if (Get-Module SetupWizard) {
        Remove-Module SetupWizard -Force
    }
}