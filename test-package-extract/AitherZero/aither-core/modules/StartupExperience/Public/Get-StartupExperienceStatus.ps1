function Get-StartupExperienceStatus {
    <#
    .SYNOPSIS
        Gets the current status of the StartupExperience management system
    .DESCRIPTION
        Returns the current state, configuration, and operation history
        of the StartupExperience management system
    .EXAMPLE
        Get-StartupExperienceStatus
    #>
    [CmdletBinding()]
    param()

    try {
        # Initialize management state if not already done
        if (-not $script:ManagementState) {
            Start-StartupExperienceManagement
        }

        $status = [PSCustomObject]@{
            State = $script:ManagementState.State
            StartTime = $script:ManagementState.StartTime
            TestMode = $script:ManagementState.TestMode
            LastOperation = $script:ManagementState.LastOperation
            OperationCount = $script:ManagementState.Operations.Count
            Configuration = $script:ManagementState.Configuration
            Duration = ((Get-Date) - $script:ManagementState.StartTime).TotalSeconds
        }

        return $status
    } catch {
        Write-Error "Failed to get StartupExperience status: $($_.Exception.Message)"
        throw
    }
}