# Fix for Duplicate Test Failure Issues

**Date**: November 2, 2025
**Issue**: Multiple duplicate issues being created for "Should execute in test mode"

## Problem

Duplicate issues were being created with identical titles like:
- Issue #1847: `🧪 Test Failure: Should execute in test mode`
- Issue #1849: `🧪 Test Failure: Should execute in test mode`
- Issue #1850: `🧪 Test Failure: Should execute in test mode`
- ...and more

## Root Cause

The fingerprinting algorithm was not generating unique fingerprints for test failures when:
1. The test file information was missing (File = "Unknown")
2. Multiple tests had the same generic test name
3. Error messages were similar after normalization

This resulted in:
```javascript
fingerprintData = {
  file: "unknown",
  testName: "should execute in test mode",
  error: "test failed",
  // ... same for all failures
}
// Result: Same fingerprint → treated as same issue
```

## Solution

Enhanced the fingerprinting algorithm to include stack trace hash when file information is missing:

### Before
```javascript
const fingerprintData = {
  type: failure.Type || failure.TestType || 'unknown',
  file: normalizeFile(failure.File),
  error: normalizeError(failure.ErrorMessage || failure.Message),
  category: failure.Category || failure.RuleName || 'general',
  testName: failure.TestName ? normalizeTestName(failure.TestName) : undefined
};
```

### After
```javascript
const fingerprintData = {
  type: failure.Type || failure.TestType || 'unknown',
  file: normalizeFile(failure.File),
  error: normalizeError(failure.ErrorMessage || failure.Message),
  category: failure.Category || failure.RuleName || 'general',
  testName: failure.TestName ? normalizeTestName(failure.TestName) : undefined,
  // NEW: Add stack trace hash for additional uniqueness when file is unknown
  stackHash: (failure.StackTrace && failure.File === 'Unknown') 
    ? crypto.createHash('md5').update(failure.StackTrace).digest('hex').substring(0, 8)
    : undefined
};
```

## How It Works

1. **When file is known**: Fingerprint uses file path as primary discriminator (works well)
2. **When file is "Unknown"**: Now includes an MD5 hash of the stack trace (first 8 chars)
   - Different stack traces → different hashes → unique fingerprints
   - Same actual failure → same stack trace → same hash → deduplicated correctly

## Example Scenario

**Scenario**: Three test failures with same name but different contexts

### Failure 1
- Test: "Should execute in test mode"
- File: "Unknown"
- Stack: `at run-test.ps1:42\nat execute-mode.ps1:15`
- StackHash: `a1b2c3d4`
- **Fingerprint**: `abc123...` (includes a1b2c3d4)

### Failure 2
- Test: "Should execute in test mode"
- File: "Unknown"
- Stack: `at run-test.ps1:42\nat execute-mode.ps1:15`
- StackHash: `a1b2c3d4` (same as Failure 1)
- **Fingerprint**: `abc123...` (same - correctly deduplicated!)

### Failure 3
- Test: "Should execute in test mode"  
- File: "Unknown"
- Stack: `at different-test.ps1:28\nat another-mode.ps1:9`
- StackHash: `e5f6g7h8` (different stack)
- **Fingerprint**: `def456...` (different - separate issue!)

## Impact

- **Prevents duplicate issues** when file information is missing
- **Maintains deduplication** for truly identical failures
- **No change** to behavior when file information is present (existing logic unchanged)
- **Backward compatible**: Only adds additional uniqueness when needed

## Testing

All existing tests still pass (7/7):
- ✅ Same error different line numbers → MATCH
- ✅ Same error different timestamps → MATCH
- ✅ Same error different GUIDs → MATCH
- ✅ Different files → NO MATCH
- ✅ Different errors → NO MATCH
- ✅ Parameterized test names → MATCH
- ✅ Absolute vs relative paths → MATCH

## Logging Enhancement

Added `hasStackHash` to debug output:
```javascript
console.log(`  Generated fingerprint ${fingerprint} for:`, {
  file: fingerprintData.file,
  type: fingerprintData.type,
  category: fingerprintData.category,
  testName: fingerprintData.testName,
  hasStackHash: !!fingerprintData.stackHash  // NEW
});
```

This helps identify when stack trace hashing is being used for differentiation.

## Related Issues

This fix addresses the duplicate issue problem seen with:
- #1847, #1849, #1850, #1851, #1852, #1853, #1854 - All "Should execute in test mode"

These should now be properly deduplicated or distinguished based on their actual stack traces.
