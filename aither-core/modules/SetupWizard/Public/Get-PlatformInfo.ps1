function Get-PlatformInfo {
    <#
    .SYNOPSIS
        Get comprehensive platform information for setup wizard
    .DESCRIPTION
        Returns detailed platform information including OS, version, architecture,
        and PowerShell version for use in setup decisions
    .EXAMPLE
        $platformInfo = Get-PlatformInfo
    #>
    [CmdletBinding()]
    param()

    try {
        return @{
            OS = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
            Version = if ($IsWindows) {
                [System.Environment]::OSVersion.Version.ToString()
            } elseif ($IsLinux) {
                if (Test-Path /etc/os-release) {
                    (Get-Content /etc/os-release | Select-String '^VERSION=' | ForEach-Object { $_.ToString().Split('=')[1].Trim('"') })
                } else {
                    'Unknown'
                }
            } elseif ($IsMacOS) {
                try {
                    & sw_vers -productVersion
                } catch {
                    'Unknown'
                }
            } else {
                'Unknown'
            }
            Architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
            PowerShell = $PSVersionTable.PSVersion.ToString()
            PSEdition = $PSVersionTable.PSEdition
            CLRVersion = $PSVersionTable.CLRVersion.ToString()
            ProcessorCount = [Environment]::ProcessorCount
            UserDomainName = [Environment]::UserDomainName
            MachineName = [Environment]::MachineName
        }
    } catch {
        Write-Warning "Failed to get complete platform information: $_"
        return @{
            OS = 'Unknown'
            Version = 'Unknown'
            Architecture = 'Unknown'
            PowerShell = $PSVersionTable.PSVersion.ToString()
        }
    }
}

Export-ModuleMember -Function Get-PlatformInfo