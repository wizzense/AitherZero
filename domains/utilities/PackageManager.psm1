#Requires -Version 7.0

<#
.SYNOPSIS
    Package Manager Utilities for AitherZero
.DESCRIPTION  
    Provides centralized package manager functions with automatic detection,
    prioritization, and fallback strategies for software installation across platforms.
.NOTES
    Author: AitherZero Team
    Created: 2024-10-24
#>

# Package Manager Configurations
$script:WindowsPackageManagers = @{
    'winget' = @{
        Command = 'winget'
        Priority = 1
        InstallArgs = @('install', '--id', '{0}', '--exact', '--source', 'winget', '--accept-source-agreements', '--accept-package-agreements', '--silent')
        CheckArgs = @('list', '--id', '{0}', '--exact')
    }
    'chocolatey' = @{
        Command = 'choco'
        Priority = 2 
        InstallArgs = @('install', '{0}', '-y')
        CheckArgs = @('list', '{0}', '--exact', '--local-only')
    }
}

$script:LinuxPackageManagers = @{
    'apt' = @{
        Command = 'apt-get'
        Priority = 1
        InstallArgs = @('install', '-y', '{0}')
        CheckArgs = @('list', '--installed', '{0}')
        UpdateArgs = @('update')
    }
    'yum' = @{
        Command = 'yum'  
        Priority = 2
        InstallArgs = @('install', '-y', '{0}')
        CheckArgs = @('list', 'installed', '{0}')
    }
    'dnf' = @{
        Command = 'dnf'
        Priority = 2
        InstallArgs = @('install', '-y', '{0}')
        CheckArgs = @('list', '--installed', '{0}')
    }
    'pacman' = @{
        Command = 'pacman'
        Priority = 3
        InstallArgs = @('-S', '--noconfirm', '{0}')
        CheckArgs = @('-Qi', '{0}')
    }
}

$script:MacPackageManagers = @{
    'brew' = @{
        Command = 'brew'
        Priority = 1
        InstallArgs = @('install', '{0}')
        CheckArgs = @('list', '{0}')
        CaskArgs = @('install', '--cask', '{0}')
    }
}

# Software Package Mappings
$script:SoftwarePackages = @{
    'git' = @{
        winget = 'Git.Git'
        chocolatey = 'git'
        apt = 'git' 
        yum = 'git'
        dnf = 'git'
        pacman = 'git'
        brew = 'git'
    }
    'nodejs' = @{
        winget = 'OpenJS.NodeJS'
        chocolatey = 'nodejs'
        apt = 'nodejs'
        yum = 'nodejs' 
        dnf = 'nodejs'
        pacman = 'nodejs'
        brew = 'node'
    }
    'vscode' = @{
        winget = 'Microsoft.VisualStudioCode'
        chocolatey = 'vscode'
        apt = 'code'
        yum = 'code'
        dnf = 'code'  
        pacman = 'code'
        brew = 'visual-studio-code'
        brew_cask = $true
    }
    'python' = @{
        winget = 'Python.Python.3.12'
        chocolatey = 'python'
        apt = 'python3'
        yum = 'python3'
        dnf = 'python3'
        pacman = 'python'
        brew = 'python3'
    }
    '7zip' = @{
        winget = '7zip.7zip'
        chocolatey = '7zip'
        apt = 'p7zip-full'
        yum = 'p7zip'
        dnf = 'p7zip'
        pacman = 'p7zip'
        brew = 'p7zip'
    }
    'azure-cli' = @{
        winget = 'Microsoft.AzureCLI'
        chocolatey = 'azure-cli'
        apt = 'azure-cli'
        yum = 'azure-cli' 
        dnf = 'azure-cli'
        pacman = 'azure-cli'
        brew = 'azure-cli'
    }
    'docker' = @{
        winget = 'Docker.DockerDesktop'
        chocolatey = 'docker-desktop'
        apt = 'docker.io'
        yum = 'docker'
        dnf = 'docker'
        pacman = 'docker'
        brew = 'docker'
        brew_cask = $true
    }
    'golang' = @{
        winget = 'GoLang.Go'
        chocolatey = 'golang'
        apt = 'golang-go'
        yum = 'golang'
        dnf = 'golang'
        pacman = 'go'
        brew = 'go'
    }
    'powershell' = @{
        winget = 'Microsoft.PowerShell'
        chocolatey = 'powershell-core'
        apt = 'powershell'
        yum = 'powershell'
        dnf = 'powershell'
        pacman = 'powershell'
        brew = 'powershell'
        brew_cask = $true
    }
}

function Write-PackageLog {
    param(
        [string]$Message,
        [ValidateSet('Debug', 'Information', 'Warning', 'Error')]
        [string]$Level = 'Information'
    )
    
    try {
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message $Message -Level $Level
        } else {
            $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            $prefix = switch ($Level) {
                'Error' { 'ERROR' }
                'Warning' { 'WARN' }
                'Debug' { 'DEBUG' }
                default { 'INFO' }
            }
            Write-Host "[$timestamp] [$prefix] $Message"
        }
    } catch {
        # Fallback to Write-Host if logging fails
        Write-Host "[$Level] $Message"
    }
}

function Get-AvailablePackageManagers {
    <#
    .SYNOPSIS
        Detects available package managers on the current system
    .DESCRIPTION
        Scans for available package managers based on the current platform
        and returns them in priority order
    #>
    [CmdletBinding()]
    param()
    
    $available = @()
    
    if ($IsWindows) {
        foreach ($pm in ($script:WindowsPackageManagers.GetEnumerator() | Sort-Object { $_.Value.Priority })) {
            if (Get-Command $pm.Value.Command -ErrorAction SilentlyContinue) {
                $available += @{
                    Name = $pm.Key
                    Config = $pm.Value
                    Platform = 'Windows'
                }
                Write-PackageLog "Found package manager: $($pm.Key)" -Level Debug
            }
        }
    } elseif ($IsLinux) {
        foreach ($pm in ($script:LinuxPackageManagers.GetEnumerator() | Sort-Object { $_.Value.Priority })) {
            if (Get-Command $pm.Value.Command -ErrorAction SilentlyContinue) {
                $available += @{
                    Name = $pm.Key
                    Config = $pm.Value  
                    Platform = 'Linux'
                }
                Write-PackageLog "Found package manager: $($pm.Key)" -Level Debug
            }
        }
    } elseif ($IsMacOS) {
        foreach ($pm in ($script:MacPackageManagers.GetEnumerator() | Sort-Object { $_.Value.Priority })) {
            if (Get-Command $pm.Value.Command -ErrorAction SilentlyContinue) {
                $available += @{
                    Name = $pm.Key
                    Config = $pm.Value
                    Platform = 'macOS'
                }
                Write-PackageLog "Found package manager: $($pm.Key)" -Level Debug  
            }
        }
    }
    
    return $available
}

function Get-PackageId {
    <#
    .SYNOPSIS
        Gets the package ID for a software package on a specific package manager
    .PARAMETER SoftwareName
        The standard name of the software (e.g., 'git', 'nodejs', 'vscode')
    .PARAMETER PackageManagerName  
        The name of the package manager (e.g., 'winget', 'chocolatey', 'apt')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SoftwareName,
        
        [Parameter(Mandatory)]
        [string]$PackageManagerName
    )
    
    $packageInfo = $script:SoftwarePackages[$SoftwareName.ToLower()]
    if (-not $packageInfo) {
        Write-PackageLog "No package mapping found for software: $SoftwareName" -Level Warning
        return $null
    }
    
    $packageId = $packageInfo[$PackageManagerName.ToLower()]
    if (-not $packageId) {
        Write-PackageLog "No package ID found for $SoftwareName on $PackageManagerName" -Level Warning  
        return $null
    }
    
    return $packageId
}

function Test-PackageInstalled {
    <#
    .SYNOPSIS
        Tests if a software package is already installed
    .PARAMETER SoftwareName
        The standard name of the software to check
    .PARAMETER PackageManager
        The package manager configuration object  
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SoftwareName,
        
        [Parameter(Mandatory)]
        [hashtable]$PackageManager
    )
    
    $packageId = Get-PackageId -SoftwareName $SoftwareName -PackageManagerName $PackageManager.Name
    if (-not $packageId) {
        return $false
    }
    
    try {
        $checkArgs = $PackageManager.Config.CheckArgs | ForEach-Object { $_ -f $packageId }
        $result = & $PackageManager.Config.Command @checkArgs 2>&1
        
        # Different package managers have different success indicators
        switch ($PackageManager.Name) {
            'winget' { 
                return $LASTEXITCODE -eq 0 -and $result -match $packageId
            }
            'chocolatey' {
                return $LASTEXITCODE -eq 0 -and $result -match $packageId  
            }
            'apt' {
                return $LASTEXITCODE -eq 0 -and $result -match 'installed'
            }
            { $_ -in 'yum', 'dnf' } {
                return $LASTEXITCODE -eq 0
            }
            'pacman' {
                return $LASTEXITCODE -eq 0
            }
            'brew' {
                return $LASTEXITCODE -eq 0  
            }
            default {
                return $LASTEXITCODE -eq 0
            }
        }
    } catch {
        Write-PackageLog "Error checking if $SoftwareName is installed via $($PackageManager.Name): $_" -Level Debug
        return $false
    }
}

function Install-SoftwarePackage {
    <#
    .SYNOPSIS  
        Installs a software package using the best available package manager
    .PARAMETER SoftwareName
        The standard name of the software to install
    .PARAMETER PreferredPackageManager
        Optional preferred package manager name  
    .PARAMETER Force
        Force installation even if package appears to be installed
    .PARAMETER WhatIf
        Show what would be done without actually installing
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$SoftwareName,
        
        [string]$PreferredPackageManager,
        
        [switch]$Force,
        
        [switch]$WhatIf
    )
    
    Write-PackageLog "Starting installation of $SoftwareName"
    
    # Get available package managers in priority order
    $packageManagers = Get-AvailablePackageManagers
    if ($packageManagers.Count -eq 0) {
        throw "No package managers found on this system"
    }
    
    # If preferred package manager specified, try it first
    if ($PreferredPackageManager) {
        $preferred = $packageManagers | Where-Object { $_.Name -eq $PreferredPackageManager }
        if ($preferred) {
            $packageManagers = @($preferred) + ($packageManagers | Where-Object { $_.Name -ne $PreferredPackageManager })
        } else {
            Write-PackageLog "Preferred package manager '$PreferredPackageManager' not available" -Level Warning
        }
    }
    
    # Check if already installed (unless Force is specified)
    if (-not $Force) {
        foreach ($pm in $packageManagers) {
            if (Test-PackageInstalled -SoftwareName $SoftwareName -PackageManager $pm) {
                Write-PackageLog "$SoftwareName is already installed via $($pm.Name)"
                return @{ Success = $true; PackageManager = $pm.Name; Status = 'Already Installed' }
            }
        }
    }
    
    # Try installing with each package manager until one succeeds
    foreach ($pm in $packageManagers) {
        $packageId = Get-PackageId -SoftwareName $SoftwareName -PackageManagerName $pm.Name  
        if (-not $packageId) {
            Write-PackageLog "Skipping $($pm.Name) - no package mapping for $SoftwareName" -Level Debug
            continue
        }
        
        Write-PackageLog "Attempting to install $SoftwareName ($packageId) via $($pm.Name)"
        
        try {
            # Handle special cases (e.g., brew cask)
            $installArgs = $pm.Config.InstallArgs
            if ($pm.Name -eq 'brew' -and $script:SoftwarePackages[$SoftwareName.ToLower()].brew_cask) {
                $installArgs = $pm.Config.CaskArgs
            }
            
            $args = $installArgs | ForEach-Object { $_ -f $packageId }
            
            if ($WhatIf) {
                Write-PackageLog "Would run: $($pm.Config.Command) $($args -join ' ')" -Level Information
                return @{ Success = $true; PackageManager = $pm.Name; Status = 'WhatIf' }
            }
            
            if ($PSCmdlet.ShouldProcess("$SoftwareName via $($pm.Name)", "Install Package")) {
                # Update package manager cache for Linux systems
                if ($pm.Platform -eq 'Linux' -and $pm.Config.UpdateArgs -and $pm.Name -eq 'apt') {
                    Write-PackageLog "Updating package cache for $($pm.Name)"
                    & sudo $pm.Config.Command @($pm.Config.UpdateArgs) 2>&1 | Out-Null
                }
                
                # Run installation
                $output = & $pm.Config.Command @args 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-PackageLog "$SoftwareName installed successfully via $($pm.Name)"
                    
                    # Verify installation
                    Start-Sleep -Seconds 2
                    if (Test-PackageInstalled -SoftwareName $SoftwareName -PackageManager $pm) {
                        return @{ Success = $true; PackageManager = $pm.Name; Status = 'Installed' }
                    } else {
                        Write-PackageLog "Installation appeared successful but verification failed" -Level Warning
                    }
                } else {
                    Write-PackageLog "Installation failed via $($pm.Name): $output" -Level Warning
                }
            }
        } catch {
            Write-PackageLog "Error installing $SoftwareName via $($pm.Name): $_" -Level Warning  
        }
    }
    
    throw "Failed to install $SoftwareName with any available package manager"
}

function Get-SoftwareVersion {
    <#
    .SYNOPSIS
        Gets the installed version of a software package
    .PARAMETER SoftwareName  
        The standard name of the software
    .PARAMETER Command
        Optional custom command to check version (defaults to common patterns)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SoftwareName,
        
        [string]$Command
    )
    
    # Common version check patterns
    $versionChecks = @{
        'git' = @('git', '--version')
        'nodejs' = @('node', '--version')  
        'python' = @('python', '--version')
        'golang' = @('go', 'version')
        'docker' = @('docker', '--version')
        'powershell' = @('pwsh', '--version')
        'vscode' = @('code', '--version')
        'azure-cli' = @('az', '--version')
    }
    
    try {
        if ($Command) {
            $versionOutput = Invoke-Expression $Command 2>&1
        } else {
            $checkCmd = $versionChecks[$SoftwareName.ToLower()]
            if ($checkCmd) {
                $versionOutput = & $checkCmd[0] $checkCmd[1] 2>&1
            } else {
                return "Version check not available for $SoftwareName"
            }
        }
        
        if ($LASTEXITCODE -eq 0) {
            return $versionOutput.ToString().Trim()
        } else {
            return "Could not determine version"
        }
    } catch {
        return "Error checking version: $_"
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Get-AvailablePackageManagers',
    'Get-PackageId', 
    'Test-PackageInstalled',
    'Install-SoftwarePackage',
    'Get-SoftwareVersion'
)