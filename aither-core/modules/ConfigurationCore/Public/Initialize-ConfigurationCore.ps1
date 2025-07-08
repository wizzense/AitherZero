function Initialize-ConfigurationCore {
    <#
    .SYNOPSIS
        Initialize the ConfigurationCore system
    .DESCRIPTION
        Sets up the unified configuration management system for AitherZero
    .PARAMETER ConfigPath
        Path to the main configuration file
    .PARAMETER Environment
        Initial environment to load (default: 'default')
    .PARAMETER Force
        Force reinitialization even if already initialized
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigPath,

        [Parameter()]
        [string]$Environment = 'default',

        [Parameter()]
        [switch]$Force
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Initializing ConfigurationCore system"

        # Load configuration from file if provided
        if ($ConfigPath -and (Test-Path $ConfigPath)) {
            Import-ConfigurationStore -Path $ConfigPath
        }

        # Set active environment
        if ($script:ConfigurationStore.Environments.ContainsKey($Environment)) {
            $script:ConfigurationStore.CurrentEnvironment = $Environment
            Write-CustomLog -Level 'INFO' -Message "Set active environment: $Environment"
        } else {
            Write-CustomLog -Level 'WARN' -Message "Environment '$Environment' not found, using default"
        }

        # Initialize default schemas for known modules
        Initialize-DefaultSchemas

        # Save initial state
        Save-ConfigurationStore

        Write-CustomLog -Level 'SUCCESS' -Message "ConfigurationCore initialized successfully"
        return $true

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to initialize ConfigurationCore: $_"
        throw
    }
}
