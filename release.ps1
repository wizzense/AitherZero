#Requires -Version 5.1

<#
.SYNOPSIS
    Dead simple release script - just tag and push
.DESCRIPTION
    Updates VERSION, creates tag, pushes to trigger GitHub Actions release workflow
.PARAMETER Version
    Version to release (e.g., 1.2.3)
.PARAMETER Message
    Release message/description
.PARAMETER DryRun
    Preview what would happen without making changes
.EXAMPLE
    ./release.ps1 -Version 1.2.3 -Message "Bug fixes"
.EXAMPLE
    ./release.ps1 -Version 2.0.0 -Message "Major release" -DryRun
.EXAMPLE
    # Auto-increment version:
    ./release.ps1 -Type patch -Message "Bug fixes"
#>

param(
    [Parameter(Mandatory, ParameterSetName = 'Explicit')]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,

    [Parameter(Mandatory, ParameterSetName = 'Auto')]
    [ValidateSet('patch', 'minor', 'major')]
    [string]$Type,

    [Parameter(Mandatory)]
    [Alias('Description')]
    [string]$Message,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# Get current version for auto-increment
if ($Type) {
    $versionFile = Join-Path $PSScriptRoot "VERSION"
    $currentVersion = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { "0.0.0" }
    $parts = $currentVersion -split '\.'

    switch ($Type) {
        'patch' {
            $parts[2] = [int]$parts[2] + 1
        }
        'minor' {
            $parts[1] = [int]$parts[1] + 1
            $parts[2] = "0"
        }
        'major' {
            $parts[0] = [int]$parts[0] + 1
            $parts[1] = "0"
            $parts[2] = "0"
        }
    }

    $Version = $parts -join '.'
}

Write-Host "`n🚀 AitherZero Simple Release" -ForegroundColor Magenta
Write-Host "============================" -ForegroundColor Magenta
Write-Host "Version: $Version" -ForegroundColor Cyan
Write-Host "Message: $Message" -ForegroundColor Cyan
Write-Host ""

# Step 1: Verify we're on main branch
$currentBranch = git branch --show-current
if ($currentBranch -ne 'main') {
    Write-Warning "Not on main branch (current: $currentBranch)"
    $confirm = Read-Host "Switch to main branch? (y/N)"
    if ($confirm -eq 'y') {
        git checkout main
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to switch to main branch"
            exit 1
        }
    } else {
        Write-Error "Releases must be created from main branch"
        exit 1
    }
}

# Step 2: Pull latest changes
Write-Host "📥 Pulling latest changes..." -ForegroundColor Yellow
git pull origin main --ff-only
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to pull latest changes. Resolve conflicts and try again."
    exit 1
}

# Step 3: Check if tag already exists
$tagName = "v$Version"
$existingTag = git tag -l $tagName
if ($existingTag) {
    Write-Error "Tag $tagName already exists!"
    exit 1
}

# Step 4: Update VERSION file
$versionFile = Join-Path $PSScriptRoot "VERSION"
$currentVersion = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { "0.0.0" }

Write-Host "`n📝 Version Update" -ForegroundColor Yellow
Write-Host "  Current: $currentVersion"
Write-Host "  New:     $Version"

if ($DryRun) {
    Write-Host "`n🔍 DRY RUN - Would perform:" -ForegroundColor Yellow
    Write-Host "  1. Update VERSION file to: $Version"
    Write-Host "  2. Commit: 'Release v$Version - $Message'"
    Write-Host "  3. Create tag: $tagName"
    Write-Host "  4. Push commit and tag to origin"
    Write-Host "`nNo changes made." -ForegroundColor Green
    exit 0
}

# Step 5: Update VERSION file
Set-Content -Path $versionFile -Value $Version -NoNewline

# Step 6: Commit the change
Write-Host "`n📝 Committing version update..." -ForegroundColor Yellow
git add VERSION
git commit -m "Release v$Version - $Message"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to commit version update"
    exit 1
}

# Step 7: Create annotated tag
Write-Host "🏷️  Creating tag $tagName..." -ForegroundColor Yellow
git tag -a $tagName -m "Release v$Version`n`n$Message"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create tag"
    exit 1
}

# Step 8: Push commit and tag
Write-Host "`n📤 Pushing to origin..." -ForegroundColor Yellow
git push origin main
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to push commit"
    exit 1
}

git push origin $tagName
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to push tag"
    exit 1
}

# Success!
Write-Host "`n✅ Release v$Version created successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📊 Next steps:" -ForegroundColor Cyan
Write-Host "  • GitHub Actions will build packages automatically"
Write-Host "  • Monitor progress at: https://github.com/wizzense/AitherZero/actions"
Write-Host "  • Release will appear at: https://github.com/wizzense/AitherZero/releases/tag/$tagName"
Write-Host ""
