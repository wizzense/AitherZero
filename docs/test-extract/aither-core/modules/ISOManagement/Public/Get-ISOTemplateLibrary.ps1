function Get-ISOTemplateLibrary {
    <#
    .SYNOPSIS
        Retrieves and manages the ISO template library for deployment automation.

    .DESCRIPTION
        This function provides access to the comprehensive template library used by the
        ISOManagement module for creating deployment-ready ISOs. It includes built-in
        templates for common deployment scenarios and supports custom template management.

    .PARAMETER TemplateName
        Specific template name to retrieve (supports wildcards)

    .PARAMETER TemplateType
        Filter templates by type:
        - 'Windows' - Windows OS templates
        - 'Linux' - Linux distribution templates
        - 'Custom' - User-defined custom templates
        - 'All' - All templates (default)

    .PARAMETER IncludeDetails
        Include detailed template configuration and requirements

    .PARAMETER IncludeExamples
        Include usage examples for each template

    .PARAMETER OutputFormat
        Output format for the results:
        - 'Object' - PowerShell objects (default)
        - 'Table' - Formatted table display
        - 'List' - Detailed list format
        - 'Json' - JSON format

    .PARAMETER ShowCustomTemplatesPath
        Display the path where custom templates should be placed

    .EXAMPLE
        # Get all available templates
        Get-ISOTemplateLibrary

    .EXAMPLE
        # Get Windows templates with details
        Get-ISOTemplateLibrary -TemplateType 'Windows' -IncludeDetails

    .EXAMPLE
        # Get specific template with examples
        Get-ISOTemplateLibrary -TemplateName 'WindowsServer2025-DC' -IncludeDetails -IncludeExamples

    .EXAMPLE
        # Display templates in table format
        Get-ISOTemplateLibrary -OutputFormat 'Table'

    .EXAMPLE
        # Show custom templates location
        Get-ISOTemplateLibrary -ShowCustomTemplatesPath

    .OUTPUTS
        Array of template objects or formatted output based on parameters
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$TemplateName,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Windows', 'Linux', 'Custom', 'All')]
        [string]$TemplateType = 'All',

        [Parameter(Mandatory = $false)]
        [switch]$IncludeDetails,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeExamples,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Object', 'Table', 'List', 'Json')]
        [string]$OutputFormat = 'Object',

        [Parameter(Mandatory = $false)]
        [switch]$ShowCustomTemplatesPath
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Retrieving ISO template library"
        
        # Show custom templates path if requested
        if ($ShowCustomTemplatesPath) {
            $customPath = Join-Path $script:ISOManagementConfig.DefaultRepositoryPath "Templates"
            Write-Host ""
            Write-Host "=== Custom Templates Location ===" -ForegroundColor Green
            Write-Host "Place custom template files in: $customPath" -ForegroundColor White
            Write-Host ""
            Write-Host "Supported custom template types:" -ForegroundColor Yellow
            Write-Host "  • Autounattend XML files: *.xml" -ForegroundColor Gray
            Write-Host "  • Bootstrap scripts: *.ps1, *.sh, *.py" -ForegroundColor Gray
            Write-Host "  • Kickstart configurations: *.cfg, *.ks" -ForegroundColor Gray
            Write-Host "  • Cloud-init configurations: *.yaml, *.yml" -ForegroundColor Gray
            Write-Host ""
            return
        }
    }

    process {
        # Define built-in template library
        $templateLibrary = @{
            # Windows Server Templates
            'WindowsServer2025-DC' = [PSCustomObject]@{
                Name = 'WindowsServer2025-DC'
                DisplayName = 'Windows Server 2025 Domain Controller'
                Type = 'Windows'
                OSType = 'Server2025'
                Edition = 'Datacenter'
                WIMIndex = 4
                Description = 'Windows Server 2025 Datacenter configured as Active Directory Domain Controller'
                Features = @('AD-Domain-Services', 'DNS', 'DHCP', 'RSAT-ADDS', 'RSAT-DNS-Server')
                Requirements = @{
                    RAM = '4GB minimum, 8GB recommended'
                    Disk = '60GB minimum'
                    Network = 'Static IP configuration recommended'
                }
                ConfigurationOptions = @(
                    'DomainName (required)',
                    'DomainMode (optional, default: 2016)',
                    'ForestMode (optional, default: 2016)',
                    'SafeModePassword (required)',
                    'DNSForwarders (optional)'
                )
                UseCase = 'Enterprise domain infrastructure, lab environments, development domains'
                AutounattendTemplate = 'autounattend-server-dc.xml'
                BootstrapTemplate = 'domain-controller-setup.ps1'
                ValidationRequirements = @('Domain configuration must be provided', 'Safe mode password required')
            }
            
            'WindowsServer2025-Member' = [PSCustomObject]@{
                Name = 'WindowsServer2025-Member'
                DisplayName = 'Windows Server 2025 Member Server'
                Type = 'Windows'
                OSType = 'Server2025'
                Edition = 'Standard'
                WIMIndex = 3
                Description = 'Windows Server 2025 Standard configured as domain member server'
                Features = @('RSAT-AD-Tools', 'Telnet-Client')
                Requirements = @{
                    RAM = '2GB minimum, 4GB recommended'
                    Disk = '40GB minimum'
                    Network = 'Domain connectivity required'
                }
                ConfigurationOptions = @(
                    'DomainName (required for domain join)',
                    'DomainCredentials (required for domain join)',
                    'ServerRoles (optional)',
                    'ServerFeatures (optional)'
                )
                UseCase = 'File servers, print servers, application servers, database servers'
                AutounattendTemplate = 'autounattend-server-member.xml'
                BootstrapTemplate = 'member-server-setup.ps1'
                ValidationRequirements = @('Domain join credentials required if joining domain')
            }
            
            'WindowsServer2025-Core' = [PSCustomObject]@{
                Name = 'WindowsServer2025-Core'
                DisplayName = 'Windows Server 2025 Server Core'
                Type = 'Windows'
                OSType = 'Server2025'
                Edition = 'Standard'
                WIMIndex = 2
                Description = 'Windows Server 2025 Server Core for minimal footprint deployments'
                Features = @('PowerShell', 'ServerCore-WOW64')
                Requirements = @{
                    RAM = '1GB minimum, 2GB recommended'
                    Disk = '20GB minimum'
                    Network = 'Remote management required'
                }
                ConfigurationOptions = @(
                    'EnableRemoteManagement (default: true)',
                    'ConfigureWinRM (default: true)',
                    'ServerRoles (limited selection)',
                    'FirewallRules (custom rules)'
                )
                UseCase = 'Container hosts, Hyper-V hosts, minimal infrastructure services'
                AutounattendTemplate = 'autounattend-server-core.xml'
                BootstrapTemplate = 'server-core-setup.ps1'
                ValidationRequirements = @('Remote management configuration required')
            }
            
            # Windows Client Templates
            'Windows11-Enterprise' = [PSCustomObject]@{
                Name = 'Windows11-Enterprise'
                DisplayName = 'Windows 11 Enterprise'
                Type = 'Windows'
                OSType = 'Windows11'
                Edition = 'Enterprise'
                WIMIndex = 6
                Description = 'Windows 11 Enterprise for business environments'
                Features = @('Microsoft-Hyper-V-All', 'Containers-DisposableClientVM')
                Requirements = @{
                    RAM = '4GB minimum, 8GB recommended'
                    Disk = '64GB minimum'
                    TPM = 'TPM 2.0 required'
                    SecureBoot = 'UEFI with Secure Boot'
                }
                ConfigurationOptions = @(
                    'DomainJoin (optional)',
                    'BitLockerEncryption (optional)',
                    'WindowsHello (optional)',
                    'EnterpriseApps (optional package list)'
                )
                UseCase = 'Business workstations, developer machines, enterprise deployments'
                AutounattendTemplate = 'autounattend-win11-enterprise.xml'
                BootstrapTemplate = 'workstation-setup.ps1'
                ValidationRequirements = @('UEFI and TPM 2.0 validation', 'Hardware compatibility check')
            }
            
            'Windows10-Pro' = [PSCustomObject]@{
                Name = 'Windows10-Pro'
                DisplayName = 'Windows 10 Professional'
                Type = 'Windows'
                OSType = 'Windows10'
                Edition = 'Professional'
                WIMIndex = 5
                Description = 'Windows 10 Professional for business and power users'
                Features = @('Microsoft-Hyper-V-All', 'Microsoft-Windows-Subsystem-Linux')
                Requirements = @{
                    RAM = '4GB minimum, 8GB recommended'
                    Disk = '64GB minimum'
                    TPM = 'TPM 1.2 or higher recommended'
                }
                ConfigurationOptions = @(
                    'DomainJoin (optional)',
                    'BitLockerEncryption (optional)',
                    'WSL (Windows Subsystem for Linux)',
                    'DeveloperMode (optional)'
                )
                UseCase = 'Business workstations, developer machines, small business deployments'
                AutounattendTemplate = 'autounattend-win10-pro.xml'
                BootstrapTemplate = 'workstation-setup.ps1'
                ValidationRequirements = @('Hardware compatibility check')
            }
            
            # Linux Templates
            'Ubuntu22.04-Server' = [PSCustomObject]@{
                Name = 'Ubuntu22.04-Server'
                DisplayName = 'Ubuntu 22.04 LTS Server'
                Type = 'Linux'
                OSType = 'Linux'
                Distribution = 'Ubuntu'
                Version = '22.04'
                Description = 'Ubuntu 22.04 LTS Server for enterprise deployments'
                Features = @('OpenSSH Server', 'Docker Engine', 'Snap Package Manager')
                Requirements = @{
                    RAM = '2GB minimum, 4GB recommended'
                    Disk = '25GB minimum'
                    Network = 'Internet connectivity for package updates'
                }
                ConfigurationOptions = @(
                    'UserAccounts (required)',
                    'SSHKeys (recommended)',
                    'PackageSelection (optional)',
                    'NetworkConfiguration (optional)',
                    'StorageLayout (optional)'
                )
                UseCase = 'Web servers, container hosts, development environments, cloud instances'
                KickstartTemplate = 'ubuntu-22.04-server.cfg'
                BootstrapTemplate = 'ubuntu-server-setup.sh'
                ValidationRequirements = @('User account configuration required', 'SSH key validation')
            }
            
            'Ubuntu20.04-Desktop' = [PSCustomObject]@{
                Name = 'Ubuntu20.04-Desktop'
                DisplayName = 'Ubuntu 20.04 LTS Desktop'
                Type = 'Linux'
                OSType = 'Linux'
                Distribution = 'Ubuntu'
                Version = '20.04'
                Description = 'Ubuntu 20.04 LTS Desktop with GNOME environment'
                Features = @('GNOME Desktop', 'Firefox Browser', 'LibreOffice Suite', 'Snap Package Manager')
                Requirements = @{
                    RAM = '4GB minimum, 8GB recommended'
                    Disk = '25GB minimum'
                    Graphics = 'Compatible graphics card for desktop environment'
                }
                ConfigurationOptions = @(
                    'UserAccounts (required)',
                    'DesktopEnvironment (GNOME, KDE, XFCE)',
                    'SoftwareSelection (optional)',
                    'AutoLogin (optional)'
                )
                UseCase = 'Developer workstations, educational environments, Linux desktop deployment'
                KickstartTemplate = 'ubuntu-20.04-desktop.cfg'
                BootstrapTemplate = 'ubuntu-desktop-setup.sh'
                ValidationRequirements = @('Desktop environment compatibility', 'Graphics driver validation')
            }
            
            'CentOS8-Server' = [PSCustomObject]@{
                Name = 'CentOS8-Server'
                DisplayName = 'CentOS 8 Server'
                Type = 'Linux'
                OSType = 'Linux'
                Distribution = 'CentOS'
                Version = '8'
                Description = 'CentOS 8 Server for enterprise RHEL-compatible deployments'
                Features = @('SELinux', 'Firewalld', 'DNF Package Manager', 'SystemD')
                Requirements = @{
                    RAM = '2GB minimum, 4GB recommended'
                    Disk = '20GB minimum'
                    Network = 'Internet connectivity for package repositories'
                }
                ConfigurationOptions = @(
                    'UserAccounts (required)',
                    'SELinuxPolicy (enforcing, permissive, disabled)',
                    'FirewallConfiguration (optional)',
                    'PackageGroups (optional)',
                    'NetworkTeaming (optional)'
                )
                UseCase = 'Enterprise servers, RHEL migration targets, web application servers'
                KickstartTemplate = 'centos-8-server.ks'
                BootstrapTemplate = 'centos-server-setup.sh'
                ValidationRequirements = @('SELinux policy validation', 'Package repository accessibility')
            }
        }
        
        # Load custom templates from repository
        $customTemplatesPath = Join-Path $script:ISOManagementConfig.DefaultRepositoryPath "Templates"
        if (Test-Path $customTemplatesPath) {
            $customTemplates = Get-ChildItem -Path $customTemplatesPath -Filter "*.json" | ForEach-Object {
                try {
                    $customTemplate = Get-Content $_.FullName | ConvertFrom-Json
                    $customTemplate.Name = $_.BaseName
                    $customTemplate.Type = 'Custom'
                    $customTemplate
                } catch {
                    Write-CustomLog -Level 'WARNING' -Message "Failed to load custom template: $($_.Name)"
                    $null
                }
            } | Where-Object { $_ -ne $null }
            
            # Add custom templates to library
            foreach ($template in $customTemplates) {
                $templateLibrary[$template.Name] = $template
            }
        }
        
        # Filter templates
        $filteredTemplates = $templateLibrary.Values
        
        # Filter by name
        if ($TemplateName) {
            $filteredTemplates = $filteredTemplates | Where-Object { $_.Name -like "*$TemplateName*" }
        }
        
        # Filter by type
        if ($TemplateType -ne 'All') {
            $filteredTemplates = $filteredTemplates | Where-Object { $_.Type -eq $TemplateType }
        }
        
        # Sort templates
        $filteredTemplates = $filteredTemplates | Sort-Object Type, Name
        
        # Add examples if requested
        if ($IncludeExamples) {
            foreach ($template in $filteredTemplates) {
                $examples = Get-TemplateUsageExamples -Template $template
                $template | Add-Member -NotePropertyName 'Examples' -NotePropertyValue $examples -Force
            }
        }
        
        # Format output
        switch ($OutputFormat) {
            'Object' {
                if ($IncludeDetails) {
                    return $filteredTemplates
                } else {
                    return $filteredTemplates | Select-Object Name, DisplayName, Type, OSType, Description
                }
            }
            
            'Table' {
                if ($filteredTemplates.Count -eq 0) {
                    Write-Host "No templates found matching the specified criteria." -ForegroundColor Yellow
                    return
                }
                
                Write-Host ""
                Write-Host "=== ISO Template Library ===" -ForegroundColor Green
                Write-Host "Available Templates: $($filteredTemplates.Count)" -ForegroundColor White
                Write-Host ""
                
                # Group by type for better display
                $groupedTemplates = $filteredTemplates | Group-Object Type
                
                foreach ($group in $groupedTemplates) {
                    Write-Host "$($group.Name) Templates:" -ForegroundColor Yellow
                    
                    $tableData = $group.Group | Select-Object @{
                        Name = 'Template Name'
                        Expression = { $_.Name }
                    }, @{
                        Name = 'Display Name'
                        Expression = { 
                            if ($_.DisplayName.Length -gt 35) { 
                                $_.DisplayName.Substring(0, 32) + "..." 
                            } else { 
                                $_.DisplayName 
                            }
                        }
                    }, @{
                        Name = 'OS/Version'
                        Expression = { 
                            if ($_.OSType) { $_.OSType }
                            elseif ($_.Distribution -and $_.Version) { "$($_.Distribution) $($_.Version)" }
                            else { $_.Type }
                        }
                    }, @{
                        Name = 'Use Case'
                        Expression = { 
                            if ($_.UseCase -and $_.UseCase.Length -gt 30) { 
                                $_.UseCase.Substring(0, 27) + "..." 
                            } else { 
                                $_.UseCase 
                            }
                        }
                    }
                    
                    $tableData | Format-Table -AutoSize
                    Write-Host ""
                }
                
                return
            }
            
            'List' {
                if ($filteredTemplates.Count -eq 0) {
                    Write-Host "No templates found matching the specified criteria." -ForegroundColor Yellow
                    return
                }
                
                Write-Host ""
                Write-Host "=== ISO Template Library (Detailed) ===" -ForegroundColor Green
                Write-Host ""
                
                foreach ($template in $filteredTemplates) {
                    Write-Host "Template: $($template.Name)" -ForegroundColor Yellow
                    Write-Host "  Display Name: $($template.DisplayName)" -ForegroundColor White
                    Write-Host "  Type: $($template.Type)" -ForegroundColor Gray
                    
                    if ($template.OSType) {
                        Write-Host "  OS Type: $($template.OSType)" -ForegroundColor Gray
                    }
                    
                    if ($template.Edition) {
                        Write-Host "  Edition: $($template.Edition)" -ForegroundColor Gray
                    }
                    
                    if ($template.Distribution -and $template.Version) {
                        Write-Host "  Distribution: $($template.Distribution) $($template.Version)" -ForegroundColor Gray
                    }
                    
                    Write-Host "  Description: $($template.Description)" -ForegroundColor White
                    
                    if ($template.Features -and $template.Features.Count -gt 0) {
                        Write-Host "  Key Features: $($template.Features -join ', ')" -ForegroundColor Cyan
                    }
                    
                    if ($template.UseCase) {
                        Write-Host "  Use Case: $($template.UseCase)" -ForegroundColor Green
                    }
                    
                    if ($IncludeDetails) {
                        if ($template.Requirements) {
                            Write-Host "  Requirements:" -ForegroundColor Magenta
                            foreach ($req in $template.Requirements.GetEnumerator()) {
                                Write-Host "    $($req.Key): $($req.Value)" -ForegroundColor Gray
                            }
                        }
                        
                        if ($template.ConfigurationOptions -and $template.ConfigurationOptions.Count -gt 0) {
                            Write-Host "  Configuration Options:" -ForegroundColor Magenta
                            foreach ($option in $template.ConfigurationOptions) {
                                Write-Host "    • $option" -ForegroundColor Gray
                            }
                        }
                    }
                    
                    Write-Host ""
                }
                
                return
            }
            
            'Json' {
                if ($IncludeDetails) {
                    return $filteredTemplates | ConvertTo-Json -Depth 10
                } else {
                    $simpleTemplates = $filteredTemplates | Select-Object Name, DisplayName, Type, OSType, Description
                    return $simpleTemplates | ConvertTo-Json -Depth 5
                }
            }
        }
    }
}

# Helper function to get usage examples for templates
function Get-TemplateUsageExamples {
    param($Template)
    
    $examples = @()
    
    switch ($Template.Name) {
        'WindowsServer2025-DC' {
            $examples += @{
                Title = 'Basic Domain Controller'
                Description = 'Create a simple domain controller for lab environment'
                Code = @'
$dcConfig = @{
    DomainName = 'lab.local'
    DomainMode = '2016'
    ForestMode = '2016'
    SafeModePassword = 'SafeMode123!'
}

New-DeploymentReadyISO -ISOTemplate 'WindowsServer2025-DC' `
    -ComputerName 'DC-01' -AdminPassword 'P@ssw0rd123!' `
    -SourceISO 'WindowsServer2025' -OutputPath 'DC-01-Ready.iso' `
    -DomainConfiguration $dcConfig
'@
            }
        }
        
        'Windows11-Enterprise' {
            $examples += @{
                Title = 'Enterprise Workstation'
                Description = 'Deploy Windows 11 Enterprise with domain join and applications'
                Code = @'
$networkConfig = @{
    IPAddress = '192.168.100.50'
    SubnetMask = '255.255.255.0'
    Gateway = '192.168.100.1'
    DNS1 = '192.168.100.10'
}

$domainConfig = @{
    DomainName = 'contoso.local'
    DomainUser = 'admin@contoso.local'
    DomainPassword = 'DomainPass123!'
}

New-DeploymentReadyISO -ISOTemplate 'Windows11-Enterprise' `
    -ComputerName 'WS-001' -AdminPassword 'P@ssw0rd!' `
    -SourceISO 'Windows11-Enterprise.iso' -OutputPath 'WS-001-Ready.iso' `
    -IPConfiguration $networkConfig -DomainConfiguration $domainConfig
'@
            }
        }
        
        'Ubuntu22.04-Server' {
            $examples += @{
                Title = 'Web Server Deployment'
                Description = 'Deploy Ubuntu server with web server packages'
                Code = @'
$serverConfig = @{
    Packages = @('nginx', 'mysql-server', 'php-fpm')
    Users = @(
        @{Username = 'webadmin'; Groups = @('sudo'); SSHKey = 'ssh-rsa AAA...'}
    )
    Services = @('nginx', 'mysql')
}

New-DeploymentReadyISO -ISOTemplate 'Ubuntu22.04-Server' `
    -ComputerName 'web-01' -AdminPassword 'AdminPass123!' `
    -SourceISO 'ubuntu-22.04-server-amd64.iso' -OutputPath 'web-01-ready.iso' `
    -AdvancedOptions $serverConfig
'@
            }
        }
    }
    
    return $examples
}