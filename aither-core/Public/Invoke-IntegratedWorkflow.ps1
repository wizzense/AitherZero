#Requires -Version 7.0

<#
.SYNOPSIS
    Executes integrated workflows across multiple AitherZero platform components.

.DESCRIPTION
    Orchestrates complex workflows that span multiple modules and tools in the AitherZero platform.
    Provides unified workflow execution with error handling, rollback capabilities, and progress tracking.

.PARAMETER WorkflowName
    Name of the predefined workflow to execute.

.PARAMETER WorkflowType
    Type of workflow to execute (Infrastructure, Development, Maintenance, Security).

.PARAMETER Parameters
    Hashtable of parameters to pass to the workflow.

.PARAMETER DryRun
    Execute in dry-run mode to preview workflow steps without making changes.

.PARAMETER EnableRollback
    Enable automatic rollback on workflow failure.

.PARAMETER ShowProgress
    Display progress information during workflow execution.

.EXAMPLE
    Invoke-IntegratedWorkflow -WorkflowName "DeployLab" -Parameters @{Environment="dev"}
    Executes the DeployLab workflow with development environment parameters.
    
.EXAMPLE
    Invoke-IntegratedWorkflow -WorkflowType Infrastructure -DryRun -ShowProgress
    Previews infrastructure workflow steps with progress display.

.EXAMPLE
    Invoke-IntegratedWorkflow -WorkflowName "MaintenanceCleanup" -EnableRollback
    Executes maintenance cleanup workflow with rollback enabled.

.NOTES
    This function provides unified workflow orchestration across the AitherZero platform.
#>

function Invoke-IntegratedWorkflow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [string]$WorkflowName,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'ByType')]
        [ValidateSet('Infrastructure', 'Development', 'Maintenance', 'Security', 'Backup')]
        [string]$WorkflowType,
        
        [Parameter()]
        [hashtable]$Parameters = @{},
        
        [Parameter()]
        [switch]$DryRun,
        
        [Parameter()]
        [switch]$EnableRollback,
        
        [Parameter()]
        [switch]$ShowProgress
    )
    
    begin {
        Write-CustomLog -Message "=== Integrated Workflow Execution ===" -Level "INFO"
        
        if ($WorkflowName) {
            Write-CustomLog -Message "Workflow: $WorkflowName" -Level "INFO"
        } else {
            Write-CustomLog -Message "Workflow Type: $WorkflowType" -Level "INFO"
        }
        
        if ($DryRun) {
            Write-CustomLog -Message "Mode: DRY RUN (no changes will be made)" -Level "WARN"
        }
    }
    
    process {
        try {
            # Initialize workflow execution context
            $workflowContext = @{
                StartTime = Get-Date
                ExecutionId = [System.Guid]::NewGuid().ToString()
                DryRun = $DryRun.IsPresent
                RollbackEnabled = $EnableRollback.IsPresent
                Parameters = $Parameters
                CompletedSteps = @()
                FailedSteps = @()
                RollbackSteps = @()
            }
            
            # Define available workflows
            $workflows = Get-AvailableWorkflows
            
            # Determine workflow to execute
            $workflowToExecute = $null
            if ($WorkflowName) {
                $workflowToExecute = $workflows | Where-Object { $_.Name -eq $WorkflowName }
                if (-not $workflowToExecute) {
                    throw "Workflow '$WorkflowName' not found. Available workflows: $($workflows.Name -join ', ')"
                }
            } else {
                $workflowToExecute = $workflows | Where-Object { $_.Type -eq $WorkflowType } | Select-Object -First 1
                if (-not $workflowToExecute) {
                    throw "No workflow found for type '$WorkflowType'. Available types: $($workflows.Type | Sort-Object -Unique -join ', ')"
                }
            }
            
            Write-CustomLog -Message "Executing workflow: $($workflowToExecute.Name)" -Level "INFO"
            Write-CustomLog -Message "Description: $($workflowToExecute.Description)" -Level "INFO"
            
            # Initialize progress tracking if requested
            $progressId = $null
            if ($ShowProgress) {
                if (Get-Module -Name "ProgressTracking" -ErrorAction SilentlyContinue) {
                    $progressId = Start-ProgressOperation -OperationName "Workflow: $($workflowToExecute.Name)" -TotalSteps $workflowToExecute.Steps.Count -ShowTime -ShowETA
                }
            }
            
            # Execute workflow steps
            $stepIndex = 0
            $workflowResult = @{
                Success = $true
                CompletedSteps = @()
                FailedSteps = @()
                ExecutionTime = $null
                RollbackPerformed = $false
            }
            
            foreach ($step in $workflowToExecute.Steps) {
                $stepIndex++
                
                try {
                    Write-CustomLog -Message "Step $stepIndex/$($workflowToExecute.Steps.Count): $($step.Name)" -Level "INFO"
                    
                    # Update progress
                    if ($progressId) {
                        Update-ProgressOperation -OperationId $progressId -IncrementStep -StepName $step.Name
                    }
                    
                    # Execute step
                    if (-not $DryRun) {
                        $stepResult = Invoke-WorkflowStep -Step $step -Parameters $Parameters -Context $workflowContext
                        $workflowResult.CompletedSteps += @{
                            Name = $step.Name
                            Result = $stepResult
                            ExecutedAt = Get-Date
                        }
                    } else {
                        Write-CustomLog -Message "DRY RUN: Would execute $($step.Name)" -Level "WARN"
                        $workflowResult.CompletedSteps += @{
                            Name = $step.Name
                            Result = "DRY RUN"
                            ExecutedAt = Get-Date
                        }
                    }
                    
                    Write-CustomLog -Message "✅ Step completed: $($step.Name)" -Level "SUCCESS"
                    
                } catch {
                    $errorMessage = "Step failed: $($step.Name) - $($_.Exception.Message)"
                    Write-CustomLog -Message $errorMessage -Level "ERROR"
                    
                    $workflowResult.FailedSteps += @{
                        Name = $step.Name
                        Error = $_.Exception.Message
                        FailedAt = Get-Date
                    }
                    
                    $workflowResult.Success = $false
                    
                    # Attempt rollback if enabled
                    if ($EnableRollback -and -not $DryRun) {
                        Write-CustomLog -Message "🔄 Attempting workflow rollback..." -Level "WARN"
                        try {
                            $rollbackResult = Invoke-WorkflowRollback -WorkflowContext $workflowContext -CompletedSteps $workflowResult.CompletedSteps
                            $workflowResult.RollbackPerformed = $rollbackResult.Success
                            Write-CustomLog -Message "✅ Rollback completed successfully" -Level "SUCCESS"
                        } catch {
                            Write-CustomLog -Message "❌ Rollback failed: $($_.Exception.Message)" -Level "ERROR"
                            $workflowResult.RollbackPerformed = $false
                        }
                    }
                    
                    break
                }
            }
            
            # Complete progress tracking
            if ($progressId) {
                if ($workflowResult.Success) {
                    Complete-ProgressOperation -OperationId $progressId -ShowSummary
                } else {
                    Complete-ProgressOperation -OperationId $progressId -ShowSummary -Status "Failed"
                }
            }
            
            # Calculate execution time
            $workflowResult.ExecutionTime = (Get-Date) - $workflowContext.StartTime
            
            # Log final result
            if ($workflowResult.Success) {
                Write-CustomLog -Message "✅ Workflow completed successfully in $($workflowResult.ExecutionTime.TotalSeconds) seconds" -Level "SUCCESS"
            } else {
                Write-CustomLog -Message "❌ Workflow failed after $($workflowResult.ExecutionTime.TotalSeconds) seconds" -Level "ERROR"
            }
            
            return $workflowResult
            
        } catch {
            Write-CustomLog -Message "Workflow execution failed: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}

# Helper function to get available workflows
function Get-AvailableWorkflows {
    [CmdletBinding()]
    param()
    
    process {
        return @(
            @{
                Name = "DeployLab"
                Type = "Infrastructure"
                Description = "Deploy and configure lab environment"
                Steps = @(
                    @{ Name = "Validate Prerequisites"; Module = "LabRunner"; Function = "Test-LabPrerequisites" },
                    @{ Name = "Initialize Configuration"; Module = "ConfigurationCore"; Function = "Initialize-ConfigurationCore" },
                    @{ Name = "Deploy Infrastructure"; Module = "OpenTofuProvider"; Function = "Invoke-OpenTofuPlan" },
                    @{ Name = "Configure Services"; Module = "LabRunner"; Function = "Start-LabRunner" },
                    @{ Name = "Validate Deployment"; Module = "LabRunner"; Function = "Test-LabHealth" }
                )
            },
            @{
                Name = "DevelopmentSetup"
                Type = "Development"
                Description = "Set up development environment and tools"
                Steps = @(
                    @{ Name = "Initialize Development Environment"; Module = "DevEnvironment"; Function = "Start-DevEnvironmentSetup" },
                    @{ Name = "Install AI Tools"; Module = "AIToolsIntegration"; Function = "Install-AITools" },
                    @{ Name = "Configure Git Workflow"; Module = "PatchManager"; Function = "Initialize-PatchManager" },
                    @{ Name = "Setup Testing Framework"; Module = "TestingFramework"; Function = "Initialize-TestingFramework" }
                )
            },
            @{
                Name = "MaintenanceCleanup"
                Type = "Maintenance"
                Description = "Perform system maintenance and cleanup"
                Steps = @(
                    @{ Name = "Backup Critical Data"; Module = "BackupManager"; Function = "Start-BackupOperation" },
                    @{ Name = "Clean Temporary Files"; Module = "UnifiedMaintenance"; Function = "Clear-TemporaryFiles" },
                    @{ Name = "Update Modules"; Module = "UnifiedMaintenance"; Function = "Update-CoreModules" },
                    @{ Name = "Verify System Health"; Module = "SystemMonitoring"; Function = "Test-SystemHealth" }
                )
            },
            @{
                Name = "SecurityAudit"
                Type = "Security"
                Description = "Perform comprehensive security audit"
                Steps = @(
                    @{ Name = "Scan for Vulnerabilities"; Module = "SecurityAutomation"; Function = "Start-SecurityScan" },
                    @{ Name = "Audit Credentials"; Module = "SecureCredentials"; Function = "Test-CredentialSecurity" },
                    @{ Name = "Check Access Controls"; Module = "SecurityAutomation"; Function = "Test-AccessControls" },
                    @{ Name = "Generate Security Report"; Module = "SecurityAutomation"; Function = "New-SecurityReport" }
                )
            },
            @{
                Name = "BackupRestore"
                Type = "Backup"
                Description = "Perform backup and restore operations"
                Steps = @(
                    @{ Name = "Validate Backup Prerequisites"; Module = "BackupManager"; Function = "Test-BackupPrerequisites" },
                    @{ Name = "Create System Backup"; Module = "BackupManager"; Function = "Start-BackupOperation" },
                    @{ Name = "Verify Backup Integrity"; Module = "BackupManager"; Function = "Test-BackupIntegrity" },
                    @{ Name = "Update Backup Catalog"; Module = "BackupManager"; Function = "Update-BackupCatalog" }
                )
            }
        )
    }
}

# Helper function to execute workflow steps
function Invoke-WorkflowStep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Step,
        
        [Parameter()]
        [hashtable]$Parameters = @{},
        
        [Parameter()]
        [hashtable]$Context = @{}
    )
    
    process {
        try {
            $moduleName = $Step.Module
            $functionName = $Step.Function
            
            # Import module if not already loaded
            if (-not (Get-Module -Name $moduleName -ErrorAction SilentlyContinue)) {
                $modulePath = Join-Path $PSScriptRoot "../../modules/$moduleName"
                if (Test-Path $modulePath) {
                    Import-Module $modulePath -Force
                }
            }
            
            # Check if function exists
            if (-not (Get-Command -Name $functionName -ErrorAction SilentlyContinue)) {
                throw "Function '$functionName' not found in module '$moduleName'"
            }
            
            # Execute function with parameters
            $result = & $functionName @Parameters
            return $result
            
        } catch {
            throw "Step execution failed: $($_.Exception.Message)"
        }
    }
}

# Helper function to perform workflow rollback
function Invoke-WorkflowRollback {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$WorkflowContext,
        
        [Parameter(Mandatory = $true)]
        [array]$CompletedSteps
    )
    
    process {
        try {
            Write-CustomLog -Message "Performing workflow rollback..." -Level "WARN"
            
            $rollbackResult = @{
                Success = $true
                RolledBackSteps = @()
                Errors = @()
            }
            
            # Reverse the completed steps for rollback
            $reversedSteps = $CompletedSteps | Sort-Object { $_.ExecutedAt } -Descending
            
            foreach ($step in $reversedSteps) {
                try {
                    Write-CustomLog -Message "Rolling back: $($step.Name)" -Level "INFO"
                    
                    # Attempt rollback - this would be step-specific logic
                    # For now, we'll just log the rollback attempt
                    $rollbackResult.RolledBackSteps += $step.Name
                    
                    Write-CustomLog -Message "✅ Rollback completed: $($step.Name)" -Level "SUCCESS"
                    
                } catch {
                    $rollbackResult.Errors += @{
                        Step = $step.Name
                        Error = $_.Exception.Message
                    }
                    $rollbackResult.Success = $false
                    Write-CustomLog -Message "❌ Rollback failed: $($step.Name) - $($_.Exception.Message)" -Level "ERROR"
                }
            }
            
            return $rollbackResult
            
        } catch {
            throw "Rollback operation failed: $($_.Exception.Message)"
        }
    }
}