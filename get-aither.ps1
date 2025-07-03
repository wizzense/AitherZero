# AitherZero Get Script - Compact & Readable
# Optimized for one-liner execution: iex (iwr https://raw.githubusercontent.com/wizzense/AitherZero/main/get-aither.ps1).Content

param(
    [string]$InstallPath = $PWD.Path,
    [switch]$Silent
)

# PowerShell 5.1+ compatibility
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Status($msg, $color = 'Cyan') {
    if (-not $Silent) { Write-Host $msg -ForegroundColor $color }
}

try {
    Write-Status "🚀 Getting AitherZero..."
    
    # Simple API call to get latest release
    $api = "https://api.github.com/repos/wizzense/AitherZero/releases/latest"
    $release = Invoke-RestMethod $api
    $windowsAsset = $release.assets | Where-Object { $_.name -like "*-windows-*.zip" } | Select-Object -First 1
    
    if (-not $windowsAsset) {
        throw "No Windows release found"
    }
    
    # Download and extract
    Write-Status "📦 Downloading..."
    $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) "AitherZero-$(Get-Date -Format 'yyyyMMdd-HHmmss').zip"
    Invoke-WebRequest $windowsAsset.browser_download_url -OutFile $tempZip
    
    Write-Status "📂 Extracting..."
    $extractPath = Join-Path $InstallPath "AitherZero"
    
    # Remove existing installation if present
    if (Test-Path $extractPath) {
        Remove-Item $extractPath -Recurse -Force
    }
    
    Expand-Archive $tempZip -DestinationPath $InstallPath -Force
    
    # Find extracted directory (GitHub creates versioned folders)
    $extractedDir = Get-ChildItem $InstallPath -Directory | Where-Object { $_.Name -like "AitherZero*" } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    
    if ($extractedDir -and $extractedDir.Name -ne "AitherZero") {
        Rename-Item $extractedDir.FullName $extractPath
    }
    
    # Cleanup
    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
    
    # Quick setup
    Push-Location $extractPath
    try {
        Write-Status "⚙️ Running setup..."
        if (Test-Path "quick-setup-simple.ps1") {
            & ".\quick-setup-simple.ps1" -Auto
        }
        
        Write-Status "✅ AitherZero ready at: $extractPath" 'Green'
        Write-Status "🎯 Quick start:" 'Yellow'
        Write-Status "   cd '$extractPath'" 'White'
        Write-Status "   .\aither.ps1 help" 'White'
        
    } finally {
        Pop-Location
    }
    
} catch {
    Write-Status "❌ Failed: $($_.Exception.Message)" 'Red'
    Write-Status "📖 Manual download: https://github.com/wizzense/AitherZero/releases" 'Yellow'
    exit 1
}