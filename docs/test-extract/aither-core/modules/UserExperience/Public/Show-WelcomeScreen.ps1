function Show-WelcomeScreen {
    <#
    .SYNOPSIS
        Displays the unified welcome screen for AitherZero
    .DESCRIPTION
        Shows a comprehensive welcome screen that adapts based on user state,
        system capabilities, and selected mode
    .PARAMETER Mode
        The mode that will be started after the welcome screen
    .PARAMETER IsFirstTime
        Whether this is a first-time user
    .PARAMETER Profile
        User profile being loaded
    .PARAMETER ShowSystemInfo
        Show detailed system information
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Mode = 'Interactive',
        
        [Parameter()]
        [bool]$IsFirstTime = $false,
        
        [Parameter()]
        [string]$Profile,
        
        [Parameter()]
        [switch]$ShowSystemInfo,
        
        [Parameter()]
        [switch]$SkipAnimation
    )
    
    try {
        # Clear screen for welcome display
        if (-not [System.Console]::IsInputRedirected) {
            try {
                Clear-Host
            } catch {
                # Ignore clear errors in restricted environments
            }
        }
        
        # Get system information for display
        $systemInfo = $script:UserExperienceState.SystemInfo ?? (Get-SystemInfo)
        $capabilities = $script:UserExperienceState.UICapabilities ?? (Get-TerminalCapabilities)
        $userPrefs = $script:UserExperienceState.UserPreferences
        
        # Determine if user preferences allow welcome screen
        if ($userPrefs -and -not $userPrefs.UI.ShowWelcome) {
            Write-Verbose "Welcome screen disabled by user preferences"
            return
        }
        
        # Show main banner
        Show-WelcomeBanner -Mode $Mode -Capabilities $capabilities -SkipAnimation:$SkipAnimation
        
        # Show mode-specific welcome message
        Show-ModeWelcomeMessage -Mode $Mode -IsFirstTime $IsFirstTime -Profile $Profile
        
        # Show system information if requested or first time
        if ($ShowSystemInfo -or $IsFirstTime) {
            Show-SystemInformation -SystemInfo $systemInfo -Compact:(-not $IsFirstTime)
        }
        
        # Show quick start information based on mode
        Show-QuickStartInfo -Mode $Mode -IsFirstTime $IsFirstTime
        
        # Show profile information if applicable
        if ($Profile) {
            Show-ProfileInformation -ProfileName $Profile
        }
        
        # Show tips and recommendations
        if ($userPrefs.UI.ShowTips -ne $false) {
            Show-WelcomeTips -Mode $Mode -IsFirstTime $IsFirstTime -Capabilities $capabilities
        }
        
        # Interactive pause unless in minimal mode
        if ($Mode -ne 'Minimal' -and -not [System.Console]::IsInputRedirected) {
            Show-WelcomeContinuePrompt -Mode $Mode
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Error displaying welcome screen: $_" -Source 'UserExperience'
        # Show minimal welcome on error
        Show-MinimalWelcome -Mode $Mode
    }
}

function Show-WelcomeBanner {
    <#
    .SYNOPSIS
        Shows the main AitherZero welcome banner
    #>
    param(
        [string]$Mode,
        [hashtable]$Capabilities,
        [switch]$SkipAnimation
    )
    
    $version = "1.0.0"
    $buildDate = "2025-07-07"
    
    # Determine banner style based on capabilities
    if ($Capabilities.SupportsEnhancedUI -and $Capabilities.Width -gt 80) {
        Show-EnhancedBanner -Version $version -BuildDate $buildDate -SkipAnimation:$SkipAnimation
    } else {
        Show-CompactBanner -Version $version -BuildDate $buildDate
    }
}

function Show-EnhancedBanner {
    param([string]$Version, [string]$BuildDate, [switch]$SkipAnimation)
    
    $bannerLines = @(
        "╔═══════════════════════════════════════════════════════════════════════════════╗",
        "║                                                                               ║",
        "║      ▄▄▄       ██▓▄▄▄█████▓ ██░ ██ ▓█████  ██▀███  ▒███████▒▓█████  ██▀███  ▒█████  ",
        "║     ▒████▄    ▓██▒▓  ██▒ ▓▒▓██░ ██▒▓█   ▀ ▓██ ▒ ██▒▒ ▒ ▒ ▄▀░▓█   ▀ ▓██ ▒ ██▒▒██▒  ██▒",
        "║     ▒██  ▀█▄  ▒██▒▒ ▓██░ ▒░▒██▀▀██░▒███   ▓██ ░▄█ ▒░ ▒ ▄▀▒░ ▒███   ▓██ ░▄█ ▒▒██░  ██▒",
        "║     ░██▄▄▄▄██ ░██░░ ▓██▓ ░ ░▓█ ░██ ▒▓█  ▄ ▒██▀▀█▄    ▄▀▒   ░▒▓█  ▄ ▒██▀▀█▄  ▒██   ██░",
        "║      ▓█   ▓██▒░██░  ▒██▒ ░ ░▓█▒░██▓░▒████▒░██▓ ▒██▒▒███████▒░▒████▒░██▓ ▒██▒░ ████▓▒░",
        "║      ▒▒   ▓▒█░░▓    ▒ ░░    ▒ ░░▒░▒░░ ▒░ ░░ ▒▓ ░▒▓░░▒▒ ▓░▒░▒░░ ▒░ ░░ ▒▓ ░▒▓░░ ▒░▒░▒░ ",
        "║       ▒   ▒▒ ░ ▒ ░    ░     ▒ ░▒░ ░ ░ ░  ░  ░▒ ░ ▒░░░▒ ▒ ░ ▒ ░ ░  ░  ░▒ ░ ▒░  ░ ▒ ▒░ ",
        "║       ░   ▒    ▒ ░  ░       ░  ░░ ░   ░     ░░   ░ ░ ░ ░ ░ ░   ░     ░░   ░ ░ ░ ░ ▒  ",
        "║           ░  ░ ░            ░  ░  ░   ░  ░   ░       ░ ░       ░  ░   ░         ░ ░  ",
        "║                                              ░                                        ║",
        "║                    Infrastructure Automation Platform v$Version                      ║",
        "║                             Build Date: $BuildDate                             ║",
        "║                                                                               ║",
        "╚═══════════════════════════════════════════════════════════════════════════════╝"
    )
    
    # Animation effect
    if (-not $SkipAnimation -and -not [System.Console]::IsInputRedirected) {
        foreach ($line in $bannerLines) {
            Write-Host $line -ForegroundColor Cyan
            Start-Sleep -Milliseconds 50
        }
    } else {
        $bannerLines | ForEach-Object { Write-Host $_ -ForegroundColor Cyan }
    }
}

function Show-CompactBanner {
    param([string]$Version, [string]$BuildDate)
    
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║              AitherZero v$Version                       ║" -ForegroundColor Cyan
    Write-Host "  ║         Infrastructure Automation Platform           ║" -ForegroundColor Cyan
    Write-Host "  ║               Build: $BuildDate                ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Show-ModeWelcomeMessage {
    param([string]$Mode, [bool]$IsFirstTime, [string]$Profile)
    
    Write-Host ""
    
    switch ($Mode) {
        'Setup' {
            if ($IsFirstTime) {
                Write-Host "  🎉 Welcome to AitherZero!" -ForegroundColor Green
                Write-Host "  This is your first time running AitherZero. We'll guide you through" -ForegroundColor White
                Write-Host "  the setup process to get everything configured for your environment." -ForegroundColor White
            } else {
                Write-Host "  🔧 Setup Mode" -ForegroundColor Yellow
                Write-Host "  Running setup wizard to configure or reconfigure your environment." -ForegroundColor White
            }
        }
        'Interactive' {
            Write-Host "  🎮 Interactive Mode" -ForegroundColor Blue
            Write-Host "  Welcome to the interactive management interface." -ForegroundColor White
            if ($Profile) {
                Write-Host "  Using profile: $Profile" -ForegroundColor Gray
            }
        }
        'Expert' {
            Write-Host "  🚀 Expert Mode" -ForegroundColor Magenta
            Write-Host "  Advanced interface with full feature access." -ForegroundColor White
        }
        'Tutorial' {
            Write-Host "  📚 Tutorial Mode" -ForegroundColor Green
            Write-Host "  Learn AitherZero with guided interactive tutorials." -ForegroundColor White
        }
        'Minimal' {
            Write-Host "  ⚡ Minimal Mode" -ForegroundColor Gray
            Write-Host "  Lightweight interface for quick operations." -ForegroundColor White
        }
        default {
            Write-Host "  ✨ AitherZero Ready" -ForegroundColor Cyan
            Write-Host "  Your infrastructure automation platform is ready to use." -ForegroundColor White
        }
    }
    Write-Host ""
}

function Show-SystemInformation {
    param([hashtable]$SystemInfo, [switch]$Compact)
    
    if ($Compact) {
        Write-Host "  📋 System: $($SystemInfo.OS) | PowerShell: $($SystemInfo.PowerShellVersion) | Arch: $($SystemInfo.Architecture)" -ForegroundColor Gray
    } else {
        Write-Host "  📋 System Information:" -ForegroundColor Yellow
        Write-Host "     Operating System: $($SystemInfo.OS)" -ForegroundColor White
        Write-Host "     PowerShell: $($SystemInfo.PowerShellVersion) ($($SystemInfo.PowerShellEdition))" -ForegroundColor White
        Write-Host "     Architecture: $($SystemInfo.Architecture)" -ForegroundColor White
        Write-Host "     User: $($SystemInfo.UserName)@$($SystemInfo.MachineName)" -ForegroundColor White
        if ($SystemInfo.TotalMemory -ne 'Unknown') {
            Write-Host "     Memory: $($SystemInfo.TotalMemory) GB" -ForegroundColor White
        }
    }
    Write-Host ""
}

function Show-QuickStartInfo {
    param([string]$Mode, [bool]$IsFirstTime)
    
    Write-Host "  🚀 Quick Start:" -ForegroundColor Green
    
    switch ($Mode) {
        'Setup' {
            Write-Host "     • Follow the guided setup process" -ForegroundColor White
            Write-Host "     • Configure your environment and preferences" -ForegroundColor White
            Write-Host "     • Install required dependencies" -ForegroundColor White
        }
        'Interactive' {
            Write-Host "     • Navigate with arrow keys or number selection" -ForegroundColor White
            Write-Host "     • Access modules from the main menu" -ForegroundColor White
            Write-Host "     • Use 'Exit' to return to command line" -ForegroundColor White
        }
        'Expert' {
            Write-Host "     • All features and modules are available" -ForegroundColor White
            Write-Host "     • Advanced configuration options unlocked" -ForegroundColor White
            Write-Host "     • Direct access to debug and admin tools" -ForegroundColor White
        }
        'Tutorial' {
            Write-Host "     • Complete guided lessons to learn AitherZero" -ForegroundColor White
            Write-Host "     • Practice with real scenarios" -ForegroundColor White
            Write-Host "     • Progress tracking available" -ForegroundColor White
        }
        'Minimal' {
            Write-Host "     • Basic operations only" -ForegroundColor White
            Write-Host "     • Optimized for performance" -ForegroundColor White
            Write-Host "     • Use './Start-AitherZero.ps1' for full features" -ForegroundColor White
        }
    }
    Write-Host ""
}

function Show-ProfileInformation {
    param([string]$ProfileName)
    
    try {
        $profile = Get-UserProfile -Name $ProfileName -ErrorAction SilentlyContinue
        if ($profile) {
            Write-Host "  👤 Profile: $ProfileName" -ForegroundColor Blue
            if ($profile.Description) {
                Write-Host "     $($profile.Description)" -ForegroundColor Gray
            }
            if ($profile.EnabledModules) {
                Write-Host "     Modules: $($profile.EnabledModules -join ', ')" -ForegroundColor Gray
            }
            Write-Host ""
        }
    } catch {
        Write-Verbose "Could not display profile information: $_"
    }
}

function Show-WelcomeTips {
    param([string]$Mode, [bool]$IsFirstTime, [hashtable]$Capabilities)
    
    $tips = @()
    
    # Mode-specific tips
    switch ($Mode) {
        'Setup' {
            $tips += "💡 Setup will auto-detect your environment and suggest optimal settings"
            $tips += "⏱️ Initial setup typically takes 1-3 minutes"
            if ($IsFirstTime) {
                $tips += "📚 Consider running Tutorial Mode after setup to learn the basics"
            }
        }
        'Interactive' {
            $tips += "💡 Press F1 for help in any menu"
            $tips += "🔍 Use the Module Explorer to discover available functionality"
            $tips += "⚙️ Access Configuration Manager to customize your experience"
        }
        'Expert' {
            $tips += "🔧 All advanced features are unlocked in this mode"
            $tips += "🎯 Use Ctrl+D for developer tools and debugging"
            $tips += "📊 Performance metrics and logging are available"
        }
    }
    
    # General tips
    if ($Capabilities.SupportsEnhancedUI) {
        $tips += "🎨 Your terminal supports enhanced UI features"
    }
    
    if ($IsFirstTime) {
        $tips += "📖 Documentation is available in the ./docs directory"
        $tips += "🆘 Use 'Get-Help Start-AitherZero' for command-line help"
    }
    
    # Display tips
    if ($tips.Count -gt 0) {
        Write-Host "  💭 Tips:" -ForegroundColor Yellow
        $displayTips = $tips | Select-Object -First 3  # Limit to 3 tips
        foreach ($tip in $displayTips) {
            Write-Host "     $tip" -ForegroundColor Gray
        }
        Write-Host ""
    }
}

function Show-WelcomeContinuePrompt {
    param([string]$Mode)
    
    if ($Mode -in @('Setup', 'Tutorial')) {
        Write-Host "  Press Enter to continue..." -ForegroundColor Green -NoNewline
        Read-Host
    } else {
        Write-Host "  Starting $Mode mode..." -ForegroundColor Green
        Start-Sleep -Seconds 1
    }
}

function Show-MinimalWelcome {
    param([string]$Mode)
    
    Write-Host ""
    Write-Host "AitherZero v1.0.0 - Infrastructure Automation Platform" -ForegroundColor Cyan
    Write-Host "Starting $Mode mode..." -ForegroundColor White
    Write-Host ""
}