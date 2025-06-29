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
            
            # Type validation
            if ($propSchema.Type) {
                $expectedType = switch ($propSchema.Type) {
                    'string' { [string] }
                    'int' { [int] }
                    'bool' { [bool] }
                    'array' { [array] }
                    'hashtable' { [hashtable] }
                    default { [object] }
                }
                
                if ($value -isnot $expectedType) {
                    $result.IsValid = $false
                    $result.Errors += "$propName: Expected type $($propSchema.Type), got $($value.GetType().Name)"
                }
            }
            
            # Valid values validation
            if ($propSchema.ValidValues -and $value -notin $propSchema.ValidValues) {
                $result.IsValid = $false
                $result.Errors += "$propName: Value '$value' not in valid values: $($propSchema.ValidValues -join ', ')"
            }
            
            # Range validation for numbers
            if ($value -is [int] -or $value -is [double]) {
                if ($propSchema.Min -and $value -lt $propSchema.Min) {
                    $result.IsValid = $false
                    $result.Errors += "$propName: Value $value is less than minimum $($propSchema.Min)"
                }
                if ($propSchema.Max -and $value -gt $propSchema.Max) {
                    $result.IsValid = $false
                    $result.Errors += "$propName: Value $value is greater than maximum $($propSchema.Max)"
                }
            }
            
            # Pattern validation for strings
            if ($value -is [string] -and $propSchema.Pattern) {
                if ($value -notmatch $propSchema.Pattern) {
                    $result.IsValid = $false
                    $result.Errors += "$propName: Value '$value' does not match pattern: $($propSchema.Pattern)"
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