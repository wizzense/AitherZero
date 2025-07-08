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
        # Initialize logging
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Level 'INFO' -Message "Starting interactive mode"
        }
        
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
                    Write-Warning "Could not load LicenseManager module: $_"
                }
            }
            
            # Get license status with fallback
            try {
                $licenseStatus = Get-LicenseStatus
                $availableTier = $licenseStatus.Tier ?? 'free'
            } catch {
                Write-Warning "Could not get license status: $_"
                $availableTier = 'free' # Default to free tier
            }
        } else {
            $availableTier = 'enterprise' # Full access for testing
        }
        
        # Load configuration profile if specified
        if ($Profile) {
            try {
                $config = Get-ConfigurationProfile -Name $Profile
                if ($config) {
                    Set-ConfigurationProfile -Name $Profile
                }
            } catch {
                Write-Warning "Configuration profile '$Profile' not found: $_"
                Write-Host "Continuing with default configuration..." -ForegroundColor Yellow
                # Continue without the profile - the application will use default config
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
                    Write-Warning "Error checking tier access for $($_.Text): $_"
                    $true  # Default to allowing access if check fails
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
        
    } catch {
        Write-Error "Error in interactive mode: $_"
        throw
    } finally {
        # Cleanup terminal UI
        Reset-TerminalUI
    }
}

function Show-Banner {
    param(
        [string]$Tier = 'free'
    )
    
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
}