function Compress-ISOFile {
    <#
    .SYNOPSIS
        Compresses ISO files using available compression methods.

    .DESCRIPTION
        Compresses large ISO files to save storage space using platform-appropriate
        compression methods (gzip, 7-zip, or PowerShell compression).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [switch]$RemoveOriginal,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Auto', 'GZip', '7Zip', 'PowerShell')]
        [string]$Method = 'Auto'
    )

    try {
        if (-not (Test-Path $FilePath)) {
            throw "Source file not found: $FilePath"
        }

        $originalSize = (Get-Item $FilePath).Length

        if (-not $OutputPath) {
            $OutputPath = $FilePath + ".gz"
        }

        Write-CustomLog -Level 'INFO' -Message "Compressing $([System.IO.Path]::GetFileName($FilePath)) ($([math]::Round($originalSize / 1MB, 2)) MB)"

        $result = @{
            Success = $false
            OriginalSize = $originalSize
            CompressedSize = 0
            SpaceSaved = 0
            CompressionRatio = 0
            Method = $Method
            OutputPath = $OutputPath
            Error = $null
        }

        # Determine compression method
        if ($Method -eq 'Auto') {
            if (Get-Command 7z -ErrorAction SilentlyContinue) {
                $Method = '7Zip'
            } elseif (Get-Command gzip -ErrorAction SilentlyContinue) {
                $Method = 'GZip'
            } else {
                $Method = 'PowerShell'
            }
        }

        $result.Method = $Method

        # Perform compression based on method
        switch ($Method) {
            '7Zip' {
                $7zArgs = @('a', '-tgzip', $OutputPath, $FilePath)
                $process = Start-Process -FilePath '7z' -ArgumentList $7zArgs -Wait -NoNewWindow -PassThru

                if ($process.ExitCode -ne 0) {
                    throw "7-Zip compression failed with exit code $($process.ExitCode)"
                }
            }

            'GZip' {
                $gzipArgs = @('-c', $FilePath)
                $process = Start-Process -FilePath 'gzip' -ArgumentList $gzipArgs -RedirectStandardOutput $OutputPath -Wait -NoNewWindow -PassThru

                if ($process.ExitCode -ne 0) {
                    throw "GZip compression failed with exit code $($process.ExitCode)"
                }
            }

            'PowerShell' {
                # Use .NET compression
                [System.IO.FileStream]$inputStream = [System.IO.File]::OpenRead($FilePath)
                [System.IO.FileStream]$outputStream = [System.IO.File]::Create($OutputPath)
                [System.IO.Compression.GZipStream]$gzipStream = New-Object System.IO.Compression.GZipStream($outputStream, [System.IO.Compression.CompressionMode]::Compress)

                try {
                    $inputStream.CopyTo($gzipStream)
                } finally {
                    $gzipStream.Close()
                    $outputStream.Close()
                    $inputStream.Close()
                }
            }

            default {
                throw "Unsupported compression method: $Method"
            }
        }

        # Verify compressed file was created
        if (-not (Test-Path $OutputPath)) {
            throw "Compressed file was not created: $OutputPath"
        }

        $compressedSize = (Get-Item $OutputPath).Length
        $result.CompressedSize = $compressedSize
        $result.SpaceSaved = $originalSize - $compressedSize
        $result.CompressionRatio = [math]::Round((($originalSize - $compressedSize) / $originalSize) * 100, 2)

        # Remove original file if requested
        if ($RemoveOriginal) {
            Remove-Item -Path $FilePath -Force
            Write-CustomLog -Level 'INFO' -Message "Original file removed: $([System.IO.Path]::GetFileName($FilePath))"
        }

        $result.Success = $true

        Write-CustomLog -Level 'SUCCESS' -Message "Compression completed: $([math]::Round($compressedSize / 1MB, 2)) MB ($($result.CompressionRatio)% reduction) using $Method"

        return $result

    } catch {
        $result.Error = $_.Exception.Message
        Write-CustomLog -Level 'ERROR' -Message "Compression failed: $($_.Exception.Message)"

        # Clean up partial compressed file
        if ($OutputPath -and (Test-Path $OutputPath)) {
            try {
                Remove-Item -Path $OutputPath -Force
            } catch {
                Write-CustomLog -Level 'WARN' -Message "Failed to clean up partial compressed file: $($_.Exception.Message)"
            }
        }

        return $result
    }
}
