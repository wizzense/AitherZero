#!/usr/bin/env pwsh
#requires -version 7

<#
.SYNOPSIS
    Setup GitHub Actions Self-Hosted Runners
.DESCRIPTION
    Provisions and configures GitHub Actions self-hosted runners using AitherZero infrastructure
.PARAMETER RunnerCount
    Number of runners to provision (default: 2)
.PARAMETER Platform
    Target platform: Windows, Linux, macOS, or Auto (default: Auto)
.PARAMETER Organization
    GitHub organization/owner name
.PARAMETER Repository
    Repository name (optional, for repo-level runners)
.PARAMETER RunnerGroup
    Runner group name (default: "default")
.PARAMETER Labels
    Additional runner labels (comma-separated)
.PARAMETER WorkDirectory
    Runner work directory (default: _work)
.PARAMETER Token
    GitHub Personal Access Token (will prompt if not provided)
.PARAMETER DryRun
    Validate configuration without making changes
.PARAMETER CI
    Run in CI mode with minimal output
.EXAMPLE
    ./0720_Setup-GitHubRunners.ps1 -Organization "myorg" -RunnerCount 3
.EXAMPLE
    ./0720_Setup-GitHubRunners.ps1 -Organization "myorg" -Repository "myrepo" -Platform Linux -Labels "docker,buildx"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [int]$RunnerCount = 2,
    [ValidateSet('Windows', 'Linux', 'macOS', 'Auto')]
    [string]$Platform = 'Auto',
    [Parameter(Mandatory)]
    [string]$Organization,
    [string]$Repository,
    [string]$RunnerGroup = 'default',
    [string]$Labels = '',
    [string]$WorkDirectory = '_work',
    [string]$Token,
    [switch]$DryRun,
    [switch]$CI
)

#region Metadata
$script:Stage = "Infrastructure"
$script:Dependencies = @('0001', '0207', '0210')
$script:Tags = @('github', 'runners', 'ci', 'devops')
$script:Condition = '$IsAdmin -and (Get-Command gh -ErrorAction SilentlyContinue)'
#endregion

# Import required modules and functions
if (Test-Path "$PSScriptRoot/../domains/utilities/Logging.psm1") {
    Import-Module "$PSScriptRoot/../domains/utilities/Logging.psm1" -Force
}

function Write-RunnerLog {
    param([string]$Message, [string]$Level = 'Information')
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level -Source "GitHubRunners"
    } else {
        Write-Host "[$Level] $Message"
    }
}

function Get-RunnerPlatform {
    if ($Platform -eq 'Auto') {
        if ($IsWindows) { return 'Windows' }
        elseif ($IsLinux) { return 'Linux' }
        elseif ($IsMacOS) { return 'macOS' }
        else { return 'Linux' }
    }
    return $Platform
}

function Test-Prerequisites {
    Write-RunnerLog "Checking prerequisites..." -Level Information

    $issues = @()

    # Check GitHub CLI
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        $issues += "GitHub CLI (gh) is not installed. Run: az 0207"
    }

    # Check admin permissions on Windows
    if ($IsWindows -and -not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $issues += "Administrator permissions required on Windows"
    }

    # Check sudo on Linux/macOS
    if ((-not $IsWindows) -and -not (Get-Command sudo -ErrorAction SilentlyContinue)) {
        $issues += "sudo access required on Unix systems"
    }

    if ($issues.Count -gt 0) {
        Write-RunnerLog "Prerequisites not met:" -Level Error
        $issues | ForEach-Object { Write-RunnerLog "  - $_" -Level Error }
        throw "Prerequisites validation failed"
    }

    Write-RunnerLog "Prerequisites validated successfully" -Level Success
}

function Get-GitHubToken {
    param([string]$ProvidedToken)

    if ($ProvidedToken) {
        return $ProvidedToken
    }

    # Try to get token from gh CLI
    try {
        $authStatus = gh auth status --show-token 2>&1 | Out-String
        if ($authStatus -match 'Token: (.*?)(\r|\n|$)') {
            Write-RunnerLog "Using existing GitHub CLI authentication" -Level Information
            return $Matches[1].Trim()
        }
    } catch {
        Write-RunnerLog "No existing GitHub CLI authentication found" -Level Warning
    }

    # Prompt for token
    if (-not $CI) {
        Write-Host "GitHub Personal Access Token required with 'repo' and 'admin:org' scopes"
        Write-Host "Create one at: https://github.com/settings/tokens"
        $secureToken = Read-Host "Enter token" -AsSecureString
        return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken))
    } else {
        throw "GitHub token required. Set -Token parameter or authenticate with 'gh auth login'"
    }
}

function Get-RunnerRegistrationToken {
    param(
        [string]$Organization,
        [string]$Repository,
        [string]$Token
    )

    Write-RunnerLog "Getting runner registration token..." -Level Information

    $headers = @{
        'Authorization' = "Bearer $Token"
        'Accept' = 'application/vnd.github.v3+json'
        'User-Agent' = 'AitherZero-Runner-Setup'
    }

    try {
        if ($Repository) {
            $url = "https://api.github.com/repos/$Organization/$Repository/actions/runners/registration-token"
        } else {
            $url = "https://api.github.com/orgs/$Organization/actions/runners/registration-token"
        }

        $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers
        return $response.token
    } catch {
        Write-RunnerLog "Failed to get registration token: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Install-RunnerBinary {
    param([string]$TargetPlatform)

    $runnerDir = if ($IsWindows) {
        "$env:ProgramFiles\GitHub-Runner"
    } else {
        "$env:HOME/actions-runner"
    }

    Write-RunnerLog "Installing GitHub Actions runner binary to: $runnerDir" -Level Information

    if (-not (Test-Path $runnerDir)) {
        New-Item -ItemType Directory -Path $runnerDir -Force | Out-Null
    }

    # Determine download URL based on platform
    $downloadUrl = switch ($TargetPlatform) {
        'Windows' {
            $arch = if ([System.Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
            "https://github.com/actions/runner/releases/latest/download/actions-runner-win-$arch.zip"
        }
        'Linux' {
            $arch = if ((uname -m) -eq 'x86_64') { 'x64' } else { 'arm64' }
            "https://github.com/actions/runner/releases/latest/download/actions-runner-linux-$arch.tar.gz"
        }
        'macOS' {
            $arch = if ((uname -m) -eq 'arm64') { 'arm64' } else { 'x64' }
            "https://github.com/actions/runner/releases/latest/download/actions-runner-osx-$arch.tar.gz"
        }
    }

    $downloadFile = Join-Path ([System.IO.Path]::GetTempPath()) (Split-Path $downloadUrl -Leaf)

    try {
        Write-RunnerLog "Downloading runner from: $downloadUrl" -Level Information
        Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadFile -UseBasicParsing

        Write-RunnerLog "Extracting runner binary..." -Level Information
        if ($TargetPlatform -eq 'Windows') {
            Expand-Archive -Path $downloadFile -DestinationPath $runnerDir -Force
        } else {
            Push-Location $runnerDir
            try {
                tar -xzf $downloadFile
                chmod +x ./config.sh ./run.sh
            } finally {
                Pop-Location
            }
        }

        Write-RunnerLog "Runner binary installed successfully" -Level Success
        return $runnerDir
    } catch {
        Write-RunnerLog "Failed to install runner binary: $($_.Exception.Message)" -Level Error
        throw
    } finally {
        if (Test-Path $downloadFile) {
            Remove-Item $downloadFile -Force -ErrorAction SilentlyContinue
        }
    }
}

function Register-Runner {
    param(
        [string]$RunnerDirectory,
        [string]$Organization,
        [string]$Repository,
        [string]$RegistrationToken,
        [string]$RunnerName,
        [string]$RunnerGroup,
        [string]$Labels,
        [string]$WorkDirectory
    )

    Write-RunnerLog "Registering runner: $RunnerName" -Level Information

    Push-Location $RunnerDirectory
    try {
        $configArgs = @()

        if ($Repository) {
            $configArgs += '--url', "https://github.com/$Organization/$Repository"
        } else {
            $configArgs += '--url', "https://github.com/$Organization"
        }

        $configArgs += '--token', $RegistrationToken
        $configArgs += '--name', $RunnerName
        $configArgs += '--work', $WorkDirectory
        $configArgs += '--runnergroup', $RunnerGroup

        if ($Labels) {
            $configArgs += '--labels', $Labels
        }

        $configArgs += '--unattended'

        if ($IsWindows) {
            $configScript = '.\config.cmd'
        } else {
            $configScript = './config.sh'
        }

        Write-RunnerLog "Configuring runner with command: $configScript $($configArgs -join ' ')" -Level Information

        if ($DryRun) {
            Write-RunnerLog "[DRY RUN] Would execute: $configScript $($configArgs -join ' ')" -Level Information
            return $true
        }

        & $configScript @configArgs

        if ($LASTEXITCODE -eq 0) {
            Write-RunnerLog "Runner registered successfully: $RunnerName" -Level Success
            return $true
        } else {
            Write-RunnerLog "Runner registration failed with exit code: $LASTEXITCODE" -Level Error
            return $false
        }
    } catch {
        Write-RunnerLog "Failed to register runner: $($_.Exception.Message)" -Level Error
        return $false
    } finally {
        Pop-Location
    }
}

function Install-RunnerService {
    param(
        [string]$RunnerDirectory,
        [string]$RunnerName
    )

    Write-RunnerLog "Installing runner as system service: $RunnerName" -Level Information

    if ($DryRun) {
        Write-RunnerLog "[DRY RUN] Would install runner service: $RunnerName" -Level Information
        return
    }

    Push-Location $RunnerDirectory
    try {
        if ($IsWindows) {
            # Install as Windows service
            & .\svc.sh install $RunnerName
            if ($LASTEXITCODE -eq 0) {
                & .\svc.sh start $RunnerName
                Write-RunnerLog "Windows service installed and started: $RunnerName" -Level Success
            } else {
                Write-RunnerLog "Failed to install Windows service" -Level Error
            }
        } else {
            # Install as systemd service on Linux
            & sudo ./svc.sh install $RunnerName
            if ($LASTEXITCODE -eq 0) {
                & sudo ./svc.sh start $RunnerName
                Write-RunnerLog "Systemd service installed and started: $RunnerName" -Level Success
            } else {
                Write-RunnerLog "Failed to install systemd service" -Level Error
            }
        }
    } catch {
        Write-RunnerLog "Failed to install runner service: $($_.Exception.Message)" -Level Error
    } finally {
        Pop-Location
    }
}

function Get-RunnerStatus {
    param(
        [string]$Organization,
        [string]$Repository,
        [string]$Token
    )

    $headers = @{
        'Authorization' = "Bearer $Token"
        'Accept' = 'application/vnd.github.v3+json'
    }

    try {
        if ($Repository) {
            $url = "https://api.github.com/repos/$Organization/$Repository/actions/runners"
        } else {
            $url = "https://api.github.com/orgs/$Organization/actions/runners"
        }

        $response = Invoke-RestMethod -Uri $url -Headers $headers
        return $response.runners
    } catch {
        Write-RunnerLog "Failed to get runner status: $($_.Exception.Message)" -Level Warning
        return @()
    }
}

# Main execution
try {
    Write-RunnerLog "Starting GitHub Actions runner setup..." -Level Information
    Write-RunnerLog "Organization: $Organization" -Level Information
    if ($Repository) {
        Write-RunnerLog "Repository: $Repository" -Level Information
    }
    Write-RunnerLog "Platform: $(Get-RunnerPlatform)" -Level Information
    Write-RunnerLog "Runner Count: $RunnerCount" -Level Information

    if ($DryRun) {
        Write-RunnerLog "Running in DRY RUN mode - no changes will be made" -Level Warning
    }

    # Validate prerequisites
    Test-Prerequisites

    # Get GitHub token
    $gitHubToken = Get-GitHubToken -ProvidedToken $Token

    # Get registration token
    $registrationToken = Get-RunnerRegistrationToken -Organization $Organization -Repository $Repository -Token $gitHubToken

    # Determine target platform
    $targetPlatform = Get-RunnerPlatform

    # Install runner binary
    $runnerDirectory = Install-RunnerBinary -TargetPlatform $targetPlatform

    # Setup multiple runners
    $successCount = 0
    for ($i = 1; $i -le $RunnerCount; $i++) {
        $runnerName = if ($Repository) {
            "$Organization-$Repository-runner-$i"
        } else {
            "$Organization-runner-$i"
        }

        $runnerLabels = @('self-hosted', $targetPlatform.ToLower())
        if ($Labels) {
            $runnerLabels += $Labels.Split(',').Trim()
        }
        $allLabels = $runnerLabels -join ','

        Write-RunnerLog "Setting up runner $i of $RunnerCount..." -Level Information

        if (Register-Runner -RunnerDirectory $runnerDirectory -Organization $Organization -Repository $Repository -RegistrationToken $registrationToken -RunnerName $runnerName -RunnerGroup $RunnerGroup -Labels $allLabels -WorkDirectory $WorkDirectory) {
            Install-RunnerService -RunnerDirectory $runnerDirectory -RunnerName $runnerName
            $successCount++
        }
    }

    # Display results
    Write-RunnerLog "Runner setup completed: $successCount of $RunnerCount runners configured" -Level Information

    if (-not $DryRun) {
        Start-Sleep -Seconds 2
        Write-RunnerLog "Checking runner status..." -Level Information
        $runners = Get-RunnerStatus -Organization $Organization -Repository $Repository -Token $gitHubToken

        if ($runners.Count -gt 0) {
            Write-RunnerLog "Active runners:" -Level Information
            $runners | ForEach-Object {
                $status = if ($_.status -eq 'online') { 'Success' } else { 'Warning' }
                Write-RunnerLog "  - $($_.name): $($_.status) ($($_.os))" -Level $status
            }
        }
    }

    Write-RunnerLog "GitHub Actions runner setup completed successfully!" -Level Success

    if (-not $CI) {
        Write-Host "`nNext steps:" -ForegroundColor Cyan
        Write-Host "1. Update your GitHub Actions workflows to use: runs-on: [self-hosted, $($targetPlatform.ToLower())]" -ForegroundColor White
        Write-Host "2. Add any additional labels if needed: runs-on: [self-hosted, $($targetPlatform.ToLower()), your-label]" -ForegroundColor White
        Write-Host "3. Run az 0721 to configure the runner environment" -ForegroundColor White
    }

    exit 0

} catch {
    Write-RunnerLog "Runner setup failed: $($_.Exception.Message)" -Level Error
    exit 1
}