# Experience Functions - Consolidated into AitherCore Experience Domain
# Unified startup experience and setup wizard functionality
# Write-CustomLog is guaranteed to be available from AitherCore orchestration

#Requires -Version 7.0

using namespace System.IO
using namespace System.Collections.Generic
using namespace System.Management.Automation

# ============================================================================
# MODULE CONSTANTS AND VARIABLES
# ============================================================================

$script:MODULE_VERSION = '1.0.0'
$script:SETUP_METADATA_VERSION = '1.0'
$script:MAX_SETUP_BACKUPS = 5
$script:DEFAULT_SETUP_TIMEOUT = 300

# Cross-platform configuration paths
$script:ConfigProfilePath = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.aitherzero' 'profiles'
$script:CurrentProfile = $null
$script:TerminalUIEnabled = $false
$script:ManagementState = $null

# Setup wizard constants
$script:SetupWizardVersion = '2.0'
$script:MaxSetupRetries = 2
$script:SetupProgressSteps = 12

# Create profile directory if it doesn't exist
if (-not (Test-Path $script:ConfigProfilePath)) {
    try {
        New-Item -Path $script:ConfigProfilePath -ItemType Directory -Force | Out-Null
    } catch {
        Write-CustomLog -Level 'WARNING' -Message "Could not create profile directory: $($_.Exception.Message)"
    }
}

# Experience registry
$script:ExperienceRegistry = @{
    SetupProfiles = @{}
    InteractiveStates = @{}
    ConfigurationProfiles = @{}
    Metadata = @{
        Version = $script:MODULE_VERSION
        LastUpdated = Get-Date
        Platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } else { 'macOS' }
    }
}

# ============================================================================
# SETUP WIZARD FUNCTIONS
# ============================================================================

function Start-IntelligentSetup {
    <#
    .SYNOPSIS
        Intelligent setup wizard for AitherZero with auto-detection and installation profiles
    .DESCRIPTION
        Provides a guided setup experience with:
        - Platform detection
        - Installation profiles (minimal, developer, full)
        - AI tools integration
        - Dependency checking
        - Configuration templates
        - Progress tracking
    .PARAMETER SkipOptional
        Skip optional components during setup
    .PARAMETER MinimalSetup
        Use minimal installation profile
    .PARAMETER ConfigPath
        Custom configuration path
    .PARAMETER InstallationProfile
        Installation profile to use
    .EXAMPLE
        Start-IntelligentSetup
    .EXAMPLE
        Start-IntelligentSetup -InstallationProfile "developer"
    #>
    [CmdletBinding()]
    param(
        [switch]$SkipOptional,
        [switch]$MinimalSetup,
        [string]$ConfigPath,
        [ValidateSet('minimal', 'developer', 'full', 'interactive')]
        [string]$InstallationProfile = 'interactive'
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Starting intelligent setup wizard"
        
        # Initialize setup state
        $setupState = @{
            StartTime = Get-Date
            Platform = Get-PlatformInfo
            InstallationProfile = $InstallationProfile
            Steps = @()
            CurrentStep = 0
            TotalSteps = 12
            Errors = @()
            Warnings = @()
            Recommendations = @()
            AIToolsToInstall = @()
        }

        # Determine installation profile if interactive
        if ($InstallationProfile -eq 'interactive') {
            $setupState.InstallationProfile = Get-InstallationProfile
        }

        # Override for legacy parameter
        if ($MinimalSetup) {
            $setupState.InstallationProfile = 'minimal'
        }

        # Display welcome
        Show-WelcomeMessage -SetupState $setupState

        # Check if progress tracking is available
        $progressAvailable = Get-Module -Name 'ProgressTracking' -ListAvailable
        $useProgress = $false
        if ($progressAvailable -and -not $env:NO_PROGRESS) {
            try {
                Import-Module ProgressTracking -Force -ErrorAction Stop
                if (-not [System.Console]::IsInputRedirected -and $Host.UI.RawUI.WindowSize.Width -gt 0) {
                    $useProgress = $true
                }
            } catch {
                Write-CustomLog -Level 'DEBUG' -Message "ProgressTracking module not available: $_"
            }
        }

        # Create progress operation if available
        $progressId = $null
        if ($useProgress -and (Get-Command Start-ProgressOperation -ErrorAction SilentlyContinue)) {
            try {
                $progressId = Start-ProgressOperation `
                    -OperationName "AitherZero Intelligent Setup" `
                    -TotalSteps $setupState.TotalSteps `
                    -ShowTime `
                    -ShowETA
            } catch {
                Write-CustomLog -Level 'DEBUG' -Message "Progress tracking not available in current environment: $_"
                $useProgress = $false
            }
        }

        Show-SetupBanner

        # Run setup steps based on profile
        $setupStepsInfo = Get-SetupSteps -Profile $setupState.InstallationProfile
        $setupSteps = $setupStepsInfo.Steps
        $profileInfo = $setupStepsInfo.Profile

        # Show enhanced profile information
        Show-EnhancedInstallationProfile -Profile $setupState.InstallationProfile -ProfileInfo $profileInfo

        $setupState.TotalSteps = $setupSteps.Count
        $setupState.ProfileInfo = $profileInfo

        foreach ($step in $setupSteps) {
            $setupState.CurrentStep++
            Show-EnhancedProgress -State $setupState -StepName $step.Name -Status 'Running'

            $stepAttempts = 0
            $maxAttempts = $script:MaxSetupRetries
            $stepCompleted = $false

            while ($stepAttempts -lt $maxAttempts -and -not $stepCompleted) {
                $stepAttempts++

                try {
                    # Validate function exists before calling
                    if (-not (Get-Command $step.Function -ErrorAction SilentlyContinue)) {
                        throw "Step function '$($step.Function)' not found"
                    }

                    $result = & $step.Function -SetupState $setupState

                    # Normalize status values
                    if ($result.Status -eq 'Success') { $result.Status = 'Passed' }

                    $setupState.Steps += $result

                    if ($result.Status -eq 'Passed' -or $result.Status -eq 'Success') {
                        Show-EnhancedProgress -State $setupState -StepName $step.Name -Status 'Success'
                        $stepCompleted = $true
                    } elseif ($result.Status -eq 'Warning') {
                        Show-EnhancedProgress -State $setupState -StepName $step.Name -Status 'Warning'
                        $stepCompleted = $true
                    } elseif ($result.Status -eq 'Failed') {
                        Show-EnhancedProgress -State $setupState -StepName $step.Name -Status 'Failed' `
                            -ErrorContext @{ LastError = $result.Details -join '; ' }

                        # Attempt recovery if this is the first attempt
                        if ($stepAttempts -eq 1) {
                            Write-Host "  🔧 Attempting automatic recovery..." -ForegroundColor Blue
                            Show-EnhancedProgress -State $setupState -StepName $step.Name -Status 'Recovering'

                            $recovery = Invoke-ErrorRecovery -StepResult $result -SetupState $setupState -StepName $step.Name

                            if ($recovery.Success) {
                                Write-Host "  ✓ Recovery successful, retrying step..." -ForegroundColor Green
                                Show-EnhancedProgress -State $setupState -StepName $step.Name -Status 'Retrying' `
                                    -ErrorContext @{ RecoveryAttempted = $true; RecoveryMethod = $recovery.Method }
                                continue
                            } else {
                                Write-Host "  ⚠️ Recovery failed or not applicable" -ForegroundColor Yellow
                                $result.Details += $recovery.Details
                            }
                        }

                        # Prompt user for action if not in skip mode
                        if (-not $SkipOptional) {
                            Write-Host ""
                            Write-Host "Step Failed: $($step.Name)" -ForegroundColor Red
                            Write-Host "Details: $($result.Details -join '; ')" -ForegroundColor Gray

                            $choice = Show-SetupPrompt -Message "Continue anyway? (y=yes, n=abort setup, r=retry manually)" -DefaultYes:$false

                            if ($choice) {
                                Write-Host "  ⚠️ Continuing with failed step" -ForegroundColor Yellow
                                $stepCompleted = $true
                            } else {
                                Write-Host "`n❌ Setup cancelled by user" -ForegroundColor Red
                                return $setupState
                            }
                        } else {
                            Write-Host "  ⚠️ Skipping failed step (optional components mode)" -ForegroundColor Yellow
                            $stepCompleted = $true
                        }
                    }

                } catch {
                    $errorMessage = "Error in $($step.Name): $_"
                    $setupState.Errors += $errorMessage

                    Show-EnhancedProgress -State $setupState -StepName $step.Name -Status 'Failed' `
                        -ErrorContext @{ LastError = $_.Exception.Message }

                    Write-Host "  ❌ Exception: $_" -ForegroundColor Red

                    if ($stepAttempts -eq 1) {
                        Write-Host "  🔄 Retrying step due to exception..." -ForegroundColor Magenta
                        Show-EnhancedProgress -State $setupState -StepName $step.Name -Status 'Retrying'
                        Start-Sleep -Milliseconds 1000
                        continue
                    } else {
                        Write-Host "  ❌ Maximum retry attempts reached" -ForegroundColor Red
                        
                        # Create a failed result object for the step
                        $failedResult = @{
                            Name = $step.Name
                            Status = 'Failed'
                            Details = @("Exception occurred: $($_.Exception.Message)", "Maximum retry attempts reached")
                            ErrorDetails = @($_.Exception.Message)
                            RecoveryOptions = @()
                        }
                        
                        $setupState.Steps += $failedResult
                        $stepCompleted = $true
                    }
                }
            }

            Start-Sleep -Milliseconds 500  # Brief pause for visual feedback
        }

        # Show summary
        Show-SetupSummary -State $setupState

        Write-CustomLog -Level 'SUCCESS' -Message "Intelligent setup wizard completed"
        return $setupState

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Setup wizard failed: $($_.Exception.Message)"
        throw
    }
}

function Get-PlatformInfo {
    <#
    .SYNOPSIS
        Get detailed platform information
    .DESCRIPTION
        Returns comprehensive platform information for setup purposes
    #>
    try {
        $platformInfo = @{
            OS = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
            Version = if ($IsWindows) {
                [System.Environment]::OSVersion.Version.ToString()
            } elseif ($IsLinux) {
                if (Test-Path /etc/os-release) {
                    (Get-Content /etc/os-release | Select-String '^VERSION=' | ForEach-Object { $_.ToString().Split('=')[1].Trim('"') })
                } else { 'Unknown' }
            } elseif ($IsMacOS) {
                try { sw_vers -productVersion } catch { 'Unknown' }
            } else { 'Unknown' }
            Architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
            PowerShell = $PSVersionTable.PSVersion.ToString()
        }

        Write-CustomLog -Level 'INFO' -Message "Platform detected: $($platformInfo.OS) $($platformInfo.Version)"
        return $platformInfo

    } catch {
        Write-CustomLog -Level 'WARNING' -Message "Could not determine platform info: $($_.Exception.Message)"
        return @{
            OS = 'Unknown'
            Version = 'Unknown'
            Architecture = 'Unknown'
            PowerShell = $PSVersionTable.PSVersion.ToString()
        }
    }
}

function Show-WelcomeMessage {
    <#
    .SYNOPSIS
        Display welcome message for setup wizard
    .DESCRIPTION
        Shows initial welcome message with platform information
    .PARAMETER SetupState
        Current setup state object
    #>
    param($SetupState)

    try {
        Write-Host ""
        Write-Host "Welcome to AitherZero Setup!" -ForegroundColor Cyan
        Write-Host "============================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Platform: $($SetupState.Platform.OS) $($SetupState.Platform.Version)" -ForegroundColor Yellow
        Write-Host "PowerShell: $($SetupState.Platform.PowerShell)" -ForegroundColor Yellow
        Write-Host "Installation Profile: $($SetupState.InstallationProfile)" -ForegroundColor Yellow
        Write-Host ""

        Write-CustomLog -Level 'INFO' -Message "Setup welcome message displayed"

    } catch {
        Write-CustomLog -Level 'WARNING' -Message "Could not display welcome message: $($_.Exception.Message)"
    }
}

function Show-SetupBanner {
    <#
    .SYNOPSIS
        Display setup wizard banner
    .DESCRIPTION
        Shows the main setup wizard banner
    #>
    try {
        # Skip Clear-Host in non-interactive environments
        if (-not [System.Console]::IsInputRedirected -and $Host.UI.RawUI.WindowSize.Width -gt 0) {
            try {
                Clear-Host
            } catch {
                # Ignore Clear-Host errors in restricted environments
            }
        }

        Write-Host ""
        Write-Host "    ╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "    ║          AitherZero Intelligent Setup Wizard          ║" -ForegroundColor Cyan
        Write-Host "    ║                    Version $($script:SetupWizardVersion)                        ║" -ForegroundColor Cyan
        Write-Host "    ╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "    Welcome! This wizard will help you set up AitherZero" -ForegroundColor White
        Write-Host "    for optimal performance on your system." -ForegroundColor White
        Write-Host ""

        Write-CustomLog -Level 'INFO' -Message "Setup banner displayed"

    } catch {
        Write-CustomLog -Level 'WARNING' -Message "Could not display setup banner: $($_.Exception.Message)"
    }
}

function Get-InstallationProfile {
    <#
    .SYNOPSIS
        Interactive profile selection for AitherZero installation
    .DESCRIPTION
        Presents user with installation profile choices
    #>
    try {
        Write-Host ""
        Write-Host "  📦 Choose your installation profile:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "    1. 🏃 Minimal     - Core AitherZero + Infrastructure tools only" -ForegroundColor Green
        Write-Host "    2. 👨‍💻 Developer   - Minimal + AI tools + Development utilities" -ForegroundColor Blue
        Write-Host "    3. 🚀 Full        - Everything including advanced integrations" -ForegroundColor Magenta
        Write-Host ""

        do {
            $choice = Read-Host "  Enter your choice (1-3)"
            switch ($choice) {
                '1' { 
                    Write-CustomLog -Level 'INFO' -Message "Selected minimal installation profile"
                    return 'minimal' 
                }
                '2' { 
                    Write-CustomLog -Level 'INFO' -Message "Selected developer installation profile"
                    return 'developer' 
                }
                '3' { 
                    Write-CustomLog -Level 'INFO' -Message "Selected full installation profile"
                    return 'full' 
                }
                default {
                    Write-Host "  ❌ Invalid choice. Please enter 1, 2, or 3." -ForegroundColor Red
                }
            }
        } while ($true)

    } catch {
        Write-CustomLog -Level 'WARNING' -Message "Could not get installation profile, defaulting to minimal: $($_.Exception.Message)"
        return 'minimal'
    }
}

function Show-EnhancedInstallationProfile {
    <#
    .SYNOPSIS
        Display enhanced installation profile information
    .DESCRIPTION
        Shows detailed information about the selected installation profile
    .PARAMETER Profile
        Profile name
    .PARAMETER ProfileInfo
        Profile information hashtable
    #>
    param(
        [string]$Profile,
        [hashtable]$ProfileInfo
    )

    try {
        Write-Host ""
        Write-Host "  🎯 Installation Profile: $($ProfileInfo.Name.ToUpper())" -ForegroundColor Cyan
        Write-Host "  Description: $($ProfileInfo.Description)" -ForegroundColor Gray
        Write-Host "  Estimated Time: $($ProfileInfo.EstimatedTime)" -ForegroundColor Yellow

        if ($ProfileInfo.TargetUse -and $ProfileInfo.TargetUse.Count -gt 0) {
            Write-Host "  Target Use Cases: $($ProfileInfo.TargetUse -join ', ')" -ForegroundColor Blue
        }

        Write-Host ""
        Write-Host "  Setup Steps ($($ProfileInfo.Steps.Count + 5) total):" -ForegroundColor White

        # Show required vs optional steps
        $requiredSteps = ($ProfileInfo.Steps | Where-Object { $_.Required -eq $true }).Count + 3
        $optionalSteps = ($ProfileInfo.Steps | Where-Object { $_.Required -ne $true }).Count + 2

        Write-Host "    ✓ Required Steps: $requiredSteps" -ForegroundColor Green
        Write-Host "    ⚠️ Optional Steps: $optionalSteps" -ForegroundColor Yellow
        Write-Host ""

        Write-CustomLog -Level 'INFO' -Message "Enhanced profile information displayed for: $Profile"

    } catch {
        Write-CustomLog -Level 'WARNING' -Message "Could not display enhanced profile information: $($_.Exception.Message)"
    }
}

function Get-SetupSteps {
    <#
    .SYNOPSIS
        Get setup steps for a given profile
    .DESCRIPTION
        Returns the setup steps configuration for the specified profile
    .PARAMETER Profile
        Installation profile name
    .PARAMETER CustomProfile
        Custom profile configuration
    #>
    param(
        [string]$Profile,
        [hashtable]$CustomProfile = @{}
    )

    try {
        # Define base steps that run for all profiles
        $baseSteps = @(
            @{Name = 'Platform Detection'; Function = 'Test-PlatformRequirements'; AllProfiles = $true; Required = $true},
            @{Name = 'PowerShell Version'; Function = 'Test-PowerShellVersion'; AllProfiles = $true; Required = $true},
            @{Name = 'Git Installation'; Function = 'Test-GitInstallation'; AllProfiles = $true; Required = $false},
            @{Name = 'Infrastructure Tools'; Function = 'Test-InfrastructureTools'; AllProfiles = $true; Required = $false},
            @{Name = 'Module Dependencies'; Function = 'Test-ModuleDependencies'; AllProfiles = $true; Required = $true}
        )

        # Enhanced profile definitions with metadata
        $profileDefinitions = @{
            'minimal' = @{
                Name = 'Minimal'
                Description = 'Core AitherZero functionality only'
                TargetUse = @('CI/CD', 'Containers', 'Basic Infrastructure')
                EstimatedTime = '2-3 minutes'
                Steps = @(
                    @{Name = 'Network Connectivity'; Function = 'Test-NetworkConnectivity'; Required = $false},
                    @{Name = 'Security Settings'; Function = 'Test-SecuritySettings'; Required = $false},
                    @{Name = 'Configuration Files'; Function = 'Initialize-Configuration'; Required = $true},
                    @{Name = 'Configuration Review'; Function = 'Review-Configuration'; Required = $false},
                    @{Name = 'Quick Start Guide'; Function = 'Generate-QuickStartGuide'; Required = $false},
                    @{Name = 'Final Validation'; Function = 'Test-SetupCompletion'; Required = $true}
                )
            }
            'developer' = @{
                Name = 'Developer'
                Description = 'Development workstation setup with AI tools'
                TargetUse = @('Development', 'AI Tools', 'VS Code Integration')
                EstimatedTime = '5-8 minutes'
                Steps = @(
                    @{Name = 'Network Connectivity'; Function = 'Test-NetworkConnectivity'; Required = $false},
                    @{Name = 'Node.js Detection'; Function = 'Test-NodeJsInstallation'; Required = $false},
                    @{Name = 'AI Tools Setup'; Function = 'Install-AITools'; Required = $false},
                    @{Name = 'Development Environment'; Function = 'Test-DevEnvironment'; Required = $false},
                    @{Name = 'Security Settings'; Function = 'Test-SecuritySettings'; Required = $false},
                    @{Name = 'Configuration Files'; Function = 'Initialize-Configuration'; Required = $true},
                    @{Name = 'Configuration Review'; Function = 'Review-Configuration'; Required = $false},
                    @{Name = 'Quick Start Guide'; Function = 'Generate-QuickStartGuide'; Required = $false},
                    @{Name = 'Final Validation'; Function = 'Test-SetupCompletion'; Required = $true}
                )
            }
            'full' = @{
                Name = 'Full'
                Description = 'Complete installation with all features'
                TargetUse = @('Production', 'Enterprise', 'Complete Infrastructure')
                EstimatedTime = '8-12 minutes'
                Steps = @(
                    @{Name = 'Network Connectivity'; Function = 'Test-NetworkConnectivity'; Required = $false},
                    @{Name = 'Node.js Detection'; Function = 'Test-NodeJsInstallation'; Required = $false},
                    @{Name = 'AI Tools Setup'; Function = 'Install-AITools'; Required = $false},
                    @{Name = 'Cloud CLIs Detection'; Function = 'Test-CloudCLIs'; Required = $false},
                    @{Name = 'Development Environment'; Function = 'Test-DevEnvironment'; Required = $false},
                    @{Name = 'Security Settings'; Function = 'Test-SecuritySettings'; Required = $false},
                    @{Name = 'License Management'; Function = 'Test-LicenseIntegration'; Required = $false},
                    @{Name = 'Module Communication'; Function = 'Test-ModuleCommunication'; Required = $false},
                    @{Name = 'Configuration Files'; Function = 'Initialize-Configuration'; Required = $true},
                    @{Name = 'Configuration Review'; Function = 'Review-Configuration'; Required = $false},
                    @{Name = 'Quick Start Guide'; Function = 'Generate-QuickStartGuide'; Required = $false},
                    @{Name = 'Final Validation'; Function = 'Test-SetupCompletion'; Required = $true}
                )
            }
            'custom' = @{
                Name = 'Custom'
                Description = 'User-defined custom profile'
                TargetUse = @('Customized Setup')
                EstimatedTime = 'Variable'
                Steps = $CustomProfile.Steps ?? @()
            }
        }

        # Handle custom profile
        if ($CustomProfile.Count -gt 0) {
            $Profile = 'custom'
            $profileDefinitions['custom'] = $CustomProfile
        }

        # Get the profile definition
        $profileDef = $profileDefinitions[$Profile]
        if (-not $profileDef) {
            Write-CustomLog -Level 'WARNING' -Message "Unknown profile '$Profile', falling back to minimal"
            $profileDef = $profileDefinitions['minimal']
        }

        # Combine base steps with profile-specific steps and deduplicate by name
        $combinedSteps = $baseSteps + $profileDef.Steps
        $allSteps = @($combinedSteps | Group-Object Name | ForEach-Object { $_.Group[0] })

        Write-CustomLog -Level 'INFO' -Message "Setup steps configured for profile: $Profile ($($allSteps.Count) steps)"

        return @{
            Steps = $allSteps
            Profile = $profileDef
            EstimatedSteps = $allSteps.Count
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get setup steps: $($_.Exception.Message)"
        throw
    }
}

function Show-EnhancedProgress {
    <#
    .SYNOPSIS
        Enhanced progress display with error context
    .DESCRIPTION
        Shows progress information with status indicators and error details
    .PARAMETER State
        Setup state object
    .PARAMETER StepName
        Name of the current step
    .PARAMETER Status
        Current status
    .PARAMETER ErrorContext
        Error context information
    #>
    param(
        [hashtable]$State,
        [string]$StepName,
        [string]$Status = 'Running',
        [hashtable]$ErrorContext = @{}
    )

    try {
        $percentage = [math]::Round(($State.CurrentStep / $State.TotalSteps) * 100)
        $progressBar = "[" + ("█" * [math]::Floor($percentage / 5)) + ("░" * (20 - [math]::Floor($percentage / 5))) + "]"

        # Status emoji mapping
        $statusEmoji = @{
            'Running' = '🔍'
            'Success' = '✅'
            'Warning' = '⚠️'
            'Failed' = '❌'
            'Retrying' = '🔄'
            'Recovering' = '🔧'
        }

        $emoji = $statusEmoji[$Status] ?? '🔍'

        Write-Host ""
        Write-Host "  $progressBar $percentage% - Step $($State.CurrentStep)/$($State.TotalSteps)" -ForegroundColor Cyan

        # Show status with appropriate color
        $statusColor = switch ($Status) {
            'Success' { 'Green' }
            'Warning' { 'Yellow' }
            'Failed' { 'Red' }
            'Retrying' { 'Magenta' }
            'Recovering' { 'Blue' }
            default { 'Yellow' }
        }

        Write-Host "  $emoji $StepName - $Status" -ForegroundColor $statusColor

        # Show error context if provided
        if ($ErrorContext.Count -gt 0) {
            if ($ErrorContext.LastError) {
                Write-Host "    Error: $($ErrorContext.LastError)" -ForegroundColor Red
            }
            if ($ErrorContext.RecoveryAttempted) {
                Write-Host "    Recovery: $($ErrorContext.RecoveryMethod)" -ForegroundColor Blue
            }
        }

        # Update ProgressTracking if available
        if ($global:ProgressTrackingOperationId) {
            try {
                Update-ProgressOperation -OperationId $global:ProgressTrackingOperationId `
                    -IncrementStep -StepName "$StepName ($Status)"
            } catch {
                # Ignore ProgressTracking errors
            }
        }

        Write-CustomLog -Level 'DEBUG' -Message "Progress updated: $StepName ($Status) - $percentage%"

    } catch {
        Write-CustomLog -Level 'WARNING' -Message "Could not show enhanced progress: $($_.Exception.Message)"
    }
}

function Show-SetupPrompt {
    <#
    .SYNOPSIS
        Display setup prompt with fallback handling
    .DESCRIPTION
        Shows interactive prompts with support for non-interactive environments
    .PARAMETER Message
        Prompt message
    .PARAMETER DefaultYes
        Default to yes response
    #>
    param(
        [string]$Message,
        [switch]$DefaultYes
    )

    try {
        # In non-interactive mode or when host doesn't support prompts, use default
        if ([System.Console]::IsInputRedirected -or $env:NO_PROMPT -or $global:WhatIfPreference) {
            Write-Host "$Message [$(if ($DefaultYes) { 'Y' } else { 'N' })]" -ForegroundColor Yellow
            return $DefaultYes
        }

        try {
            $choices = '&Yes', '&No'
            $decision = $Host.UI.PromptForChoice('', $Message, $choices, $(if ($DefaultYes) { 0 } else { 1 }))
            return $decision -eq 0
        } catch {
            # Fallback to default if prompt fails
            Write-Host "$Message [$(if ($DefaultYes) { 'Y' } else { 'N' })] (auto-selected)" -ForegroundColor Yellow
            return $DefaultYes
        }

    } catch {
        Write-CustomLog -Level 'WARNING' -Message "Could not show setup prompt: $($_.Exception.Message)"
        return $DefaultYes
    }
}

function Show-SetupSummary {
    <#
    .SYNOPSIS
        Display setup completion summary
    .DESCRIPTION
        Shows comprehensive summary of setup results
    .PARAMETER State
        Setup state object
    #>
    param($State)

    try {
        Write-Host ""
        Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║                    Setup Summary                      ║" -ForegroundColor Cyan
        Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""

        # Define critical vs optional steps
        $criticalSteps = @('Platform Detection', 'PowerShell Version', 'Configuration Files', 'Final Validation')

        # Check status of critical vs optional steps
        $criticalFailed = ($State.Steps | Where-Object {
            $_.Status -eq 'Failed' -and $_.Name -in $criticalSteps
        }).Count

        $optionalWarnings = ($State.Steps | Where-Object {
            $_.Status -eq 'Warning' -and $_.Name -notin $criticalSteps
        }).Count

        $allPassed = ($State.Steps | Where-Object { $_.Status -eq 'Passed' -or $_.Status -eq 'Success' }).Count
        $totalSteps = $State.Steps.Count

        # Overall status based on critical failures
        if ($criticalFailed -gt 0) {
            Write-Host "  ❌ Setup Status: CRITICAL FAILURE" -ForegroundColor Red
            Write-Host "     Critical components failed - AitherZero cannot run!" -ForegroundColor Red
        } elseif ($allPassed -eq $totalSteps) {
            Write-Host "  🎉 Setup Status: PERFECT! ALL COMPONENTS READY" -ForegroundColor Green
        } elseif ($optionalWarnings -gt 0) {
            Write-Host "  ✅ Setup Status: READY TO USE (with optional components missing)" -ForegroundColor Yellow
            Write-Host "     AitherZero will work, but some features may be limited" -ForegroundColor Yellow
        } else {
            Write-Host "  ✅ Setup Status: READY TO USE" -ForegroundColor Green
        }

        Write-Host ""
        Write-Host "  Setup Results:" -ForegroundColor White
        foreach ($step in $State.Steps) {
            $icon = switch ($step.Status) {
                'Passed' { '✅' }
                'Success' { '✅' }
                'Failed' { '❌' }
                'Warning' { '⚠️' }
                default { '❓' }
            }

            Write-Host "    $icon $($step.Name)" -ForegroundColor $(
                switch ($step.Status) {
                    'Passed' { 'Green' }
                    'Failed' { 'Red' }
                    'Warning' { 'Yellow' }
                    default { 'Gray' }
                }
            )
        }

        if ($State.Recommendations.Count -gt 0) {
            Write-Host ""
            Write-Host "  💡 Recommendations:" -ForegroundColor Yellow
            $State.Recommendations | Select-Object -First 3 | ForEach-Object {
                Write-Host "     • $_" -ForegroundColor White
            }
            if ($State.Recommendations.Count -gt 3) {
                Write-Host "     • ... and $($State.Recommendations.Count - 3) more" -ForegroundColor Gray
            }
        }

        Write-Host ""
        Write-Host ""
        Write-Host "  📁 Configuration saved to:" -ForegroundColor White
        Write-Host "     $(if ($State.Platform.OS -eq 'Windows') { "$env:APPDATA\AitherZero" } else { "~/.config/aitherzero" })" -ForegroundColor Gray
        Write-Host ""

        # Show clear what to do next
        Write-Host "  🚀 WHAT TO DO NEXT:" -ForegroundColor Green
        Write-Host "  ═══════════════════" -ForegroundColor Green
        Write-Host ""

        if ($criticalFailed -eq 0) {
            Write-Host "  Your setup is complete! AitherZero is ready to use." -ForegroundColor White
            Write-Host ""
            Write-Host "  TO START USING AITHERZERO:" -ForegroundColor Cyan
            Write-Host "  1. Close this setup window" -ForegroundColor White
            Write-Host "  2. Run one of these commands:" -ForegroundColor White
            Write-Host ""
            Write-Host "     INTERACTIVE MODE (Recommended for first time):" -ForegroundColor Yellow
            Write-Host "     ./Start-AitherZero.ps1" -ForegroundColor Green
            Write-Host ""
            Write-Host "     RUN SPECIFIC MODULE:" -ForegroundColor Yellow
            Write-Host "     ./Start-AitherZero.ps1 -Scripts 'LabRunner'" -ForegroundColor Green
            Write-Host ""
            Write-Host "     AUTOMATED MODE:" -ForegroundColor Yellow
            Write-Host "     ./Start-AitherZero.ps1 -Auto" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  CRITICAL ISSUES MUST BE FIXED FIRST:" -ForegroundColor Red
            Write-Host ""
            foreach ($critical in ($State.Steps | Where-Object { $_.Status -eq 'Failed' -and $_.Name -in $criticalSteps })) {
                Write-Host "     • Fix: $($critical.Name)" -ForegroundColor Red
                if ($critical.Details) {
                    $critical.Details | Where-Object { $_ -match "^❌" } | ForEach-Object {
                        Write-Host "       $_" -ForegroundColor Gray
                    }
                }
            }
        }

        Write-Host ""

        Write-CustomLog -Level 'SUCCESS' -Message "Setup summary displayed"

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Could not display setup summary: $($_.Exception.Message)"
    }
}

function Invoke-ErrorRecovery {
    <#
    .SYNOPSIS
        Enhanced error recovery system for setup failures
    .DESCRIPTION
        Attempts to recover from setup step failures
    .PARAMETER StepResult
        Result from the failed step
    .PARAMETER SetupState
        Current setup state
    .PARAMETER StepName
        Name of the failed step
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$StepResult,

        [Parameter(Mandatory)]
        [hashtable]$SetupState,

        [string]$StepName
    )

    try {
        $recovery = @{
            Attempted = $false
            Success = $false
            Method = ''
            Details = @()
        }

        # Determine recovery strategy based on step type and error
        switch ($StepName) {
            'Node.js Detection' {
                $recovery.Method = 'Package Manager Installation'
                $recovery.Details += "Attempting to install Node.js via package manager..."

                try {
                    if ($IsWindows) {
                        if (Get-Command winget -ErrorAction SilentlyContinue) {
                            & winget install OpenJS.NodeJS --silent
                            $recovery.Success = $true
                            $recovery.Details += "✓ Node.js installed via winget"
                        } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
                            & choco install nodejs -y
                            $recovery.Success = $true
                            $recovery.Details += "✓ Node.js installed via Chocolatey"
                        }
                    } elseif ($IsLinux) {
                        if (Get-Command apt -ErrorAction SilentlyContinue) {
                            & sudo apt update && sudo apt install -y nodejs npm
                            $recovery.Success = $true
                            $recovery.Details += "✓ Node.js installed via apt"
                        } elseif (Get-Command yum -ErrorAction SilentlyContinue) {
                            & sudo yum install -y nodejs npm
                            $recovery.Success = $true
                            $recovery.Details += "✓ Node.js installed via yum"
                        }
                    } elseif ($IsMacOS) {
                        if (Get-Command brew -ErrorAction SilentlyContinue) {
                            & brew install node
                            $recovery.Success = $true
                            $recovery.Details += "✓ Node.js installed via Homebrew"
                        }
                    }

                    $recovery.Attempted = $true

                } catch {
                    $recovery.Details += "⚠️ Automatic installation failed: $_"
                    $recovery.Details += "Manual installation required: https://nodejs.org"
                }
            }

            'Git Installation' {
                $recovery.Method = 'Package Manager Installation'
                $recovery.Details += "Attempting to install Git via package manager..."

                try {
                    if ($IsWindows) {
                        if (Get-Command winget -ErrorAction SilentlyContinue) {
                            & winget install Git.Git --silent
                            $recovery.Success = $true
                            $recovery.Details += "✓ Git installed via winget"
                        }
                    } elseif ($IsLinux) {
                        if (Get-Command apt -ErrorAction SilentlyContinue) {
                            & sudo apt update && sudo apt install -y git
                            $recovery.Success = $true
                            $recovery.Details += "✓ Git installed via apt"
                        }
                    } elseif ($IsMacOS) {
                        if (Get-Command brew -ErrorAction SilentlyContinue) {
                            & brew install git
                            $recovery.Success = $true
                            $recovery.Details += "✓ Git installed via Homebrew"
                        }
                    }

                    $recovery.Attempted = $true

                } catch {
                    $recovery.Details += "⚠️ Automatic installation failed: $_"
                    $recovery.Details += "Manual installation required"
                }
            }

            'Configuration Files' {
                $recovery.Method = 'Directory Creation and Permissions Fix'
                $recovery.Details += "Attempting to create configuration directories with proper permissions..."

                try {
                    # Create config directories
                    $configDir = if ($IsWindows) {
                        Join-Path $env:APPDATA "AitherZero"
                    } else {
                        Join-Path $env:HOME ".config/aitherzero"
                    }

                    New-Item -Path $configDir -ItemType Directory -Force | Out-Null

                    # Set appropriate permissions
                    if (-not $IsWindows) {
                        & chmod 755 $configDir
                    }

                    $recovery.Success = $true
                    $recovery.Attempted = $true
                    $recovery.Details += "✓ Configuration directory created: $configDir"

                } catch {
                    $recovery.Details += "⚠️ Directory creation failed: $_"
                }
            }

            default {
                $recovery.Method = 'Generic Retry'
                $recovery.Details += "No specific recovery method available for: $StepName"
            }
        }

        Write-CustomLog -Level 'INFO' -Message "Error recovery attempted for $StepName (Success: $($recovery.Success))"
        return $recovery

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Error recovery failed: $($_.Exception.Message)"
        return @{
            Attempted = $false
            Success = $false
            Method = 'Error'
            Details = @("Recovery failed: $($_.Exception.Message)")
        }
    }
}

# ============================================================================
# STARTUP EXPERIENCE FUNCTIONS
# ============================================================================

function Start-InteractiveMode {
    <#
    .SYNOPSIS
        Starts the interactive startup experience with rich terminal UI
    .DESCRIPTION
        Launches the main interactive menu system for AitherZero configuration and module management
    .PARAMETER Profile
        Configuration profile to load
    .PARAMETER SkipLicenseCheck
        Skip license validation (for testing)
    .EXAMPLE
        Start-InteractiveMode
    .EXAMPLE
        Start-InteractiveMode -Profile "development"
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Profile,

        [Parameter()]
        [switch]$SkipLicenseCheck
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Starting interactive mode"

        # Check license status unless skipped
        if (-not $SkipLicenseCheck) {
            # Try to load LicenseManager module if not already loaded
            if (-not (Get-Command Get-LicenseStatus -ErrorAction SilentlyContinue)) {
                try {
                    $projectRoot = Find-ProjectRoot
                    $licenseManagerPath = Join-Path $projectRoot "aither-core" "modules" "LicenseManager"
                    if (Test-Path $licenseManagerPath) {
                        Import-Module $licenseManagerPath -Force -ErrorAction Stop
                    }
                } catch {
                    Write-CustomLog -Level 'WARNING' -Message "Could not load LicenseManager module: $_"
                }
            }

            # Get license status with fallback
            try {
                $licenseStatus = Get-LicenseStatus
                $availableTier = $licenseStatus.Tier ?? 'free'
            } catch {
                Write-CustomLog -Level 'WARNING' -Message "Could not get license status: $_"
                $availableTier = 'free'
            }
        } else {
            $availableTier = 'enterprise'
        }

        # Load configuration profile if specified
        if ($Profile) {
            try {
                $config = Get-ConfigurationProfile -Name $Profile
                if ($config) {
                    Set-ConfigurationProfile -Name $Profile
                }
            } catch {
                Write-CustomLog -Level 'WARNING' -Message "Configuration profile '$Profile' not found: $_"
                Write-Host "Continuing with default configuration..." -ForegroundColor Yellow
            }
        }

        # Initialize terminal UI
        Initialize-TerminalUI

        # Main menu loop
        $exitRequested = $false
        while (-not $exitRequested) {
            Clear-Host
            Show-Banner -Tier $availableTier

            $menuOptions = @(
                @{Text = "Configuration Manager"; Action = "ConfigManager"; Tier = "free"},
                @{Text = "Module Explorer"; Action = "ModuleExplorer"; Tier = "free"},
                @{Text = "Run Scripts"; Action = "RunScripts"; Tier = "free"},
                @{Text = "Profile Management"; Action = "ProfileManager"; Tier = "free"},
                @{Text = "License Management"; Action = "LicenseManager"; Tier = "free"},
                @{Text = "Settings"; Action = "Settings"; Tier = "free"},
                @{Text = "Exit"; Action = "Exit"; Tier = "free"}
            )

            # Filter menu options based on tier with fallback
            $availableOptions = $menuOptions | Where-Object {
                try {
                    # Check if LicenseManager functions are available
                    if (Get-Command Test-TierAccess -ErrorAction SilentlyContinue) {
                        Test-TierAccess -RequiredTier $_.Tier -CurrentTier $availableTier
                    } else {
                        # Fallback tier logic if LicenseManager not available
                        $tierLevels = @{ 'free' = 1; 'pro' = 2; 'professional' = 2; 'enterprise' = 3 }
                        $requiredLevel = $tierLevels[$_.Tier.ToLower()] ?? 1
                        $currentLevel = $tierLevels[$availableTier.ToLower()] ?? 1
                        $currentLevel -ge $requiredLevel
                    }
                } catch {
                    Write-CustomLog -Level 'WARNING' -Message "Error checking tier access for $($_.Text): $_"
                    $true
                }
            }

            $selectedOption = Show-ContextMenu -Title "Main Menu" -Options $availableOptions -ReturnAction

            switch ($selectedOption) {
                "ConfigManager" {
                    Show-ConfigurationManager -Tier $availableTier
                }
                "ModuleExplorer" {
                    Show-ModuleExplorer -Tier $availableTier
                }
                "RunScripts" {
                    Start-ScriptRunner -Tier $availableTier
                }
                "ProfileManager" {
                    Show-ProfileManager
                }
                "LicenseManager" {
                    Show-LicenseManager
                }
                "Settings" {
                    Show-Settings
                }
                "Exit" {
                    $exitRequested = $true
                }
            }
        }

        Write-Host "`nExiting interactive mode..." -ForegroundColor Green
        Write-CustomLog -Level 'SUCCESS' -Message "Interactive mode completed"

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Error in interactive mode: $($_.Exception.Message)"
        throw
    } finally {
        # Cleanup terminal UI
        Reset-TerminalUI
    }
}

function Get-StartupMode {
    <#
    .SYNOPSIS
        Determines the appropriate startup mode with performance analytics
    .DESCRIPTION
        Analyzes parameters and environment to determine whether to use interactive or non-interactive mode.
        Includes performance metrics and UI capability detection.
    .PARAMETER Parameters
        Hashtable of parameters passed to Start-AitherZero
    .PARAMETER IncludeAnalytics
        Include detailed performance and capability analytics
    .EXAMPLE
        $mode = Get-StartupMode -Parameters $PSBoundParameters
    .EXAMPLE
        $mode = Get-StartupMode -IncludeAnalytics
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [hashtable]$Parameters = @{},

        [Parameter()]
        [switch]$IncludeAnalytics
    )

    try {
        $startTime = Get-Date
        $analytics = @{}

        # Check for explicit mode parameters
        if ($Parameters.ContainsKey('NonInteractive') -or $Parameters.ContainsKey('Auto')) {
            $result = [PSCustomObject]@{
                Mode = 'NonInteractive'
                Reason = 'Explicit non-interactive parameter'
                UseEnhancedUI = $false
                UICapability = 'Disabled'
            }

            if ($IncludeAnalytics) {
                $result | Add-Member -MemberType NoteProperty -Name 'Analytics' -Value @{
                    DetectionTime = ((Get-Date) - $startTime).TotalMilliseconds
                    Method = 'Parameter'
                }
            }

            return $result
        }

        if ($Parameters.ContainsKey('Interactive') -or $Parameters.ContainsKey('Quickstart')) {
            $uiCapability = Test-EnhancedUICapability

            $result = [PSCustomObject]@{
                Mode = 'Interactive'
                Reason = 'Explicit interactive parameter'
                UseEnhancedUI = $uiCapability
                UICapability = if ($uiCapability) { 'Enhanced' } else { 'Classic' }
            }

            if ($IncludeAnalytics) {
                $result | Add-Member -MemberType NoteProperty -Name 'Analytics' -Value @{
                    DetectionTime = ((Get-Date) - $startTime).TotalMilliseconds
                    Method = 'Parameter'
                    UITest = $uiCapability
                }
            }

            return $result
        }

        # Performance: Check environment variables
        $envCheckStart = Get-Date
        $ciVariables = @(
            'CI', 'TF_BUILD', 'GITHUB_ACTIONS', 'GITLAB_CI', 'JENKINS_URL',
            'TEAMCITY_VERSION', 'TRAVIS', 'CIRCLECI', 'APPVEYOR', 'CODEBUILD_BUILD_ID'
        )

        foreach ($var in $ciVariables) {
            if (Get-Item "Env:$var" -ErrorAction SilentlyContinue) {
                $result = [PSCustomObject]@{
                    Mode = 'NonInteractive'
                    Reason = "CI/CD environment detected ($var)"
                    UseEnhancedUI = $false
                    UICapability = 'Unavailable'
                }

                if ($IncludeAnalytics) {
                    $result | Add-Member -MemberType NoteProperty -Name 'Analytics' -Value @{
                        DetectionTime = ((Get-Date) - $startTime).TotalMilliseconds
                        Method = 'Environment'
                        DetectedVariable = $var
                        EnvCheckTime = ((Get-Date) - $envCheckStart).TotalMilliseconds
                    }
                }

                return $result
            }
        }

        # Performance: Check terminal capabilities
        $terminalCheckStart = Get-Date

        # Check if running in non-interactive shell
        if (-not [Environment]::UserInteractive) {
            $result = [PSCustomObject]@{
                Mode = 'NonInteractive'
                Reason = 'Non-interactive shell detected'
                UseEnhancedUI = $false
                UICapability = 'Unavailable'
            }

            if ($IncludeAnalytics) {
                $result | Add-Member -MemberType NoteProperty -Name 'Analytics' -Value @{
                    DetectionTime = ((Get-Date) - $startTime).TotalMilliseconds
                    Method = 'Shell'
                    TerminalCheckTime = ((Get-Date) - $terminalCheckStart).TotalMilliseconds
                }
            }

            return $result
        }

        # Check terminal capabilities
        $uiCapability = Test-EnhancedUICapability
        $isOutputRedirected = [Console]::IsOutputRedirected

        if (-not $isOutputRedirected -and $uiCapability) {
            # Interactive terminal with enhanced capabilities
            $result = [PSCustomObject]@{
                Mode = 'Interactive'
                Reason = 'Enhanced interactive terminal detected'
                UseEnhancedUI = $true
                UICapability = 'Enhanced'
            }
        } elseif (-not $isOutputRedirected) {
            # Interactive terminal with limited capabilities
            $result = [PSCustomObject]@{
                Mode = 'Interactive'
                Reason = 'Basic interactive terminal detected'
                UseEnhancedUI = $false
                UICapability = 'Classic'
            }
        } else {
            # Output redirected - non-interactive
            $result = [PSCustomObject]@{
                Mode = 'NonInteractive'
                Reason = 'Output redirection detected'
                UseEnhancedUI = $false
                UICapability = 'Unavailable'
            }
        }

        if ($IncludeAnalytics) {
            $result | Add-Member -MemberType NoteProperty -Name 'Analytics' -Value @{
                DetectionTime = ((Get-Date) - $startTime).TotalMilliseconds
                Method = 'Terminal'
                TerminalCheckTime = ((Get-Date) - $terminalCheckStart).TotalMilliseconds
                OutputRedirected = $isOutputRedirected
                UICapabilityTest = $uiCapability
            }
        }

        Write-CustomLog -Level 'INFO' -Message "Startup mode determined: $($result.Mode) ($($result.Reason))"
        return $result

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Error determining startup mode: $($_.Exception.Message)"
        
        # If we can't determine, default to non-interactive
        $result = [PSCustomObject]@{
            Mode = 'NonInteractive'
            Reason = "Error determining mode: $_"
            UseEnhancedUI = $false
            UICapability = 'Error'
        }

        if ($IncludeAnalytics) {
            $result | Add-Member -MemberType NoteProperty -Name 'Analytics' -Value @{
                DetectionTime = ((Get-Date) - $startTime).TotalMilliseconds
                Method = 'Error'
                Error = $_.Exception.Message
            }
        }

        return $result
    }
}

function Show-Banner {
    <#
    .SYNOPSIS
        Display AitherZero banner with tier information
    .DESCRIPTION
        Shows the main AitherZero banner with license tier
    .PARAMETER Tier
        License tier to display
    #>
    param(
        [string]$Tier = 'free'
    )

    try {
        $version = "1.0.0"
        $tierDisplay = switch ($Tier) {
            'pro' { " [PRO]" }
            'enterprise' { " [ENTERPRISE]" }
            default { "" }
        }

        Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║                  AitherZero v$version$tierDisplay                  ║
║          Infrastructure Automation Platform                   ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

        Write-CustomLog -Level 'INFO' -Message "Banner displayed for tier: $Tier"

    } catch {
        Write-CustomLog -Level 'WARNING' -Message "Could not display banner: $($_.Exception.Message)"
    }
}

function Initialize-TerminalUI {
    <#
    .SYNOPSIS
        Initialize terminal UI settings
    .DESCRIPTION
        Sets up terminal UI for enhanced interactive experience
    #>
    try {
        $script:TerminalUIEnabled = $true
        
        # Set console output encoding if possible
        if ($IsWindows) {
            try {
                [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            } catch {
                Write-CustomLog -Level 'DEBUG' -Message "Could not set console encoding: $_"
            }
        }

        Write-CustomLog -Level 'INFO' -Message "Terminal UI initialized"

    } catch {
        Write-CustomLog -Level 'WARNING' -Message "Could not initialize terminal UI: $($_.Exception.Message)"
        $script:TerminalUIEnabled = $false
    }
}

function Reset-TerminalUI {
    <#
    .SYNOPSIS
        Reset terminal UI to default state
    .DESCRIPTION
        Cleans up terminal UI settings
    #>
    try {
        $script:TerminalUIEnabled = $false
        Write-CustomLog -Level 'INFO' -Message "Terminal UI reset"

    } catch {
        Write-CustomLog -Level 'WARNING' -Message "Could not reset terminal UI: $($_.Exception.Message)"
    }
}

function Test-EnhancedUICapability {
    <#
    .SYNOPSIS
        Test if enhanced UI capabilities are available
    .DESCRIPTION
        Checks if the terminal supports enhanced UI features
    #>
    try {
        # Check for basic terminal capabilities
        if ([Console]::IsOutputRedirected -or [Console]::IsInputRedirected) {
            return $false
        }

        # Check for interactive host
        if (-not [Environment]::UserInteractive) {
            return $false
        }

        # Check for host UI capabilities
        if (-not $Host.UI.RawUI) {
            return $false
        }

        # Check for window size support
        try {
            $windowSize = $Host.UI.RawUI.WindowSize
            if ($windowSize.Width -eq 0 -or $windowSize.Height -eq 0) {
                return $false
            }
        } catch {
            return $false
        }

        return $true

    } catch {
        Write-CustomLog -Level 'DEBUG' -Message "Enhanced UI capability test failed: $($_.Exception.Message)"
        return $false
    }
}

function Show-ContextMenu {
    <#
    .SYNOPSIS
        Display context menu with options
    .DESCRIPTION
        Shows a context menu and returns the selected action
    .PARAMETER Title
        Menu title
    .PARAMETER Options
        Menu options array
    .PARAMETER ReturnAction
        Return action instead of index
    #>
    param(
        [string]$Title,
        [array]$Options,
        [switch]$ReturnAction
    )

    try {
        Write-Host "`n$Title" -ForegroundColor Cyan
        Write-Host ("-" * $Title.Length) -ForegroundColor Cyan
        Write-Host ""

        for ($i = 0; $i -lt $Options.Count; $i++) {
            Write-Host "  [$($i + 1)] $($Options[$i].Text)" -ForegroundColor White
        }

        Write-Host ""
        $selection = Read-Host "Select option (1-$($Options.Count))"

        if ($selection -match '^\d+$') {
            $index = [int]$selection - 1
            if ($index -ge 0 -and $index -lt $Options.Count) {
                if ($ReturnAction) {
                    return $Options[$index].Action
                } else {
                    return $index
                }
            }
        }

        return $null

    } catch {
        Write-CustomLog -Level 'WARNING' -Message "Could not show context menu: $($_.Exception.Message)"
        return $null
    }
}

# ============================================================================
# CONFIGURATION FUNCTIONS
# ============================================================================

function Edit-Configuration {
    <#
    .SYNOPSIS
        Interactive configuration editor for AitherZero
    .DESCRIPTION
        Provides an interactive way to edit configuration settings
        Supports both ConfigurationCore and legacy JSON configurations
    .PARAMETER ConfigPath
        Path to configuration file
    .PARAMETER CreateIfMissing
        Create configuration if it doesn't exist
    .PARAMETER UseConfigurationCore
        Use ConfigurationCore for configuration management
    .EXAMPLE
        Edit-Configuration
    .EXAMPLE
        Edit-Configuration -ConfigPath "./configs/custom.json"
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigPath,
        [switch]$CreateIfMissing,
        [switch]$UseConfigurationCore
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Starting configuration editor"

        # Try ConfigurationCore first if requested or available
        if ($UseConfigurationCore -or (-not $ConfigPath)) {
            try {
                $configCoreModule = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "ConfigurationCore"
                if (Test-Path $configCoreModule) {
                    Import-Module $configCoreModule -Force -ErrorAction Stop

                    Write-Host "`n⚙️  Configuration Editor (ConfigurationCore)" -ForegroundColor Green
                    Write-Host "Using unified configuration management" -ForegroundColor Yellow
                    Write-Host ""

                    # Use ConfigurationCore-based editing
                    Edit-ConfigurationCore
                    return
                }
            } catch {
                Write-CustomLog -Level 'DEBUG' -Message "ConfigurationCore not available, falling back to legacy: $_"
            }
        }

        # Find config file for legacy mode
        if (-not $ConfigPath) {
            $possiblePaths = @(
                (Join-Path $env:PROJECT_ROOT "configs/default-config.json"),
                "./configs/default-config.json",
                (Join-Path (Find-ProjectRoot) "configs/default-config.json")
            )

            foreach ($path in $possiblePaths) {
                if (Test-Path $path) {
                    $ConfigPath = $path
                    break
                }
            }
        }

        if (-not $ConfigPath -or -not (Test-Path $ConfigPath)) {
            if ($CreateIfMissing) {
                # Create default config
                $ConfigPath = Join-Path (Find-ProjectRoot) "configs/default-config.json"
                $configDir = Split-Path $ConfigPath -Parent

                if (-not (Test-Path $configDir)) {
                    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
                }

                $defaultConfig = @{
                    environment = "development"
                    modules = @{
                        enabled = @("LabRunner", "BackupManager", "OpenTofuProvider")
                        autoLoad = $true
                    }
                    logging = @{
                        level = "INFO"
                        path = "./logs"
                    }
                    infrastructure = @{
                        provider = "opentofu"
                        stateBackend = "local"
                    }
                }

                $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath
                Write-Host "✓ Created default configuration at: $ConfigPath" -ForegroundColor Green
            } else {
                Write-Host "❌ Configuration file not found!" -ForegroundColor Red
                return
            }
        }

        Write-Host "`n⚙️  Configuration Editor" -ForegroundColor Green
        Write-Host "File: $ConfigPath" -ForegroundColor Yellow
        Write-Host ""

        # Read current config
        try {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $originalJson = $config | ConvertTo-Json -Depth 10
        } catch {
            Write-Host "❌ Error reading configuration: $_" -ForegroundColor Red
            return
        }

        $editing = $true
        while ($editing) {
            Clear-Host
            Write-Host "`n⚙️  Configuration Editor" -ForegroundColor Green
            Write-Host "=" * 50 -ForegroundColor Cyan

            # Display current config
            Write-Host "`nCurrent Configuration:" -ForegroundColor Yellow
            $config | ConvertTo-Json -Depth 10 | Write-Host

            Write-Host "`n" + "=" * 50 -ForegroundColor Cyan
            Write-Host "Options:" -ForegroundColor Yellow
            Write-Host "  [1] Edit Environment (current: $($config.environment ?? 'not set'))" -ForegroundColor White
            Write-Host "  [2] Manage Enabled Modules" -ForegroundColor White
            Write-Host "  [3] Configure Logging" -ForegroundColor White
            Write-Host "  [4] Infrastructure Settings" -ForegroundColor White
            Write-Host "  [5] Add Custom Setting" -ForegroundColor White
            Write-Host "  [6] Remove Setting" -ForegroundColor White
            Write-Host "  [7] Open in External Editor" -ForegroundColor White
            Write-Host "  [8] Reset to Defaults" -ForegroundColor White
            Write-Host "  [S] Save Changes" -ForegroundColor Green
            Write-Host "  [Q] Quit Without Saving" -ForegroundColor Gray
            Write-Host ""

            $choice = Read-Host "Select option"

            switch ($choice.ToUpper()) {
                '1' {
                    Write-Host "`nAvailable environments:" -ForegroundColor Yellow
                    Write-Host "  • development" -ForegroundColor White
                    Write-Host "  • staging" -ForegroundColor White
                    Write-Host "  • production" -ForegroundColor White
                    Write-Host "  • custom (enter your own)" -ForegroundColor White

                    $env = Read-Host "`nEnter environment"
                    if ($env) {
                        $config.environment = $env
                        Write-Host "✓ Environment set to: $env" -ForegroundColor Green
                    }
                }
                '2' {
                    Write-Host "`nModule Management" -ForegroundColor Yellow

                    # Get available modules
                    $availableModules = Get-ChildItem -Path (Join-Path (Find-ProjectRoot) "aither-core" "modules") -Directory | 
                                       Select-Object -ExpandProperty Name | Sort-Object
                    $enabledModules = @($config.modules.enabled)

                    Write-Host "`nAvailable Modules:" -ForegroundColor Cyan
                    for ($i = 0; $i -lt $availableModules.Count; $i++) {
                        $module = $availableModules[$i]
                        $status = if ($module -in $enabledModules) { "[✓]" } else { "[ ]" }
                        Write-Host "  $status $($i+1). $module" -ForegroundColor $(if ($module -in $enabledModules) { 'Green' } else { 'Gray' })
                    }

                    Write-Host "`nEnter module numbers to toggle (comma-separated), or 'all' to enable all:" -ForegroundColor Yellow
                    $moduleChoice = Read-Host "Selection"

                    if ($moduleChoice -eq 'all') {
                        $config.modules.enabled = $availableModules
                        Write-Host "✓ All modules enabled" -ForegroundColor Green
                    } elseif ($moduleChoice) {
                        $selections = $moduleChoice -split ',' | ForEach-Object { [int]$_.Trim() - 1 }
                        foreach ($idx in $selections) {
                            if ($idx -ge 0 -and $idx -lt $availableModules.Count) {
                                $module = $availableModules[$idx]
                                if ($module -in $enabledModules) {
                                    $config.modules.enabled = $config.modules.enabled | Where-Object { $_ -ne $module }
                                    Write-Host "✗ Disabled: $module" -ForegroundColor Yellow
                                } else {
                                    $config.modules.enabled += $module
                                    Write-Host "✓ Enabled: $module" -ForegroundColor Green
                                }
                            }
                        }
                    }
                }
                'S' {
                    try {
                        $config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath
                        Write-Host "`n✅ Configuration saved successfully!" -ForegroundColor Green
                        Start-Sleep -Seconds 2
                        $editing = $false
                    } catch {
                        Write-Host "❌ Error saving configuration: $_" -ForegroundColor Red
                        Read-Host "Press Enter to continue"
                    }
                }
                'Q' {
                    $currentJson = $config | ConvertTo-Json -Depth 10
                    if ($currentJson -ne $originalJson) {
                        $confirm = Read-Host "`nYou have unsaved changes. Quit anyway? (yes/no)"
                        if ($confirm -eq 'yes') {
                            $editing = $false
                        }
                    } else {
                        $editing = $false
                    }
                }
            }

            if ($editing) {
                Read-Host "`nPress Enter to continue"
            }
        }

        Write-CustomLog -Level 'SUCCESS' -Message "Configuration editor completed"

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Configuration editor failed: $($_.Exception.Message)"
        throw
    }
}

function Review-Configuration {
    <#
    .SYNOPSIS
        Configuration review step for setup wizard
    .DESCRIPTION
        Prompts user to review and optionally edit configuration during setup
        Uses ConfigurationCore for unified configuration management
    .PARAMETER SetupState
        Current setup state
    #>
    param($SetupState)

    try {
        $result = @{
            Name = 'Configuration Review'
            Status = 'Unknown'
            Details = @()
            Data = @{}
        }

        Write-Host "`n📋 Configuration Review" -ForegroundColor Cyan
        Write-Host "Let's review your AitherZero configuration settings." -ForegroundColor White
        Write-Host ""

        # Try to use ConfigurationCore first
        $usingConfigCore = $false
        try {
            $configCoreModule = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "ConfigurationCore"
            if (Test-Path $configCoreModule) {
                Import-Module $configCoreModule -Force -ErrorAction Stop
                $usingConfigCore = $true
                $result.Details += "✓ Using ConfigurationCore for configuration management"
            }
        } catch {
            Write-CustomLog -Level 'DEBUG' -Message "ConfigurationCore not available, using legacy method: $_"
        }

        if ($usingConfigCore) {
            # Use ConfigurationCore to get current configuration
            try {
                $setupConfig = Get-ModuleConfiguration -ModuleName 'SetupWizard' -ErrorAction SilentlyContinue

                if ($setupConfig) {
                    Write-Host "Current Configuration (via ConfigurationCore):" -ForegroundColor Yellow
                    Write-Host "  Platform: $($setupConfig.Platform)" -ForegroundColor White
                    Write-Host "  Installation Profile: $($setupConfig.InstallationProfile)" -ForegroundColor White

                    if ($setupConfig.Settings) {
                        Write-Host "  Settings:" -ForegroundColor White
                        Write-Host "    Verbosity: $($setupConfig.Settings.Verbosity)" -ForegroundColor Gray
                        Write-Host "    Auto Update: $($setupConfig.Settings.AutoUpdate)" -ForegroundColor Gray
                        Write-Host "    Max Parallel Jobs: $($setupConfig.Settings.MaxParallelJobs)" -ForegroundColor Gray
                    }

                    if ($setupConfig.Modules -and $setupConfig.Modules.EnabledByDefault) {
                        Write-Host "  Enabled Modules: $($setupConfig.Modules.EnabledByDefault.Count)" -ForegroundColor White
                        Write-Host "    $($setupConfig.Modules.EnabledByDefault -join ', ')" -ForegroundColor Gray
                    }

                    Write-Host ""

                    # Get current environment info
                    $currentEnv = Get-ConfigurationEnvironment
                    if ($currentEnv) {
                        Write-Host "  Current Environment: $($currentEnv.Name)" -ForegroundColor White
                        Write-Host "  Environment Description: $($currentEnv.Description)" -ForegroundColor Gray
                    }

                    Write-Host ""

                    # Ask if user wants to edit
                    $response = Show-SetupPrompt -Message "Would you like to edit the configuration now?" -DefaultYes:$false

                    if ($response) {
                        Write-Host ""
                        Write-Host "Opening enhanced configuration editor..." -ForegroundColor Yellow

                        # Use ConfigurationCore-aware Edit-Configuration function
                        if (Get-Command Edit-Configuration -ErrorAction SilentlyContinue) {
                            Edit-Configuration -UseConfigurationCore
                            $result.Details += "✓ Configuration reviewed and edited using ConfigurationCore"
                        } else {
                            Write-Host "Interactive configuration editing:" -ForegroundColor Cyan

                            # Simple interactive configuration update
                            $newVerbosity = Read-Host "Verbosity level (current: $($setupConfig.Settings.Verbosity)) [normal/verbose/quiet]"
                            if ($newVerbosity -and $newVerbosity -in @('normal', 'verbose', 'quiet')) {
                                $setupConfig.Settings.Verbosity = $newVerbosity
                            }

                            $newMaxJobs = Read-Host "Max parallel jobs (current: $($setupConfig.Settings.MaxParallelJobs)) [1-16]"
                            if ($newMaxJobs -and $newMaxJobs -match '\d+' -and [int]$newMaxJobs -ge 1 -and [int]$newMaxJobs -le 16) {
                                $setupConfig.Settings.MaxParallelJobs = [int]$newMaxJobs
                            }

                            Set-ModuleConfiguration -ModuleName 'SetupWizard' -Configuration $setupConfig
                            $result.Details += "✓ Configuration updated using ConfigurationCore"
                        }

                        # Validate configuration
                        try {
                            $isValid = Test-ModuleConfiguration -ModuleName 'SetupWizard'
                            if ($isValid) {
                                $result.Details += "✓ Configuration validated successfully"
                            } else {
                                $result.Details += "⚠️ Configuration validation warnings"
                            }
                        } catch {
                            $result.Details += "⚠️ Configuration validation failed: $_"
                            $SetupState.Warnings += "Configuration may have validation errors"
                        }
                    } else {
                        $result.Details += "✓ Configuration review skipped by user"
                    }

                } else {
                    Write-Host "No SetupWizard configuration found in ConfigurationCore." -ForegroundColor Yellow
                    $result.Details += "ℹ️ No existing configuration, will use defaults"
                }

            } catch {
                Write-Host "Error accessing ConfigurationCore: $_" -ForegroundColor Red
                $usingConfigCore = $false
            }
        }

        if (-not $usingConfigCore) {
            # Fallback to legacy configuration method
            $result.Details += "⚠️ Using legacy configuration method"

            # Find config file
            $configPath = $null
            $possiblePaths = @(
                (Join-Path $env:PROJECT_ROOT "configs/default-config.json"),
                (Join-Path (Find-ProjectRoot) "configs/default-config.json"),
                "./configs/default-config.json"
            )

            foreach ($path in $possiblePaths) {
                if (Test-Path $path) {
                    $configPath = $path
                    break
                }
            }

            if ($configPath) {
                # Read and display current configuration
                $config = Get-Content $configPath -Raw | ConvertFrom-Json

                Write-Host "Current Configuration (Legacy):" -ForegroundColor Yellow
                Write-Host "  Environment: $($config.environment ?? 'development')" -ForegroundColor White

                if ($config.modules -and $config.modules.enabled) {
                    Write-Host "  Enabled Modules: $($config.modules.enabled.Count)" -ForegroundColor White
                    Write-Host "    $($config.modules.enabled -join ', ')" -ForegroundColor Gray
                }

                if ($config.logging) {
                    Write-Host "  Logging Level: $($config.logging.level ?? 'INFO')" -ForegroundColor White
                }

                if ($config.infrastructure) {
                    Write-Host "  Infrastructure Provider: $($config.infrastructure.provider ?? 'opentofu')" -ForegroundColor White
                }

                Write-Host ""

                # Ask if user wants to edit
                $response = Show-SetupPrompt -Message "Would you like to edit the configuration now?" -DefaultYes:$false

                if ($response) {
                    Write-Host ""
                    Write-Host "Opening configuration editor..." -ForegroundColor Yellow

                    # Use the Edit-Configuration function
                    if (Get-Command Edit-Configuration -ErrorAction SilentlyContinue) {
                        Edit-Configuration -ConfigPath $configPath
                        $result.Details += "✓ Configuration reviewed and edited (legacy)"
                    } else {
                        # Fallback to simple external editor
                        if ($IsWindows) {
                            Start-Process notepad.exe -ArgumentList $configPath -Wait
                        } else {
                            $editor = $env:EDITOR ?? 'nano'
                            & $editor $configPath
                        }
                        $result.Details += "✓ Configuration edited in external editor"
                    }

                    # Reload and validate configuration
                    try {
                        $config = Get-Content $configPath -Raw | ConvertFrom-Json
                        $result.Details += "✓ Configuration validated successfully"
                    } catch {
                        $result.Details += "⚠️ Configuration validation failed: $_"
                        $SetupState.Warnings += "Configuration may have syntax errors"
                    }
                } else {
                    $result.Details += "✓ Configuration review skipped by user"
                }

            } else {
                # No config file exists yet
                Write-Host "No configuration file found. A default will be created." -ForegroundColor Yellow

                $response = Show-SetupPrompt -Message "Would you like to create and customize the configuration now?" -DefaultYes

                if ($response) {
                    # Create config directory
                    $configDir = Join-Path (Find-ProjectRoot) "configs"
                    if (-not (Test-Path $configDir)) {
                        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
                    }

                    # Use Edit-Configuration with CreateIfMissing
                    if (Get-Command Edit-Configuration -ErrorAction SilentlyContinue) {
                        Edit-Configuration -CreateIfMissing
                        $result.Details += "✓ Configuration created and customized"
                    } else {
                        # Create basic default config
                        $defaultConfig = @{
                            environment = "development"
                            modules = @{
                                enabled = @("LabRunner", "BackupManager", "OpenTofuProvider")
                                autoLoad = $true
                            }
                            logging = @{
                                level = "INFO"
                                path = "./logs"
                            }
                            infrastructure = @{
                                provider = "opentofu"
                                stateBackend = "local"
                            }
                        }

                        $configPath = Join-Path $configDir "default-config.json"
                        $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content $configPath
                        $result.Details += "✓ Default configuration created"
                    }
                } else {
                    $result.Details += "ℹ️ Configuration creation deferred"
                    $SetupState.Recommendations += "Run Edit-Configuration to customize settings later"
                }
            }
        }

        $result.Status = 'Success'

        # Add configuration tips
        Write-Host ""
        Write-Host "💡 Configuration Tips:" -ForegroundColor Cyan
        if ($usingConfigCore) {
            Write-Host "  • ConfigurationCore provides unified configuration management" -ForegroundColor White
            Write-Host "  • Use Get-ModuleConfiguration/Set-ModuleConfiguration for programmatic access" -ForegroundColor White
            Write-Host "  • Multiple environments supported (Get-ConfigurationEnvironment)" -ForegroundColor White
            Write-Host "  • Configuration schemas ensure validation and consistency" -ForegroundColor White
        } else {
            Write-Host "  • You can edit configuration anytime using Edit-Configuration" -ForegroundColor White
            Write-Host "  • Use -ConfigFile parameter to specify custom configs" -ForegroundColor White
            Write-Host "  • Consider upgrading to ConfigurationCore for better management" -ForegroundColor White
        }
        Write-Host "  • ConfigurationCarousel module enables multiple config profiles" -ForegroundColor White
        Write-Host ""

        Write-CustomLog -Level 'SUCCESS' -Message "Configuration review completed"
        return $result

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Configuration review failed: $($_.Exception.Message)"
        
        # Don't fail the entire setup just because of config review
        $result = @{
            Name = 'Configuration Review'
            Status = 'Success'
            Details = @("⚠️ Configuration review skipped due to error: $_", "✓ Configuration can be edited later using Edit-Configuration")
        }
        $SetupState.Warnings += "Configuration review encountered an error but setup can continue"
        return $result
    }
}

function Generate-QuickStartGuide {
    <#
    .SYNOPSIS
        Generate platform-specific quick start guide
    .DESCRIPTION
        Creates a quick start guide based on setup results
    .PARAMETER SetupState
        Current setup state
    #>
    param($SetupState)

    try {
        $result = @{
            Name = 'Quick Start Guide'
            Status = 'Unknown'
            Details = @()
        }

        # Generate platform-specific guide
        $guide = @"
# AitherZero Quick Start Guide
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')
Platform: $($SetupState.Platform.OS) $($SetupState.Platform.Version)

## 🚀 Getting Started

### 1. Basic Usage
``````powershell
# Interactive mode (recommended for beginners)
./Start-AitherZero.ps1

# Run specific module
./Start-AitherZero.ps1 -Scripts 'LabRunner'

# Automated mode
./Start-AitherZero.ps1 -Auto
``````

### 2. Common Tasks

#### Deploy Infrastructure
``````powershell
# Initialize OpenTofu provider
Import-Module ./aither-core/modules/OpenTofuProvider
Initialize-OpenTofuProvider

# Deploy a lab
New-LabInfrastructure -ConfigFile ./configs/lab-configs/dev-lab.json
``````

#### Manage Patches
``````powershell
# Create a patch with PR
Import-Module ./aither-core/modules/PatchManager
New-Feature -Description "Add new feature" -Changes {
    # Your changes here
}
``````

#### Backup Operations
``````powershell
# Run backup
Import-Module ./aither-core/modules/BackupManager
Start-Backup -SourcePath ./important-data -DestinationPath ./backups
``````

## 📋 Your Setup Summary

### ✅ What's Ready:
"@

        foreach ($step in $SetupState.Steps | Where-Object { $_.Status -eq 'Passed' }) {
            $guide += "`n- $($step.Name)"
        }

        if ($SetupState.Warnings.Count -gt 0) {
            $guide += "`n`n### ⚠️ Things to Consider:"
            foreach ($warning in $SetupState.Warnings) {
                $guide += "`n- $warning"
            }
        }

        if ($SetupState.Recommendations.Count -gt 0) {
            $guide += "`n`n### 💡 Recommendations:"
            foreach ($rec in $SetupState.Recommendations) {
                $guide += "`n- $rec"
            }
        }

        $guide += @"

## 🔗 Resources

- Documentation: ./docs/
- Examples: ./opentofu/examples/
- Module Help: Get-Help <ModuleName> -Full
- Issues: https://github.com/wizzense/AitherZero/issues

## 🎯 Next Steps

1. Review the generated configuration in:
   $(if ($SetupState.Platform.OS -eq 'Windows') { "$env:APPDATA\AitherZero" } else { "~/.config/aitherzero" })

2. Try the interactive menu:
   ./Start-AitherZero.ps1

3. Explore available modules:
   Get-Module -ListAvailable -Name *AitherZero*

Happy automating! 🚀
"@

        # Save guide
        try {
            $guidePath = "QuickStart-$($SetupState.Platform.OS)-$(Get-Date -Format 'yyyyMMdd').md"
            Set-Content -Path $guidePath -Value $guide
            $result.Details += "✓ Generated quick start guide: $guidePath"
            $result.Status = 'Passed'

            # Also display key info
            Write-Host ""
            Write-Host "  📖 Quick Start Commands:" -ForegroundColor Green
            Write-Host "     Interactive:  ./Start-AitherZero.ps1" -ForegroundColor White
            Write-Host "     Automated:    ./Start-AitherZero.ps1 -Auto" -ForegroundColor White
            Write-Host "     Get Help:     ./Start-AitherZero.ps1 -Help" -ForegroundColor White
        } catch {
            $result.Status = 'Warning'
            $result.Details += "⚠️ Could not save guide: $_"
        }

        Write-CustomLog -Level 'SUCCESS' -Message "Quick start guide generated"
        return $result

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Quick start guide generation failed: $($_.Exception.Message)"
        
        $result = @{
            Name = 'Quick Start Guide'
            Status = 'Warning'
            Details = @("⚠️ Could not generate quick start guide: $_")
        }
        return $result
    }
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Find-ProjectRoot {
    <#
    .SYNOPSIS
        Find the project root directory
    .DESCRIPTION
        Searches for the project root by looking for Start-AitherZero.ps1
    .PARAMETER StartPath
        Starting path for search
    #>
    param([string]$StartPath = $PWD.Path)

    try {
        $currentPath = $StartPath
        while ($currentPath -and $currentPath -ne (Split-Path $currentPath -Parent)) {
            if (Test-Path (Join-Path $currentPath "Start-AitherZero.ps1")) {
                return $currentPath
            }
            $currentPath = Split-Path $currentPath -Parent
        }

        # Fallback to current directory
        return $PWD.Path

    } catch {
        Write-CustomLog -Level 'WARNING' -Message "Could not find project root: $($_.Exception.Message)"
        return $PWD.Path
    }
}

# Provide fallback Test-FeatureAccess function if LicenseManager is not loaded
if (-not (Get-Command Test-FeatureAccess -ErrorAction SilentlyContinue)) {
    function Test-FeatureAccess {
        <#
        .SYNOPSIS
            Fallback function when LicenseManager is not available
        .DESCRIPTION
            Always returns true to allow all features when license management is not loaded
        .PARAMETER FeatureName
            Name of the feature to test
        .PARAMETER ModuleName
            Name of the module
        .PARAMETER ThrowOnDenied
            Whether to throw if denied
        #>
        param(
            [string]$FeatureName,
            [string]$ModuleName,
            [switch]$ThrowOnDenied
        )

        # Without license management, all features are accessible
        return $true
    }

    Write-CustomLog -Level 'DEBUG' -Message "Using fallback Test-FeatureAccess function"
}

# ============================================================================
# MODULE INITIALIZATION
# ============================================================================

# Initialize the experience domain
try {
    Write-CustomLog -Level 'INFO' -Message "Initializing Experience domain"
    
    # Initialize experience registry
    $script:ExperienceRegistry.Metadata.LastUpdated = Get-Date
    
    Write-CustomLog -Level 'SUCCESS' -Message "Experience domain initialized successfully"
    
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Failed to initialize Experience domain: $($_.Exception.Message)"
}

Write-CustomLog -Level 'SUCCESS' -Message "Experience domain loaded with unified setup wizard and startup experience functions"