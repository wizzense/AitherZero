function Get-ConfigurationStore {
    <#
    .SYNOPSIS
        Get the current configuration store
    .DESCRIPTION
        Returns the complete configuration store including all modules, environments, and schemas
    .PARAMETER AsJson
        Return the configuration store as JSON string
    .PARAMETER IncludeMetadata
        Include metadata like last modified dates and version information
    .EXAMPLE
        $store = Get-ConfigurationStore
    .EXAMPLE
        $json = Get-ConfigurationStore -AsJson
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$AsJson,
        
        [Parameter()]
        [switch]$IncludeMetadata
    )
    
    try {
        $store = $script:ConfigurationStore.Clone()
        
        if ($IncludeMetadata) {
            $store.Metadata = @{
                LastModified = (Get-Item $script:ConfigurationStore.StorePath -ErrorAction SilentlyContinue).LastWriteTime
                Version = '1.0.0'
                CreatedBy = $env:USERNAME
                Platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } else { 'macOS' }
            }
        }
        
        if ($AsJson) {
            return ($store | ConvertTo-Json -Depth 10)
        } else {
            return $store
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get configuration store: $_"
        throw
    }
}