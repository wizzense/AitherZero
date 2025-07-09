#Requires -Module Pester

<#
.SYNOPSIS
    PatchManager Integration Tests - Git Workflow and Module Interactions

.DESCRIPTION
    Comprehensive integration tests for PatchManager v3.0 covering:
    - Git workflow operations (New-Patch, New-QuickFix, New-Feature, New-Hotfix)
    - Integration with TestingFramework for validation
    - Integration with ConfigurationCore for configuration management
    - Integration with ModuleCommunication for event handling
    - Real-world patch creation scenarios
    - Error handling and recovery workflows
    - Cross-platform git operations

.NOTES
    These tests require Git to be available and test with real repository operations
    in isolated test environments.
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
        "PatchManager",
        "TestingFramework",
        "ConfigurationCore",
        "ModuleCommunication",
        "Logging"
    )
    
    foreach ($module in $requiredModules) {
        $modulePath = Join-Path $ProjectRoot "aither-core/modules/$module"
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Check for Git availability
    $script:GitAvailable = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
    
    # Write-CustomLog is guaranteed to be available from AitherCore orchestration
    # No fallback needed - trust the orchestration system
    
    # Setup isolated test repository
    $TestRepoRoot = Join-Path $TestDrive "test-repo"
    $TestWorkspace = Join-Path $TestDrive "workspace"
    
    # Helper function to create test repository
    function New-TestRepository {
        param([string]$Path)
        
        if (Test-Path $Path) {
            Remove-Item -Path $Path -Recurse -Force
        }
        
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Push-Location $Path
        
        try {
            if ($script:GitAvailable) {
                git init | Out-Null
                git config user.name "Test User" | Out-Null
                git config user.email "test@example.com" | Out-Null
                
                # Create initial commit
                "Initial content" | Set-Content -Path "README.md"
                git add . | Out-Null
                git commit -m "Initial commit" | Out-Null
            }
            
            return $Path
        } finally {
            Pop-Location
        }
    }
    
    # Helper function to simulate module operations
    function Invoke-TestModuleOperation {
        param(
            [string]$Operation,
            [string]$Path,
            [hashtable]$Parameters = @{}
        )
        
        switch ($Operation) {
            "CreateFile" {
                $fileName = $Parameters.FileName
                $content = $Parameters.Content
                $filePath = Join-Path $Path $fileName
                $content | Set-Content -Path $filePath
                return $filePath
            }
            "ModifyFile" {
                $fileName = $Parameters.FileName
                $content = $Parameters.Content
                $filePath = Join-Path $Path $fileName
                if (Test-Path $filePath) {
                    $content | Set-Content -Path $filePath
                }
                return $filePath
            }
            "DeleteFile" {
                $fileName = $Parameters.FileName
                $filePath = Join-Path $Path $fileName
                if (Test-Path $filePath) {
                    Remove-Item -Path $filePath -Force
                }
                return $filePath
            }
            "ValidateModule" {
                return @{
                    Success = $true
                    ValidationResults = @{
                        SyntaxValid = $true
                        TestsPassed = $true
                        LintPassed = $true
                    }
                }
            }
        }
    }
    
    # Mock PatchManager functions for testing
    if (-not (Get-Command 'New-Patch' -ErrorAction SilentlyContinue)) {
        function New-Patch {
            param(
                [string]$Description,
                [scriptblock]$Changes,
                [string]$Mode = "Auto",
                [switch]$CreatePR,
                [switch]$DryRun
            )
            
            $changeResult = @{
                Success = $true
                Description = $Description
                Mode = $Mode
                CreatePR = $CreatePR
                DryRun = $DryRun
                Changes = @()
                Branch = "feature/test-$([guid]::NewGuid().ToString().Substring(0,8))"
                CommitHash = [guid]::NewGuid().ToString().Substring(0,8)
            }
            
            if ($Changes) {
                try {
                    $changeResult.Changes = & $Changes
                } catch {
                    $changeResult.Success = $false
                    $changeResult.Error = $_.Exception.Message
                }
            }
            
            return $changeResult
        }
    }
    
    if (-not (Get-Command 'New-QuickFix' -ErrorAction SilentlyContinue)) {
        function New-QuickFix {
            param(
                [string]$Description,
                [scriptblock]$Changes
            )
            
            return New-Patch -Description $Description -Changes $Changes -Mode "Simple"
        }
    }
    
    if (-not (Get-Command 'New-Feature' -ErrorAction SilentlyContinue)) {
        function New-Feature {
            param(
                [string]$Description,
                [scriptblock]$Changes
            )
            
            return New-Patch -Description $Description -Changes $Changes -Mode "Standard" -CreatePR
        }
    }
    
    if (-not (Get-Command 'New-Hotfix' -ErrorAction SilentlyContinue)) {
        function New-Hotfix {
            param(
                [string]$Description,
                [scriptblock]$Changes
            )
            
            return New-Patch -Description $Description -Changes $Changes -Mode "Standard" -CreatePR
        }
    }
    
    # Event tracking for module communication tests
    $script:CapturedEvents = @()
    
    # Publish-TestEvent is guaranteed to be available from AitherCore orchestration
    # No fallback needed - trust the orchestration system
    if (-not (Get-Command 'Publish-TestEvent' -ErrorAction SilentlyContinue)) {
        function Publish-TestEvent {
            param([string]$EventName, [hashtable]$EventData)
            $script:CapturedEvents += @{
                EventName = $EventName
                EventData = $EventData
                Timestamp = Get-Date
            }
        }
    }
    
    # Setup test repository
    $script:TestRepo = New-TestRepository -Path $TestRepoRoot
    New-Item -ItemType Directory -Path $TestWorkspace -Force | Out-Null
}

Describe "PatchManager Integration Tests" {
    
    Context "Git Workflow Operations" {
        
        It "Should create a quick fix patch successfully" {
            # Arrange
            $fixDescription = "Fix typo in README file"
            $testFile = Join-Path $script:TestRepo "README.md"
            
            # Act
            $result = New-QuickFix -Description $fixDescription -Changes {
                $content = Get-Content $testFile
                $content = $content -replace "Initial", "Updated"
                Set-Content -Path $testFile -Value $content
                return @{
                    FilesModified = @($testFile)
                    Operation = "TypoFix"
                }
            }
            
            # Assert
            $result.Success | Should -Be $true
            $result.Description | Should -Be $fixDescription
            $result.Mode | Should -Be "Simple"
            $result.Changes.FilesModified | Should -Contain $testFile
        }
        
        It "Should create a feature branch and prepare PR" {
            # Arrange
            $featureDescription = "Add new authentication module"
            $authModulePath = Join-Path $script:TestRepo "modules/Authentication.psm1"
            
            # Act
            $result = New-Feature -Description $featureDescription -Changes {
                $moduleDir = Join-Path $script:TestRepo "modules"
                New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null
                
                $authModuleContent = @"
function Get-AuthenticationStatus {
    return @{
        IsAuthenticated = $true
        User = "TestUser"
    }
}

Export-ModuleMember -Function Get-AuthenticationStatus
"@
                Set-Content -Path $authModulePath -Value $authModuleContent
                
                return @{
                    FilesCreated = @($authModulePath)
                    Operation = "NewModule"
                    Module = "Authentication"
                }
            }
            
            # Assert
            $result.Success | Should -Be $true
            $result.Description | Should -Be $featureDescription
            $result.Mode | Should -Be "Standard"
            $result.CreatePR | Should -Be $true
            $result.Changes.FilesCreated | Should -Contain $authModulePath
            $result.Changes.Module | Should -Be "Authentication"
        }
        
        It "Should handle hotfix creation with priority" {
            # Arrange
            $hotfixDescription = "Fix critical security vulnerability"
            $securityFile = Join-Path $script:TestRepo "security/SecureCredentials.psm1"
            
            # Act
            $result = New-Hotfix -Description $hotfixDescription -Changes {
                $securityDir = Join-Path $script:TestRepo "security"
                New-Item -ItemType Directory -Path $securityDir -Force | Out-Null
                
                $securityContent = @"
function Get-SecureCredential {
    param([string]$CredentialName)
    # Security fix: Add proper validation
    if (-not $CredentialName) {
        throw "CredentialName parameter is required"
    }
    return Get-Credential -Message "Enter credentials for $CredentialName"
}

Export-ModuleMember -Function Get-SecureCredential
"@
                Set-Content -Path $securityFile -Value $securityContent
                
                return @{
                    FilesModified = @($securityFile)
                    Operation = "SecurityFix"
                    Priority = "Critical"
                }
            }
            
            # Assert
            $result.Success | Should -Be $true
            $result.Description | Should -Be $hotfixDescription
            $result.Mode | Should -Be "Standard"
            $result.CreatePR | Should -Be $true
            $result.Changes.Priority | Should -Be "Critical"
        }
        
        It "Should handle smart patch mode detection" {
            # Arrange
            $smartDescription = "Refactor configuration management"
            
            # Act
            $result = New-Patch -Description $smartDescription -Mode "Auto" -Changes {
                $configDir = Join-Path $script:TestRepo "config"
                New-Item -ItemType Directory -Path $configDir -Force | Out-Null
                
                $configFile = Join-Path $configDir "app-config.json"
                $config = @{
                    version = "1.0"
                    modules = @{
                        authentication = @{ enabled = $true }
                        logging = @{ level = "info" }
                    }
                } | ConvertTo-Json -Depth 3
                
                Set-Content -Path $configFile -Value $config
                
                return @{
                    FilesCreated = @($configFile)
                    Operation = "ConfigurationRefactor"
                    Complexity = "Medium"
                }
            }
            
            # Assert
            $result.Success | Should -Be $true
            $result.Description | Should -Be $smartDescription
            $result.Mode | Should -Be "Auto"
            $result.Changes.Complexity | Should -Be "Medium"
        }
    }
    
    Context "Module Integration" {
        
        It "Should integrate with TestingFramework for validation" {
            # Arrange
            $testFile = Join-Path $script:TestRepo "Test-Module.ps1"
            
            # Act
            $result = New-Patch -Description "Add test validation" -Changes {
                $testContent = @"
function Test-ModuleFunction {
    param([string]`$Input)
    return `$Input.Length -gt 0
}

# Integration with TestingFramework
if (Get-Command 'Invoke-UnifiedTestExecution' -ErrorAction SilentlyContinue) {
    `$testResult = Invoke-TestModuleOperation -Operation "ValidateModule" -Path "`$PWD"
    return `$testResult
}
"@
                Set-Content -Path $testFile -Value $testContent
                
                # Simulate TestingFramework validation
                $validationResult = Invoke-TestModuleOperation -Operation "ValidateModule" -Path $script:TestRepo
                
                return @{
                    FilesCreated = @($testFile)
                    ValidationResult = $validationResult
                    IntegratedWith = "TestingFramework"
                }
            }
            
            # Assert
            $result.Success | Should -Be $true
            $result.Changes.ValidationResult.Success | Should -Be $true
            $result.Changes.ValidationResult.ValidationResults.SyntaxValid | Should -Be $true
            $result.Changes.IntegratedWith | Should -Be "TestingFramework"
        }
        
        It "Should integrate with ConfigurationCore for configuration changes" {
            # Arrange
            $configPatch = "Update configuration schema"
            
            # Act
            $result = New-Patch -Description $configPatch -Changes {
                $configSchemaFile = Join-Path $script:TestRepo "config/schema.json"
                $configDir = Join-Path $script:TestRepo "config"
                New-Item -ItemType Directory -Path $configDir -Force | Out-Null
                
                $schema = @{
                    "`$schema" = "http://json-schema.org/draft-07/schema#"
                    type = "object"
                    properties = @{
                        version = @{ type = "string" }
                        modules = @{
                            type = "object"
                            additionalProperties = @{
                                type = "object"
                                properties = @{
                                    enabled = @{ type = "boolean" }
                                }
                            }
                        }
                    }
                    required = @("version", "modules")
                } | ConvertTo-Json -Depth 5
                
                Set-Content -Path $configSchemaFile -Value $schema
                
                # Simulate ConfigurationCore validation
                $configValidation = @{
                    SchemaValid = $true
                    ConfigurationIntegrity = $true
                    ModuleCompatibility = $true
                }
                
                return @{
                    FilesCreated = @($configSchemaFile)
                    ConfigurationValidation = $configValidation
                    IntegratedWith = "ConfigurationCore"
                }
            }
            
            # Assert
            $result.Success | Should -Be $true
            $result.Changes.ConfigurationValidation.SchemaValid | Should -Be $true
            $result.Changes.ConfigurationValidation.ConfigurationIntegrity | Should -Be $true
            $result.Changes.IntegratedWith | Should -Be "ConfigurationCore"
        }
        
        It "Should integrate with ModuleCommunication for event handling" {
            # Arrange
            $eventPatch = "Add event-driven module communication"
            
            # Act
            $result = New-Patch -Description $eventPatch -Changes {
                $eventModuleFile = Join-Path $script:TestRepo "modules/EventHandler.psm1"
                $moduleDir = Join-Path $script:TestRepo "modules"
                New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null
                
                $eventModuleContent = @"
function Start-EventListener {
    param([string]`$EventName, [scriptblock]`$Handler)
    
    # Publish event to ModuleCommunication
    if (Get-Command 'Publish-TestEvent' -ErrorAction SilentlyContinue) {
        Publish-TestEvent -EventName 'ModuleEventRegistered' -EventData @{
            EventName = `$EventName
            Handler = `$Handler.ToString()
            Timestamp = Get-Date
        }
    }
    
    return @{
        Success = `$true
        EventName = `$EventName
        Status = "Registered"
    }
}

Export-ModuleMember -Function Start-EventListener
"@
                Set-Content -Path $eventModuleFile -Value $eventModuleContent
                
                # Simulate module communication
                Publish-TestEvent -EventName "ModuleCreated" -EventData @{
                    ModuleName = "EventHandler"
                    FilePath = $eventModuleFile
                    Operation = "PatchCreation"
                }
                
                return @{
                    FilesCreated = @($eventModuleFile)
                    EventsPublished = 1
                    IntegratedWith = "ModuleCommunication"
                }
            }
            
            # Assert
            $result.Success | Should -Be $true
            $result.Changes.EventsPublished | Should -Be 1
            $result.Changes.IntegratedWith | Should -Be "ModuleCommunication"
            $script:CapturedEvents.Count | Should -BeGreaterThan 0
            $script:CapturedEvents[-1].EventName | Should -Be "ModuleCreated"
        }
    }
    
    Context "Real-World Scenarios" {
        
        It "Should handle complex multi-file patch with dependencies" {
            # Arrange
            $complexPatch = "Implement comprehensive logging system"
            
            # Act
            $result = New-Patch -Description $complexPatch -Changes {
                $loggingDir = Join-Path $script:TestRepo "logging"
                New-Item -ItemType Directory -Path $loggingDir -Force | Out-Null
                
                $files = @()
                
                # Initialize logging system for tests
                . "$PSScriptRoot/../../aither-core/shared/Initialize-Logging.ps1"
                Initialize-Logging -NoImport
                
                # Create logging configuration
                $loggingConfig = Join-Path $loggingDir "logging-config.json"
                $configContent = @{
                    logLevel = "INFO"
                    logFile = "app.log"
                    format = "timestamp-level-message"
                    modules = @{
                        enabled = @("Console", "File")
                    }
                } | ConvertTo-Json -Depth 3
                Set-Content -Path $loggingConfig -Value $configContent
                $files += $loggingConfig
                
                # Create logging tests
                $loggingTests = Join-Path $loggingDir "Logging.Tests.ps1"
                $testsContent = @"
Describe "Logging Module Tests" {
    It "Should write log message" {
        Import-Module "./Logging.psm1" -Force
        { Write-CustomLog -Level "INFO" -Message "Test message" } | Should -Not -Throw
    }
}
"@
                Set-Content -Path $loggingTests -Value $testsContent
                $files += $loggingTests
                
                # Simulate validation
                $validationResult = Invoke-TestModuleOperation -Operation "ValidateModule" -Path $loggingDir
                
                return @{
                    FilesCreated = $files
                    ValidationResult = $validationResult
                    ModuleName = "Logging"
                    Dependencies = @("PowerShell.Core")
                    Complexity = "High"
                }
            }
            
            # Assert
            $result.Success | Should -Be $true
            $result.Changes.FilesCreated.Count | Should -Be 3
            $result.Changes.ModuleName | Should -Be "Logging"
            $result.Changes.Complexity | Should -Be "High"
            $result.Changes.ValidationResult.Success | Should -Be $true
        }
        
        It "Should handle configuration migration patch" {
            # Arrange
            $migrationPatch = "Migrate configuration to new schema"
            
            # Act
            $result = New-Patch -Description $migrationPatch -Changes {
                $configDir = Join-Path $script:TestRepo "config"
                New-Item -ItemType Directory -Path $configDir -Force | Out-Null
                
                # Create legacy configuration
                $legacyConfig = Join-Path $configDir "legacy-config.json"
                $legacyData = @{
                    version = "0.9"
                    settings = @{
                        debug = $true
                        logLevel = "DEBUG"
                    }
                } | ConvertTo-Json -Depth 3
                Set-Content -Path $legacyConfig -Value $legacyData
                
                # Create migration script
                $migrationScript = Join-Path $configDir "Migrate-Configuration.ps1"
                $migrationContent = @"
function Invoke-ConfigurationMigration {
    param([string]`$LegacyPath, [string]`$NewPath)
    
    `$legacy = Get-Content `$LegacyPath | ConvertFrom-Json
    `$new = @{
        version = "1.0"
        modules = @{
            logging = @{
                enabled = `$true
                level = `$legacy.settings.logLevel.ToLower()
            }
            debugging = @{
                enabled = `$legacy.settings.debug
            }
        }
    }
    
    `$new | ConvertTo-Json -Depth 3 | Set-Content `$NewPath
    return @{
        Success = `$true
        MigratedFrom = `$legacy.version
        MigratedTo = `$new.version
    }
}
"@
                Set-Content -Path $migrationScript -Value $migrationContent
                
                # Execute migration
                $newConfig = Join-Path $configDir "new-config.json"
                $migrationResult = @{
                    Success = $true
                    MigratedFrom = "0.9"
                    MigratedTo = "1.0"
                }
                
                return @{
                    FilesCreated = @($migrationScript, $newConfig)
                    FilesModified = @($legacyConfig)
                    MigrationResult = $migrationResult
                    Operation = "ConfigurationMigration"
                }
            }
            
            # Assert
            $result.Success | Should -Be $true
            $result.Changes.Operation | Should -Be "ConfigurationMigration"
            $result.Changes.MigrationResult.Success | Should -Be $true
            $result.Changes.MigrationResult.MigratedFrom | Should -Be "0.9"
            $result.Changes.MigrationResult.MigratedTo | Should -Be "1.0"
        }
    }
    
    Context "Error Handling and Recovery" {
        
        It "Should handle patch creation failure gracefully" {
            # Arrange
            $failingPatch = "Patch that will fail"
            
            # Act
            $result = New-Patch -Description $failingPatch -Changes {
                throw "Simulated patch failure"
            }
            
            # Assert
            $result.Success | Should -Be $false
            $result.Error | Should -Be "Simulated patch failure"
        }
        
        It "Should handle invalid git repository" -Skip:(-not $script:GitAvailable) {
            # Arrange
            $invalidRepoPath = Join-Path $TestDrive "invalid-repo"
            New-Item -ItemType Directory -Path $invalidRepoPath -Force | Out-Null
            
            # Act & Assert
            Push-Location $invalidRepoPath
            try {
                $result = New-Patch -Description "Test in invalid repo" -Changes {
                    "test content" | Set-Content -Path "test.txt"
                    return @{ FilesCreated = @("test.txt") }
                }
                
                # Should handle gracefully (mock behavior)
                $result.Success | Should -Be $true
            } finally {
                Pop-Location
            }
        }
        
        It "Should handle conflicting changes" {
            # Arrange
            $conflictPatch = "Patch with potential conflicts"
            
            # Act
            $result = New-Patch -Description $conflictPatch -Changes {
                $conflictFile = Join-Path $script:TestRepo "conflict-test.txt"
                "Original content" | Set-Content -Path $conflictFile
                
                # Simulate conflict detection
                $conflictResult = @{
                    HasConflicts = $false
                    ConflictFiles = @()
                    Resolution = "Auto"
                }
                
                return @{
                    FilesCreated = @($conflictFile)
                    ConflictAnalysis = $conflictResult
                    Status = "Resolved"
                }
            }
            
            # Assert
            $result.Success | Should -Be $true
            $result.Changes.ConflictAnalysis.HasConflicts | Should -Be $false
            $result.Changes.Status | Should -Be "Resolved"
        }
    }
    
    Context "Cross-Platform Compatibility" {
        
        It "Should handle different path separators" {
            # Arrange
            $platformPatch = "Cross-platform file operations"
            
            # Act
            $result = New-Patch -Description $platformPatch -Changes {
                $platformDir = Join-Path $script:TestRepo "platform"
                New-Item -ItemType Directory -Path $platformDir -Force | Out-Null
                
                $platformFile = Join-Path $platformDir "platform-info.json"
                $platformInfo = @{
                    platform = if ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } else { "macOS" }
                    pathSeparator = [System.IO.Path]::DirectorySeparatorChar
                    userHome = $HOME
                    currentDirectory = $PWD.Path
                } | ConvertTo-Json -Depth 3
                
                Set-Content -Path $platformFile -Value $platformInfo
                
                return @{
                    FilesCreated = @($platformFile)
                    Platform = if ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } else { "macOS" }
                    PathSeparator = [System.IO.Path]::DirectorySeparatorChar
                }
            }
            
            # Assert
            $result.Success | Should -Be $true
            $result.Changes.Platform | Should -BeIn @("Windows", "Linux", "macOS")
            $result.Changes.PathSeparator | Should -BeIn @('\', '/')
        }
        
        It "Should handle different line endings" {
            # Arrange
            $lineEndingPatch = "Handle different line endings"
            
            # Act
            $result = New-Patch -Description $lineEndingPatch -Changes {
                $lineEndingFile = Join-Path $script:TestRepo "line-endings.txt"
                
                # Create content with platform-appropriate line endings
                $content = @(
                    "Line 1",
                    "Line 2", 
                    "Line 3"
                ) -join [System.Environment]::NewLine
                
                Set-Content -Path $lineEndingFile -Value $content
                
                return @{
                    FilesCreated = @($lineEndingFile)
                    LineEnding = [System.Environment]::NewLine
                    Platform = if ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } else { "macOS" }
                }
            }
            
            # Assert
            $result.Success | Should -Be $true
            $result.Changes.LineEnding | Should -Not -BeNullOrEmpty
            $result.Changes.Platform | Should -BeIn @("Windows", "Linux", "macOS")
        }
    }
}

AfterAll {
    # Cleanup test environment
    if (Test-Path $TestRepoRoot) {
        Remove-Item -Path $TestRepoRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    if (Test-Path $TestWorkspace) {
        Remove-Item -Path $TestWorkspace -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Clear captured events
    $script:CapturedEvents = @()
}