function Invoke-BitsDownload {
    <#
    .SYNOPSIS
        Enhanced BITS download implementation with better error handling and progress tracking.
    
    .DESCRIPTION
        Uses Windows BITS service for reliable, resumable downloads with improved
        error handling and progress tracking.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,
        
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $false)]
        [string]$ISOName = "ISO",
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowProgress = $true
    )
    
    try {
        Write-CustomLog -Level 'INFO' -Message "Starting BITS download for $ISOName"
        
        # Start BITS transfer
        $bitsJob = Start-BitsTransfer -Source $Url -Destination $FilePath -Asynchronous -DisplayName "AitherZero ISO Download: $ISOName"
        
        if (-not $bitsJob) {
            throw "Failed to start BITS transfer"
        }
        
        Write-CustomLog -Level 'INFO' -Message "BITS job started with ID: $($bitsJob.JobId)"
        
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $lastProgress = 0
        $progressUpdateInterval = 2  # Update every 2 seconds
        
        # Monitor transfer progress
        while ($true) {
            Start-Sleep -Seconds $progressUpdateInterval
            
            try {
                $bitsJob = Get-BitsTransfer -JobId $bitsJob.JobId
                
                if ($bitsJob.JobState -eq 'Transferred') {
                    Complete-BitsTransfer -BitsJob $bitsJob
                    break
                } elseif ($bitsJob.JobState -eq 'Error') {
                    $errorInfo = $bitsJob.ErrorContext + ": " + $bitsJob.ErrorDescription
                    Remove-BitsTransfer -BitsJob $bitsJob
                    throw "BITS transfer failed: $errorInfo"
                } elseif ($bitsJob.JobState -eq 'Cancelled') {
                    Remove-BitsTransfer -BitsJob $bitsJob
                    throw "BITS transfer was cancelled"
                } elseif ($bitsJob.JobState -in @('Transferring', 'Connecting', 'Queued')) {
                    # Calculate progress
                    $progress = if ($bitsJob.BytesTotal -gt 0) {
                        [math]::Round(($bitsJob.BytesTransferred / $bitsJob.BytesTotal) * 100, 2)
                    } else {
                        0
                    }
                    
                    # Show progress if enabled and progress has changed
                    if ($ShowProgress -and ($progress -ne $lastProgress)) {
                        $speedMBps = if ($stopwatch.Elapsed.TotalSeconds -gt 0) {
                            [math]::Round($bitsJob.BytesTransferred / $stopwatch.Elapsed.TotalSeconds / 1MB, 2)
                        } else {
                            0
                        }
                        
                        $status = "$progress% Complete - $([math]::Round($bitsJob.BytesTransferred / 1MB, 2)) MB / $([math]::Round($bitsJob.BytesTotal / 1MB, 2)) MB - $speedMBps MB/s"
                        Write-Progress -Activity "Downloading $ISOName (BITS)" -Status $status -PercentComplete $progress
                        
                        $lastProgress = $progress
                    }
                    
                    Write-CustomLog -Level 'DEBUG' -Message "BITS progress: $progress% ($($bitsJob.JobState))"
                } else {
                    Write-CustomLog -Level 'WARN' -Message "Unexpected BITS job state: $($bitsJob.JobState)"
                }
                
            } catch [System.Management.Automation.ItemNotFoundException] {
                # Job was removed or completed
                Write-CustomLog -Level 'INFO' -Message "BITS job completed or removed"
                break
            }
        }
        
        $stopwatch.Stop()
        
        # Final progress update
        if ($ShowProgress) {
            Write-Progress -Activity "Downloading $ISOName (BITS)" -Status "Complete" -PercentComplete 100
            Write-Progress -Activity "Downloading $ISOName (BITS)" -Completed
        }
        
        # Verify file was created
        if (Test-Path $FilePath) {
            $fileSize = (Get-Item $FilePath).Length
            $averageSpeed = if ($stopwatch.Elapsed.TotalSeconds -gt 0) {
                [math]::Round($fileSize / $stopwatch.Elapsed.TotalSeconds / 1MB, 2)
            } else {
                0
            }
            
            Write-CustomLog -Level 'SUCCESS' -Message "BITS download completed. File size: $([math]::Round($fileSize / 1MB, 2)) MB, Average speed: $averageSpeed MB/s, Duration: $($stopwatch.Elapsed.TotalMinutes.ToString('F2')) minutes"
            return $true
        } else {
            throw "Download completed but file was not created"
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "BITS download failed: $($_.Exception.Message)"
        
        # Clean up failed BITS job
        try {
            if ($bitsJob) {
                Remove-BitsTransfer -BitsJob $bitsJob
            }
        } catch {
            Write-CustomLog -Level 'WARN' -Message "Failed to clean up BITS job: $($_.Exception.Message)"
        }
        
        return $false
    }
}