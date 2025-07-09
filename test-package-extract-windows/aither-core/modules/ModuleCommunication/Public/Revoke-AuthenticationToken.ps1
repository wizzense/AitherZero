function Revoke-AuthenticationToken {
    <#
    .SYNOPSIS
        Revoke an authentication token
    .DESCRIPTION
        Revokes an authentication token, making it invalid for future use
    .PARAMETER Token
        Token to revoke
    .PARAMETER ModuleName
        Revoke all tokens for a specific module
    .PARAMETER User
        Revoke all tokens for a specific user
    .PARAMETER Force
        Force revocation without confirmation
    .EXAMPLE
        Revoke-AuthenticationToken -Token "abc123..." -Force
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Token')]
        [string]$Token,

        [Parameter(Mandatory, ParameterSetName = 'Module')]
        [string]$ModuleName,

        [Parameter(Mandatory, ParameterSetName = 'User')]
        [string]$User,

        [Parameter()]
        [switch]$Force
    )

    try {
        # Check if security is enabled
        if (-not $script:SecurityContext -or -not $script:SecurityContext.SecurityEnabled) {
            Write-CustomLog -Level 'WARNING' -Message "Security is not enabled"
            return @{
                Success = $false
                Reason = "Security not enabled"
            }
        }

        $revokedTokens = @()

        switch ($PSCmdlet.ParameterSetName) {
            'Token' {
                if ($script:SecurityContext.ValidTokens.ContainsKey($Token)) {
                    if (-not $Force) {
                        $tokenInfo = $script:SecurityContext.ValidTokens[$Token]
                        $choice = Read-Host "Revoke token for module '$($tokenInfo.Module)' issued to '$($tokenInfo.User)'? (y/N)"
                        if ($choice -ne 'y' -and $choice -ne 'Y') {
                            return @{
                                Success = $false
                                Reason = "Operation cancelled"
                            }
                        }
                    }

                    $tokenInfo = $script:SecurityContext.ValidTokens[$Token]
                    $script:SecurityContext.ValidTokens.Remove($Token)
                    $script:SecurityContext.TokenExpiration.Remove($Token)
                    $revokedTokens += @{
                        Token = $Token.Substring(0, 8) + "..."
                        Module = $tokenInfo.Module
                        User = $tokenInfo.User
                    }
                } else {
                    throw "Token not found"
                }
            }

            'Module' {
                $tokensToRevoke = @()
                foreach ($tokenKey in $script:SecurityContext.ValidTokens.Keys) {
                    $tokenInfo = $script:SecurityContext.ValidTokens[$tokenKey]
                    if ($tokenInfo.Module -eq $ModuleName) {
                        $tokensToRevoke += $tokenKey
                    }
                }

                if ($tokensToRevoke.Count -eq 0) {
                    throw "No tokens found for module: $ModuleName"
                }

                if (-not $Force) {
                    $choice = Read-Host "Revoke $($tokensToRevoke.Count) tokens for module '$ModuleName'? (y/N)"
                    if ($choice -ne 'y' -and $choice -ne 'Y') {
                        return @{
                            Success = $false
                            Reason = "Operation cancelled"
                        }
                    }
                }

                foreach ($tokenKey in $tokensToRevoke) {
                    $tokenInfo = $script:SecurityContext.ValidTokens[$tokenKey]
                    $script:SecurityContext.ValidTokens.Remove($tokenKey)
                    $script:SecurityContext.TokenExpiration.Remove($tokenKey)
                    $revokedTokens += @{
                        Token = $tokenKey.Substring(0, 8) + "..."
                        Module = $tokenInfo.Module
                        User = $tokenInfo.User
                    }
                }
            }

            'User' {
                $tokensToRevoke = @()
                foreach ($tokenKey in $script:SecurityContext.ValidTokens.Keys) {
                    $tokenInfo = $script:SecurityContext.ValidTokens[$tokenKey]
                    if ($tokenInfo.User -eq $User) {
                        $tokensToRevoke += $tokenKey
                    }
                }

                if ($tokensToRevoke.Count -eq 0) {
                    throw "No tokens found for user: $User"
                }

                if (-not $Force) {
                    $choice = Read-Host "Revoke $($tokensToRevoke.Count) tokens for user '$User'? (y/N)"
                    if ($choice -ne 'y' -and $choice -ne 'Y') {
                        return @{
                            Success = $false
                            Reason = "Operation cancelled"
                        }
                    }
                }

                foreach ($tokenKey in $tokensToRevoke) {
                    $tokenInfo = $script:SecurityContext.ValidTokens[$tokenKey]
                    $script:SecurityContext.ValidTokens.Remove($tokenKey)
                    $script:SecurityContext.TokenExpiration.Remove($tokenKey)
                    $revokedTokens += @{
                        Token = $tokenKey.Substring(0, 8) + "..."
                        Module = $tokenInfo.Module
                        User = $tokenInfo.User
                    }
                }
            }
        }

        Write-CustomLog -Level 'SUCCESS' -Message "Revoked $($revokedTokens.Count) authentication tokens"

        return @{
            Success = $true
            RevokedCount = $revokedTokens.Count
            RevokedTokens = $revokedTokens
            RevokedAt = Get-Date
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to revoke token: $_"
        throw
    }
}
