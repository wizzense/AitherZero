<#
.SYNOPSIS
    Manage PR container environments with automated operations

.DESCRIPTION
    Comprehensive container management for AitherZero PR environments.
    
    This script manages the complete lifecycle of PR containers that are automatically
    built and published to GitHub Container Registry (ghcr.io) for every pull request.
    
    **What This Does:**
    - Pulls PR container images from GitHub Container Registry
    - Starts, stops, and manages container lifecycle
    - Provides interactive shell access to containers
    - Executes commands and tests in isolated PR environments
    - Monitors container logs and status
    - Handles cleanup of PR containers
    
    **Prerequisites:**
    - Docker must be installed and running
    - PR must have been built (automatic when PR is created)
    
    **Common Workflows:**
    
    1. Quick Test (Automated):
       .\0854_Manage-PRContainer.ps1 -Action QuickStart -PRNumber 1677
       
    2. Interactive Exploration:
       .\0854_Manage-PRContainer.ps1 -Action Shell -PRNumber 1677
       
    3. Run Tests:
       .\0854_Manage-PRContainer.ps1 -Action Exec -PRNumber 1677 -Command "az 0402"
       
    4. Monitor Activity:
       .\0854_Manage-PRContainer.ps1 -Action Logs -PRNumber 1677 -Follow
       
    5. Cleanup:
       .\0854_Manage-PRContainer.ps1 -Action Cleanup -PRNumber 1677

.PARAMETER Action
    Action to perform: Pull, Run, Stop, Logs, Exec, Cleanup, Status, List, QuickStart, Shell

.PARAMETER PRNumber
    Pull request number (required for most actions)

.PARAMETER Command
    Command to execute inside container (used with Exec action)

.PARAMETER ImageTag
    Custom image tag (defaults to ghcr.io/wizzense/aitherzero:pr-{PRNumber})

.PARAMETER Port
    Host port to bind (defaults to 8080 + (PRNumber % 100))
    Examples: PR #1677 → 8087, PR #1634 → 8084, PR #2500 → 8080

.PARAMETER Follow
    Follow logs in real-time (used with Logs action)

.PARAMETER Force
    Force operation even if container exists or is running

.EXAMPLE
    .\0854_Manage-PRContainer.ps1 -Action QuickStart -PRNumber 1677
    Automated setup: pull + run + verify in one command (recommended for first use)

.EXAMPLE
    .\0854_Manage-PRContainer.ps1 -Action Pull -PRNumber 1677
    Pull the container image for PR #1677 from GitHub Container Registry

.EXAMPLE
    .\0854_Manage-PRContainer.ps1 -Action Run -PRNumber 1677
    Start the container for PR #1677

.EXAMPLE
    .\0854_Manage-PRContainer.ps1 -Action Shell -PRNumber 1677
    Open interactive PowerShell shell in the container (easiest way to explore)

.EXAMPLE
    .\0854_Manage-PRContainer.ps1 -Action Exec -PRNumber 1677 -Command "az 0402"
    Execute unit tests in the running container (module auto-loads, so 'az' alias is available)

.EXAMPLE
    .\0854_Manage-PRContainer.ps1 -Action Logs -PRNumber 1677 -Follow
    View and follow container logs in real-time

.EXAMPLE
    .\0854_Manage-PRContainer.ps1 -Action Status -PRNumber 1677
    Check container status and health

.EXAMPLE
    .\0854_Manage-PRContainer.ps1 -Action List
    List all AitherZero PR containers on your system

.EXAMPLE
    .\0854_Manage-PRContainer.ps1 -Action Cleanup -PRNumber 1677
    Stop and remove the container for PR #1677

.NOTES
    Script Number: 0854
    Category: Container Management
    Required: Docker Desktop or Docker Engine
    Integration: Fully integrated with AitherZero automation system
    
    Container images are automatically built by GitHub Actions and published to:
    ghcr.io/wizzense/aitherzero:pr-{number}
    
    See DOCKER.md for complete documentation and alternative methods.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Pull', 'Run', 'Stop', 'Logs', 'Exec', 'Cleanup', 'Status', 'List', 'QuickStart', 'Shell')]
    [string]$Action,
    
    [Parameter(Mandatory = $false)]
    [int]$PRNumber,
    
    [Parameter(Mandatory = $false)]
    [string]$Command = "",
    
    [Parameter(Mandatory = $false)]
    [string]$ImageTag = "",
    
    [Parameter(Mandatory = $false)]
    [int]$Port = 0,
    
    [Parameter(Mandatory = $false)]
    [switch]$Follow,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Determine project root
$projectRoot = if ($env:AITHERZERO_ROOT) {
    $env:AITHERZERO_ROOT
} elseif ($PSScriptRoot) {
    Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
} else {
    Get-Location
}

# Import ScriptUtilities for centralized logging
$scriptUtilsPath = Join-Path $projectRoot "aithercore/automation/ScriptUtilities.psm1"
if (Test-Path $scriptUtilsPath) {
    Import-Module $scriptUtilsPath -Force -ErrorAction SilentlyContinue
}

# Script metadata
$ScriptVersion = "1.0.0"
$ScriptName = "Manage-PRContainer"

# Check if Docker is available
function Test-DockerAvailable {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-ScriptLog "Docker is not installed or not in PATH" -Level 'Error'
        Write-Host "`nInstall Docker: https://docs.docker.com/get-docker/" -ForegroundColor Yellow
        exit 1
    }
    
    try {
        $null = docker version 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-ScriptLog "Docker daemon is not running" -Level 'Error'
            Write-Host "`nStart Docker Desktop or Docker service" -ForegroundColor Yellow
            exit 1
        }
    } catch {
        Write-ScriptLog "Docker daemon is not running: $_" -Level 'Error'
        exit 1
    }
}

# Get container configuration
function Get-ContainerConfig {
    param([int]$PRNum)
    
    $containerName = "aitherzero-pr-$PRNum"
    $imageTag = if ($ImageTag) { 
        $ImageTag 
    } else { 
        "ghcr.io/wizzense/aitherzero:pr-$PRNum" 
    }
    
    $hostPort = if ($Port -gt 0) {
        $Port
    } else {
        # Dynamic port: 8080-8089 based on last digit of PR number
        $lastDigit = $PRNum % 10
        8080 + $lastDigit
    }
    
    return @{
        Name = $containerName
        Image = $imageTag
        Port = $hostPort
    }
}

# Check if container exists
function Test-ContainerExists {
    param([string]$ContainerName)
    
    $containers = docker ps -a --filter "name=^${ContainerName}$" --format "{{.Names}}" 2>$null
    return ($null -ne $containers -and $containers -eq $ContainerName)
}

# Check if container is running
function Test-ContainerRunning {
    param([string]$ContainerName)
    
    $containers = docker ps --filter "name=^${ContainerName}$" --format "{{.Names}}" 2>$null
    return ($null -ne $containers -and $containers -eq $ContainerName)
}

# Pull container image
function Invoke-PullImage {
    param([hashtable]$Config)
    
    Write-ScriptLog "Pulling image: $($Config.Image)" -Level Information
    
    try {
        docker pull $Config.Image
        
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "Image pulled successfully" -Level Information
            return $true
        } else {
            Write-ScriptLog "Failed to pull image" -Level 'Error'
            return $false
        }
    } catch {
        Write-ScriptLog "Error pulling image: $_" -Level 'Error'
        return $false
    }
}

# Run container
function Invoke-RunContainer {
    param(
        [hashtable]$Config,
        [switch]$ForceRecreate
    )
    
    Write-ScriptLog "Starting container: $($Config.Name)" -Level Information
    
    # Check if container already exists
    if (Test-ContainerExists -ContainerName $Config.Name) {
        if (Test-ContainerRunning -ContainerName $Config.Name) {
            if (-not $ForceRecreate) {
                Write-ScriptLog "Container is already running" -Level 'Warning'
                Write-Host "`nUse -Force to recreate the container" -ForegroundColor Yellow
                return $true
            }
            
            Write-ScriptLog "Stopping existing container..." -Level Information
            docker stop $Config.Name | Out-Null
        }
        
        if ($ForceRecreate) {
            Write-ScriptLog "Removing existing container..." -Level Information
            docker rm $Config.Name | Out-Null
        } else {
            Write-ScriptLog "Starting existing container..." -Level Information
            docker start $Config.Name | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                Write-ScriptLog "Container started successfully" -Level Information
                Write-Host "`nContainer is now running on port $($Config.Port)" -ForegroundColor Green
                Write-Host "Access URL: http://localhost:$($Config.Port)" -ForegroundColor Cyan
                return $true
            } else {
                Write-ScriptLog "Failed to start container" -Level 'Error'
                return $false
            }
        }
    }
    
    # Pull image if not present
    $images = docker images --format "{{.Repository}}:{{.Tag}}" | Where-Object { $_ -eq $Config.Image }
    if (-not $images) {
        Write-ScriptLog "Image not found locally, pulling..." -Level Information
        if (-not (Invoke-PullImage -Config $Config)) {
            return $false
        }
    }
    
    # Run new container
    Write-ScriptLog "Creating and starting new container..." -Level Information
    
    $runArgs = @(
        'run'
        '-d'
        '--name', $Config.Name
        '-p', "$($Config.Port):8080"
        '-e', "PR_NUMBER=$PRNumber"
        '-e', 'AITHERZERO_NONINTERACTIVE=true'
        '-e', 'AITHERZERO_CI=false'
        $Config.Image
    )
    
    try {
        docker @runArgs | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "Container started successfully" -Level Information
            
            # Wait for startup
            Write-Host "`nWaiting for container to initialize..." -ForegroundColor Cyan
            Start-Sleep -Seconds 5
            
            # Check if still running
            if (Test-ContainerRunning -ContainerName $Config.Name) {
                Write-ScriptLog "Container is healthy and running" -Level Information
                Write-Host "`n📍 Container Information:" -ForegroundColor Cyan
                Write-Host "   Name: $($Config.Name)" -ForegroundColor White
                Write-Host "   Port: $($Config.Port)" -ForegroundColor White
                Write-Host "   URL:  http://localhost:$($Config.Port)" -ForegroundColor White
                Write-Host "`n💡 Quick commands:" -ForegroundColor Cyan
                Write-Host "   Open shell: pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Shell -PRNumber $PRNumber" -ForegroundColor Gray
                Write-Host "   View logs:  pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Logs -PRNumber $PRNumber" -ForegroundColor Gray
                Write-Host "   Run tests:  pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Exec -PRNumber $PRNumber -Command 'az 0402'" -ForegroundColor Gray
                Write-Host "   Cleanup:    pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Cleanup -PRNumber $PRNumber" -ForegroundColor Gray
                return $true
            } else {
                Write-ScriptLog "Container started but exited unexpectedly" -Level 'Error'
                Write-Host "`nChecking logs..." -ForegroundColor Yellow
                docker logs $Config.Name
                return $false
            }
        } else {
            Write-ScriptLog "Failed to start container" -Level 'Error'
            return $false
        }
    } catch {
        Write-ScriptLog "Error running container: $_" -Level 'Error'
        return $false
    }
}

# Stop container
function Invoke-StopContainer {
    param([hashtable]$Config)
    
    if (-not (Test-ContainerExists -ContainerName $Config.Name)) {
        Write-ScriptLog "Container does not exist: $($Config.Name)" -Level 'Warning'
        return $true
    }
    
    if (-not (Test-ContainerRunning -ContainerName $Config.Name)) {
        Write-ScriptLog "Container is not running" -Level 'Warning'
        return $true
    }
    
    Write-ScriptLog "Stopping container: $($Config.Name)" -Level Information
    
    try {
        docker stop $Config.Name | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "Container stopped successfully" -Level Information
            return $true
        } else {
            Write-ScriptLog "Failed to stop container" -Level 'Error'
            return $false
        }
    } catch {
        Write-ScriptLog "Error stopping container: $_" -Level 'Error'
        return $false
    }
}

# View container logs
function Invoke-ViewLogs {
    param(
        [hashtable]$Config,
        [switch]$FollowLogs
    )
    
    if (-not (Test-ContainerExists -ContainerName $Config.Name)) {
        Write-ScriptLog "Container does not exist: $($Config.Name)" -Level 'Error'
        return $false
    }
    
    Write-ScriptLog "Fetching logs for: $($Config.Name)" -Level Information
    Write-Host "" # Empty line
    
    try {
        if ($FollowLogs) {
            docker logs -f $Config.Name
        } else {
            docker logs --tail 100 $Config.Name
        }
        return $true
    } catch {
        Write-ScriptLog "Error fetching logs: $_" -Level 'Error'
        return $false
    }
}

# Execute command in container
function Invoke-ExecCommand {
    param(
        [hashtable]$Config,
        [string]$Cmd
    )
    
    if (-not (Test-ContainerRunning -ContainerName $Config.Name)) {
        Write-ScriptLog "Container is not running: $($Config.Name)" -Level 'Error'
        Write-Host "`nStart the container first: pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Run -PRNumber $PRNumber" -ForegroundColor Yellow
        return $false
    }
    
    if ([string]::IsNullOrWhiteSpace($Cmd)) {
        Write-ScriptLog "No command specified" -Level 'Error'
        Write-Host "`nUsage: pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Exec -PRNumber $PRNumber -Command '<your-command>'" -ForegroundColor Yellow
        return $false
    }
    
    Write-ScriptLog "Executing command in container: $($Config.Name)" -Level Information
    Write-Host "Command: $Cmd`n" -ForegroundColor Gray
    
    try {
        # Execute command from /opt/aitherzero directory
        # Import module first so 'az' alias is available
        docker exec $Config.Name pwsh -Command "cd /opt/aitherzero; Import-Module /opt/aitherzero/AitherZero.psd1 -WarningAction SilentlyContinue; $Cmd"
        
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "`nCommand executed successfully" -Level Information
            return $true
        } else {
            Write-ScriptLog "`nCommand execution failed" -Level 'Error'
            return $false
        }
    } catch {
        Write-ScriptLog "Error executing command: $_" -Level 'Error'
        return $false
    }
}

# Cleanup container
function Invoke-CleanupContainer {
    param(
        [hashtable]$Config,
        [switch]$ForceCleanup
    )
    
    if (-not (Test-ContainerExists -ContainerName $Config.Name)) {
        Write-ScriptLog "Container does not exist: $($Config.Name)" -Level 'Warning'
        return $true
    }
    
    Write-ScriptLog "Cleaning up container: $($Config.Name)" -Level Information
    
    # Stop if running
    if (Test-ContainerRunning -ContainerName $Config.Name) {
        Write-Host "  Stopping container..." -ForegroundColor Yellow
        docker stop $Config.Name | Out-Null
    }
    
    # Remove container
    Write-Host "  Removing container..." -ForegroundColor Yellow
    try {
        docker rm $Config.Name | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog "Container cleaned up successfully" -Level Information
            
            # Optionally remove image
            if ($ForceCleanup) {
                Write-Host "  Removing image..." -ForegroundColor Yellow
                docker rmi $Config.Image 2>$null | Out-Null
            }
            
            return $true
        } else {
            Write-ScriptLog "Failed to remove container" -Level 'Error'
            return $false
        }
    } catch {
        Write-ScriptLog "Error during cleanup: $_" -Level 'Error'
        return $false
    }
}

# Get container status
function Get-ContainerStatus {
    param([hashtable]$Config)
    
    Write-Host "`n📊 Container Status" -ForegroundColor Cyan
    Write-Host "==================`n" -ForegroundColor Cyan
    
    $exists = Test-ContainerExists -ContainerName $Config.Name
    $running = Test-ContainerRunning -ContainerName $Config.Name
    
    Write-Host "Container Name: $($Config.Name)" -ForegroundColor White
    Write-Host "Image:          $($Config.Image)" -ForegroundColor White
    Write-Host "Port:           $($Config.Port)" -ForegroundColor White
    Write-Host "Exists:         $(if ($exists) { '✅ Yes' } else { '❌ No' })" -ForegroundColor $(if ($exists) { 'Green' } else { 'Red' })
    Write-Host "Running:        $(if ($running) { '✅ Yes' } else { '❌ No' })" -ForegroundColor $(if ($running) { 'Green' } else { 'Red' })
    
    if ($exists) {
        Write-Host "`nDetailed Information:" -ForegroundColor Cyan
        docker inspect --format='  State: {{.State.Status}}
  Started: {{.State.StartedAt}}
  Health: {{.State.Health.Status}}' $Config.Name 2>$null
        
        if ($running) {
            Write-Host "`n  Access URL: http://localhost:$($Config.Port)" -ForegroundColor Green
        }
    }
    
    Write-Host "" # Empty line
    return $true
}

# List all PR containers
function Get-AllPRContainers {
    Write-Host "`n📋 All PR Containers" -ForegroundColor Cyan
    Write-Host "===================`n" -ForegroundColor Cyan
    
    $containers = docker ps -a --filter "name=aitherzero-pr-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}"
    
    if ($containers) {
        Write-Host $containers
        Write-Host "" # Empty line
    } else {
        Write-Host "No PR containers found`n" -ForegroundColor Yellow
    }
    
    return $true
}

# Open interactive shell in container
function Invoke-InteractiveShell {
    param([hashtable]$Config)
    
    if (-not (Test-ContainerRunning -ContainerName $Config.Name)) {
        Write-ScriptLog "Container is not running: $($Config.Name)" -Level 'Error'
        Write-Host "`nStart the container first: pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Run -PRNumber $PRNumber" -ForegroundColor Yellow
        return $false
    }
    
    Write-ScriptLog "Opening interactive shell in: $($Config.Name)" -Level Information
    Write-Host "📝 Use Ctrl+D or type 'exit' to close the shell`n" -ForegroundColor Gray
    
    try {
        # Use the simplified docker-start.ps1 script for better UX
        # Falls back to basic pwsh if script doesn't exist
        $startScript = "pwsh /opt/aitherzero/docker-start.ps1"
        docker exec -it $Config.Name $startScript 2>$null
        
        # Fallback if docker-start.ps1 doesn't exist
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Using fallback shell access..." -ForegroundColor Yellow
            docker exec -it $Config.Name pwsh -NoProfile -WorkingDirectory /opt/aitherzero
        }
        
        return $true
    } catch {
        Write-ScriptLog "Error opening shell: $_" -Level 'Error'
        return $false
    }
}

# QuickStart - automated full workflow
function Invoke-QuickStart {
    param([hashtable]$Config)
    
    Write-Host "`n🚀 QuickStart: PR #$PRNumber" -ForegroundColor Cyan
    Write-Host "==============================`n" -ForegroundColor Cyan
    
    # Step 1: Pull
    Write-Host "[1/3] Pulling image..." -ForegroundColor Cyan
    if (-not (Invoke-PullImage -Config $Config)) {
        Write-ScriptLog "QuickStart failed at pull stage" -Level 'Error'
        return $false
    }
    
    # Step 2: Run
    Write-Host "`n[2/3] Starting container..." -ForegroundColor Cyan
    if (-not (Invoke-RunContainer -Config $Config -ForceRecreate:$Force)) {
        Write-ScriptLog "QuickStart failed at run stage" -Level 'Error'
        return $false
    }
    
    # Step 3: Status check
    Write-Host "`n[3/3] Verifying deployment..." -ForegroundColor Cyan
    Start-Sleep -Seconds 2
    Get-ContainerStatus -Config $Config
    
    Write-ScriptLog "`n✅ QuickStart complete! Container is ready for testing." -Level Information
    Write-Host "`n💡 Next steps:" -ForegroundColor Cyan
    Write-Host "   Open shell: pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Shell -PRNumber $PRNumber" -ForegroundColor Gray
    Write-Host "   Run tests:  pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Exec -PRNumber $PRNumber -Command 'az 0402'" -ForegroundColor Gray
    Write-Host "   View logs:  pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Logs -PRNumber $PRNumber" -ForegroundColor Gray
    Write-Host "   Cleanup:    pwsh automation-scripts/0854_Manage-PRContainer.ps1 -Action Cleanup -PRNumber $PRNumber" -ForegroundColor Gray
    
    return $true
}

# Main execution
function Invoke-Main {
    Write-Host "`n🐳 AitherZero Container Manager v$ScriptVersion" -ForegroundColor Cyan
    Write-Host "=========================================`n" -ForegroundColor Cyan
    
    # Check Docker availability
    Test-DockerAvailable
    
    # Validate PR number for most actions
    if ($Action -ne 'List' -and $PRNumber -le 0) {
        Write-ScriptLog "PR number is required for action: $Action" -Level 'Error'
        Write-Host "`nUsage: az 0854 -Action $Action -PRNumber <number>" -ForegroundColor Yellow
        exit 1
    }
    
    # Get container configuration
    $config = if ($PRNumber -gt 0) { Get-ContainerConfig -PRNum $PRNumber } else { $null }
    
    # Execute action
    $success = switch ($Action) {
        'Pull'       { Invoke-PullImage -Config $config }
        'Run'        { Invoke-RunContainer -Config $config -ForceRecreate:$Force }
        'Stop'       { Invoke-StopContainer -Config $config }
        'Logs'       { Invoke-ViewLogs -Config $config -FollowLogs:$Follow }
        'Exec'       { Invoke-ExecCommand -Config $config -Cmd $Command }
        'Cleanup'    { Invoke-CleanupContainer -Config $config -ForceCleanup:$Force }
        'Status'     { Get-ContainerStatus -Config $config }
        'List'       { Get-AllPRContainers }
        'Shell'      { Invoke-InteractiveShell -Config $config }
        'QuickStart' { Invoke-QuickStart -Config $config }
    }
    
    # Exit with appropriate code
    if ($success) {
        exit 0
    } else {
        exit 1
    }
}

# Execute main function
Invoke-Main
