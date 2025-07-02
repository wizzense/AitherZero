BeforeDiscovery {
    $script:SetupWizardModulePath = Join-Path $PSScriptRoot '../../aither-core/modules/SetupWizard'
    $script:TestAppName = 'SetupWizard'
    
    # Verify the SetupWizard module exists
    if (-not (Test-Path $script:SetupWizardModulePath)) {
        throw "SetupWizard module not found at: $script:SetupWizardModulePath"
    }
}

Describe 'SetupWizard - Critical Infrastructure Testing' -Tags @('Critical', 'Infrastructure', 'SetupWizard', 'Installation') {
    
    BeforeAll {
        # Import test utilities
        . "$PSScriptRoot/../Shared/Test-Utilities.ps1"
        
        # Set up isolated test environment
        $script:TestWorkspace = New-TestWorkspace -TestName 'setupwizard-tests'
        
        # Save original environment
        $script:OriginalProjectRoot = $env:PROJECT_ROOT
        $script:OriginalUserProfile = $env:USERPROFILE
        $script:OriginalHome = $env:HOME
        $script:OriginalAppData = $env:APPDATA
        $script:OriginalPwshModulesPath = $env:PWSH_MODULES_PATH
        $script:OriginalEditor = $env:EDITOR
        $script:OriginalHttpProxy = $env:HTTP_PROXY
        $script:OriginalHttpsProxy = $env:HTTPS_PROXY
        
        # Create test directory structure
        $script:TestProjectRoot = Join-Path $script:TestWorkspace 'AitherZero'
        $script:TestModulesDir = Join-Path $script:TestProjectRoot 'aither-core' 'modules'
        $script:TestSharedDir = Join-Path $script:TestProjectRoot 'aither-core' 'shared'
        $script:TestConfigsDir = Join-Path $script:TestProjectRoot 'configs'
        $script:TestLogsDir = Join-Path $script:TestProjectRoot 'logs'
        $script:TestDocsDir = Join-Path $script:TestProjectRoot 'docs'
        $script:TestUserConfigDir = Join-Path $script:TestWorkspace '.config' 'aitherzero'
        $script:TestAppDataDir = Join-Path $script:TestWorkspace 'AppData' 'Roaming' 'AitherZero'
        $script:TestCredentialsDir = Join-Path $script:TestWorkspace '.aitherzero' 'credentials'
        
        @($script:TestProjectRoot, $script:TestModulesDir, $script:TestSharedDir,
          $script:TestConfigsDir, $script:TestLogsDir, $script:TestDocsDir,
          $script:TestUserConfigDir, $script:TestAppDataDir, $script:TestCredentialsDir) | ForEach-Object {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
        
        # Set test environment variables
        $env:PROJECT_ROOT = $script:TestProjectRoot
        $env:USERPROFILE = $script:TestWorkspace
        $env:HOME = $script:TestWorkspace
        $env:APPDATA = Join-Path $script:TestWorkspace 'AppData' 'Roaming'
        $env:PWSH_MODULES_PATH = $script:TestModulesDir
        $env:EDITOR = 'nano'
        
        # Create Find-ProjectRoot utility
        $findProjectRootContent = @"
function Find-ProjectRoot {
    param([string]`$StartPath, [switch]`$Force)
    return '$script:TestProjectRoot'
}
"@
        $findProjectRootPath = Join-Path $script:TestSharedDir 'Find-ProjectRoot.ps1'
        $findProjectRootContent | Out-File -FilePath $findProjectRootPath -Encoding UTF8
        
        # Copy SetupWizard module to test environment
        $testSetupWizardModulePath = Join-Path $script:TestModulesDir 'SetupWizard'
        Copy-Item -Path "$script:SetupWizardModulePath\*" -Destination $testSetupWizardModulePath -Recurse -Force
        
        # Create mock core modules for dependency testing
        $coreModules = @('Logging', 'PatchManager', 'OpenTofuProvider', 'LabRunner', 'BackupManager', 'ProgressTracking', 'AIToolsIntegration')
        foreach ($module in $coreModules) {
            $modulePath = Join-Path $script:TestModulesDir $module
            New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
            
            # Create mock module manifest
            @"
@{
    ModuleVersion = '1.0.0'
    RootModule = '$module.psm1'
    FunctionsToExport = @('Test-$module')
}
"@ | Out-File -FilePath (Join-Path $modulePath "$module.psd1") -Encoding UTF8
            
            # Create mock module script
            @"
function Test-$module {
    Write-Host "$module module function called"
}
Export-ModuleMember -Function Test-$module
"@ | Out-File -FilePath (Join-Path $modulePath "$module.psm1") -Encoding UTF8
        }
        
        # Create mock ProgressTracking module
        @'
function Start-ProgressOperation { param($OperationName, $TotalSteps, [switch]$ShowTime, [switch]$ShowETA, $Style); return "test-progress-id-$([Guid]::NewGuid())" }
function Update-ProgressOperation { param($OperationId, $CurrentStep, $StepName) }
function Complete-ProgressOperation { param($OperationId, [switch]$ShowSummary) }
Export-ModuleMember -Function *
'@ | Out-File -FilePath (Join-Path $script:TestModulesDir 'ProgressTracking' 'ProgressTracking.psm1') -Encoding UTF8
        
        # Create mock AIToolsIntegration module
        @'
function Install-ClaudeCode {
    return @{
        Success = $true
        Message = "Claude Code installed successfully"
        Version = "1.0.0"
    }
}
function Install-GeminiCLI {
    return @{
        Success = $true
        Message = "Gemini CLI installed successfully"
        ManualSteps = $false
    }
}
function Get-AIToolsStatus {
    return @{
        ClaudeCode = @{ Installed = $true; Version = "1.0.0" }
        GeminiCLI = @{ Installed = $true; Version = "1.0.0" }
    }
}
Export-ModuleMember -Function *
'@ | Out-File -FilePath (Join-Path $script:TestModulesDir 'AIToolsIntegration' 'AIToolsIntegration.psm1') -Encoding UTF8
        
        # Mock external commands for testing
        Mock git { 
            param($Command)
            if ($Command -eq '--version') {
                return 'git version 2.40.0'
            }
            if ($Command -eq 'config' -and $args[0] -eq '--global' -and $args[1] -eq 'user.name') {
                return 'Test User'
            }
            if ($Command -eq 'config' -and $args[0] -eq '--global' -and $args[1] -eq 'user.email') {
                return 'test@example.com'
            }
            return ''
        } -ModuleName $script:TestAppName
        
        Mock tofu { 
            if ($args[0] -eq 'version') {
                return 'OpenTofu v1.6.0'
            }
            return ''
        } -ModuleName $script:TestAppName
        
        Mock terraform { 
            if ($args[0] -eq 'version') {
                return 'Terraform v1.7.0'
            }
            return ''
        } -ModuleName $script:TestAppName
        
        Mock node { 
            if ($args[0] -eq '--version') {
                return 'v20.10.0'
            }
            return ''
        } -ModuleName $script:TestAppName
        
        Mock npm { 
            if ($args[0] -eq '--version') {
                return '10.2.3'
            }
            return ''
        } -ModuleName $script:TestAppName
        
        Mock docker { return 'Docker version 24.0.0' } -ModuleName $script:TestAppName
        Mock az { return 'azure-cli 2.55.0' } -ModuleName $script:TestAppName
        Mock aws { return 'aws-cli/2.15.0' } -ModuleName $script:TestAppName
        Mock gcloud { return 'Google Cloud SDK 458.0.0' } -ModuleName $script:TestAppName
        Mock kubectl { return 'Client Version: v1.29.0' } -ModuleName $script:TestAppName
        Mock helm { return 'version.BuildInfo{Version:"v3.13.0"}' } -ModuleName $script:TestAppName
        Mock brew { return 'Homebrew 4.1.0' } -ModuleName $script:TestAppName
        
        # Mock network connectivity
        Mock Invoke-WebRequest { 
            param($Uri, $UseBasicParsing, $TimeoutSec)
            return @{ StatusCode = 200 }
        } -ModuleName $script:TestAppName
        
        # Mock Windows-specific commands
        if ($IsWindows) {
            Mock Get-MpPreference { 
                return @{
                    ExclusionPath = @('C:\TestPath')
                }
            } -ModuleName $script:TestAppName
            
            Mock Start-Process { } -ModuleName $script:TestAppName
        }
        
        # Mock Linux/macOS-specific commands
        if ($IsLinux) {
            Mock getenforce { return 'Disabled' } -ModuleName $script:TestAppName
            Mock aa-status { return 'apparmor module is loaded' } -ModuleName $script:TestAppName
        }
        
        if ($IsMacOS) {
            Mock spctl { return 'assessments enabled' } -ModuleName $script:TestAppName
            Mock sw_vers { return '14.0' } -ModuleName $script:TestAppName
        }
        
        # Mock Get-Module for availability checks
        Mock Get-Module { 
            param($Name, [switch]$ListAvailable)
            
            if ($ListAvailable) {
                $availableModules = @('ProgressTracking', 'AIToolsIntegration', 'Pester', 'PSScriptAnalyzer', 'platyPS')
                if ($Name -in $availableModules) {
                    return @{ Name = $Name; Version = '1.0.0' }
                }
            }
            return $null
        } -ModuleName $script:TestAppName
        
        # Mock Import-Module
        Mock Import-Module { } -ModuleName $script:TestAppName
        
        # Mock interactive prompts for automated testing
        Mock Read-Host { 
            param($Prompt)
            
            # Simulate user inputs for different prompts
            if ($Prompt -like "*choice*" -or $Prompt -like "*Enter your choice*") {
                return '1'  # Default to first option
            }
            if ($Prompt -like "*environment*") {
                return 'development'
            }
            if ($Prompt -like "*log*level*") {
                return '2'  # INFO level
            }
            if ($Prompt -like "*provider*") {
                return '1'  # OpenTofu
            }
            if ($Prompt -like "*backend*") {
                return '1'  # Local
            }
            return 'test-input'
        } -ModuleName $script:TestAppName
        
        # Mock Host.UI.PromptForChoice
        Mock -CommandName 'Show-SetupPrompt' -MockWith { 
            param($Message, [switch]$DefaultYes)
            return $DefaultYes.IsPresent
        } -ModuleName $script:TestAppName
        
        # Mock Clear-Host
        Mock Clear-Host { } -ModuleName $script:TestAppName
        
        # Mock Start-Sleep
        Mock Start-Sleep { } -ModuleName $script:TestAppName
        
        # Import SetupWizard module from test location
        Import-Module $testSetupWizardModulePath -Force -Global
        
        # Create test configuration files for testing
        $defaultConfigPath = Join-Path $script:TestConfigsDir 'default-config.json'
        @{
            environment = 'development'
            modules = @{
                enabled = @('Logging', 'PatchManager', 'LabRunner')
                autoLoad = $true
            }
            logging = @{
                level = 'INFO'
                path = './logs'
            }
            infrastructure = @{
                provider = 'opentofu'
                stateBackend = 'local'
            }
        } | ConvertTo-Json -Depth 10 | Out-File -FilePath $defaultConfigPath -Encoding UTF8
        
        # Create existing config for edit testing
        $existingConfigPath = Join-Path $script:TestConfigsDir 'existing-config.json'
        @{
            environment = 'production'
            modules = @{
                enabled = @('LabRunner', 'BackupManager')
                autoLoad = $false
            }
            logging = @{
                level = 'ERROR'
                path = '/var/log/aitherzero'
            }
            infrastructure = @{
                provider = 'terraform'
                stateBackend = 's3'
            }
            custom = @{
                feature = @{
                    enabled = $true
                }
            }
        } | ConvertTo-Json -Depth 10 | Out-File -FilePath $existingConfigPath -Encoding UTF8
    }
    
    AfterAll {
        # Restore original environment
        $env:PROJECT_ROOT = $script:OriginalProjectRoot
        $env:USERPROFILE = $script:OriginalUserProfile
        $env:HOME = $script:OriginalHome
        $env:APPDATA = $script:OriginalAppData
        $env:PWSH_MODULES_PATH = $script:OriginalPwshModulesPath
        $env:EDITOR = $script:OriginalEditor
        $env:HTTP_PROXY = $script:OriginalHttpProxy
        $env:HTTPS_PROXY = $script:OriginalHttpsProxy
        
        # Remove imported modules
        Remove-Module SetupWizard -Force -ErrorAction SilentlyContinue
        Remove-Module ProgressTracking -Force -ErrorAction SilentlyContinue
        Remove-Module AIToolsIntegration -Force -ErrorAction SilentlyContinue
        
        # Clean up test workspace
        if ($script:TestWorkspace -and (Test-Path $script:TestWorkspace)) {
            Remove-Item -Path $script:TestWorkspace -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    BeforeEach {
        # Clear any existing setup state
        Get-ChildItem $script:TestUserConfigDir -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Get-ChildItem $script:TestAppDataDir -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Platform Detection and Requirements' {
        
        It 'Should detect platform information correctly' {
            { $platformInfo = Get-PlatformInfo } | Should -Not -Throw
            
            $platformInfo = Get-PlatformInfo
            $platformInfo | Should -Not -BeNullOrEmpty
            $platformInfo.OS | Should -BeIn @('Windows', 'Linux', 'macOS', 'Unknown')
            $platformInfo.Architecture | Should -Not -BeNullOrEmpty
            $platformInfo.PowerShell | Should -Not -BeNullOrEmpty
        }
        
        It 'Should validate platform requirements' {
            $setupState = @{
                Platform = Get-PlatformInfo
                Warnings = @()
                Recommendations = @()
            }
            
            { $result = Test-PlatformRequirements -SetupState $setupState } | Should -Not -Throw
            
            $result = Test-PlatformRequirements -SetupState $setupState
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'Platform Detection'
            $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
            $result.Details | Should -Not -BeNullOrEmpty
            $result.Data | Should -Not -BeNullOrEmpty
        }
        
        It 'Should validate PowerShell version requirements' {
            $setupState = @{
                Platform = Get-PlatformInfo
                Recommendations = @()
            }
            
            { $result = Test-PowerShellVersion -SetupState $setupState } | Should -Not -Throw
            
            $result = Test-PowerShellVersion -SetupState $setupState
            $result.Name | Should -Be 'PowerShell Version'
            $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
            $result.Details | Should -Not -BeNullOrEmpty
            
            # Should pass for PowerShell 7+ or warn for 5.1
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                $result.Status | Should -Be 'Passed'
            } elseif ($PSVersionTable.PSVersion.Major -eq 5) {
                $result.Status | Should -Be 'Warning'
            }
        }
        
        It 'Should check Git installation and configuration' {
            $setupState = @{
                Platform = Get-PlatformInfo
                Recommendations = @()
            }
            
            { $result = Test-GitInstallation -SetupState $setupState } | Should -Not -Throw
            
            $result = Test-GitInstallation -SetupState $setupState
            $result.Name | Should -Be 'Git Installation'
            $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
            $result.Details | Should -Not -BeNullOrEmpty
        }
        
        It 'Should check infrastructure tools availability' {
            $setupState = @{
                Platform = Get-PlatformInfo
                Recommendations = @()
            }
            
            { $result = Test-InfrastructureTools -SetupState $setupState } | Should -Not -Throw
            
            $result = Test-InfrastructureTools -SetupState $setupState
            $result.Name | Should -Be 'Infrastructure Tools'
            $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
            $result.Details | Should -Not -BeNullOrEmpty
        }
        
        It 'Should validate module dependencies' {
            $setupState = @{
                Platform = Get-PlatformInfo
            }
            
            { $result = Test-ModuleDependencies -SetupState $setupState } | Should -Not -Throw
            
            $result = Test-ModuleDependencies -SetupState $setupState
            $result.Name | Should -Be 'Module Dependencies'
            $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
            $result.Details | Should -Not -BeNullOrEmpty
            
            # Should find the mock modules we created
            $result.Status | Should -Be 'Passed'
        }
        
        It 'Should test network connectivity' {
            $setupState = @{
                Platform = Get-PlatformInfo
            }
            
            { $result = Test-NetworkConnectivity -SetupState $setupState } | Should -Not -Throw
            
            $result = Test-NetworkConnectivity -SetupState $setupState
            $result.Name | Should -Be 'Network Connectivity'
            $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
            $result.Details | Should -Not -BeNullOrEmpty
        }
        
        It 'Should validate security settings' {
            $setupState = @{
                Platform = Get-PlatformInfo
            }
            
            { $result = Test-SecuritySettings -SetupState $setupState } | Should -Not -Throw
            
            $result = Test-SecuritySettings -SetupState $setupState
            $result.Name | Should -Be 'Security Settings'
            $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
            $result.Details | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Installation Profile Management' {
        
        It 'Should provide interactive profile selection' {
            # Mock Read-Host to return profile choice
            Mock Read-Host { return '2' } -ModuleName $script:TestAppName
            
            { $profile = Get-InstallationProfile } | Should -Not -Throw
            
            $profile = Get-InstallationProfile
            $profile | Should -BeIn @('minimal', 'developer', 'full')
        }
        
        It 'Should display installation profile information' {
            $profiles = @('minimal', 'developer', 'full')
            
            foreach ($profile in $profiles) {
                { Show-InstallationProfile -Profile $profile } | Should -Not -Throw
            }
        }
        
        It 'Should generate setup steps for minimal profile' {
            { $steps = Get-SetupSteps -Profile 'minimal' } | Should -Not -Throw
            
            $steps = Get-SetupSteps -Profile 'minimal'
            $steps | Should -Not -BeNullOrEmpty
            $steps.Count | Should -BeGreaterThan 5
            
            # Minimal profile should not include AI tools or cloud CLIs
            $stepNames = $steps | ForEach-Object { $_.Function }
            $stepNames | Should -Not -Contain 'Install-AITools'
            $stepNames | Should -Not -Contain 'Test-CloudCLIs'
            $stepNames | Should -Not -Contain 'Test-NodeJsInstallation'
        }
        
        It 'Should generate setup steps for developer profile' {
            { $steps = Get-SetupSteps -Profile 'developer' } | Should -Not -Throw
            
            $steps = Get-SetupSteps -Profile 'developer'
            $steps | Should -Not -BeNullOrEmpty
            $steps.Count | Should -BeGreaterThan 6
            
            # Developer profile should include Node.js and AI tools
            $stepNames = $steps | ForEach-Object { $_.Function }
            $stepNames | Should -Contain 'Test-NodeJsInstallation'
            $stepNames | Should -Contain 'Install-AITools'
            $stepNames | Should -Not -Contain 'Test-CloudCLIs'
        }
        
        It 'Should generate setup steps for full profile' {
            { $steps = Get-SetupSteps -Profile 'full' } | Should -Not -Throw
            
            $steps = Get-SetupSteps -Profile 'full'
            $steps | Should -Not -BeNullOrEmpty
            $steps.Count | Should -BeGreaterThan 7
            
            # Full profile should include everything
            $stepNames = $steps | ForEach-Object { $_.Function }
            $stepNames | Should -Contain 'Test-NodeJsInstallation'
            $stepNames | Should -Contain 'Install-AITools'
            $stepNames | Should -Contain 'Test-CloudCLIs'
        }
    }
    
    Context 'Intelligent Setup Workflow' {
        
        It 'Should execute minimal setup profile successfully' {
            # Mock interactive choices
            Mock Get-InstallationProfile { return 'minimal' } -ModuleName $script:TestAppName
            
            { $result = Start-IntelligentSetup -InstallationProfile 'minimal' } | Should -Not -Throw
            
            $result = Start-IntelligentSetup -InstallationProfile 'minimal'
            $result | Should -Not -BeNullOrEmpty
            $result.InstallationProfile | Should -Be 'minimal'
            $result.Steps | Should -Not -BeNullOrEmpty
            $result.Steps.Count | Should -BeGreaterThan 5
            $result.StartTime | Should -Not -BeNullOrEmpty
        }
        
        It 'Should execute developer setup profile successfully' {
            { $result = Start-IntelligentSetup -InstallationProfile 'developer' } | Should -Not -Throw
            
            $result = Start-IntelligentSetup -InstallationProfile 'developer'
            $result.InstallationProfile | Should -Be 'developer'
            $result.Steps | Should -Not -BeNullOrEmpty
            $result.AIToolsToInstall | Should -Not -BeNullOrEmpty
        }
        
        It 'Should execute full setup profile successfully' {
            { $result = Start-IntelligentSetup -InstallationProfile 'full' } | Should -Not -Throw
            
            $result = Start-IntelligentSetup -InstallationProfile 'full'
            $result.InstallationProfile | Should -Be 'full'
            $result.Steps | Should -Not -BeNullOrEmpty
            $result.Steps.Count | Should -BeGreaterThan 7
        }
        
        It 'Should handle interactive profile selection' {
            Mock Get-InstallationProfile { return 'developer' } -ModuleName $script:TestAppName
            
            { $result = Start-IntelligentSetup -InstallationProfile 'interactive' } | Should -Not -Throw
            
            $result = Start-IntelligentSetup -InstallationProfile 'interactive'
            $result.InstallationProfile | Should -Be 'developer'
        }
        
        It 'Should support minimal setup flag' {
            { $result = Start-IntelligentSetup -MinimalSetup } | Should -Not -Throw
            
            $result = Start-IntelligentSetup -MinimalSetup
            $result.InstallationProfile | Should -Be 'minimal'
        }
        
        It 'Should skip optional steps when requested' {
            { $result = Start-IntelligentSetup -InstallationProfile 'minimal' -SkipOptional } | Should -Not -Throw
            
            $result = Start-IntelligentSetup -InstallationProfile 'minimal' -SkipOptional
            $result.Steps | Should -Not -BeNullOrEmpty
        }
        
        It 'Should handle setup step failures gracefully' {
            # Mock a failing step
            Mock Test-NetworkConnectivity { throw "Network test failure" } -ModuleName $script:TestAppName
            Mock Show-SetupPrompt { return $false } -ModuleName $script:TestAppName  # User chooses not to continue
            
            { $result = Start-IntelligentSetup -InstallationProfile 'minimal' } | Should -Not -Throw
            
            $result = Start-IntelligentSetup -InstallationProfile 'minimal'
            $result.Errors | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'AI Tools Integration' {
        
        It 'Should test Node.js installation for developer profile' {
            $setupState = @{
                Platform = Get-PlatformInfo
                Recommendations = @()
            }
            
            { $result = Test-NodeJsInstallation -SetupState $setupState } | Should -Not -Throw
            
            $result = Test-NodeJsInstallation -SetupState $setupState
            $result.Name | Should -Be 'Node.js Detection'
            $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
            $result.Details | Should -Not -BeNullOrEmpty
        }
        
        It 'Should install AI tools for developer profile' {
            $setupState = @{
                Platform = Get-PlatformInfo
                InstallationProfile = 'developer'
                Recommendations = @()
            }
            
            { $result = Install-AITools -SetupState $setupState } | Should -Not -Throw
            
            $result = Install-AITools -SetupState $setupState
            $result.Name | Should -Be 'AI Tools Setup'
            $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
            $result.Details | Should -Not -BeNullOrEmpty
        }
        
        It 'Should install AI tools for full profile' {
            $setupState = @{
                Platform = Get-PlatformInfo
                InstallationProfile = 'full'
                Recommendations = @()
            }
            
            { $result = Install-AITools -SetupState $setupState } | Should -Not -Throw
            
            $result = Install-AITools -SetupState $setupState
            $result.Name | Should -Be 'AI Tools Setup'
            $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
            # Full profile should install both Claude Code and Gemini CLI
        }
        
        It 'Should skip AI tools for minimal profile' {
            $setupState = @{
                Platform = Get-PlatformInfo
                InstallationProfile = 'minimal'
                Recommendations = @()
            }
            
            { $result = Install-AITools -SetupState $setupState } | Should -Not -Throw
            
            $result = Install-AITools -SetupState $setupState
            $result.Status | Should -Be 'Passed'
            $result.Details | Should -Contain "*No AI tools installation required*"
        }
        
        It 'Should test cloud CLIs for full profile' {
            $setupState = @{
                Platform = Get-PlatformInfo
                Recommendations = @()
            }
            
            { $result = Test-CloudCLIs -SetupState $setupState } | Should -Not -Throw
            
            $result = Test-CloudCLIs -SetupState $setupState
            $result.Name | Should -Be 'Cloud CLIs Detection'
            $result.Status | Should -BeIn @('Passed', 'Warning', 'Failed')
            $result.Details | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Configuration Management' {
        
        It 'Should initialize configuration files' {
            $setupState = @{
                Platform = Get-PlatformInfo
            }
            
            { $result = Initialize-Configuration -SetupState $setupState } | Should -Not -Throw
            
            $result = Initialize-Configuration -SetupState $setupState
            $result.Name | Should -Be 'Configuration Files'
            $result.Status | Should -Be 'Passed'
            $result.Details | Should -Not -BeNullOrEmpty
            
            # Verify configuration directory was created
            $configDir = if ($IsWindows) {
                Join-Path $env:APPDATA "AitherZero"
            } else {
                Join-Path $env:HOME ".config/aitherzero"
            }
            Test-Path $configDir | Should -Be $true
        }
        
        It 'Should create default configuration with proper structure' {
            $setupState = @{
                Platform = Get-PlatformInfo
            }
            
            $result = Initialize-Configuration -SetupState $setupState
            $result.Status | Should -Be 'Passed'
            
            # Check that config file was created
            $configDir = if ($IsWindows) {
                Join-Path $env:APPDATA "AitherZero"
            } else {
                Join-Path $env:HOME ".config/aitherzero"
            }
            $configFile = Join-Path $configDir "config.json"
            Test-Path $configFile | Should -Be $true
            
            # Verify config structure
            $config = Get-Content $configFile -Raw | ConvertFrom-Json
            $config.Version | Should -Not -BeNullOrEmpty
            $config.Platform | Should -Not -BeNullOrEmpty
            $config.Settings | Should -Not -BeNullOrEmpty
            $config.Modules | Should -Not -BeNullOrEmpty
        }
        
        It 'Should edit existing configuration interactively' {
            $existingConfigPath = Join-Path $script:TestConfigsDir 'existing-config.json'
            
            # Mock user choices for configuration editing
            Mock Read-Host { 
                param($Prompt)
                if ($Prompt -like "*Select option*") {
                    return 'Q'  # Quit without saving
                }
                return ''
            } -ModuleName $script:TestAppName
            
            { Edit-Configuration -ConfigPath $existingConfigPath } | Should -Not -Throw
        }
        
        It 'Should create configuration if missing when requested' {
            $newConfigPath = Join-Path $script:TestConfigsDir 'new-config.json'
            Remove-Item $newConfigPath -Force -ErrorAction SilentlyContinue
            
            { Edit-Configuration -ConfigPath $newConfigPath -CreateIfMissing } | Should -Not -Throw
            
            Test-Path $newConfigPath | Should -Be $true
        }
        
        It 'Should review configuration during setup' {
            $setupState = @{
                Platform = Get-PlatformInfo
                Warnings = @()
                Recommendations = @()
            }
            
            # Mock the setup prompt to skip editing
            Mock Show-SetupPrompt { return $false } -ModuleName $script:TestAppName
            
            { $result = Review-Configuration -SetupState $setupState } | Should -Not -Throw
            
            $result = Review-Configuration -SetupState $setupState
            $result.Name | Should -Be 'Configuration Review'
            $result.Status | Should -Be 'Success'
            $result.Details | Should -Not -BeNullOrEmpty
        }
        
        It 'Should handle missing configuration during review' {
            $setupState = @{
                Platform = Get-PlatformInfo
                Warnings = @()
                Recommendations = @()
            }
            
            # Remove default config
            $defaultConfig = Join-Path $script:TestConfigsDir 'default-config.json'
            Remove-Item $defaultConfig -Force -ErrorAction SilentlyContinue
            
            # Mock the setup prompt to skip creation
            Mock Show-SetupPrompt { return $false } -ModuleName $script:TestAppName
            
            { $result = Review-Configuration -SetupState $setupState } | Should -Not -Throw
            
            $result = Review-Configuration -SetupState $setupState
            $result.Status | Should -Be 'Success'
        }
    }
    
    Context 'Quick Start Guide Generation' {
        
        It 'Should generate platform-specific quick start guide' {
            $setupState = @{
                Platform = Get-PlatformInfo
                Steps = @(
                    @{ Name = 'Platform Detection'; Status = 'Passed' },
                    @{ Name = 'PowerShell Version'; Status = 'Passed' },
                    @{ Name = 'Git Installation'; Status = 'Warning' }
                )
                Warnings = @('Git configuration incomplete')
                Recommendations = @('Configure Git user information')
            }
            
            { $result = Generate-QuickStartGuide -SetupState $setupState } | Should -Not -Throw
            
            $result = Generate-QuickStartGuide -SetupState $setupState
            $result.Name | Should -Be 'Quick Start Guide'
            $result.Status | Should -BeIn @('Passed', 'Warning')
            $result.Details | Should -Not -BeNullOrEmpty
            
            # Verify guide file was created
            $guideFiles = Get-ChildItem -Path $script:TestProjectRoot -Filter "QuickStart-*.md"
            $guideFiles | Should -Not -BeNullOrEmpty
        }
        
        It 'Should include platform-specific content in quick start guide' {
            $setupState = @{
                Platform = @{
                    OS = 'Windows'
                    Version = '10.0.19045'
                }
                Steps = @()
                Warnings = @()
                Recommendations = @()
            }
            
            $result = Generate-QuickStartGuide -SetupState $setupState
            $result.Status | Should -BeIn @('Passed', 'Warning')
            
            # Find the generated guide
            $guideFile = Get-ChildItem -Path $script:TestProjectRoot -Filter "QuickStart-Windows-*.md" | Select-Object -First 1
            $guideFile | Should -Not -BeNullOrEmpty
            
            $guideContent = Get-Content $guideFile.FullName -Raw
            $guideContent | Should -Contain 'Windows'
            $guideContent | Should -Contain 'Start-AitherZero.ps1'
            $guideContent | Should -Contain 'Getting Started'
        }
    }
    
    Context 'Setup Completion and Validation' {
        
        It 'Should perform final validation with all successful steps' {
            $setupState = @{
                Steps = @(
                    @{ Name = 'Step 1'; Status = 'Passed' },
                    @{ Name = 'Step 2'; Status = 'Passed' },
                    @{ Name = 'Step 3'; Status = 'Passed' }
                )
                StartTime = (Get-Date).AddMinutes(-5)
            }
            
            { $result = Test-SetupCompletion -SetupState $setupState } | Should -Not -Throw
            
            $result = Test-SetupCompletion -SetupState $setupState
            $result.Name | Should -Be 'Final Validation'
            $result.Status | Should -Be 'Passed'
            $result.Details | Should -Contain '*Setup completed successfully*'
        }
        
        It 'Should handle setup with warnings appropriately' {
            $setupState = @{
                Steps = @(
                    @{ Name = 'Step 1'; Status = 'Passed' },
                    @{ Name = 'Step 2'; Status = 'Warning' },
                    @{ Name = 'Step 3'; Status = 'Passed' }
                )
                StartTime = (Get-Date).AddMinutes(-5)
            }
            
            $result = Test-SetupCompletion -SetupState $setupState
            $result.Status | Should -Be 'Warning'
            $result.Details | Should -Contain '*Setup completed with minor issues*'
        }
        
        It 'Should handle setup with multiple failures' {
            $setupState = @{
                Steps = @(
                    @{ Name = 'Step 1'; Status = 'Failed' },
                    @{ Name = 'Step 2'; Status = 'Failed' },
                    @{ Name = 'Step 3'; Status = 'Failed' }
                )
                StartTime = (Get-Date).AddMinutes(-5)
            }
            
            $result = Test-SetupCompletion -SetupState $setupState
            $result.Status | Should -Be 'Failed'
            $result.Details | Should -Contain '*Setup encountered significant issues*'
        }
        
        It 'Should display comprehensive setup summary' {
            $setupState = @{
                Platform = Get-PlatformInfo
                Steps = @(
                    @{ Name = 'Platform Detection'; Status = 'Passed' },
                    @{ Name = 'PowerShell Version'; Status = 'Passed' },
                    @{ Name = 'Git Installation'; Status = 'Warning' }
                )
                Recommendations = @('Install latest Git version', 'Configure Git credentials')
            }
            
            { Show-SetupSummary -State $setupState } | Should -Not -Throw
        }
    }
    
    Context 'Cross-Platform Compatibility' {
        
        It 'Should handle Windows-specific platform detection' {
            if ($IsWindows) {
                $platformInfo = Get-PlatformInfo
                $platformInfo.OS | Should -Be 'Windows'
                $platformInfo.Version | Should -Not -BeNullOrEmpty
            } else {
                # Skip test on non-Windows platforms
                Set-ItResult -Skipped -Because "Windows-specific test"
            }
        }
        
        It 'Should handle Linux-specific platform detection' {
            if ($IsLinux) {
                $platformInfo = Get-PlatformInfo
                $platformInfo.OS | Should -Be 'Linux'
            } else {
                # Mock Linux environment for testing
                $originalOS = @($IsWindows, $IsLinux, $IsMacOS)
                
                try {
                    # Temporarily mock platform variables
                    Set-Variable -Name 'IsWindows' -Value $false -Scope Global
                    Set-Variable -Name 'IsLinux' -Value $true -Scope Global
                    Set-Variable -Name 'IsMacOS' -Value $false -Scope Global
                    
                    $platformInfo = Get-PlatformInfo
                    $platformInfo.OS | Should -Be 'Linux'
                } finally {
                    # Restore original values
                    Set-Variable -Name 'IsWindows' -Value $originalOS[0] -Scope Global
                    Set-Variable -Name 'IsLinux' -Value $originalOS[1] -Scope Global
                    Set-Variable -Name 'IsMacOS' -Value $originalOS[2] -Scope Global
                }
            }
        }
        
        It 'Should handle macOS-specific platform detection' {
            if ($IsMacOS) {
                $platformInfo = Get-PlatformInfo
                $platformInfo.OS | Should -Be 'macOS'
            } else {
                # Mock macOS environment for testing
                $originalOS = @($IsWindows, $IsLinux, $IsMacOS)
                
                try {
                    Set-Variable -Name 'IsWindows' -Value $false -Scope Global
                    Set-Variable -Name 'IsLinux' -Value $false -Scope Global
                    Set-Variable -Name 'IsMacOS' -Value $true -Scope Global
                    
                    $platformInfo = Get-PlatformInfo
                    $platformInfo.OS | Should -Be 'macOS'
                } finally {
                    Set-Variable -Name 'IsWindows' -Value $originalOS[0] -Scope Global
                    Set-Variable -Name 'IsLinux' -Value $originalOS[1] -Scope Global
                    Set-Variable -Name 'IsMacOS' -Value $originalOS[2] -Scope Global
                }
            }
        }
        
        It 'Should use appropriate configuration paths per platform' {
            $setupState = @{
                Platform = Get-PlatformInfo
            }
            
            $result = Initialize-Configuration -SetupState $setupState
            $result.Status | Should -Be 'Passed'
            
            # Verify platform-appropriate path was used
            if ($IsWindows) {
                $result.Details | Should -Contain "*$env:APPDATA*"
            } else {
                $result.Details | Should -Contain "*/.config/aitherzero*"
            }
        }
    }
    
    Context 'Error Handling and Edge Cases' {
        
        It 'Should handle missing external commands gracefully' {
            # Mock all external commands to fail
            Mock git { throw "Command not found" } -ModuleName $script:TestAppName
            Mock tofu { throw "Command not found" } -ModuleName $script:TestAppName
            Mock node { throw "Command not found" } -ModuleName $script:TestAppName
            
            $setupState = @{
                Platform = Get-PlatformInfo
                Recommendations = @()
            }
            
            { $result = Test-GitInstallation -SetupState $setupState } | Should -Not -Throw
            { $result = Test-InfrastructureTools -SetupState $setupState } | Should -Not -Throw
            { $result = Test-NodeJsInstallation -SetupState $setupState } | Should -Not -Throw
        }
        
        It 'Should handle network connectivity failures' {
            # Mock network failures
            Mock Invoke-WebRequest { throw "Network error" } -ModuleName $script:TestAppName
            
            $setupState = @{
                Platform = Get-PlatformInfo
            }
            
            { $result = Test-NetworkConnectivity -SetupState $setupState } | Should -Not -Throw
            
            $result = Test-NetworkConnectivity -SetupState $setupState
            $result.Status | Should -Be 'Failed'
        }
        
        It 'Should handle missing AIToolsIntegration module' {
            # Mock missing module
            Mock Test-Path { return $false } -ParameterFilter { $Path -like "*AIToolsIntegration*" } -ModuleName $script:TestAppName
            
            $setupState = @{
                Platform = Get-PlatformInfo
                InstallationProfile = 'developer'
                Recommendations = @()
            }
            
            { $result = Install-AITools -SetupState $setupState } | Should -Not -Throw
            
            $result = Install-AITools -SetupState $setupState
            $result.Status | Should -Be 'Warning'
        }
        
        It 'Should handle configuration file corruption' {
            $corruptedConfigPath = Join-Path $script:TestConfigsDir 'corrupted-config.json'
            "This is not valid JSON {]}" | Out-File -FilePath $corruptedConfigPath -Encoding UTF8
            
            { Edit-Configuration -ConfigPath $corruptedConfigPath } | Should -Not -Throw
        }
        
        It 'Should handle permission issues during configuration creation' {
            # Mock permission denied
            Mock New-Item { throw "Access denied" } -ParameterFilter { $ItemType -eq 'Directory' } -ModuleName $script:TestAppName
            
            $setupState = @{
                Platform = Get-PlatformInfo
            }
            
            { $result = Initialize-Configuration -SetupState $setupState } | Should -Not -Throw
            
            $result = Initialize-Configuration -SetupState $setupState
            $result.Status | Should -Be 'Failed'
        }
    }
    
    Context 'Performance and Resource Management' {
        
        It 'Should complete minimal setup within reasonable time' {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $result = Start-IntelligentSetup -InstallationProfile 'minimal'
            $stopwatch.Stop()
            
            $result.InstallationProfile | Should -Be 'minimal'
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 30000  # Less than 30 seconds
        }
        
        It 'Should handle multiple concurrent setup operations' {
            # Test that setup doesn't interfere with itself when run concurrently
            $jobs = @()
            for ($i = 1; $i -le 3; $i++) {
                $jobs += Start-Job -ScriptBlock {
                    param($ModulePath, $TestWorkspace)
                    
                    # Create unique workspace for each job
                    $jobWorkspace = Join-Path $TestWorkspace "job-$using:i"
                    New-Item -ItemType Directory -Path $jobWorkspace -Force | Out-Null
                    
                    $env:PROJECT_ROOT = Join-Path $jobWorkspace 'AitherZero'
                    $env:USERPROFILE = $jobWorkspace
                    $env:HOME = $jobWorkspace
                    
                    Import-Module $ModulePath -Force
                    
                    # Run setup with different profiles
                    $profiles = @('minimal', 'developer', 'full')
                    $profile = $profiles[($using:i - 1) % 3]
                    
                    Start-IntelligentSetup -InstallationProfile $profile
                } -ArgumentList $testSetupWizardModulePath, $script:TestWorkspace
            }
            
            $results = $jobs | Wait-Job | Receive-Job
            $jobs | Remove-Job
            
            $results.Count | Should -Be 3
            $results | ForEach-Object { $_.InstallationProfile | Should -BeIn @('minimal', 'developer', 'full') }
        }
        
        It 'Should manage memory efficiently during setup' {
            # Get initial memory usage
            $initialMemory = [GC]::GetTotalMemory($false)
            
            # Run full setup
            $result = Start-IntelligentSetup -InstallationProfile 'full'
            
            # Force garbage collection
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            [GC]::Collect()
            
            $finalMemory = [GC]::GetTotalMemory($false)
            $memoryIncrease = $finalMemory - $initialMemory
            
            $result.InstallationProfile | Should -Be 'full'
            $memoryIncrease | Should -BeLessThan 50MB  # Memory increase should be reasonable
        }
    }
    
    Context 'Integration Testing' {
        
        It 'Should integrate with ProgressTracking module when available' {
            # ProgressTracking is mocked to be available
            $result = Start-IntelligentSetup -InstallationProfile 'minimal'
            $result.Steps | Should -Not -BeNullOrEmpty
        }
        
        It 'Should work without ProgressTracking module' {
            # Mock ProgressTracking as unavailable
            Mock Get-Module { return $null } -ParameterFilter { $Name -eq 'ProgressTracking' -and $ListAvailable } -ModuleName $script:TestAppName
            
            { $result = Start-IntelligentSetup -InstallationProfile 'minimal' } | Should -Not -Throw
            
            $result = Start-IntelligentSetup -InstallationProfile 'minimal'
            $result.Steps | Should -Not -BeNullOrEmpty
        }
        
        It 'Should integrate with Find-ProjectRoot utility' {
            # Function should use Find-ProjectRoot for path resolution
            $platformInfo = Get-PlatformInfo
            $platformInfo | Should -Not -BeNullOrEmpty
            
            # Test configuration initialization which uses Find-ProjectRoot
            $setupState = @{ Platform = $platformInfo }
            $result = Initialize-Configuration -SetupState $setupState
            $result.Status | Should -Be 'Passed'
        }
        
        It 'Should validate end-to-end setup workflow' {
            # Full end-to-end test with all components
            { $result = Start-IntelligentSetup -InstallationProfile 'developer' } | Should -Not -Throw
            
            $result = Start-IntelligentSetup -InstallationProfile 'developer'
            
            # Verify all expected components
            $result.InstallationProfile | Should -Be 'developer'
            $result.Platform | Should -Not -BeNullOrEmpty
            $result.Steps | Should -Not -BeNullOrEmpty
            $result.StartTime | Should -Not -BeNullOrEmpty
            
            # Verify configuration was created
            $configDir = if ($IsWindows) {
                Join-Path $env:APPDATA "AitherZero"
            } else {
                Join-Path $env:HOME ".config/aitherzero"
            }
            Test-Path $configDir | Should -Be $true
            
            # Verify setup state was saved
            $setupStateFile = Join-Path $configDir "setup-state.json"
            Test-Path $setupStateFile | Should -Be $true
            
            # Verify quick start guide was generated
            $guideFiles = Get-ChildItem -Path $script:TestProjectRoot -Filter "QuickStart-*.md"
            $guideFiles | Should -Not -BeNullOrEmpty
        }
    }
}