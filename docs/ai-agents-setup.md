# AI Agents Setup Guide for AitherZero

This guide covers the complete setup and configuration of all AI agents in the AitherZero platform, including GitHub Copilot, Claude, Gemini, and OpenAI Codex.

## Overview

AitherZero supports multiple AI agents for enhanced development workflows:

- **GitHub Copilot**: Code completion and chat assistance
- **Claude (Anthropic)**: Code review, security analysis, and architectural guidance
- **Gemini (Google)**: Code generation, optimization, and large-scale analysis
- **OpenAI Codex/GPT**: Documentation generation and code explanation

## Quick Setup

Run the automated setup for all AI agents:

```powershell
# Setup all AI agents
./az 0730 -Provider All

# Setup specific agents
./az 0730 -Provider Claude
./az 0730 -Provider Gemini
./az 0730 -Provider Codex

# Validate configuration
./az 0730 -ValidateOnly
```

## Individual AI Agent Setup

### 1. GitHub Copilot Setup

GitHub Copilot requires GitHub CLI and authentication.

#### Installation

```powershell
# Install GitHub Copilot CLI and setup
./az 0740 -InstallCLI -ConfigureAuth -CreateAliases

# Validate setup
./az 0740 -ValidateOnly
```

#### Manual Setup

1. **Install GitHub CLI**:
   - Windows: `winget install GitHub.cli` or `choco install gh`
   - Linux: `sudo apt install gh` or `sudo yum install gh`
   - macOS: `brew install gh`

2. **Authenticate with GitHub**:
   ```bash
   gh auth login
   gh auth refresh -s copilot
   ```

3. **Install Copilot CLI Extension**:
   ```bash
   gh extension install github/gh-copilot
   ```

4. **Test Installation**:
   ```bash
   gh copilot --help
   ```

#### VSCode Extensions

The setup automatically configures these VSCode extensions:
- `github.copilot` - Code completion
- `github.copilot-chat` - Chat interface
- `github.copilot-labs` - Experimental features

### 2. Claude (Anthropic) Setup

Claude requires an Anthropic API key.

#### Get API Key

1. Visit [Anthropic Console](https://console.anthropic.com/)
2. Create an account or sign in
3. Navigate to API Keys section
4. Create a new API key
5. Copy the key (starts with `sk-ant-api03-`)

#### Installation

```powershell
# Setup Claude with authentication
./az 0741 -ConfigureAuth -SetupContext

# Validate setup
./az 0741 -ValidateOnly
```

#### Environment Variable Setup

Set the API key as an environment variable:

**Windows (PowerShell)**:
```powershell
[Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', 'your-api-key-here', [EnvironmentVariableTarget]::User)
```

**Linux/macOS**:
```bash
echo 'export ANTHROPIC_API_KEY=your-api-key-here' >> ~/.bashrc
source ~/.bashrc
```

#### Using Claude Commands

After setup, you can use these aliases:
```powershell
claude-chat "Explain this AitherZero function"
claude-code-review "./domains/ai-agents/ClaudeCodeIntegration.psm1"
claude-optimize "./automation-scripts/0730_Setup-AIAgents.ps1"
claude-explain "./config.psd1"
claude-context -Update
```

### 3. Google Gemini Setup

Gemini requires a Google API key with Generative AI access.

#### Get API Key

1. Visit [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Sign in with your Google account
3. Create a new API key
4. Copy the key

#### Installation

```powershell
# Setup Gemini with authentication
./az 0742 -ConfigureAuth -CreateAliases -SetupContext

# Validate setup
./az 0742 -ValidateOnly
```

#### Environment Variable Setup

Set the API key as an environment variable:

**Windows (PowerShell)**:
```powershell
[Environment]::SetEnvironmentVariable('GOOGLE_API_KEY', 'your-api-key-here', [EnvironmentVariableTarget]::User)
```

**Linux/macOS**:
```bash
echo 'export GOOGLE_API_KEY=your-api-key-here' >> ~/.bashrc
source ~/.bashrc
```

#### Using Gemini Commands

After setup, you can use these aliases:
```powershell
gemini-chat "Generate a PowerShell function for AitherZero"
gemini-generate "Create a domain module for network management" -Type Domain -IncludeTests
gemini-optimize "./domains/infrastructure/Infrastructure.psm1" -Target Performance
gemini-analyze "./automation-scripts/" -Scope Directory
gemini-context -Update
```

### 4. OpenAI Codex/GPT Setup

OpenAI Codex requires an OpenAI API key.

#### Get API Key

1. Visit [OpenAI Platform](https://platform.openai.com/api-keys)
2. Sign in or create an account
3. Create a new API key
4. Copy the key (starts with `sk-`)

#### Environment Variable Setup

Set the API key as an environment variable:

**Windows (PowerShell)**:
```powershell
[Environment]::SetEnvironmentVariable('OPENAI_API_KEY', 'your-api-key-here', [EnvironmentVariableTarget]::User)
```

**Linux/macOS**:
```bash
echo 'export OPENAI_API_KEY=your-api-key-here' >> ~/.bashrc
source ~/.bashrc
```

## Configuration Files

AitherZero creates several configuration files for AI agents:

### Main Configuration

The main AI configuration is in `config.psd1`:

```powershell
AI = @{
    Enabled = $true
    Providers = @{
        Claude = @{
            Enabled = $true
            ApiKeyEnvVar = 'ANTHROPIC_API_KEY'
            Model = 'claude-3-sonnet-20240229'
            MaxTokens = 4096
            Temperature = 0.7
        }
        Gemini = @{
            Enabled = $true
            ApiKeyEnvVar = 'GOOGLE_API_KEY'
            Model = 'gemini-pro'
            MaxTokens = 2048
            Temperature = 0.9
        }
        Codex = @{
            Enabled = $true
            ApiKeyEnvVar = 'OPENAI_API_KEY'
            Model = 'gpt-4'
            MaxTokens = 8192
            Temperature = 0.5
        }
    }
}
```

### IDE Configurations

The setup creates optimized configurations for:

- **VSCode**: `.vscode/settings.json`, `.vscode/extensions.json`
- **Cursor**: `.cursor/config.json`
- **GitHub Copilot**: `.github/copilot-chat-prompts.md`

### AI-Specific Configurations

Each AI agent has its own configuration directory:

- **Claude**: `.claude/auth.json`, `.claude/context.json`
- **Gemini**: `.gemini/auth.json`, `.gemini/context.json`
- **Copilot**: `.copilot/config.json`

## Multi-AI Workflows

AitherZero supports orchestrated workflows using multiple AI agents:

```powershell
# Start multi-agent code review
Start-AIWorkflow -WorkflowType code_review -Parameters @{
    FilePath = "./domains/ai-agents/AIWorkflowOrchestrator.psm1"
}

# Feature development workflow
Start-AIWorkflow -WorkflowType feature_development -Parameters @{
    FeatureName = "new-domain-module"
    Requirements = "Cross-platform file management utilities"
}

# Comprehensive documentation generation
Start-AIWorkflow -WorkflowType documentation -Parameters @{
    ModulePath = "./domains/infrastructure/"
    OutputFormat = "markdown"
}
```

## Usage Examples

### Code Review Workflow

```powershell
# Automated code review with multiple AI agents
./az 0731 -FilePath "./domains/security/Security.psm1" -ReviewType Comprehensive

# Quick security scan with Claude
claude-code-review "./automation-scripts/0100_Setup-Infrastructure.ps1"
```

### Code Generation

```powershell
# Generate a new domain module with Gemini
gemini-generate "Create a cross-platform registry management module" -Type Domain -IncludeTests

# Create documentation with Codex
./az 0733 -ModulePath "./domains/configuration/" -OutputFormat "markdown"
```

### Optimization

```powershell
# Performance optimization with Gemini
gemini-optimize "./domains/automation/DeploymentAutomation.psm1" -Target Performance

# Code quality improvements with Claude
claude-optimize "./Start-AitherZero.ps1"
```

## Troubleshooting

### Common Issues

1. **API Key Not Found**:
   - Verify environment variables are set correctly
   - Restart your terminal/IDE after setting environment variables
   - Check for typos in variable names

2. **Permission Denied**:
   - Ensure GitHub CLI is authenticated: `gh auth status`
   - Check API key permissions in the respective AI platform

3. **Module Import Errors**:
   - Run `./Initialize-AitherEnvironment.ps1` to load modules
   - Verify all AI agent modules are present in `domains/ai-agents/`

4. **Network Connectivity**:
   - Test API connectivity: `Test-NetConnection api.anthropic.com -Port 443`
   - Check firewall/proxy settings

### Validation Commands

```powershell
# Validate all AI agents
./az 0730 -ValidateOnly

# Test individual agents
./az 0741 -ValidateOnly  # Claude
./az 0742 -ValidateOnly  # Gemini
./az 0740 -ValidateOnly  # GitHub Copilot

# Test API connectivity
Test-AnthropicAPIKey
Test-GoogleAPIKey
Test-OpenAIAPIKey
```

### Debug Mode

Enable debug logging for troubleshooting:

```powershell
$env:AITHERZERO_DEBUG = "true"
./az 0730 -ValidateOnly -Verbose
```

## Best Practices

### Security

1. **Never commit API keys** to source control
2. **Use environment variables** for API key storage
3. **Rotate API keys** regularly
4. **Monitor API usage** and costs
5. **Use least-privilege** API permissions

### Performance

1. **Cache frequently used contexts** to reduce API calls
2. **Use appropriate temperature settings** for each use case
3. **Implement rate limiting** to avoid API throttling
4. **Monitor token usage** to optimize costs

### Development Workflow

1. **Use Copilot for rapid development** and code completion
2. **Use Claude for security reviews** and architectural guidance
3. **Use Gemini for optimization** and large-scale analysis
4. **Use Codex for documentation** generation
5. **Combine multiple agents** for comprehensive workflows

## Cost Management

### Usage Monitoring

AitherZero includes built-in usage monitoring:

```powershell
# View usage statistics
Get-AIUsageReport

# Check individual agent usage
Get-ClaudeUsage
Get-GeminiUsage
Get-CodexUsage
```

### Budget Alerts

Configure budget alerts in `config.psd1`:

```powershell
AI = @{
    UsageMonitoring = @{
        BudgetAlerts = @{
            Enabled = $true
            DailyLimit = 100
            MonthlyLimit = 1000
            AlertThreshold = 80
        }
    }
}
```

## Support

For issues and questions:

1. **Check logs**: `./logs/aitherzero.log`
2. **Run validation**: `./az 0730 -ValidateOnly -Verbose`
3. **Review configuration**: Ensure all API keys are set correctly
4. **Test connectivity**: Verify network access to AI services
5. **Update modules**: Ensure all AI agent modules are up to date

## References

- [GitHub Copilot Documentation](https://docs.github.com/en/copilot)
- [Claude API Documentation](https://docs.anthropic.com/claude/reference)
- [Gemini API Documentation](https://ai.google.dev/docs)
- [OpenAI API Documentation](https://platform.openai.com/docs)
- [AitherZero Architecture Guide](./architecture.md)