# Logging Module Tests

This directory contains tests for the Logging module using the Pester testing framework.

## Test Files

- `Logging.Tests.ps1` - Main test suite for the Logging module

## Running Tests

```powershell
# Run all logging tests
Invoke-Pester -Path ./Logging.Tests.ps1

# Run with detailed output
Invoke-Pester -Path ./Logging.Tests.ps1 -Output Detailed

# Run specific test tags
Invoke-Pester -Path ./Logging.Tests.ps1 -Tag "Unit"
```

## Test Coverage

The test suite covers:
- Basic logging functionality
- Log level filtering
- Context-aware logging
- Bulk logging operations
- Error handling
- Performance testing

## Adding New Tests

When adding new functions to the Logging module, ensure you add corresponding tests:

1. Follow the existing test structure
2. Use descriptive test names
3. Include both positive and negative test cases
4. Test edge cases and error conditions
5. Use appropriate test tags for categorization