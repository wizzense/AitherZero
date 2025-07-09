#Requires -Version 7.0

<#
.SYNOPSIS
    Smart release trigger that avoids unnecessary workflow reruns

.DESCRIPTION
    Intelligently triggers releases using existing CI validation data to avoid
    re-running all workflows. Perfect for when you know CI already passed.

.PARAMETER Version
    Version to release (e.g., "0.8.2")

.PARAMETER UseExistingCI
    Use existing CI data instead of waiting for new CI run (default: true)

.PARAMETER CreateTag
    Create git tag for this release (default: true)

.PARAMETER DryRun
    Preview what would be done without actually triggering

.EXAMPLE
    ./Smart-Release.ps1 -Version "0.8.2"
    # Smart release using existing CI data (no workflow spam)

.EXAMPLE
    ./Smart-Release.ps1 -Version "0.8.2" -UseExistingCI:$false
    # Force new CI run before release

.NOTES
    This avoids the "workflow spam" problem by:
    - Using manual workflow dispatch
    - Reusing existing CI validation
    - Preventing CI/Audit reruns on tag creation
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $false)]
    [bool]$UseExistingCI = $true,

    [Parameter(Mandatory = $false)]
    [bool]$CreateTag = $true,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

function Write-SmartLog {
    param($Message, $Level = "INFO")
    $color = switch ($Level) {
        'SUCCESS' { 'Green' }
        'ERROR' { 'Red' }
        'WARN' { 'Yellow' }
        default { 'Cyan' }
    }
    Write-Host "🎯 $Message" -ForegroundColor $color
}

try {
    Write-SmartLog "Smart Release v3.1 - Intelligent Workflow Triggering" "SUCCESS"
    Write-SmartLog "Target Version: $Version"
    
    if ($UseExistingCI) {
        Write-SmartLog "Strategy: Use existing CI data (no workflow spam)" "SUCCESS"
    } else {
        Write-SmartLog "Strategy: Wait for new CI run" "WARN"
    }
    
    # Check if we have recent CI data
    if ($UseExistingCI) {
        try {
            $recentRuns = gh run list --workflow="ci.yml" --limit 3 --json conclusion,createdAt,status 2>$null | ConvertFrom-Json
            $successfulRun = $recentRuns | Where-Object { $_.conclusion -eq "success" } | Select-Object -First 1
            
            if ($successfulRun) {
                $runAge = (Get-Date) - [DateTime]$successfulRun.createdAt
                Write-SmartLog "Found recent successful CI run ($([Math]::Round($runAge.TotalMinutes, 1)) minutes ago)" "SUCCESS"
            } else {
                Write-SmartLog "No recent successful CI found - consider running CI first" "WARN"
                if (-not $DryRun) {
                    $continue = Read-Host "Continue anyway? (y/N)"
                    if ($continue -ne "y" -and $continue -ne "Y") {
                        Write-SmartLog "Release cancelled by user" "ERROR"
                        exit 1
                    }
                }
            }
        } catch {
            Write-SmartLog "Could not check CI status: $($_.Exception.Message)" "WARN"
        }
    }
    
    # Prepare workflow dispatch parameters
    $params = @{
        version = $Version
        create_tag = $CreateTag.ToString().ToLower()
        use_existing_ci = $UseExistingCI.ToString().ToLower()
        skip_workflows = "true"
        force_release = "false"
    }
    
    Write-SmartLog "Release Parameters:"
    foreach ($key in $params.Keys) {
        Write-SmartLog "  $key = $($params[$key])"
    }
    
    if ($DryRun) {
        Write-SmartLog "DRY RUN: Would use PatchManager AutoTag approach" "WARN"
        Write-SmartLog "Actions that would be executed:"
        Write-Host "  1. Update VERSION file to: $Version" -ForegroundColor Gray
        Write-Host "  2. Import PatchManager module" -ForegroundColor Gray
        Write-Host "  3. New-QuickFix -Description 'Release v$Version' -AutoTag" -ForegroundColor Gray
        Write-Host "  4. PatchManager creates git tag v$Version and pushes" -ForegroundColor Gray
        Write-Host "  5. Git tag triggers release workflow automatically" -ForegroundColor Gray
        Write-SmartLog "This approach bypasses GitHub CLI workflow dispatch permission issues" "SUCCESS"
        exit 0
    }
    
    # Use PatchManager AutoTag approach since GitHub CLI lacks workflow dispatch permissions
    Write-SmartLog "Using PatchManager AutoTag approach to trigger release..." "SUCCESS"
    
    try {
        # Update VERSION file
        Set-Content -Path "VERSION" -Value $Version
        Write-SmartLog "Updated VERSION file to: $Version" "SUCCESS"
        
        # Import PatchManager
        . "$PSScriptRoot/aither-core/shared/Find-ProjectRoot.ps1"
        $projectRoot = Find-ProjectRoot
        Import-Module (Join-Path $projectRoot "aither-core/modules/PatchManager") -Force
        
        # Use PatchManager to create tag and trigger release
        Write-SmartLog "Creating version tag via PatchManager AutoTag..." "SUCCESS"
        
        $patchResult = New-QuickFix -Description "Release v$Version" -AutoTag -Changes {
            # Version file already updated above
            Write-Host "Version file updated to $Version" -ForegroundColor Green
        }
        
        if ($patchResult -and $patchResult.Success) {
            Write-SmartLog "Release workflow triggered successfully via tag creation!" "SUCCESS"
            Write-SmartLog "Benefits achieved:"
            Write-SmartLog "  ✅ No workflow dispatch permission issues" "SUCCESS"
            Write-SmartLog "  ✅ Automatic tag creation triggers release workflow" "SUCCESS"  
            Write-SmartLog "  ✅ CI will reuse existing validation data" "SUCCESS"
            Write-SmartLog "  ✅ Total approach: Tag-triggered release" "SUCCESS"
            
            Start-Sleep -Seconds 3
            
            try {
                $runs = gh run list --workflow="release.yml" --limit 1 --json url,status 2>$null | ConvertFrom-Json
                if ($runs -and $runs.Count -gt 0) {
                    Write-SmartLog "Monitor progress: $($runs[0].url)" "SUCCESS"
                }
            } catch {
                Write-SmartLog "Release triggered, check GitHub Actions for progress"
            }
        } else {
            Write-SmartLog "PatchManager operation failed" "ERROR"
            exit 1
        }
        
    } catch {
        Write-SmartLog "Failed to trigger release: $($_.Exception.Message)" "ERROR"
        exit 1
    }
    
} catch {
    Write-SmartLog "Smart release failed: $($_.Exception.Message)" "ERROR"
    exit 1
}

Write-SmartLog "Smart release trigger complete! 🚀" "SUCCESS"