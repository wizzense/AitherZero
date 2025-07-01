BeforeAll {
    # Set environment variable to indicate test execution
    $env:PESTER_RUN = 'true'

    # Import shared Find-ProjectRoot utility
    . "$PSScriptRoot/../../../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot

    # Import Logging module first
    $loggingPath = Join-Path $env:PWSH_MODULES_PATH "Logging"

    try {
        Import-Module $loggingPath -Force -Global -ErrorAction Stop
        Write-Host "Logging module imported successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to import Logging module: $_"
        throw
    }

    # Import PatchManager module
    $patchManagerPath = Join-Path $env:PWSH_MODULES_PATH "PatchManager"

    try {
        Import-Module $patchManagerPath -Force -ErrorAction Stop
        Write-Host "PatchManager module imported successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to import PatchManager module: $_"
        throw
    }

    # Mock git commands for testing
    function global:git {
        param()
        $gitArgs = $args
        $script:gitCalls += , $gitArgs

        switch ($gitArgs[0]) {
            "status" {
                if ($gitArgs[1] -eq "--porcelain") {
                    return ""  # Clean working tree
                }
                return "On branch main`nnothing to commit, working tree clean"
            }
            "config" {
                return "test-value"
            }
            "remote" {
                return "origin"
            }
            "branch" {
                return "* main"
            }
            "ls-files" {
                # Mock no conflict markers
                return ""
            }
            "grep" {
                # Mock no merge conflict markers found
                $global:LASTEXITCODE = 1  # grep returns 1 when no matches found
                return ""
            }
            "rev-parse" {
                if ($gitArgs -contains "--git-dir") {
                    return ".git"
                }
                return "abcd1234"
            }
            "stash" {
                $global:LASTEXITCODE = 0
                return "Stashed changes"
            }
            "checkout" {
                $global:LASTEXITCODE = 0
                return "Switched to branch"
            }
            default {
                return "git command mocked"
            }
        }
    }

    # Mock gh command for GitHub CLI
    function global:gh {
        param()
        return "gh command mocked"
    }

    # Create test directory
    $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "PatchManagerTest"
    if (Test-Path $script:testDir) {
        Remove-Item $script:testDir -Recurse -Force
    }
    New-Item -Path $script:testDir -ItemType Directory -Force | Out-Null
}

AfterAll {
    # Clean up test directory
    if (Test-Path $script:testDir) {
        Remove-Item $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Remove environment variable
    Remove-Item -Path "env:PESTER_RUN" -ErrorAction SilentlyContinue
}

Describe "PatchManager v2.1 Core Functions" {
    BeforeEach {
        $script:gitCalls = @()
    }

    Context "Module Loading and Structure" {
        It "Should have imported PatchManager module" {
            Get-Module "PatchManager" | Should -Not -BeNullOrEmpty
        }

        It "Should have v2.1 core functions available" {
            $expectedFunctions = @(
                'Invoke-PatchWorkflow',
                'Invoke-PatchRollback', 
                'Invoke-PostMergeCleanup',
                'Invoke-PRConsolidation'
            )

            foreach ($func in $expectedFunctions) {
                Get-Command $func -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because "$func should be available in v2.1"
            }
        }

        It "Should have additional helper functions available" {
            $helperFunctions = @(
                'New-PatchIssue',
                'New-PatchPR',
                'New-CrossForkPR',
                'Update-RepositoryDocumentation'
            )

            foreach ($func in $helperFunctions) {
                Get-Command $func -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because "$func should be available"
            }
        }
    }

    Context "Invoke-PatchWorkflow" {
        It "Should require PatchDescription parameter" {
            { Invoke-PatchWorkflow } | Should -Throw
        }

        It "Should accept basic parameters" {
            $scriptBlock = { Write-Host "Test patch operation" }
            
            { Invoke-PatchWorkflow -PatchDescription "Test patch" -PatchOperation $scriptBlock -CreateIssue:$false } | Should -Not -Throw
        }

        It "Should accept CreatePR parameter" {
            $scriptBlock = { Write-Host "Test patch operation" }
            
            { Invoke-PatchWorkflow -PatchDescription "Test patch" -PatchOperation $scriptBlock -CreatePR -CreateIssue:$false } | Should -Not -Throw
        }

        It "Should handle DryRun parameter" {
            $scriptBlock = { Write-Host "Test patch operation" }
            
            { Invoke-PatchWorkflow -PatchDescription "Test patch" -PatchOperation $scriptBlock -DryRun -CreateIssue:$false } | Should -Not -Throw
        }
    }

    Context "Invoke-PatchRollback" {
        It "Should accept valid parameters" {
            { Invoke-PatchRollback -RollbackType "LastCommit" -CreateBackup } | Should -Not -Throw
        }

        It "Should accept valid Rollback types" {
            $validTypes = @("LastCommit", "PreviousBranch")
            
            foreach ($type in $validTypes) {
                { Invoke-PatchRollback -RollbackType $type -CreateBackup } | Should -Not -Throw -Because "$type should be a valid rollback type"
            }
        }

        It "Should accept CreateBackup parameter" {
            { Invoke-PatchRollback -RollbackType "LastCommit" -CreateBackup } | Should -Not -Throw
        }
    }

    Context "Invoke-PostMergeCleanup" {
        It "Should execute with required BranchName parameter" {
            { Invoke-PostMergeCleanup -BranchName "test-branch" } | Should -Not -Throw
        }

        It "Should accept Force parameter" {
            { Invoke-PostMergeCleanup -BranchName "test-branch" -Force } | Should -Not -Throw
        }
    }

    Context "Invoke-PRConsolidation" {
        It "Should execute without required parameters" {
            { Invoke-PRConsolidation } | Should -Not -Throw
        }

        It "Should accept MaxPRs parameter" {
            { Invoke-PRConsolidation -MaxPRs 5 } | Should -Not -Throw
        }
    }
}

Describe "PatchManager Helper Functions" {
    Context "New-PatchIssue" {
        It "Should require Description parameter" {
            { New-PatchIssue } | Should -Throw
        }

        It "Should accept basic issue creation parameters" {
            { New-PatchIssue -Description "Test Issue" -Priority "Medium" } | Should -Not -Throw
        }
    }

    Context "New-PatchPR" {
        It "Should require Description parameter" {
            { New-PatchPR } | Should -Throw
        }

        It "Should accept basic PR creation parameters" {
            { New-PatchPR -Description "Test PR" -Priority "Medium" } | Should -Not -Throw
        }
    }

    Context "Update-RepositoryDocumentation" {
        It "Should execute without required parameters" {
            { Update-RepositoryDocumentation } | Should -Not -Throw
        }

        It "Should accept Force parameter" {
            { Update-RepositoryDocumentation -Force } | Should -Not -Throw
        }
    }
}

Describe "PatchManager Error Handling" {
    Context "Invalid Parameters" {
        It "Should handle empty patch description gracefully" {
            $scriptBlock = { Write-Host "Test" }
            { Invoke-PatchWorkflow -PatchDescription "" -PatchOperation $scriptBlock -CreateIssue:$false } | Should -Throw
        }

        It "Should handle invalid rollback type gracefully" {
            { Invoke-PatchRollback -RollbackType "InvalidType" } | Should -Throw
        }
    }

    Context "Environment Requirements" {
        It "Should handle missing git gracefully" {
            # This test verifies the module loads even if git isn't available
            $originalPath = $env:PATH
            try {
                $env:PATH = ""
                { Get-Command -Module PatchManager } | Should -Not -Throw
            }
            finally {
                $env:PATH = $originalPath
            }
        }
    }
}

Describe "PatchManager Integration" {
    Context "Cross-Platform Compatibility" {
        It "Should handle different path separators" {
            $testPaths = @(
                "/unix/style/path",
                "C:\\Windows\\Style\\Path", 
                "relative/path"
            )

            foreach ($path in $testPaths) {
                { Test-Path $path -ErrorAction SilentlyContinue } | Should -Not -Throw
            }
        }

        It "Should work with current directory" {
            { Invoke-PatchWorkflow -PatchDescription "Test in current dir" -PatchOperation { Get-Location } -CreateIssue:$false } | Should -Not -Throw
        }
    }
}

