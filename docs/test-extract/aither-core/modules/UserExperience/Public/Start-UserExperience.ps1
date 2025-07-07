function Start-UserExperience {
    <#
    .SYNOPSIS
        Main entry point for the unified AitherZero user experience
    .DESCRIPTION
        Provides the primary interface for users to interact with AitherZero.
        Automatically detects if this is a first-time setup or returning user,
        and provides the appropriate experience.
    .PARAMETER Mode
        Specify the experience mode: Auto, Setup, Interactive, Expert, or Minimal
    .PARAMETER Profile
        Load a specific user profile
    .PARAMETER SkipWelcome
        Skip the welcome screen and go directly to the main interface
    .PARAMETER Force
        Force a specific mode even if detection suggests otherwise
    .EXAMPLE
        Start-UserExperience
        # Automatically detects and provides appropriate experience
    .EXAMPLE
        Start-UserExperience -Mode Setup
        # Forces setup mode even for existing users
    .EXAMPLE
        Start-UserExperience -Mode Interactive -Profile "Development"
        # Starts interactive mode with development profile
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Auto', 'Setup', 'Interactive', 'Expert', 'Minimal', 'Tutorial')]
        [string]$Mode = 'Auto',
        
        [Parameter()]
        [string]$Profile,
        
        [Parameter()]
        [switch]$SkipWelcome,
        
        [Parameter()]
        [switch]$Force,
        
        [Parameter()]
        [hashtable]$Options = @{}
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting UserExperience with mode: $Mode" -Source 'UserExperience'
        
        # Initialize the user experience if not already done
        if (-not $script:UserExperienceState.Initialized) {
            Initialize-UserExperience
        }
        
        # Store session information
        $sessionInfo = @{
            StartTime = Get-Date
            Mode = $Mode
            Profile = $Profile
            SessionId = $script:UserExperienceState.SessionId
            UserAgent = "AitherZero-UserExperience/1.0.0"
        }
        
        # Save session info
        try {
            $sessionFile = Join-Path $script:UserConfigPaths.Sessions "$($sessionInfo.SessionId).json"
            $sessionInfo | ConvertTo-Json -Depth 3 | Set-Content -Path $sessionFile
        } catch {
            Write-Verbose "Could not save session information: $_"
        }
    }
    
    process {
        try {
            # Detect user experience state
            $userState = Get-UserExperienceState
            $isFirstTime = Test-FirstTimeUser
            $hasValidProfile = Test-UserProfileExists -ProfileName $Profile
            
            # Determine the appropriate mode if Auto is selected
            if ($Mode -eq 'Auto' -and -not $Force) {
                $Mode = Get-OptimalUserMode -IsFirstTime $isFirstTime -HasProfile $hasValidProfile -Options $Options
                Write-CustomLog -Level 'INFO' -Message "Auto-detected optimal mode: $Mode" -Source 'UserExperience'
            }
            
            # Show welcome screen unless skipped
            if (-not $SkipWelcome) {
                Show-WelcomeScreen -Mode $Mode -IsFirstTime $isFirstTime -Profile $Profile
            }
            
            # Initialize terminal UI for interactive modes
            if ($Mode -in @('Interactive', 'Expert', 'Tutorial')) {
                Initialize-TerminalUI -Theme 'Auto'
            }
            
            # Load user profile if specified
            if ($Profile -and $hasValidProfile) {
                try {
                    Set-UserProfile -Name $Profile
                    Write-CustomLog -Level 'INFO' -Message "Loaded user profile: $Profile" -Source 'UserExperience'
                } catch {
                    Write-Warning "Could not load profile '$Profile': $_"
                    Write-Host "Continuing with default settings..." -ForegroundColor Yellow
                }
            }
            
            # Execute the appropriate mode
            switch ($Mode) {
                'Setup' {
                    Write-CustomLog -Level 'INFO' -Message "Starting intelligent setup mode" -Source 'UserExperience'
                    $setupResult = Start-IntelligentSetup -InstallationProfile 'interactive'
                    
                    if ($setupResult -and $setupResult.TotalSteps -gt 0) {
                        $passedSteps = ($setupResult.Steps | Where-Object { $_.Status -eq 'Passed' }).Count
                        if ($passedSteps -ge 3) {
                            Write-Host "`n🎉 Setup completed successfully!" -ForegroundColor Green
                            Write-Host "AitherZero is ready to use. Starting interactive mode..." -ForegroundColor Cyan
                            Start-Sleep -Seconds 2
                            
                            # Transition to interactive mode after successful setup
                            Start-InteractiveMode -SkipLicenseCheck:$isFirstTime
                        } else {
                            Write-Host "`n⚠️ Setup completed with issues. Please review the recommendations above." -ForegroundColor Yellow
                            Show-PostSetupOptions -SetupResult $setupResult
                        }
                    }
                }
                
                'Interactive' {
                    Write-CustomLog -Level 'INFO' -Message "Starting interactive mode" -Source 'UserExperience'
                    Start-InteractiveMode -Profile $Profile
                }
                
                'Expert' {
                    Write-CustomLog -Level 'INFO' -Message "Starting expert mode" -Source 'UserExperience'
                    Start-ExpertMode -Profile $Profile -Options $Options
                }
                
                'Tutorial' {
                    Write-CustomLog -Level 'INFO' -Message "Starting tutorial mode" -Source 'UserExperience'
                    Start-TutorialMode -Profile $Profile
                }
                
                'Minimal' {
                    Write-CustomLog -Level 'INFO' -Message "Starting minimal mode" -Source 'UserExperience'
                    Start-MinimalMode -Options $Options
                }
                
                default {
                    Write-Error "Unknown mode: $Mode"
                    return
                }
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error in UserExperience: $_" -Source 'UserExperience'
            
            # Show user-friendly error message
            Write-Host "`n❌ An error occurred in the user experience system." -ForegroundColor Red
            Write-Host "Error: $_" -ForegroundColor Yellow
            Write-Host "`nYou can try:" -ForegroundColor White
            Write-Host "• Running: Start-UserExperience -Mode Minimal" -ForegroundColor Gray
            Write-Host "• Checking system requirements with: Test-SystemReadiness" -ForegroundColor Gray
            Write-Host "• Getting help with: Get-ContextualHelp -Topic 'Troubleshooting'" -ForegroundColor Gray
            
            # Offer fallback options
            $choice = Show-ConfirmationDialog -Message "Would you like to try starting in minimal mode?" -DefaultYes
            if ($choice) {
                try {
                    Start-MinimalMode -Options @{ ErrorRecovery = $true }
                } catch {
                    Write-Host "`n❌ Could not start minimal mode. Please check the troubleshooting guide." -ForegroundColor Red
                    throw
                }
            } else {
                throw
            }
        }
    }
    
    end {
        # Cleanup and logging
        try {
            $sessionEnd = Get-Date
            $sessionDuration = $sessionEnd - $sessionInfo.StartTime
            Write-CustomLog -Level 'INFO' -Message "UserExperience session completed. Duration: $($sessionDuration.ToString('hh\:mm\:ss'))" -Source 'UserExperience'
            
            # Update session file with end information
            $sessionInfo.EndTime = $sessionEnd
            $sessionInfo.Duration = $sessionDuration.TotalSeconds
            $sessionFile = Join-Path $script:UserConfigPaths.Sessions "$($sessionInfo.SessionId).json"
            $sessionInfo | ConvertTo-Json -Depth 3 | Set-Content -Path $sessionFile
            
        } catch {
            Write-Verbose "Could not update session information: $_"
        }
        
        # Reset terminal UI if it was initialized
        if ($Mode -in @('Interactive', 'Expert', 'Tutorial')) {
            try {
                Reset-TerminalUI
            } catch {
                Write-Verbose "Could not reset terminal UI: $_"
            }
        }
    }
}

function Get-OptimalUserMode {
    <#
    .SYNOPSIS
        Determines the optimal user experience mode based on user state
    #>
    param(
        [bool]$IsFirstTime,
        [bool]$HasProfile,
        [hashtable]$Options = @{}
    )
    
    # First-time users get setup mode
    if ($IsFirstTime) {
        return 'Setup'
    }
    
    # Check if user has expressed preference
    $userPrefs = Get-UserPreferences -ErrorAction SilentlyContinue
    if ($userPrefs -and $userPrefs.DefaultMode) {
        return $userPrefs.DefaultMode
    }
    
    # Check system capabilities
    $capabilities = Get-TerminalCapabilities
    if (-not $capabilities.SupportsEnhancedUI) {
        return 'Minimal'
    }
    
    # Check for expert mode indicators
    $expertIndicators = @(
        ($Options.ContainsKey('Advanced') -and $Options.Advanced),
        (Test-Path (Join-Path $script:UserConfigPaths.UserProfile 'expert-mode')),
        ($userPrefs -and $userPrefs.ExpertMode)
    )
    
    if ($expertIndicators -contains $true) {
        return 'Expert'
    }
    
    # Default to interactive mode for regular users
    return 'Interactive'
}

function Test-FirstTimeUser {
    <#
    .SYNOPSIS
        Determines if this is a first-time user
    #>
    
    # Check for existence of user configuration
    $configExists = Test-Path $script:UserConfigPaths.Preferences
    $profilesExist = (Get-ChildItem $script:UserConfigPaths.Profiles -ErrorAction SilentlyContinue).Count -gt 0
    $setupComplete = Test-Path (Join-Path $script:UserConfigPaths.UserProfile 'setup-complete')
    
    return -not ($configExists -or $profilesExist -or $setupComplete)
}

function Show-PostSetupOptions {
    <#
    .SYNOPSIS
        Shows options to user after setup completion
    #>
    param([hashtable]$SetupResult)
    
    Write-Host "`n📋 Post-Setup Options:" -ForegroundColor Cyan
    Write-Host "1. Continue to Interactive Mode" -ForegroundColor White
    Write-Host "2. Review Setup Results" -ForegroundColor White  
    Write-Host "3. Run Additional Setup Steps" -ForegroundColor White
    Write-Host "4. Exit and Configure Manually" -ForegroundColor White
    Write-Host ""
    
    $choice = Read-Host "Enter your choice (1-4)"
    
    switch ($choice) {
        '1' {
            Start-InteractiveMode -SkipLicenseCheck
        }
        '2' {
            Review-Configuration -SetupResult $SetupResult
        }
        '3' {
            Start-ConfigurationWizard -Mode 'Additional'
        }
        '4' {
            Write-Host "You can run './Start-AitherZero.ps1' anytime to continue." -ForegroundColor Green
        }
        default {
            Write-Host "Invalid choice. Starting Interactive Mode..." -ForegroundColor Yellow
            Start-InteractiveMode -SkipLicenseCheck
        }
    }
}