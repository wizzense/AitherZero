function New-DeploymentReadyISO {
    <#
    .SYNOPSIS
        Creates a deployment-ready customized ISO in a single operation with intelligent defaults.

    .DESCRIPTION
        This function provides a simplified interface for creating deployment-ready ISOs by
        combining download, customization, and validation into a single streamlined operation.
        It uses intelligent defaults and templates to minimize configuration requirements while
        providing enterprise-grade results.

    .PARAMETER ISOTemplate
        Pre-defined template for common deployment scenarios:
        - 'WindowsServer2025-DC' - Domain Controller deployment
        - 'WindowsServer2025-Member' - Domain member server
        - 'Windows11-Enterprise' - Enterprise workstation
        - 'Ubuntu22.04-Server' - Ubuntu server deployment
        - 'Custom' - Custom configuration

    .PARAMETER ComputerName
        Name for the target computer (required)

    .PARAMETER AdminPassword
        Administrator password for the deployment
        Use SecureString for enhanced security

    .PARAMETER SourceISO
        Path to source ISO file or ISO name for download

    .PARAMETER OutputPath
        Path for the deployment-ready ISO output

    .PARAMETER Organization
        Organization name for Windows deployments

    .PARAMETER TimeZone
        Time zone for the deployment (defaults to UTC)

    .PARAMETER IPConfiguration
        Network configuration hashtable:
        @{
            IPAddress = '192.168.1.100'
            SubnetMask = '255.255.255.0'
            Gateway = '192.168.1.1'
            DNS1 = '192.168.1.10'
            DNS2 = '8.8.8.8'
        }

    .PARAMETER DomainConfiguration
        Domain configuration for domain operations:
        @{
            DomainName = 'contoso.local'
            DomainMode = '2016'
            ForestMode = '2016'
            SafeModePassword = 'P@ssw0rd!'
        }

    .PARAMETER BootstrapActions
        Array of post-installation actions to perform

    .PARAMETER DriversPath
        Array of paths containing device drivers to inject

    .PARAMETER SoftwarePackages
        Array of software packages to install post-deployment

    .PARAMETER SecurityConfig
        Security configuration hashtable with policies and settings

    .PARAMETER AdvancedOptions
        Advanced configuration options for expert users

    .PARAMETER ValidateOnly
        Validate configuration without creating ISO

    .PARAMETER Force
        Overwrite existing files without prompting

    .EXAMPLE
        # Simple Windows Server 2025 Domain Controller
        $dcConfig = @{
            DomainName = 'lab.local'
            DomainMode = '2016'
            ForestMode = '2016'
            SafeModePassword = 'SafeMode123!'
        }
        
        New-DeploymentReadyISO -ISOTemplate 'WindowsServer2025-DC' `
            -ComputerName 'DC-01' -AdminPassword 'P@ssw0rd123!' `
            -SourceISO 'WindowsServer2025' -OutputPath 'C:\ISOs\DC-01-Ready.iso' `
            -Organization 'Contoso Corp' -TimeZone 'Eastern Standard Time' `
            -DomainConfiguration $dcConfig

    .EXAMPLE
        # Enterprise Windows 11 workstation with static IP
        $networkConfig = @{
            IPAddress = '192.168.100.50'
            SubnetMask = '255.255.255.0'
            Gateway = '192.168.100.1'
            DNS1 = '192.168.100.10'
            DNS2 = '8.8.8.8'
        }
        
        $bootstrapActions = @(
            'Install-WindowsFeatures',
            'Configure-WindowsUpdate',
            'Install-EnterpriseApps',
            'Configure-Security'
        )
        
        New-DeploymentReadyISO -ISOTemplate 'Windows11-Enterprise' `
            -ComputerName 'WS-001' -AdminPassword (ConvertTo-SecureString 'P@ssw0rd!' -AsPlainText -Force) `
            -SourceISO 'D:\ISOs\Windows11-Enterprise.iso' -OutputPath 'D:\ISOs\WS-001-Ready.iso' `
            -IPConfiguration $networkConfig -BootstrapActions $bootstrapActions `
            -DriversPath @('D:\Drivers\Dell-Optiplex')

    .EXAMPLE
        # Ubuntu 22.04 server with custom configuration
        $ubuntuConfig = @{
            Packages = @('docker.io', 'nginx', 'postgresql')
            Users = @(
                @{Username = 'admin'; Groups = @('sudo', 'docker'); SSHKey = 'ssh-rsa AAA...'}
            )
            Services = @('docker', 'nginx')
        }
        
        New-DeploymentReadyISO -ISOTemplate 'Ubuntu22.04-Server' `
            -ComputerName 'web-01' -AdminPassword 'AdminPass123!' `
            -SourceISO 'ubuntu-22.04-server-amd64.iso' -OutputPath 'web-01-ready.iso' `
            -AdvancedOptions $ubuntuConfig

    .EXAMPLE
        # Validate configuration without creating ISO
        New-DeploymentReadyISO -ISOTemplate 'WindowsServer2025-Member' `
            -ComputerName 'FILE-01' -AdminPassword 'P@ssw0rd!' `
            -SourceISO 'WindowsServer2025' -OutputPath 'FILE-01.iso' `
            -ValidateOnly

    .OUTPUTS
        PSCustomObject with deployment ISO creation results including:
        - Success: Boolean indicating success/failure
        - OutputISO: Path to created deployment-ready ISO
        - Template: Template used for creation
        - Configuration: Applied configuration summary
        - ValidationResults: ISO validation results
        - Metadata: Comprehensive metadata about the created ISO
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('WindowsServer2025-DC', 'WindowsServer2025-Member', 'Windows11-Enterprise', 'Windows10-Pro', 'Ubuntu22.04-Server', 'Ubuntu20.04-Server', 'CentOS8-Server', 'Custom')]
        [string]$ISOTemplate,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $AdminPassword,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceISO,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [string]$Organization = 'AitherZero Deployment',

        [Parameter(Mandatory = $false)]
        [string]$TimeZone = 'UTC',

        [Parameter(Mandatory = $false)]
        [hashtable]$IPConfiguration = @{},

        [Parameter(Mandatory = $false)]
        [hashtable]$DomainConfiguration = @{},

        [Parameter(Mandatory = $false)]
        [string[]]$BootstrapActions = @(),

        [Parameter(Mandatory = $false)]
        [string[]]$DriversPath = @(),

        [Parameter(Mandatory = $false)]
        [hashtable[]]$SoftwarePackages = @(),

        [Parameter(Mandatory = $false)]
        [hashtable]$SecurityConfig = @{},

        [Parameter(Mandatory = $false)]
        [hashtable]$AdvancedOptions = @{},

        [Parameter(Mandatory = $false)]
        [switch]$ValidateOnly,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Creating deployment-ready ISO using template: $ISOTemplate"
        Write-CustomLog -Level 'INFO' -Message "Target computer: $ComputerName"
        
        # Initialize result object
        $result = [PSCustomObject]@{
            Success = $false
            Template = $ISOTemplate
            ComputerName = $ComputerName
            SourceISO = $SourceISO
            OutputISO = $OutputPath
            Configuration = @{}
            ValidationResults = $null
            Metadata = @{}
            Errors = @()
            StartTime = Get-Date
            EndTime = $null
            Duration = $null
        }

        # Handle SecureString password
        if ($AdminPassword -is [System.Security.SecureString]) {
            $adminPasswordText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdminPassword))
        } else {
            $adminPasswordText = $AdminPassword
        }
    }

    process {
        try {
            # Load template configuration
            Write-CustomLog -Level 'INFO' -Message "Loading template configuration: $ISOTemplate"
            $templateConfig = Get-ISOTemplateConfiguration -TemplateName $ISOTemplate
            
            if (-not $templateConfig) {
                throw "Template not found or invalid: $ISOTemplate"
            }

            # Build unified configuration
            $unifiedConfig = Build-DeploymentConfiguration -TemplateConfig $templateConfig `
                -ComputerName $ComputerName -AdminPassword $adminPasswordText `
                -Organization $Organization -TimeZone $TimeZone `
                -IPConfiguration $IPConfiguration -DomainConfiguration $DomainConfiguration `
                -BootstrapActions $BootstrapActions -SecurityConfig $SecurityConfig `
                -AdvancedOptions $AdvancedOptions

            $result.Configuration = $unifiedConfig

            # Validation mode
            if ($ValidateOnly) {
                Write-CustomLog -Level 'INFO' -Message "Validation mode - checking configuration"
                
                $validationResult = Test-DeploymentConfiguration -Configuration $unifiedConfig -SourceISO $SourceISO
                $result.ValidationResults = $validationResult
                
                if ($validationResult.IsValid) {
                    Write-CustomLog -Level 'SUCCESS' -Message "Configuration validation passed"
                    $result.Success = $true
                } else {
                    $result.Errors = $validationResult.Issues
                    Write-CustomLog -Level 'ERROR' -Message "Configuration validation failed: $($validationResult.Issues -join ', ')"
                }
                
                return $result
            }

            # Check if source ISO exists or needs download
            $sourceISOPath = Resolve-SourceISO -SourceISO $SourceISO -TemplateConfig $templateConfig
            
            if (-not $sourceISOPath) {
                throw "Unable to locate or download source ISO: $SourceISO"
            }

            Write-CustomLog -Level 'INFO' -Message "Using source ISO: $sourceISOPath"

            # Generate autounattend configuration based on template
            $autounattendConfig = Build-AutounattendConfiguration -UnifiedConfig $unifiedConfig -TemplateConfig $templateConfig

            # Generate bootstrap script if needed
            $bootstrapScript = $null
            if ($BootstrapActions.Count -gt 0 -or $unifiedConfig.PostInstallCommands.Count -gt 0) {
                $bootstrapScript = New-BootstrapScript -Configuration $unifiedConfig -TemplateConfig $templateConfig
            }

            # Prepare customization parameters
            $customizationParams = @{
                SourceISOPath = $sourceISOPath
                OutputISOPath = $OutputPath
                AutounattendConfig = $autounattendConfig
                Force = $Force.IsPresent
            }

            # Add optional parameters
            if ($bootstrapScript) {
                $customizationParams.BootstrapScript = $bootstrapScript
            }

            if ($DriversPath.Count -gt 0) {
                $customizationParams.DriversPath = $DriversPath
            }

            if ($unifiedConfig.AdditionalFiles.Count -gt 0) {
                $customizationParams.AdditionalFiles = $unifiedConfig.AdditionalFiles
            }

            if ($unifiedConfig.RegistryChanges.Count -gt 0) {
                $customizationParams.RegistryChanges = $unifiedConfig.RegistryChanges
            }

            # Execute ISO customization
            Write-CustomLog -Level 'INFO' -Message "Creating customized ISO"
            
            if ($WhatIfPreference) {
                Write-Host "Would create deployment-ready ISO with the following configuration:" -ForegroundColor Yellow
                Write-Host "Template: $ISOTemplate" -ForegroundColor White
                Write-Host "Computer Name: $ComputerName" -ForegroundColor White
                Write-Host "Source ISO: $sourceISOPath" -ForegroundColor White
                Write-Host "Output ISO: $OutputPath" -ForegroundColor White
                Write-Host "Organization: $Organization" -ForegroundColor White
                Write-Host "Time Zone: $TimeZone" -ForegroundColor White
                
                if ($IPConfiguration.Count -gt 0) {
                    Write-Host "Network Configuration:" -ForegroundColor Green
                    foreach ($key in $IPConfiguration.Keys) {
                        Write-Host "  $key`: $($IPConfiguration[$key])" -ForegroundColor Gray
                    }
                }
                
                if ($DomainConfiguration.Count -gt 0) {
                    Write-Host "Domain Configuration:" -ForegroundColor Green
                    foreach ($key in $DomainConfiguration.Keys) {
                        if ($key -like "*Password*") {
                            Write-Host "  $key`: [PROTECTED]" -ForegroundColor Gray
                        } else {
                            Write-Host "  $key`: $($DomainConfiguration[$key])" -ForegroundColor Gray
                        }
                    }
                }
                
                return $result
            }

            $customResult = New-CustomISO @customizationParams

            if ($customResult.Success) {
                Write-CustomLog -Level 'SUCCESS' -Message "Deployment-ready ISO created: $OutputPath"
                
                # Validate the created ISO
                Write-CustomLog -Level 'INFO' -Message "Validating deployment-ready ISO"
                $validationResult = Test-ISOIntegrity -ISOPath $OutputPath -ValidationLevel 'Standard' -CheckBootability
                
                $result.ValidationResults = $validationResult
                $result.Success = $validationResult.IsValid
                $result.OutputISO = $OutputPath

                # Generate metadata
                $metadata = @{
                    Template = $ISOTemplate
                    ComputerName = $ComputerName
                    Organization = $Organization
                    TimeZone = $TimeZone
                    CreatedBy = 'New-DeploymentReadyISO'
                    CreatedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    SourceISO = $sourceISOPath
                    CustomizationResult = $customResult
                    ValidationResult = $validationResult
                    Configuration = @{
                        HasNetworkConfig = ($IPConfiguration.Count -gt 0)
                        HasDomainConfig = ($DomainConfiguration.Count -gt 0)
                        HasBootstrapActions = ($BootstrapActions.Count -gt 0)
                        HasDrivers = ($DriversPath.Count -gt 0)
                        HasSecurityConfig = ($SecurityConfig.Count -gt 0)
                    }
                }

                $result.Metadata = $metadata

                if ($validationResult.IsValid) {
                    Write-CustomLog -Level 'SUCCESS' -Message "Deployment-ready ISO validation passed"
                } else {
                    Write-CustomLog -Level 'WARNING' -Message "Deployment-ready ISO validation issues: $($validationResult.Issues -join ', ')"
                    $result.Errors += $validationResult.Issues
                }
            } else {
                throw "ISO customization failed: $($customResult.Error)"
            }

        } catch {
            $result.Success = $false
            $result.Errors += $_.Exception.Message
            Write-CustomLog -Level 'ERROR' -Message "Failed to create deployment-ready ISO: $($_.Exception.Message)"
        } finally {
            $result.EndTime = Get-Date
            $result.Duration = $result.EndTime - $result.StartTime
            
            Write-CustomLog -Level 'INFO' -Message "Deployment-ready ISO creation completed in $($result.Duration)"
        }

        return $result
    }
}

# Helper function to get template configuration
function Get-ISOTemplateConfiguration {
    param([string]$TemplateName)
    
    $templates = @{
        'WindowsServer2025-DC' = @{
            OSType = 'Server2025'
            Edition = 'Datacenter'
            WIMIndex = 4
            DefaultFeatures = @('AD-Domain-Services', 'DNS', 'DHCP')
            RequiredRoles = @('DomainController')
            BootstrapTemplate = 'domain-controller-setup.ps1'
            AutounattendTemplate = 'autounattend-server-dc.xml'
        }
        
        'WindowsServer2025-Member' = @{
            OSType = 'Server2025'
            Edition = 'Standard'
            WIMIndex = 3
            DefaultFeatures = @()
            RequiredRoles = @('MemberServer')
            BootstrapTemplate = 'member-server-setup.ps1'
            AutounattendTemplate = 'autounattend-server-member.xml'
        }
        
        'Windows11-Enterprise' = @{
            OSType = 'Windows11'
            Edition = 'Enterprise'
            WIMIndex = 6
            DefaultFeatures = @()
            RequiredRoles = @('Workstation')
            BootstrapTemplate = 'workstation-setup.ps1'
            AutounattendTemplate = 'autounattend-win11-enterprise.xml'
        }
        
        'Windows10-Pro' = @{
            OSType = 'Windows10'
            Edition = 'Professional'
            WIMIndex = 5
            DefaultFeatures = @()
            RequiredRoles = @('Workstation')
            BootstrapTemplate = 'workstation-setup.ps1'
            AutounattendTemplate = 'autounattend-win10-pro.xml'
        }
        
        'Ubuntu22.04-Server' = @{
            OSType = 'Linux'
            Distribution = 'Ubuntu'
            Version = '22.04'
            DefaultPackages = @('openssh-server', 'curl', 'wget', 'vim')
            BootstrapTemplate = 'ubuntu-server-setup.sh'
            KickstartTemplate = 'ubuntu-22.04-server.cfg'
        }
        
        'Custom' = @{
            OSType = 'Custom'
            Edition = 'Custom'
            WIMIndex = 1
            DefaultFeatures = @()
            RequiredRoles = @()
            BootstrapTemplate = 'custom-setup.ps1'
            AutounattendTemplate = 'autounattend-generic.xml'
        }
    }
    
    return $templates[$TemplateName]
}

# Helper function to build deployment configuration
function Build-DeploymentConfiguration {
    param(
        $TemplateConfig,
        $ComputerName,
        $AdminPassword,
        $Organization,
        $TimeZone,
        $IPConfiguration,
        $DomainConfiguration,
        $BootstrapActions,
        $SecurityConfig,
        $AdvancedOptions
    )
    
    $config = @{
        # Basic settings
        ComputerName = $ComputerName
        AdminPassword = $AdminPassword
        Organization = $Organization
        TimeZone = $TimeZone
        
        # Template-based settings
        OSType = $TemplateConfig.OSType
        Edition = $TemplateConfig.Edition
        WIMIndex = $TemplateConfig.WIMIndex
        DefaultFeatures = $TemplateConfig.DefaultFeatures
        
        # Network configuration
        NetworkConfig = $IPConfiguration
        
        # Domain configuration
        DomainConfig = $DomainConfiguration
        
        # Post-installation commands
        PostInstallCommands = @()
        
        # Security configuration
        SecurityConfig = $SecurityConfig
        
        # Registry changes
        RegistryChanges = @{}
        
        # Additional files
        AdditionalFiles = @()
    }
    
    # Build post-installation commands from bootstrap actions
    foreach ($action in $BootstrapActions) {
        switch ($action) {
            'Install-WindowsFeatures' {
                if ($TemplateConfig.DefaultFeatures.Count -gt 0) {
                    $config.PostInstallCommands += @{
                        CommandLine = "powershell -Command `"Install-WindowsFeature -Name $($TemplateConfig.DefaultFeatures -join ',') -IncludeManagementTools`""
                        Description = 'Install default Windows features'
                    }
                }
            }
            'Configure-WindowsUpdate' {
                $config.PostInstallCommands += @{
                    CommandLine = 'powershell -ExecutionPolicy Bypass -File C:\Scripts\configure-updates.ps1'
                    Description = 'Configure Windows Update settings'
                }
            }
            'Install-EnterpriseApps' {
                $config.PostInstallCommands += @{
                    CommandLine = 'powershell -ExecutionPolicy Bypass -File C:\Scripts\install-apps.ps1'
                    Description = 'Install enterprise applications'
                }
            }
            'Configure-Security' {
                $config.PostInstallCommands += @{
                    CommandLine = 'powershell -ExecutionPolicy Bypass -File C:\Scripts\configure-security.ps1'
                    Description = 'Apply security configuration'
                }
            }
        }
    }
    
    # Merge advanced options
    foreach ($key in $AdvancedOptions.Keys) {
        $config[$key] = $AdvancedOptions[$key]
    }
    
    return $config
}

# Helper function to build autounattend configuration
function Build-AutounattendConfiguration {
    param($UnifiedConfig, $TemplateConfig)
    
    $autounattendConfig = @{
        ComputerName = $UnifiedConfig.ComputerName
        AdminPassword = $UnifiedConfig.AdminPassword
        Organization = $UnifiedConfig.Organization
        TimeZone = $UnifiedConfig.TimeZone
        FirstLogonCommands = $UnifiedConfig.PostInstallCommands
    }
    
    # Add network configuration if specified
    if ($UnifiedConfig.NetworkConfig.Count -gt 0) {
        $autounattendConfig.NetworkConfig = $UnifiedConfig.NetworkConfig
    }
    
    # Add domain configuration if specified
    if ($UnifiedConfig.DomainConfig.Count -gt 0) {
        $autounattendConfig.DomainConfig = $UnifiedConfig.DomainConfig
    }
    
    return $autounattendConfig
}

# Helper function to resolve source ISO
function Resolve-SourceISO {
    param($SourceISO, $TemplateConfig)
    
    # If it's a full path, verify it exists
    if (Test-Path $SourceISO) {
        return $SourceISO
    }
    
    # Try to find in default repository
    $repoPath = $script:ISOManagementConfig.DefaultRepositoryPath
    $possiblePaths = @(
        (Join-Path $repoPath "Windows\$SourceISO"),
        (Join-Path $repoPath "Linux\$SourceISO"),
        (Join-Path $repoPath "Custom\$SourceISO")
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $path
        }
        
        # Try with .iso extension
        $isoPath = $path -replace '\.iso$', '' + '.iso'
        if (Test-Path $isoPath) {
            return $isoPath
        }
    }
    
    # Try to download if it's a known ISO name
    try {
        Write-CustomLog -Level 'INFO' -Message "Attempting to download ISO: $SourceISO"
        
        $downloadResult = Get-ISODownload -ISOName $SourceISO -DownloadPath (Join-Path $repoPath "Downloads") -VerifyIntegrity
        
        if ($downloadResult.Status -eq 'Completed') {
            return $downloadResult.FilePath
        }
    } catch {
        Write-CustomLog -Level 'WARNING' -Message "Failed to download ISO: $($_.Exception.Message)"
    }
    
    return $null
}

# Helper function to create bootstrap script
function New-BootstrapScript {
    param($Configuration, $TemplateConfig)
    
    $tempPath = Join-Path $env:TEMP "bootstrap-$([System.Guid]::NewGuid().ToString().Substring(0,8)).ps1"
    
    $scriptContent = @"
# Bootstrap script generated by New-DeploymentReadyISO
# Computer: $($Configuration.ComputerName)
# Template: $($TemplateConfig.OSType)
# Generated: $(Get-Date)

Write-Host "Starting bootstrap configuration for $($Configuration.ComputerName)"

try {
    # Execute post-installation commands
"@
    
    foreach ($command in $Configuration.PostInstallCommands) {
        $scriptContent += @"

    # $($command.Description)
    Write-Host "Executing: $($command.Description)"
    $($command.CommandLine)
"@
    }
    
    $scriptContent += @"

    Write-Host "Bootstrap configuration completed successfully"
} catch {
    Write-Error "Bootstrap configuration failed: `$_"
    exit 1
}
"@
    
    Set-Content -Path $tempPath -Value $scriptContent -Encoding UTF8
    return $tempPath
}

# Helper function to test deployment configuration
function Test-DeploymentConfiguration {
    param($Configuration, $SourceISO)
    
    $issues = @()
    $isValid = $true
    
    # Validate computer name
    if ($Configuration.ComputerName -notmatch '^[a-zA-Z0-9-]{1,15}$') {
        $issues += "Invalid computer name format"
        $isValid = $false
    }
    
    # Validate admin password
    if ($Configuration.AdminPassword.Length -lt 8) {
        $issues += "Admin password must be at least 8 characters"
        $isValid = $false
    }
    
    # Validate time zone
    try {
        [System.TimeZoneInfo]::FindSystemTimeZoneById($Configuration.TimeZone)
    } catch {
        $issues += "Invalid time zone: $($Configuration.TimeZone)"
        $isValid = $false
    }
    
    # Validate network configuration
    if ($Configuration.NetworkConfig.IPAddress) {
        try {
            [System.Net.IPAddress]::Parse($Configuration.NetworkConfig.IPAddress)
        } catch {
            $issues += "Invalid IP address format"
            $isValid = $false
        }
    }
    
    # Validate domain configuration
    if ($Configuration.DomainConfig.DomainName) {
        if ($Configuration.DomainConfig.DomainName -notmatch '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
            $issues += "Invalid domain name format"
            $isValid = $false
        }
    }
    
    return @{
        IsValid = $isValid
        Issues = $issues
    }
}