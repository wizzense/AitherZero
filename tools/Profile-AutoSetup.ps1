# OpenTofu Lab Automation - Auto Setup
# Add this to your PowerShell profile: $PROFILE

# Set PROJECT_ROOT if in the project directory
if (Test-Path "aither-core/modules" -and Test-Path "PROJECT-MANIFEST.json") {
    $env:PROJECT_ROOT = (Get-Location).Path
    $env:PWSH_MODULES_PATH = "$env:PROJECT_ROOT/aither-core/modules"
    
    Write-Host "🚀 OpenTofu Lab Environment Auto-Configured" -ForegroundColor Green
    Write-Host "   PROJECT_ROOT: $env:PROJECT_ROOT" -ForegroundColor Cyan
    Write-Host "   MODULES_PATH: $env:PWSH_MODULES_PATH" -ForegroundColor Cyan
    
    # Auto-import frequently used modules
    $commonModules = @('Logging', 'PatchManager', 'DevEnvironment')
    foreach ($module in $commonModules) {
        try {
            Import-Module "$env:PWSH_MODULES_PATH/$module" -Force -ErrorAction SilentlyContinue
            Write-Host "   ✓ $module" -ForegroundColor Green
        } catch {
            Write-Host "   ⚠ $module (not available)" -ForegroundColor Yellow
        }
    }
}
