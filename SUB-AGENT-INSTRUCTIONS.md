# Sub-Agent Instructions for AitherZero v1.0.0 MVP Recovery

## 🎯 MASTER OBJECTIVE
Get the AitherZero MVP fully operational with working CI/CD, comprehensive testing, automated reporting, and all development best practices WITHOUT compromising on quality, testing, or validation.

## 🚨 CRITICAL RULES FOR ALL SUB-AGENTS

### 1. MANDATORY FIRST ACTION
**ALWAYS** create a working branch using PatchManager as your FIRST action:
```powershell
New-Patch -Description "Fix [specific issue description]"
```
**If PatchManager fails, this is a BLOCKER that must be fixed immediately.**

### 2. TESTING REQUIREMENTS
- **TEST EVERYTHING LOCALLY** before committing
- **VALIDATE SYNTAX** for all YAML and PowerShell changes
- **RUN TESTS** that validate your changes work
- **TRIGGER WORKFLOWS** to verify GitHub Actions work correctly

### 3. QUALITY GATES (NON-NEGOTIABLE)
- No syntax errors in any file
- All tests must pass
- All workflows must complete successfully
- All artifacts must be generated correctly
- Full documentation of changes

### 4. COMMUNICATION PROTOCOL
- Report status immediately upon task start
- Report any blocking issues IMMEDIATELY
- Provide detailed results and validation proof
- Document rollback procedures for major changes

## 📋 SUB-AGENT TASK ASSIGNMENTS

### **AGENT 1: CI WORKFLOW SYNTAX FIXER**
**Task**: Fix PowerShell syntax error in CI workflow (CRITICAL BLOCKER)

**Objective**: Fix the PowerShell syntax error in `.github/workflows/ci.yml` that's causing all CI runs to fail.

**Specific Problem**: 
- File: `.github/workflows/ci.yml`
- Lines: 104-106
- Issue: `Invoke-ScriptAnalyzer -Path $files` where `$files` is an array but parameter expects string

**Required Actions**:
1. **Create branch**: `New-Patch -Description "Fix CI workflow PowerShell syntax error blocking all CI runs"`
2. **Analyze the problem**: Read the CI workflow file and identify the exact syntax issue
3. **Fix the syntax**: Convert the array handling to proper string paths for PSScriptAnalyzer
4. **Test locally**: Validate the PowerShell syntax works correctly
5. **Commit and push**: Trigger CI to validate the fix works
6. **Validate**: Ensure CI workflow completes without PowerShell errors

**Success Criteria**:
- [ ] CI workflow runs without PowerShell syntax errors
- [ ] PSScriptAnalyzer executes correctly
- [ ] Quality check step completes successfully
- [ ] No regression in workflow functionality

### **AGENT 2: YAML SYNTAX VALIDATOR**
**Task**: Validate and fix YAML syntax in all GitHub workflows

**Objective**: Ensure all workflow files have valid YAML syntax and proper GitHub Actions formatting.

**Required Actions**:
1. **Create branch**: `New-Patch -Description "Validate and fix YAML syntax across all workflows"`
2. **Validate all workflows**: Check every `.yml` file in `.github/workflows/`
3. **Use validation tools**: yamllint, GitHub Actions syntax checker, or equivalent
4. **Fix any issues**: Correct YAML syntax errors found
5. **Test validation**: Ensure all workflows can be parsed correctly
6. **Document issues**: Report any syntax problems found and fixed

**Files to validate**:
- `ci.yml`
- `release.yml`
- `comprehensive-report.yml`
- `audit.yml`
- `code-quality-remediation.yml`
- `security-scan.yml`
- `common-setup.yml`
- `trigger-release.yml`
- `workflow-config.yml`

**Success Criteria**:
- [ ] All YAML files pass syntax validation
- [ ] No GitHub Actions parsing errors
- [ ] All workflows can be triggered without syntax issues

### **AGENT 3: TEST INFRASTRUCTURE VALIDATOR**
**Task**: Validate and fix the Unified Test Runner

**Objective**: Ensure `Run-UnifiedTests.ps1` works correctly and integrates properly with CI workflows.

**Required Actions**:
1. **Create branch**: `New-Patch -Description "Validate and fix unified test runner infrastructure"`
2. **Test locally**: Run `./tests/Run-UnifiedTests.ps1 -TestSuite Quick`
3. **Fix issues**: Address any execution problems or missing dependencies
4. **Validate integration**: Ensure CI can call the test runner correctly
5. **Test all suites**: Validate Quick, All, Setup, and CI test suites work
6. **Document requirements**: Ensure all dependencies are documented

**Test Commands to Validate**:
```powershell
./tests/Run-UnifiedTests.ps1 -TestSuite Quick
./tests/Run-UnifiedTests.ps1 -TestSuite All -CI
./tests/Run-UnifiedTests.ps1 -TestSuite Setup
```

**Success Criteria**:
- [ ] Test runner executes without errors
- [ ] All test suites complete successfully
- [ ] Test reports are generated correctly
- [ ] CI integration works properly

### **AGENT 4: COMPREHENSIVE REPORTING WORKFLOW FIXER**
**Task**: Fix startup failures in comprehensive reporting workflow

**Objective**: Debug and resolve the startup failures in `comprehensive-report.yml` to restore dashboard generation.

**Required Actions**:
1. **Create branch**: `New-Patch -Description "Fix comprehensive reporting workflow startup failures"`
2. **Analyze failures**: Investigate why the workflow has startup failures
3. **Check dependencies**: Ensure all required scripts and modules exist
4. **Fix missing components**: Add or fix any missing dependencies
5. **Test workflow**: Manually trigger the workflow to validate it works
6. **Validate outputs**: Ensure HTML dashboard and all artifacts are generated

**Key Components to Check**:
- `scripts/reporting/Generate-ComprehensiveReport.ps1`
- `scripts/reporting/Generate-DynamicFeatureMap.ps1`
- All module dependencies
- Output directory structure
- Artifact collection logic

**Success Criteria**:
- [ ] Workflow starts without startup failures
- [ ] HTML dashboard is generated
- [ ] All audit reports are integrated
- [ ] Artifacts are properly uploaded

### **AGENT 5: BUILD ARTIFACT RESTORATION**
**Task**: Restore build artifact generation

**Objective**: Ensure `Build-Package.ps1` works correctly and all platform artifacts are generated.

**Required Actions**:
1. **Create branch**: `New-Patch -Description "Restore build artifact generation for all platforms"`
2. **Test build script**: Run `./build/Build-Package.ps1` locally
3. **Validate all platforms**: Test Windows, Linux, and macOS builds
4. **Fix build issues**: Address any build failures or missing components
5. **Validate workflow integration**: Ensure release workflow includes all artifacts
6. **Test artifact collection**: Verify all builds are properly collected and uploaded

**Build Tests to Perform**:
```powershell
./build/Build-Package.ps1 -Platform all
./build/Build-Package.ps1 -Platform windows
./build/Build-Package.ps1 -Platform linux
./build/Build-Package.ps1 -Platform macos
```

**Success Criteria**:
- [ ] Build script executes without errors
- [ ] All platform artifacts are generated
- [ ] Artifacts are properly packaged
- [ ] Release workflow collects all builds

### **AGENT 6: PATCHMANAGER INTEGRATION VALIDATOR**
**Task**: Validate PatchManager v3.0 integration with workflows

**Objective**: Ensure PatchManager works correctly and integrates properly with automated workflows.

**Required Actions**:
1. **Test PatchManager**: Validate core PatchManager functions work
2. **Test workflow integration**: Ensure branch creation triggers CI correctly
3. **Validate atomic operations**: Test the new v3.0 atomic operation features
4. **Fix integration issues**: Address any workflow triggering problems
5. **Document workflows**: Ensure PatchManager integration is properly documented

**PatchManager Tests**:
```powershell
# Test core functions
New-Patch -Description "Test patch creation"
New-QuickFix -Description "Test quick fix"
New-Feature -Description "Test feature workflow"

# Test workflow triggers
# Validate CI triggers on branch creation
# Validate PR creation works correctly
```

**Success Criteria**:
- [ ] PatchManager v3.0 functions work correctly
- [ ] Branch creation triggers workflows
- [ ] PR creation is automated correctly
- [ ] No git stashing issues occur

## 🔧 TECHNICAL GUIDELINES

### **PowerShell Version Requirements**
- Target PowerShell 7.0+ for all scripts
- Use cross-platform compatible syntax
- Test on both Windows and Linux environments

### **GitHub Actions Best Practices**
- Use proper YAML indentation (2 spaces)
- Include timeout settings for all long-running steps
- Use proper artifact handling with retention settings
- Include proper error handling and fallbacks

### **Testing Requirements**
- All changes must include relevant tests
- Tests must run in CI environment
- Test data and mocks must be properly isolated
- Performance impact must be considered

### **Documentation Standards**
- All changes must be documented
- Include examples and usage instructions
- Update CLAUDE.md with any new commands or procedures
- Document rollback procedures for major changes

## 🚨 ESCALATION PROCEDURES

### **When to Escalate**
- PatchManager fails to create branches (IMMEDIATE)
- Critical workflows fail after changes (IMMEDIATE)
- Dependencies are missing and cannot be resolved (IMMEDIATE)
- Test failures that cannot be resolved (IMMEDIATE)
- Any blocking issues that prevent task completion

### **How to Escalate**
1. **Immediate notification**: Report the blocking issue
2. **Provide context**: Include full error messages and steps taken
3. **Suggest alternatives**: Propose potential solutions or workarounds
4. **Document impact**: Explain how this affects the overall roadmap

## 📊 REPORTING REQUIREMENTS

### **Status Updates**
- **Task Start**: Report when beginning work
- **Progress Updates**: Report significant milestones or issues
- **Completion**: Report task completion with validation proof
- **Results**: Provide detailed results and any lessons learned

### **Validation Proof Required**
- Screenshots of successful workflow runs
- Test execution results and reports
- Artifact generation confirmation
- Error resolution documentation

## 🎯 SUCCESS METRICS

### **Individual Task Success**
- Task completed without errors
- All tests pass
- Workflows execute successfully
- Artifacts generated correctly
- Documentation updated

### **Overall Success**
- CI/CD pipeline fully operational
- All tests running and reporting correctly
- Comprehensive reporting working
- Build artifacts being generated
- Development workflow fully automated

---

**Remember**: The goal is to get the MVP working WITHOUT compromising on development best practices, automation, testing, or auditing. Quality is non-negotiable!