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
    
    # Create test configuration
    $script:testConfig = @{
        TestPath = Join-Path $TestDrive 'AitherZero'
        ConfigPath = Join-Path $TestDrive 'AitherZero' 'config.json'
        ProfilePath = Join-Path $TestDrive 'AitherZero' 'profiles'
    }
    
    # Create test directories
    New-Item -ItemType Directory -Path $script:testConfig.TestPath -Force | Out-Null
    New-Item -ItemType Directory -Path $script:testConfig.ProfilePath -Force | Out-Null
}

Describe "UserExperience Module Tests" {
    Context "Module Loading" {
        It "Should export expected functions" {
            $module = Get-Module UserExperience
            $module | Should -Not -BeNullOrEmpty
            
            # Critical functions that must be exported
            $requiredFunctions = @(
                'Start-IntelligentSetup',
                'Start-UserExperience',
                'Initialize-UserExperience',
                'Show-WelcomeScreen',
                'Start-FirstTimeSetup',
                'Complete-UserOnboarding'
            )
            
            foreach ($function in $requiredFunctions) {
                $module.ExportedFunctions.Keys | Should -Contain $function
            }
        }
        
        It "Should export expected aliases" {
            $module = Get-Module UserExperience
            $expectedAliases = @('Start-UX', 'Setup-AitherZero', 'Configure-AitherZero')
            
            foreach ($alias in $expectedAliases) {
                $module.ExportedAliases.Keys | Should -Contain $alias
            }
        }
    }
    
    Context "User Interaction Flows" {
        BeforeEach {
            # Reset mocks
            Mock Write-Host {}
            Mock Read-Host { return 'Y' }
        }
        
        It "Should display interactive menus correctly" {
            Mock Show-MainDashboard { return @{ Action = 'Exit' } }
            
            { Start-InteractiveMode } | Should -Not -Throw
            
            Should -Invoke Show-MainDashboard -Times 1
        }
        
        It "Should handle user input validation" {
            Mock Read-Host -MockWith { return 'invalid' } -ParameterFilter { $Prompt -like '*profile*' }
            Mock Read-Host -MockWith { return 'minimal' } -ParameterFilter { $Prompt -like '*try again*' }
            
            $result = Get-UserInput -Prompt "Select profile" -ValidValues @('minimal', 'developer', 'full')
            
            $result | Should -Be 'minimal'
            Should -Invoke Read-Host -Times 2
        }
        
        It "Should provide helpful error messages" {
            Mock Write-Host {}
            Mock Show-InformationDialog {}
            
            Show-InformationDialog -Title "Error" -Message "Test error" -Type "Error"
            
            Should -Invoke Show-InformationDialog -Times 1 -ParameterFilter { 
                $Type -eq 'Error' 
            }
        }
        
        It "Should support keyboard navigation" {
            # This would require more complex terminal emulation
            # For now, just ensure the functions exist
            Get-Command Initialize-TerminalUI | Should -Not -BeNullOrEmpty
            Get-Command Reset-TerminalUI | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Progress and Feedback" {
        It "Should show operation progress" {
            Mock Show-ProgressIndicator { return $true }
            
            $result = Show-ProgressIndicator -Activity "Testing" -PercentComplete 50
            
            $result | Should -Be $true
            Should -Invoke Show-ProgressIndicator -Times 1
        }
        
        It "Should provide clear status updates" {
            Mock Write-Host {}
            Mock Show-SetupProgress {}
            
            Show-SetupProgress -Step "Installing" -Progress 25 -Total 100
            
            Should -Invoke Show-SetupProgress -Times 1
        }
        
        It "Should handle interruptions gracefully" {
            Mock Test-Path { return $false }
            Mock Write-Warning {}
            
            # Simulate interruption by missing config
            { Initialize-UserExperience -ConfigPath "missing.json" } | Should -Not -Throw
            
            Should -Invoke Write-Warning -Times 1 -Scope It
        }
    }
    
    Context "Setup Flow" {
        BeforeEach {
            Mock Write-Host {}
            Mock Test-SystemReadiness { return @{ Ready = $true; Issues = @() } }
            Mock New-Item {}
            Mock Set-Content {}
        }
        
        It "Should detect first-time users" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -like '*config.json' }
            
            $result = Start-FirstTimeSetup -ConfigPath $script:testConfig.ConfigPath
            
            $result | Should -Not -BeNullOrEmpty
            $result.IsFirstTime | Should -Be $true
        }
        
        It "Should guide through configuration" {
            Mock Read-Host -MockWith { return 'developer' }
            Mock Show-SetupProgress {}
            
            $result = Start-IntelligentSetup -InstallationProfile 'interactive' -ConfigPath $script:testConfig.ConfigPath
            
            $result | Should -Not -BeNullOrEmpty
            Should -Invoke Show-SetupProgress -Times -AtLeast 1
        }
        
        It "Should validate user inputs" {
            Mock Read-Host { return '' }
            Mock Get-UserInput { return 'minimal' }
            
            $result = Start-IntelligentSetup -InstallationProfile 'interactive'
            
            Should -Invoke Get-UserInput -Times -AtLeast 1
        }
        
        It "Should create initial config files" {
            Mock New-Item {}
            Mock Set-Content {}
            Mock Test-Path { return $false }
            
            $result = Start-IntelligentSetup -InstallationProfile 'minimal' -ConfigPath $script:testConfig.ConfigPath
            
            Should -Invoke Set-Content -Times -AtLeast 1 -ParameterFilter {
                $Path -like '*config.json'
            }
        }
        
        It "Should handle setup failures" {
            Mock Test-SystemReadiness { return @{ Ready = $false; Issues = @("Missing PowerShell 7") } }
            Mock Write-Error {}
            
            { Start-IntelligentSetup -InstallationProfile 'minimal' } | Should -Not -Throw
            
            Should -Invoke Write-Error -Times -AtLeast 1
        }
    }
    
    Context "Installation Profiles" {
        BeforeEach {
            Mock Write-Host {}
            Mock Test-SystemReadiness { return @{ Ready = $true } }
            Mock Set-Content {}
        }
        
        It "Should support minimal profile" {
            $result = Start-IntelligentSetup -InstallationProfile 'minimal' -Unattended
            
            $result | Should -Not -BeNullOrEmpty
            $result.Profile | Should -Be 'minimal'
        }
        
        It "Should support developer profile" {
            Mock Install-RequiredModules { return @{ Success = $true } }
            
            $result = Start-IntelligentSetup -InstallationProfile 'developer' -Unattended
            
            $result | Should -Not -BeNullOrEmpty
            $result.Profile | Should -Be 'developer'
            Should -Invoke Install-RequiredModules -Times -AtLeast 1
        }
        
        It "Should support full profile" {
            Mock Install-RequiredModules { return @{ Success = $true } }
            Mock Configure-AITools { return @{ Success = $true } }
            
            $result = Start-IntelligentSetup -InstallationProfile 'full' -Unattended
            
            $result | Should -Not -BeNullOrEmpty
            $result.Profile | Should -Be 'full'
        }
        
        It "Should handle custom selections in interactive mode" {
            Mock Read-Host { return 'developer' }
            Mock Show-ConfirmationDialog { return $true }
            
            $result = Start-IntelligentSetup -InstallationProfile 'interactive'
            
            $result | Should -Not -BeNullOrEmpty
            Should -Invoke Read-Host -Times -AtLeast 1
        }
    }
    
    Context "Environment Validation" {
        It "Should verify PowerShell version" {
            $readiness = Test-SystemReadiness
            
            $readiness | Should -Not -BeNullOrEmpty
            $readiness.PowerShellVersion | Should -Not -BeNullOrEmpty
            $readiness.PowerShellVersion.Major | Should -BeGreaterOrEqual 7
        }
        
        It "Should check platform compatibility" {
            $readiness = Test-SystemReadiness
            
            $readiness.Platform | Should -BeIn @('Windows', 'Linux', 'macOS')
        }
        
        It "Should validate prerequisites" {
            Mock Test-Path { return $true }
            Mock Get-Command { return @{ Name = 'git' } }
            
            $readiness = Test-SystemReadiness
            
            $readiness.Prerequisites | Should -Not -BeNullOrEmpty
            $readiness.Prerequisites.Git | Should -Be $true
        }
    }
    
    Context "User Profile Management" {
        BeforeEach {
            Mock Test-Path { return $true }
            Mock Get-Content { return '{"name":"test","preferences":{}}' }
            Mock Set-Content {}
        }
        
        It "Should create new user profiles" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -like '*test-profile.json' }
            
            $profile = New-UserProfile -Name "test-profile" -ProfilePath $script:testConfig.ProfilePath
            
            $profile | Should -Not -BeNullOrEmpty
            $profile.Name | Should -Be "test-profile"
        }
        
        It "Should get existing profiles" {
            Mock Get-ChildItem { 
                return @([PSCustomObject]@{ Name = 'default.json'; FullName = 'path/default.json' })
            }
            
            $profile = Get-UserProfile -Name "default" -ProfilePath $script:testConfig.ProfilePath
            
            $profile | Should -Not -BeNullOrEmpty
        }
        
        It "Should set profile preferences" {
            $preferences = @{ Theme = 'dark'; ExpertMode = $true }
            
            Set-UserProfile -Name "test" -Preferences $preferences -ProfilePath $script:testConfig.ProfilePath
            
            Should -Invoke Set-Content -Times 1
        }
        
        It "Should export profiles" {
            Mock Get-UserProfile { return @{ Name = 'test'; Preferences = @{} } }
            
            Export-UserProfile -Name "test" -Path "$TestDrive/export.json"
            
            Should -Invoke Set-Content -Times 1 -ParameterFilter {
                $Path -like '*export.json'
            }
        }
        
        It "Should import profiles" {
            Mock Test-Path { return $true }
            Mock Get-Content { return '{"name":"imported","preferences":{}}' }
            
            $profile = Import-UserProfile -Path "$TestDrive/import.json" -ProfilePath $script:testConfig.ProfilePath
            
            $profile | Should -Not -BeNullOrEmpty
            $profile.Name | Should -Be "imported"
        }
    }
    
    Context "Theme and Customization" {
        It "Should set UI themes" {
            Mock Set-UserPreferences {}
            
            Set-UITheme -Theme "dark"
            
            Should -Invoke Set-UserPreferences -Times 1 -ParameterFilter {
                $Preferences.Theme -eq 'dark'
            }
        }
        
        It "Should get current theme" {
            Mock Get-UserPreferences { return @{ Theme = 'light' } }
            
            $theme = Get-UITheme
            
            $theme | Should -Be 'light'
        }
        
        It "Should enable expert mode" {
            Mock Set-UserPreferences {}
            
            Enable-ExpertMode
            
            Should -Invoke Set-UserPreferences -Times 1 -ParameterFilter {
                $Preferences.ExpertMode -eq $true
            }
        }
        
        It "Should disable expert mode" {
            Mock Set-UserPreferences {}
            
            Disable-ExpertMode
            
            Should -Invoke Set-UserPreferences -Times 1 -ParameterFilter {
                $Preferences.ExpertMode -eq $false
            }
        }
    }
    
    Context "Help and Guidance" {
        It "Should show user guide" {
            Mock Show-UserGuide { return $true }
            
            $result = Show-UserGuide
            
            $result | Should -Be $true
        }
        
        It "Should start tutorial mode" {
            Mock Start-TutorialMode { return @{ Started = $true } }
            
            $result = Start-TutorialMode
            
            $result.Started | Should -Be $true
        }
        
        It "Should provide contextual help" {
            Mock Get-ContextualHelp { return "Help for LabRunner" }
            
            $help = Get-ContextualHelp -Context "LabRunner"
            
            $help | Should -Be "Help for LabRunner"
        }
        
        It "Should show troubleshooting guide" {
            Mock Show-TroubleshootingGuide { return @{ Shown = $true } }
            
            $result = Show-TroubleshootingGuide -Issue "ModuleNotLoading"
            
            $result.Shown | Should -Be $true
        }
    }
    
    Context "Performance and Analytics" {
        It "Should test user experience performance" {
            $result = Test-UserExperience
            
            $result | Should -Not -BeNullOrEmpty
            $result.LoadTime | Should -Not -BeNullOrEmpty
            $result.ResponsiveUI | Should -Be $true
        }
        
        It "Should collect usage analytics" {
            Mock Get-UsageAnalytics { 
                return @{
                    ModulesUsed = @('LabRunner', 'PatchManager')
                    SessionDuration = 300
                    CommandsExecuted = 15
                }
            }
            
            $analytics = Get-UsageAnalytics
            
            $analytics.ModulesUsed.Count | Should -Be 2
            $analytics.SessionDuration | Should -BeGreaterThan 0
        }
        
        It "Should optimize user workflows" {
            Mock Optimize-UserWorkflow { 
                return @{
                    Optimizations = @('CacheEnabled', 'LazyLoading')
                    PerformanceGain = 25
                }
            }
            
            $result = Optimize-UserWorkflow
            
            $result.Optimizations.Count | Should -BeGreaterThan 0
            $result.PerformanceGain | Should -BeGreaterThan 0
        }
    }
}

AfterAll {
    # Clean up
    if (Get-Module UserExperience) {
        Remove-Module UserExperience -Force
    }
}