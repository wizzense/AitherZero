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
        return "git command mocked"
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