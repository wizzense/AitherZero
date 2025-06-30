Import-Module ./aither-core/modules/PatchManager -Force

Invoke-PatchWorkflow -PatchDescription "Add Claude release commands to CLAUDE.md for easy build/release workflow" -PatchOperation {
    $content = Get-Content "CLAUDE.md" -Raw
    
    # Find the section after "Linting Commands" and before "GitHub Actions Workflows"
    $insertPoint = $content.IndexOf("### GitHub Actions Workflows")
    
    $releaseSection = @'

### Release Management Commands

```powershell
# Create a new release (automatically increments version)
Import-Module ./aither-core/modules/PatchManager -Force

# Patch release (1.2.3 -> 1.2.4)
Invoke-PatchWorkflow -PatchDescription "Release vX.X.X - [Brief description]" -PatchOperation {
    $version = Get-Content "VERSION" -Raw
    $parts = $version.Trim() -split '\.'
    $parts[2] = [int]$parts[2] + 1
    $newVersion = $parts -join '.'
    Set-Content "VERSION" -Value $newVersion -NoNewline
    Write-Host "Updated version to $newVersion"
} -CreatePR -Priority "High"

# Minor release (1.2.3 -> 1.3.0)
Invoke-PatchWorkflow -PatchDescription "Release vX.X.0 - [Feature description]" -PatchOperation {
    $version = Get-Content "VERSION" -Raw
    $parts = $version.Trim() -split '\.'
    $parts[1] = [int]$parts[1] + 1
    $parts[2] = "0"
    $newVersion = $parts -join '.'
    Set-Content "VERSION" -Value $newVersion -NoNewline
    Write-Host "Updated version to $newVersion"
} -CreatePR -Priority "High"

# Major release (1.2.3 -> 2.0.0)
Invoke-PatchWorkflow -PatchDescription "Release vX.0.0 - [Major change description]" -PatchOperation {
    $version = Get-Content "VERSION" -Raw
    $parts = $version.Trim() -split '\.'
    $parts[0] = [int]$parts[0] + 1
    $parts[1] = "0"
    $parts[2] = "0"
    $newVersion = $parts -join '.'
    Set-Content "VERSION" -Value $newVersion -NoNewline
    Write-Host "Updated version to $newVersion"
} -CreatePR -Priority "High"

# After PR is merged, tag and push the release
git checkout main
git pull
$version = Get-Content "VERSION" -Raw
git tag -a "v$($version.Trim())" -m "Release v$($version.Trim())"
git push origin "v$($version.Trim())"

# Monitor release build
gh run list --workflow="Build & Release Pipeline" --limit 1
gh run watch
```

### Quick Release Workflow

```powershell
# One-command release creation (example for patch release)
./scripts/Create-Release.ps1 -ReleaseType "patch" -Description "Bug fixes and improvements"

# Create release with specific version
./scripts/Create-Release.ps1 -Version "1.3.0" -Description "New features added"

# Emergency hotfix release
./scripts/Create-Release.ps1 -ReleaseType "hotfix" -Description "Critical bug fix" -FastTrack
```

### Build Testing Commands

```powershell
# Test build locally before release
./build/Build-Package.ps1 -Platform "windows" -Version "test" -ArtifactExtension "zip" -PackageProfile "standard"

# Test all profiles
@("minimal", "standard", "full") | ForEach-Object {
    ./build/Build-Package.ps1 -Platform "windows" -Version "test" -ArtifactExtension "zip" -PackageProfile $_
}

# Validate build output
./tests/Test-BuildOutput.ps1 -Platform "windows" -Profile "standard"
```

'@
    
    # Insert the new section
    $content = $content.Insert($insertPoint, $releaseSection)
    
    Set-Content "CLAUDE.md" -Value $content -NoNewline
    
    # Also create the Create-Release.ps1 helper script
    $releaseScript = @'
<#
.SYNOPSIS
    Simplified release creation for AitherZero
.PARAMETER ReleaseType
    Type of release: patch, minor, major, hotfix
.PARAMETER Version
    Specific version to release (overrides ReleaseType)
.PARAMETER Description
    Release description
.PARAMETER FastTrack
    Skip confirmation prompts
#>
param(
    [ValidateSet("patch", "minor", "major", "hotfix")]
    [string]$ReleaseType = "patch",
    
    [string]$Version,
    
    [Parameter(Mandatory)]
    [string]$Description,
    
    [switch]$FastTrack
)

# Import PatchManager
Import-Module (Join-Path $PSScriptRoot "../aither-core/modules/PatchManager") -Force

# Get current version
$currentVersion = Get-Content (Join-Path $PSScriptRoot "../VERSION") -Raw
$parts = $currentVersion.Trim() -split '\.'

# Calculate new version
if ($Version) {
    $newVersion = $Version
} else {
    switch ($ReleaseType) {
        "patch" {
            $parts[2] = [int]$parts[2] + 1
        }
        "minor" {
            $parts[1] = [int]$parts[1] + 1
            $parts[2] = "0"
        }
        "major" {
            $parts[0] = [int]$parts[0] + 1
            $parts[1] = "0"
            $parts[2] = "0"
        }
        "hotfix" {
            # For hotfix, increment patch but mark as critical
            $parts[2] = [int]$parts[2] + 1
        }
    }
    $newVersion = $parts -join '.'
}

Write-Host "Creating release: v$currentVersion → v$newVersion" -ForegroundColor Cyan
Write-Host "Description: $Description" -ForegroundColor Yellow

if (-not $FastTrack) {
    $confirm = Read-Host "Continue? (Y/N)"
    if ($confirm -ne 'Y') {
        Write-Host "Release cancelled" -ForegroundColor Red
        return
    }
}

# Create release using PatchManager
$priority = if ($ReleaseType -eq "hotfix") { "High" } else { "Medium" }

Invoke-PatchWorkflow -PatchDescription "Release v$newVersion - $Description" -PatchOperation {
    Set-Content (Join-Path $PSScriptRoot "../VERSION") -Value $newVersion -NoNewline
    Write-Host "Updated VERSION to $newVersion" -ForegroundColor Green
} -CreatePR -Priority $priority

Write-Host "`nRelease PR created!" -ForegroundColor Green
Write-Host "After merging, run:" -ForegroundColor Cyan
Write-Host "  git checkout main" -ForegroundColor White
Write-Host "  git pull" -ForegroundColor White
Write-Host "  git tag -a 'v$newVersion' -m 'Release v$newVersion - $Description'" -ForegroundColor White
Write-Host "  git push origin 'v$newVersion'" -ForegroundColor White
'@
    
    # Create the scripts directory if it doesn't exist
    if (-not (Test-Path "./scripts")) {
        New-Item -ItemType Directory -Path "./scripts" -Force | Out-Null
    }
    
    Set-Content (Join-Path $PSScriptRoot "scripts/Create-Release.ps1") -Value $releaseScript
    
} -CreatePR -Priority "Medium"