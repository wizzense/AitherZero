function Enable-CommunicationSecurity {
    <#
    .SYNOPSIS
        Enable security for inter-module communication
    .DESCRIPTION
        Enables authentication and authorization for module communication
    .PARAMETER DefaultTokenExpiration
        Default token expiration time in minutes
    .PARAMETER RequireAuthentication
        Require authentication for all API calls
    .PARAMETER AllowedModules
        List of modules allowed to communicate
    .EXAMPLE
        Enable-CommunicationSecurity -DefaultTokenExpiration 60 -RequireAuthentication
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$DefaultTokenExpiration = 60,

        [Parameter()]
        [switch]$RequireAuthentication,

        [Parameter()]
        [string[]]$AllowedModules = @()
    )

    try {
        # Initialize security context
        $script:SecurityContext = @{
            ValidTokens = @{}
            TokenExpiration = @{}
            ModulePermissions = @{}
            SecurityEnabled = $true
            RequireAuthentication = $RequireAuthentication.IsPresent
            DefaultTokenExpiration = $DefaultTokenExpiration
            AllowedModules = $AllowedModules
            EnabledAt = Get-Date
        }

        # Add security middleware automatically
        $securityMiddleware = {
            param($Context, $Next)

            # Skip security for internal calls
            if ($Context.Metadata.SkipSecurity) {
                return & $Next $Context
            }

            # Check if authentication is required
            if ($script:SecurityContext.RequireAuthentication) {
                $authHeader = $Context.Headers['Authorization']
                if (-not $authHeader) {
                    throw "Authentication required: Missing Authorization header"
                }

                # Extract token from header (format: "Bearer <token>")
                if ($authHeader -notmatch '^Bearer\s+(.+)$') {
                    throw "Authentication required: Invalid Authorization header format"
                }

                $token = $matches[1]
                $tokenValidation = Test-AuthenticationToken -Token $token -RequiredScopes @('api:call') -AllowedModules $script:SecurityContext.AllowedModules

                if (-not $tokenValidation.IsValid) {
                    throw "Authentication failed: $($tokenValidation.Reason)"
                }

                # Add authentication info to context
                $Context.Authentication = $tokenValidation
                $Context.User = $tokenValidation.User
                $Context.Module = $tokenValidation.Module
            }

            return & $Next $Context
        }

        # Add the security middleware with highest priority
        Add-APIMiddleware -Name "Security" -Priority 1 -Handler $securityMiddleware

        Write-CustomLog -Level 'SUCCESS' -Message "Communication security enabled"

        return @{
            Success = $true
            SecurityEnabled = $true
            RequireAuthentication = $RequireAuthentication.IsPresent
            DefaultTokenExpiration = $DefaultTokenExpiration
            AllowedModules = $AllowedModules
            EnabledAt = Get-Date
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to enable security: $_"
        throw
    }
}
