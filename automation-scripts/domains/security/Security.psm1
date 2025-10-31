#Requires -Version 7.0

# Security Module for AitherZero Platform
# Handles secure operations including SSH command execution

# Logging helper for Security module
function Write-SecurityLog {
    param(
        [string]$Level = 'Information',
        [string]$Message,
        [hashtable]$Data = @{}
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "Security" -Data $Data
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $color = @{
            'Error' = 'Red'
            'Warning' = 'Yellow' 
            'Information' = 'White'
            'Debug' = 'Gray'
        }[$Level]
        Write-Host "[$timestamp] [$($Level.ToUpper().PadRight(11))] [Security] $Message" -ForegroundColor $color
    }
}

# Log module initialization (only once)
if (-not (Get-Variable -Name "AitherZeroSecurityInitialized" -Scope Global -ErrorAction SilentlyContinue)) {
    # Cache command availability checks at module load time
    $script:TimeoutCommandAvailable = (Get-Command timeout -ErrorAction SilentlyContinue) -ne $null
    
    Write-SecurityLog -Message "Security module initialized" -Data @{
        SSHAvailable = (Get-Command ssh -ErrorAction SilentlyContinue) -ne $null
        OpenSSLAvailable = (Get-Command openssl -ErrorAction SilentlyContinue) -ne $null
        TimeoutCommandAvailable = $script:TimeoutCommandAvailable
    }
    $global:AitherZeroSecurityInitialized = $true
}

<#
.SYNOPSIS
    Executes SSH commands on remote systems with proper timeout handling

.DESCRIPTION
    Provides secure SSH command execution with configurable timeouts and error handling.
    Designed to fail fast in environments where SSH is not available or connections cannot be established.

.PARAMETER Target
    The target hostname or IP address for SSH connection

.PARAMETER Command  
    The command to execute on the remote system

.PARAMETER Port
    SSH port number (default: 22)

.PARAMETER Username
    Username for SSH authentication (optional)

.PARAMETER TimeoutSeconds
    Command timeout in seconds (default: 10)

.PARAMETER ConnectTimeoutSeconds
    Connection timeout in seconds (default: 5)

.EXAMPLE
    Invoke-SSHCommand -Target "server.com" -Command "echo test"
    
.EXAMPLE
    Invoke-SSHCommand -Target "192.168.1.100" -Command "uptime" -TimeoutSeconds 15
#>
function Invoke-SSHCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Target,
        
        [Parameter(Mandatory)]
        [string]$Command,
        
        [int]$Port = 22,
        
        [string]$Username,
        
        [int]$TimeoutSeconds = 10,
        
        [int]$ConnectTimeoutSeconds = 5
    )
    
    Write-SecurityLog -Message "Executing SSH command" -Data @{
        Target = $Target
        Command = $Command
        Port = $Port
    }
    
    # Check if SSH is available
    if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
        Write-SecurityLog -Level Error -Message "SSH command not available on this system"
        throw "SSH is not available on this system. Install OpenSSH client to use SSH functionality."
    }
    
    try {
        # Cache SSH command for later use
        $sshCommand = Get-Command ssh
        
        # Build SSH command arguments
        $sshArgs = @()
        
        # Connection timeout
        $sshArgs += '-o'
        $sshArgs += "ConnectTimeout=$ConnectTimeoutSeconds"
        
        # Disable host key checking for CI environments
        if ($env:CI -eq $true -or $env:AITHERZERO_CI -eq $true) {
            $nullDevice = if ($IsWindows) { 'NUL' } else { '/dev/null' }
            $sshArgs += '-o'
            $sshArgs += 'StrictHostKeyChecking=no'
            $sshArgs += '-o'
            $sshArgs += "UserKnownHostsFile=$nullDevice"
        }
        
        # Port specification
        if ($Port -ne 22) {
            $sshArgs += '-p'
            $sshArgs += $Port
        }
        
        # Username if provided
        if ($Username) {
            $Target = "$Username@$Target"
        }
        
        $sshArgs += $Target
        $sshArgs += $Command
        
        # Use timeout command if available (Linux/macOS), otherwise use PowerShell jobs
        if ($script:TimeoutCommandAvailable) {
            # Use system timeout for better reliability
            $timeoutCmd = "timeout"
            $allArgs = @($TimeoutSeconds, 'ssh') + $sshArgs
            
            try {
                $output = & $timeoutCmd @allArgs 2>&1
                $exitCode = $LASTEXITCODE
            } catch {
                $output = $_.Exception.Message
                $exitCode = 255
            }
        } else {
            # Fallback to PowerShell jobs on Windows
            $job = Start-Job -ScriptBlock {
                param($sshPath, $args)
                try {
                    $output = & $sshPath @args 2>&1
                    return @{
                        Output = $output
                        ExitCode = $LASTEXITCODE
                    }
                } catch {
                    return @{
                        Output = $_.Exception.Message
                        ExitCode = 255
                    }
                }
            } -ArgumentList $sshCommand.Source, $sshArgs
            
            $completed = Wait-Job $job -Timeout $TimeoutSeconds
            
            if ($completed) {
                $jobResult = Receive-Job $job
                if ($jobResult -is [hashtable]) {
                    $output = $jobResult.Output
                    $exitCode = $jobResult.ExitCode
                } else {
                    # Fallback if job returned unexpected format
                    Write-SecurityLog -Level Warning -Message "Unexpected job result format in SSH command. Fallback path taken." -Data @{
                        JobState = $job.State
                        RawJobResult = $jobResult
                        Target = $Target
                    }
                    $output = $jobResult
                    $exitCode = if ($job.State -eq 'Failed') { 255 } else { 0 }
                }
                Remove-Job $job -Force
            } else {
                Stop-Job $job -ErrorAction SilentlyContinue
                Remove-Job $job -Force -ErrorAction SilentlyContinue
                $output = "Command timed out"
                $exitCode = 124  # timeout exit code
            }
        }
        
        # Handle timeout exit code
        if ($exitCode -eq 124) {
            Write-SecurityLog -Level Error -Message "SSH command timed out" -Data @{
                Target = $Target
                TimeoutSeconds = $TimeoutSeconds
            }
            throw "SSH command timed out after $TimeoutSeconds seconds"
        }
        
        # Log non-zero exit codes
        if ($exitCode -ne 0) {
            Write-SecurityLog -Level Warning -Message "SSH command failed" -Data @{
                Target = $Target
                ExitCode = $exitCode
            }
        }
        
        return @{
            Output = $output
            ExitCode = $exitCode
            Success = $exitCode -eq 0
        }
    }
    catch {
        Write-SecurityLog -Level Error -Message "SSH command execution failed" -Data @{
            Target = $Target
            Error = $_.Exception.Message
        }
        throw
    }
}

<#
.SYNOPSIS
    Tests SSH connectivity to a remote host

.DESCRIPTION
    Performs a basic connectivity test using SSH without executing commands

.PARAMETER Target
    The target hostname or IP address

.PARAMETER Port
    SSH port number (default: 22)

.PARAMETER TimeoutSeconds
    Connection timeout in seconds (default: 5)
#>
function Test-SSHConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Target,
        
        [int]$Port = 22,
        
        [int]$TimeoutSeconds = 5
    )
    
    try {
        $result = Invoke-SSHCommand -Target $Target -Command "echo test" -Port $Port -ConnectTimeoutSeconds $TimeoutSeconds -TimeoutSeconds $TimeoutSeconds
        return $result.Success
    }
    catch {
        return $false
    }
}

# Export module functions
Export-ModuleMember -Function @(
    'Invoke-SSHCommand',
    'Test-SSHConnection'
)