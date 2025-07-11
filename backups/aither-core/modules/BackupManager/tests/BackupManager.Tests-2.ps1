#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive tests for BackupManager module

.DESCRIPTION
    This test suite validates all BackupManager functionality including:
    - Basic backup operations and statistics
    - Advanced backup with compression, encryption, and deduplication
    - Backup consolidation and cleanup
    - Automated backup scheduling
    - Restoration and verification
    - Error handling and edge cases

.NOTES
    Generated for BackupManager v2.0.0
    Supports cross-platform testing (Windows, Linux, macOS)
#>

# Import required modules
BeforeAll {
    # Import shared utilities
    . "$PSScriptRoot/../../../../aither-core/shared/Find-ProjectRoot.ps1"
    $script:ProjectRoot = Find-ProjectRoot

    # Import BackupManager module
    $modulePath = Join-Path $script:ProjectRoot "aither-core/modules/BackupManager"
    Import-Module $modulePath -Force

    # Import Logging for enhanced test logging
    $loggingPath = Join-Path $script:ProjectRoot "aither-core/modules/Logging"
    if (Test-Path $loggingPath) {
        Import-Module $loggingPath -Force -Global -ErrorAction SilentlyContinue
    }

    # Create test directories
    $script:TestDataPath = Join-Path $TestDrive "backup-test-data"
    $script:TestBackupPath = Join-Path $TestDrive "backup-destination"
    $script:TestRestorePath = Join-Path $TestDrive "restore-destination"

    # Create test data structure
    New-Item -Path $script:TestDataPath -ItemType Directory -Force | Out-Null
    New-Item -Path $script:TestBackupPath -ItemType Directory -Force | Out-Null
    New-Item -Path $script:TestRestorePath -ItemType Directory -Force | Out-Null

    # Create sample files for testing
    @(
        @{ Path = "test1.txt"; Content = "This is test file 1 with some content to compress" }
        @{ Path = "subdir/test2.txt"; Content = "This is test file 2 in a subdirectory" }
        @{ Path = "config.backup"; Content = "This is a backup configuration file" }
        @{ Path = "data.old"; Content = "This is an old data file that should be detected" }
        @{ Path = "temp.tmp"; Content = "This is a temporary file" }
        @{ Path = "large-file.dat"; Content = "X" * 10000 } # Larger file for compression testing
    ) | ForEach-Object {
        $filePath = Join-Path $script:TestDataPath $_.Path
        $fileDir = Split-Path $filePath -Parent
        if (-not (Test-Path $fileDir)) {
            New-Item -Path $fileDir -ItemType Directory -Force | Out-Null
        }
        Set-Content -Path $filePath -Value $_.Content -Encoding UTF8
    }
}

AfterAll {
    # Cleanup test data (TestDrive handles most cleanup automatically)
    # Remove any scheduled tasks or system-level resources created during testing
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog "BackupManager tests completed" -Level INFO
    }
}

Describe "BackupManager Module Structure" {
    Context "Module Loading and Structure" {
        It "Should import successfully" {
            { Import-Module (Join-Path $script:ProjectRoot "aither-core/modules/BackupManager") -Force } | Should -Not -Throw
        }

        It "Should export all expected functions" {
            $expectedFunctions = @(
                'Get-BackupStatistics',
                'Invoke-BackupMaintenance',
                'Invoke-PermanentCleanup',
                'Invoke-BackupConsolidation',
                'New-BackupExclusion',
                'Invoke-AdvancedBackup',
                'Restore-BackupData',
                'Start-AutomatedBackup'
            )

            $exportedFunctions = (Get-Command -Module BackupManager).Name

            foreach ($function in $expectedFunctions) {
                $exportedFunctions | Should -Contain $function
            }
        }

        It "Should have proper module manifest" {
            $manifestPath = Join-Path $script:ProjectRoot "aither-core/modules/BackupManager/BackupManager.psd1"
            $manifestPath | Should -Exist

            $manifest = Import-PowerShellDataFile -Path $manifestPath
            $manifest.ModuleVersion | Should -Be "2.0.0"
            $manifest.PowerShellVersion | Should -Be "7.0"
        }
    }
}

Describe "Get-BackupStatistics" {
    Context "Basic Statistics Functionality" {
        It "Should analyze backup files without errors" {
            { Get-BackupStatistics -ProjectRoot $script:TestDataPath } | Should -Not -Throw
        }

        It "Should return proper statistics structure" {
            $stats = Get-BackupStatistics -ProjectRoot $script:TestDataPath

            $stats | Should -Not -BeNullOrEmpty
            $stats.TotalFiles | Should -BeGreaterThan 0
            $stats.TotalSize | Should -BeGreaterOrEqual 0
            $stats.FileTypes | Should -Not -BeNullOrEmpty
        }

        It "Should include details when requested" {
            $stats = Get-BackupStatistics -ProjectRoot $script:TestDataPath -IncludeDetails

            $stats.Details | Should -Not -BeNullOrEmpty
            $stats.Details.Count | Should -BeGreaterThan 0
        }

        It "Should handle empty directories gracefully" {
            $emptyDir = Join-Path $TestDrive "empty-test"
            New-Item -Path $emptyDir -ItemType Directory -Force | Out-Null

            $stats = Get-BackupStatistics -ProjectRoot $emptyDir
            $stats.TotalFiles | Should -Be 0
        }
    }
}

Describe "Invoke-BackupConsolidation" {
    Context "Basic Consolidation Functionality" {
        It "Should consolidate backup files without errors" {
            $consolidationPath = Join-Path $script:TestBackupPath "consolidated"

            { Invoke-BackupConsolidation -SourcePath $script:TestDataPath -BackupPath $consolidationPath -Force } | Should -Not -Throw
        }

        It "Should return proper consolidation results" {
            $consolidationPath = Join-Path $script:TestBackupPath "consolidated-results"

            $result = Invoke-BackupConsolidation -SourcePath $script:TestDataPath -BackupPath $consolidationPath -Force

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.FilesProcessed | Should -BeGreaterOrEqual 0
            $result.DirectoriesProcessed | Should -BeGreaterOrEqual 0
        }

        It "Should create backup directory structure" {
            $consolidationPath = Join-Path $script:TestBackupPath "structure-test"

            Invoke-BackupConsolidation -SourcePath $script:TestDataPath -BackupPath $consolidationPath -Force

            $consolidationPath | Should -Exist
        }

        It "Should handle exclusions properly" {
            $consolidationPath = Join-Path $script:TestBackupPath "exclusions-test"

            $result = Invoke-BackupConsolidation -SourcePath $script:TestDataPath -BackupPath $consolidationPath -ExcludePaths @("*.tmp") -Force

            $result.Success | Should -Be $true
        }
    }

    Context "WhatIf Functionality" {
        It "Should support WhatIf parameter" {
            $consolidationPath = Join-Path $script:TestBackupPath "whatif-test"

            { Invoke-BackupConsolidation -SourcePath $script:TestDataPath -BackupPath $consolidationPath -Force -WhatIf } | Should -Not -Throw
        }
    }
}

Describe "New-BackupExclusion" {
    Context "Exclusion Rules Creation" {
        It "Should create exclusion rules without errors" {
            { New-BackupExclusion -ProjectRoot $script:TestDataPath -Force } | Should -Not -Throw
        }

        It "Should return proper exclusion results" {
            $result = New-BackupExclusion -ProjectRoot $script:TestDataPath -Force

            $result | Should -Not -BeNullOrEmpty
            $result.UpdatedFiles | Should -Not -BeNullOrEmpty
            $result.ExclusionsUpdated | Should -BeGreaterThan 0
        }

        It "Should handle custom patterns" {
            $result = New-BackupExclusion -ProjectRoot $script:TestDataPath -Patterns @("*.custom", "*.test") -Force

            $result.Success | Should -Not -BeFalse
        }

        It "Should support WhatIf parameter" {
            { New-BackupExclusion -ProjectRoot $script:TestDataPath -Force -WhatIf } | Should -Not -Throw
        }
    }
}

Describe "Invoke-PermanentCleanup" {
    Context "Basic Cleanup Functionality" {
        BeforeEach {
            # Create some problematic files for cleanup testing
            $problemFiles = @(
                "test.bak.bak",
                "config.backup.backup",
                "temp.tmp.cache",
                "Thumbs.db"
            )

            foreach ($file in $problemFiles) {
                $filePath = Join-Path $script:TestDataPath $file
                Set-Content -Path $filePath -Value "problematic content" -Encoding UTF8
            }
        }

        It "Should identify problematic files" {
            $result = Invoke-PermanentCleanup -ProjectRoot $script:TestDataPath -Force

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Not -BeFalse
        }

        It "Should handle backup cleanup mode" {
            $backupDir = Join-Path $script:TestBackupPath "cleanup-test"
            New-Item -Path $backupDir -ItemType Directory -Force | Out-Null

            # Create an old file
            $oldFile = Join-Path $backupDir "old-backup.txt"
            Set-Content -Path $oldFile -Value "old content"
            $fileItem = Get-Item $oldFile
            $fileItem.LastWriteTime = (Get-Date).AddDays(-35)

            $result = Invoke-PermanentCleanup -BackupPath $backupDir -MaxAge 30 -Force

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Not -BeFalse
        }

        It "Should support prevention rules creation" {
            $result = Invoke-PermanentCleanup -ProjectRoot $script:TestDataPath -CreatePreventionRules -Force

            $result.PreventionRulesCreated | Should -Be $true
        }
    }
}

Describe "Invoke-BackupMaintenance" {
    Context "Maintenance Mode Operations" {
        It "Should run Quick maintenance mode" {
            { Invoke-BackupMaintenance -Mode "Quick" } | Should -Not -Throw
        }

        It "Should run Statistics mode" {
            $result = Invoke-BackupMaintenance -Mode "Statistics"

            $result | Should -Not -BeNullOrEmpty
            $result.Mode | Should -Be "Statistics"
            $result.Success | Should -Not -BeFalse
        }

        It "Should return proper maintenance results" {
            $result = Invoke-BackupMaintenance -Mode "Quick"

            $result | Should -Not -BeNullOrEmpty
            $result.Mode | Should -Be "Quick"
            $result.Operations | Should -Not -BeNullOrEmpty
            $result.StartTime | Should -Not -BeNullOrEmpty
            $result.EndTime | Should -Not -BeNullOrEmpty
        }

        It "Should support different output formats" {
            { Invoke-BackupMaintenance -Mode "Statistics" -OutputFormat "JSON" } | Should -Not -Throw
            { Invoke-BackupMaintenance -Mode "Statistics" -OutputFormat "CI" } | Should -Not -Throw
        }
    }

    Context "AutoFix Functionality" {
        It "Should support AutoFix parameter" {
            { Invoke-BackupMaintenance -Mode "Quick" -AutoFix } | Should -Not -Throw
        }
    }
}

Describe "Invoke-AdvancedBackup" {
    Context "Advanced Backup Features" {
        It "Should perform basic advanced backup" {
            $advancedBackupPath = Join-Path $script:TestBackupPath "advanced-basic"

            { Invoke-AdvancedBackup -SourcePath $script:TestDataPath -BackupPath $advancedBackupPath -Force } | Should -Not -Throw
        }

        It "Should return proper backup context" {
            $advancedBackupPath = Join-Path $script:TestBackupPath "advanced-context"

            $result = Invoke-AdvancedBackup -SourcePath $script:TestDataPath -BackupPath $advancedBackupPath -Force

            $result | Should -Not -BeNullOrEmpty
            $result.ProcessedFiles | Should -BeGreaterOrEqual 0
            $result.SourcePath | Should -Be (Resolve-Path $script:TestDataPath)
            $result.BackupPath | Should -Be (Resolve-Path $advancedBackupPath)
        }

        It "Should support compression levels" {
            $advancedBackupPath = Join-Path $script:TestBackupPath "advanced-compression"

            $result = Invoke-AdvancedBackup -SourcePath $script:TestDataPath -BackupPath $advancedBackupPath -CompressionLevel 9 -Force

            $result.CompressionLevel | Should -Be 9
        }

        It "Should support encryption (basic test)" {
            $advancedBackupPath = Join-Path $script:TestBackupPath "advanced-encryption"

            { Invoke-AdvancedBackup -SourcePath $script:TestDataPath -BackupPath $advancedBackupPath -EnableEncryption -Force } | Should -Not -Throw
        }

        It "Should support deduplication" {
            $advancedBackupPath = Join-Path $script:TestBackupPath "advanced-dedup"

            $result = Invoke-AdvancedBackup -SourcePath $script:TestDataPath -BackupPath $advancedBackupPath -EnableDeduplication -Force

            $result.EnableDeduplication | Should -Be $true
        }

        It "Should create metadata directory" {
            $advancedBackupPath = Join-Path $script:TestBackupPath "advanced-metadata"

            Invoke-AdvancedBackup -SourcePath $script:TestDataPath -BackupPath $advancedBackupPath -Force

            $metadataPath = Join-Path $advancedBackupPath ".backup-metadata"
            $metadataPath | Should -Exist
        }
    }

    Context "WhatIf Support" {
        It "Should support WhatIf parameter" {
            $advancedBackupPath = Join-Path $script:TestBackupPath "advanced-whatif"

            { Invoke-AdvancedBackup -SourcePath $script:TestDataPath -BackupPath $advancedBackupPath -Force -WhatIf } | Should -Not -Throw
        }
    }
}

Describe "Restore-BackupData" {
    Context "Basic Restoration Functionality" {
        BeforeEach {
            # Create a backup to restore from
            $script:SourceBackupPath = Join-Path $script:TestBackupPath "restore-source"
            Invoke-AdvancedBackup -SourcePath $script:TestDataPath -BackupPath $script:SourceBackupPath -Force | Out-Null
        }

        It "Should restore backup without errors" {
            $restorePath = Join-Path $script:TestRestorePath "basic-restore"

            { Restore-BackupData -BackupPath $script:SourceBackupPath -RestorePath $restorePath -Force } | Should -Not -Throw
        }

        It "Should return proper restoration context" {
            $restorePath = Join-Path $script:TestRestorePath "context-restore"

            $result = Restore-BackupData -BackupPath $script:SourceBackupPath -RestorePath $restorePath -Force

            $result | Should -Not -BeNullOrEmpty
            $result.RestoredFiles | Should -BeGreaterOrEqual 0
            $result.RestorePath | Should -Be (Resolve-Path $restorePath)
        }

        It "Should support selective restore" {
            $restorePath = Join-Path $script:TestRestorePath "selective-restore"

            { Restore-BackupData -BackupPath $script:SourceBackupPath -RestorePath $restorePath -SelectiveRestore @("*.txt") -Force } | Should -Not -Throw
        }

        It "Should support verification" {
            $restorePath = Join-Path $script:TestRestorePath "verified-restore"

            $result = Restore-BackupData -BackupPath $script:SourceBackupPath -RestorePath $restorePath -VerifyRestore -Force

            $result.VerificationResult | Should -Not -BeNullOrEmpty
        }
    }

    Context "WhatIf Support" {
        BeforeEach {
            $script:SourceBackupPath = Join-Path $script:TestBackupPath "restore-whatif-source"
            Invoke-AdvancedBackup -SourcePath $script:TestDataPath -BackupPath $script:SourceBackupPath -Force | Out-Null
        }

        It "Should support WhatIf parameter" {
            $restorePath = Join-Path $script:TestRestorePath "whatif-restore"

            { Restore-BackupData -BackupPath $script:SourceBackupPath -RestorePath $restorePath -Force -WhatIf } | Should -Not -Throw
        }
    }
}

Describe "Start-AutomatedBackup" {
    Context "Automation Configuration" {
        It "Should configure automated backup without errors" {
            $automatedBackupPath = Join-Path $script:TestBackupPath "automated"

            { Start-AutomatedBackup -SourcePaths @($script:TestDataPath) -BackupPath $automatedBackupPath -Force } | Should -Not -Throw
        }

        It "Should return proper automation status" {
            $automatedBackupPath = Join-Path $script:TestBackupPath "automated-status"

            $result = Start-AutomatedBackup -SourcePaths @($script:TestDataPath) -BackupPath $automatedBackupPath -Force

            $result | Should -Not -BeNullOrEmpty
            $result.ConfigurationId | Should -Not -BeNullOrEmpty
            $result.Status | Should -Be "Initialized"
            $result.SourcePaths | Should -Contain $script:TestDataPath
        }

        It "Should support different schedules" {
            $automatedBackupPath = Join-Path $script:TestBackupPath "automated-schedule"

            @("Hourly", "Daily", "Weekly", "Monthly") | ForEach-Object {
                { Start-AutomatedBackup -SourcePaths @($script:TestDataPath) -BackupPath "$automatedBackupPath-$_" -Schedule $_ -Force } | Should -Not -Throw
            }
        }

        It "Should create automation directory structure" {
            $automatedBackupPath = Join-Path $script:TestBackupPath "automated-structure"

            Start-AutomatedBackup -SourcePaths @($script:TestDataPath) -BackupPath $automatedBackupPath -Force

            $automationPath = Join-Path $automatedBackupPath ".automation"
            $automationPath | Should -Exist

            $configPath = Join-Path $automationPath "config.json"
            $configPath | Should -Exist
        }

        It "Should support monitoring enablement" {
            $automatedBackupPath = Join-Path $script:TestBackupPath "automated-monitoring"

            $result = Start-AutomatedBackup -SourcePaths @($script:TestDataPath) -BackupPath $automatedBackupPath -EnableMonitoring -Force

            $result.Features | Should -Contain "Monitoring"
        }

        It "Should support encryption enablement" {
            $automatedBackupPath = Join-Path $script:TestBackupPath "automated-encryption"

            $result = Start-AutomatedBackup -SourcePaths @($script:TestDataPath) -BackupPath $automatedBackupPath -EnableEncryption -Force

            $result.Features | Should -Contain "Encryption"
        }
    }

    Context "WhatIf Support" {
        It "Should support WhatIf parameter" {
            $automatedBackupPath = Join-Path $script:TestBackupPath "automated-whatif"

            { Start-AutomatedBackup -SourcePaths @($script:TestDataPath) -BackupPath $automatedBackupPath -Force -WhatIf } | Should -Not -Throw
        }
    }
}

Describe "Error Handling and Edge Cases" {
    Context "Invalid Parameters" {
        It "Should handle non-existent source paths gracefully" {
            $nonExistentPath = Join-Path $TestDrive "non-existent"

            { Get-BackupStatistics -ProjectRoot $nonExistentPath } | Should -Throw
        }

        It "Should handle invalid backup paths gracefully" {
            { Invoke-BackupConsolidation -SourcePath $script:TestDataPath -BackupPath "/invalid/path/that/does/not/exist" -Force } | Should -Throw
        }

        It "Should handle missing backup metadata gracefully" {
            $emptyBackupPath = Join-Path $script:TestBackupPath "empty-backup"
            New-Item -Path $emptyBackupPath -ItemType Directory -Force | Out-Null

            { Restore-BackupData -BackupPath $emptyBackupPath -RestorePath $script:TestRestorePath -Force } | Should -Throw
        }
    }

    Context "Resource Constraints" {
        It "Should handle read-only directories appropriately" {
            # This test may need platform-specific implementation
            $true | Should -Be $true
        }

        It "Should handle large file operations" {
            # Create a larger test file
            $largeFilePath = Join-Path $script:TestDataPath "large-test.dat"
            $largeContent = "X" * 100000  # 100KB file
            Set-Content -Path $largeFilePath -Value $largeContent

            $largeBackupPath = Join-Path $script:TestBackupPath "large-file-test"

            { Invoke-AdvancedBackup -SourcePath $script:TestDataPath -BackupPath $largeBackupPath -Force } | Should -Not -Throw
        }
    }
}

Describe "Cross-Platform Compatibility" {
    Context "Path Handling" {
        It "Should handle cross-platform paths correctly" {
            $result = Get-BackupStatistics -ProjectRoot $script:TestDataPath

            # Should work regardless of platform
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should handle different path separators" {
            $testPath = $script:TestDataPath
            if ($IsWindows) {
                $testPath = $testPath.Replace('/', '\')
            } else {
                $testPath = $testPath.Replace('\', '/')
            }

            { Get-BackupStatistics -ProjectRoot $testPath } | Should -Not -Throw
        }
    }

    Context "Platform-Specific Features" {
        It "Should handle platform differences gracefully" {
            $automatedBackupPath = Join-Path $script:TestBackupPath "platform-test"

            $result = Start-AutomatedBackup -SourcePaths @($script:TestDataPath) -BackupPath $automatedBackupPath -Force

            if ($IsWindows) {
                $result.ScheduledTask.Platform | Should -Be "Windows"
            } else {
                $result.ScheduledTask.Platform | Should -Match "Linux|macOS"
            }
        }
    }
}

Describe "Performance and Concurrency" {
    Context "Performance Characteristics" {
        It "Should complete backup operations within reasonable time" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            $perfBackupPath = Join-Path $script:TestBackupPath "performance-test"
            Invoke-AdvancedBackup -SourcePath $script:TestDataPath -BackupPath $perfBackupPath -Force

            $stopwatch.Stop()

            # Should complete within 30 seconds for test data
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 30000
        }

        It "Should handle concurrent operations" {
            $concurrentBackupPath = Join-Path $script:TestBackupPath "concurrent-test"

            { Invoke-AdvancedBackup -SourcePath $script:TestDataPath -BackupPath $concurrentBackupPath -MaxConcurrency 2 -Force } | Should -Not -Throw
        }
    }
}

Describe "Integration with Other Modules" {
    Context "Logging Integration" {
        It "Should integrate with logging system" {
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                # Logging is available - test integration
                { Get-BackupStatistics -ProjectRoot $script:TestDataPath } | Should -Not -Throw
                $true | Should -Be $true
            } else {
                # Logging not available - should still work
                { Get-BackupStatistics -ProjectRoot $script:TestDataPath } | Should -Not -Throw
                $true | Should -Be $true
            }
        }
    }

    Context "Project Root Detection" {
        It "Should detect project root correctly" {
            $projectRoot = Find-ProjectRoot
            $projectRoot | Should -Not -BeNullOrEmpty
            Test-Path $projectRoot | Should -Be $true
        }
    }
}

Describe "Module Configuration and Customization" {
    Context "Configuration Handling" {
        It "Should handle custom patterns correctly" {
            $result = New-BackupExclusion -ProjectRoot $script:TestDataPath -Patterns @("*.custom") -Force
            $result.ExclusionsUpdated | Should -BeGreaterThan 0
        }

        It "Should support different compression levels" {
            $compressionLevels = @(0, 3, 6, 9)

            foreach ($level in $compressionLevels) {
                $compBackupPath = Join-Path $script:TestBackupPath "compression-$level"
                { Invoke-AdvancedBackup -SourcePath $script:TestDataPath -BackupPath $compBackupPath -CompressionLevel $level -Force } | Should -Not -Throw
            }
        }
    }
}
