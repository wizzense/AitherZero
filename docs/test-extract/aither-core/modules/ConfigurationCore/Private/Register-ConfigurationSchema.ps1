function Register-ConfigurationSchema {
    <#
    .SYNOPSIS
        Internal function to register a configuration schema
    .DESCRIPTION
        Used by Initialize-DefaultSchemas to register module schemas
    .PARAMETER ModuleName
        Name of the module
    .PARAMETER Schema
        Schema definition
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        
        [Parameter(Mandatory)]
        [hashtable]$Schema
    )
    
    # Create default configuration from schema
    $defaultConfig = @{}
    
    if ($Schema.Properties) {
        foreach ($propName in $Schema.Properties.Keys) {
            $prop = $Schema.Properties[$propName]
            if ($prop.ContainsKey('Default')) {
                $defaultConfig[$propName] = $prop.Default
            }
        }
    }
    
    # Register using the public function
    Register-ModuleConfiguration -ModuleName $ModuleName -Schema $Schema -DefaultConfiguration $defaultConfig
}