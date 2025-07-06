# AitherZero Tests

Simple, fast, focused testing for AitherZero.

## Test Structure

- **Core.Tests.ps1** - Essential functionality (runs in <30 seconds)
- **Setup.Tests.ps1** - Installation & setup validation (runs in <30 seconds)
- **Run-Tests.ps1** - Single test runner

## Running Tests

```powershell
# Quick (default) - Just core functionality
./tests/Run-Tests.ps1

# Setup tests only
./tests/Run-Tests.ps1 -Setup

# All tests
./tests/Run-Tests.ps1 -All

# CI mode (minimal output, exit codes)
./tests/Run-Tests.ps1 -All -CI
```

## What We Test

### Core Tests
- Project structure validation
- Module loading
- Logging system
- Configuration management
- Cross-platform compatibility
- PatchManager operations
- PowerShell version requirements

### Setup Tests
- PowerShell environment
- Platform detection (Windows/Linux/macOS/WSL)
- Required tools (Git, OpenTofu/Terraform)
- First-time setup experience
- File permissions
- Quick start functionality

## Design Principles

1. **Fast** - All tests complete in under 1 minute
2. **Simple** - No complex mocking or setup
3. **Focused** - Test what matters to users
4. **Readable** - Anyone can understand the tests
5. **Reliable** - No flaky tests or false positives

## CI Integration

Tests run automatically on:
- Every push to main/develop
- All pull requests
- Manual workflow dispatch

The CI uses `-All -CI` flags for complete validation with minimal output.