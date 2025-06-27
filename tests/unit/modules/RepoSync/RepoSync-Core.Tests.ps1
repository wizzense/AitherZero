BeforeAll {
    # Import shared Find-ProjectRoot utility
    . "$PSScriptRoot/../../../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot

    # Import Logging module first
    $loggingPath = Join-Path $projectRoot "aither-core/modules/Logging"
    try {
        Import-Module $loggingPath -Force -Global -ErrorAction Stop
        Write-Host "Logging module imported successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to import Logging module: $_"
        throw
    }

    # Import RepoSync module
    $repoSyncPath = Join-Path $projectRoot "aither-core/modules/RepoSync"
    try {
        Import-Module $repoSyncPath -Force -ErrorAction Stop
        Write-Host "RepoSync module imported successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to import RepoSync module: $_"
        throw
    }

    # Mock git commands for testing
    function global:git {
        param()
        $global:LASTEXITCODE = 0
        
        # Handle different git commands
        if ($args -contains 'status' -and $args -contains '--porcelain') {
            # Return empty string to indicate clean working directory
            return ""
        }
        elseif ($args -contains 'remote' -and $args -contains '-v') {
            # Return mocked remote info
            return @(
                "origin  https://github.com/user/AitherZero.git (fetch)",
                "origin  https://github.com/user/AitherZero.git (push)",
                "aitherlab  https://github.com/user/aitherlab.git (fetch)",
                "aitherlab  https://github.com/user/aitherlab.git (push)"
            )
        }
        elseif ($args -contains 'rev-list' -and $args -contains '--count') {
            # Return a number for commit counts
            return "0"
        }
        elseif ($args -contains 'diff' -and $args -contains '--name-only') {
            # Return empty for no differences
            return ""
        }
        elseif ($args -contains 'fetch') {
            # Mock fetch operation
            return ""
        }
        elseif ($args -contains 'checkout' -and $args -contains '-b') {
            # Mock branch creation
            return "Switched to a new branch 'mock-branch'"
        }
        elseif ($args -contains 'checkout' -and $args -contains '-') {
            # Mock return to previous branch
            return "Switched to branch 'main'"
        }
        elseif ($args -contains 'checkout' -and $args -contains 'HEAD') {
            # Mock file checkout
            return ""
        }
        elseif ($args -contains 'push') {
            # Mock push operation
            return "Everything up-to-date"
        }
        elseif ($args -contains 'merge') {
            # Mock merge operation
            return "Already up to date."
        }
        elseif ($args -contains 'commit') {
            # Mock commit operation
            return "[mock-branch 1234567] Mock commit"
        }
        elseif ($args -contains 'rm') {
            # Mock rm operation
            return ""
        }
        elseif ($args -contains 'branch' -and $args -contains '-D') {
            # Mock branch deletion
            return "Deleted branch mock-branch"
        }
        else {
            # Default return
            return "git command mocked"
        }
    }

    # Mock external commands
    function global:gh {
        param()
        return "gh command mocked"
    }
}

Describe "RepoSync Module Tests" {
    Context "Module Loading" {
        It "Should import without errors" {
            Get-Module "RepoSync" | Should -Not -BeNullOrEmpty
        }

        It "Should have exported functions available" {
            $expectedFunctions = @(
                'Sync-ToAitherLab',
                'Sync-FromAitherLab',
                'Get-SyncStatus'
            )

            foreach ($func in $expectedFunctions) {
                Get-Command $func -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because "$func should be available"
            }
        }
    }

    Context "Sync-ToAitherLab" {
        It "Should require CommitMessage parameter" {
            { Sync-ToAitherLab } | Should -Throw
        }

        It "Should accept basic parameters" {
            { Sync-ToAitherLab -CommitMessage "Test sync" -WhatIf } | Should -Not -Throw
        }

        It "Should accept CreatePR parameter" {
            { Sync-ToAitherLab -CommitMessage "Test sync" -CreatePR -WhatIf } | Should -Not -Throw
        }

        It "Should accept FilesToSync parameter" {
            { Sync-ToAitherLab -CommitMessage "Test sync" -FilesToSync @("file1.ps1", "file2.ps1") -WhatIf } | Should -Not -Throw
        }
    }

    Context "Sync-FromAitherLab" {
        It "Should execute without throwing" {
            { Sync-FromAitherLab -WhatIf } | Should -Not -Throw
        }
    }

    Context "Get-SyncStatus" {
        It "Should execute without throwing" {
            { Get-SyncStatus } | Should -Not -Throw
        }

        It "Should return status information" {
            $result = Get-SyncStatus
            $result | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "RepoSync Error Handling" {
    Context "Invalid Parameters" {
        It "Should handle empty commit message gracefully" {
            { Sync-ToAitherLab -CommitMessage "" -WhatIf } | Should -Throw
        }
    }

    Context "Environment Requirements" {
        It "Should handle missing git gracefully" {
            # This test verifies the module loads even if git isn't available
            $originalPath = $env:PATH
            try {
                $env:PATH = ""
                { Get-Command -Module RepoSync } | Should -Not -Throw
            }
            finally {
                $env:PATH = $originalPath
            }
        }
    }
}