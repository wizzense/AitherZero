# GitHub Copilot Agent Routing - Quick Start

## 🎯 How It Works

When you **open or update a PR**, the system automatically:
1. ✅ Analyzes your file changes
2. ✅ Reads PR title and description 
3. ✅ Suggests 1-3 most relevant agents
4. ✅ Posts a comment with engagement commands

## 🤖 Request an Agent

### Using Mentions
```
@maya, please review the VM configuration
@sarah, check security of this change
@jessica and @olivia, add tests and docs
```

### Using Commands
```
/infrastructure  → Maya (DevOps)
/security       → Sarah (Security)
/testing        → Jessica (QA)
/ui             → Emma (UX)
/backend        → Marcus (API)
/docs           → Olivia (Documentation)
/powershell     → Rachel (Automation)
/pm             → David (Project Mgmt)
```

## 👥 Agent Quick Reference

| Icon | Agent | Expertise | When to Use |
|------|-------|-----------|-------------|
| 🏗️ | **Maya** | Infrastructure & DevOps | VMs, networks, Terraform, lab automation |
| 🔒 | **Sarah** | Security & Compliance | Certificates, credentials, vulnerabilities |
| 🧪 | **Jessica** | Testing & QA | Pester tests, coverage, quality metrics |
| 🎨 | **Emma** | Frontend & UX | Console UI, menus, user experience |
| ⚙️ | **Marcus** | Backend & API | PowerShell modules, APIs, performance |
| 📚 | **Olivia** | Documentation | READMEs, guides, technical writing |
| ⚡ | **Rachel** | PowerShell & Automation | Advanced scripts, orchestration |
| 📋 | **David** | Project Management | Planning, coordination, releases |

## 📁 Automatic Routing by File Type

| Files Changed | Suggested Agents |
|---------------|------------------|
| `infrastructure/`, `*.tf` | 🏗️ Maya, 🔒 Sarah |
| `domains/security/`, `*credential*.ps1` | 🔒 Sarah, 🏗️ Maya |
| `tests/`, `*.Tests.ps1` | 🧪 Jessica, ⚙️ Marcus |
| `domains/experience/`, `*menu*.ps1` | 🎨 Emma, ⚙️ Marcus |
| `domains/*.psm1`, `*api*.ps1` | ⚙️ Marcus, ⚡ Rachel |
| `*.md`, `docs/`, `README.md` | 📚 Olivia, 🎨 Emma |
| `*.ps1`, `orchestration/` | ⚡ Rachel, ⚙️ Marcus |
| `.github/workflows/*.yml` | 📋 David, ⚡ Rachel |

## 🔢 Script Range Mapping

Based on AitherZero's number-based orchestration (0000-9999):

| Script Range | Primary | Secondary | Purpose |
|--------------|---------|-----------|---------|
| 0000-0099 | ⚡ Rachel | 🏗️ Maya | Environment Prep |
| 0100-0199 | 🏗️ Maya | 🔒 Sarah | Infrastructure |
| 0200-0299 | ⚙️ Marcus | ⚡ Rachel | Dev Tools |
| 0400-0499 | 🧪 Jessica | ⚙️ Marcus | Testing |
| 0500-0599 | 📚 Olivia | 📋 David | Reporting |
| 0700-0799 | ⚡ Rachel | 📋 David | Git & AI |
| 9000-9999 | 🏗️ Maya | ⚡ Rachel | Maintenance |

## 🤝 Common Collaboration Patterns

### Infrastructure Setup
```
🏗️ Maya → 🔒 Sarah → 🧪 Jessica → 📚 Olivia
Deploy → Secure → Test → Document
```

### Feature Development
```
📋 David → ⚙️ Marcus/⚡ Rachel → 🧪 Jessica → 📚 Olivia
Plan → Build → Test → Document
```

### UI Development
```
🎨 Emma → ⚙️ Marcus → 🧪 Jessica → 📚 Olivia
Design → Backend → Test → Document
```

### Security Enhancement
```
🔒 Sarah → 🏗️ Maya → ⚙️ Marcus → 🧪 Jessica
Identify → Fix Infra → Update Code → Validate
```

## 💡 Pro Tips

✅ **Be specific** in your agent requests
```
Good: "@maya, review the nested virtualization config in lines 45-60"
Avoid: "@maya, check this"
```

✅ **Use multiple agents** for complex tasks
```
@maya @sarah, please review together - infrastructure with security focus
```

✅ **Check agent profiles** for detailed expertise
```
See: .github/agents/maya-infrastructure.md
```

✅ **Include context** in your requests
```
@jessica, I added tests for the new orchestration engine. 
Please review coverage and suggest edge cases.
```

## 📚 Full Documentation

- **Complete Guide**: [.github/AGENT-ROUTING-GUIDE.md](AGENT-ROUTING-GUIDE.md)
- **Agent Profiles**: [.github/agents/](agents/)
- **Configuration**: [.github/copilot.yaml](copilot.yaml)
- **Workflow**: [.github/workflows/copilot-agent-router.yml](workflows/copilot-agent-router.yml)

## 🔧 Configuration Files

```
.github/
├── copilot.yaml                    # Agent routing configuration
├── AGENT-ROUTING-GUIDE.md          # Complete documentation
├── pull_request_template.md        # Updated with agent info
├── agents/
│   ├── README.md                   # Team overview
│   ├── QUICK-REFERENCE.md          # Agent quick ref
│   ├── maya-infrastructure.md      # 🏗️ Maya's profile
│   ├── sarah-security.md           # 🔒 Sarah's profile
│   ├── jessica-testing.md          # 🧪 Jessica's profile
│   ├── emma-frontend.md            # 🎨 Emma's profile
│   ├── marcus-backend.md           # ⚙️ Marcus's profile
│   ├── olivia-documentation.md     # 📚 Olivia's profile
│   ├── rachel-powershell.md        # ⚡ Rachel's profile
│   └── david-project-manager.md    # 📋 David's profile
└── workflows/
    └── copilot-agent-router.yml    # Automation workflow
```

---

**Questions?** Open an issue or use `@david` for coordination!

*Last updated: October 2025 | AitherZero v1.0*
