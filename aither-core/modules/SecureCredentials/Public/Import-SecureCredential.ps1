function Import-SecureCredential {
    <#
    .SYNOPSIS
        Imports secure credentials from an exported file.

    .DESCRIPTION
        Imports credential metadata and optionally secrets from a previously
        exported credential file, recreating the credentials in the current system.

    .PARAMETER ImportPath
        Path to the exported credential file.

    .PARAMETER Force
        Overwrite existing credentials with the same names.

    .PARAMETER SkipSecrets
        Import only metadata, skip importing actual secret values.

    .EXAMPLE
        Import-SecureCredential -ImportPath "./backup/lab-creds.json"

    .EXAMPLE
        Import-SecureCredential -ImportPath "./transfer/creds.json" -Force -SkipSecrets
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([hashtable])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Converting from secure credential export file is a legitimate use case')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ImportPath,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$SkipSecrets
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Importing secure credentials from: $ImportPath"

        if (-not (Test-Path $ImportPath)) {
            throw "Import file not found: $ImportPath"
        }
    }

    process {
        try {
            if (-not $PSCmdlet.ShouldProcess($ImportPath, 'Import secure credentials')) {
                return @{
                    Success    = $true
                    ImportPath = $ImportPath
                    WhatIf     = $true
                }
            }

            # Load import data
            $importData = Get-Content $ImportPath | ConvertFrom-Json

            if (-not $importData.Credentials) {
                throw 'Invalid import file format - no credentials section found'
            }

            $importResults = @{
                Success             = $true
                ImportPath          = $ImportPath
                ImportedCredentials = @()
                SkippedCredentials  = @()
                Errors              = @()
            }

            Write-CustomLog -Level 'INFO' -Message "Found $($importData.Credentials.Count) credentials to import"

            foreach ($credentialData in $importData.Credentials) {
                try {
                    $credentialName = $credentialData.Name
                    Write-CustomLog -Level 'INFO' -Message "Processing credential: $credentialName"

                    # Check if credential already exists
                    if ((Test-SecureCredential -CredentialName $credentialName) -and -not $Force) {
                        Write-CustomLog -Level 'WARN' -Message "Credential '$credentialName' already exists, skipping (use -Force to overwrite)"
                        $importResults.SkippedCredentials += $credentialName
                        continue
                    }

                    # Import based on credential type
                    switch ($credentialData.Type) {
                        'UserPassword' {
                            if ($credentialData.Password -and -not $SkipSecrets) {
                                # This is a legitimate use case for importing from secure credential export
                                # PSScriptAnalyzer suppressed: PSAvoidUsingConvertToSecureStringWithPlainText
                                $securePassword = ConvertTo-SecureString $credentialData.Password -AsPlainText -Force
                                $null = New-SecureCredential -CredentialName $credentialName -CredentialType 'UserPassword' -Username $credentialData.Username -Password $securePassword -Force:$Force
                            } else {
                                Write-CustomLog -Level 'INFO' -Message 'Creating credential metadata only (no secrets imported)'
                                # Create metadata-only credential
                                $metadataPath = Get-CredentialMetadataPath
                                if (-not (Test-Path $metadataPath)) {
                                    New-Item -Path $metadataPath -ItemType Directory -Force | Out-Null
                                }
                                $metadataFile = Join-Path $metadataPath "$credentialName.json"
                                $credentialData | ConvertTo-Json -Depth 5 | Set-Content -Path $metadataFile
                            }
                        }
                        'ServiceAccount' {
                            if ($credentialData.Password -and -not $SkipSecrets) {
                                # This is a legitimate use case for importing from secure credential export
                                # PSScriptAnalyzer suppressed: PSAvoidUsingConvertToSecureStringWithPlainText
                                $securePassword = ConvertTo-SecureString $credentialData.Password -AsPlainText -Force
                                $null = New-SecureCredential -CredentialName $credentialName -CredentialType 'ServiceAccount' -Username $credentialData.Username -Password $securePassword -Force:$Force
                            } else {
                                Write-CustomLog -Level 'INFO' -Message 'Creating credential metadata only (no secrets imported)'
                                $metadataPath = Get-CredentialMetadataPath
                                if (-not (Test-Path $metadataPath)) {
                                    New-Item -Path $metadataPath -ItemType Directory -Force | Out-Null
                                }
                                $metadataFile = Join-Path $metadataPath "$credentialName.json"
                                $credentialData | ConvertTo-Json -Depth 5 | Set-Content -Path $metadataFile
                            }
                        }
                        'APIKey' {
                            if ($credentialData.APIKey -and -not $SkipSecrets) {
                                $null = New-SecureCredential -CredentialName $credentialName -CredentialType 'APIKey' -APIKey $credentialData.APIKey -Force:$Force
                            } else {
                                Write-CustomLog -Level 'INFO' -Message 'Creating credential metadata only (no secrets imported)'
                                $metadataPath = Get-CredentialMetadataPath
                                if (-not (Test-Path $metadataPath)) {
                                    New-Item -Path $metadataPath -ItemType Directory -Force | Out-Null
                                }
                                $metadataFile = Join-Path $metadataPath "$credentialName.json"
                                $credentialData | ConvertTo-Json -Depth 5 | Set-Content -Path $metadataFile
                            }
                        }
                        'Certificate' {
                            if (Test-Path $credentialData.CertificatePath) {
                                $null = New-SecureCredential -CredentialName $credentialName -CredentialType 'Certificate' -CertificatePath $credentialData.CertificatePath -Force:$Force
                            } else {
                                Write-CustomLog -Level 'WARN' -Message "Certificate file not found: $($credentialData.CertificatePath), creating metadata only"
                                $metadataPath = Get-CredentialMetadataPath
                                if (-not (Test-Path $metadataPath)) {
                                    New-Item -Path $metadataPath -ItemType Directory -Force | Out-Null
                                }
                                $metadataFile = Join-Path $metadataPath "$credentialName.json"
                                $credentialData | ConvertTo-Json -Depth 5 | Set-Content -Path $metadataFile
                            }
                        }
                    }

                    $importResults.ImportedCredentials += $credentialName
                    Write-CustomLog -Level 'SUCCESS' -Message "Successfully imported credential: $credentialName"

                } catch {
                    $errorMessage = "Failed to import credential '$($credentialData.Name)': $($_.Exception.Message)"
                    Write-CustomLog -Level 'ERROR' -Message $errorMessage
                    $importResults.Errors += $errorMessage
                }
            }

            Write-CustomLog -Level 'SUCCESS' -Message "Import completed. Imported: $($importResults.ImportedCredentials.Count), Skipped: $($importResults.SkippedCredentials.Count), Errors: $($importResults.Errors.Count)"

            return $importResults

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to import credentials from '$ImportPath': $($_.Exception.Message)"
            throw
        }
    }
}
