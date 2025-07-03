# AitherZero Release Automation Script
# This script handles the complete release process including PR creation and tagging

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('major', 'minor', 'patch')]
    [string]$ReleaseType,
    
    [Parameter(Mandatory = $true)]
    [string]$Description,
    
    [switch]$DryRun,
    [switch]$SkipPR,
    [switch]$AutoMerge
)

# Colors for output
$colors = @{
    Success = 'Green'
    Warning = 'Yellow'
    Error = 'Red'
    Info = 'Cyan'
    Step = 'Magenta'
}

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Type = 'Info'
    )
    Write-Host $Message -ForegroundColor $colors[$Type]
}

# Banner
Write-Host ""
Write-ColorOutput "AitherZero Release Automation" "Info"
Write-ColorOutput "=============================" "Info"
Write-Host ""

# Step 1: Validate prerequisites
Write-ColorOutput "[Step 1/7] Checking prerequisites..." "Step"

# Check git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-ColorOutput "ERROR: Git is not installed" "Error"
    exit 1
}

# Check gh CLI
$hasGH = Get-Command gh -ErrorAction SilentlyContinue
if (-not $hasGH -and -not $SkipPR) {
    Write-ColorOutput "WARNING: GitHub CLI (gh) not found. PR creation will be skipped." "Warning"
    $SkipPR = $true
}

# Check if we're in a git repository
$gitStatus = git status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "ERROR: Not in a git repository" "Error"
    exit 1
}

Write-ColorOutput "Prerequisites check passed" "Success"

# Step 2: Check for uncommitted changes
Write-ColorOutput "`n[Step 2/7] Checking repository status..." "Step"

$uncommittedChanges = git status --porcelain
if ($uncommittedChanges) {
    Write-ColorOutput "ERROR: You have uncommitted changes. Please commit or stash them first." "Error"
    Write-ColorOutput "Uncommitted files:" "Warning"
    $uncommittedChanges | ForEach-Object { Write-Host "  $_" }
    exit 1
}

# Get current branch
$currentBranch = git rev-parse --abbrev-ref HEAD
Write-ColorOutput "Current branch: $currentBranch" "Info"

# Ensure we're on main/master
# Check which branch exists
$null = git show-ref --verify --quiet refs/heads/main 2>$null
$hasMain = $LASTEXITCODE -eq 0
$null = git show-ref --verify --quiet refs/heads/master 2>$null
$hasMaster = $LASTEXITCODE -eq 0

$mainBranch = if ($hasMain) { "main" } elseif ($hasMaster) { "master" } else { "main" }
if ($currentBranch -ne $mainBranch) {
    Write-ColorOutput "Switching to $mainBranch branch..." "Info"
    git checkout $mainBranch 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "ERROR: Failed to switch to $mainBranch branch" "Error"
        exit 1
    }
    $currentBranch = $mainBranch
}

# Pull latest changes
Write-ColorOutput "Pulling latest changes..." "Info"
git pull origin $mainBranch
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "ERROR: Failed to pull latest changes" "Error"
    exit 1
}

Write-ColorOutput "Repository is up to date" "Success"

# Step 3: Read current version
Write-ColorOutput "`n[Step 3/7] Reading current version..." "Step"

$versionFile = "VERSION"
if (-not (Test-Path $versionFile)) {
    Write-ColorOutput "ERROR: VERSION file not found" "Error"
    exit 1
}

$currentVersion = Get-Content $versionFile -Raw
$currentVersion = $currentVersion.Trim()
Write-ColorOutput "Current version: $currentVersion" "Info"

# Parse version
if ($currentVersion -match '^(\d+)\.(\d+)\.(\d+)$') {
    $major = [int]$matches[1]
    $minor = [int]$matches[2]
    $patch = [int]$matches[3]
} else {
    Write-ColorOutput "ERROR: Invalid version format in VERSION file" "Error"
    exit 1
}

# Step 4: Calculate new version
Write-ColorOutput "`n[Step 4/7] Calculating new version..." "Step"

switch ($ReleaseType) {
    'major' {
        $major++
        $minor = 0
        $patch = 0
    }
    'minor' {
        $minor++
        $patch = 0
    }
    'patch' {
        $patch++
    }
}

$newVersion = "$major.$minor.$patch"
Write-ColorOutput "New version: $newVersion" "Success"

if ($DryRun) {
    Write-ColorOutput "`n[DRY RUN] Would update version from $currentVersion to $newVersion" "Warning"
    Write-ColorOutput "[DRY RUN] Would create PR with description: $Description" "Warning"
    exit 0
}

# Step 5: Create release branch and update version
Write-ColorOutput "`n[Step 5/7] Creating release branch..." "Step"

$releaseBranch = "release/v$newVersion"
git checkout -b $releaseBranch
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "ERROR: Failed to create release branch" "Error"
    exit 1
}

# Update VERSION file
Set-Content -Path $versionFile -Value $newVersion -NoNewline

# Update other files that might contain version
$filesToUpdate = @(
    "README.md",
    "Start-AitherZero.ps1",
    "aither-core/aither-core.ps1"
)

foreach ($file in $filesToUpdate) {
    if (Test-Path $file) {
        $content = Get-Content $file -Raw
        $updated = $content -replace "v?$([regex]::Escape($currentVersion))", "v$newVersion"
        if ($content -ne $updated) {
            Set-Content -Path $file -Value $updated -NoNewline
            Write-ColorOutput "Updated version in: $file" "Info"
        }
    }
}

# Commit changes
git add .
git commit -m "chore: bump version to v$newVersion

$Description"

if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "ERROR: Failed to commit version changes" "Error"
    git checkout $mainBranch
    git branch -D $releaseBranch
    exit 1
}

Write-ColorOutput "Version updated and committed" "Success"

# Step 6: Push branch and create PR
if (-not $SkipPR) {
    Write-ColorOutput "`n[Step 6/7] Creating pull request..." "Step"
    
    # Push branch
    git push -u origin $releaseBranch
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "ERROR: Failed to push release branch" "Error"
        exit 1
    }
    
    # Create PR
    if ($hasGH) {
        $prBody = @"
## Release v$newVersion

### Release Type: $ReleaseType

### Description
$Description

### Checklist
- [ ] Version bumped in all files
- [ ] Tests pass
- [ ] Documentation updated
- [ ] Breaking changes documented (if any)

### Notes
This PR was created automatically by the release script.
After merging, a release tag will be created automatically.
"@
        
        $prUrl = gh pr create --title "Release v$newVersion" --body $prBody --base $mainBranch
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "Pull request created: $prUrl" "Success"
            
            if ($AutoMerge) {
                Write-ColorOutput "Attempting auto-merge..." "Info"
                gh pr merge --auto --squash
            }
        } else {
            Write-ColorOutput "ERROR: Failed to create pull request" "Error"
        }
    }
} else {
    # Direct commit to main (use with caution)
    Write-ColorOutput "`n[Step 6/7] Pushing directly to $mainBranch..." "Step"
    git checkout $mainBranch
    git merge --no-ff $releaseBranch -m "Release v$newVersion"
    git push origin $mainBranch
}

# Step 7: Instructions for tagging
Write-ColorOutput "`n[Step 7/7] Next steps..." "Step"

if (-not $SkipPR) {
    Write-Host @"

IMPORTANT: After the PR is merged, create and push the release tag:

  git checkout $mainBranch
  git pull origin $mainBranch
  git tag -a "v$newVersion" -m "Release v$newVersion"
  git push origin "v$newVersion"

This will trigger the release build pipeline.
"@ -ForegroundColor Yellow
} else {
    Write-ColorOutput "Creating release tag..." "Info"
    git tag -a "v$newVersion" -m "Release v$newVersion"
    git push origin "v$newVersion"
    Write-ColorOutput "Release tag created and pushed" "Success"
}

Write-Host ""
Write-ColorOutput "Release process completed!" "Success"
Write-ColorOutput "Version: $currentVersion → $newVersion" "Info"

# Cleanup
if (git show-ref --verify --quiet refs/heads/$releaseBranch) {
    git branch -d $releaseBranch 2>$null
}