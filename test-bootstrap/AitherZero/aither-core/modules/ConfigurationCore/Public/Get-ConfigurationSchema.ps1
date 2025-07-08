function Get-ConfigurationSchema {
    <#
    .SYNOPSIS
        Get configuration schema for a module
    .DESCRIPTION
        Returns the registered configuration schema for a specific module or all modules
    .PARAMETER ModuleName
        Name of the module to get schema for
    .PARAMETER All
        Return schemas for all modules
    .PARAMETER IncludeDefaults
        Include default values in the schema output
    .EXAMPLE
        $schema = Get-ConfigurationSchema -ModuleName "LabRunner"
    .EXAMPLE
        $allSchemas = Get-ConfigurationSchema -All
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ModuleName,
        
        [Parameter()]
        [switch]$All,
        
        [Parameter()]
        [switch]$IncludeDefaults
    )
    
    try {
        if ($All) {
            $schemas = @{}
            foreach ($schemaName in $script:ConfigurationStore.Schemas.Keys) {
                $schema = $script:ConfigurationStore.Schemas[$schemaName].Clone()
                
                if ($IncludeDefaults) {
                    # Add default values to schema
                    $defaults = @{}
                    if ($schema.Properties) {
                        foreach ($propName in $schema.Properties.Keys) {
                            $prop = $schema.Properties[$propName]
                            if ($prop.ContainsKey('Default')) {
                                $defaults[$propName] = $prop.Default
                            }
                        }
                    }
                    $schema.DefaultValues = $defaults
                }
                
                $schemas[$schemaName] = $schema
            }
            return $schemas
        }
        
        if (-not $ModuleName) {
            throw "ModuleName is required when not using -All"
        }
        
        if (-not $script:ConfigurationStore.Schemas.ContainsKey($ModuleName)) {
            Write-CustomLog -Level 'WARNING' -Message "No schema found for module: $ModuleName"
            return $null
        }
        
        $schema = $script:ConfigurationStore.Schemas[$ModuleName].Clone()
        
        if ($IncludeDefaults) {
            # Add default values to schema
            $defaults = @{}
            if ($schema.Properties) {
                foreach ($propName in $schema.Properties.Keys) {
                    $prop = $schema.Properties[$propName]
                    if ($prop.ContainsKey('Default')) {
                        $defaults[$propName] = $prop.Default
                    }
                }
            }
            $schema.DefaultValues = $defaults
        }
        
        return $schema
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get configuration schema: $_"
        throw
    }
}