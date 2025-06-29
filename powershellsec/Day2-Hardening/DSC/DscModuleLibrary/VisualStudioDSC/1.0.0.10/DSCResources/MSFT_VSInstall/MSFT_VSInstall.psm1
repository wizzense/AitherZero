function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]  
        [System.String] 
        $ExecutablePath,

        [parameter(Mandatory = $true)] 
        [System.Management.Automation.PSCredential] 
        $InstallAccount,

        [parameter(Mandatory = $false)] 
        [System.String[]] 
        $Workloads,
    
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present"
    )
    Write-Verbose -Message "Detecting a previous installation of Visual Studio"

    $x86Path = "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    $installedItemsX86 = Get-ItemProperty -Path $x86Path | Select-Object -Property DisplayName
    
    $x64Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    $installedItemsX64 = Get-ItemProperty -Path $x64Path | Select-Object -Property DisplayName

    $installedItems = $installedItemsX86 + $installedItemsX64 
    $installedItems = $installedItems | Select-Object -Property DisplayName -Unique    
    $vsInstall = $installedItems | Where-Object -FilterScript { 
        $_ -match "Microsoft Visual Studio 2017" 
    }
    
    if ($vsInstall) 
    {
        return @{
            ExecutablePath = $ExecutablePath
            InstallAccount = $InstallAccount
            Workloads = $Workloads
            Ensure = "Present"
        }
    } 
    else 
    {
        return @{
            ExecutablePath = $ExecutablePath
            Workloads = $Workloads
            Ensure = "Absent"
        }
    }
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]  
        [System.String] 
        $ExecutablePath,

        [parameter(Mandatory = $true)] 
        [System.Management.Automation.PSCredential] 
        $InstallAccount,
    
        [parameter(Mandatory = $false)] 
        [System.String[]] 
        $Workloads,        
    
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present"
    )
    
    #Write-Verbose -Message "Copying the Installer executable"

    #$tempFolder = "C:\VS2017Temp"
    #New-Item -Path "C:\VS2017Temp" -ItemType Directory -Force -Confirm:$false

    #$tempPath = $tempFolder + "\" + $ExecutablePath.Split('\')[$ExecutablePath.Split('\').Length -1]
    #Copy-Item -Path $ExecutablePath -Destination $tempPath
    #$ExecutablePath = $tempPath

    $installer = Get-Item -Path $ExecutablePath

    if($installer)
    {
        $workloadArgs = ""
        foreach($workload in $Workloads)
        {
            $workloadArgs += " --add $workload"
        }
        Write-Verbose -Message "Installing Visual Studio 2017"
        Start-Process -FilePath $ExecutablePath -ArgumentList ("--quiet" + $workloadArgs) -Wait -PassThru -Credential $InstallAccount

        #Remove-Item -Path $tempFolder -Force -Recurse -Confirm:$false
    }
    else{
        throw "The Installer could not be found at $ExecutablePath"
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]  
        [System.String] 
        $ExecutablePath,

        [parameter(Mandatory = $true)] 
        [System.Management.Automation.PSCredential] 
        $InstallAccount,

        [parameter(Mandatory = $false)] 
        [System.String[]] 
        $Workloads,
    
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present"
    )
    Write-Verbose -Message "Checking to see if Visual Studio 2017 is installed"
    $x86Path = "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    $installedItemsX86 = Get-ItemProperty -Path $x86Path | Select-Object -Property DisplayName
    
    $x64Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    $installedItemsX64 = Get-ItemProperty -Path $x64Path | Select-Object -Property DisplayName

    $installedItems = $installedItemsX86 + $installedItemsX64 
    $installedItems = $installedItems | Select-Object -Property DisplayName -Unique    
    $vsInstall = $installedItems | Where-Object -FilterScript { 
        $_ -match "Microsoft Visual Studio 2017" 
    }

    if($vsInstall)
    {
	    return $true;
    }
    else
    {
    	return $false;
    }
}

Export-ModuleMember -Function *-TargetResource