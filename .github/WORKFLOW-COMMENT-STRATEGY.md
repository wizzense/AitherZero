# Workflow Comment Strategy & Harmony

This document defines how workflows coordinate their PR comments to provide value without duplication.

## Comment Hierarchy & Timing

### 1️⃣ PR Validation (First - Immediate Feedback)
**Workflow:** `pr-validation.yml`  
**Timing:** Runs immediately on PR open/update  
**Purpose:** Fast syntax validation and change analysis  
**Comment ID:** `✅ PR Validation Results`

**What it tells you:**
- ✅ Syntax is valid (or ❌ errors to fix)
- 📊 What files changed (PS, workflows, tests)
- 💡 Quick recommendations
- 🚀 What happens next

**Action:** Fix syntax errors if any, then wait for comprehensive tests

---

### 2️⃣ Unified Testing (Second - Comprehensive)
**Workflow:** `unified-testing.yml`  
**Timing:** Runs after PR validation (or on push to main/dev)  
**Purpose:** Full test suite via orchestration  
**Comment ID:** `🎯 Unified Test Orchestration Results`

**What it tells you:**
- 🧪 All test results (unit, integration, syntax, quality)
- 📊 Pass rate with visual progress bars
- 🔍 Quality & security issues
- 🎭 Profile used (quick/standard/full/ci)
- 🌐 Link to live dashboard

**Builds on PR Validation:** Expands from syntax to full testing

---

### 3️⃣ Quality Validation (Third - Detailed Quality)
**Workflow:** `quality-validation.yml`  
**Timing:** Runs in parallel with unified testing  
**Purpose:** Deep quality analysis of changed components  
**Comment ID:** `🔍 Quality Validation Report`

**What it tells you:**
- 📊 Quality scores per file
- ✅ Error handling, logging, test coverage
- 🔧 Specific improvements needed
- 📖 Links to quality guidelines

**Builds on Unified Testing:** Provides file-level quality details

---

### 4️⃣ Auto-Generate Tests (Helper)
**Workflow:** `auto-generate-tests.yml`  
**Timing:** Only when new automation scripts added  
**Purpose:** Auto-generates missing test files  
**Comment ID:** `🧪 Auto-Generated Tests`

**What it tells you:**
- 📝 Which test files were created
- 🔍 What tests cover
- ✅ Confirmation tests were added to PR

**Builds on:** Helps satisfy test coverage requirements

---

### 5️⃣ Documentation Updates (Helper)
**Workflows:** `documentation-automation.yml`, `index-automation.yml`  
**Timing:** After code changes, auto-updates docs  
**Purpose:** Keep documentation in sync  
**Comment ID:** `📚 Documentation Updated`

**What it tells you:**
- 📖 Which docs were updated
- 🔄 Index files refreshed
- ✅ Documentation is current

**Builds on:** Ensures your code changes are documented

---

## Comment Coordination Rules

### ✅ DO:
1. **Unique identifiers** - Each workflow uses a distinct emoji + title
2. **Progressive detail** - Each comment adds new information
3. **Link to previous** - Reference earlier comments when relevant
4. **Update existing** - Find and update your own comment, don't create duplicates
5. **Contextual help** - Provide next steps based on current state
6. **Visual indicators** - Use emojis and progress bars consistently

### ❌ DON'T:
1. **Repeat information** - Don't duplicate what other workflows already said
2. **Conflicting advice** - Ensure recommendations align across workflows
3. **Spam comments** - Always update existing comment when possible
4. **Generic messages** - Make each comment specific and actionable
5. **Hide context** - Always link to workflow run and relevant resources

---

## Visual Language Standards

### Status Indicators
- ✅ Success / Passed
- ❌ Failed / Error
- ⚠️ Warning / Partial Failure
- ⏳ In Progress / Queued
- ⏭️ Skipped
- 🔴 Critical / Blocking
- 🟡 Warning / Non-blocking
- 🟢 Success / Ready

### Progress Bars
```
🟢🟢🟢🟢🟢🟢🟢🟢🟢🟢  100% (All tests passed)
🟢🟢🟢🟢🟢🟢🟢🟢🟢⚪   90% (Excellent)
🟢🟢🟢🟢🟢🟢🟢⚪⚪⚪   70% (Good)
🟢🟢🟢🟢🟢⚪⚪⚪⚪⚪   50% (Needs improvement)
🔴🔴🔴🔴🔴⚪⚪⚪⚪⚪   <50% (Critical)
```

### Visual Counts
```
🟢 (repeated) = Number of passing tests (max 10)
🔴 (repeated) = Number of failing tests (max 10)
⚡ = Total items
📄 = Files
🧪 = Tests
📊 = Metrics
```

---

## Example: Coordinated Comment Flow

### Scenario: Developer opens PR with new PowerShell script

**Step 1: PR Validation comment appears (~30 seconds)**
```markdown
## ✅ PR Validation Results
### ✅ Quick Validation: 🟢 READY
📊 Changes: 2 files (PS=1, Tests=1)
✅ Syntax Check: PASSED
⏳ Main CI: Queued
```

**Step 2: Unified Testing comment appears (~2-3 minutes)**
```markdown
## 🎯 Unified Test Orchestration Results
### ✅ Status: ALL TESTS PASSED • 🟢 SUCCESS
Pass Rate: 98% 🟢🟢🟢🟢🟢🟢🟢🟢🟢⚪
📊 Test Results: 245 total, 240 passed, 5 skipped
🔍 Quality: 0 critical, 2 medium issues
→ View details in Quality Validation below
```

**Step 3: Quality Validation comment appears (parallel, ~2 minutes)**
```markdown
## 🔍 Quality Validation Report
### ✅ Overall: PASSED (Score: 85%)
File: MyNewScript.ps1 - Score 85%
✅ Error handling: Good
⚠️ Logging: 2 improvements suggested
✅ Test coverage: Present
→ See specific recommendations in collapsible section
```

**Step 4: Auto-generate tests (if needed, ~1 minute)**
```markdown
## 🧪 Auto-Generated Tests
✅ Created: tests/unit/automation-scripts/0700-0799/MyNewScript.Tests.ps1
📝 Coverage: Basic validation + parameter tests
🔄 Tests added to this PR automatically
```

### Result:
- Developer sees clear progression: syntax → full tests → quality → helpers
- Each comment adds new information, no duplication
- All comments link together logically
- Clear action items at each stage
- Visual consistency across all workflows

---

## Workflow Comment Templates

### Finding and Updating Existing Comments
```javascript
// Standard pattern - use in all workflows
const { data: comments } = await github.rest.issues.listComments({
  owner: context.repo.owner,
  repo: context.repo.repo,
  issue_number: context.issue.number
});

const existingComment = comments.find(c =>
  c.user.login === 'github-actions[bot]' &&
  c.body.includes('YOUR_UNIQUE_TITLE_HERE')
);

if (existingComment) {
  await github.rest.issues.updateComment({
    owner: context.repo.owner,
    repo: context.repo.repo,
    comment_id: existingComment.id,
    body: comment
  });
} else {
  await github.rest.issues.createComment({
    owner: context.repo.owner,
    repo: context.repo.repo,
    issue_number: context.issue.number,
    body: comment
  });
}
```

### Comment Footer Template
```markdown
---
*🤖 Automated by [Workflow Name] • [Unique Context] • [Workflow Link]*
```

---

## Maintenance

When adding new workflows that comment:
1. Choose a unique emoji + title combination
2. Add it to this document
3. Ensure it builds on existing comments
4. Use the standard comment update pattern
5. Follow visual language standards
6. Test that it doesn't conflict with existing comments

---

**Last Updated:** 2025-11-04  
**Maintained By:** AitherZero Development Team
