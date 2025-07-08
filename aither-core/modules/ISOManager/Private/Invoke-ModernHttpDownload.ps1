function Invoke-ModernHttpDownload {
    <#
    .SYNOPSIS
        Modern HTTP download implementation with progress tracking and advanced features.
    
    .DESCRIPTION
        Uses .NET HttpClient for robust, cancelable downloads with proper timeout handling,
        progress tracking, and resume capabilities.
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
        [string]$ISOName = "ISO",
        
        [Parameter(Mandatory = $false)]
        [switch]$AllowResume = $true
    )
    
    try {
        Write-CustomLog -Level 'INFO' -Message "Starting modern HTTP download for $ISOName"
        
        # Create HttpClient with proper configuration
        $httpClient = New-Object System.Net.Http.HttpClient
        $httpClient.Timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)
        $httpClient.DefaultRequestHeaders.Add("User-Agent", "AitherZero-ISOManager/1.0")
        
        # Check if we can resume download
        $startPosition = 0
        if ($AllowResume -and (Test-Path $FilePath)) {
            $existingFile = Get-Item $FilePath
            $startPosition = $existingFile.Length
            Write-CustomLog -Level 'INFO' -Message "Resuming download from position: $startPosition bytes"
        }
        
        # Create request with range header for resume capability
        $request = New-Object System.Net.Http.HttpRequestMessage
        $request.Method = [System.Net.Http.HttpMethod]::Get
        $request.RequestUri = $Url
        
        if ($startPosition -gt 0) {
            $request.Headers.Range = New-Object System.Net.Http.Headers.RangeHeaderValue($startPosition, $null)
        }
        
        # Get response
        $response = $httpClient.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
        
        if (-not $response.IsSuccessStatusCode) {
            throw "HTTP request failed with status: $($response.StatusCode) - $($response.ReasonPhrase)"
        }
        
        # Get content length
        $totalSize = if ($response.Content.Headers.ContentLength) {
            $response.Content.Headers.ContentLength.Value
        } else {
            0
        }
        
        if ($startPosition -gt 0) {
            $totalSize += $startPosition
        }
        
        Write-CustomLog -Level 'INFO' -Message "Download size: $([math]::Round($totalSize / 1MB, 2)) MB"
        
        # Create or open file for writing
        $fileMode = if ($startPosition -gt 0) { [System.IO.FileMode]::Append } else { [System.IO.FileMode]::Create }
        $fileStream = New-Object System.IO.FileStream($FilePath, $fileMode, [System.IO.FileAccess]::Write)
        
        try {
            # Get content stream
            $contentStream = $response.Content.ReadAsStreamAsync().Result
            
            # Download with progress tracking
            $buffer = New-Object byte[] 8192
            $totalBytesRead = $startPosition
            $progressUpdateInterval = 1000  # Update every 1000 iterations
            $iteration = 0
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            while ($true) {
                $bytesRead = $contentStream.ReadAsync($buffer, 0, $buffer.Length).Result
                
                if ($bytesRead -eq 0) {
                    break
                }
                
                $fileStream.Write($buffer, 0, $bytesRead)
                $totalBytesRead += $bytesRead
                
                # Update progress periodically
                if ($ShowProgress -and ($iteration % $progressUpdateInterval -eq 0)) {
                    $percentComplete = if ($totalSize -gt 0) {
                        [math]::Round(($totalBytesRead / $totalSize) * 100, 2)
                    } else {
                        0
                    }
                    
                    $speedMBps = if ($stopwatch.Elapsed.TotalSeconds -gt 0) {
                        [math]::Round(($totalBytesRead - $startPosition) / $stopwatch.Elapsed.TotalSeconds / 1MB, 2)
                    } else {
                        0
                    }
                    
                    $status = "$percentComplete% Complete - $([math]::Round($totalBytesRead / 1MB, 2)) MB / $([math]::Round($totalSize / 1MB, 2)) MB - $speedMBps MB/s"
                    Write-Progress -Activity "Downloading $ISOName" -Status $status -PercentComplete $percentComplete
                }
                
                $iteration++
            }
            
            $stopwatch.Stop()
            
            # Final progress update
            if ($ShowProgress) {
                Write-Progress -Activity "Downloading $ISOName" -Status "Complete" -PercentComplete 100
                Write-Progress -Activity "Downloading $ISOName" -Completed
            }
            
            $averageSpeed = if ($stopwatch.Elapsed.TotalSeconds -gt 0) {
                [math]::Round(($totalBytesRead - $startPosition) / $stopwatch.Elapsed.TotalSeconds / 1MB, 2)
            } else {
                0
            }
            
            Write-CustomLog -Level 'SUCCESS' -Message "Download completed. Total size: $([math]::Round($totalBytesRead / 1MB, 2)) MB, Average speed: $averageSpeed MB/s, Duration: $($stopwatch.Elapsed.TotalMinutes.ToString('F2')) minutes"
            
            return $true
            
        } finally {
            if ($fileStream) {
                $fileStream.Close()
                $fileStream.Dispose()
            }
            
            if ($contentStream) {
                $contentStream.Close()
                $contentStream.Dispose()
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Modern HTTP download failed: $($_.Exception.Message)"
        return $false
        
    } finally {
        if ($response) {
            $response.Dispose()
        }
        
        if ($httpClient) {
            $httpClient.Dispose()
        }
    }
}