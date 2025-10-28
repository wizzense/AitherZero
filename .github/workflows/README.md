# AitherZero GitHub Actions Workflows

This directory contains all automated workflows for AitherZero, including multi-agent AI collaboration between Claude, Copilot, and eventually Gemini.

## Quick Start

### Setup Claude Integration

```bash
# 1. Add API key to repository secrets
Settings > Secrets > Actions > New repository secret
Name: ANTHROPIC_API_KEY
Secret: sk-ant-api03-your-key-here

# 2. Claude will automatically review new PRs
# Or mention Claude in any PR/issue:
@claude please review the security aspects of this change
```

### Multi-Agent Collaboration

```bash
# Trigger coordinated analysis from all agents
Actions > AI Agent Coordinator > Run workflow
- Agent Type: multi-agent
- Priority: normal
```

## Key Workflows

- **`claude-ai-assistant.yml`** - Claude AI strategic analysis and collaboration
- **`ai-agent-coordinator.yml`** - Multi-agent coordination (Claude + Copilot + AitherZero)
- **`automated-copilot-agent.yml`** - Automated issue creation for Copilot
- **`copilot-pr-automation.yml`** - Copilot implementation and PR creation
- **`intelligent-ci-orchestrator.yml`** - Comprehensive CI/CD

## Documentation

For detailed information, see:
- [Claude Integration Guide](../../docs/Claude-Integration-Guide.md)
- [AI Integration Guide](../../docs/AI-Integration-Guide.md)

---
**Last Updated:** 2025-10-27
