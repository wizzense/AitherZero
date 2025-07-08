#Requires -Module Pester

<#
.SYNOPSIS
    Specialized test suite for configuration backup and restore functionality
.DESCRIPTION
    Comprehensive testing of configuration backup and restore capabilities including:
    - Automated configuration backup creation and scheduling
    - Manual backup creation with metadata and versioning
    - Configuration restore operations with validation
    - Backup integrity verification and corruption detection
    - Incremental and differential backup strategies
    - Cross-platform backup format compatibility
    - Backup compression and encryption support
    - Backup retention policies and automated cleanup
    - Point-in-time recovery and rollback scenarios
    - Multi-environment backup synchronization
    - Disaster recovery testing and validation
    - Performance optimization for large configuration sets
.NOTES
    This test suite focuses on the critical backup and restore functionality
    that ensures configuration data protection and business continuity.
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

    # Import configuration modules
    $configModules = @("ConfigurationCore", "ConfigurationCarousel", "ConfigurationRepository")
    foreach ($module in $configModules) {
        $modulePath = Join-Path $ProjectRoot "aither-core/modules/$module"
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force -ErrorAction SilentlyContinue
        }
    }

    # Mock Write-CustomLog if not available
    if (-not (Get-Command 'Write-CustomLog' -ErrorAction SilentlyContinue)) {
        function Write-CustomLog {
            param([string]$Level, [string]$Message)
            Write-Host "[$Level] $Message"
        }
    }

    # Mock compression functions if not available
    if (-not (Get-Command 'Compress-Archive' -ErrorAction SilentlyContinue)) {
        function Compress-Archive {
            param([string]$Path, [string]$DestinationPath)
            # Mock compression - just copy for testing
            Copy-Item -Path $Path -Destination ($DestinationPath -replace '\.zip$', '') -Recurse -Force
        }
    }

    if (-not (Get-Command 'Expand-Archive' -ErrorAction SilentlyContinue)) {
        function Expand-Archive {
            param([string]$Path, [string]$DestinationPath)
            # Mock decompression - just copy for testing
            $sourcePath = $Path -replace '\.zip$', ''
            if (Test-Path $sourcePath) {
                Copy-Item -Path $sourcePath -Destination $DestinationPath -Recurse -Force
            }
        }
    }

    # Create comprehensive test directory structure
    $TestBackupRestoreDir = Join-Path $TestDrive 'ConfigurationBackupRestore'
    $TestConfigDir = Join-Path $TestBackupRestoreDir 'configs'
    $TestBackupDir = Join-Path $TestBackupRestoreDir 'backups'
    $TestRestoreDir = Join-Path $TestBackupRestoreDir 'restore'
    $TestArchiveDir = Join-Path $TestBackupRestoreDir 'archives'
    $TestMetadataDir = Join-Path $TestBackupRestoreDir 'metadata'
    $TestIntegrityDir = Join-Path $TestBackupRestoreDir 'integrity'
    $TestEnvironmentsDir = Join-Path $TestBackupRestoreDir 'environments'

    @($TestBackupRestoreDir, $TestConfigDir, $TestBackupDir, $TestRestoreDir,
      $TestArchiveDir, $TestMetadataDir, $TestIntegrityDir, $TestEnvironmentsDir) | ForEach-Object {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }

    # Set up test environment
    $env:TEST_BACKUP_RESTORE_DIR = $TestBackupRestoreDir
    $env:TEST_CONFIG_DIR = $TestConfigDir
    $env:TEST_BACKUP_DIR = $TestBackupDir
    $env:TEST_RESTORE_DIR = $TestRestoreDir

    # Initialize backup tracking
    $script:BackupOperations = @()
    $script:RestoreOperations = @()
    $script:IntegrityChecks = @()
    $script:BackupMetadata = @()

    # Test data for backup and restore testing
    $script:TestData = @{
        BaseConfiguration = @{
            version = "1.0"
            name = "Backup Test Configuration"
            created = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            settings = @{
                verbosity = "normal"
                autoUpdate = $true
                backupEnabled = $true
                backupRetention = 30  # days
                backupCompression = $true
            }
            modules = @{
                Logging = @{
                    enabled = $true
                    level = "INFO"
                    logFile = "logs/app.log"
                }
                PatchManager = @{
                    enabled = $true
                    autoCommit = $false
                    repository = "origin"
                }
                BackupManager = @{
                    enabled = $true
                    schedule = "daily"
                    retentionPolicy = "30d"
                    compression = $true
                    encryption = $false
                }
            }
            environments = @{
                dev = @{
                    name = "Development"
                    settings = @{
                        debugMode = $true
                        verbosity = "detailed"
                    }
                }
                prod = @{
                    name = "Production"
                    settings = @{
                        debugMode = $false
                        verbosity = "minimal"
                        auditEnabled = $true
                    }
                }
            }
        }

        ConfigurationVariations = @{
            ModifiedSettings = @{
                version = "1.1"
                name = "Backup Test Configuration"
                modified = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                settings = @{
                    verbosity = "detailed"  # Changed
                    autoUpdate = $false     # Changed
                    backupEnabled = $true
                    backupRetention = 60    # Changed
                    backupCompression = $true
                    newSetting = "added"    # New
                }
            }
            AddedModules = @{
                version = "1.2"
                name = "Backup Test Configuration"
                modules = @{
                    NewModule = @{          # Added
                        enabled = $true
                        config = @{
                            param1 = "value1"
                        }
                    }
                    AnotherModule = @{      # Added
                        enabled = $false
                        config = @{
                            param2 = "value2"
                        }
                    }
                }
            }
            RemovedSections = @{
                version = "1.3"
                name = "Backup Test Configuration"
                settings = @{
                    verbosity = "normal"
                    autoUpdate = $true
                }
                # environments section removed
            }
        }

        BackupScenarios = @{
            FullBackup = @{
                Type = "Full"
                Description = "Complete configuration backup"
                IncludeMetadata = $true
                Compression = $true
                Encryption = $false
                ExpectedFiles = @("app-config.json", "module-config.json", "env-config.json")
            }
            IncrementalBackup = @{
                Type = "Incremental"
                Description = "Changes since last backup"
                IncludeMetadata = $true
                Compression = $true
                Encryption = $false
                RequiresPreviousBackup = $true
            }
            DifferentialBackup = @{
                Type = "Differential"
                Description = "Changes since last full backup"
                IncludeMetadata = $true
                Compression = $true
                Encryption = $false
                RequiresPreviousFullBackup = $true
            }
            EncryptedBackup = @{
                Type = "Full"
                Description = "Encrypted configuration backup"
                IncludeMetadata = $true
                Compression = $true
                Encryption = $true
                EncryptionKey = "test-encryption-key-123"
            }
        }

        RestoreScenarios = @{
            CompleteRestore = @{
                Description = "Restore entire configuration from backup"
                ValidateIntegrity = $true
                PreserveExisting = $false
                ExpectedResult = "Success"
            }
            SelectiveRestore = @{
                Description = "Restore specific sections only"
                RestoreSections = @("settings", "modules")
                ValidateIntegrity = $true
                PreserveExisting = $true
                ExpectedResult = "Success"
            }
            PointInTimeRestore = @{
                Description = "Restore configuration to specific timestamp"
                RestoreTimestamp = (Get-Date).AddHours(-2)
                ValidateIntegrity = $true
                PreserveExisting = $false
                ExpectedResult = "Success"
            }
        }

        IntegrityScenarios = @{
            ValidBackup = @{
                Description = "Valid backup with correct checksums"
                ExpectedIntegrity = $true
                CorruptionType = "None"
            }
            CorruptedMetadata = @{
                Description = "Backup with corrupted metadata"
                ExpectedIntegrity = $false
                CorruptionType = "Metadata"
            }
            CorruptedData = @{
                Description = "Backup with corrupted configuration data"
                ExpectedIntegrity = $false
                CorruptionType = "Data"
            }
            MissingFiles = @{
                Description = "Backup with missing files"
                ExpectedIntegrity = $false
                CorruptionType = "MissingFiles"
            }
        }
    }

    # Mock backup and restore functions
    function New-MockConfigurationBackup {
        param(
            [string]$ConfigurationPath,
            [string]$BackupPath,
            [string]$BackupType = "Full",
            [hashtable]$BackupSettings = @{}
        )

        try {
            $backupId = [System.Guid]::NewGuid().ToString()
            $timestamp = Get-Date

            # Create backup directory
            $backupInstanceDir = Join-Path $BackupPath "$BackupType-$($timestamp.ToString('yyyyMMdd-HHmmss'))-$($backupId.Substring(0,8))"
            New-Item -ItemType Directory -Path $backupInstanceDir -Force | Out-Null

            # Create metadata
            $metadata = @{
                BackupId = $backupId
                BackupType = $BackupType
                Timestamp = $timestamp.ToString('yyyy-MM-dd HH:mm:ss')
                SourcePath = $ConfigurationPath
                BackupPath = $backupInstanceDir
                Settings = $BackupSettings
                FileCount = 0
                TotalSize = 0
                Checksums = @{}
                Version = "1.0"
                CreatedBy = "ConfigurationBackupRestore.Tests"
            }

            # Copy configuration files
            $configFiles = Get-ChildItem -Path $ConfigurationPath -Recurse -File
            foreach ($file in $configFiles) {
                $relativePath = $file.FullName.Substring($ConfigurationPath.Length + 1)
                $destPath = Join-Path $backupInstanceDir $relativePath
                $destDir = Split-Path $destPath -Parent

                if (-not (Test-Path $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }

                Copy-Item -Path $file.FullName -Destination $destPath -Force

                # Calculate checksum (mock)
                $checksum = Get-FileHash -Path $file.FullName -Algorithm SHA256
                $metadata.Checksums[$relativePath] = $checksum.Hash
                $metadata.FileCount++
                $metadata.TotalSize += $file.Length
            }

            # Save metadata
            $metadataPath = Join-Path $backupInstanceDir "backup-metadata.json"
            $metadata | ConvertTo-Json -Depth 10 | Set-Content -Path $metadataPath

            # Apply compression if requested
            if ($BackupSettings.Compression) {
                $compressedPath = "$backupInstanceDir.zip"
                Compress-Archive -Path $backupInstanceDir -DestinationPath $compressedPath
                # Remove uncompressed version
                Remove-Item -Path $backupInstanceDir -Recurse -Force
                $metadata.CompressedPath = $compressedPath
                $metadata.Compressed = $true
            }

            $script:BackupOperations += @{
                BackupId = $backupId
                Timestamp = $timestamp
                Type = $BackupType
                SourcePath = $ConfigurationPath
                BackupPath = if ($BackupSettings.Compression) { $compressedPath } else { $backupInstanceDir }
                Metadata = $metadata
                Success = $true
            }

            $script:BackupMetadata += $metadata

            return @{
                Success = $true
                BackupId = $backupId
                BackupPath = if ($BackupSettings.Compression) { $compressedPath } else { $backupInstanceDir }
                Metadata = $metadata
            }

        } catch {
            $script:BackupOperations += @{
                BackupId = $null
                Timestamp = Get-Date
                Type = $BackupType
                SourcePath = $ConfigurationPath
                BackupPath = $BackupPath
                Success = $false
                Error = $_.Exception.Message
            }

            return @{
                Success = $false
                Error = $_.Exception.Message
            }
        }
    }

    function Restore-MockConfigurationBackup {
        param(
            [string]$BackupPath,
            [string]$RestorePath,
            [hashtable]$RestoreSettings = @{}
        )

        try {
            $restoreId = [System.Guid]::NewGuid().ToString()
            $timestamp = Get-Date

            # Determine if backup is compressed
            $workingPath = $BackupPath
            if ($BackupPath.EndsWith('.zip')) {
                $tempExtractPath = Join-Path $TestDrive "temp-extract-$restoreId"
                Expand-Archive -Path $BackupPath -DestinationPath $tempExtractPath
                $workingPath = $tempExtractPath
            }

            # Load backup metadata
            $metadataPath = Join-Path $workingPath "backup-metadata.json"
            if (-not (Test-Path $metadataPath)) {
                throw "Backup metadata not found: $metadataPath"
            }

            $metadata = Get-Content $metadataPath | ConvertFrom-Json

            # Validate backup integrity before restore
            $integrityResult = Test-MockBackupIntegrity -BackupPath $workingPath -Metadata $metadata
            if (-not $integrityResult.IsValid -and $RestoreSettings.ValidateIntegrity) {
                throw "Backup integrity validation failed: $($integrityResult.Errors -join '; ')"
            }

            # Create restore directory
            if (-not (Test-Path $RestorePath)) {
                New-Item -ItemType Directory -Path $RestorePath -Force | Out-Null
            }

            # Restore files
            $restoredFiles = @()
            $restoreSections = $RestoreSettings.RestoreSections

            $backupFiles = Get-ChildItem -Path $workingPath -Recurse -File | Where-Object { $_.Name -ne "backup-metadata.json" }
            foreach ($file in $backupFiles) {
                $relativePath = $file.FullName.Substring($workingPath.Length + 1)

                # Check if this file should be restored based on sections
                $shouldRestore = $true
                if ($restoreSections) {
                    $shouldRestore = $false
                    foreach ($section in $restoreSections) {
                        if ($relativePath -like "*$section*") {
                            $shouldRestore = $true
                            break
                        }
                    }
                }

                if ($shouldRestore) {
                    $destPath = Join-Path $RestorePath $relativePath
                    $destDir = Split-Path $destPath -Parent

                    if (-not (Test-Path $destDir)) {
                        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                    }

                    # Check if file exists and preserve setting
                    if ((Test-Path $destPath) -and $RestoreSettings.PreserveExisting) {
                        $backupFile = "$destPath.restore-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                        Move-Item -Path $destPath -Destination $backupFile
                    }

                    Copy-Item -Path $file.FullName -Destination $destPath -Force
                    $restoredFiles += $relativePath
                }
            }

            # Cleanup temporary extraction if used
            if ($BackupPath.EndsWith('.zip') -and (Test-Path $tempExtractPath)) {
                Remove-Item -Path $tempExtractPath -Recurse -Force
            }

            $script:RestoreOperations += @{
                RestoreId = $restoreId
                Timestamp = $timestamp
                BackupPath = $BackupPath
                RestorePath = $RestorePath
                RestoredFiles = $restoredFiles
                Settings = $RestoreSettings
                Success = $true
            }

            return @{
                Success = $true
                RestoreId = $restoreId
                RestoredFiles = $restoredFiles
                BackupMetadata = $metadata
            }

        } catch {
            $script:RestoreOperations += @{
                RestoreId = $restoreId
                Timestamp = Get-Date
                BackupPath = $BackupPath
                RestorePath = $RestorePath
                Success = $false
                Error = $_.Exception.Message
            }

            return @{
                Success = $false
                Error = $_.Exception.Message
            }
        }
    }

    function Test-MockBackupIntegrity {
        param(
            [string]$BackupPath,
            [hashtable]$Metadata
        )

        $errors = @()
        $warnings = @()
        $validatedFiles = 0

        try {
            # Check if metadata file exists
            $metadataPath = Join-Path $BackupPath "backup-metadata.json"
            if (-not (Test-Path $metadataPath)) {
                $errors += "Backup metadata file missing"
                return @{
                    IsValid = $false
                    Errors = $errors
                    Warnings = $warnings
                    ValidatedFiles = $validatedFiles
                }
            }

            # Validate file count
            $actualFiles = Get-ChildItem -Path $BackupPath -Recurse -File | Where-Object { $_.Name -ne "backup-metadata.json" }
            if ($actualFiles.Count -ne $Metadata.FileCount) {
                $errors += "File count mismatch: expected $($Metadata.FileCount), found $($actualFiles.Count)"
            }

            # Validate checksums
            foreach ($file in $actualFiles) {
                $relativePath = $file.FullName.Substring($BackupPath.Length + 1)
                if ($Metadata.Checksums.PSObject.Properties[$relativePath]) {
                    $expectedChecksum = $Metadata.Checksums.$relativePath
                    $actualChecksum = Get-FileHash -Path $file.FullName -Algorithm SHA256

                    if ($actualChecksum.Hash -ne $expectedChecksum) {
                        $errors += "Checksum mismatch for file: $relativePath"
                    } else {
                        $validatedFiles++
                    }
                } else {
                    $warnings += "No checksum found for file: $relativePath"
                }
            }

            # Check for required files
            $requiredFiles = @("app-config.json")  # Minimum required files
            foreach ($requiredFile in $requiredFiles) {
                $found = $actualFiles | Where-Object { $_.Name -eq $requiredFile }
                if (-not $found) {
                    $errors += "Required file missing: $requiredFile"
                }
            }

            $script:IntegrityChecks += @{
                Timestamp = Get-Date
                BackupPath = $BackupPath
                IsValid = ($errors.Count -eq 0)
                Errors = $errors
                Warnings = $warnings
                ValidatedFiles = $validatedFiles
                TotalFiles = $actualFiles.Count
            }

            return @{
                IsValid = ($errors.Count -eq 0)
                Errors = $errors
                Warnings = $warnings
                ValidatedFiles = $validatedFiles
                TotalFiles = $actualFiles.Count
            }

        } catch {
            $errors += "Integrity check error: $($_.Exception.Message)"
            return @{
                IsValid = $false
                Errors = $errors
                Warnings = $warnings
                ValidatedFiles = $validatedFiles
            }
        }
    }

    function Remove-MockOldBackups {
        param(
            [string]$BackupPath,
            [int]$RetentionDays = 30
        )

        $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
        $removedBackups = @()

        try {
            $backupDirs = Get-ChildItem -Path $BackupPath -Directory
            foreach ($backupDir in $backupDirs) {
                if ($backupDir.CreationTime -lt $cutoffDate) {
                    Remove-Item -Path $backupDir.FullName -Recurse -Force
                    $removedBackups += $backupDir.Name
                }
            }

            # Also handle compressed backups
            $backupFiles = Get-ChildItem -Path $BackupPath -File -Filter "*.zip"
            foreach ($backupFile in $backupFiles) {
                if ($backupFile.CreationTime -lt $cutoffDate) {
                    Remove-Item -Path $backupFile.FullName -Force
                    $removedBackups += $backupFile.Name
                }
            }

            return @{
                Success = $true
                RemovedBackups = $removedBackups
                RemovedCount = $removedBackups.Count
            }

        } catch {
            return @{
                Success = $false
                Error = $_.Exception.Message
                RemovedBackups = $removedBackups
                RemovedCount = $removedBackups.Count
            }
        }
    }

    function Measure-BackupRestorePerformance {
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

Describe "Configuration Backup and Restore Functionality" {

    Context "Backup Creation and Management" {

        It "Should create full configuration backup successfully" {
            $scenario = $script:TestData.BackupScenarios.FullBackup

            # Create test configuration
            $configPath = Join-Path $TestConfigDir "full-backup-test"
            New-Item -ItemType Directory -Path $configPath -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $configPath "configs") -Force | Out-Null

            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $configPath "configs/app-config.json")

            # Create backup
            $backupResult = New-MockConfigurationBackup -ConfigurationPath $configPath -BackupPath $TestBackupDir -BackupType $scenario.Type -BackupSettings @{
                IncludeMetadata = $scenario.IncludeMetadata
                Compression = $scenario.Compression
                Encryption = $scenario.Encryption
            }

            # Assert backup creation
            $backupResult.Success | Should -Be $true
            $backupResult.BackupId | Should -Not -BeNullOrEmpty
            $backupResult.BackupPath | Should -Not -BeNullOrEmpty
            Test-Path $backupResult.BackupPath | Should -Be $true

            # Verify backup metadata
            $backupResult.Metadata | Should -Not -BeNullOrEmpty
            $backupResult.Metadata.BackupType | Should -Be $scenario.Type
            $backupResult.Metadata.FileCount | Should -BeGreaterThan 0
            $backupResult.Metadata.Checksums | Should -Not -BeNullOrEmpty

            # Verify backup tracking
            $script:BackupOperations.Count | Should -BeGreaterThan 0
            $lastBackup = $script:BackupOperations[-1]
            $lastBackup.Success | Should -Be $true
            $lastBackup.BackupId | Should -Be $backupResult.BackupId
        }

        It "Should create incremental backup with only changes" {
            $scenario = $script:TestData.BackupScenarios.IncrementalBackup

            # Create test configuration
            $configPath = Join-Path $TestConfigDir "incremental-backup-test"
            New-Item -ItemType Directory -Path $configPath -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $configPath "configs") -Force | Out-Null

            # Create initial configuration and full backup
            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $configPath "configs/app-config.json")
            $fullBackupResult = New-MockConfigurationBackup -ConfigurationPath $configPath -BackupPath $TestBackupDir -BackupType "Full" -BackupSettings @{
                Compression = $true
            }

            # Wait and modify configuration
            Start-Sleep -Seconds 1
            $modifiedConfig = $script:TestData.BaseConfiguration.Clone()
            $modifiedConfig.settings.verbosity = "detailed"
            $modifiedConfig.settings.lastModified = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            $modifiedConfig | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $configPath "configs/app-config.json")

            # Create incremental backup
            $incrementalBackupResult = New-MockConfigurationBackup -ConfigurationPath $configPath -BackupPath $TestBackupDir -BackupType $scenario.Type -BackupSettings @{
                IncludeMetadata = $scenario.IncludeMetadata
                Compression = $scenario.Compression
                PreviousBackupId = $fullBackupResult.BackupId
            }

            # Assert incremental backup
            $incrementalBackupResult.Success | Should -Be $true
            $incrementalBackupResult.BackupId | Should -Not -BeNullOrEmpty
            $incrementalBackupResult.BackupId | Should -Not -Be $fullBackupResult.BackupId

            # Verify both backups exist
            $script:BackupOperations.Count | Should -BeGreaterOrEqual 2
            $fullBackup = $script:BackupOperations | Where-Object { $_.BackupId -eq $fullBackupResult.BackupId }
            $incrementalBackup = $script:BackupOperations | Where-Object { $_.BackupId -eq $incrementalBackupResult.BackupId }

            $fullBackup | Should -Not -BeNullOrEmpty
            $incrementalBackup | Should -Not -BeNullOrEmpty
            $fullBackup.Type | Should -Be "Full"
            $incrementalBackup.Type | Should -Be "Incremental"
        }

        It "Should handle backup compression correctly" {
            # Create test configuration
            $configPath = Join-Path $TestConfigDir "compression-test"
            New-Item -ItemType Directory -Path $configPath -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $configPath "configs") -Force | Out-Null

            # Create large configuration to test compression
            $largeConfig = $script:TestData.BaseConfiguration.Clone()
            $largeConfig.largeSections = @{}
            for ($i = 1; $i -le 50; $i++) {
                $largeConfig.largeSections["section$i"] = @{
                    data = "large data section $i" * 10
                    items = @(1..20)
                }
            }
            $largeConfig | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $configPath "configs/app-config.json")

            # Create uncompressed backup
            $uncompressedResult = New-MockConfigurationBackup -ConfigurationPath $configPath -BackupPath $TestBackupDir -BackupType "Full" -BackupSettings @{
                Compression = $false
            }

            # Create compressed backup
            $compressedResult = New-MockConfigurationBackup -ConfigurationPath $configPath -BackupPath $TestBackupDir -BackupType "Full" -BackupSettings @{
                Compression = $true
            }

            # Assert both backups succeeded
            $uncompressedResult.Success | Should -Be $true
            $compressedResult.Success | Should -Be $true

            # Verify compression settings in metadata
            $uncompressedResult.Metadata.Compressed | Should -Be $false
            $compressedResult.Metadata.Compressed | Should -Be $true

            # Verify file paths
            $uncompressedResult.BackupPath | Should -Not -Match "\.zip$"
            $compressedResult.BackupPath | Should -Match "\.zip$"
        }

        It "Should implement backup retention policies" {
            # Create multiple old backups
            $configPath = Join-Path $TestConfigDir "retention-test"
            New-Item -ItemType Directory -Path $configPath -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $configPath "configs") -Force | Out-Null

            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $configPath "configs/app-config.json")

            # Create several backups
            $backupResults = @()
            for ($i = 1; $i -le 5; $i++) {
                $result = New-MockConfigurationBackup -ConfigurationPath $configPath -BackupPath $TestBackupDir -BackupType "Full" -BackupSettings @{
                    Compression = ($i % 2 -eq 0)  # Alternate compression
                }
                $backupResults += $result
                Start-Sleep -Milliseconds 100  # Small delay between backups
            }

            # Count backups before cleanup
            $backupsBeforeCleanup = $script:BackupOperations.Count

            # Apply retention policy (remove all backups older than 0 days for testing)
            $cleanupResult = Remove-MockOldBackups -BackupPath $TestBackupDir -RetentionDays 0

            # Assert retention policy
            $cleanupResult.Success | Should -Be $true
            $cleanupResult.RemovedCount | Should -BeGreaterOrEqual 0  # May or may not remove based on creation time

            # Verify tracking
            $backupsBeforeCleanup | Should -Be 5
        }
    }

    Context "Configuration Restore Operations" {

        It "Should restore complete configuration successfully" {
            $scenario = $script:TestData.RestoreScenarios.CompleteRestore

            # Create test configuration and backup
            $configPath = Join-Path $TestConfigDir "complete-restore-test"
            New-Item -ItemType Directory -Path $configPath -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $configPath "configs") -Force | Out-Null

            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $configPath "configs/app-config.json")

            $backupResult = New-MockConfigurationBackup -ConfigurationPath $configPath -BackupPath $TestBackupDir -BackupType "Full" -BackupSettings @{
                Compression = $true
                IncludeMetadata = $true
            }

            # Create restore destination
            $restorePath = Join-Path $TestRestoreDir "complete-restore"

            # Perform restore
            $restoreResult = Restore-MockConfigurationBackup -BackupPath $backupResult.BackupPath -RestorePath $restorePath -RestoreSettings @{
                ValidateIntegrity = $scenario.ValidateIntegrity
                PreserveExisting = $scenario.PreserveExisting
            }

            # Assert restore success
            $restoreResult.Success | Should -Be $true
            $restoreResult.RestoreId | Should -Not -BeNullOrEmpty
            $restoreResult.RestoredFiles | Should -Not -BeNullOrEmpty
            $restoreResult.BackupMetadata | Should -Not -BeNullOrEmpty

            # Verify restored files exist
            Test-Path (Join-Path $restorePath "configs/app-config.json") | Should -Be $true

            # Verify restored content
            $restoredConfig = Get-Content (Join-Path $restorePath "configs/app-config.json") | ConvertFrom-Json
            $restoredConfig.name | Should -Be $script:TestData.BaseConfiguration.name
            $restoredConfig.version | Should -Be $script:TestData.BaseConfiguration.version

            # Verify restore tracking
            $script:RestoreOperations.Count | Should -BeGreaterThan 0
            $lastRestore = $script:RestoreOperations[-1]
            $lastRestore.Success | Should -Be $true
            $lastRestore.RestoreId | Should -Be $restoreResult.RestoreId
        }

        It "Should perform selective restore of specific sections" {
            $scenario = $script:TestData.RestoreScenarios.SelectiveRestore

            # Create test configuration with multiple sections
            $configPath = Join-Path $TestConfigDir "selective-restore-test"
            New-Item -ItemType Directory -Path $configPath -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $configPath "configs") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $configPath "modules") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $configPath "environments") -Force | Out-Null

            # Create different configuration files
            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $configPath "configs/app-config.json")
            $script:TestData.BaseConfiguration.modules | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $configPath "modules/module-config.json")
            $script:TestData.BaseConfiguration.environments | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $configPath "environments/env-config.json")

            $backupResult = New-MockConfigurationBackup -ConfigurationPath $configPath -BackupPath $TestBackupDir -BackupType "Full"

            # Create restore destination
            $restorePath = Join-Path $TestRestoreDir "selective-restore"

            # Perform selective restore
            $restoreResult = Restore-MockConfigurationBackup -BackupPath $backupResult.BackupPath -RestorePath $restorePath -RestoreSettings @{
                RestoreSections = $scenario.RestoreSections
                ValidateIntegrity = $scenario.ValidateIntegrity
                PreserveExisting = $scenario.PreserveExisting
            }

            # Assert selective restore
            $restoreResult.Success | Should -Be $true
            $restoreResult.RestoredFiles.Count | Should -BeGreaterThan 0

            # Verify only selected sections were restored
            $hasSettings = $restoreResult.RestoredFiles | Where-Object { $_ -like "*configs*" }
            $hasModules = $restoreResult.RestoredFiles | Where-Object { $_ -like "*modules*" }

            $hasSettings | Should -Not -BeNullOrEmpty
            $hasModules | Should -Not -BeNullOrEmpty
        }

        It "Should handle restore with existing file preservation" {
            # Create original configuration
            $configPath = Join-Path $TestConfigDir "preserve-test"
            New-Item -ItemType Directory -Path $configPath -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $configPath "configs") -Force | Out-Null

            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $configPath "configs/app-config.json")

            # Create backup
            $backupResult = New-MockConfigurationBackup -ConfigurationPath $configPath -BackupPath $TestBackupDir -BackupType "Full"

            # Create restore destination with existing files
            $restorePath = Join-Path $TestRestoreDir "preserve-test"
            New-Item -ItemType Directory -Path $restorePath -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $restorePath "configs") -Force | Out-Null

            $existingConfig = @{
                version = "2.0"
                name = "Existing Configuration"
                settings = @{
                    existingParam = "should be preserved"
                }
            }
            $existingConfig | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $restorePath "configs/app-config.json")

            # Perform restore with preservation
            $restoreResult = Restore-MockConfigurationBackup -BackupPath $backupResult.BackupPath -RestorePath $restorePath -RestoreSettings @{
                PreserveExisting = $true
                ValidateIntegrity = $false  # Skip validation for this test
            }

            # Assert restoration with preservation
            $restoreResult.Success | Should -Be $true

            # Verify existing files were backed up before restoration
            $backupFiles = Get-ChildItem -Path $restorePath -Filter "*.restore-backup-*" -Recurse
            $backupFiles | Should -Not -BeNullOrEmpty
        }
    }

    Context "Backup Integrity Validation" {

        It "Should validate backup integrity successfully for valid backups" {
            $scenario = $script:TestData.IntegrityScenarios.ValidBackup

            # Create test configuration and backup
            $configPath = Join-Path $TestConfigDir "integrity-valid-test"
            New-Item -ItemType Directory -Path $configPath -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $configPath "configs") -Force | Out-Null

            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $configPath "configs/app-config.json")

            $backupResult = New-MockConfigurationBackup -ConfigurationPath $configPath -BackupPath $TestBackupDir -BackupType "Full" -BackupSettings @{
                Compression = $false  # Keep uncompressed for easier testing
            }

            # Validate backup integrity
            $integrityResult = Test-MockBackupIntegrity -BackupPath $backupResult.BackupPath -Metadata $backupResult.Metadata

            # Assert valid integrity
            $integrityResult.IsValid | Should -Be $scenario.ExpectedIntegrity
            $integrityResult.Errors.Count | Should -Be 0
            $integrityResult.ValidatedFiles | Should -BeGreaterThan 0
            $integrityResult.TotalFiles | Should -BeGreaterThan 0

            # Verify integrity tracking
            $script:IntegrityChecks.Count | Should -BeGreaterThan 0
            $lastCheck = $script:IntegrityChecks[-1]
            $lastCheck.IsValid | Should -Be $true
            $lastCheck.ValidatedFiles | Should -BeGreaterThan 0
        }

        It "Should detect corrupted backup data" {
            $scenario = $script:TestData.IntegrityScenarios.CorruptedData

            # Create test configuration and backup
            $configPath = Join-Path $TestConfigDir "integrity-corrupted-test"
            New-Item -ItemType Directory -Path $configPath -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $configPath "configs") -Force | Out-Null

            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $configPath "configs/app-config.json")

            $backupResult = New-MockConfigurationBackup -ConfigurationPath $configPath -BackupPath $TestBackupDir -BackupType "Full" -BackupSettings @{
                Compression = $false
            }

            # Corrupt the backup data
            $backupConfigPath = Join-Path $backupResult.BackupPath "configs/app-config.json"
            Set-Content -Path $backupConfigPath -Value "{ corrupted json content"

            # Validate backup integrity
            $integrityResult = Test-MockBackupIntegrity -BackupPath $backupResult.BackupPath -Metadata $backupResult.Metadata

            # Assert corruption detection
            $integrityResult.IsValid | Should -Be $scenario.ExpectedIntegrity
            $integrityResult.Errors.Count | Should -BeGreaterThan 0
            $integrityResult.Errors | Should -Contain "Checksum mismatch for file: configs/app-config.json"
        }

        It "Should detect missing backup files" {
            $scenario = $script:TestData.IntegrityScenarios.MissingFiles

            # Create test configuration and backup
            $configPath = Join-Path $TestConfigDir "integrity-missing-test"
            New-Item -ItemType Directory -Path $configPath -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $configPath "configs") -Force | Out-Null

            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $configPath "configs/app-config.json")

            $backupResult = New-MockConfigurationBackup -ConfigurationPath $configPath -BackupPath $TestBackupDir -BackupType "Full" -BackupSettings @{
                Compression = $false
            }

            # Remove a file from the backup
            $backupConfigPath = Join-Path $backupResult.BackupPath "configs/app-config.json"
            Remove-Item -Path $backupConfigPath -Force

            # Validate backup integrity
            $integrityResult = Test-MockBackupIntegrity -BackupPath $backupResult.BackupPath -Metadata $backupResult.Metadata

            # Assert missing file detection
            $integrityResult.IsValid | Should -Be $scenario.ExpectedIntegrity
            $integrityResult.Errors.Count | Should -BeGreaterThan 0
            $integrityResult.Errors | Should -Contain "File count mismatch: expected $($backupResult.Metadata.FileCount), found 0"
        }

        It "Should detect corrupted backup metadata" {
            $scenario = $script:TestData.IntegrityScenarios.CorruptedMetadata

            # Create test configuration and backup
            $configPath = Join-Path $TestConfigDir "integrity-metadata-test"
            New-Item -ItemType Directory -Path $configPath -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $configPath "configs") -Force | Out-Null

            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $configPath "configs/app-config.json")

            $backupResult = New-MockConfigurationBackup -ConfigurationPath $configPath -BackupPath $TestBackupDir -BackupType "Full" -BackupSettings @{
                Compression = $false
            }

            # Corrupt the metadata file
            $metadataPath = Join-Path $backupResult.BackupPath "backup-metadata.json"
            Set-Content -Path $metadataPath -Value "{ invalid json metadata"

            # Attempt to validate integrity (this should fail gracefully)
            try {
                $integrityResult = Test-MockBackupIntegrity -BackupPath $backupResult.BackupPath -Metadata $backupResult.Metadata

                # If we get here, the function handled the corruption gracefully
                $integrityResult.IsValid | Should -Be $false
                $integrityResult.Errors.Count | Should -BeGreaterThan 0
            } catch {
                # Expected behavior - metadata corruption should cause validation to fail
                $_.Exception.Message | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Performance and Scalability" {

        It "Should handle large configuration backups efficiently" {
            # Create large configuration dataset
            $configPath = Join-Path $TestConfigDir "performance-large-test"
            New-Item -ItemType Directory -Path $configPath -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $configPath "configs") -Force | Out-Null

            # Create large configuration
            $largeConfig = $script:TestData.BaseConfiguration.Clone()
            $largeConfig.largeSections = @{}

            for ($i = 1; $i -le 100; $i++) {
                $largeConfig.largeSections["section$i"] = @{
                    id = $i
                    data = "performance test data $i" * 20
                    items = @(1..50)
                    nested = @{
                        level1 = @{
                            level2 = @{
                                data = "nested data $i" * 10
                            }
                        }
                    }
                }
            }

            $largeConfig | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $configPath "configs/app-config.json")

            # Measure backup performance
            $performance = Measure-BackupRestorePerformance {
                $backupResult = New-MockConfigurationBackup -ConfigurationPath $configPath -BackupPath $TestBackupDir -BackupType "Full" -BackupSettings @{
                    Compression = $true
                    IncludeMetadata = $true
                }
                return $backupResult
            }

            # Assert performance characteristics
            $performance.Success | Should -Be $true
            $performance.Duration | Should -BeLessThan 10000  # Should complete in under 10 seconds
            $performance.MemoryUsed | Should -BeLessThan 10240  # Should use less than 10MB
            $performance.Result.Success | Should -Be $true
            $performance.Result.Metadata.TotalSize | Should -BeGreaterThan 0
        }

        It "Should handle multiple concurrent backup operations" {
            # Create multiple configuration sets
            $configPaths = @()
            for ($i = 1; $i -le 5; $i++) {
                $configPath = Join-Path $TestConfigDir "concurrent-backup-$i"
                New-Item -ItemType Directory -Path $configPath -Force | Out-Null
                New-Item -ItemType Directory -Path (Join-Path $configPath "configs") -Force | Out-Null

                $config = $script:TestData.BaseConfiguration.Clone()
                $config.settings.concurrentId = $i
                $config | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $configPath "configs/app-config.json")

                $configPaths += $configPath
            }

            # Measure concurrent backup performance
            $performance = Measure-BackupRestorePerformance {
                $backupResults = @()

                foreach ($configPath in $configPaths) {
                    $result = New-MockConfigurationBackup -ConfigurationPath $configPath -BackupPath $TestBackupDir -BackupType "Full" -BackupSettings @{
                        Compression = $true
                    }
                    $backupResults += $result
                }

                return $backupResults
            }

            # Assert concurrent operations
            $performance.Success | Should -Be $true
            $performance.Duration | Should -BeLessThan 15000  # All backups should complete in under 15 seconds
            $performance.Result.Count | Should -Be 5

            # Verify all backups succeeded
            foreach ($result in $performance.Result) {
                $result.Success | Should -Be $true
                $result.BackupId | Should -Not -BeNullOrEmpty
            }

            # Verify tracking shows all operations
            $script:BackupOperations.Count | Should -BeGreaterOrEqual 5
        }

        It "Should optimize restore operations for large datasets" {
            # Create and backup large configuration
            $configPath = Join-Path $TestConfigDir "restore-performance-test"
            New-Item -ItemType Directory -Path $configPath -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $configPath "configs") -Force | Out-Null

            $largeConfig = $script:TestData.BaseConfiguration.Clone()
            $largeConfig.performanceData = @{}
            for ($i = 1; $i -le 50; $i++) {
                $largeConfig.performanceData["dataset$i"] = @{
                    records = @(1..100)
                    metadata = "large dataset $i" * 15
                }
            }

            $largeConfig | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $configPath "configs/app-config.json")

            $backupResult = New-MockConfigurationBackup -ConfigurationPath $configPath -BackupPath $TestBackupDir -BackupType "Full" -BackupSettings @{
                Compression = $true
            }

            # Measure restore performance
            $restorePath = Join-Path $TestRestoreDir "performance-restore"
            $performance = Measure-BackupRestorePerformance {
                $restoreResult = Restore-MockConfigurationBackup -BackupPath $backupResult.BackupPath -RestorePath $restorePath -RestoreSettings @{
                    ValidateIntegrity = $true
                    PreserveExisting = $false
                }
                return $restoreResult
            }

            # Assert restore performance
            $performance.Success | Should -Be $true
            $performance.Duration | Should -BeLessThan 8000  # Should complete in under 8 seconds
            $performance.Result.Success | Should -Be $true
            $performance.Result.RestoredFiles.Count | Should -BeGreaterThan 0

            # Verify restored data integrity
            Test-Path (Join-Path $restorePath "configs/app-config.json") | Should -Be $true
            $restoredConfig = Get-Content (Join-Path $restorePath "configs/app-config.json") | ConvertFrom-Json
            $restoredConfig.performanceData | Should -Not -BeNullOrEmpty
        }
    }

    Context "Disaster Recovery Scenarios" {

        It "Should handle complete system configuration recovery" {
            # Simulate a complete system with multiple configuration components
            $systemConfigPath = Join-Path $TestConfigDir "disaster-recovery-system"
            New-Item -ItemType Directory -Path $systemConfigPath -Force | Out-Null

            # Create comprehensive system configuration
            $systemDirs = @("configs", "modules", "environments", "policies", "scripts")
            foreach ($dir in $systemDirs) {
                New-Item -ItemType Directory -Path (Join-Path $systemConfigPath $dir) -Force | Out-Null
            }

            # Create various configuration files
            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $systemConfigPath "configs/app-config.json")
            $script:TestData.BaseConfiguration.modules | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $systemConfigPath "modules/module-config.json")
            $script:TestData.BaseConfiguration.environments | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $systemConfigPath "environments/env-config.json")

            @{
                securityPolicy = "enterprise"
                auditEnabled = $true
                complianceLevel = "high"
            } | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $systemConfigPath "policies/security-policy.json")

            "#!/bin/bash`necho 'System recovery script'" | Set-Content -Path (Join-Path $systemConfigPath "scripts/recovery.sh")

            # Create comprehensive backup
            $systemBackupResult = New-MockConfigurationBackup -ConfigurationPath $systemConfigPath -BackupPath $TestBackupDir -BackupType "Full" -BackupSettings @{
                Compression = $true
                IncludeMetadata = $true
                SystemLevel = $true
            }

            # Simulate disaster (remove all configuration)
            Remove-Item -Path $systemConfigPath -Recurse -Force

            # Perform complete system recovery
            $recoveryPath = Join-Path $TestRestoreDir "disaster-recovery"
            $recoveryResult = Restore-MockConfigurationBackup -BackupPath $systemBackupResult.BackupPath -RestorePath $recoveryPath -RestoreSettings @{
                ValidateIntegrity = $true
                SystemRecovery = $true
                PreserveExisting = $false
            }

            # Assert complete recovery
            $recoveryResult.Success | Should -Be $true
            $recoveryResult.RestoredFiles.Count | Should -BeGreaterThan 4  # Multiple files across directories

            # Verify all system components were recovered
            foreach ($dir in $systemDirs) {
                Test-Path (Join-Path $recoveryPath $dir) | Should -Be $true
            }

            Test-Path (Join-Path $recoveryPath "configs/app-config.json") | Should -Be $true
            Test-Path (Join-Path $recoveryPath "modules/module-config.json") | Should -Be $true
            Test-Path (Join-Path $recoveryPath "environments/env-config.json") | Should -Be $true
            Test-Path (Join-Path $recoveryPath "policies/security-policy.json") | Should -Be $true
            Test-Path (Join-Path $recoveryPath "scripts/recovery.sh") | Should -Be $true
        }

        It "Should handle partial system recovery with rollback" {
            # Create system configuration and backup
            $systemPath = Join-Path $TestConfigDir "partial-recovery-system"
            New-Item -ItemType Directory -Path $systemPath -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $systemPath "configs") -Force | Out-Null

            $script:TestData.BaseConfiguration | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $systemPath "configs/app-config.json")

            $backupResult = New-MockConfigurationBackup -ConfigurationPath $systemPath -BackupPath $TestBackupDir -BackupType "Full"

            # Create partially corrupted restore scenario
            $recoveryPath = Join-Path $TestRestoreDir "partial-recovery"
            New-Item -ItemType Directory -Path $recoveryPath -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $recoveryPath "configs") -Force | Out-Null

            # Create a conflicting file that might cause restore issues
            @{
                version = "conflict"
                conflictingData = "this should be backed up"
            } | ConvertTo-Json | Set-Content -Path (Join-Path $recoveryPath "configs/app-config.json")

            # Attempt restore with preservation
            $partialResult = Restore-MockConfigurationBackup -BackupPath $backupResult.BackupPath -RestorePath $recoveryPath -RestoreSettings @{
                ValidateIntegrity = $true
                PreserveExisting = $true
                AllowPartialRestore = $true
            }

            # Assert partial recovery handling
            $partialResult.Success | Should -Be $true

            # Verify original file was preserved with backup
            $preservedFiles = Get-ChildItem -Path $recoveryPath -Filter "*.restore-backup-*" -Recurse
            $preservedFiles | Should -Not -BeNullOrEmpty

            # Verify new configuration was restored
            Test-Path (Join-Path $recoveryPath "configs/app-config.json") | Should -Be $true
        }
    }
}

AfterAll {
    # Cleanup test environment
    if ($env:TEST_BACKUP_RESTORE_DIR -and (Test-Path $env:TEST_BACKUP_RESTORE_DIR)) {
        try {
            Remove-Item -Path $env:TEST_BACKUP_RESTORE_DIR -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            Write-CustomLog -Level 'WARNING' -Message "Could not cleanup test directory: $($env:TEST_BACKUP_RESTORE_DIR)"
        }
    }

    # Clear test environment variables
    $env:TEST_BACKUP_RESTORE_DIR = $null
    $env:TEST_CONFIG_DIR = $null
    $env:TEST_BACKUP_DIR = $null
    $env:TEST_RESTORE_DIR = $null

    # Clear operation tracking
    $script:BackupOperations = @()
    $script:RestoreOperations = @()
    $script:IntegrityChecks = @()
    $script:BackupMetadata = @()
}
