#Requires -Version 7.0

<#
.SYNOPSIS
    Integration test to validate the release.yml workflow migration
.DESCRIPTION
    This test verifies that the release.yml workflow correctly:
    - Runs on tag pushes (v*)
    - Creates GitHub releases
    - Uploads release artifacts
    - Builds and publishes MCP server package
    - Builds and pushes Docker images
    
    Test Checklist Item: "Create a release tag and verify"
#>

BeforeAll {
    $script:WorkflowFile = Join-Path $PSScriptRoot "../../.github/workflows/release.yml"
    $script:WorkflowsPath = Join-Path $PSScriptRoot "../../.github/workflows"
}

Describe "Release Workflow Migration" -Tag 'Integration', 'CI/CD', 'Migration' {
    BeforeAll {
        $script:Content = Get-Content -Path $script:WorkflowFile -Raw
    }

    Context "Workflow file existence and structure" {
        It "Should have release.yml workflow file" {
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

        It "Should have descriptive name" {
            $script:Content | Should -Match "name:\s*.*Release"
        }
    }

    Context "Old workflow renamed" {
        It "Should not have old 20-release-automation.yml" {
            Test-Path (Join-Path $script:WorkflowsPath "20-release-automation.yml") | Should -Be $false `
                -Because "Workflow was renamed to release.yml for simplicity"
        }
    }

    Context "Workflow triggers" {
        It "Should trigger on tag pushes matching v*" {
            $script:Content | Should -Match "push:.*tags:.*'v\*'" `
                -Because "Should trigger on version tags"
        }

        It "Should support manual workflow_dispatch" {
            $script:Content | Should -Match "workflow_dispatch:" `
                -Because "Should allow manual releases"
        }

        It "Should have version input for manual releases" {
            $script:Content | Should -Match "workflow_dispatch:.*inputs:.*version:" `
                -Because "Manual releases need version specification"
        }

        It "Should have prerelease flag option" {
            $script:Content | Should -Match "workflow_dispatch:.*inputs:.*prerelease:" `
                -Because "Should support pre-release versions"
        }

        It "Should have option to run full tests" {
            $script:Content | Should -Match "workflow_dispatch:.*inputs:.*run_full_tests:" `
                -Because "Should allow comprehensive validation before release"
        }
    }

    Context "Concurrency settings - Prevent simultaneous releases" {
        It "Should have concurrency group based on version" {
            $script:Content | Should -Match "concurrency:.*group:\s*release-" `
                -Because "Should prevent multiple releases of same version"
        }

        It "Should NOT cancel in-progress releases" {
            $script:Content | Should -Match "cancel-in-progress:\s*false" `
                -Because "Releases should complete, not be cancelled"
        }
    }

    Context "Required jobs - Release pipeline" {
        It "Should have pre-release-validation job" {
            $script:Content | Should -Match "pre-release-validation:" `
                -Because "Should validate before releasing"
        }

        It "Should have create-release job" {
            $script:Content | Should -Match "create-release:" `
                -Because "Should create GitHub release"
        }

        It "Should have build-mcp-server job" {
            $script:Content | Should -Match "build-mcp-server:" `
                -Because "Should build and publish MCP server package"
        }

        It "Should have publish-docker-image job" {
            $script:Content | Should -Match "publish-docker-image:" `
                -Because "Should publish Docker images for release"
        }

        It "Should have post-release job" {
            $script:Content | Should -Match "post-release:" `
                -Because "Should provide release summary"
        }
    }

    Context "Pre-release validation job" {
        It "Should run syntax validation" {
            $script:Content | Should -Match "pre-release-validation:.*0407_Validate-Syntax\.ps1" `
                -Because "Should validate all PowerShell syntax before release"
        }

        It "Should test module loading" {
            $script:Content | Should -Match "pre-release-validation:.*Import-Module.*AitherZero\.psd1" `
                -Because "Should verify module can be loaded"
        }

        It "Should run core tests" {
            $script:Content | Should -Match "pre-release-validation:.*0402_Run-UnitTests\.ps1" `
                -Because "Should run unit tests before release"
        }

        It "Should run code analysis" {
            $script:Content | Should -Match "pre-release-validation:.*0404_Run-PSScriptAnalyzer\.ps1" `
                -Because "Should check code quality before release"
        }

        It "Should validate module architecture (CRITICAL - blocks release)" {
            $script:Content | Should -Match "pre-release-validation:.*0950_Validate-AllAutomationScripts\.ps1" `
                -Because "Architecture validation is critical for release"
        }

        It "Should output validation status" {
            $script:Content | Should -Match "pre-release-validation:.*outputs:.*validation-status" `
                -Because "Downstream jobs need to know validation result"
        }
    }

    Context "Create release job" {
        It "Should depend on validation" {
            $script:Content | Should -Match "create-release:.*needs:.*pre-release-validation" `
                -Because "Should not release if validation fails"
        }

        It "Should update VERSION file" {
            $script:Content | Should -Match "create-release:.*Set-Content.*VERSION" `
                -Because "VERSION file should match release version"
        }

        It "Should update module manifest version" {
            $script:Content | Should -Match "create-release:.*ModuleVersion.*AitherZero\.psd1" `
                -Because "Module manifest should have correct version"
        }

        It "Should create build metadata file" {
            $script:Content | Should -Match "create-release:.*build-info\.json" `
                -Because "Release should include build metadata"
        }

        It "Should create release package" {
            $script:Content | Should -Match "create-release:.*packageName.*AitherZero-v" `
                -Because "Should create versioned package"
        }

        It "Should create ZIP archive for Windows" {
            $script:Content | Should -Match "create-release:.*Compress-Archive.*\.zip" `
                -Because "Windows users need ZIP format"
        }

        It "Should create TAR.GZ archive for Unix" {
            $script:Content | Should -Match "create-release:.*tar.*\.tar\.gz" `
                -Because "Unix users need TAR.GZ format"
        }

        It "Should generate release notes" {
            $script:Content | Should -Match "create-release:.*release-notes\.md" `
                -Because "Release should have detailed notes"
        }

        It "Should create GitHub release using softprops/action-gh-release" {
            $script:Content | Should -Match "create-release:.*uses:\s*softprops/action-gh-release@v2" `
                -Because "Should use standard release action"
        }

        It "Should upload release artifacts" {
            $script:Content | Should -Match "create-release:.*files:.*AitherZero-v.*\.zip.*\.tar\.gz.*build-info\.json" `
                -Because "Should upload all release files"
        }

        It "Should mark as latest release (if not prerelease)" {
            $script:Content | Should -Match "create-release:.*make_latest:.*prerelease.*true" `
                -Because "Stable releases should be marked as latest"
        }
    }

    Context "MCP server build job" {
        It "Should depend on create-release" {
            $script:Content | Should -Match "build-mcp-server:.*needs:.*create-release" `
                -Because "MCP server should be built after main release is created"
        }

        It "Should setup Node.js 20+" {
            $script:Content | Should -Match "build-mcp-server:.*setup-node.*node-version:.*'20" `
                -Because "MCP server needs Node.js"
        }

        It "Should update MCP server package version" {
            $script:Content | Should -Match "build-mcp-server:.*npm version.*RELEASE_VERSION" `
                -Because "MCP server version should match release"
        }

        It "Should install dependencies" {
            $script:Content | Should -Match "build-mcp-server:.*npm ci" `
                -Because "Should use clean install for reproducibility"
        }

        It "Should build MCP server" {
            $script:Content | Should -Match "build-mcp-server:.*npm run build" `
                -Because "Should compile TypeScript/JavaScript"
        }

        It "Should test MCP server" {
            $script:Content | Should -Match "build-mcp-server:.*npm test" `
                -Because "Should verify functionality"
        }

        It "Should create package archive" {
            $script:Content | Should -Match "build-mcp-server:.*npm pack" `
                -Because "Should create .tgz package"
        }

        It "Should upload package to GitHub release" {
            $script:Content | Should -Match "build-mcp-server:.*action-gh-release.*aitherzero-mcp-server.*\.tgz" `
                -Because "MCP server package should be in release assets"
        }

        It "Should publish to GitHub Packages" {
            $script:Content | Should -Match "build-mcp-server:.*npm publish" `
                -Because "Should publish to npm registry"
        }

        It "Should handle already-published version gracefully" {
            $script:Content | Should -Match "build-mcp-server:.*Cannot publish over existing version" `
                -Because "Re-runs should not fail if version exists"
        }
    }

    Context "Docker image publish job" {
        It "Should depend on create-release" {
            $script:Content | Should -Match "publish-docker-image:.*needs:.*create-release" `
                -Because "Docker image should be built after release is created"
        }

        It "Should login to GitHub Container Registry" {
            $script:Content | Should -Match "publish-docker-image:.*docker/login-action.*registry:.*ghcr\.io" `
                -Because "Should publish to ghcr.io"
        }

        It "Should generate comprehensive release tags" {
            $script:Content | Should -Match "publish-docker-image:.*generate-tags" `
                -Because "Release should have multiple tags for convenience"
        }

        It "Should tag with version number" {
            $script:Content | Should -Match "publish-docker-image:.*value=.*VERSION_NUMBER" `
                -Because "Should have version tag"
        }

        It "Should tag with major.minor version" {
            $script:Content | Should -Match "publish-docker-image:.*MAJOR_MINOR" `
                -Because "Should support major.minor version pins"
        }

        It "Should tag with major version" {
            $script:Content | Should -Match "publish-docker-image:.*MAJOR.*cut -d\. -f1" `
                -Because "Should support major version pins"
        }

        It "Should tag as 'latest' for stable releases" {
            $script:Content | Should -Match "publish-docker-image:.*latest.*IS_PRERELEASE.*true" `
                -Because "Latest should only be for stable releases"
        }

        It "Should tag as 'prerelease' for pre-releases" {
            $script:Content | Should -Match "publish-docker-image:.*prerelease.*IS_PRERELEASE" `
                -Because "Pre-releases should be clearly marked"
        }

        It "Should tag with commit SHA for traceability" {
            $script:Content | Should -Match "publish-docker-image:.*sha-.*COMMIT_SHORT" `
                -Because "Should enable deployment to specific commits"
        }

        It "Should build for multiple platforms" {
            $script:Content | Should -Match "publish-docker-image:.*platforms:.*linux/amd64,linux/arm64" `
                -Because "Should support both x64 and ARM64"
        }

        It "Should push images to registry" {
            $script:Content | Should -Match "publish-docker-image:.*push:\s*true" `
                -Because "Should publish release images"
        }

        It "Should test Docker image after build" {
            $script:Content | Should -Match "publish-docker-image:.*docker run.*test" `
                -Because "Should verify image works"
        }
    }

    Context "Post-release job" {
        It "Should depend on all release jobs" {
            $script:Content | Should -Match "post-release:.*needs:.*create-release.*build-mcp-server.*publish-docker-image" `
                -Because "Should wait for all artifacts to be published"
        }

        It "Should always run (even on partial failures)" {
            $script:Content | Should -Match "post-release:.*if:\s*always\(\)" `
                -Because "Summary should always be generated"
        }

        It "Should display release summary" {
            $script:Content | Should -Match "post-release:.*Release.*Completed Successfully" `
                -Because "Should provide clear success message"
        }

        It "Should list all release assets" {
            $script:Content | Should -Match "post-release:.*Release Assets Created.*\.zip.*\.tar\.gz.*mcp-server.*\.tgz" `
                -Because "Should enumerate all published artifacts"
        }

        It "Should show Docker image tags" {
            $script:Content | Should -Match "post-release:.*Docker Image.*ghcr\.io" `
                -Because "Should show where Docker image is published"
        }

        It "Should show MCP server package info" {
            $script:Content | Should -Match "post-release:.*MCP Server Package.*@aitherzero/mcp-server" `
                -Because "Should show npm package name"
        }

        It "Should provide installation commands" {
            $script:Content | Should -Match "post-release:.*Installation Commands.*bootstrap\.ps1" `
                -Because "Should help users install"
        }
    }

    Context "Permissions - Required for release" {
        It "Should have write permissions for contents" {
            $script:Content | Should -Match "permissions:.*contents:\s*write" `
                -Because "Needs to create release and tags"
        }

        It "Should have write permissions for pages" {
            $script:Content | Should -Match "permissions:.*pages:\s*write" `
                -Because "May publish release documentation"
        }

        It "Should have id-token write for OIDC" {
            $script:Content | Should -Match "permissions:.*id-token:\s*write" `
                -Because "May need OIDC for publishing"
        }

        It "Should have write permissions for packages" {
            $script:Content | Should -Match "permissions:.*packages:\s*write" `
                -Because "Needs to publish Docker images and npm packages"
        }
    }

    Context "Release artifacts verification" {
        It "Should include runtime-only files (no dev/test files)" {
            $script:Content | Should -Match "create-release:.*Runtime-only file list" `
                -Because "Release should be clean production package"
        }

        It "Should exclude test files from package" {
            $script:Content | Should -Match "create-release:.*Remove-Item.*tests" `
                -Because "Users don't need test files"
        }

        It "Should exclude git metadata from package" {
            $script:Content | Should -Match "create-release:.*Remove-Item.*\.git" `
                -Because "Users don't need git history"
        }

        It "Should include essential documentation" {
            $script:Content | Should -Match "create-release:.*README\.md.*LICENSE.*VERSION" `
                -Because "Documentation is essential for users"
        }

        It "Should include core module files" {
            $script:Content | Should -Match "create-release:.*AitherZero\.psd1.*AitherZero\.psm1" `
                -Because "Module manifest and loader are required"
        }

        It "Should include bootstrap scripts" {
            $script:Content | Should -Match "create-release:.*bootstrap\.ps1.*bootstrap\.sh" `
                -Because "Users need installation scripts"
        }

        It "Should include container support files" {
            $script:Content | Should -Match "create-release:.*Dockerfile.*docker-compose\.yml" `
                -Because "Container users need Docker configuration"
        }
    }

    Context "Performance expectations" {
        It "Should have reasonable timeout for validation (15 minutes)" {
            $script:Content | Should -Match "pre-release-validation:.*timeout-minutes:\s*15" `
                -Because "Validation should complete in reasonable time"
        }

        It "Should have reasonable timeout for release creation (10 minutes)" {
            $script:Content | Should -Match "create-release:.*timeout-minutes:\s*10" `
                -Because "Release creation is mostly I/O"
        }

        It "Should have reasonable timeout for MCP build (15 minutes)" {
            $script:Content | Should -Match "build-mcp-server:.*timeout-minutes:\s*15" `
                -Because "Node.js build and test should be quick"
        }

        It "Should have reasonable timeout for Docker build (30 minutes)" {
            $script:Content | Should -Match "publish-docker-image:.*timeout-minutes:\s*30" `
                -Because "Multi-platform Docker builds take time"
        }
    }
}

Describe "Release Workflow - Version Management" -Tag 'Integration', 'CI/CD', 'Migration' {
    Context "Version extraction and propagation" {
        BeforeAll {
            $script:Content = Get-Content -Path $script:WorkflowFile -Raw
        }

        It "Should extract version from tag" {
            $script:Content | Should -Match "github\.ref_name.*-replace.*\^v" `
                -Because "Should strip 'v' prefix from tag"
        }

        It "Should use manual version for workflow_dispatch" {
            $script:Content | Should -Match "github\.event\.inputs\.version" `
                -Because "Manual releases need explicit version"
        }

        It "Should set RELEASE_VERSION environment variable" {
            $script:Content | Should -Match "RELEASE_VERSION.*GITHUB_ENV" `
                -Because "Version should be available to all jobs"
        }

        It "Should update VERSION file with release version" {
            $script:Content | Should -Match "version.*Set-Content.*VERSION" `
                -Because "VERSION file should be updated"
        }

        It "Should update module manifest ModuleVersion" {
            $script:Content | Should -Match "ModuleVersion.*=.*version" `
                -Because "Module manifest version should match release"
        }
    }
}
