#Requires -Version 7.0

<#
.SYNOPSIS
    RestAPIServer module for AitherZero - External system integration via REST APIs
    
.DESCRIPTION
    This module provides a REST API server for external system integration,
    enabling third-party tools to interact with AitherZero automation capabilities
    through standardized HTTP endpoints.
    
.NOTES
    Author: AitherZero Development Team
    Version: 1.0.0
    PowerShell: 7.0+
#>

# Import shared utilities
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"

# Initialize module variables
$script:ModuleRoot = $PSScriptRoot
$script:ProjectRoot = Find-ProjectRoot
$script:APIServer = $null
$script:APIConfiguration = @{
    Port = 8080
    Protocol = 'HTTP'
    SSLEnabled = $false
    Authentication = 'ApiKey'
    CorsEnabled = $true
    RateLimiting = $true
    LoggingEnabled = $true
}
$script:RegisteredEndpoints = @{}
$script:WebhookSubscriptions = @{}

# Import Logging module
try {
    Import-Module (Join-Path $script:ProjectRoot "aither-core/modules/Logging") -Force
} catch {
    Write-Host "Warning: Could not import Logging module. Using Write-Host for output." -ForegroundColor Yellow
    # Define fallback logging function
    function Write-CustomLog {
        param($Message, $Level = "INFO")
        Write-Host "[$Level] $Message"
    }
}

# Import public functions
$publicFunctions = Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue
foreach ($function in $publicFunctions) {
    try {
        . $function.FullName
        Write-CustomLog -Message "Loaded function: $($function.BaseName)" -Level "DEBUG"
    } catch {
        Write-CustomLog -Message "Failed to load function $($function.BaseName): $($_.Exception.Message)" -Level "ERROR"
    }
}

# Module initialization
Write-CustomLog -Message "RestAPIServer v1.0.0 loaded - External integration capabilities" -Level "INFO"

# Export module members
Export-ModuleMember -Function @(
    'Start-AitherZeroAPI',
    'Stop-AitherZeroAPI',
    'Get-APIStatus',
    'Register-APIEndpoint',
    'Unregister-APIEndpoint',
    'Get-APIEndpoints',
    'Set-APIConfiguration',
    'Get-APIConfiguration',
    'Test-APIConnection',
    'Export-APIDocumentation',
    'Enable-APIWebhooks',
    'Disable-APIWebhooks',
    'Send-WebhookNotification',
    'Get-WebhookSubscriptions',
    'Add-WebhookSubscription',
    'Remove-WebhookSubscription'
)

# Initialize module-level variables for API management
$script:APIServerJob = $null
$script:APIStartTime = $null
$script:APIMetrics = @{
    RequestCount = 0
    ErrorCount = 0
    LastRequest = $null
    UpTime = 0
}