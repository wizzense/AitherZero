# Claude AI Integration Guide for AitherZero

## Overview

This guide explains how to integrate Claude AI (Anthropic's advanced language model) into your AitherZero automated workflows, enabling seamless collaboration between Claude, GitHub Copilot, and eventually Google Gemini for comprehensive code review, issue management, and PR automation.

## Table of Contents

1. [Architecture](#architecture)
2. [Setup](#setup)
3. [Workflow Integration](#workflow-integration)
4. [Usage Patterns](#usage-patterns)
5. [Collaboration Workflows](#collaboration-workflows)
6. [Configuration](#configuration)
7. [Troubleshooting](#troubleshooting)
8. [Best Practices](#best-practices)

## Architecture

### Multi-Agent Collaboration Model

The AitherZero AI integration uses a collaborative multi-agent architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Repository                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Issues     │  │     PRs      │  │   Comments   │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │               │
│         └──────────────────┴──────────────────┘               │
│                            │                                   │
└────────────────────────────┼───────────────────────────────────┘
                             │
                ┌────────────┴────────────┐
                │                         │
        ┌───────▼────────┐       ┌───────▼────────┐
        │  Event Trigger │       │  @mention      │
        │  (PR/Issue)    │       │  Detection     │
        └───────┬────────┘       └───────┬────────┘
                │                         │
                └────────────┬────────────┘
                             │
                ┌────────────▼─────────────┐
                │  Claude AI Assistant     │
                │  Workflow                │
                │  ┌─────────────────────┐ │
                │  │ 1. Detect Trigger   │ │
                │  │ 2. Gather Context   │ │
                │  │ 3. AI Analysis      │ │
                │  │ 4. Post Results     │ │
                │  │ 5. Collaborate      │ │
                │  └─────────────────────┘ │
                └────────┬────────┬────────┘
                         │        │
              ┌──────────┘        └──────────┐
              │                               │
    ┌─────────▼─────────┐         ┌─────────▼─────────┐
    │  GitHub Copilot   │         │  AitherZero       │
    │  - Implementation │         │  - Validation     │
    │  - Code Gen       │         │  - Testing        │
    │  - PR Creation    │         │  - Quality Check  │
    └─────────┬─────────┘         └─────────┬─────────┘
              │                               │
              └───────────┬───────────────────┘
                          │
                  ┌───────▼────────┐
                  │  Final Review  │
                  │  & Merge       │
                  └────────────────┘
```

### Agent Roles

1. **Claude AI** (`claude-ai-assistant.yml`)
   - Strategic analysis and architectural review
   - Security and compliance assessment
   - Best practices recommendations
   - Complex problem analysis
   - Documentation review

2. **GitHub Copilot** (`automated-copilot-agent.yml`, `copilot-pr-automation.yml`)
   - Code implementation
   - Test generation
   - Issue resolution
   - PR creation and updates

3. **AitherZero** (Orchestration workflows)
   - Automated validation (PSScriptAnalyzer, Pester)
   - Quality assurance
   - Test execution
   - Report generation

## Setup

### Prerequisites

- GitHub repository with AitherZero installed
- GitHub Actions enabled
- Admin access to repository settings

### Step 1: Configure Claude API Key

1. **Obtain an Anthropic API Key**
   - Sign up at https://console.anthropic.com/
   - Generate an API key from your account settings

2. **Add to GitHub Secrets**
   ```bash
   # Navigate to your repository on GitHub
   # Settings > Secrets and variables > Actions > New repository secret

   Name: ANTHROPIC_API_KEY
   Secret: sk-ant-api03-your-actual-key-here
   ```

3. **Verify Configuration**
   - The `claude-ai-assistant.yml` workflow will automatically detect the API key
   - If not configured, workflows will skip Claude analysis gracefully

### Step 2: Enable Workflows

All workflows should already be present in `.github/workflows/`:

- ✅ `claude-ai-assistant.yml` - New Claude integration
- ✅ `ai-agent-coordinator.yml` - Updated with Claude support
- ✅ `automated-copilot-agent.yml` - Existing Copilot automation
- ✅ `copilot-pr-automation.yml` - Existing PR automation
- ✅ `copilot-issue-commenter.yml` - Existing issue management

### Step 3: Test Integration

Trigger a test workflow manually:

```bash
# Via GitHub UI
Actions > Claude AI Assistant > Run workflow
- Analysis Type: code-review
- Target: (leave empty for repo-wide)
- Collaborate with: copilot

# Or create a test PR with @claude mention
```

## Workflow Integration

### Automatic Triggers

Claude AI Assistant automatically activates on:

1. **Pull Request Events**
   ```yaml
   pull_request:
     types: [opened, synchronize, ready_for_review]
   ```
   - Provides code review on new or updated PRs
   - Collaborates with Copilot on implementation

2. **Issue Events**
   ```yaml
   issues:
     types: [opened, labeled, assigned]
   ```
   - Analyzes new issues
   - Provides strategic guidance on auto-created issues

3. **Comment Mentions**
   ```yaml
   issue_comment:
     types: [created]
   ```
   - Responds when @claude is mentioned
   - Provides on-demand analysis

4. **After Copilot Workflows**
   ```yaml
   workflow_run:
     workflows: ["Automated Copilot Agent"]
     types: [completed]
   ```
   - Reviews Copilot's work
   - Provides additional insights
   - Suggests improvements

### Manual Triggers

```bash
# Via GitHub Actions UI
Actions > Claude AI Assistant > Run workflow

Options:
- Analysis Type: code-review | architecture | security | performance | testing
- Target: PR number, issue number, or file path
- Collaborate with: none | copilot | gemini | all
```

## Usage Patterns

### Pattern 1: PR Review with Claude + Copilot

**Scenario:** New pull request needs review and validation

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant PR as Pull Request
    participant Claude as Claude AI
    participant Copilot as GitHub Copilot
    participant AZ as AitherZero

    Dev->>PR: Create/Update PR
    PR->>Claude: Trigger analysis
    Claude->>Claude: Strategic review
    Claude->>PR: Post insights
    PR->>Copilot: Notify for implementation
    Copilot->>Copilot: Review suggestions
    Copilot->>PR: Implement changes
    PR->>AZ: Run validation
    AZ->>PR: Quality report
    PR->>Dev: Ready for merge
```

**Commands:**
```bash
# Claude automatically reviews when PR is created
# To request specific analysis, comment on PR:
@claude please review the security aspects of this change

# Copilot responds to Claude's suggestions automatically
# Or you can explicitly request:
@copilot please implement Claude's recommendation #3
```

### Pattern 2: Issue Analysis and Resolution

**Scenario:** Complex issue requires multi-agent analysis

```bash
# 1. Create issue with 'claude' or 'ai-review' label
# 2. Claude analyzes and posts strategic guidance
# 3. Copilot receives task assignment
# 4. Copilot creates PR with implementation
# 5. Claude reviews Copilot's PR
# 6. AitherZero validates
# 7. Human reviewer approves
```

### Pattern 3: Architecture Review

**Scenario:** Major refactoring needs architectural guidance

```bash
# Trigger manual Claude analysis
Actions > Claude AI Assistant > Run workflow
- Analysis Type: architecture
- Target: (leave empty for full repo)
- Collaborate with: all

# Claude will analyze:
# - Design patterns and principles
# - Module dependencies
# - Scalability concerns
# - Maintainability issues
# - Performance implications
```

### Pattern 4: Security Audit

**Scenario:** Security review before production deployment

```bash
# Trigger comprehensive security analysis
Actions > Claude AI Assistant > Run workflow
- Analysis Type: security
- Target: (leave empty or specify PR)
- Collaborate with: all

# Then trigger security validation
Actions > AI Agent Coordinator > Run workflow
- Agent Type: security
- Priority: high

# Combined Claude + AitherZero security analysis
```

### Pattern 5: Mention-based Interaction

**Scenario:** On-demand help during development

```bash
# In any PR or issue, mention Claude:
@claude what's the best way to implement caching here?

# Claude responds with:
# - Analysis of context
# - Recommendations
# - Code examples
# - Links to relevant docs
```

## Collaboration Workflows

### Claude + Copilot Collaboration

**How it works:**
1. Claude provides strategic analysis and recommendations
2. Copilot is tagged for implementation
3. Copilot creates code based on Claude's guidance
4. Claude reviews Copilot's implementation
5. Iteration continues until approved

**Example:**
```markdown
## Claude's Analysis
- Recommendation 1: Implement caching layer
- Recommendation 2: Add error handling
- Recommendation 3: Optimize database queries

@copilot Please implement these recommendations.
Focus on Recommendation 1 first.

## Copilot's Response
I'll implement the caching layer. Creating PR...

## Claude's Review
Caching implementation looks good. Consider adding:
- Cache invalidation strategy
- TTL configuration
```

### Multi-Agent Coordination

Trigger coordinated analysis from all agents:

```bash
# Via workflow dispatch
Actions > AI Agent Coordinator > Run workflow
- Agent Type: multi-agent
- Priority: normal

# This activates:
# 1. Claude AI - Strategic analysis
# 2. Copilot - Implementation planning
# 3. AitherZero - Quality validation
# 4. Comprehensive reporting
```

### Adding Gemini Support (Future)

The architecture supports adding Google Gemini:

```yaml
# In .github/workflows/gemini-ai-assistant.yml (future)
on:
  workflow_run:
    workflows: ["Claude AI Assistant"]
    types: [completed]

# Gemini will provide:
# - Alternative perspectives
# - Different analysis angles
# - Consensus with Claude
# - Conflict resolution
```

## Configuration

### Claude Workflow Configuration

Edit `.github/workflows/claude-ai-assistant.yml`:

```yaml
env:
  CLAUDE_MODEL: claude-sonnet-4-5-20250929
  CLAUDE_MAX_TOKENS: 8192
  CLAUDE_TEMPERATURE: 0.7  # Lower = more deterministic
```

### AI Coordinator Configuration

Edit `.github/workflows/ai-agent-coordinator.yml`:

```yaml
# Add Claude to agent options
agent_type:
  options: ['code-review', 'claude', 'multi-agent']
```

### Repository Configuration

Edit `config.json` (if using local AI scripts):

```json
{
  "AI": {
    "Providers": {
      "Claude": {
        "Enabled": true,
        "ApiKeyEnvVar": "ANTHROPIC_API_KEY",
        "Model": "claude-sonnet-4-5-20250929",
        "MaxTokens": 8192,
        "Temperature": 0.7,
        "Priority": 1
      }
    }
  }
}
```

## Troubleshooting

### Issue: Claude workflow not triggering

**Symptoms:**
- PRs created but no Claude analysis
- No comments from Claude AI

**Solutions:**
```bash
# 1. Check API key is configured
Settings > Secrets > ANTHROPIC_API_KEY (should exist)

# 2. Check workflow file is present
ls .github/workflows/claude-ai-assistant.yml

# 3. Check workflow is enabled
Actions > Claude AI Assistant (should not be disabled)

# 4. Manually trigger to test
Actions > Claude AI Assistant > Run workflow

# 5. Check workflow logs
Actions > Recent workflow runs > View logs
```

### Issue: Claude analysis skipped

**Symptoms:**
- Workflow runs but says "API key not configured"

**Solutions:**
```bash
# 1. Verify secret name matches exactly
Secret name must be: ANTHROPIC_API_KEY

# 2. Re-add the secret
Settings > Secrets > Remove ANTHROPIC_API_KEY
Settings > Secrets > New secret > ANTHROPIC_API_KEY

# 3. Check secret scope
Ensure it's a repository secret, not environment secret

# 4. Test with manual trigger
Actions > Claude AI Assistant > Run workflow
```

### Issue: Claude and Copilot not collaborating

**Symptoms:**
- Claude posts analysis but Copilot doesn't respond

**Solutions:**
```bash
# 1. Check Copilot workflows are enabled
Actions > Automated Copilot Agent (should be enabled)

# 2. Verify collaboration trigger
Check if PR/issue has 'auto-created' label

# 3. Manually trigger collaboration
@copilot please review Claude's recommendations above

# 4. Check workflow_run permissions
Settings > Actions > General > Workflow permissions > Read and write
```

### Issue: Rate limiting or API errors

**Symptoms:**
- 429 errors in logs
- "Rate limit exceeded" messages

**Solutions:**
```bash
# 1. Check API usage
Visit: https://console.anthropic.com/settings/usage

# 2. Implement retry logic (already built-in)
# Workflows will automatically retry with backoff

# 3. Adjust workflow triggers
# Limit to specific events instead of all PR updates

# 4. Use workflow concurrency control
# Edit .github/workflows/claude-ai-assistant.yml
concurrency:
  group: claude-${{ github.ref }}
  cancel-in-progress: true
```

## Best Practices

### 1. Effective Prompting

When mentioning Claude in comments:

```bash
# ✅ Good - Specific request
@claude please review the error handling in the AuthService.ps1 file
focusing on security implications

# ❌ Bad - Too vague
@claude check this

# ✅ Good - Context provided
@claude this PR implements caching. Please review if the cache
invalidation strategy is sound and suggest improvements

# ❌ Bad - No context
@claude review
```

### 2. Label Management

Use labels to control workflow behavior:

```bash
# Trigger Claude analysis
Labels: 'claude', 'ai-review', 'architecture-review'

# Prevent Claude analysis on draft PRs
Labels: 'wip', 'draft', 'do-not-review'

# Request specific analysis
Labels: 'security-review', 'performance-review'
```

### 3. Collaboration Etiquette

```bash
# When Claude suggests something:
# 1. Acknowledge: "Thanks @claude, I'll implement #1 and #2"
# 2. Ask for clarification: "@claude can you elaborate on #3?"
# 3. Tag Copilot: "@copilot please implement Claude's suggestion #1"

# When Copilot implements:
# 1. Tag Claude for review: "@claude please review Copilot's implementation"
# 2. Iterate: Continue conversation until consensus
```

### 4. Cost Management

```bash
# Claude API has usage costs - optimize:

# 1. Use targeted analysis instead of full repo
@claude please review src/core/Security.ps1 only

# 2. Limit analysis frequency
# Don't trigger on every commit - use ready_for_review

# 3. Use local validation first
./az.ps1 0404  # PSScriptAnalyzer
./az.ps1 0402  # Tests
# Then request Claude review

# 4. Monitor usage
Visit: https://console.anthropic.com/settings/usage
```

### 5. Security Considerations

```bash
# 1. Never commit API keys
# Use GitHub Secrets only

# 2. Rotate API keys regularly
# Update ANTHROPIC_API_KEY secret every 90 days

# 3. Limit workflow permissions
# Use minimum required permissions in workflow files

# 4. Review Claude's suggestions
# Always human-review before implementing AI suggestions

# 5. Use branch protection
# Require human approval even with AI validation
```

## Integration Examples

### Example 1: Full PR Review Workflow

```bash
# 1. Developer creates PR
git checkout -b feature/new-caching
git commit -m "Implement Redis caching"
git push origin feature/new-caching
# Create PR on GitHub

# 2. Claude automatically analyzes
# Posts strategic review with recommendations

# 3. Developer responds
@claude thanks! Can you elaborate on #2 about cache invalidation?

# 4. Claude provides details
# Detailed analysis of cache invalidation strategies

# 5. Developer tags Copilot
@copilot please implement Claude's cache invalidation suggestion

# 6. Copilot creates commit
# Adds cache invalidation logic

# 7. AitherZero validates
# Runs PSScriptAnalyzer, tests, security scans

# 8. Claude reviews implementation
# Confirms Copilot's implementation matches recommendations

# 9. Human reviewer approves and merges
```

### Example 2: Complex Issue Resolution

```bash
# 1. Issue created: "Performance degradation in report generation"
# Label: 'performance', 'auto-created'

# 2. Claude analyzes issue
# Posts: Root cause analysis, optimization strategies

# 3. Copilot assigned automatically
@copilot assigned via automated workflow

# 4. Copilot creates investigation PR
# Branch: copilot/fix-issue-123
# Initial analysis and profiling

# 5. Claude reviews findings
@claude please review the profiling results in this PR

# 6. Claude provides optimization guidance
# Specific recommendations: query optimization, caching, indexing

# 7. Copilot implements optimizations
# Updates PR with Claude's recommendations

# 8. AitherZero validates performance
./az.ps1 0734  # Performance analysis
# Confirms improvements

# 9. PR merged, issue closed
```

### Example 3: Security Audit Before Release

```bash
# Trigger comprehensive security audit
Actions > Claude AI Assistant
- Analysis Type: security
- Collaborate with: all

Actions > AI Agent Coordinator
- Agent Type: multi-agent
- Priority: high

# Results in:
# 1. Claude: Strategic security analysis
# 2. AitherZero: Automated security scans
# 3. Combined report with all findings
# 4. Prioritized remediation list
# 5. Issue creation for critical items
# 6. Copilot assignments for fixes
```

## Roadmap

### Current Capabilities (v1.0)

- ✅ Claude integration in GitHub Actions
- ✅ Collaboration with Copilot
- ✅ PR and issue analysis
- ✅ @mention support
- ✅ Multi-agent coordination

### Planned Enhancements (v1.1)

- [ ] Google Gemini integration
- [ ] Advanced caching for repeated analyses
- [ ] Custom analysis profiles
- [ ] Real-time streaming responses
- [ ] Enhanced context awareness

### Future Features (v2.0)

- [ ] Local LLM support (Ollama)
- [ ] Custom fine-tuned models
- [ ] Web dashboard for monitoring
- [ ] Advanced metrics and analytics
- [ ] IDE integration (VS Code)
- [ ] Slack/Teams notifications

## Support

### Getting Help

1. **Documentation**
   - This guide
   - [AI Integration Guide](./AI-Integration-Guide.md)
   - [Workflow Reference](../.github/workflows/README.md)

2. **Troubleshooting**
   - Check workflow logs in Actions tab
   - Review error messages in PR/issue comments
   - Verify API key configuration

3. **Community**
   - Create issue on GitHub
   - Tag with 'claude-integration' label
   - Provide workflow logs and error messages

4. **API Status**
   - Anthropic Status: https://status.anthropic.com/
   - GitHub Status: https://www.githubstatus.com/

### Contributing

We welcome contributions to improve Claude integration:

- Better prompts for specific scenarios
- Additional analysis types
- Enhanced collaboration patterns
- Documentation improvements
- Bug fixes and optimizations

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

## License

This integration follows the same license as AitherZero.

See [LICENSE](../LICENSE) for details.

---

**Last Updated:** 2025-10-27
**Version:** 1.0.0
**Maintainer:** AitherZero Team
