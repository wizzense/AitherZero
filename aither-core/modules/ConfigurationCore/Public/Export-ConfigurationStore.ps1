function Export-ConfigurationStore {
    <#
    .SYNOPSIS
        Export the configuration store to a file
    .DESCRIPTION
        Exports the current configuration store to a JSON file for backup or transfer
    .PARAMETER Path
        Path to export the configuration store to
    .PARAMETER ExcludeSchemas
        Exclude schemas from export (useful for configuration-only exports)
    .PARAMETER ExcludeEnvironments
        Specific environments to exclude from export
    .PARAMETER Format
        Export format (JSON, YAML, or XML)
    .EXAMPLE
        Export-ConfigurationStore -Path "C:\backup\config.json"
    .EXAMPLE
        Export-ConfigurationStore -Path "config-export.json" -ExcludeSchemas
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [switch]$ExcludeSchemas,

        [Parameter()]
        [string[]]$ExcludeEnvironments = @(),

        [Parameter()]
        [ValidateSet('JSON', 'YAML', 'XML')]
        [string]$Format = 'JSON'
    )

    try {
        # Get configuration store
        $store = Get-ConfigurationStore -IncludeMetadata

        # Apply exclusions
        if ($ExcludeSchemas) {
            $store.Remove('Schemas')
        }

        if ($ExcludeEnvironments.Count -gt 0) {
            foreach ($env in $ExcludeEnvironments) {
                $store.Environments.Remove($env)
            }
        }

        # Add export metadata with security information
        $configHash = Get-ConfigurationHash -Configuration $store
        $securityIssues = Test-ConfigurationSecurity -Configuration $store

        $store.ExportMetadata = @{
            ExportedBy = $env:USERNAME
            ExportedAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ'
            ExportedFrom = $env:COMPUTERNAME
            Format = $Format
            Version = '1.0.0'
            ConfigurationHash = $configHash
            SecurityValidation = @{
                ValidatedAt = Get-Date
                IssuesFound = $securityIssues.Count
                Issues = $securityIssues
            }
            Checksum = @{
                Algorithm = 'SHA256'
                Value = $configHash
            }
        }

        # Log security issues if found
        if ($securityIssues.Count -gt 0) {
            Write-CustomLog -Level 'WARNING' -Message "Security issues found in exported configuration:"
            foreach ($issue in $securityIssues) {
                Write-CustomLog -Level 'WARNING' -Message "  - $issue"
            }
        }

        if ($PSCmdlet.ShouldProcess($Path, "Export configuration store")) {
            # Ensure directory exists
            $directory = Split-Path $Path -Parent
            if ($directory -and -not (Test-Path $directory)) {
                New-Item -ItemType Directory -Path $directory -Force | Out-Null
            }

            # Export based on format
            switch ($Format) {
                'JSON' {
                    $json = $store | ConvertTo-Json -Depth 10
                    Set-Content -Path $Path -Value $json -Encoding UTF8
                }
                'YAML' {
                    # Basic YAML export (requires PowerShell-Yaml module for full support)
                    Write-CustomLog -Level 'WARNING' -Message "YAML export is basic. Consider using JSON for full compatibility."
                    $yaml = $store | ConvertTo-Json -Depth 10 | ConvertFrom-Json | ConvertTo-Yaml -ErrorAction SilentlyContinue
                    if ($yaml) {
                        Set-Content -Path $Path -Value $yaml -Encoding UTF8
                    } else {
                        Write-CustomLog -Level 'WARNING' -Message "YAML conversion failed, falling back to JSON"
                        $json = $store | ConvertTo-Json -Depth 10
                        Set-Content -Path $Path -Value $json -Encoding UTF8
                    }
                }
                'XML' {
                    # Basic XML export
                    $xml = $store | ConvertTo-Json -Depth 10 | ConvertFrom-Json | ConvertTo-Xml -NoTypeInformation
                    $xml.Save($Path)
                }
            }

            Write-CustomLog -Level 'SUCCESS' -Message "Configuration store exported to: $Path"
            return $true
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to export configuration store: $_"
        throw
    }
}
