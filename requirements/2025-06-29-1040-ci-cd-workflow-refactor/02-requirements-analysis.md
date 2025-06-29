# Phase 2: Requirements Analysis

**Requirement**: CI/CD Workflow Refactor
**Phase**: Requirements Analysis
**Status**: In Progress
**Date**: 2025-06-29

## Executive Summary

Based on Phase 1 discovery, we will refactor 8 complex GitHub Actions workflows into a unified intelligent pipeline that reduces complexity by 70% while maintaining all critical functionality.

## Current State Analysis

### Existing Workflows (8 total)
1. **api-documentation.yml** - API doc generation (Keep specialized)
2. **build-release-simple.yml.disabled** - DISABLED (Remove)
3. **build-release.yml** - 738 lines, 9 build combinations (Consolidate)
4. **ci-cd.yml** - 626 lines, comprehensive CI/CD (Merge)
5. **code-coverage.yml** - Basic coverage analysis (Merge)
6. **parallel-ci-optimized.yml** - 789 lines, smart detection (Merge)
7. **sync-to-aitherlab.yml** - Repository sync (Keep specialized)
8. **test-coverage-enhanced.yml** - Enhanced coverage (Merge)

### Problem Metrics
- **Current Jobs Per PR**: 15-25 concurrent jobs
- **Current Jobs Per Main Push**: 30+ jobs  
- **Maintenance Files**: 8 workflows to update
- **Matrix Complexity**: 6+ combinations (3 platforms × 2 PowerShell versions)
- **Resource Waste**: ~70% redundant execution

## Target Architecture

### Unified Pipeline Structure (3 workflows)

#### 1. **intelligent-ci.yml** (Primary Pipeline)
**Purpose**: Unified CI/CD with smart execution
**Triggers**: Push, PR, manual dispatch
**Key Features**:
- Intelligent change detection
- Adaptive job matrix
- Cross-platform testing (PowerShell 7 only)
- Security scanning consolidation
- Summary issue creation for failures

#### 2. **build-release.yml** (Simplified)
**Purpose**: Package building and releases
**Triggers**: Tags, manual dispatch
**Key Features**:
- Multi-profile builds (minimal/standard/full)
- Cross-platform packaging
- Streamlined 9-job matrix management
- Artifact publishing

#### 3. **documentation.yml** (Specialized)
**Purpose**: Documentation and sync operations
**Triggers**: Documentation changes, scheduled
**Key Features**:
- API documentation generation
- Repository synchronization
- Documentation-only change detection

## Detailed Requirements

### R1: Intelligent Change Detection
**Priority**: High
**Description**: Implement smart file change analysis to skip unnecessary jobs
**Acceptance Criteria**:
- Skip full CI for documentation-only changes
- Skip package builds for test-only changes
- Skip cross-platform tests for Windows-specific changes
- 70% reduction in execution time for non-code changes

**Implementation Approach**:
```yaml
# Extract from parallel-ci-optimized.yml
- name: Detect Changes
  uses: dorny/paths-filter@v2
  with:
    filters: |
      code:
        - '**/*.ps1'
        - '**/*.psm1'
        - '**/*.psd1'
      docs:
        - '**/*.md'
        - 'docs/**'
      tests:
        - 'tests/**'
      config:
        - 'configs/**'
        - '.github/workflows/**'
```

### R2: Cross-Platform Standardization
**Priority**: High
**Description**: Standardize on PowerShell 7 across all platforms
**Acceptance Criteria**:
- Windows: Use latest PowerShell 7
- Linux: Install PowerShell 7 automatically
- macOS: Install PowerShell 7 automatically
- Remove PowerShell 5.1 testing matrix
- Reduce matrix from 6+ jobs to 3 jobs

**Implementation Approach**:
```yaml
strategy:
  matrix:
    os: [windows-latest, ubuntu-latest, macos-latest]
    # Remove powershell-version matrix
steps:
  - name: Install PowerShell 7 (Linux/macOS)
    if: runner.os != 'Windows'
    shell: bash
    run: |
      # Platform-specific PowerShell 7 installation
```

### R3: Security Scanning Consolidation
**Priority**: High
**Description**: Merge all security features into unified security stage
**Acceptance Criteria**:
- SAST scanning (existing)
- Dependency vulnerability scanning (existing)
- PowerShell code quality analysis (existing)
- Security report aggregation
- Single security job instead of scattered checks

**Current Security Features to Preserve**:
- PSScriptAnalyzer for PowerShell code quality
- Dependency scanning for Node.js components
- SARIF report generation
- Security baseline validation

### R4: Multi-Profile Build Optimization
**Priority**: Medium
**Description**: Maintain 3 build profiles while optimizing execution
**Acceptance Criteria**:
- Minimal profile: Core functionality only
- Standard profile: Standard deployment features
- Full profile: All modules and capabilities
- Parallel profile builds where possible
- Clear profile documentation and selection guidance

### R5: Summary Issue Creation
**Priority**: Medium
**Description**: Automated issue creation for build failures
**Acceptance Criteria**:
- Create single summary issue for build failures
- Include failure details and logs
- Link to failed workflow run
- Auto-close resolved issues
- NO individual issues for linting warnings
- NO automatic PR creation

**Implementation Approach**:
```yaml
- name: Create Failure Summary Issue
  if: failure()
  uses: actions/github-script@v7
  with:
    script: |
      const title = `Build Failure Summary - ${context.workflow} #${context.runNumber}`;
      const body = `
      ## Build Failure Summary
      
      **Workflow**: ${context.workflow}
      **Run**: ${context.runNumber}
      **Commit**: ${context.sha.substring(0, 7)}
      
      **Failed Jobs**: 
      - [List failed jobs with details]
      
      **Logs**: [Link to workflow run]
      `;
      
      // Create or update existing issue
```

## Success Metrics

### Quantitative Targets
- **Job Reduction**: 15-25 jobs → 5-8 jobs per PR (70% reduction)
- **Execution Time**: 70% faster for documentation changes
- **Matrix Simplification**: 6+ combinations → 3 combinations
- **Maintenance Overhead**: 8 files → 3 files (62% reduction)
- **Resource Usage**: 60%+ reduction in GitHub Actions minutes

### Qualitative Targets
- Clear, trackable job status
- Reduced developer confusion
- Faster feedback loops
- Improved maintainability
- Preserved functionality

## Implementation Phases

### Phase A: Foundation (Week 1)
1. Create intelligent-ci.yml with basic structure
2. Implement change detection logic
3. Migrate core CI functionality
4. Test PowerShell 7 standardization

### Phase B: Consolidation (Week 2)
1. Merge security scanning features
2. Consolidate coverage analysis
3. Implement summary issue creation
4. Optimize build processes

### Phase C: Optimization (Week 3)
1. Fine-tune change detection rules
2. Optimize job dependencies
3. Implement advanced caching
4. Performance testing and tuning

### Phase D: Migration (Week 4)
1. Disable old workflows gradually
2. Monitor new pipeline performance
3. Documentation updates
4. Team training and rollout

## Risk Assessment

### High Risk
- **Functionality Loss**: Risk of missing edge cases during consolidation
- **Mitigation**: Comprehensive testing with existing test suites

### Medium Risk
- **Performance Regression**: Risk of slower builds during transition
- **Mitigation**: Parallel testing of old vs new workflows

### Low Risk
- **Team Adoption**: Risk of confusion during transition
- **Mitigation**: Clear documentation and gradual rollout

## Dependencies

### External Dependencies
- GitHub Actions platform capabilities
- PowerShell 7 availability across platforms
- Third-party actions (dorny/paths-filter, etc.)

### Internal Dependencies
- Existing test suites must pass
- Current artifact publishing must continue
- Security scanning requirements must be met

## Approval Criteria

- [ ] All current functionality preserved
- [ ] 70% reduction in job execution achieved
- [ ] Security scanning maintained
- [ ] Multi-profile builds working
- [ ] Change detection validated
- [ ] Summary issue creation tested
- [ ] Documentation updated
- [ ] Team approval obtained

## Next Steps

Ready to proceed to **Phase 3: Technical Design** for detailed workflow specifications and implementation plans.