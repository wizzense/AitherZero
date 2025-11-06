#Requires -Version 7.0

<#
.SYNOPSIS
    Example extension module for AitherZero
.DESCRIPTION
    Demonstrates how to create custom commands and CLI modes for AitherZero
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Gets example data
.EXAMPLE
    Get-ExampleData -Source "test"
#>
function Get-ExampleData {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Source = "default"
    )
    
    Write-Host "📊 Getting example data from: $Source" -ForegroundColor Cyan
    
    $data = @{
        Source = $Source
        Timestamp = Get-Date
        Version = '1.0.0'
        Items = @(
            @{ Id = 1; Name = "Item 1"; Status = "Active" }
            @{ Id = 2; Name = "Item 2"; Status = "Pending" }
            @{ Id = 3; Name = "Item 3"; Status = "Complete" }
        )
    }
    
    return $data
}

<#
.SYNOPSIS
    Executes an example task
.EXAMPLE
    Invoke-ExampleTask -TaskName "demo"
#>
function Invoke-ExampleTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TaskName,
        
        [switch]$DryRun
    )
    
    Write-Host "🚀 Executing example task: $TaskName" -ForegroundColor Green
    
    if ($DryRun) {
        Write-Host "   (Dry run mode - no changes will be made)" -ForegroundColor Yellow
    }
    
    # Simulate task execution
    $steps = @(
        "Initializing task..."
        "Loading configuration..."
        "Processing data..."
        "Validating results..."
        "Task completed!"
    )
    
    foreach ($step in $steps) {
        Write-Host "   $step" -ForegroundColor White
        Start-Sleep -Milliseconds 200
    }
    
    Write-Host "✅ Task '$TaskName' completed successfully" -ForegroundColor Green
}

<#
.SYNOPSIS
    Handler for the Example CLI mode
.DESCRIPTION
    This function is called when using: -Mode Example
.EXAMPLE
    Invoke-ExampleMode -Parameters @{ Target = 'demo'; Action = 'run' }
#>
function Invoke-ExampleMode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Parameters
    )
    
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              Example Extension - CLI Mode                      ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    $target = $Parameters.Target
    $action = $Parameters.Action
    
    if (-not $target) {
        Write-Host "❌ Error: -Target parameter is required" -ForegroundColor Red
        Write-Host "`nUsage: -Mode Example -Target <name> -Action <action>" -ForegroundColor Yellow
        Write-Host "Actions: run, status, info" -ForegroundColor Yellow
        return
    }
    
    Write-Host "Target: $target" -ForegroundColor White
    Write-Host "Action: $action`n" -ForegroundColor White
    
    switch ($action) {
        'run' {
            Invoke-ExampleTask -TaskName $target
        }
        'status' {
            $data = Get-ExampleData -Source $target
            Write-Host "Status retrieved:" -ForegroundColor Cyan
            $data | ConvertTo-Json -Depth 3 | Write-Host
        }
        'info' {
            Write-Host "Extension: ExampleExtension v1.0.0" -ForegroundColor Cyan
            Write-Host "Target: $target" -ForegroundColor White
            Write-Host "Available actions: run, status, info" -ForegroundColor White
        }
        default {
            Write-Host "Unknown action: $action" -ForegroundColor Red
            Write-Host "Available actions: run, status, info" -ForegroundColor Yellow
        }
    }
    
    Write-Host "`n" -NoNewline
}

# Export public functions
Export-ModuleMember -Function @(
    'Get-ExampleData'
    'Invoke-ExampleTask'
    'Invoke-ExampleMode'
)
