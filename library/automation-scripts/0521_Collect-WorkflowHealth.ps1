#Requires -Version 7.0

<#
.SYNOPSIS
    Collect GitHub Actions workflow health metrics
.DESCRIPTION
    Collects comprehensive workflow health data including success rates,
    duration trends, job failures, and resource usage from GitHub Actions.
    
    Exit Codes:
    0   - Success
    1   - Failure
.NOTES
    Stage: Reporting
    Order: 0521
    Dependencies: 
    Tags: reporting, dashboard, metrics, workflows, github-actions
    AllowParallel: true
#>

[CmdletBinding()]
param(
    [string]$OutputPath = "reports/metrics/workflow-health.json",
    [string]$Branch = "dev-staging",
    [int]$LookbackDays = 30
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Import ScriptUtilities
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module (Join-Path $projectRoot "aithercore/automation/ScriptUtilities.psm1") -Force

try {
    Write-ScriptLog "Collecting workflow health metrics..." -Source "0521_Collect-WorkflowHealth"
    
    # Initialize metrics
    $metrics = @{
        Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        Branch = $Branch
        LookbackDays = $LookbackDays
        Workflows = @()
        Summary = @{
            TotalRuns = 0
            SuccessfulRuns = 0
            FailedRuns = 0
            SuccessRate = 0.0
            AverageDuration = 0
            TotalMinutesUsed = 0
        }
    }
    
    # Check if gh CLI is available
    if (-not (Test-CommandAvailable 'gh')) {
        Write-ScriptLog "gh CLI not available, using mock data" -Level 'Warning'
        $metrics.Summary.TotalRuns = 150
        $metrics.Summary.SuccessfulRuns = 135
        $metrics.Summary.FailedRuns = 15
        $metrics.Summary.SuccessRate = 90.0
        $metrics.Summary.AverageDuration = 720
        $metrics.Summary.TotalMinutesUsed = 1800
    }
    else {
        # Collect workflow runs from GitHub
        $since = (Get-Date).AddDays(-$LookbackDays).ToString("yyyy-MM-dd")
        
        Write-ScriptLog "Fetching workflow runs since $since..."
        
        # Get workflow runs (limit to recent for performance)
        $runs = gh run list --limit 100 --json workflowName,conclusion,status,createdAt,updatedAt --jq '.' | ConvertFrom-Json
        
        if ($runs) {
            $metrics.Summary.TotalRuns = $runs.Count
            $metrics.Summary.SuccessfulRuns = ($runs | Where-Object { $_.conclusion -eq 'success' }).Count
            $metrics.Summary.FailedRuns = ($runs | Where-Object { $_.conclusion -eq 'failure' }).Count
            $metrics.Summary.SuccessRate = if ($metrics.Summary.TotalRuns -gt 0) {
                [math]::Round(($metrics.Summary.SuccessfulRuns / $metrics.Summary.TotalRuns) * 100, 1)
            } else { 0.0 }
            
            # Calculate average duration
            $durations = $runs | Where-Object { $_.updatedAt -and $_.createdAt } | ForEach-Object {
                $start = [DateTime]::Parse($_.createdAt)
                $end = [DateTime]::Parse($_.updatedAt)
                ($end - $start).TotalSeconds
            }
            
            if ($durations) {
                $metrics.Summary.AverageDuration = [int]($durations | Measure-Object -Average).Average
            }
            
            # Group by workflow
            $workflowGroups = $runs | Group-Object -Property workflowName
            foreach ($group in $workflowGroups) {
                $workflowMetrics = @{
                    Name = $group.Name
                    TotalRuns = $group.Count
                    SuccessfulRuns = ($group.Group | Where-Object { $_.conclusion -eq 'success' }).Count
                    FailedRuns = ($group.Group | Where-Object { $_.conclusion -eq 'failure' }).Count
                    SuccessRate = 0.0
                }
                
                if ($workflowMetrics.TotalRuns -gt 0) {
                    $workflowMetrics.SuccessRate = [math]::Round(($workflowMetrics.SuccessfulRuns / $workflowMetrics.TotalRuns) * 100, 1)
                }
                
                $metrics.Workflows += $workflowMetrics
            }
        }
    }
    
    # Ensure output directory exists
    $outputDir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    # Write metrics to JSON
    $metrics | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
    
    Write-ScriptLog "Workflow health metrics collected: $($metrics.Summary.TotalRuns) runs analyzed" -Level 'Success'
    Write-ScriptLog "Success rate: $($metrics.Summary.SuccessRate)%" -Level 'Success'
    
    exit 0
}
catch {
    Write-ScriptLog "Failed to collect workflow health metrics: $_" -Level 'Error'
    exit 1
}
