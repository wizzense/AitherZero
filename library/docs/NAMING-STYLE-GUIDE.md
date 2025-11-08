# AitherZero Naming & Organization Style Guide

## Overview

This guide establishes consistent naming conventions across the AitherZero project to enable "at-a-glance" understanding of components, their purpose, and their relationships.

**Core Principle**: File names should form a "breadcrumb trail" that tells you:
1. **What** it is (type)
2. **Where** it belongs (category/domain)
3. **What** it does (action/purpose)
4. **When/How** it's used (context)

---

## Automation Scripts

### Format
```
NNNN_Verb-NounContext.ps1
```

### Rules
1. **Number (NNNN)**: 4-digit range-based organization
2. **Verb**: Approved PowerShell verb (Get, Set, Invoke, Install, etc.)
3. **Noun**: Clear, singular noun describing the target
4. **Context** (optional): Additional specificity when needed

### Number Ranges
- `0000-0099`: Environment & Setup
- `0100-0199`: Infrastructure (Hyper-V, Network, Certificates)
- `0200-0299`: Development Tools (Git, Docker, VS Code)
- `0400-0499`: Testing & Validation
- `0500-0599`: Reporting & Metrics
- `0700-0799`: Git Automation & AI Tools
- `0800-0899`: Issue Management
- `0900-0999`: Validation & Verification
- `9000-9999`: Maintenance & Cleanup

### Examples
```powershell
✅ GOOD
0402_Run-UnitTests.ps1              # Clear: runs unit tests
0404_Run-PSScriptAnalyzer.ps1       # Clear: runs static analysis
0180_Download-OSISOs.ps1            # Clear: downloads OS ISOs
0962_Run-Playbook.ps1               # Clear: executes playbooks

❌ BAD
0402_Tests.ps1                      # Unclear: what kind? what action?
0404_Analyzer.ps1                   # Unclear: analyze what?
0180_ISOs.ps1                       # Unclear: what happens to ISOs?
0962_Playbook.ps1                   # Unclear: create? run? validate?
```

---

## PowerShell Modules

### Format
```
Category/DomainName.psm1
```

### Rules
1. **Category**: Primary functional area (domains/, tests/, tools/)
2. **DomainName**: PascalCase, descriptive of module purpose
3. **Avoid generic names**: Be specific about what the module manages

### Directory Structure
```
domains/
├── configuration/
│   └── Configuration.psm1          # ✅ Config management
├── infrastructure/
│   ├── Infrastructure.psm1         # ✅ Infrastructure automation
│   ├── ISOManager.psm1             # ✅ ISO operations
│   └── ISOCustomizer.psm1          # ✅ ISO customization
├── utilities/
│   ├── Logging.psm1                # ✅ Logging functionality
│   └── DownloadUtility.psm1        # ✅ File download operations
├── experience/
│   ├── UserInterface.psm1          # ✅ UI components
│   └── InteractiveUI.psm1          # ✅ Interactive menus
└── testing/
    ├── TestingFramework.psm1       # ✅ Test orchestration
    └── QualityValidator.psm1       # ✅ Quality checks
```

### Examples
```powershell
✅ GOOD
Configuration.psm1                  # Manages configuration
ISOManager.psm1                     # Manages ISO files
DownloadUtility.psm1                # Download utilities
OrchestrationEngine.psm1            # Orchestrates automation

❌ BAD
Config.psm1                         # Too abbreviated
ISO.psm1                            # Too generic
Utils.psm1                          # What kind of utilities?
Engine.psm1                         # Engine for what?
```

---

## Orchestration Playbooks

### Format
```
category/action-target-profile.json
```

### Rules
1. **Category**: Group by purpose (testing/, validation/, deployment/, operations/)
2. **Action**: What it does (run, validate, deploy, build)
3. **Target**: What it operates on (tests, workflows, infrastructure)
4. **Profile** (optional): Variant or scope (quick, full, pr)

### Directory Structure
```
domains/orchestration/playbooks/
├── testing/
│   ├── run-tests-quick.json                    # ✅ Quick test run
│   ├── run-tests-comprehensive.json            # ✅ Full test suite
│   └── run-tests-pr-validation.json            # ✅ PR-specific tests
├── validation/
│   ├── validate-syntax-all.json                # ✅ Full syntax check
│   ├── validate-config-manifest.json           # ✅ Config validation
│   ├── validate-module-manifests.json          # ✅ Module validation
│   └── validate-test-coverage.json             # ✅ Test sync check
├── operations/
│   ├── generate-documentation-full.json        # ✅ Full docs generation
│   ├── generate-test-reports.json              # ✅ Test reporting
│   └── update-index-files.json                 # ✅ Index automation
├── ci-cd/
│   ├── pr-validation-workflow.json             # ✅ PR validation
│   ├── quality-check-workflow.json             # ✅ Quality checks
│   └── release-workflow.json                   # ✅ Release process
└── meta/
    ├── run-all-validations-quick.json          # ✅ Meta: all validations
    └── run-all-validations-comprehensive.json  # ✅ Meta: complete suite
```

### Examples
```json
✅ GOOD - Clear breadcrumb trail
testing/run-tests-quick.json
  │       │    │     │
  │       │    │     └─ Profile: quick variant
  │       │    └─────── Target: tests
  │       └──────────── Action: run
  └──────────────────── Category: testing

validation/validate-config-manifest.json
  │          │        │      │
  │          │        │      └─ Specific: manifest file
  │          │        └─────── Target: config
  │          └──────────────── Action: validate
  └─────────────────────────── Category: validation

❌ BAD - Unclear purpose
test-orchestrated.json              # What's being tested? What profile?
ci-all-validations.json             # All what? For CI specifically?
ci-comprehensive-test.json          # Comprehensive what test?
documentation-tracking.json         # Tracking or generating docs?
```

### Naming Pattern Examples

#### Testing Playbooks
```
testing/run-tests-quick.json                    # Quick validation run
testing/run-tests-standard.json                 # Standard test suite
testing/run-tests-comprehensive.json            # Full test suite with reports
testing/run-tests-security-only.json            # Security tests only
testing/run-tests-pr-validation.json            # PR-specific test subset
```

#### Validation Playbooks
```
validation/validate-syntax-all.json             # All PowerShell files
validation/validate-syntax-changed.json         # Only changed files
validation/validate-config-manifest.json        # config.psd1 validation
validation/validate-module-manifests.json       # .psd1 module files
validation/validate-test-coverage.json          # Test/script sync
validation/validate-workflows-yaml.json         # GitHub Actions YAML
```

#### Operations Playbooks
```
operations/generate-documentation-full.json     # Complete doc generation
operations/generate-documentation-modules.json  # Module docs only
operations/generate-test-reports-pr.json        # PR test reports
operations/generate-test-reports-release.json   # Release reports
operations/update-index-files-all.json          # All index.md files
operations/update-index-files-changed.json      # Modified dirs only
```

#### CI/CD Playbooks
```
ci-cd/pr-validation-workflow.json               # PR validation workflow
ci-cd/pr-validation-fork.json                   # Fork PR (limited)
ci-cd/quality-check-workflow.json               # Quality validation
ci-cd/release-workflow.json                     # Release automation
ci-cd/deploy-pr-environment.json                # PR environment deploy
```

---

## Configuration Files

### Format
```
config-context.ext
```

### Rules
1. **Base config**: `config.psd1` (main configuration)
2. **Local overrides**: `config.local.psd1` (gitignored)
3. **Examples**: `config.example.psd1` (template)
4. **Environment-specific**: `config-production.psd1`, `config-development.psd1`

### Examples
```powershell
✅ GOOD
config.psd1                         # Main configuration
config.local.psd1                   # Local overrides (gitignored)
config.example.psd1                 # Example template
config-production.psd1              # Production settings
config-ci.psd1                      # CI environment settings

❌ BAD
settings.psd1                       # Use 'config' consistently
my-config.psd1                      # Personal prefixes
config_local.psd1                   # Use dash, not underscore
```

---

## Test Files

### Format
```
category/Target.Tests.ps1
```

### Rules
1. **Category**: Match source structure (domains/, unit/, integration/)
2. **Target**: Name of module/script being tested
3. **Suffix**: Always `.Tests.ps1`

### Examples
```powershell
✅ GOOD
tests/domains/configuration/Configuration.Tests.ps1
tests/unit/library/automation-scripts/0402_Run-UnitTests.Tests.ps1
tests/integration/orchestration/PlaybookExecution.Tests.ps1

❌ BAD
Configuration-Tests.ps1             # Wrong suffix format
Test-Configuration.ps1              # Verb prefix not used for tests
ConfigurationTest.ps1               # Missing .Tests suffix
```

---

## Documentation Files

### Format
```
PURPOSE-CONTEXT.md
```

### Rules
1. **README.md**: Directory overview (always lowercase)
2. **index.md**: Auto-generated file listing (always lowercase)
3. **All other docs**: UPPERCASE-WITH-DASHES.md
4. **Context**: Be specific about what's documented

### Examples
```markdown
✅ GOOD
README.md                           # Directory overview
index.md                            # Auto-generated listing
NAMING-STYLE-GUIDE.md               # This document
TESTING-OVERHAUL-COMPLETE.md        # Testing system changes
GITHUB-WORKFLOWS-MAPPING.md         # Workflow documentation
OSS-DIRECTORY-FEASIBILITY.md        # Feature investigation

❌ BAD
readme.MD                           # Wrong case
naming_guide.md                     # Use dashes, not underscores
TestingDoc.md                       # Not descriptive enough
guide.md                            # What kind of guide?
```

---

## Directory Structure

### Rules
1. **Lowercase with dashes**: `library/automation-scripts/`, `test-results/`
2. **Descriptive names**: Purpose should be obvious
3. **Consistent depth**: Avoid deeply nested structures

### Examples
```
✅ GOOD
library/automation-scripts/                 # Numbered automation scripts
domains/orchestration/playbooks/            # Playbook definitions
tests/unit/                         # Unit tests
tests/integration/                  # Integration tests
domains/configuration/              # Configuration domain
reports/metrics-history/            # Historical metrics

❌ BAD
scripts/                            # Too generic
auto/                               # Abbreviated
test/                               # Singular (use plural)
cfg/                                # Abbreviated
rpts/                               # Abbreviated
```

---

## Git Branch Naming

### Format
```
type/brief-description
```

### Types
- `feature/`: New functionality
- `fix/`: Bug fixes
- `refactor/`: Code restructuring
- `docs/`: Documentation only
- `test/`: Test additions/fixes
- `chore/`: Maintenance tasks
- `hotfix/`: Critical production fixes

### Examples
```bash
✅ GOOD
feature/add-iso-download
fix/pester-timeout-issue
refactor/playbook-naming
docs/add-style-guide
test/add-integration-tests

❌ BAD
feature/new-stuff              # Too vague
fix-bug                        # Missing type prefix
my-changes                     # Not descriptive
update                         # What's being updated?
```

---

## Quick Reference Summary

| Component | Pattern | Example |
|-----------|---------|---------|
| **Automation Script** | `NNNN_Verb-NounContext.ps1` | `0402_Run-UnitTests.ps1` |
| **Module** | `Category/DomainName.psm1` | `domains/infrastructure/ISOManager.psm1` |
| **Playbook** | `category/action-target-profile.json` | `testing/run-tests-quick.json` |
| **Config** | `config-context.ext` | `config-production.psd1` |
| **Test** | `category/Target.Tests.ps1` | `domains/Configuration.Tests.ps1` |
| **Doc** | `PURPOSE-CONTEXT.md` or `README.md` | `TESTING-OVERHAUL-COMPLETE.md` |
| **Directory** | `lowercase-with-dashes/` | `library/automation-scripts/` |
| **Branch** | `type/brief-description` | `feature/playbook-reorganization` |

---

## Validation Checklist

Before creating or renaming a component, verify:

- [ ] **Descriptive**: Name clearly indicates purpose
- [ ] **Consistent**: Follows established pattern for its type
- [ ] **Discoverable**: Can be found by logical search
- [ ] **Unambiguous**: No confusion with similar components
- [ ] **Breadcrumb**: Provides category → action → target → context
- [ ] **Standard verbs**: Uses approved PowerShell verbs for scripts
- [ ] **No abbreviations**: Spell out words (except well-known: ISO, PR, CI)

---

## Migration Strategy

When renaming existing files:

1. **Create mapping document**: Old name → New name with rationale
2. **Update all references**: Scripts, docs, workflows, configs
3. **Use git mv**: Preserve history (`git mv old-name new-name`)
4. **Deprecate gradually**: Keep old names with warnings initially
5. **Document changes**: Update all relevant documentation

---

## Benefits

Following this style guide provides:

✅ **Instant recognition**: Know what something is by its name
✅ **Easy navigation**: Logical structure matches mental models
✅ **Better maintenance**: Clear purpose reduces confusion
✅ **Onboarding**: New contributors understand structure quickly
✅ **Tooling support**: Consistent patterns enable automation
✅ **Reduced errors**: Clear naming prevents mistakes

---

**Version**: 1.0.0
**Last Updated**: 2025-11-04
**Maintained By**: AitherZero Project
