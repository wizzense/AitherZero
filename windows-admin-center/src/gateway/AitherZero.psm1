<#
.SYNOPSIS
    AitherZero gateway module for Windows Admin Center

.DESCRIPTION
    PowerShell gateway module that provides remote execution capabilities
    for AitherZero automation scripts through Windows Admin Center.
#>

#Requires -Version 7.0

Set-StrictMode -Version Latest

# Import required modules
Import-Module Microsoft.WSMan.Management -ErrorAction SilentlyContinue

<#
.SYNOPSIS
    Gets available AitherZero automation scripts on the target server.

.PARAMETER ServerName
    Name of the target server. Defaults to localhost.

.PARAMETER Category
    Optional category filter (e.g., "0000-0099", "0100-0199")

.EXAMPLE
    Get-AitherZeroScripts -ServerName "Server01"

.EXAMPLE
    Get-AitherZeroScripts -ServerName "Server01" -Category "0400-0499"
#>
function Get-AitherZeroScripts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ServerName = "localhost",

        [Parameter(Mandatory = $false)]
        [string]$Category
    )

    try {
        $scriptBlock = {
            param($CategoryFilter)
            
            # Check if AitherZero is installed
            $aitherZeroRoot = $env:AITHERZERO_ROOT
            if (-not $aitherZeroRoot) {
                # Try to find it
                $manifestPath = Get-ChildItem -Path "C:\", "$env:USERPROFILE" -Filter "AitherZero.psd1" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($manifestPath) {
                    $aitherZeroRoot = Split-Path $manifestPath.FullName -Parent
                }
            }

            if (-not $aitherZeroRoot) {
                throw "AitherZero installation not found on server"
            }

            $scriptsPath = Join-Path $aitherZeroRoot "automation-scripts"
            if (-not (Test-Path $scriptsPath)) {
                throw "Automation scripts directory not found: $scriptsPath"
            }

            $scripts = Get-ChildItem -Path $scriptsPath -Filter "*.ps1" | ForEach-Object {
                if ($_.Name -match '^(\d{4})_(.+)\.ps1$') {
                    $number = $Matches[1]
                    $name = $Matches[2] -replace '-', ' '
                    
                    # Apply category filter if provided
                    if ($CategoryFilter) {
                        $range = $CategoryFilter -split '-'
                        $start = [int]$range[0]
                        $end = [int]$range[1]
                        $scriptNum = [int]$number
                        
                        if ($scriptNum -lt $start -or $scriptNum -gt $end) {
                            return
                        }
                    }

                    [PSCustomObject]@{
                        Number      = $number
                        Name        = $name
                        FileName    = $_.Name
                        Path        = $_.FullName
                        Size        = $_.Length
                        LastModified = $_.LastWriteTime
                    }
                }
            } | Where-Object { $_ -ne $null }

            return $scripts | Sort-Object Number
        }

        if ($ServerName -eq "localhost") {
            $result = & $scriptBlock -CategoryFilter $Category
        } else {
            $result = Invoke-Command -ComputerName $ServerName -ScriptBlock $scriptBlock -ArgumentList $Category
        }

        return $result
    }
    catch {
        Write-Error "Failed to get AitherZero scripts: $_"
        throw
    }
}

<#
.SYNOPSIS
    Executes an AitherZero automation script on the target server.

.PARAMETER ServerName
    Name of the target server.

.PARAMETER ScriptNumber
    Script number to execute (e.g., "0402")

.PARAMETER Parameters
    Optional hashtable of parameters to pass to the script

.EXAMPLE
    Invoke-AitherZeroScript -ServerName "Server01" -ScriptNumber "0402"

.EXAMPLE
    Invoke-AitherZeroScript -ServerName "Server01" -ScriptNumber "0407" -Parameters @{All=$true}
#>
function Invoke-AitherZeroScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerName,

        [Parameter(Mandatory = $true)]
        [string]$ScriptNumber,

        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters = @{}
    )

    try {
        $scriptBlock = {
            param($ScriptNum, $ScriptParams)
            
            # Find AitherZero root
            $aitherZeroRoot = $env:AITHERZERO_ROOT
            if (-not $aitherZeroRoot) {
                $manifestPath = Get-ChildItem -Path "C:\", "$env:USERPROFILE" -Filter "AitherZero.psd1" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($manifestPath) {
                    $aitherZeroRoot = Split-Path $manifestPath.FullName -Parent
                }
            }

            if (-not $aitherZeroRoot) {
                throw "AitherZero installation not found"
            }

            # Import AitherZero module
            $modulePath = Join-Path $aitherZeroRoot "AitherZero.psd1"
            Import-Module $modulePath -Force -ErrorAction Stop

            # Find the script
            $scriptsPath = Join-Path $aitherZeroRoot "automation-scripts"
            $scriptFile = Get-ChildItem -Path $scriptsPath -Filter "${ScriptNum}_*.ps1" | Select-Object -First 1

            if (-not $scriptFile) {
                throw "Script $ScriptNum not found"
            }

            # Execute the script
            $startTime = Get-Date
            try {
                $output = & $scriptFile.FullName @ScriptParams 2>&1
                $success = $?
                $endTime = Get-Date
                $duration = $endTime - $startTime

                return [PSCustomObject]@{
                    Success   = $success
                    Output    = $output -join "`n"
                    StartTime = $startTime
                    EndTime   = $endTime
                    Duration  = $duration.TotalSeconds
                    ScriptNumber = $ScriptNum
                    ScriptPath = $scriptFile.FullName
                }
            }
            catch {
                $endTime = Get-Date
                $duration = $endTime - $startTime
                
                return [PSCustomObject]@{
                    Success   = $false
                    Output    = $_.Exception.Message
                    Error     = $_
                    StartTime = $startTime
                    EndTime   = $endTime
                    Duration  = $duration.TotalSeconds
                    ScriptNumber = $ScriptNum
                    ScriptPath = $scriptFile.FullName
                }
            }
        }

        if ($ServerName -eq "localhost") {
            $result = & $scriptBlock -ScriptNum $ScriptNumber -ScriptParams $Parameters
        } else {
            $result = Invoke-Command -ComputerName $ServerName -ScriptBlock $scriptBlock -ArgumentList $ScriptNumber, $Parameters
        }

        return $result
    }
    catch {
        Write-Error "Failed to invoke AitherZero script: $_"
        throw
    }
}

<#
.SYNOPSIS
    Gets available orchestration playbooks.

.PARAMETER ServerName
    Name of the target server.

.EXAMPLE
    Get-AitherZeroPlaybooks -ServerName "Server01"
#>
function Get-AitherZeroPlaybooks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ServerName = "localhost"
    )

    try {
        $scriptBlock = {
            $aitherZeroRoot = $env:AITHERZERO_ROOT
            if (-not $aitherZeroRoot) {
                $manifestPath = Get-ChildItem -Path "C:\", "$env:USERPROFILE" -Filter "AitherZero.psd1" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($manifestPath) {
                    $aitherZeroRoot = Split-Path $manifestPath.FullName -Parent
                }
            }

            if (-not $aitherZeroRoot) {
                throw "AitherZero installation not found"
            }

            $playbooksPath = Join-Path $aitherZeroRoot "orchestration\playbooks"
            if (-not (Test-Path $playbooksPath)) {
                return @()
            }

            $playbooks = Get-ChildItem -Path $playbooksPath -Filter "*.psd1" | ForEach-Object {
                [PSCustomObject]@{
                    Name         = $_.BaseName
                    FileName     = $_.Name
                    Path         = $_.FullName
                    LastModified = $_.LastWriteTime
                }
            }

            return $playbooks
        }

        if ($ServerName -eq "localhost") {
            $result = & $scriptBlock
        } else {
            $result = Invoke-Command -ComputerName $ServerName -ScriptBlock $scriptBlock
        }

        return $result
    }
    catch {
        Write-Error "Failed to get playbooks: $_"
        throw
    }
}

<#
.SYNOPSIS
    Gets server information and AitherZero installation status.

.PARAMETER ServerName
    Name of the target server.

.EXAMPLE
    Get-AitherZeroServerInfo -ServerName "Server01"
#>
function Get-AitherZeroServerInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ServerName = "localhost"
    )

    try {
        $scriptBlock = {
            $info = [PSCustomObject]@{
                ServerName        = $env:COMPUTERNAME
                PowerShellVersion = $PSVersionTable.PSVersion.ToString()
                OS                = [System.Environment]::OSVersion.VersionString
                AitherZeroInstalled = $false
                AitherZeroRoot    = $null
                AitherZeroVersion = $null
                ScriptCount       = 0
                PlaybookCount     = 0
            }

            # Check for AitherZero
            $aitherZeroRoot = $env:AITHERZERO_ROOT
            if (-not $aitherZeroRoot) {
                $manifestPath = Get-ChildItem -Path "C:\", "$env:USERPROFILE" -Filter "AitherZero.psd1" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($manifestPath) {
                    $aitherZeroRoot = Split-Path $manifestPath.FullName -Parent
                }
            }

            if ($aitherZeroRoot -and (Test-Path $aitherZeroRoot)) {
                $info.AitherZeroInstalled = $true
                $info.AitherZeroRoot = $aitherZeroRoot

                # Get version
                $manifestPath = Join-Path $aitherZeroRoot "AitherZero.psd1"
                if (Test-Path $manifestPath) {
                    $manifest = Import-PowerShellDataFile $manifestPath
                    $info.AitherZeroVersion = $manifest.ModuleVersion
                }

                # Count scripts
                $scriptsPath = Join-Path $aitherZeroRoot "automation-scripts"
                if (Test-Path $scriptsPath) {
                    $info.ScriptCount = (Get-ChildItem -Path $scriptsPath -Filter "*.ps1").Count
                }

                # Count playbooks
                $playbooksPath = Join-Path $aitherZeroRoot "orchestration\playbooks"
                if (Test-Path $playbooksPath) {
                    $info.PlaybookCount = (Get-ChildItem -Path $playbooksPath -Filter "*.psd1").Count
                }
            }

            return $info
        }

        if ($ServerName -eq "localhost") {
            $result = & $scriptBlock
        } else {
            $result = Invoke-Command -ComputerName $ServerName -ScriptBlock $scriptBlock
        }

        return $result
    }
    catch {
        Write-Error "Failed to get server info: $_"
        throw
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Get-AitherZeroScripts',
    'Invoke-AitherZeroScript',
    'Get-AitherZeroPlaybooks',
    'Get-AitherZeroServerInfo'
)
