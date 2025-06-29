function Save-ConfigurationStore {
    <#
    .SYNOPSIS
        Save the configuration store to disk
    .DESCRIPTION
        Persists the current configuration store to the configured storage path
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Ensure directory exists
        $configDir = Split-Path $script:ConfigurationStore.StorePath -Parent
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        
        # Convert to JSON and save
        $json = $script:ConfigurationStore | ConvertTo-Json -Depth 10 -Compress
        Set-Content -Path $script:ConfigurationStore.StorePath -Value $json -Encoding UTF8
        
        Write-CustomLog -Level 'DEBUG' -Message "Configuration store saved to: $($script:ConfigurationStore.StorePath)"
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to save configuration store: $_"
        throw
    }
}