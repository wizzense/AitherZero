# Script Numbering Reorganization Plan

## Problem

The 0800-0899 range contains two completely different categories of scripts:
- **0800-0840**: Issue management, workflow automation, context management
- **0850-0854**: PR deployment, Docker/container management

This violates the documented numbering system and creates confusion.

## Current Documented Ranges

From `.github/copilot-instructions.md`:
- **0000-0099**: Environment prep (PowerShell 7, directories)
- **0100-0199**: Infrastructure (Hyper-V, certificates, networking)  
- **0200-0299**: Dev tools (Git, Node, Python, Docker, VS Code)
- **0400-0499**: Testing & validation
- **0500-0599**: Reporting & metrics
- **0700-0799**: Git automation & AI tools
- **9000-9999**: Maintenance & cleanup

**Gap**: 0300-0399, 0600-0699, 0800-0899

## Proposed Solution

### Option A: Use Documented Ranges (RECOMMENDED)

Move scripts to their logical documented ranges:

#### Issue Management Scripts → 0700 range (Git automation & AI tools)
```
0800_Create-TestIssues.ps1           → 0750_Create-TestIssues.ps1
0801_Parse-PesterResults.ps1         → 0751_Parse-PesterResults.ps1
0805_Analyze-OpenIssues.ps1          → 0755_Analyze-OpenIssues.ps1
0810_Create-IssueFromTestFailure.ps1 → 0760_Create-IssueFromTestFailure.ps1
0815_Setup-IssueManagement.ps1       → 0765_Setup-IssueManagement.ps1
0816_Monitor-AutomationHealth.ps1    → 0766_Monitor-AutomationHealth.ps1
0820_Save-WorkContext.ps1            → 0770_Save-WorkContext.ps1
0821_Generate-ContinuationPrompt.ps1 → 0771_Generate-ContinuationPrompt.ps1
0822_Test-IssueCreation.ps1          → 0772_Test-IssueCreation.ps1
0825_Create-Issues-Manual.ps1        → 0775_Create-Issues-Manual.ps1
0830_Generate-IssueFiles.ps1         → 0780_Generate-IssueFiles.ps1
0831_Prompt-Templates.ps1            → 0781_Prompt-Templates.ps1
0832_Generate-PromptFromData.ps1     → 0782_Generate-PromptFromData.ps1
0835_Create-Issues-Now.ps1           → 0785_Create-Issues-Now.ps1
0840_Validate-WorkflowAutomation.ps1 → 0790_Validate-WorkflowAutomation.ps1
```

#### Deployment/Container Scripts → 0100 range (Infrastructure)
```
0850_Deploy-PREnvironment.ps1          → 0150_Deploy-PREnvironment.ps1
0851_Cleanup-PREnvironment.ps1         → 0151_Cleanup-PREnvironment.ps1
0852_Validate-PRDockerDeployment.ps1   → 0152_Validate-PRDockerDeployment.ps1
0853_Quick-Docker-Validation.ps1       → 0153_Quick-Docker-Validation.ps1
0854_Manage-PRContainer.ps1            → 0154_Manage-PRContainer.ps1
```

### Option B: Document 0800-0899 Range (NOT RECOMMENDED)

Keep current numbering but document the range:
- **0800-0849**: Issue Management & Workflow Automation
- **0850-0899**: Deployment & Container Management

**Why not recommended**: These are fundamentally different concerns that belong in separate ranges.

## Implementation Plan

### Phase 1: Preparation
1. ✅ Create this reorganization plan
2. [ ] Get approval on numbering scheme
3. [ ] Audit all references to 0800 scripts:
   - Workflows (.github/workflows/*.yml)
   - Documentation (*.md files)
   - Tests (tests/**/*.ps1)
   - Other scripts
   - Config files

### Phase 2: Migration (Automated)
1. [ ] Create migration script: `9998_Reorganize-ScriptNumbers.ps1`
2. [ ] Script should:
   - Rename files with git mv (preserves history)
   - Update all references in codebase
   - Update test files
   - Update documentation
   - Generate migration report

### Phase 3: Validation
1. [ ] Run all tests to ensure nothing broke
2. [ ] Validate workflows still reference correct scripts
3. [ ] Update copilot-instructions.md with complete range list
4. [ ] Update FUNCTIONALITY-INDEX.md

### Phase 4: Documentation
1. [ ] Update README.md with complete numbering system
2. [ ] Add deprecation notices to old script locations (symbolic links?)
3. [ ] Update all documentation references

## Impact Analysis

### Files That Will Need Updates

#### Workflow Files (Critical)
```bash
.github/workflows/deploy-pr-environment.yml
.github/workflows/pr-validation.yml
.github/workflows/quality-validation.yml
.github/workflows/intelligent-ci-orchestrator.yml
# ... potentially more
```

#### Test Files
```bash
tests/unit/automation-scripts/0800-0899/*.Tests.ps1
# Will need to be reorganized into:
tests/unit/automation-scripts/0700-0799/*.Tests.ps1  # Issue mgmt
tests/unit/automation-scripts/0100-0199/*.Tests.ps1  # Deployment
```

#### Documentation Files
```bash
README.md
FUNCTIONALITY-INDEX.md
DOCKER.md
.github/copilot-instructions.md
docs/**/*.md
```

### Risk Mitigation

1. **Use git mv**: Preserves git history for moved files
2. **Create migration script**: Automates all changes, reduces human error
3. **Comprehensive testing**: Run all test suites after migration
4. **Backward compatibility**: Consider leaving symbolic links for transition period

## Recommended Complete Numbering System

After reorganization, document all ranges in copilot-instructions.md:

```markdown
### Number-Based Orchestration System

Scripts in `/automation-scripts/` follow numeric ranges:
- **0000-0099**: Environment prep (PowerShell 7, directories, validation tools)
- **0100-0199**: Infrastructure (Hyper-V, certificates, networking, deployments, containers)
- **0200-0299**: Development tools (Git, Node, Python, Docker, VS Code, AI CLIs)
- **0300-0399**: *Reserved for future use*
- **0400-0499**: Testing & validation (unit, integration, linting, coverage)
- **0500-0599**: Reporting & metrics (dashboards, analytics, system info)
- **0600-0699**: *Reserved for future use*
- **0700-0799**: Git automation, AI tools, issue management
- **0800-0899**: *Deprecated - being reorganized*
- **9000-9999**: Maintenance & cleanup (machine reset, environment cleanup)
```

## Decision Required

**Please approve Option A (RECOMMENDED) to proceed with reorganization.**

Once approved, I will:
1. Create the automated migration script
2. Execute the migration
3. Update all references
4. Run comprehensive tests
5. Update all documentation

## Notes

- This reorganization should be done in a single PR to avoid confusion
- All changes will be in one atomic commit to allow easy rollback if needed
- Consider doing this during a low-activity period
- May want to announce in team channels before executing
