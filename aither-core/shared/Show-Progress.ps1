# Progress indication utilities for AitherZero startup
# Provides visual feedback during module loading and initialization

function Show-SimpleProgress {
    <#
    .SYNOPSIS
        Shows simple progress messages during startup
    
    .DESCRIPTION
        Displays startup progress messages with consistent formatting
    
    .PARAMETER Message
        The message to display
    
    .PARAMETER Type
        The type of progress: Start, Update, Complete
    
    .EXAMPLE
        Show-SimpleProgress -Message "Loading modules..." -Type Start
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('Start', 'Update', 'Complete')]
        [string]$Type = 'Update'
    )
    
    switch ($Type) {
        'Start' {
            Write-Host ""
            Write-Host "🚀 $Message" -ForegroundColor Cyan
            Write-Host ""
        }
        'Update' {
            Write-Host "   $Message" -ForegroundColor Gray
        }
        'Complete' {
            Write-Host "✅ $Message" -ForegroundColor Green
            Write-Host ""
        }
    }
}

function Show-ModuleLoadingProgress {
    <#
    .SYNOPSIS
        Shows progress for individual module loading
    
    .DESCRIPTION
        Displays module loading progress with statistics
    
    .PARAMETER ModuleName
        Name of the module being loaded
    
    .PARAMETER ModuleType
        Type of module (Core, Consolidated)
    
    .PARAMETER CurrentIndex
        Current module index
    
    .PARAMETER TotalCount
        Total number of modules to load
    
    .PARAMETER Statistics
        Loading statistics object
    
    .EXAMPLE
        Show-ModuleLoadingProgress -ModuleName "Logging" -ModuleType "Core" -CurrentIndex 1 -TotalCount 4
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        
        [Parameter(Mandatory)]
        [string]$ModuleType,
        
        [Parameter(Mandatory)]
        [int]$CurrentIndex,
        
        [Parameter(Mandatory)]
        [int]$TotalCount,
        
        [Parameter()]
        [hashtable]$Statistics
    )
    
    $progress = [math]::Round(($CurrentIndex / $TotalCount) * 100)
    Write-Host "   [$progress%] Loading $ModuleType module: $ModuleName" -ForegroundColor DarkGray
}

function Complete-StartupProgress {
    <#
    .SYNOPSIS
        Completes the startup progress indicator
    
    .DESCRIPTION
        Shows completion status for module loading
    
    .PARAMETER Statistics
        Loading statistics object
    
    .EXAMPLE
        Complete-StartupProgress -Statistics $moduleLoadingStats
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [hashtable]$Statistics
    )
    
    if ($Statistics) {
        $totalLoaded = $Statistics.CoreModules.Loaded + $Statistics.ConsolidatedModules.Loaded
        $totalModules = $Statistics.CoreModules.Total + $Statistics.ConsolidatedModules.Total
        
        Write-Host ""
        Write-Host "✅ Module loading completed: $totalLoaded/$totalModules modules loaded" -ForegroundColor Green
        
        if ($Statistics.CoreModules.Failed -gt 0 -or $Statistics.ConsolidatedModules.Failed -gt 0) {
            $totalFailed = $Statistics.CoreModules.Failed + $Statistics.ConsolidatedModules.Failed
            Write-Host "⚠️  Some modules failed to load: $totalFailed" -ForegroundColor Yellow
        }
    } else {
        Write-Host "✅ Startup completed" -ForegroundColor Green
    }
    
    Write-Host ""
}

# Export functions only if running as a module (not when dot-sourced)
if ($ExecutionContext.SessionState.Module) {
    Export-ModuleMember -Function @(
        'Show-SimpleProgress',
        'Show-ModuleLoadingProgress', 
        'Complete-StartupProgress'
    )
}