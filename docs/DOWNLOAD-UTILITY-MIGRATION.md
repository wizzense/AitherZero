# Example: Migrating from Invoke-WebRequest to Invoke-FileDownload

<#
.SYNOPSIS
    Example showing how to migrate scripts from Invoke-WebRequest to Invoke-FileDownload

.DESCRIPTION
    This example demonstrates the before/after patterns for upgrading download logic
    to use the new DownloadUtility module with intelligent retry and resume capabilities.
#>

# ============================================================================
# BEFORE: Using Invoke-WebRequest (old pattern)
# ============================================================================

function Old-DownloadPattern {
    param($downloadUrl, $installerPath)
    
    # OLD: Manual progress suppression and basic error handling
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
        $ProgressPreference = 'Continue'
    } catch {
        Write-Error "Failed to download: $_"
        throw
    }
}

# ============================================================================
# AFTER: Using Invoke-FileDownload (new pattern)
# ============================================================================

function New-DownloadPattern {
    param($downloadUrl, $installerPath)
    
    # NEW: Intelligent download with retry, resume, and validation
    $result = Invoke-FileDownload -Uri $downloadUrl `
        -OutFile $installerPath `
        -UseBasicParsing `
        -RetryCount 3 `
        -RetryDelaySeconds 2
    
    if (-not $result.Success) {
        Write-Error "Failed to download after $($result.Attempts) attempts: $($result.Message)"
        throw
    }
    
    Write-Host "Downloaded successfully via $($result.Method): $($result.FileSize) bytes"
}

# ============================================================================
# COMPLETE EXAMPLE: Updating an installation script
# ============================================================================

<#
# BEFORE: Lines 165-170 in 0209_Install-7Zip.ps1
Write-ScriptLog "Downloading from: $downloadUrl"
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri $downloadUrl -OutFile $tempInstaller -UseBasicParsing
$ProgressPreference = 'Continue'
Write-ScriptLog "Downloaded to: $tempInstaller"

# AFTER: Improved version with DownloadUtility
Write-ScriptLog "Downloading from: $downloadUrl"
$downloadResult = Invoke-FileDownload -Uri $downloadUrl `
    -OutFile $tempInstaller `
    -UseBasicParsing `
    -RetryCount 3

if (-not $downloadResult.Success) {
    throw "Download failed: $($downloadResult.Message)"
}

Write-ScriptLog "Downloaded successfully: $($downloadResult.FileSize) bytes in $($downloadResult.Duration.TotalSeconds.ToString('F2'))s"
Write-ScriptLog "Download method: $($downloadResult.Method)"
#>

# ============================================================================
# MIGRATION CHECKLIST
# ============================================================================

<#
For each script using Invoke-WebRequest for downloads:

1. Import or ensure DownloadUtility is available:
   - The module is automatically loaded via AitherZero.psm1
   - No manual import needed in automation scripts

2. Replace the download block:
   OLD:
   ```powershell
   $ProgressPreference = 'SilentlyContinue'
   Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing
   $ProgressPreference = 'Continue'
   ```
   
   NEW:
   ```powershell
   $result = Invoke-FileDownload -Uri $url -OutFile $file -UseBasicParsing
   if (-not $result.Success) {
       throw "Download failed: $($result.Message)"
   }
   ```

3. Benefits you get automatically:
   - ✅ Retry logic with exponential backoff
   - ✅ Intelligent resume for interrupted downloads
   - ✅ File size validation (Content-Length checking)
   - ✅ Idempotent downloads (cached file detection)
   - ✅ Clean console output (no progress bars)
   - ✅ BITS optimization on Windows
   - ✅ Cross-platform compatibility
   - ✅ Detailed logging and metrics

4. Optional enhancements:
   ```powershell
   $result = Invoke-FileDownload -Uri $url `
       -OutFile $file `
       -UseBasicParsing `
       -RetryCount 5 `              # Custom retry count
       -RetryDelaySeconds 3 `       # Custom retry delay
       -Force `                     # Force re-download
       -Method BITS                 # Force specific method
   ```
#>

# ============================================================================
# TESTING THE MIGRATION
# ============================================================================

<#
After migrating a script:

1. Test basic download:
   ./automation-scripts/XXXX_Your-Script.ps1 -WhatIf

2. Test with existing file (caching):
   # Run once to download
   ./automation-scripts/XXXX_Your-Script.ps1
   # Run again - should use cached file
   ./automation-scripts/XXXX_Your-Script.ps1

3. Test retry logic:
   # Temporarily modify URL to invalid
   # Verify it retries 3 times with exponential backoff

4. Test on different platforms:
   # Windows - should use BITS
   # Linux/macOS - should use WebRequest
#>

# ============================================================================
# SCRIPTS READY FOR MIGRATION (Priority Order)
# ============================================================================

<#
High Priority (Large downloads):
1. 0201_Install-Node.ps1 (line 200) - Node.js installer (~50MB)
2. 0206_Install-Python.ps1 (line 185) - Python installer (~30MB)
3. 0207_Install-Git.ps1 (line 143) - Git installer (~50MB)
4. 0208_Install-Docker.ps1 (line 169) - Docker installer (~100MB+)
5. 0210_Install-VSCode.ps1 (line 181) - VS Code installer (~80MB)

Medium Priority (Medium downloads):
6. 0007_Install-Go.ps1 (line 183) - Go installer (~15MB)
7. 0008_Install-OpenTofu.ps1 (lines 110, 156, 184) - OpenTofu binary (~10MB)
8. 0209_Install-7Zip.ps1 (line 168) - 7-Zip installer (~1.5MB)
9. 0211_Install-VSBuildTools.ps1 (line 122) - Build tools installer
10. 0212_Install-AzureCLI.ps1 (line 170) - Azure CLI installer

Lower Priority (Small downloads or utilities):
11. 0106_Install-WSL2.ps1 (line 160) - WSL2 kernel update
12. 0107_Install-WindowsAdminCenter.ps1 (lines 144, 151) - Admin center
13. 0205_Install-Sysinternals.ps1 (line 120) - Sysinternals suite
14. 0213_Install-AWSCLI.ps1 (lines 97, 161, 201) - AWS CLI
15. 0214_Install-Packer.ps1 (line 157) - Packer binary
16. 0442_Install-Act.ps1 (lines 81, 103) - Act binary
17. 0720_Setup-GitHubRunners.ps1 (line 219) - GitHub runner
18. domains/utilities/Bootstrap.psm1 (lines 218, 280, 435, 494, 513)
19. domains/development/DeveloperTools.psm1 (line 513)

API calls (keep as Invoke-WebRequest):
- 0500_Validate-Environment.ps1 (HEAD requests only)
- 0709_Post-PRComment.ps1 (API POST)
- 0860_Validate-Deployments.ps1 (HEAD requests only)
- 0900_Test-SelfDeployment.ps1 (connectivity test)
#>

# ============================================================================
# EXAMPLE: Complete before/after for 0201_Install-Node.ps1
# ============================================================================

<#
BEFORE (Lines 196-205):
---
$installerPath = Join-Path $tempDir 'node-installer.msi'

# Download installer
Write-ScriptLog "Downloading Node.js installer from $downloadUrl"
try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
    $ProgressPreference = 'Continue'
} catch {
    Write-ScriptLog "Failed to download Node.js installer: $_" -Level 'Error'
    throw
}
---

AFTER (Improved):
---
$installerPath = Join-Path $tempDir 'node-installer.msi'

# Download installer using intelligent download utility
Write-ScriptLog "Downloading Node.js installer from $downloadUrl"
$downloadResult = Invoke-FileDownload -Uri $downloadUrl `
    -OutFile $installerPath `
    -UseBasicParsing `
    -RetryCount 3 `
    -RetryDelaySeconds 2

if (-not $downloadResult.Success) {
    Write-ScriptLog "Failed to download Node.js installer after $($downloadResult.Attempts) attempts: $($downloadResult.Message)" -Level 'Error'
    throw
}

Write-ScriptLog "Downloaded successfully: $($downloadResult.FileSize) bytes via $($downloadResult.Method) in $($downloadResult.Duration.TotalSeconds.ToString('F2'))s"
---

Benefits:
- Automatic retry on network failures
- Resume capability if download interrupted
- File size validation
- Uses BITS on Windows (no console flooding)
- Cached file reuse (idempotent)
- Better logging and diagnostics
#>
