function Get-ISODownload {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ISOName,

        [Parameter(Mandatory = $false)]
        [string]$Version = "latest",

        [Parameter(Mandatory = $false)]
        [string]$Architecture = "x64",

        [Parameter(Mandatory = $false)]
        [string]$Language = "en-US",

        [Parameter(Mandatory = $false)]
        [ValidateSet('Windows', 'Linux', 'Custom')]
        [string]$ISOType = 'Windows',

        [Parameter(Mandatory = $false)]
        [string]$CustomURL,

        [Parameter(Mandatory = $false)]
        [string]$DownloadPath,

        [Parameter(Mandatory = $false)]
        [switch]$VerifyIntegrity,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [int]$RetryCount = 3,

        [Parameter(Mandatory = $false)]
        [int]$RetryDelaySeconds = 30,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 3600,

        [Parameter(Mandatory = $false)]
        [switch]$UseHttpClient,

        [Parameter(Mandatory = $false)]
        [switch]$ShowProgress = $true
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting ISO download: $ISOName"

        # Set default download path if not specified
        if (-not $DownloadPath) {
            $DownloadPath = Join-Path $env:TEMP "AitherZero-ISOs"
        }

        # Ensure download directory exists
        if (-not (Test-Path $DownloadPath)) {
            New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
        }
    }

    process {
        try {
            $downloadInfo = @{
                Name = $ISOName
                Version = $Version
                Architecture = $Architecture
                Language = $Language
                Type = $ISOType
                DownloadPath = $DownloadPath
                Status = 'Initializing'
                StartTime = Get-Date
                Progress = 0
            }

            # Determine download URL based on ISO type
            $downloadUrl = switch ($ISOType) {
                'Windows' {
                    Get-WindowsISOUrl -ISOName $ISOName -Version $Version -Architecture $Architecture -Language $Language
                }
                'Linux' {
                    Get-LinuxISOUrl -ISOName $ISOName -Version $Version -Architecture $Architecture
                }
                'Custom' {
                    if (-not $CustomURL) {
                        throw "CustomURL parameter is required when ISOType is 'Custom'"
                    }
                    $CustomURL
                }
                default {
                    throw "Unsupported ISO type: $ISOType"
                }
            }

            if (-not $downloadUrl) {
                throw "Could not determine download URL for ISO: $ISOName"
            }

            $fileName = Split-Path $downloadUrl -Leaf
            if (-not $fileName -or $fileName -notmatch '\.(iso|img)$') {
                $fileName = "$ISOName-$Version-$Architecture.iso"
            }

            $fullPath = Join-Path $DownloadPath $fileName
            $downloadInfo.FilePath = $fullPath
            $downloadInfo.URL = $downloadUrl

            # Check if file already exists
            if ((Test-Path $fullPath) -and -not $Force) {
                Write-CustomLog -Level 'WARN' -Message "ISO already exists: $fullPath. Use -Force to overwrite."
                $downloadInfo.Status = 'Already Exists'
                return $downloadInfo
            }

            if ($PSCmdlet.ShouldProcess($fullPath, "Download ISO")) {
                Write-CustomLog -Level 'INFO' -Message "Downloading from: $downloadUrl"
                Write-CustomLog -Level 'INFO' -Message "Saving to: $fullPath"

                $downloadInfo.Status = 'Downloading'

                # Enhanced download with retry logic and modern HTTP clients
                $downloadSuccess = $false
                $lastError = $null
                
                for ($retry = 0; $retry -lt $RetryCount; $retry++) {
                    try {
                        if ($retry -gt 0) {
                            Write-CustomLog -Level 'INFO' -Message "Retry attempt $retry of $($RetryCount - 1) for $ISOName"
                            Start-Sleep -Seconds $RetryDelaySeconds
                        }
                        
                        $downloadInfo.Status = 'Downloading'
                        
                        # Choose download method based on platform and preferences
                        if ($UseHttpClient -or (-not (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue))) {
                            # Use modern HttpClient approach
                            $downloadSuccess = Invoke-ModernHttpDownload -Url $downloadUrl -FilePath $fullPath -TimeoutSeconds $TimeoutSeconds -ShowProgress:$ShowProgress -ISOName $ISOName
                        } elseif (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
                            # Use BITS transfer (Windows)
                            $downloadSuccess = Invoke-BitsDownload -Url $downloadUrl -FilePath $fullPath -ISOName $ISOName -ShowProgress:$ShowProgress
                        } else {
                            # Fallback to Invoke-WebRequest with enhanced features
                            $downloadSuccess = Invoke-WebRequestDownload -Url $downloadUrl -FilePath $fullPath -TimeoutSeconds $TimeoutSeconds -ShowProgress:$ShowProgress -ISOName $ISOName
                        }
                        
                        if ($downloadSuccess) {
                            $downloadInfo.Status = 'Completed'
                            break
                        }
                        
                    } catch {
                        $lastError = $_.Exception.Message
                        Write-CustomLog -Level 'WARN' -Message "Download attempt $($retry + 1) failed: $lastError"
                        
                        # Clean up partial download
                        if (Test-Path $fullPath) {
                            try {
                                Remove-Item $fullPath -Force
                            } catch {
                                Write-CustomLog -Level 'WARN' -Message "Failed to clean up partial download: $($_.Exception.Message)"
                            }
                        }
                        
                        if ($retry -eq ($RetryCount - 1)) {
                            throw "Download failed after $RetryCount attempts. Last error: $lastError"
                        }
                    }
                }
                
                if (-not $downloadSuccess) {
                    throw "Download failed after $RetryCount attempts. Last error: $lastError"
                }

                $downloadInfo.EndTime = Get-Date
                $downloadInfo.Progress = 100

                # Verify file integrity if requested
                if ($VerifyIntegrity) {
                    Write-CustomLog -Level 'INFO' -Message "Verifying ISO integrity..."
                    $verificationResult = Test-ISOIntegrity -FilePath $fullPath -ISOName $ISOName -Version $Version
                    $downloadInfo.IntegrityVerified = $verificationResult.Valid
                    $downloadInfo.Checksum = $verificationResult.Checksum
                }

                Write-CustomLog -Level 'SUCCESS' -Message "ISO download completed: $fullPath"
                return $downloadInfo
            }
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to download ISO '$ISOName': $($_.Exception.Message)"
            $downloadInfo.Status = 'Failed'
            $downloadInfo.Error = $_.Exception.Message
            $downloadInfo.EndTime = Get-Date
            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Completed ISO download operation for: $ISOName"
    }
}
