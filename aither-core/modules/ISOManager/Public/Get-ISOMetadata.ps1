function Get-ISOMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeVolumeInfo,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeFileList
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Extracting metadata from ISO: $FilePath"
    }

    process {
        try {
            $metadata = @{
                FilePath = $FilePath
                FileName = Split-Path $FilePath -Leaf
                FileSize = (Get-Item $FilePath).Length
                CreatedDate = (Get-Item $FilePath).CreationTime
                ModifiedDate = (Get-Item $FilePath).LastWriteTime
                Checksum = $null
                VolumeInfo = $null
                FileCount = 0
                Files = @()
            }

            # Calculate file checksum
            Write-CustomLog -Level 'INFO' -Message "Calculating file checksum..."
            $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
            $metadata.Checksum = $hash.Hash

            # Extract volume information if available and requested
            if ($IncludeVolumeInfo) {
                Write-CustomLog -Level 'INFO' -Message "Extracting volume information..."
                try {
                    # Try to mount ISO and get volume info (Windows specific)
                    if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
                        $mountResult = Mount-DiskImage -ImagePath $FilePath -PassThru
                        if ($mountResult) {
                            $volume = Get-Volume -DiskImage $mountResult
                            $metadata.VolumeInfo = @{
                                Label = $volume.FileSystemLabel
                                Size = $volume.Size
                                FileSystem = $volume.FileSystem
                                DriveLetter = $volume.DriveLetter
                            }

                            # Get file list if requested
                            if ($IncludeFileList -and $volume.DriveLetter) {
                                $drivePath = "$($volume.DriveLetter):\"
                                $files = Get-ChildItem -Path $drivePath -Recurse -File | Select-Object Name, Length, FullName
                                $metadata.Files = $files
                                $metadata.FileCount = $files.Count
                            }

                            # Dismount the ISO
                            Dismount-DiskImage -ImagePath $FilePath | Out-Null
                        }
                    } else {
                        # Linux/macOS approach using file command or other tools
                        if (Get-Command file -ErrorAction SilentlyContinue) {
                            $fileInfo = file $FilePath
                            $metadata.VolumeInfo = @{
                                FileType = $fileInfo
                                DetectedFormat = 'ISO'
                            }
                        }
                    }
                } catch {
                    Write-CustomLog -Level 'WARN' -Message "Could not extract volume information: $($_.Exception.Message)"
                }
            }

            # Try to detect ISO type based on common patterns
            $fileName = Split-Path $FilePath -Leaf
            $metadata.DetectedType = switch -Regex ($fileName.ToLower()) {
                'windows|win10|win11|server' { 'Windows' }
                'ubuntu|centos|rhel|debian|fedora|suse|linux' { 'Linux' }
                default { 'Unknown' }
            }

            # Extract version information from filename
            if ($fileName -match '(\d+\.?\d*\.?\d*)') {
                $metadata.DetectedVersion = $matches[1]
            }

            # Extract architecture from filename
            $metadata.DetectedArchitecture = switch -Regex ($fileName.ToLower()) {
                'x64|amd64|x86_64' { 'x64' }
                'x86|i386' { 'x86' }
                'arm64|aarch64' { 'ARM64' }
                default { 'Unknown' }
            }

            Write-CustomLog -Level 'SUCCESS' -Message "Successfully extracted metadata from ISO"
            return $metadata
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to extract ISO metadata: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Completed ISO metadata extraction"
    }
}
