# Progress Tracking Guide

## Overview

The AitherZero Progress Tracking module provides sophisticated visual progress indicators and operation tracking capabilities for long-running operations. This module enhances user experience by offering real-time feedback, time estimates, and comprehensive operation monitoring across all AitherZero modules.

## Features

### 🎯 Visual Progress Indicators
- Multiple display styles: Bar, Spinner, Percentage, Detailed
- Real-time progress updates with smooth animations
- Customizable progress bar appearance and behavior
- Cross-platform terminal compatibility

### ⏱️ Time Tracking and Estimation
- Elapsed time tracking for operations
- Estimated Time to Completion (ETA) calculations
- Performance metrics and operation analysis
- Historical operation data for optimization

### 🔄 Multi-Operation Support
- Parallel operation tracking
- Nested sub-operation management
- Operation hierarchy and dependencies
- Batch operation monitoring

### 📊 Operation Analytics
- Error and warning collection
- Operation success/failure tracking
- Performance benchmarking
- Detailed operation logging

## Quick Start

### Basic Progress Tracking
```powershell
# Import the module
Import-Module ./aither-core/modules/ProgressTracking -Force

# Start tracking an operation
$operationId = Start-ProgressOperation -OperationName "Deploying Infrastructure" -TotalSteps 10

# Update progress
for ($i = 1; $i -le 10; $i++) {
    Update-ProgressOperation -OperationId $operationId -CurrentStep $i -StepName "Step $i"
    Start-Sleep -Seconds 1
}

# Complete the operation
Complete-ProgressOperation -OperationId $operationId -ShowSummary
```

### Advanced Progress Tracking
```powershell
# Start with enhanced features
$operationId = Start-ProgressOperation `
    -OperationName "Complex Deployment" `
    -TotalSteps 15 `
    -ShowTime `
    -ShowETA `
    -Style 'Detailed'

# Increment step with custom naming
Update-ProgressOperation -OperationId $operationId -IncrementStep -StepName "Initializing Resources"
```

## Display Styles

### Bar Style (Default)
Progressive horizontal bar with percentage and step information.
```powershell
$operationId = Start-ProgressOperation -OperationName "File Processing" -TotalSteps 100 -Style 'Bar'
```
Output:
```
[████████████████████░░░░░░░░] 75% - File Processing - Processing file 75/100 - 45.2s - ETA: 15.1s
```

### Spinner Style
Animated spinner with percentage for operations without clear step counts.
```powershell
$operationId = Start-ProgressOperation -OperationName "Connecting to API" -TotalSteps 1 -Style 'Spinner'
```
Output:
```
⠸ Connecting to API - 100% - Connection established
```

### Percentage Style
Simple percentage display for minimal interfaces.
```powershell
$operationId = Start-ProgressOperation -OperationName "Data Transfer" -TotalSteps 50 -Style 'Percentage'
```
Output:
```
60% - Data Transfer: Transferring chunk 30/50
```

### Detailed Style
Comprehensive display with full operation information.
```powershell
$operationId = Start-ProgressOperation -OperationName "Infrastructure Deployment" -TotalSteps 20 -Style 'Detailed' -ShowTime -ShowETA
```
Output:
```
╔════════════════════════════════════════════════════════╗
║          Infrastructure Deployment                     ║
╠════════════════════════════════════════════════════════╣
║ [████████████████████████████████████░░░░░░░░░░░░░░] 75% ║
║ Step 15/20: Creating Virtual Networks                  ║
║ Elapsed: 125.4s | ETA: 41.8s                          ║
╚════════════════════════════════════════════════════════╝
```

## Advanced Features

### Multi-Operation Tracking
Track multiple parallel operations simultaneously:

```powershell
# Define multiple operations
$operations = @(
    @{Name = "Module Loading"; Steps = 5},
    @{Name = "Environment Setup"; Steps = 8},
    @{Name = "Validation"; Steps = 3}
)

# Start multi-operation tracking
$operationIds = Start-MultiProgress -Title "AitherZero Initialization" -Operations $operations

# Update individual operations
Update-ProgressOperation -OperationId $operationIds["Module Loading"] -IncrementStep
Update-ProgressOperation -OperationId $operationIds["Environment Setup"] -CurrentStep 3
```

### Error and Warning Tracking
Capture and track issues during operations:

```powershell
# Add warnings to operations
Add-ProgressWarning -OperationId $operationId -Warning "Network latency detected"

# Add errors to operations
Add-ProgressError -OperationId $operationId -Error "Failed to connect to resource"

# Complete with summary showing issues
Complete-ProgressOperation -OperationId $operationId -ShowSummary
```

### Logging Integration
Write log messages without disrupting progress displays:

```powershell
# Write logs that don't interfere with progress bars
Write-ProgressLog -Message "Starting database backup" -Level Info
Write-ProgressLog -Message "Connection timeout, retrying..." -Level Warning
Write-ProgressLog -Message "Backup completed successfully" -Level Success
```

## Integration Examples

### Setup Wizard Integration
```powershell
# The Setup Wizard automatically uses progress tracking
Import-Module ./aither-core/modules/SetupWizard -Force
Import-Module ./aither-core/modules/ProgressTracking -Force

# Progress tracking is automatically enabled during setup
$setupResult = Start-IntelligentSetup
```

### PatchManager Integration
```powershell
# Track patch operations
$operationId = Start-ProgressOperation -OperationName "Creating Patch" -TotalSteps 5 -ShowTime

try {
    Update-ProgressOperation -OperationId $operationId -IncrementStep -StepName "Analyzing changes"
    
    # PatchManager operations
    Invoke-PatchWorkflow -PatchDescription "Update documentation" -CreatePR -PatchOperation {
        Update-ProgressOperation -OperationId $operationId -IncrementStep -StepName "Creating branch"
        # Patch operations here
        Update-ProgressOperation -OperationId $operationId -IncrementStep -StepName "Committing changes"
    }
    
    Update-ProgressOperation -OperationId $operationId -IncrementStep -StepName "Creating PR"
    Complete-ProgressOperation -OperationId $operationId -ShowSummary
    
} catch {
    Add-ProgressError -OperationId $operationId -Error $_.Exception.Message
    Complete-ProgressOperation -OperationId $operationId -ShowSummary
}
```

### OpenTofu Provider Integration
```powershell
# Track infrastructure deployment
$operationId = Start-ProgressOperation -OperationName "Infrastructure Deployment" -TotalSteps 8 -ShowTime -ShowETA -Style 'Detailed'

try {
    Update-ProgressOperation -OperationId $operationId -IncrementStep -StepName "Initializing OpenTofu"
    Initialize-OpenTofuProvider
    
    Update-ProgressOperation -OperationId $operationId -IncrementStep -StepName "Planning deployment"
    New-DeploymentPlan -ConfigPath "./opentofu/dev-lab.tf"
    
    Update-ProgressOperation -OperationId $operationId -IncrementStep -StepName "Applying infrastructure"
    Start-InfrastructureDeployment
    
    Complete-ProgressOperation -OperationId $operationId -ShowSummary
    
} catch {
    Add-ProgressError -OperationId $operationId -Error "Deployment failed: $($_.Exception.Message)"
    Complete-ProgressOperation -OperationId $operationId -ShowSummary
    throw
}
```

## Best Practices

### For Long-Running Operations
1. **Always use progress tracking** for operations longer than 30 seconds
2. **Provide meaningful step names** to keep users informed
3. **Enable time tracking** for operations with variable duration
4. **Use appropriate display styles** based on terminal capabilities

### For Batch Operations
1. **Use multi-operation tracking** for parallel processes
2. **Group related operations** under a common title
3. **Provide individual progress updates** for each operation
4. **Summarize results** at completion

### For Error Handling
1. **Track warnings and errors** during operations
2. **Continue operations** when possible despite warnings
3. **Provide actionable error messages** for failures
4. **Include recovery suggestions** in error logs

### For User Experience
1. **Start tracking immediately** when beginning operations
2. **Update progress regularly** (at least every 5-10 seconds)
3. **Provide completion summaries** for important operations
4. **Use consistent terminology** across operations

## Performance Considerations

### Efficient Updates
```powershell
# Good: Batch updates when possible
Update-ProgressOperation -OperationId $operationId -CurrentStep 5 -StepName "Processing batch"

# Avoid: Too frequent updates (can cause flickering)
for ($i = 1; $i -le 1000; $i++) {
    Update-ProgressOperation -OperationId $operationId -CurrentStep $i  # Too frequent
}
```

### Memory Management
```powershell
# Good: Complete operations when done
Complete-ProgressOperation -OperationId $operationId

# Operations are automatically cleaned up when completed
```

### Terminal Compatibility
```powershell
# Test for terminal capabilities
if ($Host.UI.SupportsVirtualTerminal) {
    $style = 'Detailed'
} else {
    $style = 'Percentage'
}

$operationId = Start-ProgressOperation -OperationName "Operation" -TotalSteps 10 -Style $style
```

## API Reference

### Core Functions

#### Start-ProgressOperation
Initializes a new progress tracking operation.

**Parameters:**
- `OperationName` (Required): Display name for the operation
- `TotalSteps` (Required): Total number of steps to complete
- `ShowTime`: Enable elapsed time display
- `ShowETA`: Enable estimated completion time
- `Style`: Display style ('Bar', 'Spinner', 'Percentage', 'Detailed')

**Returns:** Operation ID string for tracking

#### Update-ProgressOperation
Updates progress for an active operation.

**Parameters:**
- `OperationId` (Required): ID returned from Start-ProgressOperation
- `CurrentStep`: Specific step number to set
- `StepName`: Optional description of current step
- `IncrementStep`: Advance step by one

#### Complete-ProgressOperation
Completes and cleans up a progress operation.

**Parameters:**
- `OperationId` (Required): ID of operation to complete
- `ShowSummary`: Display completion summary with statistics

#### Start-MultiProgress
Initiates tracking for multiple parallel operations.

**Parameters:**
- `Title` (Required): Overall title for the group of operations
- `Operations` (Required): Array of operation definitions

**Returns:** Hashtable mapping operation names to IDs

### Utility Functions

#### Add-ProgressWarning / Add-ProgressError
Add warnings or errors to operations for tracking.

#### Write-ProgressLog
Write log messages without disrupting progress displays.

#### Get-ActiveOperations
Retrieve status of all currently active operations.

## Troubleshooting

### Common Issues

#### Progress Not Updating
**Cause**: Terminal doesn't support cursor positioning
**Solution**: Use 'Percentage' style instead of 'Bar' or 'Detailed'

#### Flickering Display
**Cause**: Too frequent updates
**Solution**: Reduce update frequency or batch updates

#### Memory Usage
**Cause**: Not completing operations properly
**Solution**: Always call Complete-ProgressOperation

### Debug Information
```powershell
# Check active operations
Get-ActiveOperations

# Verify operation status
$operations = Get-ActiveOperations
$operations | ForEach-Object { 
    Write-Host "$($_.Name): $($_.Progress)% complete" 
}
```

## Support and Resources

- **Module Source**: `/aither-core/modules/ProgressTracking/`
- **Integration Examples**: All AitherZero modules use progress tracking
- **Performance Guidelines**: See best practices section above
- **Terminal Compatibility**: Tested on Windows Terminal, PowerShell ISE, Linux terminals, and macOS Terminal

For additional support, see the main [AitherZero documentation](../README.md) or create an issue on GitHub.