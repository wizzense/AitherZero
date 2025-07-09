function Import-StartupExperienceState {
    <#
    .SYNOPSIS
        Imports previously exported state for the StartupExperience management system
    .DESCRIPTION
        Restores the management state from a JSON file that was previously
        exported using Export-StartupExperienceState
    .PARAMETER Path
        Path to the state file to import
    .EXAMPLE
        Import-StartupExperienceState -Path "C:\temp\state.json"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    try {
        if (-not (Test-Path $Path)) {
            throw "State file not found: $Path"
        }

        # Read and parse the JSON file
        $json = Get-Content -Path $Path -Raw -Encoding UTF8
        $importedData = $json | ConvertFrom-Json

        # Validate the imported data
        if (-not $importedData.State) {
            throw "Invalid state file format: Missing State property"
        }

        # Restore the management state
        $script:ManagementState = @{
            State = $importedData.State
            StartTime = [DateTime]$importedData.StartTime
            TestMode = $importedData.TestMode
            LastOperation = $importedData.LastOperation
            Operations = $importedData.Operations
            Configuration = $importedData.Configuration
        }

        Write-Verbose "State imported from: $Path"
        
        return [PSCustomObject]@{
            Path = $Path
            StateImported = $true
            ImportTime = Get-Date
            OriginalStateTime = $importedData.StartTime
            OriginalExportTime = $importedData.ExportTime
        }

    } catch {
        Write-Error "Failed to import StartupExperience state: $($_.Exception.Message)"
        throw
    }
}