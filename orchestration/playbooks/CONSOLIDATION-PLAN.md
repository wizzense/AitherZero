# Playbook Consolidation Plan

**Date**: 2025-11-02  
**Status**: Proposed  
**Current Count**: 42 playbooks  
**Target Count**: ~20 core playbooks

## Executive Summary

After comprehensive analysis of 42 playbooks and 125 automation scripts, this plan consolidates overlapping playbooks into focused, well-defined core playbooks aligned with the number-based automation script system.

## Current State Analysis

### Playbook Distribution
- **Testing**: 11 playbooks (high duplication)
- **Git Workflows**: 7 playbooks (AI/standard mix)
- **AI Workflows**: 5 playbooks (specialized)
- **Setup**: 4 playbooks (well-organized)
- **Analysis**: 4 playbooks (good coverage)
- **Ops**: 5 playbooks (mixed purposes)
- **Infrastructure**: 1 playbook (good)
- **Others**: 5 playbooks (various)

### Schema Versions
- **v1.0**: 29 playbooks (older format)
- **v2.0**: 13 playbooks (modern format with metadata)

### Usage Analysis
- All 42 playbooks are referenced in codebase
- **test-quick**: 14 references (most used)
- **test-full**: 11 references
- **test-ci**: 7 references
- Several playbooks have overlapping functionality

## Consolidation Strategy

### Phase 1: Core Testing Playbooks (11 → 5)

#### Keep As-Is
1. **test-quick** (14 refs) - Fast development validation
   - 5-10 minutes
   - Unit tests + static analysis
   - Status: Keep, standardize to v2.0

2. **test-full** (11 refs) - Complete validation
   - 30-45 minutes  
   - Unit, integration, analysis, coverage
   - Status: Keep, standardize to v2.0

3. **test-ci** (7 refs) - CI/CD optimized
   - 15-20 minutes
   - Parallel execution, fail-fast
   - Status: Keep, enhance for GitHub Actions

4. **workflow-validation** (2 refs) - Workflow testing
   - 10-15 minutes
   - GitHub Actions local testing
   - Status: Keep, specific use case

#### Create New
5. **test-standard** (NEW) - Pre-commit validation
   - 15-20 minutes
   - Unit + Integration + Analysis (no coverage)
   - Consolidates: test-comprehensive, test-validation

#### Archive/Remove
- **test-simple** → Merge features into test-quick
- **test-lightning** → Merge into test-quick  
- **test-comprehensive** → Becomes test-standard
- **comprehensive-validation** → Merge into test-full
- **test-validation** → Merge fixes into test-standard
- **test-phase1-validation** → Archive (legacy)
- **test-phase1-production** → Archive (legacy)

### Phase 2: Git Workflow Playbooks (7 → 3)

#### Keep/Consolidate
1. **git-feature** (NEW) - Complete feature workflow
   - Branch creation → Validation → Commit → Push → PR
   - AI-generated commit messages and PR descriptions
   - Consolidates: claude-feature-workflow, ai-complete-workflow

2. **git-commit** (NEW) - Simple commit workflow  
   - Stage → Validate → Commit
   - AI commit message generation
   - Consolidates: claude-commit-workflow, git-workflow

3. **git-standard** (KEEP) - Generic flexible workflow
   - Supports multiple commit types
   - Flexible staging patterns
   - Keep: git-standard-workflow

#### Remove
- **ai-git-workflow** → Merge into git-feature
- **ai-complete-workflow** → Merge into git-feature
- **claude-commit-workflow** → Merge into git-commit
- **claude-feature-workflow** → Merge into git-feature
- **claude-development-workflow** → Split into git-feature + setup playbooks

### Phase 3: Setup Playbooks (4 → 4)

**No changes needed** - Well-organized with clear purposes:

1. **minimal-setup** - Core dependencies only (CI/quick start)
2. **dev-environment** - Standard developer workstation
3. **full-development** - Power user with all tools
4. **ai-development** - AI-enhanced development environment

### Phase 4: Infrastructure Playbooks (1 → 3)

#### Current
1. **hyperv-lab-setup** - Complete Hyper-V lab

#### Add
2. **infrastructure-minimal** (NEW) - Basic infrastructure only
   - System configuration
   - No virtualization
   - Scripts: 0100

3. **infrastructure-wsl** (NEW) - WSL2 development environment
   - WSL2 + Docker
   - Development focused
   - Scripts: 0106, 0208

### Phase 5: Analysis Playbooks (4 → 4)

**Keep all** - Each serves distinct purpose:

1. **automated-security-review** - Security scanning
2. **claude-code-review** - AI code review
3. **tech-debt-analysis** - Technical debt analysis
4. **reporting-automation** - Comprehensive reporting

### Phase 6: Operations Playbooks (5 → 3)

#### Consolidate
1. **ci-pipeline** (NEW) - Standard CI/CD pipeline
   - Consolidates: github-cicd, intelligent-ci-cd

2. **deployment** (NEW) - Infrastructure deployment  
   - Consolidates: ai-assisted-deployment

3. **session-management** (KEEP) - Work session management

#### Remove
- **automated-issue-creation** → Merge into ci-pipeline as optional stage

### Phase 7: AI Workflow Playbooks (5 → 3)

**Specialized AI tools** - Consolidate overlapping ones:

1. **ai-agent-personas** (KEEP) - Custom agent personas
2. **ai-orchestration** (NEW) - Multi-agent orchestration
   - Consolidates: claude-multi-agent-orchestration, claude-sub-agent-delegation
3. **ai-commands** (KEEP) - Custom CLI commands

#### Remove
- **claude-intelligent-automation** → Merge into ai-orchestration

### Phase 8: Additional Core Playbooks

#### New Based on Script Categories

1. **devtools-minimal** (NEW) - Essential dev tools
   - Git, Node, Python, Docker
   - Scripts: 0201, 0206, 0207, 0208

2. **devtools-full** (NEW) - All development tools
   - All 0200-0299 scripts
   - VS Code, build tools, cloud CLI

3. **reporting-dashboard** (NEW) - Dashboard generation
   - Project metrics and health
   - Scripts: 0510-0515

4. **maintenance** (NEW) - System maintenance
   - Cleanup and optimization
   - Scripts: 0000, 9999

## Final Core Playbook Structure

```
orchestration/playbooks/
├── core/                          # Primary playbooks (NEW organization)
│   ├── setup/
│   │   ├── minimal-setup.json
│   │   ├── dev-environment.json
│   │   ├── full-development.json
│   │   └── ai-development.json
│   ├── testing/
│   │   ├── test-quick.json        # Fast iteration
│   │   ├── test-standard.json     # Pre-commit (NEW)
│   │   ├── test-full.json         # Complete validation
│   │   ├── test-ci.json           # CI/CD optimized
│   │   └── workflow-validation.json
│   ├── git/
│   │   ├── git-feature.json       # Feature workflow (NEW)
│   │   ├── git-commit.json        # Simple commit (NEW)
│   │   └── git-standard.json      # Flexible workflow
│   ├── infrastructure/
│   │   ├── infrastructure-minimal.json (NEW)
│   │   ├── infrastructure-wsl.json (NEW)
│   │   └── hyperv-lab-setup.json
│   ├── devtools/
│   │   ├── devtools-minimal.json  (NEW)
│   │   └── devtools-full.json     (NEW)
│   ├── operations/
│   │   ├── ci-pipeline.json       (NEW)
│   │   ├── deployment.json        (NEW)
│   │   └── session-management.json
│   ├── analysis/
│   │   ├── automated-security-review.json
│   │   ├── claude-code-review.json
│   │   ├── tech-debt-analysis.json
│   │   └── reporting-automation.json
│   └── ai/
│       ├── ai-agent-personas.json
│       ├── ai-orchestration.json  (NEW)
│       └── ai-commands.json
└── archive/                       # Deprecated playbooks
    ├── legacy/
    └── phase-specific/
```

## Migration Path

### Step 1: Create New Playbooks
- test-standard
- git-feature
- git-commit
- infrastructure-minimal
- infrastructure-wsl
- devtools-minimal
- devtools-full
- ci-pipeline
- deployment
- reporting-dashboard
- ai-orchestration
- maintenance

### Step 2: Standardize Existing to v2.0
- test-quick
- test-full
- test-ci
- All setup playbooks
- All analysis playbooks

### Step 3: Update Documentation
- Update all references in docs/
- Update .claude/ AI hooks
- Update automation scripts
- Update Start-AitherZero.ps1 tab completion

### Step 4: Archive Old Playbooks
- Move deprecated playbooks to archive/
- Keep for 1 release cycle
- Add deprecation notices

### Step 5: Test Migration
- Validate all new playbooks
- Ensure backward compatibility
- Update CI/CD workflows

## Success Metrics

- **Playbook Count**: 42 → ~23 core playbooks (45% reduction)
- **Schema Consistency**: 100% v2.0 format
- **Documentation**: Complete coverage
- **Usage Clarity**: Clear purpose for each playbook
- **Duplication**: Eliminated overlapping functionality

## Timeline

- **Week 1**: Create new playbooks, standardize existing
- **Week 2**: Update documentation and references  
- **Week 3**: Testing and validation
- **Week 4**: Archive deprecated, finalize migration

## Backward Compatibility

Deprecated playbooks will:
1. Display warning message when used
2. Redirect to new equivalent playbook
3. Log deprecation notice
4. Be removed after 1 release cycle

## Next Steps

1. Review and approve this plan
2. Create new playbook templates
3. Begin migration implementation
4. Update documentation
5. Communicate changes to users
