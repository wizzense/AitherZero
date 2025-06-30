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
            $licenseStatus = Get-LicenseStatus
            $availableTier = $licenseStatus.Tier ?? 'free'
        } else {
            $availableTier = 'enterprise' # Full access for testing
        }
        
        # Load configuration profile if specified
        if ($Profile) {
            $config = Get-ConfigurationProfile -Name $Profile
            if ($config) {
                Set-ConfigurationProfile -Name $Profile
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
            
            # Filter menu options based on tier
            $availableOptions = $menuOptions | Where-Object { 
                Test-FeatureAccess -Feature $_.Tier -CurrentTier $availableTier 
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