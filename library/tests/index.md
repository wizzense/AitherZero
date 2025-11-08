# AitherZero Test Infrastructure

**Status**: 🚧 In Development  
**Version**: 3.0  
**Last Updated**: 2025-11-08

## Quick Reference

### Run Tests

```powershell
# Quick validation (5 minutes)
./library/tests/Run-Tests.ps1 -Profile Quick

# Standard test suite (15 minutes)
./library/tests/Run-Tests.ps1 -Profile Standard

# Full test suite (30 minutes)
./library/tests/Run-Tests.ps1 -Profile Full

# CI-optimized (10 minutes)
./library/tests/Run-Tests.ps1 -Profile CI
```

### Generate Tests

```powershell
# Generate tests for all modules
./library/tests/generators/ModuleTestGenerator.ps1 -All

# Generate tests for specific module
./library/tests/generators/ModuleTestGenerator.ps1 -Module Configuration

# Generate tests for all scripts
./library/tests/generators/ScriptTestGenerator.ps1 -All

# Generate tests for script range
./library/tests/generators/ScriptTestGenerator.ps1 -Range '0400-0499'

# Generate workflow tests
./library/tests/generators/WorkflowTestGenerator.ps1 -All
```

## Directory Structure

```
library/tests/
├── unit/               # Unit tests (isolated component testing)
├── integration/        # Integration tests (component interaction)
├── e2e/               # End-to-end tests (complete scenarios)
├── quality/           # Quality validation (PSScriptAnalyzer, AST)
├── performance/       # Performance benchmarking
├── helpers/           # Shared test utilities
├── generators/        # Test generation tools
├── config/            # Test configuration
└── results/           # Test execution results
```

## Test Types

| Type | Purpose | Duration | Coverage |
|------|---------|----------|----------|
| Unit | Validate individual components | Fast | Functions, Scripts, Modules |
| Integration | Validate component interactions | Medium | Module integration, Playbooks |
| E2E | Validate complete scenarios | Slow | Bootstrap, Deployment, Release |
| Quality | Enforce code standards | Fast | PSScriptAnalyzer, AST, Style |
| Performance | Track execution metrics | Medium | Benchmarks, Resource usage |

## Test Profiles

| Profile | Duration | Use Case | Tests |
|---------|----------|----------|-------|
| Quick | 5 min | Local dev | Unit (modified only), Syntax |
| Standard | 15 min | PR validation | All unit, Integration, Quality |
| Full | 30 min | Pre-merge | All tests including E2E |
| CI | 10 min | GitHub Actions | Optimized parallel execution |
| Developer | 3 min | Active dev | Modified components only |
| Release | 45 min | Pre-release | All tests + Benchmarks |

## Components

### Helpers

- **TestHelpers.psm1** - Common test utilities
- **ASTAnalyzer.psm1** - AST-based code analysis
- **MockFactory.psm1** - Mock object creation (TODO)
- **Assertions.psm1** - Custom Pester assertions (TODO)

### Generators

- **ModuleTestGenerator.ps1** - AST-based module tests
- **ScriptTestGenerator.ps1** - Script validation tests
- **WorkflowTestGenerator.ps1** - Workflow syntax tests
- **E2ETestGenerator.ps1** - E2E scenario tests (TODO)

### Configuration

- **test-profiles.psd1** - Test execution profiles
- **coverage-rules.psd1** - Code coverage requirements
- **quality-gates.psd1** - Quality gate definitions

## Coverage Requirements

| Component | Minimum | Target |
|-----------|---------|--------|
| Core Modules | 80% | 90% |
| Automation Scripts | 70% | 85% |
| Infrastructure | 60% | 75% |
| Orchestration | 80% | 90% |
| Overall | 75% | 85% |

## Quality Gates

All code must pass:
1. ✅ All unit tests (100%)
2. ✅ All integration tests (100%)
3. ✅ PSScriptAnalyzer (no Critical/Error)
4. ✅ AST analysis (complexity < 20)
5. ✅ Documentation coverage (100% for public functions)
6. ✅ Code coverage (>= minimum threshold)

## Migration Status

- [x] Test infrastructure design
- [x] Test helpers and AST analyzer
- [x] Test configuration
- [x] Test generators
- [x] E2E test template
- [ ] Generate all module tests
- [ ] Generate all script tests
- [ ] Generate workflow tests
- [ ] Create GitHub workflow
- [ ] Migrate from old tests/
- [ ] Archive old tests directory

## Documentation

- [README.md](README.md) - Complete documentation
- [test-profiles.psd1](config/test-profiles.psd1) - Profile definitions
- [coverage-rules.psd1](config/coverage-rules.psd1) - Coverage rules
- [quality-gates.psd1](config/quality-gates.psd1) - Quality requirements

## See Also

- [AitherZero Testing README](../../TESTING-README.md)
- [Integration Testing Guide](../../docs/INTEGRATION-TESTING-GUIDE.md)
- [CI/CD Guide](../../docs/CI-CD-GUIDE.md)
