#Requires -Version 7.0
<#
.SYNOPSIS
    AitherZero Platform Launcher with Orchestration Engine
.DESCRIPTION
    Main entry point for the AitherZero automation platform.
    Provides interactive menu and number-based orchestration capabilities.
.PARAMETER Mode
    Startup mode: Interactive (default), Orchestrate, Validate
.PARAMETER Sequence
    Number sequence for orchestration mode
.PARAMETER ConfigPath
    Path to configuration file
.PARAMETER NonInteractive
    Run without user prompts
.PARAMETER Profile
    Execution profile to use
.PARAMETER Playbook
    Name of the playbook to execute
.PARAMETER PlaybookProfile
    Profile to use within the playbook (e.g., quick, full, ci)
.EXAMPLE
    # Interactive mode
    .\Start-AitherZero.ps1

.EXAMPLE
    # Run specific sequence
    .\Start-AitherZero.ps1 -Mode Orchestrate -Sequence "0000-0099"

.EXAMPLE
    # Non-interactive with profile
    .\Start-AitherZero.ps1 -NonInteractive -Profile Developer

.EXAMPLE
    # Run playbook with specific profile
    .\Start-AitherZero.ps1 -Mode Orchestrate -Playbook tech-debt-analysis -PlaybookProfile quick
#>
[CmdletBinding()]
param(
    [ValidateSet('Interactive', 'Orchestrate', 'Validate', 'Deploy', 'Test')]
    [string]$Mode = 'Interactive',

    [string[]]$Sequence,

    [string]$ConfigPath,

    [switch]$NonInteractive,

    [ValidateSet('Minimal', 'Standard', 'Developer', 'Full')]
    [string]$ProfileName,

    [string]$Playbook,

    [string]$PlaybookProfile,

    [switch]$DryRun,

    [switch]$Version,

    [switch]$Help,

    [switch]$CI,

    [hashtable]$Variables,

    [switch]$Sequential,

    [switch]$Parallel,

    # Catch any extra arguments that might come from shell redirection
    [Parameter(ValueFromRemainingArguments)]
    [object[]]$RemainingArguments
)

# Set up environment
$script:ProjectRoot = $PSScriptRoot
$env:AITHERZERO_ROOT = $script:ProjectRoot

# Import Configuration module early to use Get-ConfiguredValue
$configModulePath = Join-Path $script:ProjectRoot 'domains/configuration/Configuration.psm1'
if (Test-Path $configModulePath) {
    Import-Module $configModulePath -Force -ErrorAction SilentlyContinue
}

# Apply configuration defaults if not provided
if ([string]::IsNullOrEmpty($ProfileName)) {
    if (Get-Command Get-ConfiguredValue -ErrorAction SilentlyContinue) {
        $ProfileName = Get-ConfiguredValue -Name 'Profile' -Section 'Core' -Default 'Standard'
    } else {
        $ProfileName = 'Standard'
    }
}

# Auto-detect CI if not explicitly set
if (-not $CI -and -not $NonInteractive) {
    if (Get-Command Get-ConfiguredValue -ErrorAction SilentlyContinue) {
        # Let Configuration module detect CI
        $nonInteractiveValue = Get-ConfiguredValue -Name 'NonInteractive' -Section 'Automation' -Default $false
        if ($nonInteractiveValue -eq $true -or $nonInteractiveValue -eq '1' -or $nonInteractiveValue -eq 'true') {
            $NonInteractive = $true
        }
    }
}

# CRITICAL: Block any conflicting systems
if ($env:DISABLE_COREAPP -ne "1") {
    # Force clean environment if not already done
    @('CoreApp', 'AitherRun', 'StartupExperience', 'ConfigurationCore', 'ConfigurationCarousel') | ForEach-Object {
        Remove-Module $_ -Force -ErrorAction SilentlyContinue 2>$null
    }
    $env:DISABLE_COREAPP = "1"
    $env:SKIP_AUTO_MODULES = "1"
}

# ASCII Art Banner with Gradient Colors
function Show-Banner {
    # Split banner into lines for gradient coloring
    $bannerLines = @(
        "    _    _ _   _               ______               ",
        "   / \  (_) |_| |__   ___ _ __|__  /___ _ __ ___   ",
        "  / _ \ | | __| '_ \ / _ \ '__| / // _ \ '__/ _ \  ",
        " / ___ \| | |_| | | |  __/ |   / /|  __/ | | (_) | ",
        "/_/   \_\_|\__|_| |_|\___|_|  /____\___|_|  \___/  ",
        "                                                    ",
        "        Aitherium™ Automation Platform v1.0",
        "        PowerShell 7 | Cross-Platform | Orchestrated"
    )

    # Define gradient colors from light blue to light pink
    $gradientColors = @(
        "`e[38;2;173;216;230m",  # Light Blue
        "`e[38;2;185;209;234m",  # Blue-Cyan transition
        "`e[38;2;197;202;238m",  # Cyan-Lavender transition
        "`e[38;2;209;195;242m",  # Lavender
        "`e[38;2;221;188;246m",  # Lavender-Pink transition
        "`e[38;2;233;181;250m",  # Light Purple-Pink
        "`e[38;2;245;174;254m",  # Pink-Purple
        "`e[38;2;255;182;193m"   # Light Pink
    )

    # Display each line with gradient color
    for ($i = 0; $i -lt $bannerLines.Count; $i++) {
        Write-Host "$($gradientColors[$i])$($bannerLines[$i])`e[0m"
    }
    Write-Host ""
}

# Show help information
function Show-Help {
    if (-not $env:CI -and -not $env:GITHUB_ACTIONS) {
        try { Clear-Host } catch { Write-Verbose "Unable to clear host in this context" }
    }
    Show-UIBorder -Title "AitherZero Help" -Style 'Double'

    Write-UIText "Quick Commands:" -Color 'Primary'
    Write-UIText "  seq 0000-0099        # Run scripts 0000 through 0099" -Color 'Info'
    Write-UIText "  seq 02*              # Run all 0200-0299 scripts" -Color 'Info'
    Write-UIText "  seq stage:Core       # Run all Core stage scripts" -Color 'Info'
    Write-UIText "  seq 0001,0207,0210   # Run specific scripts" -Color 'Info'
    Write-UIText "" -Color 'Info'

    Write-UIText "Profiles:" -Color 'Primary'
    Write-UIText "  Minimal    - Core infrastructure only" -Color 'Info'
    Write-UIText "  Standard   - Production-ready setup" -Color 'Info'
    Write-UIText "  Developer  - Full development environment" -Color 'Info'
    Write-UIText "  Full       - Everything including optional components" -Color 'Info'
    Write-UIText "" -Color 'Info'

    Write-UIText "Command Line Usage:" -Color 'Primary'
    Write-UIText "  -Mode Orchestrate -Sequence '0000-0099'" -Color 'Info'
    Write-UIText "  -Mode Orchestrate -Playbook 'infrastructure-lab'" -Color 'Info'
    Write-UIText "  -Mode Orchestrate -Playbook 'tech-debt-analysis' -PlaybookProfile 'quick'" -Color 'Info'
    Write-UIText "  -NonInteractive -Profile Developer" -Color 'Info'
    Write-UIText "  -DryRun    # Preview without executing" -Color 'Info'
}

# Version
if ($Version) {
    Write-Host "AitherZero v1.0" -ForegroundColor Cyan
    exit 0
}

# Help
if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit 0
}

# Initialize core modules efficiently
function Initialize-CoreModules {
    # Direct import without background jobs to avoid double initialization
    try {
        # Check if already loaded and avoid repeated imports in CI
        $moduleLoaded = Get-Module -Name "AitherZero"
        $shouldReload = -not $moduleLoaded -or (-not $env:AITHERZERO_CI -and -not $global:AitherZeroModuleLoaded)

        if ($shouldReload) {
            Import-Module (Join-Path $script:ProjectRoot "AitherZero.psd1") -Force -Global
            $global:AitherZeroModuleLoaded = $true
        }

        # Initialize UI if available (without re-loading config)
        if (Get-Command Initialize-AitherUI -ErrorAction SilentlyContinue) {
            # Only initialize if not already done
            if (-not $global:AitherUIInitialized) {
                Initialize-AitherUI
                $global:AitherUIInitialized = $true
            }
        }

        return @{
            Logging = (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) -ne $null
            Configuration = (Get-Command Get-Configuration -ErrorAction SilentlyContinue) -ne $null
            UI = (Get-Command Show-UIMenu -ErrorAction SilentlyContinue) -ne $null
            Orchestration = (Get-Command Invoke-OrchestrationSequence -ErrorAction SilentlyContinue) -ne $null
        }
    } catch {
        Write-Error "Failed to import AitherZero module: $($_.Exception.Message)"
        return @{
            Logging = $false
            Configuration = $false
            UI = $false
            Orchestration = $false
        }
    }
}

# Load configuration
# Helper function to convert PSObject to Hashtable
function Convert-PSObjectToHashtable {
    param($InputObject)
    
    if ($InputObject -is [hashtable]) {
        return $InputObject
    }
    
    $hashtable = @{}
    if ($InputObject) {
        foreach ($property in $InputObject.PSObject.Properties) {
            if ($property.Value -is [PSCustomObject]) {
                $hashtable[$property.Name] = Convert-PSObjectToHashtable $property.Value
            } elseif ($property.Value -is [array]) {
                $hashtable[$property.Name] = $property.Value | ForEach-Object {
                    if ($_ -is [PSCustomObject]) {
                        Convert-PSObjectToHashtable $_
                    } else {
                        $_
                    }
                }
            } else {
                $hashtable[$property.Name] = $property.Value
            }
        }
    }
    return $hashtable
}

function Get-AitherConfiguration {
    param([string]$Path)

    if ($Path -and (Test-Path $Path)) {
        return Get-Content $Path -Raw | ConvertFrom-Json -AsHashtable
    }

    # Try both PSD1 and JSON formats
    $psd1Path = Join-Path $script:ProjectRoot 'config.psd1'
    if (Test-Path $psd1Path) {
        try {
            $configData = Import-PowerShellDataFile $psd1Path
            # Convert to hashtable for compatibility
            return Convert-PSObjectToHashtable $configData
        } catch {
            Write-Warning "Failed to load PSD1 config: $($_.Exception.Message)"
        }
    }

    $defaultPath = Join-Path $script:ProjectRoot 'config.json'
    if (Test-Path $defaultPath) {
        return Get-Content $defaultPath -Raw | ConvertFrom-Json -AsHashtable
    }

    Write-Warning "No configuration file found, using defaults"
    return @{
        Core = @{
            Name = "AitherZero"
            Version = "1.0.0"
            Profile = $ProfileName
        }
}
}

# Main Interactive Menu using Core UI
function Show-InteractiveMenu {
    param($Config)

    # Interactive menus are now always enabled unless in non-interactive mode

    # Show banner only once at the start
    if (-not $env:CI -and -not $env:GITHUB_ACTIONS) {
        try { Clear-Host } catch { Write-Verbose "Unable to clear host in this context" }
    }
    Show-Banner

    while ($true) {
        # Build menu items
        $menuItems = @(
            [PSCustomObject]@{
                Name = "Quick Setup"
                Description = "Run profile-based setup (Current: $($Config.Core.Profile))"
            },
            [PSCustomObject]@{
                Name = "Orchestration"
                Description = "Run custom automation sequences"
            },
            [PSCustomObject]@{
                Name = "Playbooks"
                Description = "Execute pre-defined playbooks"
            },
            [PSCustomObject]@{
                Name = "Testing"
                Description = "Run tests and validation"
            },
            [PSCustomObject]@{
                Name = "Infrastructure"
                Description = "Deploy and manage infrastructure"
            },
            [PSCustomObject]@{
                Name = "Development"
                Description = "Git automation and AI coding tools"
            },
            [PSCustomObject]@{
                Name = "Reports & Logs"
                Description = "View logs, generate reports, and analyze metrics"
            },
            [PSCustomObject]@{
                Name = "UI Demo"
                Description = "Interactive UI System Demo"
            },
            [PSCustomObject]@{
                Name = "Advanced"
                Description = "Configuration and system management"
            }
    )

        # Show menu using UI module
        try {
            $menuParams = @{
                Title = "AitherZero Main Menu"
                Items = $menuItems
                ShowNumbers = $true
                CustomActions = @{
                    'Q' = 'Quit'
                    'H' = 'Help'
                }
            }

            $selection = Show-UIMenu @menuParams
        }
        catch {
            Write-Error "Menu error: $_"
            Show-UIPrompt -Message "Press Enter to continue or Ctrl+C to exit" | Out-Null
            # Don't clear screen, just continue to menu
            continue
        }

        # Handle null selection
        if (-not $selection) {
            continue
        }

        # Handle selection
        if ($selection.Action -eq 'Q') {
            Show-UINotification -Message "Thank you for using AitherZero!" -Type 'Success'
            return
        }
    elseif ($selection.Action -eq 'H') {
            Show-Help
            Show-UIPrompt -Message "Press Enter to continue" | Out-Null
        }
    elseif ($selection.Name) {
            switch ($selection.Name) {
                'Quick Setup' { Invoke-QuickSetup -Config $Config }
                'Orchestration' { Invoke-OrchestrationMenu -Config $Config }
                'Playbooks' { Invoke-PlaybookMenu -Config $Config }
                'Testing' { Invoke-TestingMenu -Config $Config }
                'Infrastructure' { Invoke-InfrastructureMenu -Config $Config }
                'Development' { Invoke-DevelopmentMenu -Config $Config }
                'Reports & Logs' { Invoke-ReportsAndLogsMenu -Config $Config }
                'UI Demo' {
                    # Run the interactive UI demo
                    $demoPath = Join-Path $script:ProjectRoot "examples/interactive-ui-demo.ps1"
                    if (Test-Path $demoPath) {
                        & $demoPath
                    }
                    else {
                        Show-UINotification -Message "Demo script not found at: $demoPath" -Type 'Warning'
                    }
                    Show-UIPrompt -Message "Press Enter to continue" | Out-Null
                }
                'Advanced' { Show-AdvancedMenu -Config $Config }
            }
    }
}
}

# Quick Setup
function Invoke-QuickSetup {
    param($Config)

    $ProfileNameSequence = switch ($Config.Core.Profile) {
        'Minimal' { "0000-0099,0207" }
        'Standard' { "0000-0199,0207,0201" }
        'Developer' { "0000-0299,!0208" }
        'Full' { "0000-0499" }
    }

    Show-UINotification -Message "Starting $($Config.Core.Profile) profile setup" -Type 'Info' -Title "Quick Setup"

    # Call directly instead of in scriptblock to avoid scope issues
    $result = Invoke-OrchestrationSequence -Sequence $ProfileNameSequence -Configuration $Config

    if ($result.Failed -eq 0) {
        Show-UINotification -Message "Profile setup completed successfully!" -Type 'Success'
        Show-UIPrompt -Message "Press Enter to continue" | Out-Null
    } else {
        Show-UINotification -Message "Profile setup completed with $($result.Failed) errors" -Type 'Warning'
        # Don't add another prompt - orchestration errors already prompt
    }
}

# Orchestration Menu
function Invoke-OrchestrationMenu {
    param($Config)

    $sequence = Show-UIPrompt -Message "Enter orchestration sequence (e.g., 0001-0099,0201,stage:Core)"

    if ($sequence) {
        $dryRun = Show-UIPrompt -Message "Perform dry run first?" -ValidateSet @('Yes', 'No') -DefaultValue 'Yes'

        $variables = @{}
        if ($CI) { $variables['CI'] = $true }

        if ($dryRun -eq 'Yes') {
            Show-UINotification -Message "Running dry run..." -Type 'Info'
            $result = Invoke-OrchestrationSequence -Sequence $sequence -Configuration $Config -Variables $variables -DryRun

            $proceed = Show-UIPrompt -Message "Dry run complete. Proceed with execution?" -ValidateSet @('Yes', 'No') -DefaultValue 'No'
            if ($proceed -eq 'Yes') {
                $result = Invoke-OrchestrationSequence -Sequence $sequence -Configuration $Config -Variables $variables
            }
    } else {
            $result = Invoke-OrchestrationSequence -Sequence $sequence -Configuration $Config -Variables $variables
        }
}

    Show-UIPrompt -Message "Press Enter to continue" | Out-Null
}

# Playbook Menu
function Invoke-PlaybookMenu {
    param($Config)

    $playbookDir = Join-Path $script:ProjectRoot "orchestration/playbooks"
    if (-not (Test-Path $playbookDir)) {
        Show-UINotification -Message "No playbooks directory found" -Type 'Error'
        Show-UIPrompt -Message "Press Enter to continue" | Out-Null
        return
    }

    # Load playbooks (including from subdirectories)
    $playbooks = Get-ChildItem $playbookDir -Filter "*.json" -Recurse | ForEach-Object {
        $pb = Get-Content $_.FullName | ConvertFrom-Json
        # Get category from parent directory if in a subdirectory
        $category = if ($_.Directory.Name -ne 'playbooks') {
            $_.Directory.Name
        } else {
            'general'
        }
        [PSCustomObject]@{
            Name = if ($category -ne 'general' -and $category -ne 'archive') { "[$category] $($pb.Name)" } else { $pb.Name }
            Description = $pb.Description
            Path = $_.FullName
            Category = $category
            OriginalName = $pb.Name
        }
    } | Sort-Object Category, Name

    if ($playbooks.Count -eq 0) {
        Show-UINotification -Message "No playbooks found" -Type 'Warning'
        Show-UIPrompt -Message "Press Enter to continue" | Out-Null
        return
    }

    $selection = Show-UIMenu -Title "Select Playbook" -Items $playbooks -ShowNumbers

    if ($selection) {
        Show-UINotification -Message "Executing playbook: $($selection.Name)" -Type 'Info'
        $variables = @{}
        if ($CI) { $variables['CI'] = $true }
        $result = Invoke-OrchestrationSequence -LoadPlaybook $selection.Name -Configuration $Config -Variables $variables

        if ($result.Failed -eq 0) {
            Show-UINotification -Message "Playbook completed successfully!" -Type 'Success'
        } else {
            Show-UINotification -Message "Playbook completed with errors" -Type 'Error'
        }
}

    Show-UIPrompt -Message "Press Enter to continue" | Out-Null
}

# Testing Menu
function Invoke-TestingMenu {
    param($Config)

    $testItems = @(
        [PSCustomObject]@{
            Name = "Run Unit Tests"
            Description = "Execute unit test suite"
            Sequence = "0402"
        },
        [PSCustomObject]@{
            Name = "Run Integration Tests"
            Description = "Execute integration test suite"
            Sequence = "0403"
        },
        [PSCustomObject]@{
            Name = "Run PSScriptAnalyzer"
            Description = "Analyze code quality"
            Sequence = "0404"
        },
        [PSCustomObject]@{
            Name = "Validate Environment"
            Description = "Check system requirements"
            Sequence = "0500"
        },
        [PSCustomObject]@{
            Name = "Generate Coverage Report"
            Description = "Create code coverage report"
            Sequence = "0406"
        },
        [PSCustomObject]@{
            Name = "Full Test Suite"
            Description = "Run all tests with reporting"
            Playbook = "test-full"
        }
)

    $selection = Show-UIMenu -Title "Testing & Validation" -Items $testItems -ShowNumbers

    if ($selection) {
        Show-UINotification -Message "Starting: $($selection.Name)" -Type 'Info'

        if ($selection.Sequence) {
            $result = Invoke-OrchestrationSequence -Sequence $selection.Sequence -Configuration $Config
        } elseif ($selection.Playbook) {
            $result = Invoke-OrchestrationSequence -LoadPlaybook $selection.Playbook -Configuration $Config
        }

        # Only prompt if successful (errors already prompt)
        if (-not $result -or $result.Failed -eq 0) {
            Show-UIPrompt -Message "Press Enter to continue" | Out-Null
        }
    }
}

# Infrastructure Menu
function Invoke-InfrastructureMenu {
    param($Config)

    $infraItems = @(
        [PSCustomObject]@{
            Name = "Install Hyper-V"
            Description = "Setup virtualization platform"
            Sequence = "0105"
        },
        [PSCustomObject]@{
            Name = "Install OpenTofu"
            Description = "Setup infrastructure as code"
            Sequence = "0007-0009"
        },
        [PSCustomObject]@{
            Name = "Deploy Infrastructure"
            Description = "Deploy configured infrastructure"
            Sequence = "0300"
        },
        [PSCustomObject]@{
            Name = "Full Infrastructure Setup"
            Description = "Complete infrastructure deployment"
            Playbook = "infrastructure-lab"
        }
)

    $selection = Show-UIMenu -Title "Infrastructure Management" -Items $infraItems -ShowNumbers

    if ($selection) {
        $confirm = Show-UIPrompt -Message "This may modify your system. Continue?" -ValidateSet @('Yes', 'No') -DefaultValue 'No'

        if ($confirm -eq 'Yes') {
            Show-UINotification -Message "Starting: $($selection.Name)" -Type 'Info'

            if ($selection.Sequence) {
                $result = Invoke-OrchestrationSequence -Sequence $selection.Sequence -Configuration $Config
            } elseif ($selection.Playbook) {
                $result = Invoke-OrchestrationSequence -LoadPlaybook $selection.Playbook -Configuration $Config
            }
    }
}

    Show-UIPrompt -Message "Press Enter to continue" | Out-Null
}

# Development Menu
function Invoke-DevelopmentMenu {
    param($Config)

    $devItems = @(
        [PSCustomObject]@{
            Name = "Git Status"
            Description = "Show current repository status"
            Command = { git status }
        },
        [PSCustomObject]@{
            Name = "Create Feature Branch"
            Description = "Create a new feature branch"
            Command = {
                $name = Show-UIPrompt -Message "Feature name"
                if ($name) { git checkout -b "feature/$name" }
            }
    },
        [PSCustomObject]@{
            Name = "Run Pre-commit Checks"
            Description = "Validate code before commit"
            Sequence = "0404,0402"
        },
        [PSCustomObject]@{
            Name = "Generate Tests"
            Description = "Auto-generate test cases"
            Sequence = "0407"
        }
)

    $selection = Show-UIMenu -Title "Development Tools" -Items $devItems -ShowNumbers

    if ($selection) {
        if ($selection.Command) {
            & $selection.Command
        } elseif ($selection.Sequence) {
            $result = Invoke-OrchestrationSequence -Sequence $selection.Sequence -Configuration $Config
        }
}

    Show-UIPrompt -Message "Press Enter to continue" | Out-Null
}

# Reports & Logs Menu
function Invoke-ReportsAndLogsMenu {
    param($Config)

    # Import LogViewer module if not already loaded
    $logViewerPath = Join-Path $script:ProjectRoot "domains/utilities/LogViewer.psm1"
    if (Test-Path $logViewerPath) {
        Import-Module $logViewerPath -Force -ErrorAction SilentlyContinue
    }

    $reportItems = @(
        [PSCustomObject]@{
            Name = "View Latest Logs"
            Description = "Show recent log entries"
            Sequence = "0530"
            Parameters = @{ Mode = 'Latest' }
        },
        [PSCustomObject]@{
            Name = "Log Dashboard"
            Description = "Interactive log viewer with statistics"
            Sequence = "0530"
            Parameters = @{ Mode = 'Dashboard' }
        },
        [PSCustomObject]@{
            Name = "View Errors & Warnings"
            Description = "Show only error and warning messages"
            Sequence = "0530"
            Parameters = @{ Mode = 'Errors' }
        },
        [PSCustomObject]@{
            Name = "Search Logs"
            Description = "Search for specific patterns in logs"
            Sequence = "0530"
            Parameters = @{ Mode = 'Search' }
        },
        [PSCustomObject]@{
            Name = "View PowerShell Transcript"
            Description = "Show PowerShell session transcript"
            Sequence = "0530"
            Parameters = @{ Mode = 'Transcript' }
        },
        [PSCustomObject]@{
            Name = "Generate Project Report"
            Description = "Create comprehensive project analysis"
            Sequence = "0510"
        },
        [PSCustomObject]@{
            Name = "Tech Debt Analysis"
            Description = "Analyze and report technical debt"
            Sequence = "0524"
        },
        [PSCustomObject]@{
            Name = "Code Quality Report"
            Description = "Analyze code quality metrics"
            Sequence = "0522"
        },
        [PSCustomObject]@{
            Name = "Documentation Coverage"
            Description = "Check documentation completeness"
            Sequence = "0521"
        },
        [PSCustomObject]@{
            Name = "Logging Status"
            Description = "Check logging system configuration"
            Sequence = "0530"
            Parameters = @{ Mode = 'Status' }
        }
    )

    $selection = Show-UIMenu -Title "Reports & Logs" -Items $reportItems -ShowNumbers

    if ($selection) {
        Show-UINotification -Message "Starting: $($selection.Name)" -Type 'Info'

        if ($selection.Sequence) {
            # Build parameters for the script
            $scriptParams = $Config.Clone()
            if ($selection.Parameters) {
                foreach ($key in $selection.Parameters.Keys) {
                    $scriptParams[$key] = $selection.Parameters[$key]
                }
            }

            $result = Invoke-OrchestrationSequence -Sequence $selection.Sequence -Configuration $scriptParams
        }
    }

    Show-UIPrompt -Message "Press Enter to continue" | Out-Null
}

# Advanced menu using UI module
function Show-AdvancedMenu {
    param($Config)

    while ($true) {
        $advancedItems = @(
            [PSCustomObject]@{
                Name = "Change Profile"
                Description = "Switch execution profile"
            },
            [PSCustomObject]@{
                Name = "Edit Configuration"
                Description = "Open config.json in editor"
            },
            [PSCustomObject]@{
                Name = "Create Playbook"
                Description = "Create new orchestration playbook"
            },
            [PSCustomObject]@{
                Name = "System Information"
                Description = "Show system and dependency info"
            },
            [PSCustomObject]@{
                Name = "Run Single Script"
                Description = "Execute specific automation script"
            },
            [PSCustomObject]@{
                Name = "Module Manager"
                Description = "Import/reload modules"
            }
    )

        $selection = Show-UIMenu -Title "Advanced Options" -Items $advancedItems -ShowNumbers -CustomActions @{ 'B' = 'Back to Main Menu' }

        if ($selection.Action -eq 'B') {
            return
        }

        switch ($selection.Name) {
            'Change Profile' {
                $ProfileNames = @(
                    [PSCustomObject]@{ Name = 'Minimal'; Description = 'Core infrastructure only' },
                    [PSCustomObject]@{ Name = 'Standard'; Description = 'Production-ready setup' },
                    [PSCustomObject]@{ Name = 'Developer'; Description = 'Full development environment' },
                    [PSCustomObject]@{ Name = 'Full'; Description = 'Everything including optional components' }
                )

                $newProfile = Show-UIMenu -Title "Select Profile" -Items $ProfileNames -ShowNumbers
                if ($newProfile) {
                    $Config.Core.Profile = $newProfile.Name
                    Show-UINotification -Message "Profile changed to: $($newProfile.Name)" -Type 'Success'
                }
        }

            'Edit Configuration' {
                $configPath = Join-Path $script:ProjectRoot 'config.psd1'
                if ($IsWindows) {
                    Start-Process notepad.exe -ArgumentList $configPath -Wait
                } else {
                    $editor = $env:EDITOR ?? 'nano'
                    Start-Process -FilePath $editor -ArgumentList $configPath -Wait
                }
            Show-UINotification -Message "Configuration may have changed. Restart to apply changes." -Type 'Info'
            }

            'Create Playbook' {
                # Use wizard for playbook creation
                $wizardSteps = @(
                    @{
                        Name = "Basic Information"
                        Script = {
                            $name = Show-UIPrompt -Message "Playbook name" -Required
                            $desc = Show-UIPrompt -Message "Description" -Required
                            @{ Name = $name; Description = $desc }
                        }
                },
                    @{
                        Name = "Sequence Definition"
                        Script = {
                            Write-UIText "Enter sequence (e.g., 0001-0099,0201,stage:Core)" -Color 'Info'
                            $seq = Show-UIPrompt -Message "Sequence" -Required
                            @{ Sequence = ($seq -split ',') }
                        }
                },
                    @{
                        Name = "Variables"
                        Script = {
                            $addVars = Show-UIPrompt -Message "Add variables?" -ValidateSet @('Yes', 'No') -DefaultValue 'No'
                            $vars = @{}
                            if ($addVars -eq 'Yes') {
                                while ($true) {
                                    $key = Show-UIPrompt -Message "Variable name (blank to finish)"
                                    if (-not $key) { break }
                                    $value = Show-UIPrompt -Message "Value for $key"
                                    $vars[$key] = $value
                                }
                        }
                        @{ Variables = $vars }
                        }
                }
            )

                $result = Show-UIWizard -Steps $wizardSteps -Title "Create Playbook"

                if ($result) {
                    Save-OrchestrationPlaybook -Name $result.Name -Sequence $result.Sequence -Variables ($result.Variables + @{Description = $result.Description})
                    Show-UINotification -Message "Playbook '$($result.Name)' created successfully!" -Type 'Success'
                }
        }

            'System Information' {
                if (-not $env:CI -and -not $env:GITHUB_ACTIONS) {
                    try { Clear-Host } catch { Write-Verbose "Unable to clear host in this context" }
                }
                Show-UIBorder -Title "System Information" -Style 'Double'

                $sysInfo = @(
                    [PSCustomObject]@{ Property = "PowerShell"; Value = $PSVersionTable.PSVersion },
                    [PSCustomObject]@{ Property = "OS"; Value = $PSVersionTable.OS },
                    [PSCustomObject]@{ Property = "Platform"; Value = $PSVersionTable.Platform },
                    [PSCustomObject]@{ Property = "Project Root"; Value = $script:ProjectRoot },
                    [PSCustomObject]@{ Property = "Current Profile"; Value = $Config.Core.Profile }
                )

                Show-UITable -Data $sysInfo -Title "System Details"

                Write-UIText "`nChecking Dependencies..." -Color 'Info'
                $deps = @('git', 'node', 'tofu', 'docker', 'pwsh')
                $depStatus = @()

                foreach ($dep in $deps) {
                    try {
                        $version = & $dep --version 2>&1 | Select-Object -First 1
                        $depStatus += [PSCustomObject]@{
                            Tool = $dep
                            Status = "✓ Found"
                            Version = $version
                        }
                } catch {
                        $depStatus += [PSCustomObject]@{
                            Tool = $dep
                            Status = "✗ Not Found"
                            Version = "N/A"
                        }
                }
            }

                Show-UITable -Data $depStatus -Title "Dependencies"
                Show-UIPrompt -Message "Press Enter to continue" | Out-Null
            }

            'Run Single Script' {
                # Allow direct 4-digit script number input or category selection
                Write-UIText "Script Execution Options:" -Color 'Cyan'
                Write-UIText "1. Enter a 4-digit script number directly (e.g., 0402)" -Color 'Info'
                Write-UIText "2. Browse by category" -Color 'Info'
                Write-UIText "3. Search by keyword" -Color 'Info'
                Write-UIText ""

                $scriptInput = Show-UIPrompt -Message "Enter script number, keyword, or press Enter for categories"

                $scriptsPath = Join-Path $script:ProjectRoot "automation-scripts"
                $selected = $null

                if ($scriptInput -match '^\d{4}$') {
                    # Direct script number entered
                    $scriptFile = Get-ChildItem $scriptsPath -Filter "${scriptInput}_*.ps1" | Select-Object -First 1
                    if ($scriptFile) {
                        $selected = [PSCustomObject]@{
                            Name = $scriptFile.Name
                            Description = $scriptFile.Name -replace '^\d{4}_' -replace '\.ps1$' -replace '-', ' '
                        }
                    } else {
                        Show-UINotification -Message "Script $scriptInput not found" -Type 'Warning'
                    }
                } elseif ($scriptInput -and $scriptInput -notmatch '^\d{4}$') {
                    # Search by keyword
                    $scripts = Get-ChildItem $scriptsPath -Filter "*.ps1" |
                        Where-Object { $_.Name -match '^\d{4}_' -and $_.Name -like "*$scriptInput*" } |
                        ForEach-Object {
                            [PSCustomObject]@{
                                Name = $_.Name
                                Description = $_.Name -replace '^\d{4}_' -replace '\.ps1$' -replace '-', ' '
                            }
                        }

                    if ($scripts.Count -eq 0) {
                        Show-UINotification -Message "No scripts found matching '$scriptInput'" -Type 'Warning'
                    } elseif ($scripts.Count -eq 1) {
                        $selected = $scripts[0]
                    } else {
                        $selected = Show-UIMenu -Title "Scripts matching '$scriptInput'" -Items $scripts -ShowNumbers
                    }
                } else {
                    # Browse by category
                    $categories = @(
                        [PSCustomObject]@{ Name = "0000-0099 - Environment & Cleanup"; Range = "00" }
                        [PSCustomObject]@{ Name = "0100-0199 - Infrastructure"; Range = "01" }
                        [PSCustomObject]@{ Name = "0200-0299 - Development Tools"; Range = "02" }
                        [PSCustomObject]@{ Name = "0300-0399 - Deployment"; Range = "03" }
                        [PSCustomObject]@{ Name = "0400-0499 - Testing & Validation"; Range = "04" }
                        [PSCustomObject]@{ Name = "0500-0599 - Reporting & Metrics"; Range = "05" }
                        [PSCustomObject]@{ Name = "0600-0699 - Monitoring"; Range = "06" }
                        [PSCustomObject]@{ Name = "0700-0799 - Git & Development"; Range = "07" }
                        [PSCustomObject]@{ Name = "0800-0899 - Session & Issues"; Range = "08" }
                        [PSCustomObject]@{ Name = "9000-9999 - Maintenance"; Range = "9" }
                        [PSCustomObject]@{ Name = "Show All Scripts"; Range = "all" }
                    )

                    $categorySelection = Show-UIMenu -Title "Select Category" -Items $categories -ShowNumbers

                    if ($categorySelection) {
                        $scripts = if ($categorySelection.Range -eq "all") {
                            Get-ChildItem $scriptsPath -Filter "*.ps1" |
                                Where-Object { $_.Name -match '^\d{4}_' }
                        } else {
                            Get-ChildItem $scriptsPath -Filter "*.ps1" |
                                Where-Object { $_.Name -match "^$($categorySelection.Range)\d{2}_" }
                        }

                        $scripts = $scripts | ForEach-Object {
                            [PSCustomObject]@{
                                Name = $_.Name
                                Description = $_.Name -replace '^\d{4}_' -replace '\.ps1$' -replace '-', ' '
                            }
                        }

                        if ($scripts.Count -eq 0) {
                            Show-UINotification -Message "No scripts found in this category" -Type 'Warning'
                        } else {
                            $selected = Show-UIMenu -Title "Select Script from $($categorySelection.Name)" -Items $scripts -ShowNumbers
                        }
                    }
                }

                if ($selected) {
                    $confirm = Show-UIPrompt -Message "Execute $($selected.Name)?" -ValidateSet @('Yes', 'No') -DefaultValue 'No'
                    if ($confirm -eq 'Yes') {
                        $scriptPath = Join-Path $scriptsPath $selected.Name
                        # Execute directly without Show-UISpinner to avoid variable scope issues
                        Write-UIText "Executing $($selected.Name)..." -Color 'Info'
                        & $scriptPath -Configuration $Config
                        Write-UIText "Execution completed" -Color 'Success'
                }
            }
        }

            'Module Manager' {
                Show-UINotification -Message "Scanning for modules..." -Type 'Info'

                $modules = Get-ChildItem (Join-Path $script:ProjectRoot "domains") -Recurse -Filter "*.psm1" |
                    ForEach-Object {
                        $loaded = Get-Module -Name $_.BaseName -ErrorAction SilentlyContinue
                        [PSCustomObject]@{
                            Name = $_.BaseName
                            Path = $_.FullName.Replace($script:ProjectRoot, '.')
                            Status = if ($loaded) { "Loaded" } else { "Not Loaded" }
                        }
                }

                Show-UITable -Data $modules -Title "Domain Modules"

                $action = Show-UIPrompt -Message "Action" -ValidateSet @('Import All', 'Reload All', 'Cancel') -DefaultValue 'Cancel'

                if ($action -ne 'Cancel') {
                    $modules | ForEach-Object {
                        try {
                            Import-Module $_.Path.Replace('.', $script:ProjectRoot) -Force -Global
                            Write-UIText "  ✓ $($_.Name)" -Color 'Success'
                        } catch {
                            Write-UIText "  ✗ $($_.Name): $_" -Color 'Error'
                        }
                }
            }
        }
    }

        Show-UIPrompt -Message "Press Enter to continue" | Out-Null
    }
}

# Main execution
try {
    # Initialize
    if (-not $NonInteractive) {
        Show-Banner
    }

    $modules = Initialize-CoreModules

    # Check if UI module loaded successfully
    if (-not $modules.UI) {
        $errorMsg = "Failed to load UI module. Cannot continue in interactive mode."

        # Log the error if logging is available
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Level 'Error' -Message $errorMsg -Source "Start-AitherZero" -Data @{
                Mode = $Mode
                ModulesLoaded = $modules
            }
        }

        Write-Error $errorMsg
        if ($Mode -eq 'Interactive') {
            exit 1
        }
    }

    $config = Get-AitherConfiguration -Path $ConfigPath

    # Handle different modes
    switch ($Mode) {
        'Interactive' {
            if ($NonInteractive) {
                Write-Warning "Cannot run interactive mode with -NonInteractive flag"
                exit 1
            }
        Show-InteractiveMenu -Config $config
        }

        'Orchestrate' {
            if (-not $Sequence -and -not $Playbook) {
                Write-Error "Orchestrate mode requires -Sequence or -Playbook parameter"
                exit 1
            }

            # Ensure orchestration module is loaded
            if (-not (Get-Command Invoke-OrchestrationSequence -ErrorAction SilentlyContinue)) {
                Write-Error "Orchestration module not loaded. Environment initialization may have failed."
                exit 1
            }

            # Use passed Variables parameter or create empty hashtable
            if (-not $Variables) {
                $variables = @{}
            } else {
                $variables = $Variables
            }
            if ($CI) { $variables['CI'] = $true }

            if ($Playbook) {
                $params = @{
                    LoadPlaybook = $Playbook
                    Configuration = $config
                    Variables = $variables
                    DryRun = $DryRun
                }
            if ($PlaybookProfile) {
                    $params['PlaybookProfile'] = $PlaybookProfile
                }
            if ($Sequential) {
                    $params['Parallel'] = $false
                }
            if ($Parallel) {
                    $params['Parallel'] = $true
                }
            $result = Invoke-OrchestrationSequence @params
            } else {
                $result = Invoke-OrchestrationSequence -Sequence $Sequence -Configuration $config -Variables $variables -DryRun:$DryRun
            }

            # Exit with appropriate code
            if ($result.Failed -gt 0) {
                exit 1
            }
    }

        'Validate' {
            & (Join-Path $script:ProjectRoot "automation-scripts/0500_Validate-Environment.ps1") -Configuration $config
        }

        'Deploy' {
            # Ensure orchestration module is loaded
            if (-not (Get-Command Invoke-OrchestrationSequence -ErrorAction SilentlyContinue)) {
                Write-Error "Orchestration module not loaded. Environment initialization may have failed."
                exit 1
            }

            $result = Invoke-OrchestrationSequence -Sequence "0105,0008,0300" -Configuration $config -DryRun:$DryRun

            if ($result.Failed -gt 0) {
                exit 1
            }
        }

        'Test' {
            # Ensure orchestration module is loaded
            if (-not (Get-Command Invoke-OrchestrationSequence -ErrorAction SilentlyContinue)) {
                Write-Error "Orchestration module not loaded. Environment initialization may have failed."
                exit 1
            }

            # Default test sequence - unit tests, PSScriptAnalyzer, and syntax validation
            $testSequence = if ($Sequence) { $Sequence } else { @("0402", "0404", "0407") }

            Write-Host "Running tests with sequence: $($testSequence -join ',')" -ForegroundColor Cyan

            $result = Invoke-OrchestrationSequence -Sequence $testSequence -Configuration $config -DryRun:$DryRun

            if ($result.Failed -gt 0) {
                Write-Host "`nTest run completed with $($result.Failed) failures" -ForegroundColor Red
                exit 1
            } else {
                Write-Host "`nAll tests passed successfully!" -ForegroundColor Green
            }
        }
    }

} catch {
    $errorMessage = "Fatal error in Start-AitherZero"
    $errorDetails = @{
        Message = $_.Exception.Message
        Type = $_.Exception.GetType().FullName
        StackTrace = $_.ScriptStackTrace
        InvocationInfo = $_.InvocationInfo | ConvertTo-Json -Compress
        TargetObject = $_.TargetObject
    }

    # Try to log if logging is available
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level 'Critical' -Message $errorMessage -Source "Start-AitherZero" -Data $errorDetails
    }

    # Always write to console
    Write-Host "`n[CRITICAL ERROR]" -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "Location: $($_.InvocationInfo.PositionMessage)" -ForegroundColor Red

    if ($VerbosePreference -eq 'Continue' -or $DebugPreference -eq 'Continue') {
        Write-Host "`nStack Trace:" -ForegroundColor Yellow
        Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
    }

    exit 1
}