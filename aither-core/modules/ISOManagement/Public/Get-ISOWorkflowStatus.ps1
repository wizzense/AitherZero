function Get-ISOWorkflowStatus {
    <#
    .SYNOPSIS
        Retrieves status information for ISO management workflows.

    .DESCRIPTION
        This function provides comprehensive status information for ISO lifecycle workflows,
        including active workflows, completed workflows, and workflow history. It supports
        filtering and detailed reporting for workflow monitoring and troubleshooting.

    .PARAMETER WorkflowId
        Specific workflow ID to retrieve status for

    .PARAMETER WorkflowName
        Filter workflows by name pattern

    .PARAMETER Status
        Filter workflows by status (InProgress, Success, Failed, Partial)

    .PARAMETER TimeRange
        Time range for workflow filtering:
        - 'Today' - Workflows from today
        - 'Week' - Workflows from past 7 days
        - 'Month' - Workflows from past 30 days
        - 'All' - All workflows in history

    .PARAMETER IncludeDetails
        Include detailed phase information and metadata

    .PARAMETER IncludePerformance
        Include performance metrics and timing information

    .PARAMETER OutputFormat
        Output format for the results:
        - 'Object' - PowerShell objects (default)
        - 'Table' - Formatted table display
        - 'Json' - JSON format
        - 'Csv' - CSV format

    .EXAMPLE
        # Get all workflows from today
        Get-ISOWorkflowStatus -TimeRange 'Today'

    .EXAMPLE
        # Get detailed status for specific workflow
        Get-ISOWorkflowStatus -WorkflowId 'WF-20250707-143022-a1b2c3d4' -IncludeDetails -IncludePerformance

    .EXAMPLE
        # Get failed workflows from past week
        Get-ISOWorkflowStatus -Status 'Failed' -TimeRange 'Week' -IncludeDetails

    .EXAMPLE
        # Get workflow status in table format
        Get-ISOWorkflowStatus -TimeRange 'Week' -OutputFormat 'Table'

    .OUTPUTS
        Array of workflow status objects or formatted output based on OutputFormat parameter
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$WorkflowId,

        [Parameter(Mandatory = $false)]
        [string]$WorkflowName,

        [Parameter(Mandatory = $false)]
        [ValidateSet('InProgress', 'Success', 'Failed', 'Partial', 'All')]
        [string]$Status = 'All',

        [Parameter(Mandatory = $false)]
        [ValidateSet('Today', 'Week', 'Month', 'All')]
        [string]$TimeRange = 'All',

        [Parameter(Mandatory = $false)]
        [switch]$IncludeDetails,

        [Parameter(Mandatory = $false)]
        [switch]$IncludePerformance,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Object', 'Table', 'Json', 'Csv')]
        [string]$OutputFormat = 'Object'
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Retrieving workflow status information"
        
        # Load workflow history
        $historyPath = $script:ISOManagementConfig.WorkflowHistoryPath
        $workflows = @()
        
        if (Test-Path $historyPath) {
            try {
                $history = Get-Content $historyPath | ConvertFrom-Json
                $workflows = $history.Workflows
                Write-CustomLog -Level 'DEBUG' -Message "Loaded $($workflows.Count) workflows from history"
            } catch {
                Write-CustomLog -Level 'WARNING' -Message "Failed to load workflow history: $($_.Exception.Message)"
                return @()
            }
        } else {
            Write-CustomLog -Level 'INFO' -Message "No workflow history file found"
            return @()
        }
    }

    process {
        # Filter workflows based on parameters
        $filteredWorkflows = $workflows
        
        # Filter by WorkflowId
        if ($WorkflowId) {
            $filteredWorkflows = $filteredWorkflows | Where-Object { $_.WorkflowId -eq $WorkflowId }
        }
        
        # Filter by WorkflowName
        if ($WorkflowName) {
            $filteredWorkflows = $filteredWorkflows | Where-Object { $_.WorkflowName -like "*$WorkflowName*" }
        }
        
        # Filter by Status
        if ($Status -ne 'All') {
            $filteredWorkflows = $filteredWorkflows | Where-Object { $_.Status -eq $Status }
        }
        
        # Filter by TimeRange
        $cutoffDate = switch ($TimeRange) {
            'Today' { (Get-Date).Date }
            'Week' { (Get-Date).AddDays(-7) }
            'Month' { (Get-Date).AddDays(-30) }
            'All' { [DateTime]::MinValue }
        }
        
        if ($TimeRange -ne 'All') {
            $filteredWorkflows = $filteredWorkflows | Where-Object { 
                [DateTime]::Parse($_.StartTime) -ge $cutoffDate 
            }
        }
        
        # Build result objects
        $results = @()
        
        foreach ($workflow in $filteredWorkflows) {
            $result = [PSCustomObject]@{
                WorkflowId = $workflow.WorkflowId
                WorkflowName = $workflow.WorkflowName
                Status = $workflow.Status
                StartTime = $workflow.StartTime
                EndTime = $workflow.EndTime
                Duration = $workflow.Duration
                ISOName = $workflow.ISOName
                OutputISO = $workflow.OutputISO
            }
            
            # Add phase information if requested
            if ($IncludeDetails) {
                $result | Add-Member -NotePropertyName 'Phases' -NotePropertyValue $workflow.Phases
                
                # Add detailed phase analysis
                $phaseAnalysis = @{
                    TotalPhases = 0
                    CompletedPhases = 0
                    FailedPhases = 0
                    SkippedPhases = 0
                    InProgressPhases = 0
                }
                
                if ($workflow.Phases) {
                    foreach ($phase in $workflow.Phases) {
                        $phaseStatus = $phase.Split(':')[1].Trim()
                        $phaseAnalysis.TotalPhases++
                        
                        switch ($phaseStatus) {
                            'Completed' { $phaseAnalysis.CompletedPhases++ }
                            'Failed' { $phaseAnalysis.FailedPhases++ }
                            'Skipped' { $phaseAnalysis.SkippedPhases++ }
                            'InProgress' { $phaseAnalysis.InProgressPhases++ }
                        }
                    }
                }
                
                $result | Add-Member -NotePropertyName 'PhaseAnalysis' -NotePropertyValue $phaseAnalysis
            }
            
            # Add performance metrics if requested
            if ($IncludePerformance) {
                $performance = @{
                    DurationMinutes = 0
                    DurationSeconds = 0
                    SuccessRate = 0
                }
                
                if ($workflow.Duration) {
                    try {
                        $duration = [TimeSpan]::Parse($workflow.Duration)
                        $performance.DurationMinutes = [Math]::Round($duration.TotalMinutes, 2)
                        $performance.DurationSeconds = [Math]::Round($duration.TotalSeconds, 0)
                    } catch {
                        Write-CustomLog -Level 'DEBUG' -Message "Could not parse duration: $($workflow.Duration)"
                    }
                }
                
                # Calculate success rate based on phase completion
                if ($workflow.Phases -and $workflow.Phases.Count -gt 0) {
                    $completedPhases = ($workflow.Phases | Where-Object { $_ -like "*Completed*" }).Count
                    $totalPhases = $workflow.Phases.Count
                    $performance.SuccessRate = [Math]::Round(($completedPhases / $totalPhases) * 100, 1)
                }
                
                $result | Add-Member -NotePropertyName 'Performance' -NotePropertyValue $performance
            }
            
            $results += $result
        }
        
        # Sort results by start time (most recent first)
        $results = $results | Sort-Object StartTime -Descending
        
        # Format output based on requested format
        switch ($OutputFormat) {
            'Object' {
                return $results
            }
            
            'Table' {
                if ($results.Count -eq 0) {
                    Write-Host "No workflows found matching the specified criteria." -ForegroundColor Yellow
                    return
                }
                
                Write-Host ""
                Write-Host "=== ISO Workflow Status Report ===" -ForegroundColor Green
                Write-Host "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
                Write-Host "Filter: Status=$Status, TimeRange=$TimeRange" -ForegroundColor Gray
                Write-Host ""
                
                # Summary statistics
                $statusCounts = $results | Group-Object Status | ForEach-Object { "$($_.Name): $($_.Count)" }
                Write-Host "Summary: $($results.Count) workflows ($($statusCounts -join ', '))" -ForegroundColor White
                Write-Host ""
                
                # Format table
                $tableData = $results | Select-Object @{
                    Name = 'Workflow ID'
                    Expression = { $_.WorkflowId.Substring($_.WorkflowId.Length - 8) }
                }, @{
                    Name = 'Name'
                    Expression = { 
                        if ($_.WorkflowName.Length -gt 20) { 
                            $_.WorkflowName.Substring(0, 17) + "..." 
                        } else { 
                            $_.WorkflowName 
                        }
                    }
                }, @{
                    Name = 'Status'
                    Expression = { 
                        switch ($_.Status) {
                            'Success' { "$([char]0x2713) Success" }
                            'Failed' { "$([char]0x2717) Failed" }
                            'InProgress' { "$([char]0x23F3) InProgress" }
                            'Partial' { "$([char]0x26A0) Partial" }
                            default { $_.Status }
                        }
                    }
                }, @{
                    Name = 'ISO Name'
                    Expression = { 
                        if ($_.ISOName.Length -gt 15) { 
                            $_.ISOName.Substring(0, 12) + "..." 
                        } else { 
                            $_.ISOName 
                        }
                    }
                }, @{
                    Name = 'Start Time'
                    Expression = { 
                        try {
                            [DateTime]::Parse($_.StartTime).ToString('MM/dd HH:mm')
                        } catch {
                            $_.StartTime
                        }
                    }
                }, @{
                    Name = 'Duration'
                    Expression = { 
                        if ($_.Duration) {
                            try {
                                $ts = [TimeSpan]::Parse($_.Duration)
                                if ($ts.TotalHours -ge 1) {
                                    "{0:hh\:mm\:ss}" -f $ts
                                } else {
                                    "{0:mm\:ss}" -f $ts
                                }
                            } catch {
                                $_.Duration
                            }
                        } else {
                            "N/A"
                        }
                    }
                }
                
                $tableData | Format-Table -AutoSize
                
                if ($IncludeDetails -and $results.Count -gt 0) {
                    Write-Host ""
                    Write-Host "=== Detailed Phase Information ===" -ForegroundColor Green
                    
                    foreach ($workflow in $results | Select-Object -First 5) {
                        Write-Host ""
                        Write-Host "Workflow: $($workflow.WorkflowName) ($($workflow.WorkflowId))" -ForegroundColor Yellow
                        Write-Host "Status: $($workflow.Status) | Start: $($workflow.StartTime)" -ForegroundColor White
                        
                        if ($workflow.Phases) {
                            foreach ($phase in $workflow.Phases) {
                                $phaseName = $phase.Split(':')[0]
                                $phaseStatus = $phase.Split(':')[1].Trim()
                                
                                $statusIcon = switch ($phaseStatus) {
                                    'Completed' { "$([char]0x2713)" }
                                    'Failed' { "$([char]0x2717)" }
                                    'Skipped' { "$([char]0x23ED)" }
                                    'InProgress' { "$([char]0x23F3)" }
                                    default { "$([char]0x2022)" }
                                }
                                
                                Write-Host "  $statusIcon $phaseName`: $phaseStatus" -ForegroundColor Gray
                            }
                        }
                    }
                }
                
                return
            }
            
            'Json' {
                return $results | ConvertTo-Json -Depth 10
            }
            
            'Csv' {
                $csvData = $results | Select-Object WorkflowId, WorkflowName, Status, StartTime, EndTime, Duration, ISOName, OutputISO
                return $csvData | ConvertTo-Csv -NoTypeInformation
            }
        }
    }
}