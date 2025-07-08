function Get-Platform {
    if ($IsWindows -or [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) {
        return 'Windows'
    }
    elseif ($IsLinux -or [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)) {
        return 'Linux'
    }
    elseif ($IsMacOS -or [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)) {
        return 'MacOS'
    }
    elseif ($PSVersionTable.OS) {
        if ($PSVersionTable.OS -match 'Windows') { return 'Windows' }
        elseif ($PSVersionTable.OS -match 'Darwin') { return 'MacOS' }
        elseif ($PSVersionTable.OS -match 'Linux') { return 'Linux' }
    }
    return 'Unknown'
}
