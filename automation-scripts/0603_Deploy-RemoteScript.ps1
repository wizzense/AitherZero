#Requires -Version 7.0

<#
.SYNOPSIS
    Deploy and execute scripts on remote hosts via SSH
.DESCRIPTION
    Copy scripts to remote infrastructure hosts and execute them securely over SSH.
    Part of AitherZero Infrastructure Automation Platform.
.PARAMETER ProfileName
    Name of the connection profile to use
.PARAMETER ScriptPath
    Path to the local script to deploy and execute
.PARAMETER Arguments
    Arguments to pass to the remote script
.PARAMETER WorkingDirectory
    Remote working directory (default: /tmp/aitherzero)
.PARAMETER RemoveAfterExecution
    Remove script from remote host after execution
.PARAMETER ShowOutput
    Display script output in real-time
.PARAMETER Configuration
    Configuration object containing settings
.EXAMPLE
    ./0603_Deploy-RemoteScript.ps1 -ProfileName "web-server-01" -ScriptPath "./scripts/update-system.sh" -RemoveAfterExecution
.EXAMPLE
    ./0603_Deploy-RemoteScript.ps1 -ProfileName "db-server" -ScriptPath "./scripts/backup-database.sh" -Arguments @("daily", "compress")
.NOTES
    Copyright © 2025 Aitherium Corporation
    Script Range: 0600-0699 (Security and Credentials)
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ProfileName,
    
    [Parameter(Mandatory)]
    [string]$ScriptPath,
    
    [string[]]$Arguments = @(),
    
    [string]$WorkingDirectory = '/tmp/aitherzero',
    
    [switch]$RemoveAfterExecution,
    
    [switch]$ShowOutput,
    
    [hashtable]$Configuration = @{}
)

# Import required functions
if (-not (Get-Command Write-ScriptLog -ErrorAction SilentlyContinue)) {
    function Write-ScriptLog {
        param([string]$Level = 'Information', [string]$Message, [string]$Source = 'Script', [hashtable]$Data = @{})
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] [$Level] [$Source] $Message"
    }
}

# Get configuration values
$config = if ($Configuration.Count -gt 0) { $Configuration } else { @{} }
$deploymentConfig = if ($config.Security -and $config.Security.RemoteDeployment) { $config.Security.RemoteDeployment } else { @{} }

# Override defaults with configuration
if ($deploymentConfig.ScriptDeployment -and $deploymentConfig.ScriptDeployment.RemoteDirectory) {
    $WorkingDirectory = $deploymentConfig.ScriptDeployment.RemoteDirectory
}

try {
    Write-ScriptLog -Message "Starting remote script deployment" -Data @{
        ProfileName = $ProfileName
        ScriptPath = $ScriptPath
        Arguments = $Arguments -join " "
        WorkingDirectory = $WorkingDirectory
    }
    
    # Validate script exists
    if (-not (Test-Path $ScriptPath)) {
        throw "Script not found: $ScriptPath"
    }
    
    # Check if Security module is available
    if (-not (Get-Command Invoke-RemoteScript -ErrorAction SilentlyContinue)) {
        Write-ScriptLog -Level Warning -Message "Security module not loaded, attempting to import"
        
        $securityModulePath = Join-Path $PSScriptRoot "../domains/security/Security.psm1"
        if (Test-Path $securityModulePath) {
            Import-Module $securityModulePath -Force
        } else {
            throw "Security module not found. Please ensure AitherZero is properly initialized."
        }
    }
    
    # Get and validate connection profile
    $profile = Get-ConnectionProfile -ProfileName $ProfileName
    if (-not $profile) {
        throw "Connection profile '$ProfileName' not found. Use 0602_Manage-ConnectionProfiles.ps1 to create profiles."
    }
    
    Write-Host ""
    Write-Host "Remote Script Deployment" -ForegroundColor Cyan
    Write-Host "========================" -ForegroundColor Cyan
    Write-Host "Profile: $($profile.ProfileName)" -ForegroundColor White
    Write-Host "Target: $($profile.Hostname):$($profile.Port)" -ForegroundColor White
    Write-Host "Script: $ScriptPath" -ForegroundColor White
    Write-Host "Remote Directory: $WorkingDirectory" -ForegroundColor White
    Write-Host ""
    
    # Test connection first
    Write-Host "Testing connection..." -ForegroundColor Yellow
    $connectionTest = Test-SSHConnection -ProfileName $ProfileName -TimeoutSeconds 10
    
    if (-not $connectionTest) {
        throw "Cannot connect to remote host. Please check the connection profile and network connectivity."
    }
    
    Write-Host "✓ Connection successful" -ForegroundColor Green
    Write-Host ""
    
    # Prepare remote directory if needed
    Write-Host "Preparing remote environment..." -ForegroundColor Yellow
    $prepareDirCommand = "mkdir -p '$WorkingDirectory' && cd '$WorkingDirectory'"
    $prepareDirResult = Invoke-SSHCommand -ProfileName $ProfileName -Command $prepareDirCommand
    
    if (-not $prepareDirResult.Success) {
        Write-ScriptLog -Level Warning -Message "Failed to prepare remote directory, continuing anyway"
    }
    
    # Deploy and execute script
    Write-Host "Deploying and executing script..." -ForegroundColor Yellow
    Write-Host ""
    
    $executeParams = @{
        ProfileName = $ProfileName
        ScriptPath = $ScriptPath
        WorkingDirectory = $WorkingDirectory
        RemoveAfterExecution = $RemoveAfterExecution
    }
    
    if ($Arguments.Count -gt 0) {
        $executeParams.Arguments = $Arguments
    }
    
    $result = Invoke-RemoteScript @executeParams
    
    if ($result.Success) {
        Write-Host "Script Execution Successful!" -ForegroundColor Green
        Write-Host "============================" -ForegroundColor Green
        Write-Host "Exit Code: $($result.ExitCode)" -ForegroundColor White
        Write-Host ""
        
        if ($ShowOutput -or $result.Output) {
            Write-Host "Output:" -ForegroundColor Cyan
            Write-Host "-------" -ForegroundColor Cyan
            if ($result.Output) {
                Write-Host $result.Output -ForegroundColor Gray
            } else {
                Write-Host "(No output)" -ForegroundColor DarkGray
            }
            Write-Host ""
        }
        
        Write-ScriptLog -Message "Remote script execution completed successfully" -Data @{
            ProfileName = $ProfileName
            ScriptPath = $ScriptPath
            ExitCode = $result.ExitCode
            RemoteCommand = $result.Command
        }
        
        return @{
            Success = $true
            Message = "Script executed successfully"
            Result = $result
            Profile = $profile
        }
    } else {
        Write-Host "Script Execution Failed!" -ForegroundColor Red
        Write-Host "========================" -ForegroundColor Red
        Write-Host "Exit Code: $($result.ExitCode)" -ForegroundColor White
        Write-Host ""
        
        if ($result.Output) {
            Write-Host "Error Output:" -ForegroundColor Red
            Write-Host "-------------" -ForegroundColor Red
            Write-Host $result.Output -ForegroundColor Gray
            Write-Host ""
        }
        
        Write-ScriptLog -Level Error -Message "Remote script execution failed" -Data @{
            ProfileName = $ProfileName
            ScriptPath = $ScriptPath
            ExitCode = $result.ExitCode
            Output = $result.Output
        }
        
        return @{
            Success = $false
            Message = "Script execution failed"
            Result = $result
            Profile = $profile
        }
    }
}
catch {
    Write-ScriptLog -Level Error -Message "Remote script deployment failed: $_"
    
    Write-Host ""
    Write-Host "Remote Script Deployment Failed!" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    
    # Show helpful information
    Write-Host "Troubleshooting Tips:" -ForegroundColor Yellow
    Write-Host "- Verify the connection profile exists: az 0602 -Action list" -ForegroundColor Gray
    Write-Host "- Test the connection: az 0602 -Action test -ProfileName '$ProfileName'" -ForegroundColor Gray
    Write-Host "- Check script path: $ScriptPath" -ForegroundColor Gray
    Write-Host "- Ensure SSH keys are properly set up" -ForegroundColor Gray
    Write-Host ""
    
    return @{
        Success = $false
        Message = "Deployment failed: $_"
        Error = $_
    }
}