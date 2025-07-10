#Requires -Version 7.0

<#
.SYNOPSIS
    Convenience function to trigger automatic version tagging

.DESCRIPTION
    This is a simplified wrapper around Invoke-AutomaticVersionTagging that provides
    easy access to automatic version tagging functionality. It's designed to be called
    manually or from other scripts to check for VERSION file changes and create tags.

.PARAMETER Force
    Force create tag even if it already exists

.PARAMETER DryRun
    Preview what would be done without making changes

.PARAMETER ShowDetails
    Show detailed output

.EXAMPLE
    Start-AutomaticVersionTagging
    # Check for VERSION file changes and create tag if needed

.EXAMPLE
    Start-AutomaticVersionTagging -Force
    # Force create tag even if it already exists

.EXAMPLE
    Start-AutomaticVersionTagging -DryRun
    # Preview what would be done

.EXAMPLE
    Start-AutomaticVersionTagging -ShowDetails
    # Show detailed output during the process

.NOTES
    This function is a convenience wrapper that makes it easy to trigger automatic
    version tagging from the command line or other scripts. It provides a simple
    interface to the more comprehensive Invoke-AutomaticVersionTagging function.
#>

function Start-AutomaticVersionTagging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun,

        [Parameter(Mandatory = $false)]
        [switch]$ShowDetails
    )

    begin {
        # Helper function for logging
        function Write-StartTagLog {
            param([string]$Message, [string]$Level = "INFO")

            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Level $Level -Message $Message
            } else {
                $color = @{
                    'INFO' = 'Cyan'
                    'SUCCESS' = 'Green'
                    'WARNING' = 'Yellow'
                    'ERROR' = 'Red'
                }[$Level]
                Write-Host "[$Level] $Message" -ForegroundColor $color
            }
        }
    }

    process {
        try {
            Write-StartTagLog "Starting automatic version tagging check..." -Level "INFO"

            # Check if the comprehensive function is available
            if (-not (Get-Command Invoke-AutomaticVersionTagging -ErrorAction SilentlyContinue)) {
                Write-StartTagLog "Invoke-AutomaticVersionTagging function not found. Ensure PatchManager module is loaded." -Level "ERROR"
                return @{
                    Success = $false
                    Message = "Automatic version tagging function not available"
                }
            }

            # Build parameters for the main function
            $params = @{}
            if ($Force) { $params.ForceTag = $true }
            if ($DryRun) { $params.DryRun = $true }
            if (-not $ShowDetails) { $params.Silent = $true }

            # Call the main automatic version tagging function
            $result = Invoke-AutomaticVersionTagging @params

            # Provide user-friendly output
            if ($result.Success) {
                if ($result.TagCreated) {
                    Write-StartTagLog "✅ Success: Version tag $($result.TagName) created for version $($result.Version)" -Level "SUCCESS"
                    Write-StartTagLog "🚀 Release workflow should now trigger automatically" -Level "INFO"
                    
                    if ($ShowDetails) {
                        Write-StartTagLog "Commit: $($result.CommitSha)" -Level "INFO"
                        Write-StartTagLog "Tag: $($result.TagName)" -Level "INFO"
                        Write-StartTagLog "Version: $($result.Version)" -Level "INFO"
                    }
                } else {
                    Write-StartTagLog "ℹ️  $($result.Message)" -Level "INFO"
                }
            } else {
                Write-StartTagLog "❌ Failed: $($result.Message)" -Level "ERROR"
                
                if ($result.Error) {
                    Write-StartTagLog "Error details: $($result.Error)" -Level "ERROR"
                }
            }

            return $result

        } catch {
            $errorMessage = "Failed to start automatic version tagging: $($_.Exception.Message)"
            Write-StartTagLog $errorMessage -Level "ERROR"
            
            return @{
                Success = $false
                Message = $errorMessage
                Error = $_.Exception.Message
            }
        }
    }
}

# Create useful aliases
Set-Alias -Name "New-VersionTag" -Value "Start-AutomaticVersionTagging"
Set-Alias -Name "Create-VersionTag" -Value "Start-AutomaticVersionTagging"

# Export the function and aliases
Export-ModuleMember -Function Start-AutomaticVersionTagging -Alias @('New-VersionTag', 'Create-VersionTag')