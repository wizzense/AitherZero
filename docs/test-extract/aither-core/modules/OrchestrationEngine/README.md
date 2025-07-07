# OrchestrationEngine Module

## Module Overview

The OrchestrationEngine module provides advanced workflow and playbook execution capabilities for AitherZero. It enables complex infrastructure automation through declarative playbooks with support for conditional logic, parallel execution, and module integration.

### Primary Purpose and Architecture

- **Workflow orchestration** for complex multi-step operations
- **Playbook-based automation** using JSON/YAML definitions
- **Conditional execution** with runtime evaluation
- **Parallel step processing** for improved performance
- **Module integration** with all AitherZero components
- **State management** for workflow tracking and recovery
- **Cross-platform execution** on Windows, Linux, and macOS

### Key Capabilities and Features

- **Multiple execution modes**: Sequential, parallel, and conditional
- **Dynamic parameter substitution** in playbook steps
- **Environment-aware execution** (dev, staging, prod)
- **Dry-run support** for validation without execution
- **Error handling** with continue-on-error options
- **Real-time status tracking** and monitoring
- **Workflow history** and audit trails
- **Extensible step types** for custom operations

### Integration Patterns

```powershell
# Import the module
Import-Module ./aither-core/modules/OrchestrationEngine -Force

# Execute a playbook by name
$result = Invoke-PlaybookWorkflow -PlaybookName "deploy-infrastructure" -Parameters @{
    environment = "dev"
    region = "us-east-1"
} -EnvironmentContext "dev"

# Execute inline playbook definition
$playbook = New-PlaybookDefinition -Name "Quick Deploy" -Steps @(
    New-ScriptStep -Name "Validate" -Command "Test-Path ./deploy"
    New-ScriptStep -Name "Deploy" -Command "./deploy/Deploy-App.ps1"
)
$result = Invoke-PlaybookWorkflow -PlaybookDefinition $playbook

# Monitor workflow status
$status = Get-PlaybookStatus -WorkflowId $result.WorkflowId
```

## Directory Structure

```
OrchestrationEngine/
├── OrchestrationEngine.psd1    # Module manifest
├── OrchestrationEngine.psm1    # Main orchestration logic
├── README.md                   # This documentation
└── (Runtime directories created automatically)
    ├── orchestration/          # Root orchestration directory
    ├── playbooks/              # Playbook definitions
    ├── templates/              # Playbook templates
    ├── logs/                   # Execution logs
    └── state/                  # Workflow state files
```

### Module Organization

- **OrchestrationEngine.psd1**: Module manifest with dependencies and exports
- **OrchestrationEngine.psm1**: Core orchestration engine implementation
- **orchestration/**: Auto-created runtime directory structure
- **playbooks/**: Storage for playbook definition files (JSON/YAML)
- **templates/**: Reusable playbook templates
- **logs/**: Workflow execution logs
- **state/**: Persistent workflow state for recovery

## API Reference

### Main Functions

#### Invoke-PlaybookWorkflow
Executes a playbook workflow with full orchestration capabilities.

```powershell
Invoke-PlaybookWorkflow [-PlaybookName <string>] [-PlaybookDefinition <hashtable>] 
                       [-Parameters <hashtable>] [-ExecutionMode <string>]
                       [-EnvironmentContext <string>] [-DryRun] 
                       [-ContinueOnError] [-WorkflowId <string>]
```

**Parameters:**
- `PlaybookName` (string): Name of playbook file to load from playbooks directory
- `PlaybookDefinition` (hashtable): Inline playbook definition
- `Parameters` (hashtable): Parameters to pass to playbook steps
- `ExecutionMode` (string): Execution mode - sequential, parallel, conditional. Default: sequential
- `EnvironmentContext` (string): Environment context - dev, staging, prod. Default: dev
- `DryRun` (switch): Simulate execution without running commands
- `ContinueOnError` (switch): Continue execution if steps fail
- `WorkflowId` (string): Custom workflow identifier

**Returns:** Workflow result object with execution details

**Example:**
```powershell
$result = Invoke-PlaybookWorkflow -PlaybookName "database-migration" -Parameters @{
    sourceDB = "prod-db-01"
    targetDB = "prod-db-02"
    backupFirst = $true
} -EnvironmentContext "prod" -DryRun

if ($result.Success) {
    Write-Host "Dry run successful. Execute without -DryRun to proceed."
}
```

#### New-PlaybookDefinition
Creates a new playbook definition structure.

```powershell
New-PlaybookDefinition -Name <string> [-Description <string>] 
                      [-Version <string>] [-Steps <hashtable[]>]
                      [-Parameters <hashtable>] [-RequiredModules <string[]>]
```

**Parameters:**
- `Name` (string, required): Playbook name
- `Description` (string): Playbook description
- `Version` (string): Version number. Default: "1.0"
- `Steps` (hashtable[]): Array of step definitions
- `Parameters` (hashtable): Parameter definitions
- `RequiredModules` (string[]): Required AitherZero modules

**Returns:** Playbook definition hashtable

**Example:**
```powershell
$playbook = New-PlaybookDefinition -Name "WebApp Deployment" -Description "Deploy web application" -Steps @(
    New-ScriptStep -Name "Stop Services" -Command "Stop-Service WebApp*"
    New-ScriptStep -Name "Deploy Files" -Command "Copy-Item ./dist/* C:/WebApp/"
    New-ScriptStep -Name "Start Services" -Command "Start-Service WebApp*"
) -Parameters @{
    targetServer = @{ type = "string"; required = $true }
    deployPath = @{ type = "string"; default = "C:/WebApp" }
}
```

#### Get-PlaybookStatus
Gets the status of running or completed workflows.

```powershell
Get-PlaybookStatus [-WorkflowId <string>]
```

**Parameters:**
- `WorkflowId` (string): Specific workflow ID to query

**Returns:** Workflow status object or summary of all workflows

**Example:**
```powershell
# Get specific workflow
$status = Get-PlaybookStatus -WorkflowId "workflow-20250129-143022-5678"

# Get all workflows
$allWorkflows = Get-PlaybookStatus
Write-Host "Active workflows: $($allWorkflows.TotalActive)"
Write-Host "Completed workflows: $($allWorkflows.TotalHistory)"
```

#### Stop-PlaybookWorkflow
Stops a running workflow.

```powershell
Stop-PlaybookWorkflow -WorkflowId <string>
```

**Parameters:**
- `WorkflowId` (string, required): Workflow ID to stop

**Returns:** Operation result object

### Step Creation Functions

#### New-ScriptStep
Creates a script execution step.

```powershell
New-ScriptStep -Name <string> -Command <string> 
               [-Shell <string>] [-Condition <string>]
```

**Parameters:**
- `Name` (string): Step name
- `Command` (string): Command to execute
- `Shell` (string): Shell to use (powershell, bash, etc.). Default: powershell
- `Condition` (string): Conditional expression

**Returns:** Script step definition

**Example:**
```powershell
$step = New-ScriptStep -Name "Check Prerequisites" -Command "Test-Path C:/App/config.json" -Condition '$env.context -eq "prod"'
```

#### New-ConditionalStep
Creates a conditional branching step.

```powershell
New-ConditionalStep -Name <string> -Condition <string> 
                   [-ThenSteps <hashtable[]>] [-ElseSteps <hashtable[]>]
```

**Parameters:**
- `Name` (string): Step name
- `Condition` (string): Condition to evaluate
- `ThenSteps` (hashtable[]): Steps to execute if true
- `ElseSteps` (hashtable[]): Steps to execute if false

**Returns:** Conditional step definition

**Example:**
```powershell
$conditionalStep = New-ConditionalStep -Name "Environment Check" -Condition '$params.environment -eq "prod"' -ThenSteps @(
    New-ScriptStep -Name "Prod Backup" -Command "Backup-Database -Full"
) -ElseSteps @(
    New-ScriptStep -Name "Dev Backup" -Command "Backup-Database -Incremental"
)
```

#### New-ParallelStep
Creates a parallel execution step.

```powershell
New-ParallelStep -Name <string> [-ParallelSteps <hashtable[]>]
```

**Parameters:**
- `Name` (string): Step name
- `ParallelSteps` (hashtable[]): Steps to execute in parallel

**Returns:** Parallel step definition

**Example:**
```powershell
$parallelStep = New-ParallelStep -Name "Multi-Server Deploy" -ParallelSteps @(
    New-ScriptStep -Name "Deploy Server1" -Command "Deploy-ToServer -Server srv1"
    New-ScriptStep -Name "Deploy Server2" -Command "Deploy-ToServer -Server srv2"
    New-ScriptStep -Name "Deploy Server3" -Command "Deploy-ToServer -Server srv3"
)
```

### Helper Functions

#### Import-PlaybookDefinition
Imports a playbook definition from file.

```powershell
Import-PlaybookDefinition -PlaybookName <string>
```

**Parameters:**
- `PlaybookName` (string): Playbook file name (without extension)

**Returns:** Import result object with definition

#### Validate-PlaybookDefinition
Validates a playbook definition for correctness.

```powershell
Validate-PlaybookDefinition -Definition <hashtable>
```

**Parameters:**
- `Definition` (hashtable): Playbook definition to validate

**Returns:** Validation result with errors/warnings

## Core Concepts

### Playbooks

Playbooks are declarative definitions of workflows:
- **Name**: Unique identifier
- **Description**: Human-readable description
- **Parameters**: Input parameters with types and defaults
- **Steps**: Ordered list of operations
- **RequiredModules**: Dependencies on AitherZero modules

### Workflows

Workflows are runtime instances of playbooks:
- **WorkflowId**: Unique execution identifier
- **Status**: Running, Completed, Failed, Stopped
- **Context**: Runtime parameters and environment
- **Results**: Step execution results
- **Duration**: Total execution time

### Steps

Steps are individual operations within a playbook:

#### Step Types
1. **Script**: Execute PowerShell or shell commands
2. **Condition**: Conditional branching logic
3. **Parallel**: Concurrent execution of sub-steps
4. **Module**: Invoke AitherZero module functions

#### Step Properties
- **name**: Descriptive name
- **type**: Step type (script, condition, parallel, module)
- **condition**: Optional condition for execution
- **command**: Command to execute (script steps)
- **shell**: Shell interpreter (script steps)
- **then/else**: Branches (conditional steps)
- **parallel**: Sub-steps (parallel steps)
- **module**: Module name (module steps)
- **function**: Function to call (module steps)

### Conditional Logic

Conditions support PowerShell expressions with variable substitution:
- `$env.context`: Current environment context
- `$params.<name>`: Playbook parameters
- PowerShell operators: -eq, -ne, -gt, -lt, -match, etc.

Example conditions:
```powershell
'$env.context -eq "prod"'
'$params.deployTarget -match "web-*"'
'$params.force -eq $true -or $params.skipValidation -ne $true'
```

## Usage Patterns

### Common Usage Scenarios

#### Infrastructure Deployment
```powershell
# Define deployment playbook
$deployPlaybook = New-PlaybookDefinition -Name "Infrastructure Deploy" -Steps @(
    New-ScriptStep -Name "Validate Config" -Command "Test-InfrastructureConfig"
    New-ConditionalStep -Name "Environment Check" -Condition '$env.context -eq "prod"' -ThenSteps @(
        New-ScriptStep -Name "Prod Approval" -Command "Request-ProductionApproval"
    )
    New-ParallelStep -Name "Deploy Components" -ParallelSteps @(
        New-ScriptStep -Name "Deploy Network" -Command "Deploy-NetworkStack"
        New-ScriptStep -Name "Deploy Compute" -Command "Deploy-ComputeStack"
        New-ScriptStep -Name "Deploy Storage" -Command "Deploy-StorageStack"
    )
    New-ScriptStep -Name "Verify Deployment" -Command "Test-DeploymentHealth"
)

# Execute deployment
$result = Invoke-PlaybookWorkflow -PlaybookDefinition $deployPlaybook -EnvironmentContext "staging"
```

#### Multi-Environment Promotion
```powershell
# Playbook with environment-specific logic
$promotionSteps = @(
    New-ScriptStep -Name "Build Package" -Command "Build-Application -Configuration Release"
    New-ConditionalStep -Name "Dev Deploy" -Condition '$params.targetEnv -eq "dev"' -ThenSteps @(
        New-ScriptStep -Name "Deploy to Dev" -Command "Deploy-ToDev -Package {{packagePath}}"
    )
    New-ConditionalStep -Name "Staging Deploy" -Condition '$params.targetEnv -eq "staging"' -ThenSteps @(
        New-ScriptStep -Name "Run Tests" -Command "Invoke-IntegrationTests"
        New-ScriptStep -Name "Deploy to Staging" -Command "Deploy-ToStaging -Package {{packagePath}}"
    )
)

$result = Invoke-PlaybookWorkflow -PlaybookDefinition @{
    name = "App Promotion"
    steps = $promotionSteps
} -Parameters @{
    targetEnv = "staging"
    packagePath = "./dist/app.zip"
}
```

#### Maintenance Operations
```powershell
# Create maintenance playbook file
$maintenancePlaybook = @{
    name = "System Maintenance"
    description = "Regular maintenance tasks"
    parameters = @{
        backupFirst = @{ type = "bool"; default = $true }
        notifyUsers = @{ type = "bool"; default = $true }
    }
    steps = @(
        @{
            name = "Pre-maintenance"
            type = "script"
            command = 'if ($params.notifyUsers) { Send-MaintenanceNotification }'
        },
        @{
            name = "Backup"
            type = "script"
            condition = '$params.backupFirst -eq $true'
            command = "Backup-System -Full"
        },
        @{
            name = "Maintenance Tasks"
            type = "parallel"
            parallel = @(
                @{ name = "Clean Logs"; type = "script"; command = "Clear-OldLogs -DaysToKeep 30" }
                @{ name = "Update Indexes"; type = "script"; command = "Update-DatabaseIndexes" }
                @{ name = "Clear Cache"; type = "script"; command = "Clear-ApplicationCache" }
            )
        }
    )
}

# Save to file
$maintenancePlaybook | ConvertTo-Json -Depth 10 | Set-Content "./orchestration/playbooks/maintenance.json"

# Execute from file
Invoke-PlaybookWorkflow -PlaybookName "maintenance" -Parameters @{ backupFirst = $true }
```

### Integration Examples

#### With OpenTofu Module
```powershell
$terraformPlaybook = New-PlaybookDefinition -Name "Terraform Deploy" -Steps @(
    @{
        name = "Initialize Terraform"
        type = "module"
        module = "OpenTofuProvider"
        function = "Initialize-OpenTofu"
        parameters = @{ WorkingDirectory = "./infrastructure" }
    },
    @{
        name = "Plan Infrastructure"
        type = "module"
        module = "OpenTofuProvider"
        function = "Plan-OpenTofu"
        parameters = @{ OutputPlan = $true }
    },
    @{
        name = "Apply Changes"
        type = "module"
        module = "OpenTofuProvider"
        function = "Apply-OpenTofu"
        parameters = @{ AutoApprove = $false }
    }
)
```

#### With PatchManager Module
```powershell
$patchWorkflow = New-PlaybookDefinition -Name "Automated Patching" -Steps @(
    New-ScriptStep -Name "Check Git Status" -Command "git status --porcelain"
    @{
        name = "Create Patch"
        type = "module"
        module = "PatchManager"
        function = "New-Patch"
        parameters = @{
            Description = "Automated infrastructure updates"
            Mode = "Standard"
        }
    }
)
```

### Best Practices

1. **Use descriptive names** for playbooks and steps
2. **Parameterize playbooks** for reusability
3. **Add conditions** for environment-specific logic
4. **Use parallel steps** for independent operations
5. **Enable dry-run** for testing before execution
6. **Monitor workflows** with Get-PlaybookStatus
7. **Store playbooks as files** for version control
8. **Validate playbooks** before execution
9. **Use continue-on-error** judiciously
10. **Implement proper error handling** in scripts

## Advanced Features

### Dynamic Parameter Substitution

Parameters can be embedded in commands using double braces:
```powershell
$step = New-ScriptStep -Name "Deploy" -Command "Deploy-App -Server {{serverName}} -Port {{port}}"

Invoke-PlaybookWorkflow -PlaybookDefinition $playbook -Parameters @{
    serverName = "web-prod-01"
    port = 8080
}
```

### Environment Context

Environment affects condition evaluation and module behavior:
```powershell
# Different behavior per environment
$step = New-ConditionalStep -Name "Backup Strategy" -Condition '$env.context -eq "prod"' -ThenSteps @(
    New-ScriptStep -Name "Full Backup" -Command "Backup-Full"
) -ElseSteps @(
    New-ScriptStep -Name "Quick Backup" -Command "Backup-Incremental"
)
```

### Workflow State Persistence

Workflows maintain state for monitoring and recovery:
- Active workflows tracked in memory
- Completed workflows stored in history
- State includes timing, results, and errors

### Module Integration

Direct integration with AitherZero modules:
```powershell
$moduleStep = @{
    name = "Configure System"
    type = "module"
    module = "SetupWizard"
    function = "Start-IntelligentSetup"
    parameters = @{
        MinimalSetup = $true
        SkipOptional = $true
    }
}
```

## Configuration

### Module-Specific Settings

The OrchestrationEngine uses these configuration paths:
- **Playbooks**: `<projectRoot>/orchestration/playbooks/`
- **Templates**: `<projectRoot>/orchestration/templates/`
- **Logs**: `<projectRoot>/orchestration/logs/`
- **State**: `<projectRoot>/orchestration/state/`

### Customization Options

1. **Custom playbook locations** via environment variables
2. **Execution timeout** configuration per step
3. **Parallel execution limits** based on resources
4. **Custom shell interpreters** for script steps
5. **Module search paths** for extensions

### Performance Tuning Parameters

- **Parallel throttle limit**: Control with ParallelExecution module
- **Step timeout**: Configure per-step execution limits
- **State retention**: Clean old workflow history
- **Logging verbosity**: Integrate with Logging module
- **Dry-run optimization**: Skip expensive validations

## Error Handling and Recovery

### Error Handling Strategies

1. **Step-level error handling**: Each step can fail independently
2. **Continue-on-error**: Workflow continues despite failures
3. **Conditional recovery**: Use conditions to handle errors
4. **Rollback steps**: Define compensating actions

Example error handling:
```powershell
$workflow = New-PlaybookDefinition -Name "Safe Deploy" -Steps @(
    New-ScriptStep -Name "Deploy" -Command "Deploy-Application"
    New-ConditionalStep -Name "Check Deploy" -Condition '$LASTEXITCODE -ne 0' -ThenSteps @(
        New-ScriptStep -Name "Rollback" -Command "Restore-PreviousVersion"
        New-ScriptStep -Name "Alert" -Command "Send-FailureAlert"
    )
)
```

### Workflow Recovery

- Monitor active workflows with Get-PlaybookStatus
- Stop problematic workflows with Stop-PlaybookWorkflow
- Review workflow history for debugging
- Use workflow IDs for correlation

## Examples and Templates

### Basic Playbook Template
```json
{
    "name": "Basic Workflow",
    "description": "Template for simple workflows",
    "version": "1.0",
    "parameters": {
        "target": {
            "type": "string",
            "required": true,
            "description": "Target system"
        }
    },
    "steps": [
        {
            "name": "Validate",
            "type": "script",
            "command": "Test-TargetSystem -Name {{target}}"
        },
        {
            "name": "Execute",
            "type": "script",
            "command": "Invoke-MainOperation -Target {{target}}"
        },
        {
            "name": "Verify",
            "type": "script",
            "command": "Test-OperationSuccess -Target {{target}}"
        }
    ]
}
```

### Complex Workflow Example
```powershell
# Multi-stage deployment with rollback
$complexWorkflow = New-PlaybookDefinition -Name "Production Deployment" -Description "Full production deployment with validation" -Steps @(
    # Pre-deployment validation
    New-ParallelStep -Name "Pre-flight Checks" -ParallelSteps @(
        New-ScriptStep -Name "Check Services" -Command "Test-ServiceHealth"
        New-ScriptStep -Name "Check Storage" -Command "Test-StorageCapacity"
        New-ScriptStep -Name "Check Network" -Command "Test-NetworkConnectivity"
    ),
    
    # Backup current state
    New-ScriptStep -Name "Create Backup" -Command "New-SystemBackup -Label 'pre-deploy'",
    
    # Phased deployment
    New-ConditionalStep -Name "Blue-Green Deploy" -Condition '$params.deployStrategy -eq "blue-green"' -ThenSteps @(
        New-ScriptStep -Name "Deploy to Blue" -Command "Deploy-ToEnvironment -Env Blue"
        New-ScriptStep -Name "Test Blue" -Command "Test-Environment -Env Blue"
        New-ScriptStep -Name "Switch Traffic" -Command "Switch-TrafficToBlue"
    ) -ElseSteps @(
        New-ScriptStep -Name "Rolling Deploy" -Command "Start-RollingDeployment"
    ),
    
    # Post-deployment validation
    New-ScriptStep -Name "Validate Deployment" -Command "Test-DeploymentComplete",
    
    # Conditional rollback
    New-ConditionalStep -Name "Rollback Check" -Condition '$LASTEXITCODE -ne 0' -ThenSteps @(
        New-ScriptStep -Name "Initiate Rollback" -Command "Start-Rollback -BackupLabel 'pre-deploy'"
        New-ScriptStep -Name "Alert Team" -Command "Send-RollbackNotification"
    )
) -Parameters @{
    deployStrategy = @{ type = "string"; default = "blue-green"; allowed = @("blue-green", "rolling") }
    notificationEmail = @{ type = "string"; required = $true }
}

# Execute with monitoring
$deployment = Invoke-PlaybookWorkflow -PlaybookDefinition $complexWorkflow -Parameters @{
    deployStrategy = "blue-green"
    notificationEmail = "ops-team@company.com"
} -EnvironmentContext "prod"

# Monitor progress
while ($deployment.Status -eq "Running") {
    $status = Get-PlaybookStatus -WorkflowId $deployment.WorkflowId
    Write-Host "Progress: $($status.CurrentStep)/$($status.TotalSteps)"
    Start-Sleep -Seconds 5
}
```