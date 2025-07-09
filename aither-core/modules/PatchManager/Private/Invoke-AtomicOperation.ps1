#Requires -Version 7.0

<#
.SYNOPSIS
    Atomic operation framework that eliminates git stashing issues

.DESCRIPTION
    This function provides atomic, all-or-nothing operations that prevent the
    merge conflict issues caused by git stashing. Operations are designed to
    be completely self-contained and reversible.

.PARAMETER Operation
    The operation to perform atomically

.PARAMETER OperationName
    Name of the operation for logging

.PARAMETER PreConditions
    Script block to validate pre-conditions

.PARAMETER PostConditions
    Script block to validate post-conditions

.PARAMETER RollbackOperation
    Script block to rollback if operation fails

.PARAMETER RequiresCleanWorkspace
    Whether the operation requires a clean git workspace

.PARAMETER AllowWorkspaceChanges
    Whether to allow uncommitted changes (default: false for safety)
#>

function Invoke-AtomicOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Operation,

        [Parameter(Mandatory = $true)]
        [string]$OperationName,

        [Parameter(Mandatory = $false)]
        [scriptblock]$PreConditions,

        [Parameter(Mandatory = $false)]
        [scriptblock]$PostConditions,

        [Parameter(Mandatory = $false)]
        [scriptblock]$RollbackOperation,

        [Parameter(Mandatory = $false)]
        [switch]$RequiresCleanWorkspace,

        [Parameter(Mandatory = $false)]
        [switch]$AllowWorkspaceChanges
    )

    begin {
        # Initialize logging
        if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
            function Write-CustomLog {
                param($Message, $Level = "INFO")
                Write-Host "[$Level] $Message"
            }
        }

        Write-CustomLog "Starting atomic operation: $OperationName" -Level "INFO"

        # Create operation context
        $operationContext = @{
            OperationName = $OperationName
            StartTime = Get-Date
            InitialBranch = $null
            InitialCommit = $null
            WorkspaceSnapshot = @{}
            Success = $false
            RollbackPerformed = $false
        }
    }

    process {
        try {
            # Step 1: Capture initial state
            Write-CustomLog "Capturing initial state..." -Level "INFO"

            $operationContext.InitialBranch = git branch --show-current 2>&1 | Out-String | ForEach-Object Trim
            $operationContext.InitialCommit = git rev-parse HEAD 2>&1 | Out-String | ForEach-Object Trim

            # Check workspace state
            $gitStatus = git status --porcelain 2>&1
            $hasUncommittedChanges = $gitStatus -and ($gitStatus | Where-Object { $_ -match '\S' })

            if ($hasUncommittedChanges) {
                $operationContext.WorkspaceSnapshot.HasChanges = $true
                $operationContext.WorkspaceSnapshot.Changes = $gitStatus

                if ($RequiresCleanWorkspace -and -not $AllowWorkspaceChanges) {
                    throw "Operation '$OperationName' requires clean workspace but uncommitted changes detected. Use -AllowWorkspaceChanges to override."
                }

                Write-CustomLog "Workspace has uncommitted changes (allowed by operation)" -Level "WARN"
            } else {
                $operationContext.WorkspaceSnapshot.HasChanges = $false
                Write-CustomLog "Workspace is clean" -Level "INFO"
            }

            # Step 2: Check for merge conflicts (CRITICAL) - Use smart detection
            Write-CustomLog "Checking for merge conflict markers..." -Level "INFO"
            
            # Import smart conflict detection if not already loaded
            $smartConflictPath = Join-Path $PSScriptRoot "Test-RealConflictMarkers.ps1"
            if (Test-Path $smartConflictPath) {
                . $smartConflictPath
            }
            
            # Use smart conflict detection if available, fallback to basic detection
            if (Get-Command Test-RealConflictMarkers -ErrorAction SilentlyContinue) {
                $conflictResult = Test-RealConflictMarkers -ExcludeTestFiles
                if ($conflictResult.HasConflicts) {
                    $errorMsg = "MERGE CONFLICTS DETECTED! Cannot perform atomic operation when merge conflict markers exist:`n" +
                               ($conflictResult.ConflictFiles -join "`n") +
                               "`n`nReason: $($conflictResult.Reason)" +
                               "`n`nResolve conflicts first, then retry."
                    throw $errorMsg
                }
            } else {
                # Fallback to basic detection
                $conflictMarkers = git grep -l "^<<<<<<< HEAD" 2>$null
                if ($conflictMarkers) {
                    $errorMsg = "MERGE CONFLICTS DETECTED! Cannot perform atomic operation when merge conflict markers exist:`n" +
                               ($conflictMarkers -join "`n") +
                               "`n`nResolve conflicts first, then retry."
                    throw $errorMsg
                }
            }

            # Step 3: Run pre-conditions
            if ($PreConditions) {
                Write-CustomLog "Validating pre-conditions..." -Level "INFO"
                $preConditionResult = & $PreConditions
                if ($preConditionResult -eq $false) {
                    throw "Pre-conditions failed for operation: $OperationName"
                }
            }

            # Step 4: Execute operation atomically
            Write-CustomLog "Executing atomic operation..." -Level "INFO"
            $operationResult = & $Operation

            # Step 5: Run post-conditions
            if ($PostConditions) {
                Write-CustomLog "Validating post-conditions..." -Level "INFO"
                $postConditionResult = & $PostConditions
                if ($postConditionResult -eq $false) {
                    throw "Post-conditions failed for operation: $OperationName"
                }
            }

            # Step 6: Final validation
            Write-CustomLog "Performing final validation..." -Level "INFO"

            # Check for new merge conflicts using smart detection
            if (Get-Command Test-RealConflictMarkers -ErrorAction SilentlyContinue) {
                $newConflictResult = Test-RealConflictMarkers -ExcludeTestFiles
                if ($newConflictResult.HasConflicts) {
                    throw "Operation introduced merge conflict markers - rolling back"
                }
            } else {
                # Fallback to basic detection
                $newConflictMarkers = git grep -l "^<<<<<<< HEAD" 2>$null
                if ($newConflictMarkers) {
                    throw "Operation introduced merge conflict markers - rolling back"
                }
            }

            # Mark as successful
            $operationContext.Success = $true
            $operationContext.EndTime = Get-Date
            $operationContext.Duration = $operationContext.EndTime - $operationContext.StartTime

            Write-CustomLog "Atomic operation completed successfully in $($operationContext.Duration.TotalSeconds) seconds" -Level "SUCCESS"

            return @{
                Success = $true
                OperationName = $OperationName
                Duration = $operationContext.Duration
                Result = $operationResult
                Context = $operationContext
            }

        } catch {
            Write-CustomLog "Atomic operation failed: $($_.Exception.Message)" -Level "ERROR"

            # Attempt rollback if available
            if ($RollbackOperation -and -not $operationContext.RollbackPerformed) {
                try {
                    Write-CustomLog "Attempting automatic rollback..." -Level "WARN"
                    & $RollbackOperation
                    $operationContext.RollbackPerformed = $true
                    Write-CustomLog "Rollback completed successfully" -Level "INFO"
                } catch {
                    Write-CustomLog "Rollback failed: $($_.Exception.Message)" -Level "ERROR"
                }
            }

            $operationContext.Success = $false
            $operationContext.Error = $_.Exception.Message
            $operationContext.EndTime = Get-Date

            return @{
                Success = $false
                OperationName = $OperationName
                Error = $_.Exception.Message
                Context = $operationContext
                RollbackPerformed = $operationContext.RollbackPerformed
            }
        }
    }
}

Export-ModuleMember -Function Invoke-AtomicOperation
