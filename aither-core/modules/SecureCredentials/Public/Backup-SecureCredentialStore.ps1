function Backup-SecureCredentialStore {
    <#
    .SYNOPSIS
        Creates a backup of the entire secure credential store.

    .DESCRIPTION
        Creates a comprehensive backup of all credentials in the store with options
        for including sensitive data and compression. Provides restore capabilities.

    .PARAMETER BackupPath
        Path where the backup file will be created.

    .PARAMETER IncludeSecrets
        Include actual credential secrets in the backup (not recommended for production).

    .PARAMETER Compress
        Compress the backup data to reduce file size.

    .PARAMETER EncryptionKey
        Additional encryption key for backup security.

    .PARAMETER Metadata
        Additional metadata to include with the backup.

    .EXAMPLE
        Backup-SecureCredentialStore -BackupPath "C:\Backup\credentials-backup.json"

    .EXAMPLE
        Backup-SecureCredentialStore -BackupPath "backup.json" -IncludeSecrets -Compress

    .EXAMPLE
        $key = ConvertTo-SecureString "BackupKey123!" -AsPlainText -Force
        Backup-SecureCredentialStore -BackupPath "secure-backup.json" -EncryptionKey $key
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$BackupPath,

        [Parameter()]
        [switch]$IncludeSecrets,

        [Parameter()]
        [switch]$Compress,

        [Parameter()]
        [SecureString]$EncryptionKey,

        [Parameter()]
        [hashtable]$Metadata = @{}
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting credential store backup" -Context @{
            BackupPath = $BackupPath
            IncludeSecrets = $IncludeSecrets.IsPresent
            Compress = $Compress.IsPresent
            HasEncryptionKey = ($EncryptionKey -ne $null)
            MetadataProvided = ($Metadata.Count -gt 0)
        } -Category "Security"

        if ($IncludeSecrets) {
            Write-CustomLog -Level 'WARN' -Message 'Backup will include sensitive credential data - ensure secure handling' -Category "Security"
        }
    }

    process {
        try {
            if (-not $PSCmdlet.ShouldProcess($BackupPath, 'Create credential store backup')) {
                return @{
                    Success = $true
                    BackupPath = $BackupPath
                    WhatIf = $true
                }
            }

            # Create the backup using the helper function
            $backupResult = Backup-CredentialStore -BackupPath $BackupPath -IncludeSecrets:$IncludeSecrets -Compress:$Compress

            if ($backupResult.Success) {
                # Add additional encryption if key provided
                if ($EncryptionKey) {
                    try {
                        Write-CustomLog -Level 'INFO' -Message "Applying additional encryption to backup" -Category "Security"

                        $backupContent = Get-Content -Path $BackupPath -Raw
                        $plainKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($EncryptionKey)
                        )
                        $encryptedBackup = Protect-String -PlainText $backupContent

                        # Create encrypted backup structure
                        $encryptedData = @{
                            BackupInfo = @{
                                Encrypted = $true
                                OriginalSize = $backupContent.Length
                                EncryptedOn = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                                EncryptedBy = $env:USERNAME ?? $env:USER ?? 'unknown'
                            }
                            EncryptedContent = $encryptedBackup
                            Metadata = $Metadata
                        }

                        $encryptedJson = if ($Compress) {
                            $encryptedData | ConvertTo-Json -Depth 10 -Compress
                        } else {
                            $encryptedData | ConvertTo-Json -Depth 10
                        }

                        Set-Content -Path $BackupPath -Value $encryptedJson -Encoding UTF8

                        # Clear sensitive data from memory
                        $plainKey = $null
                        $backupContent = $null

                        Write-CustomLog -Level 'SUCCESS' -Message "Additional encryption applied to backup" -Category "Security"
                    }
                    catch {
                        Write-CustomLog -Level 'ERROR' -Message "Failed to apply additional encryption: $($_.Exception.Message)" -Category "Security"
                        throw "Backup encryption failed: $($_.Exception.Message)"
                    }
                }

                # Update result with additional metadata
                $backupResult.EncryptionApplied = ($EncryptionKey -ne $null)
                $backupResult.AdditionalMetadata = $Metadata
                $backupResult.BackupDateTime = Get-Date
                $backupResult.BackupBy = $env:USERNAME ?? $env:USER ?? 'unknown'

                Write-CustomLog -Level 'SUCCESS' -Message "Credential store backup completed successfully" -Context @{
                    BackupPath = $BackupPath
                    CredentialCount = $backupResult.CredentialCount
                    BackupSize = $backupResult.BackupSize
                    IncludesSecrets = $IncludeSecrets.IsPresent
                    Encrypted = ($EncryptionKey -ne $null)
                    Compressed = $Compress.IsPresent
                } -Category "Security"

                return $backupResult
            } else {
                throw "Backup operation failed"
            }
        }
        catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to backup credential store: $($_.Exception.Message)" -Category "Security"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Completed credential store backup operation" -Category "Security"
    }
}
