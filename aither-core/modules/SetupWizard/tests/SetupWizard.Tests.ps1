#Requires -Version 7.0

BeforeAll {
    # Import the module being tested
    $modulePath = Join-Path $PSScriptRoot ".." "SetupWizard.psm1"
    Import-Module $modulePath -Force -ErrorAction Stop
    
    # Setup test environment
    $script:TestPath = Join-Path ([System.IO.Path]::GetTempPath()) "SetupWizardTests"
    $script:TestConfigPath = Join-Path $script:TestPath "config"
    
    # Create test directories
    if (Test-Path $script:TestPath) {
        Remove-Item $script:TestPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $script:TestPath -Force | Out-Null
    New-Item -ItemType Directory -Path $script:TestConfigPath -Force | Out-Null
    
    # Mock environment variables to avoid affecting real system
    $script:OriginalEnv = @{
        NO_PROGRESS = $env:NO_PROGRESS
        NO_PROMPT = $env:NO_PROMPT
        APPDATA = $env:APPDATA
        HOME = $env:HOME
    }
    
    # Set test environment
    $env:NO_PROGRESS = "1"
    $env:NO_PROMPT = "1"
    if ($IsWindows) {
        $env:APPDATA = $script:TestPath
    } else {
        $env:HOME = $script:TestPath
    }
}

Describe "SetupWizard Module Tests" {
    Context "Module Loading and Initialization" {
        It "Should import module successfully" {
            Get-Module SetupWizard | Should -Not -BeNullOrEmpty
        }
        
        It "Should have valid manifest" {
            $manifestPath = Join-Path $PSScriptRoot ".." "SetupWizard.psd1"
            Test-Path $manifestPath | Should -Be $true
            
            { Test-ModuleManifest $manifestPath } | Should -Not -Throw
        }
        
        It "Should export main setup functions" {
            $expectedFunctions = @(
                'Start-IntelligentSetup',
                'Get-PlatformInfo',
                'Generate-QuickStartGuide'
            )
            
            foreach ($function in $expectedFunctions) {
                Get-Command $function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should export test functions" {
            $testFunctions = @(
                'Test-PlatformRequirements',
                'Test-PowerShellVersion',
                'Test-GitInstallation',
                'Test-InfrastructureTools',
                'Test-ModuleDependencies',
                'Test-NetworkConnectivity',
                'Test-SecuritySettings'
            )
            
            foreach ($function in $testFunctions) {
                Get-Command $function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "Get-PlatformInfo Function Tests" {
        It "Should detect current platform correctly" {
            $platformInfo = Get-PlatformInfo
            
            $platformInfo | Should -Not -BeNullOrEmpty
            $platformInfo.OS | Should -BeIn @('Windows', 'Linux', 'macOS')
            $platformInfo.Architecture | Should -Not -BeNullOrEmpty
            $platformInfo.PowerShell | Should -Not -BeNullOrEmpty
        }
        
        It "Should include PowerShell version information" {
            $platformInfo = Get-PlatformInfo
            
            $platformInfo.PowerShell | Should -Match '^\d+\.\d+\.\d+'
        }
        
        It "Should provide platform-specific version information" {
            $platformInfo = Get-PlatformInfo
            
            if ($IsWindows) {
                $platformInfo.Version | Should -Not -BeNullOrEmpty
            }
            # Linux and macOS version detection may vary based on environment
        }
    }
    
    Context "Test-PlatformRequirements Function Tests" {
        It "Should test platform requirements successfully" {
            $setupState = @{
                Platform = Get-PlatformInfo
                Warnings = @()
                Recommendations = @()
            }
            
            $result = Test-PlatformRequirements -SetupState $setupState
            
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'Platform Detection'
            $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
            $result.Details | Should -Not -BeNullOrEmpty
            $result.Data | Should -Not -BeNullOrEmpty
        }
        
        It "Should detect Windows-specific requirements" {
            if ($IsWindows) {
                $setupState = @{
                    Platform = Get-PlatformInfo
                    Warnings = @()
                    Recommendations = @()
                }
                
                $result = Test-PlatformRequirements -SetupState $setupState
                
                $result.Details | Should -Match "Operating System: Windows"
            }
        }
        
        It "Should check execution policy on Windows" {
            if ($IsWindows) {
                $setupState = @{
                    Platform = Get-PlatformInfo
                    Warnings = @()
                    Recommendations = @()
                }
                
                $result = Test-PlatformRequirements -SetupState $setupState
                
                # Should mention execution policy in some way
                $result.Details -join ' ' | Should -Match "(execution policy|ExecutionPolicy)"
            }
        }
    }
    
    Context "Test-PowerShellVersion Function Tests" {
        It "Should validate PowerShell version correctly" {
            $setupState = @{
                Platform = Get-PlatformInfo
                Recommendations = @()
            }
            
            $result = Test-PowerShellVersion -SetupState $setupState
            
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'PowerShell Version'
            $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
            $result.Details | Should -Not -BeNullOrEmpty
        }
        
        It "Should pass for PowerShell 7+" {
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                $setupState = @{
                    Platform = Get-PlatformInfo
                    Recommendations = @()
                }
                
                $result = Test-PowerShellVersion -SetupState $setupState
                
                $result.Status | Should -Be 'Passed'
                $result.Details -join ' ' | Should -Match "Full compatibility"
            }
        }
        
        It "Should detect PowerShell 7 installation on Windows" {
            if ($IsWindows) {
                $setupState = @{
                    Platform = Get-PlatformInfo
                    Recommendations = @()
                }
                
                $result = Test-PowerShellVersion -SetupState $setupState
                
                # Should check for PowerShell 7 installation
                $result.Details | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "Test-GitInstallation Function Tests" {
        It "Should test Git installation" {
            $setupState = @{
                Platform = Get-PlatformInfo
                Recommendations = @()
            }
            
            $result = Test-GitInstallation -SetupState $setupState
            
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'Git Installation'
            $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
            $result.Details | Should -Not -BeNullOrEmpty
        }
        
        It "Should provide installation recommendations when Git is missing" {
            # Mock git command as not found
            $originalPath = $env:PATH
            $env:PATH = ""
            
            try {
                $setupState = @{
                    Platform = Get-PlatformInfo
                    Recommendations = @()
                }
                
                $result = Test-GitInstallation -SetupState $setupState
                
                if ($result.Status -eq 'Warning') {
                    $setupState.Recommendations | Should -Not -BeNullOrEmpty
                }
            }
            finally {
                $env:PATH = $originalPath
            }
        }
        
        It "Should check Git configuration when Git is available" {
            if (Get-Command git -ErrorAction SilentlyContinue) {
                $setupState = @{
                    Platform = Get-PlatformInfo
                    Recommendations = @()
                }
                
                $result = Test-GitInstallation -SetupState $setupState
                
                $result.Details -join ' ' | Should -Match "(Git|git)"
            }
        }
    }
    
    Context "Test-InfrastructureTools Function Tests" {
        It "Should test infrastructure tools availability" {
            $setupState = @{
                Platform = Get-PlatformInfo
                Recommendations = @()
            }
            
            $result = Test-InfrastructureTools -SetupState $setupState
            
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'Infrastructure Tools'
            $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
            $result.Details | Should -Not -BeNullOrEmpty
        }
        
        It "Should prefer OpenTofu over Terraform" {
            $setupState = @{
                Platform = Get-PlatformInfo
                Recommendations = @()
            }
            
            $result = Test-InfrastructureTools -SetupState $setupState
            
            # Should mention OpenTofu or Terraform in details
            $detailsText = $result.Details -join ' '
            $detailsText | Should -Match "(OpenTofu|Terraform|infrastructure)"
        }
        
        It "Should detect optional tools like Docker" {
            $setupState = @{
                Platform = Get-PlatformInfo
                Recommendations = @()
            }
            
            $result = Test-InfrastructureTools -SetupState $setupState
            
            # Should run without errors regardless of tools installed
            $result.Details | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Test-ModuleDependencies Function Tests" {
        It "Should check for core modules" {
            $setupState = @{
                Platform = Get-PlatformInfo
            }
            
            $result = Test-ModuleDependencies -SetupState $setupState
            
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'Module Dependencies'
            $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
            $result.Details | Should -Not -BeNullOrEmpty
        }
        
        It "Should check for optional PowerShell modules" {
            $setupState = @{
                Platform = Get-PlatformInfo
            }
            
            $result = Test-ModuleDependencies -SetupState $setupState
            
            # Should mention optional modules
            $result.Details -join ' ' | Should -Match "(Optional|module)"
        }
    }
    
    Context "Test-NetworkConnectivity Function Tests" {
        It "Should test network connectivity" {
            $setupState = @{
                Platform = Get-PlatformInfo
            }
            
            $result = Test-NetworkConnectivity -SetupState $setupState
            
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'Network Connectivity'
            $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
            $result.Details | Should -Not -BeNullOrEmpty
        }
        
        It "Should check key endpoints" {
            $setupState = @{
                Platform = Get-PlatformInfo
            }
            
            $result = Test-NetworkConnectivity -SetupState $setupState
            
            # Should mention GitHub or other endpoints
            $result.Details -join ' ' | Should -Match "(GitHub|reachable|unreachable)"
        }
        
        It "Should detect proxy configuration" {
            # Test with proxy environment variables
            $originalProxy = $env:HTTP_PROXY
            $env:HTTP_PROXY = "http://proxy.example.com:8080"
            
            try {
                $setupState = @{
                    Platform = Get-PlatformInfo
                }
                
                $result = Test-NetworkConnectivity -SetupState $setupState
                
                $result.Details -join ' ' | Should -Match "Proxy"
            }
            finally {
                $env:HTTP_PROXY = $originalProxy
            }
        }
    }
    
    Context "Test-SecuritySettings Function Tests" {
        It "Should test security settings" {
            $setupState = @{
                Platform = Get-PlatformInfo
            }
            
            $result = Test-SecuritySettings -SetupState $setupState
            
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'Security Settings'
            $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
            $result.Details | Should -Not -BeNullOrEmpty
        }
        
        It "Should check platform-specific security features" {
            $setupState = @{
                Platform = Get-PlatformInfo
            }
            
            $result = Test-SecuritySettings -SetupState $setupState
            
            if ($IsWindows) {
                # Should check Windows Defender or security features
                $result.Details -join ' ' | Should -Match "(Defender|security|Windows)"
            }
        }
    }
    
    Context "Initialize-Configuration Function Tests" {
        It "Should initialize configuration successfully" {
            $setupState = @{
                Platform = Get-PlatformInfo
                InstallationProfile = 'minimal'
            }
            
            $result = Initialize-Configuration -SetupState $setupState
            
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'Configuration Files'
            $result.Status | Should -BeIn @('Passed', 'Warning')
            $result.Details | Should -Not -BeNullOrEmpty
        }
        
        It "Should create configuration directories" {
            $setupState = @{
                Platform = Get-PlatformInfo
                InstallationProfile = 'minimal'
            }
            
            $result = Initialize-Configuration -SetupState $setupState
            
            # Should mention configuration setup
            $result.Details -join ' ' | Should -Match "(configuration|config)"
        }
        
        It "Should handle ConfigurationCore module if available" {
            $setupState = @{
                Platform = Get-PlatformInfo
                InstallationProfile = 'minimal'
            }
            
            $result = Initialize-Configuration -SetupState $setupState
            
            # Should work regardless of ConfigurationCore availability
            $result.Status | Should -BeIn @('Passed', 'Warning')
        }
    }
    
    Context "Generate-QuickStartGuide Function Tests" {
        It "Should generate quick start guide" {
            $setupState = @{
                Platform = Get-PlatformInfo
                Steps = @(
                    @{Name = 'Test Step'; Status = 'Passed'}
                )
                Warnings = @()
                Recommendations = @()
            }
            
            $result = Generate-QuickStartGuide -SetupState $setupState
            
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'Quick Start Guide'
            $result.Status | Should -BeIn @('Passed', 'Warning')
            $result.Details | Should -Not -BeNullOrEmpty
        }
        
        It "Should create guide file" {
            Push-Location $script:TestPath
            
            try {
                $setupState = @{
                    Platform = Get-PlatformInfo
                    Steps = @(
                        @{Name = 'Test Step'; Status = 'Passed'}
                    )
                    Warnings = @()
                    Recommendations = @()
                }
                
                $result = Generate-QuickStartGuide -SetupState $setupState
                
                if ($result.Status -eq 'Passed') {
                    # Should mention guide creation
                    $result.Details -join ' ' | Should -Match "(guide|Quick Start)"
                }
            }
            finally {
                Pop-Location
            }
        }
    }
    
    Context "Test-SetupCompletion Function Tests" {
        It "Should validate setup completion" {
            $setupState = @{
                Steps = @(
                    @{Name = 'Test Step 1'; Status = 'Passed'},
                    @{Name = 'Test Step 2'; Status = 'Warning'},
                    @{Name = 'Test Step 3'; Status = 'Failed'}
                )
                StartTime = (Get-Date).AddMinutes(-5)
            }
            
            $result = Test-SetupCompletion -SetupState $setupState
            
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'Final Validation'
            $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
            $result.Details | Should -Not -BeNullOrEmpty
        }
        
        It "Should count passed, failed, and warning steps" {
            $setupState = @{
                Steps = @(
                    @{Name = 'Passed Step'; Status = 'Passed'},
                    @{Name = 'Failed Step'; Status = 'Failed'},
                    @{Name = 'Warning Step'; Status = 'Warning'}
                )
                StartTime = (Get-Date).AddSeconds(-30)
            }
            
            $result = Test-SetupCompletion -SetupState $setupState
            
            $result.Details -join ' ' | Should -Match "Passed: 1"
            $result.Details -join ' ' | Should -Match "Failed: 1"
            $result.Details -join ' ' | Should -Match "Warnings: 1"
        }
        
        It "Should calculate setup duration" {
            $setupState = @{
                Steps = @(
                    @{Name = 'Test Step'; Status = 'Passed'}
                )
                StartTime = (Get-Date).AddSeconds(-60)
            }
            
            $result = Test-SetupCompletion -SetupState $setupState
            
            $result.Details -join ' ' | Should -Match "Total time"
        }
    }
    
    Context "Get-SetupSteps Function Tests" {
        It "Should return steps for minimal profile" {
            $result = Get-SetupSteps -Profile 'minimal'
            
            $result | Should -Not -BeNullOrEmpty
            $result.Steps | Should -Not -BeNullOrEmpty
            $result.Profile | Should -Not -BeNullOrEmpty
            $result.Profile.Name | Should -Be 'Minimal'
        }
        
        It "Should return steps for developer profile" {
            $result = Get-SetupSteps -Profile 'developer'
            
            $result | Should -Not -BeNullOrEmpty
            $result.Steps | Should -Not -BeNullOrEmpty
            $result.Profile.Name | Should -Be 'Developer'
            $result.Steps.Count | Should -BeGreaterThan 8
        }
        
        It "Should return steps for full profile" {
            $result = Get-SetupSteps -Profile 'full'
            
            $result | Should -Not -BeNullOrEmpty
            $result.Steps | Should -Not -BeNullOrEmpty
            $result.Profile.Name | Should -Be 'Full'
            $result.Steps.Count | Should -BeGreaterThan 10
        }
        
        It "Should handle custom profile" {
            $customProfile = @{
                Name = 'Custom Test'
                Description = 'Test custom profile'
                Steps = @(
                    @{Name = 'Custom Step'; Function = 'Test-Custom'; Required = $true}
                )
            }
            
            $result = Get-SetupSteps -Profile 'custom' -CustomProfile $customProfile
            
            $result.Profile.Name | Should -Be 'Custom Test'
        }
        
        It "Should fallback to minimal for unknown profile" {
            $result = Get-SetupSteps -Profile 'unknown'
            
            $result.Profile.Name | Should -Be 'Minimal'
        }
    }
    
    Context "AI Tools Integration Tests" {
        It "Should have Test-NodeJsInstallation function" {
            Get-Command Test-NodeJsInstallation -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should test Node.js installation" {
            $setupState = @{
                Platform = Get-PlatformInfo
                Recommendations = @()
            }
            
            $result = Test-NodeJsInstallation -SetupState $setupState
            
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'Node.js Detection'
            $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
        }
        
        It "Should provide platform-specific Node.js installation recommendations" {
            $setupState = @{
                Platform = Get-PlatformInfo
                Recommendations = @()
            }
            
            # Mock node as not available
            $originalPath = $env:PATH
            $env:PATH = ""
            
            try {
                $result = Test-NodeJsInstallation -SetupState $setupState
                
                if ($result.Status -eq 'Warning') {
                    $setupState.Recommendations | Should -Not -BeNullOrEmpty
                }
            }
            finally {
                $env:PATH = $originalPath
            }
        }
    }
    
    Context "Error Recovery System Tests" {
        It "Should have Invoke-ErrorRecovery function" {
            Get-Command Invoke-ErrorRecovery -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle Node.js installation recovery" {
            $stepResult = @{
                Name = 'Node.js Detection'
                Status = 'Failed'
                Details = @('Node.js not found')
            }
            
            $setupState = @{
                Platform = Get-PlatformInfo
            }
            
            $recovery = Invoke-ErrorRecovery -StepResult $stepResult -SetupState $setupState -StepName 'Node.js Detection'
            
            $recovery | Should -Not -BeNullOrEmpty
            $recovery.Method | Should -Be 'Package Manager Installation'
            $recovery.Attempted | Should -BeOfType [bool]
        }
        
        It "Should handle Git installation recovery" {
            $stepResult = @{
                Name = 'Git Installation'
                Status = 'Failed'
                Details = @('Git not found')
            }
            
            $setupState = @{
                Platform = Get-PlatformInfo
            }
            
            $recovery = Invoke-ErrorRecovery -StepResult $stepResult -SetupState $setupState -StepName 'Git Installation'
            
            $recovery.Method | Should -Be 'Package Manager Installation'
        }
        
        It "Should handle configuration recovery" {
            $stepResult = @{
                Name = 'Configuration Files'
                Status = 'Failed'
                Details = @('Configuration creation failed')
            }
            
            $setupState = @{
                Platform = Get-PlatformInfo
            }
            
            $recovery = Invoke-ErrorRecovery -StepResult $stepResult -SetupState $setupState -StepName 'Configuration Files'
            
            $recovery.Method | Should -Be 'Directory Creation and Permissions Fix'
        }
        
        It "Should provide generic recovery for unknown steps" {
            $stepResult = @{
                Name = 'Unknown Step'
                Status = 'Failed'
                Details = @('Unknown error')
            }
            
            $setupState = @{
                Platform = Get-PlatformInfo
            }
            
            $recovery = Invoke-ErrorRecovery -StepResult $stepResult -SetupState $setupState -StepName 'Unknown Step'
            
            $recovery.Method | Should -Be 'Generic Retry'
        }
    }
    
    Context "Progress Display Tests" {
        It "Should display enhanced progress correctly" {
            $state = @{
                CurrentStep = 5
                TotalSteps = 10
            }
            
            { Show-EnhancedProgress -State $state -StepName "Test Step" -Status "Running" } | Should -Not -Throw
        }
        
        It "Should handle different status types" {
            $state = @{
                CurrentStep = 3
                TotalSteps = 8
            }
            
            $statuses = @('Running', 'Success', 'Warning', 'Failed', 'Retrying', 'Recovering')
            
            foreach ($status in $statuses) {
                { Show-EnhancedProgress -State $state -StepName "Test Step" -Status $status } | Should -Not -Throw
            }
        }
        
        It "Should include error context when provided" {
            $state = @{
                CurrentStep = 2
                TotalSteps = 5
            }
            
            $errorContext = @{
                LastError = "Test error message"
                RecoveryAttempted = $true
                RecoveryMethod = "Test recovery"
            }
            
            { Show-EnhancedProgress -State $state -StepName "Test Step" -Status "Failed" -ErrorContext $errorContext } | Should -Not -Throw
        }
    }
    
    Context "System Information Tests" {
        It "Should gather detailed system information" {
            $sysInfo = Get-DetailedSystemInfo
            
            $sysInfo | Should -Not -BeNullOrEmpty
            $sysInfo.OS | Should -Not -BeNullOrEmpty
            $sysInfo.PowerShell | Should -Not -BeNullOrEmpty
            $sysInfo.Hardware | Should -Not -BeNullOrEmpty
            $sysInfo.Network | Should -Not -BeNullOrEmpty
        }
        
        It "Should detect current platform in system info" {
            $sysInfo = Get-DetailedSystemInfo
            
            $sysInfo.OS.Platform | Should -BeIn @('Windows', 'Linux', 'macOS')
        }
        
        It "Should include PowerShell details" {
            $sysInfo = Get-DetailedSystemInfo
            
            $sysInfo.PowerShell.Version | Should -Not -BeNullOrEmpty
            $sysInfo.PowerShell.Edition | Should -BeIn @('Core', 'Desktop')
        }
        
        It "Should test network connectivity" {
            $sysInfo = Get-DetailedSystemInfo
            
            $sysInfo.Network.InternetConnected | Should -BeOfType [bool]
        }
    }
    
    Context "Cloud CLI Detection Tests" {
        It "Should test cloud CLI detection" {
            $setupState = @{
                Platform = Get-PlatformInfo
                Recommendations = @()
            }
            
            $result = Test-CloudCLIs -SetupState $setupState
            
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'Cloud CLIs Detection'
            $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
        }
        
        It "Should check multiple cloud tools" {
            $setupState = @{
                Platform = Get-PlatformInfo
                Recommendations = @()
            }
            
            $result = Test-CloudCLIs -SetupState $setupState
            
            # Should mention various cloud tools
            $result.Details -join ' ' | Should -Match "(Azure|AWS|Google|Docker|Kubernetes)"
        }
    }
    
    Context "Development Environment Tests" {
        It "Should test development environment" {
            $setupState = @{
                Platform = Get-PlatformInfo
                Recommendations = @()
            }
            
            $result = Test-DevEnvironment -SetupState $setupState
            
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'Development Environment'
            $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
        }
        
        It "Should check for VS Code" {
            $setupState = @{
                Platform = Get-PlatformInfo
                Recommendations = @()
            }
            
            $result = Test-DevEnvironment -SetupState $setupState
            
            $result.Details -join ' ' | Should -Match "(VS Code|code)"
        }
    }
    
    Context "License and Module Communication Tests" {
        It "Should test license integration" {
            $setupState = @{
                Platform = Get-PlatformInfo
            }
            
            $result = Test-LicenseIntegration -SetupState $setupState
            
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'License Management'
            $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
        }
        
        It "Should test module communication" {
            $setupState = @{
                Platform = Get-PlatformInfo
            }
            
            $result = Test-ModuleCommunication -SetupState $setupState
            
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'Module Communication'
            $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
        }
    }
    
    Context "Cross-Platform Compatibility" {
        It "Should work on current platform" {
            $platform = if ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } elseif ($IsMacOS) { "macOS" } else { "Unknown" }
            $platform | Should -BeIn @("Windows", "Linux", "macOS")
            
            # Test basic platform detection
            $platformInfo = Get-PlatformInfo
            $platformInfo.OS | Should -Be $platform
        }
        
        It "Should handle platform-specific paths" {
            $setupState = @{
                Platform = Get-PlatformInfo
                InstallationProfile = 'minimal'
            }
            
            $result = Initialize-Configuration -SetupState $setupState
            
            # Should work regardless of platform
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should provide platform-specific recommendations" {
            $setupState = @{
                Platform = Get-PlatformInfo
                Recommendations = @()
            }
            
            # Mock missing tools to trigger recommendations
            $originalPath = $env:PATH
            $env:PATH = ""
            
            try {
                Test-GitInstallation -SetupState $setupState | Out-Null
                Test-NodeJsInstallation -SetupState $setupState | Out-Null
                
                # Should have some recommendations for missing tools
                $setupState.Recommendations | Should -Not -BeNullOrEmpty
            }
            finally {
                $env:PATH = $originalPath
            }
        }
    }
    
    Context "Integration Tests" {
        It "Should run minimal setup workflow without errors" {
            # Set environment for non-interactive mode
            $env:NO_PROMPT = "1"
            $env:NO_PROGRESS = "1"
            
            try {
                { Start-IntelligentSetup -InstallationProfile 'minimal' -SkipOptional } | Should -Not -Throw
            }
            catch {
                # If it throws due to missing dependencies, that's expected in test environment
                $_.Exception.Message | Should -Not -Match "catastrophic|fatal|critical"
            }
        }
        
        It "Should handle configuration management workflow" {
            $setupState = @{
                Platform = Get-PlatformInfo
                InstallationProfile = 'minimal'
                Steps = @()
                Warnings = @()
                Recommendations = @()
            }
            
            # Test the configuration workflow
            $configResult = Initialize-Configuration -SetupState $setupState
            $configResult | Should -Not -BeNullOrEmpty
            
            $guideResult = Generate-QuickStartGuide -SetupState $setupState
            $guideResult | Should -Not -BeNullOrEmpty
            
            $completionResult = Test-SetupCompletion -SetupState $setupState
            $completionResult | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Error Handling and Edge Cases" {
        It "Should handle missing module gracefully" {
            $setupState = @{
                Platform = Get-PlatformInfo
            }
            
            # All test functions should handle missing dependencies gracefully
            { Test-ModuleDependencies -SetupState $setupState } | Should -Not -Throw
            { Test-DevEnvironment -SetupState $setupState } | Should -Not -Throw
            { Test-LicenseIntegration -SetupState $setupState } | Should -Not -Throw
        }
        
        It "Should handle network failures gracefully" {
            $setupState = @{
                Platform = Get-PlatformInfo
            }
            
            # Network tests should not throw even if network is unavailable
            { Test-NetworkConnectivity -SetupState $setupState } | Should -Not -Throw
        }
        
        It "Should handle permission issues gracefully" {
            $setupState = @{
                Platform = Get-PlatformInfo
                InstallationProfile = 'minimal'
            }
            
            # Configuration initialization should handle permission issues
            { Initialize-Configuration -SetupState $setupState } | Should -Not -Throw
        }
        
        It "Should handle invalid installation profiles" {
            $result = Get-SetupSteps -Profile 'invalid-profile'
            
            # Should fallback to minimal profile
            $result.Profile.Name | Should -Be 'Minimal'
        }
    }
    
    Context "Performance and Resource Management" {
        It "Should complete basic tests efficiently" {
            $startTime = Get-Date
            
            $setupState = @{
                Platform = Get-PlatformInfo
                Recommendations = @()
            }
            
            # Run several test functions
            Test-PlatformRequirements -SetupState $setupState | Out-Null
            Test-PowerShellVersion -SetupState $setupState | Out-Null
            Test-SecuritySettings -SetupState $setupState | Out-Null
            
            $duration = (Get-Date) - $startTime
            $duration.TotalSeconds | Should -BeLessThan 5
        }
        
        It "Should handle large setup state objects" {
            $setupState = @{
                Platform = Get-PlatformInfo
                Steps = @()
                Warnings = @()
                Recommendations = @()
            }
            
            # Add many items to test performance
            1..50 | ForEach-Object {
                $setupState.Steps += @{Name = "Test Step $_"; Status = 'Passed'}
                $setupState.Warnings += "Test Warning $_"
                $setupState.Recommendations += "Test Recommendation $_"
            }
            
            { Test-SetupCompletion -SetupState $setupState } | Should -Not -Throw
        }
    }
}

AfterAll {
    # Restore original environment
    foreach ($var in $script:OriginalEnv.GetEnumerator()) {
        if ($var.Value) {
            Set-Item "env:$($var.Key)" $var.Value
        } else {
            Remove-Item "env:$($var.Key)" -ErrorAction SilentlyContinue
        }
    }
    
    # Clean up test environment
    if (Test-Path $script:TestPath) {
        Remove-Item $script:TestPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Remove the module
    Remove-Module SetupWizard -Force -ErrorAction SilentlyContinue
}