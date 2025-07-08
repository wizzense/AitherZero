# ProgressTracking Module

## Test Status
- **Last Run**: 2025-07-08 17:29:43 UTC
- **Status**: ✅ PASSING (10/10 tests)
- **Coverage**: 0%
- **Platform**: ✅ Windows ✅ Linux ✅ macOS
- **Dependencies**: ✅ All resolved

## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 10/10 | 0% | 1s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 0.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Module Overview

The **ProgressTracking** module provides visual progress indicators and operation monitoring for long-running tasks in the AitherZero platform. It offers multiple display styles, ETA calculations, error/warning tracking, and support for parallel operations with comprehensive progress visualization.

### Core Functionality and Purpose

- **Visual Progress Indicators**: Multiple display styles including progress bars, spinners, percentages, and detailed views
- **Operation Monitoring**: Track start time, current step, total steps, elapsed time, and ETA
- **Multi-Operation Support**: Monitor multiple parallel operations simultaneously
- **Error/Warning Tracking**: Capture and display errors and warnings during operation execution
- **Non-Disruptive Logging**: Write log messages without interrupting progress displays
- **Cross-Platform Compatible**: Works on Windows, Linux, and macOS terminals

### Architecture and Design Patterns

The module implements a **state management pattern** using script-scoped variables to track active operations. Each operation is assigned a unique GUID for identification and can be updated independently. The module uses **atomic display updates** with carriage return (`\r`) to update progress in-place without scrolling the terminal.

### Key Features

- **Multiple Display Styles**: Bar, Spinner, Percentage, and Detailed views
- **ETA Calculation**: Automatic estimation of time to completion based on progress rate
- **Parallel Operation Tracking**: Monitor multiple operations simultaneously
- **Progress Persistence**: Track operation history and export reports
- **Smart Terminal Handling**: Gracefully handles non-interactive terminals

## Directory Structure

```
ProgressTracking/
├── ProgressTracking.psd1    # Module manifest
├── ProgressTracking.psm1    # Main module implementation
└── README.md               # This documentation
```

### Module Files and Organization

- **ProgressTracking.psd1**: Module manifest defining metadata, version, and exported functions
- **ProgressTracking.psm1**: Core implementation with all progress tracking functionality
- No Public/Private separation as this is a focused utility module with direct function exports

## Function Reference

### Start-ProgressOperation

Starts tracking a new operation with progress visualization.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| OperationName | string | Yes | Name of the operation to track |
| TotalSteps | int | Yes | Total number of steps in the operation |
| ShowTime | switch | No | Show elapsed time in progress display |
| ShowETA | switch | No | Calculate and show estimated time to completion |
| Style | string | No | Display style: 'Bar' (default), 'Spinner', 'Percentage', 'Detailed' |

#### Returns

- **string**: Operation ID (GUID) for subsequent updates

#### Example

```powershell
# Start a simple progress operation
$operationId = Start-ProgressOperation -OperationName "Deploying Infrastructure" -TotalSteps 10

# Start with time and ETA display
$operationId = Start-ProgressOperation -OperationName "Building Packages" -TotalSteps 50 -ShowTime -ShowETA

# Use detailed style for complex operations
$operationId = Start-ProgressOperation -OperationName "System Migration" -TotalSteps 100 -Style Detailed
```

### Update-ProgressOperation

Updates progress for an active operation.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| OperationId | string | Yes | ID of the operation to update |
| CurrentStep | int | No | Current step number (absolute) |
| StepName | string | No | Optional name for the current step |
| IncrementStep | switch | No | Increment the current step by 1 |

#### Example

```powershell
# Update to specific step
Update-ProgressOperation -OperationId $operationId -CurrentStep 5 -StepName "Creating VMs"

# Increment step
Update-ProgressOperation -OperationId $operationId -IncrementStep -StepName "Configuring Network"

# Simple increment without step name
Update-ProgressOperation -OperationId $operationId -IncrementStep
```

### Complete-ProgressOperation

Completes and removes a progress operation.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| OperationId | string | Yes | ID of the operation to complete |
| ShowSummary | switch | No | Show a summary of the completed operation |

#### Example

```powershell
# Complete without summary
Complete-ProgressOperation -OperationId $operationId

# Complete with summary
Complete-ProgressOperation -OperationId $operationId -ShowSummary
```

### Add-ProgressWarning

Adds a warning to the current operation.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| OperationId | string | Yes | ID of the operation |
| Warning | string | Yes | Warning message to add |

#### Example

```powershell
Add-ProgressWarning -OperationId $operationId -Warning "Network latency detected"
```

### Add-ProgressError

Adds an error to the current operation.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| OperationId | string | Yes | ID of the operation |
| Error | string | Yes | Error message to add |

#### Example

```powershell
Add-ProgressError -OperationId $operationId -Error "Failed to connect to database"
```

### Write-ProgressLog

Writes a log message without disrupting progress display.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| Message | string | Yes | Log message to display |
| Level | string | No | Log level: 'Info' (default), 'Warning', 'Error', 'Success' |

#### Example

```powershell
Write-ProgressLog -Message "Configuration validated" -Level Success
Write-ProgressLog -Message "Retrying connection" -Level Warning
```

### Get-ActiveOperations

Gets list of currently active operations.

#### Returns

- **PSCustomObject[]**: Array of operation status objects with properties:
  - Name: Operation name
  - Progress: Percentage complete (0-100)
  - CurrentStep: Current step number
  - TotalSteps: Total number of steps
  - Duration: Elapsed time in seconds
  - Warnings: Number of warnings
  - Errors: Number of errors

#### Example

```powershell
$activeOps = Get-ActiveOperations
$activeOps | Format-Table Name, Progress, Duration -AutoSize
```

### Start-MultiProgress

Starts tracking multiple parallel operations.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| Title | string | Yes | Title for the multi-operation group |
| Operations | hashtable[] | Yes | Array of operation definitions with Name and Steps properties |

#### Returns

- **hashtable**: Dictionary mapping operation names to their operation IDs

#### Example

```powershell
$operations = @(
    @{Name = "Module Loading"; Steps = 5},
    @{Name = "Environment Setup"; Steps = 8},
    @{Name = "Validation"; Steps = 3}
)

$multiOps = Start-MultiProgress -Title "AitherZero Initialization" -Operations $operations

# Update individual operations
Update-ProgressOperation -OperationId $multiOps["Module Loading"] -IncrementStep
```

### Additional Exported Functions

- **Get-ProgressStatus**: Get current status of a specific operation
- **Stop-ProgressOperation**: Force stop an operation without completion
- **Update-MultiProgress**: Update multiple operations in one call
- **Complete-MultiProgress**: Complete all operations in a multi-progress group
- **Show-ProgressSummary**: Display summary of all operations
- **Get-ProgressHistory**: Retrieve history of completed operations
- **Clear-ProgressHistory**: Clear operation history
- **Export-ProgressReport**: Export operation report to file
- **Test-ProgressOperationActive**: Check if an operation is currently active

## Key Features

### Visual Progress Styles

#### Progress Bar Style
```
[████████████████░░░░░░░░░░░░░] 53% - Deploying Infrastructure - Creating VMs - 12.3s - ETA: 10.1s
```

#### Spinner Style
```
⠹ Building Packages - 75% - Compiling modules
```

#### Percentage Style
```
45% - System Migration: Copying files
```

#### Detailed Style
```
╔════════════════════════════════════════════════════════╗
║ System Migration                                       ║
╠════════════════════════════════════════════════════════╣
║ [████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░] 45% ║
║ Step 45 of 100: Migrating user data                    ║
║ Elapsed: 125.4s | ETA: 153.2s                          ║
╚════════════════════════════════════════════════════════╝
```

### ETA Calculation

The module calculates ETA based on:
- Average time per step from operation start
- Remaining steps to complete
- Automatically adjusts as operation progresses

### Multi-Operation Tracking

Track multiple operations simultaneously with independent progress:
```powershell
# Start multiple operations
$ops = Start-MultiProgress -Title "Deployment Pipeline" -Operations @(
    @{Name = "Build"; Steps = 20},
    @{Name = "Test"; Steps = 15},
    @{Name = "Deploy"; Steps = 10}
)

# Update operations independently
Update-ProgressOperation -OperationId $ops["Build"] -IncrementStep
Update-ProgressOperation -OperationId $ops["Test"] -CurrentStep 5
```

## Usage Examples

### Real-World Scenarios

#### Long-Running Deployment
```powershell
# Track infrastructure deployment
$deployId = Start-ProgressOperation -OperationName "Infrastructure Deployment" `
    -TotalSteps 25 -ShowTime -ShowETA -Style Detailed

try {
    # Create resource group
    Update-ProgressOperation -OperationId $deployId -IncrementStep -StepName "Creating Resource Group"
    New-AzResourceGroup -Name "MyRG" -Location "EastUS"
    
    # Deploy VMs
    for ($i = 1; $i -le 5; $i++) {
        Update-ProgressOperation -OperationId $deployId -IncrementStep -StepName "Creating VM $i"
        # VM creation logic here
    }
    
    # Configure networking
    Update-ProgressOperation -OperationId $deployId -IncrementStep -StepName "Configuring Network"
    # Network configuration logic
    
} catch {
    Add-ProgressError -OperationId $deployId -Error $_.Exception.Message
    throw
} finally {
    Complete-ProgressOperation -OperationId $deployId -ShowSummary
}
```

#### File Processing with Progress
```powershell
$files = Get-ChildItem -Path "C:\LargeDataset" -File
$processId = Start-ProgressOperation -OperationName "Processing Files" `
    -TotalSteps $files.Count -ShowTime

foreach ($file in $files) {
    Update-ProgressOperation -OperationId $processId -IncrementStep `
        -StepName "Processing $($file.Name)"
    
    # Process file
    try {
        # File processing logic
    } catch {
        Add-ProgressWarning -OperationId $processId `
            -Warning "Failed to process $($file.Name): $_"
    }
}

Complete-ProgressOperation -OperationId $processId -ShowSummary
```

### Integration Patterns

#### With Error Handling
```powershell
function Deploy-Application {
    param($AppName, $Environment)
    
    $deployId = Start-ProgressOperation -OperationName "Deploying $AppName to $Environment" `
        -TotalSteps 10 -ShowTime -ShowETA
    
    try {
        # Pre-deployment checks
        Update-ProgressOperation -OperationId $deployId -CurrentStep 1 -StepName "Pre-deployment checks"
        if (-not (Test-Prerequisites)) {
            Add-ProgressError -OperationId $deployId -Error "Prerequisites not met"
            throw "Prerequisites check failed"
        }
        
        # Build application
        Update-ProgressOperation -OperationId $deployId -CurrentStep 3 -StepName "Building application"
        Build-Application -Name $AppName
        
        # Run tests
        Update-ProgressOperation -OperationId $deployId -CurrentStep 5 -StepName "Running tests"
        $testResult = Invoke-Tests
        if ($testResult.Warnings -gt 0) {
            Add-ProgressWarning -OperationId $deployId -Warning "$($testResult.Warnings) test warnings"
        }
        
        # Deploy
        Update-ProgressOperation -OperationId $deployId -CurrentStep 8 -StepName "Deploying to $Environment"
        Deploy-ToEnvironment -App $AppName -Env $Environment
        
        # Verify deployment
        Update-ProgressOperation -OperationId $deployId -CurrentStep 10 -StepName "Verifying deployment"
        Test-Deployment -App $AppName -Env $Environment
        
    } catch {
        Add-ProgressError -OperationId $deployId -Error $_.Exception.Message
        throw
    } finally {
        Complete-ProgressOperation -OperationId $deployId -ShowSummary
    }
}
```

#### Parallel Operations
```powershell
# Define parallel tasks
$tasks = @(
    @{Name = "Database Migration"; Steps = 50; ScriptBlock = { Migrate-Database }},
    @{Name = "File Sync"; Steps = 100; ScriptBlock = { Sync-Files }},
    @{Name = "Cache Rebuild"; Steps = 30; ScriptBlock = { Rebuild-Cache }}
)

# Start multi-progress tracking
$multiOps = Start-MultiProgress -Title "Parallel Maintenance Tasks" -Operations $tasks

# Run tasks in parallel
$jobs = foreach ($task in $tasks) {
    Start-Job -Name $task.Name -ScriptBlock {
        param($OperationId, $ScriptBlock)
        
        # Import module in job
        Import-Module ProgressTracking
        
        # Execute task with progress updates
        & $ScriptBlock -ProgressId $OperationId
        
    } -ArgumentList $multiOps[$task.Name], $task.ScriptBlock
}

# Monitor jobs
while ($jobs | Where-Object State -eq 'Running') {
    Start-Sleep -Seconds 1
    # Progress is automatically updated by jobs
}

# Complete all operations
Complete-MultiProgress -OperationIds $multiOps.Values -ShowSummary
```

### Code Snippets

#### Custom Progress Reporter
```powershell
function New-ProgressReporter {
    param(
        [string]$OperationName,
        [int]$TotalSteps,
        [string]$Style = 'Bar'
    )
    
    $reporter = [PSCustomObject]@{
        OperationId = Start-ProgressOperation -OperationName $OperationName `
            -TotalSteps $TotalSteps -ShowTime -ShowETA -Style $Style
        StartTime = Get-Date
        Errors = @()
        Warnings = @()
    }
    
    # Add methods
    $reporter | Add-Member -MemberType ScriptMethod -Name "Update" -Value {
        param($StepName)
        Update-ProgressOperation -OperationId $this.OperationId -IncrementStep -StepName $StepName
    }
    
    $reporter | Add-Member -MemberType ScriptMethod -Name "Complete" -Value {
        Complete-ProgressOperation -OperationId $this.OperationId -ShowSummary
    }
    
    return $reporter
}

# Usage
$reporter = New-ProgressReporter -OperationName "Data Processing" -TotalSteps 100
$reporter.Update("Loading data")
# ... processing ...
$reporter.Complete()
```

## Configuration

The ProgressTracking module uses minimal configuration and is designed to work out-of-the-box. However, you can customize behavior through parameters:

### Display Configuration

```powershell
# Set default style for all operations
$PSDefaultParameterValues['Start-ProgressOperation:Style'] = 'Detailed'

# Always show time and ETA
$PSDefaultParameterValues['Start-ProgressOperation:ShowTime'] = $true
$PSDefaultParameterValues['Start-ProgressOperation:ShowETA'] = $true
```

### Terminal Compatibility

The module automatically detects terminal capabilities:
- **Interactive Terminals**: Full progress display with in-place updates
- **Non-Interactive/Redirected Output**: Falls back to line-by-line output
- **CI/CD Environments**: Detects common CI variables and adjusts output

## Security Considerations

### Best Practices

1. **Sensitive Information**: Never include sensitive data in operation names or step descriptions
2. **Progress Logs**: Operation history may be exported - ensure no credentials are logged
3. **Error Messages**: Sanitize error messages before adding to progress tracking

### Safe Usage Examples

```powershell
# Good - Generic operation name
$opId = Start-ProgressOperation -OperationName "Database Migration" -TotalSteps 10

# Bad - Exposes sensitive information
# $opId = Start-ProgressOperation -OperationName "Migrating DB pwd:Secret123" -TotalSteps 10

# Good - Sanitized error
try {
    # Database operation
} catch {
    $sanitizedError = $_.Exception.Message -replace 'password=.*?;', 'password=***;'
    Add-ProgressError -OperationId $opId -Error $sanitizedError
}
```

## Performance Considerations

- **Update Frequency**: Limit updates to significant progress changes (avoid updating on every loop iteration)
- **Terminal I/O**: Excessive updates can impact performance in slow terminals
- **Memory Usage**: Completed operations are kept in memory until cleared

### Optimization Example

```powershell
# Inefficient - Updates on every item
foreach ($item in $largeCollection) {
    Update-ProgressOperation -OperationId $opId -IncrementStep
    Process-Item $item
}

# Efficient - Updates every 10 items
$updateInterval = 10
for ($i = 0; $i -lt $largeCollection.Count; $i++) {
    Process-Item $largeCollection[$i]
    
    if ($i % $updateInterval -eq 0) {
        Update-ProgressOperation -OperationId $opId -CurrentStep $i
    }
}
```

## Troubleshooting

### Common Issues

1. **Progress not displaying**: Check if terminal is interactive with `[Environment]::UserInteractive`
2. **Garbled output**: Terminal may not support ANSI escape codes - use simpler Style
3. **Progress freezes**: Ensure you're calling Complete-ProgressOperation in finally blocks

### Debug Mode

```powershell
# Enable verbose logging
$VerbosePreference = 'Continue'

# Check active operations
Get-ActiveOperations | Format-List *

# Manually clean up stuck operations
$script:ActiveOperations.Clear()
```