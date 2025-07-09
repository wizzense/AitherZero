# Universal Logging Fallback System
# This script provides a standardized logging fallback for all AitherZero modules

function Initialize-LoggingFallback {
    <#
    .SYNOPSIS
        Initializes universal logging fallback for modules
    
    .DESCRIPTION
        Provides a standardized Write-CustomLog function when the Logging module isn't available.
        This ensures consistent logging behavior across all modules.
    
    .PARAMETER ModuleName
        Name of the module initializing the fallback
    
    .EXAMPLE
        Initialize-LoggingFallback -ModuleName "MyModule"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )
    
    # Check if Write-CustomLog is already available
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-Verbose "[$ModuleName] Logging module already available"
        return $true
    }
    
# Create standardized fallback function in global scope
function global:Write-CustomLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('ERROR', 'WARN', 'WARNING', 'INFO', 'SUCCESS', 'DEBUG', 'TRACE', 'VERBOSE')]
        [string]$Level = 'INFO',
        
        [Parameter(Mandatory = $false)]
        [string]$Source = "AitherZero",
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Context = @{},
        
        [Parameter(Mandatory = $false)]
        [Exception]$Exception = $null
    )
    
    # Normalize level names
    if ($Level -eq 'WARNING') { $Level = 'WARN' }
    
    # Determine color based on level
    $color = switch ($Level) {
        'ERROR' { 'Red' }
        'WARN' { 'Yellow' }
        'SUCCESS' { 'Green' }
        'INFO' { 'Cyan' }
        'DEBUG' { 'Gray' }
        'TRACE' { 'DarkGray' }
        'VERBOSE' { 'DarkCyan' }
        default { 'White' }
    }
    
    # Build log message
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logMessage = "[$timestamp] [$Level] [$Source] $Message"
    
    # Add context if provided
    if ($Context.Count -gt 0) {
        $contextStr = ($Context.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ", "
        $logMessage += " {$contextStr}"
    }
    
    # Add exception if provided
    if ($Exception) {
        $logMessage += " Exception: $($Exception.Message)"
    }
    
    # Output with color
    Write-Host $logMessage -ForegroundColor $color
    
    # Also log to file if possible (fallback file logging)
    try {
        $logPath = if ($env:TEMP) { 
            Join-Path $env:TEMP "AitherZero-Fallback.log" 
        } elseif ($env:TMPDIR) { 
            Join-Path $env:TMPDIR "AitherZero-Fallback.log" 
        } else { 
            "AitherZero-Fallback.log" 
        }
        
        Add-Content -Path $logPath -Value $logMessage -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {
        # Fail silently for fallback logging
    }
}
    
    Write-Verbose "[$ModuleName] Initialized logging fallback"
    return $false
}

# Export function only if running as a module (not when dot-sourced)
if ($ExecutionContext.SessionState.Module) {
    Export-ModuleMember -Function Initialize-LoggingFallback
}