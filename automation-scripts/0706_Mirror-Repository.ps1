#Requires -Version 7.0

<#
.SYNOPSIS
    Mirror a public GitHub repository to a private internal repository

.DESCRIPTION
    Sets up and maintains a private internal GitHub repository as a mirror of a public upstream repository.
    Supports initial setup, synchronization, and local clone configuration.
    
    This script:
    - Verifies prerequisites (git, gh CLI)
    - Authenticates with GitHub CLI
    - Creates private internal repository if needed
    - Mirrors all branches and tags from upstream
    - Sets up local clone with upstream remote configured

.NOTES
    Stage: Development
    Category: Git
    Dependencies: git, gh CLI
    Tags: git, mirror, sync, repository
    
.PARAMETER UpstreamUrl
    The URL of the upstream public repository to mirror
    Default: https://github.com/wizzense/AitherZero.git

.PARAMETER TargetOrg
    The target GitHub organization for the internal repository
    Default: Aitherium

.PARAMETER InternalRepoName
    The name of the internal repository
    Default: AitherZero-Internal

.PARAMETER WorkDirectory
    The local directory to clone the internal repository
    Default: Current directory

.PARAMETER Force
    Force operations without prompting

.PARAMETER NonInteractive
    Run in non-interactive mode (for CI/CD)

.PARAMETER SyncOnly
    Only synchronize an existing mirror, don't create new

.EXAMPLE
    ./0706_Mirror-Repository.ps1
    Sets up the default mirror (wizzense/AitherZero -> Aitherium/AitherZero-Internal)

.EXAMPLE
    ./0706_Mirror-Repository.ps1 -SyncOnly
    Synchronizes existing mirror without setup

.EXAMPLE
    ./0706_Mirror-Repository.ps1 -UpstreamUrl "https://github.com/owner/repo.git" -TargetOrg "MyOrg" -InternalRepoName "MyRepo-Internal"
    Sets up custom repository mirror
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$UpstreamUrl = "https://github.com/wizzense/AitherZero.git",
    
    [string]$TargetOrg = "Aitherium",
    
    [string]$InternalRepoName = "AitherZero-Internal",
    
    [string]$WorkDirectory = (Get-Location).Path,
    
    [switch]$Force,
    
    [switch]$NonInteractive,
    
    [switch]$SyncOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Module Imports

# Import required modules
$devModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/development"
$utilModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/utilities"

if (Test-Path (Join-Path $devModulePath "GitAutomation.psm1")) {
    Import-Module (Join-Path $devModulePath "GitAutomation.psm1") -Force
}

if (Test-Path (Join-Path $utilModulePath "Logging.psm1")) {
    Import-Module (Join-Path $utilModulePath "Logging.psm1") -Force
}

#endregion

#region Helper Functions

function Write-ScriptLog {
    param(
        [string]$Message,
        [string]$Level = 'Information',
        [hashtable]$Data = @{}
    )
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "Mirror-Repository" -Data $Data
    } else {
        $color = switch ($Level) {
            'Error' { 'Red' }
            'Warning' { 'Yellow' }
            'Information' { 'Cyan' }
            default { 'White' }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
}

function Test-Command {
    param([string]$CommandName)
    
    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    if (-not $command) {
        Write-ScriptLog "Required command '$CommandName' not found" -Level Error
        return $false
    }
    return $true
}

function Test-GitHubAuth {
    <#
    .SYNOPSIS
        Test GitHub CLI authentication status
    #>
    try {
        $authStatus = gh auth status -h github.com 2>&1 | Out-String
        return $authStatus -match "Logged in to github.com"
    } catch {
        return $false
    }
}

function Invoke-GitHubAuth {
    <#
    .SYNOPSIS
        Authenticate with GitHub CLI
    #>
    if ($NonInteractive) {
        Write-ScriptLog "Cannot authenticate in non-interactive mode. Please run 'gh auth login' manually." -Level Error
        throw "GitHub authentication required"
    }
    
    Write-ScriptLog "Initiating GitHub authentication..." -Level Warning
    gh auth login --web
    
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub authentication failed"
    }
    
    Write-ScriptLog "GitHub authentication successful" -Level Information
}

function Test-GitHubRepository {
    <#
    .SYNOPSIS
        Check if a GitHub repository exists
    #>
    param([string]$RepoSlug)
    
    try {
        $null = gh repo view $RepoSlug --json name 2>&1
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function New-GitHubRepository {
    <#
    .SYNOPSIS
        Create a new private GitHub repository
    #>
    param(
        [string]$RepoSlug,
        [string]$Description,
        [switch]$Private
    )
    
    $privateFlag = if ($Private) { '--private' } else { '--public' }
    
    gh repo create $RepoSlug `
        $privateFlag `
        --description $Description `
        --disable-issues `
        --disable-wiki `
        --confirm
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create repository $RepoSlug"
    }
    
    Write-ScriptLog "Created repository: $RepoSlug" -Level Information
}

function Sync-RepositoryMirror {
    <#
    .SYNOPSIS
        Synchronize repository mirror (push all branches and tags)
    #>
    param(
        [string]$SourceUrl,
        [string]$TargetUrl,
        [string]$TempPath
    )
    
    try {
        # Clone with mirror flag for bare repository
        Write-ScriptLog "Cloning upstream repository..." -Level Information
        git clone --mirror $SourceUrl $TempPath 2>&1 | Out-Null
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to clone upstream repository"
        }
        
        Push-Location $TempPath
        
        try {
            # Push all branches and tags to internal repository
            Write-ScriptLog "Pushing to internal repository..." -Level Information
            git push --mirror $TargetUrl 2>&1 | Out-Null
            
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to push to internal repository"
            }
            
            Write-ScriptLog "Mirror synchronization completed successfully" -Level Information
            
        } finally {
            Pop-Location
        }
        
    } catch {
        Write-ScriptLog "Mirror synchronization failed: $_" -Level Error
        throw
    }
}

function Initialize-LocalClone {
    <#
    .SYNOPSIS
        Clone internal repository locally and set up upstream remote
    #>
    param(
        [string]$InternalUrl,
        [string]$UpstreamUrl,
        [string]$LocalPath
    )
    
    try {
        # Clone internal repository
        Write-ScriptLog "Cloning internal repository to $LocalPath..." -Level Information
        git clone $InternalUrl $LocalPath 2>&1 | Out-Null
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to clone internal repository"
        }
        
        Push-Location $LocalPath
        
        try {
            # Add upstream remote
            Write-ScriptLog "Configuring upstream remote..." -Level Information
            git remote add upstream $UpstreamUrl 2>&1 | Out-Null
            
            if ($LASTEXITCODE -ne 0) {
                Write-ScriptLog "Upstream remote may already exist" -Level Warning
            }
            
            # Fetch upstream
            git fetch upstream --tags 2>&1 | Out-Null
            
            # Set upstream tracking for current branch
            $currentBranch = git branch --show-current
            if ($currentBranch) {
                git branch --set-upstream-to=upstream/$currentBranch $currentBranch 2>&1 | Out-Null
            }
            
            Write-ScriptLog "Local clone initialized successfully" -Level Information
            
        } finally {
            Pop-Location
        }
        
    } catch {
        Write-ScriptLog "Local clone initialization failed: $_" -Level Error
        throw
    }
}

#endregion

#region Main Script

try {
    Write-ScriptLog "Starting repository mirror setup" -Level Information -Data @{
        Upstream = $UpstreamUrl
        Target = "$TargetOrg/$InternalRepoName"
        WorkDirectory = $WorkDirectory
    }
    
    # Verify prerequisites
    Write-Host "`n=== Checking Prerequisites ===" -ForegroundColor Cyan
    
    $missingCommands = @()
    foreach ($cmd in @('git', 'gh')) {
        if (-not (Test-Command $cmd)) {
            $missingCommands += $cmd
        } else {
            Write-Host "✓ Found: $cmd" -ForegroundColor Green
        }
    }
    
    if ($missingCommands) {
        Write-ScriptLog "Missing required commands: $($missingCommands -join ', ')" -Level Error
        throw "Please install missing prerequisites: $($missingCommands -join ', ')"
    }
    
    # Check GitHub authentication
    Write-Host "`n=== Checking GitHub Authentication ===" -ForegroundColor Cyan
    
    if (-not (Test-GitHubAuth)) {
        Write-ScriptLog "GitHub CLI not authenticated" -Level Warning
        if (-not $NonInteractive) {
            Invoke-GitHubAuth
        } else {
            throw "GitHub authentication required. Run 'gh auth login' before using non-interactive mode."
        }
    } else {
        Write-Host "✓ GitHub authenticated" -ForegroundColor Green
    }
    
    # Build repository identifiers
    $internalSlug = "$TargetOrg/$InternalRepoName"
    $internalUrl = "https://github.com/$internalSlug.git"
    $localRepoPath = Join-Path $WorkDirectory $InternalRepoName
    
    # Check/Create internal repository
    if (-not $SyncOnly) {
        Write-Host "`n=== Setting Up Internal Repository ===" -ForegroundColor Cyan
        Write-Host "Target: $internalSlug" -ForegroundColor Gray
        
        $repoExists = Test-GitHubRepository -RepoSlug $internalSlug
        
        if ($repoExists) {
            Write-Host "✓ Internal repository exists" -ForegroundColor Yellow
            Write-ScriptLog "Internal repository already exists: $internalSlug" -Level Information
        } else {
            if ($PSCmdlet.ShouldProcess($internalSlug, "Create private repository")) {
                Write-Host "Creating internal repository..." -ForegroundColor Cyan
                New-GitHubRepository -RepoSlug $internalSlug `
                    -Description "Internal mirror of $UpstreamUrl" `
                    -Private
                
                Write-Host "✓ Internal repository created" -ForegroundColor Green
                Start-Sleep -Seconds 2
            }
        }
    }
    
    # Synchronize mirror
    Write-Host "`n=== Synchronizing Repository Mirror ===" -ForegroundColor Cyan
    
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "AitherZero-Mirror-$(Get-Random)"
    
    try {
        if ($PSCmdlet.ShouldProcess($internalSlug, "Synchronize repository mirror")) {
            Sync-RepositoryMirror -SourceUrl $UpstreamUrl `
                -TargetUrl $internalUrl `
                -TempPath $tempDir
            
            Write-Host "✓ Mirror synchronized successfully" -ForegroundColor Green
        }
    } finally {
        # Clean up temporary directory
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Set up local clone
    if (-not $SyncOnly) {
        Write-Host "`n=== Setting Up Local Clone ===" -ForegroundColor Cyan
        
        if (Test-Path $localRepoPath) {
            if ($Force) {
                Write-Host "Removing existing directory: $localRepoPath" -ForegroundColor Yellow
                Remove-Item -Path $localRepoPath -Recurse -Force
            } elseif (-not $NonInteractive) {
                $response = Read-Host "Local directory exists at '$localRepoPath'. Remove it? (y/N)"
                if ($response -eq 'y') {
                    Remove-Item -Path $localRepoPath -Recurse -Force
                } else {
                    Write-Host "Skipping local clone setup" -ForegroundColor Yellow
                    $localRepoPath = $null
                }
            } else {
                Write-ScriptLog "Local directory exists, skipping clone in non-interactive mode" -Level Warning
                $localRepoPath = $null
            }
        }
        
        if ($localRepoPath -and $PSCmdlet.ShouldProcess($localRepoPath, "Clone repository locally")) {
            Initialize-LocalClone -InternalUrl $internalUrl `
                -UpstreamUrl $UpstreamUrl `
                -LocalPath $localRepoPath
            
            Write-Host "✓ Local clone configured" -ForegroundColor Green
        }
    }
    
    # Display summary
    Write-Host "`n=== SETUP COMPLETE ===" -ForegroundColor Green
    Write-Host "================================" -ForegroundColor Green
    Write-Host "Internal Repository: https://github.com/$internalSlug" -ForegroundColor White
    if ($localRepoPath -and (Test-Path $localRepoPath)) {
        Write-Host "Local Directory: $localRepoPath" -ForegroundColor White
        
        Write-Host "`nTo sync with upstream in the future:" -ForegroundColor Yellow
        Write-Host "  cd '$localRepoPath'" -ForegroundColor Gray
        Write-Host "  git fetch upstream" -ForegroundColor Gray
        Write-Host "  git merge upstream/main" -ForegroundColor Gray
        Write-Host "  git push origin main" -ForegroundColor Gray
        
        Write-Host "`nOr run this script with -SyncOnly:" -ForegroundColor Yellow
        Write-Host "  aitherzero 0706 -SyncOnly" -ForegroundColor Gray
    }
    
    Write-ScriptLog "Repository mirror setup completed successfully" -Level Information
    
} catch {
    Write-ScriptLog "Repository mirror setup failed: $_" -Level Error
    Write-Host "`n✗ Error: $_" -ForegroundColor Red
    exit 1
}

#endregion
