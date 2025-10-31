#Requires -Version 7.0

<#
.SYNOPSIS
    Set up Git environment with best practices
.DESCRIPTION
    Configures Git with recommended settings, aliases, and hooks for the project.
.NOTES
    Stage: Development
    Category: Git
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$UserName,
    [string]$UserEmail,
    [switch]$Global
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import development modules
$devModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/development"
Import-Module (Join-Path $devModulePath "GitAutomation.psm1") -Force

Write-Host "Configuring Git environment..." -ForegroundColor Cyan

# Set user info if provided
if ($UserName) {
    if ($PSCmdlet.ShouldProcess("Git configuration", "Set user name to $UserName")) {
        Set-GitConfiguration -Key "user.name" -Value $UserName -Level $(if ($Global) { 'Global' } else { 'Local' })
        Write-Host "✓ Set user name: $UserName" -ForegroundColor Green
    }
}

if ($UserEmail) {
    if ($PSCmdlet.ShouldProcess("Git configuration", "Set user email to $UserEmail")) {
        Set-GitConfiguration -Key "user.email" -Value $UserEmail -Level $(if ($Global) { 'Global' } else { 'Local' })
        Write-Host "✓ Set user email: $UserEmail" -ForegroundColor Green
    }
}

# Set recommended configurations
$configs = @{
    # Core settings
    "core.autocrlf" = if ($IsWindows) { "true" } else { "input" }
    "core.filemode" = "false"
    "core.ignorecase" = "false"

    # Pull settings
    "pull.rebase" = "true"
    "pull.ff" = "only"

    # Push settings
    "push.default" = "current"
    "push.autoSetupRemote" = "true"

    # Merge settings
    "merge.ff" = "false"
    "merge.commit" = "no"

    # Rebase settings
    "rebase.autoStash" = "true"
    "rebase.autoSquash" = "true"

    # Diff settings
    "diff.colorMoved" = "default"
    "diff.algorithm" = "histogram"
}

if ($PSCmdlet.ShouldProcess("Git configuration", "Apply recommended Git configurations")) {
    foreach ($key in $configs.Keys) {
        Set-GitConfiguration -Key $key -Value $configs[$key] -Level $(if ($Global) { 'Global' } else { 'Local' })
    }
    Write-Host "✓ Applied recommended Git configurations" -ForegroundColor Green
}

# Create useful aliases
$aliases = @{
    # Status and log
    "st" = "status -sb"
    "lg" = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
    "last" = "log -1 HEAD --stat"

    # Branching
    "co" = "checkout"
    "br" = "branch"
    "brd" = "branch -d"

    # Committing
    "cm" = "commit -m"
    "ca" = "commit --amend"
    "unstage" = "reset HEAD --"

    # Diffs
    "df" = "diff"
    "dfs" = "diff --staged"

    # Remote
    "pl" = "pull --rebase"
    "ps" = "push"
    "psf" = "push --force-with-lease"
}

if ($PSCmdlet.ShouldProcess("Git configuration", "Create Git aliases")) {
    foreach ($alias in $aliases.Keys) {
        Set-GitConfiguration -Key "alias.$alias" -Value $aliases[$alias] -Level $(if ($Global) { 'Global' } else { 'Local' })
    }
    Write-Host "✓ Created Git aliases" -ForegroundColor Green
}

# Set up commit template
$templatePath = Join-Path (Split-Path $PSScriptRoot -Parent) ".gitmessage"
$templateContent = @'
# <type>(<scope>): <subject>

# <body>

# <footer>

# Type: feat, fix, docs, style, refactor, test, chore, perf, ci, build, revert
# Scope: optional, e.g., core, ui, api
# Subject: imperative mood, no period, max 50 chars
# Body: explain what and why, not how
# Footer: breaking changes, issue references
'@

if ($PSCmdlet.ShouldProcess($templatePath, "Create commit message template")) {
    $templateContent | Set-Content $templatePath
    Set-GitConfiguration -Key "commit.template" -Value $templatePath -Level 'Local'
    Write-Host "✓ Set up commit message template" -ForegroundColor Green
}

# Create .gitignore if not exists
$gitignorePath = Join-Path (Split-Path $PSScriptRoot -Parent) ".gitignore"
if (-not (Test-Path $gitignorePath)) {
    if ($PSCmdlet.ShouldProcess($gitignorePath, "Create .gitignore file")) {
        $gitignoreContent = @'
# Logs
*.log
logs/

# Test results
test-results/
coverage/
*.trx

# Build outputs
bin/
obj/
out/

# Dependencies
node_modules/
packages/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Temporary
*.tmp
*.temp
.cache/

# Secrets
*.key
*.pem
.env
secrets/
'@
        $gitignoreContent | Set-Content $gitignorePath
        Write-Host "✓ Created .gitignore file" -ForegroundColor Green
    }
}

# Set up pre-commit hook
$hooksPath = Join-Path (Split-Path $PSScriptRoot -Parent) ".git/hooks"
if (Test-Path $hooksPath) {
    $preCommitPath = Join-Path $hooksPath "pre-commit"
    $preCommitContent = @'
#!/usr/bin/env pwsh
# Pre-commit hook for AitherZero

# Run tests
Write-Host "Running pre-commit checks..." -ForegroundColor Yellow

# Check for large files
$largeFiles = git diff --cached --name-only | ForEach-Object {
    $file = $_
    if (Test-Path $file) {
        $size = (Get-Item $file).Length
        if ($size -gt 10MB) {
            @{ File = $file; SizeMB = [math]::Round($size / 1MB, 2) }
        }
    }
}

if ($largeFiles) {
    Write-Host "Large files detected:" -ForegroundColor Red
    $largeFiles | ForEach-Object { Write-Host "  $($_.File) ($($_.SizeMB) MB)" }
    exit 1
}

# Run PSScriptAnalyzer on staged PowerShell files
$psFiles = git diff --cached --name-only --diff-filter=ACM | Where-Object { $_ -match '\.ps[m1]?$' }
if ($psFiles) {
    Write-Host "Running PSScriptAnalyzer..." -ForegroundColor Yellow
    foreach ($file in $psFiles) {
        $issues = Invoke-ScriptAnalyzer -Path $file -Severity Error
        if ($issues) {
            Write-Host "PSScriptAnalyzer found errors in $file :" -ForegroundColor Red
            $issues | Format-Table -AutoSize
            exit 1
        }
    }
}

Write-Host "Pre-commit checks passed!" -ForegroundColor Green
exit 0
'@
    if ($PSCmdlet.ShouldProcess($preCommitPath, "Create pre-commit hook")) {
        $preCommitContent | Set-Content $preCommitPath
        if (-not $IsWindows) {
            chmod +x $preCommitPath
        }
        Write-Host "✓ Set up pre-commit hook" -ForegroundColor Green
    }
}

# Display current Git status
Write-Host "`nCurrent Git configuration:" -ForegroundColor Yellow
$repo = Get-GitRepository
Write-Host "  Repository: $($repo.Path)"
Write-Host "  Branch: $($repo.Branch)"
Write-Host "  Remote: $($repo.RemoteUrl)"

if ($repo.Status) {
    Write-Host "`nUncommitted changes:" -ForegroundColor Yellow
    $repo.Status | ForEach-Object { Write-Host "  $_" }
}

Write-Host "`nGit environment setup complete!" -ForegroundColor Green
Write-Host "Use 'git lg' for pretty log, 'git st' for status" -ForegroundColor Cyan