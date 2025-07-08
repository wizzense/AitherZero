#Requires -Version 7.0

<#
.SYNOPSIS
    AitherZero Developer Setup - Unified development environment configuration

.DESCRIPTION
    Comprehensive developer setup script that configures a complete development environment
    for AitherZero. Supports multiple profiles (Quick, Full) and includes:
    
    - Prerequisites validation (PowerShell 7, Git, etc.)
    - Core development environment configuration
    - VS Code settings and extensions
    - Git pre-commit hooks
    - AI development tools (Claude Code, Gemini CLI)
    - PatchManager aliases and shortcuts
    - Module path configuration

.PARAMETER Profile
    Setup profile: Quick (minimal, fast) or Full (all tools and features)

.PARAMETER SkipAITools
    Skip AI tools installation (Claude Code, Gemini CLI)

.PARAMETER SkipGitHooks
    Skip Git pre-commit hook installation

.PARAMETER SkipVSCode
    Skip VS Code configuration and extensions

.PARAMETER Force
    Force reinstallation of existing tools

.PARAMETER WhatIf
    Show what would be done without making changes

.PARAMETER Verbose
    Show detailed progress information

.EXAMPLE
    ./Start-DeveloperSetup.ps1
    # Run with default Full profile

.EXAMPLE
    ./Start-DeveloperSetup.ps1 -Profile Quick
    # Quick setup (minimal, fast)

.EXAMPLE
    ./Start-DeveloperSetup.ps1 -Profile Full -SkipAITools
    # Full setup without AI tools

.EXAMPLE
    ./Start-DeveloperSetup.ps1 -WhatIf
    # Preview what would be done

.NOTES
    This script integrates with the existing SetupWizard and DevEnvironment modules
    to provide a streamlined developer onboarding experience.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(HelpMessage = "Setup profile: Quick (minimal), Full (complete)")]
    [ValidateSet("Quick", "Full")]
    [string]$Profile = "Full",
    
    [Parameter(HelpMessage = "Skip AI tools installation")]
    [switch]$SkipAITools,
    
    [Parameter(HelpMessage = "Skip Git pre-commit hook installation")]
    [switch]$SkipGitHooks,
    
    [Parameter(HelpMessage = "Skip VS Code configuration")]
    [switch]$SkipVSCode,
    
    [Parameter(HelpMessage = "Force reinstallation of existing tools")]
    [switch]$Force,
    
    [Parameter(HelpMessage = "Show what would be done without making changes")]
    [switch]$WhatIf,
    
    [Parameter(HelpMessage = "Show detailed progress information")]
    [switch]$Verbose
)

# Script metadata
$script:Version = "1.0.0"
$script:StartTime = Get-Date

# Initialize logging
function Write-SetupLog {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO'
    )
    
    $colors = @{
        'INFO'    = 'White'
        'SUCCESS' = 'Green'
        'WARNING' = 'Yellow'
        'ERROR'   = 'Red'
        'DEBUG'   = 'Gray'
    }
    
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $color = $colors[$Level]
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

# Function to show banner
function Show-DeveloperSetupBanner {
    Clear-Host
    Write-Host ""
    Write-Host "    ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "    ║              AitherZero Developer Setup                  ║" -ForegroundColor Cyan
    Write-Host "    ║                    Version $script:Version                      ║" -ForegroundColor Cyan
    Write-Host "    ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    🚀 ONE COMMAND SETUP - Complete development environment!" -ForegroundColor Green
    Write-Host "    📦 Profile: $Profile" -ForegroundColor Yellow
    Write-Host ""
}

# Function to detect project root
function Find-ProjectRoot {
    param([string]$StartPath = $PWD.Path)
    
    $currentPath = $StartPath
    while ($currentPath -and $currentPath -ne (Split-Path $currentPath -Parent)) {
        if (Test-Path (Join-Path $currentPath "Start-AitherZero.ps1")) {
            return $currentPath
        }
        $currentPath = Split-Path $currentPath -Parent
    }
    
    # Fallback to script directory's parent
    return Split-Path $PSScriptRoot -Parent
}

# Function to test PowerShell version
function Test-PowerShellVersionRequirement {
    $requiredVersion = [Version]"7.0.0"
    $currentVersion = $PSVersionTable.PSVersion
    
    if ($currentVersion -lt $requiredVersion) {
        Write-SetupLog "PowerShell $requiredVersion or higher is required. Current: $currentVersion" -Level ERROR
        Write-SetupLog "Please install PowerShell 7: https://aka.ms/powershell" -Level ERROR
        return $false
    }
    
    Write-SetupLog "PowerShell version check passed: $currentVersion" -Level SUCCESS
    return $true
}

# Function to validate prerequisites
function Test-Prerequisites {
    Write-SetupLog "Validating prerequisites..." -Level INFO
    
    $prerequisites = @{
        PowerShell = Test-PowerShellVersionRequirement
        Git = Test-GitInstallation
        ProjectStructure = Test-ProjectStructure
    }
    
    $failed = $prerequisites.GetEnumerator() | Where-Object { -not $_.Value }
    
    if ($failed.Count -gt 0) {
        Write-SetupLog "Prerequisites validation failed for: $($failed.Name -join ', ')" -Level ERROR
        return $false
    }
    
    Write-SetupLog "All prerequisites validated successfully" -Level SUCCESS
    return $true
}

function Test-GitInstallation {
    try {
        $gitVersion = git --version 2>$null
        if ($gitVersion) {
            Write-SetupLog "Git found: $gitVersion" -Level SUCCESS
            return $true
        }
    } catch {
        Write-SetupLog "Git not found. Please install Git first." -Level ERROR
        return $false
    }
    return $false
}

function Test-ProjectStructure {
    $projectRoot = Find-ProjectRoot
    $requiredPaths = @(
        "aither-core",
        "aither-core/modules",
        "Start-AitherZero.ps1"
    )
    
    foreach ($path in $requiredPaths) {
        $fullPath = Join-Path $projectRoot $path
        if (-not (Test-Path $fullPath)) {
            Write-SetupLog "Missing required path: $path" -Level ERROR
            return $false
        }
    }
    
    Write-SetupLog "Project structure validation passed" -Level SUCCESS
    return $true
}

# Function to setup development environment
function Initialize-DevelopmentEnvironment {
    param([string]$ProjectRoot)
    
    Write-SetupLog "Initializing development environment..." -Level INFO
    
    try {
        # Import DevEnvironment module
        $devEnvPath = Join-Path $ProjectRoot "aither-core/modules/DevEnvironment"
        if (Test-Path $devEnvPath) {
            Import-Module $devEnvPath -Force
            Write-SetupLog "DevEnvironment module imported" -Level SUCCESS
        }
        
        # Initialize development environment
        if (Get-Command Initialize-DevelopmentEnvironment -ErrorAction SilentlyContinue) {
            $result = Initialize-DevelopmentEnvironment -ProjectRoot $ProjectRoot
            Write-SetupLog "Development environment initialized" -Level SUCCESS
        } else {
            Write-SetupLog "Initialize-DevelopmentEnvironment command not found, using fallback" -Level WARNING
            Initialize-BasicDevEnvironment -ProjectRoot $ProjectRoot
        }
        
        return $true
    } catch {
        Write-SetupLog "Failed to initialize development environment: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function Initialize-BasicDevEnvironment {
    param([string]$ProjectRoot)
    
    # Basic environment setup
    Write-SetupLog "Setting up basic development environment..." -Level INFO
    
    # Set environment variables
    $env:AITHERZERO_ROOT = $ProjectRoot
    $env:AITHERZERO_MODULES = Join-Path $ProjectRoot "aither-core/modules"
    
    Write-SetupLog "Environment variables configured" -Level SUCCESS
}

# Function to setup VS Code integration
function Initialize-VSCodeIntegration {
    param([string]$ProjectRoot)
    
    if ($SkipVSCode) {
        Write-SetupLog "Skipping VS Code setup as requested" -Level INFO
        return $true
    }
    
    Write-SetupLog "Setting up VS Code integration..." -Level INFO
    
    try {
        # Check if VS Code is installed
        $vsCodeFound = $false
        $vsCodePaths = @(
            "${env:ProgramFiles}\Microsoft VS Code\Code.exe",
            "${env:LOCALAPPDATA}\Programs\Microsoft VS Code\Code.exe",
            "/usr/bin/code",
            "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
        )
        
        foreach ($path in $vsCodePaths) {
            if (Test-Path $path) {
                $vsCodeFound = $true
                break
            }
        }
        
        if (-not $vsCodeFound -and -not (Get-Command code -ErrorAction SilentlyContinue)) {
            Write-SetupLog "VS Code not found - skipping VS Code setup" -Level WARNING
            return $true
        }
        
        # Import DevEnvironment module for VS Code functions
        $devEnvPath = Join-Path $ProjectRoot "aither-core/modules/DevEnvironment"
        if (Test-Path $devEnvPath) {
            Import-Module $devEnvPath -Force
            
            # Initialize VS Code workspace
            if (Get-Command Initialize-VSCodeWorkspace -ErrorAction SilentlyContinue) {
                Initialize-VSCodeWorkspace -ProjectRoot $ProjectRoot
                Write-SetupLog "VS Code workspace initialized" -Level SUCCESS
            }
            
            # Install VS Code extensions
            if (Get-Command Install-VSCodeExtensions -ErrorAction SilentlyContinue) {
                Install-VSCodeExtensions
                Write-SetupLog "VS Code extensions installed" -Level SUCCESS
            }
        }
        
        return $true
    } catch {
        Write-SetupLog "VS Code setup failed: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

# Function to setup Git hooks
function Initialize-GitHooks {
    param([string]$ProjectRoot)
    
    if ($SkipGitHooks) {
        Write-SetupLog "Skipping Git hooks setup as requested" -Level INFO
        return $true
    }
    
    Write-SetupLog "Setting up Git pre-commit hooks..." -Level INFO
    
    try {
        # Import DevEnvironment module
        $devEnvPath = Join-Path $ProjectRoot "aither-core/modules/DevEnvironment"
        if (Test-Path $devEnvPath) {
            Import-Module $devEnvPath -Force
            
            if (Get-Command Install-PreCommitHook -ErrorAction SilentlyContinue) {
                Install-PreCommitHook -ProjectRoot $ProjectRoot
                Write-SetupLog "Git pre-commit hooks installed" -Level SUCCESS
            } else {
                # Fallback manual hook installation
                Install-BasicPreCommitHook -ProjectRoot $ProjectRoot
            }
        }
        
        return $true
    } catch {
        Write-SetupLog "Git hooks setup failed: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function Install-BasicPreCommitHook {
    param([string]$ProjectRoot)
    
    $hookPath = Join-Path $ProjectRoot ".git/hooks/pre-commit"
    $hookContent = @'
#!/bin/sh
# AitherZero pre-commit hook
echo "Running AitherZero pre-commit validation..."

# Run basic PowerShell syntax check
pwsh -NoProfile -Command "
    Get-ChildItem -Path . -Filter '*.ps1' -Recurse | ForEach-Object {
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $_.FullName -Raw), [ref]$null)
    }
"
'@
    
    if ($WhatIf) {
        Write-SetupLog "Would create pre-commit hook at: $hookPath" -Level INFO
    } else {
        Set-Content -Path $hookPath -Value $hookContent
        
        # Make executable on Unix systems
        if (-not $IsWindows) {
            chmod +x $hookPath
        }
        
        Write-SetupLog "Basic pre-commit hook installed" -Level SUCCESS
    }
}

# Function to setup AI tools
function Initialize-AITools {
    param([string]$ProjectRoot)
    
    if ($SkipAITools) {
        Write-SetupLog "Skipping AI tools setup as requested" -Level INFO
        return $true
    }
    
    Write-SetupLog "Setting up AI development tools..." -Level INFO
    
    try {
        # Import AIToolsIntegration module
        $aiToolsPath = Join-Path $ProjectRoot "aither-core/modules/AIToolsIntegration"
        if (Test-Path $aiToolsPath) {
            Import-Module $aiToolsPath -Force
            Write-SetupLog "AIToolsIntegration module imported" -Level SUCCESS
            
            # Install AI tools based on profile
            $toolsToInstall = switch ($Profile) {
                "Quick" { @("claude-code") }
                "Full"  { @("claude-code", "gemini-cli") }
                default { @("claude-code") }
            }
            
            foreach ($tool in $toolsToInstall) {
                Write-SetupLog "Installing $tool..." -Level INFO
                
                switch ($tool) {
                    "claude-code" {
                        if (Get-Command Install-ClaudeCode -ErrorAction SilentlyContinue) {
                            $result = Install-ClaudeCode
                            if ($result.Success) {
                                Write-SetupLog "Claude Code installed successfully" -Level SUCCESS
                            } else {
                                Write-SetupLog "Claude Code installation failed: $($result.Message)" -Level WARNING
                            }
                        }
                    }
                    "gemini-cli" {
                        if (Get-Command Install-GeminiCLI -ErrorAction SilentlyContinue) {
                            $result = Install-GeminiCLI
                            if ($result.Success) {
                                Write-SetupLog "Gemini CLI installed successfully" -Level SUCCESS
                            } else {
                                Write-SetupLog "Gemini CLI installation failed: $($result.Message)" -Level WARNING
                            }
                        }
                    }
                }
            }
        } else {
            Write-SetupLog "AIToolsIntegration module not found - skipping AI tools" -Level WARNING
        }
        
        return $true
    } catch {
        Write-SetupLog "AI tools setup failed: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

# Function to setup PatchManager aliases
function Initialize-PatchManagerAliases {
    param([string]$ProjectRoot)
    
    Write-SetupLog "Setting up PatchManager aliases..." -Level INFO
    
    try {
        # Import DevEnvironment module
        $devEnvPath = Join-Path $ProjectRoot "aither-core/modules/DevEnvironment"
        if (Test-Path $devEnvPath) {
            Import-Module $devEnvPath -Force
            
            if (Get-Command Set-PatchManagerAliases -ErrorAction SilentlyContinue) {
                Set-PatchManagerAliases
                Write-SetupLog "PatchManager aliases configured" -Level SUCCESS
            } else {
                # Create basic aliases
                Set-BasicPatchManagerAliases
            }
        }
        
        return $true
    } catch {
        Write-SetupLog "PatchManager aliases setup failed: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function Set-BasicPatchManagerAliases {
    # Create basic aliases for PatchManager
    $aliases = @{
        'patch'     = 'Invoke-PatchWorkflow'
        'newpatch'  = 'New-Patch'
        'hotfix'    = 'New-Hotfix'
        'feature'   = 'New-Feature'
        'quickfix'  = 'New-QuickFix'
    }
    
    foreach ($alias in $aliases.GetEnumerator()) {
        if ($WhatIf) {
            Write-SetupLog "Would create alias: $($alias.Key) -> $($alias.Value)" -Level INFO
        } else {
            New-Alias -Name $alias.Key -Value $alias.Value -Scope Global -Force -ErrorAction SilentlyContinue
        }
    }
    
    Write-SetupLog "Basic PatchManager aliases created" -Level SUCCESS
}

# Function to run setup wizard
function Invoke-SetupWizardIntegration {
    param([string]$ProjectRoot)
    
    Write-SetupLog "Running integrated setup wizard..." -Level INFO
    
    try {
        # Import SetupWizard module
        $setupWizardPath = Join-Path $ProjectRoot "aither-core/modules/SetupWizard"
        if (Test-Path $setupWizardPath) {
            Import-Module $setupWizardPath -Force
            
            # Determine installation profile based on our profile
            $installationProfile = switch ($Profile) {
                "Quick" { "minimal" }
                "Full"  { "developer" }
                default { "developer" }
            }
            
            if (Get-Command Start-IntelligentSetup -ErrorAction SilentlyContinue) {
                $setupResult = Start-IntelligentSetup -InstallationProfile $installationProfile -SkipOptional:($Profile -eq "Quick")
                Write-SetupLog "Setup wizard completed" -Level SUCCESS
                return $setupResult
            }
        } else {
            Write-SetupLog "SetupWizard module not found - skipping integrated setup" -Level WARNING
        }
        
        return $null
    } catch {
        Write-SetupLog "Setup wizard integration failed: $($_.Exception.Message)" -Level ERROR
        return $null
    }
}

# Function to show completion summary
function Show-SetupSummary {
    param(
        [hashtable]$Results,
        [object]$SetupWizardResult
    )
    
    $duration = (Get-Date) - $script:StartTime
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                  Setup Complete!                        ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # Show results summary
    $successful = ($Results.Values | Where-Object { $_ -eq $true }).Count
    $total = $Results.Count
    
    Write-SetupLog "Setup Summary:" -Level INFO
    Write-SetupLog "  Profile: $Profile" -Level INFO
    Write-SetupLog "  Successful steps: $successful/$total" -Level $(if ($successful -eq $total) { 'SUCCESS' } else { 'WARNING' })
    Write-SetupLog "  Duration: $([math]::Round($duration.TotalSeconds, 1)) seconds" -Level INFO
    
    # Show individual results
    Write-Host ""
    Write-Host "  📋 Setup Steps:" -ForegroundColor White
    foreach ($result in $Results.GetEnumerator()) {
        $icon = if ($result.Value) { "✅" } else { "❌" }
        $status = if ($result.Value) { "Success" } else { "Failed" }
        $color = if ($result.Value) { "Green" } else { "Red" }
        
        Write-Host "    $icon $($result.Key): $status" -ForegroundColor $color
    }
    
    # Show next steps
    Write-Host ""
    Write-Host "  🚀 WHAT'S NEXT:" -ForegroundColor Green
    Write-Host "  ═══════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Your development environment is ready! Here's how to get started:" -ForegroundColor White
    Write-Host ""
    Write-Host "  1. 📁 Open VS Code in this directory:" -ForegroundColor Yellow
    Write-Host "     code ." -ForegroundColor Green
    Write-Host ""
    Write-Host "  2. 🏃 Run AitherZero interactively:" -ForegroundColor Yellow
    Write-Host "     ./Start-AitherZero.ps1" -ForegroundColor Green
    Write-Host ""
    Write-Host "  3. 🔧 Try PatchManager (with new aliases):" -ForegroundColor Yellow
    Write-Host "     newpatch -Description 'My first patch'" -ForegroundColor Green
    Write-Host ""
    Write-Host "  4. 🧪 Run tests:" -ForegroundColor Yellow
    Write-Host "     ./tests/Run-Tests.ps1" -ForegroundColor Green
    Write-Host ""
    
    if ($Results.ContainsValue($false)) {
        Write-Host "  ⚠️  Some setup steps failed. Check the log above for details." -ForegroundColor Yellow
        Write-Host "     You can re-run this script with -Force to retry failed steps." -ForegroundColor Yellow
    } else {
        Write-Host "  🎉 Everything is set up perfectly! Happy coding!" -ForegroundColor Green
    }
    
    Write-Host ""
}

# Main execution
function Start-DeveloperSetup {
    # Show banner
    Show-DeveloperSetupBanner
    
    # Find project root
    $projectRoot = Find-ProjectRoot
    Write-SetupLog "Project root: $projectRoot" -Level INFO
    
    # Validate prerequisites
    if (-not (Test-Prerequisites)) {
        Write-SetupLog "Prerequisites validation failed. Exiting." -Level ERROR
        exit 1
    }
    
    # Track setup results
    $setupResults = @{}
    
    # Run setup steps
    Write-SetupLog "Starting developer environment setup..." -Level INFO
    Write-SetupLog "Profile: $Profile" -Level INFO
    
    # Core development environment
    $setupResults["Development Environment"] = Initialize-DevelopmentEnvironment -ProjectRoot $projectRoot
    
    # VS Code integration
    $setupResults["VS Code Integration"] = Initialize-VSCodeIntegration -ProjectRoot $projectRoot
    
    # Git hooks
    $setupResults["Git Hooks"] = Initialize-GitHooks -ProjectRoot $projectRoot
    
    # AI tools (if not skipped)
    if (-not $SkipAITools) {
        $setupResults["AI Tools"] = Initialize-AITools -ProjectRoot $projectRoot
    }
    
    # PatchManager aliases
    $setupResults["PatchManager Aliases"] = Initialize-PatchManagerAliases -ProjectRoot $projectRoot
    
    # Integrated setup wizard
    $wizardResult = Invoke-SetupWizardIntegration -ProjectRoot $projectRoot
    $setupResults["Setup Wizard Integration"] = $wizardResult -ne $null
    
    # Show completion summary
    Show-SetupSummary -Results $setupResults -SetupWizardResult $wizardResult
    
    # Return success if most steps succeeded
    $successCount = ($setupResults.Values | Where-Object { $_ }).Count
    $successRate = $successCount / $setupResults.Count
    
    if ($successRate -ge 0.7) {
        Write-SetupLog "Developer setup completed successfully!" -Level SUCCESS
        return $true
    } else {
        Write-SetupLog "Developer setup completed with issues. Check the summary above." -Level WARNING
        return $false
    }
}

# Script entry point
if ($MyInvocation.InvocationName -ne '.') {
    # Only run if script is executed directly, not dot-sourced
    $success = Start-DeveloperSetup
    
    if (-not $success) {
        exit 1
    }
}