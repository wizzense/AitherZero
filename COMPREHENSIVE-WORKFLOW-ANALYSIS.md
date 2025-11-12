# COMPREHENSIVE WORKFLOW ANALYSIS & REBUILD PLAN
## AitherZero GitHub Actions Infrastructure Deep Dive

**Date:** 2025-11-12  
**Status:** Research Complete - Ready for Implementation Planning  
**Total Lines Analyzed:** ~4,500 lines of workflow YAML + 20+ playbooks + 175 automation scripts

---

## EXECUTIVE SUMMARY

After comprehensive analysis of all workflows, playbooks, and automation scripts, here's what exists and what needs to be rebuilt:

### **CRITICAL PRINCIPLE: LOCAL EXECUTION FIRST** ⚠️

**Everything must be runnable locally without GitHub Actions!**

Workflows should ONLY:
- Bootstrap the environment (`./bootstrap.ps1`)
- Call playbooks (`Invoke-AitherPlaybook`)
- Upload artifacts
- Post results

**ALL logic must be in playbooks and automation scripts** so developers can run the exact same CI/CD pipeline locally:

```powershell
# What a developer runs locally (should match what CI runs)
./bootstrap.ps1 -Mode New -InstallProfile Minimal
Import-Module ./AitherZero.psd1 -Force
Invoke-AitherPlaybook -Name pr-ecosystem-complete

# What GitHub Actions runs (EXACT SAME THING)
./bootstrap.ps1 -Mode New -InstallProfile Minimal
Import-Module ./AitherZero.psd1 -Force
Invoke-AitherPlaybook -Name pr-ecosystem-complete
```

**Zero workflow logic. Zero script calls. Just playbook invocation.**

### Current State (8 Workflows, 4,490 total lines)

| Workflow | Lines | Purpose | Status | Keep? |
|----------|-------|---------|--------|-------|
| **03-test-execution.yml** | 774 | Parallel test execution (unit, domain, integration) | ✅ **WORKS WELL** | YES - **REUSABLE** |
| **04-deploy-pr-environment.yml** | 755 | PR preview environments + container builds | ✅ **USER CONFIRMED WORKING** | YES - **CORE FUNCTIONALITY** |
| **05-publish-reports-dashboard.yml** | 708 | Dashboard generation after tests | ⚠️ **FIXED (typo)** | MERGE INTO NEW |
| **09-jekyll-gh-pages.yml** | 433 | Jekyll site deployment | ✅ WORKS | YES - **PAGES DEPLOYMENT** |
| **pr-check.yml** | 434 | PR validation (5 parallel jobs) | ⚠️ COMPLEX | SIMPLIFY |
| **deploy.yml** | 223 | Branch deployment (Docker only) | ⚠️ INCOMPLETE | REBUILD |
| **release.yml** | 805 | Release process for v* tags | ✅ COMPREHENSIVE | KEEP & ENHANCE |
| **test-dashboard-generation.yml** | 358 | Manual dashboard testing | ℹ️ DEBUG TOOL | KEEP |

---

## DETAILED CURRENT STATE ANALYSIS

### What Actually Works (KEEP THESE)

#### 1. **03-test-execution.yml** ✅ EXCELLENT
- **774 lines** - Well-designed, reusable workflow
- **Triggers:**
  - `push` to protected branches
  - `workflow_call` (reusable by other workflows)
  - `workflow_dispatch` (manual)
- **Structure:**
  - Parallel test execution across 9 unit ranges
  - 6 domain module tests in parallel
  - 4 integration test suites in parallel
  - Coverage collection and aggregation
  - Performance metrics
- **Why it's good:**
  - Already parallelized optimally
  - Reusable via `workflow_call`
  - Comprehensive test coverage
  - Artifact management works
- **USE THIS:** All other workflows should call this via `uses: ./.github/workflows/03-test-execution.yml`

#### 2. **04-deploy-pr-environment.yml** ✅ USER CONFIRMED WORKING
- **755 lines** - "The only workflow that consistently works"
- **Triggers:**
  - `pull_request` events
  - `push` tags (v*)
  - `release` events
  - `issue_comment` commands
  - `workflow_dispatch`
- **Functionality:**
  - PR preview environment deployment
  - Container builds (multi-platform)
  - Release builds
  - Issue comment commands
  - Environment cleanup
- **Why keep:**
  - User confirmed it's the only reliable workflow
  - Handles both PR previews AND releases
  - Complex deployment logic that works
  - Container builds proven working
- **USE THIS:** Core container build and deployment logic

#### 3. **09-jekyll-gh-pages.yml** ✅ WORKS
- **433 lines** - Jekyll deployment to GitHub Pages
- **Triggers:** `workflow_dispatch` only (called by other workflows)
- **Functionality:**
  - Branch-specific deployment paths
  - Downloads artifacts from report workflows
  - Builds Jekyll site with reports
  - Deploys to GitHub Pages
- **Why keep:**
  - Final step in deployment chain
  - Branch-specific URL handling works
  - Artifact integration works
- **USE THIS:** Final deployment step after dashboard generation

#### 4. **release.yml** ✅ COMPREHENSIVE
- **805 lines** - Complete release pipeline
- **Triggers:**
  - `push` tags (v*)
  - `workflow_dispatch` with version input
- **Functionality:**
  - Pre-release validation
  - Comprehensive testing
  - Module manifest versioning
  - Release notes generation
  - Multi-platform container builds
  - GitHub release creation
  - Asset publishing
- **Why keep:**
  - Handles full release lifecycle
  - Already comprehensive
  - Proven to work for releases
- **ENHANCE:** Could leverage playbooks for some steps

### What Needs Rebuilding

#### 1. **pr-check.yml** ⚠️ TOO COMPLEX
- **434 lines** - 5 parallel jobs doing individual automation scripts
- **Problems:**
  - Duplicates logic that exists in playbooks
  - Calls individual scripts instead of playbooks
  - Complex job orchestration
  - Doesn't leverage `pr-ecosystem-complete` playbook
- **Current Jobs:**
  1. `validate` - Calls 0407, 0413, 0405, 0950
  2. `test` - Calls 03-test-execution.yml ✅
  3. `build` - Calls 0515, 0900
  4. `build-docker` - Builds container
  5. `docs` - Calls 0746, 0745
  6. `summary` - Aggregates results, posts comment
- **SHOULD BE:**
  - Single job calling `Invoke-AitherPlaybook pr-ecosystem-complete`
  - Playbook handles all orchestration
  - Workflow just bootstraps and calls playbook

#### 2. **deploy.yml** ⚠️ INCOMPLETE
- **223 lines** - Only builds Docker, missing full pipeline
- **Problems:**
  - Only has `build-and-push-docker` job
  - Missing test integration
  - Missing dashboard generation
  - Missing Pages deployment
  - Comments SAY it triggers other workflows, but doesn't actually call them
- **What it claims to do:**
  - "Triggers 03-test-execution.yml" - FALSE (separate push trigger)
  - "Triggers 05-publish-reports-dashboard.yml" - Via workflow_run (fragile)
  - "Triggers 09-jekyll-gh-pages.yml" - Indirectly (fragile chain)
- **SHOULD BE:**
  - Call 03-test-execution.yml explicitly
  - Build Docker after tests pass
  - Generate dashboard with test results
  - Deploy to Pages
  - Full sequential pipeline

#### 3. **05-publish-reports-dashboard.yml** ⚠️ FIXED BUT REDUNDANT
- **708 lines** - Dashboard generation
- **Fixed:** workflow_run trigger typo
- **Problems:**
  - Separate workflow creates fragile chain
  - workflow_run triggers are unreliable
  - Should be integrated into deploy.yml
  - Duplicates dashboard generation that should be in playbook
- **What it does well:**
  - Downloads test artifacts
  - Calls `Invoke-AitherPlaybook dashboard-generation-complete`
  - Triggers Jekyll deployment
- **SHOULD BE:**
  - Integrated as a job in deploy.yml
  - No separate workflow needed

---

## PLAYBOOK ANALYSIS

### Available Playbooks (20+ files)

#### PR Ecosystem Playbooks (THE SOLUTION!)

**pr-ecosystem-complete.psd1** (147 lines)
- Master orchestrator for PR validation
- Calls 3 sub-playbooks:
  1. `pr-ecosystem-build` - Build artifacts
  2. `pr-ecosystem-analyze` - Tests & quality
  3. `pr-ecosystem-report` - Dashboard & deployment
- **THIS IS WHAT pr-check.yml SHOULD USE!**

**pr-ecosystem-build.psd1** (122 lines)
- Scripts: 0407 (syntax), 0515 (metadata), 0902 (package), 0900 (self-deploy test)
- Parallel execution where possible
- Generates build artifacts

**pr-ecosystem-analyze.psd1** (199 lines)
- Scripts: 0402 (unit tests), 0403 (integration), 0404 (quality), 0420 (component quality), 0744 (diff analysis), 0520-0524 (metrics)
- Parallel test execution
- Quality analysis

**pr-ecosystem-report.psd1** (199 lines)
- Scripts: 0510 (project report), 0512 (dashboard), 0745 (indexes), 0746 (docs), 0902 (changelog)
- Generates comprehensive dashboard
- Creates PR comment markdown

#### Other Key Playbooks

**dashboard-generation-complete.psd1** (90 lines)
- Scripts: 0520-0524 (metrics collection), 0512 (dashboard generation)
- Used by 05-publish-reports-dashboard.yml
- **THIS IS WHAT deploy.yml SHOULD USE!**

**comprehensive-validation.psd1** (87 lines)
- Three-tier validation: AST → PSScriptAnalyzer → Pester
- Scripts: 0412, 0404, 0402, 0403
- Could be used for thorough validation

**code-quality-full.psd1** / **code-quality-fast.psd1**
- Quality checks with PSScriptAnalyzer
- Fast variant for CI

---

## AUTOMATION SCRIPT INVENTORY

### 175 Unique Automation Scripts by Range

| Range | Count | Purpose | Key Scripts |
|-------|-------|---------|-------------|
| 0000-0099 | 10 | Environment setup | 0000 (bootstrap), 0007 (env check) |
| 0100-0199 | 8 | Infrastructure | 0100 (Hyper-V), 0150 (certificates) |
| 0200-0299 | 19 | Dev tools install | 0200 (Git), 0210 (Node), 0220 (Python), 0250 (Docker) |
| 0300-0399 | 1 | Reserved | - |
| 0400-0499 | 28 | **TESTING** | **0402 (unit), 0403 (integration), 0404 (quality), 0407 (syntax)** |
| 0500-0599 | 26 | **REPORTING** | **0510 (project report), 0512 (dashboard), 0515 (build metadata)** |
| 0700-0799 | 36 | **GIT/AI/DOCS** | **0744 (diff), 0745 (indexes), 0746 (docs)** |
| 0800-0899 | 30 | Issue management | 0800-0830 (issue creation), 0840-0860 (PR management) |
| 0900-0999 | 16 | **VALIDATION/PACKAGE** | **0900 (self-deploy), 0902 (package), 0950 (validate scripts)** |
| 9900-9999 | 1 | Cleanup | 9900 (archive old files) |

### Critical Scripts Used by Playbooks

**Build & Package:**
- 0515: Generate build metadata
- 0900: Self-deployment test
- 0902: Create release package

**Testing:**
- 0402: Run unit tests (Pester)
- 0403: Run integration tests
- 0404: PSScriptAnalyzer
- 0407: Syntax validation
- 0412: AST validation
- 0420: Component quality validation

**Reporting & Dashboard:**
- 0510: Project health report
- 0512: Dashboard generation
- 0520-0524: Metrics collection (ring, workflow, PR, performance, tech debt)

**Documentation:**
- 0745: Generate indexes
- 0746: Generate documentation

**Analysis:**
- 0744: Diff analysis (PR changes)

---

## THE PROBLEM WITH CURRENT SETUP

### Why Current Workflows Are Broken

1. **pr-check.yml doesn't use pr-ecosystem-complete playbook**
   - Has 5 separate jobs calling individual scripts
   - Duplicates orchestration that playbook already does
   - Should just call playbook and let it handle everything

2. **deploy.yml is incomplete**
   - Only builds Docker
   - Relies on separate workflows triggering via workflow_run (fragile)
   - Doesn't explicitly call test execution
   - Doesn't generate dashboard
   - Doesn't deploy to Pages

3. **Fragile workflow_run chain**
   - deploy.yml pushes → 03-test-execution.yml (separate push trigger)
   - 03-test-execution.yml completes → 05-publish-reports-dashboard.yml (workflow_run)
   - 05-publish-reports-dashboard.yml → 09-jekyll-gh-pages.yml (workflow_dispatch)
   - **ANY FAILURE IN CHAIN = SILENT FAILURE**

4. **Duplication everywhere**
   - Docker builds in: pr-check.yml, deploy.yml, 04-deploy-pr-environment.yml, release.yml
   - Dashboard generation: pr-check.yml summary job, 05-publish-reports-dashboard.yml
   - Test execution: Inline in pr-check.yml, separate in 03-test-execution.yml

---

## PROPOSED NEW ARCHITECTURE

### Design Principles

1. **LOCAL EXECUTION FIRST** ⚠️
   - Workflows call playbooks, not scripts
   - Playbooks orchestrate scripts
   - Developer runs: `Invoke-AitherPlaybook -Name pr-ecosystem-complete`
   - CI runs: Same command
   - Zero logic in YAML - 100% in PowerShell

2. **Leverage What Works**
   - Keep 03-test-execution.yml (it's perfect)
   - Keep 04-deploy-pr-environment.yml (user confirmed working)
   - Keep 09-jekyll-gh-pages.yml (final deployment works)
   - Keep release.yml (comprehensive)

2. **Use Playbooks for Orchestration**
   - pr-check.yml → `Invoke-AitherPlaybook pr-ecosystem-complete`
   - deploy.yml → `Invoke-AitherPlaybook dashboard-generation-complete` (after tests)
   - **NO direct script calls in workflows**
   - **NO workflow-specific logic**
   - Playbooks handle everything

3. **Explicit Dependencies**
   - No workflow_run triggers
   - Use `needs:` for job dependencies
   - Use `uses:` for workflow_call

4. **Minimal Workflow Code**
   - Workflows ONLY: bootstrap, call playbook, upload artifacts, post results
   - All orchestration in playbooks
   - All logic in automation scripts
   - Playbooks testable locally: `Invoke-AitherPlaybook -Name <playbook> -DryRun`
   - **Developers run exact same commands as CI**

### New Workflow Structure (4 Core Workflows)

```
┌─────────────────────────────────────────────────────────────────┐
│                    PROPOSED ARCHITECTURE                         │
└─────────────────────────────────────────────────────────────────┘

1. PR-VALIDATION.yml (NEW - Simplified pr-check.yml)
   ├─ Trigger: pull_request
   ├─ Job 1: pr-validation
   │  ├─ Bootstrap
   │  ├─ Invoke-AitherPlaybook pr-ecosystem-complete
   │  └─ Upload artifacts
   ├─ Job 2: pr-preview (optional)
   │  └─ Call 04-deploy-pr-environment.yml
   └─ Job 3: post-comment
      └─ Post PR comment from playbook output

2. BRANCH-DEPLOYMENT.yml (NEW - Complete deploy.yml)
   ├─ Trigger: push to main/dev/dev-staging/ring-*
   ├─ Job 1: test
   │  └─ uses: ./.github/workflows/03-test-execution.yml
   ├─ Job 2: build-docker
   │  ├─ needs: test
   │  └─ Build & push Docker image
   ├─ Job 3: generate-dashboard
   │  ├─ needs: test
   │  ├─ Download test artifacts
   │  ├─ Invoke-AitherPlaybook dashboard-generation-complete
   │  └─ Upload dashboard artifacts
   ├─ Job 4: deploy-pages
   │  ├─ needs: generate-dashboard
   │  └─ uses: ./.github/workflows/09-jekyll-gh-pages.yml
   └─ Job 5: summary
      └─ Aggregate and report

3. 04-DEPLOY-PR-ENVIRONMENT.yml (KEEP - Working!)
   ├─ Trigger: pull_request, tags, release, issue_comment
   ├─ Current functionality (755 lines)
   └─ User confirmed: "Only workflow that consistently works"

4. RELEASE.yml (KEEP & ENHANCE)
   ├─ Trigger: push tags (v*), workflow_dispatch
   ├─ Current comprehensive release process
   └─ Could add playbook call for some steps

SUPPORTING WORKFLOWS (Keep as-is):
- 03-test-execution.yml (reusable test workflow)
- 09-jekyll-gh-pages.yml (Pages deployment)
- test-dashboard-generation.yml (manual testing)
```

---

## LOCAL EXECUTION EQUIVALENCE

### The Golden Rule

**Everything that runs in GitHub Actions must be runnable locally with the exact same commands.**

### PR Validation - Local vs. CI

**Developer runs locally:**
```powershell
# 1. Bootstrap environment (if needed)
./bootstrap.ps1 -Mode New -InstallProfile Minimal

# 2. Load module
Import-Module ./AitherZero.psd1 -Force

# 3. Run PR validation playbook
$env:PR_NUMBER = "1234"  # Simulate PR
$env:GITHUB_BASE_REF = "main"
$env:GITHUB_HEAD_REF = "feature-branch"

Invoke-AitherPlaybook -Name pr-ecosystem-complete -PassThru

# 4. Check results
Get-ChildItem library/reports/
Get-ChildItem library/tests/results/
```

**CI runs (IDENTICAL):**
```yaml
- name: Bootstrap
  run: ./bootstrap.ps1 -Mode New -InstallProfile Minimal

- name: Run Validation
  env:
    PR_NUMBER: ${{ github.event.pull_request.number }}
    GITHUB_BASE_REF: ${{ github.base_ref }}
    GITHUB_HEAD_REF: ${{ github.head_ref }}
  run: |
    Import-Module ./AitherZero.psd1 -Force
    Invoke-AitherPlaybook -Name pr-ecosystem-complete -PassThru
```

**Result:** Developer sees exact same output, same artifacts, same behavior.

### Branch Deployment - Local vs. CI

**Developer runs locally:**
```powershell
# 1. Bootstrap
./bootstrap.ps1 -Mode New -InstallProfile Minimal

# 2. Run tests (simulate CI test phase)
Import-Module ./AitherZero.psd1 -Force
Invoke-AitherPlaybook -Name comprehensive-validation -PassThru

# 3. Generate dashboard (simulate CI dashboard phase)
Invoke-AitherPlaybook -Name dashboard-generation-complete -PassThru

# 4. Check output
Get-ChildItem library/reports/dashboard/
```

**CI runs (IDENTICAL):**
```yaml
- name: Test
  run: |
    Import-Module ./AitherZero.psd1 -Force
    Invoke-AitherPlaybook -Name comprehensive-validation -PassThru

- name: Dashboard
  run: |
    Import-Module ./AitherZero.psd1 -Force
    Invoke-AitherPlaybook -Name dashboard-generation-complete -PassThru
```

### What Workflows Can Do (GitHub Actions Specific)

Workflows should ONLY handle things that can't be done locally:

1. **Artifact Upload** - `actions/upload-artifact@v4`
   - Stores results for later jobs
   - Developer equivalent: Files already on disk

2. **PR Comments** - `actions/github-script@v7`
   - Posts playbook-generated markdown
   - Developer equivalent: Read `library/reports/pr-comment.md`

3. **Pages Deployment** - `actions/deploy-pages@v4`
   - Publishes to GitHub Pages
   - Developer equivalent: Preview `library/reports/` locally

4. **Docker Push** - `docker/build-push-action@v5`
   - Pushes to registry
   - Developer equivalent: `docker build` locally (no push)

### Anti-Patterns to Avoid

❌ **DON'T DO THIS:**
```yaml
- name: Run Validation
  run: |
    # Workflow-specific logic
    if [[ "${{ github.event_name }}" == "pull_request" ]]; then
      ./script1.ps1
      ./script2.ps1
      if [ $? -eq 0 ]; then
        ./script3.ps1
      fi
    fi
```

✅ **DO THIS:**
```yaml
- name: Run Validation
  run: |
    # Just call playbook - all logic is in the playbook
    Import-Module ./AitherZero.psd1 -Force
    Invoke-AitherPlaybook -Name pr-ecosystem-complete
```

### Verification Commands

**Test that workflows match local execution:**

```powershell
# Simulate PR validation locally
$env:CI = "true"
$env:AITHERZERO_CI = "true"
$env:PR_NUMBER = "9999"
./bootstrap.ps1 -Mode New -InstallProfile Minimal
Import-Module ./AitherZero.psd1 -Force
Invoke-AitherPlaybook -Name pr-ecosystem-complete -PassThru

# Compare artifacts to what CI produces
Compare-Object (Get-ChildItem library/reports/) (Get-ChildItem $CIArtifacts)
```

---

## DETAILED IMPLEMENTATION PLAN

### Phase 1: Backup & Preparation (30 minutes)

**Step 1.1: Create Backup Directory**
```bash
mkdir -p .github/workflows-archive
cp .github/workflows/*.yml .github/workflows-archive/
git add .github/workflows-archive/
git commit -m "Archive current workflow files before rebuild"
```

**Step 1.2: Document Current State**
```bash
# Create manifest of current workflows
ls -lh .github/workflows/*.yml > .github/workflows-archive/MANIFEST.txt
git log --oneline .github/workflows/ | head -20 >> .github/workflows-archive/MANIFEST.txt
```

**Step 1.3: Verify Playbooks**
- Confirm pr-ecosystem-complete.psd1 exists and is current
- Confirm dashboard-generation-complete.psd1 exists
- Test locally: `Invoke-AitherPlaybook -Name pr-ecosystem-complete -DryRun`

### Phase 2: Create PR-VALIDATION.yml (NEW)

**Replace:** pr-check.yml (434 lines → ~150 lines)

**New File:** `.github/workflows/pr-validation.yml`

```yaml
---
name: ✅ PR Validation

on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
    branches: [main, dev, develop, dev-staging, ring-*]

permissions:
  contents: read
  pull-requests: write
  checks: write

concurrency:
  group: pr-validation-${{ github.event.pull_request.number }}
  cancel-in-progress: true

env:
  AITHERZERO_CI: true
  AITHERZERO_NONINTERACTIVE: true
  AITHERZERO_SUPPRESS_BANNER: true

jobs:
  # ================================================================
  # VALIDATE: Run complete PR ecosystem playbook
  # ================================================================
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
          GITHUB_REPOSITORY: ${{ github.repository }}
          GITHUB_SHA: ${{ github.sha }}
        run: |
          Import-Module ./AitherZero.psd1 -Force
          
          # Call the master PR playbook
          # This handles: Build → Analyze → Report
          $result = Invoke-AitherPlaybook -Name pr-ecosystem-complete -PassThru
          
          if ($result -and $result.FailedCount -gt 0) {
            Write-Error "PR validation failed with $($result.FailedCount) failures"
            exit 1
          }
      
      - name: 📊 Upload Artifacts
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
              console.log('No PR comment generated by playbook');
              return;
            }
            
            let body = fs.readFileSync(commentPath, 'utf8');
            const marker = '<!-- AITHERZERO_PR_VALIDATION -->';
            body += '\n' + marker;
            
            const { data: comments } = await github.rest.issues.listComments({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number
            });
            
            const existing = comments.find(c => 
              c.user.login === 'github-actions[bot]' && 
              c.body.includes(marker)
            );
            
            if (existing) {
              await github.rest.issues.updateComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                comment_id: existing.id,
                body: body
              });
            } else {
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.issue.number,
                body: body
              });
            }
```

**Key Changes:**
- Single job instead of 5
- Calls playbook for all orchestration
- Playbook generates PR comment
- Workflow just posts it
- 66% code reduction (434 → ~150 lines)

### Phase 3: Create BRANCH-DEPLOYMENT.yml (NEW)

**Replace:** deploy.yml (223 lines → ~300 lines with complete pipeline)

**New File:** `.github/workflows/branch-deployment.yml`

```yaml
---
name: 🚀 Branch Deployment

on:
  push:
    branches: [main, dev, develop, dev-staging, ring-*]

permissions:
  contents: write
  packages: write
  pages: write
  id-token: write

concurrency:
  group: deploy-${{ github.ref }}
  cancel-in-progress: true

env:
  AITHERZERO_CI: true
  AITHERZERO_NONINTERACTIVE: true
  AITHERZERO_SUPPRESS_BANNER: true

jobs:
  # ================================================================
  # PHASE 1: Test (Reuse existing test workflow)
  # ================================================================
  test:
    name: 🧪 Test Suite
    uses: ./.github/workflows/03-test-execution.yml
    with:
      test_suite: 'all'
      coverage: true
    secrets: inherit
  
  # ================================================================
  # PHASE 2: Build Docker Image
  # ================================================================
  build-docker:
    name: 🐳 Build & Push Docker
    needs: test
    runs-on: ubuntu-latest
    timeout-minutes: 30
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
    
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Set Repository Name
        id: repo
        run: echo "name=$(echo ${{ github.repository }} | tr '[:upper:]' '[:lower:]')" >> $GITHUB_OUTPUT
      
      - name: Extract Metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ steps.repo.outputs.name }}
          tags: |
            type=ref,event=branch
            type=sha,prefix=sha-
      
      - name: Build and Push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
  
  # ================================================================
  # PHASE 3: Generate Dashboard
  # ================================================================
  generate-dashboard:
    name: 📊 Generate Dashboard
    needs: test
    runs-on: ubuntu-latest
    timeout-minutes: 15
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Bootstrap
        shell: pwsh
        run: ./bootstrap.ps1 -Mode New -InstallProfile Minimal
      
      - name: Download Test Artifacts
        uses: actions/download-artifact@v4
        with:
          pattern: '*-tests-artifacts'
          path: ./artifacts
          merge-multiple: true
      
      - name: Download Coverage
        uses: actions/download-artifact@v4
        with:
          name: coverage-report
          path: ./artifacts/coverage-report
      
      - name: Organize Artifacts
        shell: pwsh
        run: |
          New-Item -ItemType Directory -Force -Path library/tests/results
          New-Item -ItemType Directory -Force -Path library/tests/coverage
          
          Get-ChildItem ./artifacts -Recurse -Filter "*.xml" | 
            Copy-Item -Destination library/tests/results/ -Force
          
          if (Test-Path ./artifacts/coverage-report) {
            Get-ChildItem ./artifacts/coverage-report -Recurse | 
              Copy-Item -Destination library/tests/coverage/ -Recurse -Force
          }
      
      - name: Generate Dashboard
        shell: pwsh
        run: |
          Import-Module ./AitherZero.psd1 -Force
          Invoke-AitherPlaybook -Name dashboard-generation-complete -PassThru
      
      - name: Upload Dashboard
        uses: actions/upload-artifact@v4
        with:
          name: dashboard-reports
          path: library/reports/**
  
  # ================================================================
  # PHASE 4: Deploy to GitHub Pages
  # ================================================================
  deploy-pages:
    name: 📄 Deploy Pages
    needs: generate-dashboard
    uses: ./.github/workflows/09-jekyll-gh-pages.yml
    with:
      triggered_by: 'branch-deployment'
    secrets: inherit
  
  # ================================================================
  # PHASE 5: Summary
  # ================================================================
  summary:
    name: 📋 Summary
    needs: [test, build-docker, deploy-pages]
    if: always()
    runs-on: ubuntu-latest
    
    steps:
      - name: Generate Summary
        run: |
          echo "## 🚀 Deployment Summary" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Branch:** \`${{ github.ref_name }}\`" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "| Phase | Status |" >> $GITHUB_STEP_SUMMARY
          echo "|-------|--------|" >> $GITHUB_STEP_SUMMARY
          echo "| 🧪 Tests | ${{ needs.test.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| 🐳 Docker | ${{ needs.build-docker.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| 📄 Pages | ${{ needs.deploy-pages.result }} |" >> $GITHUB_STEP_SUMMARY
```

**Key Changes:**
- Explicit job dependencies with `needs:`
- Calls 03-test-execution.yml via `uses:`
- Calls 09-jekyll-gh-pages.yml via `uses:`
- No workflow_run triggers (reliable!)
- Clear sequential pipeline
- All phases completed

### Phase 4: Remove Redundant Workflows

**Delete These Files:**
1. ❌ `pr-check.yml` → Replaced by pr-validation.yml
2. ❌ `deploy.yml` → Replaced by branch-deployment.yml
3. ❌ `05-publish-reports-dashboard.yml` → Integrated into branch-deployment.yml

**Keep These Files:**
1. ✅ `03-test-execution.yml` - Reusable test workflow
2. ✅ `04-deploy-pr-environment.yml` - User confirmed working
3. ✅ `09-jekyll-gh-pages.yml` - Pages deployment
4. ✅ `release.yml` - Release process
5. ✅ `test-dashboard-generation.yml` - Manual testing

### Phase 5: Update Playbooks (if needed)

**Check pr-ecosystem-complete.psd1:**
- Ensure it generates `library/reports/pr-comment.md`
- Verify all 3 phases work correctly

**Check dashboard-generation-complete.psd1:**
- Ensure it handles missing artifacts gracefully
- Verify dashboard generation completes

**If playbooks need updates, create new versions:**
- Don't modify existing playbooks mid-migration
- Create v2.1 versions if needed
- Test locally before deploying

---

## FINAL WORKFLOW COUNT

### Before: 8 Workflows, 4,490 lines
1. 03-test-execution.yml (774)
2. 04-deploy-pr-environment.yml (755)
3. 05-publish-reports-dashboard.yml (708)
4. 09-jekyll-gh-pages.yml (433)
5. pr-check.yml (434)
6. deploy.yml (223)
7. release.yml (805)
8. test-dashboard-generation.yml (358)

### After: 6 Workflows, ~3,200 lines
1. 03-test-execution.yml (774) - KEEP
2. 04-deploy-pr-environment.yml (755) - KEEP
3. 09-jekyll-gh-pages.yml (433) - KEEP
4. pr-validation.yml (150) - NEW (replaces pr-check.yml)
5. branch-deployment.yml (300) - NEW (replaces deploy.yml + 05-publish)
6. release.yml (805) - KEEP
7. test-dashboard-generation.yml (358) - KEEP (optional)

**Reduction:** ~30% less code, 100% more reliable

---

## RISK MITIGATION

### Backup Strategy
- All current workflows archived in `.github/workflows-archive/`
- Git commit before any changes
- Can revert entire directory if needed

### Testing Strategy
1. Test new workflows on feature branch first
2. Run multiple times to verify reliability
3. Compare output to current workflows
4. Verify all artifacts collected
5. Verify Pages deployment works

### Rollback Plan
```bash
# If new workflows fail
git checkout HEAD~1 -- .github/workflows/pr-validation.yml
git checkout HEAD~1 -- .github/workflows/branch-deployment.yml
git restore .github/workflows/pr-check.yml
git restore .github/workflows/deploy.yml
git restore .github/workflows/05-publish-reports-dashboard.yml
```

---

## SUCCESS CRITERIA

### Functional Requirements
- [ ] PRs validate with single playbook call
- [ ] PR comments generated and posted
- [ ] Branch pushes run full pipeline (test → build → dashboard → pages)
- [ ] All test artifacts collected
- [ ] Coverage reports generated
- [ ] Dashboard published to Pages
- [ ] Docker images built and pushed
- [ ] Releases still work

### Performance Requirements
- [ ] PR validation: < 45 minutes
- [ ] Branch deployment: < 40 minutes
- [ ] No workflow_run failures
- [ ] All phases complete successfully

### Code Quality
- [ ] Workflow code reduced by 30%
- [ ] All logic in playbooks (testable locally)
- [ ] Clear job dependencies
- [ ] No duplicated functionality

---

## NEXT STEPS

1. **Review this plan** - Verify it matches requirements
2. **Create backup** - Archive current workflows
3. **Test playbooks locally** - Ensure they work
4. **Implement pr-validation.yml** - Replace pr-check.yml
5. **Implement branch-deployment.yml** - Replace deploy.yml + 05-publish
6. **Delete redundant workflows** - Remove old files
7. **Test on feature branch** - Multiple runs
8. **Monitor production** - First few runs after merge

---

## CONCLUSION

This plan is based on comprehensive analysis of:
- **4,490 lines** of workflow YAML
- **20+ playbooks** with real orchestration logic
- **175 automation scripts** across 10 ranges
- **User feedback** on what actually works

**Key Insight:** The playbooks already exist and work! The workflows just need to call them instead of reimplementing the orchestration logic.

**Recommendation:** Proceed with implementation following this plan.
