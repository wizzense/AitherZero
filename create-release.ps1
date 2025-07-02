# Create Release Script - Full demonstration of PatchManager release workflow

Write-Host "`n🚀 Creating Release with PatchManager" -ForegroundColor Cyan
Write-Host "Current Version: 1.3.1" -ForegroundColor Gray

# Find project root and import PatchManager
. ./aither-core/shared/Find-ProjectRoot.ps1
$projectRoot = Find-ProjectRoot
Import-Module (Join-Path $projectRoot "aither-core/modules/PatchManager") -Force

Write-Host "`n📋 Release Details:" -ForegroundColor Yellow
Write-Host "  Release Type: patch (1.3.1 -> 1.3.2)" -ForegroundColor White
Write-Host "  Description: Testing infrastructure improvements and GitHub Actions fixes" -ForegroundColor White
Write-Host "  Changes:" -ForegroundColor White
Write-Host "    - Created missing scripts (Generate-APIDocs.ps1, Test-PackageIntegrity.ps1, Sync-ToAitherLabs.ps1)" -ForegroundColor Gray
Write-Host "    - Fixed GitHub Actions workflow YAML syntax issues" -ForegroundColor Gray
Write-Host "    - Added concurrency control to CI/CD pipeline" -ForegroundColor Gray
Write-Host "    - Updated PowerShell installation to use latest stable version" -ForegroundColor Gray
Write-Host "    - Enhanced build validation with comprehensive integrity checks" -ForegroundColor Gray

Write-Host "`n🔧 Using Invoke-ReleaseWorkflow for automated release..." -ForegroundColor Cyan

# Create the release
try {
    $releaseParams = @{
        ReleaseType = "patch"
        Description = "Testing infrastructure improvements and GitHub Actions fixes"
        DryRun = $false  # Set to true to preview without creating PR
    }
    
    Write-Host "`nInvoking release workflow..." -ForegroundColor Yellow
    Invoke-ReleaseWorkflow @releaseParams
    
    Write-Host "`n✅ Release workflow initiated successfully!" -ForegroundColor Green
    Write-Host "Check GitHub for the new PR and monitor the CI/CD pipeline" -ForegroundColor Cyan
    
} catch {
    Write-Host "`n❌ Release failed: $_" -ForegroundColor Red
    exit 1
}