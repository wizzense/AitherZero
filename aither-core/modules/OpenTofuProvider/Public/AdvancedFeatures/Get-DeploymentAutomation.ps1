function Get-DeploymentAutomation {
    <#
    .SYNOPSIS
        Retrieves automation status and configuration
    .DESCRIPTION
        Gets information about automated deployment processes including schedules,
        workflows, and execution history
    .PARAMETER DeploymentId
        Filter by deployment ID
    .PARAMETER AutomationId
        Get specific automation details
    .PARAMETER Status
        Filter by automation status
    .PARAMETER IncludeHistory
        Include execution history
    .EXAMPLE
        Get-DeploymentAutomation -DeploymentId "lab-prod-001" -Status Running
    #>
    [CmdletBinding(DefaultParameterSetName = 'List')]
    param(
        [Parameter(ParameterSetName = 'List')]
        [ValidateNotNullOrEmpty()]
        [string]$DeploymentId,
        
        [Parameter(Mandatory, ParameterSetName = 'Specific')]
        [ValidateNotNullOrEmpty()]
        [string]$AutomationId,
        
        [Parameter(ParameterSetName = 'List')]
        [ValidateSet('Scheduled', 'Running', 'Pending', 'Completed', 'Failed', 'Stopped', 'Terminated')]
        [string[]]$Status,
        
        [Parameter()]
        [switch]$IncludeHistory
    )
    
    try {
        Write-CustomLog -Level 'INFO' -Message "Retrieving automation information"
        
        # Get automation directories
        $automationPath = Join-Path $PSScriptRoot "../../automation"
        $statePath = Join-Path $automationPath "state"
        $historyPath = Join-Path $automationPath "history"
        
        if (-not (Test-Path $statePath)) {
            Write-CustomLog -Level 'WARNING' -Message "No automation state directory found"
            return $null
        }
        
        switch ($PSCmdlet.ParameterSetName) {
            'Specific' {
                # Get specific automation details
                $stateFile = Join-Path $statePath "$AutomationId.json"
                
                if (-not (Test-Path $stateFile)) {
                    # Check history
                    $historyFile = Join-Path $historyPath "$AutomationId.json"
                    if (Test-Path $historyFile) {
                        $automation = Get-Content $historyFile -Raw | ConvertFrom-Json
                        $automation | Add-Member -NotePropertyName IsHistorical -NotePropertyValue $true
                    }
                    else {
                        throw "Automation not found: $AutomationId"
                    }
                }
                else {
                    $automation = Get-Content $stateFile -Raw | ConvertFrom-Json
                    $automation | Add-Member -NotePropertyName IsHistorical -NotePropertyValue $false
                }
                
                # Enrich with additional details
                $result = [PSCustomObject]@{
                    AutomationId = $automation.AutomationId
                    DeploymentId = $automation.DeploymentId
                    Type = $automation.Type
                    Status = $automation.Status
                    Schedule = $automation.Schedule
                    StartTime = $automation.StartTime
                    EndTime = $automation.EndTime
                    Duration = if ($automation.EndTime) {
                        ([datetime]$automation.EndTime - [datetime]$automation.StartTime).TotalSeconds
                    } else { $null }
                    Configuration = $automation.Configuration
                    LastError = $automation.LastError
                    ExecutionCount = $automation.ExecutionCount
                    NextRun = $automation.NextRun
                    IsHistorical = $automation.IsHistorical
                }
                
                # Add execution history if requested
                if ($IncludeHistory -and $automation.History) {
                    $result | Add-Member -NotePropertyName History -NotePropertyValue $automation.History
                }
                
                # Check for active process
                if ($automation.ProcessId -and $automation.Status -eq 'Running') {
                    $process = Get-Process -Id $automation.ProcessId -ErrorAction SilentlyContinue
                    $result | Add-Member -NotePropertyName ProcessActive -NotePropertyValue ($null -ne $process)
                }
                
                return $result
            }
            
            'List' {
                # Get all automations matching criteria
                $automations = @()
                
                # Get active automations
                $stateFiles = Get-ChildItem -Path $statePath -Filter "*.json" -File -ErrorAction SilentlyContinue
                
                foreach ($file in $stateFiles) {
                    $automation = Get-Content $file.FullName -Raw | ConvertFrom-Json
                    
                    # Apply filters
                    if ($DeploymentId -and $automation.DeploymentId -ne $DeploymentId) {
                        continue
                    }
                    
                    if ($Status -and $automation.Status -notin $Status) {
                        continue
                    }
                    
                    $automations += [PSCustomObject]@{
                        AutomationId = $automation.AutomationId
                        DeploymentId = $automation.DeploymentId
                        Type = $automation.Type
                        Status = $automation.Status
                        Schedule = $automation.Schedule
                        StartTime = $automation.StartTime
                        NextRun = $automation.NextRun
                        IsHistorical = $false
                    }
                }
                
                # Include historical if requested
                if ($IncludeHistory -and (Test-Path $historyPath)) {
                    $historyFiles = Get-ChildItem -Path $historyPath -Filter "*.json" -File -ErrorAction SilentlyContinue | 
                        Select-Object -First 100  # Limit history
                    
                    foreach ($file in $historyFiles) {
                        $automation = Get-Content $file.FullName -Raw | ConvertFrom-Json
                        
                        # Apply filters
                        if ($DeploymentId -and $automation.DeploymentId -ne $DeploymentId) {
                            continue
                        }
                        
                        if ($Status -and $automation.Status -notin $Status) {
                            continue
                        }
                        
                        $automations += [PSCustomObject]@{
                            AutomationId = $automation.AutomationId
                            DeploymentId = $automation.DeploymentId
                            Type = $automation.Type
                            Status = $automation.Status
                            Schedule = $automation.Schedule
                            StartTime = $automation.StartTime
                            EndTime = $automation.EndTime
                            IsHistorical = $true
                        }
                    }
                }
                
                # Sort by start time (newest first)
                $automations = $automations | Sort-Object { 
                    if ($_.StartTime) { [datetime]$_.StartTime } else { [datetime]::MinValue }
                } -Descending
                
                # Add summary
                if ($automations.Count -gt 0) {
                    $summary = @{
                        TotalCount = $automations.Count
                        Active = ($automations | Where-Object { $_.Status -in @('Running', 'Scheduled', 'Pending') }).Count
                        Completed = ($automations | Where-Object { $_.Status -eq 'Completed' }).Count
                        Failed = ($automations | Where-Object { $_.Status -eq 'Failed' }).Count
                    }
                    
                    Write-Host "`nAutomation Summary:" -ForegroundColor Cyan
                    Write-Host "  Total:     $($summary.TotalCount)"
                    Write-Host "  Active:    $($summary.Active)" -ForegroundColor Yellow
                    Write-Host "  Completed: $($summary.Completed)" -ForegroundColor Green
                    Write-Host "  Failed:    $($summary.Failed)" -ForegroundColor Red
                    Write-Host ""
                }
                
                return $automations
            }
        }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to retrieve automation information: $_"
        throw
    }
}