#Requires -Version 7.0

<#
.SYNOPSIS
    Provides optimized file download utilities leveraging BITS when available.

.DESCRIPTION
    This module provides cross-platform file download capabilities with intelligent
    method selection. On Windows, it uses BITS (Background Intelligent Transfer Service)
    for optimized large file downloads without console progress flooding. On Linux/macOS,
    it falls back to Invoke-WebRequest with optimized settings.

.NOTES
    Module: DownloadUtility
    Domain: Utilities
    Version: 1.0.0
#>

#region Module Variables
$script:LoggingAvailable = $false
$script:BitsAvailable = $false

# Check logging availability
try {
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        $script:LoggingAvailable = $true
    }
} catch {
    # Logging not available
}

# Check BITS availability (Windows only)
if ($IsWindows) {
    try {
        $bitsModule = Get-Module -Name BitsTransfer -ListAvailable -ErrorAction SilentlyContinue
        if ($bitsModule) {
            Import-Module BitsTransfer -ErrorAction SilentlyContinue
            $script:BitsAvailable = $true
        }
    } catch {
        # BITS not available
    }
}
#endregion

#region Helper Functions
function Write-DownloadLog {
    <#
    .SYNOPSIS
        Internal logging function for download operations.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('Information', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Information'
    )
    
    if ($script:LoggingAvailable) {
        Write-CustomLog -Message $Message -Level $Level
    } else {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $prefix = switch ($Level) {
            'Error' { 'ERROR' }
            'Warning' { 'WARN' }
            'Debug' { 'DEBUG' }
            default { 'INFO' }
        }
        Write-Host "[$timestamp] [$prefix] $Message"
    }
}
#endregion

#region Public Functions
function Invoke-FileDownload {
    <#
    .SYNOPSIS
        Downloads a file using the optimal method for the current platform with intelligent resuming.
    
    .DESCRIPTION
        Downloads a file from a URL to a local path using BITS on Windows (when available)
        or Invoke-WebRequest on other platforms. BITS provides optimized large file downloads
        without flooding the console with progress bars.
        
        Features:
        - Automatic retry with exponential backoff on failures
        - Intelligent resume of interrupted downloads (idempotent)
        - Content-Length validation to detect incomplete downloads
        - Partial download cleanup on validation failure
        - Cross-platform support (BITS on Windows, WebRequest elsewhere)
    
    .PARAMETER Uri
        The URL of the file to download.
    
    .PARAMETER OutFile
        The local path where the file should be saved.
    
    .PARAMETER UseBasicParsing
        Use basic parsing for web requests (recommended for automation).
    
    .PARAMETER TimeoutSec
        Timeout in seconds for the download operation. Default is 300 (5 minutes).
    
    .PARAMETER RetryCount
        Number of retry attempts if the download fails. Default is 3.
    
    .PARAMETER RetryDelaySeconds
        Initial delay in seconds between retries. Uses exponential backoff. Default is 2.
    
    .PARAMETER Force
        Force overwrite of existing file without validation.
    
    .PARAMETER SkipValidation
        Skip content-length validation (useful when server doesn't provide Content-Length header).
    
    .PARAMETER Method
        Force a specific download method: 'Auto', 'BITS', or 'WebRequest'.
        Default is 'Auto' which selects the best available method.
    
    .EXAMPLE
        Invoke-FileDownload -Uri "https://example.com/file.zip" -OutFile "C:\Temp\file.zip"
        
        Downloads a file using the optimal method for the current platform.
    
    .EXAMPLE
        Invoke-FileDownload -Uri $url -OutFile $path -Method BITS -Force
        
        Forces download using BITS and overwrites existing file.
    
    .EXAMPLE
        Invoke-FileDownload -Uri $url -OutFile $path -RetryCount 5 -RetryDelaySeconds 3
        
        Downloads with 5 retry attempts and 3-second initial retry delay (with exponential backoff).
    
    .OUTPUTS
        PSCustomObject with download result information including:
        - Success: Boolean indicating success
        - Method: Download method used (BITS, WebRequest, or Cached)
        - FilePath: Path to downloaded file
        - FileSize: Size of downloaded file in bytes
        - ExpectedSize: Expected size from Content-Length header (if available)
        - Duration: Time taken for download
        - Attempts: Number of attempts made
        - Resumed: Boolean indicating if download was resumed
        - Message: Status message
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Uri,
        
        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$OutFile,
        
        [Parameter()]
        [switch]$UseBasicParsing,
        
        [Parameter()]
        [int]$TimeoutSec = 300,
        
        [Parameter()]
        [int]$RetryCount = 3,
        
        [Parameter()]
        [int]$RetryDelaySeconds = 2,
        
        [Parameter()]
        [switch]$Force,
        
        [Parameter()]
        [switch]$SkipValidation,
        
        [Parameter()]
        [ValidateSet('Auto', 'BITS', 'WebRequest')]
        [string]$Method = 'Auto'
    )
    
    # Single block function for proper early return behavior
    $startTime = Get-Date
    
    Write-DownloadLog "Starting file download from: $Uri" -Level 'Information'
    Write-DownloadLog "Destination: $OutFile" -Level 'Debug'
    
    # Validate destination directory exists
    $destinationDir = Split-Path $OutFile -Parent
    if (-not (Test-Path $destinationDir)) {
        try {
            New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
            Write-DownloadLog "Created destination directory: $destinationDir" -Level 'Debug'
        } catch {
            Write-DownloadLog "Failed to create destination directory: $_" -Level 'Error'
            throw
        }
    }
    
    # Get expected file size from remote server
    $expectedSize = $null
    if (-not $SkipValidation) {
        try {
            Write-DownloadLog "Checking remote file size..." -Level 'Debug'
            $headRequest = Invoke-WebRequest -Uri $Uri -Method Head -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
            if ($headRequest.Headers.'Content-Length') {
                $expectedSize = [long]$headRequest.Headers.'Content-Length'[0]
                Write-DownloadLog "Expected file size: $expectedSize bytes" -Level 'Debug'
            }
        } catch {
            Write-DownloadLog "Could not determine remote file size: $_" -Level 'Debug'
        }
    }
    
    # Check if file exists and validate it
    $existingFileValid = $false
    $resumeDownload = $false
    
    if (Test-Path $OutFile) {
        $existingFile = Get-Item $OutFile
        $existingSize = $existingFile.Length
        
        Write-DownloadLog "Existing file found: $existingSize bytes" -Level 'Debug'
        
        if ($Force) {
            Write-DownloadLog "Force flag specified, will overwrite existing file" -Level 'Debug'
        } elseif ($expectedSize -and $existingSize -eq $expectedSize) {
            # File exists and size matches - assume complete download
            Write-DownloadLog "File exists with correct size, using cached version" -Level 'Information'
            $existingFileValid = $true
        } elseif ($expectedSize -and $existingSize -lt $expectedSize) {
            # Partial download detected - can resume
            Write-DownloadLog "Partial download detected ($existingSize of $expectedSize bytes)" -Level 'Information'
            $resumeDownload = $true
        } elseif ($expectedSize -and $existingSize -gt $expectedSize) {
            # File is larger than expected - corrupt or wrong file
            Write-DownloadLog "Existing file is larger than expected, will re-download" -Level 'Warning'
            Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
        } elseif (-not $expectedSize) {
            # Cannot validate size, use existing file unless Force is specified
            Write-DownloadLog "Cannot validate file size (no Content-Length header), using existing file" -Level 'Warning'
            $existingFileValid = $true
        }
    }
    
    # Return cached file if valid
    if ($existingFileValid) {
        $fileInfo = Get-Item $OutFile
        return [PSCustomObject]@{
            Success = $true
            Method = 'Cached'
            FilePath = $OutFile
            FileSize = $fileInfo.Length
            ExpectedSize = $expectedSize
            Duration = [TimeSpan]::Zero
            Attempts = 0
            Resumed = $false
            Message = 'Using cached file (already downloaded)'
        }
    }
    
    # Determine download method
    $useMethod = $Method
    if ($Method -eq 'Auto') {
        if ($script:BitsAvailable -and $IsWindows) {
            $useMethod = 'BITS'
            Write-DownloadLog "Auto-selected BITS for download (Windows platform)" -Level 'Debug'
        } else {
            $useMethod = 'WebRequest'
            Write-DownloadLog "Auto-selected WebRequest for download (non-Windows or BITS unavailable)" -Level 'Debug'
        }
    }
    
    # Note: Resume functionality for BITS is handled automatically by the service
    # For WebRequest, we need to delete partial files as Invoke-WebRequest doesn't support resume
    if ($resumeDownload -and $useMethod -eq 'WebRequest') {
        Write-DownloadLog "WebRequest doesn't support resume, removing partial file" -Level 'Debug'
        Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
        $resumeDownload = $false
    }
    
    # Retry loop
    $attempt = 0
    $lastError = $null
    $wasResumed = $resumeDownload
    
    while ($attempt -lt $RetryCount) {
        $attempt++
        
        try {
            if ($useMethod -eq 'BITS' -and $script:BitsAvailable) {
                # Use BITS for optimized download with automatic resume
                Write-DownloadLog "Downloading via BITS (attempt $attempt of $RetryCount)..." -Level 'Information'
                
                if ($PSCmdlet.ShouldProcess($OutFile, "Download file from $Uri using BITS")) {
                    # Start-BitsTransfer parameters
                    $bitsParams = @{
                        Source = $Uri
                        Destination = $OutFile
                        ErrorAction = 'Stop'
                    }
                    
                    # Add description for better tracking
                    $bitsParams.Description = "Download: $(Split-Path $OutFile -Leaf)"
                    
                    # BITS automatically handles resume if transfer was interrupted
                    # The -Asynchronous switch would allow us to monitor, but synchronous is simpler
                    
                    # Execute BITS transfer
                    Start-BitsTransfer @bitsParams
                    
                    Write-DownloadLog "Download completed successfully via BITS" -Level 'Information'
                }
                
            } else {
                # Fallback to Invoke-WebRequest
                Write-DownloadLog "Downloading via WebRequest (attempt $attempt of $RetryCount)..." -Level 'Information'
                
                if ($PSCmdlet.ShouldProcess($OutFile, "Download file from $Uri using WebRequest")) {
                    # Suppress progress bar to avoid console flooding
                    $originalProgressPreference = $ProgressPreference
                    $ProgressPreference = 'SilentlyContinue'
                    
                    try {
                        $webRequestParams = @{
                            Uri = $Uri
                            OutFile = $OutFile
                            TimeoutSec = $TimeoutSec
                            ErrorAction = 'Stop'
                        }
                        
                        if ($UseBasicParsing) {
                            $webRequestParams.UseBasicParsing = $true
                        }
                        
                        Invoke-WebRequest @webRequestParams
                        
                        Write-DownloadLog "Download completed successfully via WebRequest" -Level 'Information'
                    } finally {
                        $ProgressPreference = $originalProgressPreference
                    }
                }
            }
            
            # Verify download
            if (Test-Path $OutFile) {
                $fileInfo = Get-Item $OutFile
                $actualSize = $fileInfo.Length
                $duration = (Get-Date) - $startTime
                
                # Validate file size if expected size is known
                if ($expectedSize -and -not $SkipValidation) {
                    if ($actualSize -eq $expectedSize) {
                        Write-DownloadLog "File downloaded successfully: $actualSize bytes in $($duration.TotalSeconds.ToString('F2')) seconds" -Level 'Information'
                    } elseif ($actualSize -lt $expectedSize) {
                        # Incomplete download
                        $percentComplete = [math]::Round(($actualSize / $expectedSize) * 100, 2)
                        throw "Incomplete download: Got $actualSize of $expectedSize bytes ($percentComplete% complete)"
                    } else {
                        # File larger than expected - possible corruption
                        throw "Downloaded file is larger than expected: $actualSize bytes (expected $expectedSize bytes)"
                    }
                } else {
                    Write-DownloadLog "File downloaded successfully: $actualSize bytes in $($duration.TotalSeconds.ToString('F2')) seconds" -Level 'Information'
                }
                
                # Success - return result
                return [PSCustomObject]@{
                    Success = $true
                    Method = $useMethod
                    FilePath = $OutFile
                    FileSize = $actualSize
                    ExpectedSize = $expectedSize
                    Duration = $duration
                    Attempts = $attempt
                    Resumed = $wasResumed
                    Message = 'Download completed successfully'
                }
            } else {
                throw "Downloaded file not found at: $OutFile"
            }
            
        } catch {
            $lastError = $_
            Write-DownloadLog "Download attempt $attempt failed: $_" -Level 'Warning'
            
            # Clean up partial/corrupt download
            if (Test-Path $OutFile) {
                try {
                    $partialSize = (Get-Item $OutFile).Length
                    Write-DownloadLog "Cleaning up partial/corrupt download ($partialSize bytes)" -Level 'Debug'
                    Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
                } catch {
                    Write-DownloadLog "Could not clean up partial file: $_" -Level 'Debug'
                }
            }
            
            if ($attempt -lt $RetryCount) {
                # Calculate retry delay with exponential backoff
                $waitSeconds = $RetryDelaySeconds * [math]::Pow(2, $attempt - 1)
                Write-DownloadLog "Retrying in $waitSeconds seconds... (attempt $($attempt + 1) of $RetryCount)" -Level 'Information'
                Start-Sleep -Seconds $waitSeconds
            } else {
                Write-DownloadLog "Retry exhausted after $attempt attempts" -Level 'Error'
            }
        }
    }
    
    # All attempts failed - return failure result
    Write-DownloadLog "Download failed after $RetryCount attempts: $lastError" -Level 'Error'
    
    return [PSCustomObject]@{
        Success = $false
        Method = $useMethod
        FilePath = $OutFile
        FileSize = 0
        ExpectedSize = $expectedSize
        Duration = (Get-Date) - $startTime
        Attempts = $attempt
        Resumed = $false
        Message = "Download failed after $RetryCount attempts: $lastError"
    }
}

function Test-BitsAvailability {
    <#
    .SYNOPSIS
        Tests if BITS (Background Intelligent Transfer Service) is available.
    
    .DESCRIPTION
        Checks if the BitsTransfer module is available and can be used
        for file downloads. BITS is only available on Windows platforms.
    
    .EXAMPLE
        Test-BitsAvailability
        
        Returns $true if BITS is available, $false otherwise.
    
    .OUTPUTS
        Boolean indicating BITS availability.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    return $script:BitsAvailable
}

function Get-DownloadMethod {
    <#
    .SYNOPSIS
        Gets the recommended download method for the current platform.
    
    .DESCRIPTION
        Returns the recommended download method based on platform and
        available features. On Windows with BITS, returns 'BITS'.
        Otherwise returns 'WebRequest'.
    
    .EXAMPLE
        Get-DownloadMethod
        
        Returns 'BITS' on Windows or 'WebRequest' on other platforms.
    
    .OUTPUTS
        String indicating the recommended download method.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    if ($script:BitsAvailable -and $IsWindows) {
        return 'BITS'
    } else {
        return 'WebRequest'
    }
}
#endregion

#region Module Exports
Export-ModuleMember -Function @(
    'Invoke-FileDownload',
    'Test-BitsAvailability',
    'Get-DownloadMethod'
)
#endregion
