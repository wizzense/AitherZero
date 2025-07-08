#Requires -Version 7.0

Describe "ISOManager Module Tests" {
    BeforeAll {
        # Import required modules
        $projectRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
        Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
        Import-Module (Join-Path $projectRoot "aither-core/modules/ISOManager") -Force

        # Create test directory
        $script:TestRepository = Join-Path $env:TEMP "AitherZero-ISO-Tests-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        New-Item -ItemType Directory -Path $script:TestRepository -Force | Out-Null

        # Create test ISO file (small for testing)
        $script:TestISOPath = Join-Path $script:TestRepository "test.iso"
        $testContent = "ISO Test Content " * 1000  # Small test file
        Set-Content -Path $script:TestISOPath -Value $testContent
    }

    AfterAll {
        # Clean up test repository
        if (Test-Path $script:TestRepository) {
            Remove-Item -Path $script:TestRepository -Recurse -Force
        }
    }

    Context "Module Loading" {
        It "Should load the ISOManager module successfully" {
            Get-Module ISOManager | Should -Not -BeNullOrEmpty
        }

        It "Should export all expected functions" {
            $module = Get-Module ISOManager
            $expectedFunctions = @(
                'Get-ISODownload',
                'Get-ISOInventory',
                'Get-ISOMetadata',
                'Test-ISOIntegrity',
                'New-ISORepository',
                'Remove-ISOFile',
                'Export-ISOInventory',
                'Import-ISOInventory',
                'Sync-ISORepository',
                'Optimize-ISOStorage'
            )

            foreach ($function in $expectedFunctions) {
                $module.ExportedFunctions.Keys | Should -Contain $function
            }
        }
    }

    Context "New-ISORepository" {
        It "Should create a new ISO repository with proper structure" {
            $repoPath = Join-Path $script:TestRepository "TestRepo"
            $result = New-ISORepository -RepositoryPath $repoPath -Name "TestRepository"

            $result.Success | Should -Be $true
            Test-Path $repoPath | Should -Be $true
            Test-Path (Join-Path $repoPath "Windows") | Should -Be $true
            Test-Path (Join-Path $repoPath "Linux") | Should -Be $true
            Test-Path (Join-Path $repoPath "Custom") | Should -Be $true
            Test-Path (Join-Path $repoPath "Metadata") | Should -Be $true
            Test-Path (Join-Path $repoPath "repository.config.json") | Should -Be $true
        }

        It "Should not overwrite existing repository without Force" {
            $repoPath = Join-Path $script:TestRepository "ExistingRepo"
            New-ISORepository -RepositoryPath $repoPath -Name "First" | Out-Null

            $result = New-ISORepository -RepositoryPath $repoPath -Name "Second"
            $config = Get-Content (Join-Path $repoPath "repository.config.json") | ConvertFrom-Json
            $config.Name | Should -Be "First"
        }
    }

    Context "Get-ISOMetadata" {
        It "Should extract metadata from test ISO file" {
            $metadata = Get-ISOMetadata -FilePath $script:TestISOPath

            $metadata | Should -Not -BeNullOrEmpty
            $metadata.FilePath | Should -Be $script:TestISOPath
            $metadata.FileName | Should -Be "test.iso"
            $metadata.Checksum | Should -Not -BeNullOrEmpty
            $metadata.FileSize | Should -BeGreaterThan 0
        }

        It "Should handle non-existent files gracefully" {
            $nonExistentPath = Join-Path $script:TestRepository "nonexistent.iso"
            { Get-ISOMetadata -FilePath $nonExistentPath } | Should -Throw
        }
    }

    Context "Test-ISOIntegrity" {
        It "Should validate test ISO file integrity" {
            $result = Test-ISOIntegrity -FilePath $script:TestISOPath

            $result | Should -Not -BeNullOrEmpty
            $result.FilePath | Should -Be $script:TestISOPath
            $result.FileExists | Should -Be $true
            $result.Checksum | Should -Not -BeNullOrEmpty
            $result.Algorithm | Should -Be "SHA256"
        }

        It "Should validate with expected checksum" {
            $hash = (Get-FileHash -Path $script:TestISOPath -Algorithm SHA256).Hash
            $result = Test-ISOIntegrity -FilePath $script:TestISOPath -ExpectedChecksum $hash

            $result.Valid | Should -Be $true
        }

        It "Should fail with incorrect expected checksum" {
            $incorrectHash = "ABC123"
            $result = Test-ISOIntegrity -FilePath $script:TestISOPath -ExpectedChecksum $incorrectHash

            $result.Valid | Should -Be $false
            $result.Errors | Should -Contain "Checksum mismatch. Expected: $incorrectHash, Actual: $($result.Checksum)"
        }
    }

    Context "Get-ISOInventory" {
        BeforeAll {
            # Create test repository with ISOs
            $script:InventoryTestRepo = Join-Path $script:TestRepository "InventoryTest"
            New-ISORepository -RepositoryPath $script:InventoryTestRepo | Out-Null

            # Create test ISO files
            $windowsISO = Join-Path $script:InventoryTestRepo "Windows" "windows11.iso"
            $linuxISO = Join-Path $script:InventoryTestRepo "Linux" "ubuntu.iso"

            Set-Content -Path $windowsISO -Value "Windows ISO Content"
            Set-Content -Path $linuxISO -Value "Linux ISO Content"
        }

        It "Should return inventory of all ISO files" {
            $inventory = Get-ISOInventory -RepositoryPath $script:InventoryTestRepo

            $inventory | Should -Not -BeNullOrEmpty
            $inventory.Count | Should -Be 2
            $inventory | Where-Object { $_.Type -eq 'Windows' } | Should -Not -BeNullOrEmpty
            $inventory | Where-Object { $_.Type -eq 'Linux' } | Should -Not -BeNullOrEmpty
        }

        It "Should filter inventory by ISO type" {
            $windowsOnly = Get-ISOInventory -RepositoryPath $script:InventoryTestRepo -ISOType 'Windows'

            $windowsOnly.Count | Should -Be 1
            $windowsOnly[0].Type | Should -Be 'Windows'
        }

        It "Should include metadata when requested" {
            $inventory = Get-ISOInventory -RepositoryPath $script:InventoryTestRepo -IncludeMetadata

            $inventory[0].Metadata | Should -Not -BeNullOrEmpty
        }
    }

    Context "Export-ISOInventory and Import-ISOInventory" {
        BeforeAll {
            $script:ExportTestRepo = Join-Path $script:TestRepository "ExportTest"
            New-ISORepository -RepositoryPath $script:ExportTestRepo | Out-Null

            # Create test ISO
            $testISO = Join-Path $script:ExportTestRepo "Windows" "test-export.iso"
            Set-Content -Path $testISO -Value "Export Test Content"
        }

        It "Should export inventory to JSON format" {
            $exportPath = Join-Path $script:TestRepository "inventory-export.json"
            $result = Export-ISOInventory -RepositoryPath $script:ExportTestRepo -ExportPath $exportPath -Format JSON

            $result.Success | Should -Be $true
            Test-Path $exportPath | Should -Be $true

            $exportedData = Get-Content $exportPath | ConvertFrom-Json
            $exportedData.Inventory | Should -Not -BeNullOrEmpty
        }

        It "Should export inventory to CSV format" {
            $exportPath = Join-Path $script:TestRepository "inventory-export.csv"
            $result = Export-ISOInventory -RepositoryPath $script:ExportTestRepo -ExportPath $exportPath -Format CSV

            $result.Success | Should -Be $true
            Test-Path $exportPath | Should -Be $true

            $csvData = Import-Csv $exportPath
            $csvData | Should -Not -BeNullOrEmpty
        }

        It "Should import inventory from JSON file" {
            $exportPath = Join-Path $script:TestRepository "inventory-export.json"
            $result = Import-ISOInventory -ImportPath $exportPath

            $result.TotalEntries | Should -BeGreaterThan 0
        }
    }

    Context "Remove-ISOFile" {
        BeforeAll {
            $script:RemoveTestISO = Join-Path $script:TestRepository "remove-test.iso"
            Set-Content -Path $script:RemoveTestISO -Value "Content to be removed"
        }

        It "Should remove ISO file successfully" {
            $result = Remove-ISOFile -FilePath $script:RemoveTestISO -Force

            $result.FilesRemoved | Should -Be 1
            Test-Path $script:RemoveTestISO | Should -Be $false
        }

        It "Should create backup before removal when requested" {
            $backupTestISO = Join-Path $script:TestRepository "backup-test.iso"
            Set-Content -Path $backupTestISO -Value "Content for backup test"

            $backupDir = Join-Path $script:TestRepository "Backup"
            $result = Remove-ISOFile -FilePath $backupTestISO -BackupBeforeRemove -BackupPath $backupDir -Force

            $result.BackupsCreated | Should -Be 1
            Test-Path $backupTestISO | Should -Be $false
            (Get-ChildItem $backupDir -Filter "*backup-test*").Count | Should -Be 1
        }
    }

    Context "Sync-ISORepository" {
        BeforeAll {
            $script:SyncTestRepo = Join-Path $script:TestRepository "SyncTest"
            New-ISORepository -RepositoryPath $script:SyncTestRepo | Out-Null

            # Create test ISO
            $testISO = Join-Path $script:SyncTestRepo "Windows" "sync-test.iso"
            Set-Content -Path $testISO -Value "Sync test content"
        }

        It "Should synchronize repository successfully" {
            $result = Sync-ISORepository -RepositoryPath $script:SyncTestRepo -UpdateMetadata

            $result.TotalISOs | Should -Be 1
            $result.UpdatedMetadata | Should -Be 1
        }

        It "Should update repository statistics" {
            Sync-ISORepository -RepositoryPath $script:SyncTestRepo | Out-Null

            $configPath = Join-Path $script:SyncTestRepo "repository.config.json"
            $config = Get-Content $configPath | ConvertFrom-Json
            $config.Statistics.TotalISOs | Should -Be 1
            $config.LastSynced | Should -Not -BeNullOrEmpty
        }
    }

    Context "Optimize-ISOStorage" {
        BeforeAll {
            $script:OptimizeTestRepo = Join-Path $script:TestRepository "OptimizeTest"
            New-ISORepository -RepositoryPath $script:OptimizeTestRepo | Out-Null

            # Create test ISOs with same content (duplicates)
            $iso1 = Join-Path $script:OptimizeTestRepo "Windows" "duplicate1.iso"
            $iso2 = Join-Path $script:OptimizeTestRepo "Windows" "duplicate2.iso"
            $content = "Duplicate content for testing"

            Set-Content -Path $iso1 -Value $content
            Set-Content -Path $iso2 -Value $content

            # Make one file older
            (Get-Item $iso2).LastWriteTime = (Get-Date).AddDays(-35)
        }

        It "Should perform dry run optimization" {
            $result = Optimize-ISOStorage -RepositoryPath $script:OptimizeTestRepo -RemoveDuplicates -DryRun

            $result.DryRun | Should -Be $true
            $result.FilesProcessed | Should -Be 2
        }

        It "Should remove duplicates when requested" {
            $result = Optimize-ISOStorage -RepositoryPath $script:OptimizeTestRepo -RemoveDuplicates -Force

            $result.DuplicatesRemoved | Should -BeGreaterThan 0
        }
    }

    Context "Error Handling" {
        It "Should handle invalid repository paths gracefully" {
            $invalidPath = "Z:\NonExistent\Path"
            { Get-ISOInventory -RepositoryPath $invalidPath } | Should -Not -Throw

            $result = Get-ISOInventory -RepositoryPath $invalidPath
            $result | Should -Be @()
        }

        It "Should handle corrupted repository configuration" {
            $corruptRepo = Join-Path $script:TestRepository "CorruptRepo"
            New-Item -ItemType Directory -Path $corruptRepo -Force | Out-Null

            # Create invalid config file
            $configPath = Join-Path $corruptRepo "repository.config.json"
            Set-Content -Path $configPath -Value "{ invalid json"

            { Sync-ISORepository -RepositoryPath $corruptRepo } | Should -Throw
        }
    }

    Context "Cross-Platform Compatibility" {
        It "Should work with cross-platform paths" {
            $crossPlatformPath = Join-Path $script:TestRepository "cross-platform.iso"
            Set-Content -Path $crossPlatformPath -Value "Cross-platform test"

            $metadata = Get-ISOMetadata -FilePath $crossPlatformPath
            $metadata.FilePath | Should -Be $crossPlatformPath
        }

        It "Should handle different file systems correctly" {
            # Test basic functionality that should work across file systems
            $result = Test-ISOIntegrity -FilePath $script:TestISOPath
            $result.FileExists | Should -Be $true
        }
    }

    Context "Performance Tests" {
        It "Should handle large inventories efficiently" {
            # This test would normally create many files, but we'll simulate with existing files
            $startTime = Get-Date
            $inventory = Get-ISOInventory -RepositoryPath $script:TestRepository
            $endTime = Get-Date

            $duration = ($endTime - $startTime).TotalSeconds
            $duration | Should -BeLessThan 10  # Should complete within 10 seconds
        }

        It "Should process metadata extraction within reasonable time" {
            $startTime = Get-Date
            $metadata = Get-ISOMetadata -FilePath $script:TestISOPath
            $endTime = Get-Date

            $duration = ($endTime - $startTime).TotalSeconds
            $duration | Should -BeLessThan 5  # Should complete within 5 seconds
        }
    }
}
