# AitherZero One-Liner Download Script
# PowerShell 5.1+ Compatible - Can be executed via iex/Invoke-Expression

<#
.SYNOPSIS
    AitherZero One-Liner Download and Installation Script

.DESCRIPTION
    This script is designed to be executed as a one-liner for quick AitherZero installation.
    It's fully compatible with PowerShell 5.1+ and handles all the complexity of downloading
    and setting up AitherZero in a single command.

.USAGE EXAMPLES
    # Basic one-liner installation:
    iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/wizzense/AitherZero/main/get-aither.ps1'))

    # PowerShell 5.1 compatible alternative:
    (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/wizzense/AitherZero/main/get-aither.ps1') | iex

    # With custom parameters (requires saving to file first):
    # Download this script, then run: .\get-aither.ps1 -InstallPath "C:\Tools" -Profile developer

.PARAMETER InstallPath
    Installation directory (defaults to current directory)

.PARAMETER Profile  
    Installation profile: minimal, standard, developer, full

.PARAMETER Silent
    Run in silent mode

.PARAMETER Force
    Force installation over existing directory

.NOTES
    AitherZero One-Liner Installer v1.0
    Optimized for web execution via iex/Invoke-Expression
    Compatible with PowerShell 5.1+ on Windows
#>

[CmdletBinding()]
param(
    [string]$InstallPath = $PWD.Path,
    [ValidateSet('minimal', 'standard', 'developer', 'full')]
    [string]$Profile = 'standard',
    [switch]$Silent,
    [switch]$Force
)

# One-liner execution detection
$isOneLineExecution = $MyInvocation.Line -match 'iex|Invoke-Expression'

# Compact configuration for one-liner
$c = @{
    Owner = 'wizzense'
    Repo = 'AitherZero'
    Branch = 'main'
    Dir = 'AitherZero'
    Temp = [System.IO.Path]::GetTempPath()
    UserAgent = 'AitherZero-GetScript/1.0'
}

# Compact logging function
function log($msg, $type = 'Info') {
    if ($Silent) { return }
    $colors = @{ Info = 'Cyan'; Success = 'Green'; Warning = 'Yellow'; Error = 'Red' }
    $prefixes = @{ Info = 'ℹ️'; Success = '✅'; Warning = '⚠️'; Error = '❌' }
    Write-Host "$($prefixes[$type]) $msg" -ForegroundColor $colors[$type]
}

# Compact PowerShell version check
function Test-PSVersion {
    $v = $PSVersionTable.PSVersion.Major
    if ($v -lt 5) {
        log "PowerShell 5.0+ required (current: $($PSVersionTable.PSVersion))" 'Error'
        return $false
    }
    log "PowerShell $($PSVersionTable.PSVersion) detected" 'Success'
    return $true
}

# Compact network test
function Test-Network {
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add('User-Agent', $c.UserAgent)
        $null = $wc.DownloadString("https://api.github.com/repos/$($c.Owner)/$($c.Repo)")
        $wc.Dispose()
        log "Network connectivity verified" 'Success'
        return $true
    } catch {
        log "Network test failed: $($_.Exception.Message)" 'Error'
        return $false
    }
}

# Compact download function
function Get-AitherZero($url, $path) {
    try {
        log "Downloading from: $url"
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add('User-Agent', $c.UserAgent)
        
        if (-not $Silent) {
            Register-ObjectEvent -InputObject $wc -EventName DownloadProgressChanged -Action {
                $p = $Event.SourceEventArgs
                $pct = [math]::Round(($p.BytesReceived / $p.TotalBytesToReceive) * 100, 1)
                Write-Progress -Activity "Downloading AitherZero" -Status "$pct%" -PercentComplete $pct
            } | Out-Null
        }
        
        $wc.DownloadFile($url, $path)
        $wc.Dispose()
        
        if (-not $Silent) { Write-Progress -Activity "Downloading AitherZero" -Completed }
        log "Download completed" 'Success'
        return $true
    } catch {
        log "Download failed: $($_.Exception.Message)" 'Error'
        return $false
    }
}

# Compact extraction function
function Expand-Archive51($archive, $dest) {
    try {
        log "Extracting archive..."
        if ($PSVersionTable.PSVersion.Major -ge 5) {
            Expand-Archive -Path $archive -DestinationPath $dest -Force
        } else {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($archive, $dest)
        }
        log "Extraction completed" 'Success'
        return $true
    } catch {
        log "Extraction failed: $($_.Exception.Message)" 'Error'
        return $false
    }
}

# Main execution for one-liner
try {
    # Header for one-liner mode
    if ($isOneLineExecution) {
        Write-Host ""
        log "🚀 AitherZero One-Liner Installer" 'Info'
        log "Compatible with PowerShell 5.1+" 'Info'
        Write-Host ""
    }
    
    # Quick prerequisite checks
    if (-not (Test-PSVersion)) { exit 1 }
    if (-not (Test-Network)) { exit 1 }
    
    # Setup paths
    $installDir = Join-Path $InstallPath $c.Dir
    if (Test-Path $installDir) {
        if ($Force) {
            log "Removing existing installation..." 'Warning'
            Remove-Item $installDir -Recurse -Force
        } else {
            log "Directory exists: $installDir (use -Force to overwrite)" 'Error'
            exit 1
        }
    }
    
    # Download URL
    $downloadUrl = "https://github.com/$($c.Owner)/$($c.Repo)/archive/refs/heads/$($c.Branch).zip"
    
    # Temporary paths
    $tempZip = Join-Path $c.Temp "AitherZero-$(Get-Date -Format 'yyyyMMddHHmmss').zip"
    $tempExtract = Join-Path $c.Temp "AitherZero-Extract-$(Get-Date -Format 'yyyyMMddHHmmss')"
    
    try {
        # Download
        if (-not (Get-AitherZero $downloadUrl $tempZip)) { throw "Download failed" }
        
        # Extract
        if (-not (Expand-Archive51 $tempZip $tempExtract)) { throw "Extraction failed" }
        
        # Move content
        log "Moving content to final location..."
        $extractedDir = Get-ChildItem -Path $tempExtract -Directory | Select-Object -First 1
        if ($extractedDir) {
            Move-Item $extractedDir.FullName $installDir -Force
            log "Installation completed" 'Success'
        } else {
            throw "Unexpected archive structure"
        }
        
        # Quick setup
        $quickSetup = Join-Path $installDir "quick-setup-simple.ps1"
        if (Test-Path $quickSetup) {
            log "Running quick setup..."
            Push-Location $installDir
            try {
                $setupArgs = if ($Silent) { @('-Auto') } else { @() }
                & $quickSetup @setupArgs
                log "Setup completed" 'Success'
            } catch {
                log "Setup had issues: $($_.Exception.Message)" 'Warning'
            } finally {
                Pop-Location
            }
        }
        
        # Success message
        Write-Host ""
        log "🎉 AitherZero installed successfully!" 'Success'
        Write-Host ""
        log "NEXT STEPS:" 'Info'
        Write-Host "  cd '$installDir'"
        Write-Host "  .\aither.ps1 help"
        Write-Host "  .\aither.ps1 init"
        Write-Host ""
        
    } finally {
        # Cleanup
        @($tempZip, $tempExtract) | ForEach-Object {
            if (Test-Path $_) { Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
    
} catch {
    log "Installation failed: $($_.Exception.Message)" 'Error'
    Write-Host ""
    log "TROUBLESHOOTING:" 'Warning'
    Write-Host "  1. Check internet connection"
    Write-Host "  2. Run PowerShell as Administrator"
    Write-Host "  3. Try manual download: https://github.com/$($c.Owner)/$($c.Repo)/releases"
    Write-Host ""
    exit 1
}