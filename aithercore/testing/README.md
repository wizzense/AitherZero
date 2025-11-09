# AitherZero Testing Framework - Module Organization

## Active Modules (In Use)

### Core Test Generation
- **AutoTestGenerator.psm1** - Main test generation engine
  - Generates unit and integration tests automatically
  - Uses FunctionalTestTemplates for script-specific tests
  - Integrates with three-tier validation
  - Status: ✅ **ACTIVE - Enhanced**

### Functional Testing
- **FunctionalTestFramework.psm1** - Functional test utilities
  - Pester native mocking wrappers
  - Test environment creation
  - Output validation (Assert-ScriptOutput)
  - Side-effect validation (Assert-SideEffect)
  - Integration test helpers
  - Performance measurement
  - Status: ✅ **ACTIVE - NEW**

- **FunctionalTestTemplates.psm1** - Script-type-specific test templates
  - PSScriptAnalyzer test templates
  - Git automation test templates
  - Testing tools test templates
  - Deployment test templates
  - Reporting test templates
  - General functional test templates
  - Status: ✅ **ACTIVE - NEW**

### Validation Frameworks
- **ThreeTierValidation.psm1** - Comprehensive three-tier validation
  - Tier 1: AST parsing and analysis
  - Tier 2: PSScriptAnalyzer code quality
  - Tier 3: Pester functional testing
  - Quality score calculation
  - Comprehensive validation reporting
  - Status: ✅ **ACTIVE - NEW**

- **PlaybookTestFramework.psm1** - Playbook and orchestration testing
  - Playbook structure validation
  - Playbook execution testing
  - Sequence validation
  - Dependency chain testing
  - Success criteria validation
  - Performance benchmarking
  - Status: ✅ **ACTIVE - NEW**

### Utilities
- **TestCacheManager.psm1** - Test result caching
  - Cache test results for performance
  - Invalidate on script changes
  - Query cached results
  - Status: ✅ **ACTIVE - UTILITY**

## Legacy Modules (To Be Deprecated/Consolidated)

### Deprecated - Superseded by AutoTestGenerator
- **TestGenerator.psm1** - Old test generator
  - Status: ⚠️ **DEPRECATED** - Use AutoTestGenerator.psm1
  
- **AdvancedTestGenerator.psm1** - Advanced test generator
  - Status: ⚠️ **DEPRECATED** - Features merged into AutoTestGenerator.psm1
  
- **FunctionalTestGenerator.psm1** - Functional test generator
  - Status: ⚠️ **DEPRECATED** - Superseded by FunctionalTestTemplates.psm1

### Under Review - May Be Consolidated
- **TestingFramework.psm1** - Original testing framework
  - Status: 🔍 **REVIEW** - Evaluate if useful features should be merged

- **AitherTestFramework.psm1** - Alternative test framework
  - Status: 🔍 **REVIEW** - Evaluate for consolidation

- **CoreTestSuites.psm1** - Core test suites
  - Status: 🔍 **REVIEW** - May contain useful test helpers

- **QualityValidator.psm1** - Quality validation
  - Status: 🔍 **REVIEW** - May overlap with ThreeTierValidation.psm1

## Module Dependencies

```
AutoTestGenerator.psm1
├── FunctionalTestTemplates.psm1 (for script-specific tests)
└── Imports at generation time

FunctionalTestFramework.psm1
└── Pester (native mocking, assertions)

ThreeTierValidation.psm1
├── AST Parser (System.Management.Automation.Language)
├── PSScriptAnalyzer (module)
└── Pester (test execution)

PlaybookTestFramework.psm1
├── FunctionalTestFramework.psm1 (for helpers)
└── OrchestrationEngine.psm1 (for playbook execution)
```

## Import Strategy

### For Test Generation
```powershell
Import-Module ./aithercore/testing/AutoTestGenerator.psm1
# Automatically imports FunctionalTestTemplates
```

### For Manual Functional Testing
```powershell
Import-Module ./aithercore/testing/FunctionalTestFramework.psm1
# Provides: New-TestMock, Assert-ScriptOutput, Assert-SideEffect, etc.
```

### For Three-Tier Validation
```powershell
Import-Module ./aithercore/testing/ThreeTierValidation.psm1
# Provides: Invoke-ThreeTierValidation, Invoke-ASTValidation, etc.
```

### For Playbook Testing
```powershell
Import-Module ./aithercore/testing/PlaybookTestFramework.psm1
# Provides: Test-PlaybookStructure, Test-PlaybookExecution, etc.
```

## Integration Points

### OrchestrationEngine Integration
```powershell
# OrchestrationEngine.psm1 should import:
Import-Module ./aithercore/testing/ThreeTierValidation.psm1
Import-Module ./aithercore/testing/PlaybookTestFramework.psm1

# Enables validation of playbooks before execution
```

### Playbook Integration
```yaml
# comprehensive-validation.psd1
Sequence:
  - Tier 1: AST validation (0407_Validate-Syntax.ps1)
  - Tier 2: PSScriptAnalyzer (0404_Run-PSScriptAnalyzer.ps1)  
  - Tier 3: Pester tests (0402_Run-UnitTests.ps1, 0403_Run-IntegrationTests.ps1)
  - Report generation (0510_Generate-ProjectReport.ps1)
```

### GitHub Workflow Integration
```yaml
# .github/workflows/test-execution.yml
- name: Three-Tier Validation
  run: |
    Import-Module ./aithercore/testing/ThreeTierValidation.psm1
    Invoke-ThreeTierValidation -ScriptPath $path

- name: Playbook Validation
  run: |
    Import-Module ./aithercore/testing/PlaybookTestFramework.psm1
    Test-PlaybookExecution -PlaybookName $playbook
```

### Dashboard Integration
```powershell
# 0512_Generate-Dashboard.ps1 should import:
Import-Module ./aithercore/testing/ThreeTierValidation.psm1

# Collect three-tier metrics for dashboard
```

## Migration Path

### Phase 1: Immediate Actions
1. ✅ Use new frameworks (FunctionalTestFramework, FunctionalTestTemplates, ThreeTierValidation, PlaybookTestFramework)
2. ✅ Update AutoTestGenerator to use new templates
3. ⚠️ Mark old modules as deprecated
4. 📝 Update documentation

### Phase 2: Consolidation (Next Week)
1. Evaluate TestingFramework.psm1, AitherTestFramework.psm1, CoreTestSuites.psm1
2. Extract useful features into active modules
3. Archive deprecated modules to tests/archive/
4. Update all imports

### Phase 3: Integration (Week 2)
1. Integrate ThreeTierValidation into OrchestrationEngine
2. Update all playbooks with three-tier approach
3. Update GitHub workflows
4. Update dashboard generation

### Phase 4: Cleanup (Week 3)
1. Remove deprecated modules
2. Clean up duplicate tests
3. Final documentation update
4. Performance optimization

## File Locations

### Active Modules
```
aithercore/testing/
├── AutoTestGenerator.psm1          ✅ ACTIVE
├── FunctionalTestFramework.psm1    ✅ ACTIVE (NEW)
├── FunctionalTestTemplates.psm1    ✅ ACTIVE (NEW)
├── ThreeTierValidation.psm1        ✅ ACTIVE (NEW)
├── PlaybookTestFramework.psm1      ✅ ACTIVE (NEW)
└── TestCacheManager.psm1           ✅ ACTIVE (UTILITY)
```

### Deprecated (To Archive)
```
aithercore/testing/
├── TestGenerator.psm1              ⚠️ DEPRECATED
├── AdvancedTestGenerator.psm1      ⚠️ DEPRECATED
└── FunctionalTestGenerator.psm1    ⚠️ DEPRECATED
```

### Under Review
```
aithercore/testing/
├── TestingFramework.psm1           🔍 REVIEW
├── AitherTestFramework.psm1        🔍 REVIEW
├── CoreTestSuites.psm1             🔍 REVIEW
└── QualityValidator.psm1           🔍 REVIEW
```

## Quick Reference

### Generate Tests
```powershell
Import-Module ./aithercore/testing/AutoTestGenerator.psm1
New-AutoTest -ScriptPath $path -Force
Invoke-AutoTestGeneration -Mode Full
```

### Run Three-Tier Validation
```powershell
Import-Module ./aithercore/testing/ThreeTierValidation.psm1
Invoke-ThreeTierValidation -ScriptPath $path -TestPath $testPath
```

### Test Playbooks
```powershell
Import-Module ./aithercore/testing/PlaybookTestFramework.psm1
Test-PlaybookStructure -PlaybookPath $path
Test-PlaybookExecution -PlaybookName $name
```

### Create Test Environment
```powershell
Import-Module ./aithercore/testing/FunctionalTestFramework.psm1
$env = New-TestEnvironment -Files @{ 'test.ps1' = $content }
```

### Mock Commands (Pester Native)
```powershell
# Direct Pester mocking
Mock git { return 'Success' }
Should -Invoke git -Times 1 -Exactly

# Or use our wrappers
New-TestMock -CommandName git -ReturnValue 'Success'
Assert-MockCalled -CommandName git -Times 1 -Exactly
```

---

**Last Updated**: 2025-11-09
**Status**: Consolidation in progress
**Version**: 2.0 (Three-Tier Validation Era)
