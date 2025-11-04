# AitherZero Architecture: Single-Purpose Scripts & Orchestration

**Context:** You're working with AitherZero's number-based automation system (0000-9999).

## ⚠️ CRITICAL RULE: No Duplicate Scripts

### The Problem
Scripts 0000-9999 are designed for sequential execution. Creating variants breaks this model:

```
❌ BAD:
0404_Run-PSScriptAnalyzer.ps1
0404_Run-PSScriptAnalyzer-Parallel.ps1     # Causes confusion
0404_Run-PSScriptAnalyzer-Fast.ps1         # Which one runs?
0404_Run-PSScriptAnalyzer-Clean.ps1        # Violates numbering system
```

When someone runs `aitherzero 0404`, which script executes? The system breaks.

### The Solution

**Option 1: Use Different Numbers for Different Purposes**
```
✅ GOOD:
0404_Run-PSScriptAnalyzer.ps1       # Comprehensive analysis
0410_Run-PSScriptAnalyzer-Fast.ps1  # Quick CI checks (different number!)
0415_Manage-PSScriptAnalyzerCache.ps1  # Cache management
```

Each script has ONE clear purpose. No confusion.

**Option 2: Use Orchestration for Complex Workflows**
```
✅ GOOD:
orchestration/playbooks/code-quality-full.psd1

Sequence:
  1. Run 0404 (PSScriptAnalyzer)
  2. Run 0407 (Syntax validation)
  3. Run 0512 (Generate dashboard)
```

Complex workflows belong in playbooks, not duplicate scripts.

## Design Principles

### 1. Single Responsibility
Each numbered script does ONE thing:
- 0404: Run PSScriptAnalyzer with caching
- 0410: Quick PSScriptAnalyzer for CI
- 0415: Manage cache

### 2. No Variants
Never create:
- Script-Parallel
- Script-Fast
- Script-Clean
- Script-Alternative

Instead:
- Add caching/performance to the original script
- Create new numbered scripts for truly different functions
- Use playbooks for orchestration

### 3. Orchestration Over Duplication
If you need to:
- Run multiple scripts in sequence
- Coordinate complex workflows
- Handle dependencies

Create a playbook, don't duplicate scripts.

## When Adding Functionality

### ❌ Wrong Approach
```powershell
# User asks: "Make PSScriptAnalyzer faster with parallelization"
# Bad response: Create 0404_Run-PSScriptAnalyzer-Parallel.ps1
```

### ✅ Correct Approach
**Option A: Enhance Existing Script**
```powershell
# Add caching to existing 0404_Run-PSScriptAnalyzer.ps1
# Keep the same script number
# Add performance optimizations inline
```

**Option B: Break Into Focused Scripts**
```powershell
# If too complex for one script:
0404_Run-PSScriptAnalyzer.ps1     # Main functionality
0415_Manage-PSScriptAnalyzerCache.ps1  # Cache management
0416_Generate-AnalysisReport.ps1  # Reporting

# Then create playbook:
orchestration/playbooks/code-quality-full.psd1
```

## Real-World Example

### What Happened (BAD)
```
Agent created:
- 0404_Run-PSScriptAnalyzer.ps1
- 0404_Run-PSScriptAnalyzer-Parallel.ps1   ❌ DUPLICATE!

Result: Confusion, which one to use? Which is canonical?
```

### What Should Happen (GOOD)
```
Agent created:
- 0404_Run-PSScriptAnalyzer.ps1 (enhanced with caching)
- 0415_Manage-PSScriptAnalyzerCache.ps1 (new functionality)
- orchestration/playbooks/code-quality-full.psd1 (workflow)

Result: Clear separation of concerns, no confusion
```

## Checklist Before Creating Scripts

- [ ] Is this truly a different purpose? → Different number (0404 vs 0410)
- [ ] Is this an enhancement? → Update existing script
- [ ] Is this a complex workflow? → Create playbook
- [ ] Am I creating a variant? → STOP! Wrong approach

## Language to Avoid

Never say:
- "I'll create a parallel version"
- "Let me make a fast variant"
- "I'll add a clean alternative"
- "Here's the optimized script alongside the original"

Instead say:
- "I'll enhance the existing script with caching"
- "I'll create script 0415 for cache management"
- "I'll create a playbook to orchestrate this workflow"

## Remember

> "One script = one job. Complex workflows = orchestration playbooks."

This is a **HARD REQUIREMENT** in AitherZero. Not a suggestion.
