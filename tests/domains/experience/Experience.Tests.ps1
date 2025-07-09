# Experience Domain Tests - Comprehensive Coverage
# Tests for Experience domain functions (SetupWizard, StartupExperience)
# Total Expected Functions: 22

BeforeAll {
    # Setup test environment
    $script:ProjectRoot = Split-Path -Parent $PSScriptRoot | Split-Path -Parent | Split-Path -Parent
    $script:DomainsPath = Join-Path $ProjectRoot "aither-core/domains"
    $script:TestDataPath = Join-Path $PSScriptRoot "test-data"
    
    # Import logging module first
    $LoggingModulePath = Join-Path $ProjectRoot "aither-core/modules/Logging/Logging.psm1"
    if (Test-Path $LoggingModulePath) {
        Import-Module $LoggingModulePath -Force
    }
    
    # Import test helpers
    $TestHelpersPath = Join-Path $ProjectRoot "tests/TestHelpers.psm1"
    if (Test-Path $TestHelpersPath) {
        Import-Module $TestHelpersPath -Force
    }
    
    # Import experience domain
    $ExperienceDomainPath = Join-Path $DomainsPath "experience/Experience.ps1"
    if (Test-Path $ExperienceDomainPath) {
        . $ExperienceDomainPath
    }
    
    # Create test data directory
    if (-not (Test-Path $TestDataPath)) {
        New-Item -Path $TestDataPath -ItemType Directory -Force
    }
    
    # Test data
    $script:TestConfigPath = Join-Path $TestDataPath "test-config.json"
    $script:TestSetupState = @{
        Platform = "Windows"
        PowerShellVersion = "7.3.0"
        InstallationProfile = "developer"
        Progress = 50
    }
}

Describe "Experience Domain - Setup Wizard Functions" {
    Context "Intelligent Setup" {
        It "Start-IntelligentSetup should start intelligent setup process" {
            Mock Write-CustomLog { }
            Mock Get-PlatformInfo { return @{ OS = "Windows"; Version = "10" } }
            Mock Test-Path { return $true }
            Mock Get-Content { return '{}' }
            Mock Set-Content { }
            
            $result = Start-IntelligentSetup -InstallationProfile "minimal"
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Get-PlatformInfo should return platform information" {
            Mock Write-CustomLog { }
            
            $result = Get-PlatformInfo
            $result | Should -Not -BeNullOrEmpty
            $result.OS | Should -Not -BeNullOrEmpty
        }
        
        It "Show-WelcomeMessage should display welcome message" {
            Mock Write-CustomLog { }
            Mock Write-Host { }
            Mock Get-PlatformInfo { return @{ OS = "Windows"; Version = "10" } }
            
            { Show-WelcomeMessage } | Should -Not -Throw
        }
        
        It "Show-SetupBanner should display setup banner" {
            Mock Write-CustomLog { }
            Mock Write-Host { }
            
            { Show-SetupBanner -Title "Test Setup" -Version "1.0.0" } | Should -Not -Throw
        }
    }
    
    Context "Installation Profile Management" {
        It "Get-InstallationProfile should return installation profile" {
            Mock Write-CustomLog { }
            
            $result = Get-InstallationProfile -ProfileName "developer"
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Show-EnhancedInstallationProfile should display enhanced profile" {
            Mock Write-CustomLog { }
            Mock Write-Host { }
            Mock Get-InstallationProfile { return @{ Name = "developer"; Components = @("Git", "VSCode") } }
            
            { Show-EnhancedInstallationProfile -ProfileName "developer" } | Should -Not -Throw
        }
        
        It "Get-InstallationProgress should return installation progress" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return ($TestSetupState | ConvertTo-Json) }
            
            $result = Get-InstallationProgress
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Set-InstallationProgress should update installation progress" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return ($TestSetupState | ConvertTo-Json) }
            Mock Set-Content { }
            
            { Set-InstallationProgress -Progress 75 -CurrentStep "Installing components" } | Should -Not -Throw
        }
        
        It "Test-InstallationComplete should test if installation is complete" {
            Mock Write-CustomLog { }
            Mock Get-InstallationProgress { return @{ Progress = 100 } }
            
            $result = Test-InstallationComplete
            $result | Should -BeOfType [bool]
        }
    }
    
    Context "Quick Start Guide" {
        It "Generate-QuickStartGuide should generate quick start guide" {
            Mock Write-CustomLog { }
            Mock Get-PlatformInfo { return @{ OS = "Windows"; Version = "10" } }
            Mock New-Item { }
            Mock Set-Content { }
            
            { Generate-QuickStartGuide -SetupState $TestSetupState } | Should -Not -Throw
        }
        
        It "Show-QuickStartGuide should display quick start guide" {
            Mock Write-CustomLog { }
            Mock Write-Host { }
            Mock Get-PlatformInfo { return @{ OS = "Windows"; Version = "10" } }
            
            { Show-QuickStartGuide -SetupState $TestSetupState } | Should -Not -Throw
        }
        
        It "Get-NextSteps should return next steps" {
            Mock Write-CustomLog { }
            Mock Test-InstallationComplete { return $true }
            
            $result = Get-NextSteps -SetupState $TestSetupState
            $result | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Experience Domain - Startup Experience Functions" {
    Context "Startup Mode Management" {
        It "Get-StartupMode should return startup mode" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return '{"StartupMode": "Interactive"}' }
            
            $result = Get-StartupMode
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Set-StartupMode should set startup mode" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return '{}' }
            Mock Set-Content { }
            
            { Set-StartupMode -Mode "Automated" } | Should -Not -Throw
        }
        
        It "Test-FirstTimeSetup should test if first-time setup is needed" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $false }
            
            $result = Test-FirstTimeSetup
            $result | Should -BeOfType [bool]
        }
    }
    
    Context "Interactive Experience" {
        It "Start-InteractiveExperience should start interactive experience" {
            Mock Write-CustomLog { }
            Mock Show-WelcomeMessage { }
            Mock Show-MainMenu { }
            Mock Read-Host { return "1" }
            
            { Start-InteractiveExperience } | Should -Not -Throw
        }
        
        It "Show-MainMenu should display main menu" {
            Mock Write-CustomLog { }
            Mock Write-Host { }
            Mock Get-AvailableModules { return @("Module1", "Module2") }
            
            { Show-MainMenu } | Should -Not -Throw
        }
        
        It "Get-AvailableModules should return available modules" {
            Mock Write-CustomLog { }
            Mock Get-ChildItem { return @(@{ Name = "Module1"; BaseName = "Module1" }) }
            
            $result = Get-AvailableModules
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Invoke-ModuleSelection should invoke module selection" {
            Mock Write-CustomLog { }
            Mock Get-AvailableModules { return @("Module1", "Module2") }
            Mock Read-Host { return "1" }
            
            $result = Invoke-ModuleSelection
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Environment Validation" {
        It "Test-EnvironmentReady should test if environment is ready" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Command { return @{ Name = "powershell" } }
            
            $result = Test-EnvironmentReady
            $result | Should -BeOfType [bool]
        }
        
        It "Get-EnvironmentStatus should return environment status" {
            Mock Write-CustomLog { }
            Mock Test-EnvironmentReady { return $true }
            Mock Get-PlatformInfo { return @{ OS = "Windows"; Version = "10" } }
            
            $result = Get-EnvironmentStatus
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Initialize-StartupEnvironment should initialize startup environment" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $false }
            Mock New-Item { }
            Mock Set-Content { }
            
            { Initialize-StartupEnvironment } | Should -Not -Throw
        }
        
        It "Save-StartupState should save startup state" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Set-Content { }
            
            { Save-StartupState -State @{ LastRun = (Get-Date) } } | Should -Not -Throw
        }
    }
}

AfterAll {
    # Clean up test environment
    if (Test-Path $TestDataPath) {
        Remove-Item -Path $TestDataPath -Recurse -Force
    }
}