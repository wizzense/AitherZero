#!/usr/bin/env pwsh
#requires -version 7

<#
.SYNOPSIS
    Deploy AitherZero Self-Hosted Runner with Persistent Main Branch Deployment
.DESCRIPTION
    Automates the deployment of a self-hosted GitHub Actions runner with an always-on
    main branch deployment. Uses the infrastructure in infrastructure/self-hosted-runner/.
.PARAMETER InstallPath
    Installation path for the runner (default: /opt/aitherzero-runner)
.PARAMETER GitHubToken
    GitHub Personal Access Token with repo and workflow scopes
.PARAMETER Organization
    GitHub organization/owner name (default: wizzense)
.PARAMETER Repository
    Repository name (default: AitherZero)
.PARAMETER RunnerName
    Name for the self-hosted runner (default: aitherzero-main-runner)
.PARAMETER RunnerLabels
    Comma-separated runner labels (default: self-hosted,linux,x64,aitherzero,main-deployment)
.PARAMETER DeploymentPort
    Port for main deployment web dashboard (default: 8080)
.PARAMETER SkipDocker
    Skip Docker installation if already present
.PARAMETER DryRun
    Validate configuration without making changes
.PARAMETER NonInteractive
    Run in non-interactive mode
.EXAMPLE
    ./0724_Deploy-SelfHostedRunner.ps1 -GitHubToken "ghp_xxx"
.EXAMPLE
    ./0724_Deploy-SelfHostedRunner.ps1 -Organization "myorg" -Repository "myrepo" -RunnerName "prod-runner"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$InstallPath = '/opt/aitherzero-runner',
    [Parameter(Mandatory)]
    [string]$GitHubToken,
    [string]$Organization = 'wizzense',
    [string]$Repository = 'AitherZero',
    [string]$RunnerName = 'aitherzero-main-runner',
    [string]$RunnerLabels = 'self-hosted,linux,x64,aitherzero,main-deployment',
    [int]$DeploymentPort = 8080,
    [switch]$SkipDocker,
    [switch]$DryRun,
    [switch]$NonInteractive
)

#region Metadata
$script:Stage = "Infrastructure"
$script:Dependencies = @('0001')
$script:Tags = @('github', 'runners', 'self-hosted', 'docker', 'deployment')
$script:Condition = '$IsLinux'
#endregion

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Initialize
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:InfrastructurePath = Join-Path $script:ProjectRoot "infrastructure/self-hosted-runner"

# Import logging if available
if (Test-Path "$script:ProjectRoot/domains/utilities/Logging.psm1") {
    Import-Module "$script:ProjectRoot/domains/utilities/Logging.psm1" -Force
}

function Write-DeployLog {
    param([string]$Message, [string]$Level = 'Information')
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level -Source "SelfHostedRunner"
    } else {
        $color = switch ($Level) {
            'Success' { 'Green' }
            'Warning' { 'Yellow' }
            'Error' { 'Red' }
            default { 'White' }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
}

function Test-Prerequisites {
    Write-DeployLog "Checking prerequisites..." -Level Information

    $issues = @()

    # Check Linux platform
    if (-not $IsLinux) {
        $issues += "This script requires Linux. For other platforms, see docs/SELF-HOSTED-RUNNER-SETUP.md"
    }

    # Check root/sudo access
    if ($env:USER -ne 'root' -and -not (Get-Command sudo -ErrorAction SilentlyContinue)) {
        $issues += "Root or sudo access required"
    }

    # Check infrastructure files
    if (-not (Test-Path $script:InfrastructurePath)) {
        $issues += "Infrastructure path not found: $script:InfrastructurePath"
    }

    $requiredFiles = @(
        'install-runner.sh',
        'docker-compose.yml',
        '.env.example'
    )

    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $script:InfrastructurePath $file
        if (-not (Test-Path $filePath)) {
            $issues += "Required file missing: $file"
        }
    }

    if ($issues.Count -gt 0) {
        Write-DeployLog "Prerequisites not met:" -Level Error
        $issues | ForEach-Object { Write-DeployLog "  - $_" -Level Error }
        throw "Prerequisites validation failed"
    }

    Write-DeployLog "Prerequisites validated successfully" -Level Success
}

function New-EnvConfiguration {
    param(
        [string]$OutputPath
    )

    Write-DeployLog "Creating configuration file..." -Level Information

    $envContent = @"
# GitHub Configuration
GITHUB_OWNER=$Organization
GITHUB_REPO=$Repository
GITHUB_TOKEN=$GitHubToken

# Runner Configuration
RUNNER_NAME=$RunnerName
RUNNER_LABELS=$RunnerLabels
RUNNER_WORKDIR=/runner/_work
RUNNER_GROUP=default

# Deployment Configuration
DEPLOYMENT_PORT=$DeploymentPort
DEPLOYMENT_HTTPS_PORT=8443
DEPLOYMENT_AUTO_UPDATE=true
DEPLOYMENT_BRANCH=main

# Resource Limits
RUNNER_CPU_LIMIT=2
RUNNER_MEMORY_LIMIT=4G
DEPLOYMENT_CPU_LIMIT=2
DEPLOYMENT_MEMORY_LIMIT=2G

# Logging
LOG_LEVEL=info
LOG_RETENTION_DAYS=7

# Auto-update Settings
AUTO_UPDATE_ENABLED=true
AUTO_UPDATE_SCHEDULE=daily
AUTO_UPDATE_TIME=02:00
"@

    $envContent | Set-Content -Path $OutputPath -Force
    
    # Secure the file
    if ($IsLinux) {
        chmod 600 $OutputPath 2>&1 | Out-Null
    }

    Write-DeployLog "Configuration file created: $OutputPath" -Level Success
}

function Invoke-Installation {
    Write-DeployLog "Starting installation..." -Level Information

    if ($DryRun) {
        Write-DeployLog "DRY RUN: Would execute installation" -Level Warning
        return
    }

    $installScript = Join-Path $script:InfrastructurePath "install-runner.sh"
    
    if (-not (Test-Path $installScript)) {
        throw "Installation script not found: $installScript"
    }

    # Make script executable
    chmod +x $installScript 2>&1 | Out-Null

    # Execute installation
    $sudoCmd = if ($env:USER -ne 'root') { 'sudo' } else { '' }
    
    Write-DeployLog "Executing installation script with sudo..." -Level Information
    
    $process = Start-Process -FilePath $sudoCmd -ArgumentList $installScript -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -ne 0) {
        throw "Installation failed with exit code: $($process.ExitCode)"
    }

    Write-DeployLog "Installation completed successfully" -Level Success
}

function Test-Installation {
    Write-DeployLog "Verifying installation..." -Level Information

    $checks = @()

    # Check systemd service
    $serviceStatus = systemctl is-active aitherzero-runner 2>&1
    if ($LASTEXITCODE -eq 0 -and $serviceStatus -eq 'active') {
        Write-DeployLog "✓ Systemd service is active" -Level Success
        $checks += $true
    } else {
        Write-DeployLog "✗ Systemd service is not active" -Level Error
        $checks += $false
    }

    # Check containers
    $runnerContainer = docker ps --filter "name=aitherzero-runner" --format "{{.Names}}" 2>&1
    if ($runnerContainer -eq 'aitherzero-runner') {
        Write-DeployLog "✓ Runner container is running" -Level Success
        $checks += $true
    } else {
        Write-DeployLog "✗ Runner container is not running" -Level Error
        $checks += $false
    }

    $mainContainer = docker ps --filter "name=aitherzero-main" --format "{{.Names}}" 2>&1
    if ($mainContainer -eq 'aitherzero-main') {
        Write-DeployLog "✓ Main deployment container is running" -Level Success
        $checks += $true
    } else {
        Write-DeployLog "✗ Main deployment container is not running" -Level Error
        $checks += $false
    }

    # Check web interface
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$DeploymentPort" -TimeoutSec 5 -ErrorAction Stop
        if ($response.StatusCode -in @(200, 301, 302)) {
            Write-DeployLog "✓ Web interface is accessible on port $DeploymentPort" -Level Success
            $checks += $true
        }
    } catch {
        Write-DeployLog "✗ Web interface is not accessible on port $DeploymentPort" -Level Error
        $checks += $false
    }

    $allPassed = $checks -notcontains $false

    if ($allPassed) {
        Write-DeployLog "All verification checks passed!" -Level Success
        return $true
    } else {
        Write-DeployLog "Some verification checks failed. Review logs above." -Level Warning
        return $false
    }
}

function Show-DeploymentInfo {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Self-Hosted Runner Deployment Complete" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Installation Path: " -NoNewline
    Write-Host $InstallPath -ForegroundColor White
    Write-Host ""
    Write-Host "Access Points:" -ForegroundColor Cyan
    Write-Host "  • Web Dashboard:  " -NoNewline -ForegroundColor White
    Write-Host "http://localhost:$DeploymentPort" -ForegroundColor Yellow
    Write-Host "  • Runner Status:  " -NoNewline -ForegroundColor White
    Write-Host "https://github.com/$Organization/$Repository/settings/actions/runners" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Management Commands:" -ForegroundColor Cyan
    Write-Host "  • Service:  " -NoNewline -ForegroundColor White
    Write-Host "sudo systemctl start|stop|restart aitherzero-runner" -ForegroundColor Yellow
    Write-Host "  • Logs:     " -NoNewline -ForegroundColor White
    Write-Host "docker logs -f aitherzero-runner" -ForegroundColor Yellow
    Write-Host "  • Update:   " -NoNewline -ForegroundColor White
    Write-Host "sudo $InstallPath/scripts/update-main.sh" -ForegroundColor Yellow
    Write-Host "  • Health:   " -NoNewline -ForegroundColor White
    Write-Host "$InstallPath/scripts/health-check.sh" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Documentation:" -ForegroundColor Cyan
    Write-Host "  • Setup Guide:      " -NoNewline -ForegroundColor White
    Write-Host "docs/SELF-HOSTED-RUNNER-SETUP.md" -ForegroundColor Yellow
    Write-Host "  • Quick Reference:  " -NoNewline -ForegroundColor White
    Write-Host "docs/SELF-HOSTED-RUNNER-QUICKREF.md" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

#region Main Execution
try {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Blue
    Write-Host "║  AitherZero Self-Hosted Runner Deployment                ║" -ForegroundColor Blue
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Blue
    Write-Host ""

    # Step 1: Validate prerequisites
    Test-Prerequisites

    # Step 2: Navigate to infrastructure directory
    Push-Location $script:InfrastructurePath
    
    try {
        # Step 3: Create .env configuration
        $envPath = Join-Path $script:InfrastructurePath ".env"
        New-EnvConfiguration -OutputPath $envPath

        # Step 4: Execute installation
        Invoke-Installation

        # Step 5: Wait for containers to start
        if (-not $DryRun) {
            Write-DeployLog "Waiting for containers to initialize..." -Level Information
            Start-Sleep -Seconds 10
        }

        # Step 6: Verify installation
        if (-not $DryRun) {
            $verificationPassed = Test-Installation
            
            if (-not $verificationPassed) {
                Write-DeployLog "Installation completed but some checks failed. Review the output above." -Level Warning
            }
        }

        # Step 7: Show deployment information
        Show-DeploymentInfo

        Write-DeployLog "Deployment script completed successfully" -Level Success
        exit 0

    } finally {
        Pop-Location
    }

} catch {
    Write-DeployLog "Deployment failed: $_" -Level Error
    Write-DeployLog $_.ScriptStackTrace -Level Error
    
    if (-not $DryRun) {
        Write-Host ""
        Write-Host "Troubleshooting:" -ForegroundColor Yellow
        Write-Host "  1. Check logs: sudo journalctl -u aitherzero-runner -n 50" -ForegroundColor White
        Write-Host "  2. Check containers: docker ps -a | grep aitherzero" -ForegroundColor White
        Write-Host "  3. Review documentation: docs/SELF-HOSTED-RUNNER-SETUP.md" -ForegroundColor White
        Write-Host ""
    }
    
    exit 1
}
#endregion
