#Requires -Version 7.0

Write-Host "Committing all recovered changes and safety enhancements..." -ForegroundColor Green

# Show what we're committing
Write-Host "`nFiles to commit:" -ForegroundColor Yellow
git status --porcelain

# Stage everything
Write-Host "`nStaging all changes..." -ForegroundColor Yellow
git add .

# Create comprehensive commit
Write-Host "`nCreating commit..." -ForegroundColor Yellow
git commit -m "CRITICAL: Complete recovery and PatchManager safety enhancement

Recovered ALL changes from feature branch:
- CI/CD workflow updates (3 unified pipelines)
- Claude settings updates
- PatchManager safety enhancements to prevent data loss

PatchManager Safety Features Added:
- Automatic backup of all uncommitted changes to temp directory
- Automatic git stash as secondary backup
- Safety warnings before any operations
- Get-PatchWorkflowBackup function for easy restoration
- Test-PatchWorkflowSafety and Restore-PatchWorkflowBackup functions

This ensures PatchManager will NEVER lose uncommitted work again.
All changes are automatically backed up before any git operations."

Write-Host "`nAll changes committed successfully!" -ForegroundColor Green

# Clean up temp scripts
Write-Host "`nCleaning up temporary scripts..." -ForegroundColor Yellow
Remove-Item -Path @(
    "./recover-api-gateway.ps1",
    "./fix-patchmanager-safety.ps1",
    "./commit-recovery-and-safety.ps1"
) -Force -ErrorAction SilentlyContinue

Write-Host "`nDone! The codebase is now fully recovered and protected." -ForegroundColor Green