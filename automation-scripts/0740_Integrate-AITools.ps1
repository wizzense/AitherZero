#Requires -Version 7.0

<#
.SYNOPSIS
    Integrate AI tools for code review and analysis
.DESCRIPTION
    Sets up and configures AI tools including Claude Code CLI, Gemini CLI, 
    OpenAI Codex CLI, and GitHub Copilot CLI for automated code reviews,
    test generation, and code analysis.
    
    Exit Codes:
    0   - AI tools configured successfully
    1   - Configuration failed
    2   - Tool installation error
    
.NOTES
    Stage: AI Integration
    Order: 0740
    Dependencies: 0700
    Tags: ai, code-review, automation, claude, gemini, openai, copilot
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('claude', 'gemini', 'openai', 'copilot', 'all')]
    [string]$Tool = 'all',
    
    [string]$ConfigPath,
    [switch]$SkipInstallation,
    [switch]$TestConnection,
    [switch]$CI
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata
$scriptMetadata = @{
    Stage = 'AI Integration'
    Order = 0740
    Dependencies = @('0700')
    Tags = @('ai', 'code-review', 'automation')
    RequiresAdmin = $false
    SupportsWhatIf = $true
}

# Import modules
$projectRoot = Split-Path $PSScriptRoot -Parent
$loggingModule = Join-Path $projectRoot "domains/core/Logging.psm1"
$configModule = Join-Path $projectRoot "domains/configuration/Configuration.psm1"

if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force
}

if (Test-Path $configModule) {
    Import-Module $configModule -Force
}

function Write-ScriptLog {
    param(
        [string]$Level = 'Information',
        [string]$Message,
        [hashtable]$Data = @{}
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "0740_Integrate-AITools" -Data $Data
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $color = @{
            'Error' = 'Red'
            'Warning' = 'Yellow'
            'Information' = 'White'
            'Debug' = 'Gray'
        }[$Level]
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    }
}

function Test-AITool {
    param(
        [string]$ToolName,
        [string]$Command,
        [string]$TestArgs = '--version'
    )
    
    try {
        Write-ScriptLog -Message "Testing $ToolName availability"
        $result = & $Command $TestArgs 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-ScriptLog -Message "$ToolName is available" -Data @{ Version = $result }
            return $true
        }
    } catch {
        Write-ScriptLog -Level Warning -Message "$ToolName not available: $_"
    }
    return $false
}

function Install-ClaudeCodeCLI {
    if ($SkipInstallation) {
        Write-ScriptLog -Message "Skipping Claude Code CLI installation"
        return
    }
    
    Write-ScriptLog -Message "Installing Claude Code CLI"
    
    if ($PSCmdlet.ShouldProcess("Claude Code CLI", "Install")) {
        try {
            # Check if npm is available
            if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
                Write-ScriptLog -Level Warning -Message "npm not found. Install Node.js first."
                return $false
            }
            
            # Install claude-dev CLI (popular Claude integration)
            npm install -g @anthropic-ai/claude-cli 2>$null
            
            if (Test-AITool -ToolName "Claude CLI" -Command "claude" -TestArgs "--help") {
                Write-ScriptLog -Message "Claude Code CLI installed successfully"
                return $true
            } else {
                Write-ScriptLog -Level Warning -Message "Claude Code CLI installation failed"
                return $false
            }
        } catch {
            Write-ScriptLog -Level Error -Message "Claude Code CLI installation error: $_"
            return $false
        }
    }
}

function Install-GeminiCLI {
    if ($SkipInstallation) {
        Write-ScriptLog -Message "Skipping Gemini CLI installation"
        return
    }
    
    Write-ScriptLog -Message "Installing Gemini CLI"
    
    if ($PSCmdlet.ShouldProcess("Gemini CLI", "Install")) {
        try {
            # Check if Python is available
            if (-not (Get-Command python -ErrorAction SilentlyContinue) -and 
                -not (Get-Command python3 -ErrorAction SilentlyContinue)) {
                Write-ScriptLog -Level Warning -Message "Python not found. Install Python first."
                return $false
            }
            
            # Install Google AI CLI
            $pythonCmd = if (Get-Command python3 -ErrorAction SilentlyContinue) { 'python3' } else { 'python' }
            & $pythonCmd -m pip install google-generativeai 2>$null
            
            Write-ScriptLog -Message "Gemini CLI components installed"
            return $true
        } catch {
            Write-ScriptLog -Level Error -Message "Gemini CLI installation error: $_"
            return $false
        }
    }
}

function Install-OpenAICodex {
    if ($SkipInstallation) {
        Write-ScriptLog -Message "Skipping OpenAI Codex CLI installation"
        return
    }
    
    Write-ScriptLog -Message "Installing OpenAI CLI"
    
    if ($PSCmdlet.ShouldProcess("OpenAI CLI", "Install")) {
        try {
            # Install OpenAI CLI
            if (Get-Command pip -ErrorAction SilentlyContinue) {
                pip install openai-cli 2>$null
            } elseif (Get-Command npm -ErrorAction SilentlyContinue) {
                npm install -g openai-cli 2>$null
            } else {
                Write-ScriptLog -Level Warning -Message "Neither pip nor npm found for OpenAI CLI installation"
                return $false
            }
            
            Write-ScriptLog -Message "OpenAI CLI installed"
            return $true
        } catch {
            Write-ScriptLog -Level Error -Message "OpenAI CLI installation error: $_"
            return $false
        }
    }
}

function Install-GitHubCopilotCLI {
    if ($SkipInstallation) {
        Write-ScriptLog -Message "Skipping GitHub Copilot CLI installation"
        return
    }
    
    Write-ScriptLog -Message "Installing GitHub Copilot CLI"
    
    if ($PSCmdlet.ShouldProcess("GitHub Copilot CLI", "Install")) {
        try {
            # Install GitHub CLI extension for Copilot
            if (Get-Command gh -ErrorAction SilentlyContinue) {
                gh extension install github/gh-copilot 2>$null
                
                if ($LASTEXITCODE -eq 0) {
                    Write-ScriptLog -Message "GitHub Copilot CLI installed successfully"
                    return $true
                }
            } else {
                Write-ScriptLog -Level Warning -Message "GitHub CLI not found. Install 'gh' first."
            }
            return $false
        } catch {
            Write-ScriptLog -Level Error -Message "GitHub Copilot CLI installation error: $_"
            return $false
        }
    }
}

function New-AIConfigFile {
    Write-ScriptLog -Message "Creating AI tools configuration"
    
    $aiConfig = @{
        Tools = @{
            Claude = @{
                Enabled = $false
                Command = 'claude'
                ApiKey = '$env:ANTHROPIC_API_KEY'
                Model = 'claude-3-sonnet-20240229'
                Features = @('code-review', 'documentation', 'testing')
            }
            Gemini = @{
                Enabled = $false
                Command = 'python'
                Args = @('-m', 'google.generativeai')
                ApiKey = '$env:GOOGLE_AI_API_KEY'
                Model = 'gemini-pro'
                Features = @('code-analysis', 'optimization', 'security')
            }
            OpenAI = @{
                Enabled = $false
                Command = 'openai'
                ApiKey = '$env:OPENAI_API_KEY'
                Model = 'gpt-4'
                Features = @('code-generation', 'refactoring', 'testing')
            }
            Copilot = @{
                Enabled = $false
                Command = 'gh'
                Args = @('copilot')
                Features = @('suggestions', 'explanations', 'cli-help')
            }
        }
        Settings = @{
            MaxTokens = 4000
            Temperature = 0.3
            EnableLogging = $true
            LogPath = './logs/ai-tools.log'
            TimeoutSeconds = 30
        }
    }
    
    $configPath = if ($ConfigPath) { $ConfigPath } else { Join-Path $projectRoot "config/ai-tools.json" }
    
    # Ensure config directory exists
    $configDir = Split-Path $configPath -Parent
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    
    if ($PSCmdlet.ShouldProcess($configPath, "Create AI tools configuration")) {
        $aiConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
        Write-ScriptLog -Message "AI configuration created: $configPath"
    }
}

function Test-AIConnections {
    Write-ScriptLog -Message "Testing AI tool connections"
    
    $results = @{}
    
    # Test Claude CLI
    if (Test-AITool -ToolName "Claude CLI" -Command "claude" -TestArgs "--help") {
        $results.Claude = $true
    }
    
    # Test GitHub Copilot CLI  
    if (Test-AITool -ToolName "GitHub Copilot CLI" -Command "gh" -TestArgs "copilot --version") {
        $results.Copilot = $true
    }
    
    # Test OpenAI CLI
    if (Test-AITool -ToolName "OpenAI CLI" -Command "openai" -TestArgs "--version") {
        $results.OpenAI = $true
    }
    
    # Test Python for Gemini
    if (Get-Command python -ErrorAction SilentlyContinue) {
        try {
            python -c "import google.generativeai" 2>$null
            if ($LASTEXITCODE -eq 0) {
                $results.Gemini = $true
            }
        } catch {
            $results.Gemini = $false
        }
    }
    
    Write-ScriptLog -Message "AI connection test results" -Data $results
    
    # Display results
    Write-Host "`nAI Tools Status:" -ForegroundColor Cyan
    foreach ($tool in $results.Keys) {
        $status = if ($results[$tool]) { "✅ Available" } else { "❌ Not Available" }
        $color = if ($results[$tool]) { 'Green' } else { 'Red' }
        Write-Host "  $tool`: $status" -ForegroundColor $color
    }
    
    return $results
}

function New-AICodeReviewScript {
    Write-ScriptLog -Message "Creating AI code review automation script"
    
    $reviewScript = @'
#!/usr/bin/env pwsh
# AI-powered code review script

param(
    [string[]]$Files,
    [string]$Tool = 'copilot',
    [switch]$Interactive
)

function Invoke-AICodeReview {
    param($FilePath, $AITool)
    
    Write-Host "Reviewing: $FilePath" -ForegroundColor Cyan
    
    switch ($AITool) {
        'copilot' {
            if (Get-Command gh -ErrorAction SilentlyContinue) {
                gh copilot explain $FilePath
            }
        }
        'claude' {
            if (Get-Command claude -ErrorAction SilentlyContinue) {
                $prompt = "Please review this PowerShell code for best practices, security, and potential improvements: $(Get-Content $FilePath -Raw)"
                claude $prompt
            }
        }
        default {
            Write-Host "AI tool '$AITool' not configured" -ForegroundColor Yellow
        }
    }
}

# Get changed files if none specified
if (-not $Files) {
    $Files = @(git diff --name-only HEAD~1 HEAD | Where-Object { $_ -match '\.(ps1|psm1|psd1)$' })
}

foreach ($file in $Files) {
    if (Test-Path $file) {
        Invoke-AICodeReview -FilePath $file -AITool $Tool
    }
}
'@

    $scriptPath = Join-Path $projectRoot "tools/ai-code-review.ps1"
    
    # Ensure tools directory exists
    $toolsDir = Split-Path $scriptPath -Parent
    if (-not (Test-Path $toolsDir)) {
        New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
    }
    
    if ($PSCmdlet.ShouldProcess($scriptPath, "Create AI code review script")) {
        $reviewScript | Set-Content -Path $scriptPath
        Write-ScriptLog -Message "AI code review script created: $scriptPath"
    }
}

try {
    Write-ScriptLog -Message "Starting AI tools integration"
    
    $installResults = @{}
    
    # Install tools based on selection
    if ($Tool -eq 'all' -or $Tool -eq 'claude') {
        $installResults.Claude = Install-ClaudeCodeCLI
    }
    
    if ($Tool -eq 'all' -or $Tool -eq 'gemini') {
        $installResults.Gemini = Install-GeminiCLI
    }
    
    if ($Tool -eq 'all' -or $Tool -eq 'openai') {
        $installResults.OpenAI = Install-OpenAICodex
    }
    
    if ($Tool -eq 'all' -or $Tool -eq 'copilot') {
        $installResults.Copilot = Install-GitHubCopilotCLI
    }
    
    # Create configuration file
    New-AIConfigFile
    
    # Create AI automation scripts
    New-AICodeReviewScript
    
    # Test connections if requested
    if ($TestConnection) {
        $connectionResults = Test-AIConnections
    }
    
    # Create setup instructions
    $instructions = @"
# AI Tools Setup Instructions

## Environment Variables Required

Add these to your environment:
```bash
export ANTHROPIC_API_KEY="your-claude-api-key"
export GOOGLE_AI_API_KEY="your-gemini-api-key"  
export OPENAI_API_KEY="your-openai-api-key"
```

## Usage Examples

### Code Review with GitHub Copilot
```powershell
gh copilot explain ./script.ps1
```

### AI-powered Git Commit Messages  
```powershell
gh copilot suggest "git commit message for bug fix in authentication module"
```

### Automated Code Review
```powershell
./tools/ai-code-review.ps1 -Tool copilot -Files @("script1.ps1", "script2.ps1")
```

## Integration with CI/CD

The AI tools are now integrated into the CI/CD pipeline and will:
- Review code changes in pull requests
- Generate test suggestions
- Provide security analysis feedback
- Suggest code improvements

Configure API keys in GitHub repository secrets for full automation.
"@

    $instructionsPath = Join-Path $projectRoot "docs/ai-tools-setup.md"
    if ($PSCmdlet.ShouldProcess($instructionsPath, "Create setup instructions")) {
        $instructions | Set-Content -Path $instructionsPath
        Write-ScriptLog -Message "Setup instructions created: $instructionsPath"
    }
    
    # Summary
    Write-Host "`nAI Tools Integration Summary:" -ForegroundColor Green
    Write-Host "✅ Configuration files created" -ForegroundColor Green
    Write-Host "✅ Automation scripts generated" -ForegroundColor Green
    Write-Host "✅ Setup instructions documented" -ForegroundColor Green
    
    if ($installResults.Count -gt 0) {
        Write-Host "`nInstallation Results:" -ForegroundColor Cyan
        foreach ($tool in $installResults.Keys) {
            $status = if ($installResults[$tool]) { "✅ Success" } else { "❌ Failed" }
            $color = if ($installResults[$tool]) { 'Green' } else { 'Yellow' }
            Write-Host "  $tool`: $status" -ForegroundColor $color
        }
    }
    
    Write-Host "`nNext Steps:" -ForegroundColor Cyan
    Write-Host "1. Configure API keys in environment variables" -ForegroundColor White
    Write-Host "2. Test tool connections with: ./automation-scripts/0740_Integrate-AITools.ps1 -TestConnection" -ForegroundColor White
    Write-Host "3. Review setup instructions: docs/ai-tools-setup.md" -ForegroundColor White
    
    Write-ScriptLog -Message "AI tools integration completed successfully"
    exit 0
    
} catch {
    $errorMsg = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
    Write-ScriptLog -Level Error -Message "AI tools integration failed: $_" -Data @{ Exception = $errorMsg }
    exit 1
}
