#!/usr/bin/env pwsh
# Emergency patch release script for v1.2.17
# Fixes critical PowerShell 5.1 compatibility issue

try {
    # Import PatchManager module
    Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "aither-core/modules/PatchManager") -Force
    
    Write-Host "Creating emergency patch release v1.2.17..." -ForegroundColor Green
    Write-Host "This fixes the critical PowerShell 5.1 compatibility issue in the packaged launcher." -ForegroundColor Yellow
    Write-Host ""
    
    # Use Invoke-ReleaseWorkflow to create v1.2.17
    $releaseResult = Invoke-ReleaseWorkflow -Version "1.2.17" -Description "Emergency fix: PowerShell 5.1 compatibility in packaged launcher" -DryRun:$false
    
    if ($releaseResult -and $releaseResult.Success) {
        Write-Host ""
        Write-Host "✅ Emergency patch release v1.2.17 created successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Release Details:" -ForegroundColor Cyan
        Write-Host "  Version: 1.2.17" -ForegroundColor White
        Write-Host "  PR Number: $($releaseResult.PRNumber)" -ForegroundColor White
        Write-Host "  PR URL: $($releaseResult.PRURL)" -ForegroundColor White
        Write-Host ""
        Write-Host "Next Steps:" -ForegroundColor Yellow
        Write-Host "  1. Monitor PR for merge: $($releaseResult.PRURL)" -ForegroundColor White
        Write-Host "  2. Release tag will be auto-created after merge" -ForegroundColor White
        Write-Host "  3. GitHub Actions will build and publish the release" -ForegroundColor White
        Write-Host ""
        
        # Return results for parsing
        Write-Output "PR_NUMBER=$($releaseResult.PRNumber)"
        Write-Output "PR_URL=$($releaseResult.PRURL)"
        Write-Output "SUCCESS=true"
    } else {
        Write-Host "❌ Release workflow failed" -ForegroundColor Red
        if ($releaseResult.Error) {
            Write-Host "Error: $($releaseResult.Error)" -ForegroundColor Red
        }
        Write-Output "SUCCESS=false"
        exit 1
    }
    
} catch {
    Write-Host "❌ Error creating emergency patch release:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Ensure you're in the correct directory" -ForegroundColor White
    Write-Host "  2. Check that PatchManager module is available" -ForegroundColor White
    Write-Host "  3. Verify git repository status" -ForegroundColor White
    Write-Output "SUCCESS=false"
    exit 1
}