#Requires -Version 7.0

<#
.SYNOPSIS
    Generate comprehensive build metadata for PR and releases
.DESCRIPTION
    Creates detailed build-info.json with PR context, git info, environment details
.PARAMETER OutputPath
    Path where build-info.json will be saved
.PARAMETER IncludePRInfo
    Include PR-specific information (number, title, author, branches)
.PARAMETER IncludeGitInfo
    Include git commit information and history
.PARAMETER IncludeEnvironmentInfo
    Include CI/CD environment details
.EXAMPLE
    ./0515_Generate-BuildMetadata.ps1 -OutputPath ./build-info.json -IncludePRInfo
.NOTES
    Stage: Reporting
    Category: Build
    Order: 0515
    Tags: metadata, build, pr, release
#>

[CmdletBinding()]
param(
    [string]$OutputPath = "library/reports/build-metadata.json",
    [switch]$IncludePRInfo,
    [switch]$IncludeGitInfo,
    [switch]$IncludeEnvironmentInfo
)

$ErrorActionPreference = 'Stop'

# Import utilities
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module (Join-Path $ProjectRoot "aithercore/automation/ScriptUtilities.psm1") -Force -ErrorAction SilentlyContinue

$buildInfo = @{
    generated_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    version = "1.0.0"
}

# PR Information
if ($IncludePRInfo -and $env:PR_NUMBER) {
    $buildInfo.pr = @{
        number = [int]$env:PR_NUMBER
        title = $env:PR_TITLE
        author = $env:GITHUB_ACTOR
        base_branch = $env:GITHUB_BASE_REF
        head_branch = $env:GITHUB_HEAD_REF
        base_sha = $env:GITHUB_BASE_SHA
        head_sha = $env:GITHUB_SHA
        url = "https://github.com/$env:GITHUB_REPOSITORY/pull/$env:PR_NUMBER"
    }
}

# Git Information
if ($IncludeGitInfo) {
    try {
        $buildInfo.git = @{
            commit_sha = if ($env:GITHUB_SHA) { $env:GITHUB_SHA } else { git rev-parse HEAD }
            commit_short = if ($env:GITHUB_SHA) { $env:GITHUB_SHA.Substring(0,8) } else { git rev-parse --short HEAD }
            commit_message = git log -1 --pretty=%B
            commit_author = git log -1 --pretty=%an
            commit_date = git log -1 --pretty=%cI
            branch = git rev-parse --abbrev-ref HEAD
            tag = git describe --tags --exact-match 2>$null
            commits_count = git rev-list --count HEAD
        }
    } catch {
        Write-Warning "Could not retrieve git information: $_"
    }
}

# Environment Information
if ($IncludeEnvironmentInfo) {
    $buildInfo.environment = @{
        ci = ($env:CI -eq 'true')
        platform = if ($env:GITHUB_ACTIONS) { 'GitHub Actions' } else { 'Local' }
        runner_os = $env:RUNNER_OS
        workflow = $env:GITHUB_WORKFLOW
        run_id = $env:GITHUB_RUN_ID
        run_number = $env:GITHUB_RUN_NUMBER
        job = $env:GITHUB_JOB
        powershell_version = $PSVersionTable.PSVersion.ToString()
        os = $PSVersionTable.OS
    }
}

# Artifacts
$buildInfo.artifacts = @{
    container_image_base = "ghcr.io/$($env:GITHUB_REPOSITORY)".ToLower()
}

# Add PR container tags only if we have the required variables
if ($env:PR_NUMBER -and $env:GITHUB_SHA) {
    $buildInfo.artifacts.pr_container_tags = @(
        "pr-$($env:PR_NUMBER)-$($env:GITHUB_SHA.Substring(0,8))",
        "pr-$($env:PR_NUMBER)-latest"
    )
    $buildInfo.artifacts.package_prefix = "AitherZero-PR$($env:PR_NUMBER)"
} elseif ($env:PR_NUMBER) {
    # Fallback to git rev-parse if GITHUB_SHA not available
    try {
        $shortSha = git rev-parse --short HEAD
        $buildInfo.artifacts.pr_container_tags = @(
            "pr-$($env:PR_NUMBER)-$shortSha",
            "pr-$($env:PR_NUMBER)-latest"
        )
        $buildInfo.artifacts.package_prefix = "AitherZero-PR$($env:PR_NUMBER)"
    } catch {
        Write-Warning "Could not generate PR container tags: $_"
    }
}

# GitHub Pages
$repoName = ($env:GITHUB_REPOSITORY -split '/')[-1]
$owner = ($env:GITHUB_REPOSITORY -split '/')[0]
$buildInfo.pages = @{
    base_url = "https://$owner.github.io/$repoName"
    pr_dashboard = "https://$owner.github.io/$repoName/pr-$($env:PR_NUMBER)/"
    pr_reports = "https://$owner.github.io/$repoName/pr-$($env:PR_NUMBER)/reports/"
}

# Ensure output directory exists
$outputDir = Split-Path $OutputPath -Parent
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Write metadata
$buildInfo | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8

Write-Host "✅ Build metadata generated: $OutputPath" -ForegroundColor Green
Write-Host "   PR: #$($env:PR_NUMBER)" -ForegroundColor Cyan
Write-Host "   Commit: $($buildInfo.git.commit_short)" -ForegroundColor Cyan
Write-Host "   Dashboard: $($buildInfo.pages.pr_dashboard)" -ForegroundColor Cyan
