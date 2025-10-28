<#
.SYNOPSIS
    Manage PR container environments with automated operations

.DESCRIPTION
    Comprehensive container management for AitherZero PR environments.
    Provides automated pull, run, stop, logs, exec, and cleanup operations.
    Simplifies testing PR deployments locally.

.PARAMETER Action
    Action to perform: Pull, Run, Stop, Logs, Exec, Cleanup, Status, List

.PARAMETER PRNumber
    Pull request number (required for most actions)

.PARAMETER Command
    Command to execute inside container (used with Exec action)

.PARAMETER ImageTag
    Custom image tag (defaults to ghcr.io/wizzense/aitherzero:pr-{PRNumber})

.PARAMETER Port
    Host port to bind (defaults to 808{last digit of PR number})

.PARAMETER Follow
    Follow logs in real-time (used with Logs action)

.PARAMETER Force
    Force operation even if container exists or is running

.EXAMPLE
    .\0854_Manage-PRContainer.ps1 -Action Pull -PRNumber 1634
    Pull the container image for PR #1634

.EXAMPLE
    .\0854_Manage-PRContainer.ps1 -Action Run -PRNumber 1634
    Start the container for PR #1634

.EXAMPLE
    .\0854_Manage-PRContainer.ps1 -Action Exec -PRNumber 1634 -Command "./az.ps1 0402"
    Execute tests in the running container

.EXAMPLE
    .\0854_Manage-PRContainer.ps1 -Action Logs -PRNumber 1634 -Follow
    View and follow container logs

.EXAMPLE
    .\0854_Manage-PRContainer.ps1 -Action Status -PRNumber 1634
    Check container status

.EXAMPLE
    .\0854_Manage-PRContainer.ps1 -Action Shell -PRNumber 1634
    Open interactive shell in the running container

.EXAMPLE
    .\0854_Manage-PRContainer.ps1 -Action List
    List all PR containers

.EXAMPLE
    .\0854_Manage-PRContainer.ps1 -Action QuickStart -PRNumber 1634
    Automated setup: pull + run + verify in one command

.NOTES
    Script Number: 0854
    Category: Container Management
    Required: Docker
    Integration: Fully integrated with AitherZero automation system
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

# Script metadata
$ScriptVersion = "1.0.0"
$ScriptName = "Manage-PRContainer"

# Helper function for logging
function Write-LogMessage {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $colors = @{
        'Info' = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error' = 'Red'
    }
    
    $icons = @{
        'Info' = 'ℹ️'
        'Success' = '✅'
        'Warning' = '⚠️'
        'Error' = '❌'
    }
    
    $color = $colors[$Level]
    $icon = $icons[$Level]
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level
    }
    
    Write-Host "$icon $Message" -ForegroundColor $color
}

# Check if Docker is available
function Test-DockerAvailable {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-LogMessage "Docker is not installed or not in PATH" -Level 'Error'
        Write-Host "`nInstall Docker: https://docs.docker.com/get-docker/" -ForegroundColor Yellow
        exit 1
    }
    
    try {
        $null = docker version 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-LogMessage "Docker daemon is not running" -Level 'Error'
            Write-Host "`nStart Docker Desktop or Docker service" -ForegroundColor Yellow
            exit 1
        }
    } catch {
        Write-LogMessage "Docker daemon is not running: $_" -Level 'Error'
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
    
    Write-LogMessage "Pulling image: $($Config.Image)" -Level 'Info'
    
    try {
        docker pull $Config.Image
        
        if ($LASTEXITCODE -eq 0) {
            Write-LogMessage "Image pulled successfully" -Level 'Success'
            return $true
        } else {
            Write-LogMessage "Failed to pull image" -Level 'Error'
            return $false
        }
    } catch {
        Write-LogMessage "Error pulling image: $_" -Level 'Error'
        return $false
    }
}

# Run container
function Invoke-RunContainer {
    param(
        [hashtable]$Config,
        [switch]$ForceRecreate
    )
    
    Write-LogMessage "Starting container: $($Config.Name)" -Level 'Info'
    
    # Check if container already exists
    if (Test-ContainerExists -ContainerName $Config.Name) {
        if (Test-ContainerRunning -ContainerName $Config.Name) {
            if (-not $ForceRecreate) {
                Write-LogMessage "Container is already running" -Level 'Warning'
                Write-Host "`nUse -Force to recreate the container" -ForegroundColor Yellow
                return $true
            }
            
            Write-LogMessage "Stopping existing container..." -Level 'Info'
            docker stop $Config.Name | Out-Null
        }
        
        if ($ForceRecreate) {
            Write-LogMessage "Removing existing container..." -Level 'Info'
            docker rm $Config.Name | Out-Null
        } else {
            Write-LogMessage "Starting existing container..." -Level 'Info'
            docker start $Config.Name | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                Write-LogMessage "Container started successfully" -Level 'Success'
                Write-Host "`nContainer is now running on port $($Config.Port)" -ForegroundColor Green
                Write-Host "Access URL: http://localhost:$($Config.Port)" -ForegroundColor Cyan
                return $true
            } else {
                Write-LogMessage "Failed to start container" -Level 'Error'
                return $false
            }
        }
    }
    
    # Pull image if not present
    $images = docker images --format "{{.Repository}}:{{.Tag}}" | Where-Object { $_ -eq $Config.Image }
    if (-not $images) {
        Write-LogMessage "Image not found locally, pulling..." -Level 'Info'
        if (-not (Invoke-PullImage -Config $Config)) {
            return $false
        }
    }
    
    # Run new container
    Write-LogMessage "Creating and starting new container..." -Level 'Info'
    
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
            Write-LogMessage "Container started successfully" -Level 'Success'
            
            # Wait for startup
            Write-Host "`nWaiting for container to initialize..." -ForegroundColor Cyan
            Start-Sleep -Seconds 5
            
            # Check if still running
            if (Test-ContainerRunning -ContainerName $Config.Name) {
                Write-LogMessage "Container is healthy and running" -Level 'Success'
                Write-Host "`n📍 Container Information:" -ForegroundColor Cyan
                Write-Host "   Name: $($Config.Name)" -ForegroundColor White
                Write-Host "   Port: $($Config.Port)" -ForegroundColor White
                Write-Host "   URL:  http://localhost:$($Config.Port)" -ForegroundColor White
                Write-Host "`n💡 Quick commands:" -ForegroundColor Cyan
                Write-Host "   Open shell: az 0854 -Action Shell -PRNumber $PRNumber" -ForegroundColor Gray
                Write-Host "   View logs:  az 0854 -Action Logs -PRNumber $PRNumber" -ForegroundColor Gray
                Write-Host "   Run tests:  az 0854 -Action Exec -PRNumber $PRNumber -Command './az.ps1 0402'" -ForegroundColor Gray
                Write-Host "   Cleanup:    az 0854 -Action Cleanup -PRNumber $PRNumber" -ForegroundColor Gray
                return $true
            } else {
                Write-LogMessage "Container started but exited unexpectedly" -Level 'Error'
                Write-Host "`nChecking logs..." -ForegroundColor Yellow
                docker logs $Config.Name
                return $false
            }
        } else {
            Write-LogMessage "Failed to start container" -Level 'Error'
            return $false
        }
    } catch {
        Write-LogMessage "Error running container: $_" -Level 'Error'
        return $false
    }
}

# Stop container
function Invoke-StopContainer {
    param([hashtable]$Config)
    
    if (-not (Test-ContainerExists -ContainerName $Config.Name)) {
        Write-LogMessage "Container does not exist: $($Config.Name)" -Level 'Warning'
        return $true
    }
    
    if (-not (Test-ContainerRunning -ContainerName $Config.Name)) {
        Write-LogMessage "Container is not running" -Level 'Warning'
        return $true
    }
    
    Write-LogMessage "Stopping container: $($Config.Name)" -Level 'Info'
    
    try {
        docker stop $Config.Name | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-LogMessage "Container stopped successfully" -Level 'Success'
            return $true
        } else {
            Write-LogMessage "Failed to stop container" -Level 'Error'
            return $false
        }
    } catch {
        Write-LogMessage "Error stopping container: $_" -Level 'Error'
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
        Write-LogMessage "Container does not exist: $($Config.Name)" -Level 'Error'
        return $false
    }
    
    Write-LogMessage "Fetching logs for: $($Config.Name)" -Level 'Info'
    Write-Host "" # Empty line
    
    try {
        if ($FollowLogs) {
            docker logs -f $Config.Name
        } else {
            docker logs --tail 100 $Config.Name
        }
        return $true
    } catch {
        Write-LogMessage "Error fetching logs: $_" -Level 'Error'
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
        Write-LogMessage "Container is not running: $($Config.Name)" -Level 'Error'
        Write-Host "`nStart the container first: az 0854 -Action Run -PRNumber $PRNumber" -ForegroundColor Yellow
        return $false
    }
    
    if ([string]::IsNullOrWhiteSpace($Cmd)) {
        Write-LogMessage "No command specified" -Level 'Error'
        Write-Host "`nUsage: az 0854 -Action Exec -PRNumber $PRNumber -Command '<your-command>'" -ForegroundColor Yellow
        return $false
    }
    
    Write-LogMessage "Executing command in container: $($Config.Name)" -Level 'Info'
    Write-Host "Command: $Cmd`n" -ForegroundColor Gray
    
    try {
        # Execute command from /opt/aitherzero directory
        docker exec $Config.Name pwsh -Command "cd /opt/aitherzero; $Cmd"
        
        if ($LASTEXITCODE -eq 0) {
            Write-LogMessage "`nCommand executed successfully" -Level 'Success'
            return $true
        } else {
            Write-LogMessage "`nCommand execution failed" -Level 'Error'
            return $false
        }
    } catch {
        Write-LogMessage "Error executing command: $_" -Level 'Error'
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
        Write-LogMessage "Container does not exist: $($Config.Name)" -Level 'Warning'
        return $true
    }
    
    Write-LogMessage "Cleaning up container: $($Config.Name)" -Level 'Info'
    
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
            Write-LogMessage "Container cleaned up successfully" -Level 'Success'
            
            # Optionally remove image
            if ($ForceCleanup) {
                Write-Host "  Removing image..." -ForegroundColor Yellow
                docker rmi $Config.Image 2>$null | Out-Null
            }
            
            return $true
        } else {
            Write-LogMessage "Failed to remove container" -Level 'Error'
            return $false
        }
    } catch {
        Write-LogMessage "Error during cleanup: $_" -Level 'Error'
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
        Write-LogMessage "Container is not running: $($Config.Name)" -Level 'Error'
        Write-Host "`nStart the container first: az 0854 -Action Run -PRNumber $PRNumber" -ForegroundColor Yellow
        return $false
    }
    
    Write-LogMessage "Opening interactive shell in: $($Config.Name)" -Level 'Info'
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
        Write-LogMessage "Error opening shell: $_" -Level 'Error'
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
        Write-LogMessage "QuickStart failed at pull stage" -Level 'Error'
        return $false
    }
    
    # Step 2: Run
    Write-Host "`n[2/3] Starting container..." -ForegroundColor Cyan
    if (-not (Invoke-RunContainer -Config $Config -ForceRecreate:$Force)) {
        Write-LogMessage "QuickStart failed at run stage" -Level 'Error'
        return $false
    }
    
    # Step 3: Status check
    Write-Host "`n[3/3] Verifying deployment..." -ForegroundColor Cyan
    Start-Sleep -Seconds 2
    Get-ContainerStatus -Config $Config
    
    Write-LogMessage "`n✅ QuickStart complete! Container is ready for testing." -Level 'Success'
    Write-Host "`n💡 Next steps:" -ForegroundColor Cyan
    Write-Host "   Open shell: az 0854 -Action Shell -PRNumber $PRNumber" -ForegroundColor Gray
    Write-Host "   Run tests:  az 0854 -Action Exec -PRNumber $PRNumber -Command './az.ps1 0402'" -ForegroundColor Gray
    Write-Host "   View logs:  az 0854 -Action Logs -PRNumber $PRNumber" -ForegroundColor Gray
    Write-Host "   Cleanup:    az 0854 -Action Cleanup -PRNumber $PRNumber" -ForegroundColor Gray
    
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
        Write-LogMessage "PR number is required for action: $Action" -Level 'Error'
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
