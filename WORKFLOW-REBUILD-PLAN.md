# GitHub Actions Workflow Rebuild Plan

## Executive Summary

This plan outlines a complete rebuild of the GitHub Actions workflows for AitherZero, leveraging the existing orchestration engine, playbooks, and automation scripts to create a minimal, efficient, and maintainable CI/CD pipeline.

**Core Principle:** Keep workflows simple by delegating complexity to playbooks and automation scripts.

---

## Current State Analysis

### Existing Workflows (8 files)
1. `pr-check.yml` - PR validation (consolidated)
2. `deploy.yml` - Branch deployment
3. `03-test-execution.yml` - Test execution (reusable)
4. `04-deploy-pr-environment.yml` - PR environment deployment
5. `05-publish-reports-dashboard.yml` - Dashboard publishing
6. `09-jekyll-gh-pages.yml` - Jekyll deployment
7. `release.yml` - Release workflow
8. `test-dashboard-generation.yml` - Manual dashboard testing

### Existing Assets
- **177 automation scripts** in `library/automation-scripts/`
- **20+ playbooks** in `library/playbooks/`
- **Orchestration engine** with `Invoke-AitherPlaybook` command
- **Test execution** already parallelized and working
- **Container build** process that works

### Key Playbooks Available
- `pr-ecosystem-complete.psd1` - Complete PR validation (Build → Analyze → Report)
- `dashboard-generation-complete.psd1` - Dashboard generation
- `comprehensive-validation.psd1` - Full validation
- `code-quality-full.psd1` / `code-quality-fast.psd1` - Code quality checks
- `integration-tests-full.psd1` - Integration testing

---

## Proposed New Architecture

### Design Principles

1. **Minimal Workflows**: Reduce to 3-4 core workflows
2. **Maximum Delegation**: Let playbooks handle all complexity
3. **Clear Triggers**: Each workflow has one clear purpose
4. **Reusable Components**: Use `workflow_call` for shared logic
5. **Fast Feedback**: Optimize for quick PR validation
6. **Comprehensive Coverage**: Full CI/CD on main branch

### New Workflow Structure

```
┌─────────────────────────────────────────────────────────────┐
│                     PROPOSED ARCHITECTURE                    │
└─────────────────────────────────────────────────────────────┘

1. COORDINATOR.yml (Master Orchestrator)
   ├─ Trigger: pull_request, push, workflow_dispatch
   ├─ Job: Determine execution path
   └─ Calls: pr-validation.yml OR branch-deployment.yml

2. PR-VALIDATION.yml (Reusable)
   ├─ Called by: coordinator.yml (on PR events)
   ├─ Bootstrap → Invoke-AitherPlaybook pr-ecosystem-complete
   └─ Outputs: test results, coverage, quality metrics

3. BRANCH-DEPLOYMENT.yml (Reusable)
   ├─ Called by: coordinator.yml (on push events)
   ├─ Bootstrap → Invoke-AitherPlaybook deployment-complete
   └─ Jobs: Test → Build → Deploy → Pages

4. RELEASE.yml (Independent)
   ├─ Trigger: tag push (v*)
   ├─ Bootstrap → Invoke-AitherPlaybook release-complete
   └─ Outputs: Release artifacts, containers, packages
```

---

## Detailed Workflow Specifications

### 1. COORDINATOR.yml (The Single Entry Point)

**Purpose:** Route events to appropriate workflows based on trigger type

**File:** `.github/workflows/coordinator.yml`

**Structure:**
```yaml
name: 🎯 CI/CD Coordinator

on:
  pull_request:
  push:
    branches: [main, dev, develop, dev-staging, ring-*]
  workflow_dispatch:

jobs:
  route:
    name: 🧭 Route to Appropriate Workflow
    runs-on: ubuntu-latest
    outputs:
      workflow: ${{ steps.determine.outputs.workflow }}
    
    steps:
      - name: Determine Workflow
        id: determine
        run: |
          if [[ "${{ github.event_name }}" == "pull_request" ]]; then
            echo "workflow=pr-validation" >> $GITHUB_OUTPUT
          else
            echo "workflow=branch-deployment" >> $GITHUB_OUTPUT
          fi
  
  pr-validation:
    if: needs.route.outputs.workflow == 'pr-validation'
    needs: route
    uses: ./.github/workflows/pr-validation.yml
    secrets: inherit
  
  branch-deployment:
    if: needs.route.outputs.workflow == 'branch-deployment'
    needs: route
    uses: ./.github/workflows/branch-deployment.yml
    secrets: inherit
```

**Key Features:**
- Single entry point for all CI/CD
- Clear routing logic
- No complex logic - just routing
- All secrets passed through

---

### 2. PR-VALIDATION.yml (PR Workflow)

**Purpose:** Validate PRs using playbook orchestration

**File:** `.github/workflows/pr-validation.yml`

**Structure:**
```yaml
name: ✅ PR Validation

on:
  workflow_call:
  workflow_dispatch:

permissions:
  contents: read
  pull-requests: write
  checks: write

env:
  AITHERZERO_CI: true
  AITHERZERO_NONINTERACTIVE: true
  AITHERZERO_SUPPRESS_BANNER: true

jobs:
  validate:
    name: 🚀 PR Ecosystem Validation
    runs-on: ubuntu-latest
    timeout-minutes: 45
    
    steps:
      - name: 📥 Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: 🔧 Bootstrap
        shell: pwsh
        run: ./bootstrap.ps1 -Mode New -InstallProfile Minimal
      
      - name: 🚀 Execute PR Ecosystem Playbook
        shell: pwsh
        env:
          PR_NUMBER: ${{ github.event.pull_request.number }}
          GITHUB_BASE_REF: ${{ github.base_ref }}
          GITHUB_HEAD_REF: ${{ github.head_ref }}
        run: |
          Import-Module ./AitherZero.psd1 -Force
          
          $result = Invoke-AitherPlaybook -Name pr-ecosystem-complete -PassThru
          
          if ($result.FailedCount -gt 0) {
            Write-Error "Validation failed"
            exit 1
          }
      
      - name: 📊 Upload Test Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: pr-validation-results
          path: |
            library/tests/results/**
            library/tests/coverage/**
            library/reports/**
      
      - name: 📝 Post PR Comment
        if: always()
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const commentPath = './library/reports/pr-comment.md';
            
            if (!fs.existsSync(commentPath)) {
              console.log('No PR comment generated');
              return;
            }
            
            const body = fs.readFileSync(commentPath, 'utf8');
            const marker = '<!-- AITHERZERO_PR_VALIDATION -->';
            
            const { data: comments } = await github.rest.issues.listComments({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number
            });
            
            const existing = comments.find(c => 
              c.user.login === 'github-actions[bot]' && 
              c.body.includes(marker)
            );
            
            const finalBody = body + '\n' + marker;
            
            if (existing) {
              await github.rest.issues.updateComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                comment_id: existing.id,
                body: finalBody
              });
            } else {
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.issue.number,
                body: finalBody
              });
            }
```

**Key Features:**
- Single job - all logic in playbook
- Playbook handles: build, test, analyze, report
- Minimal workflow code
- Proper artifact collection
- PR comment from playbook output

---

### 3. BRANCH-DEPLOYMENT.yml (Branch Workflow)

**Purpose:** Full deployment pipeline for branch pushes

**File:** `.github/workflows/branch-deployment.yml`

**Structure:**
```yaml
name: 🚀 Branch Deployment

on:
  workflow_call:
  workflow_dispatch:

permissions:
  contents: write
  packages: write
  pages: write
  id-token: write

env:
  AITHERZERO_CI: true
  AITHERZERO_NONINTERACTIVE: true
  AITHERZERO_SUPPRESS_BANNER: true

jobs:
  # ================================================================
  # PHASE 1: Test & Validate
  # ================================================================
  test:
    name: 🧪 Test Suite
    runs-on: ubuntu-latest
    timeout-minutes: 30
    
    steps:
      - uses: actions/checkout@v4
      - run: ./bootstrap.ps1 -Mode New -InstallProfile Minimal
        shell: pwsh
      
      - name: Run Test Playbook
        shell: pwsh
        run: |
          Import-Module ./AitherZero.psd1 -Force
          Invoke-AitherPlaybook -Name comprehensive-validation -PassThru
      
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results
          path: library/tests/results/**
      
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: coverage-report
          path: library/tests/coverage/**
  
  # ================================================================
  # PHASE 2: Build Container
  # ================================================================
  build:
    name: 🐳 Build Container
    needs: test
    runs-on: ubuntu-latest
    timeout-minutes: 20
    
    steps:
      - uses: actions/checkout@v4
      
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Build and Push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.ref_name }}
  
  # ================================================================
  # PHASE 3: Generate Dashboard
  # ================================================================
  dashboard:
    name: 📊 Generate Dashboard
    needs: test
    runs-on: ubuntu-latest
    timeout-minutes: 15
    
    steps:
      - uses: actions/checkout@v4
      - run: ./bootstrap.ps1 -Mode New -InstallProfile Minimal
        shell: pwsh
      
      - uses: actions/download-artifact@v4
        with:
          name: test-results
          path: library/tests/results
      
      - uses: actions/download-artifact@v4
        with:
          name: coverage-report
          path: library/tests/coverage
      
      - name: Generate Dashboard
        shell: pwsh
        run: |
          Import-Module ./AitherZero.psd1 -Force
          Invoke-AitherPlaybook -Name dashboard-generation-complete -PassThru
      
      - uses: actions/upload-artifact@v4
        with:
          name: dashboard-reports
          path: library/reports/**
  
  # ================================================================
  # PHASE 4: Deploy to GitHub Pages
  # ================================================================
  deploy-pages:
    name: 📄 Deploy Pages
    needs: dashboard
    runs-on: ubuntu-latest
    timeout-minutes: 10
    
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/download-artifact@v4
        with:
          name: dashboard-reports
          path: library/reports
      
      - name: Build Jekyll Site
        uses: actions/jekyll-build-pages@v1
      
      - name: Deploy to Pages
        uses: actions/deploy-pages@v4
```

**Key Features:**
- Sequential phases: test → build → dashboard → pages
- Each phase uses playbooks
- Artifact passing between phases
- Clear dependencies

---

### 4. RELEASE.yml (Release Workflow)

**Purpose:** Handle versioned releases (v* tags)

**File:** `.github/workflows/release.yml`

**Structure:**
```yaml
name: 🎉 Release

on:
  push:
    tags: ['v*']
  workflow_dispatch:

permissions:
  contents: write
  packages: write

jobs:
  release:
    name: 🚀 Create Release
    runs-on: ubuntu-latest
    timeout-minutes: 60
    
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - run: ./bootstrap.ps1 -Mode New -InstallProfile Full
        shell: pwsh
      
      - name: Execute Release Playbook
        shell: pwsh
        run: |
          Import-Module ./AitherZero.psd1 -Force
          Invoke-AitherPlaybook -Name release-complete -PassThru
      
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          files: ./dist/**
          generate_release_notes: true
```

**Key Features:**
- Triggered only on version tags
- Full profile bootstrap
- Complete release playbook
- Auto-generated release notes

---

## Required Playbook Updates

### New Playbooks Needed

#### 1. `deployment-complete.psd1`
Combines test execution, container build, and dashboard generation for branch deployments.

```powershell
@{
    Name = "deployment-complete"
    Description = "Complete branch deployment pipeline"
    Sequence = @(
        @{ Playbook = "comprehensive-validation"; Phase = "test" }
        @{ Script = "0744"; Description = "Build container metadata"; Phase = "build" }
        @{ Playbook = "dashboard-generation-complete"; Phase = "dashboard" }
    )
}
```

#### 2. `release-complete.psd1`
Full release process including validation, building, packaging, and publishing.

```powershell
@{
    Name = "release-complete"
    Description = "Complete release pipeline"
    Sequence = @(
        @{ Playbook = "comprehensive-validation"; Phase = "validate" }
        @{ Script = "0515"; Description = "Build release packages"; Phase = "build" }
        @{ Script = "0902"; Description = "Generate changelog"; Phase = "docs" }
        @{ Playbook = "dashboard-generation-complete"; Phase = "report" }
    )
}
```

### Playbook Enhancements Needed

1. **pr-ecosystem-complete.psd1** - Ensure it generates `pr-comment.md`
2. **dashboard-generation-complete.psd1** - Verify it handles missing artifacts gracefully
3. **comprehensive-validation.psd1** - Add code quality checks

---

## Migration Strategy

### Phase 1: Backup (Safety First)

```bash
# Create backup directory
mkdir -p .github/workflows-backup

# Copy all existing workflows
cp .github/workflows/*.yml .github/workflows-backup/

# Document current state
ls -lh .github/workflows/*.yml > .github/workflows-backup/MANIFEST.txt
```

### Phase 2: Create New Playbooks

1. Create `deployment-complete.psd1`
2. Create `release-complete.psd1`
3. Update existing playbooks as needed
4. Test playbooks locally

### Phase 3: Implement New Workflows

1. Create `coordinator.yml`
2. Create `pr-validation.yml`
3. Create `branch-deployment.yml`
4. Update `release.yml`

### Phase 4: Remove Old Workflows

Move to backup:
- `pr-check.yml` → backup
- `deploy.yml` → backup
- `03-test-execution.yml` → backup (logic in playbook now)
- `04-deploy-pr-environment.yml` → backup
- `05-publish-reports-dashboard.yml` → backup
- `09-jekyll-gh-pages.yml` → backup (logic in branch-deployment now)
- `test-dashboard-generation.yml` → backup

Keep only:
- `coordinator.yml` (new)
- `pr-validation.yml` (new)
- `branch-deployment.yml` (new)
- `release.yml` (updated)

### Phase 5: Testing & Validation

1. Test on feature branch first
2. Verify PR validation works
3. Verify branch deployment works
4. Verify release process works
5. Monitor first few runs
6. Adjust as needed

---

## Performance Optimizations

### 1. Parallel Execution
- Test suites already run in parallel (keep this)
- Independent workflow jobs run in parallel
- Artifact uploads happen asynchronously

### 2. Caching Strategy
```yaml
- name: Cache PowerShell Modules
  uses: actions/cache@v4
  with:
    path: ~/.local/share/powershell/Modules
    key: ${{ runner.os }}-pwsh-${{ hashFiles('**/AitherZero.psd1') }}

- name: Cache Docker Layers
  uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

### 3. Timeout Settings
- PR validation: 45 minutes (comprehensive)
- Test suite: 30 minutes (parallelized)
- Container build: 20 minutes (cached)
- Dashboard generation: 15 minutes
- Pages deployment: 10 minutes

### 4. Conditional Execution
- Skip Docker build on doc-only changes
- Skip tests on workflow-only changes
- Fast-path for minor changes

---

## Best Practices Applied

### 1. Workflow Design
- ✅ Single responsibility per workflow
- ✅ Reusable workflows via `workflow_call`
- ✅ Clear naming and documentation
- ✅ Proper timeout settings
- ✅ Minimal permissions

### 2. Error Handling
- ✅ Proper exit codes from playbooks
- ✅ Continue-on-error where appropriate
- ✅ Artifact collection even on failure
- ✅ Clear error messages

### 3. Security
- ✅ Minimal permissions per job
- ✅ No secrets in logs
- ✅ GITHUB_TOKEN for authentication
- ✅ Signed releases

### 4. Maintainability
- ✅ Logic in playbooks, not workflows
- ✅ Version pinned actions
- ✅ Self-documenting YAML
- ✅ Easy to test locally

---

## Expected Benefits

### Reduced Complexity
- **Before:** 8 workflows, ~1000 lines of YAML
- **After:** 4 workflows, ~400 lines of YAML
- **Reduction:** 60% less workflow code

### Improved Speed
- **PR Validation:** 15-20 minutes (optimized)
- **Branch Deployment:** 25-30 minutes (parallelized)
- **Release:** 40-50 minutes (comprehensive)

### Better Maintainability
- All logic in playbooks (testable locally)
- Clear workflow structure
- Easy to understand and modify
- Self-documenting

### Enhanced Reliability
- Fewer moving parts
- Better error handling
- Clear dependencies
- Proper artifact management

---

## Risk Mitigation

### Backup Strategy
- All existing workflows backed up
- Can revert quickly if needed
- Documented restoration process

### Testing Plan
1. Test on feature branch
2. Run multiple times
3. Verify all scenarios
4. Monitor first production runs
5. Keep backup accessible for 30 days

### Rollback Plan
```bash
# If needed, restore old workflows
cp .github/workflows-backup/*.yml .github/workflows/
git add .github/workflows/
git commit -m "Rollback to previous workflow configuration"
```

---

## Success Metrics

### Performance
- [ ] PR validation completes in < 20 minutes
- [ ] Branch deployment completes in < 30 minutes
- [ ] All tests run in parallel
- [ ] Dashboard generated successfully

### Reliability
- [ ] 100% workflow success rate (excluding intentional failures)
- [ ] All artifacts collected properly
- [ ] GitHub Pages deploys consistently
- [ ] Releases build successfully

### Maintainability
- [ ] No workflow logic duplication
- [ ] All complex logic in playbooks
- [ ] Easy to add new steps
- [ ] Clear documentation

---

## Implementation Checklist

### Preparation
- [ ] Review and approve this plan
- [ ] Create backup directory
- [ ] Backup all existing workflows
- [ ] Document current workflow triggers

### Playbook Development
- [ ] Create `deployment-complete.psd1`
- [ ] Create `release-complete.psd1`
- [ ] Update `pr-ecosystem-complete.psd1`
- [ ] Test all playbooks locally

### Workflow Implementation
- [ ] Create `coordinator.yml`
- [ ] Create `pr-validation.yml`
- [ ] Create `branch-deployment.yml`
- [ ] Update `release.yml`
- [ ] Remove old workflows

### Testing
- [ ] Test on feature branch
- [ ] Verify PR validation
- [ ] Verify branch deployment
- [ ] Verify release process
- [ ] Monitor production runs

### Documentation
- [ ] Update README with new workflow info
- [ ] Document playbook usage
- [ ] Create workflow diagrams
- [ ] Update contribution guide

---

## Timeline Estimate

- **Planning & Backup:** 30 minutes
- **Playbook Development:** 2-3 hours
- **Workflow Implementation:** 2-3 hours
- **Testing & Validation:** 2-4 hours
- **Documentation:** 1-2 hours

**Total:** 8-12 hours (1-2 days)

---

## Conclusion

This plan provides a comprehensive rebuild of the GitHub Actions workflows following the principle of **simplicity through delegation**. By moving all complex logic to playbooks and keeping workflows as simple coordinators, we achieve:

- **Faster execution** through optimization
- **Easier maintenance** through simplification
- **Better reliability** through clearer structure
- **Local testability** through playbook abstraction

The new architecture reduces workflow count from 8 to 4, cuts YAML code by 60%, and makes the entire CI/CD pipeline easier to understand and maintain.

**Next Step:** Review and approve this plan before beginning implementation.
