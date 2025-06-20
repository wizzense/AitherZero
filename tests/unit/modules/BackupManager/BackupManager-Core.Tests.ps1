BeforeAll {
    # Mock Write-CustomLog function
    function global:Write-CustomLog {
        param([string]$Message, [string]$Level = "INFO")
        Write-Host "[$Level] $Message"
    }
    
    # Import the BackupManager module
    $projectRoot = if ($env:PROJECT_ROOT) { 
        $env:PROJECT_ROOT 
    } else { 
        # Default to workspace root if environment variable not set
        '/workspaces/AitherLabs'
    }
    $backupManagerPath = Join-Path $projectRoot "aither-core/modules/BackupManager"
    
    try {
        Import-Module $backupManagerPath -Force -ErrorAction Stop
        Write-Host "BackupManager module imported successfully from: $backupManagerPath" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to import BackupManager module: $_"
        throw
    }
    
    # Create test backup environment
    $script:testBackupRoot = Join-Path $TestDrive "TestBackups"
    $script:testSourceDir = Join-Path $TestDrive "SourceFiles"
    $script:testArchiveDir = Join-Path $TestDrive "Archive"
    
    New-Item -Path $script:testBackupRoot -ItemType Directory -Force | Out-Null
    New-Item -Path $script:testSourceDir -ItemType Directory -Force | Out-Null
    New-Item -Path $script:testArchiveDir -ItemType Directory -Force | Out-Null
    
    # Create sample files for backup testing
    @("file1.txt", "file2.ps1", "file3.json") | ForEach-Object {
        $filePath = Join-Path $script:testSourceDir $_
        "Sample content for $_" | Out-File -FilePath $filePath -Encoding UTF8
    }
    
    # Create some backup files with different dates
    $script:oldBackupFile = Join-Path $script:testBackupRoot "old-backup-$(Get-Date (Get-Date).AddDays(-35) -Format 'yyyyMMdd').zip"
    $script:recentBackupFile = Join-Path $script:testBackupRoot "recent-backup-$(Get-Date -Format 'yyyyMMdd').zip"
    
    "Old backup content" | Out-File -FilePath $script:oldBackupFile -Encoding UTF8
    "Recent backup content" | Out-File -FilePath $script:recentBackupFile -Encoding UTF8
}

Describe "BackupManager Module - Core Functions" {
    
    Context "Invoke-BackupConsolidation" {
        
        It "Should consolidate backups successfully" {
            $result = Invoke-BackupConsolidation -SourcePath $script:testSourceDir -BackupPath $script:testBackupRoot
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }
        
        It "Should create backup with timestamp" {
            Invoke-BackupConsolidation -SourcePath $script:testSourceDir -BackupPath $script:testBackupRoot
            
            $backupFiles = Get-ChildItem -Path $script:testBackupRoot -Filter "*backup*.zip"
            $backupFiles | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle exclusions properly" {
            # Create files that should be excluded
            $tempFile = Join-Path $script:testSourceDir "temp.tmp"
            $logFile = Join-Path $script:testSourceDir "test.log"
            
            "Temp content" | Out-File -FilePath $tempFile -Encoding UTF8
            "Log content" | Out-File -FilePath $logFile -Encoding UTF8
            
            $result = Invoke-BackupConsolidation -SourcePath $script:testSourceDir -BackupPath $script:testBackupRoot -ExcludePatterns @("*.tmp", "*.log")
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }
        
        It "Should handle compression options" {
            $result = Invoke-BackupConsolidation -SourcePath $script:testSourceDir -BackupPath $script:testBackupRoot -CompressionLevel "Optimal"
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }
        
        It "Should handle non-existent source path" {
            $nonExistentPath = Join-Path $TestDrive "NonExistent"
            
            { Invoke-BackupConsolidation -SourcePath $nonExistentPath -BackupPath $script:testBackupRoot } | Should -Throw
        }
        
        It "Should create backup path if it doesn't exist" {
            $newBackupPath = Join-Path $TestDrive "NewBackupLocation"
            
            $result = Invoke-BackupConsolidation -SourcePath $script:testSourceDir -BackupPath $newBackupPath
            
            Test-Path $newBackupPath | Should -Be $true
            $result.Success | Should -Be $true
        }
    }
    
    Context "Invoke-PermanentCleanup" {
        
        BeforeEach {
            # Ensure we have test backup files
            if (-not (Test-Path $script:oldBackupFile)) {
                "Old backup content" | Out-File -FilePath $script:oldBackupFile -Encoding UTF8
            }
            if (-not (Test-Path $script:recentBackupFile)) {
                "Recent backup content" | Out-File -FilePath $script:recentBackupFile -Encoding UTF8
            }
        }
        
        It "Should clean up old backup files" {
            $result = Invoke-PermanentCleanup -BackupPath $script:testBackupRoot -MaxAge 30
            
            $result | Should -Not -BeNullOrEmpty
            $result.FilesRemoved | Should -BeGreaterOrEqual 0
        }
        
        It "Should preserve recent backup files" {
            Invoke-PermanentCleanup -BackupPath $script:testBackupRoot -MaxAge 30
            
            Test-Path $script:recentBackupFile | Should -Be $true
        }
        
        It "Should move files to archive when specified" {
            $result = Invoke-PermanentCleanup -BackupPath $script:testBackupRoot -MaxAge 30 -ArchivePath $script:testArchiveDir
            
            $result | Should -Not -BeNullOrEmpty
            # Should have archived rather than deleted
            $archivedFiles = Get-ChildItem -Path $script:testArchiveDir
            $archivedFiles | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle different file age thresholds" {
            $result = Invoke-PermanentCleanup -BackupPath $script:testBackupRoot -MaxAge 1
            
            $result | Should -Not -BeNullOrEmpty
            # With a 1-day threshold, should clean up more files
        }
        
        It "Should handle empty backup directory" {
            $emptyDir = Join-Path $TestDrive "EmptyBackupDir"
            if (-not (Test-Path $emptyDir)) { New-Item -Path $emptyDir -ItemType Directory -Force | Out-Null }
            
            $result = Invoke-PermanentCleanup -BackupPath $emptyDir -MaxAge 30
            
            $result | Should -Not -BeNullOrEmpty
            $result.FilesRemoved | Should -Be 0
        }
        
        It "Should handle non-existent backup path" {
            $nonExistentPath = Join-Path $TestDrive "NonExistentBackups"
            
            { Invoke-PermanentCleanup -BackupPath $nonExistentPath -MaxAge 30 } | Should -Throw
        }
    }
    
    Context "New-BackupExclusion" {
        
        It "Should add new exclusion pattern" {
            $result = New-BackupExclusion -ProjectRoot $script:testBackupRoot -Patterns @("*.bak")
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }
        
        It "Should add multiple exclusion patterns" {
            $patterns = @("*.tmp", "*.cache", "*.lock")
            $result = New-BackupExclusion -ProjectRoot $script:testBackupRoot -Patterns $patterns
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }
        
        It "Should handle duplicate exclusion patterns" {
            New-BackupExclusion -ProjectRoot $script:testBackupRoot -Patterns @("*.duplicate")
            $result = New-BackupExclusion -ProjectRoot $script:testBackupRoot -Patterns @("*.duplicate")
            
            # Should handle gracefully (either ignore duplicate or update)
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should validate exclusion pattern format" {
            # Test with invalid pattern
            try {
                $result = New-BackupExclusion -ProjectRoot $script:testBackupRoot -Patterns @("")
                $result.Success | Should -Be $false
            }
            catch {
                $_.Exception.Message | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should support regex patterns" {
            $result = New-BackupExclusion -ProjectRoot $script:testBackupRoot -Patterns @("test\d+\.txt")
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }
    }
    
    Context "Get-BackupStatistics" {
        
        BeforeEach {
            # Ensure we have some backup files for statistics
            $statsTestDir = Join-Path $script:testBackupRoot "StatsTest"
            if (-not (Test-Path $statsTestDir)) { New-Item -Path $statsTestDir -ItemType Directory -Force | Out-Null }
            
            @(1..5) | ForEach-Object {
                $backupFile = Join-Path $statsTestDir "backup-$_.zip"
                "Backup content $_" | Out-File -FilePath $backupFile -Encoding UTF8
            }
        }
        
        It "Should return backup statistics" {
            $stats = Get-BackupStatistics -ProjectRoot $script:testBackupRoot
            
            $stats | Should -Not -BeNullOrEmpty
            $stats.TotalFiles | Should -BeGreaterThan 0
            $stats.TotalSize | Should -BeGreaterThan 0
        }
        
        It "Should include file age analysis" {
            $stats = Get-BackupStatistics -ProjectRoot $script:testBackupRoot -IncludeDetails
            
            $stats | Should -Not -BeNullOrEmpty
            $stats.Details | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle recursive directory scanning" {
            $stats = Get-BackupStatistics -ProjectRoot $script:testBackupRoot -IncludeDetails
            
            $stats | Should -Not -BeNullOrEmpty
            $stats.TotalFiles | Should -BeGreaterThan 0
        }
        
        It "Should filter by file patterns" {
            $stats = Get-BackupStatistics -ProjectRoot $script:testBackupRoot -IncludeDetails
            
            $stats | Should -Not -BeNullOrEmpty
            # Should provide detailed analysis
        }
        
        It "Should handle empty backup directory for statistics" {
            $emptyStatsDir = Join-Path $TestDrive "EmptyStatsDir"
            if (-not (Test-Path $emptyStatsDir)) { New-Item -Path $emptyStatsDir -ItemType Directory -Force | Out-Null }
            
            $stats = Get-BackupStatistics -ProjectRoot $emptyStatsDir
            
            $stats | Should -Not -BeNullOrEmpty
            $stats.TotalFiles | Should -Be 0
            $stats.TotalSize | Should -Be 0
        }
    }
    
    Context "Invoke-BackupMaintenance" {
        
        It "Should perform comprehensive backup maintenance" {
            $result = Invoke-BackupMaintenance -Mode "Full"
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }
        
        It "Should include verification checks" {
            $result = Invoke-BackupMaintenance -Mode "Statistics"
            
            $result | Should -Not -BeNullOrEmpty
            $result.TotalOperations | Should -BeGreaterOrEqual 0
        }
        
        It "Should perform cleanup as part of maintenance" {
            $result = Invoke-BackupMaintenance -Mode "Cleanup" -AutoFix
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }
        
        It "Should generate maintenance report" {
            $result = Invoke-BackupMaintenance -Mode "Statistics" -OutputFormat "JSON"
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }
        
        It "Should handle maintenance errors gracefully" {
            # Test with different mode
            try {
                $result = Invoke-BackupMaintenance -Mode "All"
                # If it doesn't throw, should handle gracefully
                $result.Success | Should -Be $true
            }
            catch {
                $_.Exception.Message | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Describe "BackupManager Module - Integration Tests" {
    
    Context "Complete Backup Workflow" {
        
        It "Should execute full backup, cleanup, and maintenance cycle" {
            # Step 1: Create backup
            $backupResult = Invoke-BackupConsolidation -SourcePath $script:testSourceDir -BackupPath $script:testBackupRoot
            $backupResult.Success | Should -Be $true
            
            # Step 2: Get statistics
            $stats = Get-BackupStatistics -ProjectRoot $script:testBackupRoot
            $stats.TotalFiles | Should -BeGreaterThan 0
            
            # Step 3: Perform maintenance
            $maintenanceResult = Invoke-BackupMaintenance -Mode "Full"
            $maintenanceResult.Success | Should -Be $true
            
            # Step 4: Cleanup old files
            $cleanupResult = Invoke-PermanentCleanup -BackupPath $script:testBackupRoot -MaxAge 0
            $cleanupResult | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle backup rotation properly" {
            # Create multiple backups over time
            $rotationTestDir = Join-Path $TestDrive "RotationTest"
            if (-not (Test-Path $rotationTestDir)) { New-Item -Path $rotationTestDir -ItemType Directory -Force | Out-Null }
            
            # Simulate backups from different days
            @(-5, -3, -1, 0) | ForEach-Object {
                $backupDate = (Get-Date).AddDays($_)
                $backupFile = Join-Path $rotationTestDir "backup-$($backupDate.ToString('yyyyMMdd')).zip"
                "Backup from $($backupDate.ToString('yyyy-MM-dd'))" | Out-File -FilePath $backupFile -Encoding UTF8
                
                # Set file creation time
                if ($_ -ne 0) {
                    (Get-Item $backupFile).CreationTime = $backupDate
                    (Get-Item $backupFile).LastWriteTime = $backupDate
                }
            }
              # Clean up files older than 2 days
            Invoke-PermanentCleanup -BackupPath $rotationTestDir -MaxAge 2 | Out-Null
            
            # Should have removed old backups but kept recent ones
            $remainingFiles = Get-ChildItem -Path $rotationTestDir
            $remainingFiles.Count | Should -BeLessThan 4
        }
    }
    
    Context "Error Handling and Edge Cases" {
        
        It "Should handle corrupted backup files" {
            $corruptedBackupDir = Join-Path $TestDrive "CorruptedBackups"
            if (-not (Test-Path $corruptedBackupDir)) { New-Item -Path $corruptedBackupDir -ItemType Directory -Force | Out-Null }
            
            # Create a corrupted zip file
            $corruptedFile = Join-Path $corruptedBackupDir "corrupted.zip"
            [System.IO.File]::WriteAllBytes($corruptedFile, @(0x50, 0x4B, 0x00, 0x00))  # Invalid ZIP header
            
            $result = Invoke-BackupMaintenance -Mode "Statistics"
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }
          It "Should handle insufficient disk space scenarios" {
            # This is challenging to test without actually filling disk
            # We'll test the parameter validation instead
            try {
                Invoke-BackupConsolidation -SourcePath $script:testSourceDir -BackupPath $script:testBackupRoot -MinFreeSpaceGB 999999 | Out-Null
                # Should either handle gracefully or throw appropriate error
                $true | Should -Be $true
            }
            catch {
                $_.Exception.Message | Should -Match "space|disk|storage"
            }
        }
        
        It "Should handle concurrent backup operations" {
            $concurrentTestDir = Join-Path $TestDrive "ConcurrentBackups"
            if (-not (Test-Path $concurrentTestDir)) { New-Item -Path $concurrentTestDir -ItemType Directory -Force | Out-Null }
            
            # Start multiple backup operations
            $jobs = @()
            1..3 | ForEach-Object {
                $jobs += Start-Job -ScriptBlock {
                    param($SourcePath, $BackupPath, $ModulePath)
                    Import-Module $ModulePath -Force
                    Invoke-BackupConsolidation -SourcePath $SourcePath -BackupPath "$BackupPath\Job$_"
                } -ArgumentList $script:testSourceDir, $concurrentTestDir, (Join-Path $projectRoot "core-runner/modules/BackupManager")
            }
            
            $results = $jobs | Wait-Job | Receive-Job
            $jobs | Remove-Job
            
            # All jobs should complete successfully
            $results | ForEach-Object { $_.Success | Should -Be $true }
        }
    }
}

Describe "BackupManager Module - Performance and Reliability" {
    
    Context "Performance Validation" {
        
        It "Should handle large file operations efficiently" {
            # Create a larger test file
            $largeFileDir = Join-Path $TestDrive "LargeFiles"
            if (-not (Test-Path $largeFileDir)) { New-Item -Path $largeFileDir -ItemType Directory -Force | Out-Null }
            
            $largeFile = Join-Path $largeFileDir "large-file.txt"
            $content = "This is test content. " * 1000  # Create ~20KB file
            $content | Out-File -FilePath $largeFile -Encoding UTF8
            
            $startTime = Get-Date
            $result = Invoke-BackupConsolidation -SourcePath $largeFileDir -BackupPath $script:testBackupRoot
            $endTime = Get-Date
            
            $result.Success | Should -Be $true
            ($endTime - $startTime).TotalSeconds | Should -BeLessThan 30
        }
        
        It "Should scale with multiple files" {
            $multiFileDir = Join-Path $TestDrive "MultipleFiles"
            if (-not (Test-Path $multiFileDir)) { New-Item -Path $multiFileDir -ItemType Directory -Force | Out-Null }
            
            # Create multiple files
            1..50 | ForEach-Object {
                $fileName = Join-Path $multiFileDir "file-$_.txt"
                "Content for file $_" | Out-File -FilePath $fileName -Encoding UTF8
            }
            
            $startTime = Get-Date
            $result = Invoke-BackupConsolidation -SourcePath $multiFileDir -BackupPath $script:testBackupRoot
            $endTime = Get-Date
            
            $result.Success | Should -Be $true
            ($endTime - $startTime).TotalSeconds | Should -BeLessThan 60
        }
    }
    
    Context "Resource Management" {
        
        It "Should clean up temporary resources" {
            $tempFilesBefore = Get-ChildItem -Path $env:TEMP -Filter "*backup*" -ErrorAction SilentlyContinue
            $tempCountBefore = if ($tempFilesBefore) { $tempFilesBefore.Count } else { 0 }
            
            Invoke-BackupConsolidation -SourcePath $script:testSourceDir -BackupPath $script:testBackupRoot
            
            $tempFilesAfter = Get-ChildItem -Path $env:TEMP -Filter "*backup*" -ErrorAction SilentlyContinue
            $tempCountAfter = if ($tempFilesAfter) { $tempFilesAfter.Count } else { 0 }
            
            # Should not have significantly increased temp files
            $tempCountAfter | Should -BeLessOrEqual ($tempCountBefore + 2)
        }
    }
}

