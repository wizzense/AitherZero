#Requires -Version 7.0

<#
.SYNOPSIS
    Monitor and automatically tag releases when release PRs are merged
    
.DESCRIPTION
    This function monitors for merged release PRs and automatically creates
    the corresponding version tags to trigger GitHub Actions builds.
    
.PARAMETER PRNumber
    Specific PR number to monitor
    
.PARAMETER Version
    Expected version to tag after merge
    
.PARAMETER Description
    Release description for the tag
    
.PARAMETER MaxWaitMinutes
    Maximum minutes to wait for PR merge (default: 30)
    
.EXAMPLE
    Watch-ReleasePR -PRNumber 204 -Version "1.2.16" -Description "Enhanced automation"
    
.EXAMPLE
    Watch-ReleasePR -PRNumber 204 -Version "1.2.16" -Description "Bug fixes" -MaxWaitMinutes 60
#>

function Watch-ReleasePR {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PRNumber,
        
        [Parameter(Mandatory)]
        [string]$Version,
        
        [Parameter(Mandatory)]
        [string]$Description,
        
        [int]$MaxWaitMinutes = 30
    )
    
    begin {
        # Helper function for logging
        function Write-WatchLog {
            param([string]$Message, [string]$Level = "INFO")
            
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Level $Level -Message "Watch-ReleasePR: $Message"
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
        $startTime = Get-Date
        $timeout = $startTime.AddMinutes($MaxWaitMinutes)
        
        Write-WatchLog "Monitoring PR #$PRNumber for merge (timeout: $MaxWaitMinutes minutes)..."
        
        # Check if gh CLI is available
        $ghAvailable = Get-Command gh -ErrorAction SilentlyContinue
        
        if (-not $ghAvailable) {
            Write-WatchLog "GitHub CLI not available. Please merge PR manually and run:" "WARNING"
            Write-WatchLog "  git tag -a 'v$Version' -m 'Release v$Version - $Description'" "WARNING"
            Write-WatchLog "  git push origin 'v$Version'" "WARNING"
            return $false
        }
        
        while ((Get-Date) -lt $timeout) {
            try {
                $prStatus = & gh pr view $PRNumber --json state,mergedAt 2>$null | ConvertFrom-Json
                
                if ($prStatus.state -eq "MERGED") {
                    Write-WatchLog "PR #$PRNumber has been merged!" "SUCCESS"
                    
                    # Sync with remote to get latest changes
                    Write-WatchLog "Syncing with remote..." "INFO"
                    git fetch origin main 2>&1 | Out-Null
                    git checkout main 2>&1 | Out-Null
                    git pull origin main 2>&1 | Out-Null
                    
                    # Verify VERSION file was updated
                    $currentVersion = (Get-Content "VERSION" -Raw).Trim()
                    if ($currentVersion -eq $Version) {
                        Write-WatchLog "VERSION file confirmed: $currentVersion" "SUCCESS"
                        
                        # Check if tag already exists
                        $existingTag = git tag -l "v$Version" 2>$null
                        if ($existingTag) {
                            Write-WatchLog "Tag v$Version already exists" "WARNING"
                            return $true
                        }
                        
                        # Create and push release tag
                        Write-WatchLog "Creating release tag v$Version..." "INFO"
                        
                        $tagMessage = "Release v$Version - $Description"
                        git tag -a "v$Version" -m $tagMessage 2>&1 | Out-Null
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-WatchLog "Tag created successfully" "SUCCESS"
                            
                            # Push tag to trigger build
                            git push origin "v$Version" 2>&1 | Out-Null
                            
                            if ($LASTEXITCODE -eq 0) {
                                Write-WatchLog "Tag v$Version pushed successfully!" "SUCCESS"
                                Write-WatchLog "GitHub Actions Build & Release Pipeline should now trigger" "SUCCESS"
                                Write-WatchLog "Monitor at: https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\([^.]*\).*/\1/')/actions" "INFO"
                                return $true
                            } else {
                                Write-WatchLog "Failed to push tag" "ERROR"
                                return $false
                            }
                        } else {
                            Write-WatchLog "Failed to create tag" "ERROR"
                            return $false
                        }
                    } else {
                        Write-WatchLog "VERSION file mismatch. Expected: $Version, Found: $currentVersion" "ERROR"
                        return $false
                    }
                }
                elseif ($prStatus.state -eq "CLOSED") {
                    Write-WatchLog "PR #$PRNumber was closed without merging" "ERROR"
                    return $false
                }
                
                # Show progress
                $elapsed = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
                Write-Host "`rWaiting for merge... ($elapsed/$MaxWaitMinutes minutes)" -NoNewline
                
                Start-Sleep -Seconds 30
            }
            catch {
                Write-WatchLog "Error checking PR status: $_" "WARNING"
                Start-Sleep -Seconds 60
            }
        }
        
        Write-WatchLog "Timeout waiting for PR merge" "WARNING"
        Write-WatchLog "You can manually create the tag when ready:" "INFO"
        Write-WatchLog "  git tag -a 'v$Version' -m 'Release v$Version - $Description'" "INFO"
        Write-WatchLog "  git push origin 'v$Version'" "INFO"
        return $false
    }
}

Export-ModuleMember -Function Watch-ReleasePR