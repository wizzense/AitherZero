#Requires -Version 7.0

<#
.SYNOPSIS
    Core ISO management module - extraction, mounting, validation.

.DESCRIPTION
    Provides cross-platform ISO management capabilities including:
    - ISO extraction (Windows: Mount-DiskImage, Linux/macOS: 7z)
    - ISO mounting and unmounting
    - ISO validation and integrity checking
    - Cross-platform path handling

.NOTES
    This module is part of the AitherZero infrastructure automation platform.
    Developed using Test-Driven Development (TDD) methodology.
#>

#region Helper Functions

function Write-ISOLog {
    <#
    .SYNOPSIS
        Write log messages for ISO operations.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('Information', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Information'
    )
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
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

function Test-ISOFile {
    <#
    .SYNOPSIS
        Validates if a file is a valid ISO image.
    
    .DESCRIPTION
        Checks if the specified file exists and has .iso extension.
        Optionally validates ISO signature (first 32KB).
    
    .PARAMETER Path
        Path to the ISO file to validate.
    
    .PARAMETER ValidateSignature
        If specified, validates the ISO 9660 signature.
    
    .EXAMPLE
        Test-ISOFile -Path "C:\ISOs\ubuntu.iso"
        Returns $true if the file exists and is a valid ISO.
    
    .OUTPUTS
        Boolean indicating if the file is a valid ISO.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Path,
        
        [Parameter()]
        [switch]$ValidateSignature
    )
    
    process {
        Write-ISOLog "Validating ISO file: $Path" -Level 'Debug'
        
        # Check if file exists
        if (-not (Test-Path $Path)) {
            Write-ISOLog "File not found: $Path" -Level 'Debug'
            return $false
        }
        
        # Check extension
        $extension = [System.IO.Path]::GetExtension($Path)
        if ($extension -ne '.iso') {
            Write-ISOLog "Invalid extension: $extension (expected .iso)" -Level 'Debug'
            return $false
        }
        
        # Validate signature if requested
        if ($ValidateSignature) {
            try {
                $bytes = [System.IO.File]::ReadAllBytes($Path)
                if ($bytes.Length -lt 32768) {
                    Write-ISOLog "File too small to be a valid ISO" -Level 'Debug'
                    return $false
                }
                
                # Check for ISO 9660 signature at offset 32769 (0x8001)
                # Signature is "CD001"
                $signatureOffset = 32769
                if ($bytes.Length -gt $signatureOffset + 4) {
                    $signature = [System.Text.Encoding]::ASCII.GetString($bytes[$signatureOffset..($signatureOffset + 4)])
                    if ($signature -ne 'CD001') {
                        Write-ISOLog "Invalid ISO signature: $signature" -Level 'Debug'
                        return $false
                    }
                }
            } catch {
                Write-ISOLog "Error validating ISO signature: $_" -Level 'Error'
                return $false
            }
        }
        
        Write-ISOLog "ISO file is valid" -Level 'Debug'
        return $true
    }
}

function Get-ISOExtractionMethod {
    <#
    .SYNOPSIS
        Determines the best ISO extraction method for the current platform.
    
    .DESCRIPTION
        Returns the recommended extraction method based on platform and available tools.
        - Windows: Mount-DiskImage (preferred), 7z (fallback)
        - Linux/macOS: 7z (preferred), mount (requires sudo)
    
    .EXAMPLE
        Get-ISOExtractionMethod
        Returns 'MountDiskImage', '7zip', or 'Mount'
    
    .OUTPUTS
        String indicating the extraction method.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    if ($IsWindows) {
        # Check if Mount-DiskImage is available
        if (Get-Command Mount-DiskImage -ErrorAction SilentlyContinue) {
            return 'MountDiskImage'
        }
    }
    
    # Check for 7z
    $sevenZip = $null
    if ($IsWindows) {
        $sevenZip = Get-Command '7z.exe' -ErrorAction SilentlyContinue
        if (-not $sevenZip) {
            $sevenZip = Get-Command 'C:\Program Files\7-Zip\7z.exe' -ErrorAction SilentlyContinue
        }
    } else {
        $sevenZip = Get-Command '7z' -ErrorAction SilentlyContinue
        if (-not $sevenZip) {
            $sevenZip = Get-Command 'p7zip' -ErrorAction SilentlyContinue
        }
    }
    
    if ($sevenZip) {
        return '7zip'
    }
    
    # Linux/macOS: mount as last resort (requires sudo)
    if ($IsLinux -or $IsMacOS) {
        if (Get-Command 'mount' -ErrorAction SilentlyContinue) {
            return 'Mount'
        }
    }
    
    throw "No ISO extraction method available. Install 7-Zip or ensure Mount-DiskImage is available."
}

function Expand-ISOImage {
    <#
    .SYNOPSIS
        Extracts contents of an ISO image to a directory.
    
    .DESCRIPTION
        Extracts the contents of an ISO file to a specified destination directory.
        Automatically selects the best extraction method for the platform.
    
    .PARAMETER ISOPath
        Path to the ISO file to extract.
    
    .PARAMETER DestinationPath
        Directory where ISO contents will be extracted.
    
    .PARAMETER Force
        If specified, overwrites existing destination directory.
    
    .EXAMPLE
        Expand-ISOImage -ISOPath "C:\ISOs\ubuntu.iso" -DestinationPath "C:\Extracted\ubuntu"
        Extracts Ubuntu ISO contents to the specified directory.
    
    .OUTPUTS
        PSCustomObject with extraction result details.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-ISOFile -Path $_ })]
        [string]$ISOPath,
        
        [Parameter(Mandatory)]
        [string]$DestinationPath,
        
        [Parameter()]
        [switch]$Force
    )
    
    $startTime = Get-Date
    Write-ISOLog "Starting ISO extraction: $ISOPath -> $DestinationPath"
    
    # Validate ISO
    if (-not (Test-ISOFile -Path $ISOPath)) {
        throw "Invalid ISO file: $ISOPath"
    }
    
    # Check destination
    if (Test-Path $DestinationPath) {
        if ($Force) {
            Write-ISOLog "Removing existing destination: $DestinationPath" -Level 'Warning'
            if ($PSCmdlet.ShouldProcess($DestinationPath, 'Remove existing directory')) {
                Remove-Item $DestinationPath -Recurse -Force
            }
        } else {
            throw "Destination already exists: $DestinationPath. Use -Force to overwrite."
        }
    }
    
    # Create destination
    if ($PSCmdlet.ShouldProcess($DestinationPath, 'Create directory')) {
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    }
    
    # Get extraction method
    $method = Get-ISOExtractionMethod
    Write-ISOLog "Using extraction method: $method"
    
    $success = $false
    $filesExtracted = 0
    
    try {
        if ($PSCmdlet.ShouldProcess($ISOPath, "Extract using $method")) {
            switch ($method) {
                'MountDiskImage' {
                    # Mount ISO
                    $mount = Mount-DiskImage -ImagePath $ISOPath -PassThru
                    $driveLetter = ($mount | Get-Volume).DriveLetter
                    $sourcePath = "${driveLetter}:\"
                    
                    # Copy contents
                    Write-ISOLog "Copying files from ${sourcePath} to $DestinationPath"
                    Copy-Item -Path "${sourcePath}*" -Destination $DestinationPath -Recurse -Force
                    
                    # Unmount
                    Dismount-DiskImage -ImagePath $ISOPath | Out-Null
                    
                    $filesExtracted = (Get-ChildItem $DestinationPath -Recurse -File).Count
                    $success = $true
                }
                
                '7zip' {
                    # Find 7z executable
                    $sevenZipExe = if ($IsWindows) {
                        $cmd = Get-Command '7z.exe' -ErrorAction SilentlyContinue
                        if ($cmd) { $cmd.Source } else { 'C:\Program Files\7-Zip\7z.exe' }
                    } else {
                        $cmd = Get-Command '7z' -ErrorAction SilentlyContinue
                        if ($cmd) { $cmd.Source } else { '7z' }
                    }
                    
                    # Extract
                    Write-ISOLog "Extracting with 7-Zip: $sevenZipExe"
                    $result = & $sevenZipExe x "$ISOPath" "-o$DestinationPath" -y
                    
                    if ($LASTEXITCODE -eq 0) {
                        $filesExtracted = (Get-ChildItem $DestinationPath -Recurse -File).Count
                        $success = $true
                    } else {
                        throw "7-Zip extraction failed with exit code: $LASTEXITCODE"
                    }
                }
                
                'Mount' {
                    # Linux/macOS mount (requires sudo)
                    $mountPoint = "/mnt/iso_$(Get-Random)"
                    sudo mkdir -p $mountPoint
                    sudo mount -o loop "$ISOPath" $mountPoint
                    
                    # Copy contents
                    Write-ISOLog "Copying files from $mountPoint to $DestinationPath"
                    Copy-Item -Path "${mountPoint}/*" -Destination $DestinationPath -Recurse -Force
                    
                    # Unmount
                    sudo umount $mountPoint
                    sudo rmdir $mountPoint
                    
                    $filesExtracted = (Get-ChildItem $DestinationPath -Recurse -File).Count
                    $success = $true
                }
            }
        }
        
        $duration = (Get-Date) - $startTime
        Write-ISOLog "ISO extraction completed: $filesExtracted files in $($duration.TotalSeconds.ToString('F2'))s"
        
        return [PSCustomObject]@{
            Success = $success
            Method = $method
            ISOPath = $ISOPath
            DestinationPath = $DestinationPath
            FilesExtracted = $filesExtracted
            Duration = $duration
            Message = "Extracted $filesExtracted files using $method"
        }
        
    } catch {
        Write-ISOLog "ISO extraction failed: $_" -Level 'Error'
        return [PSCustomObject]@{
            Success = $false
            Method = $method
            ISOPath = $ISOPath
            DestinationPath = $DestinationPath
            FilesExtracted = 0
            Duration = (Get-Date) - $startTime
            Message = "Extraction failed: $_"
        }
    }
}

#endregion

# Export functions
Export-ModuleMember -Function @(
    'Test-ISOFile'
    'Get-ISOExtractionMethod'
    'Expand-ISOImage'
)
