# Import PatchManager
Import-Module ./aither-core/modules/PatchManager -Force

# Create the v1.0.0 release patch with a concise description
# The full details will be in the PR body
Invoke-PatchWorkflow -PatchDescription "Release v1.0.0 - First Stable Release" -PatchOperation {
    # Add all modified files
    git add .claude/settings.local.json
    git add .vscode/tasks.json
    git add CLAUDE.md
    git add README.md
    git add Start-AitherZero.ps1
    git add aither-core/modules/AIToolsIntegration/AIToolsIntegration.psd1
    git add aither-core/modules/OpenTofuProvider/OpenTofuProvider.psd1
    git add aither-core/modules/PatchManager/PatchManager.psd1
    git add aither-core/modules/SecureCredentials/SecureCredentials.psd1
    git add build/Build-Package.ps1
    git add docs/INSTALLATION.md
    
    # Add new files
    git add GIT-STATUS-REPORT.md
    git add aither-core/modules/LicenseManager/
    git add aither-core/modules/PatchManager/Public/Sync-GitBranch.ps1
    git add aither-core/modules/StartupExperience/
    git add configs/feature-registry.json
    git add scripts/README-GitDivergence.md
    git add requirements/2025-01-29-1408-startup-experience-overhaul/
    
    Write-Host "All files staged for v1.0.0 release"
} -CreatePR -Priority "High" -CreateIssue:$false