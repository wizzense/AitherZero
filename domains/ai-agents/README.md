# AI Agents Domain

This domain provides comprehensive AI integration for the AitherZero platform, enabling multi-agent workflows with GitHub Copilot, Claude, Gemini, and OpenAI Codex.

## Overview

The AI Agents domain orchestrates multiple AI services to enhance development productivity through:

- **Code Review**: Automated security, quality, and performance analysis
- **Code Generation**: AI-powered creation of PowerShell modules and scripts
- **Documentation**: Automated generation of comprehensive documentation
- **Optimization**: Performance and code quality improvements
- **Testing**: Automated test generation and validation
- **Architecture**: AI-assisted architectural decisions and planning

## Architecture

```
domains/ai-agents/
├── AIWorkflowOrchestrator.psm1    # Multi-agent workflow coordination
├── ClaudeCodeIntegration.psm1     # Anthropic Claude integration
├── GeminiIntegration.psm1         # Google Gemini integration
├── CodexIntegration.psm1          # OpenAI Codex/GPT integration
└── README.md                      # This file
```

## Modules

### AIWorkflowOrchestrator.psm1

Coordinates multi-agent workflows and manages AI agent pools.

**Key Functions:**
- `Initialize-AIWorkflowOrchestrator` - Setup orchestrator with available agents
- `Start-AIWorkflow` - Execute multi-agent workflows
- `Get-WorkflowStatus` - Monitor workflow progress
- `Wait-AIWorkflow` - Wait for workflow completion

**Workflow Types:**
- `code_review` - Comprehensive code analysis with multiple agents
- `feature_development` - AI-assisted feature development
- `documentation` - Automated documentation generation
- `testing` - Comprehensive test generation
- `optimization` - Performance optimization
- `security_analysis` - Security analysis and remediation

### ClaudeCodeIntegration.psm1

Integrates with Anthropic Claude for code analysis and review.

**Key Functions:**
- `Initialize-ClaudeIntegration` - Setup Claude API connection
- `Invoke-ClaudeChat` - Send chat requests to Claude
- `Invoke-ClaudeCodeReview` - Perform code reviews
- `Invoke-ClaudeCodeOptimization` - Optimize code quality
- `Get-ClaudeUsage` - Monitor API usage

**Specialties:**
- Security analysis and vulnerability detection
- Code quality assessment
- Architecture review and recommendations
- Refactoring suggestions

### GeminiIntegration.psm1

Integrates with Google Gemini for code generation and optimization.

**Key Functions:**
- `Initialize-GeminiIntegration` - Setup Gemini API connection
- `Invoke-GeminiChat` - Send requests to Gemini
- `Invoke-GeminiCodeOptimization` - Optimize code performance
- `Invoke-GeminiCodeGeneration` - Generate new code
- `Get-GeminiUsage` - Monitor API usage

**Specialties:**
- Code generation and synthesis
- Performance optimization
- Large-scale codebase analysis (1M token context window)
- Bulk processing and analysis

### CodexIntegration.psm1

Integrates with OpenAI Codex/GPT for documentation and explanation.

**Key Functions:**
- `Initialize-CodexIntegration` - Setup OpenAI API connection
- `Invoke-CodexChat` - Send chat requests
- `Invoke-CodexDocumentation` - Generate documentation
- `Invoke-CodexRefactoring` - Refactor code structure
- `Invoke-CodexCodeReview` - Perform code reviews
- `Get-CodexUsage` - Monitor API usage

**Specialties:**
- Technical documentation generation
- Code explanation and commenting
- Refactoring and restructuring
- API documentation

## Quick Start

### 1. Setup All AI Agents

```powershell
# Automated setup
./az 0730 -Provider All

# Validate configuration
./az 0730 -ValidateOnly
```

### 2. Configure API Keys

Set environment variables for each AI service:

```powershell
# Claude (Anthropic)
$env:ANTHROPIC_API_KEY = "sk-ant-api03-..."

# Gemini (Google)
$env:GOOGLE_API_KEY = "AI..."

# OpenAI Codex
$env:OPENAI_API_KEY = "sk-..."
```

### 3. Initialize Orchestrator

```powershell
# Load the AI agents domain
Import-Module "./domains/ai-agents/AIWorkflowOrchestrator.psm1"

# Initialize with all agents
Initialize-AIWorkflowOrchestrator -EnabledAgents @("claude", "gemini", "codex")
```

## Usage Examples

### Multi-Agent Code Review

```powershell
# Start comprehensive code review
$workflow = Start-AIWorkflow -WorkflowType code_review -Parameters @{
    FilePath = "./domains/infrastructure/Infrastructure.psm1"
    ReviewFocus = @("security", "performance", "quality")
}

# Monitor progress
Get-WorkflowStatus -WorkflowId $workflow.WorkflowId

# Wait for completion
$results = Wait-AIWorkflow -WorkflowId $workflow.WorkflowId -TimeoutMinutes 15
```

### Feature Development Workflow

```powershell
# AI-assisted feature development
$workflow = Start-AIWorkflow -WorkflowType feature_development -Parameters @{
    FeatureName = "cross-platform-registry"
    Requirements = "PowerShell module for cross-platform registry access"
    IncludeTests = $true
    IncludeDocs = $true
}

# Results include:
# - Architecture planning (Claude)
# - Implementation code (Codex)
# - Optimization suggestions (Gemini)
# - Test strategy (Claude)
```

### Individual Agent Usage

```powershell
# Claude code review
$review = Invoke-ClaudeCodeReview -Code $codeContent -ReviewFocus @("Security", "Quality")

# Gemini code generation
$generated = Invoke-GeminiCodeGeneration -Requirements "Create a logging utility" -ModuleType Function -IncludeTests

# Codex documentation
$docs = Invoke-CodexDocumentation -Code $codeContent -DocumentationType README -IncludeExamples
```

## Configuration

### Main Configuration (config.psd1)

```powershell
AI = @{
    Enabled = $true
    Providers = @{
        Claude = @{
            Enabled = $true
            Model = "claude-3-sonnet-20240229"
            MaxTokens = 4096
            Temperature = 0.7
            ApiKeyEnvVar = "ANTHROPIC_API_KEY"
            RateLimits = @{
                RequestsPerMinute = 50
                TokensPerMinute = 100000
            }
        }
        Gemini = @{
            Enabled = $true
            Model = "gemini-pro"
            MaxTokens = 1000000  # Large context window
            Temperature = 0.9
            ApiKeyEnvVar = "GOOGLE_API_KEY"
            RateLimits = @{
                RequestsPerMinute = 60
                TokensPerMinute = 120000
            }
        }
        Codex = @{
            Enabled = $true
            Model = "gpt-4"
            MaxTokens = 8192
            Temperature = 0.5
            ApiKeyEnvVar = "OPENAI_API_KEY"
            RateLimits = @{
                RequestsPerMinute = 60
                TokensPerMinute = 150000
            }
        }
    }
}
```

### Agent-Specific Context Files

Each agent maintains context files optimized for their strengths:

- **Claude**: `.claude/context.json` - Security and architecture focused
- **Gemini**: `.gemini/context.json` - Performance and generation focused
- **Copilot**: `.copilot/config.json` - Development workflow focused

## Advanced Features

### Custom Workflow Definition

```powershell
# Define custom workflow template
$customWorkflow = @{
    Name = "Infrastructure Audit"
    Agents = @(
        @{ Agent = "Claude"; Task = "security_audit"; Priority = 1 }
        @{ Agent = "Gemini"; Task = "performance_analysis"; Priority = 2 }
        @{ Agent = "Codex"; Task = "documentation_review"; Priority = 3 }
    )
    Aggregation = "audit_report"
}

# Register and execute
Register-WorkflowTemplate -Name "infrastructure_audit" -Template $customWorkflow
Start-AIWorkflow -WorkflowType infrastructure_audit -Parameters @{ ModulePath = "./domains/infrastructure/" }
```

### Context Management

```powershell
# Update AI context with current project state
Update-AIContext -IncludeGitStatus -IncludeRecentChanges -CompressHistory

# Export context for external use
Export-AIContext -OutputPath "./reports/ai-context.json" -Format Comprehensive
```

### Usage Monitoring

```powershell
# Get usage statistics for all agents
Get-AIUsageReport -TimeRange "Last7Days" -IncludeCosts

# Monitor specific agent usage
Get-ClaudeUsage | Format-Table
Get-GeminiUsage | ConvertTo-Json
Get-CodexUsage | Export-Csv "./reports/codex-usage.csv"
```

## Best Practices

### Agent Selection Guidelines

Choose agents based on their strengths:

- **Claude**: Security analysis, code review, architectural decisions
- **Gemini**: Code generation, optimization, large-scale analysis
- **Codex**: Documentation, explanation, refactoring
- **GitHub Copilot**: Real-time code completion and chat

### Context Optimization

1. **Keep contexts focused** - Include only relevant files
2. **Use agent specialties** - Match tasks to agent strengths
3. **Manage token limits** - Monitor usage to avoid throttling
4. **Cache frequently used contexts** - Reduce API calls

### Error Handling

```powershell
try {
    $result = Invoke-ClaudeCodeReview -Code $code -ReviewFocus @("Security")
    if (-not $result.Success) {
        Write-Warning "Claude analysis failed: $($result.Error)"
        # Fallback to Codex
        $result = Invoke-CodexCodeReview -Code $code -ReviewFocus @("Security")
    }
} catch {
    Write-Error "AI analysis failed: $_"
}
```

## Troubleshooting

### Common Issues

1. **API Key Not Found**:
   ```powershell
   # Check environment variables
   Get-ChildItem Env: | Where-Object Name -like "*API_KEY"
   ```

2. **Rate Limiting**:
   ```powershell
   # Check current usage
   Get-AIUsageReport -ShowRateLimits
   ```

3. **Module Import Errors**:
   ```powershell
   # Reload modules
   Get-Module ai-agents* | Remove-Module -Force
   Import-Module "./domains/ai-agents/AIWorkflowOrchestrator.psm1" -Force
   ```

### Debug Mode

Enable detailed logging:

```powershell
$env:AITHERZERO_DEBUG = "true"
Initialize-AIWorkflowOrchestrator -EnabledAgents @("claude") -Verbose
```

## Testing

### Unit Tests

Run domain-specific tests:

```powershell
# Run all AI agents tests
Invoke-Pester -Path "./tests/domains/ai-agents/" -Output Detailed

# Test specific module
Invoke-Pester -Path "./tests/domains/ai-agents/AIWorkflowOrchestrator.Tests.ps1"
```

### Integration Tests

Test with actual AI services:

```powershell
# Test Claude integration (requires API key)
Test-ClaudeIntegration -Verbose

# Test all integrations
Test-AllAIIntegrations -SkipLongRunning
```

## Performance Metrics

The AI agents domain tracks:

- **Response Times**: Average API response times
- **Token Usage**: Input/output token consumption
- **Success Rates**: API call success rates
- **Cost Tracking**: Estimated costs per provider
- **Workflow Efficiency**: Multi-agent workflow performance

## Security Considerations

1. **API Key Protection**: Never log or expose API keys
2. **Data Privacy**: Code sent to AI services is subject to their privacy policies
3. **Network Security**: All API calls use HTTPS encryption
4. **Access Control**: Implement proper access controls for AI features
5. **Audit Logging**: All AI interactions are logged for audit purposes

## Contributing

When contributing to the AI agents domain:

1. **Follow naming conventions** for consistency
2. **Include comprehensive tests** for new functions
3. **Update documentation** for any changes
4. **Test with multiple agents** to ensure compatibility
5. **Monitor performance impact** of new features

## Support

For issues with the AI agents domain:

1. Check the [AI Agents Setup Guide](../../docs/ai-agents-setup.md)
2. Run validation: `./az 0730 -ValidateOnly -Verbose`
3. Review logs: `./logs/aitherzero.log`
4. Test individual agents with their respective validation scripts

## References

- [AI Agents Setup Guide](../../docs/ai-agents-setup.md)
- [AitherZero Architecture](../../docs/architecture.md)
- [Configuration Guide](../../docs/configuration.md)
- [Testing Guide](../../docs/testing.md)