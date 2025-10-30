# Test Discovery Fix - November 2025

## Problem Summary

Only 12 test cases were being executed from ~2,400+ available tests across 288 test files (142 Unit | 139 Integration). The dashboard showed confusing metrics that didn't clearly distinguish between available test infrastructure and actual test execution.

## Root Causes

### 1. Missing Filter Configuration
The `config.psd1` file was missing the `Filter` configuration section under `Testing.Pester`. Without this configuration, the test runner fell back to default restrictive filters.

### 2. Tag Filter Logic Bug  
The logic in `0402_Run-UnitTests.ps1` had a bug when handling empty tag arrays:
```powershell
# BUG: This treats empty array as "not configured"
if ($pesterSettings.Filter.Tag -and $pesterSettings.Filter.Tag.Count -gt 0) {
    # Use configured tags
} else {
    # Falls back to @('Unit') - too restrictive!
}
```

### 3. Property Check Method
Using `PSObject.Properties` check instead of `ContainsKey()` for hashtable property detection:
```powershell
# WRONG for hashtables
if ($pesterSettings.Filter.PSObject.Properties['Tag'] -ne $null)

# CORRECT for hashtables  
if ($pesterSettings.Filter.ContainsKey('Tag'))
```

### 4. Dashboard Label Confusion
Labels didn't clearly distinguish:
- **Test Files**: 288 available test files
- **Test Cases**: ~2,400+ potential test cases (It blocks)
- **Executed Tests**: Only 12 actually ran

## Solutions Implemented

### 1. Added Filter Configuration (`config.psd1`)
```powershell
Pester = @{
    # ... other settings ...
    
    # Filter settings - control which tests to run
    Filter = @{
        Tag = @()  # Empty array = run ALL tests
        ExcludeTag = @('Skip', 'Disabled')  # Only exclude explicitly disabled
    }
}
```

**Key Insight**: Empty `Tag` array means "no filter" - run all tests regardless of tags.

### 2. Fixed Tag Filter Logic (`0402_Run-UnitTests.ps1`)
```powershell
# FIXED: Check if property exists first, then handle empty array
if ($pesterSettings.Filter.ContainsKey('Tag')) {
    $pesterConfig.Filter.Tag = $pesterSettings.Filter.Tag
    if ($pesterSettings.Filter.Tag.Count -eq 0) {
        Write-ScriptLog -Message "Running all tests - no tag filter applied"
    }
} else {
    # Only use default when not configured at all
    $pesterConfig.Filter.Tag = @('Unit')
}
```

### 3. Updated Dashboard Labels (`0512_Generate-Dashboard.ps1`)

**Before**:
```
🧪 Test Suite: 281
✅ 12 Passed | ❌ 0 Failed
```

**After**:
```
🧪 Test Files: 288 (142 Unit | 139 Integration)
Last Test Run Results:
✅ 12 Passed | ❌ 0 Failed
⚠️ Only 12 test cases executed. Run ./az 0402 for full test suite.
```

## How to Verify the Fix

### 1. Run Full Test Suite
```powershell
./az 0402
```
Expected: ~2,400+ tests discovered and executed

### 2. Check Configuration
```powershell
$config = Import-PowerShellDataFile ./config.psd1
$config.Testing.Pester.Filter.Tag
# Should output: (empty array)
```

### 3. Generate Dashboard
```powershell
./az 0512
```
Check dashboard shows:
- Clear distinction between test files vs executed tests
- Warning if partial run detected

## Configuration Options

### Run All Tests (Current Default)
```powershell
Filter = @{
    Tag = @()  # No filtering
    ExcludeTag = @('Skip', 'Disabled')
}
```

### Run Only Unit Tests
```powershell
Filter = @{
    Tag = @('Unit')
    ExcludeTag = @('Integration', 'E2E', 'Performance')
}
```

### Run Specific Categories
```powershell
Filter = @{
    Tag = @('Core', 'Infrastructure')
    ExcludeTag = @('Slow', 'Manual')
}
```

## Testing Strategy

### Unit Tests (`./tests/unit`)
- Fast, isolated tests
- Mock external dependencies
- Should run in < 5 minutes total
- Tag: `Unit`

### Integration Tests (`./tests/integration`)  
- Test component integration
- May require external resources
- Longer execution time
- Tag: `Integration`

### Tag Usage
All test files should have appropriate tags in their `Describe` blocks:
```powershell
Describe 'MyComponent' -Tag 'Unit', 'Core' {
    It 'should do something' {
        # Test code
    }
}
```

## Key Takeaways

1. **Empty array `@()` in Pester Filter.Tag means "run everything"** - not "use default"
2. **Use `ContainsKey()` for hashtables**, not `PSObject.Properties`
3. **Dashboard labels matter** - distinguish between infrastructure and execution
4. **Explicit configuration** prevents unexpected defaults
5. **Test discovery** depends on proper tag filtering configuration

## Related Files

- `/config.psd1` - Main configuration with Pester settings
- `/automation-scripts/0402_Run-UnitTests.ps1` - Unit test execution script
- `/automation-scripts/0512_Generate-Dashboard.ps1` - Dashboard generation
- `/tests/unit/` - Unit test files (142 files)
- `/tests/integration/` - Integration test files (139 files)

## References

- Pester Documentation: https://pester.dev/docs/usage/configuration
- AitherZero Test Architecture: `/docs/TESTING.md`
- Automation Scripts Guide: `/docs/AUTOMATION-SCRIPTS.md`
