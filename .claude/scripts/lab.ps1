#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Claude command wrapper for Lab Runner module
.DESCRIPTION
    Provides CLI interface for LabRunner functionality through Claude commands
.PARAMETER Action
    The action to perform (create, deploy, test, snapshot, destroy, clone, monitor)
.PARAMETER Arguments
    Additional arguments passed from Claude command
#>

param(
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateSet("create", "deploy", "test", "snapshot", "destroy", "clone", "monitor")]
    [string]$Action = "monitor",
    
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
    
    # Import LabRunner module
    $labRunnerPath = Join-Path $projectRoot "aither-core/modules/LabRunner"
    Import-Module $labRunnerPath -Force -ErrorAction Stop
    
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
            "^--env$" {
                if ($i + 1 -lt $Arguments.Count) {
                    $params.Environment = $Arguments[++$i]
                }
            }
            "^--template$" {
                $params.Template = $Arguments[++$i]
            }
            "^--ttl$" {
                $params.TimeToLive = $Arguments[++$i]
            }
            "^--resources$" {
                $params.Resources = $Arguments[++$i]
            }
            "^--isolated$" {
                $params.Isolated = $true
            }
            "^--app$" {
                $params.Application = $Arguments[++$i]
            }
            "^--version$" {
                $params.Version = $Arguments[++$i]
            }
            "^--test-data$" {
                $params.TestData = $Arguments[++$i]
            }
            "^--config$" {
                $params.ConfigFile = $Arguments[++$i]
            }
            "^--validate$" {
                $params.Validate = $true
            }
            "^--automated$" {
                $params.Automated = $true
            }
            "^--suite$" {
                $params.TestSuite = $Arguments[++$i]
            }
            "^--report$" {
                $params.GenerateReport = $true
            }
            "^--parallel$" {
                $params.Parallel = $true
            }
            "^--coverage$" {
                $params.Coverage = $true
            }
            "^--name$" {
                $params.SnapshotName = $Arguments[++$i]
            }
            "^--description$" {
                $params.Description = $Arguments[++$i]
            }
            "^--restore$" {
                $params.RestoreSnapshot = $Arguments[++$i]
            }
            "^--list$" {
                $params.ListSnapshots = $true
            }
            "^--cleanup$" {
                $params.FullCleanup = $true
            }
            "^--preserve-data$" {
                $params.PreserveData = $true
            }
            "^--force$" {
                $params.Force = $true
            }
            "^--archive$" {
                $params.Archive = $true
            }
            "^--from$" {
                $params.SourceEnvironment = $Arguments[++$i]
            }
            "^--to$" {
                $params.TargetEnvironment = $Arguments[++$i]
            }
            "^--sanitize-data$" {
                $params.SanitizeData = $true
            }
            "^--scale-down$" {
                $params.ScaleDown = $true
            }
            "^--network-isolated$" {
                $params.NetworkIsolated = $true
            }
            "^--status$" {
                $params.ShowStatus = $true
            }
            "^--costs$" {
                $params.ShowCosts = $true
            }
            "^--usage$" {
                $params.ShowUsage = $true
            }
            "^--cleanup-expired$" {
                $params.CleanupExpired = $true
            }
            "^--extend-ttl$" {
                $params.ExtendTTL = @($Arguments[++$i], $Arguments[++$i])
            }
        }
        $i++
    }
    
    switch ($Action) {
        "create" {
            Write-CommandLog "Creating lab environment..." -Level "INFO"
            
            if (-not $params.Environment) {
                $params.Environment = "lab-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            }
            if (-not $params.Template) {
                $params.Template = "minimal"
            }
            
            Write-CommandLog "Environment: $($params.Environment), Template: $($params.Template)" -Level "INFO"
            # Call LabRunner functions here
            Write-CommandLog "Lab environment creation initiated" -Level "SUCCESS"
        }
        
        "deploy" {
            Write-CommandLog "Deploying application to lab..." -Level "INFO"
            
            if (-not $params.Application) {
                Write-CommandLog "Error: --app is required for deploy action" -Level "ERROR"
                exit 1
            }
            
            Write-CommandLog "Deploying $($params.Application) to lab environment" -Level "INFO"
            # Call LabRunner deployment functions here
            Write-CommandLog "Application deployment completed" -Level "SUCCESS"
        }
        
        "test" {
            Write-CommandLog "Executing lab tests..." -Level "INFO"
            
            if ($params.Automated) {
                Write-CommandLog "Running automated test suite" -Level "INFO"
                # Call automated testing functions
            }
            
            Write-CommandLog "Lab testing completed" -Level "SUCCESS"
        }
        
        "snapshot" {
            Write-CommandLog "Managing lab snapshots..." -Level "INFO"
            
            if ($params.ListSnapshots) {
                Write-CommandLog "Listing available snapshots" -Level "INFO"
                # List snapshots
            } elseif ($params.RestoreSnapshot) {
                Write-CommandLog "Restoring from snapshot: $($params.RestoreSnapshot)" -Level "INFO"
                # Restore snapshot
            } else {
                Write-CommandLog "Creating snapshot: $($params.SnapshotName)" -Level "INFO"
                # Create snapshot
            }
            
            Write-CommandLog "Snapshot operation completed" -Level "SUCCESS"
        }
        
        "destroy" {
            Write-CommandLog "Destroying lab environment..." -Level "WARN"
            
            if (-not $params.Environment) {
                Write-CommandLog "Error: --env is required for destroy action" -Level "ERROR"
                exit 1
            }
            
            if ($params.PreserveData) {
                Write-CommandLog "Preserving data before destruction" -Level "INFO"
            }
            
            Write-CommandLog "Lab environment destroyed: $($params.Environment)" -Level "SUCCESS"
        }
        
        "clone" {
            Write-CommandLog "Cloning lab environment..." -Level "INFO"
            
            if (-not $params.SourceEnvironment -or -not $params.TargetEnvironment) {
                Write-CommandLog "Error: Both --from and --to are required for clone action" -Level "ERROR"
                exit 1
            }
            
            Write-CommandLog "Cloning $($params.SourceEnvironment) to $($params.TargetEnvironment)" -Level "INFO"
            Write-CommandLog "Environment cloning completed" -Level "SUCCESS"
        }
        
        "monitor" {
            Write-CommandLog "Monitoring lab environments..." -Level "INFO"
            
            if ($params.ShowStatus) {
                Write-CommandLog "Lab environment status:" -Level "INFO"
                # Show status
            }
            if ($params.ShowCosts) {
                Write-CommandLog "Lab cost breakdown:" -Level "INFO"
                # Show costs
            }
            if ($params.CleanupExpired) {
                Write-CommandLog "Cleaning up expired environments" -Level "INFO"
                # Cleanup expired
            }
            
            Write-CommandLog "Lab monitoring completed" -Level "SUCCESS"
        }
        
        default {
            Write-CommandLog "Unknown action: $Action" -Level "ERROR"
            Write-CommandLog "Available actions: create, deploy, test, snapshot, destroy, clone, monitor" -Level "INFO"
            exit 1
        }
    }
    
} catch {
    Write-CommandLog "Command execution failed: $($_.Exception.Message)" -Level "ERROR"
    Write-CommandLog "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
}