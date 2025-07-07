# Startup Progress Indicator Utilities
# Provides visual feedback during module loading and startup

function Show-StartupProgress {
    <#
    .SYNOPSIS
        Shows progress during AitherZero startup
    
    .DESCRIPTION
        Displays a progress bar and status messages during module loading
    
    .PARAMETER Activity
        The main activity being performed
    
    .PARAMETER Status
        Current status message
    
    .PARAMETER PercentComplete
        Percentage of completion (0-100)
    
    .PARAMETER CurrentOperation
        Current operation details
    
    .EXAMPLE
        Show-StartupProgress -Activity "Loading Modules" -Status "Loading Logging module" -PercentComplete 10
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Activity,
        
        [Parameter(Mandatory)]
        [string]$Status,
        
        [Parameter()]
        [int]$PercentComplete = -1,
        
        [Parameter()]
        [string]$CurrentOperation = ""
    )
    
    # Skip progress in quiet/silent modes
    if ($global:Quiet -or $global:Verbosity -eq 'silent') {
        return
    }
    
    $progressParams = @{
        Activity = $Activity
        Status = $Status
    }
    
    if ($PercentComplete -ge 0) {
        $progressParams['PercentComplete'] = $PercentComplete
    }
    
    if ($CurrentOperation) {
        $progressParams['CurrentOperation'] = $CurrentOperation
    }
    
    Write-Progress @progressParams
}

function Show-ModuleLoadingProgress {
    <#
    .SYNOPSIS
        Shows progress specifically for module loading
    
    .DESCRIPTION
        Calculates and displays progress based on module loading statistics
    
    .PARAMETER ModuleName
        Name of the module being loaded
    
    .PARAMETER ModuleType
        Type of module (Core, Consolidated, Optional)
    
    .PARAMETER CurrentIndex
        Current module index (1-based)
    
    .PARAMETER TotalCount
        Total number of modules to load
    
    .PARAMETER Statistics
        Module loading statistics hashtable
    
    .EXAMPLE
        Show-ModuleLoadingProgress -ModuleName "Logging" -ModuleType "Core" -CurrentIndex 1 -TotalCount 4
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        
        [Parameter(Mandatory)]
        [ValidateSet('Core', 'Consolidated', 'Optional')]
        [string]$ModuleType,
        
        [Parameter(Mandatory)]
        [int]$CurrentIndex,
        
        [Parameter(Mandatory)]
        [int]$TotalCount,
        
        [Parameter()]
        [hashtable]$Statistics
    )
    
    # Calculate overall progress
    $percentComplete = [Math]::Round(($CurrentIndex / $TotalCount) * 100)
    
    # Build status message
    $status = "Loading $ModuleType module: $ModuleName ($CurrentIndex of $TotalCount)"
    
    # Add statistics if available
    if ($Statistics) {
        $loaded = $Statistics["${ModuleType}Modules"].Loaded
        $failed = $Statistics["${ModuleType}Modules"].Failed
        
        if ($failed -gt 0) {
            $status += " | Loaded: $loaded, Failed: $failed"
        }
    }
    
    Show-StartupProgress -Activity "AitherZero Startup" -Status $status -PercentComplete $percentComplete -CurrentOperation "Importing $ModuleName..."
}

function Complete-StartupProgress {
    <#
    .SYNOPSIS
        Completes the startup progress display
    
    .DESCRIPTION
        Finalizes the progress bar and displays completion message
    
    .PARAMETER Statistics
        Module loading statistics hashtable
    
    .EXAMPLE
        Complete-StartupProgress -Statistics $moduleLoadingStats
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [hashtable]$Statistics
    )
    
    # Complete the progress bar
    Write-Progress -Activity "AitherZero Startup" -Completed
    
    # Skip summary in quiet/silent modes
    if ($global:Quiet -or $global:Verbosity -eq 'silent') {
        return
    }
    
    # Display summary if statistics available
    if ($Statistics) {
        $totalLoaded = $Statistics.CoreModules.Loaded + $Statistics.ConsolidatedModules.Loaded
        $totalFailed = $Statistics.CoreModules.Failed + $Statistics.ConsolidatedModules.Failed
        $duration = (Get-Date) - $Statistics.StartTime
        
        Write-Host "`n✅ AitherZero Startup Complete" -ForegroundColor Green
        Write-Host "   Modules Loaded: $totalLoaded" -ForegroundColor Cyan
        
        if ($totalFailed -gt 0) {
            Write-Host "   Modules Failed: $totalFailed" -ForegroundColor Yellow
        }
        
        Write-Host "   Startup Time: $([Math]::Round($duration.TotalSeconds, 2)) seconds" -ForegroundColor Cyan
        Write-Host ""
    }
}

function Show-SimpleProgress {
    <#
    .SYNOPSIS
        Shows a simple text-based progress indicator
    
    .DESCRIPTION
        Displays a simple progress message for environments where Write-Progress isn't available
    
    .PARAMETER Message
        Progress message to display
    
    .PARAMETER Type
        Type of progress (Start, Update, Complete)
    
    .EXAMPLE
        Show-SimpleProgress -Message "Loading core modules..." -Type Start
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('Start', 'Update', 'Complete', 'Error')]
        [string]$Type = 'Update'
    )
    
    # Skip in quiet/silent modes
    if ($global:Quiet -or $global:Verbosity -eq 'silent') {
        return
    }
    
    switch ($Type) {
        'Start' {
            Write-Host "`n🚀 $Message" -ForegroundColor Cyan
        }
        'Update' {
            Write-Host "   ⏳ $Message" -ForegroundColor Gray
        }
        'Complete' {
            Write-Host "   ✅ $Message" -ForegroundColor Green
        }
        'Error' {
            Write-Host "   ❌ $Message" -ForegroundColor Red
        }
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Show-StartupProgress',
    'Show-ModuleLoadingProgress',
    'Complete-StartupProgress',
    'Show-SimpleProgress'
)