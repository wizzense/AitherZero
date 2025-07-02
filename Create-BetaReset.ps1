# Import PatchManager
Import-Module './aither-core/modules/PatchManager' -Force

Write-Host "Creating v0.5-beta reset PR..." -ForegroundColor Cyan

# Use New-Feature to create a PR for the reset
New-Feature -Description 'Reset project to v0.5-beta - Fix ConfigurationCore syntax errors and prepare for fresh start' -Changes {
    # Update VERSION file
    Set-Content './VERSION' -Value '0.5-beta' -NoNewline
    Write-Host "✅ Updated VERSION to 0.5-beta" -ForegroundColor Green
    
    # Create a new CHANGELOG
    $changelogContent = @'
# CHANGELOG

## [0.5-beta] - 2025-01-02

### 🎉 Fresh Start - Beta Release

This marks a complete reset of the AitherZero project versioning to establish a clean release history.

### Fixed
- **Critical**: Fixed PowerShell syntax errors in ConfigurationCore module
  - Corrected variable interpolation in error messages using `${variableName}:` syntax
  - Resolved "Variable reference is not valid" errors preventing module loading
  - Fixed 5 instances in Validate-Configuration.ps1
  - Fixed 1 instance in Invoke-ConfigurationReload.ps1

### Changed
- Reset version numbering from v1.4.3 to v0.5-beta
- Cleaned up all previous tags and releases for a fresh start
- Established new release strategy: beta → release candidate → stable

### Added
- Comprehensive test suite for ConfigurationCore module
- Backup of all previous tags and releases for reference

### Technical Details
- All 29 previous tags removed (v1.0.0 through v1.4.3)
- All 16 GitHub releases archived and removed
- Clean git history maintained with proper commit tracking

### Next Steps
- Continue beta development (0.5 → 0.6 → 0.7 → 0.8 → 0.9)
- Release candidates (1.0.0-rc1, 1.0.0-rc2, etc.)
- First stable release (1.0.0)

---

*Previous release history has been archived in backup-before-reset/*
'@
    Set-Content './CHANGELOG.md' -Value $changelogContent
    Write-Host "✅ Created fresh CHANGELOG.md" -ForegroundColor Green
    
    # Update README with beta notice
    $readmeContent = Get-Content './README.md' -Raw
    if ($readmeContent -notmatch '## Beta Notice') {
        $betaNotice = @'

## Beta Notice

> **⚠️ This is a beta release (v0.5-beta)**  
> AitherZero is currently in beta. While core functionality is stable, you may encounter bugs or incomplete features.  
> We welcome feedback and contributions!

'@
        # Insert after the main title
        $readmeContent = $readmeContent -replace '(# AitherZero.*?\n)', "`$1`n$betaNotice"
        Set-Content './README.md' -Value $readmeContent
        Write-Host "✅ Added beta notice to README.md" -ForegroundColor Green
    }
    
    # Clean up temporary files
    Remove-Item './delete-all-tags.ps1' -ErrorAction SilentlyContinue
    Remove-Item './delete-remote-tags.ps1' -ErrorAction SilentlyContinue
    Remove-Item './delete-github-releases.ps1' -ErrorAction SilentlyContinue
    Remove-Item './backup-tags-and-releases.ps1' -ErrorAction SilentlyContinue
    Remove-Item './.last_backup_dir' -ErrorAction SilentlyContinue
    Write-Host "✅ Cleaned up temporary files" -ForegroundColor Green
}

Write-Host "`nPR creation initiated. Follow the prompts to complete the process." -ForegroundColor Yellow