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

#region GitHub-Based Credential Storage

<#
.SYNOPSIS
    Store credentials in a private GitHub repository
    
.DESCRIPTION
    Stores encrypted credentials in a private GitHub repository for team sharing.
    Requires authentication to access. Uses GitHub's private repository features
    to securely store and version control credentials.
    
    This is useful for:
    - Team credential sharing (DevOps teams)
    - Cross-environment credential synchronization
    - Audit trail and version history of credential changes
    - Centralized credential management
    
.PARAMETER Name
    Credential name/identifier
    
.PARAMETER Credential
    PSCredential object to store
    
.PARAMETER ApiKey
    API key or token to store
    
.PARAMETER Repository
    GitHub repository in format "owner/repo" (e.g., "myorg/credentials-vault")
    
.PARAMETER GitHubToken
    GitHub Personal Access Token with repo access
    If not provided, will attempt to use stored token or environment variable
    
.PARAMETER Branch
    Branch to store credentials (default: main)
    
.PARAMETER Path
    Path within repository (default: credentials/)
    
.EXAMPLE
    Set-AitherCredentialGitHub -Name "AWS-Prod" -Credential (Get-Credential) -Repository "myorg/vault"
    
    Stores AWS credentials in private GitHub repository
    
.EXAMPLE
    $token = Read-Host -AsSecureString "GitHub Token"
    Set-AitherCredentialGitHub -Name "Azure-Key" -ApiKey $apiKey -Repository "myorg/vault" -GitHubToken $token
    
    Stores Azure API key with explicit GitHub token
    
.EXAMPLE
    # Use environment variable for GitHub token
    $env:GITHUB_TOKEN = "ghp_xxxxx"
    Set-AitherCredentialGitHub -Name "Deploy-Prod" -Credential $cred -Repository "myorg/vault"
    
.OUTPUTS
    None
    
.NOTES
    Security:
    - Repository MUST be private
    - GitHub token requires 'repo' scope
    - Credentials are encrypted before storage
    - Access controlled via GitHub permissions
    - Full audit trail via git history
    
    Setup:
    1. Create private GitHub repository
    2. Generate PAT with 'repo' scope
    3. Store PAT: Set-AitherCredential -Name "GitHub-Vault" -ApiKey $pat
    
.LINK
    Get-AitherCredentialGitHub
    
.LINK
    Set-AitherCredential
#>
function Set-AitherCredentialGitHub {
    [CmdletBinding(SupportsShouldProcess)]
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
        
        [Parameter(Mandatory)]
        [ValidatePattern('^[\w-]+/[\w-]+$')]
        [string]$Repository,
        
        [Parameter()]
        [SecureString]$GitHubToken,
        
        [Parameter()]
        [string]$Branch = 'main',
        
        [Parameter()]
        [string]$Path = 'credentials'
    )
    
    if ($PSCmdlet.ShouldProcess("$Repository/$Path/$Name", "Store credential in GitHub")) {
        try {
            # Get GitHub token
            if (-not $GitHubToken) {
                $GitHubToken = if ($env:GITHUB_TOKEN) {
                    ConvertTo-SecureString $env:GITHUB_TOKEN -AsPlainText -Force
                }
                elseif (Test-Path ~/.aitherzero/credentials/GitHub-Vault.cred) {
                    Get-AitherCredential -Name "GitHub-Vault"
                }
                else {
                    throw "GitHub token not found. Provide -GitHubToken, set GITHUB_TOKEN env var, or store with: Set-AitherCredential -Name 'GitHub-Vault' -ApiKey <token>"
                }
            }
            
            $token = ConvertFrom-SecureStringSecurely -SecureString $GitHubToken
            
            # Prepare credential data
            if ($PSCmdlet.ParameterSetName -eq 'Credential') {
                $credData = @{
                    Type = 'Credential'
                    Username = $Credential.UserName
                    Password = $Credential.Password | ConvertFrom-SecureString
                    StoredAt = (Get-Date).ToString('o')
                    StoredBy = $env:USERNAME
                }
            }
            else {
                $credData = @{
                    Type = 'ApiKey'
                    Key = $ApiKey | ConvertFrom-SecureString
                    StoredAt = (Get-Date).ToString('o')
                    StoredBy = $env:USERNAME
                }
            }
            
            # Convert to JSON (encrypted)
            $jsonContent = $credData | ConvertTo-Json -Depth 10
            $base64Content = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($jsonContent))
            
            # GitHub API: Get file SHA if exists (for updates)
            $apiUrl = "https://api.github.com/repos/$Repository/contents/$Path/$Name.json"
            $headers = @{
                Authorization = "token $token"
                Accept = "application/vnd.github.v3+json"
            }
            
            $existingSha = $null
            try {
                $existingFile = Invoke-RestMethod -Uri "$apiUrl`?ref=$Branch" -Headers $headers -Method Get
                $existingSha = $existingFile.sha
            }
            catch {
                # File doesn't exist yet
            }
            
            # Create/update file
            $body = @{
                message = "Update credential: $Name"
                content = $base64Content
                branch = $Branch
            }
            
            if ($existingSha) {
                $body.sha = $existingSha
            }
            
            $result = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Put -Body ($body | ConvertTo-Json) -ContentType 'application/json'
            
            Write-SecurityLog -Message "Credential stored in GitHub repository" -Data @{
                Name = $Name
                Repository = $Repository
                Path = "$Path/$Name.json"
                CommitSha = $result.commit.sha
            }
        }
        catch {
            Write-SecurityLog -Level Error -Message "Failed to store credential in GitHub" -Data @{
                Name = $Name
                Repository = $Repository
                Error = $_.Exception.Message
            }
            throw
        }
    }
}

<#
.SYNOPSIS
    Retrieve credential from private GitHub repository
    
.DESCRIPTION
    Retrieves encrypted credentials from a private GitHub repository.
    Requires authentication to access.
    
.PARAMETER Name
    Credential name to retrieve
    
.PARAMETER Repository
    GitHub repository in format "owner/repo"
    
.PARAMETER GitHubToken
    GitHub Personal Access Token
    
.PARAMETER Branch
    Branch to read from (default: main)
    
.PARAMETER Path
    Path within repository (default: credentials/)
    
.PARAMETER AsPlainText
    Return API key as plain text (use with caution)
    
.EXAMPLE
    $cred = Get-AitherCredentialGitHub -Name "AWS-Prod" -Repository "myorg/vault"
    
.EXAMPLE
    $apiKey = Get-AitherCredentialGitHub -Name "Azure-Key" -Repository "myorg/vault" -AsPlainText
    
.OUTPUTS
    [PSCredential] or [SecureString] or [string]
    
.LINK
    Set-AitherCredentialGitHub
#>
function Get-AitherCredentialGitHub {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [ValidatePattern('^[\w-]+/[\w-]+$')]
        [string]$Repository,
        
        [Parameter()]
        [SecureString]$GitHubToken,
        
        [Parameter()]
        [string]$Branch = 'main',
        
        [Parameter()]
        [string]$Path = 'credentials',
        
        [Parameter()]
        [switch]$AsPlainText
    )
    
    try {
        # Get GitHub token
        if (-not $GitHubToken) {
            $GitHubToken = if ($env:GITHUB_TOKEN) {
                ConvertTo-SecureString $env:GITHUB_TOKEN -AsPlainText -Force
            }
            elseif (Test-Path ~/.aitherzero/credentials/GitHub-Vault.cred) {
                Get-AitherCredential -Name "GitHub-Vault"
            }
            else {
                throw "GitHub token not found. Provide -GitHubToken, set GITHUB_TOKEN env var, or store with: Set-AitherCredential -Name 'GitHub-Vault' -ApiKey <token>"
            }
        }
        
        $token = ConvertFrom-SecureStringSecurely -SecureString $GitHubToken
        
        # GitHub API: Get file content
        $apiUrl = "https://api.github.com/repos/$Repository/contents/$Path/$Name.json"
        $headers = @{
            Authorization = "token $token"
            Accept = "application/vnd.github.v3+json"
        }
        
        $file = Invoke-RestMethod -Uri "$apiUrl`?ref=$Branch" -Headers $headers -Method Get
        
        # Decode content
        $jsonContent = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($file.content))
        $credData = $jsonContent | ConvertFrom-Json
        
        # Return credential
        if ($credData.Type -eq 'Credential') {
            $password = $credData.Password | ConvertTo-SecureString
            return [PSCredential]::new($credData.Username, $password)
        }
        elseif ($credData.Type -eq 'ApiKey') {
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
        Write-SecurityLog -Level Error -Message "Failed to retrieve credential from GitHub" -Data @{
            Name = $Name
            Repository = $Repository
            Error = $_.Exception.Message
        }
        throw
    }
}

<#
.SYNOPSIS
    Get credential from GitHub Actions/Repository Secrets
    
.DESCRIPTION
    Retrieves credentials from GitHub Secrets (Actions secrets or repository secrets).
    This is the recommended way to use credentials in GitHub Actions workflows.
    
    Requires:
    - GitHub CLI (gh) installed
    - Authenticated with gh auth login
    - Or GITHUB_TOKEN environment variable (in Actions)
    
.PARAMETER Name
    Secret name in GitHub
    
.PARAMETER Repository
    Repository in format "owner/repo"
    If not provided, uses current repository
    
.PARAMETER Environment
    Environment name (for environment-specific secrets)
    
.PARAMETER AsPlainText
    Return as plain text (use with caution)
    
.EXAMPLE
    # In GitHub Actions workflow
    $deployToken = Get-AitherSecretGitHub -Name "DEPLOY_TOKEN"
    
.EXAMPLE
    # Get from specific repository
    $apiKey = Get-AitherSecretGitHub -Name "API_KEY" -Repository "myorg/myrepo" -AsPlainText
    
.EXAMPLE
    # Get environment-specific secret
    $prodKey = Get-AitherSecretGitHub -Name "DB_PASSWORD" -Environment "production"
    
.OUTPUTS
    [SecureString] or [string] if -AsPlainText
    
.NOTES
    In GitHub Actions, secrets are automatically available as environment variables.
    This function provides a programmatic way to access them.
    
    Setup:
    - Repository secrets: Settings → Secrets and variables → Actions
    - Environment secrets: Settings → Environments → <env> → Secrets
    
.LINK
    Set-AitherCredentialGitHub
#>
function Get-AitherSecretGitHub {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter()]
        [string]$Repository,
        
        [Parameter()]
        [string]$Environment,
        
        [Parameter()]
        [switch]$AsPlainText
    )
    
    try {
        # In GitHub Actions, secrets are environment variables
        if ($env:GITHUB_ACTIONS -eq 'true') {
            $secretValue = Get-ChildItem env: | Where-Object { $_.Name -eq $Name } | Select-Object -ExpandProperty Value
            
            if ($secretValue) {
                if ($AsPlainText) {
                    return $secretValue
                }
                else {
                    return ConvertTo-SecureString $secretValue -AsPlainText -Force
                }
            }
        }
        
        # Use GitHub CLI to get secret
        if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
            throw "GitHub CLI (gh) not found. Install from: https://cli.github.com/"
        }
        
        # Build gh command
        $ghArgs = @('secret', 'list')
        
        if ($Repository) {
            $ghArgs += @('--repo', $Repository)
        }
        
        if ($Environment) {
            $ghArgs += @('--env', $Environment)
        }
        
        # Check if secret exists
        $secrets = & gh @ghArgs --json name | ConvertFrom-Json
        $secretExists = $secrets | Where-Object { $_.name -eq $Name }
        
        if (-not $secretExists) {
            throw "Secret '$Name' not found in GitHub"
        }
        
        # Note: gh CLI cannot retrieve secret values for security reasons
        # Secrets can only be accessed as environment variables in Actions
        throw "Cannot retrieve secret value via gh CLI. Use environment variable `$env:$Name in GitHub Actions, or use Get-AitherCredentialGitHub for repo-stored credentials."
    }
    catch {
        Write-SecurityLog -Level Error -Message "Failed to retrieve GitHub secret" -Data @{
            Name = $Name
            Repository = $Repository
            Environment = $Environment
            Error = $_.Exception.Message
        }
        throw
    }
}

<#
.SYNOPSIS
    Sync local credentials to GitHub repository
    
.DESCRIPTION
    Synchronizes all local credentials to a private GitHub repository.
    Useful for backup and team sharing.
    
.PARAMETER Repository
    GitHub repository in format "owner/repo"
    
.PARAMETER GitHubToken
    GitHub Personal Access Token
    
.PARAMETER IncludeNames
    Only sync credentials matching these names (wildcards supported)
    
.PARAMETER ExcludeNames
    Exclude credentials matching these names (wildcards supported)
    
.EXAMPLE
    Sync-AitherCredentialsGitHub -Repository "myorg/vault"
    
    Syncs all local credentials to GitHub
    
.EXAMPLE
    Sync-AitherCredentialsGitHub -Repository "myorg/vault" -IncludeNames "AWS-*", "Azure-*"
    
    Syncs only AWS and Azure credentials
    
.OUTPUTS
    [PSCustomObject[]] Sync results
    
.LINK
    Set-AitherCredentialGitHub
#>
function Sync-AitherCredentialsGitHub {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[\w-]+/[\w-]+$')]
        [string]$Repository,
        
        [Parameter()]
        [SecureString]$GitHubToken,
        
        [Parameter()]
        [string[]]$IncludeNames = @('*'),
        
        [Parameter()]
        [string[]]$ExcludeNames = @()
    )
    
    try {
        $localCreds = Get-AitherCredentialList
        $results = @()
        
        foreach ($cred in $localCreds) {
            # Check filters
            $include = $false
            foreach ($pattern in $IncludeNames) {
                if ($cred.Name -like $pattern) {
                    $include = $true
                    break
                }
            }
            
            if (-not $include) {
                continue
            }
            
            $exclude = $false
            foreach ($pattern in $ExcludeNames) {
                if ($cred.Name -like $pattern) {
                    $exclude = $true
                    break
                }
            }
            
            if ($exclude) {
                continue
            }
            
            # Sync credential
            try {
                $localCredValue = Get-AitherCredential -Name $cred.Name
                
                $params = @{
                    Name = $cred.Name
                    Repository = $Repository
                }
                
                if ($GitHubToken) {
                    $params.GitHubToken = $GitHubToken
                }
                
                if ($cred.Type -eq 'Credential') {
                    $params.Credential = $localCredValue
                }
                else {
                    $params.ApiKey = $localCredValue
                }
                
                Set-AitherCredentialGitHub @params
                
                $results += [PSCustomObject]@{
                    Name = $cred.Name
                    Type = $cred.Type
                    Status = 'Success'
                    Error = $null
                }
            }
            catch {
                $results += [PSCustomObject]@{
                    Name = $cred.Name
                    Type = $cred.Type
                    Status = 'Failed'
                    Error = $_.Exception.Message
                }
            }
        }
        
        Write-SecurityLog -Message "Credential sync completed" -Data @{
            Repository = $Repository
            Total = $results.Count
            Success = ($results | Where-Object Status -eq 'Success').Count
            Failed = ($results | Where-Object Status -eq 'Failed').Count
        }
        
        return $results
    }
    catch {
        Write-SecurityLog -Level Error -Message "Credential sync failed" -Data @{
            Repository = $Repository
            Error = $_.Exception.Message
        }
        throw
    }
}

#endregion

#region Environment Variable Management for Credentials

<#
.SYNOPSIS
    Set environment variable from stored credential
    
.DESCRIPTION
    Sets an environment variable using a stored credential. Useful for configuring
    access tokens, API keys, and other credentials as environment variables for
    tools that expect them (e.g., GITHUB_TOKEN, AWS_ACCESS_KEY_ID, etc.).
    
    Supports:
    - Session scope (current PowerShell session only)
    - User scope (persists across sessions for current user)
    - Machine scope (system-wide, requires admin)
    - Process scope (current process only)
    
.PARAMETER Name
    Environment variable name (e.g., "GITHUB_TOKEN", "AWS_ACCESS_KEY_ID")
    
.PARAMETER CredentialName
    Name of stored credential to use
    
.PARAMETER Scope
    Environment variable scope: Session (default), User, Machine, Process
    
.PARAMETER FromGitHub
    Get credential from GitHub repository instead of local storage
    
.PARAMETER Repository
    GitHub repository (required if -FromGitHub)
    
.EXAMPLE
    Set-AitherEnvironmentVariable -Name "GITHUB_TOKEN" -CredentialName "GitHub-Vault"
    
    Sets GITHUB_TOKEN from stored credential for current session
    
.EXAMPLE
    Set-AitherEnvironmentVariable -Name "AWS_ACCESS_KEY_ID" -CredentialName "AWS-Prod" -Scope User
    
    Sets AWS token persistently for current user
    
.EXAMPLE
    Set-AitherEnvironmentVariable -Name "DEPLOY_TOKEN" -CredentialName "Deploy-Prod" -FromGitHub -Repository "myorg/vault"
    
    Sets token from GitHub repository credential
    
.EXAMPLE
    # Quick setup for common tools
    Set-AitherEnvironmentVariable -Name "GITHUB_TOKEN" -CredentialName "GitHub-PAT"
    Set-AitherEnvironmentVariable -Name "AZURE_DEVOPS_PAT" -CredentialName "Azure-PAT"
    Set-AitherEnvironmentVariable -Name "AWS_ACCESS_KEY_ID" -CredentialName "AWS-Key"
    
.OUTPUTS
    None
    
.NOTES
    Scopes:
    - Session: Current PowerShell session only (cleared when session ends)
    - Process: Current process only (child processes inherit)
    - User: Current user (persists across sessions)
    - Machine: System-wide (requires admin, all users)
    
    Common Environment Variables:
    - GITHUB_TOKEN: GitHub CLI and API access
    - AZURE_DEVOPS_PAT: Azure DevOps access
    - AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY: AWS credentials
    - GOOGLE_APPLICATION_CREDENTIALS: GCP service account
    - DOCKER_USERNAME, DOCKER_PASSWORD: Docker registry
    
.LINK
    Get-AitherEnvironmentVariable
    
.LINK
    Remove-AitherEnvironmentVariable
#>
function Set-AitherEnvironmentVariable {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$CredentialName,
        
        [Parameter()]
        [ValidateSet('Session', 'User', 'Machine', 'Process')]
        [string]$Scope = 'Session',
        
        [Parameter()]
        [switch]$FromGitHub,
        
        [Parameter()]
        [string]$Repository
    )
    
    if ($PSCmdlet.ShouldProcess($Name, "Set environment variable from credential $CredentialName")) {
        try {
            # Get credential value
            if ($FromGitHub) {
                if (-not $Repository) {
                    throw "Repository parameter required when using -FromGitHub"
                }
                $credential = Get-AitherCredentialGitHub -Name $CredentialName -Repository $Repository -AsPlainText
            }
            else {
                $credential = Get-AitherCredential -Name $CredentialName
                
                # Convert to plain text
                if ($credential -is [PSCredential]) {
                    $credential = $credential.GetNetworkCredential().Password
                }
                elseif ($credential -is [SecureString]) {
                    $credential = ConvertFrom-SecureStringSecurely -SecureString $credential
                }
            }
            
            # Set environment variable based on scope
            switch ($Scope) {
                'Session' {
                    Set-Item -Path "env:$Name" -Value $credential
                }
                'Process' {
                    [Environment]::SetEnvironmentVariable($Name, $credential, 'Process')
                }
                'User' {
                    [Environment]::SetEnvironmentVariable($Name, $credential, 'User')
                    # Also set in current session
                    Set-Item -Path "env:$Name" -Value $credential
                }
                'Machine' {
                    if (-not (Test-IsAdministrator)) {
                        throw "Machine scope requires administrator privileges"
                    }
                    [Environment]::SetEnvironmentVariable($Name, $credential, 'Machine')
                    # Also set in current session
                    Set-Item -Path "env:$Name" -Value $credential
                }
            }
            
            Write-SecurityLog -Message "Environment variable set from credential" -Data @{
                Name = $Name
                CredentialName = $CredentialName
                Scope = $Scope
                FromGitHub = $FromGitHub
            }
        }
        catch {
            Write-SecurityLog -Level Error -Message "Failed to set environment variable" -Data @{
                Name = $Name
                CredentialName = $CredentialName
                Error = $_.Exception.Message
            }
            throw
        }
    }
}

<#
.SYNOPSIS
    Get environment variable value
    
.DESCRIPTION
    Retrieves environment variable value, optionally as SecureString.
    
.PARAMETER Name
    Environment variable name
    
.PARAMETER AsSecureString
    Return value as SecureString (for sensitive data)
    
.EXAMPLE
    $token = Get-AitherEnvironmentVariable -Name "GITHUB_TOKEN"
    
.EXAMPLE
    $secureToken = Get-AitherEnvironmentVariable -Name "API_KEY" -AsSecureString
    
.OUTPUTS
    [string] or [SecureString]
    
.LINK
    Set-AitherEnvironmentVariable
#>
function Get-AitherEnvironmentVariable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter()]
        [switch]$AsSecureString
    )
    
    $value = [Environment]::GetEnvironmentVariable($Name)
    
    if (-not $value) {
        Write-Warning "Environment variable '$Name' not found"
        return $null
    }
    
    if ($AsSecureString) {
        return ConvertTo-SecureString $value -AsPlainText -Force
    }
    else {
        return $value
    }
}

<#
.SYNOPSIS
    Remove environment variable
    
.DESCRIPTION
    Removes environment variable from specified scope.
    
.PARAMETER Name
    Environment variable name
    
.PARAMETER Scope
    Scope to remove from (Session, User, Machine, Process, All)
    
.EXAMPLE
    Remove-AitherEnvironmentVariable -Name "GITHUB_TOKEN"
    
    Removes from current session
    
.EXAMPLE
    Remove-AitherEnvironmentVariable -Name "AWS_ACCESS_KEY_ID" -Scope User
    
    Removes persistent user variable
    
.EXAMPLE
    Remove-AitherEnvironmentVariable -Name "OLD_TOKEN" -Scope All
    
    Removes from all scopes
    
.LINK
    Set-AitherEnvironmentVariable
#>
function Remove-AitherEnvironmentVariable {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter()]
        [ValidateSet('Session', 'User', 'Machine', 'Process', 'All')]
        [string]$Scope = 'Session'
    )
    
    if ($PSCmdlet.ShouldProcess($Name, "Remove environment variable from $Scope scope")) {
        try {
            if ($Scope -eq 'All') {
                Remove-Item -Path "env:$Name" -ErrorAction SilentlyContinue
                [Environment]::SetEnvironmentVariable($Name, $null, 'Process')
                [Environment]::SetEnvironmentVariable($Name, $null, 'User')
                
                if (Test-IsAdministrator) {
                    [Environment]::SetEnvironmentVariable($Name, $null, 'Machine')
                }
            }
            else {
                switch ($Scope) {
                    'Session' {
                        Remove-Item -Path "env:$Name" -ErrorAction SilentlyContinue
                    }
                    'Process' {
                        [Environment]::SetEnvironmentVariable($Name, $null, 'Process')
                    }
                    'User' {
                        [Environment]::SetEnvironmentVariable($Name, $null, 'User')
                        Remove-Item -Path "env:$Name" -ErrorAction SilentlyContinue
                    }
                    'Machine' {
                        if (-not (Test-IsAdministrator)) {
                            throw "Machine scope requires administrator privileges"
                        }
                        [Environment]::SetEnvironmentVariable($Name, $null, 'Machine')
                        Remove-Item -Path "env:$Name" -ErrorAction SilentlyContinue
                    }
                }
            }
            
            Write-SecurityLog -Message "Environment variable removed" -Data @{
                Name = $Name
                Scope = $Scope
            }
        }
        catch {
            Write-SecurityLog -Level Error -Message "Failed to remove environment variable" -Data @{
                Name = $Name
                Scope = $Scope
                Error = $_.Exception.Message
            }
            throw
        }
    }
}

<#
.SYNOPSIS
    Initialize common environment variables from stored credentials
    
.DESCRIPTION
    Quick setup function to configure common environment variables (GitHub, AWS, Azure, etc.)
    from stored credentials. Simplifies the process of setting up development environments.
    
.PARAMETER Profile
    Predefined profile: Development, CI, Production, or Custom
    
.PARAMETER Scope
    Environment variable scope (default: Session)
    
.PARAMETER FromGitHub
    Get credentials from GitHub repository
    
.PARAMETER Repository
    GitHub repository for credentials (if -FromGitHub)
    
.PARAMETER CustomMapping
    Custom hashtable mapping env var names to credential names
    
.EXAMPLE
    Initialize-AitherEnvironment -Profile Development
    
    Sets up common dev environment variables:
    - GITHUB_TOKEN from "GitHub-Dev"
    - AWS_ACCESS_KEY_ID from "AWS-Dev"
    - AZURE_DEVOPS_PAT from "Azure-Dev"
    
.EXAMPLE
    Initialize-AitherEnvironment -Profile CI -Scope User
    
    Sets up CI environment variables persistently
    
.EXAMPLE
    Initialize-AitherEnvironment -Profile Custom -CustomMapping @{
        GITHUB_TOKEN = "GitHub-Prod"
        NPM_TOKEN = "NPM-Registry"
        DOCKER_PASSWORD = "Docker-Hub"
    }
    
.EXAMPLE
    Initialize-AitherEnvironment -Profile Production -FromGitHub -Repository "myorg/vault"
    
    Sets up production environment from GitHub repository
    
.OUTPUTS
    [PSCustomObject[]] Results of each variable initialization
    
.NOTES
    Predefined Profiles:
    
    Development:
    - GITHUB_TOKEN → GitHub-Dev
    - AWS_ACCESS_KEY_ID → AWS-Dev
    - AZURE_DEVOPS_PAT → Azure-Dev
    
    CI:
    - GITHUB_TOKEN → GitHub-CI
    - AWS_ACCESS_KEY_ID → AWS-CI
    - AZURE_DEVOPS_PAT → Azure-CI
    - DOCKER_USERNAME → Docker-CI
    - DOCKER_PASSWORD → Docker-CI
    
    Production:
    - GITHUB_TOKEN → GitHub-Prod
    - AWS_ACCESS_KEY_ID → AWS-Prod
    - AWS_SECRET_ACCESS_KEY → AWS-Prod-Secret
    - AZURE_DEVOPS_PAT → Azure-Prod
    
.LINK
    Set-AitherEnvironmentVariable
#>
function Initialize-AitherEnvironment {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0)]
        [ValidateSet('Development', 'CI', 'Production', 'Custom')]
        [string]$Profile = 'Development',
        
        [Parameter()]
        [ValidateSet('Session', 'User', 'Machine', 'Process')]
        [string]$Scope = 'Session',
        
        [Parameter()]
        [switch]$FromGitHub,
        
        [Parameter()]
        [string]$Repository,
        
        [Parameter()]
        [hashtable]$CustomMapping = @{},
        
        [Parameter()]
        [switch]$SkipMissing
    )
    
    # Define profile mappings
    $profiles = @{
        Development = @{
            GITHUB_TOKEN = 'GitHub-Dev'
            AWS_ACCESS_KEY_ID = 'AWS-Dev'
            AZURE_DEVOPS_PAT = 'Azure-Dev'
        }
        CI = @{
            GITHUB_TOKEN = 'GitHub-CI'
            AWS_ACCESS_KEY_ID = 'AWS-CI'
            AZURE_DEVOPS_PAT = 'Azure-CI'
            DOCKER_USERNAME = 'Docker-CI'
            DOCKER_PASSWORD = 'Docker-CI'
        }
        Production = @{
            GITHUB_TOKEN = 'GitHub-Prod'
            AWS_ACCESS_KEY_ID = 'AWS-Prod'
            AWS_SECRET_ACCESS_KEY = 'AWS-Prod-Secret'
            AZURE_DEVOPS_PAT = 'Azure-Prod'
        }
        Custom = $CustomMapping
    }
    
    $mapping = $profiles[$Profile]
    
    if (-not $mapping -or $mapping.Count -eq 0) {
        throw "No mappings defined for profile '$Profile'"
    }
    
    $results = @()
    
    foreach ($envVar in $mapping.Keys) {
        $credName = $mapping[$envVar]
        
        try {
            $params = @{
                Name = $envVar
                CredentialName = $credName
                Scope = $Scope
                FromGitHub = $FromGitHub
            }
            
            if ($FromGitHub -and $Repository) {
                $params.Repository = $Repository
            }
            
            # First check if credential exists when SkipMissing is enabled
            if ($SkipMissing) {
                $credExists = $null -ne (Get-AitherCredential -Name $credName -ErrorAction SilentlyContinue)
                if (-not $credExists) {
                    Write-SecurityLog -Level Warning -Message "Skipping missing credential" -Data @{
                        CredentialName = $credName
                        Variable = $envVar
                    }
                    $results += [PSCustomObject]@{
                        Variable = $envVar
                        CredentialName = $credName
                        Scope = $Scope
                        Status = 'Skipped'
                        Error = "Credential not found (skipped)"
                    }
                    continue
                }
            }
            
            Set-AitherEnvironmentVariable @params
            
            $results += [PSCustomObject]@{
                Variable = $envVar
                CredentialName = $credName
                Scope = $Scope
                Status = 'Success'
                Error = $null
            }
        }
        catch {
            $results += [PSCustomObject]@{
                Variable = $envVar
                CredentialName = $credName
                Scope = $Scope
                Status = 'Failed'
                Error = $_.Exception.Message
            }
        }
    }
    
    Write-SecurityLog -Message "Environment initialization completed" -Data @{
        Profile = $Profile
        Scope = $Scope
        Total = $results.Count
        Success = ($results | Where-Object Status -eq 'Success').Count
        Failed = ($results | Where-Object Status -eq 'Failed').Count
        Skipped = ($results | Where-Object Status -eq 'Skipped').Count
    }
    
    return $results
}

# Helper function to check if running as administrator
function Test-IsAdministrator {
    if ($IsWindows) {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]$identity
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    else {
        # On Linux/macOS, check if running as root
        return (id -u) -eq 0
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
    'Invoke-AitherRemoteCommand',
    'Set-AitherCredentialGitHub',
    'Get-AitherCredentialGitHub',
    'Get-AitherSecretGitHub',
    'Sync-AitherCredentialsGitHub',
    'Set-AitherEnvironmentVariable',
    'Get-AitherEnvironmentVariable',
    'Remove-AitherEnvironmentVariable',
    'Initialize-AitherEnvironment'
)