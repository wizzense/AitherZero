# AitherZero Ultra-Simple Bootstrap
# PowerShell 5.1+ Compatible - Clean one-liner installation

# Enable TLS 1.2 for PowerShell 5.1 compatibility
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    Write-Host "🚀 Downloading AitherZero..." -ForegroundColor Cyan
    
    # Get latest Windows release
    $release = Invoke-RestMethod "https://api.github.com/repos/wizzense/AitherZero/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -like "*-windows-*.zip" } | Select-Object -First 1
    
    if (-not $asset) { 
        throw "No Windows release found. Try manual download from: https://github.com/wizzense/AitherZero/releases"
    }
    
    # Download and extract
    $zipFile = "AitherZero.zip"
    Invoke-WebRequest $asset.browser_download_url -OutFile $zipFile
    Expand-Archive $zipFile -DestinationPath "." -Force
    Remove-Item $zipFile
    
    # Find and enter AitherZero directory
    $folder = Get-ChildItem -Directory | Where-Object { $_.Name -like "AitherZero*" } | Select-Object -First 1
    if (-not $folder) { throw "AitherZero directory not found after extraction" }
    
    Set-Location $folder.Name
    Write-Host "✅ AitherZero downloaded to: $($folder.FullName)" -ForegroundColor Green
    
    # Auto-start with best available method
    if (Test-Path "quick-setup-simple.ps1") {
        Write-Host "🔧 Running automated setup..." -ForegroundColor Yellow
        & ".\quick-setup-simple.ps1" -Auto
    } elseif (Test-Path "aither.ps1") {
        Write-Host "🔧 Starting AitherZero CLI..." -ForegroundColor Yellow
        & ".\aither.ps1" init --auto
    } elseif (Test-Path "Start-AitherZero.ps1") {
        Write-Host "🔧 Starting AitherZero..." -ForegroundColor Yellow
        & ".\Start-AitherZero.ps1" -Auto
    } else {
        Write-Host "✅ Ready! Run one of:" -ForegroundColor Green
        Write-Host "  .\aither.ps1 init" -ForegroundColor White
        Write-Host "  .\Start-AitherZero.ps1" -ForegroundColor White
    }
    
} catch {
    Write-Host "❌ Installation failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "📖 Manual installation: https://github.com/wizzense/AitherZero/releases" -ForegroundColor Yellow
    exit 1
}