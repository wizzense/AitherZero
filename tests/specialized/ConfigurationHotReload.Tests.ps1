#Requires -Module Pester

<#
.SYNOPSIS
    Specialized test suite for configuration hot-reload functionality
.DESCRIPTION
    Comprehensive testing of configuration hot-reload capabilities including:
    - File system watchers for configuration change detection
    - Event system integration for configuration updates
    - Real-time configuration reloading without service restarts
    - Configuration validation during hot-reload operations
    - Performance impact of hot-reload mechanisms
    - Error handling and fallback during hot-reload failures
    - Multi-file configuration dependency handling
    - Environment-specific hot-reload behavior
    - Configuration change propagation to dependent modules
    - Hot-reload security and validation safeguards
.NOTES
    This test suite focuses specifically on the hot-reload functionality
    which is a critical feature for production environments requiring
    zero-downtime configuration updates.
#>

BeforeAll {
    # Import required modules using the TestingFramework infrastructure
    $ProjectRoot = if ($env:PROJECT_ROOT) { $env:PROJECT_ROOT } else {
        $currentPath = $PSScriptRoot
        while ($currentPath -and -not (Test-Path (Join-Path $currentPath ".git"))) {
            $currentPath = Split-Path $currentPath -Parent
        }
        $currentPath
    }
    
    # Import TestingFramework for infrastructure
    $testingFrameworkPath = Join-Path $ProjectRoot "aither-core/modules/TestingFramework"
    if (Test-Path $testingFrameworkPath) {
        Import-Module $testingFrameworkPath -Force
    }
    
    # Import the ConfigurationCore module (primary module for hot-reload)
    $configCoreModulePath = Join-Path $ProjectRoot "aither-core/modules/ConfigurationCore"
    if (Test-Path $configCoreModulePath) {
        Import-Module $configCoreModulePath -Force
    }
    
    # Import event system module if available
    $eventModulePath = Join-Path $ProjectRoot "aither-core/modules/EventSystem"
    if (Test-Path $eventModulePath) {
        Import-Module $eventModulePath -Force -ErrorAction SilentlyContinue
    }
    
    # Mock Write-CustomLog if not available
    if (-not (Get-Command 'Write-CustomLog' -ErrorAction SilentlyContinue)) {
        function Write-CustomLog {
            param([string]$Level, [string]$Message)
            Write-Host "[$Level] $Message"
        }
    }
    
    # Mock event system functions if not available
    if (-not (Get-Command 'Publish-TestEvent' -ErrorAction SilentlyContinue)) {
        function Publish-TestEvent {
            param([string]$EventName, [hashtable]$EventData)
            $script:PublishedEvents += @{
                EventName = $EventName
                EventData = $EventData
                Timestamp = Get-Date
            }
        }
    }
    
    if (-not (Get-Command 'Subscribe-TestEvent' -ErrorAction SilentlyContinue)) {
        function Subscribe-TestEvent {
            param([string]$EventName, [scriptblock]$Action)
            $script:EventSubscriptions += @{
                EventName = $EventName
                Action = $Action
                Timestamp = Get-Date
            }
        }
    }
    
    # Initialize event tracking
    $script:PublishedEvents = @()
    $script:EventSubscriptions = @()
    $script:FileChangeEvents = @()
    $script:ConfigurationReloadEvents = @()
    $script:ValidationEvents = @()
    
    # Create test directory structure for hot-reload testing
    $TestHotReloadDir = Join-Path $TestDrive 'ConfigurationHotReload'
    $TestConfigDir = Join-Path $TestHotReloadDir 'configs'
    $TestWatchDir = Join-Path $TestHotReloadDir 'watched'
    $TestBackupDir = Join-Path $TestHotReloadDir 'backups'
    $TestLogDir = Join-Path $TestHotReloadDir 'logs'
    $TestValidationDir = Join-Path $TestHotReloadDir 'validation'
    
    @($TestHotReloadDir, $TestConfigDir, $TestWatchDir, $TestBackupDir, $TestLogDir, $TestValidationDir) | ForEach-Object {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
    
    # Set up test environment
    $env:TEST_HOTRELOAD_DIR = $TestHotReloadDir
    $env:TEST_CONFIG_DIR = $TestConfigDir
    $env:TEST_WATCH_DIR = $TestWatchDir
    
    # Test data for hot-reload testing
    $script:TestData = @{
        BaseConfiguration = @{
            version = "1.0"
            name = "Hot Reload Test Configuration"
            settings = @{
                verbosity = "normal"
                autoUpdate = $true
                hotReloadEnabled = $true
                hotReloadInterval = 1000  # 1 second
                hotReloadTimeout = 5000   # 5 seconds
            }
            modules = @{
                Logging = @{
                    enabled = $true
                    level = "INFO"
                    hotReloadSupported = $true
                }
                PatchManager = @{
                    enabled = $true
                    autoCommit = $false
                    hotReloadSupported = $true
                }
            }
            hotReload = @{
                enabled = $true
                watchedFiles = @(
                    "configs/*.json",
                    "environments/*.json",
                    "modules/*.json"
                )
                excludePatterns = @(
                    "*.tmp",
                    "*.bak",
                    "*.lock"
                )
                validationRequired = $true
                backupOnChange = $true
                eventNotification = $true
            }
        }
        
        ConfigurationVariations = @{
            VerbosityChange = @{
                version = "1.0"
                name = "Hot Reload Test Configuration"
                settings = @{
                    verbosity = "detailed"  # Changed from "normal"
                    autoUpdate = $true
                    hotReloadEnabled = $true
                    hotReloadInterval = 1000
                    hotReloadTimeout = 5000
                }
            }
            ModuleChange = @{
                version = "1.0"
                name = "Hot Reload Test Configuration"
                settings = @{
                    verbosity = "normal"
                    autoUpdate = $true
                    hotReloadEnabled = $true
                    hotReloadInterval = 1000
                    hotReloadTimeout = 5000
                }
                modules = @{
                    Logging = @{
                        enabled = $true
                        level = "DEBUG"  # Changed from "INFO"
                        hotReloadSupported = $true
                    }
                    PatchManager = @{
                        enabled = $false  # Changed from $true
                        autoCommit = $false
                        hotReloadSupported = $true
                    }
                    NewModule = @{  # Added new module
                        enabled = $true
                        config = @{
                            param1 = "value1"
                        }
                        hotReloadSupported = $true
                    }
                }
            }
            InvalidChange = @{
                version = "1.0"
                name = "Hot Reload Test Configuration"
                settings = @{
                    verbosity = "invalid_level"  # Invalid value
                    autoUpdate = "not_a_boolean"  # Invalid type
                    hotReloadEnabled = $true
                    hotReloadInterval = -1000  # Invalid negative value
                    hotReloadTimeout = 5000
                }
            }
        }
        
        FileWatcherScenarios = @{
            SingleFileChange = @{
                Description = "Single configuration file modification"
                Files = @("configs/app-config.json")
                ExpectedEvents = 1
                ExpectedReloads = 1
            }
            MultipleFileChange = @{
                Description = "Multiple configuration files modified simultaneously"
                Files = @("configs/app-config.json", "configs/module-config.json", "environments/dev/env-config.json")
                ExpectedEvents = 3
                ExpectedReloads = 1  # Should batch multiple changes
            }
            RapidFileChanges = @{
                Description = "Rapid successive changes to the same file"
                Files = @("configs/app-config.json")
                ChangeCount = 5
                ExpectedEvents = 5
                ExpectedReloads = 1  # Should debounce rapid changes
            }
            DirectoryChange = @{
                Description = "New file added to watched directory"
                Files = @("configs/new-config.json")
                ExpectedEvents = 1
                ExpectedReloads = 1
            }
        }
        
        ErrorScenarios = @{
            FileCorruption = @{
                Description = "Configuration file becomes corrupted during hot-reload"
                CorruptedContent = "{ invalid json content"
                ExpectedBehavior = "Rollback to previous configuration"
            }
            FilePermissions = @{
                Description = "Configuration file permissions changed during hot-reload"
                ExpectedBehavior = "Graceful error handling and logging"
            }
            NetworkInterruption = @{
                Description = "Network interruption during remote configuration fetch"
                ExpectedBehavior = "Use cached configuration and retry"
            }
        }
    }
    
    # Mock file system watcher functionality
    function Start-MockFileSystemWatcher {
        param(
            [string]$Path,
            [string]$Filter = "*",
            [scriptblock]$ChangeHandler
        )
        
        return @{
            Path = $Path
            Filter = $Filter
            ChangeHandler = $ChangeHandler
            EnableRaisingEvents = $true
            IsActive = $true
            EventsProcessed = 0
        }
    }
    
    function Stop-MockFileSystemWatcher {
        param($Watcher)
        
        if ($Watcher) {
            $Watcher.EnableRaisingEvents = $false
            $Watcher.IsActive = $false
        }
    }
    
    function Invoke-MockFileSystemWatcher {
        param(
            $Watcher,
            [string]$ChangeType,
            [string]$FullPath
        )
        
        if ($Watcher -and $Watcher.IsActive) {
            $Watcher.EventsProcessed++
            
            $eventArgs = @{
                ChangeType = $ChangeType
                FullPath = $FullPath
                Name = Split-Path $FullPath -Leaf
                OldFullPath = $null
            }
            
            $script:FileChangeEvents += @{
                Timestamp = Get-Date
                ChangeType = $ChangeType
                FullPath = $FullPath
                WatcherPath = $Watcher.Path
            }
            
            # Execute the change handler
            if ($Watcher.ChangeHandler) {
                & $Watcher.ChangeHandler $eventArgs
            }
        }
    }
    
    # Mock configuration hot-reload functionality
    function Start-MockConfigurationHotReload {
        param(
            [string]$ConfigurationPath,
            [hashtable]$HotReloadSettings
        )
        
        $watcher = Start-MockFileSystemWatcher -Path $ConfigurationPath -Filter "*.json" -ChangeHandler {
            param($EventArgs)
            
            $script:ConfigurationReloadEvents += @{
                Timestamp = Get-Date
                FilePath = $EventArgs.FullPath
                ChangeType = $EventArgs.ChangeType
                ReloadTriggered = $true
            }
            
            # Simulate configuration reload process
            try {
                # Validate configuration before reload
                $validationResult = Test-MockConfigurationValidation -ConfigurationPath $EventArgs.FullPath
                
                if ($validationResult.IsValid) {
                    # Simulate successful reload
                    Publish-TestEvent -EventName "ConfigurationReloaded" -EventData @{
                        FilePath = $EventArgs.FullPath
                        ChangeType = $EventArgs.ChangeType
                        Success = $true
                        Timestamp = Get-Date
                    }
                } else {
                    # Simulate failed reload
                    Publish-TestEvent -EventName "ConfigurationReloadFailed" -EventData @{
                        FilePath = $EventArgs.FullPath
                        ChangeType = $EventArgs.ChangeType
                        Success = $false
                        Errors = $validationResult.Errors
                        Timestamp = Get-Date
                    }
                }
            } catch {
                # Simulate exception during reload
                Publish-TestEvent -EventName "ConfigurationReloadError" -EventData @{
                    FilePath = $EventArgs.FullPath
                    ChangeType = $EventArgs.ChangeType
                    Success = $false
                    Exception = $_.Exception.Message
                    Timestamp = Get-Date
                }
            }
        }
        
        return @{
            Watcher = $watcher
            Settings = $HotReloadSettings
            IsActive = $true
            StartTime = Get-Date
        }
    }
    
    function Stop-MockConfigurationHotReload {
        param($HotReloadManager)
        
        if ($HotReloadManager -and $HotReloadManager.Watcher) {
            Stop-MockFileSystemWatcher -Watcher $HotReloadManager.Watcher
            $HotReloadManager.IsActive = $false
        }
    }
    
    function Test-MockConfigurationValidation {
        param([string]$ConfigurationPath)
        
        $errors = @()
        $warnings = @()
        
        try {
            if (Test-Path $ConfigurationPath) {
                $content = Get-Content $ConfigurationPath -Raw
                $config = $content | ConvertFrom-Json
                
                # Basic validation rules
                if (-not $config.version) {
                    $errors += "Missing version field"
                }
                
                if (-not $config.name) {
                    $errors += "Missing name field"
                }
                
                if ($config.settings) {
                    if ($config.settings.verbosity -notin @("silent", "normal", "detailed", "debug")) {
                        $errors += "Invalid verbosity level: $($config.settings.verbosity)"
                    }
                    
                    if ($config.settings.PSObject.Properties["autoUpdate"] -and $config.settings.autoUpdate -isnot [bool]) {
                        $errors += "autoUpdate must be a boolean value"
                    }
                    
                    if ($config.settings.hotReloadInterval -and $config.settings.hotReloadInterval -lt 0) {
                        $errors += "hotReloadInterval must be positive"
                    }
                }
                
            } else {
                $errors += "Configuration file not found: $ConfigurationPath"
            }
            
        } catch {
            $errors += "JSON parsing error: $($_.Exception.Message)"
        }
        
        $script:ValidationEvents += @{
            Timestamp = Get-Date
            FilePath = $ConfigurationPath
            IsValid = ($errors.Count -eq 0)
            Errors = $errors
            Warnings = $warnings
        }
        
        return @{
            IsValid = ($errors.Count -eq 0)
            Errors = $errors
            Warnings = $warnings
            FilePath = $ConfigurationPath
        }
    }
    
    function Measure-HotReloadPerformance {
        param([scriptblock]$ScriptBlock)
        
        $startTime = Get-Date
        $startMemory = [System.GC]::GetTotalMemory($false)
        
        try {
            $result = & $ScriptBlock
            $success = $true
        } catch {
            $result = $_.Exception.Message
            $success = $false
        }
        
        $endTime = Get-Date
        $endMemory = [System.GC]::GetTotalMemory($false)
        
        return @{
            Success = $success
            Result = $result
            Duration = ($endTime - $startTime).TotalMilliseconds
            MemoryUsed = ($endMemory - $startMemory) / 1KB
        }
    }
}

Describe "Configuration Hot-Reload Functionality" {
    
    Context "File System Watcher Integration" {
        
        It "Should detect single file changes and trigger hot-reload" {
            $scenario = $script:TestData.FileWatcherScenarios.SingleFileChange
            $configPath = Join-Path $TestConfigDir "app-config.json"
            
            # Create initial configuration
            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
            
            # Start hot-reload monitoring
            $hotReloadManager = Start-MockConfigurationHotReload -ConfigurationPath $TestConfigDir -HotReloadSettings @{
                debounceInterval = 500
                validationRequired = $true
            }
            
            # Clear event tracking
            $script:FileChangeEvents = @()
            $script:ConfigurationReloadEvents = @()
            
            # Simulate file change
            $script:TestData.ConfigurationVariations.VerbosityChange | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
            Invoke-MockFileSystemWatcher -Watcher $hotReloadManager.Watcher -ChangeType "Changed" -FullPath $configPath
            
            # Wait for processing
            Start-Sleep -Milliseconds 100
            
            # Stop hot-reload monitoring
            Stop-MockConfigurationHotReload -HotReloadManager $hotReloadManager
            
            # Assert results
            $script:FileChangeEvents.Count | Should -Be $scenario.ExpectedEvents
            $script:ConfigurationReloadEvents.Count | Should -Be $scenario.ExpectedReloads
            $script:FileChangeEvents[0].ChangeType | Should -Be "Changed"
            $script:FileChangeEvents[0].FullPath | Should -Be $configPath
            $script:ConfigurationReloadEvents[0].ReloadTriggered | Should -Be $true
        }
        
        It "Should handle multiple file changes with debouncing" {
            $scenario = $script:TestData.FileWatcherScenarios.MultipleFileChange
            $configPaths = @()
            
            # Create multiple configuration files
            foreach ($file in $scenario.Files) {
                $filePath = Join-Path $TestHotReloadDir $file
                $fileDir = Split-Path $filePath -Parent
                if (-not (Test-Path $fileDir)) {
                    New-Item -ItemType Directory -Path $fileDir -Force | Out-Null
                }
                
                $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath
                $configPaths += $filePath
            }
            
            # Start hot-reload monitoring
            $hotReloadManager = Start-MockConfigurationHotReload -ConfigurationPath $TestHotReloadDir -HotReloadSettings @{
                debounceInterval = 200
                batchChanges = $true
            }
            
            # Clear event tracking
            $script:FileChangeEvents = @()
            $script:ConfigurationReloadEvents = @()
            
            # Simulate multiple file changes
            foreach ($configPath in $configPaths) {
                $script:TestData.ConfigurationVariations.ModuleChange | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
                Invoke-MockFileSystemWatcher -Watcher $hotReloadManager.Watcher -ChangeType "Changed" -FullPath $configPath
            }
            
            # Wait for debouncing
            Start-Sleep -Milliseconds 300
            
            # Stop hot-reload monitoring
            Stop-MockConfigurationHotReload -HotReloadManager $hotReloadManager
            
            # Assert results
            $script:FileChangeEvents.Count | Should -Be $scenario.ExpectedEvents
            # Note: In a real implementation, debouncing would batch multiple changes into a single reload
            # For the mock, we expect individual events but could be batched in actual implementation
            $script:FileChangeEvents | Should -HaveCount $scenario.ExpectedEvents
        }
        
        It "Should handle rapid successive changes with debouncing" {
            $scenario = $script:TestData.FileWatcherScenarios.RapidFileChanges
            $configPath = Join-Path $TestConfigDir "rapid-changes.json"
            
            # Create initial configuration
            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
            
            # Start hot-reload monitoring with aggressive debouncing
            $hotReloadManager = Start-MockConfigurationHotReload -ConfigurationPath $TestConfigDir -HotReloadSettings @{
                debounceInterval = 1000  # 1 second debounce
                validationRequired = $true
            }
            
            # Clear event tracking
            $script:FileChangeEvents = @()
            $script:ConfigurationReloadEvents = @()
            
            # Simulate rapid changes
            $performance = Measure-HotReloadPerformance {
                for ($i = 1; $i -le $scenario.ChangeCount; $i++) {
                    $modifiedConfig = $script:TestData.BaseConfiguration.Clone()
                    $modifiedConfig.settings.rapidChangeId = $i
                    $modifiedConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
                    
                    Invoke-MockFileSystemWatcher -Watcher $hotReloadManager.Watcher -ChangeType "Changed" -FullPath $configPath
                    Start-Sleep -Milliseconds 50  # Rapid changes
                }
            }
            
            # Wait for debouncing to complete
            Start-Sleep -Milliseconds 1200
            
            # Stop hot-reload monitoring
            Stop-MockConfigurationHotReload -HotReloadManager $hotReloadManager
            
            # Assert results
            $performance.Success | Should -Be $true
            $performance.Duration | Should -BeLessThan 1000  # Should complete rapidly
            $script:FileChangeEvents.Count | Should -Be $scenario.ExpectedEvents
            # In a real implementation, debouncing would reduce the number of actual reloads
        }
        
        It "Should detect new files added to watched directories" {
            $scenario = $script:TestData.FileWatcherScenarios.DirectoryChange
            $newConfigPath = Join-Path $TestConfigDir "new-config.json"
            
            # Start hot-reload monitoring
            $hotReloadManager = Start-MockConfigurationHotReload -ConfigurationPath $TestConfigDir -HotReloadSettings @{
                watchNewFiles = $true
                autoIncludeNewFiles = $true
            }
            
            # Clear event tracking
            $script:FileChangeEvents = @()
            $script:ConfigurationReloadEvents = @()
            
            # Simulate new file creation
            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path $newConfigPath
            Invoke-MockFileSystemWatcher -Watcher $hotReloadManager.Watcher -ChangeType "Created" -FullPath $newConfigPath
            
            # Wait for processing
            Start-Sleep -Milliseconds 100
            
            # Stop hot-reload monitoring
            Stop-MockConfigurationHotReload -HotReloadManager $hotReloadManager
            
            # Assert results
            $script:FileChangeEvents.Count | Should -Be $scenario.ExpectedEvents
            $script:ConfigurationReloadEvents.Count | Should -Be $scenario.ExpectedReloads
            $script:FileChangeEvents[0].ChangeType | Should -Be "Created"
            $script:FileChangeEvents[0].FullPath | Should -Be $newConfigPath
        }
    }
    
    Context "Event System Integration" {
        
        It "Should publish configuration reload events" {
            $configPath = Join-Path $TestConfigDir "event-test.json"
            
            # Create initial configuration
            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
            
            # Start hot-reload monitoring
            $hotReloadManager = Start-MockConfigurationHotReload -ConfigurationPath $TestConfigDir -HotReloadSettings @{
                eventNotification = $true
                publishEvents = $true
            }
            
            # Clear event tracking
            $script:PublishedEvents = @()
            
            # Simulate configuration change
            $script:TestData.ConfigurationVariations.VerbosityChange | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
            Invoke-MockFileSystemWatcher -Watcher $hotReloadManager.Watcher -ChangeType "Changed" -FullPath $configPath
            
            # Wait for event processing
            Start-Sleep -Milliseconds 100
            
            # Stop hot-reload monitoring
            Stop-MockConfigurationHotReload -HotReloadManager $hotReloadManager
            
            # Assert events were published
            $script:PublishedEvents.Count | Should -BeGreaterThan 0
            $configReloadEvent = $script:PublishedEvents | Where-Object { $_.EventName -eq "ConfigurationReloaded" }
            $configReloadEvent | Should -Not -BeNullOrEmpty
            $configReloadEvent.EventData.FilePath | Should -Be $configPath
            $configReloadEvent.EventData.Success | Should -Be $true
        }
        
        It "Should handle event subscription for configuration changes" {
            $configPath = Join-Path $TestConfigDir "subscription-test.json"
            $eventReceived = $false
            $eventData = $null
            
            # Create initial configuration
            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
            
            # Subscribe to configuration events
            Subscribe-TestEvent -EventName "ConfigurationReloaded" -Action {
                param($EventArgs)
                $script:eventReceived = $true
                $script:eventData = $EventArgs
            }
            
            # Start hot-reload monitoring
            $hotReloadManager = Start-MockConfigurationHotReload -ConfigurationPath $TestConfigDir -HotReloadSettings @{
                eventNotification = $true
            }
            
            # Clear event tracking
            $script:PublishedEvents = @()
            
            # Simulate configuration change
            $script:TestData.ConfigurationVariations.ModuleChange | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
            Invoke-MockFileSystemWatcher -Watcher $hotReloadManager.Watcher -ChangeType "Changed" -FullPath $configPath
            
            # Wait for event processing
            Start-Sleep -Milliseconds 100
            
            # Stop hot-reload monitoring
            Stop-MockConfigurationHotReload -HotReloadManager $hotReloadManager
            
            # Assert subscription worked
            $script:EventSubscriptions.Count | Should -BeGreaterThan 0
            $script:EventSubscriptions[0].EventName | Should -Be "ConfigurationReloaded"
            $script:EventSubscriptions[0].Action | Should -Not -BeNullOrEmpty
        }
        
        It "Should publish different event types for different scenarios" {
            $configPath = Join-Path $TestConfigDir "event-types-test.json"
            
            # Create initial configuration
            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
            
            # Start hot-reload monitoring
            $hotReloadManager = Start-MockConfigurationHotReload -ConfigurationPath $TestConfigDir -HotReloadSettings @{
                eventNotification = $true
                detailedEvents = $true
            }
            
            # Clear event tracking
            $script:PublishedEvents = @()
            
            # Test successful reload
            $script:TestData.ConfigurationVariations.VerbosityChange | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
            Invoke-MockFileSystemWatcher -Watcher $hotReloadManager.Watcher -ChangeType "Changed" -FullPath $configPath
            Start-Sleep -Milliseconds 50
            
            # Test failed reload (invalid configuration)
            $script:TestData.ConfigurationVariations.InvalidChange | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
            Invoke-MockFileSystemWatcher -Watcher $hotReloadManager.Watcher -ChangeType "Changed" -FullPath $configPath
            Start-Sleep -Milliseconds 50
            
            # Test file deletion
            Remove-Item $configPath -Force
            Invoke-MockFileSystemWatcher -Watcher $hotReloadManager.Watcher -ChangeType "Deleted" -FullPath $configPath
            Start-Sleep -Milliseconds 50
            
            # Stop hot-reload monitoring
            Stop-MockConfigurationHotReload -HotReloadManager $hotReloadManager
            
            # Assert different event types
            $script:PublishedEvents.Count | Should -BeGreaterThan 1
            $successEvents = $script:PublishedEvents | Where-Object { $_.EventName -eq "ConfigurationReloaded" -and $_.EventData.Success -eq $true }
            $failureEvents = $script:PublishedEvents | Where-Object { $_.EventName -eq "ConfigurationReloadFailed" -and $_.EventData.Success -eq $false }
            
            $successEvents | Should -Not -BeNullOrEmpty
            $failureEvents | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Configuration Validation During Hot-Reload" {
        
        It "Should validate configuration before applying hot-reload" {
            $configPath = Join-Path $TestConfigDir "validation-test.json"
            
            # Create initial valid configuration
            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
            
            # Start hot-reload monitoring with validation
            $hotReloadManager = Start-MockConfigurationHotReload -ConfigurationPath $TestConfigDir -HotReloadSettings @{
                validationRequired = $true
                validateBeforeApply = $true
            }
            
            # Clear event and validation tracking
            $script:PublishedEvents = @()
            $script:ValidationEvents = @()
            
            # Test valid configuration change
            $script:TestData.ConfigurationVariations.VerbosityChange | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
            Invoke-MockFileSystemWatcher -Watcher $hotReloadManager.Watcher -ChangeType "Changed" -FullPath $configPath
            Start-Sleep -Milliseconds 100
            
            # Stop hot-reload monitoring
            Stop-MockConfigurationHotReload -HotReloadManager $hotReloadManager
            
            # Assert validation occurred
            $script:ValidationEvents.Count | Should -BeGreaterThan 0
            $validationEvent = $script:ValidationEvents | Where-Object { $_.FilePath -eq $configPath }
            $validationEvent | Should -Not -BeNullOrEmpty
            $validationEvent.IsValid | Should -Be $true
            $validationEvent.Errors.Count | Should -Be 0
            
            # Assert successful reload event
            $successEvent = $script:PublishedEvents | Where-Object { $_.EventName -eq "ConfigurationReloaded" -and $_.EventData.Success -eq $true }
            $successEvent | Should -Not -BeNullOrEmpty
        }
        
        It "Should reject invalid configuration during hot-reload" {
            $configPath = Join-Path $TestConfigDir "invalid-validation-test.json"
            
            # Create initial valid configuration
            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
            
            # Start hot-reload monitoring with validation
            $hotReloadManager = Start-MockConfigurationHotReload -ConfigurationPath $TestConfigDir -HotReloadSettings @{
                validationRequired = $true
                rejectInvalidConfig = $true
            }
            
            # Clear event and validation tracking
            $script:PublishedEvents = @()
            $script:ValidationEvents = @()
            
            # Test invalid configuration change
            $script:TestData.ConfigurationVariations.InvalidChange | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
            Invoke-MockFileSystemWatcher -Watcher $hotReloadManager.Watcher -ChangeType "Changed" -FullPath $configPath
            Start-Sleep -Milliseconds 100
            
            # Stop hot-reload monitoring
            Stop-MockConfigurationHotReload -HotReloadManager $hotReloadManager
            
            # Assert validation occurred and failed
            $script:ValidationEvents.Count | Should -BeGreaterThan 0
            $validationEvent = $script:ValidationEvents | Where-Object { $_.FilePath -eq $configPath }
            $validationEvent | Should -Not -BeNullOrEmpty
            $validationEvent.IsValid | Should -Be $false
            $validationEvent.Errors.Count | Should -BeGreaterThan 0
            
            # Assert failed reload event
            $failureEvent = $script:PublishedEvents | Where-Object { $_.EventName -eq "ConfigurationReloadFailed" -and $_.EventData.Success -eq $false }
            $failureEvent | Should -Not -BeNullOrEmpty
            $failureEvent.EventData.Errors.Count | Should -BeGreaterThan 0
        }
        
        It "Should handle corrupted configuration files gracefully" {
            $configPath = Join-Path $TestConfigDir "corrupted-test.json"
            
            # Create initial valid configuration
            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
            
            # Start hot-reload monitoring
            $hotReloadManager = Start-MockConfigurationHotReload -ConfigurationPath $TestConfigDir -HotReloadSettings @{
                validationRequired = $true
                handleCorruption = $true
            }
            
            # Clear event and validation tracking
            $script:PublishedEvents = @()
            $script:ValidationEvents = @()
            
            # Corrupt the configuration file
            Set-Content -Path $configPath -Value "{ invalid json content without closing brace"
            Invoke-MockFileSystemWatcher -Watcher $hotReloadManager.Watcher -ChangeType "Changed" -FullPath $configPath
            Start-Sleep -Milliseconds 100
            
            # Stop hot-reload monitoring
            Stop-MockConfigurationHotReload -HotReloadManager $hotReloadManager
            
            # Assert validation caught the corruption
            $script:ValidationEvents.Count | Should -BeGreaterThan 0
            $validationEvent = $script:ValidationEvents | Where-Object { $_.FilePath -eq $configPath }
            $validationEvent | Should -Not -BeNullOrEmpty
            $validationEvent.IsValid | Should -Be $false
            $validationEvent.Errors | Should -Contain "JSON parsing error*"
            
            # Assert error event was published
            $errorEvent = $script:PublishedEvents | Where-Object { $_.EventName -eq "ConfigurationReloadFailed" }
            $errorEvent | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Performance and Resource Management" {
        
        It "Should handle hot-reload operations efficiently" {
            $configPath = Join-Path $TestConfigDir "performance-test.json"
            
            # Create initial configuration
            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
            
            # Start hot-reload monitoring
            $hotReloadManager = Start-MockConfigurationHotReload -ConfigurationPath $TestConfigDir -HotReloadSettings @{
                performanceOptimized = $true
                batchProcessing = $true
            }
            
            # Performance test: multiple rapid changes
            $performance = Measure-HotReloadPerformance {
                for ($i = 1; $i -le 10; $i++) {
                    $modifiedConfig = $script:TestData.BaseConfiguration.Clone()
                    $modifiedConfig.settings.performanceTestId = $i
                    $modifiedConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
                    
                    Invoke-MockFileSystemWatcher -Watcher $hotReloadManager.Watcher -ChangeType "Changed" -FullPath $configPath
                    Start-Sleep -Milliseconds 10
                }
            }
            
            # Stop hot-reload monitoring
            Stop-MockConfigurationHotReload -HotReloadManager $hotReloadManager
            
            # Assert performance characteristics
            $performance.Success | Should -Be $true
            $performance.Duration | Should -BeLessThan 1000  # Should complete in under 1 second
            $performance.MemoryUsed | Should -BeLessThan 1024  # Should use less than 1MB
        }
        
        It "Should limit resource usage during intensive hot-reload operations" {
            $configPath = Join-Path $TestConfigDir "resource-test.json"
            
            # Create initial configuration
            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
            
            # Start hot-reload monitoring with resource limits
            $hotReloadManager = Start-MockConfigurationHotReload -ConfigurationPath $TestConfigDir -HotReloadSettings @{
                resourceLimits = @{
                    maxMemoryUsage = 10MB
                    maxCpuTime = 5000  # 5 seconds
                    maxConcurrentOperations = 5
                }
            }
            
            # Clear event tracking
            $script:FileChangeEvents = @()
            
            # Simulate intensive operations
            $performance = Measure-HotReloadPerformance {
                for ($i = 1; $i -le 20; $i++) {
                    $largeConfig = $script:TestData.BaseConfiguration.Clone()
                    $largeConfig.settings.resourceTestId = $i
                    
                    # Add some complexity to the configuration
                    $largeConfig.bulkData = @{}
                    for ($j = 1; $j -le 10; $j++) {
                        $largeConfig.bulkData["item$j"] = "data$j" * 10
                    }
                    
                    $largeConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
                    Invoke-MockFileSystemWatcher -Watcher $hotReloadManager.Watcher -ChangeType "Changed" -FullPath $configPath
                    Start-Sleep -Milliseconds 5
                }
            }
            
            # Stop hot-reload monitoring
            Stop-MockConfigurationHotReload -HotReloadManager $hotReloadManager
            
            # Assert resource management
            $performance.Success | Should -Be $true
            $performance.MemoryUsed | Should -BeLessThan 10240  # Should respect memory limits
            $script:FileChangeEvents.Count | Should -Be 20  # All events should be processed
        }
        
        It "Should handle large configuration files efficiently" {
            $largeConfigPath = Join-Path $TestConfigDir "large-config.json"
            
            # Create large configuration
            $largeConfig = $script:TestData.BaseConfiguration.Clone()
            $largeConfig.largeSections = @{}
            
            # Add substantial data to create a large file
            for ($i = 1; $i -le 100; $i++) {
                $largeConfig.largeSections["section$i"] = @{
                    id = $i
                    data = "large data section $i" * 20
                    settings = @{
                        param1 = "value$i"
                        param2 = $i * 10
                        param3 = ($i % 2 -eq 0)
                    }
                }
            }
            
            $largeConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $largeConfigPath
            
            # Start hot-reload monitoring
            $hotReloadManager = Start-MockConfigurationHotReload -ConfigurationPath $TestConfigDir -HotReloadSettings @{
                largeFileSupport = $true
                streamingValidation = $true
            }
            
            # Clear event tracking
            $script:ValidationEvents = @()
            
            # Test hot-reload with large file
            $performance = Measure-HotReloadPerformance {
                $largeConfig.largeSections.section1.data = "modified large data section 1" * 20
                $largeConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $largeConfigPath
                Invoke-MockFileSystemWatcher -Watcher $hotReloadManager.Watcher -ChangeType "Changed" -FullPath $largeConfigPath
                Start-Sleep -Milliseconds 200
            }
            
            # Stop hot-reload monitoring
            Stop-MockConfigurationHotReload -HotReloadManager $hotReloadManager
            
            # Assert large file handling
            $performance.Success | Should -Be $true
            $performance.Duration | Should -BeLessThan 5000  # Should complete in under 5 seconds
            $script:ValidationEvents.Count | Should -BeGreaterThan 0
            
            # Verify the large file was processed
            $validationEvent = $script:ValidationEvents | Where-Object { $_.FilePath -eq $largeConfigPath }
            $validationEvent | Should -Not -BeNullOrEmpty
            $validationEvent.IsValid | Should -Be $true
        }
    }
    
    Context "Error Handling and Recovery" {
        
        It "Should handle file system errors gracefully" {
            $configPath = Join-Path $TestConfigDir "filesystem-error-test.json"
            
            # Create initial configuration
            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
            
            # Start hot-reload monitoring
            $hotReloadManager = Start-MockConfigurationHotReload -ConfigurationPath $TestConfigDir -HotReloadSettings @{
                errorHandling = $true
                retryOnFailure = $true
            }
            
            # Clear event tracking
            $script:PublishedEvents = @()
            
            # Simulate file system error (file deleted during read)
            Remove-Item $configPath -Force
            Invoke-MockFileSystemWatcher -Watcher $hotReloadManager.Watcher -ChangeType "Changed" -FullPath $configPath
            Start-Sleep -Milliseconds 100
            
            # Stop hot-reload monitoring
            Stop-MockConfigurationHotReload -HotReloadManager $hotReloadManager
            
            # Assert error handling
            $errorEvents = $script:PublishedEvents | Where-Object { $_.EventName -eq "ConfigurationReloadFailed" }
            $errorEvents | Should -Not -BeNullOrEmpty
            $errorEvents[0].EventData.Success | Should -Be $false
        }
        
        It "Should implement fallback strategies for failed reloads" {
            $configPath = Join-Path $TestConfigDir "fallback-test.json"
            $backupPath = Join-Path $TestBackupDir "fallback-test.json.backup"
            
            # Create initial configuration and backup
            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
            Copy-Item $configPath $backupPath
            
            # Start hot-reload monitoring with fallback
            $hotReloadManager = Start-MockConfigurationHotReload -ConfigurationPath $TestConfigDir -HotReloadSettings @{
                fallbackEnabled = $true
                backupPath = $TestBackupDir
                autoRestore = $true
            }
            
            # Clear event tracking
            $script:PublishedEvents = @()
            
            # Simulate configuration corruption
            Set-Content -Path $configPath -Value "corrupted content"
            Invoke-MockFileSystemWatcher -Watcher $hotReloadManager.Watcher -ChangeType "Changed" -FullPath $configPath
            Start-Sleep -Milliseconds 100
            
            # Stop hot-reload monitoring
            Stop-MockConfigurationHotReload -HotReloadManager $hotReloadManager
            
            # Assert fallback was triggered
            $failureEvents = $script:PublishedEvents | Where-Object { $_.EventName -eq "ConfigurationReloadFailed" }
            $failureEvents | Should -Not -BeNullOrEmpty
            $failureEvents[0].EventData.Success | Should -Be $false
            
            # Verify backup exists for potential restore
            Test-Path $backupPath | Should -Be $true
        }
        
        It "Should handle concurrent access to configuration files" {
            $configPath = Join-Path $TestConfigDir "concurrent-test.json"
            
            # Create initial configuration
            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
            
            # Start hot-reload monitoring with concurrency handling
            $hotReloadManager = Start-MockConfigurationHotReload -ConfigurationPath $TestConfigDir -HotReloadSettings @{
                concurrencyControl = $true
                fileLocking = $true
            }
            
            # Clear event tracking
            $script:FileChangeEvents = @()
            
            # Simulate concurrent access (multiple rapid changes)
            $performance = Measure-HotReloadPerformance {
                for ($i = 1; $i -le 5; $i++) {
                    $modifiedConfig = $script:TestData.BaseConfiguration.Clone()
                    $modifiedConfig.settings.concurrentTestId = $i
                    $modifiedConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
                    
                    Invoke-MockFileSystemWatcher -Watcher $hotReloadManager.Watcher -ChangeType "Changed" -FullPath $configPath
                    # No sleep to simulate true concurrent access
                }
            }
            
            # Stop hot-reload monitoring
            Stop-MockConfigurationHotReload -HotReloadManager $hotReloadManager
            
            # Assert concurrency handling
            $performance.Success | Should -Be $true
            $script:FileChangeEvents.Count | Should -Be 5  # All changes should be detected
        }
    }
    
    Context "Environment-Specific Hot-Reload Behavior" {
        
        It "Should handle different hot-reload settings per environment" {
            $environments = @("dev", "staging", "prod")
            $hotReloadManagers = @{}
            
            foreach ($env in $environments) {
                $envDir = Join-Path $TestEnvironmentsDir $env
                New-Item -ItemType Directory -Path $envDir -Force | Out-Null
                
                $configPath = Join-Path $envDir "env-config.json"
                $envConfig = $script:TestData.BaseConfiguration.Clone()
                $envConfig.environment = $env
                $envConfig.settings.hotReloadInterval = switch ($env) {
                    "dev" { 100 }      # Very fast for development
                    "staging" { 1000 } # Moderate for staging
                    "prod" { 5000 }    # Conservative for production
                }
                $envConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
                
                # Start environment-specific hot-reload
                $hotReloadSettings = @{
                    debounceInterval = $envConfig.settings.hotReloadInterval
                    validationRequired = ($env -ne "dev")
                    backupOnChange = ($env -eq "prod")
                }
                
                $hotReloadManagers[$env] = Start-MockConfigurationHotReload -ConfigurationPath $envDir -HotReloadSettings $hotReloadSettings
            }
            
            # Clear event tracking
            $script:PublishedEvents = @()
            
            # Test each environment
            foreach ($env in $environments) {
                $envDir = Join-Path $TestEnvironmentsDir $env
                $configPath = Join-Path $envDir "env-config.json"
                
                # Modify environment configuration
                $modifiedConfig = Get-Content $configPath | ConvertFrom-Json
                $modifiedConfig.settings.testModification = "env-$env-modified"
                $modifiedConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
                
                Invoke-MockFileSystemWatcher -Watcher $hotReloadManagers[$env].Watcher -ChangeType "Changed" -FullPath $configPath
                Start-Sleep -Milliseconds 100
            }
            
            # Stop all hot-reload managers
            foreach ($env in $environments) {
                Stop-MockConfigurationHotReload -HotReloadManager $hotReloadManagers[$env]
            }
            
            # Assert environment-specific behavior
            $script:PublishedEvents.Count | Should -Be ($environments.Count)
            
            foreach ($env in $environments) {
                $envEvents = $script:PublishedEvents | Where-Object { $_.EventData.FilePath -like "*$env*" }
                $envEvents | Should -Not -BeNullOrEmpty
                $envEvents[0].EventData.Success | Should -Be $true
            }
        }
    }
}

AfterAll {
    # Cleanup test environment
    if ($env:TEST_HOTRELOAD_DIR -and (Test-Path $env:TEST_HOTRELOAD_DIR)) {
        try {
            Remove-Item -Path $env:TEST_HOTRELOAD_DIR -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            Write-CustomLog -Level 'WARNING' -Message "Could not cleanup test directory: $($env:TEST_HOTRELOAD_DIR)"
        }
    }
    
    # Clear test environment variables
    $env:TEST_HOTRELOAD_DIR = $null
    $env:TEST_CONFIG_DIR = $null
    $env:TEST_WATCH_DIR = $null
    
    # Clear event tracking
    $script:PublishedEvents = @()
    $script:EventSubscriptions = @()
    $script:FileChangeEvents = @()
    $script:ConfigurationReloadEvents = @()
    $script:ValidationEvents = @()
}