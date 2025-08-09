---
name: Test Failure
about: Report test failures from automated test runs
title: '[TEST] '
labels: test-failure, automated
assignees: ''

---

## Test Failure Summary
<!-- Brief description of which tests are failing -->

## Test Execution Context
**Test Type:** <!-- Unit/Integration/Performance/E2E -->
**Test Profile:** <!-- Quick/Standard/Full/CI -->
**Test Framework:** <!-- Pester/PSScriptAnalyzer/Other -->
**Execution Time:** <!-- When did the tests run? -->

## Failed Test Details
```powershell
# Test command used
seq 0402  # or specific test command

# Test output
Describing [Module/Function Name]
  Context [Test Context]
    [-] Test case name
      Expected: [expected value]
      But was: [actual value]
      at line: [file:line]
```

## Test Statistics
- **Total Tests:** <!-- Number -->
- **Passed:** <!-- Number -->
- **Failed:** <!-- Number -->
- **Skipped:** <!-- Number -->
- **Coverage:** <!-- Percentage if available -->

## Error Analysis
```powershell
# Stack trace or error details
```

## Affected Components
- [ ] Module: <!-- Module name -->
- [ ] Function: <!-- Function name -->
- [ ] Script: <!-- Script number/name -->

## Test History
- [ ] This test was passing previously
- [ ] This is a new test
- [ ] This is an intermittent failure
- [ ] This fails consistently

## Environment
**PowerShell Version:** <!-- $PSVersionTable.PSVersion -->
**OS:** <!-- Windows/Linux/macOS -->
**AitherZero Version:** <!-- Get-Content ./VERSION -->

## Reproduction Steps
```powershell
# Initialize environment
./Initialize-AitherModules.ps1

# Run specific test
Invoke-Pester -Path "./tests/path/to/test.ps1"
```

## Test Report Location
<!-- Path to HTML/JSON test report if generated -->
`./tests/reports/[timestamp]/`

## AI Context for Resolution
**Failure Pattern:** <!-- Describe any patterns in failures -->
**Recent Changes:** <!-- git log --oneline -5 -->
**Related Files:** <!-- List files that might need fixing -->