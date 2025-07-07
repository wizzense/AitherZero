function Invoke-WebRequestDownload {
    <#
    .SYNOPSIS
        Enhanced Invoke-WebRequest download with progress tracking and timeout handling.
    
    .DESCRIPTION
        Fallback download method using Invoke-WebRequest with enhanced features
        for better reliability and user experience.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,
        
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 3600,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowProgress = $true,
        
        [Parameter(Mandatory = $false)]
        [string]$ISOName = "ISO"
    )
    
    try {
        Write-CustomLog -Level 'INFO' -Message "Starting Invoke-WebRequest download for $ISOName"
        
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        # Configure web request parameters
        $webRequestParams = @{
            Uri = $Url
            OutFile = $FilePath
            TimeoutSec = $TimeoutSeconds
            UserAgent = "AitherZero-ISOManager/1.0"
        }
        
        # Add progress tracking if supported (PowerShell 6+)
        if ($PSVersionTable.PSVersion.Major -ge 6 -and $ShowProgress) {
            # For PowerShell 6+, we can use Write-Progress with Invoke-WebRequest
            $progressPreference = $ProgressPreference
            $ProgressPreference = 'Continue'
            
            try {
                # Use a job to track progress
                $job = Start-Job -ScriptBlock {
                    param($Url, $FilePath, $TimeoutSeconds)
                    
                    try {
                        Invoke-WebRequest -Uri $Url -OutFile $FilePath -TimeoutSec $TimeoutSeconds -UserAgent "AitherZero-ISOManager/1.0"
                        return @{ Success = $true; Error = $null }
                    } catch {
                        return @{ Success = $false; Error = $_.Exception.Message }
                    }
                } -ArgumentList $Url, $FilePath, $TimeoutSeconds
                
                # Monitor job progress by checking file size
                $lastSize = 0
                while ($job.State -eq 'Running') {
                    Start-Sleep -Seconds 2
                    
                    if (Test-Path $FilePath) {
                        $currentSize = (Get-Item $FilePath).Length
                        if ($currentSize -gt $lastSize) {
                            $speedMBps = if ($stopwatch.Elapsed.TotalSeconds -gt 0) {
                                [math]::Round(($currentSize - $lastSize) / 2 / 1MB, 2)  # MB/s over 2 second interval
                            } else {
                                0
                            }
                            
                            $status = "Downloaded: $([math]::Round($currentSize / 1MB, 2)) MB - $speedMBps MB/s"
                            Write-Progress -Activity "Downloading $ISOName (WebRequest)" -Status $status -PercentComplete -1
                            
                            $lastSize = $currentSize
                        }
                    }
                }
                
                # Get job results
                $result = Receive-Job -Job $job
                Remove-Job -Job $job
                
                if (-not $result.Success) {
                    throw $result.Error
                }
                
            } finally {
                $ProgressPreference = $progressPreference
            }
        } else {
            # Standard Invoke-WebRequest without progress tracking
            if ($ShowProgress) {
                Write-Progress -Activity "Downloading $ISOName (WebRequest)" -Status "Download in progress..." -PercentComplete -1
            }
            
            Invoke-WebRequest @webRequestParams
        }
        
        $stopwatch.Stop()
        
        # Final progress update
        if ($ShowProgress) {
            Write-Progress -Activity "Downloading $ISOName (WebRequest)" -Status "Complete" -PercentComplete 100
            Write-Progress -Activity "Downloading $ISOName (WebRequest)" -Completed
        }
        
        # Verify file was created and get statistics
        if (Test-Path $FilePath) {
            $fileSize = (Get-Item $FilePath).Length
            $averageSpeed = if ($stopwatch.Elapsed.TotalSeconds -gt 0) {
                [math]::Round($fileSize / $stopwatch.Elapsed.TotalSeconds / 1MB, 2)
            } else {
                0
            }
            
            Write-CustomLog -Level 'SUCCESS' -Message "WebRequest download completed. File size: $([math]::Round($fileSize / 1MB, 2)) MB, Average speed: $averageSpeed MB/s, Duration: $($stopwatch.Elapsed.TotalMinutes.ToString('F2')) minutes"
            return $true
        } else {
            throw "Download completed but file was not created"
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "WebRequest download failed: $($_.Exception.Message)"
        
        # Clean up partial download
        if (Test-Path $FilePath) {
            try {
                Remove-Item $FilePath -Force
                Write-CustomLog -Level 'INFO' -Message "Cleaned up partial download file"
            } catch {
                Write-CustomLog -Level 'WARN' -Message "Failed to clean up partial download: $($_.Exception.Message)"
            }
        }
        
        return $false
    }
}