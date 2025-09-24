#!/usr/bin/env pwsh
#requires -version 7

<#
.SYNOPSIS
    Setup and configure Claude CLI for AitherZero development

.DESCRIPTION
    Installs Claude CLI tools, configures authentication with Anthropic API,
    sets up context management, and integrates with AitherZero workflows.

.PARAMETER InstallCLI
    Install Claude CLI tool (if available)

.PARAMETER ConfigureAuth
    Setup Anthropic API authentication

.PARAMETER SetupContext
    Configure Claude context management for AitherZero

.PARAMETER ValidateOnly
    Only validate existing Claude configuration

.EXAMPLE
    ./0741_Setup-ClaudeCLI.ps1 -ConfigureAuth -SetupContext
    
.EXAMPLE
    ./0741_Setup-ClaudeCLI.ps1 -ValidateOnly
    
.NOTES
    This script sets up Claude integration for AitherZero development.
    Requires ANTHROPIC_API_KEY environment variable for authentication.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$InstallCLI,
    [switch]$ConfigureAuth,
    [switch]$SetupContext,
    [switch]$ValidateOnly
)

#region Metadata
$script:Stage = "DevelopmentTools"
$script:Dependencies = @('0001', '0730')
$script:Tags = @('claude', 'anthropic', 'ai', 'cli', 'development')
$script:Condition = '$true'
$script:Platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
#endregion

#region Module Imports
$projectRoot = Split-Path $PSScriptRoot -Parent
$modulePaths = @(
    "$projectRoot/domains/utilities/Logging.psm1"
    "$projectRoot/domains/configuration/Configuration.psm1"
    "$projectRoot/domains/ai-agents/ClaudeCodeIntegration.psm1"
)

foreach ($modulePath in $modulePaths) {
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force
    }
}
#endregion

function Write-ClaudeLog {
    param([string]$Message, [string]$Level = 'Information')
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level -Source "ClaudeCLI"
    } else {
        Write-Host "[$Level] Claude CLI: $Message"
    }
}

function Test-AnthropicAPIKey {
    <#
    .SYNOPSIS
        Test Anthropic API key validity
    #>
    [CmdletBinding()]
    param(
        [string]$ApiKey = $env:ANTHROPIC_API_KEY
    )
    
    try {
        if (-not $ApiKey) {
            Write-ClaudeLog "ANTHROPIC_API_KEY environment variable not set" -Level Warning
            return $false
        }
        
        # Test API key format
        if ($ApiKey -notmatch '^sk-ant-api03-[A-Za-z0-9_-]+$') {
            Write-ClaudeLog "API key format appears invalid" -Level Warning
            return $false
        }
        
        # Test API connectivity
        $headers = @{
            'x-api-key' = $ApiKey
            'anthropic-version' = '2023-06-01'
            'content-type' = 'application/json'
        }
        
        $body = @{
            model = 'claude-3-haiku-20240307'
            max_tokens = 10
            messages = @(@{role = "user"; content = "test"})
        } | ConvertTo-Json -Depth 10
        
        $response = Invoke-RestMethod -Uri 'https://api.anthropic.com/v1/messages' -Method Post -Headers $headers -Body $body -ErrorAction Stop
        
        Write-ClaudeLog "Anthropic API key is valid and working" -Level Information
        return $true
    }
    catch {
        Write-ClaudeLog "Failed to validate Anthropic API key: $_" -Level Error
        return $false
    }
}

function Install-ClaudeCLI {
    <#
    .SYNOPSIS
        Install Claude CLI tools
    #>
    [CmdletBinding()]
    param()
    
    Write-ClaudeLog "Installing Claude CLI tools for $script:Platform" -Level Information
    
    try {
        # Check if pip is available for Python-based Claude CLI
        if (Get-Command pip -ErrorAction SilentlyContinue) {
            Write-ClaudeLog "Installing claude-cli via pip" -Level Information
            & pip install claude-cli --user
            
            if ($LASTEXITCODE -eq 0) {
                Write-ClaudeLog "Claude CLI installed successfully" -Level Information
                return $true
            }
        }
        
        # Check if npm is available for Node.js-based tools
        if (Get-Command npm -ErrorAction SilentlyContinue) {
            Write-ClaudeLog "Installing Claude CLI tools via npm" -Level Information
            & npm install -g @anthropic-ai/claude-cli
            
            if ($LASTEXITCODE -eq 0) {
                Write-ClaudeLog "Claude CLI tools installed successfully" -Level Information
                return $true
            }
        }
        
        # Manual installation note
        Write-ClaudeLog "No package manager found for Claude CLI installation" -Level Warning
        Write-ClaudeLog "You may need to install Claude CLI manually or use the integrated module" -Level Information
        return $false
    }
    catch {
        Write-ClaudeLog "Failed to install Claude CLI: $_" -Level Error
        return $false
    }
}

function Setup-ClaudeAuthentication {
    <#
    .SYNOPSIS
        Setup Claude authentication configuration
    #>
    [CmdletBinding()]
    param()
    
    Write-ClaudeLog "Setting up Claude authentication" -Level Information
    
    try {
        $apiKey = $env:ANTHROPIC_API_KEY
        
        if (-not $apiKey) {
            Write-ClaudeLog "ANTHROPIC_API_KEY not found in environment" -Level Warning
            
            if (-not $ValidateOnly) {
                $secureKey = Read-Host -Prompt "Enter your Anthropic API key" -AsSecureString
                if ($secureKey.Length -gt 0) {
                    $apiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
                    )
                    
                    # Set environment variable for current session
                    $env:ANTHROPIC_API_KEY = $apiKey
                    
                    # Set persistent environment variable
                    if ($PSCmdlet.ShouldProcess("User environment variable 'ANTHROPIC_API_KEY'", "Set API key")) {
                        [Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', $apiKey, [EnvironmentVariableTarget]::User)
                        Write-ClaudeLog "API key stored in user environment variables" -Level Information
                    }
                } else {
                    Write-ClaudeLog "No API key provided" -Level Warning
                    return $false
                }
            }
        }
        
        # Test the API key
        if (-not (Test-AnthropicAPIKey -ApiKey $apiKey)) {
            Write-ClaudeLog "API key validation failed" -Level Error
            return $false
        }
        
        # Create Claude configuration directory
        $claudeDir = "$projectRoot/.claude"
        if (-not (Test-Path $claudeDir)) {
            New-Item -Path $claudeDir -ItemType Directory -Force | Out-Null
        }
        
        # Create authentication config
        $authConfig = @{
            api_key = "env:ANTHROPIC_API_KEY"
            api_url = "https://api.anthropic.com/v1"
            model = "claude-3-sonnet-20240229"
            max_tokens = 4000
            temperature = 0.7
        }
        
        $authConfigPath = "$claudeDir/auth.json"
        $authConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $authConfigPath
        
        Write-ClaudeLog "Claude authentication configured successfully" -Level Information
        return $true
    }
    catch {
        Write-ClaudeLog "Failed to setup Claude authentication: $_" -Level Error
        return $false
    }
}

function Setup-ClaudeContext {
    <#
    .SYNOPSIS
        Setup Claude context management for AitherZero
    #>
    [CmdletBinding()]
    param()
    
    Write-ClaudeLog "Setting up Claude context management" -Level Information
    
    try {
        $claudeDir = "$projectRoot/.claude"
        if (-not (Test-Path $claudeDir)) {
            New-Item -Path $claudeDir -ItemType Directory -Force | Out-Null
        }
        
        # Create context configuration
        $contextConfig = @{
            version = "1.0"
            project = @{
                name = "AitherZero"
                type = "infrastructure-automation"
                description = "PowerShell-based infrastructure automation platform with AI integration"
                root_path = $projectRoot
            }
            context_files = @(
                @{
                    path = ".github/copilot-instructions.md"
                    type = "instructions"
                    priority = "high"
                    description = "Project instructions and patterns"
                }
                @{
                    path = "README.md"
                    type = "documentation"
                    priority = "high"
                    description = "Project overview and setup"
                }
                @{
                    path = "config.psd1"
                    type = "configuration"
                    priority = "high"
                    description = "Main configuration file"
                }
                @{
                    path = "config.example.psd1"
                    type = "configuration"
                    priority = "medium"
                    description = "Configuration template with documentation"
                }
            )
            include_patterns = @(
                "automation-scripts/**/*.ps1"
                "domains/**/*.psm1"
                "domains/**/*.psd1"
                "tests/**/*.ps1"
                "orchestration/**/*.json"
                "docs/**/*.md"
            )
            exclude_patterns = @(
                "logs/**"
                "backups/**"
                "archive/**"
                "temp-*/**"
                "*.log"
                ".terraform/**"
                "node_modules/**"
                "__pycache__/**"
            )
            ai_instructions = @{
                role = "You are an expert PowerShell developer and infrastructure automation specialist working with the AitherZero platform."
                context = @(
                    "AitherZero is a cross-platform PowerShell 7+ infrastructure automation platform"
                    "Uses number-based script orchestration (0000-9999) in automation-scripts/"
                    "Domain-based module architecture in domains/ directory"
                    "Hierarchical configuration system using .psd1 files"
                    "Multi-AI orchestration with Claude, Gemini, OpenAI, and GitHub Copilot"
                    "Cross-platform compatibility (Windows, Linux, macOS)"
                    "Centralized logging using Write-CustomLog pattern"
                    "Pester-based testing framework"
                )
                patterns = @(
                    "Always use #requires -version 7 for PowerShell scripts"
                    "Implement [CmdletBinding()] for advanced functions"
                    "Use Write-CustomLog instead of Write-Host for output"
                    "Check platform variables (\$IsWindows, \$IsLinux, \$IsMacOS)"
                    "Follow hierarchical configuration loading patterns"
                    "Include comprehensive comment-based help"
                    "Use Export-ModuleMember for module exports"
                    "Implement proper error handling with try/catch"
                    "Support -WhatIf and -Confirm for state-changing functions"
                )
            }
        }
        
        $contextConfigPath = "$claudeDir/context.json"
        $contextConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $contextConfigPath
        
        # Create session context file if it doesn't exist
        $sessionContextPath = "$claudeDir/session-context.json"
        if (-not (Test-Path $sessionContextPath)) {
            $sessionContext = @{
                created = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
                project = "AitherZero"
                current_session = @{
                    id = [System.Guid]::NewGuid().ToString()
                    started = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
                    context_loaded = $false
                }
                recent_files = @()
                active_tasks = @()
            }
            
            $sessionContext | ConvertTo-Json -Depth 10 | Set-Content -Path $sessionContextPath
        }
        
        # Create continuation prompt template
        $continuationPrompt = @"
# AitherZero Development Session Context

## Project Overview
AitherZero is a PowerShell-based infrastructure automation platform with AI integration.

## Current Session Status
- Project: AitherZero Infrastructure Automation Platform
- Session ID: {session_id}
- Last Updated: {timestamp}
- Context Files Loaded: {context_files_count}

## Recent Activity
{recent_activity}

## Active Tasks
{active_tasks}

## Next Steps
{next_steps}

## Quick Commands
- `./az.ps1 0730` - Setup AI agents
- `./az.ps1 0402` - Run unit tests
- `./az.ps1 0404` - Run PSScriptAnalyzer
- `./az.ps1 0701 -Type feature -Name "feature-name"` - Create feature branch

## Key Files for Context
- `.github/copilot-instructions.md` - Project instructions
- `config.psd1` - Main configuration
- `domains/ai-agents/` - AI integration modules
- `automation-scripts/` - Numbered automation scripts

Please continue where we left off with the AitherZero development tasks.
"@
        
        $promptPath = "$claudeDir/continuation-prompt.md"
        Set-Content -Path $promptPath -Value $continuationPrompt
        
        Write-ClaudeLog "Claude context management configured successfully" -Level Information
        return $true
    }
    catch {
        Write-ClaudeLog "Failed to setup Claude context: $_" -Level Error
        return $false
    }
}

function New-ClaudeAliases {
    <#
    .SYNOPSIS
        Create helpful Claude CLI aliases
    #>
    [CmdletBinding()]
    param()
    
    Write-ClaudeLog "Creating Claude CLI aliases" -Level Information
    
    try {
        # Create PowerShell functions for Claude integration
        $aliasContent = @"
# AitherZero Claude CLI Integration

function claude-chat {
    param([string]`$Message)
    if (Get-Command Invoke-ClaudeChat -ErrorAction SilentlyContinue) {
        Invoke-ClaudeChat -Message `$Message
    } else {
        Write-Warning "Claude integration not available. Run az 0730 to setup AI agents."
    }
}

function claude-code-review {
    param([string]`$FilePath)
    if (Get-Command Invoke-ClaudeCodeReview -ErrorAction SilentlyContinue) {
        if (Test-Path `$FilePath) {
            `$code = Get-Content `$FilePath -Raw
            Invoke-ClaudeCodeReview -Code `$code -ReviewFocus @('Quality', 'Security', 'Performance')
        } else {
            Write-Error "File not found: `$FilePath"
        }
    } else {
        Write-Warning "Claude integration not available. Run az 0730 to setup AI agents."
    }
}

function claude-optimize {
    param([string]`$FilePath)
    if (Get-Command Invoke-ClaudeCodeOptimization -ErrorAction SilentlyContinue) {
        if (Test-Path `$FilePath) {
            `$code = Get-Content `$FilePath -Raw
            Invoke-ClaudeCodeOptimization -Code `$code -OptimizationTarget 'All'
        } else {
            Write-Error "File not found: `$FilePath"
        }
    } else {
        Write-Warning "Claude integration not available. Run az 0730 to setup AI agents."
    }
}

function claude-explain {
    param([string]`$FilePath)
    if (Get-Command Invoke-ClaudeChat -ErrorAction SilentlyContinue) {
        if (Test-Path `$FilePath) {
            `$code = Get-Content `$FilePath -Raw
            `$prompt = "Please explain this AitherZero PowerShell code and how it fits into the platform architecture:`n`n```powershell`n`$code`n```"
            Invoke-ClaudeChat -Message `$prompt
        } else {
            Write-Error "File not found: `$FilePath"
        }
    } else {
        Write-Warning "Claude integration not available. Run az 0730 to setup AI agents."
    }
}

function claude-context {
    param([switch]`$Update, [switch]`$Show)
    `$contextPath = "./.claude/session-context.json"
    
    if (`$Update) {
        Write-Host "Updating Claude context..." -ForegroundColor Yellow
        # Update context with current project state
        `$context = @{
            updated = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
            git_status = (git status --porcelain 2>`$null)
            recent_files = (git log --name-only --oneline -5 2>`$null)
            current_branch = (git branch --show-current 2>`$null)
        }
        
        if (Test-Path `$contextPath) {
            `$existingContext = Get-Content `$contextPath | ConvertFrom-Json
            `$existingContext.last_update = `$context
            `$existingContext | ConvertTo-Json -Depth 10 | Set-Content `$contextPath
        }
        
        Write-Host "Claude context updated." -ForegroundColor Green
    }
    
    if (`$Show) {
        if (Test-Path `$contextPath) {
            Get-Content `$contextPath | ConvertFrom-Json | ConvertTo-Json -Depth 10
        } else {
            Write-Warning "Claude context file not found. Run az 0741 to setup Claude CLI."
        }
    }
}
"@
        
        # Add to PowerShell profile
        $profilePath = $PROFILE.CurrentUserAllHosts
        if (-not (Test-Path (Split-Path $profilePath -Parent))) {
            New-Item -Path (Split-Path $profilePath -Parent) -ItemType Directory -Force | Out-Null
        }
        
        if (Test-Path $profilePath) {
            $existingContent = Get-Content $profilePath -Raw
            if ($existingContent -notlike "*AitherZero Claude CLI Integration*") {
                Add-Content -Path $profilePath -Value "`n$aliasContent"
                Write-ClaudeLog "Added Claude aliases to PowerShell profile" -Level Information
            } else {
                Write-ClaudeLog "Claude aliases already exist in PowerShell profile" -Level Information
            }
        } else {
            Set-Content -Path $profilePath -Value $aliasContent
            Write-ClaudeLog "Created PowerShell profile with Claude aliases" -Level Information
        }
        
        return $true
    }
    catch {
        Write-ClaudeLog "Failed to create Claude aliases: $_" -Level Error
        return $false
    }
}

function Test-ClaudeIntegration {
    <#
    .SYNOPSIS
        Validate complete Claude integration
    #>
    [CmdletBinding()]
    param()
    
    Write-ClaudeLog "Validating Claude integration" -Level Information
    
    $results = @{
        APIKey = Test-AnthropicAPIKey
        AuthConfig = Test-Path "$projectRoot/.claude/auth.json"
        ContextConfig = Test-Path "$projectRoot/.claude/context.json"
        SessionContext = Test-Path "$projectRoot/.claude/session-context.json"
        ContinuationPrompt = Test-Path "$projectRoot/.claude/continuation-prompt.md"
        ClaudeModule = Test-Path "$projectRoot/domains/ai-agents/ClaudeCodeIntegration.psm1"
    }
    
    $allPassed = $true
    foreach ($test in $results.Keys) {
        $status = if ($results[$test]) { "✓ PASS" } else { "✗ FAIL"; $allPassed = $false }
        Write-ClaudeLog "$test : $status" -Level Information
    }
    
    if ($allPassed) {
        Write-ClaudeLog "All Claude integration tests passed" -Level Information
        Write-ClaudeLog "Use 'claude-chat', 'claude-code-review', 'claude-optimize' commands" -Level Information
        return $true
    } else {
        Write-ClaudeLog "Some Claude integration tests failed" -Level Warning
        return $false
    }
}

# Main execution
function Main {
    Write-ClaudeLog "Starting Claude CLI setup for AitherZero (Platform: $script:Platform)" -Level Information
    
    try {
        if ($ValidateOnly) {
            return Test-ClaudeIntegration
        }
        
        $success = $true
        
        # Install CLI if requested
        if ($InstallCLI) {
            $success = $success -and (Install-ClaudeCLI)
        }
        
        # Setup authentication
        if ($ConfigureAuth) {
            $success = $success -and (Setup-ClaudeAuthentication)
        }
        
        # Setup context management
        if ($SetupContext) {
            $success = $success -and (Setup-ClaudeContext)
        }
        
        # Create aliases
        if ($success) {
            $success = $success -and (New-ClaudeAliases)
        }
        
        # Final validation
        if ($success) {
            $success = Test-ClaudeIntegration
        }
        
        if ($success) {
            Write-ClaudeLog "Claude CLI setup completed successfully" -Level Information
            Write-ClaudeLog "Restart your terminal to use the new aliases" -Level Information
            Write-ClaudeLog "Run 'claude-context -Update' to initialize the context" -Level Information
        } else {
            Write-ClaudeLog "Claude CLI setup completed with issues" -Level Warning
        }
        
        return $success
    }
    catch {
        Write-ClaudeLog "Failed to setup Claude CLI: $_" -Level Error
        return $false
    }
}

# Run main function
if (-not $MyInvocation.ScriptName) {
    # Running interactively
    Main
} else {
    # Running as script
    $result = Main
    exit if ($result) { 0 } else { 1 }
}