function New-AutounattendFile {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Server2025', 'Server2022', 'Server2019', 'Windows11', 'Windows10', 'Generic')]
        [string]$OSType = 'Server2025',

        [Parameter(Mandatory = $false)]
        [ValidateSet('Standard', 'Datacenter', 'Core', 'Desktop')]
        [string]$Edition = 'Datacenter',

        [Parameter(Mandatory = $false)]
        [string]$TemplatePath,

        [Parameter(Mandatory = $false)]
        [switch]$HeadlessMode,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Generating autounattend file for: $OSType"
        
        # Set default configuration values
        $defaultConfig = @{
            # Windows PE Settings
            InputLocale = 'en-US'
            SystemLocale = 'en-US'
            UILanguage = 'en-US'
            UserLocale = 'en-US'
            
            # User Data
            AcceptEula = $true
            ProductKey = 'Insert License Key Here'
            FullName = 'AitherZero Lab'
            Organization = 'AitherZero Infrastructure'
            
            # Disk Configuration
            DiskID = 0
            EFIPartitionSize = 260
            MSRPartitionSize = 16
            PrimaryPartitionSize = 20000
            
            # Administrator Account
            AdminPassword = 'P@ssw0rd123!'
            AdminPasswordPlainText = $false
            
            # Computer Settings
            ComputerName = 'WIN-LAB-01'
            TimeZone = 'UTC'
            
            # Network Settings
            EnableDHCP = $true
            
            # Additional Settings
            EnableRDP = $true
            DisableWindowsDefender = $false
            DisableFirewall = $false
            DisableUAC = $false
            AutoLogon = $false
            AutoLogonCount = 3
            
            # Commands to run
            FirstLogonCommands = @()
            BootstrapScript = $null
        }

        # Merge provided configuration with defaults
        foreach ($key in $defaultConfig.Keys) {
            if (-not $Configuration.ContainsKey($key)) {
                $Configuration[$key] = $defaultConfig[$key]
            }
        }

        # Determine OS image name based on type and edition
        $imageName = Get-OSImageName -OSType $OSType -Edition $Edition

        # Check if output directory exists
        $outputDir = Split-Path $OutputPath -Parent
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        # Check if file already exists
        if ((Test-Path $OutputPath) -and -not $Force) {
            throw "Autounattend file already exists: $OutputPath. Use -Force to overwrite."
        }
    }

    process {
        try {
            if ($PSCmdlet.ShouldProcess($OutputPath, "Generate Autounattend File")) {
                
                Write-CustomLog -Level 'INFO' -Message "Creating autounattend XML content..."

                # Build the XML content
                $xmlContent = @"
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
                <AcceptEula>$($Configuration.AcceptEula.ToString().ToLower())</AcceptEula>
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
                            <Value>$imageName</Value>
                        </MetaData>
                    </InstallFrom>
                    <InstallTo>
                        <DiskID>$($Configuration.DiskID)</DiskID>
                        <PartitionID>3</PartitionID>
                    </InstallTo>
                </OSImage>
            </ImageInstall>
            <DiskConfiguration>
                <Disk wcm:action="add">
                    <CreatePartitions>
                        <CreatePartition wcm:action="add">
                            <Order>1</Order>
                            <Size>$($Configuration.EFIPartitionSize)</Size>
                            <Type>EFI</Type>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Order>2</Order>
                            <Size>$($Configuration.MSRPartitionSize)</Size>
                            <Type>MSR</Type>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Order>3</Order>
                            <Type>Primary</Type>
                            <Size>$($Configuration.PrimaryPartitionSize)</Size>
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
                    <DiskID>$($Configuration.DiskID)</DiskID>
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

                # Add RDP configuration if enabled
                if ($Configuration.EnableRDP) {
                    $xmlContent += @"
        <component name="Microsoft-Windows-TerminalServices-LocalSessionManager" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <fDenyTSConnections>false</fDenyTSConnections>
        </component>
        <component name="Microsoft-Windows-TerminalServices-RDP-WinStationExtensions" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <UserAuthentication>0</UserAuthentication>
        </component>
"@
                }

                # Add firewall configuration
                if ($Configuration.DisableFirewall) {
                    $xmlContent += @"
        <component name="Networking-MPSSVC-Svc" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <DomainProfile_EnableFirewall>false</DomainProfile_EnableFirewall>
            <PrivateProfile_EnableFirewall>false</PrivateProfile_EnableFirewall>
            <PublicProfile_EnableFirewall>false</PublicProfile_EnableFirewall>
        </component>
"@
                }

                $xmlContent += @"
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <UserAccounts>
                <AdministratorPassword>
                    <Value>$($Configuration.AdminPassword)</Value>
                    <PlainText>$($Configuration.AdminPasswordPlainText.ToString().ToLower())</PlainText>
                </AdministratorPassword>
            </UserAccounts>
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <NetworkLocation>Work</NetworkLocation>
                <ProtectYourPC>1</ProtectYourPC>
                <SkipUserOOBE>true</SkipUserOOBE>
                <SkipMachineOOBE>true</SkipMachineOOBE>
            </OOBE>
"@

                # Add auto logon configuration if enabled
                if ($Configuration.AutoLogon) {
                    $xmlContent += @"
            <AutoLogon>
                <Password>
                    <Value>$($Configuration.AdminPassword)</Value>
                    <PlainText>$($Configuration.AdminPasswordPlainText.ToString().ToLower())</PlainText>
                </Password>
                <Username>Administrator</Username>
                <Enabled>true</Enabled>
                <LogonCount>$($Configuration.AutoLogonCount)</LogonCount>
            </AutoLogon>
"@
                }

                # Add first logon commands
                if ($Configuration.FirstLogonCommands.Count -gt 0 -or $Configuration.BootstrapScript) {
                    $xmlContent += @"
            <FirstLogonCommands>
"@
                    
                    $commandOrder = 1
                    
                    # Add bootstrap script if specified
                    if ($Configuration.BootstrapScript) {
                        $xmlContent += @"
                <SynchronousCommand wcm:action="add">
                    <Order>$commandOrder</Order>
                    <CommandLine>powershell.exe -ExecutionPolicy Bypass -File C:\Windows\bootstrap.ps1</CommandLine>
                    <Description>Run Bootstrap Script</Description>
                </SynchronousCommand>
"@
                        $commandOrder++
                    }

                    # Add custom first logon commands
                    foreach ($command in $Configuration.FirstLogonCommands) {
                        $xmlContent += @"
                <SynchronousCommand wcm:action="add">
                    <Order>$commandOrder</Order>
                    <CommandLine>$($command.CommandLine)</CommandLine>
                    <Description>$($command.Description)</Description>
                </SynchronousCommand>
"@
                        $commandOrder++
                    }

                    $xmlContent += @"
            </FirstLogonCommands>
"@
                }

                $xmlContent += @"
        </component>
    </settings>
</unattend>
"@

                # Write the XML content to file
                Write-CustomLog -Level 'INFO' -Message "Writing autounattend file to: $OutputPath"
                Set-Content -Path $OutputPath -Value $xmlContent -Encoding UTF8

                # Validate the generated XML
                try {
                    [xml]$xmlTest = Get-Content $OutputPath -Raw
                    Write-CustomLog -Level 'SUCCESS' -Message "Autounattend XML validation successful"
                } catch {
                    Write-CustomLog -Level 'ERROR' -Message "Generated XML is invalid: $($_.Exception.Message)"
                    throw "Generated autounattend XML is invalid"
                }

                Write-CustomLog -Level 'SUCCESS' -Message "Autounattend file generated successfully: $OutputPath"

                return @{
                    Success = $true
                    FilePath = $OutputPath
                    OSType = $OSType
                    Edition = $Edition
                    ImageName = $imageName
                    Configuration = $Configuration
                    FileSize = (Get-Item $OutputPath).Length
                    CreationTime = Get-Date
                    Message = "Autounattend file generated successfully"
                }
            }
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to generate autounattend file: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Completed New-AutounattendFile operation"
    }
}
