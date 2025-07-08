# ScriptManager Module

## Module Overview

The ScriptManager module provides centralized management for one-off scripts and script automation within the AitherZero framework. It enables registration, validation, and execution of standalone PowerShell scripts while ensuring they are properly integrated into the project framework without breaking dependencies.

### Primary Functionality
- Script registration and metadata management
- One-off script execution with parameter support
- Script template management
- Script repository discovery and validation
- Execution tracking and status monitoring

### Use Cases and Scenarios
- Running maintenance scripts on demand
- Executing data migration or transformation scripts
- Automating repetitive administrative tasks
- Testing new functionality before module integration
- Quick prototyping of automation workflows

### Integration with AitherZero
- Integrates with the Logging module for consistent output
- Works alongside LabRunner for lab-specific scripts
- Supports execution from the main menu system
- Provides metadata tracking for audit purposes

## Directory Structure

```
ScriptManager/
├── ScriptManager.psd1         # Module manifest
├── ScriptManager.psm1         # Main module script with core logic
├── one-off-scripts.json       # Script registry metadata
└── Public/                    # Exported public functions
    ├── Get-ScriptRepository.ps1
    ├── Get-ScriptTemplate.ps1
    ├── Invoke-OneOffScript.ps1
    └── Start-ScriptExecution.ps1
```

## Core Functions

### Register-OneOffScript
Registers a script in the script management system with metadata tracking.

**Parameters:**
- `ScriptPath` (string, mandatory): Full path to the script file
- `Name` (string, mandatory): Friendly name for the script
- `Description` (string): Description of script functionality
- `Parameters` (hashtable): Parameters accepted by the script
- `Force` (switch): Force re-registration of existing script

**Returns:** None (writes status to console)

**Example:**
```powershell
Register-OneOffScript -ScriptPath "C:\Scripts\Update-VMConfig.ps1" `
    -Name "VM Configuration Update" `
    -Description "Updates VM configurations based on CSV input" `
    -Parameters @{CsvPath = "Path to CSV file"; DryRun = "Preview changes only"}
```

### Invoke-OneOffScript
Executes a registered script with optional parameters and tracks execution status.

**Parameters:**
- `ScriptPath` (string, mandatory): Path to the script to execute
- `Parameters` (hashtable): Parameters to pass to the script
- `Force` (switch): Force re-execution of already executed scripts

**Returns:** Script execution result

**Example:**
```powershell
# Execute script with parameters
$result = Invoke-OneOffScript -ScriptPath "C:\Scripts\Update-VMConfig.ps1" `
    -Parameters @{CsvPath = "C:\Data\vms.csv"; DryRun = $true}

# Re-execute a previously run script
Invoke-OneOffScript -ScriptPath "C:\Scripts\Cleanup-Logs.ps1" -Force
```

### Get-ScriptRepository
Retrieves information about available scripts in the script repository.

**Parameters:**
- `Path` (string): Path to script repository (defaults to project scripts folder)

**Returns:** Hashtable containing repository information and script details

**Example:**
```powershell
$repo = Get-ScriptRepository
Write-Host "Found $($repo.TotalScripts) scripts, $($repo.ValidScripts) are valid"

# Check specific repository
$customRepo = Get-ScriptRepository -Path "C:\CustomScripts"
```

### Start-ScriptExecution
Starts execution of a script by name with optional background execution.

**Parameters:**
- `ScriptName` (string, mandatory): Name or partial name of script
- `Parameters` (hashtable): Parameters to pass to the script
- `Background` (switch): Run script as background job

**Returns:** Execution status object

**Example:**
```powershell
# Run script in foreground
Start-ScriptExecution -ScriptName "Update-VM" -Parameters @{VMName = "TestVM"}

# Run script in background
$job = Start-ScriptExecution -ScriptName "Backup-Data" -Background
```

### Get-ScriptTemplate
Retrieves available script templates for creating new scripts.

**Parameters:**
- `TemplateName` (string): Specific template to retrieve

**Returns:** Template object(s) with content

**Example:**
```powershell
# Get all templates
$templates = Get-ScriptTemplate

# Get specific template
$labTemplate = Get-ScriptTemplate -TemplateName "Lab"
$labTemplate.Content | Out-File "NewLabScript.ps1"
```

### Test-OneOffScript
Validates a script for proper module imports and modern function usage.

**Parameters:**
- `ScriptPath` (string, mandatory): Path to script to validate

**Returns:** Boolean indicating validation status

**Example:**
```powershell
if (Test-OneOffScript -ScriptPath "C:\Scripts\MyScript.ps1") {
    Write-Host "Script is valid and can be executed"
}
```

## Key Features

### One-off Scripts
- **Purpose**: Execute scripts that don't belong to a specific module
- **Registration**: Track script metadata and execution history
- **Validation**: Ensure scripts follow project standards
- **Execution**: Run with parameter support and status tracking

### Script Templates
The module provides three built-in templates:

1. **Basic Template**: Simple PowerShell script structure
2. **Module Template**: Script that uses AitherZero modules
3. **Lab Template**: Lab automation script with logging

### Script Repository
- Automatic discovery of scripts in project directories
- Validation of script compatibility
- Size and modification tracking
- Quick access to frequently used scripts

## Usage Workflows

### Registering and Running a New Script

```powershell
# 1. Import the module
Import-Module ScriptManager -Force

# 2. Register your script
Register-OneOffScript -ScriptPath ".\MyNewScript.ps1" `
    -Name "My Automation Script" `
    -Description "Automates specific task X"

# 3. Execute the script
Invoke-OneOffScript -ScriptPath ".\MyNewScript.ps1"

# 4. Check execution history
$metadata = Get-Content ".\one-off-scripts.json" | ConvertFrom-Json
$metadata | Where-Object Name -eq "My Automation Script"
```

### Creating a Script from Template

```powershell
# 1. Get available templates
$templates = Get-ScriptTemplate

# 2. Select and save template
$template = Get-ScriptTemplate -TemplateName "Module"
$template.Content | Out-File ".\NewModuleScript.ps1"

# 3. Edit script as needed
# 4. Register and run
Register-OneOffScript -ScriptPath ".\NewModuleScript.ps1" -Name "New Module Script"
Invoke-OneOffScript -ScriptPath ".\NewModuleScript.ps1"
```

### Background Script Execution

```powershell
# Start long-running script in background
$job = Start-ScriptExecution -ScriptName "DataMigration" `
    -Parameters @{SourceDB = "OldDB"; TargetDB = "NewDB"} `
    -Background

# Check job status
Get-Job -Id $job.JobId

# Get job results when complete
Receive-Job -Id $job.JobId
```

## Security

### Script Validation
- Scripts are validated before execution
- Module import checks ensure dependency management
- Function usage validation for deprecated methods

### Execution Tracking
- All script executions are logged with timestamps
- Success/failure status is recorded
- Execution parameters are tracked for audit

### Best Practices
1. Always register scripts before first execution
2. Use descriptive names and descriptions
3. Document script parameters in registration
4. Validate scripts before production use
5. Review execution history regularly

## Configuration

### Script Metadata Storage
Script metadata is stored in `one-off-scripts.json`:
```json
[
  {
    "ScriptPath": "C:\\Scripts\\Update-Config.ps1",
    "Name": "Configuration Updater",
    "Description": "Updates system configurations",
    "Parameters": {
      "ConfigFile": "Path to configuration file",
      "Backup": "Create backup before update"
    },
    "RegisteredDate": "2025-01-15 10:30:00",
    "Executed": true,
    "ExecutionDate": "2025-01-15 14:45:00",
    "ExecutionResult": "Success"
  }
]
```

### Script Repository Paths
Default paths searched for scripts:
- `$env:PROJECT_ROOT/aither-core/scripts`
- Custom paths via `-Path` parameter

### Integration Points
- **Logging Module**: All output uses Write-CustomLog
- **Project Root Detection**: Uses Find-ProjectRoot utility
- **Error Handling**: Comprehensive try-catch blocks

## Common Scenarios

### Daily Maintenance Scripts
```powershell
# Register daily cleanup script
Register-OneOffScript -ScriptPath ".\Cleanup-Daily.ps1" `
    -Name "Daily Cleanup" `
    -Description "Removes old logs and temp files"

# Run daily (could be scheduled)
Invoke-OneOffScript -ScriptPath ".\Cleanup-Daily.ps1" -Force
```

### Migration Scripts
```powershell
# Register migration script with parameters
Register-OneOffScript -ScriptPath ".\Migrate-Data.ps1" `
    -Name "Data Migration v2" `
    -Parameters @{
        SourcePath = "Source data location"
        TargetPath = "Target data location"
        ValidateOnly = "Run validation without migration"
    }

# Run migration with validation first
Invoke-OneOffScript -ScriptPath ".\Migrate-Data.ps1" `
    -Parameters @{ValidateOnly = $true}
```

### Development and Testing
```powershell
# Quick script validation
if (Test-OneOffScript -ScriptPath ".\Test-Feature.ps1") {
    # Register for development testing
    Register-OneOffScript -ScriptPath ".\Test-Feature.ps1" `
        -Name "Feature Test" -Force
    
    # Execute with test parameters
    Invoke-OneOffScript -ScriptPath ".\Test-Feature.ps1" `
        -Parameters @{TestMode = $true; Verbose = $true}
}
```

## Best Practices

1. **Script Organization**: Keep one-off scripts in a dedicated directory
2. **Naming Convention**: Use descriptive names with verb-noun format
3. **Parameter Documentation**: Always document parameters during registration
4. **Error Handling**: Include proper error handling in all scripts
5. **Logging**: Use Write-CustomLog for consistent output
6. **Validation**: Run Test-OneOffScript before production use
7. **Version Control**: Track script changes in git
8. **Cleanup**: Periodically review and archive old scripts