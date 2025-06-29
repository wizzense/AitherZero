# PatchManager and ProgressTracking Integration

## Overview

The PatchManager module has been enhanced with optional ProgressTracking integration to provide visual feedback during patch operations. This integration is completely optional and non-breaking - the PatchManager will function normally whether or not the ProgressTracking module is available.

## Features

### Visual Progress Indicators

When the ProgressTracking module is available, PatchManager operations will show:

1. **Progress bars** with percentage completion
2. **Current operation stage** descriptions
3. **Time elapsed** and **ETA** calculations
4. **Step-by-step status updates**
5. **Summary reports** upon completion

### Supported Operations

Progress tracking has been integrated into the following PatchManager functions:

#### 1. Invoke-PatchWorkflow
Shows progress for:
- Conflict checking
- Stashing uncommitted changes
- Creating patch branches
- Running tests
- Creating GitHub issues
- Applying patch changes
- Committing and sanitizing files
- Creating pull requests
- PR consolidation (if enabled)

#### 2. Invoke-PatchRollback
Shows progress for:
- Environment validation
- Creating backup branches
- Performing rollback operations
- Finalizing changes

#### 3. Nested Operations
When New-PatchIssue and New-PatchPR are called from within Invoke-PatchWorkflow, they contribute status updates to the parent operation's progress display.

## Usage

### Basic Usage (Automatic)

No changes are required to use progress tracking. Simply ensure both modules are loaded:

```powershell
Import-Module PatchManager -Force
Import-Module ProgressTracking -Force

# Progress will automatically be shown
Invoke-PatchWorkflow -PatchDescription "My changes" -PatchOperation {
    # Your changes here
}
```

### Without Progress Tracking

The PatchManager works normally without ProgressTracking:

```powershell
# Only import PatchManager
Import-Module PatchManager -Force

# Works exactly the same, just without visual progress
Invoke-PatchWorkflow -PatchDescription "My changes" -PatchOperation {
    # Your changes here
}
```

## Implementation Details

### Conditional Loading

The integration uses a private helper module (`Initialize-ProgressTracking.ps1`) that:
1. Checks if the ProgressTracking module is available
2. Loads it if found
3. Provides wrapper functions that gracefully handle its absence

### Progress-Aware Logging

A new `Write-PatchProgressLog` function ensures that log messages don't interfere with progress displays when active.

### Progress Calculation

Each operation calculates its total steps dynamically based on:
- Which optional features are enabled (issues, PRs, tests)
- The complexity of the operation
- User-specified parameters

### Error Handling

Progress tracking includes error awareness:
- Errors are tracked and displayed in the summary
- Progress completes even if operations fail
- Error messages are preserved in the progress display

## Testing

A test script is provided to verify the integration:

```powershell
# Test with progress tracking
./tests/Test-PatchManagerProgress.ps1

# Test without progress tracking
./tests/Test-PatchManagerProgress.ps1 -WithoutProgress

# Test error handling
./tests/Test-PatchManagerProgress.ps1 -SimulateError
```

## Benefits

1. **Better User Experience**: Users can see what's happening during long operations
2. **Time Estimates**: ETAs help users plan their work
3. **Non-Intrusive**: Completely optional with no breaking changes
4. **Informative**: Progress descriptions explain each stage
5. **Error Visibility**: Problems are highlighted in the progress display

## Technical Notes

### Performance Impact

The progress tracking integration has minimal performance impact:
- Only active when ProgressTracking module is loaded
- Lightweight progress updates
- No additional processing when disabled

### Compatibility

- Works with PowerShell 7.0+
- Cross-platform (Windows, Linux, macOS)
- No external dependencies
- Backwards compatible with existing scripts

### Future Enhancements

Potential improvements could include:
- Customizable progress styles per operation
- Progress persistence across sessions
- Integration with CI/CD pipelines
- Web-based progress monitoring