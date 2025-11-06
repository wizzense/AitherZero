#Requires -Version 7.0
<#
.SYNOPSIS
    Enhanced Interactive UI with Modal UI support
.DESCRIPTION
    This module extends the existing InteractiveUI module with modal UI capabilities.
    It wraps existing dynamic menu generation with VIM-like modal interaction.
    
    IMPORTANT: This is an ENHANCEMENT, not a replacement. All existing functionality
    is preserved and accessible. The modal UI is an optional layer that can be
    enabled/disabled via configuration.
    
.NOTES
    Integration approach:
    1. Use existing Build-MainMenuItems() to generate menu content
    2. Use existing Get-ManifestCapabilities() for dynamic capabilities
    3. Wrap display with Show-ModalMenu() for enhanced interaction
    4. Return results back to existing menu handlers
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import required modules
$modulesToImport = @(
    (Join-Path $PSScriptRoot "InteractiveUI.psm1")
    (Join-Path $PSScriptRoot "ModalUIIntegration.psm1")
    (Join-Path $PSScriptRoot "BreadcrumbNavigation.psm1")
)

foreach ($modulePath in $modulesToImport) {
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force -ErrorAction SilentlyContinue
    }
}

<#
.SYNOPSIS
    Starts the enhanced interactive UI with modal support
.DESCRIPTION
    Enhances the existing Start-InteractiveUI with modal UI capabilities.
    Uses dynamic menu generation but adds VIM-like interaction.
    
.PARAMETER ConfigPath
    Path to config.psd1 file
    
.PARAMETER Profile
    Profile to use (Minimal, Standard, Developer, Full)
    
.PARAMETER EnableModalUI
    Enable modal UI enhancements (default: true if configured)
#>
function Start-EnhancedInteractiveUI {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigPath = './config.psd1',
        
        [Parameter()]
        [ValidateSet('Minimal', 'Standard', 'Developer', 'Full', 'CI')]
        [string]$Profile = 'Standard',
        
        [switch]$EnableModalUI = $true
    )
    
    try {
        # Load configuration
        Write-Host "Loading configuration..." -ForegroundColor Cyan
        
        # Try to load config and check if modal UI is enabled
        $modalUIEnabled = $false
        if (Test-Path $ConfigPath) {
            try {
                # Use scriptblock evaluation instead of Import-PowerShellDataFile
                # because config.psd1 contains PowerShell expressions ($true/$false) that
                # Import-PowerShellDataFile treats as "dynamic expressions"
                $configContent = Get-Content -Path $ConfigPath -Raw -ErrorAction SilentlyContinue
                $scriptBlock = [scriptblock]::Create($configContent)
                $configData = & $scriptBlock
                if ($configData -and $configData.UI.ModalUI.Enabled -ne $null) {
                    $modalUIEnabled = $configData.UI.ModalUI.Enabled
                }
            } catch {
                Write-Verbose "Could not read ModalUI config, using parameter: $_"
            }
        }
        
        # Override with parameter if explicitly set
        if ($PSBoundParameters.ContainsKey('EnableModalUI')) {
            $modalUIEnabled = $EnableModalUI.IsPresent
        }
        
        if ($modalUIEnabled) {
            Write-Host "✨ Modal UI: ENABLED (VIM-like interface)" -ForegroundColor Green
            Start-ModalEnhancedMenu -ConfigPath $ConfigPath -Profile $Profile
        } else {
            Write-Host "📋 Modal UI: DISABLED (Classic interface)" -ForegroundColor Yellow
            # Fall back to existing InteractiveUI
            if (Get-Command Start-InteractiveUI -ErrorAction SilentlyContinue) {
                Start-InteractiveUI -ConfigPath $ConfigPath -Profile $Profile
            } else {
                Write-Warning "InteractiveUI module not available. Please check installation."
            }
        }
    }
    catch {
        Write-Error "Failed to start enhanced interactive UI: $_"
        throw
    }
}

<#
.SYNOPSIS
    Shows the main menu with modal UI enhancements
.DESCRIPTION
    Uses existing Build-MainMenuItems to generate content,
    then displays it with modal UI wrapper.
#>
function Start-ModalEnhancedMenu {
    [CmdletBinding()]
    param(
        [string]$ConfigPath,
        [string]$Profile
    )
    
    # Initialize - reuse existing InteractiveUI state if available
    if (Get-Command Start-InteractiveUI -ErrorAction SilentlyContinue) {
        # The existing module already initializes config and caches
        # We just need to hook into it
        Write-Verbose "Using existing InteractiveUI infrastructure"
    }
    
    # Show welcome
    Show-EnhancedWelcomeBanner
    
    # Main loop
    $running = $true
    $breadcrumbStack = New-BreadcrumbStack -ErrorAction SilentlyContinue
    
    while ($running) {
        # Build menu items using EXISTING dynamic generation
        $menuItems = @()
        
        # Try to use existing Build-MainMenuItems function
        if (Get-Command Build-MainMenuItems -ErrorAction SilentlyContinue) {
            $menuItems = Build-MainMenuItems
        } else {
            # Fallback to hardcoded items if function not available
            $menuItems = Get-FallbackMenuItems
        }
        
        # Convert to modal-compatible format
        $modalItems = $menuItems | ForEach-Object {
            [PSCustomObject]@{
                Name = $_.Name
                Description = $_.Description
                Action = $_.Action
                Mode = if ($_.Mode) { $_.Mode } else { $null }
            }
        }
        
        # Build context for modal display
        $context = @{
            Breadcrumb = if ($breadcrumbStack) {
                Get-BreadcrumbPath -Stack $breadcrumbStack -IncludeRoot
            } else {
                "Main Menu"
            }
            Profile = $Profile
        }
        
        # Show menu with modal UI wrapper
        $result = Show-ModalMenu `
            -Items $modalItems `
            -Title "AitherZero Enhanced Interactive Menu" `
            -Context $context
        
        # Handle result
        if (-not $result) {
            # User quit
            $running = $false
            Write-Host "`n✨ Goodbye!" -ForegroundColor Cyan
            break
        }
        
        # Check if it's a command result
        if ($result.Action -eq 'Command') {
            Execute-ModalCommand -ParsedCommand $result.ParsedCommand -Context $context
            continue
        }
        
        # Otherwise it's a selected item - execute its action
        if ($result.Action -and $result.Action -is [scriptblock]) {
            try {
                & $result.Action
            } catch {
                Write-Host "`n❌ Error executing action: $_" -ForegroundColor Red
                Write-Host "Press any key to continue..." -ForegroundColor DarkGray
                $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            }
        }
    }
}

<#
.SYNOPSIS
    Shows enhanced welcome banner with modal UI info
#>
function Show-EnhancedWelcomeBanner {
    Clear-Host
    
    $banner = @"

    ╔══════════════════════════════════════════════════════════════╗
    ║              AitherZero - Enhanced Interactive UI            ║
    ║         VIM-like Modal Interface + Dynamic Menus             ║
    ╚══════════════════════════════════════════════════════════════╝

    ✨ Enhanced Features:
    
    • Normal Mode - Navigate with arrows or VIM keys (h,j,k,l)
    • Command Mode - Type commands like :run 0402
    • Search Mode - Filter items in real-time with /pattern
    • Quick Selection - Press 1-9 for instant access
    • Dynamic Content - All menus generated from config.psd1
    
    💡 Press ? anytime for help
    
"@
    
    Write-Host $banner -ForegroundColor Cyan
    Write-Host "    Press any key to continue..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

<#
.SYNOPSIS
    Executes a command from Command mode
.DESCRIPTION
    Handles commands entered via :command syntax
#>
function Execute-ModalCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$ParsedCommand,
        
        [hashtable]$Context = @{}
    )
    
    $command = $ParsedCommand.Command
    $args = $ParsedCommand.Arguments
    
    Write-Host "`n🎯 Executing: :$command $($ args -join ' ')" -ForegroundColor Cyan
    
    switch ($command) {
        'run' {
            if ($args.Count -gt 0) {
                $scriptNum = $args[0]
                Write-Host "Running script $scriptNum..." -ForegroundColor Green
                
                # Try to execute via existing infrastructure
                if (Get-Command Invoke-AitherScript -ErrorAction SilentlyContinue) {
                    Invoke-AitherScript -ScriptNumber $scriptNum
                } else {
                    Write-Host "Would run script $scriptNum (execution handler not available)" -ForegroundColor Yellow
                }
            }
        }
        'orchestrate' {
            if ($args.Count -gt 0) {
                $playbook = $args[0]
                Write-Host "Running playbook: $playbook..." -ForegroundColor Green
                
                # Try to execute via existing infrastructure
                if (Get-Command Invoke-OrchestrationPlaybook -ErrorAction SilentlyContinue) {
                    Invoke-OrchestrationPlaybook -PlaybookName $playbook
                } else {
                    Write-Host "Would run playbook $playbook (execution handler not available)" -ForegroundColor Yellow
                }
            }
        }
        'search' {
            if ($args.Count -gt 0) {
                $pattern = $args -join ' '
                Write-Host "Searching for: $pattern..." -ForegroundColor Green
                # Search implementation would go here
            }
        }
        'quit' {
            Write-Host "Exiting..." -ForegroundColor Cyan
            # This will be handled by caller
        }
        default {
            Write-Host "Command '$command' not yet implemented" -ForegroundColor Yellow
        }
    }
    
    Write-Host "`nPress any key to continue..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

<#
.SYNOPSIS
    Gets fallback menu items when dynamic generation is not available
#>
function Get-FallbackMenuItems {
    return @(
        @{
            Name = "🎯 Run Scripts"
            Description = "Execute automation scripts"
            Action = { Write-Host "Run Scripts menu would go here" -ForegroundColor Yellow }
        }
        @{
            Name = "📚 Orchestrate"
            Description = "Run playbooks and workflows"
            Action = { Write-Host "Orchestrate menu would go here" -ForegroundColor Yellow }
        }
        @{
            Name = "🔍 Search"
            Description = "Search scripts and resources"
            Action = { Write-Host "Search menu would go here" -ForegroundColor Yellow }
        }
        @{
            Name = "✅ Testing"
            Description = "Run tests and validation"
            Action = { Write-Host "Testing menu would go here" -ForegroundColor Yellow }
        }
        @{
            Name = "📊 Reports"
            Description = "View reports and metrics"
            Action = { Write-Host "Reports menu would go here" -ForegroundColor Yellow }
        }
    )
}

# Export module members
Export-ModuleMember -Function @(
    'Start-EnhancedInteractiveUI',
    'Start-ModalEnhancedMenu',
    'Show-EnhancedWelcomeBanner',
    'Execute-ModalCommand'
)
