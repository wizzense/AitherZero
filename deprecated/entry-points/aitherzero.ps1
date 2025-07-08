# AitherZero Universal Launcher
# Works with any PowerShell version - automatically uses PowerShell 7 if available

# Don't use #Requires - we want this to work in PS5 too
param(
    [switch]$Setup,
    [switch]$Auto,
    [string]$Scripts,
    [switch]$Help
)

Write-Host ""
Write-Host "AitherZero Universal Launcher" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host ""

# Check if we're in PowerShell 7+
if ($PSVersionTable.PSVersion.Major -ge 7) {
    # We're already in PS7, just run the main script
    & "$PSScriptRoot\Start-AitherZero.ps1" @PSBoundParameters
    exit $LASTEXITCODE
}

# We're in an older PowerShell, need to find PS7
Write-Host "Detected PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
Write-Host "Looking for PowerShell 7..." -ForegroundColor Yellow

$pwsh7 = $null

# Windows paths
if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or $env:OS -eq 'Windows_NT') {
    $paths = @(
        "C:\Program Files\PowerShell\7\pwsh.exe",
        "C:\Program Files\PowerShell\7-preview\pwsh.exe",
        "$env:ProgramFiles\PowerShell\7\pwsh.exe"
    )

    foreach ($path in $paths) {
        if (Test-Path $path) {
            $pwsh7 = $path
            break
        }
    }
}

# Unix paths
if (-not $pwsh7) {
    $paths = @("/usr/local/bin/pwsh", "/usr/bin/pwsh", "/opt/microsoft/powershell/7/pwsh")
    foreach ($path in $paths) {
        if (Test-Path $path) {
            $pwsh7 = $path
            break
        }
    }
}

# Try command lookup
if (-not $pwsh7) {
    try {
        $cmd = Get-Command pwsh -ErrorAction SilentlyContinue
        if ($cmd) {
            $pwsh7 = $cmd.Source
        }
    } catch {
        # Ignore errors
    }
}

if ($pwsh7) {
    Write-Host "Found PowerShell 7 at: $pwsh7" -ForegroundColor Green
    Write-Host "Launching AitherZero with PowerShell 7..." -ForegroundColor Cyan
    Write-Host ""

    # Build arguments
    $args = @('-NoProfile', '-File', "$PSScriptRoot\Start-AitherZero.ps1")
    if ($Setup) { $args += '-Setup' }
    if ($Auto) { $args += '-Auto' }
    if ($Scripts) { $args += '-Scripts'; $args += $Scripts }
    if ($Help) { $args += '-Help' }

    & $pwsh7 $args
    exit $LASTEXITCODE
} else {
    Write-Host ""
    Write-Host "ERROR: PowerShell 7 is required but not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install PowerShell 7:" -ForegroundColor Yellow
    Write-Host ""

    if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or $env:OS -eq 'Windows_NT') {
        Write-Host "  Option 1: winget install Microsoft.PowerShell" -ForegroundColor Cyan
        Write-Host "  Option 2: Download from https://aka.ms/powershell-release" -ForegroundColor Cyan
    } else {
        Write-Host "  Visit: https://docs.microsoft.com/powershell/scripting/install/installing-powershell" -ForegroundColor Cyan
    }

    Write-Host ""
    Write-Host "After installing, run this script again." -ForegroundColor Yellow
    exit 1
}
