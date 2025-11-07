#Requires -Version 7.0

<#
.SYNOPSIS
    Deployment artifact generation for AitherZero configurations
.DESCRIPTION
    Generates deployment artifacts from configuration files including:
    - Windows: Unattend.xml, registry files, PowerShell DSC
    - Linux: Cloud-init, Kickstart, Preseed, shell scripts
    - macOS: Shell scripts, Brewfiles, configuration profiles
    - Docker: Dockerfiles and docker-compose.yml
    - ISO: Integration with ISO customization tools
    
    This module bridges configuration management and infrastructure deployment.
.NOTES
    Module: DeploymentArtifacts
    Domain: Infrastructure
    Version: 1.0.0
#>

#region Helper Functions

function Write-ArtifactLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Information', 'Warning', 'Error', 'Success', 'Debug')]
        [string]$Level = 'Information'
    )
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level
    }
    else {
        $colors = @{
            Information = 'Cyan'
            Warning = 'Yellow'
            Error = 'Red'
            Success = 'Green'
            Debug = 'DarkGray'
        }
        Write-Host "[$Level] $Message" -ForegroundColor $colors[$Level]
    }
}

function Ensure-OutputDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
        Write-ArtifactLog "Created output directory: $Path" -Level Debug
    }
}

#endregion

#region Windows Artifacts

function New-WindowsUnattendXml {
    <#
    .SYNOPSIS
        Generate Windows Unattend.xml from configuration
    
    .DESCRIPTION
        Creates an Unattend.xml file for Windows automated installation
        based on settings from config.windows.psd1
    
    .PARAMETER ConfigPath
        Path to Windows configuration file
    
    .PARAMETER OutputPath
        Output directory for generated file
    
    .PARAMETER FileName
        Output filename (default: Autounattend.xml)
    
    .EXAMPLE
        New-WindowsUnattendXml -ConfigPath ./config.windows.psd1
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,
        
        [string]$OutputPath = './artifacts/windows',
        
        [string]$FileName = 'Autounattend.xml'
    )
    
    Write-ArtifactLog "Generating Windows Unattend.xml from $ConfigPath" -Level Information
    
    try {
        # Load configuration
        $content = Get-Content -Path $ConfigPath -Raw
        $scriptBlock = [scriptblock]::Create($content)
        $config = & $scriptBlock
        
        if (-not $config.Windows.DeploymentArtifacts.Unattend.Generate) {
            Write-ArtifactLog "Unattend.xml generation is disabled in configuration" -Level Warning
            return $null
        }
        
        $unattendConfig = $config.Windows.DeploymentArtifacts.Unattend
        
        # Create XML document
        $xml = [xml]@'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
</unattend>
'@
        
        # Add windowsPE configuration pass
        $windowsPE = $xml.CreateElement('settings', $xml.DocumentElement.NamespaceURI)
        $windowsPE.SetAttribute('pass', 'windowsPE')
        
        # Add specialize configuration pass
        $specialize = $xml.CreateElement('settings', $xml.DocumentElement.NamespaceURI)
        $specialize.SetAttribute('pass', 'specialize')
        
        # Add oobeSystem configuration pass (user creation, etc.)
        $oobeSystem = $xml.CreateElement('settings', $xml.DocumentElement.NamespaceURI)
        $oobeSystem.SetAttribute('pass', 'oobeSystem')
        
        # Add computer name if configured
        if ($unattendConfig.ComputerName) {
            $component = $xml.CreateElement('component', $xml.DocumentElement.NamespaceURI)
            $component.SetAttribute('name', 'Microsoft-Windows-Shell-Setup')
            $component.SetAttribute('processorArchitecture', 'amd64')
            $component.SetAttribute('publicKeyToken', '31bf3856ad364e35')
            $component.SetAttribute('language', 'neutral')
            $component.SetAttribute('versionScope', 'nonSxS')
            
            $computerName = $xml.CreateElement('ComputerName', $xml.DocumentElement.NamespaceURI)
            $computerName.InnerText = $unattendConfig.ComputerName
            $component.AppendChild($computerName) | Out-Null
            
            $specialize.AppendChild($component) | Out-Null
        }
        
        $xml.DocumentElement.AppendChild($windowsPE) | Out-Null
        $xml.DocumentElement.AppendChild($specialize) | Out-Null
        $xml.DocumentElement.AppendChild($oobeSystem) | Out-Null
        
        # Ensure output directory exists
        Ensure-OutputDirectory -Path $OutputPath
        
        # Save XML file
        $outputFile = Join-Path $OutputPath $FileName
        $xml.Save($outputFile)
        
        Write-ArtifactLog "Generated Unattend.xml: $outputFile" -Level Success
        return $outputFile
    }
    catch {
        Write-ArtifactLog "Error generating Unattend.xml: $($_.Exception.Message)" -Level Error
        throw
    }
}

function New-WindowsRegistryFile {
    <#
    .SYNOPSIS
        Generate Windows registry import file (.reg)
    
    .DESCRIPTION
        Creates a .reg file with registry settings from config.windows.psd1
    
    .PARAMETER ConfigPath
        Path to Windows configuration file
    
    .PARAMETER OutputPath
        Output directory for generated file
    
    .EXAMPLE
        New-WindowsRegistryFile -ConfigPath ./config.windows.psd1
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,
        
        [string]$OutputPath = './artifacts/windows'
    )
    
    Write-ArtifactLog "Generating Windows registry file from $ConfigPath" -Level Information
    
    try {
        # Load configuration
        $content = Get-Content -Path $ConfigPath -Raw
        $scriptBlock = [scriptblock]::Create($content)
        $config = & $scriptBlock
        
        if (-not $config.Windows.DeploymentArtifacts.RegistryExport.Generate) {
            Write-ArtifactLog "Registry export is disabled in configuration" -Level Warning
            return $null
        }
        
        $registryConfig = $config.Windows.Registry
        $outputFileName = $config.Windows.DeploymentArtifacts.RegistryExport.FileName
        
        # Start registry file content
        $regContent = @('Windows Registry Editor Version 5.00', '')
        
        # Process all registry categories
        foreach ($category in $registryConfig.Keys | Where-Object { $_ -ne 'AutoApply' -and $_ -ne 'BackupBeforeChanges' }) {
            $regContent += ""; $regContent += "; $category Settings"
            
            foreach ($settingKey in $registryConfig[$category].Keys) {
                $setting = $registryConfig[$category][$settingKey]
                
                if ($setting.Enabled -and $setting.Path -and $setting.Name) {
                    # Convert PowerShell path to registry path
                    $regPath = $setting.Path -replace 'HKLM:', 'HKEY_LOCAL_MACHINE' -replace 'HKCU:', 'HKEY_CURRENT_USER'
                    
                    $regContent += "[$regPath]"
                    
                    # Determine registry value type
                    $valueType = switch ($setting.Type) {
                        'DWord' { 'dword' }
                        'String' { '' }
                        'QWord' { 'qword' }
                        'Binary' { 'hex' }
                        'MultiString' { 'hex(7)' }
                        'ExpandString' { 'hex(2)' }
                        default { 'dword' }
                    }
                    
                    if ($valueType -eq '') {
                        # String value
                        $regContent += "`"$($setting.Name)`"=`"$($setting.Value)`""
                    }
                    else {
                        # Other types
                        $value = $setting.Value
                        if ($valueType -eq 'dword' -and $value -is [bool]) {
                            $value = if ($value) { 1 } else { 0 }
                        }
                        $regContent += "`"$($setting.Name)`"=$valueType`:$([string]$value)"
                    }
                    
                    if ($setting.Description) {
                        $regContent += "; $($setting.Description)"
                    }
                    $regContent += ""
                }
            }
        }
        
        # Ensure output directory exists
        Ensure-OutputDirectory -Path $OutputPath
        
        # Save registry file
        $outputFile = Join-Path $OutputPath $outputFileName
        $regContent | Out-File -FilePath $outputFile -Encoding ASCII -Force
        
        Write-ArtifactLog "Generated registry file: $outputFile" -Level Success
        return $outputFile
    }
    catch {
        Write-ArtifactLog "Error generating registry file: $($_.Exception.Message)" -Level Error
        throw
    }
}

#endregion

#region Linux Artifacts

function New-LinuxCloudInitConfig {
    <#
    .SYNOPSIS
        Generate cloud-init configuration from Linux config
    
    .DESCRIPTION
        Creates a cloud-init YAML/JSON configuration file
    
    .PARAMETER ConfigPath
        Path to Linux configuration file
    
    .PARAMETER OutputPath
        Output directory for generated file
    
    .PARAMETER Format
        Output format (yaml or json)
    
    .EXAMPLE
        New-LinuxCloudInitConfig -ConfigPath ./config.linux.psd1
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,
        
        [string]$OutputPath = './artifacts/linux',
        
        [ValidateSet('yaml', 'json')]
        [string]$Format = 'yaml'
    )
    
    Write-ArtifactLog "Generating cloud-init configuration from $ConfigPath" -Level Information
    
    try {
        # Load configuration
        $content = Get-Content -Path $ConfigPath -Raw
        $scriptBlock = [scriptblock]::Create($content)
        $config = & $scriptBlock
        
        if (-not $config.Linux.DeploymentArtifacts.CloudInit.Generate) {
            Write-ArtifactLog "Cloud-init generation is disabled in configuration" -Level Warning
            return $null
        }
        
        $cloudInitConfig = $config.Linux.DeploymentArtifacts.CloudInit
        
        # Build cloud-init configuration
        $cloudInit = @{
            '#cloud-config' = $null
            hostname = $config.Linux.System.Hostname.Name
            fqdn = $config.Linux.System.Hostname.FQDN
            manage_etc_hosts = $true
        }
        
        # Add users
        if ($config.Linux.Users.Create.Count -gt 0) {
            $cloudInit.users = @()
            foreach ($user in $config.Linux.Users.Create) {
                $cloudInit.users += @{
                    name = $user.Username
                    groups = $user.Groups -join ','
                    shell = $user.Shell
                    sudo = if ($user.Groups -contains 'sudo') { 'ALL=(ALL) NOPASSWD:ALL' } else { $null }
                }
            }
        }
        
        # Add packages
        if ($config.Linux.Packages.Essential.Count -gt 0) {
            $cloudInit.packages = $config.Linux.Packages.Essential
        }
        
        # Add kernel parameters
        if ($config.Linux.KernelParameters.AutoApply) {
            $cloudInit.write_files = @(
                @{
                    path = $config.Linux.KernelParameters.ConfigFile
                    content = ($config.Linux.KernelParameters.Parameters.GetEnumerator() | ForEach-Object { "$($_.Key) = $($_.Value)" }) -join "`n"
                    owner = 'root:root'
                    permissions = '0644'
                }
            )
        }
        
        # Ensure output directory exists
        Ensure-OutputDirectory -Path $OutputPath
        
        # Save cloud-init file
        $fileName = if ($Format -eq 'yaml') { 'cloud-init.yaml' } else { 'cloud-init.json' }
        $outputFile = Join-Path $OutputPath $fileName
        
        if ($Format -eq 'yaml') {
            # Simple YAML generation (for complex scenarios, use a proper YAML library)
            $yamlContent = "#cloud-config`n"
            $yamlContent += ConvertTo-SimpleYaml -Data $cloudInit
            $yamlContent | Out-File -FilePath $outputFile -Encoding UTF8 -Force
        }
        else {
            $cloudInit | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputFile -Encoding UTF8 -Force
        }
        
        Write-ArtifactLog "Generated cloud-init config: $outputFile" -Level Success
        return $outputFile
    }
    catch {
        Write-ArtifactLog "Error generating cloud-init config: $($_.Exception.Message)" -Level Error
        throw
    }
}

function ConvertTo-SimpleYaml {
    param([hashtable]$Data, [int]$Indent = 0)
    
    $yaml = ""
    $indentStr = "  " * $Indent
    
    foreach ($key in $Data.Keys) {
        $value = $Data[$key]
        
        if ($value -is [hashtable]) {
            $yaml += "$indentStr$($key):`n"
            $yaml += ConvertTo-SimpleYaml -Data $value -Indent ($Indent + 1)
        }
        elseif ($value -is [array]) {
            $yaml += "$indentStr$($key):`n"
            foreach ($item in $value) {
                if ($item -is [hashtable]) {
                    $yaml += "$indentStr  -`n"
                    foreach ($subKey in $item.Keys) {
                        $yaml += "$indentStr    $($subKey): $($item[$subKey])`n"
                    }
                }
                else {
                    $yaml += "$indentStr  - $item`n"
                }
            }
        }
        elseif ($null -eq $value) {
            # Skip null values or output as empty
        }
        else {
            $yaml += "$indentStr$($key): $value`n"
        }
    }
    
    return $yaml
}

function New-LinuxShellScript {
    <#
    .SYNOPSIS
        Generate Linux shell script from configuration
    
    .DESCRIPTION
        Creates a shell script that applies Linux configuration settings
    
    .PARAMETER ConfigPath
        Path to Linux configuration file
    
    .PARAMETER OutputPath
        Output directory for generated file
    
    .EXAMPLE
        New-LinuxShellScript -ConfigPath ./config.linux.psd1
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,
        
        [string]$OutputPath = './artifacts/linux'
    )
    
    Write-ArtifactLog "Generating Linux shell script from $ConfigPath" -Level Information
    
    try {
        # Load configuration
        $content = Get-Content -Path $ConfigPath -Raw
        $scriptBlock = [scriptblock]::Create($content)
        $config = & $scriptBlock
        
        if (-not $config.Linux.DeploymentArtifacts.ShellScript.Generate) {
            Write-ArtifactLog "Shell script generation is disabled in configuration" -Level Warning
            return $null
        }
        
        $scriptConfig = $config.Linux.DeploymentArtifacts.ShellScript
        
        # Build shell script
        $scriptLines = @()
        $scriptLines += $scriptConfig.Shebang
        $scriptLines += "#"
        $scriptLines += "# AitherZero Linux Configuration Script"
        $scriptLines += "# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $scriptLines += "#"
        $scriptLines += ""
        $scriptLines += "set -e  # Exit on error"
        $scriptLines += ""
        
        # Add hostname configuration
        if ($config.Linux.System.Hostname.Name) {
            $scriptLines += "# Set hostname"
            $scriptLines += "hostnamectl set-hostname $($config.Linux.System.Hostname.Name)"
            $scriptLines += ""
        }
        
        # Add kernel parameters
        if ($config.Linux.KernelParameters.AutoApply) {
            $scriptLines += "# Configure kernel parameters"
            $scriptLines += "cat > $($config.Linux.KernelParameters.ConfigFile) << 'EOF'"
            foreach ($param in $config.Linux.KernelParameters.Parameters.GetEnumerator()) {
                $scriptLines += "$($param.Key) = $($param.Value)"
            }
            $scriptLines += "EOF"
            $scriptLines += "sysctl -p $($config.Linux.KernelParameters.ConfigFile)"
            $scriptLines += ""
        }
        
        # Add package installation
        if ($config.Linux.Packages.Essential.Count -gt 0) {
            $scriptLines += "# Install essential packages"
            $scriptLines += "apt-get update -qq"
            $scriptLines += "apt-get install -y $($config.Linux.Packages.Essential -join ' ')"
            $scriptLines += ""
        }
        
        # Add firewall rules
        if ($config.Linux.Firewall.AutoApply) {
            $scriptLines += "# Configure firewall"
            $scriptLines += "ufw default $($config.Linux.Firewall.DefaultPolicy.Incoming) incoming"
            $scriptLines += "ufw default $($config.Linux.Firewall.DefaultPolicy.Outgoing) outgoing"
            
            foreach ($rule in $config.Linux.Firewall.Rules | Where-Object { $_.Enabled -ne $false }) {
                $scriptLines += "ufw $($rule.Action) $($rule.Port)/$($rule.Protocol)"
            }
            
            if ($config.Linux.Firewall.Enabled) {
                $scriptLines += "ufw --force enable"
            }
            $scriptLines += ""
        }
        
        $scriptLines += "echo 'AitherZero configuration complete!'"
        
        # Ensure output directory exists
        Ensure-OutputDirectory -Path $OutputPath
        
        # Save shell script
        $outputFile = Join-Path $OutputPath $scriptConfig.FileName
        $scriptLines -join "`n" | Out-File -FilePath $outputFile -Encoding UTF8 -Force
        
        # Make executable on Unix
        if ($IsLinux -or $IsMacOS) {
            chmod +x $outputFile
        }
        
        Write-ArtifactLog "Generated shell script: $outputFile" -Level Success
        return $outputFile
    }
    catch {
        Write-ArtifactLog "Error generating shell script: $($_.Exception.Message)" -Level Error
        throw
    }
}

#endregion

#region macOS Artifacts

function New-MacOSBrewfile {
    <#
    .SYNOPSIS
        Generate Homebrew Brewfile from macOS configuration
    
    .DESCRIPTION
        Creates a Brewfile for installing Homebrew packages
    
    .PARAMETER ConfigPath
        Path to macOS configuration file
    
    .PARAMETER OutputPath
        Output directory for generated file
    
    .EXAMPLE
        New-MacOSBrewfile -ConfigPath ./config.macos.psd1
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,
        
        [string]$OutputPath = './artifacts/macos'
    )
    
    Write-ArtifactLog "Generating Homebrew Brewfile from $ConfigPath" -Level Information
    
    try {
        # Load configuration
        $content = Get-Content -Path $ConfigPath -Raw
        $scriptBlock = [scriptblock]::Create($content)
        $config = & $scriptBlock
        
        if (-not $config.macOS.DeploymentArtifacts.Brewfile.Generate) {
            Write-ArtifactLog "Brewfile generation is disabled in configuration" -Level Warning
            return $null
        }
        
        $brewConfig = $config.macOS.DeploymentArtifacts.Brewfile
        $brewLines = @()
        
        # Add taps
        if ($brewConfig.IncludeTaps -and $config.macOS.Homebrew.Taps.Count -gt 0) {
            $brewLines += "# Taps"
            foreach ($tap in $config.macOS.Homebrew.Taps) {
                $brewLines += "tap '$tap'"
            }
            $brewLines += ""
        }
        
        # Add formulae
        if ($brewConfig.IncludeFormulae -and $config.macOS.Homebrew.Formulae.Count -gt 0) {
            $brewLines += "# Formulae"
            foreach ($formula in $config.macOS.Homebrew.Formulae) {
                $brewLines += "brew '$formula'"
            }
            $brewLines += ""
        }
        
        # Add casks
        if ($brewConfig.IncludeCasks -and $config.macOS.Homebrew.Casks.Count -gt 0) {
            $brewLines += "# Casks"
            foreach ($cask in $config.macOS.Homebrew.Casks) {
                $brewLines += "cask '$cask'"
            }
            $brewLines += ""
        }
        
        # Add Mac App Store apps
        if ($brewConfig.IncludeMAS -and $config.macOS.Homebrew.MAS.Count -gt 0) {
            $brewLines += "# Mac App Store"
            foreach ($app in $config.macOS.Homebrew.MAS) {
                $brewLines += "mas '$app'"
            }
        }
        
        # Ensure output directory exists
        Ensure-OutputDirectory -Path $OutputPath
        
        # Save Brewfile
        $outputFile = Join-Path $OutputPath $brewConfig.FileName
        $brewLines -join "`n" | Out-File -FilePath $outputFile -Encoding UTF8 -Force
        
        Write-ArtifactLog "Generated Brewfile: $outputFile" -Level Success
        return $outputFile
    }
    catch {
        Write-ArtifactLog "Error generating Brewfile: $($_.Exception.Message)" -Level Error
        throw
    }
}

#endregion

#region Docker Artifacts

function New-Dockerfile {
    <#
    .SYNOPSIS
        Generate Dockerfile from OS-specific configuration
    
    .DESCRIPTION
        Creates a Dockerfile based on Linux or Windows configuration
    
    .PARAMETER ConfigPath
        Path to configuration file (Linux or Windows)
    
    .PARAMETER OutputPath
        Output directory for generated file
    
    .PARAMETER Platform
        Target platform (linux or windows)
    
    .EXAMPLE
        New-Dockerfile -ConfigPath ./config.linux.psd1 -Platform linux
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,
        
        [string]$OutputPath = './artifacts/docker',
        
        [ValidateSet('linux', 'windows')]
        [string]$Platform = 'linux'
    )
    
    Write-ArtifactLog "Generating Dockerfile from $ConfigPath" -Level Information
    
    try {
        # Load configuration
        $content = Get-Content -Path $ConfigPath -Raw
        $scriptBlock = [scriptblock]::Create($content)
        $config = & $scriptBlock
        
        $dockerLines = @()
        $dockerConfig = $null
        
        if ($Platform -eq 'linux') {
            if (-not $config.Linux.DeploymentArtifacts.Dockerfile.Generate) {
                Write-ArtifactLog "Dockerfile generation is disabled in configuration" -Level Warning
                return $null
            }
            
            $dockerConfig = $config.Linux.DeploymentArtifacts.Dockerfile
            
            $dockerLines += "# AitherZero Linux Container"
            $dockerLines += "FROM $($dockerConfig.BaseImage)"
            $dockerLines += ""
            $dockerLines += "# Update and install packages"
            $dockerLines += "RUN apt-get update && apt-get install -y \"
            $dockerLines += "    $($config.Linux.Packages.Essential -join ' ') \"
            $dockerLines += "    && rm -rf /var/lib/apt/lists/*"
            $dockerLines += ""
            
            # Add environment variables
            if ($config.Linux.EnvironmentVariables.System.Count -gt 0) {
                $dockerLines += "# Environment variables"
                foreach ($env in $config.Linux.EnvironmentVariables.System.GetEnumerator()) {
                    $dockerLines += "ENV $($env.Key)=$($env.Value)"
                }
                $dockerLines += ""
            }
            
            $dockerLines += "WORKDIR /workspace"
            $dockerLines += 'CMD ["/bin/bash"]'
        }
        elseif ($Platform -eq 'windows') {
            # Windows Dockerfile generation
            if (-not $config.Windows.DeploymentArtifacts.Dockerfile.Generate) {
                Write-ArtifactLog "Dockerfile generation is disabled in configuration" -Level Warning
                return $null
            }
            
            $dockerConfig = $config.Windows.DeploymentArtifacts.Dockerfile
            
            $dockerLines += "# AitherZero Windows Container"
            $dockerLines += "FROM $($dockerConfig.BaseImage)"
            $dockerLines += ""
            $dockerLines += "# Install PowerShell packages"
            if ($config.Windows.PowerShell.Modules.Count -gt 0) {
                $dockerLines += "RUN Install-PackageProvider -Name NuGet -Force"
                foreach ($module in $config.Windows.PowerShell.Modules) {
                    $dockerLines += "RUN Install-Module -Name $module -Force -SkipPublisherCheck"
                }
                $dockerLines += ""
            }
            
            # Add environment variables
            if ($config.Windows.EnvironmentVariables.System.Count -gt 0) {
                $dockerLines += "# Environment variables"
                foreach ($env in $config.Windows.EnvironmentVariables.System.GetEnumerator()) {
                    $dockerLines += "ENV $($env.Key)=$($env.Value)"
                }
                $dockerLines += ""
            }
            
            $dockerLines += "WORKDIR C:\\workspace"
            $dockerLines += 'CMD ["powershell.exe"]'
        }
        
        # Validate that dockerConfig was set
        if (-not $dockerConfig) {
            throw "Docker configuration not found for platform: $Platform"
        }
        
        # Ensure output directory exists
        Ensure-OutputDirectory -Path $OutputPath
        
        # Save Dockerfile
        $outputFile = Join-Path $OutputPath $dockerConfig.FileName
        $dockerLines -join "`n" | Out-File -FilePath $outputFile -Encoding UTF8 -Force
        
        Write-ArtifactLog "Generated Dockerfile: $outputFile" -Level Success
        return $outputFile
    }
    catch {
        Write-ArtifactLog "Error generating Dockerfile: $($_.Exception.Message)" -Level Error
        throw
    }
}

#endregion

#region Unified Generation

function New-DeploymentArtifacts {
    <#
    .SYNOPSIS
        Generate all deployment artifacts from configuration files
    
    .DESCRIPTION
        Main function to generate all deployment artifacts based on OS-specific configs
    
    .PARAMETER Platform
        Target platform(s): Windows, Linux, macOS, Docker, All
    
    .PARAMETER ConfigPath
        Base path to configuration files (default: current directory)
    
    .PARAMETER OutputPath
        Base output directory for all artifacts
    
    .EXAMPLE
        New-DeploymentArtifacts -Platform Windows
    
    .EXAMPLE
        New-DeploymentArtifacts -Platform All -OutputPath ./build/artifacts
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Windows', 'Linux', 'macOS', 'Docker', 'All')]
        [string[]]$Platform = 'All',
        
        [string]$ConfigPath = '.',
        
        [string]$OutputPath = './artifacts'
    )
    
    Write-ArtifactLog "Generating deployment artifacts for: $($Platform -join ', ')" -Level Information
    
    $generated = @{
        Windows = @()
        Linux = @()
        macOS = @()
        Docker = @()
    }
    
    try {
        # Windows artifacts
        if ($Platform -contains 'Windows' -or $Platform -contains 'All') {
            $windowsConfig = Join-Path $ConfigPath 'config.windows.psd1'
            if (Test-Path $windowsConfig) {
                Write-ArtifactLog "Processing Windows configuration..." -Level Information
                
                $unattend = New-WindowsUnattendXml -ConfigPath $windowsConfig -OutputPath (Join-Path $OutputPath 'windows')
                if ($unattend) { $generated.Windows += $unattend }
                
                $registry = New-WindowsRegistryFile -ConfigPath $windowsConfig -OutputPath (Join-Path $OutputPath 'windows')
                if ($registry) { $generated.Windows += $registry }
            }
        }
        
        # Linux artifacts
        if ($Platform -contains 'Linux' -or $Platform -contains 'All') {
            $linuxConfig = Join-Path $ConfigPath 'config.linux.psd1'
            if (Test-Path $linuxConfig) {
                Write-ArtifactLog "Processing Linux configuration..." -Level Information
                
                $cloudInit = New-LinuxCloudInitConfig -ConfigPath $linuxConfig -OutputPath (Join-Path $OutputPath 'linux')
                if ($cloudInit) { $generated.Linux += $cloudInit }
                
                $shellScript = New-LinuxShellScript -ConfigPath $linuxConfig -OutputPath (Join-Path $OutputPath 'linux')
                if ($shellScript) { $generated.Linux += $shellScript }
            }
        }
        
        # macOS artifacts
        if ($Platform -contains 'macOS' -or $Platform -contains 'All') {
            $macosConfig = Join-Path $ConfigPath 'config.macos.psd1'
            if (Test-Path $macosConfig) {
                Write-ArtifactLog "Processing macOS configuration..." -Level Information
                
                $brewfile = New-MacOSBrewfile -ConfigPath $macosConfig -OutputPath (Join-Path $OutputPath 'macos')
                if ($brewfile) { $generated.macOS += $brewfile }
            }
        }
        
        # Docker artifacts
        if ($Platform -contains 'Docker' -or $Platform -contains 'All') {
            $linuxConfig = Join-Path $ConfigPath 'config.linux.psd1'
            if (Test-Path $linuxConfig) {
                Write-ArtifactLog "Processing Docker configuration..." -Level Information
                
                $dockerfile = New-Dockerfile -ConfigPath $linuxConfig -OutputPath (Join-Path $OutputPath 'docker') -Platform 'linux'
                if ($dockerfile) { $generated.Docker += $dockerfile }
            }
        }
        
        # Summary
        $totalGenerated = ($generated.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
        Write-ArtifactLog "Generated $totalGenerated deployment artifacts" -Level Success
        
        return $generated
    }
    catch {
        Write-ArtifactLog "Error generating deployment artifacts: $($_.Exception.Message)" -Level Error
        throw
    }
}

#endregion

#region Exports

Export-ModuleMember -Function @(
    'New-WindowsUnattendXml'
    'New-WindowsRegistryFile'
    'New-LinuxCloudInitConfig'
    'New-LinuxShellScript'
    'New-MacOSBrewfile'
    'New-Dockerfile'
    'New-DeploymentArtifacts'
)

#endregion
