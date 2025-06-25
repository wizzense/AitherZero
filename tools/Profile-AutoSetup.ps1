# OpenTofu Lab Automation - Auto Setup
# Add this to your PowerShell profile: $PROFILE

# Set PROJECT_ROOT if in the project directory
if (Test-Path "aither-core/modules" -and Test-Path "PROJECT-MANIFEST.json") {
    $env:PROJECT_ROOT = (Get-Location).Path
    $env:PWSH_MODULES_PATH = "$env:PROJECT_ROOT/aither-core/modules"

    # Import logging first for consistent output
    try {
        Import-Module "$env:PWSH_MODULES_PATH/Logging" -Force -ErrorAction SilentlyContinue
        Write-CustomLog -Level 'SUCCESS' -Message "OpenTofu Lab Environment Auto-Configured"
        Write-CustomLog -Level 'INFO' -Message "   PROJECT_ROOT: $env:PROJECT_ROOT"
        Write-CustomLog -Level 'INFO' -Message "   MODULES_PATH: $env:PWSH_MODULES_PATH"
    } catch {
        # Fallback to Write-Host if logging isn't available
        Write-Host "OpenTofu Lab Environment Auto-Configured" -ForegroundColor Green
        Write-Host "   PROJECT_ROOT: $env:PROJECT_ROOT" -ForegroundColor Cyan
        Write-Host "   MODULES_PATH: $env:PWSH_MODULES_PATH" -ForegroundColor Cyan
    }

    # Auto-import frequently used modules
    $commonModules = @('Logging', 'PatchManager', 'DevEnvironment')
    foreach ($module in $commonModules) {
        try {
            Import-Module "$env:PWSH_MODULES_PATH/$module" -Force -ErrorAction SilentlyContinue
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Level 'SUCCESS' -Message "   Module: $module"
            } else {
                Write-Host "   ✓ $module" -ForegroundColor Green
            }
        } catch {
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Level 'WARN' -Message "   Module: $module (not available)"
            } else {
                Write-Host "   ⚠ $module (not available)" -ForegroundColor Yellow
            }
        }
    }
}