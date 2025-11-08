# Test Migration Strategy

## Overview

This document outlines the strategy for migrating from the old `/tests` directory to the new `/library/tests` infrastructure.

## Current State Analysis

### Old Tests Directory (`/tests`)
- **Location**: Repository root `/tests`
- **Total Files**: 342 test files
  - 167 unit tests (`tests/unit/`)
  - 166 integration tests (`tests/integration/`)
  - 7 domain tests (`tests/domains/`)
- **Organization**: Mixed structure with automation-scripts tests organized by range
- **Quality**: Auto-generated structural tests (file exists, parameter checks, syntax validation)
- **Issues**:
  - Many outdated tests from old code versions
  - Basic structural validation only
  - No AST-based analysis
  - No comprehensive E2E testing
  - Scattered test orchestration

### New Tests Directory (`/library/tests`)
- **Location**: `/library/tests`
- **Organization**: Structured by test type (unit, integration, e2e, quality, performance)
- **Quality**: AST-driven comprehensive testing
- **Features**:
  - Module function validation (parameters, return values, error handling)
  - Script metadata and behavior testing
  - Workflow validation
  - E2E scenario testing
  - Quality gates (PSScriptAnalyzer, AST analysis, coverage)
  - Test profiles (Quick, Standard, Full, CI, Developer, Release)

## Migration Phases

### Phase 1: Parallel Operation ✅
**Status**: Complete

- [x] Create new test infrastructure in `/library/tests`
- [x] Build test generators (module, script, workflow)
- [x] Create test helpers and AST analyzer
- [x] Define test profiles and quality gates
- [x] Generate sample tests to validate system

### Phase 2: Archive Preparation (Current)
**Tasks**:

1. **Create Archive Directory**
   ```powershell
   mkdir /library/tests/archive/old-tests
   ```

2. **Document Old Tests**
   ```powershell
   # Create inventory of old tests
   ./library/tests/migration/Create-TestInventory.ps1 -Path /tests -Output /library/tests/archive/test-inventory.json
   ```

3. **Identify Valuable Tests**
   - Review old tests for unique scenarios
   - Extract any custom test logic not covered by generators
   - Document special cases

### Phase 3: Coverage Validation
**Tasks**:

1. **Generate New Test Suite**
   ```powershell
   # Generate all module tests
   ./library/tests/generators/ModuleTestGenerator.ps1 -All

   # Generate all script tests
   ./library/tests/generators/ScriptTestGenerator.ps1 -All

   # Generate workflow tests
   ./library/tests/generators/WorkflowTestGenerator.ps1 -All
   ```

2. **Compare Coverage**
   ```powershell
   # Run old tests and capture coverage
   Invoke-Pester -Path /tests -CodeCoverage aithercore/**/*.psm1 -CodeCoverageOutputFile old-coverage.xml

   # Run new tests and capture coverage
   ./library/tests/Run-Tests.ps1 -Profile Full -GenerateCoverage

   # Compare coverage
   ./library/tests/migration/Compare-Coverage.ps1 -Old old-coverage.xml -New library/tests/results/coverage.xml
   ```

3. **Validate All Scenarios**
   - Ensure all test scenarios from old tests are covered
   - Add any missing E2E tests
   - Validate workflow tests cover all workflows

### Phase 4: Workflow Updates
**Tasks**:

1. **Create New Test Workflow**
   - File: `.github/workflows/test-execution.yml`
   - Features:
     - Parallel test execution by type
     - Test result aggregation
     - Coverage reporting
     - Quality gate validation

2. **Update Existing Workflows**
   - Update references from `/tests` to `/library/tests`
   - Replace old orchestration scripts with new `Run-Tests.ps1`
   - Update test result paths

3. **Deprecate Old Workflows**
   - Mark old test workflows as deprecated
   - Add migration notices

### Phase 5: Migration Execution
**Tasks**:

1. **Archive Old Tests**
   ```powershell
   # Move old tests to archive
   Move-Item /tests /library/tests/archive/old-tests -Force

   # Create README in archive
   ./library/tests/migration/Create-ArchiveReadme.ps1
   ```

2. **Update References**
   ```powershell
   # Find all references to /tests
   Get-ChildItem -Path . -Recurse -Include *.ps1,*.psm1,*.md,*.yml |
       Select-String -Pattern '(/tests|\\tests)' |
       Select-Object -Unique

   # Update each reference to /library/tests
   ```

3. **Update Documentation**
   - Update `/TESTING-README.md`
   - Update `/README.md`
   - Update all domain READMEs that reference tests
   - Update GitHub workflow documentation

### Phase 6: Validation & Cleanup
**Tasks**:

1. **Run Full Test Suite**
   ```powershell
   # Run comprehensive tests
   ./library/tests/Run-Tests.ps1 -Profile Full -GenerateReport
   ```

2. **Validate CI/CD**
   - Trigger all test workflows
   - Verify test results are published correctly
   - Confirm coverage reports work

3. **Monitor for Issues**
   - Run for 1-2 weeks with both old and new tests
   - Address any issues found
   - Validate performance is acceptable

4. **Final Cleanup**
   - Remove old test orchestration scripts (0460, 0470, 0480, 0490)
   - Remove deprecated workflows
   - Update config.psd1 to remove old test references

## Rollback Plan

If issues are discovered:

1. **Keep Archive Accessible**
   - Old tests remain in `/library/tests/archive/old-tests`
   - Can be moved back to `/tests` if needed

2. **Workflow Rollback**
   - Old workflows remain in repository (deprecated)
   - Can be re-enabled if needed

3. **Gradual Migration Option**
   - Run both old and new tests in parallel
   - Gradually deprecate old tests as confidence grows

## Success Criteria

Migration is successful when:

- [ ] All new tests pass
- [ ] Code coverage >= old coverage
- [ ] All test scenarios covered
- [ ] All workflows updated and working
- [ ] Documentation updated
- [ ] No references to old `/tests` location (except archive)
- [ ] CI/CD pipelines stable for 2 weeks

## Timeline

- **Phase 1**: ✅ Complete
- **Phase 2**: 1 day
- **Phase 3**: 1-2 days
- **Phase 4**: 1 day
- **Phase 5**: 1 day
- **Phase 6**: 1-2 weeks (monitoring period)

**Total**: ~2-3 weeks

## Migration Scripts

Create these helper scripts in `/library/tests/migration/`:

1. **Create-TestInventory.ps1** - Generate inventory of old tests
2. **Compare-Coverage.ps1** - Compare code coverage between old and new
3. **Create-ArchiveReadme.ps1** - Generate README for archived tests
4. **Validate-Migration.ps1** - Comprehensive validation of migration
5. **Update-References.ps1** - Update all references from old to new location

## Communication Plan

1. **PR Description**: Explain migration strategy and testing approach
2. **Documentation**: Update all docs before merge
3. **Team Notification**: Notify team of new test location
4. **Migration Guide**: Provide quick reference for developers

## Risk Mitigation

1. **Parallel Operation**: Keep both test systems running initially
2. **Archive Preservation**: Never delete old tests, only archive
3. **Comprehensive Validation**: Multiple validation passes before cleanup
4. **Gradual Rollout**: Workflows updated one at a time
5. **Monitoring Period**: 1-2 weeks of stability before final cleanup

---

**Document Version**: 1.0  
**Last Updated**: 2025-11-08  
**Status**: In Progress - Phase 2
