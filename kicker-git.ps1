<#
.SYNOPSIS
    Cross-compatible bootstrap script for Aitherium Infrastructure Automation with CoreApp orchestration.

.DESCRIPTION
    This is the single entry point for downloading and setting up the entire Aitherium suite.
    Compatible with both PowerShell 5.1 and 7.x, with robust cross-platform support.

    Features:
    - Full compatibility with PowerShell 5.1 and 7.x
    - Cross-platform support (Windows, Linux, macOS)
    - Self-updating capabilities
    - Comprehensive error handling and logging
    - Integration with CoreApp orchestration
    - Non-interactive mode support
    - Robust dependency management
    - Health checks and validation
    - Progressive enhancement based on PowerShell version

.PARAMETER ConfigFile
    Path to custom configuration file. If not specified, will use default configuration.

.PARAMETER Quiet
    Run in quiet mode with minimal output.

.PARAMETER NonInteractive
    Run without any interactive prompts (suitable for automation).

.PARAMETER Verbosity
    Controls output verbosity: silent, normal, detailed.

.PARAMETER SkipPrerequisites
    Skip automatic installation of prerequisites (Git, GitHub CLI, PowerShell).

.PARAMETER SkipGitHubAuth
    Skip GitHub authentication check.

.PARAMETER TargetBranch
    Specify which branch to bootstrap from (default: main).

.PARAMETER LocalPath
    Custom local path for repository clone (default: temp directory).

.PARAMETER Force
    Force re-clone even if repository already exists.

.EXAMPLE
    # PowerShell 5.1 and 7.x compatible one-liner
    iex (iwr 'https://raw.githubusercontent.com/Aitherium/AitherLabs/main/kicker-git.ps1').Content

.EXAMPLE
    # Traditional Windows PowerShell 5.1
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Aitherium/AitherLabs/main/kicker-git.ps1' -OutFile '.\kicker-git.ps1'; .\kicker-git.ps1"

.EXAMPLE
    # PowerShell 7.x (cross-platform)
    pwsh -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Aitherium/AitherLabs/main/kicker-git.ps1' -OutFile '.\kicker-git.ps1'; .\kicker-git.ps1"

.EXAMPLE
    # Cross-platform bootstrap with custom configuration
    ./kicker-git.ps1 -ConfigFile "my-lab-config.json"

.EXAMPLE
    # Non-interactive automation-friendly bootstrap
    ./kicker-git.ps1 -NonInteractive -Verbosity silent

.EXAMPLE
    # Bootstrap from development branch
    .\kicker-git.ps1 -TargetBranch "develop" -Verbosity detailed

.EXAMPLE
    # CI/CD pipeline usage - PowerShell 7
    curl -sL https://raw.githubusercontent.com/Aitherium/AitherLabs/main/kicker-git.ps1 | pwsh -

.EXAMPLE
    # CI/CD pipeline usage - PowerShell 5.1
    curl -sL https://raw.githubusercontent.com/Aitherium/AitherLabs/main/kicker-git.ps1 | powershell -
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ConfigFile,
    [switch]$Quiet,
    [switch]$NonInteractive,
    [ValidateSet('silent', 'normal', 'detailed')]
    [string]$Verbosity = 'normal',
    [switch]$SkipPrerequisites,
    [switch]$SkipGitHubAuth,
    [string]$TargetBranch = 'main',
    [string]$LocalPath,
    [switch]$Force
)

#Requires -Version 5.1

# Bootstrap constants
$script:BootstrapVersion = '2.1.0'
$script:RepoUrl = 'https://github.com/Aitherium/AitherLabs.git'
$script:RawBaseUrl = 'https://raw.githubusercontent.com/Aitherium/AitherLabs'
$script:DefaultConfigUrl = "$script:RawBaseUrl/$TargetBranch/core-runner/core_app/default-config.json"

# PowerShell version compatibility detection
$script:IsPowerShell7Plus = $PSVersionTable.PSVersion.Major -ge 7
$script:IsPowerShell5 = $PSVersionTable.PSVersion.Major -eq 5

# Cross-platform detection (with fallback for PowerShell 5.1)
if ($script:IsPowerShell7Plus) {
    # PowerShell 7+ has RuntimeInformation
    $script:PlatformWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
    $script:PlatformLinux = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)
    $script:PlatformMacOS = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)
} else {
    # PowerShell 5.1 fallback detection
    $script:PlatformWindows = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
    $script:PlatformLinux = $false
    $script:PlatformMacOS = $false

    # Additional check for non-Windows in PowerShell 5.1
    if (-not $script:PlatformWindows) {
        if ($env:OS -eq 'linux' -or $IsLinux) {
            $script:PlatformLinux = $true
        } elseif ($env:OS -eq 'darwin' -or $IsMacOS) {
            $script:PlatformMacOS = $true
        }
    }
}

# Interactive detection (compatible with both versions)
if ($script:IsPowerShell7Plus) {
    $script:IsInteractive = $null -ne $Host.UI.RawUI -and [Environment]::UserInteractive
} else {
    # PowerShell 5.1 compatible detection
    $script:IsInteractive = $Host.Name -ne 'ServerRemoteHost' -and [Environment]::UserInteractive
}

# Auto-detect non-interactive mode
if (-not $NonInteractive -and (-not $script:IsInteractive -or $env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true')) {
    $NonInteractive = $true
    Write-Verbose "Auto-detected non-interactive environment"
}

# Set verbosity
if ($Quiet) { $Verbosity = 'silent' }
$script:VerbosityLevel = @{ silent = 0; normal = 1; detailed = 2 }[$Verbosity]

# Cross-platform paths (compatible with both PowerShell versions)
function Get-PlatformTempPath {
    if ($script:PlatformWindows) {
        if ($env:TEMP) {
            return $env:TEMP
        } elseif ($env:TMP) {
            return $env:TMP
        } else {
            return 'C:/temp'
        }
    } elseif ($script:PlatformLinux -or $script:PlatformMacOS) {
        if ($env:TMPDIR) {
            return $env:TMPDIR
        } else {
            return '/tmp'
        }
    } else {
        Write-BootstrapLog -Message 'Unknown platform. Using fallback temp path.' -Level 'WARN'
        if ($script:PlatformWindows) {
            return 'C:/temp'
        } else {
            return '/tmp'
        }
    }
}

# Enhanced logging with PowerShell version compatibility
function Write-BootstrapLog {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO',

        [switch]$NoTimestamp    )

    $levelPriority = @{ INFO = 1; WARN = 1; ERROR = 0; SUCCESS = 1 }[$Level]

    if ($script:VerbosityLevel -ge $levelPriority) {
        $timestamp = if ($NoTimestamp) { '' } else { "[$(Get-Date -Format 'HH:mm:ss')] " }
        $colorMap = @{ INFO = 'White'; WARN = 'Yellow'; ERROR = 'Red'; SUCCESS = 'Green' }

        # Handle empty messages (for spacing)
        $displayMessage = if ([string]::IsNullOrEmpty($Message)) { '' } else { "$Level`: $Message" }

        # PowerShell 5.1 compatible color output
        try {
            Write-Host "$timestamp$displayMessage" -ForegroundColor $colorMap[$Level]
        } catch {
            # Fallback for environments without color support
            Write-Host "$timestamp$displayMessage"
        }
    }

    # Always log to file if possible (enhanced error handling)
    if ($script:LogFile -and -not [string]::IsNullOrEmpty($Message)) {
        try {
            $logDir = Split-Path $script:LogFile -Parent
            if (-not (Test-Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            }
            $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
            Add-Content -Path $script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
        } catch {
            # Silently ignore logging errors to prevent bootstrap failures
        }
    }
}

# Initialize logging after function definition
$script:LogFile = Join-Path (Get-PlatformTempPath) "opentofu-lab-bootstrap-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
New-Item -ItemType File -Path $script:LogFile -Force -ErrorAction SilentlyContinue | Out-Null

Write-BootstrapLog "Aitherium Bootstrap v$script:BootstrapVersion" 'SUCCESS'
Write-BootstrapLog "PowerShell Version: $($PSVersionTable.PSVersion)" 'INFO'
Write-BootstrapLog "PowerShell Edition: $($PSVersionTable.PSEdition)" 'INFO'
if ($PSVersionTable.OS) {
    Write-BootstrapLog "Platform: $($PSVersionTable.OS)" 'INFO'
} else {
    Write-BootstrapLog "Platform: Windows (PowerShell 5.1)" 'INFO'
}
Write-BootstrapLog "Compatibility Mode: PowerShell $($PSVersionTable.PSVersion.Major).x" 'INFO'

# Cross-platform PowerShell path detection (enhanced compatibility)
function Get-PlatformPowerShell {
    # Always prefer PowerShell 7+ if available
    if ($script:PlatformWindows) {
        $pwshPaths = @(
            "$env:ProgramFiles/PowerShell/7/pwsh.exe",
            "${env:ProgramFiles(x86)}/PowerShell/7/pwsh.exe",
            "pwsh.exe"
        )
        foreach ($path in $pwshPaths) {
            try {
                if (Get-Command $path -ErrorAction SilentlyContinue) {
                    return $path
                }
            } catch {
                continue
            }
        }
        # Fallback to Windows PowerShell 5.1
        return "powershell.exe"
    } else {
        # Unix-like systems
        try {
            $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
            if ($pwshCmd) {
                return $pwshCmd.Source
            }
        } catch {
            # Continue to fallback
        }

        # Check common installation paths
        $unixPaths = @('/usr/bin/pwsh', '/usr/local/bin/pwsh', '/opt/microsoft/powershell/7/pwsh')
        foreach ($path in $unixPaths) {
            if (Test-Path $path) {
                return $path
            }
        }

        # Last resort fallback
        return 'pwsh'
    }
}

# Error handling
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Dependency checking and installation
function Test-Prerequisite {
    param(
        [string]$Name,
        [string[]]$Commands,
        [string]$InstallUrl,
        [string]$InstallInstructions
    )

    Write-BootstrapLog "Checking prerequisite: $Name" 'INFO'

    foreach ($cmd in $Commands) {
        if (Get-Command $cmd -ErrorAction SilentlyContinue) {
            Write-BootstrapLog "OK $Name is available ($cmd)" 'SUCCESS'
            return $true
        }
    }

    Write-BootstrapLog "FAIL $Name not found" 'WARN'

    if ($SkipPrerequisites) {
        Write-BootstrapLog "Skipping $Name installation (SkipPrerequisites specified)" 'WARN'
        return $false
    }

    if ($NonInteractive) {
        Write-BootstrapLog "Cannot install $Name in non-interactive mode" 'ERROR'
        Write-BootstrapLog "Please install manually: $InstallInstructions" 'INFO'
        return $false
    }

    Write-BootstrapLog "Installation required for $Name" 'INFO'
    Write-BootstrapLog "Instructions: $InstallInstructions" 'INFO'

    if ($InstallUrl) {
        Write-BootstrapLog "Download: $InstallUrl" 'INFO'
    }

    return $false
}

# Enhanced web request function for PowerShell compatibility
function Invoke-CompatibleWebRequest {
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter(Mandatory)]
        [string]$OutFile,

        [switch]$UseBasicParsing
    )

    # Default to using basic parsing
    if (-not $PSBoundParameters.ContainsKey('UseBasicParsing')) {
        $UseBasicParsing = $true
    }

    try {
        if ($script:IsPowerShell7Plus) {
            # PowerShell 7+ - use modern approach
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing:$UseBasicParsing
        } else {
            # PowerShell 5.1 - use compatible approach
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add('User-Agent', 'PowerShell/5.1 OpenTofu-Lab-Bootstrap')

            # Handle TLS for older systems
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

            $webClient.DownloadFile($Uri, $OutFile)
            $webClient.Dispose()
        }
        return $true
    } catch {
        Write-BootstrapLog "Web request failed: $($_.Exception.Message)" 'ERROR'
        return $false
    }
}

# Enhanced Git installation for Windows (PowerShell version compatible)
function Install-GitForWindows {
    if (-not $script:PlatformWindows) { return $false }

    Write-BootstrapLog "Installing Git for Windows..." 'INFO'

    try {
        $gitUrl = "https://github.com/git-for-windows/git/releases/latest/download/Git-2.47.1-64-bit.exe"
        $gitInstaller = Join-Path (Get-PlatformTempPath) "Git-Installer.exe"

        if (-not (Invoke-CompatibleWebRequest -Uri $gitUrl -OutFile $gitInstaller)) {
            throw "Failed to download Git installer"
        }

        $process = Start-Process -FilePath $gitInstaller -ArgumentList "/SILENT", "/NORESTART" -Wait -NoNewWindow -PassThru
        Remove-Item $gitInstaller -ErrorAction SilentlyContinue
          if ($process.ExitCode -eq 0) {
            # Refresh PATH (PowerShell 5.1 compatible)
            $machinePath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
            $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
            $env:PATH = $machinePath + ';' + $userPath

            Write-BootstrapLog "Git installation completed successfully" 'SUCCESS'
            return $true
        } else {
            throw "Git installer returned exit code: $($process.ExitCode)"
        }
    } catch {
        Write-BootstrapLog "Git installation failed: $($_.Exception.Message)" 'ERROR'
        return $false
    }
}

function Install-PowerShell7 {
    if (-not $script:PlatformWindows) { return $false }

    Write-BootstrapLog "Installing PowerShell 7..." 'INFO'

    try {
        $pwshUrl = "https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7.4.6-win-x64.msi"
        $pwshInstaller = Join-Path (Get-PlatformTempPath) "PowerShell-7-Installer.msi"

        if (-not (Invoke-CompatibleWebRequest -Uri $pwshUrl -OutFile $pwshInstaller)) {
            throw "Failed to download PowerShell 7 installer"
        }

        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $pwshInstaller, "/quiet", "/norestart" -Wait -NoNewWindow -PassThru
        Remove-Item $pwshInstaller -ErrorAction SilentlyContinue

        if ($process.ExitCode -eq 0) {
            Write-BootstrapLog "PowerShell 7 installation completed successfully" 'SUCCESS'
            return $true
        } else {
            throw "PowerShell 7 installer returned exit code: $($process.ExitCode)"
        }
    } catch {
        Write-BootstrapLog "PowerShell 7 installation failed: $($_.Exception.Message)" 'ERROR'
        return $false
    }
}

# Enhanced GitHub authentication check
function Test-GitHubAuthentication {
    if ($SkipGitHubAuth) {
        Write-BootstrapLog "Skipping GitHub authentication check (SkipGitHubAuth specified)" 'INFO'
        return $true
    }

    # Check if GitHub CLI is available
    if (-not (Get-Command 'gh' -ErrorAction SilentlyContinue)) {
        Write-BootstrapLog "GitHub CLI not available, skipping authentication check" 'WARN'
        return $true
    }

    Write-BootstrapLog "Checking GitHub CLI authentication..." 'INFO'

    try {
        $authStatus = & gh auth status 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-BootstrapLog "OK GitHub CLI is authenticated" 'SUCCESS'
            return $true
        } else {
            Write-BootstrapLog "GitHub CLI is not authenticated" 'WARN'

            if ($NonInteractive) {
                Write-BootstrapLog "Cannot authenticate in non-interactive mode. Some features may be limited." 'WARN'
                return $true  # Don't fail, just warn
            } else {
                Write-BootstrapLog "Please authenticate with GitHub CLI: gh auth login" 'INFO'
                return $true  # Don't fail, just inform
            }
        }
    } catch {
        Write-BootstrapLog "GitHub authentication check failed: $($_.Exception.Message)" 'WARN'
        return $true  # Don't fail on auth check errors
    }
}

# Main prerequisite validation
function Test-Prerequisites {
    Write-BootstrapLog "=== Validating Prerequisites ===" 'INFO'

    $allGood = $true
      # PowerShell 7 (recommended but not required)
    if (-not (Test-Prerequisite -Name "PowerShell 7" -Commands @("pwsh") -InstallInstructions "Install from https://github.com/PowerShell/PowerShell/releases")) {
        if ($script:PlatformWindows -and -not $SkipPrerequisites) {
            Install-PowerShell7 | Out-Null
        }
    }

    # Git
    if (-not (Test-Prerequisite -Name "Git" -Commands @("git") -InstallUrl "https://git-scm.com/downloads" -InstallInstructions "Install Git from https://git-scm.com/downloads")) {
        if ($script:PlatformWindows -and -not $SkipPrerequisites) {
            if (-not (Install-GitForWindows)) {
                $allGood = $false
            }
        } else {
            $allGood = $false
        }
    }    # GitHub CLI (optional but recommended)
    Test-Prerequisite -Name "GitHub CLI" -Commands @("gh") -InstallUrl "https://cli.github.com/" -InstallInstructions "Install from https://cli.github.com/" | Out-Null

    # Check GitHub authentication
    Test-GitHubAuthentication | Out-Null

    if (-not $allGood) {
        throw "Required prerequisites are missing. Please install them and re-run this script."
    }

    Write-BootstrapLog "OK All required prerequisites are available" 'SUCCESS'
}

# Repository operations
function Get-RepositoryPath {
    if ($LocalPath) {
        $basePath = $LocalPath
    } else {
        $basePath = Get-PlatformTempPath
    }

    return Join-Path $basePath "opentofu-lab-automation"
}

# Enhanced repository synchronization (PowerShell 5.1 and 7.x compatible)
function Sync-Repository {
    $repoPath = Get-RepositoryPath

    Write-BootstrapLog "=== Repository Synchronization ===" 'INFO'
    Write-BootstrapLog "Target path: $repoPath" 'INFO'
    Write-BootstrapLog "Branch: $TargetBranch" 'INFO'

    if (Test-Path $repoPath) {
        if ($Force) {
            Write-BootstrapLog "Removing existing repository (Force specified)" 'WARN'
            try {
                Remove-Item $repoPath -Recurse -Force -ErrorAction Stop
            } catch {
                Write-BootstrapLog "Failed to remove existing repository: $($_.Exception.Message)" 'ERROR'
                throw
            }
        } else {
            Write-BootstrapLog "Repository exists, updating..." 'INFO'
            try {
                Push-Location $repoPath

                # Check if it's a valid git repository
                $gitDir = Join-Path $repoPath '.git'
                if (-not (Test-Path $gitDir)) {
                    throw "Directory exists but is not a git repository"
                }

                # Enhanced git operations with better error handling
                Write-BootstrapLog "Fetching latest changes..." 'INFO'
                & git fetch origin 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    throw "Git fetch failed with exit code: $LASTEXITCODE"
                }

                & git reset --hard "origin/$TargetBranch" 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    throw "Git reset failed with exit code: $LASTEXITCODE"
                }

                & git clean -fdx 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-BootstrapLog "Git clean had issues but continuing..." 'WARN'
                }

                Write-BootstrapLog "OK Repository updated successfully" 'SUCCESS'
                Pop-Location
                return $repoPath
            } catch {
                Write-BootstrapLog "Update failed, will re-clone: $($_.Exception.Message)" 'WARN'
                Pop-Location
                try {
                    Remove-Item $repoPath -Recurse -Force -ErrorAction Stop
                } catch {
                    Write-BootstrapLog "Failed to clean up for re-clone: $($_.Exception.Message)" 'ERROR'
                    throw
                }
            }
        }
    }

    Write-BootstrapLog "Cloning repository..." 'INFO'

    try {
        $parentPath = Split-Path $repoPath -Parent
        if (-not (Test-Path $parentPath)) {
            New-Item -ItemType Directory -Path $parentPath -Force | Out-Null
        }

        # Enhanced git clone with better error handling
        & git clone --branch $TargetBranch --single-branch --depth 1 $script:RepoUrl $repoPath 2>&1 | Out-Null

        if ($LASTEXITCODE -ne 0) {
            throw "Git clone failed with exit code: $LASTEXITCODE"
        }

        if (-not (Test-Path $repoPath)) {
            throw "Repository clone appeared successful but path does not exist"
        }

        # Verify it's a proper clone
        $gitDir = Join-Path $repoPath '.git'
        if (-not (Test-Path $gitDir)) {
            throw "Cloned directory is not a valid git repository"
        }

        Write-BootstrapLog "OK Repository cloned successfully" 'SUCCESS'
        return $repoPath
    } catch {
        throw "Failed to clone repository: $($_.Exception.Message)"
    }
}

# Enhanced configuration management (PowerShell version compatible)
function Get-BootstrapConfig {
    param([string]$RepoPath)

    Write-BootstrapLog "=== Configuration Loading ===" 'INFO'

    if ($ConfigFile -and (Test-Path $ConfigFile)) {
        $configPath = $ConfigFile
        Write-BootstrapLog "Using specified config: $configPath" 'INFO'
    } else {
        # Look for config in repo
        $defaultConfigPath = Join-Path $RepoPath "core-runner/core_app/default-config.json"

        if (Test-Path $defaultConfigPath) {
            $configPath = $defaultConfigPath
            Write-BootstrapLog "Using repository default config" 'INFO'
        } else {
            # Download default config
            $tempConfig = Join-Path (Get-PlatformTempPath) "bootstrap-config.json"
            try {
                if (Invoke-CompatibleWebRequest -Uri $script:DefaultConfigUrl -OutFile $tempConfig) {
                    $configPath = $tempConfig
                    Write-BootstrapLog "Downloaded default configuration" 'INFO'
                } else {
                    throw "Failed to download default configuration"
                }
            } catch {
                Write-BootstrapLog "Could not download default config, using minimal config: $($_.Exception.Message)" 'WARN'
                return $null
            }
        }
    }

    try {
        $configContent = Get-Content $configPath -Raw -ErrorAction Stop

        # PowerShell 5.1 compatible JSON parsing
        if ($script:IsPowerShell7Plus) {
            $config = $configContent | ConvertFrom-Json
        } else {
            # PowerShell 5.1 - use more careful JSON parsing
            try {
                $config = $configContent | ConvertFrom-Json
            } catch {
                # Fallback for complex JSON in PowerShell 5.1
                Add-Type -AssemblyName System.Web.Extensions
                $jsSerializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
                $config = $jsSerializer.DeserializeObject($configContent)
            }
        }

        Write-BootstrapLog "OK Configuration loaded successfully" 'SUCCESS'
        return $config
    } catch {
        Write-BootstrapLog "Failed to parse configuration: $($_.Exception.Message)" 'ERROR'
        return $null
    }
}

# Enhanced CoreApp orchestration (PowerShell 5.1 and 7.x compatible)
function Invoke-CoreAppBootstrap {
    [CmdletBinding()]
    param(
        [string]$RepoPath,
        [object]$Config
    )

    Write-BootstrapLog "=== CoreApp Orchestration Bootstrap ===" 'INFO'

    $runnerScript = Join-Path $RepoPath "core-runner/core_app/core-runner.ps1"

    if (-not (Test-Path $runnerScript)) {
        throw "CoreApp runner script not found at: $runnerScript"
    }

    Write-BootstrapLog "Invoking CoreApp orchestration..." 'INFO'

    try {
        Push-Location $RepoPath

        # Prepare arguments for CoreApp
        $coreAppArgs = @(
            '-NoLogo',
            '-NoProfile',
            '-File',
            $runnerScript
        )

        if ($Config) {
            $tempConfigPath = Join-Path (Get-PlatformTempPath) "bootstrap-runtime-config.json"

            try {
                if ($script:IsPowerShell7Plus) {
                    $Config | ConvertTo-Json -Depth 10 | Set-Content $tempConfigPath -Encoding UTF8
                } else {
                    $jsonOutput = $Config | ConvertTo-Json -Depth 10
                    [System.IO.File]::WriteAllText($tempConfigPath, $jsonOutput, [System.Text.Encoding]::UTF8)
                }
                $coreAppArgs += @('-ConfigFile', $tempConfigPath)
            } catch {
                Write-BootstrapLog "Failed to serialize config, proceeding without it: $($_.Exception.Message)" 'WARN'
            }
        }

        if ($Verbosity -eq 'silent') {
            $coreAppArgs += '-Quiet'
        } else {
            $coreAppArgs += @('-Verbosity', $Verbosity)
        }

        if ($NonInteractive) {
            $coreAppArgs += '-NonInteractive'
            $coreAppArgs += '-Auto'
        }

        $pwshPath = Get-PlatformPowerShell
        Write-BootstrapLog "Using PowerShell: $pwshPath" 'INFO'

        try {
            # Debug: Show the exact command being executed
            Write-BootstrapLog "Executing: $pwshPath" 'INFO'
            Write-BootstrapLog "Arguments:" 'INFO'
            for ($i = 0; $i -lt $coreAppArgs.Length; $i++) {
                Write-BootstrapLog "  [$i]: '$($coreAppArgs[$i])'" 'INFO'
            }

            # Use Start-Process with explicit parameter handling to avoid argument parsing issues
            $process = Start-Process -FilePath $pwshPath -ArgumentList ($coreAppArgs -join ' ') -Wait -NoNewWindow -PassThru -WorkingDirectory $RepoPath

            if ($process.ExitCode -eq 0) {
                Write-BootstrapLog "OK CoreApp orchestration completed successfully" 'SUCCESS'
            } else {
                throw "CoreApp orchestration failed with exit code: $($process.ExitCode)"
            }
        } catch {
            Write-BootstrapLog "CoreApp orchestration failed: $($_.Exception.Message)" 'ERROR'
            throw
        }

        Pop-Location
    } catch {
        Pop-Location
        throw "CoreApp orchestration failed: $($_.Exception.Message)"
    }
}

# Demonstrate CoreApp orchestration features
function Show-CoreAppDemo {
    param([string]$RepoPath)

    if ($NonInteractive -or $script:VerbosityLevel -eq 0) {
        return
    }

    Write-BootstrapLog "" 'INFO' -NoTimestamp
    Write-BootstrapLog "* Would you like to see the CoreApp orchestration in action? (y/N)" 'INFO' -NoTimestamp

    $response = Read-Host
    if ($response -match '^[Yy]') {
        Write-BootstrapLog "Demonstrating CoreApp orchestration features..." 'INFO'
        try {
            Push-Location $RepoPath
            # Import CoreApp module
            $coreAppPath = Join-Path $RepoPath "core-runner/core_app"
            Import-Module $coreAppPath -Force
            Write-BootstrapLog "OK CoreApp module imported" 'SUCCESS'
            # Initialize and show module status
            Write-BootstrapLog "Initializing core application..." 'INFO'
            $initResult = Initialize-CoreApplication
            if ($initResult.Success) {
                Write-BootstrapLog "OK Core application initialized" 'SUCCESS'
                Write-BootstrapLog "Loaded modules: $($initResult.LoadedModules -join ', ')" 'INFO'
            }
            # Show module status
            Write-BootstrapLog "Module Status:" 'INFO'
            $moduleStatus = Get-CoreModuleStatus
            $moduleStatus | ForEach-Object {
                $icon = if ($_.Status -eq 'Loaded') { 'OK' } else { 'WARNING' }
                $color = if ($_.Status -eq 'Loaded') { 'SUCCESS' } else { 'WARN' }
                Write-BootstrapLog "  $icon $($_.Name): $($_.Status)" $color
            }
            Write-BootstrapLog "OK CoreApp demonstration completed" 'SUCCESS'
            Pop-Location
        } catch {
            Write-BootstrapLog "Demo failed: $($_.Exception.Message)" 'WARN'
            Pop-Location
        }
    }
}

# Health check and validation
function Test-BootstrapHealth {
    param([string]$RepoPath)

    Write-BootstrapLog "=== Health Check ===" 'INFO'

    $healthItems = @(
        @{ Path = Join-Path $RepoPath "core-runner/core_app/CoreApp.psm1"; Name = "CoreApp Module" }
        @{ Path = Join-Path $RepoPath "core-runner/modules"; Name = "Core Modules Directory" }
        @{ Path = Join-Path $RepoPath "tests"; Name = "Test Framework" }
        @{ Path = Join-Path $RepoPath "opentofu"; Name = "OpenTofu Configuration" }
    )

    $healthGood = $true

    foreach ($item in $healthItems) {
        if (Test-Path $item.Path) {
            Write-BootstrapLog "OK $($item.Name)" 'SUCCESS'
        } else {
            Write-BootstrapLog "FAIL $($item.Name) - Missing: $($item.Path)" 'ERROR'
            $healthGood = $false
        }
    }

    if ($healthGood) {
        Write-BootstrapLog "OK All health checks passed" 'SUCCESS'
    } else {
        Write-BootstrapLog "WARNING Some health checks failed - proceeding anyway" 'WARN'
    }

    return $healthGood
}

# Cross-platform package installation
function Install-Prerequisites {
    if ($script:PlatformWindows) {
        Write-BootstrapLog -Message "Installing prerequisites on Windows..." -Level INFO
        # Windows-specific installation logic
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Write-BootstrapLog -Message "Git is not installed. Please install Git manually." -Level ERROR
            return
        }    } elseif ($script:PlatformLinux) {
        Write-BootstrapLog -Message "Installing prerequisites on Linux..." -Level INFO
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Write-BootstrapLog -Message "Installing Git..." -Level INFO
            sudo apt-get update; sudo apt-get install -y git
        }
        if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
            Write-BootstrapLog -Message "Installing PowerShell..." -Level INFO
            sudo apt-get install -y powershell
        }
    } elseif ($script:PlatformMacOS) {
        Write-BootstrapLog -Message "Installing prerequisites on macOS..." -Level INFO
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Write-BootstrapLog -Message "Installing Git..." -Level INFO
            brew install git
        }
        if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
            Write-BootstrapLog -Message "Installing PowerShell..." -Level INFO
            brew install --cask powershell
        }
    } else {
        Write-BootstrapLog -Message "Unsupported platform. Exiting..." -Level ERROR
        return
    }
}

# Update repository clone logic for cross-platform paths
function New-RepositoryClone {
    param(
        [string]$RepositoryUrl,
        [string]$DestinationPath
    )

    $DestinationPath = if ($DestinationPath) { $DestinationPath } else { Get-PlatformTempPath }

    if (-not (Test-Path -Path $DestinationPath)) {
        New-Item -ItemType Directory -Path $DestinationPath | Out-Null
    }

    if (Test-Path -Path "$DestinationPath/.git") {
        Write-BootstrapLog -Message "Repository already exists. Pulling latest changes..." -Level INFO
        git -C $DestinationPath pull
    } else {
        Write-BootstrapLog -Message "Cloning repository to $DestinationPath..." -Level INFO
        git clone $RepositoryUrl $DestinationPath
    }
}

# Main bootstrap workflow
function Start-Bootstrap {
    [CmdletBinding()]
    param()
    Write-BootstrapLog "=== Aitherium Bootstrap ===" 'SUCCESS'

    try {
        # Step 1: Validate prerequisites
        Test-Prerequisites        # Step 2: Sync repository
        $repoPath = Sync-Repository
        Write-BootstrapLog "Repository path: '$repoPath'" 'INFO'

        # Step 3: Load configuration
        $config = Get-BootstrapConfig -RepoPath $repoPath

        # Step 4: Health check
        Test-BootstrapHealth -RepoPath $repoPath | Out-Null        # Step 5: Invoke CoreApp orchestration
        if ($WhatIfPreference) {
            Write-BootstrapLog "WhatIf: Would complete bootstrap with CoreApp orchestration" 'INFO'
            return
        }

        Write-BootstrapLog "About to call Invoke-CoreAppBootstrap with repoPath: '$repoPath'" 'INFO'
        Invoke-CoreAppBootstrap -RepoPath $repoPath -Config $config
        # Step 6: Demonstrate CoreApp features (interactive only)
        Show-CoreAppDemo -RepoPath $repoPath

        # Step 7: Change to project directory and create relaunch helper
        Write-BootstrapLog "Setting up project environment..." 'INFO'

        # Change to project directory
        Set-Location $repoPath
        Write-BootstrapLog "OK Changed to project directory: $repoPath" 'SUCCESS'

        # Create a convenient relaunch script
        $relaunchScript = Join-Path $repoPath "Relaunch-CoreApp.ps1"
        $relaunchContent = @"
<#
.SYNOPSIS
    Convenient relaunch script for Aitherium Infrastructure Automation CoreApp

.DESCRIPTION
    This script was generated by kicker-git.ps1 to provide an easy way to
    restart the CoreApp environment after the initial bootstrap.

.EXAMPLE
    .\Relaunch-CoreApp.ps1

.EXAMPLE
    .\Relaunch-CoreApp.ps1 -Force
#>

[CmdletBinding()]
param(
    [switch]`$Force
)

# Ensure we're in the right directory
Set-Location "`$PSScriptRoot"

Write-Host " Relaunching Aitherium Infrastructure Automation CoreApp..." -ForegroundColor Cyan
Write-Host "Project Directory: `$(Get-Location)" -ForegroundColor Green

try {
    # Import CoreApp module
    Import-Module "./core-runner/core_app/CoreApp.psm1" -Force:`$Force

    # Initialize CoreApp ecosystem
    Initialize-CoreApplication -Force:`$Force

    Write-Host "[SUCCESS] CoreApp relaunch complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host " Available commands:" -ForegroundColor Yellow
    Write-Host "  - Get-CoreModuleStatus      - Check module status"
    Write-Host "  - Invoke-UnifiedMaintenance - Run maintenance"
    Write-Host "  - Start-DevEnvironmentSetup - Setup dev environment"
    Write-Host "  - Test-CoreApplicationHealth - Health check"
    Write-Host ""
    Write-Host "TIP: Quick actions:" -ForegroundColor Yellow
    Write-Host "  - Run tests: Invoke-Pester"
    Write-Host "  - Open VS Code: code ./opentofu-lab-automation.code-workspace"
    Write-Host "  - Run PatchManager demo: ./run-demo-examples.ps1"

} catch {
    Write-Error "Failed to relaunch CoreApp: `$(`$_.Exception.Message)"
    Write-Host "TIP: Try running: .\kicker-git.ps1 -Force" -ForegroundColor Yellow
    exit 1
}
"@

        Set-Content -Path $relaunchScript -Value $relaunchContent -Encoding UTF8
        Write-BootstrapLog "Created relaunch helper: $relaunchScript" 'SUCCESS'

        # Success message with clear next steps
        Write-BootstrapLog "=== Bootstrap Completed Successfully ===" 'SUCCESS'
        Write-BootstrapLog "Repository location: $repoPath" 'INFO'
        Write-BootstrapLog "Current directory: $(Get-Location)" 'INFO'
        Write-BootstrapLog "Log file: $script:LogFile" 'INFO'
        Write-BootstrapLog "PowerShell compatibility: $($PSVersionTable.PSVersion.Major).x OK" 'INFO'

        if ($script:VerbosityLevel -ge 1) {
            Write-BootstrapLog "" 'INFO' -NoTimestamp
            Write-BootstrapLog " Aitherium is ready! " 'SUCCESS' -NoTimestamp
            Write-BootstrapLog "You are now in the project directory: $(Get-Location)" 'SUCCESS' -NoTimestamp
            Write-BootstrapLog "" 'INFO' -NoTimestamp
            Write-BootstrapLog " To relaunch CoreApp anytime:" 'INFO' -NoTimestamp
            Write-BootstrapLog "  .\Relaunch-CoreApp.ps1           # Convenient relaunch script" 'INFO' -NoTimestamp
            Write-BootstrapLog "  .\Start-CoreApp.ps1             # Alternative launcher" 'INFO' -NoTimestamp
            Write-BootstrapLog "" 'INFO' -NoTimestamp
            Write-BootstrapLog " Quick Start Options:" 'INFO' -NoTimestamp
            Write-BootstrapLog "  .\Relaunch-CoreApp.ps1          # Start CoreApp (recommended)" 'INFO' -NoTimestamp
            Write-BootstrapLog "  .\Quick-Setup.ps1               # Development environment" 'INFO' -NoTimestamp
            Write-BootstrapLog "  .\run-demo-examples.ps1         # Run PatchManager demos" 'INFO' -NoTimestamp
            Write-BootstrapLog "" 'INFO' -NoTimestamp
            Write-BootstrapLog " Development Commands:" 'INFO' -NoTimestamp
            Write-BootstrapLog "  - Run tests: Invoke-Pester" 'INFO' -NoTimestamp
            Write-BootstrapLog "  - Open VS Code: code ./opentofu-lab-automation.code-workspace" 'INFO' -NoTimestamp
            Write-BootstrapLog "  - Explore configs: ls ./opentofu/" 'INFO' -NoTimestamp
            Write-BootstrapLog "" 'INFO' -NoTimestamp
            Write-BootstrapLog "DOCS: Documentation: ./docs/ | BUGS: Issues: https://github.com/Aitherium/AitherLabs/issues" 'INFO' -NoTimestamp
        }

    } catch {
        Write-BootstrapLog "Bootstrap failed: $($_.Exception.Message)" 'ERROR'
        Write-BootstrapLog "Log file: $script:LogFile" 'INFO'
        exit 1
    }
}

# Script entry point
if ($MyInvocation.InvocationName -ne '.') {
    Start-Bootstrap
}

# PowerShell 5.1 and 7.x Compatible Bootstrap Script
# Updated: 06/18/2025 - Enhanced cross-version compatibility
# Features: PowerShell 5.1/7.x compatibility, cross-platform support, robust error handling
