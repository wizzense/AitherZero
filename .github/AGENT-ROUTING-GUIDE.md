# GitHub Copilot Agent Routing Guide

This guide explains how to use the automatic agent routing system for PR reviews and collaboration with custom GitHub Copilot agents.

## 🎯 Overview

The AitherZero repository includes 8 specialized custom agents that automatically assist with different aspects of development. The agent routing system analyzes your PR and suggests the most relevant agents based on:

- **File patterns**: Which files you've changed
- **Keywords**: Terms in your PR title and description
- **Labels**: Applied PR labels
- **Script ranges**: AitherZero's number-based orchestration system (0000-9999)

## 🤖 Available Agents

### 👩‍💻 Maya - Infrastructure & DevOps Specialist
**File:** [`.github/agents/maya-infrastructure.md`](.github/agents/maya-infrastructure.md)

**Best for:**
- Hyper-V and VM management
- OpenTofu/Terraform infrastructure code
- Network configuration
- Lab automation scripts (0100-0199 range)
- DevOps pipeline infrastructure

**Triggers:**
- Files: `infrastructure/`, `*.tf`, `*vm*.ps1`, `automation-scripts/01*.ps1`
- Keywords: `vm`, `hyper-v`, `network`, `infrastructure`, `terraform`
- Labels: `infrastructure`, `devops`, `networking`

**How to engage:**
```
@maya, please review the infrastructure changes in this PR
/infrastructure
```

---

### 👩‍💻 Sarah - Security & Compliance Expert
**File:** [`.github/agents/sarah-security.md`](.github/agents/sarah-security.md)

**Best for:**
- Certificate and credential management
- Security vulnerability scanning
- Compliance auditing
- Access control implementation
- Secret management

**Triggers:**
- Files: `domains/security/`, `*security*.ps1`, `*certificate*.ps1`, `*credential*.ps1`
- Keywords: `security`, `certificate`, `credential`, `vulnerability`
- Labels: `security`, `vulnerability`, `compliance`

**How to engage:**
```
@sarah, please review the security implications of these changes
/security
```

---

### 👩‍💻 Jessica - Testing & QA Engineer
**File:** [`.github/agents/jessica-testing.md`](.github/agents/jessica-testing.md)

**Best for:**
- Pester test development
- Test coverage analysis
- Quality metrics
- Test automation (0400-0499 range)
- CI/CD test integration

**Triggers:**
- Files: `tests/`, `*.Tests.ps1`, `automation-scripts/04*.ps1`
- Keywords: `test`, `pester`, `quality`, `coverage`
- Labels: `testing`, `qa`, `quality`

**How to engage:**
```
@jessica, please help improve test coverage for this feature
/testing
```

---

### 👩‍💻 Emma - Frontend & UX Developer
**File:** [`.github/agents/emma-frontend.md`](.github/agents/emma-frontend.md)

**Best for:**
- Console UI/UX components
- Interactive menu systems
- Terminal interface design
- User experience improvements
- Accessibility features

**Triggers:**
- Files: `domains/experience/`, `*ui*.ps1`, `*menu*.ps1`, `*wizard*.ps1`
- Keywords: `ui`, `ux`, `menu`, `interface`, `user experience`
- Labels: `ui`, `ux`, `user-experience`

**How to engage:**
```
@emma, please review the user interface changes
/ui
```

---

### 👨‍💻 Marcus - Backend & API Developer
**File:** [`.github/agents/marcus-backend.md`](.github/agents/marcus-backend.md)

**Best for:**
- PowerShell module architecture
- Function design and optimization
- API development
- Performance improvements
- Dev tools setup (0200-0299 range)

**Triggers:**
- Files: `domains/*.psm1`, `*api*.ps1`, `automation-scripts/02*.ps1`
- Keywords: `api`, `module`, `backend`, `performance`, `optimization`
- Labels: `backend`, `api`, `performance`

**How to engage:**
```
@marcus, please help optimize this module's performance
/backend
```

---

### 👩‍💻 Olivia - Documentation & Technical Writing
**File:** [`.github/agents/olivia-documentation.md`](.github/agents/olivia-documentation.md)

**Best for:**
- Technical documentation
- README files and guides
- API documentation
- Code comments review
- Reporting scripts (0500-0599 range)

**Triggers:**
- Files: `*.md`, `docs/`, `README.md`, `automation-scripts/05*.ps1`
- Keywords: `documentation`, `readme`, `guide`, `docs`, `tutorial`
- Labels: `documentation`, `docs`

**How to engage:**
```
@olivia, please review and improve this documentation
/docs
```

---

### 👩‍💻 Rachel - PowerShell & Automation Expert
**File:** [`.github/agents/rachel-powershell.md`](.github/agents/rachel-powershell.md)

**Best for:**
- Advanced PowerShell scripting
- Automation workflows
- Orchestration sequences
- Cross-platform PowerShell 7+
- Environment prep (0000-0099), Git automation (0700-0799), Maintenance (9000-9999)

**Triggers:**
- Files: `*.ps1`, `*.psm1`, `orchestration/`, `automation-scripts/00*.ps1`, `07*.ps1`, `90*.ps1`
- Keywords: `powershell`, `automation`, `orchestration`, `script`, `workflow`
- Labels: `automation`, `powershell`, `scripting`

**How to engage:**
```
@rachel, please optimize this PowerShell script
/powershell
```

---

### 👨‍💻 David - Project Manager & Coordinator
**File:** [`.github/agents/david-project-manager.md`](.github/agents/david-project-manager.md)

**Best for:**
- Sprint planning and coordination
- Release management
- Risk assessment
- Workflow orchestration
- Team facilitation

**Triggers:**
- Files: `.github/workflows/*.yml`, `*roadmap.md`, `*planning.md`
- Keywords: `project`, `planning`, `roadmap`, `sprint`, `release`
- Labels: `project-management`, `planning`, `release`

**How to engage:**
```
@david, please help coordinate this release
/pm
```

---

## 🚀 How It Works

### Automatic Suggestions

When you open or update a PR, the agent routing workflow automatically:

1. **Analyzes your changes**: Examines changed files and patterns
2. **Scans PR content**: Reads title, description, and keywords
3. **Calculates relevance**: Scores each agent based on expertise match
4. **Suggests top agents**: Posts a comment with 1-3 most relevant agents
5. **Provides guidance**: Includes commands to engage each agent

### Manual Invocation

You can manually request any agent at any time:

**Using mentions:**
```
@maya, can you review the VM configuration?
@sarah and @maya, please check the security of this infrastructure setup
```

**Using commands:**
```
/infrastructure - Engages Maya
/security - Engages Sarah
/testing - Engages Jessica
/ui - Engages Emma
/backend - Engages Marcus
/docs - Engages Olivia
/powershell - Engages Rachel
/pm - Engages David
```

## 🤝 Collaboration Patterns

For complex tasks, multiple agents often work together:

### Infrastructure Setup
```
Workflow: Maya → Sarah → Jessica → Olivia
Example: Deploy new VM → Security review → Validation tests → Documentation
```

### Feature Development
```
Workflow: David → Marcus/Rachel → Jessica → Olivia
Example: Plan feature → Implement code → Test thoroughly → Document usage
```

### UI Development
```
Workflow: Emma → Marcus → Jessica → Olivia
Example: Design interface → Backend logic → Test UX → Document features
```

### Security Enhancement
```
Workflow: Sarah → Maya → Marcus → Jessica
Example: Identify vulnerability → Fix infrastructure → Update code → Validate fix
```

## 📋 Example Workflow

### Opening a PR

1. **Create PR** with infrastructure changes
2. **Automation runs** and analyzes your changes
3. **Bot comments** with agent suggestions:
   ```
   🤖 Recommended GitHub Copilot Agents
   
   🏗️ Maya - Infrastructure & DevOps
   Relevance Score: 12
   To engage: @maya or /infrastructure
   
   🔒 Sarah - Security & Compliance
   Relevance Score: 8
   To engage: @sarah or /security
   ```
4. **You respond** with specific requests:
   ```
   @maya, please review the Hyper-V configuration
   @sarah, can you check if we're following security best practices?
   ```
5. **Agents assist** with their specialized knowledge

### During Review

Comment on specific lines or sections:
```
@rachel, is there a more efficient way to handle this PowerShell loop?
```

Request multiple agents for complex issues:
```
@emma and @marcus, how can we improve both the UI and backend performance here?
```

## 📊 Agent Routing Configuration

The routing logic is defined in [`.github/copilot.yaml`](.github/copilot.yaml) and includes:

- **File patterns**: Regular expressions matching file paths
- **Keywords**: Terms that indicate agent expertise
- **Labels**: GitHub labels that map to agents
- **Collaboration patterns**: Pre-defined multi-agent workflows
- **Command aliases**: Alternative ways to invoke agents

### Customization

You can customize agent routing by editing `.github/copilot.yaml`:

```yaml
agents:
  maya:
    file_patterns:
      - "infrastructure/**/*"
      - "**/*vm*.ps1"
    keywords:
      - "hyper-v"
      - "infrastructure"
    labels:
      - infrastructure
```

## 💡 Best Practices

### For Maximum Effectiveness

1. **Be specific**: "Review security" vs "Check certificate expiration handling in line 42"
2. **Provide context**: Share background information with your request
3. **Use right agent**: Match the agent's expertise to your question
4. **Collaborate**: Don't hesitate to engage multiple agents
5. **Review profiles**: Check agent files to understand their strengths

### Writing Good Agent Requests

**Good Examples:**
```
@maya, this PR adds Hyper-V support for nested virtualization. 
Please review the VM configuration in hyperv-manager.ps1 for best practices.

@jessica, I've added new test cases for the orchestration engine. 
Can you review coverage and suggest edge cases I might have missed?

@rachel and @marcus, I'm refactoring the module loader. 
Rachel: PowerShell best practices? 
Marcus: Module architecture concerns?
```

**Less Effective:**
```
@maya, review this
@jessica, tests?
```

## 🔧 Troubleshooting

### Agent Not Responding

Agents are automatically configured but require:
- ✅ Valid agent file in `.github/agents/`
- ✅ Configuration in `.github/copilot.yaml`
- ✅ Proper mention format (`@agent-name`)

### Wrong Agent Suggested

The routing system learns from:
- File patterns in your changes
- Keywords in PR title/description
- Applied labels

To improve suggestions:
- Add relevant labels to your PR
- Include keywords in PR description
- Manually invoke the correct agent

### Multiple Agents Needed

Use collaboration patterns:
```
@david, can you coordinate a review team for this complex feature?
```

Or invoke multiple agents:
```
@maya @sarah, please review together - infrastructure with security focus
```

## 📚 Additional Resources

- **Agent Profiles**: See [`.github/agents/README.md`](.github/agents/README.md)
- **Quick Reference**: Check [`.github/agents/QUICK-REFERENCE.md`](.github/agents/QUICK-REFERENCE.md)
- **Team Summary**: View [`.github/agents/TEAM-SUMMARY.txt`](.github/agents/TEAM-SUMMARY.txt)
- **Copilot Docs**: Read [`.github/copilot-instructions.md`](.github/copilot-instructions.md)

## 🎓 Learning More

### Understanding Agent Expertise

Each agent has:
- **12+ years combined experience** in their domain
- **Specific certifications** and education
- **Defined communication style** and approach
- **Primary and secondary** focus areas

### AitherZero Number System Integration

Agents map to script ranges:
- **0000-0099**: Rachel, Maya (Environment)
- **0100-0199**: Maya, Sarah (Infrastructure)
- **0200-0299**: Marcus, Rachel (Dev Tools)
- **0400-0499**: Jessica, Marcus (Testing)
- **0500-0599**: Olivia, David (Reporting)
- **0700-0799**: Rachel, David (Git & AI)
- **9000-9999**: Maya, Rachel (Maintenance)

## 🚦 Getting Started

1. **Open a PR** or comment on existing one
2. **Wait for suggestions** from the agent router
3. **Review agent profiles** in `.github/agents/`
4. **Engage agents** using `@mention` or `/command`
5. **Collaborate** with multiple agents as needed

---

**Questions?** Open an issue or ask in PR comments!

**Need help?** Use `@david` for coordination or check agent profiles for specific expertise.

*Last updated: October 2025*
