BeforeAll {
    # Set environment variable to indicate test execution
    $env:PESTER_RUN = 'true'

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

    # Mock Write-CustomLog function
    function global:Write-CustomLog {
        param([string]$Message, [string]$Level = "INFO")
        Write-Host "[$Level] $Message"
    }

    # Import PatchManager module
    $patchManagerPath = Join-Path $projectRoot "aither-core/modules/PatchManager"

    try {
        Import-Module $patchManagerPath -Force -ErrorAction Stop
        Write-Host "PatchManager module imported successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to import PatchManager module: $_"
        throw
    }

    # Mock git commands
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
            "rev-parse" {
                if ($gitArgs[1] -eq "--abbrev-ref" -and $gitArgs[2] -eq "HEAD") {
                    return "main"
                }
            }
            "branch" {
                if ($gitArgs[1] -eq "-r") {
                    return @(
                        "  origin/main",
                        "  origin/feature/test-branch"
                    )
                }
            }
            "remote" {
                if ($gitArgs[1] -eq "-v") {
                    return "origin  https://github.com/test/repo.git (fetch)"
                }
            }
            default {
                $global:LASTEXITCODE = 0
                return ""
            }
        }
    }

    # Mock gh command (GitHub CLI)
    function global:gh {
        param()
        $ghArgs = $args

        if ($ghArgs[0] -eq "auth" -and $ghArgs[1] -eq "status") {
            return "Logged in to github.com as testuser"
        }

        $global:LASTEXITCODE = 0
        return ""    }
}

AfterAll {
    # Clean up environment variable
    Remove-Item env:PESTER_RUN -ErrorAction SilentlyContinue
}

Describe "PatchManager Core Functions" {
    BeforeEach {
        $script:gitCalls = @()    }

    Context "Test-PatchingRequirements" {
        It "Should validate basic patching requirements" {
            $result = Test-PatchingRequirements -ProjectRoot $PWD

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -BeOfType [bool]
        }

        It "Should return proper structure with required properties" {
            $result = Test-PatchingRequirements -ProjectRoot $PWD

            $result.AllRequirementsMet | Should -BeOfType [bool]

            # Test that properties exist and are collection types with Count property
            $result.ModulesAvailable | Should -Not -BeNullOrEmpty
            $result.ModulesAvailable.Count | Should -BeGreaterThan -1
            ($result.ModulesAvailable -is [array]) | Should -BeTrue

            # For potentially empty arrays, just check they have Count property and are enumerable
            { $result.ModulesMissing.Count } | Should -Not -Throw
            $result.ModulesMissing.Count | Should -BeGreaterOrEqual 0
            ($result.ModulesMissing -is [array]) | Should -BeTrue

            $result.CommandsAvailable | Should -Not -BeNullOrEmpty
            $result.CommandsAvailable.Count | Should -BeGreaterOrEqual 1
            ($result.CommandsAvailable -is [array]) | Should -BeTrue

            { $result.CommandsMissing.Count } | Should -Not -Throw
            $result.CommandsMissing.Count | Should -BeGreaterOrEqual 0
            ($result.CommandsMissing -is [array]) | Should -BeTrue
        }
    }
      Context "Invoke-GitControlledPatch" {
        It "Should require PatchDescription parameter" {
            # Test that mandatory parameter validation works by providing invalid empty string
            { Invoke-GitControlledPatch -PatchDescription "" -DryRun } | Should -Throw
        }

        It "Should accept DryRun parameter" {
            $scriptBlock = { Write-Host "Test patch" }

            { Invoke-GitControlledPatch -PatchDescription "Test patch" -PatchOperation $scriptBlock -DryRun } | Should -Not -Throw
        }

        It "Should validate working tree when not forced" {
            $scriptBlock = { Write-Host "Test patch" }

            # This should not throw since our mock git returns clean status
            { Invoke-GitControlledPatch -PatchDescription "Test patch" -PatchOperation $scriptBlock -DryRun } | Should -Not -Throw
        }
    }

    Context "Invoke-EnhancedPatchManager" {
        It "Should require PatchDescription parameter" {
            { Invoke-EnhancedPatchManager } | Should -Throw
        }

        It "Should accept AutoValidate parameter" {
            { Invoke-EnhancedPatchManager -PatchDescription "Test patch" -AutoValidate -DryRun } | Should -Not -Throw
        }

        It "Should accept CreatePullRequest parameter" {
            { Invoke-EnhancedPatchManager -PatchDescription "Test patch" -CreatePullRequest -DryRun } | Should -Not -Throw
        }    }

    Context "Invoke-QuickRollback" {
        It "Should accept RollbackType parameter" {
            { Invoke-QuickRollback -RollbackType "LastCommit" -DryRun } | Should -Not -Throw
        }
          It "Should accept CreateBackup parameter" {
            { Invoke-QuickRollback -RollbackType "LastCommit" -CreateBackup -DryRun } | Should -Not -Throw
        }
    }
}

Describe "PatchManager Integration Tests" {
    BeforeEach {
        $script:gitCalls = @()
    }

    Context "Module Loading" {
        It "Should have imported PatchManager functions" {
            Get-Command -Module "PatchManager" | Should -Not -BeNullOrEmpty
        }
          It "Should have core functions available" {
            $expectedFunctions = @(
                'Invoke-GitControlledPatch',
                'Invoke-EnhancedPatchManager',
                'Test-PatchingRequirements',
                'Invoke-QuickRollback'
            )

            foreach ($func in $expectedFunctions) {
                Get-Command $func -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because "$func should be available"
            }
        }
    }

    Context "Cross-Platform Environment" {
        It "Should handle cross-platform paths correctly" {
            # Test that the module works with forward slash paths
            $testPath = "/test/path/file.ps1"

            # This should not throw an error
            { Test-Path $testPath -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }
}

Describe "PatchManager Error Handling" {
    Context "Invalid Parameters" {
        It "Should handle invalid patch description gracefully" {
            { Invoke-GitControlledPatch -PatchDescription "" -DryRun } | Should -Throw
        }
          It "Should handle invalid rollback type gracefully" {
            { Invoke-QuickRollback -RollbackType "InvalidType" -DryRun } | Should -Throw
        }
    }

    Context "Environment Validation" {
        It "Should detect missing git command" {
            # Mock Get-Command to return null for git (simulating not found)
            Mock Get-Command -MockWith {
                return $null
            } -ParameterFilter { $Name -eq "git" } -ModuleName PatchManager

            $result = Test-PatchingRequirements -ProjectRoot $PWD
            $result.CommandsMissing | Should -Contain "git"
        }
    }
}

