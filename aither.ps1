#!/usr/bin/env pwsh
<#
.SYNOPSIS
    AitherZero - Modern Infrastructure Automation CLI

.DESCRIPTION
    Unified command-line interface for AitherZero infrastructure automation.
    Provides a clean, modern CLI experience with consistent commands and behavior.

.PARAMETER Command
    The main command to execute (init, deploy, workflow, dev, config, plugin, server, help)

.PARAMETER SubCommand
    The sub-command within the main command

.PARAMETER Arguments
    Additional arguments passed to the command

.EXAMPLE
    ./aither.ps1 init
    Initialize AitherZero with interactive setup

.EXAMPLE
    ./aither.ps1 deploy plan ./infrastructure
    Plan infrastructure deployment

.EXAMPLE
    ./aither.ps1 dev release patch "Fix authentication bug"
    Create a patch release with automated workflow

.EXAMPLE
    ./aither.ps1 help
    Show comprehensive help information

.NOTES
    AitherZero v2.0 - Unified CLI Interface
    This is the bridge solution that provides modern CLI UX while leveraging existing modules.
#>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [ValidateSet('init', 'deploy', 'workflow', 'dev', 'config', 'plugin', 'server', 'help', '')]
    [string]$Command = 'help',
    
    [Parameter(Position=1)]
    [string]$SubCommand = '',
    
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Arguments = @()
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Get script directory and project root
$script:ScriptDir = $PSScriptRoot
$script:ProjectRoot = $PSScriptRoot

# Import core utilities
. "$PSScriptRoot/aither-core/shared/Find-ProjectRoot.ps1"
$script:ProjectRoot = Find-ProjectRoot

# Global configuration
$script:Config = @{
    Version = "2.0.0-preview"
    ProjectRoot = $script:ProjectRoot
    ModulesPath = Join-Path $script:ProjectRoot "aither-core/modules"
    Debug = $false
}

# Color scheme for consistent output
$script:Colors = @{
    Primary = 'Cyan'
    Success = 'Green'
    Warning = 'Yellow'
    Error = 'Red'
    Info = 'Blue'
    Muted = 'DarkGray'
}

function Write-AitherMessage {
    param(
        [string]$Message,
        [ValidateSet('Primary', 'Success', 'Warning', 'Error', 'Info', 'Muted')]
        [string]$Type = 'Info'
    )
    
    $color = $script:Colors[$Type]
    Write-Host $Message -ForegroundColor $color
}

function Write-AitherHeader {
    param([string]$Title)
    
    Write-Host ""
    Write-AitherMessage "AitherZero v$($script:Config.Version) - $Title" -Type Primary
    Write-AitherMessage ("=" * 50) -Type Muted
    Write-Host ""
}

function Show-AitherHelp {
    Write-AitherHeader "Infrastructure Automation CLI"
    
    Write-AitherMessage "USAGE:" -Type Info
    Write-Host "  aither [command] [subcommand] [options]"
    Write-Host ""
    
    Write-AitherMessage "COMMANDS:" -Type Info
    
    $commands = @(
        @{Name = "init"; Description = "Initialize AitherZero (first-time setup)"}
        @{Name = "deploy"; Description = "Infrastructure deployment (OpenTofu/Terraform)"}
        @{Name = "workflow"; Description = "Orchestration and playbook execution"}
        @{Name = "dev"; Description = "Development workflow automation"}
        @{Name = "config"; Description = "Configuration management"}
        @{Name = "plugin"; Description = "Plugin management"}
        @{Name = "server"; Description = "REST API server mode"}
        @{Name = "help"; Description = "Show help information"}
    )
    
    foreach ($cmd in $commands) {
        $nameFormatted = $cmd.Name.PadRight(12)
        Write-Host "  $nameFormatted $($cmd.Description)" -ForegroundColor White
    }
    
    Write-Host ""
    Write-AitherMessage "EXAMPLES:" -Type Info
    Write-Host "  aither init                              # Interactive setup"
    Write-Host "  aither deploy plan ./infrastructure      # Plan deployment"
    Write-Host "  aither deploy apply --auto-approve       # Apply with auto-approval"
    Write-Host "  aither workflow run deployment.yaml      # Execute workflow"
    Write-Host "  aither dev release patch 'Bug fix'       # Create patch release"
    Write-Host "  aither config switch production          # Switch to prod config"
    Write-Host "  aither server start --port 8080          # Start API server"
    Write-Host ""
    
    Write-AitherMessage "For detailed help on any command, use: aither [command] help" -Type Muted
}

function Invoke-AitherInit {
    param([string[]]$Args)
    
    Write-AitherHeader "Initialize AitherZero"
    
    # Parse arguments
    $interactive = $true
    $profile = "standard"
    
    for ($i = 0; $i -lt $Args.Count; $i++) {
        switch ($Args[$i]) {
            '--auto' { $interactive = $false }
            '--profile' { 
                if ($i + 1 -lt $Args.Count) {
                    $profile = $Args[$i + 1]
                    $i++
                }
            }
            'help' { 
                Show-InitHelp
                return
            }
        }
    }
    
    try {
        # Load SetupWizard module
        $setupWizardPath = Join-Path $script:Config.ModulesPath "SetupWizard"
        if (Test-Path $setupWizardPath) {
            Import-Module $setupWizardPath -Force
            
            if ($interactive) {
                Write-AitherMessage "Starting interactive setup..." -Type Info
                $result = Start-IntelligentSetup
            } else {
                Write-AitherMessage "Starting automated setup with profile: $profile" -Type Info
                $result = Start-IntelligentSetup -MinimalSetup -SkipOptional
            }
            
            if ($result) {
                Write-AitherMessage "✅ AitherZero initialized successfully!" -Type Success
                Write-AitherMessage "Next steps:" -Type Info
                Write-Host "  1. Try: aither deploy create my-first-project"
                Write-Host "  2. Or: aither workflow list"
                Write-Host "  3. For help: aither help"
            }
        } else {
            Write-AitherMessage "❌ SetupWizard module not found. Please run ./Start-AitherZero.ps1 -Setup first." -Type Error
        }
    } catch {
        Write-AitherMessage "❌ Setup failed: $($_.Exception.Message)" -Type Error
        Write-AitherMessage "Try running: ./Start-AitherZero.ps1 -Setup" -Type Info
    }
}

function Invoke-AitherDeploy {
    param([string]$SubCmd, [string[]]$Args)
    
    Write-AitherHeader "Infrastructure Deployment"
    
    switch ($SubCmd) {
        'plan' { Invoke-DeployPlan $Args }
        'apply' { Invoke-DeployApply $Args }
        'destroy' { Invoke-DeployDestroy $Args }
        'state' { Invoke-DeployState $Args }
        'create' { Invoke-DeployCreate $Args }
        'help' { Show-DeployHelp }
        default { 
            Write-AitherMessage "❌ Unknown subcommand: $SubCmd" -Type Error
            Write-AitherMessage "Use 'aither deploy help' for available commands" -Type Info
        }
    }
}

function Invoke-AitherWorkflow {
    param([string]$SubCmd, [string[]]$Args)
    
    Write-AitherHeader "Workflow Orchestration"
    
    switch ($SubCmd) {
        'run' { Invoke-WorkflowRun $Args }
        'list' { Invoke-WorkflowList $Args }
        'status' { Invoke-WorkflowStatus $Args }
        'create' { Invoke-WorkflowCreate $Args }
        'help' { Show-WorkflowHelp }
        default { 
            Write-AitherMessage "❌ Unknown subcommand: $SubCmd" -Type Error
            Write-AitherMessage "Use 'aither workflow help' for available commands" -Type Info
        }
    }
}

function Invoke-AitherDev {
    param([string]$SubCmd, [string[]]$Args)
    
    Write-AitherHeader "Development Workflow"
    
    switch ($SubCmd) {
        'release' { Invoke-DevRelease $Args }
        'pr' { Invoke-DevPR $Args }
        'setup' { Invoke-DevSetup $Args }
        'tools' { Invoke-DevTools $Args }
        'help' { Show-DevHelp }
        default { 
            Write-AitherMessage "❌ Unknown subcommand: $SubCmd" -Type Error
            Write-AitherMessage "Use 'aither dev help' for available commands" -Type Info
        }
    }
}

function Invoke-DevRelease {
    param([string[]]$Args)
    
    if ($Args.Count -lt 2) {
        Write-AitherMessage "❌ Usage: aither dev release [patch|minor|major] 'Description'" -Type Error
        return
    }
    
    $releaseType = $Args[0]
    $description = $Args[1]
    
    try {
        # Load PatchManager module
        $patchManagerPath = Join-Path $script:Config.ModulesPath "PatchManager"
        if (Test-Path $patchManagerPath) {
            Import-Module $patchManagerPath -Force
            
            Write-AitherMessage "🚀 Creating $releaseType release: $description" -Type Info
            $result = Invoke-ReleaseWorkflow -ReleaseType $releaseType -Description $description
            
            if ($result) {
                Write-AitherMessage "✅ Release workflow completed successfully!" -Type Success
            }
        } else {
            Write-AitherMessage "❌ PatchManager module not found" -Type Error
        }
    } catch {
        Write-AitherMessage "❌ Release failed: $($_.Exception.Message)" -Type Error
    }
}

# Placeholder functions for other commands
function Invoke-DeployPlan { param([string[]]$Args) Write-AitherMessage "🔄 Deploy plan functionality - Coming soon!" -Type Warning }
function Invoke-DeployApply { param([string[]]$Args) Write-AitherMessage "🔄 Deploy apply functionality - Coming soon!" -Type Warning }
function Invoke-DeployDestroy { param([string[]]$Args) Write-AitherMessage "🔄 Deploy destroy functionality - Coming soon!" -Type Warning }
function Invoke-DeployState { param([string[]]$Args) Write-AitherMessage "🔄 Deploy state functionality - Coming soon!" -Type Warning }
function Invoke-DeployCreate { param([string[]]$Args) Write-AitherMessage "🔄 Deploy create functionality - Coming soon!" -Type Warning }
function Invoke-WorkflowRun { param([string[]]$Args) Write-AitherMessage "🔄 Workflow run functionality - Coming soon!" -Type Warning }
function Invoke-WorkflowList { param([string[]]$Args) Write-AitherMessage "🔄 Workflow list functionality - Coming soon!" -Type Warning }
function Invoke-WorkflowStatus { param([string[]]$Args) Write-AitherMessage "🔄 Workflow status functionality - Coming soon!" -Type Warning }
function Invoke-WorkflowCreate { param([string[]]$Args) Write-AitherMessage "🔄 Workflow create functionality - Coming soon!" -Type Warning }
function Invoke-DevPR { param([string[]]$Args) Write-AitherMessage "🔄 Dev PR functionality - Coming soon!" -Type Warning }
function Invoke-DevSetup { param([string[]]$Args) Write-AitherMessage "🔄 Dev setup functionality - Coming soon!" -Type Warning }
function Invoke-DevTools { param([string[]]$Args) Write-AitherMessage "🔄 Dev tools functionality - Coming soon!" -Type Warning }

function Show-InitHelp {
    Write-AitherMessage "USAGE: aither init [options]" -Type Info
    Write-Host ""
    Write-Host "OPTIONS:"
    Write-Host "  --auto          Run automated setup (non-interactive)"
    Write-Host "  --profile NAME  Use specific installation profile"
    Write-Host ""
    Write-Host "PROFILES:"
    Write-Host "  minimal         Core infrastructure only"
    Write-Host "  standard        Standard features (default)"
    Write-Host "  developer       Includes AI tools and dev features"
    Write-Host "  full           Everything available"
}

function Show-DeployHelp {
    Write-AitherMessage "USAGE: aither deploy [subcommand] [options]" -Type Info
    Write-Host ""
    Write-Host "SUBCOMMANDS:"
    Write-Host "  create PATH     Create new infrastructure project"
    Write-Host "  plan [PATH]     Show deployment plan"
    Write-Host "  apply [PATH]    Apply infrastructure changes"
    Write-Host "  destroy [PATH]  Destroy infrastructure"
    Write-Host "  state           Show current state"
}

function Show-WorkflowHelp {
    Write-AitherMessage "USAGE: aither workflow [subcommand] [options]" -Type Info
    Write-Host ""
    Write-Host "SUBCOMMANDS:"
    Write-Host "  run PLAYBOOK    Execute workflow/playbook"
    Write-Host "  list            List available workflows"
    Write-Host "  status [ID]     Show workflow status"
    Write-Host "  create NAME     Create new workflow"
}

function Show-DevHelp {
    Write-AitherMessage "USAGE: aither dev [subcommand] [options]" -Type Info
    Write-Host ""
    Write-Host "SUBCOMMANDS:"
    Write-Host "  release TYPE MSG    Create release (patch|minor|major)"
    Write-Host "  pr create [OPTIONS] Create pull request"
    Write-Host "  setup              Setup development environment"
    Write-Host "  tools              Manage development tools"
}

# Main execution logic
try {
    switch ($Command) {
        'init' { Invoke-AitherInit $Arguments }
        'deploy' { Invoke-AitherDeploy $SubCommand $Arguments }
        'workflow' { Invoke-AitherWorkflow $SubCommand $Arguments }
        'dev' { Invoke-AitherDev $SubCommand $Arguments }
        'config' { Write-AitherMessage "🔄 Config management - Coming soon!" -Type Warning }
        'plugin' { Write-AitherMessage "🔄 Plugin management - Coming soon!" -Type Warning }
        'server' { Write-AitherMessage "🔄 API server mode - Coming soon!" -Type Warning }
        'help' { Show-AitherHelp }
        '' { Show-AitherHelp }
        default { 
            Write-AitherMessage "❌ Unknown command: $Command" -Type Error
            Write-AitherMessage "Use 'aither help' for available commands" -Type Info
        }
    }
} catch {
    Write-AitherMessage "❌ Error: $($_.Exception.Message)" -Type Error
    if ($script:Config.Debug) {
        Write-AitherMessage "Stack trace: $($_.ScriptStackTrace)" -Type Muted
    }
    exit 1
}