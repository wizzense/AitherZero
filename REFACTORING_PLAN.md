# AitherZero Refactoring Implementation Plan

## Current State Analysis
- **503 PowerShell files** across project
- **33 domain module files** in 11 domain directories  
- **101 automation scripts** with 4 duplicate numbers
- **135 legacy files** requiring integration/cleanup
- **Deep nesting** in experience domain (3+ levels)

## Target Architecture

### 1. Consolidated Domain Structure (11 → 5 domains)
```
domains/
├── core/           # Configuration + Utilities + Logging (was utilities + configuration)
├── automation/     # Orchestration + Deployment (consolidate automation domain)
├── interface/      # All UI components (flatten experience domain)
├── development/    # Git + Testing + AI tools (merge testing + development + ai-agents) 
└── infrastructure/ # Infrastructure + Security + Reporting (merge infrastructure + security + reporting)
```

### 2. Flattened Module Files (33 → 12 modules)

#### core/ (5 modules)
- `Configuration.psm1` - Config management (merge configuration/Configuration.psm1)
- `Logging.psm1` - All logging functions (merge utilities/Logging*.psm1)  
- `Utilities.psm1` - Performance, maintenance, package mgmt (merge utilities/*)
- `Bootstrap.psm1` - Environment setup (keep utilities/Bootstrap.psm1)
- `FileSystem.psm1` - File operations and paths

#### automation/ (2 modules)  
- `Orchestration.psm1` - Workflow orchestration (merge automation/*)
- `Deployment.psm1` - Infrastructure deployment

#### interface/ (2 modules)
- `UserInterface.psm1` - All UI components (flatten experience/*)
- `Menu.psm1` - Interactive menus and prompts

#### development/ (2 modules)
- `DevTools.psm1` - Git, testing, CI/CD (merge development/* + testing/*)
- `AIIntegration.psm1` - AI tools and workflows (merge ai-agents/*)

#### infrastructure/ (1 module)
- `Infrastructure.psm1` - All infrastructure, security, reporting (merge infrastructure/* + security/* + reporting/*)

### 3. Automation Scripts Consolidation (101 → ~60 scripts)

#### Merge Related Scripts:
- **Testing scripts (20 → 8)**: Combine similar test runners
- **AI/Git scripts (24 → 12)**: Merge overlapping functionality  
- **Reporting scripts (15 → 8)**: Consolidate report generators
- **Issue management (9 → 4)**: Simplify issue workflows

#### Fix Duplicate Numbers:
- `0106_Install-WSL2.ps1` → `0107_Install-WSL2.ps1`
- `0106_Install-WindowsAdminCenter.ps1` → `0108_Install-WindowsAdminCenter.ps1`
- `0450_Test-Optimized.ps1` → `0451_Test-Optimized.ps1`
- `0512_Schedule-ReportGeneration.ps1` → `0513_Schedule-ReportGeneration.ps1`
- `0520_Deploy-Documentation.ps1` → `0521_Deploy-Documentation.ps1`

### 4. Orchestration Simplification

#### Standardized Playbook Format:
```json
{
  "name": "playbook-name",
  "description": "Description",
  "category": "setup|testing|development|deployment",
  "scripts": ["0001", "0002", "0100"],
  "variables": { "key": "value" },
  "options": {
    "continueOnError": false,
    "parallel": false,
    "timeout": 300
  }
}
```

#### Reduced Categories (8 → 4):
- **setup/**: Environment and tool installation
- **testing/**: All testing workflows  
- **development/**: Development workflows
- **deployment/**: Infrastructure deployment

### 5. Legacy Integration Strategy

#### High Priority (Keep & Integrate):
- Core functionality that's missing from main codebase
- Updated versions of existing tools
- Platform-specific enhancements

#### Low Priority (Archive or Remove):
- Duplicate functionality already in main codebase
- Experimental or incomplete features
- Outdated tools with modern replacements

## Implementation Phases

### Phase 1: Domain Consolidation ✅
- [x] Create new consolidated domain structure
- [ ] Merge and flatten domain modules
- [ ] Update module manifest with new structure
- [ ] Test module loading

### Phase 2: Automation Scripts Cleanup
- [ ] Fix duplicate script numbers
- [ ] Consolidate related scripts
- [ ] Standardize script parameters
- [ ] Update script documentation

### Phase 3: Orchestration Simplification  
- [ ] Standardize all playbook formats
- [ ] Consolidate playbook categories
- [ ] Test playbook execution
- [ ] Create playbook generation tools

### Phase 4: Legacy Integration
- [ ] Audit legacy files systematically
- [ ] Integrate valuable components
- [ ] Archive or remove outdated files
- [ ] Clean up root directory

### Phase 5: Testing & Validation
- [ ] Update all tests for new structure
- [ ] Validate automation script execution
- [ ] Performance testing of consolidated modules
- [ ] Documentation updates

## Success Metrics
- Reduce PowerShell files by 40% (503 → ~300)
- Reduce domain modules by 65% (33 → 12)  
- Eliminate all duplicate script numbers
- Reduce playbook categories by 50% (8 → 4)
- Maintain 100% functionality while improving performance