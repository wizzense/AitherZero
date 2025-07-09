function New-AuthenticationToken {
    <#
    .SYNOPSIS
        Create a new authentication token
    .DESCRIPTION
        Creates a new authentication token for inter-module communication
    .PARAMETER ModuleName
        Module requesting the token
    .PARAMETER User
        User associated with the token
    .PARAMETER Scopes
        Scopes/permissions for the token
    .PARAMETER ExpirationMinutes
        Token expiration time in minutes
    .EXAMPLE
        New-AuthenticationToken -ModuleName "LabRunner" -User "System" -Scopes @('api:call', 'events:publish')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter()]
        [string]$User = $env:USERNAME,

        [Parameter()]
        [string[]]$Scopes = @('api:call'),

        [Parameter()]
        [int]$ExpirationMinutes
    )

    try {
        # Check if security is enabled
        if (-not $script:SecurityContext -or -not $script:SecurityContext.SecurityEnabled) {
            throw "Security is not enabled. Call Enable-CommunicationSecurity first."
        }

        # Use default expiration if not specified
        if (-not $ExpirationMinutes) {
            $ExpirationMinutes = $script:SecurityContext.DefaultTokenExpiration
        }

        # Generate secure token
        $tokenBytes = New-Object byte[] 32
        $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
        $rng.GetBytes($tokenBytes)
        $token = [Convert]::ToBase64String($tokenBytes).Replace('+', '-').Replace('/', '_').Replace('=', '')

        # Create token info
        $tokenInfo = @{
            Module = $ModuleName
            User = $User
            Scopes = $Scopes
            IssuedAt = Get-Date
            ExpiresAt = (Get-Date).AddMinutes($ExpirationMinutes)
            LastUsed = $null
            Active = $true
        }

        # Store token
        $script:SecurityContext.ValidTokens[$token] = $tokenInfo
        $script:SecurityContext.TokenExpiration[$token] = $tokenInfo.ExpiresAt

        Write-CustomLog -Level 'SUCCESS' -Message "Authentication token created for module: $ModuleName"

        return @{
            Token = $token
            ModuleName = $ModuleName
            User = $User
            Scopes = $Scopes
            IssuedAt = $tokenInfo.IssuedAt
            ExpiresAt = $tokenInfo.ExpiresAt
            ExpirationMinutes = $ExpirationMinutes
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to create authentication token: $_"
        throw
    }
}
