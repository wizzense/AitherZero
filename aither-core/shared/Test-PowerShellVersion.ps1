# Simplified PowerShell version checking utility
# Supports PowerShell 5.1+ for cross-platform compatibility

function Test-PowerShellVersion {
    <#
    .SYNOPSIS
        Tests if the current PowerShell version meets requirements
    
    .DESCRIPTION
        Checks PowerShell version and provides upgrade guidance if needed.
        Supports PowerShell 5.1+ for cross-platform compatibility.
    
    .PARAMETER MinimumVersion
        Minimum required PowerShell version (default: 7.0)
    
    .PARAMETER Quiet
        Suppress all output, only return boolean
    
    .EXAMPLE
        Test-PowerShellVersion -MinimumVersion "7.0"
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [version]$MinimumVersion = "7.0",
        
        [Parameter()]
        [switch]$Quiet
    )
    
    $currentVersion = $PSVersionTable.PSVersion
    $meetsRequirement = $currentVersion -ge $MinimumVersion
    
    if ($Quiet) {
        return $meetsRequirement
    }
    
    if (-not $meetsRequirement) {
        Write-Host "PowerShell $MinimumVersion or later is required." -ForegroundColor Yellow
        Write-Host "Current version: $currentVersion" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To install PowerShell 7:" -ForegroundColor Cyan
        
        if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or $PSVersionTable.PSEdition -eq 'Desktop') {
            Write-Host "  winget install Microsoft.PowerShell" -ForegroundColor Green
            Write-Host "  or visit: https://aka.ms/powershell-release" -ForegroundColor Green
        } elseif ($IsLinux) {
            Write-Host "  Visit: https://docs.microsoft.com/powershell/scripting/install/installing-powershell-on-linux" -ForegroundColor Green
        } elseif ($IsMacOS) {
            Write-Host "  brew install --cask powershell" -ForegroundColor Green
            Write-Host "  or visit: https://docs.microsoft.com/powershell/scripting/install/installing-powershell-on-macos" -ForegroundColor Green
        }
    }
    
    return $meetsRequirement
}

function Find-PowerShell7 {
    <#
    .SYNOPSIS
        Finds PowerShell 7 installation on the system
    
    .DESCRIPTION
        Searches common installation paths and returns the path to pwsh executable
    
    .EXAMPLE
        $pwsh7Path = Find-PowerShell7
    #>
    [CmdletBinding()]
    param()
    
    # Try Get-Command first (most reliable)
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCmd -and $pwshCmd.Source) {
        return $pwshCmd.Source
    }
    
    # Common installation paths
    $searchPaths = @()
    
    if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or $PSVersionTable.PSEdition -eq 'Desktop') {
        $searchPaths += @(
            "$env:ProgramFiles\PowerShell\7\pwsh.exe",
            "$env:ProgramFiles\PowerShell\7-preview\pwsh.exe",
            "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe"
        )
    } else {
        $searchPaths += @(
            "/usr/local/bin/pwsh",
            "/usr/bin/pwsh",
            "/opt/microsoft/powershell/7/pwsh",
            "/snap/bin/pwsh"
        )
    }
    
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    return $null
}

function Start-WithPowerShell7 {
    <#
    .SYNOPSIS
        Restarts the current script with PowerShell 7
    
    .DESCRIPTION
        Finds PowerShell 7 and relaunches the current script with all parameters preserved
    
    .PARAMETER ScriptPath
        Path to the script to restart (default: current script)
    
    .PARAMETER Parameters
        Parameters to pass to the script
    
    .EXAMPLE
        Start-WithPowerShell7 -Parameters $PSBoundParameters
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ScriptPath = $MyInvocation.PSCommandPath,
        
        [Parameter()]
        [hashtable]$Parameters = @{}
    )
    
    $pwsh7 = Find-PowerShell7
    
    if (-not $pwsh7) {
        Write-Host "❌ PowerShell 7 is not installed!" -ForegroundColor Red
        Write-Host "Please install PowerShell 7 and try again." -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "✅ Found PowerShell 7 at: $pwsh7" -ForegroundColor Green
    Write-Host "🔄 Relaunching with PowerShell 7..." -ForegroundColor Cyan
    
    # Build argument list
    $argList = @('-NoProfile', '-File', $ScriptPath)
    
    foreach ($key in $Parameters.Keys) {
        $value = $Parameters[$key]
        
        if ($value -is [switch]) {
            if ($value.IsPresent) {
                $argList += "-$key"
            }
        } elseif ($null -ne $value) {
            $argList += "-$key"
            $argList += $value
        }
    }
    
    # Start new process
    & $pwsh7 @argList
    
    # Exit current process with same exit code
    exit $LASTEXITCODE
}

# Export functions only if running as a module (not when dot-sourced)
# When dot-sourced, functions are automatically available in the caller's scope
if ($ExecutionContext.SessionState.Module) {
    Export-ModuleMember -Function @(
        'Test-PowerShellVersion',
        'Find-PowerShell7',
        'Start-WithPowerShell7'
    )
}