#Requires -Version 7.0

<#
.SYNOPSIS
    Integration test to validate the deploy.yml workflow migration
.DESCRIPTION
    This test verifies that the consolidated deploy.yml workflow correctly
    handles branch-specific deployments:
    - Docker image builds and pushes to ghcr.io
    - Staging deployments for dev-staging branch
    - Dashboard publishing for all branches
    - NO staging deployment for main branch
    
    Test Checklist Items:
    - "Push to dev-staging and verify"
    - "Push to main and verify"
#>

BeforeAll {
    $script:WorkflowFile = Join-Path $PSScriptRoot "../../.github/workflows/deploy.yml"
    $script:WorkflowsPath = Join-Path $PSScriptRoot "../../.github/workflows"
}

Describe "Deploy Workflow Migration" -Tag 'Integration', 'CI/CD', 'Migration' {
    BeforeAll {
        $script:Content = Get-Content -Path $script:WorkflowFile -Raw
    }

    Context "Workflow file existence and structure" {
        It "Should have deploy.yml workflow file" {
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
            $script:Content | Should -Match "name:\s*.*Deploy.*Consolidated"
        }
    }

    Context "Workflow triggers - Push events" {
        It "Should trigger on push to main branch" {
            $script:Content | Should -Match "push:.*branches:.*- main" `
                -Because "Should deploy on main branch pushes"
        }

        It "Should trigger on push to dev-staging branch" {
            $script:Content | Should -Match "push:.*branches:.*- dev-staging" `
                -Because "Should deploy to staging on dev-staging pushes"
        }

        It "Should trigger on push to dev and develop branches" {
            $script:Content | Should -Match "push:.*branches:.*- dev" `
                -Because "Should deploy on development branch pushes"
        }
    }

    Context "Concurrency settings - Branch-specific, not global" {
        It "Should have branch-specific concurrency group" {
            $script:Content | Should -Match "concurrency:.*group:\s*deploy-.*github\.ref" `
                -Because "Each branch should have its own deployment queue"
        }

        It "Should cancel in-progress deployments for same branch" {
            $script:Content | Should -Match "cancel-in-progress:\s*true" `
                -Because "Old deployments should be cancelled when new commits arrive"
        }

        It "Should NOT use global pages lock" {
            $script:Content | Should -Not -Match "concurrency:.*group:\s*pages$" `
                -Because "Global lock causes branch blocking - use branch-specific instead"
        }
    }

    Context "Required jobs - Deployment pipeline" {
        It "Should have build-and-push-docker job" {
            $script:Content | Should -Match "build-and-push-docker:" `
                -Because "Should build and push Docker images"
        }

        It "Should have deploy-to-staging job" {
            $script:Content | Should -Match "deploy-to-staging:" `
                -Because "Should handle staging deployments"
        }

        It "Should have publish-dashboard job" {
            $script:Content | Should -Match "publish-dashboard:" `
                -Because "Should publish dashboards to GitHub Pages"
        }

        It "Should have summary job" {
            $script:Content | Should -Match "summary:" `
                -Because "Should provide deployment summary"
        }
    }

    Context "Docker build and push job" {
        It "Should login to GitHub Container Registry" {
            $script:Content | Should -Match "build-and-push-docker:.*docker/login-action@v3.*registry:.*ghcr\.io" `
                -Because "Should authenticate to ghcr.io"
        }

        It "Should use GITHUB_TOKEN for authentication" {
            $script:Content | Should -Match "build-and-push-docker:.*password:.*secrets\.GITHUB_TOKEN" `
                -Because "Should use built-in token"
        }

        It "Should build for multiple platforms" {
            $script:Content | Should -Match "build-and-push-docker:.*platforms:.*linux/amd64,linux/arm64" `
                -Because "Should support both x64 and ARM64"
        }

        It "Should push images to registry" {
            $script:Content | Should -Match "build-and-push-docker:.*push:\s*true" `
                -Because "Should publish images on deployment"
        }

        It "Should tag images with branch name" {
            $script:Content | Should -Match "build-and-push-docker:.*type=ref,event=branch" `
                -Because "Should tag with branch for easy identification"
        }

        It "Should tag images with commit SHA" {
            $script:Content | Should -Match "build-and-push-docker:.*type=sha,prefix=sha-" `
                -Because "Should enable deployment to specific commits"
        }

        It "Should use lowercase repository name" {
            $script:Content | Should -Match "build-and-push-docker:.*repo-lower.*tr \[:upper:\] \[:lower:\]" `
                -Because "Docker registry requires lowercase names"
        }

        It "Should output image tag and digest" {
            $script:Content | Should -Match "build-and-push-docker:.*outputs:.*image-tag.*image-digest" `
                -Because "Downstream jobs need image information"
        }
    }

    Context "Staging deployment - dev-staging branch only" {
        It "Should depend on Docker build job" {
            $script:Content | Should -Match "deploy-to-staging:.*needs:\s*build-and-push-docker" `
                -Because "Staging needs Docker image to be ready"
        }

        It "Should only run for dev-staging branch" {
            $script:Content | Should -Match "deploy-to-staging:.*if:.*github\.ref == 'refs/heads/dev-staging'" `
                -Because "Only dev-staging should deploy to staging environment"
        }

        It "Should use staging environment" {
            $script:Content | Should -Match "deploy-to-staging:.*environment:.*name:\s*staging" `
                -Because "Should use GitHub environment for tracking"
        }

        It "Should pull Docker image to verify" {
            $script:Content | Should -Match "deploy-to-staging:.*docker pull" `
                -Because "Should verify image exists and is pullable"
        }
    }

    Context "Dashboard publishing - All branches" {
        It "Should depend on Docker build job" {
            $script:Content | Should -Match "publish-dashboard:.*needs:\s*build-and-push-docker" `
                -Because "Dashboard generation may need successful build"
        }

        It "Should generate branch-specific dashboard" {
            $script:Content | Should -Match "publish-dashboard:.*github\.ref_name" `
                -Because "Each branch should have its own dashboard"
        }

        It "Should use dashboard generation script" {
            $script:Content | Should -Match "publish-dashboard:.*0523_Generate-Dashboard\.ps1" `
                -Because "Should use existing dashboard script"
        }

        It "Should generate ring status for ring branches" {
            $script:Content | Should -Match "publish-dashboard:.*ring-.*0531_Generate-RingStatus\.ps1" `
                -Because "Ring branches need ring status dashboard"
        }

        It "Should deploy to GitHub Pages with peaceiris action" {
            $script:Content | Should -Match "publish-dashboard:.*peaceiris/actions-gh-pages@v3" `
                -Because "Should use standard Pages deployment action"
        }

        It "Should publish to branch-specific directory" {
            $script:Content | Should -Match "publish-dashboard:.*destination_dir:.*github\.ref_name" `
                -Because "Each branch should publish to its own path"
        }

        It "Should enable Jekyll for Pages" {
            $script:Content | Should -Match "publish-dashboard:.*enable_jekyll:\s*true" `
                -Because "GitHub Pages uses Jekyll"
        }

        It "Should keep existing files from other branches" {
            $script:Content | Should -Match "publish-dashboard:.*keep_files:\s*true" `
                -Because "Should not delete other branches' dashboards"
        }
    }

    Context "Main branch - No staging deployment" {
        It "Should NOT deploy to staging when ref is main" {
            # Verify staging job has conditional that excludes main
            $script:Content | Should -Match "deploy-to-staging:.*if:.*github\.ref == 'refs/heads/dev-staging'" `
                -Because "Main branch should NOT trigger staging deployment"
        }

        It "Should build Docker image for main" {
            # build-and-push-docker should run for all branches including main
            $script:Content | Should -Match "build-and-push-docker:" `
                -Because "Main should still build Docker images"
        }

        It "Should publish dashboard for main" {
            # publish-dashboard should run for all branches including main
            $script:Content | Should -Match "publish-dashboard:" `
                -Because "Main should still publish dashboard"
        }
    }

    Context "Permissions - Required for deployment" {
        It "Should have write permissions for contents" {
            $script:Content | Should -Match "permissions:.*contents:\s*write" `
                -Because "Needs to push to gh-pages branch"
        }

        It "Should have write permissions for packages" {
            $script:Content | Should -Match "permissions:.*packages:\s*write" `
                -Because "Needs to push Docker images to ghcr.io"
        }

        It "Should have write permissions for pages" {
            $script:Content | Should -Match "permissions:.*pages:\s*write" `
                -Because "Needs to deploy to GitHub Pages"
        }

        It "Should have id-token write for OIDC" {
            $script:Content | Should -Match "permissions:.*id-token:\s*write" `
                -Because "May need OIDC for deployments"
        }

        It "Should have write permissions for deployments" {
            $script:Content | Should -Match "permissions:.*deployments:\s*write" `
                -Because "Needs to create deployment records"
        }
    }

    Context "Environment variables - Deployment configuration" {
        It "Should set container registry to ghcr.io" {
            $script:Content | Should -Match "env:.*CONTAINER_REGISTRY:\s*ghcr\.io" `
                -Because "Should use GitHub Container Registry"
        }

        It "Should set CI environment variables" {
            $script:Content | Should -Match "env:.*AITHERZERO_CI:\s*true" `
                -Because "Scripts should detect CI environment"
        }
    }

    Context "Summary job - Deployment status" {
        It "Should depend on all deployment jobs" {
            $script:Content | Should -Match "summary:.*needs:.*build-and-push-docker.*deploy-to-staging.*publish-dashboard" `
                -Because "Summary should wait for all deployments"
        }

        It "Should always run (even on failures)" {
            $script:Content | Should -Match "summary:.*if:\s*always\(\)" `
                -Because "Summary should always be generated"
        }

        It "Should include Docker image information" {
            $script:Content | Should -Match "summary:.*Docker Image.*image-tag" `
                -Because "Summary should show deployed image"
        }

        It "Should include staging deployment status" {
            $script:Content | Should -Match "summary:.*Staging.*deploy-to-staging\.result" `
                -Because "Summary should show staging status"
        }

        It "Should include dashboard publish status" {
            $script:Content | Should -Match "summary:.*Dashboard.*publish-dashboard\.result" `
                -Because "Summary should show dashboard status"
        }

        It "Should include dashboard URL" {
            $script:Content | Should -Match "summary:.*github\.io.*github\.ref_name" `
                -Because "Summary should link to published dashboard"
        }
    }

    Context "Performance expectations" {
        It "Should have reasonable timeouts for all jobs" {
            # Docker build: 30 minutes (multi-platform build)
            $script:Content | Should -Match "build-and-push-docker:.*timeout-minutes:\s*30"
            
            # Staging deploy: 15 minutes
            $script:Content | Should -Match "deploy-to-staging:.*timeout-minutes:\s*15"
            
            # Dashboard: 15 minutes
            $script:Content | Should -Match "publish-dashboard:.*timeout-minutes:\s*15"
            
            # Summary: 5 minutes
            $script:Content | Should -Match "summary:.*timeout-minutes:\s*5"
        }
    }

    Context "Ephemeral PR environments - Removed" {
        It "Should not have PR environment deployment workflow enabled" {
            Test-Path (Join-Path $script:WorkflowsPath "04-deploy-pr-environment.yml") | Should -Be $false `
                -Because "Ephemeral deployments are useless without external access"
        }

        It "Should have disabled workflow file as documentation" {
            Test-Path (Join-Path $script:WorkflowsPath "04-deploy-pr-environment.yml.disabled") | Should -Be $true `
                -Because "Should keep for reference"
        }
    }
}

Describe "Deploy Workflow - Concurrency Configuration" -Tag 'Integration', 'CI/CD', 'Migration' {
    Context "No global blocking - Branch-specific queues" {
        BeforeAll {
            $script:Content = Get-Content -Path $script:WorkflowFile -Raw
        }

        It "Should use github.ref in concurrency group" {
            $script:Content | Should -Match "concurrency:.*deploy-.*\$\{\{\s*github\.ref\s*\}\}" `
                -Because "Each branch gets its own deployment queue"
        }

        It "Should NOT block other branches" {
            # Negative test - should not have global concurrency lock
            $script:Content | Should -Not -Match "concurrency:.*group:\s*['\"](pages|deploy)['\"]$" `
                -Because "Global lock would block all branches"
        }

        It "Should allow parallel deployments to different branches" {
            # Test scenario: dev-staging and main can deploy simultaneously
            # This is enforced by the concurrency group including github.ref
            $script:Content | Should -Match "deploy-.*\$\{\{\s*github\.ref\s*\}\}" `
                -Because "Different refs create different concurrency groups"
        }
    }
}

Describe "Deploy Workflow - Dashboard Publishing Configuration" -Tag 'Integration', 'CI/CD', 'Migration' {
    Context "GitHub Pages deployment settings" {
        BeforeAll {
            $script:Content = Get-Content -Path $script:WorkflowFile -Raw
        }

        It "Should publish to branch-specific subdirectory" {
            $script:Content | Should -Match "destination_dir:.*\$\{\{\s*github\.ref_name\s*\}\}" `
                -Because "Each branch should have isolated dashboard path"
        }

        It "Should construct dashboard URL correctly" {
            # URL pattern: https://owner.github.io/repo/branch-name/
            $script:Content | Should -Match "github\.io.*github\.event\.repository\.name.*github\.ref_name" `
                -Because "Dashboard URL should be accessible and predictable"
        }

        It "Should preserve files from other branches" {
            $script:Content | Should -Match "keep_files:\s*true" `
                -Because "Multiple branches publish to same gh-pages branch"
        }
    }
}
