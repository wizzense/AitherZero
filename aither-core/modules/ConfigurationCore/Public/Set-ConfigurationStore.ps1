function Set-ConfigurationStore {
    <#
    .SYNOPSIS
        Set the configuration store
    .DESCRIPTION
        Replaces the current configuration store with a new one
    .PARAMETER Store
        Configuration store hashtable to set
    .PARAMETER Backup
        Create a backup before replacing the store
    .PARAMETER Validate
        Validate the store structure before setting
    .EXAMPLE
        Set-ConfigurationStore -Store $newStore -Backup
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Store,

        [Parameter()]
        [switch]$Backup,

        [Parameter()]
        [switch]$Validate
    )

    try {
        if ($Validate) {
            # Validate store structure
            $requiredKeys = @('Modules', 'Environments', 'CurrentEnvironment', 'Schemas', 'HotReload', 'StorePath')
            foreach ($key in $requiredKeys) {
                if (-not $Store.ContainsKey($key)) {
                    throw "Invalid store structure: missing required key '$key'"
                }
            }

            # Validate environments structure
            if (-not $Store.Environments.ContainsKey($Store.CurrentEnvironment)) {
                throw "Current environment '$($Store.CurrentEnvironment)' not found in environments"
            }
        }

        if ($PSCmdlet.ShouldProcess("Configuration Store", "Replace")) {
            # Create backup if requested
            if ($Backup) {
                Backup-Configuration -Reason "Store replacement"
            }

            # Replace the store
            $script:ConfigurationStore = $Store

            # Ensure StorePath is set
            if (-not $script:ConfigurationStore.StorePath) {
                $script:ConfigurationStore.StorePath = Join-Path $env:APPDATA 'AitherZero' 'configuration.json'
                if ($IsLinux -or $IsMacOS) {
                    $script:ConfigurationStore.StorePath = Join-Path $env:HOME '.aitherzero' 'configuration.json'
                }
            }

            # Save the new store
            Save-ConfigurationStore

            Write-CustomLog -Level 'SUCCESS' -Message "Configuration store updated successfully"
            return $true
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to set configuration store: $_"
        throw
    }
}
