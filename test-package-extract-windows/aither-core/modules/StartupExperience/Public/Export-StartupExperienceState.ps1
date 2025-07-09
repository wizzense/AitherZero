function Export-StartupExperienceState {
    <#
    .SYNOPSIS
        Exports the current state of the StartupExperience management system
    .DESCRIPTION
        Saves the current management state to a JSON file for persistence
        and backup purposes
    .PARAMETER Path
        Path where to save the state file
    .EXAMPLE
        Export-StartupExperienceState -Path "C:\temp\state.json"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    try {
        # Initialize management state if not already done
        if (-not $script:ManagementState) {
            Start-StartupExperienceManagement
        }

        # Create export object
        $exportData = @{
            State = $script:ManagementState.State
            StartTime = $script:ManagementState.StartTime
            TestMode = $script:ManagementState.TestMode
            LastOperation = $script:ManagementState.LastOperation
            Operations = $script:ManagementState.Operations
            Configuration = $script:ManagementState.Configuration
            ExportTime = Get-Date
        }

        # Convert to JSON and save
        $json = $exportData | ConvertTo-Json -Depth 10
        Set-Content -Path $Path -Value $json -Encoding UTF8

        Write-Verbose "State exported to: $Path"
        
        return [PSCustomObject]@{
            Path = $Path
            Size = (Get-Item $Path).Length
            ExportTime = $exportData.ExportTime
        }

    } catch {
        Write-Error "Failed to export StartupExperience state: $($_.Exception.Message)"
        throw
    }
}