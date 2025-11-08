# Repository Structure (Clean & Organized)

## Root Files (Keep Only Essential)

### Core
- `README.md` - Main project documentation
- `LICENSE` - MIT license
- `AitherZero.psd1` - Module manifest
- `AitherZero.psm1` - Root module loader
- `bootstrap.ps1` / `bootstrap.sh` - Setup scripts
- `config.psd1` / `config.example.psd1` - Configuration
- `Start-AitherZero.ps1` - Main entry point
- `Invoke-AitherTests.ps1` - Test runner

### Documentation (Consolidated)
- `TESTING-README.md` - Testing guide (v2.0)
- `QUICK-REFERENCE.md` - Quick commands
- `DOCKER.md` - Docker setup
- `index.md` - Auto-generated index

### To Archive
- `RELEASE-REPUBLISH-GUIDE.md` → Move to docs/
- `STRATEGIC-DOCS-README.md` → Move to docs/
- `STRATEGIC-ROADMAP.md` → Move to docs/
- `VISUAL-GUIDE.md` → Move to docs/
- `WORK_COMPLETED.md` → Move to docs/archived/

## Directory Structure

```
AitherZero/
├── .github/
│   ├── workflows/          # 15 workflows (down from 24)
│   │   ├── unified-testing.yml         # PRIMARY test workflow
│   │   ├── pr-validation.yml
│   │   ├── quality-validation.yml
│   │   ├── validate-config.yml
│   │   ├── validate-manifests.yml
│   │   ├── copilot-agent-router.yml
│   │   ├── documentation-automation.yml
│   │   ├── index-automation.yml
│   │   ├── auto-generate-tests.yml
│   │   ├── auto-create-issues-from-failures.yml
│   │   ├── publish-test-reports.yml
│   │   ├── validate-test-sync.yml
│   │   ├── workflow-health-check.yml
│   │   ├── diagnose-ci-failures.yml
│   │   └── comprehensive-test-execution.yml (DEPRECATED)
│   ├── copilot.yaml
│   ├── mcp-servers.json
│   └── prompts/
├── automation-scripts/     # 125+ numbered scripts
│   ├── DEPRECATED-SCRIPTS.md
│   ├── 0400-0499/          # Testing scripts
│   ├── 0500-0599/          # Reporting scripts
│   └── 0951_Regenerate-FunctionalTests.ps1
├── domains/                # 11 functional domains
│   ├── testing/
│   │   ├── FunctionalTestGenerator.psm1  # NEW v2.0
│   │   ├── AutoTestGenerator.psm1
│   │   └── TestingFramework.psm1
│   ├── reporting/
│   │   └── ReportingEngine.psm1
│   ├── orchestration/       # Playbooks and sequences
│   │   ├── playbooks/
│   │   │   └── test-orchestrated.json  # THE ONLY ONE
│   │   └── schema/
│   │       └── playbook-schema-v3.json
│   └── ...
├── tests/                  # 316 test files
│   ├── unit/
│   ├── integration/
│   └── TestHelpers.psm1
├── docs/                   # Documentation
├── reports/                # Generated reports
└── ...
```

## What Was Cleaned

### Playbooks: 57 → 1 (98% reduction)
- Deleted 56 example/experiment/duplicate playbooks
- Kept only `test-orchestrated.json` (production-ready)

### Root MD Files: 25 → 10 (60% reduction)
- Deleted 15 experimental/outdated docs
- Kept only essential documentation

### Workflows: 24 → 15 (38% reduction)
- Deleted 10 bogus/unused workflows
- Kept 8 core + 7 supporting workflows
- Marked 1 as deprecated

## Migration Completed

All testing now goes through:
1. **Playbook:** `domains/orchestration/playbooks/test-orchestrated.json`
2. **Workflow:** `.github/workflows/unified-testing.yml`
3. **Dashboard:** `reports/dashboard.html`

---

**Status:** Repository is now clean and organized  
**Removed:** 81 files (56 playbooks + 15 docs + 10 workflows)  
**Result:** Clear structure, zero confusion
