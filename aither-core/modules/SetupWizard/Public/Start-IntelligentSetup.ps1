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
                # Test if we can use progress in current environment
                if (-not [System.Console]::IsInputRedirected -and $Host.UI.RawUI.WindowSize.Width -gt 0) {
                    $useProgress = $true
                }
            } catch {
                Write-Verbose "ProgressTracking module not available: $_"
            }
        }

        # Create progress operation if available (skip in non-interactive mode)
        $progressId = $null
        if ($useProgress -and (Get-Command Start-ProgressOperation -ErrorAction SilentlyContinue)) {
            try {
                $progressId = Start-ProgressOperation `
                    -OperationName "AitherZero Intelligent Setup" `
                    -TotalSteps $setupState.TotalSteps `
                    -ShowTime `
                    -ShowETA
            } catch {
                Write-Verbose "Progress tracking not available in current environment: $_"
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
            $maxAttempts = 2
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

        return $setupState

    } catch {
        Write-Error "Setup wizard failed: $_"
        return @{
            StartTime = Get-Date
            Status = 'Failed'
            Error = $_.Exception.Message
            InstallationProfile = $InstallationProfile
        }
    }
}

# Helper functions that might be missing - provide fallbacks

function Show-WelcomeMessage {
    param($SetupState)

    Write-Host ""
    Write-Host "Welcome to AitherZero Setup!" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Platform: $($SetupState.Platform.OS) $($SetupState.Platform.Version)" -ForegroundColor Yellow
    Write-Host "PowerShell: $($SetupState.Platform.PowerShell)" -ForegroundColor Yellow
    Write-Host "Installation Profile: $($SetupState.InstallationProfile)" -ForegroundColor Yellow
    Write-Host ""
}

function Show-SetupBanner {
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
    Write-Host "    ║                    Version 2.0                        ║" -ForegroundColor Cyan
    Write-Host "    ╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    Welcome! This wizard will help you set up AitherZero" -ForegroundColor White
    Write-Host "    for optimal performance on your system." -ForegroundColor White
    Write-Host ""
}

function Show-EnhancedInstallationProfile {
    param(
        [string]$Profile,
        [hashtable]$ProfileInfo
    )

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
    $requiredSteps = ($ProfileInfo.Steps | Where-Object { $_.Required -eq $true }).Count + 3  # Base required steps
    $optionalSteps = ($ProfileInfo.Steps | Where-Object { $_.Required -ne $true }).Count + 2  # Base optional steps

    Write-Host "    ✓ Required Steps: $requiredSteps" -ForegroundColor Green
    Write-Host "    ⚠️ Optional Steps: $optionalSteps" -ForegroundColor Yellow

    Write-Host ""
}

function Show-EnhancedProgress {
    param(
        [hashtable]$State,
        [string]$StepName,
        [string]$Status = 'Running',
        [hashtable]$ErrorContext = @{}
    )

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
}

function Show-SetupSummary {
    param($State)

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

    if ($State.Recommendations -and $State.Recommendations.Count -gt 0) {
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
}

function Invoke-ErrorRecovery {
    param(
        [Parameter(Mandatory)]
        [hashtable]$StepResult,
        [Parameter(Mandatory)]
        [hashtable]$SetupState,
        [string]$StepName
    )

    $recovery = @{
        Attempted = $false
        Success = $false
        Method = ''
        Details = @()
    }

    # Basic error recovery - in real implementation, add specific recovery strategies
    $recovery.Method = 'Generic Retry'
    $recovery.Details += "No specific recovery method available for: $StepName"
    $recovery.Attempted = $true
    $recovery.Success = $false

    return $recovery
}

Export-ModuleMember -Function Start-IntelligentSetup