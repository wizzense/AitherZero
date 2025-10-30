<#
.SYNOPSIS
    Build and publish Docker images to multiple registries (Docker Hub, GitHub Container Registry)

.DESCRIPTION
    Automated Docker image publishing for AitherZero with multi-registry support.

    This script provides a complete solution for building and publishing Docker images
    to make AitherZero easily accessible via Docker Desktop on Windows, Linux, and macOS.

    **Features:**
    - Builds Docker images with proper versioning
    - Publishes to Docker Hub for public accessibility
    - Publishes to GitHub Container Registry (ghcr.io) for CI/CD
    - Automatic version tagging from VERSION file
    - Multi-platform builds (amd64, arm64)
    - Automated tagging strategies (latest, semantic versions)

    **Prerequisites:**
    - Docker must be installed and running
    - Docker login credentials for target registries
    - For Docker Hub: DOCKER_HUB_USERNAME and DOCKER_HUB_TOKEN environment variables
    - For GHCR: GITHUB_TOKEN environment variable (or use gh auth token)

    **Common Workflows:**

    1. Publish to Docker Hub (Public):
       .\0855_Publish-DockerImage.ps1 -Registry DockerHub -Username "myuser"

    2. Publish to Both Registries:
       .\0855_Publish-DockerImage.ps1 -Registry All -Username "myuser"

    3. Build and Publish Release Version:
       .\0855_Publish-DockerImage.ps1 -Registry DockerHub -Username "myuser" -Version "1.0.0" -PushLatest

    4. Local Build Only (No Push):
       .\0855_Publish-DockerImage.ps1 -BuildOnly

    5. Quick Test Build:
       .\0855_Publish-DockerImage.ps1 -BuildOnly -Platform linux/amd64

.PARAMETER Registry
    Target registry: DockerHub, GHCR (GitHub Container Registry), or All
    Default: DockerHub

.PARAMETER Username
    Docker Hub username or GitHub username for GHCR
    Required when publishing (not for BuildOnly)

.PARAMETER Repository
    Repository name (defaults to 'aitherzero')

.PARAMETER Version
    Version tag (defaults to value from VERSION file)
    Examples: 1.0.0, 1.0.0-beta, latest

.PARAMETER Platform
    Target platform(s) for multi-platform builds
    Examples: linux/amd64, linux/arm64, linux/amd64,linux/arm64
    Default: linux/amd64,linux/arm64

.PARAMETER PushLatest
    Also tag and push as 'latest' (recommended for stable releases)

.PARAMETER BuildOnly
    Build the image locally without pushing to any registry

.PARAMETER Force
    Force rebuild without using cache

.PARAMETER DryRun
    Show what would be done without actually executing

.EXAMPLE
    .\0855_Publish-DockerImage.ps1 -Registry DockerHub -Username "wizzense"
    Build and publish to Docker Hub as wizzense/aitherzero with version from VERSION file

.EXAMPLE
    .\0855_Publish-DockerImage.ps1 -Registry DockerHub -Username "wizzense" -Version "1.0.0" -PushLatest
    Publish version 1.0.0 and also tag as latest

.EXAMPLE
    .\0855_Publish-DockerImage.ps1 -Registry All -Username "wizzense"
    Publish to both Docker Hub and GitHub Container Registry

.EXAMPLE
    .\0855_Publish-DockerImage.ps1 -BuildOnly
    Build locally for testing without pushing to any registry

.EXAMPLE
    .\0855_Publish-DockerImage.ps1 -Registry DockerHub -Username "wizzense" -Platform linux/amd64
    Build and publish for x86_64 architecture only (faster for testing)

.NOTES
    Script Number: 0855
    Category: Container Management
    Requires: Docker, Docker Buildx
    Environment Variables:
    - DOCKER_HUB_USERNAME: Docker Hub username (optional, overrides -Username)
    - DOCKER_HUB_TOKEN: Docker Hub access token (required for Docker Hub publishing)
    - GITHUB_TOKEN: GitHub token (required for GHCR publishing)

.LINK
    https://github.com/wizzense/AitherZero
    https://hub.docker.com/r/wizzense/aitherzero
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('DockerHub', 'GHCR', 'All')]
    [string]$Registry = 'DockerHub',

    [Parameter(Mandatory = $false)]
    [string]$Username,

    [Parameter(Mandatory = $false)]
    [string]$Repository = 'aitherzero',

    [Parameter(Mandatory = $false)]
    [string]$Version,

    [Parameter(Mandatory = $false)]
    [string]$Platform = 'linux/amd64,linux/arm64',

    [Parameter(Mandatory = $false)]
    [switch]$PushLatest,

    [Parameter(Mandatory = $false)]
    [switch]$BuildOnly,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

# Script configuration
$ErrorActionPreference = 'Stop'
$script:ScriptName = '0855_Publish-DockerImage'
$script:ExitCode = 0

#region Helper Functions

function Write-LogMessage {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'Info'    { 'Cyan' }
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
    }

    $prefix = switch ($Level) {
        'Info'    { 'ℹ️' }
        'Success' { '✅' }
        'Warning' { '⚠️' }
        'Error'   { '❌' }
    }

    Write-Host "[$timestamp] $prefix $Message" -ForegroundColor $color
}

function Test-DockerAvailable {
    try {
        $null = docker version 2>&1
        return $true
    }
    catch {
        return $false
    }
}

function Test-DockerBuildxAvailable {
    try {
        $null = docker buildx version 2>&1
        return $true
    }
    catch {
        return $false
    }
}

function Get-AitherZeroVersion {
    $versionFile = Join-Path $PSScriptRoot '..' 'VERSION'
    if (Test-Path $versionFile) {
        $version = (Get-Content $versionFile -Raw).Trim()
        return $version
    }
    return '1.0.0.0'
}

function Get-RegistryUrl {
    param([string]$RegistryType)

    switch ($RegistryType) {
        'DockerHub' { return 'docker.io' }
        'GHCR'      { return 'ghcr.io' }
        default     { return 'docker.io' }
    }
}

function Get-ImageReference {
    param(
        [string]$RegistryType,
        [string]$Username,
        [string]$Repository,
        [string]$Tag
    )

    switch ($RegistryType) {
        'DockerHub' {
            return "${Username}/${Repository}:${Tag}"
        }
        'GHCR' {
            $usernameLower = $Username.ToLower()
            return "ghcr.io/${usernameLower}/${Repository}:${Tag}"
        }
        default {
            return "${Username}/${Repository}:${Tag}"
        }
    }
}

function Invoke-DockerLogin {
    param(
        [string]$RegistryType,
        [string]$Username
    )

    Write-LogMessage "Authenticating to $RegistryType..." -Level Info

    $registryUrl = Get-RegistryUrl -RegistryType $RegistryType

    switch ($RegistryType) {
        'DockerHub' {
            # Check for Docker Hub token
            $token = $env:DOCKER_HUB_TOKEN
            if (-not $token) {
                Write-LogMessage "DOCKER_HUB_TOKEN environment variable not found" -Level Warning
                Write-LogMessage "Please set it with: `$env:DOCKER_HUB_TOKEN = 'your-token'" -Level Info
                Write-LogMessage "Or create one at: https://hub.docker.com/settings/security" -Level Info

                if (-not $DryRun) {
                    $secureToken = Read-Host "Enter Docker Hub access token" -AsSecureString
                    $token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
                    )
                }
            }

            if ($DryRun) {
                Write-LogMessage "[DRY RUN] Would login to Docker Hub as $Username" -Level Info
                return $true
            }

            try {
                $token | docker login $registryUrl -u $Username --password-stdin 2>&1 | Out-Null
                Write-LogMessage "Successfully authenticated to Docker Hub" -Level Success
                return $true
            }
            catch {
                Write-LogMessage "Failed to authenticate to Docker Hub: $_" -Level Error
                return $false
            }
        }
        'GHCR' {
            # Check for GitHub token
            $token = $env:GITHUB_TOKEN
            if (-not $token) {
                # Try to get token from gh CLI
                try {
                    $token = gh auth token 2>$null
                }
                catch {
                    Write-LogMessage "GITHUB_TOKEN not found and gh CLI not available" -Level Warning
                    Write-LogMessage "Please set GITHUB_TOKEN or authenticate with: gh auth login" -Level Info

                    if (-not $DryRun) {
                        $secureToken = Read-Host "Enter GitHub personal access token" -AsSecureString
                        $token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
                        )
                    }
                }
            }

            if ($DryRun) {
                Write-LogMessage "[DRY RUN] Would login to GHCR as $Username" -Level Info
                return $true
            }

            try {
                $token | docker login $registryUrl -u $Username --password-stdin 2>&1 | Out-Null
                Write-LogMessage "Successfully authenticated to GitHub Container Registry" -Level Success
                return $true
            }
            catch {
                Write-LogMessage "Failed to authenticate to GHCR: $_" -Level Error
                return $false
            }
        }
    }

    return $false
}

function Build-DockerImage {
    param(
        [string[]]$Tags,
        [string]$Platform,
        [bool]$Push,
        [bool]$UseCache
    )

    Write-LogMessage "Building Docker image..." -Level Info
    Write-LogMessage "  Platform(s): $Platform" -Level Info
    Write-LogMessage "  Tags: $($Tags -join ', ')" -Level Info
    Write-LogMessage "  Push: $Push" -Level Info

    # Prepare build command
    $buildArgs = @(
        'buildx', 'build'
    )

    # Add platform
    $buildArgs += '--platform', $Platform

    # Add tags
    foreach ($tag in $Tags) {
        $buildArgs += '-t', $tag
    }

    # Add push or load
    if ($Push) {
        $buildArgs += '--push'
    }
    else {
        # For local builds on single platform, use --load
        if ($Platform -notlike '*,*') {
            $buildArgs += '--load'
        }
        else {
            Write-LogMessage "Multi-platform builds require --push or save to registry" -Level Warning
            Write-LogMessage "Building without --load (images will not be available locally)" -Level Info
        }
    }

    # Add cache options
    if ($UseCache) {
        $cacheTag = ($Tags[0] -replace ':.*$', ':buildcache')
        $buildArgs += '--cache-from', "type=registry,ref=$cacheTag"
        $buildArgs += '--cache-to', "type=registry,ref=$cacheTag,mode=max"
    }
    else {
        $buildArgs += '--no-cache'
    }

    # Add build context
    $buildArgs += '.'

    if ($DryRun) {
        Write-LogMessage "[DRY RUN] Would execute: docker $($buildArgs -join ' ')" -Level Info
        return $true
    }

    try {
        Write-LogMessage "Starting build process..." -Level Info
        & docker $buildArgs

        if ($LASTEXITCODE -eq 0) {
            Write-LogMessage "Docker image built successfully" -Level Success
            return $true
        }
        else {
            Write-LogMessage "Docker build failed with exit code $LASTEXITCODE" -Level Error
            return $false
        }
    }
    catch {
        Write-LogMessage "Docker build error: $_" -Level Error
        return $false
    }
}

function Show-ImageInfo {
    param([string[]]$Tags)

    Write-LogMessage "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Level Info
    Write-LogMessage "Docker Image Publishing Complete!" -Level Success
    Write-LogMessage "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Level Info
    Write-LogMessage "" -Level Info
    Write-LogMessage "Published Images:" -Level Info
    foreach ($tag in $Tags) {
        Write-LogMessage "  📦 $tag" -Level Success
    }
    Write-LogMessage "" -Level Info
    Write-LogMessage "Pull Commands:" -Level Info
    foreach ($tag in $Tags) {
        Write-LogMessage "  docker pull $tag" -Level Info
    }
    Write-LogMessage "" -Level Info
    Write-LogMessage "Run Command (using first tag):" -Level Info
    Write-LogMessage "  docker run -it --name aitherzero $($Tags[0])" -Level Info
    Write-LogMessage "" -Level Info
    Write-LogMessage "For more information, see DOCKER.md" -Level Info
    Write-LogMessage "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Level Info
}

#endregion

#region Main Script

try {
    Write-LogMessage "AitherZero Docker Image Publisher" -Level Info
    Write-LogMessage "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Level Info

    # Validate Docker is available
    if (-not (Test-DockerAvailable)) {
        Write-LogMessage "Docker is not available. Please install Docker and ensure it's running." -Level Error
        exit 1
    }

    # Validate Docker Buildx is available
    if (-not (Test-DockerBuildxAvailable)) {
        Write-LogMessage "Docker Buildx is not available. Please install Docker Buildx." -Level Error
        Write-LogMessage "See: https://docs.docker.com/buildx/working-with-buildx/" -Level Info
        exit 1
    }

    # Get version
    if (-not $Version) {
        $Version = Get-AitherZeroVersion
        Write-LogMessage "Using version from VERSION file: $Version" -Level Info
    }

    # Get username from environment if not provided
    if (-not $Username) {
        if ($BuildOnly) {
            # For local builds, use a default username if none provided
            $Username = $env:DOCKER_HUB_USERNAME
            if (-not $Username) {
                $Username = $env:USER
                if (-not $Username) {
                    $Username = 'local'
                }
            }
            Write-LogMessage "Using username for local build: $Username" -Level Info
        }
        else {
            # For publishing, username is required
            $Username = $env:DOCKER_HUB_USERNAME
            if (-not $Username) {
                Write-LogMessage "Username not provided. Use -Username parameter or set DOCKER_HUB_USERNAME" -Level Error
                exit 1
            }
            Write-LogMessage "Using username from environment: $Username" -Level Info
        }
    }

    # Determine which registries to use
    $registries = @()
    switch ($Registry) {
        'DockerHub' { $registries = @('DockerHub') }
        'GHCR'      { $registries = @('GHCR') }
        'All'       { $registries = @('DockerHub', 'GHCR') }
    }

    # Build tag list
    $allTags = @()

    if ($BuildOnly) {
        # Local build - use simple tag
        $allTags += "${Repository}:${Version}"
        if ($PushLatest) {
            $allTags += "${Repository}:latest"
        }
    }
    else {
        # Build tags for each registry
        foreach ($reg in $registries) {
            $versionTag = Get-ImageReference -RegistryType $reg -Username $Username -Repository $Repository -Tag $Version
            $allTags += $versionTag

            if ($PushLatest) {
                $latestTag = Get-ImageReference -RegistryType $reg -Username $Username -Repository $Repository -Tag 'latest'
                $allTags += $latestTag
            }

            # Add semantic version tags if version is semver
            if ($Version -match '^(\d+)\.(\d+)\.(\d+)') {
                $major = $Matches[1]
                $minor = $Matches[2]

                $majorMinorTag = Get-ImageReference -RegistryType $reg -Username $Username -Repository $Repository -Tag "${major}.${minor}"
                $majorTag = Get-ImageReference -RegistryType $reg -Username $Username -Repository $Repository -Tag $major

                $allTags += $majorMinorTag
                $allTags += $majorTag
            }
        }
    }

    # Remove duplicates
    $allTags = $allTags | Select-Object -Unique

    Write-LogMessage "Configuration:" -Level Info
    Write-LogMessage "  Registry: $Registry" -Level Info
    Write-LogMessage "  Repository: $Repository" -Level Info
    Write-LogMessage "  Version: $Version" -Level Info
    Write-LogMessage "  Platform(s): $Platform" -Level Info
    Write-LogMessage "  Build Only: $BuildOnly" -Level Info
    Write-LogMessage "  Push Latest: $PushLatest" -Level Info
    Write-LogMessage "  Force Rebuild: $Force" -Level Info
    Write-LogMessage "  Dry Run: $DryRun" -Level Info
    Write-LogMessage "" -Level Info

    # Authenticate to registries if not build-only
    if (-not $BuildOnly) {
        foreach ($reg in $registries) {
            $loginSuccess = Invoke-DockerLogin -RegistryType $reg -Username $Username
            if (-not $loginSuccess -and -not $DryRun) {
                Write-LogMessage "Failed to authenticate to $reg. Cannot continue." -Level Error
                exit 1
            }
        }
    }

    # Build and push image
    $buildSuccess = Build-DockerImage `
        -Tags $allTags `
        -Platform $Platform `
        -Push (-not $BuildOnly) `
        -UseCache (-not $Force)

    if (-not $buildSuccess -and -not $DryRun) {
        Write-LogMessage "Failed to build Docker image" -Level Error
        exit 1
    }

    # Show success message
    if (-not $DryRun) {
        Show-ImageInfo -Tags $allTags
    }
    else {
        Write-LogMessage "[DRY RUN] Operation completed successfully (no changes made)" -Level Success
    }

    exit 0
}
catch {
    Write-LogMessage "Unexpected error: $_" -Level Error
    Write-LogMessage $_.ScriptStackTrace -Level Error
    exit 1
}

#endregion
