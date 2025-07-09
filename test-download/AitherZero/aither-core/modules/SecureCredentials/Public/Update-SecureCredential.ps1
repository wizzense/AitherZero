function Update-SecureCredential {
    <#
    .SYNOPSIS
        Updates an existing secure credential with new values while maintaining history.

    .DESCRIPTION
        Updates credential data with proper versioning, backup, and audit trail.
        Supports password rotation, API key updates, and certificate renewal.

    .PARAMETER CredentialName
        Name of the credential to update.

    .PARAMETER NewPassword
        New password for UserPassword or ServiceAccount credentials.

    .PARAMETER NewAPIKey
        New API key for APIKey credentials.

    .PARAMETER NewCertificatePath
        New certificate path for Certificate credentials.

    .PARAMETER NewUsername
        Update the username (if allowed by credential type).

    .PARAMETER NewDescription
        Update the credential description.

    .PARAMETER BackupOldVersion
        Create backup of current version before updating.

    .PARAMETER Force
        Force update even if current credential cannot be validated.

    .EXAMPLE
        Update-SecureCredential -CredentialName "VMAdmin" -NewPassword (Read-Host -AsSecureString "New Password")

    .EXAMPLE
        Update-SecureCredential -CredentialName "APIService" -NewAPIKey "new-api-key-value" -BackupOldVersion
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$CredentialName,

        [Parameter()]
        [SecureString]$NewPassword,

        [Parameter()]
        [string]$NewAPIKey,

        [Parameter()]
        [string]$NewCertificatePath,

        [Parameter()]
        [string]$NewUsername,

        [Parameter()]
        [string]$NewDescription,

        [Parameter()]
        [switch]$BackupOldVersion,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Updating secure credential: $CredentialName" -Category "Security"
    }

    process {
        try {
            if (-not $PSCmdlet.ShouldProcess($CredentialName, 'Update secure credential')) {
                return @{
                    Success = $true
                    CredentialName = $CredentialName
                    WhatIf = $true
                }
            }

            # Validate credential exists
            if (-not (Test-SecureCredential -CredentialName $CredentialName -Quiet)) {
                throw "Credential not found: $CredentialName"
            }

            # Get current credential
            $currentResult = Retrieve-CredentialSecurely -CredentialName $CredentialName
            if (-not $currentResult.Success) {
                if (-not $Force) {
                    throw "Cannot retrieve current credential: $($currentResult.Error)"
                } else {
                    Write-CustomLog -Level 'WARN' -Message "Forcing update despite retrieval error: $($currentResult.Error)" -Category "Security"
                }
            }

            $currentCredential = $currentResult.Credential
            $updateInfo = @{
                Success = $true
                CredentialName = $CredentialName
                UpdatedFields = @()
                BackupCreated = $false
                UpdateTime = Get-Date
                PreviousVersion = $null
            }

            # Create backup if requested
            if ($BackupOldVersion) {
                try {
                    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
                    $backupName = "$CredentialName-backup-$timestamp"

                    $exportResult = Export-SecureCredential -CredentialName $CredentialName -ExportPath "$(Get-CredentialStoragePath)/$backupName.json" -IncludeSecrets

                    if ($exportResult.Success) {
                        $updateInfo.BackupCreated = $true
                        $updateInfo.BackupPath = $exportResult.ExportPath
                        Write-CustomLog -Level 'SUCCESS' -Message "Backup created: $backupName" -Category "Security"
                    }
                } catch {
                    Write-CustomLog -Level 'WARN' -Message "Failed to create backup: $($_.Exception.Message)" -Category "Security"
                }
            }

            # Prepare updated credential data
            $updatedCredential = @{
                Name = $CredentialName
                Type = $currentCredential.Type
                Username = if ($NewUsername) { $NewUsername } else { $currentCredential.Username }
                Description = if ($NewDescription) { $NewDescription } else { $currentCredential.Description }
                Created = $currentCredential.Created
                LastModified = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                Metadata = $currentCredential.Metadata
            }

            # Update version history in metadata
            if (-not $updatedCredential.Metadata) {
                $updatedCredential.Metadata = @{}
            }
            if (-not $updatedCredential.Metadata.VersionHistory) {
                $updatedCredential.Metadata.VersionHistory = @()
            }

            # Add current version to history
            $versionEntry = @{
                Version = $updatedCredential.Metadata.VersionHistory.Count + 1
                UpdatedBy = $env:USERNAME ?? $env:USER ?? 'unknown'
                UpdatedOn = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                Changes = @()
            }

            # Track specific changes and update based on credential type
            switch ($currentCredential.Type) {
                'UserPassword' {
                    if ($NewPassword) {
                        $result = Save-CredentialSecurely -CredentialData $updatedCredential -Password $NewPassword
                        if ($result.Success) {
                            $updateInfo.UpdatedFields += 'Password'
                            $versionEntry.Changes += 'Password updated'
                        } else {
                            throw "Failed to save updated password: $($result.Error)"
                        }
                    }
                }
                'ServiceAccount' {
                    if ($NewPassword) {
                        $result = Save-CredentialSecurely -CredentialData $updatedCredential -Password $NewPassword
                        if ($result.Success) {
                            $updateInfo.UpdatedFields += 'Password'
                            $versionEntry.Changes += 'Service account password updated'
                        } else {
                            throw "Failed to save updated service account password: $($result.Error)"
                        }
                    }
                }
                'APIKey' {
                    if ($NewAPIKey) {
                        $result = Save-CredentialSecurely -CredentialData $updatedCredential -APIKey $NewAPIKey
                        if ($result.Success) {
                            $updateInfo.UpdatedFields += 'APIKey'
                            $versionEntry.Changes += 'API key updated'
                        } else {
                            throw "Failed to save updated API key: $($result.Error)"
                        }
                    }
                }
                'Certificate' {
                    if ($NewCertificatePath) {
                        if (-not (Test-Path $NewCertificatePath)) {
                            throw "Certificate file not found: $NewCertificatePath"
                        }
                        $result = Save-CredentialSecurely -CredentialData $updatedCredential -CertificatePath $NewCertificatePath
                        if ($result.Success) {
                            $updateInfo.UpdatedFields += 'CertificatePath'
                            $versionEntry.Changes += "Certificate path updated to: $NewCertificatePath"
                        } else {
                            throw "Failed to save updated certificate: $($result.Error)"
                        }
                    }
                }
            }

            # Update metadata fields
            if ($NewUsername -and $NewUsername -ne $currentCredential.Username) {
                $updateInfo.UpdatedFields += 'Username'
                $versionEntry.Changes += "Username updated from '$($currentCredential.Username)' to '$NewUsername'"
            }

            if ($NewDescription -and $NewDescription -ne $currentCredential.Description) {
                $updateInfo.UpdatedFields += 'Description'
                $versionEntry.Changes += "Description updated"
            }

            # Save metadata updates if any non-secret fields were changed
            if ($updateInfo.UpdatedFields -contains 'Username' -or $updateInfo.UpdatedFields -contains 'Description' -or $versionEntry.Changes.Count -gt 0) {
                $updatedCredential.Metadata.VersionHistory += $versionEntry

                # Re-save the credential with updated metadata
                $currentResult = Retrieve-CredentialSecurely -CredentialName $CredentialName
                if ($currentResult.Success) {
                    $saveParams = @{
                        CredentialData = $updatedCredential
                    }

                    # Include current secrets in the save operation
                    switch ($currentCredential.Type) {
                        'UserPassword' {
                            if (-not $NewPassword) {
                                $saveParams.Password = $currentResult.Credential.Password
                            }
                        }
                        'ServiceAccount' {
                            if (-not $NewPassword) {
                                $saveParams.Password = $currentResult.Credential.Password
                            }
                        }
                        'APIKey' {
                            if (-not $NewAPIKey) {
                                $saveParams.APIKey = $currentResult.Credential.APIKey
                            }
                        }
                        'Certificate' {
                            if (-not $NewCertificatePath) {
                                $saveParams.CertificatePath = $currentResult.Credential.CertificatePath
                            }
                        }
                    }

                    $result = Save-CredentialSecurely @saveParams
                    if (-not $result.Success) {
                        throw "Failed to save updated metadata: $($result.Error)"
                    }
                }
            }

            # Audit log the update
            Write-CustomLog -Level 'SUCCESS' -Message "Credential updated successfully: $CredentialName" -Context @{
                CredentialName = $CredentialName
                UpdatedFields = $updateInfo.UpdatedFields -join ', '
                UpdatedBy = $env:USERNAME ?? $env:USER ?? 'unknown'
                BackupCreated = $updateInfo.BackupCreated
                VersionNumber = $versionEntry.Version
            } -Category "Security"

            return $updateInfo

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to update credential '$CredentialName': $($_.Exception.Message)" -Category "Security"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Completed credential update for: $CredentialName" -Category "Security"
    }
}
