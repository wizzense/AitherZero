#Requires -Version 7.0

<#
.SYNOPSIS
    Parallel execution script template
.DESCRIPTION
    Template for creating scripts that execute operations in parallel
.PARAMETER Items
    Items to process in parallel
.PARAMETER MaxParallel
    Maximum number of parallel operations
.EXAMPLE
    .\ParallelScript.ps1 -Items @("item1", "item2", "item3") -MaxParallel 3
#>

param(
    [Parameter(Mandatory = $true)]
    [string[]]$Items,
    
    [Parameter(Mandatory = $false)]
    [int]$MaxParallel = 5,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

try {
    Write-CustomLog -Level 'INFO' -Message "Parallel execution script started with $($Items.Count) items"
    
    if ($WhatIf) {
        Write-CustomLog -Level 'INFO' -Message "WhatIf mode: Would process $($Items.Count) items in parallel"
        return
    }
    
    # Process items in parallel
    $results = $Items | ForEach-Object -Parallel {
        param($item)
        
        try {
            Write-Host "Processing item: $item" -ForegroundColor Cyan
            
            # Your parallel processing logic here
            Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 3)
            
            return @{
                Item = $item
                Status = 'Success'
                Result = "Processed successfully"
            }
        } catch {
            return @{
                Item = $item
                Status = 'Failed'
                Result = $_.Exception.Message
            }
        }
    } -ThrottleLimit $MaxParallel
    
    # Process results
    $successful = $results | Where-Object { $_.Status -eq 'Success' }
    $failed = $results | Where-Object { $_.Status -eq 'Failed' }
    
    Write-CustomLog -Level 'SUCCESS' -Message "Parallel execution completed. Success: $($successful.Count), Failed: $($failed.Count)"
    
    if ($failed.Count -gt 0) {
        Write-CustomLog -Level 'WARNING' -Message "Some items failed to process:"
        foreach ($failure in $failed) {
            Write-CustomLog -Level 'ERROR' -Message "  - $($failure.Item): $($failure.Result)"
        }
    }
    
    return $results
    
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Parallel execution script failed: $($_.Exception.Message)"
    throw
}
