# Orchestration Engine Module for AitherZero
# Advanced workflow and playbook execution with conditional logic and parallel processing

# Import required modules
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

# Import logging if available
$loggingModule = Join-Path $projectRoot "aither-core/modules/Logging"
if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force -ErrorAction SilentlyContinue
}

# Import ParallelExecution if available
$parallelModule = Join-Path $projectRoot "aither-core/modules/ParallelExecution"
if (Test-Path $parallelModule) {
    Import-Module $parallelModule -Force -ErrorAction SilentlyContinue
}

# Global variables for workflow tracking
$Script:ActiveWorkflows = @{}
$Script:WorkflowHistory = @()
$Script:PlaybooksPath = Join-Path $projectRoot "orchestration/playbooks"

# Initialize orchestration directory structure
function Initialize-OrchestrationEngine {
    $paths = @(
        (Join-Path $projectRoot "orchestration"),
        (Join-Path $projectRoot "orchestration/playbooks"),
        (Join-Path $projectRoot "orchestration/templates"),
        (Join-Path $projectRoot "orchestration/logs"),
        (Join-Path $projectRoot "orchestration/state")
    )

    foreach ($path in $paths) {
        if (-not (Test-Path $path)) {
            New-Item -Path $path -ItemType Directory -Force | Out-Null
        }
    }
}

function Invoke-PlaybookWorkflow {
    <#
    .SYNOPSIS
        Executes a playbook workflow with conditional logic and parallel execution
    .DESCRIPTION
        Main orchestration function that processes playbook definitions and executes steps
    #>
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName = 'PlaybookName', Mandatory)]
        [string]$PlaybookName,

        [Parameter(ParameterSetName = 'PlaybookDefinition', Mandatory)]
        [hashtable]$PlaybookDefinition,

        [hashtable]$Parameters = @{},

        [ValidateSet('sequential', 'parallel', 'conditional')]
        [string]$ExecutionMode = 'sequential',

        [ValidateSet('dev', 'staging', 'prod')]
        [string]$EnvironmentContext = 'dev',

        [switch]$DryRun,

        [switch]$ContinueOnError,

        [string]$WorkflowId
    )

    try {
        # Generate workflow ID if not provided
        if (-not $WorkflowId) {
            $WorkflowId = "workflow-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$((Get-Random -Minimum 1000 -Maximum 9999))"
        }

        Write-CustomLog -Level 'INFO' -Message "Starting playbook workflow: $WorkflowId"

        # Load playbook definition
        if ($PlaybookName) {
            $playbook = Import-PlaybookDefinition -PlaybookName $PlaybookName
            if (-not $playbook.Success) {
                throw "Failed to load playbook '$PlaybookName': $($playbook.Error)"
            }
            $PlaybookDefinition = $playbook.Definition
        }

        # Validate playbook definition
        $validationResult = Validate-PlaybookDefinition -Definition $PlaybookDefinition
        if (-not $validationResult.IsValid) {
            throw "Playbook validation failed: $($validationResult.Errors -join '; ')"
        }

        # Create workflow context
        $workflowContext = @{
            WorkflowId = $WorkflowId
            PlaybookName = $PlaybookName ?? 'inline'
            StartTime = Get-Date
            ExecutionMode = $ExecutionMode
            EnvironmentContext = $EnvironmentContext
            Parameters = $Parameters
            DryRun = $DryRun
            ContinueOnError = $ContinueOnError
            Status = 'Running'
            CurrentStep = 0
            TotalSteps = $PlaybookDefinition.steps.Count
            Results = @()
            Errors = @()
        }

        # Register active workflow
        $Script:ActiveWorkflows[$WorkflowId] = $workflowContext

        # Execute playbook steps
        $executionResult = Execute-PlaybookSteps -Definition $PlaybookDefinition -Context $workflowContext

        # Update final status
        $workflowContext.Status = if ($executionResult.Success) { 'Completed' } else { 'Failed' }
        $workflowContext.EndTime = Get-Date
        $workflowContext.Duration = $workflowContext.EndTime - $workflowContext.StartTime

        # Move to history
        $Script:WorkflowHistory += $workflowContext
        $Script:ActiveWorkflows.Remove($WorkflowId)

        Write-CustomLog -Level $(if ($executionResult.Success) { 'SUCCESS' } else { 'ERROR' }) -Message "Workflow $WorkflowId completed with status: $($workflowContext.Status)"

        return @{
            Success = $executionResult.Success
            WorkflowId = $WorkflowId
            Status = $workflowContext.Status
            Duration = $workflowContext.Duration
            Results = $workflowContext.Results
            Errors = $workflowContext.Errors
            StepsExecuted = $workflowContext.CurrentStep
            TotalSteps = $workflowContext.TotalSteps
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Workflow execution failed: $_"

        # Update context if it exists
        if ($Script:ActiveWorkflows.ContainsKey($WorkflowId)) {
            $Script:ActiveWorkflows[$WorkflowId].Status = 'Failed'
            $Script:ActiveWorkflows[$WorkflowId].Errors += $_.Exception.Message
        }

        return @{
            Success = $false
            WorkflowId = $WorkflowId
            Error = $_.Exception.Message
        }
    }
}

function Execute-PlaybookSteps {
    param(
        [hashtable]$Definition,
        [hashtable]$Context
    )

    try {
        $allSuccess = $true

        foreach ($step in $Definition.steps) {
            $Context.CurrentStep++

            Write-CustomLog -Level 'INFO' -Message "Executing step $($Context.CurrentStep)/$($Context.TotalSteps): $($step.name)"

            # Check if step should be executed based on conditions
            if ($step.condition) {
                $conditionResult = Evaluate-StepCondition -Condition $step.condition -Context $Context
                if (-not $conditionResult) {
                    Write-CustomLog -Level 'INFO' -Message "Skipping step '$($step.name)' - condition not met"
                    continue
                }
            }

            # Execute step based on type
            $stepResult = switch ($step.type) {
                'script' {
                    Execute-ScriptStep -Step $step -Context $Context
                }
                'condition' {
                    Execute-ConditionalStep -Step $step -Context $Context
                }
                'parallel' {
                    Execute-ParallelStep -Step $step -Context $Context
                }
                'module' {
                    Execute-ModuleStep -Step $step -Context $Context
                }
                default {
                    @{
                        Success = $false
                        Error = "Unknown step type: $($step.type)"
                    }
                }
            }

            # Record step result
            $stepRecord = @{
                StepNumber = $Context.CurrentStep
                StepName = $step.name
                StepType = $step.type
                Success = $stepResult.Success
                StartTime = Get-Date
                Duration = $stepResult.Duration ?? (New-TimeSpan)
                Output = $stepResult.Output
                Error = $stepResult.Error
            }

            $Context.Results += $stepRecord

            # Handle step failure
            if (-not $stepResult.Success) {
                $allSuccess = $false
                $Context.Errors += "Step '$($step.name)' failed: $($stepResult.Error)"

                Write-CustomLog -Level 'ERROR' -Message "Step failed: $($step.name) - $($stepResult.Error)"

                if (-not $Context.ContinueOnError) {
                    Write-CustomLog -Level 'ERROR' -Message "Stopping workflow due to step failure"
                    break
                }
            } else {
                Write-CustomLog -Level 'SUCCESS' -Message "Step completed: $($step.name)"
            }
        }

        return @{
            Success = $allSuccess
            Message = if ($allSuccess) { "All steps completed successfully" } else { "Some steps failed" }
        }

    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Execute-ScriptStep {
    param(
        [hashtable]$Step,
        [hashtable]$Context
    )

    try {
        $startTime = Get-Date

        if ($Context.DryRun) {
            Write-CustomLog -Level 'INFO' -Message "DRY RUN: Would execute script: $($Step.command)"
            return @{
                Success = $true
                Output = "DRY RUN: Script step simulation"
                Duration = (Get-Date) - $startTime
            }
        }

        # Replace parameters in command
        $command = $Step.command
        foreach ($param in $Context.Parameters.Keys) {
            $command = $command -replace "\{\{$param\}\}", $Context.Parameters[$param]
        }

        # Execute command
        if ($Step.shell -eq 'powershell' -or -not $Step.shell) {
            $result = Invoke-Expression $command 2>&1
            $success = $LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE
        } else {
            # For other shells, use external execution
            $result = & $Step.shell -c $command 2>&1
            $success = $LASTEXITCODE -eq 0
        }

        return @{
            Success = $success
            Output = $result
            Duration = (Get-Date) - $startTime
            Error = if (-not $success) { "Command failed with exit code: $LASTEXITCODE" } else { $null }
        }

    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            Duration = (Get-Date) - $startTime
        }
    }
}

function Execute-ConditionalStep {
    param(
        [hashtable]$Step,
        [hashtable]$Context
    )

    try {
        $startTime = Get-Date

        # Evaluate condition
        $conditionResult = Evaluate-StepCondition -Condition $Step.condition -Context $Context

        # Execute appropriate branch
        if ($conditionResult -and $Step.then) {
            $branchResult = Execute-PlaybookSteps -Definition @{ steps = $Step.then } -Context $Context
        } elseif (-not $conditionResult -and $Step.else) {
            $branchResult = Execute-PlaybookSteps -Definition @{ steps = $Step.else } -Context $Context
        } else {
            $branchResult = @{ Success = $true; Message = "No matching branch to execute" }
        }

        return @{
            Success = $branchResult.Success
            Output = "Condition: $conditionResult, Branch executed: $(if ($conditionResult) { 'then' } else { 'else' })"
            Duration = (Get-Date) - $startTime
            Error = $branchResult.Error
        }

    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            Duration = (Get-Date) - $startTime
        }
    }
}

function Execute-ParallelStep {
    param(
        [hashtable]$Step,
        [hashtable]$Context
    )

    try {
        $startTime = Get-Date

        if ($Context.DryRun) {
            Write-CustomLog -Level 'INFO' -Message "DRY RUN: Would execute $($Step.parallel.Count) parallel steps"
            return @{
                Success = $true
                Output = "DRY RUN: Parallel execution simulation"
                Duration = (Get-Date) - $startTime
            }
        }

        # Check if ParallelExecution module is available
        if (Get-Command Start-ParallelExecution -ErrorAction SilentlyContinue) {
            # Use AitherZero's ParallelExecution module
            $parallelJobs = @()
            foreach ($parallelStep in $Step.parallel) {
                $parallelJobs += @{
                    Name = $parallelStep.name
                    ScriptBlock = {
                        param($StepDef, $StepContext)
                        # Execute the parallel step based on its type
                        switch ($StepDef.type) {
                            'script' {
                                # Replace parameters in command
                                $command = $StepDef.command
                                if ($StepContext -and $StepContext.Parameters) {
                                    foreach ($param in $StepContext.Parameters.Keys) {
                                        $command = $command -replace "\{\{$param\}\}", $StepContext.Parameters[$param]
                                    }
                                }
                                # Execute script command
                                $result = Invoke-Expression $command
                                return @{
                                    Success = $true
                                    Output = $result
                                    Duration = New-TimeSpan
                                }
                            }
                            'module' {
                                # Execute module function
                                if ($StepDef.module -and $StepDef.function) {
                                    $result = & $StepDef.function @($StepDef.parameters ?? @{})
                                    return @{
                                        Success = $true
                                        Output = $result
                                        Duration = New-TimeSpan
                                    }
                                } else {
                                    return @{
                                        Success = $false
                                        Error = "Module or function not specified for module step"
                                        Duration = New-TimeSpan
                                    }
                                }
                            }
                            default {
                                return @{
                                    Success = $false
                                    Error = "Unsupported step type in parallel execution: $($StepDef.type)"
                                    Duration = New-TimeSpan
                                }
                            }
                        }
                    }
                    Arguments = @($parallelStep, $Context)
                }
            }

            # Execute all jobs in parallel
            $parallelResult = Start-ParallelExecution -Jobs $parallelJobs -MaxConcurrentJobs 4

            return @{
                Success = $parallelResult.Success
                Output = "Parallel execution: $($parallelResult.CompletedJobs)/$($parallelResult.TotalJobs) jobs completed"
                Duration = (Get-Date) - $startTime
                Error = if (-not $parallelResult.Success) { "Some parallel jobs failed: $($parallelResult.Errors -join '; ')" } else { $null }
            }
        } else {
            # Fallback to PowerShell jobs
            $jobs = @()
            foreach ($parallelStep in $Step.parallel) {
                $job = Start-Job -ScriptBlock {
                    param($StepDef)
                    Invoke-Expression $StepDef.command
                } -ArgumentList $parallelStep
                $jobs += $job
            }

            # Wait for all jobs to complete
            $jobs | Wait-Job | Out-Null

            # Collect results
            $allSuccess = $true
            $outputs = @()
            foreach ($job in $jobs) {
                $jobResult = Receive-Job $job
                $outputs += $jobResult
                if ($job.State -ne 'Completed') {
                    $allSuccess = $false
                }
                Remove-Job $job
            }

            return @{
                Success = $allSuccess
                Output = $outputs -join "`n"
                Duration = (Get-Date) - $startTime
                Error = if (-not $allSuccess) { "Some parallel jobs failed" } else { $null }
            }
        }

    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            Duration = (Get-Date) - $startTime
        }
    }
}

function Execute-ModuleStep {
    param(
        [hashtable]$Step,
        [hashtable]$Context
    )

    try {
        $startTime = Get-Date

        if ($Context.DryRun) {
            Write-CustomLog -Level 'INFO' -Message "DRY RUN: Would execute module: $($Step.module)"
            return @{
                Success = $true
                Output = "DRY RUN: Module execution simulation"
                Duration = (Get-Date) - $startTime
            }
        }

        # Load and execute AitherZero module
        $modulePath = Join-Path $projectRoot "aither-core/modules/$($Step.module)"
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force

            # Execute module function
            if ($Step.function) {
                $result = & $Step.function @($Step.parameters ?? @{})
            } else {
                $result = "Module $($Step.module) loaded successfully"
            }

            return @{
                Success = $true
                Output = $result
                Duration = (Get-Date) - $startTime
            }
        } else {
            throw "Module not found: $($Step.module)"
        }

    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            Duration = (Get-Date) - $startTime
        }
    }
}

function Evaluate-StepCondition {
    param(
        [string]$Condition,
        [hashtable]$Context
    )

    try {
        # Replace variables in condition
        $evaluatedCondition = $Condition

        # Replace environment context
        $evaluatedCondition = $evaluatedCondition -replace '\$env\.context', "'$($Context.EnvironmentContext)'"

        # Replace parameters
        foreach ($param in $Context.Parameters.Keys) {
            $evaluatedCondition = $evaluatedCondition -replace "\`$params\.$param", "'$($Context.Parameters[$param])'"
        }

        # Evaluate the condition
        $result = Invoke-Expression $evaluatedCondition
        return [bool]$result

    } catch {
        Write-CustomLog -Level 'WARNING' -Message "Condition evaluation failed: $Condition - $_"
        return $false
    }
}

function New-PlaybookDefinition {
    <#
    .SYNOPSIS
        Creates a new playbook definition structure
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [string]$Description,

        [string]$Version = '1.0',

        [hashtable[]]$Steps = @(),

        [hashtable]$Parameters = @{},

        [string[]]$RequiredModules = @()
    )

    $playbook = @{
        name = $Name
        description = $Description ?? "Playbook: $Name"
        version = $Version
        created = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        parameters = $Parameters
        requiredModules = $RequiredModules
        steps = $Steps
    }

    return $playbook
}

function Import-PlaybookDefinition {
    <#
    .SYNOPSIS
        Imports a playbook definition from file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PlaybookName
    )

    try {
        Initialize-OrchestrationEngine

        # Look for playbook file
        $playbookFile = $null
        $extensions = @('.json', '.yaml', '.yml')

        foreach ($ext in $extensions) {
            $testPath = Join-Path $Script:PlaybooksPath "$PlaybookName$ext"
            if (Test-Path $testPath) {
                $playbookFile = $testPath
                break
            }
        }

        if (-not $playbookFile) {
            throw "Playbook file not found: $PlaybookName"
        }

        # Load based on file extension
        switch ((Get-Item $playbookFile).Extension) {
            '.json' {
                $definition = Get-Content $playbookFile | ConvertFrom-Json -AsHashtable
            }
            { $_ -in @('.yaml', '.yml') } {
                # Note: Would need PowerShell-Yaml module for YAML support
                throw "YAML playbooks not yet supported. Use JSON format."
            }
        }

        return @{
            Success = $true
            Definition = $definition
            SourceFile = $playbookFile
        }

    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Validate-PlaybookDefinition {
    <#
    .SYNOPSIS
        Validates a playbook definition for correctness
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Definition
    )

    $errors = @()
    $warnings = @()

    # Check required fields
    if (-not $Definition.name) {
        $errors += "Playbook name is required"
    }

    if (-not $Definition.steps -or $Definition.steps.Count -eq 0) {
        $errors += "Playbook must have at least one step"
    }

    # Validate each step
    if ($Definition.steps) {
        for ($i = 0; $i -lt $Definition.steps.Count; $i++) {
            $step = $Definition.steps[$i]
            $stepErrors = Validate-PlaybookStep -Step $step -StepNumber ($i + 1)
            $errors += $stepErrors
        }
    }

    return @{
        IsValid = ($errors.Count -eq 0)
        Errors = $errors
        Warnings = $warnings
    }
}

function Validate-PlaybookStep {
    param([hashtable]$Step, [int]$StepNumber)

    $errors = @()

    if (-not $Step.name) {
        $errors += "Step ${StepNumber}: name is required"
    }

    if (-not $Step.type) {
        $errors += "Step ${StepNumber}: type is required"
    } elseif ($Step.type -notin @('script', 'condition', 'parallel', 'module')) {
        $errors += "Step ${StepNumber}: invalid type '$($Step.type)'"
    }

    # Type-specific validation
    switch ($Step.type) {
        'script' {
            if (-not $Step.command) {
                $errors += "Step ${StepNumber}: script steps require 'command' property"
            }
        }
        'condition' {
            if (-not $Step.condition) {
                $errors += "Step ${StepNumber}: conditional steps require 'condition' property"
            }
        }
        'parallel' {
            if (-not $Step.parallel -or $Step.parallel.Count -eq 0) {
                $errors += "Step ${StepNumber}: parallel steps require 'parallel' array with sub-steps"
            }
        }
        'module' {
            if (-not $Step.module) {
                $errors += "Step ${StepNumber}: module steps require 'module' property"
            }
        }
    }

    return $errors
}

function Get-PlaybookStatus {
    <#
    .SYNOPSIS
        Gets the status of running or completed workflows
    #>
    [CmdletBinding()]
    param(
        [string]$WorkflowId
    )

    if ($WorkflowId) {
        # Get specific workflow
        if ($Script:ActiveWorkflows.ContainsKey($WorkflowId)) {
            return $Script:ActiveWorkflows[$WorkflowId]
        } else {
            $historical = $Script:WorkflowHistory | Where-Object { $_.WorkflowId -eq $WorkflowId }
            return $historical
        }
    } else {
        # Get all workflows
        return @{
            Active = $Script:ActiveWorkflows.Values
            History = $Script:WorkflowHistory
            TotalActive = $Script:ActiveWorkflows.Count
            TotalHistory = $Script:WorkflowHistory.Count
        }
    }
}

function Stop-PlaybookWorkflow {
    <#
    .SYNOPSIS
        Stops a running workflow
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$WorkflowId
    )

    if ($Script:ActiveWorkflows.ContainsKey($WorkflowId)) {
        $workflow = $Script:ActiveWorkflows[$WorkflowId]
        $workflow.Status = 'Stopped'
        $workflow.EndTime = Get-Date
        $workflow.Duration = $workflow.EndTime - $workflow.StartTime

        # Move to history
        $Script:WorkflowHistory += $workflow
        $Script:ActiveWorkflows.Remove($WorkflowId)

        Write-CustomLog -Level 'INFO' -Message "Workflow $WorkflowId stopped"
        return @{ Success = $true; Message = "Workflow stopped" }
    } else {
        return @{ Success = $false; Error = "Workflow not found or not active" }
    }
}

# Helper functions for creating step definitions
function New-ScriptStep {
    param(
        [string]$Name,
        [string]$Command,
        [string]$Shell = 'powershell',
        [string]$Condition
    )

    $step = @{
        name = $Name
        type = 'script'
        command = $Command
        shell = $Shell
    }

    if ($Condition) {
        $step.condition = $Condition
    }

    return $step
}

function New-ConditionalStep {
    param(
        [string]$Name,
        [string]$Condition,
        [hashtable[]]$ThenSteps = @(),
        [hashtable[]]$ElseSteps = @()
    )

    return @{
        name = $Name
        type = 'condition'
        condition = $Condition
        then = $ThenSteps
        else = $ElseSteps
    }
}

function New-ParallelStep {
    param(
        [string]$Name,
        [hashtable[]]$ParallelSteps = @()
    )

    return @{
        name = $Name
        type = 'parallel'
        parallel = $ParallelSteps
    }
}

# Logging fallback functions
if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
    function Write-CustomLog {
        param(
            [string]$Level,
            [string]$Message
        )
        $color = switch ($Level) {
            'SUCCESS' { 'Green' }
            'ERROR' { 'Red' }
            'WARNING' { 'Yellow' }
            'INFO' { 'Cyan' }
            default { 'White' }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
}

# Initialize on module load
Initialize-OrchestrationEngine

# Export functions
Export-ModuleMember -Function @(
    'Invoke-PlaybookWorkflow',
    'New-PlaybookDefinition',
    'Import-PlaybookDefinition',
    'Validate-PlaybookDefinition',
    'Get-PlaybookStatus',
    'Stop-PlaybookWorkflow',
    'New-ConditionalStep',
    'New-ParallelStep',
    'New-ScriptStep'
)
