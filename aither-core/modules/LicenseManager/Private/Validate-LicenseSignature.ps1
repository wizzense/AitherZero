function Validate-LicenseSignature {
    <#
    .SYNOPSIS
        Validates a license signature
    .DESCRIPTION
        Checks if the license signature is valid
    .PARAMETER License
        License object to validate
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$License
    )
    
    try {
        # Simple validation for now
        # In production, use proper cryptographic signing
        
        if (-not $License.signature) {
            return $false
        }
        
        # Recreate the data that was signed
        $dataToSign = "$($License.licenseId)|$($License.tier)|$($License.issuedTo)|$($License.expiryDate)"
        
        # Decode signature
        try {
            $decodedSignature = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($License.signature))
            
            # Simple check - in production use proper verification
            return $decodedSignature -eq $dataToSign
        } catch {
            return $false
        }
        
    } catch {
        Write-Warning "Error validating signature: $_"
        return $false
    }
}