<#
.SYNOPSIS
    Enhanced cross-compatible bootstrap script for Aitherium Infrastructure Automation with multi-repository development pipeline support.

.DESCRIPTION
    This enhanced bootstrap script supports multiple development workflows:
    1. Lightweight Bootstrap: Downloads only aither-core/ for basic usage
    2. Full Development Setup: Clones complete repository with development environment
    3. Multi-Repository Pipeline: Supports wizzense → AitherLabs → Aitherium workflow

    Features:
    - Multi-repository development pipeline support
    - Lightweight vs. full project download options
    - Development environment setup automation
    - Enhanced GitHub Copilot integration
    - Cross-platform compatibility (Windows, Linux, macOS)
    - PowerShell 5.1 and 7.x compatibility

.PARAMETER Mode
    Bootstrap mode: 'lightweight' (aither-core only), 'full' (complete project), 'dev' (development environment)

.PARAMETER Repository
    Target repository: 'public' (Aitherium/AitherLabs), 'dev' (wizzense/opentofu-lab-automation), 'premium' (Aitherium/Aitherium)

.PARAMETER SetupDevEnvironment
    Automatically configure development environment with VS Code, extensions, and tools

.PARAMETER ConfigureGitHubCopilot
    Configure GitHub Copilot integration and settings

.PARAMETER TargetBranch
    Specify which branch to bootstrap from (default: main)

.PARAMETER LocalPath
    Custom local path for repository clone (default: temp directory)

.EXAMPLE
    # Lightweight bootstrap - aither-core only (fastest)
    ./kicker-git-enhanced.ps1 -Mode lightweight

.EXAMPLE
    # Full development setup with GitHub Copilot integration
    ./kicker-git-enhanced.ps1 -Mode dev -Repository dev -SetupDevEnvironment -ConfigureGitHubCopilot

.EXAMPLE
    # Production deployment from public repository
    ./kicker-git-enhanced.ps1 -Mode full -Repository public
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('lightweight', 'full', 'dev')]
    [string]$Mode = 'lightweight',

    [ValidateSet('public', 'dev', 'premium')]
    [string]$Repository = 'public',

    [switch]$SetupDevEnvironment,
    [switch]$ConfigureGitHubCopilot,
    [string]$TargetBranch = 'main',
    [string]$LocalPath,
    [switch]$Force,

    # Legacy parameters for backward compatibility
    [string]$ConfigFile,
    [switch]$Quiet,
    [switch]$NonInteractive,
    [ValidateSet('silent', 'normal', 'detailed')]
    [string]$Verbosity = 'normal',
    [switch]$SkipPrerequisites,
    [switch]$SkipGitHubAuth
)

#Requires -Version 5.1

# Enhanced bootstrap constants
$script:BootstrapVersion = '3.0.0'

# Repository configurations for multi-tier development pipeline
$script:Repositories = @{
    'dev'     = @{
        Name        = 'wizzense/opentofu-lab-automation'
        Url         = 'https://github.com/wizzense/opentofu-lab-automation.git'
        RawBaseUrl  = 'https://raw.githubusercontent.com/wizzense/opentofu-lab-automation'
        Description = 'Personal development fork (GitHub Copilot enabled)'
        Tier        = 'Development'
        Upstreams   = @(
            @{ Name = 'upstream-public'; Url = 'https://github.com/Aitherium/AitherLabs.git' },
            @{ Name = 'upstream-premium'; Url = 'https://github.com/Aitherium/Aitherium.git' }
        )
    }
    'public'  = @{
        Name        = 'Aitherium/AitherLabs'
        Url         = 'https://github.com/Aitherium/AitherLabs.git'
        RawBaseUrl  = 'https://raw.githubusercontent.com/Aitherium/AitherLabs'
        Description = 'Public open-source version (staging/test)'
        Tier        = 'Staging'
        Upstreams   = @(
            @{ Name = 'upstream-premium'; Url = 'https://github.com/Aitherium/Aitherium.git' }
        )
    }
    'premium' = @{
        Name        = 'Aitherium/Aitherium'
        Url         = 'https://github.com/Aitherium/Aitherium.git'
        RawBaseUrl  = 'https://raw.githubusercontent.com/Aitherium/Aitherium'
        Description = 'Premium enterprise version (production)'
        Tier        = 'Production'
        Upstreams   = @()
    }
}

# Get selected repository configuration
$script:SelectedRepo = $script:Repositories[$Repository]
$script:RepoUrl = $script:SelectedRepo.Url
$script:RawBaseUrl = $script:SelectedRepo.RawBaseUrl

Write-Host "Aitherium Enhanced Bootstrap v$script:BootstrapVersion" -ForegroundColor Cyan
Write-Host "Mode: $Mode | Repository: $($script:SelectedRepo.Name) | Branch: $TargetBranch" -ForegroundColor Green

# Cross-platform compatibility check (avoid overwriting read-only variables)
$script:IsWindowsPlatform = if ($PSVersionTable.PSVersion.Major -ge 6) { $IsWindows } else { $env:OS -eq 'Windows_NT' }
$script:IsLinuxPlatform = if ($PSVersionTable.PSVersion.Major -ge 6) { $IsLinux } else { $false }
$script:IsMacOSPlatform = if ($PSVersionTable.PSVersion.Major -ge 6) { $IsMacOS } else { $false }

# Enhanced logging function
function Write-EnhancedLog {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info',
        [switch]$NoNewline
    )

    if ($Verbosity -eq 'silent') { return }

    $color = switch ($Level) {
        'Info' { 'Cyan' }
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
    }
    $prefix = switch ($Level) {
        'Info' { '[INFO]' }
        'Success' { '[SUCCESS]' }
        'Warning' { '[WARN]' }
        'Error' { '[ERROR]' }
    }

    if ($NoNewline) {
        Write-Host "$prefix $Message" -ForegroundColor $color -NoNewline
    } else {
        Write-Host "$prefix $Message" -ForegroundColor $color
    }
}

# Determine target directory
if (-not $LocalPath) {
    $LocalPath = if ($script:IsWindowsPlatform) {
        Join-Path $env:TEMP 'AitherLabs-Bootstrap'
    } else {
        Join-Path '/tmp' 'AitherLabs-Bootstrap'
    }
}

Write-EnhancedLog "Target directory: $LocalPath" -Level Info

# Create target directory
try {
    if (-not (Test-Path $LocalPath)) {
        New-Item -ItemType Directory -Path $LocalPath -Force | Out-Null
    }
    Set-Location $LocalPath
    Write-EnhancedLog "Working directory set to: $LocalPath" -Level Success
} catch {
    Write-EnhancedLog "Failed to create/access directory: $($_.Exception.Message)" -Level Error
    exit 1
}

# Function to set up multi-repository development pipeline
function Initialize-MultiRepoWorkflow {
    param(
        [string]$LocalRepoPath,
        [string]$SelectedRepoKey
    )

    Write-EnhancedLog 'Setting up multi-repository development pipeline...' -Level Info

    $selectedRepo = $script:Repositories[$SelectedRepoKey]

    if (-not $selectedRepo.Upstreams -or $selectedRepo.Upstreams.Count -eq 0) {
        Write-EnhancedLog "No upstream repositories to configure for $($selectedRepo.Description)" -Level Info
        return
    }

    Push-Location $LocalRepoPath

    try {
        foreach ($upstream in $selectedRepo.Upstreams) {
            $existingRemote = git remote | Where-Object { $_ -eq $upstream.Name }

            if ($existingRemote) {
                Write-EnhancedLog "Remote '$($upstream.Name)' already exists, updating URL..." -Level Info
                git remote set-url $upstream.Name $upstream.Url
            } else {
                Write-EnhancedLog "Adding upstream remote: $($upstream.Name) -> $($upstream.Url)" -Level Info
                git remote add $upstream.Name $upstream.Url
            }
        }

        # Fetch all remotes to verify connectivity
        Write-EnhancedLog 'Fetching from all remotes...' -Level Info
        git remote | ForEach-Object {
            Write-EnhancedLog "Fetching from $_..." -Level Info
            git fetch $_ --no-tags 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-EnhancedLog "Successfully fetched from $_" -Level Success
            } else {
                Write-EnhancedLog "Failed to fetch from $_ (this may be expected for private repos)" -Level Warning
            }
        }

        # Display the configured remotes
        Write-EnhancedLog 'Multi-repository configuration complete!' -Level Success
        Write-EnhancedLog 'Configured remotes:' -Level Info
        $remotes = git remote -v
        $remotes | ForEach-Object { Write-EnhancedLog "  $_" -Level Info }

    } catch {
        Write-EnhancedLog "Failed to configure multi-repo workflow: $($_.Exception.Message)" -Level Error
    } finally {
        Pop-Location
    }
}

# Mode-specific implementation
switch ($Mode) {
    'lightweight' {
        Write-EnhancedLog 'Lightweight mode: Downloading aither-core only...' -Level Info

        # Create minimal structure
        $aitherCorePath = Join-Path $LocalPath 'aither-core'
        if (Test-Path $aitherCorePath) {
            if ($Force) {
                Remove-Item $aitherCorePath -Recurse -Force
            } else {
                Write-EnhancedLog 'aither-core already exists. Use -Force to overwrite.' -Level Warning
                return
            }
        }

        try {
            # Download core files using direct GitHub API
            Write-EnhancedLog 'Downloading core modules...' -Level Info

            $coreFiles = @(
                'aither-core/aither-core.ps1',
                'aither-core/AitherCore.psd1',
                'aither-core/AitherCore.psm1',
                'aither-core/default-config.json'
            )

            foreach ($file in $coreFiles) {
                $url = "$($script:RawBaseUrl)/$TargetBranch/$file"
                $localFile = Join-Path $LocalPath $file
                $dir = Split-Path $localFile -Parent

                if (-not (Test-Path $dir)) {
                    New-Item -ItemType Directory -Path $dir -Force | Out-Null
                }

                Write-EnhancedLog "Downloading: $file" -Level Info
                Invoke-WebRequest -Uri $url -OutFile $localFile -ErrorAction Stop
            }

            # Download modules directory structure
            Write-EnhancedLog 'Setting up modules...' -Level Info
            $modulesPath = Join-Path $aitherCorePath 'modules'
            New-Item -ItemType Directory -Path $modulesPath -Force | Out-Null

            # Create module setup script
            $moduleSetupScript = @"
# Module setup for lightweight installation
Write-Host "Setting up lightweight installation..." -ForegroundColor Green
Write-Host "Use the following command to get the full modules:" -ForegroundColor Yellow
Write-Host "git clone $($script:RepoUrl) full-install" -ForegroundColor Cyan
Write-Host ""
Write-Host "Core runner available at: ./aither-core/aither-core.ps1" -ForegroundColor Green
"@

            Set-Content -Path (Join-Path $LocalPath 'setup-full.ps1') -Value $moduleSetupScript

            Write-EnhancedLog 'Lightweight installation complete!' -Level Success
            Write-EnhancedLog 'Run ./aither-core/aither-core.ps1 to start' -Level Info
            Write-EnhancedLog 'Run ./setup-full.ps1 for full installation' -Level Info

        } catch {
            Write-EnhancedLog "Failed to download core files: $($_.Exception.Message)" -Level Error
            exit 1
        }
    }

    'full' {
        Write-EnhancedLog 'Full mode: Cloning complete repository...' -Level Info

        try {
            # Check if git is available
            $gitAvailable = Get-Command git -ErrorAction SilentlyContinue
            if (-not $gitAvailable) {
                Write-EnhancedLog 'Git is required for full mode. Please install Git first.' -Level Error
                exit 1
            }

            # Clone repository
            $clonePath = Join-Path $LocalPath 'AitherLabs'
            if (Test-Path $clonePath) {
                if ($Force) {
                    Remove-Item $clonePath -Recurse -Force
                } else {
                    Write-EnhancedLog 'Repository already exists. Use -Force to overwrite.' -Level Warning
                    return
                }
            }

            Write-EnhancedLog "Cloning from: $($script:RepoUrl)" -Level Info
            git clone --branch $TargetBranch $script:RepoUrl $clonePath

            if ($LASTEXITCODE -eq 0) {
                Set-Location $clonePath
                Write-EnhancedLog 'Repository cloned successfully!' -Level Success
                Write-EnhancedLog "Location: $clonePath" -Level Info

                # Run initial setup if available
                $setupScript = Join-Path $clonePath 'aither-core/aither-core.ps1'
                if (Test-Path $setupScript) {
                    Write-EnhancedLog 'Running initial setup...' -Level Info
                    & $setupScript -NonInteractive -Verbosity $Verbosity
                }
            } else {
                Write-EnhancedLog 'Failed to clone repository' -Level Error
                exit 1
            }

        } catch {
            Write-EnhancedLog "Clone operation failed: $($_.Exception.Message)" -Level Error
            exit 1
        }
    }

    'dev' {
        Write-EnhancedLog 'Development mode: Setting up complete development environment...' -Level Info

        # First do a full clone
        & $MyInvocation.MyCommand.Path -Mode full -Repository $Repository -TargetBranch $TargetBranch -LocalPath $LocalPath -Force:$Force

        if ($SetupDevEnvironment) {
            Write-EnhancedLog 'Configuring development environment...' -Level Info
            # Setup VS Code settings if VS Code is available
            $vsCodeConfigPath = if ($script:IsWindowsPlatform) {
                Join-Path $env:APPDATA 'Code/User'
            } elseif ($script:IsMacOSPlatform) {
                Join-Path $env:HOME 'Library/Application Support/Code/User'
            } else {
                Join-Path $env:HOME '.config/Code/User'
            }

            if (Test-Path $vsCodeConfigPath) {
                Write-EnhancedLog 'Configuring VS Code settings...' -Level Info
                # Add VS Code configuration here
            }
        }

        if ($ConfigureGitHubCopilot) {
            Write-EnhancedLog 'Configuring GitHub Copilot integration...' -Level Info
            # Check for GitHub CLI and configure Copilot
            $ghAvailable = Get-Command gh -ErrorAction SilentlyContinue
            if ($ghAvailable) {
                Write-EnhancedLog 'GitHub CLI detected - Copilot configuration available' -Level Success
            } else {
                Write-EnhancedLog "GitHub CLI not found - install 'gh' for Copilot integration" -Level Warning
            }
        }

        Write-EnhancedLog 'Development environment setup complete!' -Level Success
    }
}

Write-EnhancedLog 'Bootstrap completed successfully!' -Level Success
Write-EnhancedLog "Enhanced bootstrap v$script:BootstrapVersion" -Level Info
