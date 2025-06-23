function Format-Config {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline = $true,
                   ValueFromPipelineByPropertyName = $true)]
        [AllowNull()]
        [pscustomobject]$Config
    )

    begin {
        $hasInput = $false        # Throw if -Config $null is supplied explicitly so callers get a
        # consistent ArgumentException regardless of how input is provided.
        if ($PSBoundParameters.ContainsKey('Config') -and $null -eq $Config) {
            throw [System.ArgumentException]::new(
                'A configuration object must be provided via -Config or the pipeline.',
                'Config'
            )
        }
    }    process {
        $hasInput = $true

        if ($null -eq $Config) {
            throw [System.ArgumentException]::new(
                'A configuration object must be provided via -Config or the pipeline.',
                'Config'
            )
        }        # Serialize the configuration object to indented JSON so nested
        # properties are easier to read in the console output.  Depth 10
        # should be sufficient for our current config structure.
        $Config | ConvertTo-Json -Depth 10
    }

    end {        if (-not $hasInput) {
            throw [System.ArgumentException]::new(
                'A configuration object must be provided via -Config or the pipeline.',
                'Config'
            )
        }
    }
}





