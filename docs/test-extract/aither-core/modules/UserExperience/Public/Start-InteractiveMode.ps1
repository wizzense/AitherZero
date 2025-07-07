function Start-InteractiveMode {
    <#
    .SYNOPSIS
        Starts the unified interactive management interface for AitherZero
    .DESCRIPTION
        Launches the main interactive menu system combining the best features
        from both SetupWizard and StartupExperience modules with enhanced
        user experience and comprehensive functionality
    .PARAMETER Profile
        Configuration profile to load
    .PARAMETER SkipLicenseCheck
        Skip license validation (for testing)
    .PARAMETER Theme
        UI theme to use (Auto, Dark, Light, HighContrast)
    .PARAMETER ExpertMode
        Start in expert mode with advanced features
    .EXAMPLE
        Start-InteractiveMode
        # Start with default settings
    .EXAMPLE
        Start-InteractiveMode -Profile "Development" -Theme Dark
        # Start with specific profile and theme
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Profile,
        
        [Parameter()]
        [switch]$SkipLicenseCheck,
        
        [Parameter()]
        [ValidateSet('Auto', 'Dark', 'Light', 'HighContrast')]
        [string]$Theme = 'Auto',
        
        [Parameter()]
        [switch]$ExpertMode
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting Interactive Mode" -Source 'UserExperience'
        
        # Initialize user experience if not already done
        if (-not $script:UserExperienceState.Initialized) {
            Initialize-UserExperience
        }
        
        # Store session context
        $sessionContext = @{
            StartTime = Get-Date
            Mode = 'Interactive'
            Profile = $Profile
            Theme = $Theme
            ExpertMode = $ExpertMode
            SessionId = [System.Guid]::NewGuid().ToString()
        }
    }
    
    process {
        try {
            # Check license status unless skipped
            $licenseInfo = Get-LicenseInformation -SkipCheck:$SkipLicenseCheck
            $availableTier = $licenseInfo.Tier
            
            # Load configuration profile if specified
            if ($Profile) {
                try {
                    $profileData = Get-UserProfile -Name $Profile
                    if ($profileData) {
                        Set-UserProfile -Name $Profile -Quiet
                        Write-CustomLog -Level 'INFO' -Message "Loaded profile: $Profile" -Source 'UserExperience'
                        
                        # Apply profile-specific settings
                        if ($profileData.Settings.Theme -and -not $PSBoundParameters.ContainsKey('Theme')) {
                            $Theme = $profileData.Settings.Theme
                        }
                        if ($profileData.Settings.ExpertMode -and -not $ExpertMode) {
                            $ExpertMode = $profileData.Settings.ExpertMode
                        }
                    }
                } catch {
                    Write-Warning "Could not load profile '$Profile': $_"
                    Write-Host "Continuing with default configuration..." -ForegroundColor Yellow
                }
            }
            
            # Initialize terminal UI with specified theme
            $uiResult = Initialize-TerminalUI -Theme $Theme
            if (-not $uiResult.Success) {
                Write-Warning "Enhanced UI not available, using fallback mode"
            }
            
            # Determine available features based on license and expert mode
            $features = Get-AvailableFeatures -Tier $availableTier -ExpertMode:$ExpertMode
            
            # Main interactive loop
            $exitRequested = $false
            $lastMenuRefresh = Get-Date
            
            while (-not $exitRequested) {
                try {
                    # Refresh screen
                    Clear-Host
                    
                    # Show header with system information
                    Show-InteractiveHeader -LicenseInfo $licenseInfo -Profile $Profile -ExpertMode:$ExpertMode
                    
                    # Show system status if available
                    Show-SystemStatus -Compact
                    
                    # Get current menu options based on context
                    $menuOptions = Get-InteractiveMenuOptions -Features $features -ExpertMode:$ExpertMode -LicenseTier $availableTier
                    
                    # Show main menu
                    $selectedOption = Show-ContextMenu -Title "Main Menu" -Options $menuOptions -ShowHelp -ReturnAction
                    
                    # Handle menu selection
                    $actionResult = Invoke-MenuAction -Action $selectedOption -Context $sessionContext -Features $features
                    
                    # Handle special actions
                    switch ($actionResult.Action) {
                        'Exit' { 
                            $exitRequested = $true 
                        }
                        'Refresh' { 
                            $lastMenuRefresh = Get-Date 
                        }
                        'ChangeProfile' {
                            $Profile = $actionResult.NewProfile
                            $sessionContext.Profile = $Profile
                        }
                        'ToggleExpert' {
                            $ExpertMode = -not $ExpertMode
                            $sessionContext.ExpertMode = $ExpertMode
                            $features = Get-AvailableFeatures -Tier $availableTier -ExpertMode:$ExpertMode
                        }
                    }
                    
                    # Auto-refresh menu if it's been a while
                    if ((Get-Date) - $lastMenuRefresh -gt [TimeSpan]::FromMinutes(5)) {
                        $lastMenuRefresh = Get-Date
                        Write-Verbose "Auto-refreshing menu options"
                    }
                    
                } catch {
                    Write-CustomLog -Level 'ERROR' -Message "Error in interactive loop: $_" -Source 'UserExperience'
                    
                    # Show error to user with recovery options
                    Show-InteractiveError -Error $_ -SessionContext $sessionContext
                    
                    # Offer recovery options
                    $recovery = Show-ErrorRecoveryMenu -Error $_
                    if ($recovery -eq 'Exit') {
                        $exitRequested = $true
                    }
                }
            }
            
            # Show exit message
            Show-ExitMessage -SessionContext $sessionContext
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Critical error in Interactive Mode: $_" -Source 'UserExperience'
            
            # Show critical error message
            Write-Host "`n❌ Critical Error in Interactive Mode" -ForegroundColor Red
            Write-Host "Error: $_" -ForegroundColor Yellow
            Write-Host "`nTrying fallback mode..." -ForegroundColor White
            
            # Try to start minimal fallback mode
            try {
                Start-FallbackInteractiveMode -Error $_
            } catch {
                Write-Host "❌ Fallback mode also failed. Exiting..." -ForegroundColor Red
                throw
            }
        }
    }
    
    end {
        # Cleanup and logging
        try {
            $sessionDuration = (Get-Date) - $sessionContext.StartTime
            Write-CustomLog -Level 'INFO' -Message "Interactive Mode session completed. Duration: $($sessionDuration.ToString('hh\:mm\:ss'))" -Source 'UserExperience'
            
            # Reset terminal UI
            Reset-TerminalUI
            
            # Save session information for analytics
            Save-SessionAnalytics -Context $sessionContext -Duration $sessionDuration
            
        } catch {
            Write-Verbose "Error in Interactive Mode cleanup: $_"
        }
    }
}

function Get-LicenseInformation {
    <#
    .SYNOPSIS
        Gets license information with fallback handling
    #>
    param([switch]$SkipCheck)
    
    if ($SkipCheck) {
        return @{
            Tier = 'enterprise'
            Status = 'Active'
            Features = @('core', 'setup', 'interactive', 'expert', 'enterprise')
            Skipped = $true
        }
    }
    
    try {
        if (Get-Command Get-LicenseStatus -ErrorAction SilentlyContinue) {
            $licenseStatus = Get-LicenseStatus
            return @{
                Tier = $licenseStatus.Tier ?? 'free'
                Status = $licenseStatus.Status ?? 'Active'
                Features = $licenseStatus.Features ?? @('core', 'setup', 'interactive')
                Skipped = $false
            }
        }
    } catch {
        Write-Verbose "Could not get license status: $_"
    }
    
    # Fallback to free tier
    return @{
        Tier = 'free'
        Status = 'Active'
        Features = @('core', 'setup', 'interactive')
        Skipped = $false
    }
}

function Get-AvailableFeatures {
    <#
    .SYNOPSIS
        Determines available features based on license tier and mode
    #>
    param(
        [string]$Tier = 'free',
        [switch]$ExpertMode
    )
    
    $baseFeatures = @(
        'ConfigurationManager',
        'ModuleExplorer', 
        'ProfileManager',
        'Help'
    )
    
    $tierFeatures = switch ($Tier.ToLower()) {
        'pro' {
            $baseFeatures + @('AdvancedConfiguration', 'Performance', 'Analytics')
        }
        'enterprise' {
            $baseFeatures + @('AdvancedConfiguration', 'Performance', 'Analytics', 'Security', 'Compliance', 'API')
        }
        default {
            $baseFeatures
        }
    }
    
    if ($ExpertMode) {
        $tierFeatures += @('DebugTools', 'SystemInternals', 'ModuleDevelopment', 'AdvancedScripting')
    }
    
    return $tierFeatures
}

function Show-InteractiveHeader {
    <#
    .SYNOPSIS
        Shows the interactive mode header with system information
    #>
    param(
        [hashtable]$LicenseInfo,
        [string]$Profile,
        [switch]$ExpertMode
    )
    
    $version = "1.0.0"
    $tierDisplay = switch ($LicenseInfo.Tier) {
        'pro' { " [PRO]" }
        'enterprise' { " [ENTERPRISE]" }
        default { "" }
    }
    
    $expertDisplay = if ($ExpertMode) { " [EXPERT]" } else { "" }
    $profileDisplay = if ($Profile) { " | Profile: $Profile" } else { "" }
    
    Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║                  AitherZero v$version$tierDisplay$expertDisplay                  ║
║          Interactive Management Interface                    ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
    
    # Show context information
    if ($profileDisplay -or $LicenseInfo.Skipped) {
        $contextInfo = ""
        if ($profileDisplay) { $contextInfo += $profileDisplay }
        if ($LicenseInfo.Skipped) { $contextInfo += " | License: Skipped" }
        
        Write-Host "Context:$contextInfo" -ForegroundColor Gray
    }
    
    Write-Host ""
}

function Show-SystemStatus {
    <#
    .SYNOPSIS
        Shows compact system status information
    #>
    param([switch]$Compact)
    
    try {
        $systemInfo = $script:UserExperienceState.SystemInfo ?? (Get-SystemInfo)
        $moduleCount = (Get-Module -ListAvailable | Where-Object { $_.Name -like "*AitherZero*" -or $_.ModuleBase -like "*aither-core*" }).Count
        
        if ($Compact) {
            Write-Host "  📊 System: $($systemInfo.OS) | Modules: $moduleCount | PowerShell: $($systemInfo.PowerShellVersion)" -ForegroundColor Gray
        } else {
            Write-Host "  📊 System Status:" -ForegroundColor Yellow
            Write-Host "     OS: $($systemInfo.OS) $($systemInfo.Architecture)" -ForegroundColor White
            Write-Host "     PowerShell: $($systemInfo.PowerShellVersion) ($($systemInfo.PowerShellEdition))" -ForegroundColor White
            Write-Host "     Available Modules: $moduleCount" -ForegroundColor White
            Write-Host "     Execution Policy: $($systemInfo.ExecutionPolicy)" -ForegroundColor White
        }
        Write-Host ""
    } catch {
        Write-Verbose "Could not show system status: $_"
    }
}

function Get-InteractiveMenuOptions {
    <#
    .SYNOPSIS
        Gets menu options based on available features and context
    #>
    param(
        [array]$Features,
        [switch]$ExpertMode,
        [string]$LicenseTier
    )
    
    $menuOptions = @()
    
    # Core options available to all tiers
    if ('ConfigurationManager' -in $Features) {
        $menuOptions += @{
            Text = "Configuration Manager"
            Action = "ConfigManager"
            Description = "Manage AitherZero configuration and settings"
            Icon = "⚙️"
            Tier = "free"
            Category = "Core"
        }
    }
    
    if ('ModuleExplorer' -in $Features) {
        $menuOptions += @{
            Text = "Module Explorer"
            Action = "ModuleExplorer"
            Description = "Discover and manage AitherZero modules"
            Icon = "🔍"
            Tier = "free"
            Category = "Core"
        }
    }
    
    if ('ProfileManager' -in $Features) {
        $menuOptions += @{
            Text = "Profile Management"
            Action = "ProfileManager"
            Description = "Create and manage user profiles"
            Icon = "👤"
            Tier = "free"
            Category = "Core"
        }
    }
    
    # Infrastructure and automation
    $menuOptions += @{
        Text = "Run Infrastructure Tasks"
        Action = "InfrastructureTasks"
        Description = "Execute infrastructure automation tasks"
        Icon = "🏗️"
        Tier = "free"
        Category = "Infrastructure"
    }
    
    $menuOptions += @{
        Text = "Script Runner"
        Action = "ScriptRunner"
        Description = "Execute scripts and automation workflows"
        Icon = "📜"
        Tier = "free"
        Category = "Infrastructure"
    }
    
    # Advanced features for higher tiers
    if ('Performance' -in $Features) {
        $menuOptions += @{
            Text = "Performance Monitor"
            Action = "PerformanceMonitor"
            Description = "Monitor system and application performance"
            Icon = "📊"
            Tier = "pro"
            Category = "Advanced"
        }
    }
    
    if ('Analytics' -in $Features) {
        $menuOptions += @{
            Text = "Usage Analytics"
            Action = "Analytics"
            Description = "View usage analytics and insights"
            Icon = "📈"
            Tier = "pro"
            Category = "Advanced"
        }
    }
    
    if ('Security' -in $Features) {
        $menuOptions += @{
            Text = "Security Center"
            Action = "SecurityCenter"
            Description = "Manage security settings and compliance"
            Icon = "🛡️"
            Tier = "enterprise"
            Category = "Enterprise"
        }
    }
    
    # Expert mode features
    if ($ExpertMode) {
        if ('DebugTools' -in $Features) {
            $menuOptions += @{
                Text = "Debug Tools"
                Action = "DebugTools"
                Description = "Advanced debugging and diagnostic tools"
                Icon = "🔧"
                Tier = "free"
                Category = "Expert"
                ExpertOnly = $true
            }
        }
        
        if ('SystemInternals' -in $Features) {
            $menuOptions += @{
                Text = "System Internals"
                Action = "SystemInternals"
                Description = "Low-level system information and controls"
                Icon = "⚡"
                Tier = "free"
                Category = "Expert"
                ExpertOnly = $true
            }
        }
        
        if ('ModuleDevelopment' -in $Features) {
            $menuOptions += @{
                Text = "Module Development"
                Action = "ModuleDevelopment"
                Description = "Tools for developing AitherZero modules"
                Icon = "🛠️"
                Tier = "free"
                Category = "Expert"
                ExpertOnly = $true
            }
        }
    }
    
    # Always available options
    if ('Help' -in $Features) {
        $menuOptions += @{
            Text = "Help & Documentation"
            Action = "Help"
            Description = "Access help, tutorials, and documentation"
            Icon = "❓"
            Tier = "free"
            Category = "Support"
        }
    }
    
    # System options
    $menuOptions += @{
        Text = "Settings"
        Action = "Settings"
        Description = "Application settings and preferences"
        Icon = "⚙️"
        Tier = "free"
        Category = "System"
    }
    
    if ($ExpertMode) {
        $menuOptions += @{
            Text = "Exit Expert Mode"
            Action = "ToggleExpert"
            Description = "Switch back to standard mode"
            Icon = "👤"
            Tier = "free"
            Category = "System"
        }
    } else {
        $menuOptions += @{
            Text = "Expert Mode"
            Action = "ToggleExpert"
            Description = "Enable expert mode with advanced features"
            Icon = "🚀"
            Tier = "free"
            Category = "System"
        }
    }
    
    $menuOptions += @{
        Text = "Exit"
        Action = "Exit"
        Description = "Exit interactive mode"
        Icon = "🚪"
        Tier = "free"
        Category = "System"
    }
    
    # Filter by tier access
    return $menuOptions | Where-Object { 
        Test-TierAccess -RequiredTier $_.Tier -CurrentTier $LicenseTier
    }
}

function Invoke-MenuAction {
    <#
    .SYNOPSIS
        Invokes the selected menu action
    #>
    param(
        [string]$Action,
        [hashtable]$Context,
        [array]$Features
    )
    
    $result = @{ Action = $Action }
    
    try {
        switch ($Action) {
            'ConfigManager' {
                Show-ConfigurationManager -Context $Context
            }
            'ModuleExplorer' {
                Show-ModuleExplorer -Context $Context
            }
            'ProfileManager' {
                $newProfile = Show-ProfileManager -Context $Context
                if ($newProfile) {
                    $result.Action = 'ChangeProfile'
                    $result.NewProfile = $newProfile
                }
            }
            'InfrastructureTasks' {
                Start-InfrastructureTaskRunner -Context $Context
            }
            'ScriptRunner' {
                Start-ScriptRunner -Context $Context
            }
            'PerformanceMonitor' {
                Show-PerformanceMonitor -Context $Context
            }
            'Analytics' {
                Show-UsageAnalytics -Context $Context
            }
            'SecurityCenter' {
                Show-SecurityCenter -Context $Context
            }
            'DebugTools' {
                Show-DebugTools -Context $Context
            }
            'SystemInternals' {
                Show-SystemInternals -Context $Context
            }
            'ModuleDevelopment' {
                Start-ModuleDevelopmentTools -Context $Context
            }
            'Help' {
                Show-HelpSystem -Context $Context
            }
            'Settings' {
                Show-SettingsManager -Context $Context
            }
            'ToggleExpert' {
                $result.Action = 'ToggleExpert'
            }
            'Exit' {
                $result.Action = 'Exit'
            }
            default {
                Write-Warning "Unknown action: $Action"
                Read-Host "Press Enter to continue"
            }
        }
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Error executing action '$Action': $_" -Source 'UserExperience'
        Show-ActionError -Action $Action -Error $_ -Context $Context
    }
    
    return $result
}

function Show-ExitMessage {
    <#
    .SYNOPSIS
        Shows exit message with session summary
    #>
    param([hashtable]$SessionContext)
    
    $duration = (Get-Date) - $SessionContext.StartTime
    
    Write-Host "`n" -NoNewline
    Write-Host "Thank you for using AitherZero Interactive Mode!" -ForegroundColor Green
    Write-Host "Session duration: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Gray
    
    if ($SessionContext.Profile) {
        Write-Host "Profile used: $($SessionContext.Profile)" -ForegroundColor Gray
    }
    
    Write-Host "`nTo restart: " -NoNewline -ForegroundColor White
    Write-Host "Start-UserExperience -Mode Interactive" -ForegroundColor Cyan
    Write-Host ""
}

function Test-TierAccess {
    <#
    .SYNOPSIS
        Tests if current tier has access to required tier
    #>
    param(
        [string]$RequiredTier,
        [string]$CurrentTier
    )
    
    $tierLevels = @{
        'free' = 1
        'pro' = 2
        'professional' = 2
        'enterprise' = 3
    }
    
    $requiredLevel = $tierLevels[$RequiredTier.ToLower()] ?? 1
    $currentLevel = $tierLevels[$CurrentTier.ToLower()] ?? 1
    
    return $currentLevel -ge $requiredLevel
}