#Requires -Version 7.0

<#
.SYNOPSIS
    Security domain module for credential and remote connection management
.DESCRIPTION
    Provides SSH key management, credential storage, and remote connection functionality
    for infrastructure deployment and script execution on remote hosts.
    Integrates with OS built-in credential stores cross-platform.
.NOTES
    Copyright © 2025 Aitherium Corporation
    Part of AitherZero Infrastructure Automation Platform
#>

# Script variables
$script:IsInitialized = $false
$script:SSHKeyCache = @{}
$script:ConnectionProfiles = @{}
$script:CredentialStore = @{}

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
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $color = @{
            'Error' = 'Red'
            'Warning' = 'Yellow'
            'Information' = 'White'
            'Debug' = 'Gray'
        }[$Level]
        Write-Host "[$timestamp] [$Level] [Security] $Message" -ForegroundColor $color
    }
}

# Initialize the Security module
function Initialize-SecurityModule {
    [CmdletBinding()]
    param()
    
    if ($script:IsInitialized) {
        return
    }

    try {
        # Ensure SSH client is available
        if (-not (Test-SSHAvailability)) {
            Write-SecurityLog -Level Warning -Message "SSH client not available, some features may be limited"
        }

        # Initialize credential store paths
        Initialize-CredentialStorePaths

        Write-SecurityLog -Message "Security module initialized successfully" -Data @{
            SSHAvailable = (Test-SSHAvailability)
            Platform = $PSVersionTable.Platform
        }
        
        $script:IsInitialized = $true
    }
    catch {
        Write-SecurityLog -Level Error -Message "Failed to initialize Security module: $_"
        throw
    }
}

# Test SSH client availability
function Test-SSHAvailability {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    try {
        $null = Get-Command ssh -ErrorAction Stop
        $null = Get-Command ssh-keygen -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# Initialize credential store paths based on platform
function Initialize-CredentialStorePaths {
    [CmdletBinding()]
    param()
    
    $sshDir = if ($IsWindows) {
        Join-Path $env:USERPROFILE ".ssh"
    } else {
        Join-Path $env:HOME ".ssh"
    }
    
    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
        if (-not $IsWindows) {
            chmod 700 $sshDir
        }
    }
    
    Write-SecurityLog -Level Debug -Message "SSH directory ensured at: $sshDir"
}

# Generate SSH key pair
function New-SSHKeyPair {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$KeyName,
        
        [ValidateSet('rsa', 'ed25519', 'ecdsa')]
        [string]$KeyType = 'ed25519',
        
        [string]$Comment = '',
        
        [int]$KeySize = 4096,
        
        [switch]$Force
    )
    
    Initialize-SecurityModule
    
    if (-not (Test-SSHAvailability)) {
        throw "SSH client tools are not available on this system"
    }
    
    $sshDir = if ($IsWindows) {
        Join-Path $env:USERPROFILE ".ssh"
    } else {
        Join-Path $env:HOME ".ssh"
    }
    
    $privateKeyPath = Join-Path $sshDir $KeyName
    $publicKeyPath = "$privateKeyPath.pub"
    
    # Check if key already exists
    if ((Test-Path $privateKeyPath) -and -not $Force) {
        Write-SecurityLog -Level Warning -Message "SSH key '$KeyName' already exists. Use -Force to overwrite."
        return $false
    }
    
    if ($PSCmdlet.ShouldProcess($KeyName, "Generate SSH key pair")) {
        try {
            $keygenArgs = @(
                "-t", $KeyType
                "-f", $privateKeyPath
                "-N", '""'  # Empty passphrase for automation (quoted empty string)
            )
            
            if ($Comment) {
                $keygenArgs += @("-C", $Comment)
            }
            
            if ($KeyType -eq 'rsa') {
                $keygenArgs += @("-b", $KeySize.ToString())
            }
            
            Write-SecurityLog -Message "Generating SSH key pair: $KeyName ($KeyType)"
            
            $result = Start-Process -FilePath "ssh-keygen" -ArgumentList $keygenArgs -Wait -NoNewWindow -PassThru
            
            if ($result.ExitCode -eq 0) {
                # Set proper permissions on Unix-like systems
                if (-not $IsWindows) {
                    chmod 600 $privateKeyPath
                    chmod 644 $publicKeyPath
                }
                
                Write-SecurityLog -Message "SSH key pair generated successfully" -Data @{
                    KeyName = $KeyName
                    KeyType = $KeyType
                    PrivateKeyPath = $privateKeyPath
                    PublicKeyPath = $publicKeyPath
                }
                
                return @{
                    KeyName = $KeyName
                    KeyType = $KeyType
                    PrivateKeyPath = $privateKeyPath
                    PublicKeyPath = $publicKeyPath
                    PublicKey = (Get-Content $publicKeyPath -Raw).Trim()
                }
            }
            else {
                throw "ssh-keygen failed with exit code: $($result.ExitCode)"
            }
        }
        catch {
            Write-SecurityLog -Level Error -Message "Failed to generate SSH key pair: $_"
            throw
        }
    }
}

# Get SSH key information
function Get-SSHKey {
    [CmdletBinding()]
    param(
        [string]$KeyName,
        [switch]$ListAll
    )
    
    Initialize-SecurityModule
    
    $sshDir = if ($IsWindows) {
        Join-Path $env:USERPROFILE ".ssh"
    } else {
        Join-Path $env:HOME ".ssh"
    }
    
    if ($ListAll) {
        $keys = @()
        $keyFiles = Get-ChildItem -Path $sshDir -Filter "*.pub" -ErrorAction SilentlyContinue
        
        foreach ($keyFile in $keyFiles) {
            $keyName = $keyFile.BaseName
            $publicKeyPath = $keyFile.FullName
            $privateKeyPath = Join-Path $sshDir $keyName
            
            if (Test-Path $privateKeyPath) {
                $publicKeyContent = Get-Content $publicKeyPath -Raw
                $keyInfo = Parse-SSHPublicKey $publicKeyContent
                
                $keys += @{
                    KeyName = $keyName
                    KeyType = $keyInfo.Type
                    PrivateKeyPath = $privateKeyPath
                    PublicKeyPath = $publicKeyPath
                    PublicKey = $publicKeyContent.Trim()
                    Comment = $keyInfo.Comment
                    Fingerprint = Get-SSHKeyFingerprint $publicKeyPath
                }
            }
        }
        
        return $keys
    }
    elseif ($KeyName) {
        $privateKeyPath = Join-Path $sshDir $KeyName
        $publicKeyPath = "$privateKeyPath.pub"
        
        if (-not (Test-Path $privateKeyPath) -or -not (Test-Path $publicKeyPath)) {
            Write-SecurityLog -Level Warning -Message "SSH key '$KeyName' not found"
            return $null
        }
        
        $publicKeyContent = Get-Content $publicKeyPath -Raw
        $keyInfo = Parse-SSHPublicKey $publicKeyContent
        
        return @{
            KeyName = $KeyName
            KeyType = $keyInfo.Type
            PrivateKeyPath = $privateKeyPath
            PublicKeyPath = $publicKeyPath
            PublicKey = $publicKeyContent.Trim()
            Comment = $keyInfo.Comment
            Fingerprint = Get-SSHKeyFingerprint $publicKeyPath
        }
    }
}

# Parse SSH public key
function Parse-SSHPublicKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PublicKeyContent
    )
    
    $parts = $PublicKeyContent.Trim() -split '\s+'
    
    if ($parts.Count -ge 2) {
        return @{
            Type = $parts[0]
            Key = $parts[1]
            Comment = if ($parts.Count -gt 2) { $parts[2..($parts.Count-1)] -join ' ' } else { '' }
        }
    }
    else {
        return @{
            Type = 'unknown'
            Key = $PublicKeyContent
            Comment = ''
        }
    }
}

# Get SSH key fingerprint
function Get-SSHKeyFingerprint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$KeyPath
    )
    
    try {
        $result = & ssh-keygen -lf $KeyPath 2>&1
        if ($LASTEXITCODE -eq 0) {
            # Extract fingerprint from output like "2048 SHA256:... user@host (RSA)"
            if ($result -match 'SHA256:([A-Za-z0-9+/]+)') {
                return "SHA256:$($matches[1])"
            }
        }
        return "Unable to determine"
    }
    catch {
        return "Error: $_"
    }
}

# Remove SSH key pair
function Remove-SSHKey {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [string]$KeyName
    )
    
    Initialize-SecurityModule
    
    $sshDir = if ($IsWindows) {
        Join-Path $env:USERPROFILE ".ssh"
    } else {
        Join-Path $env:HOME ".ssh"
    }
    
    $privateKeyPath = Join-Path $sshDir $KeyName
    $publicKeyPath = "$privateKeyPath.pub"
    
    if (-not (Test-Path $privateKeyPath) -and -not (Test-Path $publicKeyPath)) {
        Write-SecurityLog -Level Warning -Message "SSH key '$KeyName' not found"
        return $false
    }
    
    if ($PSCmdlet.ShouldProcess($KeyName, "Remove SSH key pair")) {
        try {
            if (Test-Path $privateKeyPath) {
                Remove-Item -Path $privateKeyPath -Force
                Write-SecurityLog -Message "Removed private key: $privateKeyPath"
            }
            
            if (Test-Path $publicKeyPath) {
                Remove-Item -Path $publicKeyPath -Force
                Write-SecurityLog -Message "Removed public key: $publicKeyPath"
            }
            
            Write-SecurityLog -Message "SSH key pair '$KeyName' removed successfully"
            return $true
        }
        catch {
            Write-SecurityLog -Level Error -Message "Failed to remove SSH key '$KeyName': $_"
            throw
        }
    }
}

# Store credential securely using OS credential store
function Set-SecureCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Target,
        
        [Parameter(Mandatory)]
        [string]$Username,
        
        [Parameter(Mandatory)]
        [SecureString]$Password,
        
        [string]$Description = ''
    )
    
    Initialize-SecurityModule
    
    try {
        if ($IsWindows) {
            # Use Windows Credential Manager
            $credential = New-Object PSCredential($Username, $Password)
            $plainPassword = $credential.GetNetworkCredential().Password
            
            # Use cmdkey to store credential
            $result = Start-Process -FilePath "cmdkey" -ArgumentList @("/generic:$Target", "/user:$Username", "/pass:$plainPassword") -Wait -NoNewWindow -PassThru
            
            if ($result.ExitCode -eq 0) {
                Write-SecurityLog -Message "Credential stored in Windows Credential Manager" -Data @{ Target = $Target; Username = $Username }
                return $true
            }
            else {
                throw "cmdkey failed with exit code: $($result.ExitCode)"
            }
        }
        elseif ($IsMacOS) {
            # Use macOS Keychain
            $credential = New-Object PSCredential($Username, $Password)
            $plainPassword = $credential.GetNetworkCredential().Password
            
            $keychainArgs = @(
                "add-generic-password"
                "-a", $Username
                "-s", $Target
                "-w", $plainPassword
            )
            
            if ($Description) {
                $keychainArgs += @("-D", $Description)
            }
            
            $result = Start-Process -FilePath "security" -ArgumentList $keychainArgs -Wait -NoNewWindow -PassThru
            
            if ($result.ExitCode -eq 0) {
                Write-SecurityLog -Message "Credential stored in macOS Keychain" -Data @{ Target = $Target; Username = $Username }
                return $true
            }
            else {
                throw "security command failed with exit code: $($result.ExitCode)"
            }
        }
        else {
            # Use libsecret on Linux (if available)
            if (Get-Command secret-tool -ErrorAction SilentlyContinue) {
                $credential = New-Object PSCredential($Username, $Password)
                $plainPassword = $credential.GetNetworkCredential().Password
                
                $secretArgs = @(
                    "store"
                    "--label=$Description"
                    "target", $Target
                    "username", $Username
                )
                
                $process = Start-Process -FilePath "secret-tool" -ArgumentList $secretArgs -Wait -NoNewWindow -PassThru -RedirectStandardInput
                $plainPassword | Out-String | Set-Content -Path "/proc/$($process.Id)/fd/0" -NoNewline
                
                if ($process.ExitCode -eq 0) {
                    Write-SecurityLog -Message "Credential stored in Linux Secret Service" -Data @{ Target = $Target; Username = $Username }
                    return $true
                }
                else {
                    throw "secret-tool failed with exit code: $($process.ExitCode)"
                }
            }
            else {
                # Fallback: store in PowerShell SecretManagement if available
                if (Get-Module Microsoft.PowerShell.SecretManagement -ListAvailable) {
                    Import-Module Microsoft.PowerShell.SecretManagement -Force
                    
                    $credential = New-Object PSCredential($Username, $Password)
                    Set-Secret -Name $Target -Secret $credential
                    
                    Write-SecurityLog -Message "Credential stored in PowerShell SecretManagement" -Data @{ Target = $Target; Username = $Username }
                    return $true
                }
                else {
                    Write-SecurityLog -Level Warning -Message "No secure credential store available on this platform"
                    return $false
                }
            }
        }
    }
    catch {
        Write-SecurityLog -Level Error -Message "Failed to store credential: $_"
        throw
    }
}

# Retrieve credential from OS credential store
function Get-SecureCredential {
    [CmdletBinding()]
    [OutputType([PSCredential])]
    param(
        [Parameter(Mandatory)]
        [string]$Target
    )
    
    Initialize-SecurityModule
    
    try {
        if ($IsWindows) {
            # Use Windows Credential Manager via PowerShell
            $cred = Get-StoredCredential -Target $Target -ErrorAction SilentlyContinue
            if ($cred) {
                return $cred
            }
            else {
                Write-SecurityLog -Level Warning -Message "Credential not found in Windows Credential Manager: $Target"
                return $null
            }
        }
        elseif ($IsMacOS) {
            # Use macOS Keychain
            try {
                $password = & security find-generic-password -s $Target -w 2>/dev/null
                $username = & security find-generic-password -s $Target -a "" 2>/dev/null | Select-String -Pattern 'acct.*"([^"]*)"' | ForEach-Object { $_.Matches[0].Groups[1].Value }
                
                if ($password -and $username) {
                    $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
                    return New-Object PSCredential($username, $securePassword)
                }
            }
            catch {
                Write-SecurityLog -Level Debug -Message "Credential not found in macOS Keychain: $Target"
            }
        }
        else {
            # Try libsecret on Linux
            if (Get-Command secret-tool -ErrorAction SilentlyContinue) {
                try {
                    $password = & secret-tool lookup target $Target 2>/dev/null
                    $username = & secret-tool lookup target $Target username 2>/dev/null
                    
                    if ($password -and $username) {
                        $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
                        return New-Object PSCredential($username, $securePassword)
                    }
                }
                catch {
                    Write-SecurityLog -Level Debug -Message "Credential not found in Linux Secret Service: $Target"
                }
            }
            
            # Fallback: PowerShell SecretManagement
            if (Get-Module Microsoft.PowerShell.SecretManagement -ListAvailable) {
                Import-Module Microsoft.PowerShell.SecretManagement -Force
                
                try {
                    $secret = Get-Secret -Name $Target -ErrorAction SilentlyContinue
                    if ($secret -is [PSCredential]) {
                        return $secret
                    }
                }
                catch {
                    Write-SecurityLog -Level Debug -Message "Credential not found in PowerShell SecretManagement: $Target"
                }
            }
        }
        
        return $null
    }
    catch {
        Write-SecurityLog -Level Error -Message "Failed to retrieve credential: $_"
        throw
    }
}

# Helper function for Windows credential retrieval
function Get-StoredCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Target
    )
    
    try {
        # Try to use the CredentialManager module if available
        if (Get-Module CredentialManager -ListAvailable) {
            Import-Module CredentialManager -Force
            return Get-StoredCredential -Target $Target
        }
        
        # Fallback: manual parsing of cmdkey output
        $cmdkeyOutput = & cmdkey /list:$Target 2>&1
        if ($LASTEXITCODE -eq 0 -and $cmdkeyOutput -match "User: (.+)") {
            $username = $matches[1]
            # Note: cmdkey doesn't provide password retrieval, this is a limitation
            Write-SecurityLog -Level Warning -Message "Windows cmdkey doesn't support password retrieval. Consider using CredentialManager module."
            return $null
        }
        
        return $null
    }
    catch {
        return $null
    }
}

# Create connection profile for remote host
function New-ConnectionProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProfileName,
        
        [Parameter(Mandatory)]
        [string]$Hostname,
        
        [string]$Username,
        
        [int]$Port = 22,
        
        [string]$SSHKeyName,
        
        [string]$Description = '',
        
        [hashtable]$SSHOptions = @{},
        
        [switch]$Force
    )
    
    Initialize-SecurityModule
    
    if ($script:ConnectionProfiles.ContainsKey($ProfileName) -and -not $Force) {
        Write-SecurityLog -Level Warning -Message "Connection profile '$ProfileName' already exists. Use -Force to overwrite."
        return $false
    }
    
    # Validate SSH key if specified
    if ($SSHKeyName) {
        $key = Get-SSHKey -KeyName $SSHKeyName
        if (-not $key) {
            throw "SSH key '$SSHKeyName' not found"
        }
    }
    
    $profile = @{
        ProfileName = $ProfileName
        Hostname = $Hostname
        Username = $Username
        Port = $Port
        SSHKeyName = $SSHKeyName
        Description = $Description
        SSHOptions = $SSHOptions
        Created = Get-Date
        LastUsed = $null
    }
    
    $script:ConnectionProfiles[$ProfileName] = $profile
    
    Write-SecurityLog -Message "Connection profile created: $ProfileName" -Data @{
        Hostname = $Hostname
        Username = $Username
        Port = $Port
        SSHKeyName = $SSHKeyName
    }
    
    # Save to persistent storage
    Save-ConnectionProfiles
    
    return $profile
}

# Get connection profile
function Get-ConnectionProfile {
    [CmdletBinding()]
    param(
        [string]$ProfileName,
        [switch]$ListAll
    )
    
    Initialize-SecurityModule
    Load-ConnectionProfiles
    
    if ($ListAll) {
        return $script:ConnectionProfiles.Values
    }
    elseif ($ProfileName) {
        return $script:ConnectionProfiles[$ProfileName]
    }
    else {
        return $script:ConnectionProfiles.Keys
    }
}

# Remove connection profile
function Remove-ConnectionProfile {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [string]$ProfileName
    )
    
    Initialize-SecurityModule
    Load-ConnectionProfiles
    
    if (-not $script:ConnectionProfiles.ContainsKey($ProfileName)) {
        Write-SecurityLog -Level Warning -Message "Connection profile '$ProfileName' not found"
        return $false
    }
    
    if ($PSCmdlet.ShouldProcess($ProfileName, "Remove connection profile")) {
        $script:ConnectionProfiles.Remove($ProfileName)
        Save-ConnectionProfiles
        
        Write-SecurityLog -Message "Connection profile removed: $ProfileName"
        return $true
    }
}

# Test SSH connection
function Test-SSHConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Profile')]
        [string]$ProfileName,
        
        [Parameter(Mandatory, ParameterSetName = 'Direct')]
        [string]$Hostname,
        
        [Parameter(ParameterSetName = 'Direct')]
        [string]$Username,
        
        [Parameter(ParameterSetName = 'Direct')]
        [int]$Port = 22,
        
        [Parameter(ParameterSetName = 'Direct')]
        [string]$SSHKeyName,
        
        [int]$TimeoutSeconds = 10
    )
    
    Initialize-SecurityModule
    
    if (-not (Test-SSHAvailability)) {
        throw "SSH client not available"
    }
    
    if ($PSCmdlet.ParameterSetName -eq 'Profile') {
        $profile = Get-ConnectionProfile -ProfileName $ProfileName
        if (-not $profile) {
            throw "Connection profile '$ProfileName' not found"
        }
        
        $Hostname = $profile.Hostname
        $Username = $profile.Username
        $Port = $profile.Port
        $SSHKeyName = $profile.SSHKeyName
    }
    
    try {
        $sshArgs = @(
            "-o", "ConnectTimeout=$TimeoutSeconds"
            "-o", "BatchMode=yes"
            "-o", "StrictHostKeyChecking=no"
            "-p", $Port.ToString()
        )
        
        if ($SSHKeyName) {
            $keyPath = Get-SSHKey -KeyName $SSHKeyName | Select-Object -ExpandProperty PrivateKeyPath
            if ($keyPath) {
                $sshArgs += @("-i", $keyPath)
            }
        }
        
        if ($Username) {
            $target = "$Username@$Hostname"
        }
        else {
            $target = $Hostname
        }
        
        $sshArgs += @($target, "echo", "SSH_CONNECTION_TEST_SUCCESS")
        
        Write-SecurityLog -Level Debug -Message "Testing SSH connection to $target"
        
        $result = & ssh @sshArgs 2>&1
        
        if ($LASTEXITCODE -eq 0 -and $result -match "SSH_CONNECTION_TEST_SUCCESS") {
            Write-SecurityLog -Message "SSH connection test successful" -Data @{ Target = $target; Port = $Port }
            
            # Update last used timestamp for profile
            if ($PSCmdlet.ParameterSetName -eq 'Profile') {
                $script:ConnectionProfiles[$ProfileName].LastUsed = Get-Date
                Save-ConnectionProfiles
            }
            
            return $true
        }
        else {
            Write-SecurityLog -Level Warning -Message "SSH connection test failed" -Data @{ 
                Target = $target
                Port = $Port
                ExitCode = $LASTEXITCODE
                Output = $result
            }
            return $false
        }
    }
    catch {
        Write-SecurityLog -Level Error -Message "SSH connection test error: $_"
        return $false
    }
}

# Execute command on remote host
function Invoke-SSHCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Profile')]
        [string]$ProfileName,
        
        [Parameter(Mandatory, ParameterSetName = 'Direct')]
        [string]$Hostname,
        
        [Parameter(ParameterSetName = 'Direct')]
        [string]$Username,
        
        [Parameter(ParameterSetName = 'Direct')]
        [int]$Port = 22,
        
        [Parameter(ParameterSetName = 'Direct')]
        [string]$SSHKeyName,
        
        [Parameter(Mandatory)]
        [string]$Command,
        
        [int]$TimeoutSeconds = 300
    )
    
    Initialize-SecurityModule
    
    if (-not (Test-SSHAvailability)) {
        throw "SSH client not available"
    }
    
    if ($PSCmdlet.ParameterSetName -eq 'Profile') {
        $profile = Get-ConnectionProfile -ProfileName $ProfileName
        if (-not $profile) {
            throw "Connection profile '$ProfileName' not found"
        }
        
        $Hostname = $profile.Hostname
        $Username = $profile.Username
        $Port = $profile.Port
        $SSHKeyName = $profile.SSHKeyName
    }
    
    try {
        $sshArgs = @(
            "-o", "ConnectTimeout=$TimeoutSeconds"
            "-o", "StrictHostKeyChecking=no"
            "-p", $Port.ToString()
        )
        
        if ($SSHKeyName) {
            $keyPath = Get-SSHKey -KeyName $SSHKeyName | Select-Object -ExpandProperty PrivateKeyPath
            if ($keyPath) {
                $sshArgs += @("-i", $keyPath)
            }
        }
        
        if ($Username) {
            $target = "$Username@$Hostname"
        }
        else {
            $target = $Hostname
        }
        
        $sshArgs += @($target, $Command)
        
        Write-SecurityLog -Message "Executing SSH command" -Data @{ 
            Target = $target
            Command = $Command
            Port = $Port
        }
        
        $output = & ssh @sshArgs 2>&1
        
        $result = @{
            ExitCode = $LASTEXITCODE
            Output = $output
            Command = $Command
            Target = $target
            Success = ($LASTEXITCODE -eq 0)
        }
        
        if ($result.Success) {
            Write-SecurityLog -Message "SSH command executed successfully" -Data @{ Target = $target }
        }
        else {
            Write-SecurityLog -Level Warning -Message "SSH command failed" -Data @{ 
                Target = $target
                ExitCode = $LASTEXITCODE
            }
        }
        
        # Update last used timestamp for profile
        if ($PSCmdlet.ParameterSetName -eq 'Profile') {
            $script:ConnectionProfiles[$ProfileName].LastUsed = Get-Date
            Save-ConnectionProfiles
        }
        
        return $result
    }
    catch {
        Write-SecurityLog -Level Error -Message "SSH command execution error: $_"
        throw
    }
}

# Copy file to remote host
function Copy-FileToRemote {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Profile')]
        [string]$ProfileName,
        
        [Parameter(Mandatory, ParameterSetName = 'Direct')]
        [string]$Hostname,
        
        [Parameter(ParameterSetName = 'Direct')]
        [string]$Username,
        
        [Parameter(ParameterSetName = 'Direct')]
        [int]$Port = 22,
        
        [Parameter(ParameterSetName = 'Direct')]
        [string]$SSHKeyName,
        
        [Parameter(Mandatory)]
        [string]$LocalPath,
        
        [Parameter(Mandatory)]
        [string]$RemotePath,
        
        [switch]$Recursive
    )
    
    Initialize-SecurityModule
    
    if (-not (Test-SSHAvailability)) {
        throw "SSH client not available"
    }
    
    if (-not (Test-Path $LocalPath)) {
        throw "Local path not found: $LocalPath"
    }
    
    if ($PSCmdlet.ParameterSetName -eq 'Profile') {
        $profile = Get-ConnectionProfile -ProfileName $ProfileName
        if (-not $profile) {
            throw "Connection profile '$ProfileName' not found"
        }
        
        $Hostname = $profile.Hostname
        $Username = $profile.Username
        $Port = $profile.Port
        $SSHKeyName = $profile.SSHKeyName
    }
    
    try {
        $scpArgs = @(
            "-o", "StrictHostKeyChecking=no"
            "-P", $Port.ToString()
        )
        
        if ($Recursive) {
            $scpArgs += "-r"
        }
        
        if ($SSHKeyName) {
            $keyPath = Get-SSHKey -KeyName $SSHKeyName | Select-Object -ExpandProperty PrivateKeyPath
            if ($keyPath) {
                $scpArgs += @("-i", $keyPath)
            }
        }
        
        if ($Username) {
            $target = "$Username@${Hostname}:$RemotePath"
        }
        else {
            $target = "${Hostname}:$RemotePath"
        }
        
        $scpArgs += @($LocalPath, $target)
        
        Write-SecurityLog -Message "Copying file to remote host" -Data @{
            LocalPath = $LocalPath
            RemotePath = $RemotePath
            Target = $target
            Recursive = $Recursive
        }
        
        $output = & scp @scpArgs 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-SecurityLog -Message "File copied successfully to remote host"
            
            # Update last used timestamp for profile
            if ($PSCmdlet.ParameterSetName -eq 'Profile') {
                $script:ConnectionProfiles[$ProfileName].LastUsed = Get-Date
                Save-ConnectionProfiles
            }
            
            return $true
        }
        else {
            Write-SecurityLog -Level Error -Message "File copy failed" -Data @{
                ExitCode = $LASTEXITCODE
                Output = $output
            }
            return $false
        }
    }
    catch {
        Write-SecurityLog -Level Error -Message "File copy error: $_"
        throw
    }
}

# Deploy script to remote host and execute
function Invoke-RemoteScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Profile')]
        [string]$ProfileName,
        
        [Parameter(Mandatory, ParameterSetName = 'Direct')]
        [string]$Hostname,
        
        [Parameter(ParameterSetName = 'Direct')]
        [string]$Username,
        
        [Parameter(ParameterSetName = 'Direct')]
        [int]$Port = 22,
        
        [Parameter(ParameterSetName = 'Direct')]
        [string]$SSHKeyName,
        
        [Parameter(Mandatory)]
        [string]$ScriptPath,
        
        [string[]]$Arguments = @(),
        
        [string]$WorkingDirectory = "/tmp",
        
        [switch]$RemoveAfterExecution
    )
    
    Initialize-SecurityModule
    
    if (-not (Test-Path $ScriptPath)) {
        throw "Script not found: $ScriptPath"
    }
    
    $scriptName = Split-Path $ScriptPath -Leaf
    $remoteScriptPath = "$WorkingDirectory/$scriptName"
    
    try {
        # Copy script to remote host
        $copyParams = @{
            LocalPath = $ScriptPath
            RemotePath = $remoteScriptPath
        }
        
        if ($PSCmdlet.ParameterSetName -eq 'Profile') {
            $copyParams.ProfileName = $ProfileName
        }
        else {
            $copyParams.Hostname = $Hostname
            if ($Username) { $copyParams.Username = $Username }
            if ($Port -ne 22) { $copyParams.Port = $Port }
            if ($SSHKeyName) { $copyParams.SSHKeyName = $SSHKeyName }
        }
        
        $copyResult = Copy-FileToRemote @copyParams
        
        if (-not $copyResult) {
            throw "Failed to copy script to remote host"
        }
        
        # Make script executable
        $chmodCommand = "chmod +x '$remoteScriptPath'"
        $executeParams = @{
            Command = $chmodCommand
        }
        
        if ($PSCmdlet.ParameterSetName -eq 'Profile') {
            $executeParams.ProfileName = $ProfileName
        }
        else {
            $executeParams.Hostname = $Hostname
            if ($Username) { $executeParams.Username = $Username }
            if ($Port -ne 22) { $executeParams.Port = $Port }
            if ($SSHKeyName) { $executeParams.SSHKeyName = $SSHKeyName }
        }
        
        $chmodResult = Invoke-SSHCommand @executeParams
        
        if (-not $chmodResult.Success) {
            Write-SecurityLog -Level Warning -Message "Failed to make script executable, continuing anyway"
        }
        
        # Execute script
        $scriptCommand = "'$remoteScriptPath'"
        if ($Arguments.Count -gt 0) {
            $scriptCommand += " " + ($Arguments -join " ")
        }
        
        $executeParams.Command = $scriptCommand
        $scriptResult = Invoke-SSHCommand @executeParams
        
        # Clean up if requested
        if ($RemoveAfterExecution) {
            $cleanupParams = $executeParams.Clone()
            $cleanupParams.Command = "rm -f '$remoteScriptPath'"
            $cleanupResult = Invoke-SSHCommand @cleanupParams
            
            if ($cleanupResult.Success) {
                Write-SecurityLog -Level Debug -Message "Remote script cleaned up successfully"
            }
        }
        
        Write-SecurityLog -Message "Remote script execution completed" -Data @{
            ScriptPath = $ScriptPath
            RemoteScriptPath = $remoteScriptPath
            ExitCode = $scriptResult.ExitCode
            Success = $scriptResult.Success
        }
        
        return $scriptResult
    }
    catch {
        Write-SecurityLog -Level Error -Message "Remote script execution failed: $_"
        throw
    }
}

# Save connection profiles to persistent storage
function Save-ConnectionProfiles {
    [CmdletBinding()]
    param()
    
    $configDir = if ($IsWindows) {
        Join-Path $env:USERPROFILE ".aitherzero"
    } else {
        Join-Path $env:HOME ".aitherzero"
    }
    
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    
    $profilesPath = Join-Path $configDir "connection-profiles.json"
    
    try {
        $script:ConnectionProfiles | ConvertTo-Json -Depth 10 | Out-File -FilePath $profilesPath -Encoding UTF8
        Write-SecurityLog -Level Debug -Message "Connection profiles saved to: $profilesPath"
    }
    catch {
        Write-SecurityLog -Level Error -Message "Failed to save connection profiles: $_"
    }
}

# Load connection profiles from persistent storage
function Load-ConnectionProfiles {
    [CmdletBinding()]
    param()
    
    $configDir = if ($IsWindows) {
        Join-Path $env:USERPROFILE ".aitherzero"
    } else {
        Join-Path $env:HOME ".aitherzero"
    }
    
    $profilesPath = Join-Path $configDir "connection-profiles.json"
    
    if (Test-Path $profilesPath) {
        try {
            $profilesData = Get-Content -Path $profilesPath -Raw | ConvertFrom-Json
            
            # Convert from PSCustomObject to hashtable
            $script:ConnectionProfiles = @{}
            foreach ($property in $profilesData.PSObject.Properties) {
                $script:ConnectionProfiles[$property.Name] = @{}
                foreach ($subProperty in $property.Value.PSObject.Properties) {
                    $script:ConnectionProfiles[$property.Name][$subProperty.Name] = $subProperty.Value
                }
            }
            
            Write-SecurityLog -Level Debug -Message "Connection profiles loaded from: $profilesPath"
        }
        catch {
            Write-SecurityLog -Level Warning -Message "Failed to load connection profiles: $_"
            $script:ConnectionProfiles = @{}
        }
    }
}

# Export public functions
Export-ModuleMember -Function @(
    'Initialize-SecurityModule',
    'Test-SSHAvailability',
    'New-SSHKeyPair',
    'Get-SSHKey',
    'Get-SSHKeyFingerprint',
    'Remove-SSHKey',
    'Set-SecureCredential',
    'Get-SecureCredential',
    'New-ConnectionProfile',
    'Get-ConnectionProfile',
    'Remove-ConnectionProfile',
    'Test-SSHConnection',
    'Invoke-SSHCommand',
    'Copy-FileToRemote',
    'Invoke-RemoteScript'
)

# Initialize module on import
Initialize-SecurityModule