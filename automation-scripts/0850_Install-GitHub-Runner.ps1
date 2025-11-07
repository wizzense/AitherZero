#Requires -Version 7.0

<#
.SYNOPSIS
    Install and configure GitHub Actions self-hosted runner
.DESCRIPTION
    Downloads, installs, and configures a GitHub Actions self-hosted runner.
    Supports Windows, Linux, and macOS.
    Can install as a service for automatic startup.
.PARAMETER Repository
    GitHub repository in format owner/repo (e.g., "wizzense/AitherZero")
.PARAMETER Token
    GitHub registration token (obtained from repo settings)
.PARAMETER RunnerName
    Custom name for the runner (default: computername-runner)
.PARAMETER RunnerGroup
    Runner group name (default: Default)
.PARAMETER Labels
    Additional labels for the runner (comma-separated)
.PARAMETER InstallAsService
    Install runner as a system service
.PARAMETER WorkDirectory
    Working directory for runner (default: _work)
.EXAMPLE
    ./0850_Install-GitHub-Runner.ps1 -Repository "wizzense/AitherZero" -Token "XXXX"
.EXAMPLE
    ./0850_Install-GitHub-Runner.ps1 -Repository "wizzense/AitherZero" -Token "XXXX" -InstallAsService -Labels "docker,opentofu"
.NOTES
    Stage: CI/CD Infrastructure
    Dependencies: None
    Tags: github, runner, cicd, self-hosted, actions
    
    Registration token can be obtained from:
    https://github.com/OWNER/REPO/settings/actions/runners/new
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Repository,
    
    [Parameter(Mandatory)]
    [string]$Token,
    
    [string]$RunnerName,
    
    [string]$RunnerGroup = 'Default',
    
    [string]$Labels,
    
    [switch]$InstallAsService,
    
    [string]$WorkDirectory = '_work'
)

$ErrorActionPreference = 'Stop'

# Set default runner name
if (-not $RunnerName) {
    if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT') {
        $RunnerName = "$env:COMPUTERNAME-runner"
    }
    else {
        $RunnerName = "$(hostname)-runner"
    }
}

Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  GitHub Actions Self-Hosted Runner Setup" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Repository: $Repository" -ForegroundColor Gray
Write-Host "  Runner Name: $RunnerName" -ForegroundColor Gray
Write-Host "  Runner Group: $RunnerGroup" -ForegroundColor Gray
Write-Host ""

try {
    # Determine installation directory
    if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT') {
        $runnerDir = Join-Path $env:ProgramData 'GitHubRunner'
        $arch = 'win-x64'
        $ext = 'zip'
    }
    elseif ($IsLinux) {
        $runnerDir = '/opt/github-runner'
        $arch = 'linux-x64'
        $ext = 'tar.gz'
    }
    elseif ($IsMacOS) {
        $runnerDir = '/usr/local/github-runner'
        $arch = 'osx-x64'
        $ext = 'tar.gz'
    }
    
    # Create runner directory
    Write-Host "[i] Creating runner directory: $runnerDir" -ForegroundColor Cyan
    if (-not (Test-Path $runnerDir)) {
        if ($IsWindows) {
            New-Item -ItemType Directory -Path $runnerDir -Force | Out-Null
        }
        else {
            sudo mkdir -p $runnerDir
            sudo chown $env:USER $runnerDir
        }
    }
    
    # Get latest runner version
    Write-Host "[i] Fetching latest runner version..." -ForegroundColor Cyan
    $releasesUrl = 'https://api.github.com/repos/actions/runner/releases/latest'
    $latest = Invoke-RestMethod -Uri $releasesUrl -UseBasicParsing
    $version = $latest.tag_name -replace 'v', ''
    
    Write-Host "  Latest version: $version" -ForegroundColor Gray
    
    # Download runner
    $downloadUrl = "https://github.com/actions/runner/releases/download/v$version/actions-runner-$arch-$version.$ext"
    $downloadPath = Join-Path $runnerDir "actions-runner.$ext"
    
    Write-Host "[i] Downloading runner..." -ForegroundColor Cyan
    Write-Host "  URL: $downloadUrl" -ForegroundColor Gray
    
    Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -UseBasicParsing
    
    # Extract runner
    Write-Host "[i] Extracting runner..." -ForegroundColor Cyan
    Push-Location $runnerDir
    
    try {
        if ($ext -eq 'zip') {
            Expand-Archive -Path $downloadPath -DestinationPath $runnerDir -Force
        }
        else {
            tar -xzf $downloadPath
        }
        
        Remove-Item $downloadPath -Force
        
        # Make scripts executable on Unix
        if ($IsLinux -or $IsMacOS) {
            chmod +x ./config.sh
            chmod +x ./run.sh
            chmod +x ./bin/*
        }
        
        # Configure runner
        Write-Host "[i] Configuring runner..." -ForegroundColor Cyan
        
        $configArgs = @(
            '--url', "https://github.com/$Repository",
            '--token', $Token,
            '--name', $RunnerName,
            '--runnergroup', $RunnerGroup,
            '--work', $WorkDirectory,
            '--unattended',
            '--replace'
        )
        
        # Add labels if specified
        if ($Labels) {
            $allLabels = "self-hosted,$Labels"
            $configArgs += @('--labels', $allLabels)
        }
        
        if ($IsWindows) {
            & ./config.cmd @configArgs
        }
        else {
            ./config.sh @configArgs
        }
        
        Write-Host "[✓] Runner configured successfully" -ForegroundColor Green
        
        # Install as service if requested
        if ($InstallAsService) {
            Write-Host "[i] Installing runner as service..." -ForegroundColor Cyan
            
            if ($IsWindows) {
                & ./svc.cmd install
                & ./svc.cmd start
                Write-Host "[✓] Runner service installed and started" -ForegroundColor Green
            }
            elseif ($IsLinux) {
                sudo ./svc.sh install
                sudo ./svc.sh start
                Write-Host "[✓] Runner service installed and started" -ForegroundColor Green
            }
            elseif ($IsMacOS) {
                ./svc.sh install
                ./svc.sh start
                Write-Host "[✓] Runner service installed and started" -ForegroundColor Green
            }
        }
        else {
            Write-Host "[i] To run the runner:" -ForegroundColor Yellow
            Write-Host "  cd $runnerDir" -ForegroundColor Gray
            if ($IsWindows) {
                Write-Host "  ./run.cmd" -ForegroundColor Gray
            }
            else {
                Write-Host "  ./run.sh" -ForegroundColor Gray
            }
        }
        
        # Summary
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Runner Installation Complete" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Runner Directory: $runnerDir" -ForegroundColor Gray
        Write-Host "  Runner Name: $RunnerName" -ForegroundColor Gray
        Write-Host "  Status: $(if ($InstallAsService) { 'Running as service' } else { 'Ready to start' })" -ForegroundColor Green
        Write-Host ""
        
        if ($InstallAsService) {
            Write-Host "  Service commands:" -ForegroundColor Yellow
            if ($IsWindows) {
                Write-Host "    Start: cd $runnerDir && ./svc.cmd start" -ForegroundColor Gray
                Write-Host "    Stop: cd $runnerDir && ./svc.cmd stop" -ForegroundColor Gray
                Write-Host "    Status: cd $runnerDir && ./svc.cmd status" -ForegroundColor Gray
            }
            else {
                Write-Host "    Start: cd $runnerDir && sudo ./svc.sh start" -ForegroundColor Gray
                Write-Host "    Stop: cd $runnerDir && sudo ./svc.sh stop" -ForegroundColor Gray
                Write-Host "    Status: cd $runnerDir && sudo ./svc.sh status" -ForegroundColor Gray
            }
        }
        
        Write-Host ""
        
        exit 0
    }
    finally {
        Pop-Location
    }
}
catch {
    Write-Error "Failed to install GitHub runner: $($_.Exception.Message)"
    exit 1
}
