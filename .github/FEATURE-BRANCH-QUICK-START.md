# Quick Start: Feature Branch PR Workflow

## 🎯 When to Use What

### Use Light Validation (Feature Branch PRs) When:
- 🔧 Fixing specific issues in a copilot branch
- 🚀 Making incremental improvements between feature branches
- ⚡ Need quick feedback and fast iteration
- 🔄 Working on experimental changes

### Use Full Validation (Main Branch PRs) When:
- ✅ Ready to merge to production/staging
- 📦 Completing a feature for release
- 🔒 Changes affect main branch code
- 📊 Need comprehensive quality assurance

---

## 📋 Common Workflows

### Workflow 1: Quick Fix to Copilot Branch

```bash
# Scenario: Copilot branch has a syntax error, need to fix quickly

# 1. Start from the copilot branch
git checkout copilot/feature-123
git pull

# 2. Create a fix branch
git checkout -b fix/syntax-error

# 3. Make your fix
# ... edit files ...

# 4. Commit and push
git add .
git commit -m "fix: resolve syntax error in module"
git push origin fix/syntax-error

# 5. Create PR via GitHub UI
# Source: fix/syntax-error
# Target: copilot/feature-123  ← This triggers LIGHT validation ⚡

# Result:
# ✅ Syntax check runs (~1 min)
# ✅ Critical issues check (~1 min)
# ⏭️ Full tests skipped
# 🚀 Can merge quickly after review
```

### Workflow 2: Feature Work to Dev (Production)

```bash
# Scenario: Feature is complete, ready for staging/production

# 1. Ensure feature branch is up to date
git checkout copilot/feature-123
git pull

# 2. Create PR via GitHub UI
# Source: copilot/feature-123
# Target: dev  ← This triggers FULL validation 🔒

# Result:
# ✅ All tests run (~10-15 min)
# ✅ Full quality checks
# ✅ Coverage analysis
# ✅ Documentation validation
# 🔒 Must pass all gates to merge
```

### Workflow 3: Incremental Feature Development

```bash
# Scenario: Large feature, breaking into sub-tasks

# 1. Create main feature branch from dev
git checkout dev
git pull
git checkout -b feature/large-feature

# 2. Create sub-task branches
git checkout -b feature/large-feature-part1

# 3. Work on part 1
# ... implement part 1 ...

# 4. PR part 1 back to main feature branch
# Source: feature/large-feature-part1
# Target: feature/large-feature  ← LIGHT validation ⚡

# 5. Repeat for other parts
git checkout feature/large-feature
git checkout -b feature/large-feature-part2
# ... implement part 2 ...
# PR: feature/large-feature-part2 → feature/large-feature  ← LIGHT validation ⚡

# 6. When all parts complete, PR to dev
# Source: feature/large-feature
# Target: dev  ← FULL validation 🔒
```

---

## 💡 Tips and Best Practices

### ✅ Do's

1. **Use feature branch PRs for incremental work**
   - Merge fixes between feature branches quickly
   - Iterate faster with light validation

2. **Always use full validation before production**
   - Final PR to dev/main gets comprehensive checks
   - Quality gates protect production code

3. **Name branches clearly**
   - `copilot/*` for Copilot-generated branches
   - `feature/*` for feature development
   - `fix/*` for bug fixes
   - `hotfix/*` for urgent production fixes

4. **Keep feature branch PRs small**
   - Light validation is for focused changes
   - Large changes should go through full validation

### ❌ Don'ts

1. **Don't skip validation entirely**
   - Even light validation catches critical issues
   - Always review PR before merging

2. **Don't merge untested code to main branches**
   - Feature branches are for experimentation
   - Main branches require full validation

3. **Don't abuse light validation**
   - Not meant to bypass quality standards
   - Use for incremental fixes, not architectural changes

4. **Don't forget to run tests locally**
   - Light validation doesn't run full tests
   - Run `./az.ps1 0402` locally before PR to main

---

## 🔍 Understanding PR Comments

### Light Validation Comment Example

```markdown
## 🤖 Copilot Branch PR Detected

**PR #123: Fix syntax error**
- **Author:** @username
- **Source:** `fix/syntax-error`
- **Target:** `copilot/feature-123`

### 🎯 Validation Strategy
This PR is targeting a **copilot branch** (not main/dev), so validation has been adjusted:

#### ✅ Enabled Validations
- **Syntax Check** - Ensures PowerShell code parses correctly
- **Basic Quality** - Lightweight quality checks
- **File Analysis** - Change impact assessment

#### ⚡ Relaxed Validations (for incremental fixes)
- **Comprehensive Tests** - ⏭️ Skipped (will run when merging to dev/main)
- **Full PSScriptAnalyzer** - ⏭️ Relaxed (critical issues only)
- **Documentation Updates** - ⏭️ Optional
- **Coverage Requirements** - ⏭️ Optional

### 💡 Workflow Intent
This allows you to:
- ✅ Make incremental fixes specific to the copilot branch
- ✅ Merge quickly to address specific issues
- ✅ Validate thoroughly when merging to dev/main later
```

### Full Validation Comment Example

```markdown
## 🔍 PR Validation Results

**#456: Complete feature implementation** by @username
**Target Branch:** `dev`

**Full validation** is applied to PRs targeting main branches.

### 📊 Change Summary
15 files: PS=12, Workflows=0, Tests=3

### ✅ Validation Status
- **Syntax Check:** ✅ PASSED
- **Main CI:** Will run automatically after this validation
```

---

## 📊 Decision Tree

```
                    Create PR
                       │
                       ▼
              What is target branch?
                       │
         ┌─────────────┼─────────────┐
         │                           │
         ▼                           ▼
    main/develop/dev        copilot/*/feature/*
         │                           │
         ▼                           ▼
  Full Validation              Light Validation
         │                           │
    ┌────┴────┐                 ┌────┴────┐
    │         │                 │         │
    ▼         ▼                 ▼         ▼
  Tests    Quality          Syntax    Critical
  (All)   (Complete)        Check     Issues
    │         │                 │         │
    └────┬────┘                 └────┬────┘
         │                           │
         ▼                           ▼
    10-15 min                    3-5 min
         │                           │
         ▼                           ▼
   High Quality                Fast Iteration
     Gate 🔒                      ⚡
```

---

## ⚠️ Troubleshooting

### Issue: "Why is full validation running on my feature branch PR?"

**Check:**
1. Is your PR target `main`, `develop`, or `dev`?
   - If yes → Full validation is correct
2. Did you select the wrong target branch?
   - If yes → Close PR and recreate with correct target

### Issue: "I need full validation on my feature branch PR"

**Solution:**
Use workflow_dispatch to manually run comprehensive tests:
1. Go to Actions tab
2. Select "Comprehensive Test Execution"
3. Click "Run workflow"
4. Select your branch

### Issue: "Light validation failed, now what?"

**Steps:**
1. Review the syntax errors or critical issues in PR comment
2. Fix the issues locally
3. Run `./az.ps1 0407` to verify syntax
4. Push changes - validation runs automatically
5. Once passing, merge and continue work

---

## 📚 Additional Resources

- **Full Documentation:** [FEATURE-BRANCH-PR-WORKFLOW.md](FEATURE-BRANCH-PR-WORKFLOW.md)
- **Implementation Details:** [FEATURE-BRANCH-PR-IMPLEMENTATION-SUMMARY.md](FEATURE-BRANCH-PR-IMPLEMENTATION-SUMMARY.md)
- **Workflow Documentation:** [workflows/README.md](workflows/README.md)
- **PR Triggers:** [WORKFLOW-PR-TRIGGERS.md](WORKFLOW-PR-TRIGGERS.md)

---

**Questions?** Open an issue or ask in team chat!
