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
        [switch]$Force
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
                
                # Use BITS transfer if available (Windows), otherwise use Invoke-WebRequest
                if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
                    $bitsJob = Start-BitsTransfer -Source $downloadUrl -Destination $fullPath -Asynchronous -DisplayName "ISO Download: $ISOName"
                    
                    while (($bitsJob.JobState -eq 'Transferring') -or ($bitsJob.JobState -eq 'Connecting')) {
                        $progress = [math]::Round(($bitsJob.BytesTransferred / $bitsJob.BytesTotal) * 100, 2)
                        $downloadInfo.Progress = $progress
                        Write-Progress -Activity "Downloading $ISOName" -Status "$progress% Complete" -PercentComplete $progress
                        Start-Sleep -Seconds 2
                        $bitsJob = Get-BitsTransfer -JobId $bitsJob.JobId
                    }
                    
                    if ($bitsJob.JobState -eq 'Transferred') {
                        Complete-BitsTransfer -BitsJob $bitsJob
                        $downloadInfo.Status = 'Completed'
                    } else {
                        Remove-BitsTransfer -BitsJob $bitsJob
                        throw "BITS transfer failed with state: $($bitsJob.JobState)"
                    }                } else {
                    # Fallback to Invoke-WebRequest with progress tracking
                    Invoke-WebRequest -Uri $downloadUrl -OutFile $fullPath
                    $downloadInfo.Status = 'Completed'
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
