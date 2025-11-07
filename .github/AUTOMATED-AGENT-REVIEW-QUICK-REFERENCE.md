# 🤖 Automated Agent Review - Quick Reference Card

## ⚡ What Is It?

**Instant, expert code review on every commit** - Specialized AI agents automatically analyze your changes and post actionable feedback in PR comments within 2-3 minutes.

## 🚀 Quick Start (3 Steps)

1. **Commit** → Push code to your PR branch
2. **Wait** → Agents review in 2-3 minutes
3. **Fix** → Address feedback and commit again

**That's it!** No setup required. Works automatically on all PRs.

## 👥 Meet Your Review Team (8 Agents)

| Agent | Icon | When They Review | What They Check |
|-------|------|------------------|-----------------|
| **Maya Infrastructure** | 🏗️ | Infrastructure files, VMs, networking | IaC best practices, VM configs |
| **Sarah Security** | 🔒 | Security code, certificates, credentials | Secure handling, no secrets in code |
| **Jessica Testing** | 🧪 | Test files, test coverage | Test structure, coverage gaps |
| **Emma Frontend** | 🎨 | UI/UX components, menus | Consistency, accessibility |
| **Marcus Backend** | ⚙️ | PowerShell modules, APIs | Module structure, performance |
| **Olivia Documentation** | 📚 | Markdown, docs, comments | Completeness, broken links |
| **Rachel PowerShell** | ⚡ | All PowerShell code | Best practices, cross-platform |
| **David ProjectManager** | 📋 | Workflows, planning docs | Configuration correctness |

## 📊 Issue Severity Levels

| Level | Symbol | Meaning | Action Required |
|-------|--------|---------|-----------------|
| **Critical** | 🚨 | Errors that break functionality | **Must fix before merge** |
| **Warning** | ⚠️ | Potential problems | **Should fix** |
| **Suggestion** | 💡 | Improvements and best practices | **Consider implementing** |

## 🔍 Common Checks by Agent

### ⚡ Rachel PowerShell
```
✅ Use Write-CustomLog (not Write-Host)
✅ Add #Requires -Version 7.0
✅ Use approved PowerShell verbs
✅ Cross-platform compatible ($IsWindows, etc.)
```

### 🔒 Sarah Security
```
✅ No plaintext passwords in code
✅ Secure credential handling
✅ No secrets in environment variables
✅ Proper certificate management
```

### 🧪 Jessica Testing
```
✅ Tests exist for automation scripts
✅ Proper Pester structure
✅ Adequate test coverage
✅ Use of mocking and assertions
```

### 📚 Olivia Documentation
```
✅ Comment-based help (.SYNOPSIS, .DESCRIPTION)
✅ No broken links in markdown
✅ Parameter documentation
✅ Usage examples included
```

## 💬 Example Review Comment

```markdown
## 🔒 Automated Review: Sarah Security

**Commit:** abc1234 • **Files Reviewed:** 3 • **Issues Found:** 2

**Focus Area:** Security, certificates, credentials, vulnerabilities

---

### ⚠️ Warnings (1)
- **`domains/security/Certs.psm1`** (Line 85)
  - Avoid using -AsPlainText with ConvertTo-SecureString
  - Rule: `CustomRule-AvoidPlainTextSecureString`

### 💡 Suggestions (1)
- **`domains/security/Creds.psm1`**
  - Add certificate validation before operations
  - Rule: `CustomRule-ValidateCertificates`

---

### 📋 Next Steps
1. Review the issues identified above
2. Address critical issues and warnings
3. Consider suggestions for improvements
4. Re-commit - review runs automatically

**Need help?** Tag me with `@sarah` for guidance.
```

## 🎯 How Agent Selection Works

```
Your Changes → Agent Scoring → Top 3 Selected

Example:
  Changed: automation-scripts/0150_Setup-VM.ps1
           domains/security/Certificates.psm1
           tests/unit/Security.Tests.ps1

  Scores:  Maya 🏗️ = 3 (VM script)
           Sarah 🔒 = 6 (security + tests)
           Jessica 🧪 = 3 (tests)
           Rachel ⚡ = 6 (all .ps1 files)

  Selected: Sarah 🔒, Rachel ⚡, Maya 🏗️
```

## 📝 Tips for Best Results

### ✅ DO:
- Commit small, focused changes
- Read all feedback (not just critical)
- Ask agents questions with `@agent-name`
- Address issues incrementally
- Run local checks before committing

### ❌ DON'T:
- Ignore critical issues
- Commit large, unfocused changes
- Skip documentation/tests
- Disable or bypass reviews

## 🔄 Continuous Feedback Loop

```
Commit 1 → Review → 10 issues found
          ↓
          Fix 8 issues
          ↓
Commit 2 → Review → 2 issues found
          ↓
          Fix 2 issues
          ↓
Commit 3 → Review → ✅ No issues!
          ↓
          Ready to merge
```

## 🆘 Troubleshooting

| Problem | Solution |
|---------|----------|
| No agents review | Changed files don't match patterns - check file types |
| Too many issues | Run local PSScriptAnalyzer first: `./automation-scripts/0404_Run-PSScriptAnalyzer.ps1` |
| False positive | Document why in code comment, report to maintainers |
| Review doesn't trigger | Ensure PR is open and not draft |
| Need specific agent | Tag them: `@agent-name, please help with...` |

## 🔗 Related Commands

```powershell
# Run local analysis before committing
./automation-scripts/0404_Run-PSScriptAnalyzer.ps1

# Validate syntax
./automation-scripts/0407_Validate-Syntax.ps1 -All

# Run tests
./automation-scripts/0402_Run-UnitTests.ps1

# Generate missing tests
./automation-scripts/0950_Generate-AllTests.ps1 -Mode Quick

# Quality validation
./automation-scripts/0420_Validate-ComponentQuality.ps1 -Path ./path/to/file
```

## 📚 Full Documentation

- **Main Guide**: `.github/AUTOMATED-AGENT-REVIEW-GUIDE.md`
- **Visual Guide**: `.github/AUTOMATED-AGENT-REVIEW-VISUAL-GUIDE.md`
- **Agent Profiles**: `.github/agents/README.md`
- **Copilot Instructions**: `.github/copilot-instructions.md`

## 🎯 Success Metrics

```
Before: Manual review wait → Hours/Days
After:  Automated review → 2-3 minutes ✅

Before: Late issue discovery → PR review stage
After:  Instant discovery → First commit ✅

Before: Inconsistent feedback → Depends on reviewer
After:  Consistent feedback → Expert agents ✅

Before: Slow learning → Delayed feedback
After:  Fast learning → Immediate guidance ✅
```

## 💡 Pro Tips

1. **Commit Early, Commit Often** - Get fast feedback on small changes
2. **Read All Agents** - Each brings unique expertise
3. **Learn from Patterns** - Notice recurring suggestions
4. **Ask Questions** - Tag agents for clarification
5. **Run Local First** - Catch issues before pushing

## 🌟 Benefits Summary

| Benefit | Value |
|---------|-------|
| ⚡ Speed | 10-100x faster than manual review |
| 🎯 Quality | Expert-level, consistent feedback |
| 🔄 Continuous | Every commit gets reviewed |
| 📊 Actionable | Specific issues with line numbers |
| 🤝 Collaborative | Multiple perspectives |
| 📈 Learning | Improve skills through feedback |

---

## 🚀 Get Started Now

**Just commit your code!** The system works automatically. No configuration needed.

Questions? Tag an agent in your PR: `@agent-name, please help with...`

---

*💻 Part of the AitherZero Infrastructure Automation Platform*
