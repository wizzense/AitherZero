# GitHub Copilot Quick Reference

This is a quick reference guide for using GitHub Copilot with AitherZero. For detailed information, see the full documentation.

## Setup Checklist

- [ ] Install GitHub Copilot extensions in VS Code
- [ ] Install recommended extensions (prompted by VS Code)
- [ ] Set `GITHUB_TOKEN` environment variable for MCP servers
- [ ] Install Node.js 18+ for MCP servers
- [ ] Open in Dev Container OR install local dependencies

## Custom Agents

Route work to specialized experts using `/agent-name` or `@agent-name`:

| Agent | Expertise | Example Usage |
|-------|-----------|---------------|
| **maya** | Infrastructure, Hyper-V, OpenTofu, Networking | `/infrastructure Design VM network` |
| **sarah** | Security, Certificates, Credentials | `@sarah Review cert storage` |
| **jessica** | Testing, Pester, QA | `@jessica Create unit tests` |
| **emma** | UI/UX, Console, Menus | `@emma Design new menu` |
| **marcus** | Backend, Modules, APIs | `@marcus Optimize module loading` |
| **olivia** | Documentation, Writing | `@olivia Document this function` |
| **rachel** | PowerShell, Automation | `@rachel Improve this script` |
| **david** | Project Management | `@david Plan feature rollout` |

## MCP Servers

Enhanced context providers (auto-enabled):

| Server | Purpose | Example |
|--------|---------|---------|
| **filesystem** | Repository access | `@workspace List all test files` |
| **github** | GitHub API | `@workspace Create issue for bug` |
| **git** | Version control | `@workspace Show recent changes` |
| **powershell-docs** | Best practices | `@workspace PowerShell error handling` |
| **sequential-thinking** | Complex planning | `@workspace Design deployment workflow` |

## Common Prompts

### Code Generation
```
@workspace Create a new function in the utilities domain that:
- Validates input parameters
- Uses Write-CustomLog for logging
- Handles errors properly
- Works cross-platform
- Includes comment-based help
```

### Testing
```
@jessica Create Pester tests for this function with:
- Parameter validation tests
- Success case tests
- Error handling tests
- Mock external dependencies
```

### Infrastructure
```
/infrastructure I need to:
- Create a Hyper-V VM configuration
- Set up networking for 3 VMs
- Configure shared storage
```

### Security Review
```
@sarah Review this code for security issues:
- Credential storage
- Certificate handling
- Input validation
- Error messages (sensitive data exposure)
```

### Documentation
```
@olivia Create documentation for this module:
- Overview and purpose
- Function descriptions
- Usage examples
- Parameter details
```

### Refactoring
```
@workspace Refactor this function to:
- Follow AitherZero patterns
- Improve error handling
- Add proper logging
- Make it cross-platform
```

## VS Code Tasks

Press `Ctrl+Shift+B` (build) or `Ctrl+Shift+P` → "Tasks: Run Task"

- **Run Unit Tests** - Execute Pester test suite
- **Run PSScriptAnalyzer** - Lint PowerShell code
- **Validate Syntax** - Check for syntax errors
- **Run Quick Tests** - Fast validation suite
- **Generate Project Report** - Status and metrics
- **Quality Check** - Validate component quality

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Tab` | Accept Copilot suggestion |
| `Alt+]` | Next suggestion |
| `Alt+[` | Previous suggestion |
| `Esc` | Reject suggestion |
| `Ctrl+Shift+I` | Open Copilot Chat |
| `Ctrl+Shift+B` | Run build task |
| `F5` | Start debugging |

## Best Practices

### ✅ Do
- Reference custom instructions explicitly
- Use appropriate agents for specialized work
- Provide architectural context in prompts
- Validate all AI-generated code
- Run tests and linters
- Iterate incrementally

### ❌ Don't
- Trust suggestions blindly
- Skip testing and validation
- Ignore security warnings
- Make large changes without review
- Commit without running quality checks

## Troubleshooting

### Copilot Not Working
1. Check license is active
2. Verify extension is installed
3. Reload VS Code window
4. Check file type is enabled

### Agents Not Routing
1. Verify `.github/copilot.yaml` exists
2. Use manual invocation: `/agent-name`
3. Check file patterns match
4. Restart VS Code

### MCP Servers Not Loading
1. Install Node.js 18+
2. Set `GITHUB_TOKEN` environment variable
3. Check VS Code output panel
4. Validate `mcp-servers.json` syntax

## Quick Links

- [Full Dev Environment Guide](COPILOT-DEV-ENVIRONMENT.md)
- [MCP Setup Guide](COPILOT-MCP-SETUP.md)
- [Custom Instructions](../.github/copilot-instructions.md)
- [Agent Routing Config](../.github/copilot.yaml)
- [Development Setup](DEVELOPMENT-SETUP.md)

## Example Workflow

1. **Start task**: Open VS Code, use Dev Container or local setup
2. **Understand context**: `@workspace Explain the domain structure`
3. **Get guidance**: `/infrastructure How should I structure VM deployment?`
4. **Generate code**: `@workspace Create function following patterns`
5. **Add tests**: `@jessica Create tests for this function`
6. **Validate**: Run tasks → PSScriptAnalyzer, Unit Tests
7. **Document**: `@olivia Add documentation for this change`
8. **Review**: `@sarah Security review of credential handling`
9. **Commit**: Use quality checks before committing

## Getting Help

- **In Copilot Chat**: `@workspace How do I...?`
- **Documentation**: Browse `docs/` directory
- **Agent Help**: `/agent-name` for specialist assistance
- **GitHub Issues**: Report problems or request features

---

**Happy coding with AI! 🚀🤖**
