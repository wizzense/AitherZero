# AitherZero Testing Infrastructure v3.0

A comprehensive, AST-driven testing framework for complete validation of AitherZero platform.

## Architecture Philosophy

This testing infrastructure validates the entire AitherZero ecosystem:
- **Functions** - Every exported function in every module
- **Scripts** - All 150+ automation scripts (0000-9999)
- **Modules** - Module manifests, dependencies, exports
- **Workflows** - GitHub Actions workflow validation
- **Playbooks** - Orchestration playbook execution
- **Integrations** - End-to-end bootstrap→infrastructure→deployment flows

## Directory Structure

```
library/tests/
├── unit/                    # Isolated component testing
│   ├── modules/            # Per-module function tests (AST-generated)
│   │   ├── configuration/  # Configuration.psm1 functions
│   │   ├── infrastructure/ # Infrastructure.psm1 functions
│   │   ├── security/       # Security.psm1 functions
│   │   └── ...             # All aithercore modules
│   ├── scripts/            # Automation script tests (by range)
│   │   ├── 0000-0099/     # Environment setup scripts
│   │   ├── 0100-0199/     # Infrastructure scripts
│   │   ├── 0400-0499/     # Testing & quality scripts
│   │   └── ...
│   └── workflows/          # GitHub workflow syntax validation
│
├── integration/             # Cross-component interaction testing
│   ├── modules/            # Module interaction tests
│   ├── infrastructure/     # Infrastructure provisioning tests
│   ├── playbooks/          # Playbook execution tests
│   └── workflows/          # Workflow integration tests
│
├── e2e/                     # End-to-end scenario testing
│   ├── bootstrap/          # Bootstrap process validation
│   ├── deployment/         # Full deployment scenarios
│   ├── orchestration/      # Multi-playbook orchestration
│   └── release/            # Build/test/release pipeline
│
├── quality/                 # Code quality and standards
│   ├── psscriptanalyzer/  # PSScriptAnalyzer validation
│   ├── ast-analysis/       # AST-based code analysis
│   ├── style-compliance/   # Style guide compliance
│   └── documentation/      # Documentation coverage
│
├── performance/             # Performance benchmarking
│   ├── modules/            # Module performance tests
│   ├── scripts/            # Script execution benchmarks
│   └── workflows/          # Workflow execution timing
│
├── helpers/                 # Shared test utilities
│   ├── TestHelpers.psm1   # Common test functions
│   ├── ASTAnalyzer.psm1   # AST parsing and validation
│   ├── MockFactory.psm1   # Mock object creation
│   └── Assertions.psm1    # Custom Pester assertions
│
├── generators/              # Test generation tools
│   ├── ModuleTestGenerator.ps1      # AST-based module tests
│   ├── ScriptTestGenerator.ps1      # Script validation tests
│   ├── WorkflowTestGenerator.ps1    # Workflow syntax tests
│   └── E2ETestGenerator.ps1         # E2E scenario tests
│
└── config/                  # Test configuration
    ├── test-profiles.psd1   # Test execution profiles
    ├── coverage-rules.psd1  # Coverage requirements
    └── quality-gates.psd1   # Quality gate definitions
```

## Test Categories

### 1. Unit Tests (`unit/`)

**Purpose**: Validate individual components in isolation

**Module Tests** (`unit/modules/`):
- AST-generated tests for every exported function
- Parameter validation (types, attributes, defaults)
- Return value validation
- Error handling validation
- Cross-platform compatibility

**Script Tests** (`unit/scripts/`):
- Organized by number range (0000-0099, 0100-0199, etc.)
- Script metadata validation (Stage, Dependencies, Tags)
- Parameter validation
- WhatIf/Confirm support
- Exit code validation
- Help documentation completeness

**Example Module Test**:
```powershell
# Auto-generated from AST analysis
Describe 'Get-Configuration Function' -Tag 'Unit', 'Configuration' {
    Context 'Parameter Validation' {
        It 'Should have Section parameter with string type' {
            $cmd = Get-Command Get-Configuration
            $cmd.Parameters['Section'].ParameterType | Should -Be ([string])
        }
    }
    
    Context 'Return Value Validation' {
        It 'Should return hashtable when no section specified' {
            $result = Get-Configuration
            $result | Should -BeOfType [hashtable]
        }
    }
    
    Context 'Error Handling' {
        It 'Should throw when invalid section requested' {
            { Get-Configuration -Section 'NonExistent' } | Should -Throw
        }
    }
}
```

### 2. Integration Tests (`integration/`)

**Purpose**: Validate interactions between components

**Module Integration**:
- Configuration → Logging integration
- Security → Infrastructure integration
- Orchestration → Testing integration

**Playbook Execution**:
- Test playbook loading and parsing
- Script dependency resolution
- Parallel execution validation
- Error recovery and rollback

**Example Integration Test**:
```powershell
Describe 'Bootstrap to Infrastructure Flow' -Tag 'Integration' {
    It 'Bootstrap should set AITHERZERO_ROOT environment variable' {
        ./bootstrap.ps1 -Mode New -InstallProfile Minimal
        $env:AITHERZERO_ROOT | Should -Not -BeNullOrEmpty
    }
    
    It 'Configuration module should load after bootstrap' {
        Import-Module ./AitherZero.psd1 -Force
        Get-Command Get-Configuration | Should -Not -BeNull
    }
}
```

### 3. E2E Tests (`e2e/`)

**Purpose**: Validate complete user scenarios

**Scenarios**:
- Fresh installation (bootstrap → module loading → first playbook)
- Update flow (existing installation → update → verify)
- Full deployment (infrastructure provisioning → VM creation)
- CI/CD pipeline (PR validation → tests → merge → release)

**Example E2E Test**:
```powershell
Describe 'Fresh Installation E2E' -Tag 'E2E' {
    It 'Should complete full installation flow' {
        # Step 1: Bootstrap
        ./bootstrap.ps1 -Mode New -InstallProfile Minimal
        
        # Step 2: Verify module loading
        Import-Module ./AitherZero.psd1 -Force
        
        # Step 3: Execute test playbook
        Invoke-AitherPlaybook -Name 'test-orchestration' -Profile quick
        
        # Step 4: Verify results
        Test-Path 'reports/dashboard.html' | Should -Be $true
    }
}
```

### 4. Quality Tests (`quality/`)

**Purpose**: Enforce code standards and best practices

**PSScriptAnalyzer**:
- All PowerShell files analyzed
- Critical/Error severity violations fail tests
- Warning violations tracked but don't fail
- Custom rules for AitherZero patterns

**AST Analysis**:
- Function complexity metrics
- Proper error handling (try/catch patterns)
- Logging usage (Write-CustomLog calls)
- Cross-platform compatibility checks

**Documentation**:
- All functions have comment-based help
- All scripts have metadata headers
- README files in all directories

### 5. Performance Tests (`performance/`)

**Purpose**: Track execution performance and resource usage

**Benchmarks**:
- Module import time
- Function execution time
- Script execution time
- Workflow execution time
- Memory usage
- CPU usage

## Test Execution

### Quick Test (5 minutes)
```powershell
# Run fast validation
aitherzero orchestrate test-quick

# What runs:
# - Unit tests for modified modules only
# - Syntax validation
# - Basic integration tests
```

### Standard Test (15 minutes)
```powershell
# Run comprehensive tests
aitherzero orchestrate test-standard

# What runs:
# - All unit tests
# - All integration tests
# - PSScriptAnalyzer
# - AST analysis
```

### Full Test (30 minutes)
```powershell
# Run complete test suite
aitherzero orchestrate test-full

# What runs:
# - All unit tests
# - All integration tests
# - All E2E tests
# - Quality validation
# - Performance benchmarks
# - Coverage analysis
```

### CI Test (10 minutes)
```powershell
# Optimized for GitHub Actions
aitherzero orchestrate test-ci

# What runs:
# - Parallelized unit tests
# - Critical integration tests
# - Syntax validation
# - Quality gates only
```

## Test Generation

### Auto-Generate All Tests
```powershell
# Generate tests for all modules (AST-based)
./library/tests/generators/ModuleTestGenerator.ps1 -All

# Generate tests for all scripts (by range)
./library/tests/generators/ScriptTestGenerator.ps1 -All

# Generate workflow validation tests
./library/tests/generators/WorkflowTestGenerator.ps1

# Generate E2E scenario tests
./library/tests/generators/E2ETestGenerator.ps1
```

### Generate Tests for Specific Component
```powershell
# Generate tests for one module
./library/tests/generators/ModuleTestGenerator.ps1 -Module Configuration

# Generate tests for one script range
./library/tests/generators/ScriptTestGenerator.ps1 -Range '0400-0499'

# Generate tests for one workflow
./library/tests/generators/WorkflowTestGenerator.ps1 -Workflow 'comprehensive-tests-v2'
```

## Coverage Requirements

| Component | Minimum Coverage | Target Coverage |
|-----------|-----------------|-----------------|
| Core Modules | 80% | 90% |
| Automation Scripts | 70% | 85% |
| Infrastructure | 60% | 75% |
| Orchestration | 80% | 90% |
| Overall | 75% | 85% |

## Quality Gates

All code changes must pass:
1. ✅ All unit tests (100% pass)
2. ✅ All integration tests (100% pass)
3. ✅ PSScriptAnalyzer (no Critical/Error)
4. ✅ AST analysis (complexity < 20)
5. ✅ Documentation coverage (100% for public functions)
6. ✅ Code coverage (>= minimum threshold)

## Migration from Old Tests

The old `/tests` directory will be archived and removed:
```powershell
# Archive old tests
./library/tests/migration/Archive-OldTests.ps1

# Verify new tests cover old functionality
./library/tests/migration/Verify-Coverage.ps1

# Delete old tests (after verification)
./library/tests/migration/Delete-OldTests.ps1
```

## CI/CD Integration

### GitHub Workflows

**Test Execution Workflow** (`.github/workflows/test-execution.yml`):
```yaml
jobs:
  unit-tests:
    strategy:
      matrix:
        range: [0000-0099, 0100-0199, 0200-0299, 0400-0499, ...]
    runs-on: ubuntu-latest
    steps:
      - name: Run Unit Tests
        run: |
          Invoke-Pester -Path library/tests/unit/scripts/${{ matrix.range }}
  
  integration-tests:
    needs: unit-tests
    runs-on: ubuntu-latest
    steps:
      - name: Run Integration Tests
        run: |
          Invoke-Pester -Path library/tests/integration
  
  e2e-tests:
    needs: integration-tests
    runs-on: ubuntu-latest
    steps:
      - name: Run E2E Tests
        run: |
          Invoke-Pester -Path library/tests/e2e
  
  quality-gates:
    needs: [unit-tests, integration-tests]
    runs-on: ubuntu-latest
    steps:
      - name: Validate Quality
        run: |
          Invoke-Pester -Path library/tests/quality
```

## Best Practices

1. **Test Naming**: `{Component}.{Function}.Tests.ps1` or `{ScriptNumber}_{ScriptName}.Tests.ps1`
2. **Tag Usage**: Always tag with test type (Unit, Integration, E2E, Quality, Performance)
3. **Isolation**: Unit tests must not depend on external state
4. **Mocking**: Use mocks for external dependencies
5. **Assertions**: One logical assertion per test
6. **Cleanup**: Always clean up resources in AfterAll/AfterEach
7. **Documentation**: Include purpose and expected behavior in test descriptions

## Troubleshooting

**Test Failures**:
```powershell
# View detailed test results
Get-Content library/tests/results/test-results.xml

# View failed tests only
Invoke-Pester -Path library/tests -Output Diagnostic | Where-Object Result -eq 'Failed'
```

**Coverage Issues**:
```powershell
# Generate coverage report
Invoke-Pester -Path library/tests/unit -CodeCoverage aithercore/**/*.psm1 -CodeCoverageOutputFile coverage.xml

# View coverage report
Start-Process coverage.xml
```

## Contributing

When adding new functionality:
1. Write tests first (TDD)
2. Use test generators when possible
3. Ensure minimum coverage thresholds
4. Run full test suite before PR
5. Update test documentation

## Version History

- **v3.0** (Current) - Complete rewrite with AST-driven testing
- **v2.0** (Deprecated) - Auto-generated structural tests
- **v1.0** (Archived) - Manual test creation

---

**Status**: 🚧 In Development
**Maintainer**: AitherZero Team
**Last Updated**: 2025-11-08
