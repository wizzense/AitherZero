function Stop-DeploymentAutomation {
    <#
    .SYNOPSIS
        Stops automated deployment processes
    .DESCRIPTION
        Cancels running automation workflows, scheduled deployments, or continuous
        deployment pipelines with graceful shutdown
    .PARAMETER DeploymentId
        Deployment identifier
    .PARAMETER AutomationId
        Specific automation process ID
    .PARAMETER Force
        Force immediate termination
    .PARAMETER Timeout
        Graceful shutdown timeout in seconds
    .EXAMPLE
        Stop-DeploymentAutomation -DeploymentId "lab-prod-001" -AutomationId "auto-deploy-123"
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByDeployment')]
        [ValidateNotNullOrEmpty()]
        [string]$DeploymentId,
        
        [Parameter(Mandatory, ParameterSetName = 'ByAutomation')]
        [ValidateNotNullOrEmpty()]
        [string]$AutomationId,
        
        [Parameter()]
        [switch]$Force,
        
        [Parameter()]
        [ValidateRange(1, 300)]
        [int]$Timeout = 30
    )
    
    try {
        Write-CustomLog -Level 'INFO' -Message "Processing automation stop request"
        
        # Get automation state directory
        $automationPath = Join-Path $PSScriptRoot "../../automation"
        $statePath = Join-Path $automationPath "state"
        
        if (-not (Test-Path $statePath)) {
            Write-CustomLog -Level 'WARNING' -Message "No automation state directory found"
            return
        }
        
        # Find automation processes to stop
        $automationsToStop = @()
        
        switch ($PSCmdlet.ParameterSetName) {
            'ByDeployment' {
                # Find all automations for deployment
                $stateFiles = Get-ChildItem -Path $statePath -Filter "*.json" -File
                
                foreach ($file in $stateFiles) {
                    $state = Get-Content $file.FullName -Raw | ConvertFrom-Json
                    if ($state.DeploymentId -eq $DeploymentId -and $state.Status -in @('Running', 'Scheduled', 'Pending')) {
                        $automationsToStop += @{
                            File = $file
                            State = $state
                        }
                    }
                }
            }
            
            'ByAutomation' {
                # Find specific automation
                $stateFile = Join-Path $statePath "$AutomationId.json"
                
                if (Test-Path $stateFile) {
                    $state = Get-Content $stateFile -Raw | ConvertFrom-Json
                    if ($state.Status -in @('Running', 'Scheduled', 'Pending')) {
                        $automationsToStop += @{
                            File = Get-Item $stateFile
                            State = $state
                        }
                    }
                    else {
                        Write-CustomLog -Level 'INFO' -Message "Automation $AutomationId is not running (Status: $($state.Status))"
                        return
                    }
                }
                else {
                    throw "Automation not found: $AutomationId"
                }
            }
        }
        
        if ($automationsToStop.Count -eq 0) {
            Write-CustomLog -Level 'INFO' -Message "No running automations found"
            return
        }
        
        # Confirm stop action
        $message = "Stop $($automationsToStop.Count) automation process(es)?"
        if ($PSCmdlet.ShouldProcess($message)) {
            $results = @()
            
            foreach ($automation in $automationsToStop) {
                try {
                    $result = Stop-AutomationProcess -Automation $automation -Force:$Force -Timeout $Timeout
                    $results += $result
                }
                catch {
                    Write-CustomLog -Level 'ERROR' -Message "Failed to stop automation $($automation.State.AutomationId): $_"
                }
            }
            
            Write-CustomLog -Level 'SUCCESS' -Message "Stopped $($results.Count) automation process(es)"
            return $results
        }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to stop automation: $_"
        throw
    }
}

# Helper function to stop individual automation
function Stop-AutomationProcess {
    param(
        $Automation,
        [switch]$Force,
        [int]$Timeout
    )
    
    $state = $Automation.State
    $stateFile = $Automation.File
    
    Write-CustomLog -Level 'INFO' -Message "Stopping automation: $($state.AutomationId)"
    
    # Create stop signal file
    $signalPath = Join-Path (Split-Path $stateFile.FullName -Parent) "signals"
    if (-not (Test-Path $signalPath)) {
        New-Item -ItemType Directory -Path $signalPath -Force | Out-Null
    }
    
    $stopSignal = Join-Path $signalPath "$($state.AutomationId).stop"
    @{
        Timestamp = Get-Date -Format "yyyy-MM-dd'T'HH:mm:ss'Z'"
        RequestedBy = $env:USERNAME
        Force = $Force.IsPresent
        Reason = "Manual stop request"
    } | ConvertTo-Json | Set-Content -Path $stopSignal -Encoding UTF8
    
    # Update state to stopping
    $state.Status = 'Stopping'
    $state.StopRequested = Get-Date -Format "yyyy-MM-dd'T'HH:mm:ss'Z'"
    $state | ConvertTo-Json -Depth 5 | Set-Content -Path $stateFile.FullName -Encoding UTF8
    
    if ($Force) {
        # Force termination
        if ($state.ProcessId) {
            try {
                Stop-Process -Id $state.ProcessId -Force -ErrorAction Stop
                Write-CustomLog -Level 'WARNING' -Message "Force terminated process: $($state.ProcessId)"
            }
            catch {
                Write-CustomLog -Level 'WARNING' -Message "Process already terminated or not found: $($state.ProcessId)"
            }
        }
        
        # Update final state
        $state.Status = 'Terminated'
        $state.EndTime = Get-Date -Format "yyyy-MM-dd'T'HH:mm:ss'Z'"
        $state.TerminationReason = "Force terminated by user"
    }
    else {
        # Wait for graceful shutdown
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        while ($stopwatch.Elapsed.TotalSeconds -lt $Timeout) {
            Start-Sleep -Seconds 1
            
            # Check if process stopped
            if ($state.ProcessId) {
                $process = Get-Process -Id $state.ProcessId -ErrorAction SilentlyContinue
                if (-not $process) {
                    $state.Status = 'Stopped'
                    $state.EndTime = Get-Date -Format "yyyy-MM-dd'T'HH:mm:ss'Z'"
                    break
                }
            }
            
            # Check for completion signal
            $completeSignal = Join-Path $signalPath "$($state.AutomationId).complete"
            if (Test-Path $completeSignal) {
                $state.Status = 'Stopped'
                $state.EndTime = Get-Date -Format "yyyy-MM-dd'T'HH:mm:ss'Z'"
                Remove-Item $completeSignal -Force
                break
            }
        }
        
        # Timeout reached
        if ($state.Status -eq 'Stopping') {
            Write-CustomLog -Level 'WARNING' -Message "Graceful shutdown timeout reached, forcing termination"
            if ($state.ProcessId) {
                Stop-Process -Id $state.ProcessId -Force -ErrorAction SilentlyContinue
            }
            $state.Status = 'Terminated'
            $state.EndTime = Get-Date -Format "yyyy-MM-dd'T'HH:mm:ss'Z'"
            $state.TerminationReason = "Timeout during graceful shutdown"
        }
    }
    
    # Save final state
    $state | ConvertTo-Json -Depth 5 | Set-Content -Path $stateFile.FullName -Encoding UTF8
    
    # Clean up signal file
    if (Test-Path $stopSignal) {
        Remove-Item $stopSignal -Force
    }
    
    return [PSCustomObject]@{
        AutomationId = $state.AutomationId
        DeploymentId = $state.DeploymentId
        Status = $state.Status
        StartTime = $state.StartTime
        EndTime = $state.EndTime
        Duration = if ($state.EndTime) {
            ([datetime]$state.EndTime - [datetime]$state.StartTime).TotalSeconds
        } else { $null }
        TerminationReason = $state.TerminationReason
    }
}