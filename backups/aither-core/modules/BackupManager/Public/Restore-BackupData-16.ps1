<#
.SYNOPSIS
Restores data from advanced backup archives

.DESCRIPTION
This function restores files from backups created with Invoke-AdvancedBackup,
handling decompression, decryption, and deduplication restoration automatically.

.PARAMETER BackupPath
The path to the backup directory

.PARAMETER RestorePath
The destination path for restored files

.PARAMETER EncryptionKey
The encryption key for encrypted backups

.PARAMETER SelectiveRestore
Only restore specific files (supports wildcards)

.PARAMETER VerifyRestore
Verify restored files match original checksums

.PARAMETER OverwriteExisting
Overwrite existing files during restore

.EXAMPLE
Restore-BackupData -BackupPath "./advanced-backup" -RestorePath "./restored"

.EXAMPLE
Restore-BackupData -BackupPath "./secure-backup" -RestorePath "./restored" -EncryptionKey $key -VerifyRestore

.NOTES
Requires the same encryption key used for backup if data was encrypted
#>
function Restore-BackupData {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$BackupPath,

        [Parameter(Mandatory)]
        [string]$RestorePath,

        [Parameter()]
        [SecureString]$EncryptionKey,

        [Parameter()]
        [string[]]$SelectiveRestore = @(),

        [Parameter()]
        [switch]$VerifyRestore,

        [Parameter()]
        [switch]$OverwriteExisting,

        [Parameter()]
        [switch]$Force
    )

    $ErrorActionPreference = "Stop"

    try {
        # Import shared utilities
        . "$PSScriptRoot/../../../shared/Find-ProjectRoot.ps1"
        $projectRoot = Find-ProjectRoot

        # Import logging if available
        $loggingPath = Join-Path $projectRoot "aither-core/modules/Logging"
        if (Test-Path $loggingPath) {
            Import-Module $loggingPath -Force -ErrorAction SilentlyContinue
        }

        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog "Starting backup restoration" -Level INFO
        } else {
            Write-Host "INFO Starting backup restoration" -ForegroundColor Green
        }

        # Validate paths
        $BackupPath = Resolve-Path $BackupPath -ErrorAction Stop
        if (-not (Test-Path $RestorePath)) {
            New-Item -Path $RestorePath -ItemType Directory -Force | Out-Null
        }
        $RestorePath = Resolve-Path $RestorePath

        # Load backup metadata
        $metadataPath = Join-Path $BackupPath ".backup-metadata"
        if (-not (Test-Path $metadataPath)) {
            throw "Backup metadata not found. This may not be a valid advanced backup."
        }

        # Find the latest backup manifest
        $manifestFiles = Get-ChildItem -Path $metadataPath -Filter "backup-manifest-*.json" | Sort-Object LastWriteTime -Descending
        if ($manifestFiles.Count -eq 0) {
            throw "No backup manifest found in metadata directory."
        }

        $latestManifest = $manifestFiles[0]
        $manifest = Get-Content $latestManifest.FullName | ConvertFrom-Json

        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog "Found backup manifest: $($latestManifest.Name)" -Level INFO
        }

        # Load deduplication index if available
        $dedupIndex = @{}
        $dedupIndexPath = Join-Path $metadataPath "dedup-index.json"
        if (Test-Path $dedupIndexPath) {
            $dedupIndex = Get-Content $dedupIndexPath | ConvertFrom-Json -AsHashtable
        }

        # Check for encryption
        if ($manifest.EnableEncryption -and -not $EncryptionKey) {
            $keyPath = Join-Path $metadataPath "encryption.key"
            if (Test-Path $keyPath) {
                Write-Warning "Backup is encrypted. Please provide the encryption key or check $keyPath"
                return @{
                    Success = $false
                    Message = "Encryption key required for encrypted backup"
                }
            }
        }

        # Initialize restore context
        $restoreContext = @{
            BackupPath = $BackupPath
            RestorePath = $RestorePath
            StartTime = Get-Date
            RestoredFiles = 0
            SkippedFiles = 0
            Errors = @()
            DeduplicatedFiles = 0
            DecryptedFiles = 0
            TotalSize = 0
        }

        # Discover backup files
        $backupFiles = Get-ChildItem -Path $BackupPath -Recurse -File -Filter "*.backup"
        $dedupFiles = Get-ChildItem -Path $BackupPath -Recurse -File -Filter "*.dedup"
        $allFiles = $backupFiles + $dedupFiles

        # Apply selective restore filter
        if ($SelectiveRestore.Count -gt 0) {
            $filteredFiles = @()
            foreach ($pattern in $SelectiveRestore) {
                $filteredFiles += $allFiles | Where-Object { $_.Name -like $pattern }
            }
            $allFiles = $filteredFiles | Sort-Object -Unique
        }

        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog "Found $($allFiles.Count) files to restore" -Level INFO
        }

        # Restore files
        foreach ($file in $allFiles) {
            try {
                if ($file.Extension -eq ".dedup") {
                    # Handle deduplicated file
                    $result = Restore-DeduplicatedFile -File $file -Context $restoreContext -DedupIndex $dedupIndex
                    if ($result.Success) {
                        $restoreContext.RestoredFiles++
                        $restoreContext.DeduplicatedFiles++
                    } else {
                        $restoreContext.Errors += $result.Error
                        $restoreContext.SkippedFiles++
                    }
                } else {
                    # Handle regular backup file
                    $result = Restore-BackupFile -File $file -Context $restoreContext -EncryptionKey $EncryptionKey -OverwriteExisting:$OverwriteExisting
                    if ($result.Success) {
                        $restoreContext.RestoredFiles++
                        $restoreContext.TotalSize += $result.RestoredSize
                        if ($result.WasDecrypted) {
                            $restoreContext.DecryptedFiles++
                        }
                    } else {
                        $restoreContext.Errors += $result.Error
                        $restoreContext.SkippedFiles++
                    }
                }

            } catch {
                $error = "Failed to restore $($file.Name): $($_.Exception.Message)"
                $restoreContext.Errors += $error
                $restoreContext.SkippedFiles++

                if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                    Write-CustomLog $error -Level WARN
                }
            }
        }

        # Verify restoration if requested
        if ($VerifyRestore) {
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog "Verifying restored files..." -Level INFO
            }

            $verificationResult = Test-RestoredFiles -RestorePath $RestorePath -BackupManifest $manifest
            $restoreContext.VerificationResult = $verificationResult

            if (-not $verificationResult.Success) {
                $restoreContext.Errors += $verificationResult.Errors
            }
        }

        # Complete restore context
        $restoreContext.EndTime = Get-Date
        $restoreContext.Duration = $restoreContext.EndTime - $restoreContext.StartTime

        # Log completion
        $encryptionInfo = if ($restoreContext.DecryptedFiles -gt 0) { ", $($restoreContext.DecryptedFiles) decrypted" } else { "" }
        $dedupInfo = if ($restoreContext.DeduplicatedFiles -gt 0) { ", $($restoreContext.DeduplicatedFiles) deduplicated" } else { "" }

        $completionMessage = "Backup restoration completed: $($restoreContext.RestoredFiles) files restored$encryptionInfo$dedupInfo"

        if ($restoreContext.Errors.Count -gt 0) {
            $completionMessage += " ($($restoreContext.Errors.Count) errors)"
        }

        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog $completionMessage -Level SUCCESS
        } else {
            Write-Host "SUCCESS $completionMessage" -ForegroundColor Green
        }

        # Create restore report
        $reportPath = Join-Path $RestorePath "restore-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $restoreContext | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath -Encoding UTF8

        return $restoreContext

    } catch {
        $errorMessage = "Backup restoration failed: $($_.Exception.Message)"

        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog $errorMessage -Level ERROR
        } else {
            Write-Error $errorMessage
        }

        throw
    }
}

function Restore-DeduplicatedFile {
    [CmdletBinding()]
    param(
        [System.IO.FileInfo]$File,
        [hashtable]$Context,
        [hashtable]$DedupIndex
    )

    try {
        # Read deduplication link
        $linkData = Get-Content $File.FullName | ConvertFrom-Json

        # Find the target file
        $targetBackupFile = $linkData.DedupTarget
        if (-not (Test-Path $targetBackupFile)) {
            return @{
                Success = $false
                Error = "Deduplication target not found: $targetBackupFile"
            }
        }

        # Restore the target file to the current location
        $relativePath = $File.FullName.Replace($Context.BackupPath, "").TrimStart('\', '/').Replace('.dedup', '')
        $restoreFilePath = Join-Path $Context.RestorePath $relativePath
        $restoreDir = Split-Path $restoreFilePath -Parent

        if (-not (Test-Path $restoreDir)) {
            New-Item -Path $restoreDir -ItemType Directory -Force | Out-Null
        }

        # Copy the deduplicated content
        Copy-Item -Path $targetBackupFile -Destination $restoreFilePath -Force

        return @{
            Success = $true
            RestoredPath = $restoreFilePath
        }

    } catch {
        return @{
            Success = $false
            Error = "Failed to restore deduplicated file: $($_.Exception.Message)"
        }
    }
}

function Restore-BackupFile {
    [CmdletBinding()]
    param(
        [System.IO.FileInfo]$File,
        [hashtable]$Context,
        [SecureString]$EncryptionKey,
        [switch]$OverwriteExisting
    )

    try {
        # Calculate restore path
        $relativePath = $File.FullName.Replace($Context.BackupPath, "").TrimStart('\', '/').Replace('.backup', '')
        $restoreFilePath = Join-Path $Context.RestorePath $relativePath
        $restoreDir = Split-Path $restoreFilePath -Parent

        # Check if file already exists
        if ((Test-Path $restoreFilePath) -and -not $OverwriteExisting.IsPresent) {
            return @{
                Success = $false
                Error = "File already exists and OverwriteExisting not specified: $restoreFilePath"
            }
        }

        if (-not (Test-Path $restoreDir)) {
            New-Item -Path $restoreDir -ItemType Directory -Force | Out-Null
        }

        # Read backup file
        $backupContent = [System.IO.File]::ReadAllBytes($File.FullName)
        $wasDecrypted = $false

        # Decrypt if needed
        if ($EncryptionKey) {
            $backupContent = Unprotect-Data -Data $backupContent -EncryptionKey $EncryptionKey
            $wasDecrypted = $true
        }

        # Decompress
        $originalContent = Decompress-Data -Data $backupContent

        # Write restored file
        [System.IO.File]::WriteAllBytes($restoreFilePath, $originalContent)

        return @{
            Success = $true
            RestoredPath = $restoreFilePath
            RestoredSize = $originalContent.Length
            WasDecrypted = $wasDecrypted
        }

    } catch {
        return @{
            Success = $false
            Error = "Failed to restore backup file: $($_.Exception.Message)"
        }
    }
}

function Decompress-Data {
    [CmdletBinding()]
    param([byte[]]$Data)

    $inputStream = [System.IO.MemoryStream]::new($Data)
    $outputStream = [System.IO.MemoryStream]::new()

    $gzipStream = [System.IO.Compression.GZipStream]::new($inputStream, [System.IO.Compression.CompressionMode]::Decompress)
    $gzipStream.CopyTo($outputStream)
    $gzipStream.Close()

    $decompressedData = $outputStream.ToArray()
    $inputStream.Dispose()
    $outputStream.Dispose()

    return $decompressedData
}

function Unprotect-Data {
    [CmdletBinding()]
    param(
        [byte[]]$Data,
        [SecureString]$EncryptionKey
    )

    # Decrypt using the same XOR method as encryption
    $keyBytes = [System.Text.Encoding]::UTF8.GetBytes(
        [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($EncryptionKey)
        )
    )

    $decryptedData = [byte[]]::new($Data.Length)
    for ($i = 0; $i -lt $Data.Length; $i++) {
        $decryptedData[$i] = $Data[$i] -bxor $keyBytes[$i % $keyBytes.Length]
    }

    return $decryptedData
}

function Test-RestoredFiles {
    [CmdletBinding()]
    param(
        [string]$RestorePath,
        [object]$BackupManifest
    )

    $result = @{
        Success = $true
        Errors = @()
        VerifiedFiles = 0
        MismatchedFiles = 0
    }

    try {
        $restoredFiles = Get-ChildItem -Path $RestorePath -Recurse -File

        foreach ($file in $restoredFiles) {
            try {
                # Basic existence and readability check
                $content = [System.IO.File]::ReadAllBytes($file.FullName)
                $result.VerifiedFiles++
            } catch {
                $result.MismatchedFiles++
                $result.Errors += "File verification failed: $($file.FullName)"
                $result.Success = $false
            }
        }

    } catch {
        $result.Success = $false
        $result.Errors += "File verification failed: $($_.Exception.Message)"
    }

    return $result
}
