function Get-ConnectionMetadataPath {
    [CmdletBinding()]
    param()

    return Get-ConnectionStoragePath
}

function Get-ConnectionConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConnectionName
    )

    try {
        $storagePath = Get-ConnectionStoragePath
        $configFile = Join-Path $storagePath "$ConnectionName.json"

        if (-not (Test-Path $configFile)) {
            return @{ Success = $false; Error = "Connection configuration not found" }
        }

        $config = Get-Content -Path $configFile -Raw | ConvertFrom-Json
        return @{ Success = $true; Configuration = $config }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get connection configuration: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Save-ConnectionConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ConnectionData
    )

    try {
        $storagePath = Get-ConnectionStoragePath
        if (-not (Test-Path $storagePath)) {
            New-Item -Path $storagePath -ItemType Directory -Force | Out-Null
        }

        $configFile = Join-Path $storagePath "$($ConnectionData.Name).json"
        $ConnectionData | ConvertTo-Json -Depth 10 | Set-Content -Path $configFile -Encoding UTF8

        return @{ Success = $true }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to save connection configuration: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Remove-ConnectionConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConnectionName
    )

    try {
        $storagePath = Get-ConnectionStoragePath
        $configFile = Join-Path $storagePath "$ConnectionName.json"

        if (-not (Test-Path $configFile)) {
            return @{ Success = $false; Error = "Connection configuration not found" }
        }

        Remove-Item -Path $configFile -Force
        return @{ Success = $true }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to remove connection configuration: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Get-ConnectionStoragePath {
    [CmdletBinding()]
    param()

    # Cross-platform storage path
    if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') {
        $basePath = Join-Path $env:APPDATA 'AitherZero'
    } elseif ($IsLinux) {
        $basePath = Join-Path $env:HOME '.config/aitherzero'
    } elseif ($IsMacOS) {
        $basePath = Join-Path $env:HOME 'Library/Application Support/AitherZero'
    } else {
        $basePath = Join-Path (Get-Location) '.aitherzero'
    }

    return Join-Path $basePath 'connections'
}

function Connect-SSHEndpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 30
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Establishing SSH connection to: $($Config.HostName)"

        # Get credential if specified
        $credential = $null
        if ($Config.CredentialName) {
            $credResult = Get-SecureCredential -CredentialName $Config.CredentialName
            if ($credResult) {
                $credential = $credResult
            }
        }

        # Simulate SSH connection (replace with actual SSH implementation)
        $sessionInfo = @{
            ConnectionName = $Config.Name
            EndpointType = 'SSH'
            HostName = $Config.HostName
            Port = $Config.Port
            Connected = $true
            ConnectedAt = Get-Date
        }

        Write-CustomLog -Level 'SUCCESS' -Message "SSH connection established: $($Config.HostName)"
        return @{ Success = $true; Session = $sessionInfo }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "SSH connection failed: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Connect-WinRMEndpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 30
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Establishing WinRM connection to: $($Config.HostName)"

        # Get credential if specified
        $credential = $null
        if ($Config.CredentialName) {
            $credResult = Get-SecureCredential -CredentialName $Config.CredentialName
            if ($credResult) {
                $credential = $credResult
            }
        }

        # Simulate WinRM connection (replace with actual WinRM implementation)
        $sessionInfo = @{
            ConnectionName = $Config.Name
            EndpointType = 'WinRM'
            HostName = $Config.HostName
            Port = $Config.Port
            Connected = $true
            ConnectedAt = Get-Date
        }

        Write-CustomLog -Level 'SUCCESS' -Message "WinRM connection established: $($Config.HostName)"
        return @{ Success = $true; Session = $sessionInfo }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "WinRM connection failed: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

# VMware endpoint connection
function Connect-VMwareEndpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 30
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Establishing VMware connection to: $($Config.HostName)"

        # Get credential if specified
        $credential = $null
        if ($Config.CredentialName) {
            $credResult = Get-SecureCredential -CredentialName $Config.CredentialName
            if ($credResult) {
                $credential = $credResult
            }
        }

        # Check if VMware PowerCLI is available
        if (-not (Get-Module -Name VMware.PowerCLI -ListAvailable)) {
            throw "VMware PowerCLI module not found. Please install with: Install-Module VMware.PowerCLI"
        }

        # Import VMware modules
        Import-Module VMware.PowerCLI -Force

        # Configure PowerCLI settings
        Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -Scope Session

        # Connect to VMware endpoint
        $connectParams = @{
            Server = $Config.HostName
            Port = $Config.Port
        }

        if ($credential) {
            $connectParams['Credential'] = $credential
        }

        $connection = Connect-VIServer @connectParams

        $sessionInfo = @{
            ConnectionName = $Config.Name
            EndpointType = 'VMware'
            HostName = $Config.HostName
            Port = $Config.Port
            Connected = $true
            ConnectedAt = Get-Date
            SessionId = $connection.SessionId
            Connection = $connection
        }

        Write-CustomLog -Level 'SUCCESS' -Message "VMware connection established: $($Config.HostName)"
        return @{ Success = $true; Session = $sessionInfo }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "VMware connection failed: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

# Hyper-V endpoint connection
function Connect-HyperVEndpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 30
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Establishing Hyper-V connection to: $($Config.HostName)"

        # Get credential if specified
        $credential = $null
        if ($Config.CredentialName) {
            $credResult = Get-SecureCredential -CredentialName $Config.CredentialName
            if ($credResult) {
                $credential = $credResult
            }
        }

        # Test if Hyper-V module is available
        if (-not (Get-Module -Name Hyper-V -ListAvailable)) {
            throw "Hyper-V module not found. Please install Hyper-V management tools."
        }

        # Import Hyper-V module
        Import-Module Hyper-V -Force

        # Test connection to Hyper-V host
        $testParams = @{
            ComputerName = $Config.HostName
        }

        if ($credential) {
            $testParams['Credential'] = $credential
        }

        # Test basic connectivity
        $testResult = Test-NetConnection -ComputerName $Config.HostName -Port $Config.Port -InformationLevel Quiet
        if (-not $testResult) {
            throw "Cannot connect to Hyper-V host $($Config.HostName) on port $($Config.Port)"
        }

        $sessionInfo = @{
            ConnectionName = $Config.Name
            EndpointType = 'Hyper-V'
            HostName = $Config.HostName
            Port = $Config.Port
            Connected = $true
            ConnectedAt = Get-Date
            Credential = $credential
        }

        Write-CustomLog -Level 'SUCCESS' -Message "Hyper-V connection established: $($Config.HostName)"
        return @{ Success = $true; Session = $sessionInfo }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Hyper-V connection failed: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

# Docker endpoint connection
function Connect-DockerEndpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 30
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Establishing Docker connection to: $($Config.HostName)"

        # Build Docker endpoint URL
        $protocol = if ($Config.EnableSSL) { 'https' } else { 'http' }
        $dockerUrl = "${protocol}://$($Config.HostName):$($Config.Port)"

        # Test Docker API connectivity
        $headers = @{}
        if ($Config.EnableSSL) {
            # For TLS connections, we might need certificates
            # This is a simplified implementation
            $headers['Content-Type'] = 'application/json'
        }

        try {
            $response = Invoke-RestMethod -Uri "$dockerUrl/version" -Headers $headers -TimeoutSec $TimeoutSeconds
            $dockerVersion = $response.Version
        }
        catch {
            throw "Cannot connect to Docker API at $dockerUrl : $($_.Exception.Message)"
        }

        $sessionInfo = @{
            ConnectionName = $Config.Name
            EndpointType = 'Docker'
            HostName = $Config.HostName
            Port = $Config.Port
            Connected = $true
            ConnectedAt = Get-Date
            DockerUrl = $dockerUrl
            Version = $dockerVersion
            EnableSSL = $Config.EnableSSL
        }

        Write-CustomLog -Level 'SUCCESS' -Message "Docker connection established: $($Config.HostName) (Version: $dockerVersion)"
        return @{ Success = $true; Session = $sessionInfo }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Docker connection failed: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

# Kubernetes endpoint connection
function Connect-KubernetesEndpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 30
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Establishing Kubernetes connection to: $($Config.HostName)"

        # Get credential if specified
        $credential = $null
        if ($Config.CredentialName) {
            $credResult = Get-SecureCredential -CredentialName $Config.CredentialName
            if ($credResult) {
                $credential = $credResult
            }
        }

        # Check if kubectl is available
        if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
            throw "kubectl command not found. Please install kubectl."
        }

        # Build kubectl server URL
        $serverUrl = "https://$($Config.HostName):$($Config.Port)"

        # Test basic connectivity to Kubernetes API
        try {
            $testCmd = "kubectl cluster-info --server=$serverUrl --insecure-skip-tls-verify"
            $clusterInfo = Invoke-Expression $testCmd
        }
        catch {
            throw "Cannot connect to Kubernetes API at $serverUrl : $($_.Exception.Message)"
        }

        $sessionInfo = @{
            ConnectionName = $Config.Name
            EndpointType = 'Kubernetes'
            HostName = $Config.HostName
            Port = $Config.Port
            Connected = $true
            ConnectedAt = Get-Date
            ServerUrl = $serverUrl
            Credential = $credential
            Namespace = $Config.KubernetesOptions.Namespace
        }

        Write-CustomLog -Level 'SUCCESS' -Message "Kubernetes connection established: $($Config.HostName)"
        return @{ Success = $true; Session = $sessionInfo }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Kubernetes connection failed: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Disconnect-EndpointSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConnectionName
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Disconnecting session: $ConnectionName"
        # Implement actual disconnection logic here
        return @{ Success = $true }
    }
    catch {
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Get-AllConnectionConfigs {
    [CmdletBinding()]
    param()

    try {
        $storagePath = Get-ConnectionStoragePath
        if (-not (Test-Path $storagePath)) {
            return @{ Success = $true; Configurations = @() }
        }

        $configFiles = Get-ChildItem -Path $storagePath -Filter "*.json"
        $configurations = @()

        foreach ($file in $configFiles) {
            try {
                $config = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
                $configurations += $config
            }
            catch {
                Write-CustomLog -Level 'WARN' -Message "Failed to load configuration file: $($file.Name)"
            }
        }

        return @{ Success = $true; Configurations = $configurations }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get all connection configurations: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Test-EndpointConnectivity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostName,

        [Parameter()]
        [int]$Port = 22,

        [Parameter()]
        [int]$TimeoutSeconds = 30
    )

    try {
        # Simple connectivity test using Test-NetConnection if available, otherwise use a basic approach
        if (Get-Command Test-NetConnection -ErrorAction SilentlyContinue) {
            $result = Test-NetConnection -ComputerName $HostName -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue
            return $result
        } else {
            # Fallback for cross-platform compatibility
            try {
                $tcpClient = New-Object System.Net.Sockets.TcpClient
                $asyncResult = $tcpClient.BeginConnect($HostName, $Port, $null, $null)
                $wait = $asyncResult.AsyncWaitHandle.WaitOne($TimeoutSeconds * 1000, $false)

                if ($wait) {
                    $tcpClient.EndConnect($asyncResult)
                    $tcpClient.Close()
                    return $true
                } else {
                    $tcpClient.Close()
                    return $false
                }
            } catch {
                return $false
            }
        }
    } catch {
        return $false
    }
}

# Session management functions
function Start-SSHSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $false)]
        [int]$Timeout = 30
    )

    return Connect-SSHEndpoint -Config $Config -TimeoutSeconds $Timeout
}

function Start-WinRMSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $false)]
        [int]$Timeout = 30
    )

    return Connect-WinRMEndpoint -Config $Config -TimeoutSeconds $Timeout
}

function Start-VMwareSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $false)]
        [int]$Timeout = 30
    )

    return Connect-VMwareEndpoint -Config $Config -TimeoutSeconds $Timeout
}

function Start-HyperVSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $false)]
        [int]$Timeout = 30
    )

    return Connect-HyperVEndpoint -Config $Config -TimeoutSeconds $Timeout
}

function Start-DockerSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $false)]
        [int]$Timeout = 30
    )

    return Connect-DockerEndpoint -Config $Config -TimeoutSeconds $Timeout
}

function Start-KubernetesSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $false)]
        [int]$Timeout = 30
    )

    return Connect-KubernetesEndpoint -Config $Config -TimeoutSeconds $Timeout
}

# Command execution functions
function Invoke-SSHCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters = @{},

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 300,

        [Parameter(Mandatory = $false)]
        [switch]$AsJob
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Executing SSH command: $Command"

        # Get credential if specified
        $credential = $null
        if ($Config.CredentialName) {
            $credResult = Get-SecureCredential -CredentialName $Config.CredentialName
            if ($credResult) {
                $credential = $credResult
            }
        }

        # Check if SSH client is available
        if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
            throw "SSH client not found. Please install OpenSSH client."
        }

        # Build SSH command
        $sshCommand = "ssh"
        if ($Config.Port -ne 22) {
            $sshCommand += " -p $($Config.Port)"
        }

        # Add SSH options
        if ($Config.SSHOptions) {
            if ($Config.SSHOptions.StrictHostKeyChecking -eq $false) {
                $sshCommand += " -o StrictHostKeyChecking=no"
            }
            if ($Config.SSHOptions.UserKnownHostsFile) {
                $sshCommand += " -o UserKnownHostsFile=$($Config.SSHOptions.UserKnownHostsFile)"
            }
        }

        # Add username and host
        if ($credential) {
            $username = $credential.UserName
        } else {
            $username = "root"
        }

        $sshCommand += " $username@$($Config.HostName) '$Command'"

        if ($AsJob) {
            $job = Start-Job -ScriptBlock {
                param($SshCmd)
                Invoke-Expression $SshCmd
            } -ArgumentList $sshCommand

            return @{
                Success = $true
                Output = "Command started as job"
                ExitCode = 0
                Job = $job
            }
        } else {
            $output = Invoke-Expression $sshCommand
            $exitCode = $LASTEXITCODE

            return @{
                Success = $exitCode -eq 0
                Output = $output
                ExitCode = $exitCode
            }
        }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "SSH command execution failed: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
            ExitCode = 1
        }
    }
}

function Invoke-WinRMCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters = @{},

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 300,

        [Parameter(Mandatory = $false)]
        [switch]$AsJob
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Executing WinRM command: $Command"

        # Get credential if specified
        $credential = $null
        if ($Config.CredentialName) {
            $credResult = Get-SecureCredential -CredentialName $Config.CredentialName
            if ($credResult) {
                $credential = $credResult
            }
        }

        # Build session options
        $sessionOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck
        if ($Config.WinRMOptions.AllowUnencrypted) {
            $sessionOptions.UseSSL = $false
        }

        # Create session parameters
        $sessionParams = @{
            ComputerName = $Config.HostName
            Port = $Config.Port
            SessionOption = $sessionOptions
        }

        if ($credential) {
            $sessionParams['Credential'] = $credential
        }

        if ($Config.EnableSSL) {
            $sessionParams['UseSSL'] = $true
        }

        # Create script block
        $scriptBlock = [scriptblock]::Create($Command)

        if ($AsJob) {
            $job = Invoke-Command @sessionParams -ScriptBlock $scriptBlock -AsJob
            return @{
                Success = $true
                Output = "Command started as job"
                ExitCode = 0
                Job = $job
            }
        } else {
            $output = Invoke-Command @sessionParams -ScriptBlock $scriptBlock
            return @{
                Success = $true
                Output = $output
                ExitCode = 0
            }
        }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "WinRM command execution failed: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
            ExitCode = 1
        }
    }
}

function Invoke-VMwareCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters = @{},

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 300,

        [Parameter(Mandatory = $false)]
        [switch]$AsJob
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Executing VMware command: $Command"

        # Ensure VMware connection is established
        if (-not $global:DefaultVIServer) {
            $connectResult = Connect-VMwareEndpoint -Config $Config -TimeoutSeconds 30
            if (-not $connectResult.Success) {
                throw "VMware connection failed: $($connectResult.Error)"
            }
        }

        # Create script block
        $scriptBlock = [scriptblock]::Create($Command)

        if ($AsJob) {
            $job = Start-Job -ScriptBlock $scriptBlock
            return @{
                Success = $true
                Output = "Command started as job"
                ExitCode = 0
                Job = $job
            }
        } else {
            $output = & $scriptBlock
            return @{
                Success = $true
                Output = $output
                ExitCode = 0
            }
        }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "VMware command execution failed: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
            ExitCode = 1
        }
    }
}

function Invoke-HyperVCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters = @{},

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 300,

        [Parameter(Mandatory = $false)]
        [switch]$AsJob
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Executing Hyper-V command: $Command"

        # Get credential if specified
        $credential = $null
        if ($Config.CredentialName) {
            $credResult = Get-SecureCredential -CredentialName $Config.CredentialName
            if ($credResult) {
                $credential = $credResult
            }
        }

        # Build command with ComputerName parameter
        $commandWithHost = $Command -replace '(Get-VM|Start-VM|Stop-VM|New-VM|Remove-VM)', '$1 -ComputerName $($Config.HostName)'

        if ($credential) {
            $commandWithHost += " -Credential `$credential"
        }

        # Create script block
        $scriptBlock = [scriptblock]::Create($commandWithHost)

        if ($AsJob) {
            $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $Config, $credential
            return @{
                Success = $true
                Output = "Command started as job"
                ExitCode = 0
                Job = $job
            }
        } else {
            $output = & $scriptBlock
            return @{
                Success = $true
                Output = $output
                ExitCode = 0
            }
        }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Hyper-V command execution failed: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
            ExitCode = 1
        }
    }
}

function Invoke-DockerCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters = @{},

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 300,

        [Parameter(Mandatory = $false)]
        [switch]$AsJob
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Executing Docker command: $Command"

        # Build Docker endpoint URL
        $protocol = if ($Config.EnableSSL) { 'https' } else { 'http' }
        $dockerUrl = "${protocol}://$($Config.HostName):$($Config.Port)"

        # Set Docker host environment variable
        $env:DOCKER_HOST = $dockerUrl

        if ($Config.EnableSSL) {
            $env:DOCKER_TLS_VERIFY = "1"
        }

        if ($AsJob) {
            $job = Start-Job -ScriptBlock {
                param($DockerCmd, $DockerHost, $TlsVerify)
                $env:DOCKER_HOST = $DockerHost
                if ($TlsVerify) { $env:DOCKER_TLS_VERIFY = "1" }
                Invoke-Expression $DockerCmd
            } -ArgumentList $Command, $dockerUrl, $Config.EnableSSL

            return @{
                Success = $true
                Output = "Command started as job"
                ExitCode = 0
                Job = $job
            }
        } else {
            $output = Invoke-Expression $Command
            $exitCode = $LASTEXITCODE

            return @{
                Success = $exitCode -eq 0
                Output = $output
                ExitCode = $exitCode
            }
        }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Docker command execution failed: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
            ExitCode = 1
        }
    }
}

function Invoke-KubernetesCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters = @{},

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 300,

        [Parameter(Mandatory = $false)]
        [switch]$AsJob
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Executing Kubernetes command: $Command"

        # Build kubectl command with server and namespace
        $serverUrl = "https://$($Config.HostName):$($Config.Port)"
        $kubectlCommand = $Command

        if ($kubectlCommand -notlike "*--server=*") {
            $kubectlCommand += " --server=$serverUrl"
        }

        if ($Config.KubernetesOptions.Namespace -and $kubectlCommand -notlike "*--namespace=*") {
            $kubectlCommand += " --namespace=$($Config.KubernetesOptions.Namespace)"
        }

        if ($Config.KubernetesOptions.SkipTLSVerify) {
            $kubectlCommand += " --insecure-skip-tls-verify"
        }

        if ($AsJob) {
            $job = Start-Job -ScriptBlock {
                param($KubectlCmd)
                Invoke-Expression $KubectlCmd
            } -ArgumentList $kubectlCommand

            return @{
                Success = $true
                Output = "Command started as job"
                ExitCode = 0
                Job = $job
            }
        } else {
            $output = Invoke-Expression $kubectlCommand
            $exitCode = $LASTEXITCODE

            return @{
                Success = $exitCode -eq 0
                Output = $output
                ExitCode = $exitCode
            }
        }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Kubernetes command execution failed: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
            ExitCode = 1
        }
    }
}
