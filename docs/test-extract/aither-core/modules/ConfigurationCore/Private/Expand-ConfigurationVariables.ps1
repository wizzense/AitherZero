function Expand-ConfigurationVariables {
    <#
    .SYNOPSIS
        Expand variables in configuration values
    .DESCRIPTION
        Replaces variable placeholders like ${ENV:VAR} or ${CONFIG:Module.Setting}
    .PARAMETER Configuration
        Configuration hashtable to expand
    .PARAMETER Environment
        Current environment name
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration,
        
        [Parameter()]
        [string]$Environment = $script:ConfigurationStore.CurrentEnvironment
    )
    
    $expanded = @{}
    
    foreach ($key in $Configuration.Keys) {
        $value = $Configuration[$key]
        
        if ($value -is [string]) {
            # Expand environment variables
            $value = [System.Environment]::ExpandEnvironmentVariables($value)
            
            # Expand configuration references ${CONFIG:Module.Setting}
            $pattern = '\$\{CONFIG:([^}]+)\}'
            $value = [regex]::Replace($value, $pattern, {
                param($match)
                $path = $match.Groups[1].Value
                $parts = $path -split '\.'
                
                if ($parts.Count -eq 2) {
                    $modName = $parts[0]
                    $setting = $parts[1]
                    
                    $modConfig = Get-ModuleConfiguration -ModuleName $modName -Environment $Environment
                    if ($modConfig -and $modConfig.ContainsKey($setting)) {
                        return $modConfig[$setting]
                    }
                }
                
                return $match.Value  # Return original if not found
            })
            
            # Expand special variables
            $value = $value -replace '\$\{ENVIRONMENT\}', $Environment
            $value = $value -replace '\$\{PLATFORM\}', $(if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } else { 'macOS' })
            
            $expanded[$key] = $value
        }
        elseif ($value -is [hashtable]) {
            # Recursively expand nested hashtables
            $expanded[$key] = Expand-ConfigurationVariables -Configuration $value -Environment $Environment
        }
        else {
            # Copy other types as-is
            $expanded[$key] = $value
        }
    }
    
    return $expanded
}