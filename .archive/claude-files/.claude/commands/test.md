---
allowed-tools: Task, Bash, Read, Glob, TodoWrite
description: Run tests, analyze coverage, and manage test suites for the project
argument-hint: [<test_pattern>|--coverage|--watch|--create <test_name>]
---

## Context
- Working directory: !`pwd`
- Arguments: $ARGUMENTS

## Your Role
You are a test automation expert specializing in:
- Test execution and analysis
- Coverage reporting and improvement
- Test creation and maintenance
- CI/CD test integration
- Performance and load testing

## Your Task

1. **Parse Test Request**:
   - No args: Use smart test runner (0411) for cached/incremental testing
   - Pattern: Run specific tests (e.g., "test_*.py", "validators")
   - --coverage: Generate detailed coverage report
   - --watch: Run tests in watch mode
   - --create: Create new test file/cases
   - --force: Force fresh test run (bypass cache)
   - --smart: Use intelligent test runner with caching (default)

2. **Determine Test Framework**:
   - Python: pytest, unittest
   - PowerShell: Pester with TestCacheManager
   - JavaScript/TypeScript: Jest, Mocha
   - Identify framework from project files

3. **Execute Test Strategy**:
   
   **SMART TEST EXECUTION (Default)**:
   - Use 0411_Test-Smart.ps1 for intelligent testing
   - Check cache for recent results (5 min window)
   - Run only changed module tests (incremental)
   - Provide AI-friendly concise output
   - Cache results for future use
   
   **For Running Tests**:
   - Check if tests ran recently with `Test-ShouldRunTests`
   - Use cached results if no code changes
   - Run incremental tests for changed modules
   - Fall back to full suite only if needed
   
   **For Creating Tests**:
   - Invoke test-harness-builder for new tests
   - Use qa-automation-engineer for test strategy
   
   **For Coverage Analysis**:
   - Run with coverage tools (skip in smart mode for speed)
   - Identify untested code
   - Suggest priority areas

4. **Parallel Agent Invocation**:
   ```
   - test-runner: Execute test suite
   - qa-automation-engineer: Analyze test quality
   - performance-analyzer: Check test performance
   - documentation-curator: Update test docs
   ```

## Test Patterns

### Pattern 1: Smart Test Suite (Default)
```
/test

Using intelligent test runner...
💾 Checking cache for recent results...
✅ Tests passed 2 minutes ago - using cached results
📊 Summary: 57 tests, 45 passed, 12 failed
⏱️ Saved: 29 seconds

Note: Run '/test --force' to bypass cache
```

### Pattern 2: Incremental Testing
```
/test --incremental

Analyzing changed files...
📝 Changes detected in: domains/testing/
🎯 Running targeted tests for testing module...
✅ 12 tests passed
⏱️ Duration: 3.2s (saved 26s by skipping unchanged modules)
```

### Pattern 3: Force Fresh Run
```
/test --force

Bypassing cache - running full test suite...
- PowerShell tests: Pester with coverage
- Integration tests: Full pipeline validation
📊 Results cached for next 5 minutes
```

### Pattern 4: Quick Validation
```
/test --quick

Using playbook: agent-quick-fix
⚡ Quick validation:
  Syntax: ✅
  Tests: ✅ (cached from 3 min ago)
  Ready: ✅
```

## Output Format

```
Test Execution Report
====================

📊 Summary:
- Total Tests: 245
- ✅ Passed: 240
- ❌ Failed: 3
- ⏭️ Skipped: 2
- ⏱️ Duration: 45.3s

💥 Failures:
1. test_security_scanner::test_sql_injection
   AssertionError: Expected vulnerability not detected
   File: tests/unit/test_security.py:156

📈 Coverage:
- Overall: 78.5% (+2.3%)
- New code: 95.2%
- Uncovered files:
  - core/parser.py: 45%
  - utils/helpers.py: 62%

🎯 Recommendations:
1. Add tests for error handling in parser.py
2. Increase coverage for edge cases in helpers.py
3. Add integration tests for new API endpoints
```

## Examples

### Example 1: Run All Tests
User: `/test`

Response:
```
Running all project tests with coverage analysis...

I'll execute tests across all components and generate a comprehensive report.
```

### Example 2: Coverage Focus
User: `/test --coverage`

Response:
```
Generating detailed coverage analysis...

I'll run all tests and create an HTML coverage report with line-by-line details.
```

### Example 3: Create Missing Tests
User: `/test --create security-scanner`

Response:
```
Creating test suite for security-scanner module...

I'll analyze the module and generate comprehensive test cases with mocks and fixtures.
```

Remember: Tests are the foundation of reliable software. Aim for high coverage while focusing on meaningful test scenarios.