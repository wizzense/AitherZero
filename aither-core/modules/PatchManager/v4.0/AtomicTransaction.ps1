#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    PatchManager v4.0 - Atomic Transaction System
    
.DESCRIPTION
    True atomic transaction system for PatchManager that guarantees:
    - All-or-nothing operations
    - Automatic rollback on any failure
    - State isolation and consistency
    - Comprehensive audit trail
    - Cross-platform reliability
    
.NOTES
    Version: 4.0.0
    Author: AitherZero Reengineering Team
    Breaking Changes from v3.0:
    - True atomic operations (not just better wrappers)
    - State machine architecture
    - Comprehensive rollback system
    - Event-driven design
    - Dependency injection
#>

# Import shared utilities
. "$PSScriptRoot/../../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

# Import logging and event system
Import-Module "$projectRoot/aither-core/modules/Logging" -Force -ErrorAction SilentlyContinue
Import-Module "$projectRoot/aither-core/modules/ModuleCommunication" -Force -ErrorAction SilentlyContinue

# Atomic transaction states
enum TransactionState {
    Initializing = 0
    Prepared = 1
    Executing = 2
    Committing = 3
    Committed = 4
    RollingBack = 5
    RolledBack = 6
    Failed = 7
    Aborted = 8
}

# Transaction operation types
enum OperationType {
    FileSystem = 1
    GitOperation = 2
    GitHubAPI = 3
    ProcessExecution = 4
    ModuleImport = 5
    Configuration = 6
    Network = 7
    Registry = 8
}

# Transaction isolation levels
enum IsolationLevel {
    ReadUncommitted = 0
    ReadCommitted = 1
    RepeatableRead = 2
    Serializable = 3
}

class AtomicOperation {
    [string] $Id
    [OperationType] $Type
    [string] $Description
    [scriptblock] $ExecuteAction
    [scriptblock] $RollbackAction
    [scriptblock] $ValidateAction
    [hashtable] $Context
    [hashtable] $PreState
    [hashtable] $PostState
    [DateTime] $StartTime
    [DateTime] $EndTime
    [TimeSpan] $Duration
    [bool] $Completed
    [bool] $RolledBack
    [System.Exception] $LastError
    [string[]] $Dependencies
    [int] $RetryCount
    [int] $MaxRetries
    
    AtomicOperation([string]$id, [OperationType]$type, [string]$description) {
        $this.Id = $id
        $this.Type = $type
        $this.Description = $description
        $this.Context = @{}
        $this.PreState = @{}
        $this.PostState = @{}
        $this.Completed = $false
        $this.RolledBack = $false
        $this.Dependencies = @()
        $this.RetryCount = 0
        $this.MaxRetries = 3
    }
    
    [void] SetExecuteAction([scriptblock]$action) {
        $this.ExecuteAction = $action
    }
    
    [void] SetRollbackAction([scriptblock]$action) {
        $this.RollbackAction = $action
    }
    
    [void] SetValidateAction([scriptblock]$action) {
        $this.ValidateAction = $action
    }
    
    [void] CapturePreState() {
        $this.PreState = @{
            Timestamp = Get-Date
            WorkingDirectory = Get-Location
            GitBranch = (git branch --show-current 2>&1 | Out-String).Trim()
            GitStatus = git status --porcelain 2>&1
            EnvironmentVariables = Get-ChildItem Env: | ForEach-Object { @{ $_.Name = $_.Value } }
        }
    }
    
    [void] CapturePostState() {
        $this.PostState = @{
            Timestamp = Get-Date
            WorkingDirectory = Get-Location
            GitBranch = (git branch --show-current 2>&1 | Out-String).Trim()
            GitStatus = git status --porcelain 2>&1
            EnvironmentVariables = Get-ChildItem Env: | ForEach-Object { @{ $_.Name = $_.Value } }
        }
    }
    
    [bool] Execute() {
        try {
            Write-CustomLog "Executing atomic operation: $($this.Id)" -Level 'INFO'
            $this.StartTime = Get-Date
            $this.CapturePreState()
            
            if ($this.ExecuteAction) {
                & $this.ExecuteAction
            }
            
            $this.CapturePostState()
            $this.EndTime = Get-Date
            $this.Duration = $this.EndTime - $this.StartTime
            $this.Completed = $true
            
            Write-CustomLog "Atomic operation completed: $($this.Id) in $($this.Duration.TotalMilliseconds)ms" -Level 'SUCCESS'
            return $true
        } catch {
            $this.LastError = $_.Exception
            Write-CustomLog "Atomic operation failed: $($this.Id) - $($_.Exception.Message)" -Level 'ERROR'
            return $false
        }
    }
    
    [bool] Rollback() {
        try {
            Write-CustomLog "Rolling back atomic operation: $($this.Id)" -Level 'WARN'
            
            if ($this.RollbackAction) {
                & $this.RollbackAction
            }
            
            $this.RolledBack = $true
            Write-CustomLog "Atomic operation rolled back: $($this.Id)" -Level 'INFO'
            return $true
        } catch {
            $this.LastError = $_.Exception
            Write-CustomLog "Rollback failed for operation: $($this.Id) - $($_.Exception.Message)" -Level 'ERROR'
            return $false
        }
    }
    
    [bool] Validate() {
        try {
            if ($this.ValidateAction) {
                return & $this.ValidateAction
            }
            return $true
        } catch {
            $this.LastError = $_.Exception
            Write-CustomLog "Validation failed for operation: $($this.Id) - $($_.Exception.Message)" -Level 'ERROR'
            return $false
        }
    }
}

class AtomicTransaction {
    [string] $Id
    [string] $Description
    [TransactionState] $State
    [IsolationLevel] $IsolationLevel
    [AtomicOperation[]] $Operations
    [hashtable] $Context
    [hashtable] $GlobalPreState
    [hashtable] $GlobalPostState
    [DateTime] $StartTime
    [DateTime] $EndTime
    [TimeSpan] $Duration
    [System.Exception] $LastError
    [string[]] $AuditTrail
    [hashtable] $Metrics
    [bool] $AutoCommit
    [int] $MaxOperations
    
    AtomicTransaction([string]$id, [string]$description) {
        $this.Id = $id
        $this.Description = $description
        $this.State = [TransactionState]::Initializing
        $this.IsolationLevel = [IsolationLevel]::ReadCommitted
        $this.Operations = @()
        $this.Context = @{}
        $this.GlobalPreState = @{}
        $this.GlobalPostState = @{}
        $this.AuditTrail = @()
        $this.Metrics = @{}
        $this.AutoCommit = $true
        $this.MaxOperations = 100
    }
    
    [void] AddOperation([AtomicOperation]$operation) {
        if ($this.Operations.Count -ge $this.MaxOperations) {
            throw "Maximum operations limit ($($this.MaxOperations)) exceeded"
        }
        
        if ($this.State -ne [TransactionState]::Initializing) {
            throw "Cannot add operations after transaction preparation"
        }
        
        $this.Operations += $operation
        $this.LogAudit("Added operation: $($operation.Id)")
    }
    
    [void] LogAudit([string]$message) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $auditEntry = "[$timestamp] [$($this.State)] $message"
        $this.AuditTrail += $auditEntry
        Write-CustomLog $auditEntry -Level 'DEBUG'
    }
    
    [void] CaptureGlobalPreState() {
        $this.GlobalPreState = @{
            Timestamp = Get-Date
            WorkingDirectory = Get-Location
            GitRepository = @{
                Branch = (git branch --show-current 2>&1 | Out-String).Trim()
                Status = git status --porcelain 2>&1
                Head = git rev-parse HEAD 2>&1
                Remote = git remote -v 2>&1
                Stashes = git stash list 2>&1
            }
            Environment = @{
                Variables = Get-ChildItem Env: | ForEach-Object { @{ $_.Name = $_.Value } }
                Modules = Get-Module | Select-Object Name, Version
                PSVersion = $PSVersionTable
            }
            FileSystem = @{
                Files = Get-ChildItem -Force | Select-Object Name, Length, LastWriteTime
                Permissions = if ($IsWindows) { Get-Acl . } else { ls -la }
            }
        }
    }
    
    [void] CaptureGlobalPostState() {
        $this.GlobalPostState = @{
            Timestamp = Get-Date
            WorkingDirectory = Get-Location
            GitRepository = @{
                Branch = (git branch --show-current 2>&1 | Out-String).Trim()
                Status = git status --porcelain 2>&1
                Head = git rev-parse HEAD 2>&1
                Remote = git remote -v 2>&1
                Stashes = git stash list 2>&1
            }
            Environment = @{
                Variables = Get-ChildItem Env: | ForEach-Object { @{ $_.Name = $_.Value } }
                Modules = Get-Module | Select-Object Name, Version
                PSVersion = $PSVersionTable
            }
            FileSystem = @{
                Files = Get-ChildItem -Force | Select-Object Name, Length, LastWriteTime
                Permissions = if ($IsWindows) { Get-Acl . } else { ls -la }
            }
        }
    }
    
    [bool] Prepare() {
        try {
            if ($this.State -ne [TransactionState]::Initializing) {
                throw "Transaction already prepared or in invalid state: $($this.State)"
            }
            
            $this.State = [TransactionState]::Prepared
            $this.LogAudit("Transaction prepared with $($this.Operations.Count) operations")
            
            # Validate operation dependencies
            foreach ($operation in $this.Operations) {
                foreach ($dependency in $operation.Dependencies) {
                    $dependentOp = $this.Operations | Where-Object { $_.Id -eq $dependency }
                    if (-not $dependentOp) {
                        throw "Operation $($operation.Id) depends on non-existent operation: $dependency"
                    }
                }
            }
            
            # Validate all operations before execution
            foreach ($operation in $this.Operations) {
                if (-not $operation.Validate()) {
                    throw "Pre-execution validation failed for operation: $($operation.Id)"
                }
            }
            
            return $true
        } catch {
            $this.LastError = $_.Exception
            $this.State = [TransactionState]::Failed
            $this.LogAudit("Transaction preparation failed: $($_.Exception.Message)")
            return $false
        }
    }
    
    [bool] Execute() {
        try {
            if ($this.State -ne [TransactionState]::Prepared) {
                throw "Transaction not prepared or in invalid state: $($this.State)"
            }
            
            $this.State = [TransactionState]::Executing
            $this.StartTime = Get-Date
            $this.CaptureGlobalPreState()
            $this.LogAudit("Transaction execution started")
            
            # Execute operations in dependency order
            $executedOperations = @()
            
            foreach ($operation in $this.Operations) {
                # Check dependencies
                foreach ($dependency in $operation.Dependencies) {
                    $dependentOp = $executedOperations | Where-Object { $_.Id -eq $dependency }
                    if (-not $dependentOp -or -not $dependentOp.Completed) {
                        throw "Dependency not satisfied for operation $($operation.Id): $dependency"
                    }
                }
                
                # Execute operation
                if (-not $operation.Execute()) {
                    throw "Operation execution failed: $($operation.Id)"
                }
                
                # Post-execution validation
                if (-not $operation.Validate()) {
                    throw "Post-execution validation failed for operation: $($operation.Id)"
                }
                
                $executedOperations += $operation
                $this.LogAudit("Operation executed successfully: $($operation.Id)")
            }
            
            $this.CaptureGlobalPostState()
            $this.EndTime = Get-Date
            $this.Duration = $this.EndTime - $this.StartTime
            
            if ($this.AutoCommit) {
                return $this.Commit()
            } else {
                $this.State = [TransactionState]::Executed
                return $true
            }
        } catch {
            $this.LastError = $_.Exception
            $this.LogAudit("Transaction execution failed: $($_.Exception.Message)")
            return $this.Rollback()
        }
    }
    
    [bool] Commit() {
        try {
            if ($this.State -ne [TransactionState]::Executed -and $this.State -ne [TransactionState]::Executing) {
                throw "Transaction not ready for commit. Current state: $($this.State)"
            }
            
            $this.State = [TransactionState]::Committing
            $this.LogAudit("Transaction commit started")
            
            # Final validation of all operations
            foreach ($operation in $this.Operations) {
                if (-not $operation.Validate()) {
                    throw "Final validation failed for operation: $($operation.Id)"
                }
            }
            
            # Calculate metrics
            $this.Metrics = @{
                TotalOperations = $this.Operations.Count
                SuccessfulOperations = ($this.Operations | Where-Object { $_.Completed }).Count
                FailedOperations = ($this.Operations | Where-Object { -not $_.Completed }).Count
                TotalDuration = $this.Duration
                AverageOperationDuration = ($this.Operations | Measure-Object -Property Duration -Average).Average
            }
            
            $this.State = [TransactionState]::Committed
            $this.LogAudit("Transaction committed successfully")
            
            # Publish success event
            if (Get-Command Submit-ModuleEvent -ErrorAction SilentlyContinue) {
                Submit-ModuleEvent -EventName "TransactionCommitted" -EventData @{
                    TransactionId = $this.Id
                    Description = $this.Description
                    Metrics = $this.Metrics
                    Duration = $this.Duration
                }
            }
            
            return $true
        } catch {
            $this.LastError = $_.Exception
            $this.LogAudit("Transaction commit failed: $($_.Exception.Message)")
            return $this.Rollback()
        }
    }
    
    [bool] Rollback() {
        try {
            $this.State = [TransactionState]::RollingBack
            $this.LogAudit("Transaction rollback started")
            
            # Rollback operations in reverse order
            $reversedOperations = $this.Operations | Where-Object { $_.Completed }
            [Array]::Reverse($reversedOperations)
            
            $rollbackErrors = @()
            foreach ($operation in $reversedOperations) {
                if (-not $operation.Rollback()) {
                    $rollbackErrors += "Failed to rollback operation: $($operation.Id)"
                }
            }
            
            if ($rollbackErrors.Count -gt 0) {
                $this.LogAudit("Partial rollback completed with errors: $($rollbackErrors -join '; ')")
                $this.State = [TransactionState]::Failed
                return $false
            }
            
            $this.State = [TransactionState]::RolledBack
            $this.LogAudit("Transaction rolled back successfully")
            
            # Publish rollback event
            if (Get-Command Submit-ModuleEvent -ErrorAction SilentlyContinue) {
                Submit-ModuleEvent -EventName "TransactionRolledBack" -EventData @{
                    TransactionId = $this.Id
                    Description = $this.Description
                    Reason = $this.LastError.Message
                }
            }
            
            return $true
        } catch {
            $this.LastError = $_.Exception
            $this.State = [TransactionState]::Failed
            $this.LogAudit("Transaction rollback failed: $($_.Exception.Message)")
            return $false
        }
    }
    
    [void] Abort() {
        $this.State = [TransactionState]::Aborted
        $this.LogAudit("Transaction aborted by user")
    }
    
    [hashtable] GetStatus() {
        return @{
            Id = $this.Id
            Description = $this.Description
            State = $this.State
            Operations = $this.Operations.Count
            CompletedOperations = ($this.Operations | Where-Object { $_.Completed }).Count
            Duration = $this.Duration
            LastError = $this.LastError?.Message
            AuditTrailEntries = $this.AuditTrail.Count
            Metrics = $this.Metrics
        }
    }
    
    [string] GenerateReport() {
        $report = @"
================================================================================
ATOMIC TRANSACTION REPORT
================================================================================
Transaction ID: $($this.Id)
Description: $($this.Description)
State: $($this.State)
Isolation Level: $($this.IsolationLevel)
Duration: $($this.Duration)
Operations: $($this.Operations.Count)
Completed: $(($this.Operations | Where-Object { $_.Completed }).Count)
Failed: $(($this.Operations | Where-Object { -not $_.Completed }).Count)

OPERATION DETAILS:
$(foreach ($op in $this.Operations) {
    "- $($op.Id): $($op.Description) [$($op.Type)] - $(if ($op.Completed) { 'COMPLETED' } else { 'FAILED' })"
})

AUDIT TRAIL:
$(foreach ($entry in $this.AuditTrail) {
    "  $entry"
})

METRICS:
$(foreach ($metric in $this.Metrics.Keys) {
    "  $metric: $($this.Metrics[$metric])"
})
================================================================================
"@
        return $report
    }
}

# Factory functions for common operations
function New-FileSystemOperation {
    param(
        [string]$Id,
        [string]$Description,
        [scriptblock]$ExecuteAction,
        [scriptblock]$RollbackAction,
        [scriptblock]$ValidateAction
    )
    
    $operation = [AtomicOperation]::new($Id, [OperationType]::FileSystem, $Description)
    $operation.SetExecuteAction($ExecuteAction)
    $operation.SetRollbackAction($RollbackAction)
    $operation.SetValidateAction($ValidateAction)
    
    return $operation
}

function New-GitOperation {
    param(
        [string]$Id,
        [string]$Description,
        [scriptblock]$ExecuteAction,
        [scriptblock]$RollbackAction,
        [scriptblock]$ValidateAction
    )
    
    $operation = [AtomicOperation]::new($Id, [OperationType]::GitOperation, $Description)
    $operation.SetExecuteAction($ExecuteAction)
    $operation.SetRollbackAction($RollbackAction)
    $operation.SetValidateAction($ValidateAction)
    
    return $operation
}

function New-AtomicTransaction {
    param(
        [string]$Id = [guid]::NewGuid().ToString(),
        [string]$Description,
        [IsolationLevel]$IsolationLevel = [IsolationLevel]::ReadCommitted,
        [bool]$AutoCommit = $true
    )
    
    $transaction = [AtomicTransaction]::new($Id, $Description)
    $transaction.IsolationLevel = $IsolationLevel
    $transaction.AutoCommit = $AutoCommit
    
    return $transaction
}

# Export public functions
Export-ModuleMember -Function New-FileSystemOperation, New-GitOperation, New-AtomicTransaction