# YAML Helper Functions for OpenTofuProvider Module

function ConvertFrom-Yaml {
    <#
    .SYNOPSIS
    Converts YAML content to PowerShell objects.

    .DESCRIPTION
    Provides basic YAML parsing functionality for configuration files.
    This is a simplified implementation for basic YAML structures.

    .PARAMETER InputObject
    The YAML string to convert.

    .EXAMPLE
    $yamlContent = @"
    name: test
    values:
      - item1
      - item2
    "@
    $result = ConvertFrom-Yaml $yamlContent
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$InputObject
    )

    begin {
        Write-CustomLog -Level 'DEBUG' -Message "Converting YAML content to PowerShell object"
    }

    process {
        try {
            # Try to use powershell-yaml module if available
            if (Get-Module -ListAvailable -Name powershell-yaml) {
                Import-Module powershell-yaml -Force
                return ConvertFrom-Yaml $InputObject
            }

            # Fallback to basic YAML parsing
            Write-CustomLog -Level 'WARN' -Message "powershell-yaml module not available, using basic YAML parsing"

            $lines = $InputObject -split "`n" | ForEach-Object { $_.Trim() }
            $result = @{}
            $currentObject = $result
            $objectStack = @()

            foreach ($line in $lines) {
                if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
                    continue
                }

                if ($line.Contains(':')) {
                    $parts = $line -split ':', 2
                    $key = $parts[0].Trim()
                    $value = if ($parts.Length -gt 1) { $parts[1].Trim() } else { '' }

                    # Handle quoted strings
                    if ($value.StartsWith('"') -and $value.EndsWith('"')) {
                        $value = $value.Substring(1, $value.Length - 2)
                    }

                    # Handle boolean values
                    if ($value -eq 'true') { $value = $true }
                    elseif ($value -eq 'false') { $value = $false }
                    # Handle numeric values
                    elseif ($value -match '^\d+$') { $value = [int]$value }
                    elseif ($value -match '^\d+\.\d+$') { $value = [double]$value }

                    if ([string]::IsNullOrWhiteSpace($value)) {
                        # This might be the start of a nested object
                        $nestedObject = @{}
                        $currentObject[$key] = $nestedObject
                        $objectStack += $currentObject
                        $currentObject = $nestedObject
                    } else {
                        $currentObject[$key] = $value
                    }
                } elseif ($line.StartsWith('-')) {
                    # Handle array items (basic support)
                    $item = $line.Substring(1).Trim()
                    if ($item.StartsWith('"') -and $item.EndsWith('"')) {
                        $item = $item.Substring(1, $item.Length - 2)
                    }

                    # Find the last key that should become an array
                    $lastKey = $currentObject.Keys | Select-Object -Last 1
                    if ($lastKey) {
                        if ($currentObject[$lastKey] -is [array]) {
                            $currentObject[$lastKey] += $item
                        } else {
                            $currentObject[$lastKey] = @($item)
                        }
                    }
                }
            }

            return $result

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to parse YAML: $($_.Exception.Message)"
            throw "YAML parsing failed: $($_.Exception.Message)"
        }
    }
}

function ConvertTo-Yaml {
    <#
    .SYNOPSIS
    Converts PowerShell objects to YAML format.

    .DESCRIPTION
    Provides basic YAML output functionality.

    .PARAMETER InputObject
    The PowerShell object to convert to YAML.

    .PARAMETER Depth
    Maximum depth for nested objects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$InputObject,

        [Parameter()]
        [int]$Depth = 10
    )

    process {
        try {
            # Try to use powershell-yaml module if available
            if (Get-Module -ListAvailable -Name powershell-yaml) {
                Import-Module powershell-yaml -Force
                return ConvertTo-Yaml $InputObject -Depth $Depth
            }

            # Fallback to basic YAML output
            Write-CustomLog -Level 'WARN' -Message "powershell-yaml module not available, using basic YAML output"

            function ConvertTo-YamlString {
                param($Object, $IndentLevel = 0)

                $indent = '  ' * $IndentLevel
                $result = @()

                if ($Object -is [hashtable] -or $Object.GetType().Name -eq 'PSCustomObject') {
                    $properties = if ($Object -is [hashtable]) { $Object.Keys } else { $Object.PSObject.Properties.Name }

                    foreach ($key in $properties) {
                        $value = if ($Object -is [hashtable]) { $Object[$key] } else { $Object.$key }

                        if ($value -is [hashtable] -or $value.GetType().Name -eq 'PSCustomObject') {
                            $result += "$indent$key" + ":"
                            $result += ConvertTo-YamlString -Object $value -IndentLevel ($IndentLevel + 1)
                        } elseif ($value -is [array]) {
                            $result += "$indent$key" + ":"
                            foreach ($item in $value) {
                                if ($item -is [hashtable] -or $item.GetType().Name -eq 'PSCustomObject') {
                                    $result += "$('  ' * ($IndentLevel + 1))- "
                                    $itemYaml = ConvertTo-YamlString -Object $item -IndentLevel ($IndentLevel + 2)
                                    $result += $itemYaml -replace "^$('  ' * ($IndentLevel + 2))", "$('  ' * ($IndentLevel + 2))"
                                } else {
                                    $result += "$('  ' * ($IndentLevel + 1))- $item"
                                }
                            }
                        } else {
                            $valueStr = if ($value -is [string] -and $value.Contains(' ')) { "`"$value`"" } else { $value }
                            $result += "$indent$key" + ": $valueStr"
                        }
                    }
                }

                return $result -join "`n"
            }

            return ConvertTo-YamlString -Object $InputObject

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to convert to YAML: $($_.Exception.Message)"
            throw "YAML conversion failed: $($_.Exception.Message)"
        }
    }
}
