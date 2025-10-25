#Requires -Version 7.0
<#
.SYNOPSIS
    AitherZero Bootstrap Module - Environment Setup and Initialization
.DESCRIPTION
    Consolidates functionality from automation scripts 0000-0099 into a proper PowerShell module.
    Handles environment preparation, directory setup, PowerShell 7 installation, and core tools.
.NOTES
    Copyright © 2025 Aitherium Corporation
    Replaces: 0000_Cleanup-Environment.ps1, 0001_Ensure-PowerShell7.ps1, 0002_Setup-Directories.ps1,
              0006_Install-ValidationTools.ps1, 0007_Install-Go.ps1, 0008_Install-OpenTofu.ps1,
              0009_Initialize-OpenTofu.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module state
$script:BootstrapState = @{
    ProjectRoot = $env:AITHERZERO_ROOT ?? $PSScriptRoot
    Initialized = $false
    EnvironmentStatus = @{}
    InstalledTools = @{}
}

# Import dependencies
if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
    $script:LoggingAvailable = $true
} else {
    $script:LoggingAvailable = $false
}

function Write-BootstrapLog {
    param(
        [string]$Message,
        [string]$Level = 'Information',
        [hashtable]$Data = @{}
    )
    
    if ($script:LoggingAvailable) {
        Write-CustomLog -Message $Message -Level $Level -Source 'Bootstrap' -Data $Data
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

function Initialize-AitherEnvironment {
    <#
    .SYNOPSIS
        Initialize the complete AitherZero environment
    .DESCRIPTION
        Performs comprehensive environment setup including PowerShell 7, directories, and core tools
    .PARAMETER Force
        Force initialization even if already completed
    .PARAMETER IncludeTools
        Include installation of development tools (Go, OpenTofu, etc.)
    .PARAMETER Clean
        Clean environment before initialization
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$Force,
        [switch]$IncludeTools,
        [switch]$Clean,
        [hashtable]$Configuration = @{}
    )
    
    Write-BootstrapLog "Initializing AitherZero environment"
    
    try {
        # Clean environment if requested
        if ($Clean) {
            Clear-AitherEnvironment -Force:$Force
        }
        
        # Ensure PowerShell 7+
        if (-not (Test-PowerShell7)) {
            Install-PowerShell7
        }
        
        # Setup directory structure
        Initialize-DirectoryStructure
        
        # Install validation tools
        Install-ValidationTools
        
        # Install development tools if requested
        if ($IncludeTools) {
            Install-DevelopmentTools -Configuration $Configuration
        }
        
        # Mark as initialized
        $script:BootstrapState.Initialized = $true
        $script:BootstrapState.EnvironmentStatus = Get-EnvironmentStatus
        
        Write-BootstrapLog "Environment initialization completed successfully" -Level Success
        return $true
        
    } catch {
        Write-BootstrapLog "Environment initialization failed: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Test-PowerShell7 {
    <#
    .SYNOPSIS
        Test if PowerShell 7+ is available and current
    .DESCRIPTION
        Checks PowerShell version and availability
    #>
    [CmdletBinding()]
    param()
    
    # Check current PowerShell version
    $currentVersion = $PSVersionTable.PSVersion
    Write-BootstrapLog "Current PowerShell version: $currentVersion"
    
    if ($currentVersion.Major -ge 7) {
        Write-BootstrapLog "PowerShell 7+ is available" -Level Success
        return $true
    }
    
    # Check if pwsh is available
    $pwshPath = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshPath) {
        Write-BootstrapLog "PowerShell 7 (pwsh) found at: $($pwshPath.Source)"
        return $true
    }
    
    Write-BootstrapLog "PowerShell 7 is required but not available" -Level Warning
    return $false
}

function Install-PowerShell7 {
    <#
    .SYNOPSIS
        Install PowerShell 7 on the current system
    .DESCRIPTION
        Installs PowerShell 7 using appropriate method for the platform
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$Force
    )
    
    Write-BootstrapLog "Installing PowerShell 7"
    
    if (-not $Force -and (Test-PowerShell7)) {
        Write-BootstrapLog "PowerShell 7 is already available"
        return $true
    }
    
    try {
        if ($IsWindows) {
            Install-PowerShell7Windows
        } elseif ($IsLinux) {
            Install-PowerShell7Linux
        } elseif ($IsMacOS) {
            Install-PowerShell7MacOS
        } else {
            throw "Unsupported operating system"
        }
        
        Write-BootstrapLog "PowerShell 7 installation completed" -Level Success
        return $true
        
    } catch {
        Write-BootstrapLog "PowerShell 7 installation failed: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Install-PowerShell7Windows {
    <#
    .SYNOPSIS
        Install PowerShell 7 on Windows
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    Write-BootstrapLog "Installing PowerShell 7 for Windows"
    
    # Try winget first
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Write-BootstrapLog "Using winget to install PowerShell"
        if ($PSCmdlet.ShouldProcess("PowerShell 7", "Install via winget")) {
            & winget install --id Microsoft.Powershell --source winget
        }
        return
    }
    
    # Try Chocolatey
    $choco = Get-Command choco -ErrorAction SilentlyContinue
    if ($choco) {
        Write-BootstrapLog "Using Chocolatey to install PowerShell"
        if ($PSCmdlet.ShouldProcess("PowerShell 7", "Install via Chocolatey")) {
            & choco install powershell-core -y
        }
        return
    }
    
    # Download and install MSI
    Write-BootstrapLog "Downloading PowerShell 7 MSI installer"
    $downloadUrl = "https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7-win-x64.msi"
    $installerPath = Join-Path $env:TEMP "PowerShell-7-win-x64.msi"
    
    if ($PSCmdlet.ShouldProcess("PowerShell 7", "Download and install MSI")) {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath
        Start-Process msiexec.exe -ArgumentList "/i", $installerPath, "/quiet" -Wait
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
    }
}

function Install-PowerShell7Linux {
    <#
    .SYNOPSIS
        Install PowerShell 7 on Linux
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    Write-BootstrapLog "Installing PowerShell 7 for Linux"
    
    # Detect Linux distribution
    if (Test-Path '/etc/os-release') {
        $osInfo = Get-Content '/etc/os-release' | ConvertFrom-StringData
        $distro = $osInfo.ID
        
        switch ($distro) {
            'ubuntu' { Install-PowerShell7Ubuntu }
            'debian' { Install-PowerShell7Debian }
            'centos' { Install-PowerShell7CentOS }
            'rhel' { Install-PowerShell7RHEL }
            default {
                Write-BootstrapLog "Installing PowerShell via snap (generic Linux)"
                if ($PSCmdlet.ShouldProcess("PowerShell 7", "Install via snap")) {
                    & sudo snap install powershell --classic
                }
            }
        }
    }
}

function Install-PowerShell7MacOS {
    <#
    .SYNOPSIS
        Install PowerShell 7 on macOS
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    Write-BootstrapLog "Installing PowerShell 7 for macOS"
    
    # Try Homebrew
    $brew = Get-Command brew -ErrorAction SilentlyContinue
    if ($brew) {
        Write-BootstrapLog "Using Homebrew to install PowerShell"
        if ($PSCmdlet.ShouldProcess("PowerShell 7", "Install via Homebrew")) {
            & brew install --cask powershell
        }
        return
    }
    
    # Download and install PKG
    Write-BootstrapLog "Downloading PowerShell 7 PKG installer"
    $downloadUrl = "https://github.com/PowerShell/PowerShell/releases/latest/download/powershell-7-osx-x64.pkg"
    $installerPath = "/tmp/powershell-7-osx-x64.pkg"
    
    if ($PSCmdlet.ShouldProcess("PowerShell 7", "Download and install PKG")) {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath
        & sudo installer -pkg $installerPath -target /
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
    }
}

function Initialize-DirectoryStructure {
    <#
    .SYNOPSIS
        Initialize the AitherZero directory structure
    .DESCRIPTION
        Creates all necessary directories for AitherZero operation
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    Write-BootstrapLog "Initializing directory structure"
    
    $projectRoot = $script:BootstrapState.ProjectRoot
    $directories = @(
        'logs',
        'temp',
        'cache', 
        'reports',
        'reports/tech-debt',
        'reports/coverage',
        'reports/analysis',
        'test-results',
        'backups',
        'downloads'
    )
    
    foreach ($dir in $directories) {
        $dirPath = Join-Path $projectRoot $dir
        if (-not (Test-Path $dirPath)) {
            Write-BootstrapLog "Creating directory: $dir"
            if ($PSCmdlet.ShouldProcess($dirPath, "Create directory")) {
                New-Item -Path $dirPath -ItemType Directory -Force | Out-Null
            }
        }
    }
    
    Write-BootstrapLog "Directory structure initialized" -Level Success
}

function Install-ValidationTools {
    <#
    .SYNOPSIS
        Install validation and testing tools
    .DESCRIPTION
        Installs Pester, PSScriptAnalyzer, and other validation tools
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    Write-BootstrapLog "Installing validation tools"
    
    $tools = @(
        @{ Name = 'Pester'; MinVersion = '5.0.0'; Repository = 'PSGallery' },
        @{ Name = 'PSScriptAnalyzer'; MinVersion = '1.20.0'; Repository = 'PSGallery' },
        @{ Name = 'platyPS'; MinVersion = '0.14.0'; Repository = 'PSGallery' }
    )
    
    foreach ($tool in $tools) {
        try {
            $installed = Get-Module -Name $tool.Name -ListAvailable | 
                Where-Object { $_.Version -ge [Version]$tool.MinVersion } | 
                Sort-Object Version -Descending | 
                Select-Object -First 1
            
            if (-not $installed) {
                Write-BootstrapLog "Installing $($tool.Name)"
                if ($PSCmdlet.ShouldProcess($tool.Name, "Install module")) {
                    Install-Module -Name $tool.Name -Repository $tool.Repository -MinimumVersion $tool.MinVersion -Force -Scope CurrentUser
                }
            } else {
                Write-BootstrapLog "$($tool.Name) v$($installed.Version) is already installed"
            }
            
            $script:BootstrapState.InstalledTools[$tool.Name] = $true
            
        } catch {
            Write-BootstrapLog "Failed to install $($tool.Name): $($_.Exception.Message)" -Level Warning
        }
    }
    
    Write-BootstrapLog "Validation tools installation completed" -Level Success
}

function Install-DevelopmentTools {
    <#
    .SYNOPSIS
        Install development tools (Go, OpenTofu, etc.)
    .DESCRIPTION
        Installs additional development tools based on configuration
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [hashtable]$Configuration = @{}
    )
    
    Write-BootstrapLog "Installing development tools"
    
    # Install Go if requested
    if ($Configuration.ContainsKey('InstallGo') -and $Configuration.InstallGo) {
        Install-GoLanguage
    }
    
    # Install OpenTofu if requested  
    if ($Configuration.ContainsKey('InstallOpenTofu') -and $Configuration.InstallOpenTofu) {
        Install-OpenTofu
        Initialize-OpenTofu
    }
    
    Write-BootstrapLog "Development tools installation completed" -Level Success
}

function Install-GoLanguage {
    <#
    .SYNOPSIS
        Install Go programming language
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    Write-BootstrapLog "Installing Go programming language"
    
    # Check if Go is already installed
    $go = Get-Command go -ErrorAction SilentlyContinue
    if ($go) {
        $version = & go version
        Write-BootstrapLog "Go is already installed: $version"
        return
    }
    
    try {
        if ($IsWindows) {
            # Use Chocolatey or winget
            $choco = Get-Command choco -ErrorAction SilentlyContinue
            if ($choco) {
                if ($PSCmdlet.ShouldProcess("Go", "Install via Chocolatey")) {
                    & choco install golang -y
                }
            } else {
                Write-BootstrapLog "Manual installation required for Go on Windows without package manager" -Level Warning
            }
        } elseif ($IsLinux) {
            # Download and install Go for Linux
            $goVersion = "1.21.0"  # Update as needed
            $downloadUrl = "https://golang.org/dl/go$goVersion.linux-amd64.tar.gz"
            $installPath = "/usr/local/go"
            
            if ($PSCmdlet.ShouldProcess("Go $goVersion", "Download and install")) {
                Write-BootstrapLog "Downloading Go $goVersion"
                $tempFile = "/tmp/go$goVersion.linux-amd64.tar.gz"
                Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile
                
                Write-BootstrapLog "Installing Go to $installPath"
                & sudo rm -rf $installPath
                & sudo tar -C /usr/local -xzf $tempFile
                
                # Add to PATH
                $profileLine = 'export PATH=$PATH:/usr/local/go/bin'
                Add-Content -Path ~/.profile -Value $profileLine
                
                Remove-Item $tempFile -Force
            }
        } elseif ($IsMacOS) {
            # Use Homebrew
            $brew = Get-Command brew -ErrorAction SilentlyContinue
            if ($brew) {
                if ($PSCmdlet.ShouldProcess("Go", "Install via Homebrew")) {
                    & brew install go
                }
            }
        }
        
        $script:BootstrapState.InstalledTools['Go'] = $true
        Write-BootstrapLog "Go installation completed" -Level Success
        
    } catch {
        Write-BootstrapLog "Go installation failed: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Install-OpenTofu {
    <#
    .SYNOPSIS
        Install OpenTofu (Terraform alternative)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    Write-BootstrapLog "Installing OpenTofu"
    
    # Check if OpenTofu is already installed
    $tofu = Get-Command tofu -ErrorAction SilentlyContinue
    if ($tofu) {
        $version = & tofu version
        Write-BootstrapLog "OpenTofu is already installed: $version"
        return
    }
    
    try {
        $tofuVersion = "1.6.0"  # Update as needed
        
        if ($IsWindows) {
            $downloadUrl = "https://github.com/opentofu/opentofu/releases/download/v$tofuVersion/tofu_${tofuVersion}_windows_amd64.zip"
            $installPath = "$env:ProgramFiles\OpenTofu"
            
            if ($PSCmdlet.ShouldProcess("OpenTofu $tofuVersion", "Download and install")) {
                Write-BootstrapLog "Downloading OpenTofu for Windows"
                $tempZip = Join-Path $env:TEMP "opentofu.zip"
                Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip
                
                Write-BootstrapLog "Installing OpenTofu to $installPath"
                Expand-Archive -Path $tempZip -DestinationPath $installPath -Force
                
                # Add to PATH
                $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
                if ($currentPath -notlike "*$installPath*") {
                    [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$installPath", "Machine")
                }
                
                Remove-Item $tempZip -Force
            }
        } elseif ($IsLinux) {
            $downloadUrl = "https://github.com/opentofu/opentofu/releases/download/v$tofuVersion/tofu_${tofuVersion}_linux_amd64.tar.gz"
            
            if ($PSCmdlet.ShouldProcess("OpenTofu $tofuVersion", "Download and install")) {
                Write-BootstrapLog "Downloading OpenTofu for Linux"
                $tempFile = "/tmp/opentofu.tar.gz"
                Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile
                
                Write-BootstrapLog "Installing OpenTofu to /usr/local/bin"
                & tar -xzf $tempFile -C /tmp
                & sudo mv /tmp/tofu /usr/local/bin/
                & sudo chmod +x /usr/local/bin/tofu
                
                Remove-Item $tempFile -Force
            }
        } elseif ($IsMacOS) {
            # Use Homebrew
            $brew = Get-Command brew -ErrorAction SilentlyContinue
            if ($brew) {
                if ($PSCmdlet.ShouldProcess("OpenTofu", "Install via Homebrew")) {
                    & brew install opentofu
                }
            }
        }
        
        $script:BootstrapState.InstalledTools['OpenTofu'] = $true
        Write-BootstrapLog "OpenTofu installation completed" -Level Success
        
    } catch {
        Write-BootstrapLog "OpenTofu installation failed: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Initialize-OpenTofu {
    <#
    .SYNOPSIS
        Initialize OpenTofu configuration
    .DESCRIPTION
        Sets up OpenTofu configuration and workspace
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    Write-BootstrapLog "Initializing OpenTofu configuration"
    
    $projectRoot = $script:BootstrapState.ProjectRoot
    $infraPath = Join-Path $projectRoot "infrastructure"
    
    if (-not (Test-Path $infraPath)) {
        Write-BootstrapLog "Creating infrastructure directory"
        if ($PSCmdlet.ShouldProcess($infraPath, "Create directory")) {
            New-Item -Path $infraPath -ItemType Directory -Force | Out-Null
        }
    }
    
    # Create basic main.tf if it doesn't exist
    $mainTfPath = Join-Path $infraPath "main.tf"
    if (-not (Test-Path $mainTfPath)) {
        $mainTfContent = @'
# AitherZero Infrastructure Configuration
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

# Example resource - customize as needed
resource "local_file" "aitherzero_marker" {
  content  = "AitherZero infrastructure initialized at ${timestamp()}"
  filename = "${path.module}/../temp/infrastructure-initialized.txt"
}
'@
        
        Write-BootstrapLog "Creating basic main.tf configuration"
        if ($PSCmdlet.ShouldProcess($mainTfPath, "Create Terraform configuration")) {
            Set-Content -Path $mainTfPath -Value $mainTfContent -Encoding UTF8
        }
    }
    
    # Initialize OpenTofu
    $tofu = Get-Command tofu -ErrorAction SilentlyContinue
    if ($tofu) {
        Write-BootstrapLog "Running tofu init"
        if ($PSCmdlet.ShouldProcess($infraPath, "Initialize OpenTofu")) {
            Push-Location $infraPath
            try {
                & tofu init
                Write-BootstrapLog "OpenTofu initialization completed" -Level Success
            } finally {
                Pop-Location
            }
        }
    } else {
        Write-BootstrapLog "OpenTofu not available for initialization" -Level Warning
    }
}

function Clear-AitherEnvironment {
    <#
    .SYNOPSIS
        Clean up AitherZero environment
    .DESCRIPTION
        Removes temporary files, caches, and resets environment state
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$Force
    )
    
    Write-BootstrapLog "Cleaning AitherZero environment"
    
    $projectRoot = $script:BootstrapState.ProjectRoot
    $cleanupPaths = @(
        'temp/*',
        'cache/*',
        'logs/*.log',
        'test-results/*'
    )
    
    foreach ($path in $cleanupPaths) {
        $fullPath = Join-Path $projectRoot $path
        $items = Get-ChildItem -Path $fullPath -Force -ErrorAction SilentlyContinue
        
        if ($items) {
            Write-BootstrapLog "Cleaning: $path"
            if ($PSCmdlet.ShouldProcess($fullPath, "Remove items")) {
                $items | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    # Reset state
    $script:BootstrapState.Initialized = $false
    $script:BootstrapState.EnvironmentStatus = @{}
    $script:BootstrapState.InstalledTools = @{}
    
    Write-BootstrapLog "Environment cleanup completed" -Level Success
}

function Get-EnvironmentStatus {
    <#
    .SYNOPSIS
        Get comprehensive environment status
    .DESCRIPTION
        Returns detailed information about the AitherZero environment setup
    #>
    [CmdletBinding()]
    param()
    
    $status = @{
        PowerShellVersion = $PSVersionTable.PSVersion
        PowerShell7Available = Test-PowerShell7
        ProjectRoot = $script:BootstrapState.ProjectRoot
        DirectoriesCreated = @()
        InstalledTools = $script:BootstrapState.InstalledTools.Clone()
        SystemInfo = @{
            OS = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
            Architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
            DotNetVersion = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
        }
    }
    
    # Check directories
    $expectedDirectories = @('logs', 'temp', 'cache', 'reports', 'test-results')
    foreach ($dir in $expectedDirectories) {
        $dirPath = Join-Path $script:BootstrapState.ProjectRoot $dir
        if (Test-Path $dirPath) {
            $status.DirectoriesCreated += $dir
        }
    }
    
    # Check for external tools
    $externalTools = @('git', 'go', 'tofu', 'terraform', 'docker', 'node', 'npm')
    $status.ExternalTools = @{}
    
    foreach ($tool in $externalTools) {
        $command = Get-Command $tool -ErrorAction SilentlyContinue
        $status.ExternalTools[$tool] = if ($command) { 
            @{ Available = $true; Path = $command.Source }
        } else { 
            @{ Available = $false; Path = $null }
        }
    }
    
    return $status
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-AitherEnvironment',
    'Test-PowerShell7',
    'Install-PowerShell7', 
    'Initialize-DirectoryStructure',
    'Install-ValidationTools',
    'Install-DevelopmentTools',
    'Install-GoLanguage',
    'Install-OpenTofu',
    'Initialize-OpenTofu',
    'Clear-AitherEnvironment',
    'Get-EnvironmentStatus'
)