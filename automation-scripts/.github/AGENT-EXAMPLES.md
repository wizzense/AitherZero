# GitHub Copilot Agent Routing - Examples

This document provides real-world examples of how the automatic agent routing system works in practice.

## Example 1: Infrastructure PR

### Scenario
You're adding new Hyper-V VM management functionality.

### PR Content
```
Title: Add nested virtualization support for lab VMs
Files Changed:
- infrastructure/vm/New-LabVM.ps1
- automation-scripts/0105_Create-LabVM.ps1
- domains/infrastructure/VMManagement.psm1
```

### Automatic Suggestion
The system analyzes and posts:

```markdown
🤖 Recommended GitHub Copilot Agents

Based on the changes in this PR (3 files), here are the recommended agents:

🏗️ Maya - Infrastructure & DevOps
File: .github/agents/maya-infrastructure.md
Relevance Score: 11
To engage: @maya or /infrastructure

🔒 Sarah - Security & Compliance
File: .github/agents/sarah-security.md
Relevance Score: 5
To engage: @sarah or /security

📊 Change Analysis
| Category | Files Changed |
|----------|---------------|
| Infrastructure | 3 |
| PowerShell | 3 |
```

### You Can Then Comment
```
@maya, please review the VM configuration for best practices
@sarah, can you check if the VM security settings are appropriate?
```

---

## Example 2: Security Enhancement PR

### Scenario
You're implementing certificate rotation automation.

### PR Content
```
Title: Implement automatic certificate rotation
Files Changed:
- domains/security/CertificateManagement.psm1
- automation-scripts/0150_Rotate-Certificates.ps1
- tests/security/CertificateRotation.Tests.ps1
```

### Automatic Suggestion
```markdown
🤖 Recommended GitHub Copilot Agents

🔒 Sarah - Security & Compliance
Relevance Score: 12
To engage: @sarah or /security

🧪 Jessica - Testing & QA
Relevance Score: 6
To engage: @jessica or /testing

🏗️ Maya - Infrastructure & DevOps
Relevance Score: 4
To engage: @maya or /infrastructure
```

### Collaboration Request
```
@sarah and @maya, please review together:
- Sarah: Security best practices for cert rotation
- Maya: Infrastructure impact and automation approach
```

---

## Example 3: Testing Improvement PR

### Scenario
Adding comprehensive test coverage for orchestration engine.

### PR Content
```
Title: Increase orchestration test coverage to 90%
Files Changed:
- tests/automation/Orchestration.Tests.ps1
- tests/automation/Sequence.Tests.ps1
- tests/automation/PlaybookExecution.Tests.ps1
- automation-scripts/0402_Run-Tests.ps1
```

### Automatic Suggestion
```markdown
🤖 Recommended GitHub Copilot Agents

🧪 Jessica - Testing & QA
Relevance Score: 15
To engage: @jessica or /testing

⚙️ Marcus - Backend & API
Relevance Score: 4
To engage: @marcus or /backend
```

### Engagement
```
@jessica, I've added extensive test coverage for the orchestration engine.
Can you review for:
1. Edge cases I might have missed
2. Mock usage best practices
3. Any opportunities to improve assertions
```

---

## Example 4: UI/UX Redesign PR

### Scenario
Modernizing the console menu system.

### PR Content
```
Title: Redesign interactive menu system with improved UX
Files Changed:
- domains/experience/Menu.psm1
- domains/experience/UserInterface.psm1
- domains/experience/Wizard.psm1
- tests/experience/Menu.Tests.ps1
```

### Automatic Suggestion
```markdown
🤖 Recommended GitHub Copilot Agents

🎨 Emma - Frontend & UX
Relevance Score: 12
To engage: @emma or /ui

⚙️ Marcus - Backend & API
Relevance Score: 5
To engage: @marcus or /backend

🧪 Jessica - Testing & QA
Relevance Score: 3
To engage: @jessica or /testing
```

### Multi-Agent Request
```
@emma, please review the UX improvements and accessibility features
@marcus, can you check if the menu backend integration is optimal?
@jessica, do the tests cover all user interaction scenarios?
```

---

## Example 5: Documentation Update PR

### Scenario
Creating comprehensive deployment guide.

### PR Content
```
Title: Add deployment and configuration guide
Files Changed:
- docs/deployment/README.md
- docs/deployment/quickstart.md
- docs/deployment/troubleshooting.md
- docs/configuration/advanced.md
```

### Automatic Suggestion
```markdown
🤖 Recommended GitHub Copilot Agents

📚 Olivia - Documentation & Technical Writing
Relevance Score: 15
To engage: @olivia or /docs

🏗️ Maya - Infrastructure & DevOps
Relevance Score: 3
To engage: @maya or /infrastructure
```

### Request
```
@olivia, please review this deployment guide for:
- Clarity and completeness
- Technical accuracy
- Proper formatting and structure
- Any missing prerequisites or steps
```

---

## Example 6: PowerShell Automation PR

### Scenario
Creating new orchestration playbook system.

### PR Content
```
Title: Implement dynamic playbook execution engine
Files Changed:
- orchestration/PlaybookEngine.ps1
- orchestration/SequenceRunner.ps1
- automation-scripts/0705_Execute-Playbook.ps1
- automation-scripts/0706_Validate-Playbook.ps1
```

### Automatic Suggestion
```markdown
🤖 Recommended GitHub Copilot Agents

⚡ Rachel - PowerShell & Automation
Relevance Score: 14
To engage: @rachel or /powershell

⚙️ Marcus - Backend & API
Relevance Score: 6
To engage: @marcus or /backend
```

### Expert Consultation
```
@rachel, I'm implementing a new playbook engine. Can you review for:
- PowerShell best practices and patterns
- Cross-platform compatibility (PS 7+)
- Performance optimization opportunities
- Error handling robustness
```

---

## Example 7: Release Preparation PR

### Scenario
Preparing for major version release.

### PR Content
```
Title: Prepare v2.0.0 release
Files Changed:
- VERSION
- AitherZero.psd1
- CHANGELOG.md
- .github/workflows/release-automation.yml
- docs/release-notes-v2.0.0.md
```

### Automatic Suggestion
```markdown
🤖 Recommended GitHub Copilot Agents

📋 David - Project Management & Coordinator
Relevance Score: 10
To engage: @david or /pm

📚 Olivia - Documentation
Relevance Score: 8
To engage: @olivia or /docs
```

### Coordination Request
```
@david, can you coordinate the release preparation and ensure all teams are ready?
@olivia, please verify release notes and documentation are complete
```

---

## Example 8: Mixed-Domain PR (Complex Feature)

### Scenario
Adding new feature that touches multiple areas.

### PR Content
```
Title: Implement automated lab deployment with security hardening
Files Changed:
- infrastructure/LabDeployment.ps1
- domains/security/Hardening.psm1
- domains/infrastructure/VMProvisioning.psm1
- tests/integration/LabDeployment.Tests.ps1
- docs/guides/lab-deployment.md
- automation-scripts/0180_Deploy-Lab.ps1
```

### Automatic Suggestion
```markdown
🤖 Recommended GitHub Copilot Agents

🏗️ Maya - Infrastructure & DevOps
Relevance Score: 15
To engage: @maya or /infrastructure

🔒 Sarah - Security & Compliance
Relevance Score: 9
To engage: @sarah or /security

🧪 Jessica - Testing & QA
Relevance Score: 6
To engage: @jessica or /testing
```

### Collaboration Workflow
```
@david, please coordinate review for this complex feature:
1. @maya - Infrastructure architecture and deployment strategy
2. @sarah - Security hardening implementation
3. @jessica - Integration test coverage
4. @olivia - Documentation completeness

This follows our "Infrastructure Setup" collaboration pattern.
```

---

## Command Examples

### Quick Agent Invocation
```
/infrastructure    # Engages Maya
/security         # Engages Sarah
/testing          # Engages Jessica
/ui               # Engages Emma
/backend          # Engages Marcus
/docs             # Engages Olivia
/powershell       # Engages Rachel
/pm               # Engages David
```

### Direct Mentions
```
@maya review this
@sarah @maya review together
@jessica, @olivia, @marcus - full review please
```

### Specific Requests
```
@maya, line 45-60: Is this the correct approach for nested virtualization?
@sarah, can you audit the certificate handling in CertManager.psm1?
@rachel, is there a more idiomatic PowerShell way to do this loop?
@emma, how can we improve the accessibility of this menu?
```

---

## Tips from the Examples

1. **Be Specific**: Reference exact files, line numbers, or functions
2. **Provide Context**: Explain what you're trying to achieve
3. **Use Collaboration**: Complex PRs benefit from multiple agents
4. **Follow Patterns**: Use the suggested collaboration workflows
5. **Check Profiles**: Review agent expertise before requesting help

---

**Ready to try it yourself?** Open a PR and watch the agent router in action!

*For more details, see [AGENT-ROUTING-GUIDE.md](AGENT-ROUTING-GUIDE.md)*
