#Requires -Version 7.0

<#
.SYNOPSIS
    Initializes the AitherZero platform with unified API gateway interface.

.DESCRIPTION
    Creates a unified AitherZero platform object that provides a consistent API
    for all module operations. This function implements the API gateway pattern
    to simplify interaction with the complex module ecosystem.

.PARAMETER Profile
    The platform profile to initialize (Minimal, Standard, Full).

.PARAMETER Environment
    The environment configuration to load (default: 'default').

.PARAMETER Force
    Force reinitialization even if platform is already loaded.

.PARAMETER SkipHealthCheck
    Skip initial health check validation.

.PARAMETER AutoStart
    Automatically start platform services.

.EXAMPLE
    $aither = Initialize-AitherPlatform -Profile "Standard"
    $aither.Lab.Execute("DeployInfrastructure")

.EXAMPLE
    $aither = Initialize-AitherPlatform -Profile "Full"
    $aither.Configuration.Switch("Production")
    $aither.Patch.Create("Fix authentication bug")

.NOTES
    This function is the primary entry point for the unified AitherZero platform API.
    It returns a platform object with categorized access to all module functionality.
#>

function Initialize-AitherPlatform {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Minimal', 'Standard', 'Full')]
        [string]$Profile = 'Standard',

        [Parameter()]
        [string]$Environment = 'default',

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$SkipHealthCheck,

        [Parameter()]
        [switch]$AutoStart
    )

    begin {
        Write-CustomLog -Message "=== AitherZero Platform Initialization ===" -Level "INFO"
        Write-CustomLog -Message "Profile: $Profile | Environment: $Environment" -Level "INFO"
    }

    process {
        try {
            # Step 1: Initialize core application with profile-based module selection
            $requiredOnly = $Profile -eq 'Minimal'
            Initialize-CoreApplication -RequiredOnly:$requiredOnly -Force:$Force

            # Step 2: Initialize configuration system
            if (Get-Module ConfigurationCore -ErrorAction SilentlyContinue) {
                Initialize-ConfigurationCore -Environment $Environment
                Write-CustomLog -Message "✅ Configuration system initialized" -Level "SUCCESS"
            }

            # Step 3: Initialize communication system
            if (Get-Module ModuleCommunication -ErrorAction SilentlyContinue) {
                # Communication is initialized automatically via module import
                Write-CustomLog -Message "✅ Communication system ready" -Level "SUCCESS"
            }

            # Step 4: Create platform API gateway object
            $platform = New-AitherPlatformAPI -Profile $Profile -Environment $Environment

            # Step 5: Auto-start services if requested
            if ($AutoStart) {
                Start-PlatformServices -Platform $platform
                Write-CustomLog -Message "✅ Platform services started" -Level "SUCCESS"
            }

            # Step 6: Health check unless skipped
            if (-not $SkipHealthCheck) {
                $healthResult = Test-CoreApplicationHealth
                if (-not $healthResult) {
                    Write-CustomLog -Message "⚠️ Platform health check failed - some features may not work correctly" -Level "WARN"
                } else {
                    Write-CustomLog -Message "✅ Platform health check passed" -Level "SUCCESS"
                }
            }

            # Step 7: Log successful initialization
            $moduleCount = $script:LoadedModules.Count
            Write-CustomLog -Message "✅ AitherZero Platform initialized successfully" -Level "SUCCESS"
            Write-CustomLog -Message "Profile: $Profile | Modules: $moduleCount | API Gateway: Active" -Level "INFO"

            return $platform

        } catch {
            Write-CustomLog -Message "❌ Platform initialization failed: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}
