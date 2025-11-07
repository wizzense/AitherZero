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

<#
.SYNOPSIS
    Securely converts a SecureString to plain text with proper memory cleanup

.DESCRIPTION
    Converts a SecureString to plain text while properly managing unmanaged memory.
    Immediately zeros the BSTR memory after conversion to minimize exposure time.
    This is the recommended way to convert SecureString when plain text is required.

.PARAMETER SecureString
    The SecureString to convert

.EXAMPLE
    $securePassword = Read-Host -AsSecureString
    $plainPassword = ConvertFrom-SecureStringSecurely -SecureString $securePassword

.NOTES
    This function uses proper memory cleanup with try/finally to ensure the 
    unmanaged BSTR pointer is always zeroed and freed, even if an error occurs.
#>
function ConvertFrom-SecureStringSecurely {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.Security.SecureString]$SecureString
    )
    
    if ($SecureString.Length -eq 0) {
        return [string]::Empty
    }
    
    $bstr = [IntPtr]::Zero
    try {
        # Convert SecureString to BSTR (unmanaged memory)
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        
        # Convert BSTR to managed string - use PtrToStringBSTR for proper BSTR handling
        $plainText = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        
        return $plainText
    }
    catch {
        Write-SecurityLog -Level Error -Message "Failed to convert SecureString securely" -Data @{
            Error = $_.Exception.Message
        }
        throw
    }
    finally {
        # Always zero and free the BSTR memory to minimize exposure
        if ($bstr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }
}

#region Secure Credential Management

<#
.SYNOPSIS
    Store a credential securely using PowerShell's credential store
    
.DESCRIPTION
    Securely stores credentials (username/password, API keys, tokens) using PowerShell's
    built-in SecureString and credential storage. On Windows, uses Data Protection API (DPAPI).
    On Linux/macOS, uses local file storage with restricted permissions.
    
    Credentials are stored per-user and encrypted. They persist across sessions.
    
.PARAMETER Name
    Unique identifier for the credential (e.g., "AWS-Prod", "Azure-Dev", "SSH-Server1")
    
.PARAMETER Credential
    PSCredential object containing username and password/token
    
.PARAMETER ApiKey
    API key or token to store (will be stored as SecureString)
    
.PARAMETER Force
    Overwrite existing credential with the same name
    
.EXAMPLE
    Set-AitherCredential -Name "AWS-Prod" -Credential (Get-Credential)
    
    Prompts for AWS credentials and stores them securely
    
.EXAMPLE
    $apiKey = Read-Host -AsSecureString "Enter API Key"
    Set-AitherCredential -Name "GitHub-Token" -ApiKey $apiKey
    
    Stores a GitHub API token securely
    
.EXAMPLE
    $cred = [PSCredential]::new("admin", (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force))
    Set-AitherCredential -Name "LocalAdmin" -Credential $cred -Force
    
    Stores credentials programmatically (useful in automation)
    
.OUTPUTS
    None
    
.NOTES
    Security:
    - Windows: Uses DPAPI for encryption (user-specific)
    - Linux/macOS: Uses file permissions (600) for protection
    - Credentials are stored in: ~/.aitherzero/credentials/
    - Never store credentials in code or config files
    - Use environment variables or prompt for sensitive data
    
.LINK
    Get-AitherCredential
    
.LINK
    Remove-AitherCredential
#>
function Set-AitherCredential {
    [CmdletBinding(DefaultParameterSetName = 'Credential', SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter(Mandatory, ParameterSetName = 'Credential')]
        [ValidateNotNull()]
        [PSCredential]$Credential,
        
        [Parameter(Mandatory, ParameterSetName = 'ApiKey')]
        [ValidateNotNull()]
        [SecureString]$ApiKey,
        
        [Parameter()]
        [switch]$Force
    )
    
    $credentialPath = if ($IsWindows) {
        Join-Path $env:USERPROFILE ".aitherzero/credentials"
    } else {
        Join-Path $env:HOME ".aitherzero/credentials"
    }
    
    # Create directory if it doesn't exist
    if (-not (Test-Path $credentialPath)) {
        New-Item -ItemType Directory -Path $credentialPath -Force | Out-Null
        
        # Set restrictive permissions on Linux/macOS
        if (-not $IsWindows) {
            chmod 700 $credentialPath 2>$null
        }
    }
    
    $credFile = Join-Path $credentialPath "$Name.cred"
    
    # Check if credential already exists
    if ((Test-Path $credFile) -and -not $Force) {
        throw "Credential '$Name' already exists. Use -Force to overwrite."
    }
    
    if ($PSCmdlet.ShouldProcess($Name, "Store credential")) {
        try {
            if ($PSCmdlet.ParameterSetName -eq 'Credential') {
                # Store PSCredential
                $credData = @{
                    Type = 'Credential'
                    Username = $Credential.UserName
                    Password = $Credential.Password | ConvertFrom-SecureString
                    Created = (Get-Date).ToString('o')
                }
            }
            else {
                # Store API Key
                $credData = @{
                    Type = 'ApiKey'
                    Key = $ApiKey | ConvertFrom-SecureString
                    Created = (Get-Date).ToString('o')
                }
            }
            
            # Export to encrypted file
            $credData | Export-Clixml -Path $credFile -Force
            
            # Set restrictive permissions on Linux/macOS
            if (-not $IsWindows) {
                chmod 600 $credFile 2>$null
            }
            
            Write-SecurityLog -Message "Credential stored successfully" -Data @{
                Name = $Name
                Type = $credData.Type
                Path = $credFile
            }
        }
        catch {
            Write-SecurityLog -Level Error -Message "Failed to store credential" -Data @{
                Name = $Name
                Error = $_.Exception.Message
            }
            throw
        }
    }
}

<#
.SYNOPSIS
    Retrieve a securely stored credential
    
.DESCRIPTION
    Retrieves a credential previously stored with Set-AitherCredential.
    Decrypts and returns the credential in the requested format.
    
.PARAMETER Name
    Name of the stored credential
    
.PARAMETER AsPlainText
    Return API key as plain text string (use with caution)
    
.EXAMPLE
    $cred = Get-AitherCredential -Name "AWS-Prod"
    # Use $cred with AWS cmdlets
    
.EXAMPLE
    $apiKey = Get-AitherCredential -Name "GitHub-Token" -AsPlainText
    $headers = @{ Authorization = "Bearer $apiKey" }
    
.EXAMPLE
    # Use in automation
    $sshCred = Get-AitherCredential -Name "SSH-Server1"
    Invoke-SSHCommand -Target "server.com" -Command "uptime" -Username $sshCred.UserName
    
.OUTPUTS
    [PSCredential] for stored credentials
    [SecureString] for API keys (default)
    [string] for API keys when -AsPlainText is used
    
.NOTES
    Security:
    - Credentials are decrypted in memory only
    - Use SecureString format when possible
    - Avoid -AsPlainText unless absolutely necessary
    - Credentials are user-specific and cannot be accessed by other users
    
.LINK
    Set-AitherCredential
    
.LINK
    Remove-AitherCredential
#>
function Get-AitherCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter()]
        [switch]$AsPlainText
    )
    
    $credentialPath = if ($IsWindows) {
        Join-Path $env:USERPROFILE ".aitherzero/credentials"
    } else {
        Join-Path $env:HOME ".aitherzero/credentials"
    }
    
    $credFile = Join-Path $credentialPath "$Name.cred"
    
    if (-not (Test-Path $credFile)) {
        throw "Credential '$Name' not found. Use Set-AitherCredential to store it first."
    }
    
    try {
        $credData = Import-Clixml -Path $credFile
        
        if ($credData.Type -eq 'Credential') {
            # Return PSCredential
            $password = $credData.Password | ConvertTo-SecureString
            return [PSCredential]::new($credData.Username, $password)
        }
        elseif ($credData.Type -eq 'ApiKey') {
            # Return API Key
            $secureKey = $credData.Key | ConvertTo-SecureString
            
            if ($AsPlainText) {
                return ConvertFrom-SecureStringSecurely -SecureString $secureKey
            }
            else {
                return $secureKey
            }
        }
        else {
            throw "Unknown credential type: $($credData.Type)"
        }
    }
    catch {
        Write-SecurityLog -Level Error -Message "Failed to retrieve credential" -Data @{
            Name = $Name
            Error = $_.Exception.Message
        }
        throw
    }
}

<#
.SYNOPSIS
    Remove a stored credential
    
.DESCRIPTION
    Securely removes a stored credential from the credential store.
    
.PARAMETER Name
    Name of the credential to remove
    
.PARAMETER Force
    Skip confirmation prompt
    
.EXAMPLE
    Remove-AitherCredential -Name "AWS-Prod"
    
    Removes the AWS-Prod credential after confirmation
    
.EXAMPLE
    Remove-AitherCredential -Name "OldToken" -Force
    
    Removes the credential without confirmation
    
.OUTPUTS
    None
    
.LINK
    Set-AitherCredential
    
.LINK
    Get-AitherCredential
#>
function Remove-AitherCredential {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter()]
        [switch]$Force
    )
    
    $credentialPath = if ($IsWindows) {
        Join-Path $env:USERPROFILE ".aitherzero/credentials"
    } else {
        Join-Path $env:HOME ".aitherzero/credentials"
    }
    
    $credFile = Join-Path $credentialPath "$Name.cred"
    
    if (-not (Test-Path $credFile)) {
        Write-Warning "Credential '$Name' not found."
        return
    }
    
    if ($Force -or $PSCmdlet.ShouldProcess($Name, "Remove credential")) {
        try {
            Remove-Item -Path $credFile -Force
            Write-SecurityLog -Message "Credential removed successfully" -Data @{
                Name = $Name
            }
        }
        catch {
            Write-SecurityLog -Level Error -Message "Failed to remove credential" -Data @{
                Name = $Name
                Error = $_.Exception.Message
            }
            throw
        }
    }
}

<#
.SYNOPSIS
    List all stored credentials
    
.DESCRIPTION
    Returns a list of all credentials stored in the AitherZero credential store.
    Does not return the actual credentials, only their names and metadata.
    
.EXAMPLE
    Get-AitherCredentialList
    
    Lists all stored credentials
    
.EXAMPLE
    Get-AitherCredentialList | Where-Object Type -eq 'ApiKey'
    
    Lists only API key credentials
    
.OUTPUTS
    [PSCustomObject[]] Array of credential metadata objects
    
.LINK
    Get-AitherCredential
    
.LINK
    Set-AitherCredential
#>
function Get-AitherCredentialList {
    [CmdletBinding()]
    param()
    
    $credentialPath = if ($IsWindows) {
        Join-Path $env:USERPROFILE ".aitherzero/credentials"
    } else {
        Join-Path $env:HOME ".aitherzero/credentials"
    }
    
    if (-not (Test-Path $credentialPath)) {
        Write-Verbose "No credentials stored yet."
        return @()
    }
    
    Get-ChildItem -Path $credentialPath -Filter "*.cred" | ForEach-Object {
        try {
            $credData = Import-Clixml -Path $_.FullName
            [PSCustomObject]@{
                Name = $_.BaseName
                Type = $credData.Type
                Created = $credData.Created
                Path = $_.FullName
            }
        }
        catch {
            Write-Warning "Failed to read credential: $($_.Name)"
        }
    }
}

<#
.SYNOPSIS
    Create a secure PSRemoting session with stored credentials
    
.DESCRIPTION
    Creates a PowerShell remoting session (PSSession) to a remote computer using
    stored credentials. Supports both Windows (WinRM) and Linux/macOS (SSH) targets.
    
.PARAMETER ComputerName
    Target computer name or IP address
    
.PARAMETER CredentialName
    Name of stored credential to use for authentication
    
.PARAMETER UseSSH
    Use SSH for remoting instead of WinRM (for Linux/macOS targets)
    
.PARAMETER Port
    Port number (default: 5985 for WinRM, 22 for SSH)
    
.PARAMETER UseSSL
    Use SSL for WinRM connection (port 5986)
    
.EXAMPLE
    $session = New-AitherRemoteSession -ComputerName "server01" -CredentialName "DomainAdmin"
    Invoke-Command -Session $session -ScriptBlock { Get-Service }
    
    Creates a WinRM session and runs a command
    
.EXAMPLE
    $session = New-AitherRemoteSession -ComputerName "linux-server" -CredentialName "SSH-Root" -UseSSH
    Invoke-Command -Session $session -ScriptBlock { uname -a }
    
    Creates an SSH session to a Linux server
    
.EXAMPLE
    # Batch operations across multiple servers
    $servers = "web01", "web02", "web03"
    $sessions = $servers | ForEach-Object {
        New-AitherRemoteSession -ComputerName $_ -CredentialName "WebAdmin"
    }
    Invoke-Command -Session $sessions -ScriptBlock { Restart-Service IIS }
    
.OUTPUTS
    [System.Management.Automation.Runspaces.PSSession]
    
.NOTES
    Requirements:
    - Windows targets: WinRM must be enabled
    - Linux/macOS targets: SSH server must be running, PowerShell must be installed
    - Credentials must be stored first using Set-AitherCredential
    
    Security:
    - Always use SSL/TLS for production environments
    - Verify host keys when using SSH
    - Use restricted credentials with minimal required permissions
    
.LINK
    Get-AitherCredential
    
.LINK
    Invoke-AitherRemoteCommand
#>
function New-AitherRemoteSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName,
        
        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$CredentialName,
        
        [Parameter()]
        [switch]$UseSSH,
        
        [Parameter()]
        [int]$Port,
        
        [Parameter()]
        [switch]$UseSSL
    )
    
    try {
        $credential = Get-AitherCredential -Name $CredentialName
        
        $sessionParams = @{
            ComputerName = $ComputerName
            Credential = $credential
        }
        
        if ($UseSSH) {
            $sessionParams.SSHTransport = $true
            if ($Port) {
                $sessionParams.Port = $Port
            }
        }
        else {
            # WinRM
            if ($UseSSL) {
                $sessionParams.UseSSL = $true
                $sessionParams.Port = 5986
            }
            elseif ($Port) {
                $sessionParams.Port = $Port
            }
        }
        
        Write-SecurityLog -Message "Creating remote session" -Data @{
            ComputerName = $ComputerName
            CredentialName = $CredentialName
            UseSSH = $UseSSH
            UseSSL = $UseSSL
        }
        
        $session = New-PSSession @sessionParams -ErrorAction Stop
        
        Write-SecurityLog -Message "Remote session created successfully" -Data @{
            SessionId = $session.Id
            ComputerName = $session.ComputerName
        }
        
        return $session
    }
    catch {
        Write-SecurityLog -Level Error -Message "Failed to create remote session" -Data @{
            ComputerName = $ComputerName
            Error = $_.Exception.Message
        }
        throw
    }
}

<#
.SYNOPSIS
    Execute a command on a remote computer using stored credentials
    
.DESCRIPTION
    One-liner function to execute commands on remote computers without manually
    managing PSSession objects. Automatically creates, uses, and cleans up the session.
    
.PARAMETER ComputerName
    Target computer name or IP address
    
.PARAMETER CredentialName
    Name of stored credential
    
.PARAMETER ScriptBlock
    Script block to execute remotely
    
.PARAMETER UseSSH
    Use SSH instead of WinRM
    
.PARAMETER UseSSL
    Use SSL for WinRM
    
.EXAMPLE
    Invoke-AitherRemoteCommand -ComputerName "server01" -CredentialName "Admin" -ScriptBlock { Get-Service | Where-Object Status -eq 'Running' }
    
    Runs a command remotely and returns results
    
.EXAMPLE
    # Deploy to multiple servers
    $servers = "web01", "web02", "web03"
    $servers | ForEach-Object {
        Invoke-AitherRemoteCommand -ComputerName $_ -CredentialName "Deploy" -ScriptBlock {
            Stop-Service MyApp
            Copy-Item \\share\release\*.* C:\App\
            Start-Service MyApp
        }
    }
    
.OUTPUTS
    [object] Results from the remote script block
    
.LINK
    New-AitherRemoteSession
#>
function Invoke-AitherRemoteCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName,
        
        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$CredentialName,
        
        [Parameter(Mandatory, Position = 2)]
        [ValidateNotNull()]
        [ScriptBlock]$ScriptBlock,
        
        [Parameter()]
        [switch]$UseSSH,
        
        [Parameter()]
        [switch]$UseSSL
    )
    
    $session = $null
    try {
        $sessionParams = @{
            ComputerName = $ComputerName
            CredentialName = $CredentialName
            UseSSH = $UseSSH
            UseSSL = $UseSSL
        }
        
        $session = New-AitherRemoteSession @sessionParams
        
        $result = Invoke-Command -Session $session -ScriptBlock $ScriptBlock -ErrorAction Stop
        
        return $result
    }
    catch {
        Write-SecurityLog -Level Error -Message "Remote command execution failed" -Data @{
            ComputerName = $ComputerName
            Error = $_.Exception.Message
        }
        throw
    }
    finally {
        if ($session) {
            Remove-PSSession -Session $session -ErrorAction SilentlyContinue
        }
    }
}

#endregion

# Export module functions
Export-ModuleMember -Function @(
    'Invoke-SSHCommand',
    'Test-SSHConnection',
    'ConvertFrom-SecureStringSecurely',
    'Set-AitherCredential',
    'Get-AitherCredential',
    'Remove-AitherCredential',
    'Get-AitherCredentialList',
    'New-AitherRemoteSession',
    'Invoke-AitherRemoteCommand'
)