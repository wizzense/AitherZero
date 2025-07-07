function Get-UtilityEvents {
    <#
    .SYNOPSIS
        Retrieves utility service events
    #>
    [CmdletBinding()]
    param(
        [string]$EventType,
        [string]$Source,
        [int]$Count = 100
    )
    
    $events = $script:ServiceEventSystem.EventHistory
    
    if ($EventType) {
        $events = $events | Where-Object { $_.EventType -eq $EventType }
    }
    
    if ($Source) {
        $events = $events | Where-Object { $_.Source -eq $Source }
    }
    
    return $events | Select-Object -Last $Count | Sort-Object Timestamp -Descending
}

function Clear-UtilityEvents {
    <#
    .SYNOPSIS
        Clears utility service event history
    #>
    [CmdletBinding()]
    param(
        [string]$EventType,
        [switch]$Force
    )
    
    if ($EventType) {
        $script:ServiceEventSystem.EventHistory = $script:ServiceEventSystem.EventHistory | Where-Object { 
            $_.EventType -ne $EventType 
        }
        Write-UtilityLog "Cleared events of type: $EventType" -Level "INFO"
    } else {
        if ($Force) {
            $script:ServiceEventSystem.EventHistory = @()
            Write-UtilityLog "Cleared all event history" -Level "INFO"
        } else {
            throw "Use -Force to clear all events"
        }
    }
}