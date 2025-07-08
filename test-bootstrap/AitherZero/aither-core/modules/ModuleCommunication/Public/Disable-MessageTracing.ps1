function Disable-MessageTracing {
    <#
    .SYNOPSIS
        Disable message tracing
    .DESCRIPTION
        Turns off message tracing and optionally archives trace logs
    .PARAMETER ArchiveLogs
        Archive existing trace logs
    .PARAMETER ArchivePath
        Path for archived logs
    .EXAMPLE
        Disable-MessageTracing -ArchiveLogs -ArchivePath "archived-traces"
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$ArchiveLogs,
        
        [Parameter()]
        [string]$ArchivePath = "archived-traces"
    )
    
    try {
        $previousState = @{
            WasEnabled = $script:Configuration.EnableTracing
            Level = $script:Configuration.TracingLevel
            LoggingToFile = $script:Configuration.TracingToFile
            FilePath = $script:Configuration.TracingFilePath
        }
        
        # Disable tracing
        $script:Configuration.EnableTracing = $false
        $script:Configuration.TracingLevel = $null
        
        # Archive logs if requested
        if ($ArchiveLogs -and $previousState.LoggingToFile -and $previousState.FilePath) {
            if (Test-Path $previousState.FilePath) {
                # Create archive directory
                if (-not (Test-Path $ArchivePath)) {
                    New-Item -Path $ArchivePath -ItemType Directory -Force | Out-Null
                }
                
                $archiveFileName = "trace-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
                $archiveFullPath = Join-Path $ArchivePath $archiveFileName
                
                # Add closure to trace file
                $closure = @"

# ===============================================
# Trace ended: $(Get-Date)
# Duration: $((Get-Date) - (Get-Item $previousState.FilePath).CreationTime)
# Final state logged below
# ===============================================
"@
                $closure | Out-File -FilePath $previousState.FilePath -Append -Encoding UTF8
                
                # Archive the file
                Move-Item -Path $previousState.FilePath -Destination $archiveFullPath -Force
                
                Write-CustomLog -Level 'INFO' -Message "Trace log archived to: $archiveFullPath"
            }
        }
        
        # Reset file tracing configuration
        $script:Configuration.TracingToFile = $false
        $script:Configuration.TracingFilePath = $null
        
        Write-CustomLog -Level 'SUCCESS' -Message "Message tracing disabled"
        
        return @{
            Success = $true
            PreviousState = $previousState
            LogsArchived = $ArchiveLogs.IsPresent -and $previousState.LoggingToFile
            ArchivePath = if ($ArchiveLogs -and $previousState.LoggingToFile) { $ArchivePath } else { $null }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to disable tracing: $_"
        throw
    }
}