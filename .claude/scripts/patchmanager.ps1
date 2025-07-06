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
    [ValidateSet("quickfix", "feature", "hotfix", "patch", "workflow", "rollback", "status", "consolidate", "sync", "release")]
    [string]$Action = "patch",
    
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
                    $params.Description = $Arguments[++$i]
                    $params.PatchDescription = $Arguments[$i]  # Legacy compatibility
                }
            }
            "^--changes$" {
                $params.Changes = [scriptblock]::Create($Arguments[++$i])
            }
            "^--operation$" {
                # Legacy compatibility - map to new Changes parameter
                $params.Changes = [scriptblock]::Create($Arguments[++$i])
                $params.PatchOperation = [scriptblock]::Create($Arguments[$i])  # Legacy compatibility
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
        "quickfix" {
            Write-CommandLog "Executing quick fix..." -Level "INFO"
            
            # Validate required parameters
            if (-not $params.Description) {
                Write-CommandLog "Error: --description is required for quickfix action" -Level "ERROR"
                exit 1
            }
            
            # Execute using New-QuickFix if available, fallback to legacy
            if (Get-Command New-QuickFix -ErrorAction SilentlyContinue) {
                $result = New-QuickFix -Description $params.Description -Changes $params.Changes -DryRun:($params.DryRun -eq $true)
            } else {
                Write-CommandLog "Warning: Using legacy workflow for quickfix" -Level "WARNING"
                $legacyParams = @{
                    PatchDescription = $params.Description
                    PatchOperation = $params.Changes
                    CreateIssue = $false
                    CreatePR = $false
                }
                if ($params.DryRun) { $legacyParams.DryRun = $true }
                $result = Invoke-PatchWorkflow @legacyParams
            }
            
            if ($result.Success) {
                Write-CommandLog "Quick fix completed successfully" -Level "SUCCESS"
            } else {
                Write-CommandLog "Quick fix failed: $($result.Message)" -Level "ERROR"
                exit 1
            }
        }
        
        "feature" {
            Write-CommandLog "Executing feature development workflow..." -Level "INFO"
            
            # Validate required parameters
            if (-not $params.Description) {
                Write-CommandLog "Error: --description is required for feature action" -Level "ERROR"
                exit 1
            }
            
            # Execute using New-Feature if available, fallback to legacy
            if (Get-Command New-Feature -ErrorAction SilentlyContinue) {
                $featureParams = @{
                    Description = $params.Description
                    Changes = $params.Changes
                }
                if ($params.TargetFork) { $featureParams.TargetFork = $params.TargetFork }
                if ($params.DryRun) { $featureParams.DryRun = $true }
                $result = New-Feature @featureParams
            } else {
                Write-CommandLog "Warning: Using legacy workflow for feature" -Level "WARNING"
                $legacyParams = @{
                    PatchDescription = $params.Description
                    PatchOperation = $params.Changes
                    CreatePR = $true
                }
                if ($params.TargetFork) { $legacyParams.TargetFork = $params.TargetFork }
                if ($params.DryRun) { $legacyParams.DryRun = $true }
                $result = Invoke-PatchWorkflow @legacyParams
            }
            
            if ($result.Success) {
                Write-CommandLog "Feature development completed successfully" -Level "SUCCESS"
                if ($result.PullRequestUrl) {
                    Write-CommandLog "PR: $($result.PullRequestUrl)" -Level "SUCCESS"
                }
            } else {
                Write-CommandLog "Feature development failed: $($result.Message)" -Level "ERROR"
                exit 1
            }
        }
        
        "hotfix" {
            Write-CommandLog "Executing emergency hotfix..." -Level "INFO"
            
            # Validate required parameters
            if (-not $params.Description) {
                Write-CommandLog "Error: --description is required for hotfix action" -Level "ERROR"
                exit 1
            }
            
            # Execute using New-Hotfix if available, fallback to legacy
            if (Get-Command New-Hotfix -ErrorAction SilentlyContinue) {
                $hotfixParams = @{
                    Description = $params.Description
                    Changes = $params.Changes
                }
                if ($params.DryRun) { $hotfixParams.DryRun = $true }
                $result = New-Hotfix @hotfixParams
            } else {
                Write-CommandLog "Warning: Using legacy workflow for hotfix" -Level "WARNING"
                $legacyParams = @{
                    PatchDescription = $params.Description
                    PatchOperation = $params.Changes
                    Priority = "Critical"
                    CreatePR = $true
                }
                if ($params.DryRun) { $legacyParams.DryRun = $true }
                $result = Invoke-PatchWorkflow @legacyParams
            }
            
            if ($result.Success) {
                Write-CommandLog "Emergency hotfix completed successfully" -Level "SUCCESS"
                if ($result.PullRequestUrl) {
                    Write-CommandLog "PR: $($result.PullRequestUrl)" -Level "SUCCESS"
                }
            } else {
                Write-CommandLog "Emergency hotfix failed: $($result.Message)" -Level "ERROR"
                exit 1
            }
        }
        
        "patch" {
            Write-CommandLog "Executing smart patch with auto-detection..." -Level "INFO"
            
            # Validate required parameters
            if (-not $params.Description) {
                Write-CommandLog "Error: --description is required for patch action" -Level "ERROR"
                exit 1
            }
            
            # Execute using New-Patch if available, fallback to legacy
            if (Get-Command New-Patch -ErrorAction SilentlyContinue) {
                $patchParams = @{
                    Description = $params.Description
                    Changes = $params.Changes
                }
                if ($params.Mode) { $patchParams.Mode = $params.Mode }
                if ($params.CreatePR) { $patchParams.CreatePR = $true }
                if ($params.DryRun) { $patchParams.DryRun = $true }
                $result = New-Patch @patchParams
            } else {
                Write-CommandLog "Warning: Using legacy workflow for patch" -Level "WARNING"
                $legacyParams = @{
                    PatchDescription = $params.Description
                    PatchOperation = $params.Changes
                }
                if ($params.CreatePR) { $legacyParams.CreatePR = $true }
                if ($params.DryRun) { $legacyParams.DryRun = $true }
                $result = Invoke-PatchWorkflow @legacyParams
            }
            
            if ($result.Success) {
                Write-CommandLog "Smart patch completed successfully" -Level "SUCCESS"
                if ($result.IssueUrl) {
                    Write-CommandLog "Issue: $($result.IssueUrl)" -Level "SUCCESS"
                }
                if ($result.PullRequestUrl) {
                    Write-CommandLog "PR: $($result.PullRequestUrl)" -Level "SUCCESS"
                }
            } else {
                Write-CommandLog "Smart patch failed: $($result.Message)" -Level "ERROR"
                exit 1
            }
        }
        
        "workflow" {
            Write-CommandLog "Executing legacy PatchManager workflow..." -Level "WARNING"
            Write-CommandLog "Note: Consider using 'patch', 'feature', 'quickfix', or 'hotfix' actions instead" -Level "WARNING"
            
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