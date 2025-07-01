# AitherZero Production Testing Suite

This directory contains the comprehensive testing infrastructure for AitherZero, including production test runners, automated GitHub issue creation for failures, and multi-format reporting.

## 🚀 Quick Start

### Run Production Tests Locally

```powershell
# Run all critical tests with HTML report
./tests/Run-ProductionTests.ps1 -TestSuite Critical -GenerateHTML

# Run with GitHub issue creation for failures
./tests/Run-ProductionTests.ps1 -TestSuite Critical -CreateIssues -GenerateHTML

# CI/CD mode with full reporting
./tests/Run-ProductionTests.ps1 -CI -CreateIssues -ShowCoverage -UploadArtifacts
```

### Run Release Validation

```powershell
# Release validation for patch release
./tests/Invoke-ReleaseValidation.ps1 -ReleaseType patch -ValidationLevel Standard

# Complete release validation with automatic release creation
./tests/Invoke-ReleaseValidation.ps1 -TargetVersion "2.1.0" -ValidationLevel Complete -CreateRelease

# Production-grade validation
./tests/Invoke-ReleaseValidation.ps1 -ValidationLevel Production -CI
```

### Run Simplified Test Runners

```powershell
# Quick test runner with coverage enforcement
./tests/Invoke-QuickTests.ps1 -TestCategory Unit -MinCoverage 85 -ShowCoverage

# Individual module testing
./tests/Test-Module.ps1 -ModuleName Logging -Coverage -Verbose

# Watch mode for continuous testing during development
./tests/Test-Module.ps1 -ModuleName PatchManager -Watch
```

### Run Legacy Test Runners

```powershell
# Bulletproof validation (recommended for development)
./tests/Run-BulletproofValidation.ps1 -ValidationLevel Standard

# All module tests
./tests/Run-AllModuleTests.ps1

# Quick validation (30 seconds)
./tests/Run-BulletproofValidation.ps1 -ValidationLevel Quick
```

## 📁 Directory Structure

```
tests/
├── Critical/               # Critical infrastructure tests
│   ├── aither-core.Tests.ps1
│   ├── Cross-Platform-Deployment.Tests.ps1
│   ├── Git-Integration.Tests.ps1
│   ├── OpenTofuProvider.Tests.ps1
│   ├── API-NonInteractive-Modes.Tests.ps1
│   ├── Build-Integrity.Tests.ps1
│   ├── Release-EndToEnd.Tests.ps1
│   └── E2E-Release-Scenarios.Tests.ps1
├── Unit/                   # Unit tests for individual modules
├── Integration/            # Integration tests
├── E2E/                    # End-to-end tests
├── Performance/            # Performance tests
├── Shared/                 # Shared utilities and functions
│   ├── Test-Utilities.ps1
│   ├── New-TestFailureIssue.ps1
│   ├── ConvertTo-TestReport.ps1
│   └── Test-PerformanceRegression.ps1
├── TestResults/            # Generated test reports (gitignored)
├── Run-ProductionTests.ps1 # 🆕 Production test runner
├── Invoke-ReleaseValidation.ps1 # 🆕 Release validation system
├── Invoke-QuickTests.ps1   # 🆕 Quick test runner with coverage
├── Test-Module.ps1         # 🆕 Individual module testing with watch mode
├── Run-BulletproofValidation.ps1
├── Run-AllModuleTests.ps1
└── README.md              # This file
```

## 🧪 Production Test Runner

The `Run-ProductionTests.ps1` script is the primary production test runner with the following features:

### Features

- **Multi-Format Reporting**: JSON, HTML, XML, CSV, Markdown
- **GitHub Issue Creation**: Automatic issue creation for test failures
- **Code Coverage Analysis**: Integrated coverage reporting
- **Real-Time Progress Tracking**: Visual progress indicators
- **Cross-Platform Support**: Windows, Linux, macOS
- **CI/CD Integration**: Optimized for automated pipelines

### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `TestSuite` | Test suite to run (All, Critical, Unit, Integration, E2E, Performance) | Critical |
| `ReportLevel` | Detail level (Minimal, Standard, Detailed, Diagnostic) | Standard |
| `CreateIssues` | Create GitHub issues for failures | false |
| `GenerateHTML` | Generate interactive HTML report | false |
| `FailFast` | Stop on first failure | false |
| `CI` | CI/CD optimized mode | false |
| `ShowCoverage` | Include code coverage analysis | false |
| `OutputPath` | Report output directory | ./tests/TestResults |
| `DryRun` | Preview issue creation without creating them | false |

### Examples

```powershell
# Development testing with HTML dashboard
./tests/Run-ProductionTests.ps1 -TestSuite Critical -GenerateHTML -ReportLevel Detailed

# Production CI/CD with issue creation
./tests/Run-ProductionTests.ps1 -CI -CreateIssues -ShowCoverage

# Test specific areas with custom output
./tests/Run-ProductionTests.ps1 -TestSuite Integration -OutputPath "./reports" -IncludeTags @('Infrastructure', 'API')

# Preview issue creation (dry run)
./tests/Run-ProductionTests.ps1 -TestSuite Critical -CreateIssues -DryRun
```

## 🚀 Release Validation System

The `Invoke-ReleaseValidation.ps1` script provides comprehensive release validation with automated quality gates:

### Features

- **Multi-Level Validation**: Quick (5min), Standard (15min), Complete (30min), Production (60min)
- **Version Management**: Automatic version calculation and validation
- **Security Analysis**: PSScriptAnalyzer security checks with critical issue detection
- **Performance Benchmarking**: Performance regression testing with baseline comparison
- **Build Validation**: Module manifest validation and syntax checking
- **Release Automation**: Integrated with PatchManager release workflow
- **Quality Gates**: Enforced thresholds with override capabilities

### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ReleaseType` | Release type (patch, minor, major) | patch |
| `TargetVersion` | Specific version override | Auto-calculated |
| `ValidationLevel` | Validation depth (Quick, Standard, Complete, Production) | Standard |
| `SkipTests` | Skip test categories (Unit, Integration, E2E, Performance, Security) | @() |
| `CreateRelease` | Automatically create release after validation | false |
| `DryRun` | Preview validation without execution | false |
| `CI` | CI/CD optimized mode | false |
| `ForceValidation` | Bypass non-critical failures | false |

### Validation Pipeline

#### Quick (5 minutes)
- Version requirements validation
- Project structure verification  
- Critical test execution

#### Standard (15 minutes)
- All Quick validations
- Security analysis with PSScriptAnalyzer
- Unit test execution
- Build integrity validation

#### Complete (30 minutes)
- All Standard validations
- Integration test execution
- Performance benchmark comparison
- Coverage analysis

#### Production (60 minutes)
- All Complete validations
- End-to-end test execution
- Full security scan
- Automated release creation

### Examples

```powershell
# Standard release validation
./tests/Invoke-ReleaseValidation.ps1 -ReleaseType patch -ValidationLevel Standard

# Complete validation with release creation
./tests/Invoke-ReleaseValidation.ps1 -TargetVersion "2.1.0" -ValidationLevel Complete -CreateRelease

# CI/CD production validation
./tests/Invoke-ReleaseValidation.ps1 -ValidationLevel Production -CI -ForceValidation

# Security-focused validation
./tests/Invoke-ReleaseValidation.ps1 -ValidationLevel Standard -SkipTests @('Performance')

# Dry run preview
./tests/Invoke-ReleaseValidation.ps1 -ValidationLevel Complete -DryRun
```

## ⚡ Quick Test Runner

The `Invoke-QuickTests.ps1` script provides streamlined testing with mandatory coverage enforcement:

### Features

- **Coverage Enforcement**: Configurable minimum coverage thresholds (default: 80%)
- **Fast Execution**: Optimized for development workflow
- **Multiple Output Formats**: Console, JSON, HTML
- **GitHub Integration**: Automatic issue creation for failures
- **CI/CD Ready**: Optimized settings for automated execution
- **Fail-Fast Option**: Stop on first failure for rapid feedback

### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `TestCategory` | Test category (Unit, Integration, Critical, E2E, All) | Unit |
| `MinCoverage` | Minimum coverage percentage (0-100) | 80 |
| `FailFast` | Stop on first test failure | false |
| `ShowCoverage` | Display detailed coverage report | false |
| `CreateIssues` | Create GitHub issues for failures | false |
| `CI` | CI/CD optimized mode | false |
| `OutputFormat` | Output format (Console, JSON, HTML) | Console |

### Examples

```powershell
# Unit tests with 85% coverage requirement
./tests/Invoke-QuickTests.ps1 -TestCategory Unit -MinCoverage 85 -ShowCoverage

# Integration tests with GitHub issue creation
./tests/Invoke-QuickTests.ps1 -TestCategory Integration -CreateIssues -FailFast

# All tests with HTML report
./tests/Invoke-QuickTests.ps1 -TestCategory All -OutputFormat HTML -MinCoverage 90

# CI/CD mode
./tests/Invoke-QuickTests.ps1 -TestCategory Critical -CI -CreateIssues
```

## 🔧 Module Test Runner

The `Test-Module.ps1` script provides focused testing for individual modules with watch mode:

### Features

- **Module-Specific Testing**: Focus on individual modules for faster feedback
- **Watch Mode**: Continuous testing during development with file system monitoring
- **Coverage Analysis**: Optional code coverage for the specific module
- **Multiple Test Types**: Unit, Integration, or All tests for the module
- **Real-Time Feedback**: Immediate results during development
- **Minimal Setup**: Lightweight execution with minimal dependencies

### Parameters

| Parameter | Description | Required |
|-----------|-------------|----------|
| `ModuleName` | Name of module to test (e.g., 'Logging', 'PatchManager') | Yes |
| `TestType` | Type of tests (Unit, Integration, All) | No (Unit) |
| `Coverage` | Enable code coverage analysis | No |
| `Watch` | Run in watch mode for continuous testing | No |
| `Verbose` | Show detailed test output | No |

### Examples

```powershell
# Test specific module
./tests/Test-Module.ps1 -ModuleName Logging

# Test with coverage analysis
./tests/Test-Module.ps1 -ModuleName PatchManager -Coverage -Verbose

# Watch mode for continuous development
./tests/Test-Module.ps1 -ModuleName TestingFramework -Watch

# Integration tests for module
./tests/Test-Module.ps1 -ModuleName OpenTofuProvider -TestType Integration -Coverage
```

### Watch Mode Features

- **File System Monitoring**: Automatically detects changes in module files and tests
- **Throttled Execution**: Prevents multiple rapid test runs
- **Real-Time Feedback**: Immediate test results on file changes
- **Selective Monitoring**: Only watches relevant module and test files
- **Graceful Exit**: Ctrl+C to stop watching

## 🐛 GitHub Issue Integration

### Automatic Issue Creation

When tests fail, the production test runner automatically creates GitHub issues with:

- **Intelligent Analysis**: Error categorization and root cause analysis
- **Comprehensive Context**: System information, test environment details
- **Affected Files**: Automatically detected from stack traces
- **Priority Assignment**: Based on failure count and impact
- **Actionable Information**: Reproduction steps and suggested fixes

### Issue Features

- **Smart Grouping**: Multiple failures in the same file grouped into single issues
- **Rich Metadata**: Platform, PowerShell version, test context
- **Error Analysis**: Categorizes errors (timeout, permission, network, etc.)
- **Direct Links**: Links to test artifacts and reports
- **Auto-Labeling**: Appropriate labels based on failure analysis

### Configuration

Issues are created using PatchManager's enhanced `New-PatchIssue` function with:

```powershell
# Automatic issue creation for all failures
./tests/Run-ProductionTests.ps1 -CreateIssues

# Target specific repository
./tests/Run-ProductionTests.ps1 -CreateIssues -IssueRepository "myorg/myrepo"

# Preview without creating
./tests/Run-ProductionTests.ps1 -CreateIssues -DryRun
```

## 📊 Test Reports

### Report Formats

| Format | Description | Use Case |
|--------|-------------|----------|
| **JSON** | Structured data with full test details | Automation, APIs |
| **HTML** | Interactive dashboard with charts | Human review, presentations |
| **XML** | NUnit/JUnit compatible format | CI/CD integration |
| **CSV** | Tabular data for analysis | Data analysis, Excel |
| **Markdown** | Human-readable summary | Documentation, GitHub |

### HTML Report Features

- **Interactive Dashboard**: Charts, graphs, collapsible sections
- **Performance Analysis**: Duration distribution, slowest/fastest tests
- **Failure Details**: Expandable error information with stack traces
- **Theme Support**: Light/Dark/Auto themes
- **Mobile Responsive**: Works on all devices
- **Direct Links**: Links to created GitHub issues

### Sample Report Structure

```json
{
  "Summary": {
    "TotalTests": 156,
    "PassedTests": 142,
    "FailedTests": 14,
    "PassRate": 91.03,
    "Duration": { "TotalSeconds": 45.67, "Formatted": "45.67s" }
  },
  "Failures": [
    {
      "Name": "Test-OpenTofuProvider should validate configuration",
      "File": "OpenTofuProvider.Tests.ps1",
      "Error": { "Message": "Provider not found", "StackTrace": "..." }
    }
  ],
  "IssuesCreated": [
    {
      "IssueUrl": "https://github.com/org/repo/issues/123",
      "Title": "Test Failure: OpenTofu Provider Configuration"
    }
  ]
}
```

## 🔄 CI/CD Integration

### GitHub Actions Integration

The production test runner is integrated into the Intelligent CI/CD Pipeline:

```yaml
- name: Run Production Test Suite
  shell: pwsh
  run: |
    ./tests/Run-ProductionTests.ps1 `
      -TestSuite Critical `
      -CI `
      -CreateIssues `
      -GenerateHTML `
      -ShowCoverage `
      -UploadArtifacts
```

### Workflow Features

- **Cross-Platform Testing**: Runs on Windows, Linux, macOS
- **Artifact Upload**: All reports uploaded as build artifacts
- **PR Comments**: Test summaries posted to pull requests
- **Failure Recovery**: Issues created even if test execution fails
- **Smart Caching**: PowerShell modules cached for performance

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `GITHUB_TOKEN` | GitHub API access (automatically provided) | `${{ secrets.GITHUB_TOKEN }}` |
| `PESTER_RUN` | Marks test environment | `true` |
| `CI` | CI/CD mode indicator | `true` |

## 🎯 Test Suite Organization

### Critical Infrastructure Tests

Located in `tests/Critical/`, these are the most important tests covering:

- **Core Application**: aither-core.ps1 initialization and module loading
- **Cross-Platform**: Path handling, environment detection
- **Git Integration**: Repository detection, branch sync, PR/issue creation
- **OpenTofu Provider**: Infrastructure deployment operations
- **API/Non-Interactive**: Automation scenarios, error propagation
- **Build Integrity**: Package creation, license tier filtering
- **E2E Release**: Installation, upgrade, production scenarios

### Test Categories

| Category | Description | Location |
|----------|-------------|----------|
| **Unit** | Individual function/module tests | `tests/Unit/` |
| **Integration** | Multi-component interaction tests | `tests/Integration/` |
| **E2E** | End-to-end workflow tests | `tests/E2E/` |
| **Performance** | Performance and load tests | `tests/Performance/` |
| **Critical** | Production-critical infrastructure tests | `tests/Critical/` |

## 🛠️ Development Guidelines

### Writing Tests

1. **Follow Pester 5.x conventions**
2. **Use BeforeDiscovery for setup validation**
3. **Include proper tags for categorization**
4. **Mock external dependencies appropriately**
5. **Provide descriptive test names and contexts**

### Test Structure Example

```powershell
BeforeDiscovery {
    $script:TestAppName = 'MyComponent'
    # Verify test prerequisites
}

Describe 'MyComponent - Critical Infrastructure Testing' -Tags @('Critical', 'Infrastructure', 'MyComponent') {
    BeforeAll {
        # Import test utilities
        . "$PSScriptRoot/../Shared/Test-Utilities.ps1"
        
        # Set up test environment
        $script:TestWorkspace = New-TestWorkspace -TestName 'mycomponent-tests'
    }
    
    Context 'Feature Testing' {
        It 'Should perform expected operation' {
            # Test implementation
        }
    }
    
    AfterAll {
        # Cleanup test environment
    }
}
```

### Best Practices

- **Isolated Environments**: Use test workspaces for isolation
- **Comprehensive Mocking**: Mock external dependencies
- **Clear Assertions**: Use descriptive Should statements
- **Proper Cleanup**: Always clean up test artifacts
- **Error Scenarios**: Test both success and failure paths

## 📈 Performance Considerations

### Test Execution Times

| Test Suite | Typical Duration | Use Case |
|------------|------------------|----------|
| Module Test Runner | 5-30 seconds | Individual module development |
| Quick Test Runner | 1-3 minutes | Unit/Integration with coverage |
| Release Validation (Quick) | ~5 minutes | Basic release validation |
| Release Validation (Standard) | ~15 minutes | Standard release validation |
| Release Validation (Complete) | ~30 minutes | Comprehensive release validation |
| Release Validation (Production) | ~60 minutes | Full production validation |
| Quick Validation | ~30 seconds | Development, commits |
| Standard Validation | 2-5 minutes | Pre-PR, daily testing |
| Complete Validation | 10-15 minutes | Release preparation |
| Critical Tests | 3-8 minutes | Production validation |

### Optimization Tips

- **Parallel Execution**: Use `-Parallel` for independent tests
- **Smart Filtering**: Use tags to run specific test subsets
- **Cached Dependencies**: Leverage module caching in CI/CD
- **Minimal Setup**: Only set up what each test needs

## 🔧 Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| GitHub CLI not found | Install GitHub CLI and authenticate |
| PowerShell 5.1 vs 7.0+ | Tests require PowerShell 7.0+ |
| Module import failures | Check PROJECT_ROOT and PWSH_MODULES_PATH |
| Permission errors | Run with appropriate permissions |
| Network timeouts | Check proxy settings and connectivity |

### Debug Mode

```powershell
# Run with maximum detail
./tests/Run-ProductionTests.ps1 -ReportLevel Diagnostic -Verbose

# Check specific test files
./tests/Run-ProductionTests.ps1 -IncludeTags @('MyTag') -ReportLevel Detailed
```

### Log Analysis

Test logs are automatically created in:
- `tests/TestResults/production-test-[date].log`
- Individual test file outputs in test results

## 🔗 Related Documentation

- [AitherZero CLAUDE.md](../CLAUDE.md) - Development guidelines
- [PatchManager Documentation](../aither-core/modules/PatchManager/README.md) - Git workflow automation
- [CI/CD Pipeline](./.github/workflows/intelligent-ci.yml) - Automated testing workflow
- [Build System](../build/README.md) - Package creation and distribution

## 📞 Support

For testing-related issues:

1. **Review test logs** in `tests/TestResults/`
2. **Check GitHub issues** for similar problems
3. **Run with diagnostic reporting** for detailed information
4. **Create an issue** with test failure details

---

*This testing infrastructure provides comprehensive validation for AitherZero's production deployment and ensures reliable infrastructure automation.*