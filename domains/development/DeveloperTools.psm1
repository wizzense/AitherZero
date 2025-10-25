#Requires -Version 7.0
<#
.SYNOPSIS
    AitherZero Developer Tools Module - Development Environment Setup
.DESCRIPTION
    Consolidates functionality from automation scripts 0200-0299 into a proper PowerShell module.
    Handles installation and configuration of development tools across platforms.
.NOTES
    Copyright © 2025 Aitherium Corporation
    Replaces: 0201_Install-Node.ps1, 0204_Install-Poetry.ps1, 0205_Install-Sysinternals.ps1,
              0206_Install-Python.ps1, 0207_Install-Git.ps1, 0208_Install-Docker.ps1,
              0209_Install-7Zip.ps1, 0210_Install-VSCode.ps1, 0211_Install-VSBuildTools.ps1,
              0212_Install-AzureCLI.ps1, 0213_Install-AWSCLI.ps1, 0214_Install-Packer.ps1,
              0215_Install-Chocolatey.ps1, 0216_Set-PowerShellProfile.ps1, 0217_Install-ClaudeCode.ps1,
              0218_Install-GeminiCLI.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module state
$script:DeveloperToolsState = @{
    InstalledTools = @{}
    PackageManagers = @{}
    InstallationLog = @()
}

# Import dependencies
if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
    $script:LoggingAvailable = $true
} else {
    $script:LoggingAvailable = $false
}

# Import PackageManager if available
$packageManagerPath = Join-Path (Split-Path $PSScriptRoot -Parent) "utilities/PackageManager.psm1"
if (Test-Path $packageManagerPath) {
    Import-Module $packageManagerPath -Force -Global -ErrorAction SilentlyContinue
    $script:PackageManagerAvailable = $true
} else {
    $script:PackageManagerAvailable = $false
}

function Write-DevToolsLog {
    param(
        [string]$Message,
        [string]$Level = 'Information',
        [hashtable]$Data = @{}
    )

    if ($script:LoggingAvailable) {
        Write-CustomLog -Message $Message -Level $Level -Source 'DeveloperTools' -Data $Data
    } else {
        $timestamp = Get-Date -Format 'HH:mm:ss'
        $prefix = switch ($Level) {
            'Error' { '❌' }
            'Warning' { '⚠️' }
            'Information' { 'ℹ️' }
            'Success' { '✅' }
            default { '•' }
        }
        Write-Host "[$timestamp] $prefix $Message"
    }
}

function Install-DevelopmentEnvironment {
    <#
    .SYNOPSIS
        Install complete development environment
    .DESCRIPTION
        Installs all development tools based on configuration profile
    .PARAMETER Profile
        Development profile: Minimal, Standard, Full, or Custom
    .PARAMETER Tools
        Specific tools to install (overrides profile)
    .PARAMETER Force
        Force installation even if tools already exist
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateSet('Minimal', 'Standard', 'Full', 'Custom')]
        [string]$Profile = 'Standard',

        [string[]]$Tools = @(),

        [switch]$Force,

        [hashtable]$Configuration = @{}
    )

    Write-DevToolsLog "Installing development environment - Profile: $Profile"

    # Define tool sets for each profile
    $profileTools = @{
        Minimal = @('Git', 'Node', 'Python', 'VSCode')
        Standard = @('Git', 'Node', 'Python', 'VSCode', 'Docker', 'AzureCLI', '7Zip')
        Full = @('Git', 'Node', 'Python', 'VSCode', 'Docker', 'AzureCLI', 'AWSCLI',
                'Packer', '7Zip', 'VSBuildTools', 'Poetry', 'Sysinternals', 'ClaudeCode', 'GeminiCLI')
        Custom = $Tools
    }

    $toolsToInstall = $profileTools[$Profile]
    if ($Tools.Count -gt 0) {
        $toolsToInstall = $Tools
    }

    Write-DevToolsLog "Installing tools: $($toolsToInstall -join ', ')"

    # Ensure package managers are available first
    Initialize-PackageManagers

    # Install each tool
    $results = @{}
    foreach ($tool in $toolsToInstall) {
        try {
            Write-DevToolsLog "Installing $tool"
            $result = Install-DeveloperTool -Tool $tool -Force:$Force -Configuration $Configuration
            $results[$tool] = @{ Success = $result; Error = $null }
            $script:DeveloperToolsState.InstalledTools[$tool] = $true
        } catch {
            Write-DevToolsLog "Failed to install ${tool}: $($_.Exception.Message)" -Level Error
            $results[$tool] = @{ Success = $false; Error = $_.Exception.Message }
        }
    }

    # Configure PowerShell profile
    if ('PowerShellProfile' -in $toolsToInstall -or $Profile -ne 'Minimal') {
        Set-PowerShellDevelopmentProfile
    }

    Write-DevToolsLog "Development environment installation completed" -Level Success
    return $results
}

function Install-DeveloperTool {
    <#
    .SYNOPSIS
        Install a specific development tool
    .DESCRIPTION
        Installs a single development tool using the best available package manager
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Git', 'Node', 'Python', 'VSCode', 'Docker', 'AzureCLI', 'AWSCLI',
                    'Packer', '7Zip', 'VSBuildTools', 'Poetry', 'Sysinternals', 'ClaudeCode',
                    'GeminiCLI', 'Chocolatey')]
        [string]$Tool,

        [switch]$Force,

        [hashtable]$Configuration = @{}
    )

    Write-DevToolsLog "Installing developer tool: $Tool"

    # Check if already installed (unless forced)
    if (-not $Force -and (Test-ToolInstalled -Tool $Tool)) {
        Write-DevToolsLog "$Tool is already installed"
        return $true
    }

    # Install the specific tool
    switch ($Tool) {
        'Git' { return Install-Git -Configuration $Configuration }
        'Node' { return Install-NodeJS -Configuration $Configuration }
        'Python' { return Install-Python -Configuration $Configuration }
        'VSCode' { return Install-VSCode -Configuration $Configuration }
        'Docker' { return Install-Docker -Configuration $Configuration }
        'AzureCLI' { return Install-AzureCLI -Configuration $Configuration }
        'AWSCLI' { return Install-AWSCLI -Configuration $Configuration }
        'Packer' { return Install-Packer -Configuration $Configuration }
        '7Zip' { return Install-7Zip -Configuration $Configuration }
        'VSBuildTools' {
            Write-DevToolsLog "VS Build Tools installation not yet implemented"
            return $false
        }
        'Poetry' {
            Write-DevToolsLog "Poetry installation not yet implemented"
            return $false
        }
        'Sysinternals' {
            Write-DevToolsLog "Sysinternals installation not yet implemented"
            return $false
        }
        'ClaudeCode' {
            Write-DevToolsLog "Claude Code installation not yet implemented"
            return $false
        }
        'GeminiCLI' {
            Write-DevToolsLog "Gemini CLI installation not yet implemented"
            return $false
        }
        'Chocolatey' { return Install-Chocolatey -Configuration $Configuration }
        default { throw "Unknown tool: $Tool" }
    }
}

function Initialize-PackageManagers {
    <#
    .SYNOPSIS
        Initialize available package managers
    .DESCRIPTION
        Detects and initializes package managers for the current platform
    #>
    [CmdletBinding()]
    param()

    Write-DevToolsLog "Initializing package managers"

    if ($IsWindows) {
        # Check for winget
        $winget = Get-Command winget -ErrorAction SilentlyContinue
        if ($winget) {
            $script:DeveloperToolsState.PackageManagers['winget'] = $true
            Write-DevToolsLog "Windows Package Manager (winget) available"
        }

        # Check for Chocolatey
        $choco = Get-Command choco -ErrorAction SilentlyContinue
        if ($choco) {
            $script:DeveloperToolsState.PackageManagers['chocolatey'] = $true
            Write-DevToolsLog "Chocolatey available"
        } else {
            Write-DevToolsLog "Chocolatey not found - will install if needed"
        }

        # Check for Scoop
        $scoop = Get-Command scoop -ErrorAction SilentlyContinue
        if ($scoop) {
            $script:DeveloperToolsState.PackageManagers['scoop'] = $true
            Write-DevToolsLog "Scoop available"
        }

    } elseif ($IsLinux) {
        # Check for common Linux package managers
        $managers = @('apt', 'yum', 'dnf', 'pacman', 'zypper', 'snap')
        foreach ($manager in $managers) {
            $cmd = Get-Command $manager -ErrorAction SilentlyContinue
            if ($cmd) {
                $script:DeveloperToolsState.PackageManagers[$manager] = $true
                Write-DevToolsLog "Package manager available: $manager"
            }
        }

    } elseif ($IsMacOS) {
        # Check for Homebrew
        $brew = Get-Command brew -ErrorAction SilentlyContinue
        if ($brew) {
            $script:DeveloperToolsState.PackageManagers['homebrew'] = $true
            Write-DevToolsLog "Homebrew available"
        }

        # Check for MacPorts
        $port = Get-Command port -ErrorAction SilentlyContinue
        if ($port) {
            $script:DeveloperToolsState.PackageManagers['macports'] = $true
            Write-DevToolsLog "MacPorts available"
        }
    }
}

function Install-Git {
    <#
    .SYNOPSIS
        Install Git version control system
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([hashtable]$Configuration = @{})

    Write-DevToolsLog "Installing Git"

    if ($script:PackageManagerAvailable -and (Get-Command Install-Package -Module PackageManager -ErrorAction SilentlyContinue)) {
        return Install-Package -Name 'git' -DisplayName 'Git' -WhatIf:$WhatIfPreference
    }

    # Fallback to direct installation
    if ($IsWindows) {
        if ($script:DeveloperToolsState.PackageManagers.ContainsKey('winget')) {
            if ($PSCmdlet.ShouldProcess("Git", "Install via winget")) {
                & winget install --id Git.Git --source winget
            }
        } elseif ($script:DeveloperToolsState.PackageManagers.ContainsKey('chocolatey')) {
            if ($PSCmdlet.ShouldProcess("Git", "Install via Chocolatey")) {
                & choco install git -y
            }
        }
    } elseif ($IsLinux) {
        if ($script:DeveloperToolsState.PackageManagers.ContainsKey('apt')) {
            if ($PSCmdlet.ShouldProcess("Git", "Install via apt")) {
                & sudo apt update && sudo apt install -y git
            }
        } elseif ($script:DeveloperToolsState.PackageManagers.ContainsKey('yum')) {
            if ($PSCmdlet.ShouldProcess("Git", "Install via yum")) {
                & sudo yum install -y git
            }
        }
    } elseif ($IsMacOS) {
        if ($script:DeveloperToolsState.PackageManagers.ContainsKey('homebrew')) {
            if ($PSCmdlet.ShouldProcess("Git", "Install via Homebrew")) {
                & brew install git
            }
        }
    }

    return $true
}

function Install-NodeJS {
    <#
    .SYNOPSIS
        Install Node.js and npm
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([hashtable]$Configuration = @{})

    Write-DevToolsLog "Installing Node.js"

    $nodeVersion = $Configuration.NodeVersion ?? "lts"

    if ($script:PackageManagerAvailable -and (Get-Command Install-Package -Module PackageManager -ErrorAction SilentlyContinue)) {
        return Install-Package -Name 'nodejs' -DisplayName 'Node.js' -WhatIf:$WhatIfPreference
    }

    # Fallback to direct installation
    if ($IsWindows) {
        if ($script:DeveloperToolsState.PackageManagers.ContainsKey('winget')) {
            if ($PSCmdlet.ShouldProcess("Node.js", "Install via winget")) {
                & winget install --id OpenJS.NodeJS --source winget
            }
        } elseif ($script:DeveloperToolsState.PackageManagers.ContainsKey('chocolatey')) {
            if ($PSCmdlet.ShouldProcess("Node.js", "Install via Chocolatey")) {
                & choco install nodejs -y
            }
        }
    } elseif ($IsLinux) {
        # Install via NodeSource repository for latest versions
        if ($PSCmdlet.ShouldProcess("Node.js", "Install via NodeSource")) {
            & curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            & sudo apt-get install -y nodejs
        }
    } elseif ($IsMacOS) {
        if ($script:DeveloperToolsState.PackageManagers.ContainsKey('homebrew')) {
            if ($PSCmdlet.ShouldProcess("Node.js", "Install via Homebrew")) {
                & brew install node
            }
        }
    }

    return $true
}

function Install-Python {
    <#
    .SYNOPSIS
        Install Python programming language
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([hashtable]$Configuration = @{})

    Write-DevToolsLog "Installing Python"

    $pythonVersion = $Configuration.PythonVersion ?? "3.11"

    if ($IsWindows) {
        if ($script:DeveloperToolsState.PackageManagers.ContainsKey('winget')) {
            if ($PSCmdlet.ShouldProcess("Python", "Install via winget")) {
                & winget install --id Python.Python.3.11 --source winget
            }
        } elseif ($script:DeveloperToolsState.PackageManagers.ContainsKey('chocolatey')) {
            if ($PSCmdlet.ShouldProcess("Python", "Install via Chocolatey")) {
                & choco install python -y
            }
        }
    } elseif ($IsLinux) {
        if ($script:DeveloperToolsState.PackageManagers.ContainsKey('apt')) {
            if ($PSCmdlet.ShouldProcess("Python", "Install via apt")) {
                & sudo apt update && sudo apt install -y python3 python3-pip python3-venv
            }
        }
    } elseif ($IsMacOS) {
        if ($script:DeveloperToolsState.PackageManagers.ContainsKey('homebrew')) {
            if ($PSCmdlet.ShouldProcess("Python", "Install via Homebrew")) {
                & brew install python
            }
        }
    }

    return $true
}

function Install-VSCode {
    <#
    .SYNOPSIS
        Install Visual Studio Code
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([hashtable]$Configuration = @{})

    Write-DevToolsLog "Installing Visual Studio Code"

    if ($IsWindows) {
        if ($script:DeveloperToolsState.PackageManagers.ContainsKey('winget')) {
            if ($PSCmdlet.ShouldProcess("VS Code", "Install via winget")) {
                & winget install --id Microsoft.VisualStudioCode --source winget
            }
        } elseif ($script:DeveloperToolsState.PackageManagers.ContainsKey('chocolatey')) {
            if ($PSCmdlet.ShouldProcess("VS Code", "Install via Chocolatey")) {
                & choco install vscode -y
            }
        }
    } elseif ($IsLinux) {
        if ($PSCmdlet.ShouldProcess("VS Code", "Install via apt")) {
            & wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
            & sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
            & echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
            & sudo apt update && sudo apt install -y code
        }
    } elseif ($IsMacOS) {
        if ($script:DeveloperToolsState.PackageManagers.ContainsKey('homebrew')) {
            if ($PSCmdlet.ShouldProcess("VS Code", "Install via Homebrew")) {
                & brew install --cask visual-studio-code
            }
        }
    }

    return $true
}

function Install-Docker {
    <#
    .SYNOPSIS
        Install Docker container platform
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([hashtable]$Configuration = @{})

    Write-DevToolsLog "Installing Docker"

    if ($IsWindows) {
        if ($script:DeveloperToolsState.PackageManagers.ContainsKey('winget')) {
            if ($PSCmdlet.ShouldProcess("Docker Desktop", "Install via winget")) {
                & winget install --id Docker.DockerDesktop --source winget
            }
        } elseif ($script:DeveloperToolsState.PackageManagers.ContainsKey('chocolatey')) {
            if ($PSCmdlet.ShouldProcess("Docker Desktop", "Install via Chocolatey")) {
                & choco install docker-desktop -y
            }
        }
    } elseif ($IsLinux) {
        if ($PSCmdlet.ShouldProcess("Docker", "Install via official script")) {
            & curl -fsSL https://get.docker.com -o get-docker.sh
            & sudo sh get-docker.sh
            & sudo usermod -aG docker $env:USER
            Remove-Item get-docker.sh -Force -ErrorAction SilentlyContinue
        }
    } elseif ($IsMacOS) {
        if ($script:DeveloperToolsState.PackageManagers.ContainsKey('homebrew')) {
            if ($PSCmdlet.ShouldProcess("Docker Desktop", "Install via Homebrew")) {
                & brew install --cask docker
            }
        }
    }

    return $true
}

function Install-AzureCLI {
    <#
    .SYNOPSIS
        Install Azure CLI
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([hashtable]$Configuration = @{})

    Write-DevToolsLog "Installing Azure CLI"

    if ($IsWindows) {
        if ($script:DeveloperToolsState.PackageManagers.ContainsKey('winget')) {
            if ($PSCmdlet.ShouldProcess("Azure CLI", "Install via winget")) {
                & winget install --id Microsoft.AzureCLI --source winget
            }
        }
    } elseif ($IsLinux) {
        if ($PSCmdlet.ShouldProcess("Azure CLI", "Install via official script")) {
            & curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
        }
    } elseif ($IsMacOS) {
        if ($script:DeveloperToolsState.PackageManagers.ContainsKey('homebrew')) {
            if ($PSCmdlet.ShouldProcess("Azure CLI", "Install via Homebrew")) {
                & brew install azure-cli
            }
        }
    }

    return $true
}

function Install-AWSCLI {
    <#
    .SYNOPSIS
        Install AWS CLI
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([hashtable]$Configuration = @{})

    Write-DevToolsLog "Installing AWS CLI"

    if ($IsWindows) {
        if ($PSCmdlet.ShouldProcess("AWS CLI", "Download and install")) {
            $installerUrl = "https://awscli.amazonaws.com/AWSCLIV2.msi"
            $installerPath = Join-Path $env:TEMP "AWSCLIV2.msi"
            Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
            Start-Process msiexec.exe -ArgumentList "/i", $installerPath, "/quiet" -Wait
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        }
    } elseif ($IsLinux) {
        if ($PSCmdlet.ShouldProcess("AWS CLI", "Install via official installer")) {
            & curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
            & unzip awscliv2.zip
            & sudo ./aws/install
            Remove-Item -Path "awscliv2.zip", "aws" -Recurse -Force -ErrorAction SilentlyContinue
        }
    } elseif ($IsMacOS) {
        if ($script:DeveloperToolsState.PackageManagers.ContainsKey('homebrew')) {
            if ($PSCmdlet.ShouldProcess("AWS CLI", "Install via Homebrew")) {
                & brew install awscli
            }
        }
    }

    return $true
}

function Install-7Zip {
    <#
    .SYNOPSIS
        Install 7-Zip compression utility
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([hashtable]$Configuration = @{})

    Write-DevToolsLog "Installing 7-Zip"

    if ($IsWindows) {
        if ($script:DeveloperToolsState.PackageManagers.ContainsKey('winget')) {
            if ($PSCmdlet.ShouldProcess("7-Zip", "Install via winget")) {
                & winget install --id 7zip.7zip --source winget
            }
        } elseif ($script:DeveloperToolsState.PackageManagers.ContainsKey('chocolatey')) {
            if ($PSCmdlet.ShouldProcess("7-Zip", "Install via Chocolatey")) {
                & choco install 7zip -y
            }
        }
    } elseif ($IsLinux) {
        if ($script:DeveloperToolsState.PackageManagers.ContainsKey('apt')) {
            if ($PSCmdlet.ShouldProcess("p7zip", "Install via apt")) {
                & sudo apt update && sudo apt install -y p7zip-full
            }
        }
    } elseif ($IsMacOS) {
        if ($script:DeveloperToolsState.PackageManagers.ContainsKey('homebrew')) {
            if ($PSCmdlet.ShouldProcess("p7zip", "Install via Homebrew")) {
                & brew install p7zip
            }
        }
    }

    return $true
}

function Install-Chocolatey {
    <#
    .SYNOPSIS
        Install Chocolatey package manager for Windows
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([hashtable]$Configuration = @{})

    if (-not $IsWindows) {
        Write-DevToolsLog "Chocolatey is only available on Windows" -Level Warning
        return $false
    }

    Write-DevToolsLog "Installing Chocolatey"

    if ($PSCmdlet.ShouldProcess("Chocolatey", "Install via PowerShell")) {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

        # Update package manager state
        $script:DeveloperToolsState.PackageManagers['chocolatey'] = $true
    }

    return $true
}

function Set-PowerShellDevelopmentProfile {
    <#
    .SYNOPSIS
        Configure PowerShell profile for development
    .DESCRIPTION
        Sets up PowerShell profile with useful aliases, functions, and modules
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-DevToolsLog "Configuring PowerShell development profile"

    $profilePath = $PROFILE.AllUsersAllHosts
    if (-not (Test-Path (Split-Path $profilePath -Parent))) {
        if ($PSCmdlet.ShouldProcess((Split-Path $profilePath -Parent), "Create profile directory")) {
            New-Item -Path (Split-Path $profilePath -Parent) -ItemType Directory -Force | Out-Null
        }
    }

    $profileContent = @'
# AitherZero Development Profile
# Auto-generated by DeveloperTools module

# Import AitherZero module if available
# Try to find AitherZero module in common locations
$aitherZeroLocations = @(
    (Join-Path $env:AITHERZERO_ROOT "AitherZero.psm1"),
    (Join-Path $HOME "AitherZero" "AitherZero.psm1"),
    (Join-Path (Split-Path $PSScriptRoot -Parent) -Parent "AitherZero.psm1")
)

foreach ($location in $aitherZeroLocations) {
    if ($location -and (Test-Path $location)) {
        Import-Module $location -Force -Global -ErrorAction SilentlyContinue
        break
    }
}

# Useful aliases
Set-Alias -Name ll -Value Get-ChildItem -Force
Set-Alias -Name grep -Value Select-String -Force
Set-Alias -Name which -Value Get-Command -Force

# Git aliases
function gs { git status }
function ga { git add $args }
function gc { git commit -m $args }
function gp { git push }
function gl { git log --oneline -10 }

# Directory shortcuts
function docs { Set-Location "$HOME/Documents" }
function desktop { Set-Location "$HOME/Desktop" }

# Enhanced prompt
function prompt {
    $location = Get-Location
    $gitBranch = ""

    # Show git branch if in git repo
    if (Test-Path .git) {
        try {
            $branch = & git branch --show-current 2>$null
            if ($branch) {
                $gitBranch = " [$branch]"
            }
        } catch { }
    }

    # Show PowerShell version and path
    $psVersion = $PSVersionTable.PSVersion.Major
    Write-Host "PS$psVersion " -NoNewline -ForegroundColor Cyan
    Write-Host $location -NoNewline -ForegroundColor Green
    Write-Host $gitBranch -NoNewline -ForegroundColor Yellow
    return "> "
}

Write-Host "AitherZero Development Environment Loaded" -ForegroundColor Green
'@

    if ($PSCmdlet.ShouldProcess($profilePath, "Create PowerShell profile")) {
        Set-Content -Path $profilePath -Value $profileContent -Encoding UTF8
        Write-DevToolsLog "PowerShell profile configured at: $profilePath" -Level Success
    }

    return $true
}

function Test-ToolInstalled {
    <#
    .SYNOPSIS
        Test if a development tool is installed
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Tool
    )

    $commands = @{
        'Git' = 'git'
        'Node' = 'node'
        'Python' = 'python'
        'VSCode' = 'code'
        'Docker' = 'docker'
        'AzureCLI' = 'az'
        'AWSCLI' = 'aws'
        '7Zip' = if ($IsWindows) { '7z' } else { '7za' }
        'Packer' = 'packer'
        'Chocolatey' = 'choco'
    }

    $commandName = $commands[$Tool]
    if ($commandName) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        return $null -ne $command
    }

    return $false
}

function Get-DeveloperToolsStatus {
    <#
    .SYNOPSIS
        Get status of all development tools
    .DESCRIPTION
        Returns comprehensive status information about installed development tools
    #>
    [CmdletBinding()]
    param()

    $tools = @('Git', 'Node', 'Python', 'VSCode', 'Docker', 'AzureCLI', 'AWSCLI',
               '7Zip', 'Packer', 'Chocolatey')

    $status = @{
        InstalledTools = @{}
        PackageManagers = $script:DeveloperToolsState.PackageManagers.Clone()
        SystemInfo = @{
            OS = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
            PowerShellVersion = $PSVersionTable.PSVersion
        }
    }

    foreach ($tool in $tools) {
        $isInstalled = Test-ToolInstalled -Tool $tool
        $status.InstalledTools[$tool] = @{
            Installed = $isInstalled
            Command = if ($isInstalled) {
                $commands = @{
                    'Git' = 'git'; 'Node' = 'node'; 'Python' = 'python'; 'VSCode' = 'code'
                    'Docker' = 'docker'; 'AzureCLI' = 'az'; 'AWSCLI' = 'aws'
                    '7Zip' = if ($IsWindows) { '7z' } else { '7za' }
                    'Packer' = 'packer'; 'Chocolatey' = 'choco'
                }
                $cmd = Get-Command $commands[$tool] -ErrorAction SilentlyContinue
                if ($cmd) { $cmd.Source } else { $null }
            } else { $null }
        }
    }

    return $status
}

# Export functions
Export-ModuleMember -Function @(
    'Install-DevelopmentEnvironment',
    'Install-DeveloperTool',
    'Initialize-PackageManagers',
    'Install-Git',
    'Install-NodeJS',
    'Install-Python',
    'Install-VSCode',
    'Install-Docker',
    'Install-AzureCLI',
    'Install-AWSCLI',
    'Install-7Zip',
    'Install-Chocolatey',
    'Set-PowerShellDevelopmentProfile',
    'Test-ToolInstalled',
    'Get-DeveloperToolsStatus'
)