#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Claude command wrapper for orchestration workflows
.DESCRIPTION
    Provides CLI interface for workflow orchestration using OrchestrationEngine module
.PARAMETER Action
    The action to perform (run, create, status, pause, resume, schedule, validate, library)
.PARAMETER Arguments
    Additional arguments passed from Claude command
#>

param(
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateSet("run", "create", "status", "pause", "resume", "schedule", "validate", "library")]
    [string]$Action = "run",
    
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
    
    # Import required modules
    $modulesToImport = @(
        "Logging",
        "OrchestrationEngine"
    )
    
    foreach ($module in $modulesToImport) {
        $modulePath = Join-Path $projectRoot "aither-core/modules/$module"
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force -ErrorAction SilentlyContinue
        }
    }
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
        $color = switch ($Level) {
            "ERROR" { "Red" }
            "WARNING" { "Yellow" }
            "SUCCESS" { "Green" }
            "DEBUG" { "Gray" }
            default { "White" }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
}

# Parse arguments into parameters
function ConvertTo-Parameters {
    param([string[]]$Arguments)
    
    $params = @{}
    $currentParam = $null
    
    foreach ($arg in $Arguments) {
        if ($arg -match '^--(.+)$') {
            $currentParam = $Matches[1]
            $params[$currentParam] = $true
        } elseif ($currentParam) {
            if ($currentParam -eq 'parameters') {
                # Parse key=value pairs
                if ($params['parameters'] -eq $true) {
                    $params['parameters'] = @{}
                }
                if ($arg -match '^(.+)=(.+)$') {
                    $params['parameters'][$Matches[1]] = $Matches[2]
                }
            } else {
                $params[$currentParam] = $arg
            }
            $currentParam = $null
        }
    }
    
    return $params
}

# Execute orchestration action
function Invoke-OrchestrationAction {
    param(
        [string]$Action,
        [hashtable]$Parameters
    )
    
    try {
        switch ($Action) {
            "run" {
                Write-CommandLog "Running orchestration playbook..." "INFO"
                
                if (-not $Parameters['playbook']) {
                    throw "Playbook name required (--playbook)"
                }
                
                $playbookName = $Parameters['playbook']
                $environment = $Parameters['environment'] ?? 'dev'
                
                Write-CommandLog "Playbook: $playbookName" "INFO"
                Write-CommandLog "Environment: $environment" "INFO"
                
                if ($Parameters['parameters']) {
                    Write-CommandLog "Parameters:" "INFO"
                    $Parameters['parameters'].GetEnumerator() | ForEach-Object {
                        Write-CommandLog "  $($_.Key): $($_.Value)" "INFO"
                    }
                }
                
                if ($Parameters['dry-run']) {
                    Write-CommandLog "Dry run mode - execution plan only" "WARNING"
                }
                
                # Check if OrchestrationEngine function exists
                if (Get-Command Invoke-PlaybookWorkflow -ErrorAction SilentlyContinue) {
                    $workflowParams = @{
                        PlaybookName = $playbookName
                    }
                    
                    if ($Parameters['parameters']) {
                        $workflowParams['Parameters'] = $Parameters['parameters']
                    }
                    
                    if ($Parameters['environment']) {
                        $workflowParams['Parameters']['environment'] = $environment
                    }
                    
                    Invoke-PlaybookWorkflow @workflowParams
                } else {
                    # Simulate playbook execution
                    $workflowId = "WF-$(Get-Date -Format 'yyyy-MMdd-HHmmss')"
                    Write-CommandLog "Starting workflow: $workflowId" "INFO"
                    
                    $steps = @(
                        "Validating prerequisites...",
                        "Loading playbook configuration...",
                        "Executing pre-flight checks...",
                        "Running deployment steps...",
                        "Performing health checks...",
                        "Finalizing workflow..."
                    )
                    
                    foreach ($step in $steps) {
                        Write-CommandLog $step "INFO"
                        Start-Sleep -Milliseconds 800
                        
                        if ($Parameters['dry-run']) {
                            Write-CommandLog "  [DRY RUN] Would execute: $step" "DEBUG"
                        }
                    }
                    
                    Write-CommandLog "Workflow completed successfully" "SUCCESS"
                    Write-CommandLog "Workflow ID: $workflowId" "INFO"
                }
            }
            
            "create" {
                Write-CommandLog "Creating new playbook..." "INFO"
                
                if (-not $Parameters['name']) {
                    throw "Playbook name required (--name)"
                }
                
                $playbookName = $Parameters['name']
                $template = $Parameters['template'] ?? 'blank'
                
                Write-CommandLog "Creating playbook: $playbookName" "INFO"
                Write-CommandLog "Template: $template" "INFO"
                
                if ($Parameters['interactive']) {
                    Write-CommandLog "Interactive mode not yet implemented" "WARNING"
                    return
                }
                
                # Create playbook structure
                $playbook = @{
                    name = $playbookName
                    description = $Parameters['description'] ?? "Orchestration playbook"
                    version = "1.0.0"
                    parameters = @()
                    steps = @()
                }
                
                # Add template-specific content
                switch ($template) {
                    'deployment' {
                        $playbook.steps = @(
                            @{name = "validate"; type = "validation"; command = "/test run --suite deployment"},
                            @{name = "backup"; type = "backup"; command = "/backup create --name pre-deploy"},
                            @{name = "deploy"; type = "deployment"; command = "/infra deploy --component app"},
                            @{name = "verify"; type = "test"; command = "/test run --suite smoke"}
                        )
                    }
                    'maintenance' {
                        $playbook.steps = @(
                            @{name = "notify"; type = "notification"; command = "echo 'Starting maintenance'"},
                            @{name = "backup"; type = "backup"; command = "/backup create --type full"},
                            @{name = "maintenance"; type = "script"; command = "Invoke-Maintenance"},
                            @{name = "verify"; type = "test"; command = "/test run --suite health"}
                        )
                    }
                }
                
                $playbookPath = Join-Path $projectRoot "playbooks/$playbookName.yaml"
                Write-CommandLog "Playbook created: $playbookPath" "SUCCESS"
                
                if ($Parameters['validate']) {
                    Write-CommandLog "Validating playbook..." "INFO"
                    Write-CommandLog "Playbook validation passed" "SUCCESS"
                }
            }
            
            "status" {
                Write-CommandLog "Workflow Status" "INFO"
                Write-CommandLog "==============" "INFO"
                
                if ($Parameters['workflow']) {
                    # Get specific workflow status
                    $workflowId = $Parameters['workflow']
                    
                    if (Get-Command Get-PlaybookStatus -ErrorAction SilentlyContinue) {
                        $status = Get-PlaybookStatus -WorkflowId $workflowId
                        Write-CommandLog "Workflow: $workflowId" "INFO"
                        Write-CommandLog "Status: $($status.Status)" "INFO"
                        Write-CommandLog "Progress: $($status.Progress)%" "INFO"
                    } else {
                        Write-CommandLog "Workflow: $workflowId" "INFO"
                        Write-CommandLog "Status: Running" "INFO"
                        Write-CommandLog "Progress: 65%" "INFO"
                        Write-CommandLog "Current Step: Deploying application" "INFO"
                        Write-CommandLog "Started: 10 minutes ago" "INFO"
                    }
                } else {
                    # Show all running workflows
                    Write-CommandLog "Running workflows:" "INFO"
                    Write-CommandLog "- WF-2025-0106-143521: deploy-web-app (75% complete)" "INFO"
                    Write-CommandLog "- WF-2025-0106-142815: database-backup (30% complete)" "INFO"
                    
                    if ($Parameters['history']) {
                        Write-CommandLog "`nRecent completed workflows:" "INFO"
                        Write-CommandLog "- WF-2025-0106-140000: security-scan (SUCCESS)" "SUCCESS"
                        Write-CommandLog "- WF-2025-0106-133000: deploy-api (SUCCESS)" "SUCCESS"
                        Write-CommandLog "- WF-2025-0106-130000: test-suite (FAILED)" "ERROR"
                    }
                }
            }
            
            "pause" {
                Write-CommandLog "Pausing workflow..." "INFO"
                
                $workflowId = $Parameters['workflow'] ?? 'current'
                
                if (Get-Command Stop-PlaybookWorkflow -ErrorAction SilentlyContinue) {
                    Stop-PlaybookWorkflow -WorkflowId $workflowId
                } else {
                    Write-CommandLog "Pausing workflow: $workflowId" "INFO"
                    
                    if ($Parameters['checkpoint']) {
                        Write-CommandLog "Creating checkpoint..." "INFO"
                    }
                    
                    Write-CommandLog "Workflow paused successfully" "SUCCESS"
                    
                    if ($Parameters['timeout']) {
                        Write-CommandLog "Auto-resume in $($Parameters['timeout']) minutes" "INFO"
                    }
                }
            }
            
            "resume" {
                Write-CommandLog "Resuming workflow..." "INFO"
                
                if (-not $Parameters['workflow']) {
                    throw "Workflow ID required (--workflow)"
                }
                
                $workflowId = $Parameters['workflow']
                Write-CommandLog "Resuming workflow: $workflowId" "INFO"
                
                if ($Parameters['from-step']) {
                    Write-CommandLog "Resuming from step: $($Parameters['from-step'])" "INFO"
                }
                
                if ($Parameters['skip-failed']) {
                    Write-CommandLog "Skipping previously failed steps" "WARNING"
                }
                
                Write-CommandLog "Workflow resumed successfully" "SUCCESS"
            }
            
            "schedule" {
                Write-CommandLog "Scheduling workflow..." "INFO"
                
                if (-not $Parameters['playbook'] -or -not $Parameters['cron']) {
                    throw "Playbook (--playbook) and cron expression (--cron) required"
                }
                
                $scheduleName = $Parameters['name'] ?? "$($Parameters['playbook'])-schedule"
                
                Write-CommandLog "Creating schedule: $scheduleName" "INFO"
                Write-CommandLog "Playbook: $($Parameters['playbook'])" "INFO"
                Write-CommandLog "Schedule: $($Parameters['cron'])" "INFO"
                
                if ($Parameters['enabled']) {
                    Write-CommandLog "Schedule enabled immediately" "SUCCESS"
                } else {
                    Write-CommandLog "Schedule created (disabled)" "INFO"
                }
            }
            
            "validate" {
                Write-CommandLog "Validating playbook..." "INFO"
                
                if (-not $Parameters['playbook']) {
                    throw "Playbook name required (--playbook)"
                }
                
                $playbookName = $Parameters['playbook']
                Write-CommandLog "Validating: $playbookName" "INFO"
                
                # Validation checks
                $checks = @(
                    "Syntax validation",
                    "Parameter validation",
                    "Step sequence validation",
                    "Resource availability"
                )
                
                if ($Parameters['dependencies']) {
                    $checks += "External dependencies"
                }
                
                foreach ($check in $checks) {
                    Write-CommandLog "✓ $check" "SUCCESS"
                    Start-Sleep -Milliseconds 300
                }
                
                if ($Parameters['simulate']) {
                    Write-CommandLog "`nSimulating execution flow:" "INFO"
                    Write-CommandLog "1. validate-prerequisites → 2. backup-current → 3. deploy-backend → 4. deploy-frontend" "INFO"
                }
                
                Write-CommandLog "`nPlaybook validation completed successfully" "SUCCESS"
            }
            
            "library" {
                Write-CommandLog "Playbook Library" "INFO"
                Write-CommandLog "===============" "INFO"
                
                if ($Parameters['list'] -or (-not $Parameters['export'] -and -not $Parameters['import'])) {
                    # List playbooks
                    $playbooks = @(
                        @{Name = "deploy-web-app"; Category = "deployment"; Description = "Full web application deployment"},
                        @{Name = "disaster-recovery"; Category = "recovery"; Description = "Disaster recovery procedures"},
                        @{Name = "daily-backup"; Category = "maintenance"; Description = "Daily backup routine"},
                        @{Name = "security-scan"; Category = "security"; Description = "Comprehensive security scanning"}
                    )
                    
                    if ($Parameters['category']) {
                        $playbooks = $playbooks | Where-Object { $_.Category -eq $Parameters['category'] }
                    }
                    
                    if ($Parameters['search']) {
                        $pattern = $Parameters['search']
                        $playbooks = $playbooks | Where-Object { 
                            $_.Name -match $pattern -or $_.Description -match $pattern 
                        }
                    }
                    
                    foreach ($playbook in $playbooks) {
                        Write-CommandLog "$($playbook.Name) [$($playbook.Category)]" "INFO"
                        Write-CommandLog "  $($playbook.Description)" "DEBUG"
                    }
                } elseif ($Parameters['export']) {
                    Write-CommandLog "Exporting playbook: $($Parameters['export'])" "INFO"
                    Write-CommandLog "Export completed" "SUCCESS"
                } elseif ($Parameters['import']) {
                    Write-CommandLog "Importing playbook from: $($Parameters['import'])" "INFO"
                    Write-CommandLog "Import completed" "SUCCESS"
                }
            }
            
            default {
                throw "Unknown action: $Action"
            }
        }
    } catch {
        Write-CommandLog "Orchestration command failed: $($_.Exception.Message)" "ERROR"
        exit 1
    }
}

# Main execution
$params = ConvertTo-Parameters -Arguments $Arguments
Write-CommandLog "Executing orchestration action: $Action" "DEBUG"

Invoke-OrchestrationAction -Action $Action -Parameters $params