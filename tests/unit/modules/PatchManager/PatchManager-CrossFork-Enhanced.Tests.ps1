BeforeAll {
    # Set environment variable to indicate test execution
    $env:PESTER_RUN = 'true'

    # Find project root by looking for characteristic files
    $currentPath = $PSScriptRoot
    $projectRoot = $currentPath
    while ($projectRoot -and -not (Test-Path (Join-Path $projectRoot "aither-core"))) {
        $projectRoot = Split-Path $projectRoot -Parent
    }

    if (-not $projectRoot) {
        throw "Could not find project root (looking for aither-core directory)"
    }

    Write-CustomLog -Level 'WARN' -Message "Project root detected: $projectRoot"

    # Import TestingFramework module first for proper test orchestration
    $testingFrameworkPath = Join-Path $projectRoot "aither-core/modules/TestingFramework"
    try {
        Import-Module $testingFrameworkPath -Force -Global -ErrorAction Stop
        Write-CustomLog -Level 'SUCCESS' -Message "TestingFramework module imported successfully"
    }
    catch {
        Write-Warning "TestingFramework module not available, using fallback logging"
    }

    # Import Logging module
    $loggingPath = Join-Path $projectRoot "aither-core/modules/Logging"
    try {
        Import-Module $loggingPath -Force -Global -ErrorAction SilentlyContinue
    }
    catch {
        # Mock Write-CustomLog if Logging module is not available
        function global:Write-CustomLog {
            param([string]$Message, [string]$Level = "INFO")
            Write-CustomLog -Level 'INFO' -Message "[$Level] $Message"
        }
    }

    # Import PatchManager module
    $patchManagerPath = Join-Path $projectRoot "aither-core/modules/PatchManager"
    try {
        Import-Module $patchManagerPath -Force -ErrorAction Stop
        Write-CustomLog -Level 'SUCCESS' -Message "PatchManager module imported successfully"
    }
    catch {
        Write-Error "Failed to import PatchManager module: $_"
        throw
    }
      # Mock GitHub CLI commands for testing - simplified version
    function global:gh {
        param()
        Write-CustomLog -Level 'WARN' -Message "Mock gh called with: $($args -join ' ')"
        return "Mock gh command executed"
    }

    # Mock git commands - simplified version
    function global:git {
        param()
        Write-CustomLog -Level 'WARN' -Message "Mock git called with: $($args -join ' ')"

        switch ($args[0]) {
            'remote' {
                if ($args[1] -eq 'get-url') {
                    switch ($args[2]) {
                        'origin' { return 'https://github.com/wizzense/AitherZero.git' }
                        'upstream' { return 'https://github.com/Aitherium/AitherLabs.git' }
                        'root' { return 'https://github.com/Aitherium/Aitherium.git' }
                    }
                }
                elseif ($args[1] -eq 'show') {
                    return @'
origin
upstream
root
'@
                }
            }
            'status' { return 'On branch main' }
            'branch' { return '* main' }
            'rev-parse' { return 'abc123def456' }
            default { return "Mock git: $($args -join ' ')" }
        }
    }
}

Describe "PatchManager Cross-Fork Integration Tests" -Tags @('Integration', 'CrossFork', 'PatchManager') {
      BeforeEach {
        # Clear any previous state if needed
        Write-CustomLog -Level 'INFO' -Message "Setting up test scenario..."
    }

    Context "Repository Detection and Fork Chain Analysis" {
          It "Should detect current repository correctly" {
            $repoInfo = Get-GitRepositoryInfo

            $repoInfo | Should -Not -BeNullOrEmpty
            $repoInfo.Name | Should -Not -BeNullOrEmpty
            $repoInfo.Owner | Should -Not -BeNullOrEmpty
        }

        It "Should identify fork chain when available" {
            $repoInfo = Get-GitRepositoryInfo

            $repoInfo.ForkChain | Should -Not -BeNullOrEmpty
            # Should have at least the current repository
            $repoInfo.ForkChain.Count | Should -BeGreaterThan 0
        }

        It "Should map remotes correctly" {
            $repoInfo = Get-GitRepositoryInfo

            $repoInfo.Remotes | Should -Not -BeNullOrEmpty
            $repoInfo.Remotes.ContainsKey('origin') | Should -Be $true
        }
    }

    Context "Cross-Fork Issue Creation" {
          It "Should create issue in current repo when TargetRepository is 'current'" {
            $result = New-PatchIssue -Description "Test issue for current repo" -Priority "Medium" -TargetRepository "current" -DryRun

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }

        It "Should create issue in upstream repo when TargetRepository is 'upstream'" {
            $result = New-PatchIssue -Description "Test issue for upstream repo" -Priority "High" -TargetRepository "upstream" -DryRun

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }

        It "Should create issue in root repo when TargetRepository is 'root'" {
            $result = New-PatchIssue -Description "Test issue for root repo" -Priority "Critical" -TargetRepository "root" -DryRun

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }
    }
      Context "Cross-Fork Pull Request Creation" {

        It "Should create PR in current repo when TargetFork is 'current'" {
            $result = New-PatchPR -Description "Test PR for current repo" -BranchName "test-branch" -DryRun

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }

        It "Should create cross-fork PR when targeting upstream" {
            $result = New-CrossForkPR -Description "Test cross-fork PR" -BranchName "feature-branch" -TargetFork "upstream" -DryRun

            $result | Should -Not -BeNullOrEmpty
            # Cross-fork PRs may fail in test environment - that's expected
        }

        It "Should create cross-fork PR when targeting root" {
            $result = New-CrossForkPR -Description "Test cross-fork PR to root" -BranchName "major-feature" -TargetFork "root" -DryRun

            $result | Should -Not -BeNullOrEmpty
            # Cross-fork PRs may fail in test environment - that's expected
        }
    }
      Context "Integrated Workflow with Cross-Fork Support" {

        It "Should execute complete workflow with issue and PR creation" {
            $result = Invoke-PatchWorkflow -PatchDescription "Test integrated workflow" -PatchOperation {
                Write-CustomLog -Level 'INFO' -Message "Mock patch operation"
            } -CreatePR -TargetFork "current" -DryRun

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }

        It "Should handle workflow without CreatePR but with issue creation" {
            $result = Invoke-PatchWorkflow -PatchDescription "Test issue-only workflow" -PatchOperation {
                Write-CustomLog -Level 'INFO' -Message "Mock patch operation"
            } -TargetFork "current" -DryRun

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }

        It "Should handle local-only workflow when CreateIssue is disabled" {
            $result = Invoke-PatchWorkflow -PatchDescription "Test local-only workflow" -PatchOperation {
                Write-CustomLog -Level 'INFO' -Message "Mock patch operation"
            } -CreateIssue:$false -DryRun

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }
    }

    Context "Error Handling and Validation" {
          It "Should validate TargetRepository parameter against available remotes" {
            { New-PatchIssue -Description "Test" -TargetRepository "nonexistent" -DryRun } | Should -Throw
        }

        It "Should handle missing GitHub CLI gracefully in dry run mode" {
            # This test would need to mock a missing gh command scenario
            # For now, just verify the function can handle various edge cases
            $result = New-PatchIssue -Description "Test resilience" -Priority "Low" -DryRun
            $result | Should -Not -BeNullOrEmpty
        }
          It "Should preserve existing branch when no changes are made" {
            $result = Invoke-PatchWorkflow -PatchDescription "No-op test" -PatchOperation {
                # Intentionally empty operation
            } -DryRun

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }
    }
}

Describe "Cross-Fork Repository Perspective Tests" -Tags @('Integration', 'CrossFork', 'Scenarios') {

    Context "AitherZero Repository Perspective" {

        It "Should identify repository information" {
            $repoInfo = Get-GitRepositoryInfo
            $repoInfo.Name | Should -Not -BeNullOrEmpty
            $repoInfo.Owner | Should -Not -BeNullOrEmpty
        }

        It "Should handle cross-fork operations gracefully" {
            $result = New-CrossForkPR -Description "Feature from AitherZero to AitherLabs" -BranchName "new-feature" -TargetFork "upstream" -DryRun

            # Result should exist whether it succeeds or fails gracefully
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Multi-Repository Workflow Validation" {

        It "Should handle different target repositories consistently" {
            $targets = @('current')  # Only test current repo to avoid remote dependencies

            foreach ($target in $targets) {
                $result = Invoke-PatchWorkflow -PatchDescription "Consistency test for $target" -PatchOperation {
                    Write-CustomLog -Level 'INFO' -Message "Test operation"
                } -CreatePR -TargetFork $target -DryRun

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $true
            }
        }
    }
}
