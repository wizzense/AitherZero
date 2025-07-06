# /test

Unified testing interface for AitherZero - run tests, generate coverage reports, and validate changes before commits.

## Usage
```
/test [action] [options]
```

## Actions

### `run` - Run test suites (default)
Execute specific test suites with real-time progress tracking and detailed reporting.

**Options:**
- `--suite [quick|core|setup|all]` - Test suite to run (default: quick)
- `--module "module-name"` - Test specific module
- `--coverage` - Generate coverage report
- `--watch` - Watch mode for continuous testing
- `--parallel` - Run tests in parallel
- `--verbose` - Detailed test output
- `--ci` - CI mode (optimized for pipelines)

**Examples:**
```bash
/test run --suite quick
/test run --suite core --coverage
/test run --module PatchManager --verbose
/test run --suite all --parallel --ci
```

### `validate` - Pre-commit validation
Comprehensive validation before committing changes, including syntax, style, and functionality checks.

**Options:**
- `--files "pattern"` - Validate specific files
- `--fix` - Auto-fix minor issues
- `--strict` - Strict validation mode
- `--skip-slow` - Skip time-consuming tests

**Examples:**
```bash
/test validate
/test validate --files "*.ps1" --fix
/test validate --strict --skip-slow
```

### `coverage` - Coverage analysis
Analyze and report test coverage across modules and functions.

**Options:**
- `--format [console|html|json|cobertura]` - Output format
- `--threshold [percentage]` - Minimum coverage threshold
- `--module "module-name"` - Module-specific coverage
- `--open` - Open HTML report in browser

**Examples:**
```bash
/test coverage --format html --open
/test coverage --threshold 80 --module LabRunner
/test coverage --format cobertura --ci
```

### `benchmark` - Performance testing
Run performance benchmarks and compare with baselines.

**Options:**
- `--baseline "name"` - Compare with named baseline
- `--save "name"` - Save results as new baseline
- `--iterations [number]` - Test iterations (default: 10)
- `--warmup [number]` - Warmup iterations (default: 3)

**Examples:**
```bash
/test benchmark
/test benchmark --baseline v1.0 --iterations 20
/test benchmark --save current --warmup 5
```

### `integration` - Integration testing
Test integration between modules and external systems.

**Options:**
- `--environment [local|staging|production]` - Target environment
- `--external` - Include external service tests
- `--timeout [seconds]` - Test timeout (default: 300)
- `--retry [count]` - Retry failed tests

**Examples:**
```bash
/test integration --environment staging
/test integration --external --timeout 600
/test integration --retry 3
```

### `status` - Test status and history
View test results, trends, and CI/CD pipeline status.

**Options:**
- `--history [days]` - Show history (default: 7)
- `--failed` - Show only failed tests
- `--trends` - Display trend analysis
- `--ci` - Include CI/CD status

**Examples:**
```bash
/test status
/test status --history 30 --trends
/test status --failed --ci
```

## Test Suites

### Quick Tests (~30 seconds)
- Core functionality validation
- Module loading verification
- Basic integration checks
- Syntax validation

### Core Tests (~2 minutes)
- Comprehensive module testing
- Function-level validation
- Error handling verification
- Cross-platform compatibility

### Setup Tests (~1 minute)
- Installation validation
- Environment setup checks
- Dependency verification
- Configuration validation

### All Tests (~5 minutes)
- Complete test suite
- Integration testing
- Performance benchmarks
- Security validation

## Integration Features

### GitHub Actions Integration
- Automatic test runs on PR creation
- Coverage reports in PR comments
- Status checks for merge protection
- Performance regression detection

### VS Code Integration
- Test explorer integration
- Inline test results
- Coverage highlighting
- Quick test actions

### PatchManager Integration
- Pre-patch validation
- Post-patch verification
- Automatic test runs in workflows
- Rollback on test failures

## Advanced Features

### Smart Test Selection
- Run only affected tests based on changes
- Dependency-aware test execution
- Historical failure analysis
- Risk-based test prioritization

### Parallel Execution
- Automatic test distribution
- Resource-aware parallelization
- Result aggregation
- Load balancing

### Test Data Management
- Isolated test environments
- Automatic cleanup
- Mock data generation
- State restoration

### Reporting and Analytics
- Detailed HTML reports
- Trend analysis dashboards
- Failure pattern detection
- Performance tracking

## Configuration

### Test Configuration File
```powershell
# .aither-test.json
{
  "defaults": {
    "suite": "quick",
    "parallel": true,
    "coverage": {
      "enabled": true,
      "threshold": 75
    }
  },
  "modules": {
    "PatchManager": {
      "timeout": 120,
      "retries": 2
    }
  }
}
```

### Environment Variables
- `AITHER_TEST_SUITE` - Default test suite
- `AITHER_TEST_PARALLEL` - Enable parallel execution
- `AITHER_TEST_VERBOSE` - Verbose output
- `AITHER_TEST_CI` - CI mode

## Best Practices

1. **Run quick tests before commits** - Catch issues early
2. **Use coverage reports** - Maintain code quality
3. **Monitor trends** - Identify degradation patterns
4. **Test in isolation** - Prevent side effects
5. **Automate validation** - Integrate with workflows

## Troubleshooting

### Common Issues
- **Module not found**: Ensure proper module installation
- **Test timeout**: Increase timeout or optimize tests
- **Coverage gaps**: Add tests for uncovered code
- **Flaky tests**: Use retry mechanism or fix root cause

### Debug Mode
```bash
/test run --suite core --verbose --debug
```

This provides detailed logging, stack traces, and diagnostic information for troubleshooting test failures.