# Automated Agent Review - Visual Flow

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Developer Workflow                          │
└─────────────────────────────────────────────────────────────────┘

   1. Developer commits code
            │
            ▼
   2. Push to PR branch
            │
            ▼
┌───────────────────────────────────────────────────────────────────┐
│              🤖 Automated Agent Review System                     │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Phase 1: Detection                                      │   │
│  │  • Workflow triggered on push                            │   │
│  │  • Check if branch has open PR                           │   │
│  │  • Get PR number and context                             │   │
│  └─────────────────────────────────────────────────────────┘   │
│              │                                                   │
│              ▼                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Phase 2: Analysis                                       │   │
│  │  • Get changed files (git diff)                          │   │
│  │  • Analyze file patterns                                 │   │
│  │  • Calculate agent relevance scores                      │   │
│  │  • Select top 3 agents                                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│              │                                                   │
│              ▼                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Phase 3: Parallel Review (Matrix Strategy)             │   │
│  │                                                           │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │   │
│  │  │  Agent 1    │  │  Agent 2    │  │  Agent 3    │     │   │
│  │  │  Reviews    │  │  Reviews    │  │  Reviews    │     │   │
│  │  │  Files      │  │  Files      │  │  Files      │     │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │   │
│  │       │                 │                 │              │   │
│  │       └─────────────────┼─────────────────┘              │   │
│  │                         ▼                                 │   │
│  │              Posts Individual Comments                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│              │                                                   │
│              ▼                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Phase 4: Summary                                        │   │
│  │  • Aggregate all reviews                                 │   │
│  │  • Post summary comment                                  │   │
│  │  • Link to individual agent comments                     │   │
│  └─────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────┘
            │
            ▼
   3. Developer sees feedback in PR
            │
            ▼
   4. Developer addresses issues
            │
            ▼
   5. Developer commits again → LOOP BACK TO STEP 1
```

## Agent Selection Example

```
Changed Files:
  - automation-scripts/0150_Setup-VM.ps1
  - aithercore/security/Certificate-Management.psm1
  - tests/unit/Security.Tests.ps1
  - README.md

                    ▼

Agent Scoring:
  🏗️  Maya (Infrastructure)    → Score: 3  (0150_Setup-VM.ps1)
  🔒  Sarah (Security)         → Score: 6  (Certificate-Management.psm1 + Security.Tests.ps1)
  🧪  Jessica (Testing)        → Score: 3  (Security.Tests.ps1)
  📚  Olivia (Documentation)   → Score: 3  (README.md)
  ⚡  Rachel (PowerShell)      → Score: 6  (all .ps1 files)

                    ▼

Top 3 Selected:
  1. 🔒  Sarah (Security)      → Score: 6
  2. ⚡  Rachel (PowerShell)   → Score: 6
  3. 🏗️  Maya (Infrastructure) → Score: 3

                    ▼

Parallel Reviews Execute
```

## Agent Review Process

```
For each selected agent:

┌────────────────────────────────────────────┐
│  Load Agent Profile                        │
│  • Name, Role, Icon                        │
│  • Expertise Focus Area                    │
└────────────────────────────────────────────┘
                    │
                    ▼
┌────────────────────────────────────────────┐
│  Filter Relevant Files                     │
│  • Match file patterns                     │
│  • Only review expertise area              │
└────────────────────────────────────────────┘
                    │
                    ▼
┌────────────────────────────────────────────┐
│  Run Analysis Tools                        │
│  • PSScriptAnalyzer (PowerShell)          │
│  • Link validation (Markdown)             │
│  • Content analysis (All files)           │
└────────────────────────────────────────────┘
                    │
                    ▼
┌────────────────────────────────────────────┐
│  Apply Agent-Specific Rules                │
│  • Custom checks per agent                 │
│  • Domain expertise validation             │
└────────────────────────────────────────────┘
                    │
                    ▼
┌────────────────────────────────────────────┐
│  Classify Issues by Severity               │
│  • 🚨 Critical (Errors)                    │
│  • ⚠️  Warnings                            │
│  • 💡 Suggestions (Info)                   │
└────────────────────────────────────────────┘
                    │
                    ▼
┌────────────────────────────────────────────┐
│  Post Review Comment                       │
│  • Issue breakdown by severity             │
│  • Line numbers and file paths             │
│  • Next steps and guidance                 │
└────────────────────────────────────────────┘
```

## Issue Classification Flow

```
PSScriptAnalyzer Result:
  Severity: Error
  Message: "Variable is not defined"
  Line: 42
  Rule: PSUseDeclaredVarsMoreThanAssignments

            ▼

Agent Processing:
  🚨 CRITICAL ISSUE
  - Must fix before merge
  - Blocks functionality

            ▼

Comment Format:
  ### 🚨 Critical Issues (1)
  - **`file.ps1`** (Line 42)
    - Variable is not defined
    - Rule: `PSUseDeclaredVarsMoreThanAssignments`
```

## Continuous Feedback Loop

```
Commit 1:
  ↓
Agent Review → 10 issues found
  ↓
Developer fixes 8 issues
  ↓
Commit 2:
  ↓
Agent Review → 2 issues found
  ↓
Developer fixes 2 issues
  ↓
Commit 3:
  ↓
Agent Review → ✅ No issues!
  ↓
Ready to merge
```

## Integration with Existing Workflows

```
PR Opened
  │
  ├─→ copilot-agent-router.yml
  │   • Suggests agents
  │   • Posts recommendation comment
  │   • Manual invocation setup
  │
  └─→ pr-validation.yml
      • Syntax validation
      • Fork PR handling

      ▼

Every Commit
  │
  ├─→ automated-agent-review.yml  ← NEW!
  │   • Proactive code review
  │   • Agent-specific feedback
  │   • Continuous improvement
  │
  ├─→ quality-validation.yml
  │   • PSScriptAnalyzer
  │   • Quality checks
  │
  └─→ Other CI/CD workflows
      • Tests, builds, etc.

      ▼

All Checks Pass → Ready to Merge
```

## Benefits Visualization

```
Traditional Manual Review:
  Commit → Wait → Manual Review → Feedback → Fix → Wait → Review...
  ⏱️  Days/Hours per cycle

                    VS

Automated Agent Review:
  Commit → Instant Review → Feedback → Fix → Instant Review...
  ⏱️  2-3 minutes per cycle

Speed Improvement: 10-100x faster feedback loop
Quality Improvement: Consistent, expert-level reviews
```

## Agent Specialization Matrix

```
File Type/Area           | Primary Agent(s)           | Secondary Agent(s)
-------------------------|----------------------------|-------------------
Infrastructure (.tf)     | 🏗️  Maya                  | 🔒 Sarah
Security code            | 🔒  Sarah                 | ⚡ Rachel
Tests (.Tests.ps1)       | 🧪  Jessica               | ⚡ Rachel
Documentation (.md)      | 📚  Olivia                | -
UI/Console               | 🎨  Emma                  | ⚙️  Marcus
PowerShell modules       | ⚙️  Marcus                | ⚡ Rachel
Automation scripts       | ⚡  Rachel                | (varies)
Workflows (.yml)         | 📋  David                 | ⚡ Rachel
```

## Success Metrics

```
Before Automated Reviews:
  ├─ Review wait time: Hours/Days
  ├─ Issues found in PR: Late stage
  ├─ Feedback consistency: Variable
  └─ Developer learning: Slow

After Automated Reviews:
  ├─ Review wait time: 2-3 minutes ✅
  ├─ Issues found in PR: Immediate ✅
  ├─ Feedback consistency: 100% ✅
  └─ Developer learning: Fast ✅
```

---

*This visual guide illustrates the automated agent review system architecture, flow, and benefits.*
