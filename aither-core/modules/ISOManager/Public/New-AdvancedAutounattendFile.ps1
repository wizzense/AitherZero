function New-AdvancedAutounattendFile {
    <#
    .SYNOPSIS
        Creates advanced autounattend files with modern Windows features and enterprise configurations.

    .DESCRIPTION
        Generates comprehensive autounattend.xml files with support for:
        - Windows Subsystem for Linux (WSL)
        - Container features
        - Modern security settings
        - Enterprise domain integration
        - Cloud platform optimization
        - Modern Windows features (Windows Hello, Microsoft Store, etc.)

    .PARAMETER Configuration
        Hashtable containing advanced configuration options

    .PARAMETER OutputPath
        Path where the autounattend.xml file will be created

    .PARAMETER OSType
        Target operating system type

    .PARAMETER Edition
        OS edition type

    .PARAMETER Profile
        Deployment profile (Enterprise, Cloud, Developer, Security)

    .PARAMETER IncludeWSL
        Include Windows Subsystem for Linux configuration

    .PARAMETER IncludeContainers
        Include container platform support

    .PARAMETER SecurityProfile
        Security hardening profile (CIS, STIG, Custom)

    .PARAMETER CloudOptimization
        Cloud platform optimization (Azure, AWS, None)

    .PARAMETER Force
        Overwrite existing files

    .EXAMPLE
        $config = @{
            ComputerName = "DEV-WORKSTATION-01"
            AdminPassword = "placeholder"
            Domain = @{
                JoinDomain = $true
                DomainName = "corp.contoso.com"
                DomainUser = "Administrator"
                DomainPassword = "placeholder"
            }
            Features = @{
                EnableWSL = $true
                EnableContainers = $true
                EnableHyperV = $true
            }
            Security = @{
                EnableBitLocker = $true
                ConfigureWindowsDefender = $true
                EnableFirewall = $true
                RequireSecureBoot = $true
            }
        }

        New-AdvancedAutounattendFile -Configuration $config `
                                   -OutputPath "./enterprise-autounattend.xml" `
                                   -OSType "Windows11" `
                                   -Edition "Enterprise" `
                                   -Profile "Enterprise" `
                                   -IncludeWSL `
                                   -IncludeContainers `
                                   -SecurityProfile "CIS"

    .OUTPUTS
        PSCustomObject with operation results
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Server2025', 'Server2022', 'Server2019', 'Windows11', 'Windows10')]
        [string]$OSType = 'Windows11',

        [Parameter(Mandatory = $false)]
        [ValidateSet('Standard', 'Datacenter', 'Core', 'Pro', 'Enterprise', 'Education')]
        [string]$Edition = 'Pro',

        [Parameter(Mandatory = $false)]
        [ValidateSet('Enterprise', 'Cloud', 'Developer', 'Security', 'Gaming')]
        [string]$Profile = 'Enterprise',

        [Parameter(Mandatory = $false)]
        [switch]$IncludeWSL,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeContainers,

        [Parameter(Mandatory = $false)]
        [ValidateSet('None', 'CIS', 'STIG', 'Custom')]
        [string]$SecurityProfile = 'None',

        [Parameter(Mandatory = $false)]
        [ValidateSet('None', 'Azure', 'AWS', 'Hybrid')]
        [string]$CloudOptimization = 'None',

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Generating advanced autounattend file for: $OSType $Edition ($Profile profile)"

        # Validate configuration structure
        if (-not $Configuration.ContainsKey('ComputerName')) {
            $Configuration.ComputerName = "WIN-ADV-$(Get-Random -Minimum 100 -Maximum 999)"
        }

        if (-not $Configuration.ContainsKey('AdminPassword')) {
            throw "AdminPassword is required in Configuration"
        }

        # Check if output directory exists
        $outputDir = Split-Path $OutputPath -Parent
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        # Check if file already exists
        if ((Test-Path $OutputPath) -and -not $Force) {
            throw "Advanced autounattend file already exists: $OutputPath. Use -Force to overwrite."
        }
    }

    process {
        try {
            if ($PSCmdlet.ShouldProcess($OutputPath, "Generate Advanced Autounattend File")) {

                Write-CustomLog -Level 'INFO' -Message "Creating advanced autounattend XML content with profile: $Profile"

                # Start with base configuration
                $baseConfig = @{
                    ComputerName = $Configuration.ComputerName
                    AdminPassword = $Configuration.AdminPassword
                    InputLocale = $Configuration.InputLocale ?? 'en-US'
                    SystemLocale = $Configuration.SystemLocale ?? 'en-US'
                    UILanguage = $Configuration.UILanguage ?? 'en-US'
                    UserLocale = $Configuration.UserLocale ?? 'en-US'
                    AcceptEula = $true
                    ProductKey = $Configuration.ProductKey ?? 'Insert License Key Here'
                    FullName = $Configuration.FullName ?? 'Enterprise User'
                    Organization = $Configuration.Organization ?? 'Enterprise Organization'
                    TimeZone = $Configuration.TimeZone ?? 'UTC'
                    EnableRDP = $Configuration.EnableRDP ?? $true
                    FirstLogonCommands = @()
                }

                # Generate OS image name
                $imageName = Get-OSImageName -OSType $OSType -Edition $Edition

                # Build XML content with modern structure
                $xmlContent = Build-AdvancedXMLStructure -Configuration $baseConfig -OSType $OSType -Edition $Edition -ImageName $imageName

                # Add profile-specific configurations
                $xmlContent = Add-ProfileSpecificConfig -XMLContent $xmlContent -Profile $Profile -Configuration $Configuration

                # Add modern Windows features
                if ($IncludeWSL -or $Configuration.Features.EnableWSL) {
                    $xmlContent = Add-WSLConfiguration -XMLContent $xmlContent
                }

                if ($IncludeContainers -or $Configuration.Features.EnableContainers) {
                    $xmlContent = Add-ContainerConfiguration -XMLContent $xmlContent
                }

                # Add security hardening
                if ($SecurityProfile -ne 'None') {
                    $xmlContent = Add-SecurityHardening -XMLContent $xmlContent -SecurityProfile $SecurityProfile -Configuration $Configuration
                }

                # Add cloud optimization
                if ($CloudOptimization -ne 'None') {
                    $xmlContent = Add-CloudOptimization -XMLContent $xmlContent -CloudPlatform $CloudOptimization
                }

                # Add domain configuration if specified
                if ($Configuration.Domain -and $Configuration.Domain.JoinDomain) {
                    $xmlContent = Add-DomainConfiguration -XMLContent $xmlContent -DomainConfig $Configuration.Domain
                }

                # Write the XML content to file
                Write-CustomLog -Level 'INFO' -Message "Writing advanced autounattend file to: $OutputPath"
                Set-Content -Path $OutputPath -Value $xmlContent -Encoding UTF8

                # Validate the generated XML
                try {
                    [xml]$xmlTest = Get-Content $OutputPath -Raw
                    Write-CustomLog -Level 'SUCCESS' -Message "Advanced autounattend XML validation successful"
                } catch {
                    Write-CustomLog -Level 'ERROR' -Message "Generated XML is invalid: $($_.Exception.Message)"
                    throw "Generated advanced autounattend XML is invalid"
                }

                Write-CustomLog -Level 'SUCCESS' -Message "Advanced autounattend file generated successfully: $OutputPath"

                return @{
                    Success = $true
                    FilePath = $OutputPath
                    OSType = $OSType
                    Edition = $Edition
                    Profile = $Profile
                    ImageName = $imageName
                    Configuration = $Configuration
                    Features = @{
                        WSL = $IncludeWSL -or $Configuration.Features.EnableWSL
                        Containers = $IncludeContainers -or $Configuration.Features.EnableContainers
                        SecurityProfile = $SecurityProfile
                        CloudOptimization = $CloudOptimization
                    }
                    FileSize = (Get-Item $OutputPath).Length
                    CreationTime = Get-Date
                    Message = "Advanced autounattend file generated successfully"
                }
            }
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to generate advanced autounattend file: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Completed New-AdvancedAutounattendFile operation"
    }
}

function Build-AdvancedXMLStructure {
    param(
        [hashtable]$Configuration,
        [string]$OSType,
        [string]$Edition,
        [string]$ImageName
    )

    return @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>$($Configuration.InputLocale)</InputLocale>
            <SystemLocale>$($Configuration.SystemLocale)</SystemLocale>
            <UILanguage>$($Configuration.UILanguage)</UILanguage>
            <UserLocale>$($Configuration.UserLocale)</UserLocale>
        </component>
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <UserData>
                <AcceptEula>true</AcceptEula>
                <ProductKey>
                    <WillShowUI>Never</WillShowUI>
                    <Key>$($Configuration.ProductKey)</Key>
                </ProductKey>
                <FullName>$($Configuration.FullName)</FullName>
                <Organization>$($Configuration.Organization)</Organization>
            </UserData>
            <ImageInstall>
                <OSImage>
                    <InstallFrom>
                        <MetaData wcm:action="add">
                            <Key>/IMAGE/NAME</Key>
                            <Value>$ImageName</Value>
                        </MetaData>
                    </InstallFrom>
                    <InstallTo>
                        <DiskID>0</DiskID>
                        <PartitionID>3</PartitionID>
                    </InstallTo>
                </OSImage>
            </ImageInstall>
            <DiskConfiguration>
                <Disk wcm:action="add">
                    <CreatePartitions>
                        <CreatePartition wcm:action="add">
                            <Order>1</Order>
                            <Size>260</Size>
                            <Type>EFI</Type>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Order>2</Order>
                            <Size>16</Size>
                            <Type>MSR</Type>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Order>3</Order>
                            <Type>Primary</Type>
                            <Extend>true</Extend>
                        </CreatePartition>
                    </CreatePartitions>
                    <ModifyPartitions>
                        <ModifyPartition wcm:action="add">
                            <Order>1</Order>
                            <PartitionID>1</PartitionID>
                            <Label>System</Label>
                            <Format>FAT32</Format>
                        </ModifyPartition>
                        <ModifyPartition wcm:action="add">
                            <Order>2</Order>
                            <PartitionID>2</PartitionID>
                        </ModifyPartition>
                        <ModifyPartition wcm:action="add">
                            <Order>3</Order>
                            <PartitionID>3</PartitionID>
                            <Label>Windows</Label>
                            <Letter>C</Letter>
                            <Format>NTFS</Format>
                        </ModifyPartition>
                    </ModifyPartitions>
                    <DiskID>0</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
                </Disk>
            </DiskConfiguration>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ComputerName>$($Configuration.ComputerName)</ComputerName>
            <TimeZone>$($Configuration.TimeZone)</TimeZone>
        </component>
"@
}

function Add-ProfileSpecificConfig {
    param(
        [string]$XMLContent,
        [string]$Profile,
        [hashtable]$Configuration
    )

    $profileConfig = ""

    switch ($Profile) {
        'Enterprise' {
            $profileConfig = @"
        <component name="Microsoft-Windows-SystemSettings" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <LocalAccountTokenFilterPolicy>1</LocalAccountTokenFilterPolicy>
        </component>
"@
        }
        'Developer' {
            $profileConfig = @"
        <component name="Microsoft-Windows-SystemSettings" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <LocalAccountTokenFilterPolicy>1</LocalAccountTokenFilterPolicy>
        </component>
"@
        }
        'Security' {
            $profileConfig = @"
        <component name="Microsoft-Windows-SystemSettings" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <LocalAccountTokenFilterPolicy>0</LocalAccountTokenFilterPolicy>
        </component>
"@
        }
    }

    return $XMLContent + $profileConfig
}

function Add-WSLConfiguration {
    param([string]$XMLContent)

    $wslConfig = @"
        <component name="Microsoft-Windows-Subsystem-Linux" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        </component>
"@

    return $XMLContent + $wslConfig
}

function Add-ContainerConfiguration {
    param([string]$XMLContent)

    $containerConfig = @"
        <component name="Microsoft-Windows-Containers" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        </component>
"@

    return $XMLContent + $containerConfig
}

function Add-SecurityHardening {
    param(
        [string]$XMLContent,
        [string]$SecurityProfile,
        [hashtable]$Configuration
    )

    $securityConfig = @"
        <component name="Microsoft-Windows-Security-SPP-UX" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SkipAutoActivation>true</SkipAutoActivation>
        </component>
"@

    return $XMLContent + $securityConfig
}

function Add-CloudOptimization {
    param(
        [string]$XMLContent,
        [string]$CloudPlatform
    )

    $cloudConfig = ""

    switch ($CloudPlatform) {
        'Azure' {
            $cloudConfig = @"
        <component name="Microsoft-Windows-CloudStore" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        </component>
"@
        }
    }

    return $XMLContent + $cloudConfig
}

function Add-DomainConfiguration {
    param(
        [string]$XMLContent,
        [hashtable]$DomainConfig
    )

    $domainConfigXML = @"
        <component name="Microsoft-Windows-UnattendedJoin" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <Identification>
                <Credentials>
                    <Domain>$($DomainConfig.DomainName)</Domain>
                    <Password>$($DomainConfig.DomainPassword)</Password>
                    <Username>$($DomainConfig.DomainUser)</Username>
                </Credentials>
                <JoinDomain>$($DomainConfig.DomainName)</JoinDomain>
            </Identification>
        </component>
"@

    return $XMLContent + $domainConfigXML
}
