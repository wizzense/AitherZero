# AitherZero Architecture: Single-Purpose Scripts with Parameters

**Context:** You're working with AitherZero's number-based automation system (0000-9999).

## ⚠️ CRITICAL RULE: Use Parameters, Not Duplicate Scripts

### The Problem
Scripts 0000-9999 are designed for sequential execution. Creating variants breaks this model:

```
❌ BAD - Multiple scripts for behavior variations:
0404_Run-PSScriptAnalyzer.ps1
0404_Run-PSScriptAnalyzer-Parallel.ps1     # Causes confusion
0404_Run-PSScriptAnalyzer-Fast.ps1         # Which one runs?
0410_Run-PSScriptAnalyzer-Fast.ps1         # Just another version of same thing!
0404_Run-PSScriptAnalyzer-Clean.ps1        # Violates numbering system
```

When someone runs `aitherzero 0404`, which script executes? The system breaks.

### The Solution

**PRIMARY APPROACH: Use Parameters to Modify Behavior**
```powershell
✅ CORRECT - ONE script with parameters:
0404_Run-PSScriptAnalyzer.ps1

# Script accepts parameters:
param(
    [switch]$Fast,              # Fast mode for CI
    [switch]$Comprehensive,     # Full scan
    [switch]$UseCache,          # Use cached results
    [switch]$Parallel,          # Use parallel processing
    [string[]]$Severity         # Control severity levels
)

# Usage examples:
./0404_Run-PSScriptAnalyzer.ps1                    # Default behavior
./0404_Run-PSScriptAnalyzer.ps1 -Fast              # Fast mode
./0404_Run-PSScriptAnalyzer.ps1 -Fast -UseCache    # Fast with cache
./0404_Run-PSScriptAnalyzer.ps1 -Severity Error    # Errors only
./0404_Run-PSScriptAnalyzer.ps1 -Parallel          # Use parallelization
```

**ONLY use different numbers for TRULY DIFFERENT FUNCTIONALITY:**
```
✅ CORRECT - Different purposes = different numbers:
0404_Run-PSScriptAnalyzer.ps1          # Analysis (all modes via parameters)
0415_Manage-PSScriptAnalyzerCache.ps1  # Cache management (different function)
0416_Generate-AnalysisReport.ps1       # Report generation (different function)
```

Each script has ONE clear purpose. No confusion about what each does.

**For Complex Workflows - Use Orchestration:**
```
✅ CORRECT - Playbook for workflows:
orchestration/playbooks/code-quality-full.psd1

Sequence:
  1. Run 0404 with parameters
  2. Run 0407 (Syntax validation)
  3. Run 0512 (Generate dashboard)
```

Complex workflows belong in playbooks, not duplicate scripts.

## Design Principles

### 1. Parameters Over Duplicates
Modify behavior with parameters, NOT separate scripts:
- ✅ `0404_Run-PSScriptAnalyzer.ps1 -Fast`
- ❌ `0410_Run-PSScriptAnalyzer-Fast.ps1`

### 2. One Script Per Function
Each numbered script does ONE function (with parameter variations):
- 0404: Analysis (comprehensive, fast, cached - all via parameters)
- 0415: Cache management (info, clear, prune - via -Action parameter)

### 3. Never Create Behavior Variants
Never create:
- Script-Parallel (use `-Parallel` parameter)
- Script-Fast (use `-Fast` parameter)
- Script-Clean (use `-Clean` parameter)
- Script-Alternative (use parameters)

### 4. Orchestration For Workflows
If you need to:
- Run multiple scripts in sequence
- Coordinate complex workflows
- Handle dependencies

Create a playbook, don't duplicate scripts.

## When Adding Functionality

### ❌ Wrong Approach
```powershell
# User asks: "Make PSScriptAnalyzer faster"
# Bad response: Create 0410_Run-PSScriptAnalyzer-Fast.ps1

# User asks: "Add parallel processing"
# Bad response: Create 0404_Run-PSScriptAnalyzer-Parallel.ps1
```

### ✅ Correct Approach
```powershell
# User asks: "Make PSScriptAnalyzer faster"
# Correct response: Add -Fast parameter to 0404_Run-PSScriptAnalyzer.ps1

param(
    [switch]$Fast,
    [switch]$UseCache
)

if ($Fast) {
    # Fast mode logic
} else {
    # Comprehensive mode logic
}

# User asks: "Add parallel processing"
# Correct response: Add -Parallel parameter to 0404_Run-PSScriptAnalyzer.ps1

param([switch]$Parallel)

if ($Parallel) {
    # Use parallel processing
}
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
