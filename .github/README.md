# .github Directory - GitHub Configuration

This directory contains GitHub-specific configuration files, workflows, and the GitHub Copilot agent routing system.

## 🤖 GitHub Copilot Agent Routing System

AitherZero includes an **automatic agent routing system** that suggests specialized custom agents for PR reviews based on the files you change and keywords in your PR.

### Quick Start
1. **Open a PR** - Agent suggestions appear automatically
2. **Request agents** - Use `@agent-name` or `/command` in comments
3. **Collaborate** - Multiple agents can work together

### Documentation
- **[AGENT-QUICK-START.md](AGENT-QUICK-START.md)** - Quick reference card
- **[AGENT-ROUTING-GUIDE.md](AGENT-ROUTING-GUIDE.md)** - Complete documentation
- **[AGENT-EXAMPLES.md](AGENT-EXAMPLES.md)** - Real-world usage examples

### Available Agents
- 🏗️ **Maya** - Infrastructure & DevOps (`@maya`, `/infrastructure`)
- 🔒 **Sarah** - Security & Compliance (`@sarah`, `/security`)
- 🧪 **Jessica** - Testing & QA (`@jessica`, `/testing`)
- 🎨 **Emma** - Frontend & UX (`@emma`, `/ui`)
- ⚙️ **Marcus** - Backend & API (`@marcus`, `/backend`)
- 📚 **Olivia** - Documentation (`@olivia`, `/docs`)
- ⚡ **Rachel** - PowerShell & Automation (`@rachel`, `/powershell`)
- 📋 **David** - Project Management (`@david`, `/pm`)

See [agents/README.md](agents/README.md) for detailed agent profiles.

## 📁 Directory Structure

```
.github/
├── README.md                          # This file
│
├── 🤖 Agent Routing System
│   ├── copilot.yaml                   # Agent routing configuration
│   ├── AGENT-ROUTING-GUIDE.md         # Complete documentation
│   ├── AGENT-QUICK-START.md           # Quick reference
│   ├── AGENT-EXAMPLES.md              # Usage examples
│   └── agents/                        # Agent profiles directory
│       ├── README.md                  # Agent team overview
│       ├── QUICK-REFERENCE.md         # Agent quick ref
│       ├── maya-infrastructure.md     # 🏗️ Infrastructure agent
│       ├── sarah-security.md          # 🔒 Security agent
│       ├── jessica-testing.md         # 🧪 Testing agent
│       ├── emma-frontend.md           # 🎨 Frontend agent
│       ├── marcus-backend.md          # ⚙️ Backend agent
│       ├── olivia-documentation.md    # 📚 Documentation agent
│       ├── rachel-powershell.md       # ⚡ PowerShell agent
│       └── david-project-manager.md   # 📋 Project manager agent
│
├── 📋 Templates
│   ├── pull_request_template.md       # PR template (includes agent info)
│   └── ISSUE_TEMPLATE/                # Issue templates
│
├── ⚙️ Workflows (GitHub Actions)
│   └── workflows/
│       ├── copilot-agent-router.yml   # Agent routing automation
│       ├── pr-validation.yml          # PR validation checks
│       ├── quality-validation.yml     # Code quality checks
│       ├── comment-release.yml        # Release via comment
│       ├── release-automation.yml     # Release automation
│       ├── documentation-automation.yml # Auto-generate documentation
│       ├── index-automation.yml       # Auto-generate project indexes
│       └── [other workflows...]
│
└── 📚 Documentation
    ├── copilot-instructions.md        # General Copilot instructions
    ├── WORKFLOW-COORDINATION.md       # Workflow coordination docs
    ├── ../docs/AUTOMATED-DOC-INDEX-UPDATES.md  # Doc & Index automation guide
    └── [other docs...]
```

## 🚀 How Agent Routing Works

### Automatic Suggestions (When PR Opens)

The [copilot-agent-router.yml](workflows/copilot-agent-router.yml) workflow:

1. **Analyzes** changed files and patterns
2. **Reads** PR title and description for keywords
3. **Calculates** relevance scores for each agent
4. **Suggests** top 1-3 agents in a comment
5. **Provides** commands to engage each agent

### Manual Invocation (In PR Comments)

Use mentions or commands:
```
@maya, please review the VM configuration
/infrastructure
```

The workflow:
1. **Detects** agent mention or command
2. **Reacts** to your comment (👀)
3. **Posts** acknowledgment and guidance

## 🎯 Agent Routing Rules

Defined in [copilot.yaml](copilot.yaml):

### File Pattern Matching
```yaml
maya:
  file_patterns:
    - "infrastructure/**/*"
    - "automation-scripts/01[0-9][0-9]_*.ps1"
    - "**/*.tf"
```

### Keyword Detection
```yaml
sarah:
  keywords:
    - "security"
    - "certificate"
    - "credential"
```

### Label-Based Routing
```yaml
jessica:
  labels:
    - testing
    - qa
    - quality
```

## 🤝 Collaboration Patterns

Pre-configured multi-agent workflows:

### Infrastructure Setup
```
Maya → Sarah → Jessica → Olivia
Deploy → Secure → Test → Document
```

### Feature Development
```
David → Marcus/Rachel → Jessica → Olivia
Plan → Build → Test → Document
```

See [AGENT-ROUTING-GUIDE.md](AGENT-ROUTING-GUIDE.md) for all patterns.

## 📊 Integration with AitherZero

Agents map to the **number-based orchestration system** (0000-9999):

| Range | Primary | Secondary | Purpose |
|-------|---------|-----------|---------|
| 0000-0099 | ⚡ Rachel | 🏗️ Maya | Environment |
| 0100-0199 | 🏗️ Maya | 🔒 Sarah | Infrastructure |
| 0200-0299 | ⚙️ Marcus | ⚡ Rachel | Dev Tools |
| 0400-0499 | 🧪 Jessica | ⚙️ Marcus | Testing |
| 0500-0599 | 📚 Olivia | 📋 David | Reporting |
| 0700-0799 | ⚡ Rachel | 📋 David | Git & AI |
| 9000-9999 | 🏗️ Maya | ⚡ Rachel | Maintenance |

## 🔧 Configuration Files

### copilot.yaml
Main configuration defining:
- All 8 agents with expertise areas
- File pattern matching rules
- Keyword detection
- Label-based routing
- Collaboration patterns
- Command aliases

### workflows/copilot-agent-router.yml
Automation workflow handling:
- PR change analysis
- Agent relevance scoring
- Automatic comment posting
- Command parsing and acknowledgment

## 💡 Best Practices

### When Creating PRs
1. **Use descriptive titles** with relevant keywords
2. **Apply appropriate labels** (infrastructure, security, testing, etc.)
3. **Include context** in PR description
4. **Reference script numbers** if applicable (e.g., "Updates 0105_Create-VM.ps1")

### When Engaging Agents
1. **Be specific** about what you need reviewed
2. **Provide context** and background information
3. **Reference files/lines** for targeted feedback
4. **Use collaboration** for complex tasks

### For Repository Maintainers
1. **Keep agent profiles updated** in `agents/`
2. **Adjust routing rules** in `copilot.yaml` as needed
3. **Monitor agent suggestions** for accuracy
4. **Update documentation** when adding agents

## 🔍 Troubleshooting

### Agent Not Suggested?
- Check if files match patterns in `copilot.yaml`
- Add relevant keywords to PR title/description
- Apply appropriate labels
- Manually invoke with `@agent-name` or `/command`

### Wrong Agent Suggested?
- System learns from file patterns and keywords
- Manually invoke the correct agent
- Consider updating `copilot.yaml` rules

### Multiple Agents Needed?
- Use collaboration patterns
- Tag multiple agents: `@maya @sarah @jessica`
- Request coordination: `@david, please coordinate review team`

## 📚 Additional Resources

### Main Repository Documentation
- [README.md](../README.md) - Project overview
- [CONTRIBUTING.md](../CONTRIBUTING.md) - Contribution guidelines
- [copilot-instructions.md](copilot-instructions.md) - General Copilot guidance

### Agent System Documentation
- [agents/README.md](agents/README.md) - Team overview and profiles
- [agents/QUICK-REFERENCE.md](agents/QUICK-REFERENCE.md) - Fast lookup guide
- [agents/TEAM-SUMMARY.txt](agents/TEAM-SUMMARY.txt) - Team roster

### Workflow Documentation
- [WORKFLOW-COORDINATION.md](WORKFLOW-COORDINATION.md) - GitHub Actions coordination
- [workflows/](workflows/) - All workflow files

## 🎓 Learning More

### Understanding the System
1. Read [AGENT-QUICK-START.md](AGENT-QUICK-START.md) - 5 minute overview
2. Review [AGENT-EXAMPLES.md](AGENT-EXAMPLES.md) - Real-world scenarios
3. Study [AGENT-ROUTING-GUIDE.md](AGENT-ROUTING-GUIDE.md) - Complete details

### Trying It Out
1. Create a test PR with infrastructure changes
2. Watch for automatic agent suggestions
3. Try manual invocation: `@maya, hello!`
4. Request multiple agents for complex reviews

---

**Questions?** Open an issue or use `@david` for coordination!

**Contributing?** See agent profiles and routing config to understand the system!

*Last updated: October 2025 | AitherZero Project*
