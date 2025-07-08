function Add-EventFilter {
    <#
    .SYNOPSIS
        Add event filter for specific event handlers
    .DESCRIPTION
        Adds custom filtering logic to event handlers to control which events are processed
    .PARAMETER HandlerId
        The event handler ID to add filter to
    .PARAMETER FilterName
        Name of the filter
    .PARAMETER FilterLogic
        ScriptBlock that returns $true if event should be processed
    .PARAMETER Priority
        Filter priority (lower numbers run first)
    .EXAMPLE
        Add-EventFilter -HandlerId "handler-123" -FilterName "CriticalOnly" -FilterLogic {
            param($Event)
            return $Event.Data.Priority -eq 'Critical'
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$HandlerId,
        
        [Parameter(Mandatory)]
        [string]$FilterName,
        
        [Parameter(Mandatory)]
        [scriptblock]$FilterLogic,
        
        [Parameter()]
        [int]$Priority = 50
    )
    
    try {
        # Find the handler
        $handler = $null
        foreach ($key in $script:MessageBus.Subscriptions.Keys) {
            $sub = $script:MessageBus.Subscriptions[$key]
            if ($sub.Id -eq $HandlerId) {
                $handler = $sub
                break
            }
        }
        
        if (-not $handler) {
            throw "Event handler not found: $HandlerId"
        }
        
        # Initialize filters if not exists
        if (-not $handler.Filters) {
            $handler.Filters = @()
        }
        
        # Create filter
        $filter = @{
            Name = $FilterName
            Logic = $FilterLogic
            Priority = $Priority
            AddedAt = Get-Date
            UsageCount = 0
        }
        
        # Remove existing filter with same name
        $handler.Filters = $handler.Filters | Where-Object { $_.Name -ne $FilterName }
        
        # Add new filter
        $handler.Filters += $filter
        
        # Sort by priority
        $handler.Filters = $handler.Filters | Sort-Object Priority
        
        Write-CustomLog -Level 'SUCCESS' -Message "Event filter added: $FilterName to handler $HandlerId"
        
        return @{
            HandlerId = $HandlerId
            FilterName = $FilterName
            Priority = $Priority
            TotalFilters = $handler.Filters.Count
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to add event filter: $_"
        throw
    }
}