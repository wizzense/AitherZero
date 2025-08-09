# Claude Code Hooks System

This directory contains the Claude Code hooks configuration for AitherZero, providing intelligent, context-aware AI assistance for development workflows.

## Overview

The Claude Code hooks system integrates deeply with AitherZero's orchestration and automation capabilities, providing:

- **Context-aware assistance** based on current project state
- **Intelligent validation** of potentially dangerous operations
- **Automated follow-up actions** after tool usage
- **Project-specific guidance** for AitherZero workflows
- **Integration with existing automation scripts** and orchestration playbooks

## Hook Configuration

### Settings (`settings.json`)

The main configuration file defines:
- Hook script mappings
- Project metadata
- Development preferences
- Orchestration triggers

### Available Hooks

| Hook | Script | Purpose |
|------|--------|---------|
| `PreToolUse` | `pre-tool-use.ps1` | Validates operations before execution, adds context |
| `PostToolUse` | `post-tool-use.ps1` | Logs actions, triggers follow-up automation |
| `UserPromptSubmit` | `user-prompt-submit.ps1` | Analyzes intent, provides project-specific context |
| `SessionStart` | `session-start.ps1` | Initializes project context and environment |
| `SubagentStop` | `subagent-stop.ps1` | Processes subagent results, triggers workflows |

## Hook Features

### Pre-Tool-Use Validation

- **Safety checks** for dangerous commands (rm -rf, destructive operations)
- **Context injection** for AitherZero-specific operations
- **Environment validation** (initialization status, git state)
- **Best practice suggestions** (orchestration over individual scripts)

### Post-Tool-Use Automation

- **Automatic validation** of modified PowerShell files
- **Follow-up suggestions** based on completed actions
- **Activity logging** for audit trail
- **Background maintenance** (log cleanup, test report generation)

### User Prompt Intelligence

- **Intent analysis** (development, testing, infrastructure, CI/CD)
- **Project status context** (git branch, uncommitted changes, environment state)
- **Command suggestions** based on detected task type
- **Warning injection** for potentially destructive operations

### Session Context

- **Project overview** and architecture explanation
- **Available automation scripts** by category
- **Orchestration playbooks** with descriptions
- **Environment status** and quick-start tips
- **Auto-initialization** of AitherZero environment

### Subagent Integration

- **Result processing** for security scans, tests, syntax validation
- **Priority-based alerts** for critical findings
- **Automated reporting** and follow-up actions
- **Activity tracking** for compliance and audit

## Environment Variables

The hooks system uses these environment variables:

| Variable | Purpose | Default |
|----------|---------|---------|
| `CLAUDE_PROJECT_DIR` | Project root directory | (auto-detected) |
| `AITHERZERO_INITIALIZED` | Environment initialization status | `false` |
| `AITHERZERO_AUTO_VALIDATE` | Auto-trigger validation after edits | `false` |
| `AITHERZERO_AUTO_CI` | Auto-trigger CI after commits | `false` |
| `AITHERZERO_AUTO_SECURITY` | Auto-respond to security findings | `false` |
| `AITHERZERO_AUTO_REPORTS` | Auto-generate reports after tests | `false` |
| `AITHERZERO_AUTO_FOLLOWUP` | Enable automated follow-up actions | `false` |

## Integration with AitherZero

### Orchestration Triggers

The hooks system can trigger AitherZero automation:

```powershell
# Triggered by git commits
az 0404  # PSScriptAnalyzer validation
az 0407  # Syntax validation

# Triggered by branch creation  
az 0700  # Git environment setup
az 0701  # Branch configuration

# Triggered by PR creation
az 0703  # PR automation

# Triggered by CI events
seq test-ci  # CI test playbook
```

### Intelligent Context

Based on user prompts, the system provides relevant context:

- **Development tasks** → PowerShell best practices, testing guidance
- **Infrastructure work** → OpenTofu patterns, deployment playbooks
- **CI/CD questions** → GitHub Actions workflows, runner setup
- **Security concerns** → Scanning tools, compliance checks

### Automated Workflows

The system can trigger background automation:

- **File modifications** → Syntax validation, documentation updates
- **Test execution** → Report generation, coverage analysis
- **Security scans** → Alert processing, remediation workflows
- **Git operations** → CI validation, branch tracking

## Logging and Monitoring

### Hook Activity Logs

All hook executions are logged to:
- `logs/claude-hooks.log` - General hook activity
- `logs/activity.json` - Structured tool usage history  
- `logs/subagent-activity.json` - Subagent execution results

### Log Format

```
[2025-01-08 14:30:15] [INFO] PreToolUse: Tool use intercepted: Edit
[2025-01-08 14:30:16] [INFO] PostToolUse: File modified: automation-scripts/0720_Setup-GitHubRunners.ps1
[2025-01-08 14:30:20] [INFO] UserPromptSubmit: CI/CD task detected
```

## Security Considerations

### Protected Operations

The hooks system blocks or warns about:
- Destructive file operations (`rm -rf /`, etc.)
- Modifications to critical system files
- Potentially unsafe command patterns
- Operations without proper environment initialization

### Safe Defaults

- Hooks fail safely (allow operation if hook fails)
- No persistent state modification in hooks
- Proper input validation and error handling
- Audit trail for all hook executions

## Customization

### Adding New Hooks

1. Create new PowerShell script in `.claude/hooks/`
2. Update `settings.json` to reference the new hook
3. Follow existing patterns for input/output handling
4. Add appropriate logging and error handling

### Extending Functionality

- Modify existing hook scripts to add new validations
- Update trigger conditions in `settings.json`
- Add new environment variables for configuration
- Integrate with additional AitherZero automation scripts

### Integration Points

The hooks system integrates with:
- **AitherZero orchestration** (playbooks, sequences)
- **Automation scripts** (0000-9999 series)
- **Testing framework** (Pester, coverage, validation)
- **CI/CD pipelines** (GitHub Actions, self-hosted runners)
- **Security tools** (scanning, compliance, audit)

## Troubleshooting

### Common Issues

1. **Hooks not executing**
   - Check `CLAUDE_PROJECT_DIR` environment variable
   - Verify hook scripts have execute permissions
   - Review Claude Code settings configuration

2. **Validation failures**
   - Check PowerShell execution policy
   - Verify AitherZero environment initialization
   - Review hook logs for specific errors

3. **Context not appearing**
   - Ensure hooks are properly registered in `settings.json`
   - Check for JSON syntax errors in hook outputs
   - Verify project directory structure

### Debug Mode

Enable detailed logging by setting:
```powershell
$env:CLAUDE_HOOK_DEBUG = $true
```

This provides additional diagnostic information in the hook logs.

## Best Practices

### Hook Development

- Keep hooks fast and lightweight
- Handle errors gracefully (fail safe)
- Provide meaningful log messages
- Use consistent JSON output format
- Validate inputs thoroughly

### Project Integration

- Initialize AitherZero environment in new sessions
- Use orchestration commands (`seq`) for multi-step operations
- Leverage automation scripts (`az`) for individual tasks
- Monitor hook logs for optimization opportunities
- Configure environment variables for your workflow preferences

## Future Enhancements

The hooks system is designed for extensibility:

- **Multi-AI integration** (Claude, Gemini, Codex)
- **Advanced workflow automation** (conditional triggers)
- **Machine learning** (pattern recognition, optimization)
- **Integration APIs** (external tools, services)
- **Custom agent development** (domain-specific AI assistants)

This hooks system transforms Claude Code from a general AI assistant into a domain-specific, project-aware development partner for AitherZero infrastructure automation.