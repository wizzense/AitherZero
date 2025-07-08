function Validate-Configuration {
    <#
    .SYNOPSIS
        Validate configuration against schema
    .DESCRIPTION
        Validates a configuration hashtable against a module's registered schema
    .PARAMETER ModuleName
        Name of the module
    .PARAMETER Configuration
        Configuration to validate
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        
        [Parameter(Mandatory)]
        [hashtable]$Configuration
    )
    
    $result = @{
        IsValid = $true
        Warnings = @()
        Errors = @()
    }
    
    # Get schema
    if (-not $script:ConfigurationStore.Schemas.ContainsKey($ModuleName)) {
        $result.Warnings += "No schema defined for module: $ModuleName"
        return $result
    }
    
    $schema = $script:ConfigurationStore.Schemas[$ModuleName]
    
    # Validate each property
    if ($schema.Properties) {
        foreach ($propName in $schema.Properties.Keys) {
            $propSchema = $schema.Properties[$propName]
            
            # Check if required property is missing
            if ($propSchema.Required -and -not $Configuration.ContainsKey($propName)) {
                $result.IsValid = $false
                $result.Errors += "Required property missing: $propName"
                continue
            }
            
            # Skip validation if property not present and not required
            if (-not $Configuration.ContainsKey($propName)) {
                continue
            }
            
            $value = $Configuration[$propName]
            
            # Enhanced type validation with complex types
            if ($propSchema.Type) {
                $typeValid = $true
                $typeError = $null
                
                switch ($propSchema.Type) {
                    'string' { 
                        if ($value -isnot [string]) {
                            $typeValid = $false
                            $typeError = "Expected string, got $($value.GetType().Name)"
                        }
                    }
                    'int' { 
                        if ($value -isnot [int] -and $value -isnot [long]) {
                            # Try to convert to int
                            if ([int]::TryParse($value, [ref]$null)) {
                                # Can be converted, that's acceptable
                            } else {
                                $typeValid = $false
                                $typeError = "Expected integer, got $($value.GetType().Name)"
                            }
                        }
                    }
                    'bool' { 
                        if ($value -isnot [bool]) {
                            # Try to convert common boolean representations
                            if ($value -in @('true', 'false', '1', '0', 'yes', 'no')) {
                                # Can be converted, that's acceptable
                            } else {
                                $typeValid = $false
                                $typeError = "Expected boolean, got $($value.GetType().Name)"
                            }
                        }
                    }
                    'array' { 
                        if ($value -isnot [array] -and $value -isnot [System.Collections.IEnumerable]) {
                            $typeValid = $false
                            $typeError = "Expected array, got $($value.GetType().Name)"
                        } elseif ($propSchema.ItemType) {
                            # Validate array item types
                            foreach ($item in $value) {
                                $itemValid = Test-ConfigurationValueType -Value $item -Type $propSchema.ItemType
                                if (-not $itemValid.IsValid) {
                                    $typeValid = $false
                                    $typeError = "Array item validation failed: $($itemValid.Error)"
                                    break
                                }
                            }
                        }
                    }
                    'hashtable' { 
                        if ($value -isnot [hashtable] -and $value -isnot [System.Collections.IDictionary]) {
                            $typeValid = $false
                            $typeError = "Expected hashtable, got $($value.GetType().Name)"
                        }
                    }
                    'email' {
                        if ($value -isnot [string] -or $value -notmatch '^[^@]+@[^@]+\.[^@]+$') {
                            $typeValid = $false
                            $typeError = "Expected valid email address"
                        }
                    }
                    'url' {
                        try {
                            $uri = [System.Uri]::new($value)
                            if (-not $uri.IsAbsoluteUri) {
                                $typeValid = $false
                                $typeError = "Expected absolute URL"
                            }
                        } catch {
                            $typeValid = $false
                            $typeError = "Expected valid URL"
                        }
                    }
                    'path' {
                        if ($value -isnot [string] -or ([string]::IsNullOrWhiteSpace($value))) {
                            $typeValid = $false
                            $typeError = "Expected valid file path"
                        } elseif ($propSchema.MustExist -and -not (Test-Path $value)) {
                            $typeValid = $false
                            $typeError = "Path does not exist: $value"
                        }
                    }
                    default { 
                        # For unknown types, just check if it's an object
                        if ($null -eq $value) {
                            $typeValid = $false
                            $typeError = "Value cannot be null for type $($propSchema.Type)"
                        }
                    }
                }
                
                if (-not $typeValid) {
                    $result.IsValid = $false
                    $result.Errors += "${propName}: $typeError"
                }
            }
            
            # Valid values validation
            if ($propSchema.ValidValues -and $value -notin $propSchema.ValidValues) {
                $result.IsValid = $false
                $result.Errors += "${propName}: Value '$value' not in valid values: $($propSchema.ValidValues -join ', ')"
            }
            
            # Range validation for numbers
            if ($value -is [int] -or $value -is [double]) {
                if ($propSchema.Min -and $value -lt $propSchema.Min) {
                    $result.IsValid = $false
                    $result.Errors += "${propName}: Value $value is less than minimum $($propSchema.Min)"
                }
                if ($propSchema.Max -and $value -gt $propSchema.Max) {
                    $result.IsValid = $false
                    $result.Errors += "${propName}: Value $value is greater than maximum $($propSchema.Max)"
                }
            }
            
            # Pattern validation for strings
            if ($value -is [string] -and $propSchema.Pattern) {
                if ($value -notmatch $propSchema.Pattern) {
                    $result.IsValid = $false
                    $result.Errors += "${propName}: Value '$value' does not match pattern: $($propSchema.Pattern)"
                }
            }
            
            # Dependency validation
            if ($propSchema.DependsOn) {
                foreach ($dependency in $propSchema.DependsOn) {
                    if (-not $Configuration.ContainsKey($dependency)) {
                        $result.IsValid = $false
                        $result.Errors += "${propName}: Depends on property '$dependency' which is not present"
                    } elseif ($propSchema.DependsOnValue -and $Configuration[$dependency] -ne $propSchema.DependsOnValue[$dependency]) {
                        $result.IsValid = $false
                        $result.Errors += "${propName}: Depends on property '$dependency' having value '$($propSchema.DependsOnValue[$dependency])'"
                    }
                }
            }
            
            # Conditional validation
            if ($propSchema.ConditionalValidation) {
                foreach ($condition in $propSchema.ConditionalValidation) {
                    $conditionMet = $true
                    if ($condition.When) {
                        foreach ($whenKey in $condition.When.Keys) {
                            if (-not $Configuration.ContainsKey($whenKey) -or $Configuration[$whenKey] -ne $condition.When[$whenKey]) {
                                $conditionMet = $false
                                break
                            }
                        }
                    }
                    
                    if ($conditionMet -and $condition.Then) {
                        # Apply conditional validation rules
                        if ($condition.Then.Required -and [string]::IsNullOrEmpty($value)) {
                            $result.IsValid = $false
                            $result.Errors += "${propName}: Required when $($condition.When | ConvertTo-Json -Compress)"
                        }
                        if ($condition.Then.ValidValues -and $value -notin $condition.Then.ValidValues) {
                            $result.IsValid = $false
                            $result.Errors += "${propName}: Must be one of [$($condition.Then.ValidValues -join ', ')] when $($condition.When | ConvertTo-Json -Compress)"
                        }
                    }
                }
            }
        }
    }
    
    # Check for unknown properties
    if ($schema.AdditionalProperties -eq $false) {
        $schemaProps = $schema.Properties.Keys
        foreach ($key in $Configuration.Keys) {
            if ($key -notin $schemaProps) {
                $result.Warnings += "Unknown property: $key"
            }
        }
    }
    
    return $result
}