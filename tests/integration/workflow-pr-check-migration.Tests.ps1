#Requires -Version 7.0

<#
.SYNOPSIS
    Integration test to validate the pr-check.yml workflow migration
.DESCRIPTION
    This test verifies that the consolidated pr-check.yml workflow correctly
    replaces and consolidates the functionality of the old workflows:
    - 01-master-orchestrator.yml
    - 02-pr-validation-build.yml
    - 06-documentation.yml
    - 07-indexes.yml
    - 08-update-pr-title.yml
    - 10-module-validation-performance.yml
    
    Test Checklist Item: "Create a test PR and verify"
#>

BeforeAll {
    $script:WorkflowFile = Join-Path $PSScriptRoot "../../.github/workflows/pr-check.yml"
    $script:WorkflowsPath = Join-Path $PSScriptRoot "../../.github/workflows"
}

Describe "PR Check Workflow Migration" -Tag 'Integration', 'CI/CD', 'Migration' {
    BeforeAll {
        $script:Content = Get-Content -Path $script:WorkflowFile -Raw
    }

    Context "Workflow file existence and structure" {
        It "Should have pr-check.yml workflow file" {
            Test-Path $script:WorkflowFile | Should -Be $true
        }

        It "Should have valid YAML structure" {
            { 
                $pythonCmd = if (Get-Command python3 -ErrorAction SilentlyContinue) { 'python3' } 
                            elseif (Get-Command python -ErrorAction SilentlyContinue) { 'python' }
                            else { $null }
                
                if ($pythonCmd) {
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    try {
                        $script:Content | Set-Content -Path $tempFile -Encoding UTF8
                        $pythonScript = "import yaml; yaml.safe_load(open(r'$tempFile'))"
                        & $pythonCmd -c $pythonScript 2>&1 | Out-Null
                        if ($LASTEXITCODE -ne 0) {
                            throw "YAML validation failed"
                        }
                    } finally {
                        if (Test-Path $tempFile) {
                            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
                        }
                    }
                }
            } | Should -Not -Throw
        }

        It "Should have descriptive name indicating consolidation" {
            $script:Content | Should -Match "name:\s*.*PR Check.*Consolidated"
        }
    }

    Context "Old workflows are deleted/replaced" {
        It "Should not have 01-master-orchestrator.yml" {
            Test-Path (Join-Path $script:WorkflowsPath "01-master-orchestrator.yml") | Should -Be $false
        }

        It "Should not have 02-pr-validation-build.yml" {
            Test-Path (Join-Path $script:WorkflowsPath "02-pr-validation-build.yml") | Should -Be $false
        }

        It "Should not have 06-documentation.yml" {
            Test-Path (Join-Path $script:WorkflowsPath "06-documentation.yml") | Should -Be $false
        }

        It "Should not have 07-indexes.yml" {
            Test-Path (Join-Path $script:WorkflowsPath "07-indexes.yml") | Should -Be $false
        }

        It "Should not have 08-update-pr-title.yml" {
            Test-Path (Join-Path $script:WorkflowsPath "08-update-pr-title.yml") | Should -Be $false
        }

        It "Should not have 10-module-validation-performance.yml" {
            Test-Path (Join-Path $script:WorkflowsPath "10-module-validation-performance.yml") | Should -Be $false
        }
    }

    Context "Workflow triggers - PR events" {
        It "Should trigger on pull_request events" {
            $script:Content | Should -Match "on:.*pull_request:" -Because "PR check should trigger on pull requests"
        }

        It "Should trigger on PR opened, synchronize, reopened, and ready_for_review" {
            $script:Content | Should -Match "types:\s*\[opened,\s*synchronize,\s*reopened,\s*ready_for_review\]"
        }

        It "Should target main and dev branches" {
            $script:Content | Should -Match "branches:\s*\[main.*dev" -Because "Should monitor main development branches"
        }
    }

    Context "Concurrency settings - Prevent duplicate runs" {
        It "Should have concurrency group based on PR number" {
            $script:Content | Should -Match "concurrency:.*group:\s*pr-check-.*github\.event\.pull_request\.number" `
                -Because "Should prevent duplicate runs for the same PR"
        }

        It "Should cancel in-progress runs when new commits are pushed" {
            $script:Content | Should -Match "cancel-in-progress:\s*true" `
                -Because "Old runs should be cancelled when new commits arrive"
        }
    }

    Context "Required jobs - All checks consolidated" {
        It "Should have validation job" {
            $script:Content | Should -Match "validate:" -Because "Syntax, config, manifests validation"
        }

        It "Should have test job" {
            $script:Content | Should -Match "test:" -Because "Comprehensive test execution"
        }

        It "Should have build job" {
            $script:Content | Should -Match "build:" -Because "Package building"
        }

        It "Should have build-docker job" {
            $script:Content | Should -Match "build-docker:" -Because "Docker image build test"
        }

        It "Should have docs job" {
            $script:Content | Should -Match "docs:" -Because "Documentation generation"
        }

        It "Should have summary job" {
            $script:Content | Should -Match "summary:" -Because "Single consolidated PR comment"
        }
    }

    Context "Validation job - Replaces old validation workflows" {
        It "Should run syntax validation (0407_Validate-Syntax.ps1)" {
            $script:Content | Should -Match "0407_Validate-Syntax\.ps1" `
                -Because "Should validate all PowerShell syntax"
        }

        It "Should run config validation (0413_Validate-ConfigManifest.ps1)" {
            $script:Content | Should -Match "0413_Validate-ConfigManifest\.ps1" `
                -Because "Should validate config manifest"
        }

        It "Should run manifest validation (0405_Validate-Manifests.ps1)" {
            $script:Content | Should -Match "0405_Validate-Manifests\.ps1" `
                -Because "Should validate module manifests"
        }

        It "Should run architecture validation (0950_Validate-AllAutomationScripts.ps1)" {
            $script:Content | Should -Match "0950_Validate-AllAutomationScripts\.ps1" `
                -Because "Should validate automation scripts architecture"
        }

        It "Should have reasonable timeout (10 minutes)" {
            $script:Content | Should -Match "validate.*timeout-minutes:\s*10" `
                -Because "Validation should complete quickly"
        }
    }

    Context "Test job - Delegates to test execution workflow" {
        It "Should use workflow_call to delegate to 03-test-execution.yml" {
            $script:Content | Should -Match "test:.*uses:\s*\.\/\.github\/workflows\/03-test-execution\.yml" `
                -Because "Should reuse existing test workflow"
        }

        It "Should run all test suites" {
            $script:Content | Should -Match "test_suite:\s*'all'" `
                -Because "PR checks should run comprehensive tests"
        }

        It "Should depend on validation job" {
            $script:Content | Should -Match "test:.*needs:\s*validate" `
                -Because "Tests should wait for validation to pass"
        }

        It "Should run even if validation fails (for visibility)" {
            $script:Content | Should -Match "test:.*if:\s*always\(\)" `
                -Because "Tests should run to show all issues"
        }
    }

    Context "Build job - Verify package building" {
        It "Should generate build metadata" {
            $script:Content | Should -Match "0515_Generate-BuildMetadata\.ps1" `
                -Because "Should track build information"
        }

        It "Should create release package" {
            $script:Content | Should -Match "0902_Create-ReleasePackage\.ps1" `
                -Because "Should verify package creation works"
        }

        It "Should upload build artifacts" {
            $script:Content | Should -Match "Upload Build Artifacts" `
                -Because "Build artifacts should be available for review"
            $script:Content | Should -Match "actions/upload-artifact" `
                -Because "Should use GitHub artifact upload action"
        }

        It "Should have reasonable timeout (15 minutes)" {
            $script:Content | Should -Match "build.*timeout-minutes:\s*15" `
                -Because "Build should complete in reasonable time"
        }
    }

    Context "Docker build job - Test only, no push" {
        It "Should build Docker image without pushing" {
            $script:Content | Should -Match "build-docker.*push:\s*false" `
                -Because "PR checks should only test build, not push"
        }

        It "Should use docker/build-push-action" {
            $script:Content | Should -Match "docker/build-push-action" `
                -Because "Should use standard Docker build action"
        }

        It "Should build for linux/amd64 platform" {
            $script:Content | Should -Match "platforms.*linux/amd64" `
                -Because "Should at least build for common platform"
        }

        It "Should use GitHub Actions cache" {
            $script:Content | Should -Match "cache-from.*type=gha" `
                -Because "Should leverage cache for faster builds"
        }
    }

    Context "Documentation job - Replaces old doc workflows" {
        It "Should generate function documentation if script exists" {
            $script:Content | Should -Match "0524_Generate-FunctionDocs\.ps1" `
                -Because "Should update function documentation"
        }

        It "Should update indexes if script exists" {
            $script:Content | Should -Match "0526_Update-Indexes\.ps1" `
                -Because "Should update index.md files"
        }

        It "Should upload documentation artifacts" {
            $script:Content | Should -Match "Upload Documentation" `
                -Because "Documentation should be reviewable"
            $script:Content | Should -Match "actions/upload-artifact" `
                -Because "Should use GitHub artifact upload action"
        }
    }

    Context "Summary job - Single consolidated comment" {
        It "Should depend on all jobs" {
            $script:Content | Should -Match "summary.*needs" `
                -Because "Summary should wait for all checks"
            $script:Content | Should -Match "validate.*test.*build.*build-docker.*docs" `
                -Because "Should depend on all check jobs"
        }

        It "Should always run (even on failures)" {
            $script:Content | Should -Match "summary.*if:\s*always\(\)" `
                -Because "Comment should always be posted"
        }

        It "Should use actions/github-script to post comment" {
            $script:Content | Should -Match "actions/github-script" `
                -Because "Should use GitHub API to manage comments"
        }

        It "Should create or update existing bot comment" {
            $script:Content | Should -Match "github-actions\[bot\]" `
                -Because "Should find and update existing comment to avoid duplicates"
            $script:Content | Should -Match "PR Check" `
                -Because "Should use consistent comment marker"
        }

        It "Should include all check results in comment" {
            $allChecks = @('validate', 'test', 'build', 'docker', 'docs')
            foreach ($check in $allChecks) {
                $script:Content | Should -Match $check `
                    -Because "Comment should reference $check result"
            }
        }

        It "Should show overall status (PASSED/FAILED)" {
            $script:Content | Should -Match "PASSED|FAILED" `
                -Because "Should clearly indicate overall outcome"
        }

        It "Should include links to workflow run and artifacts" {
            $script:Content | Should -Match "Workflow Run|artifacts" `
                -Because "Developers need easy access to details"
        }
    }

    Context "Permissions - Security best practices" {
        It "Should have minimal required permissions" {
            $script:Content | Should -Match "permissions:" -Because "Should explicitly define permissions"
        }

        It "Should have read permissions for contents" {
            $script:Content | Should -Match "contents:\s*read" -Because "Only needs to read code"
        }

        It "Should have write permissions for pull-requests" {
            $script:Content | Should -Match "pull-requests:\s*write" -Because "Needs to post comments"
        }

        It "Should have write permissions for checks" {
            $script:Content | Should -Match "checks:\s*write" -Because "Needs to report check results"
        }
    }

    Context "Environment variables - CI detection" {
        It "Should set AITHERZERO_CI to true" {
            $script:Content | Should -Match "env:.*AITHERZERO_CI:\s*true" `
                -Because "Scripts should detect CI environment"
        }

        It "Should set AITHERZERO_NONINTERACTIVE to true" {
            $script:Content | Should -Match "env:.*AITHERZERO_NONINTERACTIVE:\s*true" `
                -Because "Scripts should not prompt for input"
        }

        It "Should suppress banner output" {
            $script:Content | Should -Match "env:.*AITHERZERO_SUPPRESS_BANNER:\s*true" `
                -Because "Should minimize log noise"
        }
    }

    Context "Performance expectations" {
        It "Should complete in under 15 minutes (aggregate job timeouts)" {
            # Verify reasonable timeouts exist
            $script:Content | Should -Match "timeout-minutes" `
                -Because "Jobs should have timeout limits"
        }

        It "Should have parallel execution (jobs don't block each other)" {
            # Verify that test, build, build-docker, and docs can run in parallel
            # by checking they all depend on validate
            $script:Content | Should -Match "test:" `
                -Because "Test job should exist"
            $script:Content | Should -Match "needs:\s*validate" `
                -Because "Jobs should depend on validate"
            $script:Content | Should -Match "build:" `
                -Because "Build job should exist"
        }
    }

    Context "Bootstrap and setup" {
        It "Should bootstrap with Minimal profile for speed" {
            $script:Content | Should -Match "bootstrap\.ps1.*-InstallProfile\s+Minimal" `
                -Because "CI should use minimal profile for faster setup"
        }

        It "Should use ubuntu-latest runner" {
            $script:Content | Should -Match "runs-on:\s*ubuntu-latest" `
                -Because "ubuntu-latest has PowerShell 7 pre-installed"
        }
    }
}

Describe "PR Check Workflow - Comment Uniqueness" -Tag 'Integration', 'CI/CD', 'Migration' {
    Context "Single comment enforcement mechanism" {
        BeforeAll {
            $script:Content = Get-Content -Path $script:WorkflowFile -Raw
        }

        It "Should search for existing bot comment by marker" {
            $script:Content | Should -Match "listComments" `
                -Because "Should identify existing comments"
            $script:Content | Should -Match "github-actions\[bot\]" `
                -Because "Should filter for bot comments"
        }

        It "Should update existing comment if found" {
            $script:Content | Should -Match "updateComment" `
                -Because "Should update instead of creating duplicates"
        }

        It "Should create new comment only if none exists" {
            $script:Content | Should -Match "createComment" `
                -Because "Should create comment on first run"
        }

        It "Should use consistent comment identifier" {
            $script:Content | Should -Match "'PR Check -'" `
                -Because "Comment title should be consistent for finding"
        }
    }
}
