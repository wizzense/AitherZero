function Merge-Configuration {
    <#
    .SYNOPSIS
        Merge two configuration hashtables
    .DESCRIPTION
        Deep merges configuration hashtables with override taking precedence
    .PARAMETER Base
        Base configuration hashtable
    .PARAMETER Override
        Override configuration hashtable
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [hashtable]$Base = @{},

        [Parameter()]
        [hashtable]$Override = @{}
    )

    # Clone base to avoid modifying original
    $result = @{}

    # Copy all base values
    foreach ($key in $Base.Keys) {
        if ($Base[$key] -is [hashtable]) {
            $result[$key] = Merge-Configuration -Base $Base[$key] -Override @{}
        } elseif ($Base[$key] -is [array]) {
            $result[$key] = @($Base[$key])
        } else {
            $result[$key] = $Base[$key]
        }
    }

    # Apply overrides
    foreach ($key in $Override.Keys) {
        if ($Override[$key] -is [hashtable] -and $result.ContainsKey($key) -and $result[$key] -is [hashtable]) {
            # Deep merge hashtables
            $result[$key] = Merge-Configuration -Base $result[$key] -Override $Override[$key]
        } else {
            # Direct override for non-hashtable values or new keys
            $result[$key] = $Override[$key]
        }
    }

    return $result
}
