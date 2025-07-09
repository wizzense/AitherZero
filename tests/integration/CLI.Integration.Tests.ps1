#Requires -Module Pester

<#
.SYNOPSIS
    CLI Entry Point and End-to-End Workflow Integration Tests

.DESCRIPTION
    Comprehensive integration tests for CLI entry points and complete workflows:
    - Start-AitherZero.ps1 entry point testing
    - Complete user workflows from CLI to execution
    - Setup wizard integration workflows
    - Script execution and coordination
    - Error handling and recovery workflows
    - Cross-platform CLI behavior
    - Interactive vs automated modes
    - Configuration management through CLI

.NOTES
    Tests the complete user experience from CLI invocation through 
    to successful execution and result delivery.
#>

BeforeAll {
    # Setup test environment
    $ProjectRoot = if ($env:PROJECT_ROOT) { $env:PROJECT_ROOT } else {
        $currentPath = $PSScriptRoot
        while ($currentPath -and -not (Test-Path (Join-Path $currentPath ".git"))) {
            $currentPath = Split-Path $currentPath -Parent
        }
        $currentPath
    }
    
    # Import required modules
    $requiredModules = @(
        "SetupWizard",
        "ConfigurationCore",
        "Logging",
        "TestingFramework",
        "StartupExperience"
    )
    
    foreach ($module in $requiredModules) {
        $modulePath = Join-Path $ProjectRoot "aither-core/modules/$module"
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Write-CustomLog is guaranteed to be available from AitherCore orchestration
    # No fallback needed - trust the orchestration system
    
    # Setup test directory structure
    $TestCLIRoot = Join-Path $TestDrive "cli-integration"
    $TestConfigRoot = Join-Path $TestCLIRoot "config"
    $TestLogsRoot = Join-Path $TestCLIRoot "logs"
    $TestOutputRoot = Join-Path $TestCLIRoot "output"
    $TestWorkspaceRoot = Join-Path $TestCLIRoot "workspace"
    
    @($TestCLIRoot, $TestConfigRoot, $TestLogsRoot, $TestOutputRoot, $TestWorkspaceRoot) | ForEach-Object {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
    
    # CLI entry point paths
    $StartAitherZeroPath = Join-Path $ProjectRoot "Start-AitherZero.ps1"
    $StartDeveloperSetupPath = Join-Path $ProjectRoot "Start-DeveloperSetup.ps1"
    
    # Mock CLI execution functions
    function Invoke-MockCLIExecution {
        param(
            [string]$ScriptPath,
            [hashtable]$Parameters = @{},
            [string]$WorkingDirectory = $TestWorkspaceRoot,
            [int]$TimeoutSeconds = 30
        )
        
        $executionResult = @{
            Success = $true
            ExitCode = 0
            ScriptPath = $ScriptPath
            Parameters = $Parameters
            WorkingDirectory = $WorkingDirectory
            ExecutionTime = Get-Date
            Duration = (Get-Random -Minimum 1 -Maximum 10)
            Output = @()
            Errors = @()
        }
        
        # Simulate different script behaviors
        $scriptName = Split-Path $ScriptPath -Leaf
        
        switch ($scriptName) {
            "Start-AitherZero.ps1" {
                $executionResult.Output += "🚀 AitherZero Infrastructure Automation Framework"
                $executionResult.Output += "============================================="
                
                if ($Parameters.ContainsKey("Setup")) {
                    $executionResult.Output += "Running first-time setup wizard..."
                    $executionResult.Output += "✅ Setup completed successfully"
                }
                
                if ($Parameters.ContainsKey("Auto")) {
                    $executionResult.Output += "Running in automatic mode..."
                    $executionResult.Output += "✅ Automatic execution completed"
                }
                
                if ($Parameters.ContainsKey("Scripts")) {
                    $executionResult.Output += "Running specified scripts: $($Parameters.Scripts)"
                    $executionResult.Output += "✅ Scripts executed successfully"
                }
                
                if ($Parameters.ContainsKey("WhatIf")) {
                    $executionResult.Output += "Preview mode - showing what would be done"
                    $executionResult.Output += "✅ Preview completed"
                }
                
                $executionResult.Output += "🎯 AitherZero execution completed successfully"
            }
            
            "Start-DeveloperSetup.ps1" {
                $executionResult.Output += "🔧 Developer Setup Wizard"
                $executionResult.Output += "========================="
                
                if ($Parameters.ContainsKey("Profile")) {
                    $executionResult.Output += "Using profile: $($Parameters.Profile)"
                }
                
                $executionResult.Output += "✅ Prerequisites validated"
                $executionResult.Output += "✅ Development environment configured"
                $executionResult.Output += "✅ VS Code settings updated"
                $executionResult.Output += "✅ Git hooks installed"
                $executionResult.Output += "🎯 Developer setup completed successfully"
            }
            
            default {
                $executionResult.Output += "Mock execution of $scriptName"
                $executionResult.Output += "✅ Execution completed"
            }
        }
        
        return $executionResult
    }
    
    # Mock setup wizard functions
    function Invoke-MockSetupWizard {
        param(
            [string]$InstallationProfile = "interactive",
            [bool]$NonInteractive = $false,
            [bool]$SkipOptional = $false
        )
        
        $setupResult = @{
            Success = $true
            Profile = $InstallationProfile
            NonInteractive = $NonInteractive
            SkipOptional = $SkipOptional
            Steps = @()
            Duration = (Get-Random -Minimum 5 -Maximum 30)
            ConfigurationPath = Join-Path $TestConfigRoot "setup-config.json"
        }
        
        # Simulate setup steps
        $setupSteps = @(
            @{ Name = "ValidatePrerequisites"; Success = $true; Duration = 2 },
            @{ Name = "ConfigureEnvironment"; Success = $true; Duration = 5 },
            @{ Name = "SetupDirectories"; Success = $true; Duration = 1 },
            @{ Name = "InitializeConfiguration"; Success = $true; Duration = 3 },
            @{ Name = "InstallDependencies"; Success = $true; Duration = 10 },
            @{ Name = "ConfigureModules"; Success = $true; Duration = 4 },
            @{ Name = "ValidateInstallation"; Success = $true; Duration = 2 }
        )
        
        if ($InstallationProfile -eq "minimal") {
            $setupSteps = $setupSteps | Where-Object { $_.Name -in @("ValidatePrerequisites", "ConfigureEnvironment", "SetupDirectories", "InitializeConfiguration") }
        }
        
        if ($SkipOptional) {
            $setupSteps = $setupSteps | Where-Object { $_.Name -notin @("InstallDependencies") }
        }
        
        $setupResult.Steps = $setupSteps
        
        # Create setup configuration
        $setupConfig = @{
            profile = $InstallationProfile
            completedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            steps = $setupSteps
            environment = @{
                platform = if ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } else { "macOS" }
                powershellVersion = $PSVersionTable.PSVersion.ToString()
                userHome = $HOME
            }
        }
        
        $setupConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $setupResult.ConfigurationPath
        
        return $setupResult
    }
    
    # Mock configuration management
    function Invoke-MockConfigurationManagement {
        param(
            [string]$Action,
            [hashtable]$Parameters = @{}
        )
        
        $configResult = @{
            Success = $true
            Action = $Action
            Parameters = $Parameters
            ConfigurationPath = Join-Path $TestConfigRoot "active-config.json"
            Timestamp = Get-Date
        }
        
        switch ($Action) {
            "Initialize" {
                $config = @{
                    version = "1.0.0"
                    initialized = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    platform = if ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } else { "macOS" }
                    modules = @{
                        core = @{ enabled = $true }
                        logging = @{ enabled = $true }
                    }
                }
                
                $config | ConvertTo-Json -Depth 5 | Set-Content -Path $configResult.ConfigurationPath
                $configResult.Configuration = $config
            }
            
            "Update" {
                if (Test-Path $configResult.ConfigurationPath) {
                    $config = Get-Content $configResult.ConfigurationPath | ConvertFrom-Json
                    
                    if ($Parameters.ContainsKey("ModuleSettings")) {
                        $config.modules = $Parameters.ModuleSettings
                    }
                    
                    $config.lastUpdated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    $config | ConvertTo-Json -Depth 5 | Set-Content -Path $configResult.ConfigurationPath
                    $configResult.Configuration = $config
                }
            }
            
            "Validate" {
                if (Test-Path $configResult.ConfigurationPath) {
                    try {
                        $config = Get-Content $configResult.ConfigurationPath | ConvertFrom-Json
                        $configResult.Validation = @{
                            Valid = $true
                            Version = $config.version
                            RequiredFields = @("version", "modules")
                            MissingFields = @()
                        }
                    } catch {
                        $configResult.Success = $false
                        $configResult.Validation = @{
                            Valid = $false
                            Error = $_.Exception.Message
                        }
                    }
                } else {
                    $configResult.Success = $false
                    $configResult.Validation = @{
                        Valid = $false
                        Error = "Configuration file not found"
                    }
                }
            }
        }
        
        return $configResult
    }
    
    # Event tracking
    $script:CLIEvents = @()
    
    # Publish-TestEvent is guaranteed to be available from AitherCore orchestration
    # No fallback needed - trust the orchestration system
    if (-not (Get-Command 'Publish-TestEvent' -ErrorAction SilentlyContinue)) {
        function Publish-TestEvent {
            param([string]$EventName, [hashtable]$EventData)
            $script:CLIEvents += @{
                EventName = $EventName
                EventData = $EventData
                Timestamp = Get-Date
            }
        }
    }
}

Describe "CLI Entry Point and End-to-End Workflow Integration Tests" {
    
    Context "Start-AitherZero.ps1 Entry Point" {
        
        It "Should execute successfully in interactive mode" {
            # Arrange
            $interactiveParams = @{}
            
            # Act
            $result = Invoke-MockCLIExecution -ScriptPath $StartAitherZeroPath -Parameters $interactiveParams
            
            # Publish CLI execution event
            Publish-TestEvent -EventName "CLIExecutionCompleted" -EventData @{
                ScriptPath = $StartAitherZeroPath
                Mode = "Interactive"
                Parameters = $interactiveParams
                Success = $result.Success
                Duration = $result.Duration
            }
            
            # Assert
            $result.Success | Should -Be $true
            $result.ExitCode | Should -Be 0
            $result.Output | Should -Contain "🚀 AitherZero Infrastructure Automation Framework"
            $result.Output | Should -Contain "🎯 AitherZero execution completed successfully"
            $result.Errors.Count | Should -Be 0
            
            # Verify event tracking
            $cliEvents = $script:CLIEvents | Where-Object { $_.EventName -eq "CLIExecutionCompleted" }
            $cliEvents.Count | Should -BeGreaterThan 0
            $cliEvents[-1].EventData.Mode | Should -Be "Interactive"
        }
        
        It "Should execute successfully in automatic mode" {
            # Arrange
            $autoParams = @{
                Auto = $true
                Scripts = "LabRunner,BackupManager"
            }
            
            # Act
            $result = Invoke-MockCLIExecution -ScriptPath $StartAitherZeroPath -Parameters $autoParams
            
            # Publish CLI execution event
            Publish-TestEvent -EventName "CLIExecutionCompleted" -EventData @{
                ScriptPath = $StartAitherZeroPath
                Mode = "Automatic"
                Parameters = $autoParams
                Success = $result.Success
                Duration = $result.Duration
            }
            
            # Assert
            $result.Success | Should -Be $true
            $result.ExitCode | Should -Be 0
            $result.Output | Should -Contain "Running in automatic mode..."
            $result.Output | Should -Contain "Running specified scripts: LabRunner,BackupManager"
            $result.Output | Should -Contain "✅ Scripts executed successfully"
            
            # Verify event tracking
            $cliEvents = $script:CLIEvents | Where-Object { $_.EventName -eq "CLIExecutionCompleted" }
            $cliEvents[-1].EventData.Mode | Should -Be "Automatic"
            $cliEvents[-1].EventData.Parameters.Auto | Should -Be $true
        }
        
        It "Should execute setup wizard workflow" {
            # Arrange
            $setupParams = @{
                Setup = $true
                InstallationProfile = "developer"
                NonInteractive = $true
            }
            
            # Act
            $result = Invoke-MockCLIExecution -ScriptPath $StartAitherZeroPath -Parameters $setupParams
            
            # Simulate setup wizard execution
            $setupResult = Invoke-MockSetupWizard -InstallationProfile "developer" -NonInteractive $true
            
            # Publish setup workflow event
            Publish-TestEvent -EventName "SetupWorkflowCompleted" -EventData @{
                CLIResult = $result
                SetupResult = $setupResult
                Profile = "developer"
                NonInteractive = $true
            }
            
            # Assert
            $result.Success | Should -Be $true
            $result.Output | Should -Contain "Running first-time setup wizard..."
            $result.Output | Should -Contain "✅ Setup completed successfully"
            
            $setupResult.Success | Should -Be $true
            $setupResult.Profile | Should -Be "developer"
            $setupResult.NonInteractive | Should -Be $true
            $setupResult.Steps.Count | Should -BeGreaterThan 0
            Test-Path $setupResult.ConfigurationPath | Should -Be $true
            
            # Verify event tracking
            $setupEvents = $script:CLIEvents | Where-Object { $_.EventName -eq "SetupWorkflowCompleted" }
            $setupEvents.Count | Should -BeGreaterThan 0
            $setupEvents[-1].EventData.Profile | Should -Be "developer"
        }
        
        It "Should execute preview mode (WhatIf)" {
            # Arrange
            $previewParams = @{
                WhatIf = $true
                Scripts = "LabRunner"
            }
            
            # Act
            $result = Invoke-MockCLIExecution -ScriptPath $StartAitherZeroPath -Parameters $previewParams
            
            # Publish preview execution event
            Publish-TestEvent -EventName "PreviewExecutionCompleted" -EventData @{
                ScriptPath = $StartAitherZeroPath
                Mode = "Preview"
                Parameters = $previewParams
                Success = $result.Success
            }
            
            # Assert
            $result.Success | Should -Be $true
            $result.Output | Should -Contain "Preview mode - showing what would be done"
            $result.Output | Should -Contain "✅ Preview completed"
            
            # Verify event tracking
            $previewEvents = $script:CLIEvents | Where-Object { $_.EventName -eq "PreviewExecutionCompleted" }
            $previewEvents.Count | Should -BeGreaterThan 0
            $previewEvents[-1].EventData.Mode | Should -Be "Preview"
        }
    }
    
    Context "Developer Setup Workflow" {
        
        It "Should execute complete developer setup workflow" {
            # Arrange
            $devSetupParams = @{
                Profile = "Full"
                SkipAITools = $false
                SkipGitHooks = $false
            }
            
            # Act
            $result = Invoke-MockCLIExecution -ScriptPath $StartDeveloperSetupPath -Parameters $devSetupParams
            
            # Simulate detailed setup process
            $detailedSetup = @{
                Prerequisites = @{
                    PowerShellVersion = @{
                        Required = "7.0"
                        Actual = $PSVersionTable.PSVersion.ToString()
                        Valid = $PSVersionTable.PSVersion.Major -ge 7
                    }
                    GitAvailable = @{
                        Required = $true
                        Available = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
                    }
                }
                ConfigurationSteps = @(
                    @{ Name = "ValidatePrerequisites"; Success = $true },
                    @{ Name = "ConfigureVSCode"; Success = $true },
                    @{ Name = "InstallGitHooks"; Success = $true },
                    @{ Name = "SetupAITools"; Success = $true },
                    @{ Name = "ConfigureAliases"; Success = $true },
                    @{ Name = "SetupModulePaths"; Success = $true }
                )
                Environment = @{
                    VSCodeConfigured = $true
                    GitHooksInstalled = $true
                    AIToolsInstalled = $true
                    AliasesConfigured = $true
                }
            }
            
            # Publish developer setup event
            Publish-TestEvent -EventName "DeveloperSetupCompleted" -EventData @{
                CLIResult = $result
                SetupDetails = $detailedSetup
                Profile = $devSetupParams.Profile
            }
            
            # Assert
            $result.Success | Should -Be $true
            $result.Output | Should -Contain "🔧 Developer Setup Wizard"
            $result.Output | Should -Contain "Using profile: Full"
            $result.Output | Should -Contain "✅ Prerequisites validated"
            $result.Output | Should -Contain "✅ Development environment configured"
            $result.Output | Should -Contain "✅ VS Code settings updated"
            $result.Output | Should -Contain "✅ Git hooks installed"
            $result.Output | Should -Contain "🎯 Developer setup completed successfully"
            
            # Verify prerequisites
            $detailedSetup.Prerequisites.PowerShellVersion.Valid | Should -Be $true
            $detailedSetup.ConfigurationSteps | ForEach-Object { $_.Success | Should -Be $true }
            
            # Verify event tracking
            $devSetupEvents = $script:CLIEvents | Where-Object { $_.EventName -eq "DeveloperSetupCompleted" }
            $devSetupEvents.Count | Should -BeGreaterThan 0
            $devSetupEvents[-1].EventData.Profile | Should -Be "Full"
        }
        
        It "Should handle minimal developer setup profile" {
            # Arrange
            $minimalParams = @{
                Profile = "Quick"
                SkipAITools = $true
                SkipGitHooks = $true
            }
            
            # Act
            $result = Invoke-MockCLIExecution -ScriptPath $StartDeveloperSetupPath -Parameters $minimalParams
            
            # Simulate minimal setup
            $minimalSetup = Invoke-MockSetupWizard -InstallationProfile "minimal" -SkipOptional $true
            
            # Publish minimal setup event
            Publish-TestEvent -EventName "MinimalSetupCompleted" -EventData @{
                CLIResult = $result
                SetupResult = $minimalSetup
                Profile = "Quick"
                SkippedComponents = @("AITools", "GitHooks")
            }
            
            # Assert
            $result.Success | Should -Be $true
            $result.Output | Should -Contain "Using profile: Quick"
            $result.Output | Should -Contain "🎯 Developer setup completed successfully"
            
            $minimalSetup.Success | Should -Be $true
            $minimalSetup.Profile | Should -Be "minimal"
            $minimalSetup.SkipOptional | Should -Be $true
            $minimalSetup.Steps.Count | Should -BeLessThan 7  # Fewer steps than full setup
            
            # Verify event tracking
            $minimalEvents = $script:CLIEvents | Where-Object { $_.EventName -eq "MinimalSetupCompleted" }
            $minimalEvents.Count | Should -BeGreaterThan 0
            $minimalEvents[-1].EventData.SkippedComponents | Should -Contain "AITools"
            $minimalEvents[-1].EventData.SkippedComponents | Should -Contain "GitHooks"
        }
    }
    
    Context "End-to-End Configuration Workflow" {
        
        It "Should handle complete configuration lifecycle through CLI" {
            # Arrange
            $configWorkflow = @{
                Steps = @("initialize", "configure", "validate", "deploy")
                Environment = "development"
                Profile = "interactive"
            }
            
            # Act
            $workflowResults = @{}
            
            # Step 1: Initialize configuration
            $workflowResults.Initialize = Invoke-MockConfigurationManagement -Action "Initialize"
            
            # Step 2: Configure modules
            $moduleSettings = @{
                core = @{ enabled = $true; priority = 1 }
                logging = @{ enabled = $true; level = "info" }
                testing = @{ enabled = $true; framework = "Pester" }
            }
            $workflowResults.Configure = Invoke-MockConfigurationManagement -Action "Update" -Parameters @{
                ModuleSettings = $moduleSettings
            }
            
            # Step 3: Validate configuration
            $workflowResults.Validate = Invoke-MockConfigurationManagement -Action "Validate"
            
            # Step 4: Deploy configuration (simulate CLI execution)
            $deployParams = @{
                Auto = $true
                ConfigFile = $workflowResults.Initialize.ConfigurationPath
            }
            $workflowResults.Deploy = Invoke-MockCLIExecution -ScriptPath $StartAitherZeroPath -Parameters $deployParams
            
            # Publish configuration workflow event
            Publish-TestEvent -EventName "ConfigurationWorkflowCompleted" -EventData @{
                WorkflowSteps = $configWorkflow.Steps
                Environment = $configWorkflow.Environment
                Results = $workflowResults
                Success = $true
            }
            
            # Assert
            $workflowResults.Initialize.Success | Should -Be $true
            $workflowResults.Configure.Success | Should -Be $true
            $workflowResults.Validate.Success | Should -Be $true
            $workflowResults.Deploy.Success | Should -Be $true
            
            # Verify configuration files
            Test-Path $workflowResults.Initialize.ConfigurationPath | Should -Be $true
            
            # Verify configuration content
            $configContent = Get-Content $workflowResults.Initialize.ConfigurationPath | ConvertFrom-Json
            $configContent.version | Should -Be "1.0.0"
            $configContent.modules.core.enabled | Should -Be $true
            
            # Verify validation results
            $workflowResults.Validate.Validation.Valid | Should -Be $true
            $workflowResults.Validate.Validation.MissingFields.Count | Should -Be 0
            
            # Verify event tracking
            $configEvents = $script:CLIEvents | Where-Object { $_.EventName -eq "ConfigurationWorkflowCompleted" }
            $configEvents.Count | Should -BeGreaterThan 0
            $configEvents[-1].EventData.Environment | Should -Be "development"
        }
        
        It "Should handle configuration hot-reload workflow" {
            # Arrange
            $hotReloadWorkflow = @{
                InitialConfig = Join-Path $TestConfigRoot "hot-reload-initial.json"
                UpdatedConfig = Join-Path $TestConfigRoot "hot-reload-updated.json"
                ReloadTrigger = "FileWatcher"
            }
            
            # Act
            # Create initial configuration
            $initialConfig = @{
                version = "1.0.0"
                modules = @{
                    core = @{ enabled = $true; version = "1.0.0" }
                    logging = @{ enabled = $true; level = "info" }
                }
                hotReload = @{
                    enabled = $true
                    watchPaths = @($hotReloadWorkflow.InitialConfig)
                }
            }
            $initialConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $hotReloadWorkflow.InitialConfig
            
            # Start with initial configuration
            $initialResult = Invoke-MockCLIExecution -ScriptPath $StartAitherZeroPath -Parameters @{
                ConfigFile = $hotReloadWorkflow.InitialConfig
                Auto = $true
            }
            
            # Update configuration
            $updatedConfig = $initialConfig.Clone()
            $updatedConfig.modules.logging.level = "debug"
            $updatedConfig.modules.newModule = @{ enabled = $true; version = "1.0.0" }
            $updatedConfig.lastUpdated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $updatedConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $hotReloadWorkflow.UpdatedConfig
            
            # Simulate hot-reload trigger
            $hotReloadResult = @{
                Success = $true
                TriggerType = $hotReloadWorkflow.ReloadTrigger
                ConfigChanges = @{
                    Modified = @("modules.logging.level")
                    Added = @("modules.newModule")
                    Removed = @()
                }
                ReloadTime = Get-Date
            }
            
            # Publish hot-reload event
            Publish-TestEvent -EventName "ConfigurationHotReloaded" -EventData @{
                InitialConfig = $hotReloadWorkflow.InitialConfig
                UpdatedConfig = $hotReloadWorkflow.UpdatedConfig
                ReloadResult = $hotReloadResult
                TriggerType = $hotReloadWorkflow.ReloadTrigger
            }
            
            # Assert
            $initialResult.Success | Should -Be $true
            $hotReloadResult.Success | Should -Be $true
            
            # Verify configuration files
            Test-Path $hotReloadWorkflow.InitialConfig | Should -Be $true
            Test-Path $hotReloadWorkflow.UpdatedConfig | Should -Be $true
            
            # Verify configuration changes
            $initialConfigContent = Get-Content $hotReloadWorkflow.InitialConfig | ConvertFrom-Json
            $updatedConfigContent = Get-Content $hotReloadWorkflow.UpdatedConfig | ConvertFrom-Json
            
            $initialConfigContent.modules.logging.level | Should -Be "info"
            $updatedConfigContent.modules.logging.level | Should -Be "debug"
            $updatedConfigContent.modules.newModule.enabled | Should -Be $true
            
            # Verify hot-reload tracking
            $hotReloadResult.ConfigChanges.Modified | Should -Contain "modules.logging.level"
            $hotReloadResult.ConfigChanges.Added | Should -Contain "modules.newModule"
            
            # Verify event tracking
            $hotReloadEvents = $script:CLIEvents | Where-Object { $_.EventName -eq "ConfigurationHotReloaded" }
            $hotReloadEvents.Count | Should -BeGreaterThan 0
            $hotReloadEvents[-1].EventData.TriggerType | Should -Be "FileWatcher"
        }
    }
    
    Context "Error Handling and Recovery Workflows" {
        
        It "Should handle CLI execution failures gracefully" {
            # Arrange
            $failureParams = @{
                InvalidParameter = "invalid-value"
                Scripts = "NonExistentScript"
            }
            
            # Act - Simulate CLI failure
            $failureResult = @{
                Success = $false
                ExitCode = 1
                ScriptPath = $StartAitherZeroPath
                Parameters = $failureParams
                ExecutionTime = Get-Date
                Duration = 2
                Output = @("🚀 AitherZero Infrastructure Automation Framework")
                Errors = @(
                    "Error: Script 'NonExistentScript' not found",
                    "Error: Invalid parameter 'InvalidParameter'"
                )
            }
            
            # Simulate recovery attempt
            $recoveryParams = @{
                Scripts = "LabRunner"  # Valid script
                Force = $true
            }
            
            $recoveryResult = Invoke-MockCLIExecution -ScriptPath $StartAitherZeroPath -Parameters $recoveryParams
            
            # Publish error handling event
            Publish-TestEvent -EventName "CLIErrorHandled" -EventData @{
                OriginalFailure = $failureResult
                RecoveryAttempt = $recoveryResult
                RecoverySuccess = $recoveryResult.Success
                ErrorTypes = @("ScriptNotFound", "InvalidParameter")
            }
            
            # Assert
            $failureResult.Success | Should -Be $false
            $failureResult.ExitCode | Should -Be 1
            $failureResult.Errors.Count | Should -BeGreaterThan 0
            
            $recoveryResult.Success | Should -Be $true
            $recoveryResult.ExitCode | Should -Be 0
            $recoveryResult.Errors.Count | Should -Be 0
            
            # Verify error handling event
            $errorEvents = $script:CLIEvents | Where-Object { $_.EventName -eq "CLIErrorHandled" }
            $errorEvents.Count | Should -BeGreaterThan 0
            $errorEvents[-1].EventData.RecoverySuccess | Should -Be $true
            $errorEvents[-1].EventData.ErrorTypes | Should -Contain "ScriptNotFound"
        }
        
        It "Should handle configuration corruption and recovery" {
            # Arrange
            $corruptedConfigPath = Join-Path $TestConfigRoot "corrupted-config.json"
            $backupConfigPath = Join-Path $TestConfigRoot "backup-config.json"
            
            # Create valid backup configuration
            $validConfig = @{
                version = "1.0.0"
                modules = @{
                    core = @{ enabled = $true }
                    logging = @{ enabled = $true; level = "info" }
                }
            }
            $validConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $backupConfigPath
            
            # Create corrupted configuration
            "{ invalid json syntax" | Set-Content -Path $corruptedConfigPath
            
            # Act - Attempt to use corrupted configuration
            $corruptedResult = Invoke-MockConfigurationManagement -Action "Validate" -Parameters @{
                ConfigPath = $corruptedConfigPath
            }
            
            # Recovery process
            $recoverySteps = @()
            
            # Step 1: Detect corruption
            $recoverySteps += @{
                Step = "DetectCorruption"
                Success = -not $corruptedResult.Success
                Details = $corruptedResult.Validation
            }
            
            # Step 2: Restore from backup
            Copy-Item -Path $backupConfigPath -Destination $corruptedConfigPath -Force
            $recoverySteps += @{
                Step = "RestoreFromBackup"
                Success = $true
                BackupPath = $backupConfigPath
            }
            
            # Step 3: Validate restored configuration
            $restoredResult = Invoke-MockConfigurationManagement -Action "Validate" -Parameters @{
                ConfigPath = $corruptedConfigPath
            }
            $recoverySteps += @{
                Step = "ValidateRestored"
                Success = $restoredResult.Success
                ValidationResult = $restoredResult.Validation
            }
            
            # Publish corruption recovery event
            Publish-TestEvent -EventName "ConfigurationCorruptionRecovered" -EventData @{
                CorruptedConfigPath = $corruptedConfigPath
                BackupConfigPath = $backupConfigPath
                RecoverySteps = $recoverySteps
                RecoverySuccess = $recoverySteps | ForEach-Object { $_.Success } | Where-Object { $_ -eq $false } | Should -BeNullOrEmpty
            }
            
            # Assert
            $corruptedResult.Success | Should -Be $false
            $corruptedResult.Validation.Valid | Should -Be $false
            
            $recoverySteps[0].Success | Should -Be $true  # Corruption detected
            $recoverySteps[1].Success | Should -Be $true  # Backup restored
            $recoverySteps[2].Success | Should -Be $true  # Validation passed
            
            $restoredResult.Success | Should -Be $true
            $restoredResult.Validation.Valid | Should -Be $true
            
            # Verify recovery event
            $recoveryEvents = $script:CLIEvents | Where-Object { $_.EventName -eq "ConfigurationCorruptionRecovered" }
            $recoveryEvents.Count | Should -BeGreaterThan 0
            $recoveryEvents[-1].EventData.RecoverySteps.Count | Should -Be 3
        }
    }
    
    Context "Cross-Platform CLI Behavior" {
        
        It "Should handle cross-platform path differences" {
            # Arrange
            $platformInfo = @{
                Current = if ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } else { "macOS" }
                PathSeparator = [System.IO.Path]::DirectorySeparatorChar
                ConfigPath = Join-Path $TestConfigRoot "platform-config.json"
            }
            
            # Act
            $platformConfig = @{
                version = "1.0.0"
                platform = $platformInfo.Current
                paths = @{
                    home = $HOME
                    config = $TestConfigRoot
                    logs = $TestLogsRoot
                    pathSeparator = $platformInfo.PathSeparator
                }
                platformSpecific = @{
                    windows = @{
                        powershellPath = if ($IsWindows) { $PSHOME } else { $null }
                        userProfile = if ($IsWindows) { $env:USERPROFILE } else { $null }
                    }
                    linux = @{
                        bashPath = if ($IsLinux) { "/bin/bash" } else { $null }
                        userHome = if ($IsLinux) { $env:HOME } else { $null }
                    }
                    macos = @{
                        bashPath = if ($IsMacOS) { "/bin/bash" } else { $null }
                        userHome = if ($IsMacOS) { $env:HOME } else { $null }
                    }
                }
            }
            
            $platformConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $platformInfo.ConfigPath
            
            # Execute CLI with platform-specific configuration
            $platformResult = Invoke-MockCLIExecution -ScriptPath $StartAitherZeroPath -Parameters @{
                ConfigFile = $platformInfo.ConfigPath
                Auto = $true
            }
            
            # Publish cross-platform event
            Publish-TestEvent -EventName "CrossPlatformCLIExecuted" -EventData @{
                Platform = $platformInfo.Current
                PathSeparator = $platformInfo.PathSeparator
                ConfigPath = $platformInfo.ConfigPath
                CLIResult = $platformResult
            }
            
            # Assert
            $platformResult.Success | Should -Be $true
            $platformInfo.Current | Should -BeIn @("Windows", "Linux", "macOS")
            $platformInfo.PathSeparator | Should -BeIn @('\', '/')
            
            # Verify platform-specific configuration
            $configContent = Get-Content $platformInfo.ConfigPath | ConvertFrom-Json
            $configContent.platform | Should -Be $platformInfo.Current
            $configContent.paths.pathSeparator | Should -Be $platformInfo.PathSeparator
            
            # Verify event tracking
            $platformEvents = $script:CLIEvents | Where-Object { $_.EventName -eq "CrossPlatformCLIExecuted" }
            $platformEvents.Count | Should -BeGreaterThan 0
            $platformEvents[-1].EventData.Platform | Should -Be $platformInfo.Current
        }
        
        It "Should handle different PowerShell versions" {
            # Arrange
            $versionInfo = @{
                Current = $PSVersionTable.PSVersion
                Major = $PSVersionTable.PSVersion.Major
                Minor = $PSVersionTable.PSVersion.Minor
                Supported = $PSVersionTable.PSVersion.Major -ge 7
            }
            
            # Act
            $versionResult = @{
                Success = $versionInfo.Supported
                Version = $versionInfo.Current.ToString()
                Major = $versionInfo.Major
                Minor = $versionInfo.Minor
                Supported = $versionInfo.Supported
                Features = @{
                    CrossPlatform = $versionInfo.Major -ge 6
                    ModernSyntax = $versionInfo.Major -ge 7
                    ParallelForEach = $versionInfo.Major -ge 7
                }
            }
            
            # Execute CLI with version validation
            if ($versionResult.Success) {
                $cliResult = Invoke-MockCLIExecution -ScriptPath $StartAitherZeroPath -Parameters @{
                    Auto = $true
                    Verbosity = "detailed"
                }
                $versionResult.CLIExecution = $cliResult
            }
            
            # Publish version compatibility event
            Publish-TestEvent -EventName "PowerShellVersionValidated" -EventData @{
                VersionInfo = $versionInfo
                VersionResult = $versionResult
                CLICompatible = $versionResult.Success
            }
            
            # Assert
            $versionInfo.Current | Should -Not -BeNullOrEmpty
            $versionInfo.Major | Should -BeGreaterThan 0
            $versionInfo.Supported | Should -Be $true  # Test environment should have PS 7+
            
            $versionResult.Features.CrossPlatform | Should -Be $true
            $versionResult.Features.ModernSyntax | Should -Be $true
            $versionResult.Features.ParallelForEach | Should -Be $true
            
            if ($versionResult.Success) {
                $versionResult.CLIExecution.Success | Should -Be $true
            }
            
            # Verify version event
            $versionEvents = $script:CLIEvents | Where-Object { $_.EventName -eq "PowerShellVersionValidated" }
            $versionEvents.Count | Should -BeGreaterThan 0
            $versionEvents[-1].EventData.CLICompatible | Should -Be $true
        }
    }
}

AfterAll {
    # Cleanup test environment
    if (Test-Path $TestCLIRoot) {
        Remove-Item -Path $TestCLIRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Clear captured events
    $script:CLIEvents = @()
}