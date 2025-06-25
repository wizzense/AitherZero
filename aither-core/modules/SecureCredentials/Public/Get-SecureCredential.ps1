function Get-SecureCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CredentialName
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting Get-SecureCredential for: $CredentialName"
    }

    process {
        try {
            $result = Retrieve-CredentialSecurely -CredentialName $CredentialName

            if ($result.Success) {
                Write-CustomLog -Level 'SUCCESS' -Message "Successfully retrieved credential: $CredentialName"
                return $result.Credential
            } else {
                Write-CustomLog -Level 'WARN' -Message "Credential not found: $CredentialName"
                return $null
            }
        }
        catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to retrieve credential $CredentialName : $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Completed Get-SecureCredential for: $CredentialName"
    }
}