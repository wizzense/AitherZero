function Export-ConfigurationProfile {
    <#
    .SYNOPSIS
        Exports a configuration profile to a file
    .DESCRIPTION
        Exports configuration profile in various formats for sharing or backup
    .PARAMETER Name
        Name of the profile to export
    .PARAMETER Path
        Output path for the exported file
    .PARAMETER Format
        Export format: JSON, YAML, or EnvFile
    .PARAMETER IncludeSecrets
        Include sensitive data in export
    .PARAMETER Config
        Configuration object to export (instead of loading by name)
    .EXAMPLE
        Export-ConfigurationProfile -Name "production" -Path "./prod-config.json"
    .EXAMPLE
        Export-ConfigurationProfile -Name "dev" -Format YAML -Path "./dev.yaml"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByConfig')]
        [PSCustomObject]$Config,

        [Parameter()]
        [string]$Path,

        [Parameter()]
        [ValidateSet('JSON', 'YAML', 'EnvFile')]
        [string]$Format = 'JSON',

        [Parameter()]
        [switch]$IncludeSecrets
    )

    try {
        # Get configuration
        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            $Config = Get-ConfigurationProfile -Name $Name
            $profileName = $Name
        } else {
            $profileName = $Config.profile.name ?? 'exported'
        }

        # Set default path if not provided
        if (-not $Path) {
            $extension = switch ($Format) {
                'YAML' { 'yaml' }
                'EnvFile' { 'env' }
                default { 'json' }
            }
            $Path = Join-Path (Get-Location) "$profileName-export.$extension"
        }

        # Remove sensitive data unless explicitly included
        if (-not $IncludeSecrets) {
            $Config = Remove-SensitiveData -Config $Config
        }

        # Export based on format
        switch ($Format) {
            'JSON' {
                $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8
            }
            'YAML' {
                $yaml = ConvertTo-Yaml -Object $Config
                $yaml | Set-Content -Path $Path -Encoding UTF8
            }
            'EnvFile' {
                $envContent = ConvertTo-EnvFile -Config $Config
                $envContent | Set-Content -Path $Path -Encoding UTF8
            }
        }

        Write-Host "✅ Configuration exported to: $Path" -ForegroundColor Green
        Write-Host "   Format: $Format" -ForegroundColor DarkGray
        if (-not $IncludeSecrets) {
            Write-Host "   Note: Sensitive data was removed" -ForegroundColor Yellow
        }

        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Level 'INFO' -Message "Exported configuration profile: $profileName to $Path"
        }

        return Get-Item $Path

    } catch {
        Write-Error "Failed to export configuration profile: $_"
        throw
    }
}

function Import-ConfigurationProfile {
    <#
    .SYNOPSIS
        Imports a configuration profile from a file
    .DESCRIPTION
        Imports configuration from various file formats
    .PARAMETER Path
        Path to the configuration file to import
    .PARAMETER Name
        Name for the imported profile (defaults to filename)
    .PARAMETER Format
        Format of the import file (auto-detected by default)
    .PARAMETER SetAsCurrent
        Set the imported profile as current
    .EXAMPLE
        Import-ConfigurationProfile -Path "./prod-config.json" -SetAsCurrent
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [string]$Name,

        [Parameter()]
        [ValidateSet('Auto', 'JSON', 'YAML', 'EnvFile')]
        [string]$Format = 'Auto',

        [Parameter()]
        [switch]$SetAsCurrent
    )

    try {
        # Verify file exists
        if (-not (Test-Path $Path)) {
            throw "Configuration file not found: $Path"
        }

        # Auto-detect format if needed
        if ($Format -eq 'Auto') {
            $extension = [System.IO.Path]::GetExtension($Path).TrimStart('.')
            $Format = switch ($extension) {
                'yaml' { 'YAML' }
                'yml' { 'YAML' }
                'env' { 'EnvFile' }
                default { 'JSON' }
            }
        }

        # Import based on format
        $config = switch ($Format) {
            'JSON' {
                Get-Content $Path -Raw | ConvertFrom-Json
            }
            'YAML' {
                ConvertFrom-Yaml -Yaml (Get-Content $Path -Raw)
            }
            'EnvFile' {
                ConvertFrom-EnvFile -Path $Path
            }
        }

        # Set profile name
        if (-not $Name) {
            if ($config.profile.name) {
                $Name = $config.profile.name
            } else {
                $Name = [System.IO.Path]::GetFileNameWithoutExtension($Path)
            }
        }

        # Create profile
        New-ConfigurationProfile -Name $Name -Config $config -SetAsCurrent:$SetAsCurrent

        Write-Host "✅ Configuration imported successfully as profile: $Name" -ForegroundColor Green

        return $config

    } catch {
        Write-Error "Failed to import configuration profile: $_"
        throw
    }
}

# Helper functions for format conversion
function Remove-SensitiveData {
    param([PSCustomObject]$Config)

    $cleaned = $Config | ConvertTo-Json -Depth 10 | ConvertFrom-Json

    # List of sensitive properties to remove
    $sensitiveProps = @(
        'Password',
        'ApiKey',
        'Token',
        'Secret',
        'Credential',
        'PrivateKey',
        'ConnectionString'
    )

    # Recursively clean object
    function Clean-Object {
        param($obj)

        if ($obj -is [PSCustomObject]) {
            $obj.PSObject.Properties | ForEach-Object {
                $propName = $_.Name
                foreach ($sensitive in $sensitiveProps) {
                    if ($propName -like "*$sensitive*") {
                        $obj.$propName = "[REDACTED]"
                        break
                    }
                }
                if ($obj.$propName -is [PSCustomObject] -or $obj.$propName -is [Array]) {
                    Clean-Object $obj.$propName
                }
            }
        } elseif ($obj -is [Array]) {
            foreach ($item in $obj) {
                Clean-Object $item
            }
        }
    }

    Clean-Object $cleaned
    return $cleaned
}

function ConvertTo-Yaml {
    param([PSCustomObject]$Object)

    # Simple YAML converter (basic implementation)
    $yaml = @()

    function Convert-ObjectToYaml {
        param($obj, $indent = 0)

        $prefix = ' ' * $indent

        if ($obj -is [PSCustomObject]) {
            $obj.PSObject.Properties | ForEach-Object {
                $key = $_.Name
                $value = $_.Value

                if ($null -eq $value) {
                    $yaml += "${prefix}${key}: null"
                } elseif ($value -is [bool]) {
                    $yaml += "${prefix}${key}: $($value.ToString().ToLower())"
                } elseif ($value -is [string]) {
                    if ($value -match '[\r\n:]' -or $value.StartsWith(' ') -or $value.EndsWith(' ')) {
                        $yaml += "${prefix}${key}: `"$($value -replace '"', '\"')`""
                    } else {
                        $yaml += "${prefix}${key}: $value"
                    }
                } elseif ($value -is [int] -or $value -is [double]) {
                    $yaml += "${prefix}${key}: $value"
                } elseif ($value -is [array]) {
                    $yaml += "${prefix}${key}:"
                    foreach ($item in $value) {
                        if ($item -is [PSCustomObject]) {
                            $yaml += "${prefix}- "
                            Convert-ObjectToYaml $item ($indent + 2)
                        } else {
                            $yaml += "${prefix}- $item"
                        }
                    }
                } elseif ($value -is [PSCustomObject]) {
                    $yaml += "${prefix}${key}:"
                    Convert-ObjectToYaml $value ($indent + 2)
                }
            }
        }
    }

    Convert-ObjectToYaml $Object
    return $yaml -join "`n"
}

function ConvertTo-EnvFile {
    param([PSCustomObject]$Config)

    $env = @()

    function Flatten-Object {
        param($obj, $prefix = '')

        if ($obj -is [PSCustomObject]) {
            $obj.PSObject.Properties | ForEach-Object {
                $key = $_.Name
                $value = $_.Value
                $fullKey = if ($prefix) { "${prefix}_${key}" } else { $key }

                if ($value -is [PSCustomObject]) {
                    Flatten-Object $value $fullKey
                } elseif ($value -is [array]) {
                    $env += "${fullKey}=$($value -join ',')"
                } elseif ($value -is [bool]) {
                    $env += "${fullKey}=$($value.ToString().ToLower())"
                } elseif ($null -ne $value) {
                    $env += "${fullKey}=$value"
                }
            }
        }
    }

    Flatten-Object $Config
    return $env -join "`n"
}

function ConvertFrom-Yaml {
    param([string]$Yaml)

    # This is a very basic YAML parser - for production use a proper YAML module
    throw "YAML import requires the 'powershell-yaml' module. Install with: Install-Module powershell-yaml"
}

function ConvertFrom-EnvFile {
    param([string]$Path)

    $config = [PSCustomObject]@{}

    Get-Content $Path | Where-Object { $_ -match '^[^#].*=' } | ForEach-Object {
        $parts = $_ -split '=', 2
        $key = $parts[0].Trim()
        $value = $parts[1].Trim()

        # Convert string values to appropriate types
        if ($value -eq 'true') { $value = $true }
        elseif ($value -eq 'false') { $value = $false }
        elseif ($value -match '^\d+$') { $value = [int]$value }
        elseif ($value -match '^\d+\.\d+$') { $value = [double]$value }

        # Handle nested properties
        $keyParts = $key -split '_'
        $current = $config

        for ($i = 0; $i -lt $keyParts.Count - 1; $i++) {
            $part = $keyParts[$i]
            if (-not $current.PSObject.Properties.Name -contains $part) {
                $current | Add-Member -MemberType NoteProperty -Name $part -Value ([PSCustomObject]@{})
            }
            $current = $current.$part
        }

        $lastPart = $keyParts[-1]
        $current | Add-Member -MemberType NoteProperty -Name $lastPart -Value $value -Force
    }

    return $config
}
