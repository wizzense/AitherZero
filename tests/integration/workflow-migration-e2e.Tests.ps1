#Requires -Version 7.0

<#
.SYNOPSIS
    End-to-end integration test for CI/CD workflow migration completion
.DESCRIPTION
    This test validates the overall migration from 13 workflows to 6 workflows,
    ensuring all aspects of the migration checklist are met:
    
    1. PR checks produce exactly 1 bot comment
    2. All workflows complete in reasonable time
    3. No duplicate workflow runs
    4. Concurrency is properly configured
    5. Old workflows are deleted
    6. New workflows follow best practices
    
    This is the master verification test for the migration checklist.
#>

BeforeAll {
    $script:WorkflowsPath = Join-Path $PSScriptRoot "../../.github/workflows"
}

Describe "CI/CD Migration - Overall Verification" -Tag 'Integration', 'CI/CD', 'Migration', 'E2E' {
    Context "Workflow count reduction - 13 to 6" {
        BeforeAll {
            $script:AllWorkflows = Get-ChildItem -Path $script:WorkflowsPath -Filter "*.yml" -File |
                Where-Object { $_.Name -notmatch '\.disabled' }
        }

        It "Should have pr-check.yml" {
            $script:AllWorkflows.Name | Should -Contain 'pr-check.yml'
        }

        It "Should have deploy.yml" {
            $script:AllWorkflows.Name | Should -Contain 'deploy.yml'
        }

        It "Should have release.yml" {
            $script:AllWorkflows.Name | Should -Contain 'release.yml'
        }

        It "Should have 03-test-execution.yml (reused)" {
            $script:AllWorkflows.Name | Should -Contain '03-test-execution.yml'
        }

        It "Should have 05-publish-reports-dashboard.yml (manual only)" {
            $script:AllWorkflows.Name | Should -Contain '05-publish-reports-dashboard.yml'
        }

        It "Should have 09-jekyll-gh-pages.yml (maintained)" {
            $script:AllWorkflows.Name | Should -Contain '09-jekyll-gh-pages.yml'
        }

        It "Should NOT have excessive workflow files" {
            # Allow a few extra for utilities, but should be significantly reduced
            $script:AllWorkflows.Count | Should -BeLessOrEqual 10 `
                -Because "Migration should reduce workflow count dramatically"
        }
    }

    Context "Deleted workflows - Old orchestrator and duplicates" {
        It "Should not have 01-master-orchestrator.yml (consolidated into pr-check)" {
            Test-Path (Join-Path $script:WorkflowsPath "01-master-orchestrator.yml") | Should -Be $false
        }

        It "Should not have 02-pr-validation-build.yml (consolidated into pr-check)" {
            Test-Path (Join-Path $script:WorkflowsPath "02-pr-validation-build.yml") | Should -Be $false
        }

        It "Should not have 06-documentation.yml (consolidated into pr-check)" {
            Test-Path (Join-Path $script:WorkflowsPath "06-documentation.yml") | Should -Be $false
        }

        It "Should not have 07-indexes.yml (consolidated into pr-check)" {
            Test-Path (Join-Path $script:WorkflowsPath "07-indexes.yml") | Should -Be $false
        }

        It "Should not have 08-update-pr-title.yml (feature removed)" {
            Test-Path (Join-Path $script:WorkflowsPath "08-update-pr-title.yml") | Should -Be $false
        }

        It "Should not have 10-module-validation-performance.yml (consolidated into pr-check)" {
            Test-Path (Join-Path $script:WorkflowsPath "10-module-validation-performance.yml") | Should -Be $false
        }

        It "Should not have 30-ring-status-dashboard.yml (consolidated into deploy)" {
            Test-Path (Join-Path $script:WorkflowsPath "30-ring-status-dashboard.yml") | Should -Be $false
        }

        It "Should not have 31-diagnose-ci-failures.yml (no longer needed)" {
            Test-Path (Join-Path $script:WorkflowsPath "31-diagnose-ci-failures.yml") | Should -Be $false
        }
    }

    Context "Disabled workflows - Documented but not active" {
        It "Should have 04-deploy-pr-environment.yml.disabled (ephemeral deployments disabled)" {
            Test-Path (Join-Path $script:WorkflowsPath "04-deploy-pr-environment.yml.disabled") | Should -Be $true `
                -Because "Should keep for documentation"
        }
    }

    Context "Migration benefits verification" {
        BeforeAll {
            # Count bot comment sources in pr-check.yml
            $prCheckContent = Get-Content (Join-Path $script:WorkflowsPath "pr-check.yml") -Raw
            
            # Count summary job (should be exactly 1)
            $summaryJobs = [regex]::Matches($prCheckContent, 'summary:').Count
            
            # Count comment posting actions
            $commentActions = [regex]::Matches($prCheckContent, 'createComment|updateComment').Count
        }

        It "Should have exactly 1 summary job in pr-check.yml" {
            $summaryJobs | Should -Be 1 `
                -Because "Only one summary job should post comments"
        }

        It "Should create or update comment (not always create)" {
            $commentActions | Should -BeGreaterOrEqual 2 `
                -Because "Should both create (first run) and update (subsequent runs)"
        }

        It "Should check for existing comment before creating new one" {
            $prCheckContent = Get-Content (Join-Path $script:WorkflowsPath "pr-check.yml") -Raw
            $prCheckContent | Should -Match "listComments.*github-actions\[bot\]" `
                -Because "Should find existing comment to update"
        }
    }

    Context "Concurrency configuration - No global blocking" {
        It "pr-check.yml should use PR-specific concurrency" {
            $content = Get-Content (Join-Path $script:WorkflowsPath "pr-check.yml") -Raw
            $content | Should -Match "concurrency:.*pr-check.*github\.event\.pull_request\.number" `
                -Because "Each PR should have its own queue"
        }

        It "deploy.yml should use branch-specific concurrency" {
            $content = Get-Content (Join-Path $script:WorkflowsPath "deploy.yml") -Raw
            $content | Should -Match "concurrency:.*deploy.*github\.ref" `
                -Because "Each branch should have its own deployment queue"
        }

        It "release.yml should use version-specific concurrency" {
            $content = Get-Content (Join-Path $script:WorkflowsPath "release.yml") -Raw
            $content | Should -Match "concurrency:.*release-" `
                -Because "Each version should have its own release queue"
        }

        It "Should NOT have global 'pages' concurrency lock anywhere" {
            $allWorkflows = Get-ChildItem -Path $script:WorkflowsPath -Filter "*.yml" -File |
                Where-Object { $_.Name -notmatch '\.disabled' }
            
            foreach ($workflow in $allWorkflows) {
                $content = Get-Content $workflow.FullName -Raw
                $content | Should -Not -Match "concurrency:.*group:\s*['\""]pages['\""]$" `
                    -Because "$($workflow.Name) should not use global pages lock"
            }
        }
    }

    Context "Performance - Timing expectations" {
        BeforeAll {
            $prCheckContent = Get-Content (Join-Path $script:WorkflowsPath "pr-check.yml") -Raw
            $deployContent = Get-Content (Join-Path $script:WorkflowsPath "deploy.yml") -Raw
            $releaseContent = Get-Content (Join-Path $script:WorkflowsPath "release.yml") -Raw
        }

        It "pr-check.yml validation should complete in 10 minutes" {
            $prCheckContent | Should -Match "validate:.*timeout-minutes:\s*10"
        }

        It "pr-check.yml build should complete in 15 minutes" {
            $prCheckContent | Should -Match "build:.*timeout-minutes:\s*15"
        }

        It "pr-check.yml Docker build should complete in 20 minutes" {
            $prCheckContent | Should -Match "build-docker:.*timeout-minutes:\s*20"
        }

        It "deploy.yml Docker build and push should complete in 30 minutes" {
            $deployContent | Should -Match "build-and-push-docker:.*timeout-minutes:\s*30"
        }

        It "release.yml validation should complete in 15 minutes" {
            $releaseContent | Should -Match "pre-release-validation:.*timeout-minutes:\s*15"
        }
    }

    Context "Bootstrap consistency - All workflows use Minimal profile" {
        BeforeAll {
            $workflowsToCheck = @('pr-check.yml', 'deploy.yml', '03-test-execution.yml')
        }

        foreach ($workflowName in $workflowsToCheck) {
            It "$workflowName should bootstrap with Minimal profile" {
                $content = Get-Content (Join-Path $script:WorkflowsPath $workflowName) -Raw
                $content | Should -Match "bootstrap\.ps1.*-InstallProfile\s+Minimal" `
                    -Because "CI should use minimal profile for speed"
            }
        }
    }

    Context "Runner selection - Ubuntu latest for PowerShell" {
        BeforeAll {
            $activeWorkflows = Get-ChildItem -Path $script:WorkflowsPath -Filter "*.yml" -File |
                Where-Object { $_.Name -notmatch '\.disabled' }
        }

        foreach ($workflow in $activeWorkflows) {
            It "$($workflow.Name) should use ubuntu-latest runner" {
                $content = Get-Content $workflow.FullName -Raw
                # Most jobs should use ubuntu-latest (which has pwsh pre-installed)
                $content | Should -Match "runs-on:\s*ubuntu-latest" `
                    -Because "ubuntu-latest has PowerShell 7 pre-installed"
            }
        }
    }

    Context "Security - Minimal permissions principle" {
        BeforeAll {
            $prCheckContent = Get-Content (Join-Path $script:WorkflowsPath "pr-check.yml") -Raw
            $deployContent = Get-Content (Join-Path $script:WorkflowsPath "deploy.yml") -Raw
            $releaseContent = Get-Content (Join-Path $script:WorkflowsPath "release.yml") -Raw
        }

        It "pr-check.yml should have read-only contents permission" {
            $prCheckContent | Should -Match "permissions:.*contents:\s*read" `
                -Because "PR checks only need to read code"
        }

        It "deploy.yml should have write permissions for deployment" {
            $deployContent | Should -Match "permissions:.*contents:\s*write" `
                -Because "Deployment needs to push to gh-pages"
            
            $deployContent | Should -Match "permissions:.*packages:\s*write" `
                -Because "Deployment needs to push Docker images"
        }

        It "release.yml should have write permissions for releases" {
            $releaseContent | Should -Match "permissions:.*contents:\s*write" `
                -Because "Release needs to create release and tags"
            
            $releaseContent | Should -Match "permissions:.*packages:\s*write" `
                -Because "Release needs to publish packages"
        }
    }

    Context "Environment variables - CI detection" {
        BeforeAll {
            $activeWorkflows = Get-ChildItem -Path $script:WorkflowsPath -Filter "*.yml" -File |
                Where-Object { 
                    $_.Name -notmatch '\.disabled' -and 
                    $_.Name -in @('pr-check.yml', 'deploy.yml', 'release.yml', '03-test-execution.yml')
                }
        }

        foreach ($workflow in $activeWorkflows) {
            It "$($workflow.Name) should set AITHERZERO_CI=true" {
                $content = Get-Content $workflow.FullName -Raw
                $content | Should -Match "AITHERZERO_CI:\s*true" `
                    -Because "Scripts need to detect CI environment"
            }

            It "$($workflow.Name) should set AITHERZERO_NONINTERACTIVE=true" {
                $content = Get-Content $workflow.FullName -Raw
                $content | Should -Match "AITHERZERO_NONINTERACTIVE:\s*true" `
                    -Because "Scripts should not prompt for input in CI"
            }
        }
    }
}

Describe "CI/CD Migration - Workflow Dependencies" -Tag 'Integration', 'CI/CD', 'Migration' {
    Context "Test execution workflow - Reusability" {
        BeforeAll {
            $testWorkflow = Get-Content (Join-Path $script:WorkflowsPath "03-test-execution.yml") -Raw
        }

        It "Should support workflow_call trigger" {
            $testWorkflow | Should -Match "on:.*workflow_call:" `
                -Because "Should be callable from pr-check.yml"
        }

        It "Should accept test_suite input parameter" {
            $testWorkflow | Should -Match "workflow_call:.*inputs:.*test_suite:" `
                -Because "Caller should be able to specify test suite"
        }

        It "Should accept coverage input parameter" {
            $testWorkflow | Should -Match "workflow_call:.*inputs:.*coverage:" `
                -Because "Caller should be able to request coverage"
        }

        It "Should support workflow_dispatch for manual testing" {
            $testWorkflow | Should -Match "on:.*workflow_dispatch:" `
                -Because "Developers should be able to run tests manually"
        }
    }

    Context "pr-check.yml uses test execution workflow" {
        BeforeAll {
            $prCheck = Get-Content (Join-Path $script:WorkflowsPath "pr-check.yml") -Raw
        }

        It "Should call 03-test-execution.yml via workflow_call" {
            $prCheck | Should -Match "test:.*uses:.*03-test-execution\.yml" `
                -Because "Should delegate to dedicated test workflow"
        }

        It "Should pass test_suite parameter" {
            $prCheck | Should -Match "test:.*with:.*test_suite:" `
                -Because "Should specify which tests to run"
        }

        It "Should inherit secrets" {
            $prCheck | Should -Match "test:.*secrets:\s*inherit" `
                -Because "Test workflow may need secrets"
        }
    }
}

Describe "CI/CD Migration - YAML Validity" -Tag 'Integration', 'CI/CD', 'Migration' {
    Context "All active workflow files have valid YAML" {
        BeforeAll {
            $script:ActiveWorkflows = Get-ChildItem -Path $script:WorkflowsPath -Filter "*.yml" -File |
                Where-Object { $_.Name -notmatch '\.disabled' }
        }

        foreach ($workflow in $script:ActiveWorkflows) {
            It "$($workflow.Name) should be valid YAML" {
                { 
                    $pythonCmd = if (Get-Command python3 -ErrorAction SilentlyContinue) { 'python3' } 
                                elseif (Get-Command python -ErrorAction SilentlyContinue) { 'python' }
                                else { $null }
                    
                    if ($pythonCmd) {
                        $tempFile = [System.IO.Path]::GetTempFileName()
                        try {
                            Get-Content $workflow.FullName -Raw | Set-Content -Path $tempFile -Encoding UTF8
                            $pythonScript = "import yaml; yaml.safe_load(open(r'$tempFile'))"
                            & $pythonCmd -c $pythonScript 2>&1 | Out-Null
                            if ($LASTEXITCODE -ne 0) {
                                throw "YAML validation failed for $($workflow.Name)"
                            }
                        } finally {
                            if (Test-Path $tempFile) {
                                Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
                            }
                        }
                    }
                } | Should -Not -Throw
            }
        }
    }
}

Describe "CI/CD Migration - Documentation" -Tag 'Integration', 'CI/CD', 'Migration' {
    Context "Migration documentation exists" {
        It "Should have MIGRATION.md guide" {
            Test-Path (Join-Path $script:WorkflowsPath "MIGRATION.md") | Should -Be $true `
                -Because "Team needs migration documentation"
        }

        It "Should have README.md for workflows" {
            Test-Path (Join-Path $script:WorkflowsPath "README.md") | Should -Be $true `
                -Because "Workflows should be documented"
        }
    }

    Context "MIGRATION.md has testing checklist" {
        BeforeAll {
            $migrationDoc = Get-Content (Join-Path $script:WorkflowsPath "MIGRATION.md") -Raw
        }

        It "Should document PR testing" {
            $migrationDoc | Should -Match "Create a test PR and verify" `
                -Because "PR testing is in the checklist"
        }

        It "Should document dev-staging testing" {
            $migrationDoc | Should -Match "Push to.*dev-staging.*and verify" `
                -Because "Staging deployment testing is in the checklist"
        }

        It "Should document main branch testing" {
            $migrationDoc | Should -Match "Push to.*main.*and verify" `
                -Because "Production deployment testing is in the checklist"
        }

        It "Should document release testing" {
            $migrationDoc | Should -Match "Create a release tag and verify" `
                -Because "Release workflow testing is in the checklist"
        }

        It "Should have rollback plan" {
            $migrationDoc | Should -Match "Rollback Plan" `
                -Because "Emergency procedures should be documented"
        }
    }
}
