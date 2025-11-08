# Fingerprint Algorithm Test Suite

This test suite validates the enhanced fingerprinting algorithm used for issue deduplication in the Phase 2 Intelligent Issue Creation workflow.

## Purpose

The fingerprint algorithm creates stable, normalized hashes of test failures, errors, and issues to prevent duplicate issue creation. This test suite ensures:

1. **Stability**: Same errors with different volatile data (timestamps, line numbers, GUIDs) produce the same fingerprint
2. **Uniqueness**: Different errors produce different fingerprints
3. **Normalization**: Various forms of the same error are properly normalized

## Running the Tests

### Prerequisites

- Node.js (v14 or higher)

### Execute Tests

```bash
# From repository root
node tests/test-fingerprint-algorithm.js

# Or if marked executable
./tests/test-fingerprint-algorithm.js
```

### Expected Output

```
🧪 Testing Enhanced Fingerprint Algorithm

======================================================================

Test 1: Same error different line numbers should match
  Fingerprint 1: 97f7b8172042f93e
  Fingerprint 2: 97f7b8172042f93e
  Expected: MATCH
  Actual: MATCH
  Result: ✅ PASS

... (more tests)

======================================================================

📊 Test Results: 7 passed, 0 failed out of 7 tests

✅ All tests passed! Fingerprint algorithm is working correctly.
```

## Test Cases

### 1. Line Number Variations
**Validates**: Same error at different line numbers produces same fingerprint
```javascript
"Expected 'true' but got 'false' at line 42"
"Expected 'true' but got 'false' at line 87"
// Should MATCH
```

### 2. Timestamp Variations
**Validates**: Same error with different timestamps produces same fingerprint
```javascript
"Certificate validation failed on 2025-11-01T10:30:45"
"Certificate validation failed on 2025-11-02T15:22:13"
// Should MATCH
```

### 3. GUID Variations
**Validates**: Same error with different GUIDs produces same fingerprint
```javascript
"Resource not found: a1b2c3d4-e5f6-7890-abcd-ef1234567890"
"Resource not found: 9f8e7d6c-5b4a-3210-fedc-ba0987654321"
// Should MATCH
```

### 4. Different Files
**Validates**: Same error in different files produces different fingerprints
```javascript
File: "aithercore/infrastructure/VmManagement.psm1", Error: "Failed to create VM"
File: "aithercore/security/CertificateManagement.psm1", Error: "Failed to create VM"
// Should NOT MATCH
```

### 5. Different Errors
**Validates**: Different errors in same file produce different fingerprints
```javascript
File: "tests/unit/Logging.Tests.ps1", Error: "Expected log level INFO"
File: "tests/unit/Logging.Tests.ps1", Error: "Expected log level ERROR"
// Should NOT MATCH
```

### 6. Parameterized Tests
**Validates**: Same test with different parameters produces same fingerprint
```javascript
"Should validate input [TestCase1]"
"Should validate input [TestCase2]"
// Should MATCH
```

### 7. Path Variations
**Validates**: Absolute vs relative paths produce same fingerprint
```javascript
"/home/runner/work/AitherZero/AitherZero/aithercore/experience/UserInterface.psm1"
"aithercore/experience/UserInterface.psm1"
// Should MATCH
```

## Normalization Rules

The fingerprinting algorithm applies these normalization rules:

### File Paths
- Normalizes path separators (`\` → `/`)
- Removes absolute path prefixes
- Keeps relative structure from key directories
- Converts to lowercase

### Error Messages
- Replaces GUIDs with `GUID`
- Replaces ISO timestamps with `TIMESTAMP`
- Replaces dates with `DATE`
- Replaces hashes with `HASH`
- Normalizes line numbers to `line N`
- Normalizes position references to `at N:N`
- Replaces all remaining numbers with `N`
- Normalizes whitespace

### Test Names
- Removes parameterized test data in brackets
- Removes numbers between words
- Converts to lowercase

## Adding New Tests

To add a new test case:

```javascript
{
  name: "Description of what this test validates",
  failure1: {
    File: "path/to/file.ps1",
    ErrorMessage: "Error message variant 1",
    TestType: "Unit"
  },
  failure2: {
    File: "path/to/file.ps1",
    ErrorMessage: "Error message variant 2",
    TestType: "Unit"
  },
  shouldMatch: true  // or false
}
```

## Integration with Workflow

This test suite validates the same algorithm used in:
- `.github/workflows/phase2-intelligent-issue-creation.yml`
- Job: `intelligent-issue-grouping`
- Function: `createFingerprint()`

The test implementation mirrors the workflow implementation to ensure consistency.

## Troubleshooting

### Test Failures

If tests fail:

1. **Check the debug output**: Failed tests show the normalized data for both failures
2. **Verify normalization rules**: Ensure the expected normalization is working
3. **Check regex ordering**: Specific patterns must be replaced before general ones
4. **Compare with workflow**: Ensure test matches workflow implementation

### Common Issues

**Problem**: GUIDs not matching
**Solution**: Ensure GUID regex runs before general number replacement

**Problem**: Timestamps not matching
**Solution**: Ensure timestamp regex includes optional milliseconds and timezone

**Problem**: Paths not matching
**Solution**: Ensure absolute path prefixes are removed correctly

## CI/CD Integration

This test can be integrated into CI/CD pipelines:

```yaml
- name: Test Fingerprint Algorithm
  run: node tests/test-fingerprint-algorithm.js
```

Exit code:
- `0`: All tests pass
- `1`: One or more tests fail

## Maintenance

When updating the fingerprinting algorithm:

1. Update the workflow implementation first
2. Update this test file to match
3. Run tests to validate
4. Update test cases if needed
5. Document any new normalization rules

## Related Documentation

- `.github/ISSUE-CREATION-FIX-2025-11-02.md` - Implementation details
- `.github/VALIDATION-REPORT-2025-11-02.md` - Validation results
- `.github/workflows/phase2-intelligent-issue-creation.yml` - Production implementation
