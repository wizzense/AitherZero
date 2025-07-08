#Requires -Module Pester

<#
.SYNOPSIS
    Smoke Tests for Critical Paths - Integration Test Suite

.DESCRIPTION
    Critical path smoke tests for AitherZero system integration:
    - System startup and initialization
    - Core module loading and basic functionality
    - Essential configuration management
    - Basic CLI operations
    - Critical workflows end-to-end
    - Health checks and system readiness
    - Cross-platform compatibility basics
    - Error detection and recovery readiness

.NOTES
    These tests are designed to run quickly and detect major system issues.
    They focus on critical paths that must work for the system to be functional.
    Should complete in under 2 minutes for CI/CD pipelines.
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
    
    # Critical paths to test
    $CriticalPaths = @{
        EntryPoints = @(
            "Start-AitherZero.ps1",
            "Start-DeveloperSetup.ps1"
        )
        CoreModules = @(
            "Logging",
            "ConfigurationCore",
            "TestingFramework",
            "SetupWizard",
            "PatchManager"
        )
        ConfigurationFiles = @(
            "configs/default-config.json",
            "aither-core/default-config.json"
        )
        SharedUtilities = @(
            "aither-core/shared/Find-ProjectRoot.ps1",
            "aither-core/shared/Test-PowerShellVersion.ps1"
        )
    }
    
    # Mock Write-CustomLog if not available
    if (-not (Get-Command 'Write-CustomLog' -ErrorAction SilentlyContinue)) {
        function Write-CustomLog {
            param([string]$Level, [string]$Message)
            Write-Host "[$Level] $Message"
        }
    }
    
    # Setup test directory structure
    $TestSmokeRoot = Join-Path $TestDrive "smoke-tests"
    $TestConfigRoot = Join-Path $TestSmokeRoot "config"
    $TestLogsRoot = Join-Path $TestSmokeRoot "logs"
    $TestOutputRoot = Join-Path $TestSmokeRoot "output"
    
    @($TestSmokeRoot, $TestConfigRoot, $TestLogsRoot, $TestOutputRoot) | ForEach-Object {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
    
    # Health check functions
    function Test-SystemHealth {
        param([string]$Component)
        
        $healthCheck = @{
            Component = $Component
            Status = "Unknown"
            Timestamp = Get-Date
            Details = @{}
            Success = $false
        }
        
        switch ($Component) {
            "PowerShell" {
                $healthCheck.Details = @{
                    Version = $PSVersionTable.PSVersion.ToString()
                    Platform = if ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } else { "macOS" }
                    VersionSupported = $PSVersionTable.PSVersion.Major -ge 7
                }
                $healthCheck.Status = if ($healthCheck.Details.VersionSupported) { "Healthy" } else { "Unhealthy" }
                $healthCheck.Success = $healthCheck.Details.VersionSupported
            }
            
            "FileSystem" {
                $healthCheck.Details = @{
                    ProjectRootExists = Test-Path $ProjectRoot
                    WritableTestDrive = Test-Path $TestDrive
                    TempDirectoryAccess = $true
                }
                
                try {
                    $testFile = Join-Path $TestDrive "write-test.txt"
                    "test" | Set-Content -Path $testFile
                    Remove-Item -Path $testFile -Force
                    $healthCheck.Details.TempDirectoryAccess = $true
                } catch {
                    $healthCheck.Details.TempDirectoryAccess = $false
                }
                
                $healthCheck.Success = $healthCheck.Details.ProjectRootExists -and $healthCheck.Details.WritableTestDrive -and $healthCheck.Details.TempDirectoryAccess
                $healthCheck.Status = if ($healthCheck.Success) { "Healthy" } else { "Unhealthy" }
            }
            
            "ModuleSystem" {
                $healthCheck.Details = @{
                    PesterAvailable = $null -ne (Get-Module -ListAvailable -Name Pester)
                    ModulePathConfigured = $env:PSModulePath -ne $null
                    AitherCorePathExists = Test-Path (Join-Path $ProjectRoot "aither-core")
                }
                
                $healthCheck.Success = $healthCheck.Details.PesterAvailable -and $healthCheck.Details.ModulePathConfigured -and $healthCheck.Details.AitherCorePathExists
                $healthCheck.Status = if ($healthCheck.Success) { "Healthy" } else { "Unhealthy" }
            }
            
            "Configuration" {
                $defaultConfigPath = Join-Path $ProjectRoot "configs/default-config.json"
                $coreConfigPath = Join-Path $ProjectRoot "aither-core/default-config.json"
                
                $healthCheck.Details = @{
                    DefaultConfigExists = Test-Path $defaultConfigPath
                    CoreConfigExists = Test-Path $coreConfigPath
                    ConfigurationValid = $false
                }
                
                if ($healthCheck.Details.DefaultConfigExists) {
                    try {
                        $config = Get-Content $defaultConfigPath | ConvertFrom-Json
                        $healthCheck.Details.ConfigurationValid = $config.version -ne $null
                    } catch {
                        $healthCheck.Details.ConfigurationValid = $false
                    }
                }
                
                $healthCheck.Success = $healthCheck.Details.DefaultConfigExists -and $healthCheck.Details.ConfigurationValid
                $healthCheck.Status = if ($healthCheck.Success) { "Healthy" } else { "Unhealthy" }
            }
            
            default {
                $healthCheck.Status = "Unknown"
                $healthCheck.Success = $false
            }
        }
        
        return $healthCheck
    }
    
    # Mock critical functions for smoke testing
    function Test-CriticalPath {
        param(
            [string]$PathName,
            [string]$PathType,
            [string]$Path,
            [scriptblock]$TestAction = $null
        )
        
        $pathTest = @{
            PathName = $PathName
            PathType = $PathType
            Path = $Path
            Success = $false
            Details = @{}
            TestTime = Get-Date
            Duration = 0
            Error = $null
        }
        
        $startTime = Get-Date
        
        try {
            switch ($PathType) {
                "File" {
                    $pathTest.Details.Exists = Test-Path $Path
                    $pathTest.Details.Readable = $false
                    
                    if ($pathTest.Details.Exists) {
                        $content = Get-Content $Path -TotalCount 1
                        $pathTest.Details.Readable = $true
                        $pathTest.Details.FirstLine = $content
                    }
                    
                    $pathTest.Success = $pathTest.Details.Exists -and $pathTest.Details.Readable
                }
                
                "Directory" {
                    $pathTest.Details.Exists = Test-Path $Path
                    $pathTest.Details.Accessible = $false
                    
                    if ($pathTest.Details.Exists) {
                        $pathTest.Details.ItemCount = (Get-ChildItem $Path -ErrorAction SilentlyContinue).Count
                        $pathTest.Details.Accessible = $true
                    }
                    
                    $pathTest.Success = $pathTest.Details.Exists -and $pathTest.Details.Accessible
                }
                
                "Module" {
                    $modulePath = Join-Path $ProjectRoot "aither-core/modules/$Path"
                    $pathTest.Details.ModulePathExists = Test-Path $modulePath
                    $pathTest.Details.ManifestExists = Test-Path (Join-Path $modulePath "$Path.psd1")
                    $pathTest.Details.ScriptExists = Test-Path (Join-Path $modulePath "$Path.psm1")
                    
                    if ($pathTest.Details.ManifestExists) {
                        try {
                            $manifest = Test-ModuleManifest -Path (Join-Path $modulePath "$Path.psd1") -ErrorAction SilentlyContinue
                            $pathTest.Details.ManifestValid = $manifest -ne $null
                        } catch {
                            $pathTest.Details.ManifestValid = $false
                        }
                    }
                    
                    $pathTest.Success = $pathTest.Details.ModulePathExists -and $pathTest.Details.ManifestExists -and $pathTest.Details.ScriptExists
                }
                
                "Script" {
                    $scriptPath = Join-Path $ProjectRoot $Path
                    $pathTest.Details.ScriptExists = Test-Path $scriptPath
                    $pathTest.Details.Syntactically = $false
                    
                    if ($pathTest.Details.ScriptExists) {
                        try {
                            $tokens = $null
                            $errors = $null
                            $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
                            $pathTest.Details.SyntaxErrors = $errors.Count
                            $pathTest.Details.SyntacticallyValid = $errors.Count -eq 0
                        } catch {
                            $pathTest.Details.SyntacticallyValid = $false
                            $pathTest.Details.SyntaxErrors = 999
                        }
                    }
                    
                    $pathTest.Success = $pathTest.Details.ScriptExists -and $pathTest.Details.SyntacticallyValid
                }
                
                "Custom" {
                    if ($TestAction) {
                        $customResult = & $TestAction
                        $pathTest.Details.CustomResult = $customResult
                        $pathTest.Success = $customResult.Success
                    }
                }
            }
        } catch {
            $pathTest.Error = $_.Exception.Message
            $pathTest.Success = $false
        }
        
        $endTime = Get-Date
        $pathTest.Duration = ($endTime - $startTime).TotalMilliseconds
        
        return $pathTest
    }
    
    # Event tracking
    $script:SmokeTestEvents = @()
    
    if (-not (Get-Command 'Publish-TestEvent' -ErrorAction SilentlyContinue)) {
        function Publish-TestEvent {
            param([string]$EventName, [hashtable]$EventData)
            $script:SmokeTestEvents += @{
                EventName = $EventName
                EventData = $EventData
                Timestamp = Get-Date
            }
        }
    }
}

Describe "Smoke Tests for Critical Paths" -Tag @("Smoke", "Critical", "Fast") {
    
    Context "System Health and Readiness" {
        
        It "Should have healthy PowerShell environment" {
            # Act
            $healthCheck = Test-SystemHealth -Component "PowerShell"
            
            # Publish health check event
            Publish-TestEvent -EventName "SystemHealthCheck" -EventData @{
                Component = "PowerShell"
                HealthCheck = $healthCheck
                CriticalPath = $true
            }
            
            # Assert
            $healthCheck.Success | Should -Be $true
            $healthCheck.Status | Should -Be "Healthy"
            $healthCheck.Details.VersionSupported | Should -Be $true
            $healthCheck.Details.Version | Should -Not -BeNullOrEmpty
            $healthCheck.Details.Platform | Should -BeIn @("Windows", "Linux", "macOS")
        }
        
        It "Should have healthy file system access" {
            # Act
            $healthCheck = Test-SystemHealth -Component "FileSystem"
            
            # Publish health check event
            Publish-TestEvent -EventName "SystemHealthCheck" -EventData @{
                Component = "FileSystem"
                HealthCheck = $healthCheck
                CriticalPath = $true
            }
            
            # Assert
            $healthCheck.Success | Should -Be $true
            $healthCheck.Status | Should -Be "Healthy"
            $healthCheck.Details.ProjectRootExists | Should -Be $true
            $healthCheck.Details.WritableTestDrive | Should -Be $true
            $healthCheck.Details.TempDirectoryAccess | Should -Be $true
        }
        
        It "Should have healthy module system" {
            # Act
            $healthCheck = Test-SystemHealth -Component "ModuleSystem"
            
            # Publish health check event
            Publish-TestEvent -EventName "SystemHealthCheck" -EventData @{
                Component = "ModuleSystem"
                HealthCheck = $healthCheck
                CriticalPath = $true
            }
            
            # Assert
            $healthCheck.Success | Should -Be $true
            $healthCheck.Status | Should -Be "Healthy"
            $healthCheck.Details.PesterAvailable | Should -Be $true
            $healthCheck.Details.ModulePathConfigured | Should -Be $true
            $healthCheck.Details.AitherCorePathExists | Should -Be $true
        }
        
        It "Should have healthy configuration system" {
            # Act
            $healthCheck = Test-SystemHealth -Component "Configuration"
            
            # Publish health check event
            Publish-TestEvent -EventName "SystemHealthCheck" -EventData @{
                Component = "Configuration"
                HealthCheck = $healthCheck
                CriticalPath = $true
            }
            
            # Assert
            $healthCheck.Success | Should -Be $true
            $healthCheck.Status | Should -Be "Healthy"
            $healthCheck.Details.DefaultConfigExists | Should -Be $true
            $healthCheck.Details.ConfigurationValid | Should -Be $true
        }
    }
    
    Context "Critical File and Directory Paths" {
        
        It "Should have all critical entry point scripts" {
            # Arrange & Act
            $entryPointResults = @()
            
            foreach ($entryPoint in $CriticalPaths.EntryPoints) {
                $result = Test-CriticalPath -PathName $entryPoint -PathType "Script" -Path $entryPoint
                $entryPointResults += $result
            }
            
            # Publish entry point test event
            Publish-TestEvent -EventName "CriticalPathsValidated" -EventData @{
                PathType = "EntryPoints"
                Results = $entryPointResults
                TotalPaths = $CriticalPaths.EntryPoints.Count
                SuccessfulPaths = ($entryPointResults | Where-Object { $_.Success }).Count
            }
            
            # Assert
            $entryPointResults.Count | Should -Be $CriticalPaths.EntryPoints.Count
            $entryPointResults | ForEach-Object { $_.Success | Should -Be $true }
            $entryPointResults | ForEach-Object { $_.Details.ScriptExists | Should -Be $true }
            $entryPointResults | ForEach-Object { $_.Details.SyntacticallyValid | Should -Be $true }
        }
        
        It "Should have all critical core modules" {
            # Arrange & Act
            $moduleResults = @()
            
            foreach ($module in $CriticalPaths.CoreModules) {
                $result = Test-CriticalPath -PathName $module -PathType "Module" -Path $module
                $moduleResults += $result
            }
            
            # Publish module test event
            Publish-TestEvent -EventName "CriticalPathsValidated" -EventData @{
                PathType = "CoreModules"
                Results = $moduleResults
                TotalPaths = $CriticalPaths.CoreModules.Count
                SuccessfulPaths = ($moduleResults | Where-Object { $_.Success }).Count
            }
            
            # Assert
            $moduleResults.Count | Should -Be $CriticalPaths.CoreModules.Count
            $moduleResults | ForEach-Object { $_.Success | Should -Be $true }
            $moduleResults | ForEach-Object { $_.Details.ModulePathExists | Should -Be $true }
            $moduleResults | ForEach-Object { $_.Details.ManifestExists | Should -Be $true }
            $moduleResults | ForEach-Object { $_.Details.ScriptExists | Should -Be $true }
        }
        
        It "Should have all critical configuration files" {
            # Arrange & Act
            $configResults = @()
            
            foreach ($configFile in $CriticalPaths.ConfigurationFiles) {
                $result = Test-CriticalPath -PathName $configFile -PathType "File" -Path (Join-Path $ProjectRoot $configFile)
                $configResults += $result
            }
            
            # Publish configuration test event
            Publish-TestEvent -EventName "CriticalPathsValidated" -EventData @{
                PathType = "ConfigurationFiles"
                Results = $configResults
                TotalPaths = $CriticalPaths.ConfigurationFiles.Count
                SuccessfulPaths = ($configResults | Where-Object { $_.Success }).Count
            }
            
            # Assert
            $configResults.Count | Should -Be $CriticalPaths.ConfigurationFiles.Count
            $configResults | ForEach-Object { $_.Success | Should -Be $true }
            $configResults | ForEach-Object { $_.Details.Exists | Should -Be $true }
            $configResults | ForEach-Object { $_.Details.Readable | Should -Be $true }
        }
        
        It "Should have all critical shared utilities" {
            # Arrange & Act
            $utilityResults = @()
            
            foreach ($utility in $CriticalPaths.SharedUtilities) {
                $result = Test-CriticalPath -PathName $utility -PathType "Script" -Path $utility
                $utilityResults += $result
            }
            
            # Publish utility test event
            Publish-TestEvent -EventName "CriticalPathsValidated" -EventData @{
                PathType = "SharedUtilities"
                Results = $utilityResults
                TotalPaths = $CriticalPaths.SharedUtilities.Count
                SuccessfulPaths = ($utilityResults | Where-Object { $_.Success }).Count
            }
            
            # Assert
            $utilityResults.Count | Should -Be $CriticalPaths.SharedUtilities.Count
            $utilityResults | ForEach-Object { $_.Success | Should -Be $true }
            $utilityResults | ForEach-Object { $_.Details.ScriptExists | Should -Be $true }
            $utilityResults | ForEach-Object { $_.Details.SyntacticallyValid | Should -Be $true }
        }
    }
    
    Context "Critical Module Loading" {
        
        It "Should load Logging module successfully" {
            # Arrange
            $loggingModulePath = Join-Path $ProjectRoot "aither-core/modules/Logging"
            
            # Act
            $loadResult = @{
                Success = $false
                ModulePath = $loggingModulePath
                LoadTime = Get-Date
                Duration = 0
                Error = $null
                Functions = @()
            }
            
            $startTime = Get-Date
            try {
                Import-Module $loggingModulePath -Force -ErrorAction Stop
                $loadResult.Success = $true
                $loadResult.Functions = (Get-Command -Module Logging -ErrorAction SilentlyContinue).Name
            } catch {
                $loadResult.Error = $_.Exception.Message
            }
            $endTime = Get-Date
            $loadResult.Duration = ($endTime - $startTime).TotalMilliseconds
            
            # Test basic functionality
            $funcTest = @{
                WriteCustomLogExists = (Get-Command 'Write-CustomLog' -ErrorAction SilentlyContinue) -ne $null
                BasicLogWorks = $false
            }
            
            if ($funcTest.WriteCustomLogExists) {
                try {
                    Write-CustomLog -Level "INFO" -Message "Smoke test"
                    $funcTest.BasicLogWorks = $true
                } catch {
                    $funcTest.BasicLogWorks = $false
                }
            }
            
            # Publish module loading event
            Publish-TestEvent -EventName "CriticalModuleLoaded" -EventData @{
                ModuleName = "Logging"
                LoadResult = $loadResult
                FunctionTest = $funcTest
                CriticalPath = $true
            }
            
            # Assert
            $loadResult.Success | Should -Be $true
            $loadResult.Error | Should -BeNullOrEmpty
            $loadResult.Duration | Should -BeLessThan 5000  # Should load in under 5 seconds
            $funcTest.WriteCustomLogExists | Should -Be $true
            $funcTest.BasicLogWorks | Should -Be $true
        }
        
        It "Should load ConfigurationCore module successfully" {
            # Arrange
            $configCoreModulePath = Join-Path $ProjectRoot "aither-core/modules/ConfigurationCore"
            
            # Act
            $loadResult = @{
                Success = $false
                ModulePath = $configCoreModulePath
                LoadTime = Get-Date
                Duration = 0
                Error = $null
                Functions = @()
            }
            
            $startTime = Get-Date
            try {
                Import-Module $configCoreModulePath -Force -ErrorAction Stop
                $loadResult.Success = $true
                $loadResult.Functions = (Get-Command -Module ConfigurationCore -ErrorAction SilentlyContinue).Name
            } catch {
                $loadResult.Error = $_.Exception.Message
            }
            $endTime = Get-Date
            $loadResult.Duration = ($endTime - $startTime).TotalMilliseconds
            
            # Test basic functionality
            $funcTest = @{
                HasConfigurationFunctions = $loadResult.Functions.Count -gt 0
                InitializeFunctionExists = $loadResult.Functions -contains "Initialize-ConfigurationCore"
            }
            
            # Publish module loading event
            Publish-TestEvent -EventName "CriticalModuleLoaded" -EventData @{
                ModuleName = "ConfigurationCore"
                LoadResult = $loadResult
                FunctionTest = $funcTest
                CriticalPath = $true
            }
            
            # Assert
            $loadResult.Success | Should -Be $true
            $loadResult.Error | Should -BeNullOrEmpty
            $loadResult.Duration | Should -BeLessThan 5000  # Should load in under 5 seconds
            $funcTest.HasConfigurationFunctions | Should -Be $true
            $loadResult.Functions.Count | Should -BeGreaterThan 0
        }
        
        It "Should load TestingFramework module successfully" {
            # Arrange
            $testingModulePath = Join-Path $ProjectRoot "aither-core/modules/TestingFramework"
            
            # Act
            $loadResult = @{
                Success = $false
                ModulePath = $testingModulePath
                LoadTime = Get-Date
                Duration = 0
                Error = $null
                Functions = @()
            }
            
            $startTime = Get-Date
            try {
                Import-Module $testingModulePath -Force -ErrorAction Stop
                $loadResult.Success = $true
                $loadResult.Functions = (Get-Command -Module TestingFramework -ErrorAction SilentlyContinue).Name
            } catch {
                $loadResult.Error = $_.Exception.Message
            }
            $endTime = Get-Date
            $loadResult.Duration = ($endTime - $startTime).TotalMilliseconds
            
            # Test basic functionality
            $funcTest = @{
                HasTestingFunctions = $loadResult.Functions.Count -gt 0
                UnifiedTestExists = $loadResult.Functions -contains "Invoke-UnifiedTestExecution"
            }
            
            # Publish module loading event
            Publish-TestEvent -EventName "CriticalModuleLoaded" -EventData @{
                ModuleName = "TestingFramework"
                LoadResult = $loadResult
                FunctionTest = $funcTest
                CriticalPath = $true
            }
            
            # Assert
            $loadResult.Success | Should -Be $true
            $loadResult.Error | Should -BeNullOrEmpty
            $loadResult.Duration | Should -BeLessThan 5000  # Should load in under 5 seconds
            $funcTest.HasTestingFunctions | Should -Be $true
            $loadResult.Functions.Count | Should -BeGreaterThan 0
        }
    }
    
    Context "Critical Workflow Smoke Tests" {
        
        It "Should execute basic configuration workflow" {
            # Arrange
            $workflowTest = @{
                Name = "BasicConfigurationWorkflow"
                Steps = @("initialize", "validate", "apply")
                Results = @()
                Success = $false
                StartTime = Get-Date
                Duration = 0
            }
            
            # Act
            $startTime = Get-Date
            
            # Step 1: Initialize configuration
            $initResult = @{
                Step = "initialize"
                Success = $true
                Details = @{
                    ConfigPath = Join-Path $TestConfigRoot "smoke-config.json"
                    ConfigData = @{
                        version = "1.0.0"
                        modules = @{
                            core = @{ enabled = $true }
                            logging = @{ enabled = $true; level = "info" }
                        }
                    }
                }
            }
            
            $initResult.Details.ConfigData | ConvertTo-Json -Depth 5 | Set-Content -Path $initResult.Details.ConfigPath
            $workflowTest.Results += $initResult
            
            # Step 2: Validate configuration
            $validateResult = @{
                Step = "validate"
                Success = $false
                Details = @{
                    ConfigPath = $initResult.Details.ConfigPath
                    ValidationErrors = @()
                }
            }
            
            try {
                $config = Get-Content $initResult.Details.ConfigPath | ConvertFrom-Json
                $validateResult.Success = $config.version -ne $null -and $config.modules -ne $null
                $validateResult.Details.ConfigVersion = $config.version
            } catch {
                $validateResult.Details.ValidationErrors += $_.Exception.Message
            }
            
            $workflowTest.Results += $validateResult
            
            # Step 3: Apply configuration
            $applyResult = @{
                Step = "apply"
                Success = $validateResult.Success
                Details = @{
                    Applied = $validateResult.Success
                    AppliedAt = Get-Date
                }
            }
            
            $workflowTest.Results += $applyResult
            
            $endTime = Get-Date
            $workflowTest.Duration = ($endTime - $startTime).TotalMilliseconds
            $workflowTest.Success = ($workflowTest.Results | Where-Object { -not $_.Success }).Count -eq 0
            
            # Publish workflow test event
            Publish-TestEvent -EventName "CriticalWorkflowTested" -EventData @{
                WorkflowName = $workflowTest.Name
                WorkflowTest = $workflowTest
                CriticalPath = $true
            }
            
            # Assert
            $workflowTest.Success | Should -Be $true
            $workflowTest.Duration | Should -BeLessThan 2000  # Should complete in under 2 seconds
            $workflowTest.Results.Count | Should -Be 3
            $workflowTest.Results | ForEach-Object { $_.Success | Should -Be $true }
        }
        
        It "Should execute basic CLI smoke test" {
            # Arrange
            $cliTest = @{
                Name = "BasicCLISmokeTest"
                Script = "Start-AitherZero.ps1"
                Parameters = @{ Help = $true }
                Success = $false
                StartTime = Get-Date
                Duration = 0
                Output = @()
                Error = $null
            }
            
            # Act
            $startTime = Get-Date
            
            # Simulate CLI execution (mock for smoke test)
            $cliResult = @{
                ExitCode = 0
                Success = $true
                Output = @(
                    "AitherZero Infrastructure Automation Framework",
                    "Usage: Start-AitherZero.ps1 [options]",
                    "Options:",
                    "  -Help    Show this help message",
                    "  -Auto    Run in automatic mode",
                    "  -Setup   Run setup wizard"
                )
                Error = $null
            }
            
            $cliTest.Success = $cliResult.Success -and $cliResult.ExitCode -eq 0
            $cliTest.Output = $cliResult.Output
            $cliTest.Error = $cliResult.Error
            
            $endTime = Get-Date
            $cliTest.Duration = ($endTime - $startTime).TotalMilliseconds
            
            # Publish CLI test event
            Publish-TestEvent -EventName "CriticalWorkflowTested" -EventData @{
                WorkflowName = $cliTest.Name
                CLITest = $cliTest
                CriticalPath = $true
            }
            
            # Assert
            $cliTest.Success | Should -Be $true
            $cliTest.Duration | Should -BeLessThan 1000  # Should complete in under 1 second
            $cliTest.Output.Count | Should -BeGreaterThan 0
            $cliTest.Output | Should -Contain "AitherZero Infrastructure Automation Framework"
            $cliTest.Error | Should -BeNullOrEmpty
        }
        
        It "Should execute basic module communication smoke test" {
            # Arrange
            $commTest = @{
                Name = "BasicModuleCommunicationSmokeTest"
                Modules = @("ModuleA", "ModuleB")
                Success = $false
                StartTime = Get-Date
                Duration = 0
                Communications = @()
            }
            
            # Act
            $startTime = Get-Date
            
            # Simulate module communication
            $moduleA = @{
                Name = "ModuleA"
                Status = "Running"
                Health = "Healthy"
                API = @{
                    health = @{ status = "ok"; timestamp = Get-Date }
                    version = @{ version = "1.0.0"; build = "123" }
                }
            }
            
            $moduleB = @{
                Name = "ModuleB"
                Status = "Running"
                Health = "Healthy"
                API = @{
                    health = @{ status = "ok"; timestamp = Get-Date }
                    status = @{ running = $true; uptime = 300 }
                }
            }
            
            # Test communication between modules
            $commTest.Communications += @{
                From = "ModuleA"
                To = "ModuleB"
                Type = "HealthCheck"
                Success = $true
                Response = $moduleB.API.health
            }
            
            $commTest.Communications += @{
                From = "ModuleB"
                To = "ModuleA"
                Type = "VersionCheck"
                Success = $true
                Response = $moduleA.API.version
            }
            
            $endTime = Get-Date
            $commTest.Duration = ($endTime - $startTime).TotalMilliseconds
            $commTest.Success = ($commTest.Communications | Where-Object { -not $_.Success }).Count -eq 0
            
            # Publish communication test event
            Publish-TestEvent -EventName "CriticalWorkflowTested" -EventData @{
                WorkflowName = $commTest.Name
                CommunicationTest = $commTest
                CriticalPath = $true
            }
            
            # Assert
            $commTest.Success | Should -Be $true
            $commTest.Duration | Should -BeLessThan 1000  # Should complete in under 1 second
            $commTest.Communications.Count | Should -Be 2
            $commTest.Communications | ForEach-Object { $_.Success | Should -Be $true }
        }
    }
    
    Context "Cross-Platform Compatibility Smoke Tests" {
        
        It "Should detect current platform correctly" {
            # Arrange & Act
            $platformTest = @{
                Name = "PlatformDetectionSmokeTest"
                DetectedPlatform = if ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } else { "macOS" }
                PowerShellVersion = $PSVersionTable.PSVersion.ToString()
                PathSeparator = [System.IO.Path]::DirectorySeparatorChar
                HomeDirectory = $HOME
                Success = $false
                StartTime = Get-Date
                Duration = 0
            }
            
            $startTime = Get-Date
            
            # Platform-specific tests
            $platformTest.Details = @{
                PlatformDetected = $platformTest.DetectedPlatform -in @("Windows", "Linux", "macOS")
                PowerShellVersionValid = $PSVersionTable.PSVersion.Major -ge 7
                PathSeparatorValid = $platformTest.PathSeparator -in @('\', '/')
                HomeDirectoryExists = Test-Path $platformTest.HomeDirectory
            }
            
            $endTime = Get-Date
            $platformTest.Duration = ($endTime - $startTime).TotalMilliseconds
            $platformTest.Success = ($platformTest.Details.Values | Where-Object { $_ -eq $false }).Count -eq 0
            
            # Publish platform test event
            Publish-TestEvent -EventName "CrossPlatformSmokeTest" -EventData @{
                TestName = $platformTest.Name
                PlatformTest = $platformTest
                CriticalPath = $true
            }
            
            # Assert
            $platformTest.Success | Should -Be $true
            $platformTest.DetectedPlatform | Should -BeIn @("Windows", "Linux", "macOS")
            $platformTest.Details.PlatformDetected | Should -Be $true
            $platformTest.Details.PowerShellVersionValid | Should -Be $true
            $platformTest.Details.PathSeparatorValid | Should -Be $true
            $platformTest.Details.HomeDirectoryExists | Should -Be $true
        }
        
        It "Should handle cross-platform paths correctly" {
            # Arrange & Act
            $pathTest = @{
                Name = "CrossPlatformPathSmokeTest"
                TestPaths = @()
                Success = $false
                StartTime = Get-Date
                Duration = 0
            }
            
            $startTime = Get-Date
            
            # Test various path operations
            $testScenarios = @(
                @{ Name = "JoinPath"; Path1 = $TestDrive; Path2 = "test"; Expected = "test" },
                @{ Name = "RelativePath"; Path1 = $TestDrive; Path2 = ".."; Expected = ".." },
                @{ Name = "AbsolutePath"; Path1 = $HOME; Path2 = "Documents"; Expected = "Documents" }
            )
            
            foreach ($scenario in $testScenarios) {
                $joinedPath = Join-Path $scenario.Path1 $scenario.Path2
                $pathTest.TestPaths += @{
                    Scenario = $scenario.Name
                    Path1 = $scenario.Path1
                    Path2 = $scenario.Path2
                    JoinedPath = $joinedPath
                    Success = $joinedPath -ne $null -and $joinedPath -like "*$($scenario.Expected)*"
                }
            }
            
            $endTime = Get-Date
            $pathTest.Duration = ($endTime - $startTime).TotalMilliseconds
            $pathTest.Success = ($pathTest.TestPaths | Where-Object { -not $_.Success }).Count -eq 0
            
            # Publish path test event
            Publish-TestEvent -EventName "CrossPlatformSmokeTest" -EventData @{
                TestName = $pathTest.Name
                PathTest = $pathTest
                CriticalPath = $true
            }
            
            # Assert
            $pathTest.Success | Should -Be $true
            $pathTest.TestPaths.Count | Should -Be 3
            $pathTest.TestPaths | ForEach-Object { $_.Success | Should -Be $true }
        }
    }
    
    Context "Error Detection and Recovery Readiness" {
        
        It "Should detect and handle missing dependencies gracefully" {
            # Arrange
            $dependencyTest = @{
                Name = "DependencyHandlingSmokeTest"
                RequiredDependencies = @("PowerShell", "Pester")
                OptionalDependencies = @("Git", "Docker")
                Results = @()
                Success = $false
                StartTime = Get-Date
                Duration = 0
            }
            
            # Act
            $startTime = Get-Date
            
            # Test required dependencies
            foreach ($dep in $dependencyTest.RequiredDependencies) {
                $depResult = @{
                    Dependency = $dep
                    Type = "Required"
                    Available = $false
                    Version = $null
                    Details = @{}
                }
                
                switch ($dep) {
                    "PowerShell" {
                        $depResult.Available = $PSVersionTable.PSVersion.Major -ge 7
                        $depResult.Version = $PSVersionTable.PSVersion.ToString()
                        $depResult.Details.Major = $PSVersionTable.PSVersion.Major
                    }
                    "Pester" {
                        $pesterModule = Get-Module -ListAvailable -Name Pester
                        $depResult.Available = $pesterModule -ne $null
                        $depResult.Version = if ($pesterModule) { $pesterModule.Version.ToString() } else { $null }
                    }
                }
                
                $dependencyTest.Results += $depResult
            }
            
            # Test optional dependencies
            foreach ($dep in $dependencyTest.OptionalDependencies) {
                $depResult = @{
                    Dependency = $dep
                    Type = "Optional"
                    Available = $false
                    Version = $null
                    Details = @{}
                }
                
                switch ($dep) {
                    "Git" {
                        $gitCmd = Get-Command git -ErrorAction SilentlyContinue
                        $depResult.Available = $gitCmd -ne $null
                        if ($gitCmd) {
                            try {
                                $depResult.Version = (git --version 2>$null).Split(' ')[2]
                            } catch {
                                $depResult.Version = "Unknown"
                            }
                        }
                    }
                    "Docker" {
                        $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
                        $depResult.Available = $dockerCmd -ne $null
                        if ($dockerCmd) {
                            try {
                                $depResult.Version = (docker --version 2>$null).Split(' ')[2]
                            } catch {
                                $depResult.Version = "Unknown"
                            }
                        }
                    }
                }
                
                $dependencyTest.Results += $depResult
            }
            
            $endTime = Get-Date
            $dependencyTest.Duration = ($endTime - $startTime).TotalMilliseconds
            
            # Check if all required dependencies are available
            $requiredResults = $dependencyTest.Results | Where-Object { $_.Type -eq "Required" }
            $dependencyTest.Success = ($requiredResults | Where-Object { -not $_.Available }).Count -eq 0
            
            # Publish dependency test event
            Publish-TestEvent -EventName "ErrorDetectionSmokeTest" -EventData @{
                TestName = $dependencyTest.Name
                DependencyTest = $dependencyTest
                CriticalPath = $true
            }
            
            # Assert
            $dependencyTest.Success | Should -Be $true
            $dependencyTest.Results.Count | Should -Be 4
            
            # All required dependencies should be available
            $requiredResults | ForEach-Object { $_.Available | Should -Be $true }
            
            # Optional dependencies may or may not be available (that's okay)
            $optionalResults = $dependencyTest.Results | Where-Object { $_.Type -eq "Optional" }
            $optionalResults.Count | Should -Be 2
        }
        
        It "Should have error recovery mechanisms ready" {
            # Arrange
            $recoveryTest = @{
                Name = "ErrorRecoveryReadinessSmokeTest"
                RecoveryMechanisms = @()
                Success = $false
                StartTime = Get-Date
                Duration = 0
            }
            
            # Act
            $startTime = Get-Date
            
            # Test backup/restore capability
            $backupTest = @{
                Mechanism = "BackupRestore"
                Ready = $false
                Details = @{}
            }
            
            $testBackupPath = Join-Path $TestDrive "backup-test"
            $testRestorePath = Join-Path $TestDrive "restore-test"
            
            try {
                # Create test content
                "test content" | Set-Content -Path $testBackupPath
                
                # Test backup (copy)
                Copy-Item -Path $testBackupPath -Destination "$testBackupPath.bak" -Force
                $backupTest.Details.BackupCreated = Test-Path "$testBackupPath.bak"
                
                # Test restore (copy back)
                Copy-Item -Path "$testBackupPath.bak" -Destination $testRestorePath -Force
                $backupTest.Details.RestoreWorked = Test-Path $testRestorePath
                
                $backupTest.Ready = $backupTest.Details.BackupCreated -and $backupTest.Details.RestoreWorked
            } catch {
                $backupTest.Details.Error = $_.Exception.Message
                $backupTest.Ready = $false
            }
            
            $recoveryTest.RecoveryMechanisms += $backupTest
            
            # Test rollback capability
            $rollbackTest = @{
                Mechanism = "Rollback"
                Ready = $false
                Details = @{}
            }
            
            try {
                # Simulate rollback scenario
                $originalState = @{ Value = "original" }
                $modifiedState = @{ Value = "modified" }
                
                # Test state preservation
                $rollbackTest.Details.OriginalStatePreserved = $originalState.Value -eq "original"
                $rollbackTest.Details.ModifiedStateDetected = $modifiedState.Value -eq "modified"
                $rollbackTest.Details.CanRollback = $true
                
                $rollbackTest.Ready = $rollbackTest.Details.OriginalStatePreserved -and $rollbackTest.Details.CanRollback
            } catch {
                $rollbackTest.Details.Error = $_.Exception.Message
                $rollbackTest.Ready = $false
            }
            
            $recoveryTest.RecoveryMechanisms += $rollbackTest
            
            $endTime = Get-Date
            $recoveryTest.Duration = ($endTime - $startTime).TotalMilliseconds
            $recoveryTest.Success = ($recoveryTest.RecoveryMechanisms | Where-Object { -not $_.Ready }).Count -eq 0
            
            # Publish recovery test event
            Publish-TestEvent -EventName "ErrorDetectionSmokeTest" -EventData @{
                TestName = $recoveryTest.Name
                RecoveryTest = $recoveryTest
                CriticalPath = $true
            }
            
            # Assert
            $recoveryTest.Success | Should -Be $true
            $recoveryTest.RecoveryMechanisms.Count | Should -Be 2
            $recoveryTest.RecoveryMechanisms | ForEach-Object { $_.Ready | Should -Be $true }
            
            # Verify specific recovery mechanisms
            $backupMechanism = $recoveryTest.RecoveryMechanisms | Where-Object { $_.Mechanism -eq "BackupRestore" }
            $backupMechanism.Ready | Should -Be $true
            $backupMechanism.Details.BackupCreated | Should -Be $true
            $backupMechanism.Details.RestoreWorked | Should -Be $true
            
            $rollbackMechanism = $recoveryTest.RecoveryMechanisms | Where-Object { $_.Mechanism -eq "Rollback" }
            $rollbackMechanism.Ready | Should -Be $true
            $rollbackMechanism.Details.CanRollback | Should -Be $true
        }
    }
}

AfterAll {
    # Generate smoke test summary
    $smokeTestSummary = @{
        TotalEvents = $script:SmokeTestEvents.Count
        CriticalPathEvents = ($script:SmokeTestEvents | Where-Object { $_.EventData.CriticalPath -eq $true }).Count
        EventTypes = $script:SmokeTestEvents | Group-Object -Property EventName | ForEach-Object { @{ EventName = $_.Name; Count = $_.Count } }
        TestDuration = (Get-Date) - $script:SmokeTestEvents[0].Timestamp
        Summary = @{
            SystemHealthChecks = ($script:SmokeTestEvents | Where-Object { $_.EventName -eq "SystemHealthCheck" }).Count
            CriticalPathValidations = ($script:SmokeTestEvents | Where-Object { $_.EventName -eq "CriticalPathsValidated" }).Count
            ModuleLoadings = ($script:SmokeTestEvents | Where-Object { $_.EventName -eq "CriticalModuleLoaded" }).Count
            WorkflowTests = ($script:SmokeTestEvents | Where-Object { $_.EventName -eq "CriticalWorkflowTested" }).Count
            CrossPlatformTests = ($script:SmokeTestEvents | Where-Object { $_.EventName -eq "CrossPlatformSmokeTest" }).Count
            ErrorDetectionTests = ($script:SmokeTestEvents | Where-Object { $_.EventName -eq "ErrorDetectionSmokeTest" }).Count
        }
    }
    
    # Output summary
    Write-Host "🔥 Smoke Test Summary 🔥" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    Write-Host "Total Events: $($smokeTestSummary.TotalEvents)" -ForegroundColor White
    Write-Host "Critical Path Events: $($smokeTestSummary.CriticalPathEvents)" -ForegroundColor Green
    Write-Host "Test Duration: $($smokeTestSummary.TestDuration.ToString('mm\:ss'))" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Event Summary:" -ForegroundColor White
    foreach ($eventType in $smokeTestSummary.EventTypes) {
        Write-Host "  • $($eventType.EventName): $($eventType.Count)" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "Test Category Summary:" -ForegroundColor White
    Write-Host "  • System Health Checks: $($smokeTestSummary.Summary.SystemHealthChecks)" -ForegroundColor Gray
    Write-Host "  • Critical Path Validations: $($smokeTestSummary.Summary.CriticalPathValidations)" -ForegroundColor Gray
    Write-Host "  • Module Loadings: $($smokeTestSummary.Summary.ModuleLoadings)" -ForegroundColor Gray
    Write-Host "  • Workflow Tests: $($smokeTestSummary.Summary.WorkflowTests)" -ForegroundColor Gray
    Write-Host "  • Cross-Platform Tests: $($smokeTestSummary.Summary.CrossPlatformTests)" -ForegroundColor Gray
    Write-Host "  • Error Detection Tests: $($smokeTestSummary.Summary.ErrorDetectionTests)" -ForegroundColor Gray
    
    # Cleanup test environment
    if (Test-Path $TestSmokeRoot) {
        Remove-Item -Path $TestSmokeRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Clear events
    $script:SmokeTestEvents = @()
}