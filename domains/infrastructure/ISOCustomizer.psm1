#Requires -Version 7.0

<#
.SYNOPSIS
    Windows ISO customization module.

.DESCRIPTION
    Provides functionality for customizing Windows ISO images:
    - Unattend.xml generation for automated installations
    - Driver injection using DISM
    - Windows update integration
    
    Developed using Test-Driven Development (TDD) methodology.

.NOTES
    Part of the AitherZero infrastructure automation platform.
#>

#region Helper Functions

function Write-ISOCustomizerLog {
    <#
    .SYNOPSIS
        Write log messages for ISO customization operations.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('Information', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Information'
    )
    
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
}

#endregion

#region Public Functions

function Test-DISMAvailability {
    <#
    .SYNOPSIS
        Tests if DISM is available on the system.
    
    .DESCRIPTION
        Checks if the Deployment Image Servicing and Management (DISM) tool
        is available. DISM is required for driver injection and other Windows
        image manipulation tasks.
    
    .EXAMPLE
        Test-DISMAvailability
        Returns $true if DISM is available, $false otherwise.
    
    .OUTPUTS
        Boolean indicating DISM availability.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    if (-not $IsWindows) {
        Write-ISOCustomizerLog "DISM is only available on Windows" -Level 'Debug'
        return $false
    }
    
    $dism = Get-Command DISM.exe -ErrorAction SilentlyContinue
    if ($dism) {
        Write-ISOCustomizerLog "DISM found at: $($dism.Source)" -Level 'Debug'
        return $true
    }
    
    Write-ISOCustomizerLog "DISM not found on system" -Level 'Debug'
    return $false
}

function New-UnattendXml {
    <#
    .SYNOPSIS
        Generates an unattend.xml file for automated Windows installation.
    
    .DESCRIPTION
        Creates a customized unattend.xml file for Windows automated installation.
        Supports configuration of computer name, product key, time zone, and
        administrator password.
    
    .PARAMETER ComputerName
        The name to assign to the computer during installation.
    
    .PARAMETER OutputPath
        Path where the unattend.xml file will be saved.
    
    .PARAMETER ProductKey
        Optional Windows product key. If not specified, installation will
        require manual key entry.
    
    .PARAMETER TimeZone
        Time zone to configure. Defaults to UTC.
    
    .PARAMETER AdministratorPassword
        Secure string containing the administrator password.
        If not specified, password will be left blank (not recommended for production).
    
    .PARAMETER AutoLogon
        If specified, enables automatic logon after installation.
    
    .PARAMETER AutoLogonCount
        Number of automatic logons to perform. Defaults to 1.
    
    .EXAMPLE
        $pass = ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force
        New-UnattendXml -ComputerName "SERVER01" -OutputPath "C:\unattend.xml" -AdministratorPassword $pass
        
        Creates an unattend.xml for SERVER01 with specified password.
    
    .OUTPUTS
        PSCustomObject with Success, OutputPath, and Message properties.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [Parameter()]
        [string]$ProductKey,
        
        [Parameter()]
        [string]$TimeZone = 'UTC',
        
        [Parameter()]
        [SecureString]$AdministratorPassword,
        
        [Parameter()]
        [switch]$AutoLogon,
        
        [Parameter()]
        [int]$AutoLogonCount = 1
    )
    
    Write-ISOCustomizerLog "Generating unattend.xml for computer: $ComputerName"
    
    # Convert secure string password to plain text for XML
    $plainPassword = if ($AdministratorPassword) {
        $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdministratorPassword)
        try {
            [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
        } finally {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        }
    } else {
        ""
    }
    
    # Create unattend.xml content
    $unattendContent = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <UserData>
                <AcceptEula>true</AcceptEula>
$(if ($ProductKey) {
@"
                <ProductKey>
                    <Key>$ProductKey</Key>
                </ProductKey>
"@
})
            </UserData>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ComputerName>$ComputerName</ComputerName>
            <TimeZone>$TimeZone</TimeZone>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <SkipMachineOOBE>true</SkipMachineOOBE>
                <SkipUserOOBE>true</SkipUserOOBE>
            </OOBE>
            <UserAccounts>
                <AdministratorPassword>
                    <Value>$plainPassword</Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>
            </UserAccounts>
$(if ($AutoLogon) {
@"
            <AutoLogon>
                <Password>
                    <Value>$plainPassword</Value>
                    <PlainText>true</PlainText>
                </Password>
                <Enabled>true</Enabled>
                <Username>Administrator</Username>
                <LogonCount>$AutoLogonCount</LogonCount>
            </AutoLogon>
"@
})
        </component>
    </settings>
</unattend>
"@
    
    try {
        if ($PSCmdlet.ShouldProcess($OutputPath, 'Create unattend.xml')) {
            # Validate XML is well-formed
            $null = [xml]$unattendContent
            
            # Save to file
            $unattendContent | Out-File -FilePath $OutputPath -Encoding utf8 -Force
            
            Write-ISOCustomizerLog "Unattend.xml created successfully at: $OutputPath"
            
            return [PSCustomObject]@{
                Success = $true
                OutputPath = $OutputPath
                ComputerName = $ComputerName
                Message = "Unattend.xml created successfully"
            }
        } else {
            return [PSCustomObject]@{
                Success = $false
                OutputPath = $OutputPath
                ComputerName = $ComputerName
                Message = "WhatIf: Would create unattend.xml at $OutputPath"
            }
        }
    } catch {
        Write-ISOCustomizerLog "Failed to create unattend.xml: $_" -Level 'Error'
        return [PSCustomObject]@{
            Success = $false
            OutputPath = $OutputPath
            ComputerName = $ComputerName
            Message = "Failed to create unattend.xml: $_"
        }
    }
}

function Add-ISODriver {
    <#
    .SYNOPSIS
        Injects drivers into a mounted Windows ISO image using DISM.
    
    .DESCRIPTION
        Uses the Deployment Image Servicing and Management (DISM) tool to inject
        drivers into a mounted Windows image. This is useful for adding storage,
        network, or other critical drivers to Windows installation media.
    
    .PARAMETER MountPath
        Path to the mounted Windows image (WIM file mount point).
    
    .PARAMETER DriverPath
        Path to the directory containing driver .inf files, or path to a specific .inf file.
    
    .PARAMETER Recurse
        If specified, searches for drivers recursively in subdirectories.
    
    .EXAMPLE
        Add-ISODriver -MountPath "C:\Mount" -DriverPath "C:\Drivers" -Recurse
        Injects all drivers from C:\Drivers and its subdirectories into the mounted image.
    
    .OUTPUTS
        PSCustomObject with Success, DriversAdded, and Message properties.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ })]
        [string]$MountPath,
        
        [Parameter(Mandatory)]
        [string]$DriverPath,
        
        [Parameter()]
        [switch]$Recurse
    )
    
    Write-ISOCustomizerLog "Adding drivers to mounted image at: $MountPath"
    
    # Check if DISM is available
    if (-not (Test-DISMAvailability)) {
        $message = "DISM is not available. Driver injection requires DISM on Windows."
        Write-ISOCustomizerLog $message -Level 'Error'
        return [PSCustomObject]@{
            Success = $false
            DriversAdded = 0
            Message = $message
        }
    }
    
    # Validate driver path
    if (-not (Test-Path $DriverPath)) {
        $message = "Driver path not found: $DriverPath"
        Write-ISOCustomizerLog $message -Level 'Error'
        return [PSCustomObject]@{
            Success = $false
            DriversAdded = 0
            Message = $message
        }
    }
    
    try {
        if ($PSCmdlet.ShouldProcess($MountPath, "Inject drivers from $DriverPath")) {
            # Build DISM command
            $dismArgs = @(
                '/Image:' + $MountPath
                '/Add-Driver'
                '/Driver:' + $DriverPath
            )
            
            if ($Recurse) {
                $dismArgs += '/Recurse'
            }
            
            Write-ISOCustomizerLog "Executing DISM with arguments: $($dismArgs -join ' ')"
            
            # Execute DISM
            $output = & DISM.exe $dismArgs 2>&1
            $exitCode = $LASTEXITCODE
            
            if ($exitCode -eq 0) {
                # Parse output to count drivers added
                $driversAdded = 0
                if ($output -match "(\d+) driver\(s\) were added") {
                    $driversAdded = [int]$matches[1]
                }
                
                Write-ISOCustomizerLog "Successfully added $driversAdded driver(s)"
                
                return [PSCustomObject]@{
                    Success = $true
                    DriversAdded = $driversAdded
                    Message = "Successfully added $driversAdded driver(s)"
                }
            } else {
                $message = "DISM failed with exit code: $exitCode"
                Write-ISOCustomizerLog $message -Level 'Error'
                Write-ISOCustomizerLog "DISM output: $output" -Level 'Debug'
                
                return [PSCustomObject]@{
                    Success = $false
                    DriversAdded = 0
                    Message = $message
                }
            }
        } else {
            return [PSCustomObject]@{
                Success = $false
                DriversAdded = 0
                Message = "WhatIf: Would inject drivers from $DriverPath into $MountPath"
            }
        }
    } catch {
        Write-ISOCustomizerLog "Failed to add drivers: $_" -Level 'Error'
        return [PSCustomObject]@{
            Success = $false
            DriversAdded = 0
            Message = "Failed to add drivers: $_"
        }
    }
}

#endregion

# Export functions
Export-ModuleMember -Function @(
    'Test-DISMAvailability'
    'New-UnattendXml'
    'Add-ISODriver'
)
