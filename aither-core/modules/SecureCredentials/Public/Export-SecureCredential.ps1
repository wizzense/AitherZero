function Export-SecureCredential {
    <#
    .SYNOPSIS
        Exports secure credential metadata to a file for backup or transfer.

    .DESCRIPTION
        Exports credential metadata (not the actual secrets) to a secure format
        for backup, transfer, or documentation purposes.

    .PARAMETER CredentialName
        Name of the credential to export.

    .PARAMETER ExportPath
        Path where to save the exported credential metadata.

    .PARAMETER IncludeSecrets
        Whether to include actual secret values (not recommended for production).

    .EXAMPLE
        Export-SecureCredential -CredentialName "HyperV-Lab-01" -ExportPath "./backup/lab-creds.json"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$CredentialName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ExportPath,

        [Parameter()]
        [switch]$IncludeSecrets
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Exporting secure credential: $CredentialName"
        
        if ($IncludeSecrets) {
            Write-CustomLog -Level 'WARN' -Message "Including secrets in export - ensure secure handling of export file"
        }
    }

    process {
        try {
            if (-not $PSCmdlet.ShouldProcess($ExportPath, "Export credential metadata")) {
                return @{
                    Success = $true
                    CredentialName = $CredentialName
                    ExportPath = $ExportPath
                    WhatIf = $true
                }
            }

            # Get credential metadata
            $metadataPath = Get-CredentialMetadataPath
            $metadataFile = Join-Path $metadataPath "$CredentialName.json"

            if (-not (Test-Path $metadataFile)) {
                throw "Credential metadata not found: $CredentialName"
            }

            $metadata = Get-Content $metadataFile | ConvertFrom-Json

            # Create export data structure
            $exportData = @{
                ExportInfo = @{
                    ExportedBy = $env:USERNAME
                    ExportedDate = Get-Date
                    AitherZeroVersion = "1.0.0"
                    IncludesSecrets = $IncludeSecrets.IsPresent
                }
                Credentials = @()
            }

            $credentialExport = @{
                Name = $metadata.Name
                Type = $metadata.Type
                CreatedDate = $metadata.CreatedDate
                LastModified = $metadata.LastModified
            }

            # Add type-specific metadata
            switch ($metadata.Type) {
                'UserPassword' {
                    $credentialExport.Username = $metadata.Username
                    if ($IncludeSecrets) {
                        $storedCred = Get-SecureCredential -CredentialName $CredentialName
                        if ($storedCred) {
                            $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                                [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($storedCred.Credential.Password)
                            )
                            $credentialExport.Password = $plainPassword
                        }
                    }
                }
                'ServiceAccount' {
                    $credentialExport.Username = $metadata.Username
                    if ($IncludeSecrets) {
                        $storedCred = Get-SecureCredential -CredentialName $CredentialName
                        if ($storedCred) {
                            $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                                [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($storedCred.Credential.Password)
                            )
                            $credentialExport.Password = $plainPassword
                        }
                    }
                }
                'APIKey' {
                    if ($IncludeSecrets) {
                        $storedCred = Get-SecureCredential -CredentialName $CredentialName
                        if ($storedCred) {
                            $credentialExport.APIKey = $storedCred.APIKey
                        }
                    }
                }
                'Certificate' {
                    $credentialExport.CertificatePath = $metadata.CertificatePath
                    $credentialExport.Thumbprint = $metadata.Thumbprint
                    $credentialExport.ExpiryDate = $metadata.ExpiryDate
                }
            }

            $exportData.Credentials += $credentialExport

            # Ensure export directory exists
            $exportDir = Split-Path $ExportPath -Parent
            if ($exportDir -and -not (Test-Path $exportDir)) {
                New-Item -Path $exportDir -ItemType Directory -Force | Out-Null
            }

            # Export to file
            $exportData | ConvertTo-Json -Depth 10 | Set-Content -Path $ExportPath -Encoding UTF8

            Write-CustomLog -Level 'SUCCESS' -Message "Credential exported successfully to: $ExportPath"

            return @{
                Success = $true
                CredentialName = $CredentialName
                ExportPath = $ExportPath
                ExportSize = (Get-Item $ExportPath).Length
                IncludedSecrets = $IncludeSecrets.IsPresent
                ExportDate = Get-Date
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to export credential '$CredentialName': $($_.Exception.Message)"
            throw
        }
    }
}
