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
    Mock Start-Sleep {}
    
    # Create test environment
    $script:testEnv = @{
        StartTime = Get-Date
        ModulePath = $modulePath
        TestConfig = @{
            UIMode = 'enhanced'
            Theme = 'default'
            ShowProgress = $true
        }
    }
}

Describe "StartupExperience Module Tests" {
    Context "Module Loading" {
        It "Should export expected functions" {
            $module = Get-Module StartupExperience
            $module | Should -Not -BeNullOrEmpty
            
            # Critical functions for startup
            $requiredFunctions = @(
                'Start-EnhancedStartup',
                'Show-StartupProgress',
                'Initialize-StartupEnvironment',
                'Test-StartupPerformance',
                'Show-ModuleLoadingProgress'
            )
            
            foreach ($function in $requiredFunctions) {
                $module.ExportedFunctions.Keys | Should -Contain $function
            }
        }
    }
    
    Context "Startup Sequence" {
        BeforeEach {
            Mock Write-Host {}
            Mock Start-Sleep {}
            Mock Get-Module { return @{ Name = 'TestModule' } }
        }
        
        It "Should load in under 3 seconds" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            Mock Import-Module {}
            Mock Test-ModuleAvailability { return $true }
            
            $result = Start-EnhancedStartup -Modules @('Logging', 'ConfigurationCore')
            
            $stopwatch.Stop()
            
            $stopwatch.Elapsed.TotalSeconds | Should -BeLessThan 3
            $result.Success | Should -Be $true
        }
        
        It "Should detect first-time users" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -like '*startup.state' }
            
            $result = Initialize-StartupEnvironment
            
            $result.IsFirstTime | Should -Be $true
            $result.RequiresSetup | Should -Be $true
        }
        
        It "Should initialize required modules" {
            Mock Import-Module {}
            Mock Test-ModuleAvailability { return $true }
            
            $modules = @('Logging', 'ConfigurationCore', 'ModuleCommunication')
            $result = Start-EnhancedStartup -Modules $modules
            
            Should -Invoke Import-Module -Times $modules.Count
            $result.ModulesLoaded | Should -Be $modules.Count
        }
        
        It "Should handle missing dependencies" {
            Mock Test-ModuleAvailability { return $false }
            Mock Write-Warning {}
            
            $result = Start-EnhancedStartup -Modules @('NonExistentModule')
            
            $result.Success | Should -Be $false
            $result.MissingModules | Should -Contain 'NonExistentModule'
            Should -Invoke Write-Warning -Times -AtLeast 1
        }
    }
    
    Context "Environment Validation" {
        It "Should verify PowerShell version" {
            $validation = Test-StartupEnvironment
            
            $validation | Should -Not -BeNullOrEmpty
            $validation.PowerShellVersion | Should -BeGreaterOrEqual 7
            $validation.PowerShellValid | Should -Be $true
        }
        
        It "Should check platform compatibility" {
            $validation = Test-StartupEnvironment
            
            $validation.Platform | Should -BeIn @('Windows', 'Linux', 'macOS')
            $validation.PlatformSupported | Should -Be $true
        }
        
        It "Should validate prerequisites" {
            Mock Test-Path { return $true }
            Mock Get-Command { return @{ Name = 'git' } }
            
            $validation = Test-StartupEnvironment
            
            $validation.Prerequisites | Should -Not -BeNullOrEmpty
            $validation.Prerequisites.Git | Should -Be $true
            $validation.Prerequisites.ModulePath | Should -Be $true
        }
    }
    
    Context "Progress Indicators" {
        BeforeEach {
            Mock Write-Progress {}
            Mock Write-Host {}
        }
        
        It "Should show module loading progress" {
            $modules = @('Module1', 'Module2', 'Module3')
            
            Show-ModuleLoadingProgress -Modules $modules -Current 2
            
            Should -Invoke Write-Progress -Times 1 -ParameterFilter {
                $PercentComplete -eq 66
            }
        }
        
        It "Should display startup progress" {
            Show-StartupProgress -Activity "Initializing" -PercentComplete 50
            
            Should -Invoke Write-Progress -Times 1 -ParameterFilter {
                $Activity -eq "Initializing" -and $PercentComplete -eq 50
            }
        }
        
        It "Should show completion status" {
            Show-StartupProgress -Activity "Complete" -Completed
            
            Should -Invoke Write-Progress -Times 1 -ParameterFilter {
                $Completed -eq $true
            }
        }
    }
    
    Context "Error Recovery" {
        BeforeEach {
            Mock Write-Error {}
            Mock Write-Warning {}
        }
        
        It "Should recover from module loading failures" {
            Mock Import-Module { throw "Module load failed" }
            Mock Test-ModuleAvailability { return $false }
            
            $result = Start-EnhancedStartup -Modules @('FailingModule') -ContinueOnError
            
            $result.Success | Should -Be $true
            $result.PartialSuccess | Should -Be $true
            $result.FailedModules | Should -Contain 'FailingModule'
        }
        
        It "Should handle corrupted configuration gracefully" {
            Mock Get-Content { throw "Invalid JSON" }
            Mock Test-Path { return $true }
            
            $result = Initialize-StartupEnvironment -ConfigPath "corrupt.json"
            
            $result.ConfigurationValid | Should -Be $false
            $result.UsingDefaults | Should -Be $true
            Should -Invoke Write-Warning -Times -AtLeast 1
        }
        
        It "Should detect and recover from crashed sessions" {
            Mock Test-Path { return $true }
            Mock Get-Content { 
                return @{
                    SessionId = 'old-session'
                    StartTime = (Get-Date).AddMinutes(-5)
                    Status = 'Starting'
                } | ConvertTo-Json
            }
            
            $result = Initialize-StartupEnvironment
            
            $result.RecoveredFromCrash | Should -Be $true
            $result.PreviousSessionCleaned | Should -Be $true
        }
    }
    
    Context "Performance Monitoring" {
        BeforeEach {
            Mock Measure-Command { return [timespan]::FromMilliseconds(100) }
        }
        
        It "Should measure startup performance" {
            $metrics = Test-StartupPerformance
            
            $metrics | Should -Not -BeNullOrEmpty
            $metrics.TotalTime | Should -Not -BeNullOrEmpty
            $metrics.ModuleLoadTimes | Should -Not -BeNullOrEmpty
        }
        
        It "Should track module loading times" {
            Mock Import-Module {}
            
            $result = Start-EnhancedStartup -Modules @('Module1', 'Module2') -TrackPerformance
            
            $result.PerformanceMetrics | Should -Not -BeNullOrEmpty
            $result.PerformanceMetrics.ModuleTimes | Should -HaveCount 2
        }
        
        It "Should identify slow-loading modules" {
            Mock Measure-Command { return [timespan]::FromSeconds(2) }
            Mock Import-Module {}
            
            $result = Start-EnhancedStartup -Modules @('SlowModule') -TrackPerformance
            
            $result.PerformanceMetrics.SlowModules | Should -Contain 'SlowModule'
        }
    }
    
    Context "UI Mode Support" {
        It "Should support enhanced UI mode" {
            Mock Test-TerminalCapabilities { return @{ SupportsColor = $true; SupportsUnicode = $true } }
            
            $result = Initialize-StartupUI -Mode 'enhanced'
            
            $result.UIMode | Should -Be 'enhanced'
            $result.FeaturesEnabled | Should -Contain 'Color'
            $result.FeaturesEnabled | Should -Contain 'Unicode'
        }
        
        It "Should fallback to basic UI when needed" {
            Mock Test-TerminalCapabilities { return @{ SupportsColor = $false; SupportsUnicode = $false } }
            
            $result = Initialize-StartupUI -Mode 'enhanced'
            
            $result.UIMode | Should -Be 'basic'
            $result.FallbackReason | Should -Not -BeNullOrEmpty
        }
        
        It "Should respect user UI preferences" {
            Mock Get-UserPreferences { return @{ UIMode = 'classic' } }
            
            $result = Initialize-StartupUI -Mode 'auto'
            
            $result.UIMode | Should -Be 'classic'
            $result.Source | Should -Be 'UserPreference'
        }
    }
    
    Context "Startup State Management" {
        BeforeEach {
            $script:statePath = Join-Path $TestDrive 'startup.state'
            Mock Set-Content {}
            Mock Get-Content { return '{}' }
        }
        
        It "Should save startup state" {
            $state = @{
                SessionId = 'test-session'
                StartTime = Get-Date
                Status = 'Started'
                Modules = @('Module1', 'Module2')
            }
            
            Save-StartupState -State $state -Path $script:statePath
            
            Should -Invoke Set-Content -Times 1 -ParameterFilter {
                $Path -eq $script:statePath
            }
        }
        
        It "Should load startup state" {
            Mock Test-Path { return $true }
            Mock Get-Content { 
                return @{
                    SessionId = 'test-session'
                    Status = 'Started'
                } | ConvertTo-Json
            }
            
            $state = Get-StartupState -Path $script:statePath
            
            $state | Should -Not -BeNullOrEmpty
            $state.SessionId | Should -Be 'test-session'
            $state.Status | Should -Be 'Started'
        }
        
        It "Should clean up old startup states" {
            Mock Get-ChildItem {
                return @(
                    [PSCustomObject]@{ 
                        Name = 'startup-old.state'
                        LastWriteTime = (Get-Date).AddDays(-7)
                        FullName = "$TestDrive/startup-old.state"
                    }
                )
            }
            Mock Remove-Item {}
            
            Clear-OldStartupStates -Path $TestDrive -DaysToKeep 3
            
            Should -Invoke Remove-Item -Times 1
        }
    }
    
    Context "Integration with Core Modules" {
        It "Should integrate with Logging module" {
            Mock Get-Module { return @{ Name = 'Logging' } }
            Mock Write-CustomLog {}
            
            Initialize-StartupLogging
            
            Should -Invoke Write-CustomLog -Times -AtLeast 1
        }
        
        It "Should integrate with ConfigurationCore" {
            Mock Get-Module { return @{ Name = 'ConfigurationCore' } }
            Mock Get-ModuleConfiguration { return @{ StartupConfig = @{} } }
            
            $config = Get-StartupConfiguration
            
            $config | Should -Not -BeNullOrEmpty
            Should -Invoke Get-ModuleConfiguration -Times 1
        }
        
        It "Should integrate with ProgressTracking" {
            Mock Get-Module { return @{ Name = 'ProgressTracking' } }
            Mock Start-ProgressOperation { return 'op-123' }
            
            $opId = Start-StartupProgressTracking
            
            $opId | Should -Be 'op-123'
            Should -Invoke Start-ProgressOperation -Times 1
        }
    }
    
    Context "Startup Optimization" {
        It "Should support parallel module loading" {
            Mock Start-Job { return [PSCustomObject]@{ Id = 1 } }
            Mock Wait-Job {}
            Mock Receive-Job { return @{ Success = $true } }
            Mock Remove-Job {}
            
            $result = Start-EnhancedStartup -Modules @('Module1', 'Module2') -Parallel
            
            Should -Invoke Start-Job -Times 2
            $result.LoadMethod | Should -Be 'Parallel'
        }
        
        It "Should cache module information" {
            Mock Test-Path { return $true }
            Mock Get-Content { 
                return @{
                    Modules = @{
                        'TestModule' = @{
                            Path = '/path/to/module'
                            Version = '1.0.0'
                            LastChecked = (Get-Date)
                        }
                    }
                } | ConvertTo-Json
            }
            
            $moduleInfo = Get-CachedModuleInfo -ModuleName 'TestModule'
            
            $moduleInfo | Should -Not -BeNullOrEmpty
            $moduleInfo.Version | Should -Be '1.0.0'
        }
        
        It "Should skip unnecessary module checks" {
            Mock Test-ModuleAvailability { return $true }
            Mock Get-CachedModuleInfo { 
                return @{
                    Available = $true
                    LastChecked = (Get-Date).AddMinutes(-1)
                }
            }
            
            $result = Test-ModuleAvailability -ModuleName 'CachedModule' -UseCache
            
            Should -Not -Invoke Test-ModuleAvailability -ParameterFilter {
                $ModuleName -eq 'CachedModule'
            }
        }
    }
}

AfterAll {
    # Clean up
    if (Get-Module StartupExperience) {
        Remove-Module StartupExperience -Force
    }
}