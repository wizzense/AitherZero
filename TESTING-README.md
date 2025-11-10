# Testing Infrastructure v2.0

## Quick Start

```bash
# Run tests
aitherzero orchestrate test-orchestrated --profile quick  # 5min
aitherzero orchestrate test-orchestrated                  # 10min (default)

# View results
open reports/dashboard.html

# Regenerate tests
./library/automation-scripts/0950_Generate-AllTests.ps1 -Mode Full -Force
```

## What Changed

### Before

- 8+ orchestration scripts (confusing)
- Results scattered in 3+ locations
- Tests only checked "file exists" (useless)

### After

- **ONE** playbook: `test-orchestrated.json`
- **ONE** dashboard: `reports/dashboard.html`
- **Functional** tests: validate actual behavior

## Test Profiles

- `quick` (5min): Unit + Syntax
- `standard` (10min): + Integration + Quality
- `full` (20min): + Security + Everything
- `ci` (10min): Optimized for GitHub Actions

## Architecture

```
aitherzero orchestrate test-orchestrated
  ↓
Playbook orchestrates existing scripts:
  ├─ 0400 Install Tools
  ├─ 0402 Unit Tests
  ├─ 0403 Integration Tests
  ├─ 0404 PSScriptAnalyzer
  ├─ 0407 Syntax Validation
  ├─ 0420 Quality Checks
  └─ Post-Actions:
       ├─ 0510 Project Report
       └─ 0512 Dashboard Generation
  ↓
reports/dashboard.html (all data in ONE place)
```

## Test Generation

The `FunctionalTestGenerator` creates tests with:

- **📋 Structural**: File, syntax, parameters
- **⚙️ Functional**: WhatIf execution, outputs, exit codes
- **🚨 Error Handling**: Invalid inputs, edge cases
- **🎭 Mocked Dependencies**: External calls

### Example

```powershell
# OLD (structural only)
It 'Script file should exist' {
    Test-Path $script:ScriptPath | Should -Be $true
}

# NEW (functional)
Context '⚙️ Functional Validation' {
    It 'Executes in WhatIf mode without errors' {
        { & $script:ScriptPath -WhatIf } | Should -Not -Throw
    }
}

Context '🎭 Mocked Dependencies' {
    It 'Calls Invoke-Pester correctly' {
        Mock Invoke-Pester { } -Verifiable
        Should -InvokeVerifiable
    }
}
```

## Files

### Core

- `aithercore/orchestration/playbooks/testing/test-orchestrated.json` - Main playbook
- `.github/workflows/unified-testing.yml` - CI/CD workflow
- `aithercore/testing/AutoTestGenerator.psm1` - Test generator
- `library/automation-scripts/0950_Generate-AllTests.ps1` - Batch regeneration

### Deprecated (Don't Use)

- `library/automation-scripts/0460_Orchestrate-Tests.ps1` → Use playbook
- `library/automation-scripts/0470_Orchestrate-SimpleTesting.ps1` → Use playbook
- `library/automation-scripts/0480_Test-Simple.ps1` → Use playbook
- `library/automation-scripts/0490_AI-TestRunner.ps1` → Use playbook

## Metrics

| Metric | Before | After |
|--------|--------|-------|
| Entry Points | 8+ scripts | 1 playbook |
| Result Locations | 3+ dirs | 1 dashboard |
| Code Duplication | ~30% | 0% |
| Test Quality | Structural only | + Functional + Error + Mock |

## CI/CD

The `unified-testing.yml` workflow:

1. Runs playbook on push/PR
2. Generates dashboard
3. Publishes to GitHub Pages
4. Comments on PR with summary

## Troubleshooting

**Tests fail?**

- Check `reports/dashboard.html` for prioritized issues
- Review logs: `logs/transcript-*.log`

**Want to customize?**

- Edit `aithercore/orchestration/playbooks/testing/test-orchestrated.json`
- Add/remove stages
- Adjust timeouts
- Create custom profiles

## Migration

| Old Command | New Command |
|-------------|-------------|
| `./library/library/automation-scripts/0409_Run-AllTests.ps1` | `aitherzero orchestrate test-orchestrated --profile full` |
| `./library/library/automation-scripts/0480_Test-Simple.ps1` | `aitherzero orchestrate test-orchestrated --profile quick` |
| Multiple result files | One dashboard: `reports/dashboard.html` |

---

**Version:** 2.0
**Status:** Production Ready
**Documentation:** This file replaces 6 previous guides
