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
        Write-SmartLog "DRY RUN: Would trigger release workflow with above parameters" "WARN"
        Write-SmartLog "Command that would be executed:"
        Write-Host "  gh workflow run release.yml" -ForegroundColor Gray
        foreach ($key in $params.Keys) {
            Write-Host "    --field $key=$($params[$key])" -ForegroundColor Gray
        }
        exit 0
    }
    
    # Trigger the release workflow
    Write-SmartLog "Triggering smart release workflow..." "SUCCESS"
    
    $cmd = "gh workflow run release.yml"
    foreach ($key in $params.Keys) {
        $cmd += " --field $key=$($params[$key])"
    }
    
    $result = Invoke-Expression $cmd 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-SmartLog "Release workflow triggered successfully!" "SUCCESS"
        Write-SmartLog "Benefits achieved:"
        Write-SmartLog "  ✅ No CI re-run (saves ~5 minutes)" "SUCCESS"
        Write-SmartLog "  ✅ No Audit re-run (saves ~2 minutes)" "SUCCESS"  
        Write-SmartLog "  ✅ Only Release + Security workflows run" "SUCCESS"
        Write-SmartLog "  ✅ Total time savings: ~7 minutes" "SUCCESS"
        
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
        Write-SmartLog "Failed to trigger release workflow: $result" "ERROR"
        exit 1
    }
    
} catch {
    Write-SmartLog "Smart release failed: $($_.Exception.Message)" "ERROR"
    exit 1
}

Write-SmartLog "Smart release trigger complete! 🚀" "SUCCESS"