#Requires -Version 7.0

<#
.SYNOPSIS
    Unit tests for ProjectIndexer module
.DESCRIPTION
    Tests for the automated project indexing and navigation generation system
#>

BeforeAll {
    # Import the module
    $projectRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
    $modulePath = Join-Path $projectRoot "domains/documentation/ProjectIndexer.psm1"
    
    Import-Module $modulePath -Force
    
    # Create test directory structure
    $script:TestRoot = Join-Path $TestDrive "test-project"
    New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
}

Describe "ProjectIndexer Initialization" {
    It "Initializes with default configuration" {
        { Initialize-ProjectIndexer -RootPath $script:TestRoot } | Should -Not -Throw
    }
    
    It "Returns configuration after initialization" {
        Initialize-ProjectIndexer -RootPath $script:TestRoot
        $config = Get-IndexerConfig
        $config | Should -Not -BeNullOrEmpty
        $config.RootPath | Should -Be $script:TestRoot
    }
    
    It "Accepts custom exclude paths" {
        $excludePaths = @('custom1', 'custom2')
        Initialize-ProjectIndexer -RootPath $script:TestRoot -ExcludePaths $excludePaths
        $config = Get-IndexerConfig
        $config.ExcludePaths | Should -Contain 'custom1'
        $config.ExcludePaths | Should -Contain 'custom2'
    }
}

Describe "Directory Content Analysis" {
    BeforeEach {
        # Create test structure
        $testDir = Join-Path $script:TestRoot "test-dir"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        
        # Create some test files
        Set-Content -Path (Join-Path $testDir "test.ps1") -Value "<#`n.SYNOPSIS`n  Test script`n#>`nWrite-Host 'test'"
        Set-Content -Path (Join-Path $testDir "README.md") -Value "# Test Directory"
        Set-Content -Path (Join-Path $testDir "data.json") -Value "{}"
        
        # Create subdirectories
        New-Item -ItemType Directory -Path (Join-Path $testDir "subdir1") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $testDir "subdir2") -Force | Out-Null
        
        Initialize-ProjectIndexer -RootPath $script:TestRoot
    }
    
    It "Analyzes directory content correctly" {
        $content = Get-DirectoryContent -Path $testDir
        $content | Should -Not -BeNullOrEmpty
        $content.Directories.Count | Should -Be 2
        $content.Files.Count | Should -Be 3
        $content.Scripts.Count | Should -Be 1
    }
    
    It "Detects existing README" {
        $content = Get-DirectoryContent -Path $testDir
        $content.HasReadme | Should -Be $true
    }
    
    It "Detects missing index" {
        $content = Get-DirectoryContent -Path $testDir
        $content.HasIndex | Should -Be $false
    }
}

Describe "Content Hashing and Change Detection" {
    BeforeEach {
        $testDir = Join-Path $script:TestRoot "hash-test"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        Set-Content -Path (Join-Path $testDir "file1.txt") -Value "content1"
        
        Initialize-ProjectIndexer -RootPath $script:TestRoot
    }
    
    It "Calculates content hash" {
        $hash = Get-ContentHash -Path $testDir
        $hash | Should -Not -BeNullOrEmpty
        $hash.Length | Should -Be 64  # SHA256 hash length
    }
    
    It "Detects changes when content changes" {
        # First hash
        $hash1 = Get-ContentHash -Path $testDir
        
        # Modify content
        Set-Content -Path (Join-Path $testDir "file2.txt") -Value "new content"
        
        # Second hash should be different
        $hash2 = Get-ContentHash -Path $testDir
        $hash2 | Should -Not -Be $hash1
    }
    
    It "Reports content changed for new directory" {
        $changed = Test-ContentChanged -Path $testDir
        $changed | Should -Be $true
    }
}

Describe "Navigation Path Generation" {
    BeforeEach {
        # Create nested structure
        $level1 = Join-Path $script:TestRoot "level1"
        $level2 = Join-Path $level1 "level2"
        $level3 = Join-Path $level2 "level3"
        
        New-Item -ItemType Directory -Path $level3 -Force | Out-Null
        
        Initialize-ProjectIndexer -RootPath $script:TestRoot
    }
    
    It "Identifies root directory" {
        $nav = Get-NavigationPath -Path $script:TestRoot
        $nav.IsRoot | Should -Be $true
        $nav.Parts.Count | Should -Be 0
    }
    
    It "Generates breadcrumb for nested directory" {
        $level3 = Join-Path (Join-Path $script:TestRoot "level1") "level2/level3"
        $nav = Get-NavigationPath -Path $level3
        $nav.IsRoot | Should -Be $false
        $nav.Parts.Count | Should -Be 3
        $nav.Parts[0].Name | Should -Be "level1"
        $nav.Parts[1].Name | Should -Be "level2"
        $nav.Parts[2].Name | Should -Be "level3"
    }
    
    It "Identifies parent directory correctly" {
        $level2 = Join-Path (Join-Path $script:TestRoot "level1") "level2"
        $nav = Get-NavigationPath -Path $level2
        $nav.Parent | Should -Not -BeNullOrEmpty
        $nav.Parent.Name | Should -Be "level1"
    }
}

Describe "Index Generation" {
    BeforeEach {
        $testDir = Join-Path $script:TestRoot "index-test"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        
        # Create test files
        Set-Content -Path (Join-Path $testDir "script.ps1") -Value "<#`n.SYNOPSIS`n  Test script for indexing`n#>`nWrite-Host 'test'"
        Set-Content -Path (Join-Path $testDir "README.md") -Value "# Test Directory`nThis is a test."
        
        # Create subdirectories
        New-Item -ItemType Directory -Path (Join-Path $testDir "subdir1") -Force | Out-Null
        
        Initialize-ProjectIndexer -RootPath $script:TestRoot
    }
    
    It "Generates index.md file" {
        $result = New-DirectoryIndex -Path $testDir
        $result.Success | Should -Be $true
        $result.Updated | Should -Be $true
        
        $indexPath = Join-Path $testDir "index.md"
        Test-Path $indexPath | Should -Be $true
    }
    
    It "Index contains navigation header" {
        New-DirectoryIndex -Path $testDir | Out-Null
        $indexPath = Join-Path $testDir "index.md"
        $content = Get-Content $indexPath -Raw
        $content | Should -Match "index-test"
    }
    
    It "Index contains subdirectory links" {
        New-DirectoryIndex -Path $testDir | Out-Null
        $indexPath = Join-Path $testDir "index.md"
        $content = Get-Content $indexPath -Raw
        $content | Should -Match "subdir1"
    }
    
    It "Index contains file listings" {
        New-DirectoryIndex -Path $testDir | Out-Null
        $indexPath = Join-Path $testDir "index.md"
        $content = Get-Content $indexPath -Raw
        $content | Should -Match "script.ps1"
        $content | Should -Match "README.md"
    }
    
    It "Index includes script synopsis" {
        New-DirectoryIndex -Path $testDir | Out-Null
        $indexPath = Join-Path $testDir "index.md"
        $content = Get-Content $indexPath -Raw
        $content | Should -Match "Test script for indexing"
    }
    
    It "Skips regeneration when content unchanged" {
        # First generation
        $result1 = New-DirectoryIndex -Path $testDir
        $result1.Updated | Should -Be $true
        
        # Second generation without changes
        $result2 = New-DirectoryIndex -Path $testDir
        $result2.Updated | Should -Be $false
        $result2.Reason | Should -Be 'NoChanges'
    }
    
    It "Regenerates when content changes" {
        # First generation
        New-DirectoryIndex -Path $testDir | Out-Null
        
        # Add new file
        Set-Content -Path (Join-Path $testDir "newfile.txt") -Value "new content"
        
        # Second generation should update
        $result = New-DirectoryIndex -Path $testDir
        $result.Updated | Should -Be $true
    }
}

Describe "Project-wide Index Generation" {
    BeforeEach {
        # Create multi-level structure
        $dir1 = Join-Path $script:TestRoot "dir1"
        $dir2 = Join-Path $script:TestRoot "dir2"
        $subdir = Join-Path $dir1 "subdir"
        
        New-Item -ItemType Directory -Path $dir1 -Force | Out-Null
        New-Item -ItemType Directory -Path $dir2 -Force | Out-Null
        New-Item -ItemType Directory -Path $subdir -Force | Out-Null
        
        Set-Content -Path (Join-Path $dir1 "file1.txt") -Value "content"
        Set-Content -Path (Join-Path $subdir "file2.txt") -Value "content"
        
        Initialize-ProjectIndexer -RootPath $script:TestRoot
    }
    
    It "Generates indexes recursively" {
        $results = New-ProjectIndexes -RootPath $script:TestRoot -Recursive
        $results.TotalDirectories | Should -BeGreaterThan 1
        $results.UpdatedIndexes | Should -BeGreaterThan 1
        $results.FailedIndexes | Should -Be 0
    }
    
    It "Creates index files in all directories" {
        New-ProjectIndexes -RootPath $script:TestRoot -Recursive | Out-Null
        
        Test-Path (Join-Path $script:TestRoot "index.md") | Should -Be $true
        Test-Path (Join-Path $script:TestRoot "dir1/index.md") | Should -Be $true
        Test-Path (Join-Path $script:TestRoot "dir2/index.md") | Should -Be $true
        Test-Path (Join-Path $script:TestRoot "dir1/subdir/index.md") | Should -Be $true
    }
    
    It "Saves hash cache after generation" {
        New-ProjectIndexes -RootPath $script:TestRoot -Recursive | Out-Null
        
        $cacheFile = Join-Path $script:TestRoot ".aitherzero-index-cache.json"
        Test-Path $cacheFile | Should -Be $true
    }
    
    It "Loads hash cache on initialization" {
        # First run creates cache
        New-ProjectIndexes -RootPath $script:TestRoot -Recursive | Out-Null
        
        # Re-initialize and check cache loaded
        Initialize-ProjectIndexer -RootPath $script:TestRoot
        $config = Get-IndexerConfig
        $cacheFile = $config.HashCacheFile
        Test-Path $cacheFile | Should -Be $true
    }
}

Describe "Content Comparison and Timestamp Handling" {
    BeforeEach {
        Initialize-ProjectIndexer -RootPath $script:TestRoot
    }
    
    It "Compare-IndexContent detects identical content ignoring timestamps" {
        $content1 = @"
# Test Directory
## Overview
Some content here
---
*Generated by AitherZero Project Indexer* • Last updated: 2025-10-29 12:00:00 UTC
"@
        
        $content2 = @"
# Test Directory
## Overview
Some content here
---
*Generated by AitherZero Project Indexer* • Last updated: 2025-10-30 14:30:00 UTC
"@
        
        $changed = Compare-IndexContent -ExistingContent $content1 -NewContent $content2
        $changed | Should -Be $false
    }
    
    It "Compare-IndexContent detects real content changes" {
        $content1 = @"
# Test Directory
## Overview
Original content
---
*Generated by AitherZero Project Indexer* • Last updated: 2025-10-29 12:00:00 UTC
"@
        
        $content2 = @"
# Test Directory
## Overview
Modified content
---
*Generated by AitherZero Project Indexer* • Last updated: 2025-10-30 14:30:00 UTC
"@
        
        $changed = Compare-IndexContent -ExistingContent $content1 -NewContent $content2
        $changed | Should -Be $true
    }
    
    It "Skips index write when only timestamp differs" {
        $testDir = Join-Path $script:TestRoot "timestamp-test"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        Set-Content -Path (Join-Path $testDir "test.txt") -Value "content"
        
        # First generation
        $result1 = New-DirectoryIndex -Path $testDir
        $result1.Updated | Should -Be $true
        
        # Get the index file timestamp
        $indexPath = Join-Path $testDir "index.md"
        $timestamp1 = (Get-Item $indexPath).LastWriteTime
        
        # Wait a bit to ensure timestamp would differ
        Start-Sleep -Milliseconds 100
        
        # Second generation without content changes and without Force
        $result2 = New-DirectoryIndex -Path $testDir
        
        # File should not be updated because content hasn't changed
        $timestamp2 = (Get-Item $indexPath).LastWriteTime
        
        # Without Force, directory content hasn't changed, so it should be skipped
        $result2.Updated | Should -Be $false
        $result2.Reason | Should -BeIn @('NoChanges', 'ContentUnchanged')
    }
}

Describe "Edge Cases and Error Handling" {
    BeforeEach {
        Initialize-ProjectIndexer -RootPath $script:TestRoot
    }
    
    It "Handles empty directory" {
        $emptyDir = Join-Path $script:TestRoot "empty"
        New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
        
        $result = New-DirectoryIndex -Path $emptyDir
        $result.Success | Should -Be $true
    }
    
    It "Handles non-existent directory gracefully" {
        $fakePath = Join-Path $script:TestRoot "nonexistent"
        $content = Get-DirectoryContent -Path $fakePath
        $content | Should -BeNullOrEmpty
    }
    
    It "Excludes configured paths" {
        # Create .git directory
        $gitDir = Join-Path $script:TestRoot ".git"
        New-Item -ItemType Directory -Path $gitDir -Force | Out-Null
        
        $results = New-ProjectIndexes -RootPath $script:TestRoot -Recursive
        
        # Should not have created index in .git
        Test-Path (Join-Path $gitDir "index.md") | Should -Be $false
    }
}

AfterAll {
    # Cleanup is handled by TestDrive automatically
}
