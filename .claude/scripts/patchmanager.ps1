#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Claude command wrapper for PatchManager module
.DESCRIPTION
    Provides CLI interface for PatchManager functionality through Claude commands
.PARAMETER Action
    The action to perform (workflow, rollback, status, consolidate)
.PARAMETER Arguments
    Additional arguments passed from Claude command
#>

param(
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateSet("workflow", "rollback", "status", "consolidate")]
    [string]$Action = "workflow",
    
    [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true)]
    [string[]]$Arguments = @()
)

# Cross-platform script location detection
$scriptPath = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)

# Import required modules
try {
    . (Join-Path $projectRoot "aither-core/shared/Find-ProjectRoot.ps1")
    $projectRoot = Find-ProjectRoot
    
    # Import PatchManager module
    $patchManagerPath = Join-Path $projectRoot "aither-core/modules/PatchManager"
    Import-Module $patchManagerPath -Force -ErrorAction Stop
    
    # Import Logging module for consistent output
    $loggingPath = Join-Path $projectRoot "aither-core/modules/Logging" 
    Import-Module $loggingPath -Force -ErrorAction SilentlyContinue
} catch {
    Write-Error "Failed to import required modules: $($_.Exception.Message)"
    exit 1
}

# Helper function for consistent logging
function Write-CommandLog {
    param($Message, $Level = "INFO")
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level
    } else {
        $prefix = switch ($Level) {
            "ERROR" { "[ERROR]" }
            "WARN" { "[WARN]" }
            "SUCCESS" { "[SUCCESS]" }
            default { "[INFO]" }
        }
        Write-Host "$prefix $Message"
    }
}

# Execute the requested action
try {
    # Parse arguments inline
    $params = @{}
    $i = 0
    
    while ($i -lt $Arguments.Count) {
        $arg = $Arguments[$i]
        
        switch -Regex ($arg) {
            "^--description$" {
                if ($i + 1 -lt $Arguments.Count) {
                    $params.PatchDescription = $Arguments[++$i]
                }
            }
            "^--operation$" {
                $params.PatchOperation = [scriptblock]::Create($Arguments[++$i])
            }
            "^--create-issue$" {
                $params.CreateIssue = $true
            }
            "^--create-issue:false$" {
                $params.CreateIssue = $false
            }
            "^--create-pr$" {
                $params.CreatePR = $true
            }
            "^--target-fork$" {
                $params.TargetFork = $Arguments[++$i]
            }
            "^--priority$" {
                $params.Priority = $Arguments[++$i]
            }
            "^--dry-run$" {
                $params.DryRun = $true
            }
            "^--force$" {
                $params.Force = $true
            }
            "^--auto-consolidate$" {
                $params.AutoConsolidate = $true
            }
            "^--test$" {
                if (-not $params.TestCommands) { $params.TestCommands = @() }
                $params.TestCommands += $Arguments[++$i]
            }
            "^--type$" {
                $params.RollbackType = $Arguments[++$i]
            }
            "^--commit-hash$" {
                $params.CommitHash = $Arguments[++$i]
            }
            "^--create-backup$" {
                $params.CreateBackup = $true
            }
            "^--strategy$" {
                $params.ConsolidationStrategy = $Arguments[++$i]
            }
            "^--max-prs$" {
                $params.MaxPRsToConsolidate = [int]$Arguments[++$i]
            }
            default {
                # If no flag prefix, treat as description for workflow action
                if (-not $params.PatchDescription -and $arg -notmatch "^--") {
                    $params.PatchDescription = $arg
                }
            }
        }
        $i++
    }
    
    switch ($Action) {
        "workflow" {
            Write-CommandLog "Executing PatchManager workflow..." -Level "INFO"
            
            # Validate required parameters
            if (-not $params.PatchDescription) {
                Write-CommandLog "Error: --description is required for workflow action" -Level "ERROR"
                exit 1
            }
            
            # Execute workflow
            $result = Invoke-PatchWorkflow @params
            
            if ($result.Success) {
                Write-CommandLog "Patch workflow completed successfully" -Level "SUCCESS"
                if ($result.IssueUrl) {
                    Write-CommandLog "Issue: $($result.IssueUrl)" -Level "SUCCESS"
                }
                if ($result.PullRequestUrl) {
                    Write-CommandLog "PR: $($result.PullRequestUrl)" -Level "SUCCESS"
                }
            } else {
                Write-CommandLog "Patch workflow failed: $($result.Message)" -Level "ERROR"
                exit 1
            }
        }
        
        "rollback" {
            Write-CommandLog "Executing PatchManager rollback..." -Level "INFO"
            
            # Set default rollback type if not specified
            if (-not $params.RollbackType) {
                $params.RollbackType = "LastCommit"
            }
            
            $result = Invoke-PatchRollback @params
            
            if ($result.Success) {
                Write-CommandLog "Rollback completed successfully: $($result.Message)" -Level "SUCCESS"
            } else {
                Write-CommandLog "Rollback failed: $($result.Message)" -Level "ERROR"
                exit 1
            }
        }
        
        "status" {
            Write-CommandLog "Getting Git status with guidance..." -Level "INFO"
            Show-GitStatusGuidance
        }
        
        "consolidate" {
            Write-CommandLog "Executing PR consolidation..." -Level "INFO"
            
            # Set defaults
            if (-not $params.ConsolidationStrategy) {
                $params.ConsolidationStrategy = "Compatible"
            }
            if (-not $params.MaxPRsToConsolidate) {
                $params.MaxPRsToConsolidate = 5
            }
            
            $result = Invoke-PRConsolidation @params
            
            if ($result.Success) {
                Write-CommandLog "PR consolidation completed successfully" -Level "SUCCESS"
                Write-CommandLog "PRs consolidated: $($result.PRsConsolidated)" -Level "INFO"
                if ($result.ConsolidatedPRUrl) {
                    Write-CommandLog "Consolidated PR: $($result.ConsolidatedPRUrl)" -Level "SUCCESS"
                }
            } else {
                Write-CommandLog "PR consolidation failed: $($result.Message)" -Level "ERROR"
                exit 1
            }
        }
        
        default {
            Write-CommandLog "Unknown action: $Action" -Level "ERROR"
            Write-CommandLog "Available actions: workflow, rollback, status, consolidate" -Level "INFO"
            exit 1
        }
    }
    
} catch {
    Write-CommandLog "Command execution failed: $($_.Exception.Message)" -Level "ERROR"
    Write-CommandLog "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
}