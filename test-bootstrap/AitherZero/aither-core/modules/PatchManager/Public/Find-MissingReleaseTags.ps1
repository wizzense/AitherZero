#Requires -Version 7.0

<#
.SYNOPSIS
    Finds merged release PRs that are missing their corresponding tags
    
.DESCRIPTION
    This function scans recent merged PRs to find release PRs that should have tags
    but don't. This helps identify broken release automation.
    
.PARAMETER Days
    Number of days back to search (default: 30)
    
.PARAMETER Fix
    Automatically create missing tags for found PRs
    
.EXAMPLE
    Find-MissingReleaseTags
    # Lists missing tags for the last 30 days
    
.EXAMPLE
    Find-MissingReleaseTags -Days 60 -Fix
    # Finds and automatically creates missing tags for the last 60 days
#>

function Find-MissingReleaseTags {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [int]$Days = 30,
        [switch]$Fix
    )
    
    begin {
        $ErrorActionPreference = 'Stop'
        
        # Find project root
        $projectRoot = Find-ProjectRoot -StartPath $PSScriptRoot
        if (-not $projectRoot) {
            throw "Could not find project root"
        }
        
        # Helper function for logging
        function Write-ScanLog {
            param([string]$Message, [string]$Level = "INFO")
            
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Level $Level -Message "MissingTagScan: $Message"
            } else {
                $color = @{
                    'INFO' = 'Cyan'
                    'SUCCESS' = 'Green'
                    'WARNING' = 'Yellow'
                    'ERROR' = 'Red'
                }[$Level]
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor $color
            }
        }
    }
    
    process {
        try {
            Write-Host ""
            Write-Host "🔍 Scanning for Missing Release Tags" -ForegroundColor Magenta
            Write-Host ("=" * 45) -ForegroundColor Magenta
            
            # Check if gh CLI is available
            if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
                throw "GitHub CLI (gh) is required but not available"
            }
            
            # Get merged PRs from the last N days
            $since = (Get-Date).AddDays(-$Days).ToString("yyyy-MM-dd")
            Write-ScanLog "Scanning merged PRs since $since..."
            
            $mergedPRs = & gh pr list --state merged --limit 100 --json number,title,mergedAt | ConvertFrom-Json
            
            # Filter for release PRs
            $releasePRs = $mergedPRs | Where-Object { 
                $_.title -match "^Release v\d+\.\d+\.\d+" -and 
                [datetime]$_.mergedAt -ge (Get-Date).AddDays(-$Days)
            }
            
            if (-not $releasePRs) {
                Write-ScanLog "No release PRs found in the last $Days days" "INFO"
                return
            }
            
            Write-ScanLog "Found $($releasePRs.Count) release PRs in the last $Days days" "INFO"
            
            # Get all existing tags
            $existingTags = & git tag -l | Where-Object { $_ -match "^v\d+\.\d+\.\d+$" }
            
            $missingTags = @()
            
            foreach ($pr in $releasePRs) {
                # Extract version from PR title
                if ($pr.title -match "Release v(\d+\.\d+\.\d+)") {
                    $version = $Matches[1]
                    $expectedTag = "v$version"
                    
                    if ($expectedTag -notin $existingTags) {
                        $missingTags += [PSCustomObject]@{
                            PRNumber = $pr.number
                            Version = $version
                            Tag = $expectedTag
                            Title = $pr.title
                            MergedAt = $pr.mergedAt
                        }
                        
                        Write-ScanLog "MISSING TAG: PR #$($pr.number) -> $expectedTag" "WARNING"
                    } else {
                        Write-ScanLog "✓ PR #$($pr.number) -> $expectedTag (exists)" "SUCCESS"
                    }
                }
            }
            
            if ($missingTags.Count -eq 0) {
                Write-Host ""
                Write-Host "✅ All release PRs have their corresponding tags!" -ForegroundColor Green
                return
            }
            
            # Report missing tags
            Write-Host ""
            Write-Host "❌ Found $($missingTags.Count) missing release tags:" -ForegroundColor Red
            Write-Host ""
            
            foreach ($missing in $missingTags) {
                Write-Host "  PR #$($missing.PRNumber): $($missing.Tag)" -ForegroundColor Yellow
                Write-Host "    Title: $($missing.Title)" -ForegroundColor Gray
                Write-Host "    Merged: $($missing.MergedAt)" -ForegroundColor Gray
                Write-Host ""
            }
            
            # Fix missing tags if requested
            if ($Fix) {
                Write-Host "🔧 Attempting to create missing tags..." -ForegroundColor Cyan
                Write-Host ""
                
                foreach ($missing in $missingTags) {
                    try {
                        Write-ScanLog "Creating tag for PR #$($missing.PRNumber): $($missing.Tag)" "INFO"
                        
                        # Extract description from title
                        $description = $missing.Title -replace "^Release v\d+\.\d+\.\d+\s*-?\s*", ""
                        if (-not $description) {
                            $description = "Release $($missing.Tag)"
                        }
                        
                        # Use the post-merge tagging function
                        Invoke-PostMergeTagging -PRNumber $missing.PRNumber -Version $missing.Version -Description $description
                        
                        Write-ScanLog "✅ Successfully created $($missing.Tag)" "SUCCESS"
                    }
                    catch {
                        Write-ScanLog "❌ Failed to create $($missing.Tag): $_" "ERROR"
                    }
                }
                
                Write-Host ""
                Write-Host "🎉 Missing tag creation completed!" -ForegroundColor Green
            }
            else {
                Write-Host "To fix these missing tags, run:" -ForegroundColor Cyan
                Write-Host "  Find-MissingReleaseTags -Fix" -ForegroundColor White
                Write-Host ""
                Write-Host "Or create them manually:" -ForegroundColor Cyan
                foreach ($missing in $missingTags) {
                    Write-Host "  Invoke-PostMergeTagging -PRNumber $($missing.PRNumber) -Description 'Release'" -ForegroundColor White
                }
            }
            
        }
        catch {
            Write-ScanLog "Missing tag scan failed: $_" "ERROR"
            Write-Host ""
            Write-Host "❌ Missing tag scan failed" -ForegroundColor Red
            Write-Host "Error: $_" -ForegroundColor Red
            throw
        }
    }
}

# Export the function
Export-ModuleMember -Function Find-MissingReleaseTags