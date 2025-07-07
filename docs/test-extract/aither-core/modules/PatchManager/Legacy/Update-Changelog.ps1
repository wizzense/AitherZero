function Update-Changelog {
    <#
    .SYNOPSIS
    Automatically updates the project changelog with patch information
    
    .DESCRIPTION
    Updates CHANGELOG.md with patch details, maintaining proper formatting and structure.
    Supports multiple change types and automatic commit information.
    
    .PARAMETER PatchDescription
    Description of the patch changes
    
    .PARAMETER ChangeType
    Type of change: Added, Changed, Deprecated, Removed, Fixed, Security
    
    .PARAMETER AffectedFiles
    List of files affected by the patch
    
    .PARAMETER CommitHash
    Git commit hash for reference
    
    .PARAMETER PullRequestNumber
    PR number if available
    
    .PARAMETER ProjectRoot
    Project root directory (defaults to $env:PROJECT_ROOT)
    
    .EXAMPLE
    Update-Changelog -PatchDescription "feat: add new feature" -ChangeType "Added" -AffectedFiles @("file1.ps1", "file2.ps1")
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PatchDescription,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Added", "Changed", "Deprecated", "Removed", "Fixed", "Security")]
        [string]$ChangeType = "Added",
        
        [Parameter(Mandatory = $false)]
        [string[]]$AffectedFiles = @(),
        
        [Parameter(Mandatory = $false)]
        [string]$CommitHash,
        
        [Parameter(Mandatory = $false)]
        [int]$PullRequestNumber,
        
        [Parameter(Mandatory = $false)]
        [string]$ProjectRoot = $env:PROJECT_ROOT
    )
    
    try {
        $changelogPath = Join-Path $ProjectRoot "CHANGELOG.md"
        
        if (-not (Test-Path $changelogPath)) {
            Write-Warning "CHANGELOG.md not found at $changelogPath. Creating basic changelog."
            $initialContent = @"
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

"@
            Set-Content -Path $changelogPath -Value $initialContent -Encoding UTF8
        }
        
        $content = Get-Content $changelogPath -Raw
        
        # Extract change type from patch description if not specified
        if ($ChangeType -eq "Added") {
            if ($PatchDescription -match "^fix:|^hotfix:") { $ChangeType = "Fixed" }
            elseif ($PatchDescription -match "^feat:|^feature:") { $ChangeType = "Added" }
            elseif ($PatchDescription -match "^refactor:|^style:|^perf:") { $ChangeType = "Changed" }
            elseif ($PatchDescription -match "^remove:|^delete:") { $ChangeType = "Removed" }
            elseif ($PatchDescription -match "^security:") { $ChangeType = "Security" }
            elseif ($PatchDescription -match "^deprecate:") { $ChangeType = "Deprecated" }
        }
        
        # Clean up patch description for changelog
        $cleanDescription = $PatchDescription -replace "^(feat|fix|hotfix|refactor|style|perf|remove|delete|security|deprecate):\s*", ""
        $cleanDescription = $cleanDescription.Substring(0,1).ToUpper() + $cleanDescription.Substring(1)
          # Build the changelog entry
        $entry = "- $cleanDescription"
        
        # Add reference information if available
        $references = @()
        if ($CommitHash) { $references += "commit: $($CommitHash.Substring(0,7))" }
        if ($PullRequestNumber) { $references += "PR: #$PullRequestNumber" }
        if ($AffectedFiles.Count -gt 0 -and $AffectedFiles.Count -le 3) { 
            $references += "files: $($AffectedFiles -join ', ')" 
        }
        elseif ($AffectedFiles.Count -gt 3) {
            $references += "files: $($AffectedFiles[0..2] -join ', ') + $($AffectedFiles.Count - 3) more"
        }
        
        if ($references.Count -gt 0) {
            $entry += " ($($references -join ', '))"
        }
        
        # Find the Unreleased section and add the entry
        if ($content -match "## \[Unreleased\]") {
            # Check if the change type section exists
            $sectionPattern = "### $ChangeType"
            
            if ($content -match $sectionPattern) {
                # Add to existing section
                $content = $content -replace "($sectionPattern)", "`$1`n$entry"
            } else {
                # Create new section after Unreleased
                $content = $content -replace "(## \[Unreleased\])", "`$1`n### $ChangeType`n$entry`n"
            }
        } else {
            Write-Warning "Could not find [Unreleased] section in changelog. Appending entry at the end."
            $content += "`n### $ChangeType`n$entry`n"
        }
        
        # Write the updated content
        Set-Content -Path $changelogPath -Value $content -Encoding UTF8
        
        Write-Host "✓ Updated changelog:" -ForegroundColor Green
        Write-Host "  Type: $ChangeType" -ForegroundColor Cyan
        Write-Host "  Entry: $cleanDescription" -ForegroundColor White
        if ($references.Count -gt 0) {
            Write-Host "  References: $($references -join ', ')" -ForegroundColor Gray
        }
        
        return @{
            Success = $true
            ChangelogPath = $changelogPath
            ChangeType = $ChangeType
            Entry = $entry
        }
    }
    catch {
        Write-Error "Failed to update changelog: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}
