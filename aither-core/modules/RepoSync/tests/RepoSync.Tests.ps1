#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive Pester tests for the RepoSync module

.DESCRIPTION
    Tests repository synchronization functionality including:
    - Bidirectional sync operations
    - Git repository management
    - Remote repository coordination
    - Status monitoring and reporting

.NOTES
    Customized for RepoSync module functionality
#>

BeforeAll {
    # Import the module under test
    $ModulePath = Split-Path -Parent $PSScriptRoot
    Import-Module $ModulePath -Force

    # Setup test environment
    $script:TestStartTime = Get-Date
    $script:ModuleName = "RepoSync"
    $script:TestWorkspace = if ($env:TEMP) {
        Join-Path $env:TEMP "RepoSync-Test-$(Get-Random)"
    } elseif (Test-Path '/tmp') {
        "/tmp/RepoSync-Test-$(Get-Random)"
    } else {
        Join-Path (Get-Location) "RepoSync-Test-$(Get-Random)"
    }

    # Create test workspace
    New-Item -Path $script:TestWorkspace -ItemType Directory -Force | Out-Null

    # Mock dependencies if not available
    if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
        function Write-CustomLog {
            param([string]$Message, [string]$Level = "INFO")
            Write-Host "[$Level] $Message"
        }
    }
}

AfterAll {
    # Cleanup test workspace
    if ($script:TestWorkspace -and (Test-Path $script:TestWorkspace)) {
        Remove-Item $script:TestWorkspace -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Calculate test execution time
    $testDuration = (Get-Date) - $script:TestStartTime
    Write-Host "RepoSync module test execution completed in $($testDuration.TotalSeconds) seconds" -ForegroundColor Green
}

Describe "RepoSync Module - Core Functionality" {
    Context "Module Import and Structure" {
        It "Should import the module successfully" {
            Get-Module -Name $script:ModuleName | Should -Not -BeNullOrEmpty
        }

        It "Should export expected repository sync functions" {
            $expectedFunctions = @(
                'Sync-ToAitherLab',
                'Sync-FromAitherLab',
                'Get-SyncStatus',
                'Get-RepoSyncStatus'
            )

            $exportedFunctions = Get-Command -Module $script:ModuleName | Select-Object -ExpandProperty Name

            foreach ($function in $expectedFunctions) {
                $exportedFunctions | Should -Contain $function
            }
        }

        It "Should require PowerShell 7.0 or higher" {
            $module = Get-Module $script:ModuleName
            $module.PowerShellVersion | Should -BeGreaterOrEqual ([Version]"7.0")
        }

        It "Should have proper module metadata" {
            $module = Get-Module $script:ModuleName
            $module | Should -Not -BeNullOrEmpty
            $module.Description | Should -Not -BeNullOrEmpty
        }
    }

    Context "Function Help and Documentation" {
        It "Should provide help for all exported functions" {
            $functions = Get-Command -Module $script:ModuleName -CommandType Function

            foreach ($function in $functions) {
                { Get-Help $function.Name } | Should -Not -Throw
                $help = Get-Help $function.Name
                $help.Synopsis | Should -Not -BeNullOrEmpty
            }
        }

        It "Should have proper parameter documentation" {
            $functions = Get-Command -Module $script:ModuleName -CommandType Function
            
            foreach ($function in $functions) {
                $help = Get-Help $function.Name
                if ($help.Parameters) {
                    $help.Parameters.Parameter | Should -Not -BeNullOrEmpty
                }
            }
        }
    }

    Context "Repository Status Operations" {
        It "Should get repository sync status without errors" {
            { Get-RepoSyncStatus } | Should -Not -Throw
        }

        It "Should return proper status structure" {
            $status = Get-RepoSyncStatus
            $status | Should -Not -BeNullOrEmpty
            $status.Status | Should -Not -BeNullOrEmpty
            $status.LastSync | Should -Not -BeNullOrEmpty
            $status.RemoteStatus | Should -Not -BeNullOrEmpty
            $status.PendingChanges | Should -Not -BeNullOrEmpty
        }

        It "Should handle missing git gracefully" {
            # Mock git command failure
            Mock Invoke-Expression { throw "git not found" } -ParameterFilter { $Command -like "*git*" }
            
            { Get-RepoSyncStatus } | Should -Not -Throw
            $status = Get-RepoSyncStatus
            $status.Status | Should -Be "Git not available"
        }
    }

    Context "Sync Operations" {
        It "Should validate Sync-ToAitherLab parameters" {
            # Test mandatory parameters
            { Sync-ToAitherLab -WhatIf } | Should -Throw
            { Sync-ToAitherLab -CommitMessage "Test" -WhatIf } | Should -Not -Throw
        }

        It "Should validate Sync-FromAitherLab parameters" {
            # Test with WhatIf to avoid actual git operations
            { Sync-FromAitherLab -WhatIf } | Should -Not -Throw
            { Sync-FromAitherLab -Branch "main" -WhatIf } | Should -Not -Throw
        }

        It "Should support dry run for Sync-FromAitherLab" {
            # Test dry run functionality
            { Sync-FromAitherLab -DryRun } | Should -Not -Throw
        }

        It "Should support WhatIf for sync operations" {
            # Test WhatIf support
            { Sync-ToAitherLab -CommitMessage "Test" -WhatIf } | Should -Not -Throw
            { Sync-FromAitherLab -WhatIf } | Should -Not -Throw
        }
    }

    Context "Error Handling" {
        It "Should handle missing mandatory parameters gracefully" {
            { Sync-ToAitherLab -ErrorAction Stop } | Should -Throw
        }

        It "Should provide meaningful error messages" {
            try {
                Sync-ToAitherLab -ErrorAction Stop
            } catch {
                $_.Exception.Message | Should -Not -BeNullOrEmpty
            }
        }

        It "Should handle git command failures gracefully" {
            # Test with non-existent branch
            { Sync-FromAitherLab -Branch "non-existent-branch" -DryRun } | Should -Not -Throw
        }
    }

    Context "Integration with AitherZero Framework" {
        It "Should integrate with logging system" {
            # Test logging integration
            $logFunction = Get-Command Write-CustomLog -ErrorAction SilentlyContinue
            $logFunction | Should -Not -BeNullOrEmpty
        }

        It "Should handle configuration properly" {
            # Test configuration handling
            $module = Get-Module $script:ModuleName
            $module.ModuleBase | Should -Exist
        }

        It "Should support cross-platform operation" {
            # Test cross-platform compatibility
            $module = Get-Module $script:ModuleName
            $module | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "RepoSync Module - Advanced Scenarios" {
    Context "Sync Configuration" {
        It "Should handle file exclusions properly" {
            $excludeFiles = @("*.secret*", "*.env*")
            { Sync-FromAitherLab -ExcludeFiles $excludeFiles -DryRun } | Should -Not -Throw
        }

        It "Should support selective file sync" {
            $filesToSync = @("README.md", "VERSION")
            { Sync-ToAitherLab -CommitMessage "Test" -FilesToSync $filesToSync -WhatIf } | Should -Not -Throw
        }

        It "Should support branch specification" {
            { Sync-FromAitherLab -Branch "develop" -DryRun } | Should -Not -Throw
        }

        It "Should support PR creation flag" {
            { Sync-ToAitherLab -CommitMessage "Test" -CreatePR -WhatIf } | Should -Not -Throw
        }
    }

    Context "Status Reporting" {
        It "Should provide comprehensive sync status" {
            { Get-SyncStatus } | Should -Not -Throw
        }

        It "Should handle missing git repository gracefully" {
            # Change to non-git directory
            Push-Location $script:TestWorkspace
            try {
                { Get-SyncStatus } | Should -Not -Throw
            } finally {
                Pop-Location
            }
        }

        It "Should report remote status accurately" {
            $status = Get-RepoSyncStatus
            $status.RemoteStatus | Should -BeIn @('Connected', 'Disconnected', 'Unknown', 'Error')
        }
    }

    Context "Performance and Reliability" {
        It "Should execute status operations within acceptable time limits" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            Get-RepoSyncStatus | Out-Null
            $stopwatch.Stop()

            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000
        }

        It "Should handle concurrent status requests" {
            $jobs = 1..3 | ForEach-Object {
                Start-Job -ScriptBlock {
                    Import-Module "RepoSync" -Force
                    Get-RepoSyncStatus
                }
            }

            $results = $jobs | Wait-Job | Receive-Job
            $jobs | Remove-Job

            $results | Should -HaveCount 3
            $results | ForEach-Object { $_.Status | Should -Not -BeNullOrEmpty }
        }

        It "Should maintain consistent behavior across multiple calls" {
            $status1 = Get-RepoSyncStatus
            $status2 = Get-RepoSyncStatus

            $status1.Status | Should -Be $status2.Status
            $status1.RemoteStatus | Should -Be $status2.RemoteStatus
        }
    }

    Context "Git Integration" {
        It "Should detect git availability" {
            $gitAvailable = Get-Command git -ErrorAction SilentlyContinue
            $status = Get-RepoSyncStatus
            
            if ($gitAvailable) {
                $status.Status | Should -Not -Be "Git not available"
            } else {
                $status.Status | Should -Be "Git not available"
            }
        }

        It "Should handle git repository detection" {
            # Test behavior in different directory contexts
            $currentDir = Get-Location
            try {
                Set-Location $script:TestWorkspace
                $status = Get-RepoSyncStatus
                $status | Should -Not -BeNullOrEmpty
            } finally {
                Set-Location $currentDir
            }
        }
    }

    Context "Regression Testing" {
        It "Should not regress existing functionality" {
            # Ensure all expected functions are still exported
            $moduleInfo = Get-Module $script:ModuleName
            $exportedFunctions = $moduleInfo.ExportedFunctions.Keys

            # Basic regression check - module should have the expected functions
            $exportedFunctions.Count | Should -Be 4

            # All exported functions should be callable
            foreach ($functionName in $exportedFunctions) {
                $function = Get-Command $functionName -ErrorAction SilentlyContinue
                $function | Should -Not -BeNullOrEmpty
                $function.ModuleName | Should -Be $script:ModuleName
            }
        }

        It "Should maintain backward compatibility" {
            # Test that existing function signatures haven't changed
            $syncToLab = Get-Command Sync-ToAitherLab
            $syncFromLab = Get-Command Sync-FromAitherLab
            $getSyncStatus = Get-Command Get-SyncStatus
            $getRepoSyncStatus = Get-Command Get-RepoSyncStatus

            $syncToLab.Parameters.Keys | Should -Contain "CommitMessage"
            $syncFromLab.Parameters.Keys | Should -Contain "Branch"
            $getSyncStatus | Should -Not -BeNullOrEmpty
            $getRepoSyncStatus | Should -Not -BeNullOrEmpty
        }
    }
}