function Invoke-DeploymentStage {
    <#
    .SYNOPSIS
        Invokes a specific deployment stage.

    .DESCRIPTION
        Executes all actions within a deployment stage with retry logic,
        error handling, and progress tracking. Supports both sequential
        and parallel action execution.

    .PARAMETER Plan
        Deployment plan object from New-DeploymentPlan.

    .PARAMETER StageName
        Name of the stage to execute.

    .PARAMETER DryRun
        Execute in dry-run mode without making changes.

    .PARAMETER MaxRetries
        Maximum retry attempts for failed actions.

    .PARAMETER Force
        Continue execution even if non-critical actions fail.

    .PARAMETER ActionTimeout
        Override default action timeout.

    .EXAMPLE
        $stageResult = Invoke-DeploymentStage -Plan $plan -StageName "Apply"

    .EXAMPLE
        $result = Invoke-DeploymentStage -Plan $plan -StageName "Validate" -DryRun

    .OUTPUTS
        Stage execution result object
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Plan,
        
        [Parameter(Mandatory)]
        [string]$StageName,
        
        [Parameter()]
        [switch]$DryRun,
        
        [Parameter()]
        [ValidateRange(0, 5)]
        [int]$MaxRetries = 2,
        
        [Parameter()]
        [switch]$Force,
        
        [Parameter()]
        [TimeSpan]$ActionTimeout
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Invoking deployment stage: $StageName"
        
        # Validate stage exists
        if (-not $Plan.Stages.ContainsKey($StageName)) {
            throw "Stage '$StageName' not found in deployment plan"
        }
        
        $stage = $Plan.Stages[$StageName]
        
        # Check prerequisites
        foreach ($prereq in $stage.Prerequisites) {
            if ($script:deploymentState -and -not ($script:deploymentState.CompletedStages -contains $prereq)) {
                throw "Prerequisite stage '$prereq' has not been completed"
            }
        }
    }
    
    process {
        try {
            # Initialize stage result
            $stageResult = @{
                StageName = $StageName
                Success = $false
                StartTime = Get-Date
                EndTime = $null
                Duration = $null
                Actions = @{}
                Outputs = @{}
                Error = $null
                Warnings = @()
                Artifacts = @{}
            }
            
            Write-CustomLog -Level 'INFO' -Message "Stage '$StageName' has $($stage.Actions.Count) action(s)"
            
            # Execute stage actions
            $actionResults = @()
            $criticalFailure = $false
            
            foreach ($action in $stage.Actions) {
                if ($criticalFailure -and -not $Force) {
                    Write-CustomLog -Level 'WARN' -Message "Skipping action '$($action.Name)' due to previous critical failure"
                    continue
                }
                
                Write-CustomLog -Level 'INFO' -Message "Executing action: $($action.Name)"
                
                # Initialize action result
                $actionResult = @{
                    Name = $action.Name
                    Success = $false
                    StartTime = Get-Date
                    EndTime = $null
                    Duration = $null
                    Output = $null
                    Error = $null
                    RetryCount = 0
                }
                
                # Determine timeout
                $timeout = if ($ActionTimeout) { $ActionTimeout } else { $action.Timeout }
                
                # Execute with retry logic
                $retryCount = 0
                $maxAttempts = if ($action.Type -eq 'OpenTofu') { 1 } else { $MaxRetries + 1 }
                
                while ($retryCount -lt $maxAttempts) {
                    try {
                        if ($retryCount -gt 0) {
                            Write-CustomLog -Level 'WARN' -Message "Retry attempt $retryCount for action '$($action.Name)'"
                            Start-Sleep -Seconds ($stage.RetryPolicy.DelaySeconds * $retryCount)
                        }
                        
                        # Execute based on action type with progress tracking integration
                        switch ($action.Type) {
                            'PowerShell' {
                                # Check if ProgressTracking is available for granular updates
                                if ((Get-Module -Name 'ProgressTracking' -ErrorAction SilentlyContinue)) {
                                    Write-ProgressLog -Message "Executing PowerShell action: $($action.Name)" -Level 'Info'
                                }
                                $actionOutput = Invoke-PowerShellAction -Action $action -DryRun:$DryRun -Timeout $timeout
                            }
                            
                            'OpenTofu' {
                                # Enhanced OpenTofu execution with progress tracking
                                if ((Get-Module -Name 'ProgressTracking' -ErrorAction SilentlyContinue)) {
                                    Write-ProgressLog -Message "Executing OpenTofu action: $($action.Name)" -Level 'Info'
                                }
                                $actionOutput = Invoke-OpenTofuAction -Action $action -Plan $Plan -Stage $stage -DryRun:$DryRun -Timeout $timeout
                            }
                            
                            default {
                                throw "Unknown action type: $($action.Type)"
                            }
                        }
                        
                        # Success
                        $actionResult.Success = $true
                        $actionResult.Output = $actionOutput
                        
                        # Extract outputs if available
                        if ($actionOutput -and $actionOutput.PSObject.Properties['Outputs']) {
                            foreach ($outputKey in $actionOutput.Outputs.Keys) {
                                $stageResult.Outputs[$outputKey] = $actionOutput.Outputs[$outputKey]
                            }
                        }
                        
                        Write-CustomLog -Level 'SUCCESS' -Message "Action '$($action.Name)' completed successfully"
                        break
                        
                    } catch {
                        $retryCount++
                        $actionResult.RetryCount = $retryCount - 1
                        $actionResult.Error = $_.Exception.Message
                        
                        if ($retryCount -ge $maxAttempts) {
                            Write-CustomLog -Level 'ERROR' -Message "Action '$($action.Name)' failed after $retryCount attempts: $($_.Exception.Message)"
                            
                            if (-not $action.ContinueOnError -and -not $Force) {
                                $criticalFailure = $true
                            } else {
                                $stageResult.Warnings += "Action '$($action.Name)' failed but continuing: $($_.Exception.Message)"
                            }
                        }
                    }
                }
                
                $actionResult.EndTime = Get-Date
                $actionResult.Duration = $actionResult.EndTime - $actionResult.StartTime
                
                $stageResult.Actions[$action.Name] = [PSCustomObject]$actionResult
                $actionResults += $actionResult
            }
            
            # Determine overall stage success
            $failedActions = $actionResults | Where-Object { -not $_.Success }
            $criticalFailures = $stage.Actions | Where-Object { 
                -not $_.ContinueOnError -and 
                ($stageResult.Actions[$_.Name].Success -eq $false)
            }
            
            if ($criticalFailures.Count -eq 0) {
                $stageResult.Success = $true
                Write-CustomLog -Level 'SUCCESS' -Message "Stage '$StageName' completed successfully"
            } else {
                $stageResult.Error = "Stage failed due to $($criticalFailures.Count) critical action failure(s)"
                Write-CustomLog -Level 'ERROR' -Message $stageResult.Error
            }
            
            # Generate stage artifacts
            if ($StageName -eq 'Plan' -and $stageResult.Success) {
                # Save plan file
                $planFile = Join-Path $script:deploymentDir "deployment-plan.json"
                $Plan | ConvertTo-Json -Depth 10 | Set-Content -Path $planFile
                $stageResult.Artifacts['PlanFile'] = $planFile
                
                # Save tofu plan if exists
                $tofuPlanFile = Join-Path $script:deploymentDir "tfplan"
                if (Test-Path $tofuPlanFile) {
                    $stageResult.Artifacts['TofuPlan'] = $tofuPlanFile
                }
            }
            
            # Stage-specific post-processing
            switch ($StageName) {
                'Apply' {
                    if ($stageResult.Success) {
                        # Save state file
                        $stateFile = Join-Path $script:deploymentDir "terraform.tfstate"
                        if (Test-Path $stateFile) {
                            $stageResult.Artifacts['StateFile'] = $stateFile
                        }
                        
                        # Extract resource information
                        $stageResult.Outputs['DeployedResources'] = Get-DeployedResourceInfo -StateFile $stateFile
                    }
                }
                
                'Verify' {
                    if ($stageResult.Success) {
                        # Generate verification report
                        $reportFile = Join-Path $script:deploymentDir "verification-report.html"
                        New-VerificationReport -StageResult $stageResult -OutputPath $reportFile
                        $stageResult.Artifacts['VerificationReport'] = $reportFile
                    }
                }
            }
            
            return [PSCustomObject]$stageResult
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to invoke stage '$StageName': $($_.Exception.Message)"
            throw
        } finally {
            $stageResult.EndTime = Get-Date
            $stageResult.Duration = $stageResult.EndTime - $stageResult.StartTime
            
            Write-CustomLog -Level 'INFO' -Message "Stage '$StageName' duration: $([Math]::Round($stageResult.Duration.TotalSeconds, 2)) seconds"
        }
    }
}

function Invoke-PowerShellAction {
    param(
        [PSCustomObject]$Action,
        [switch]$DryRun,
        [TimeSpan]$Timeout
    )
    
    try {
        if ($DryRun) {
            Write-CustomLog -Level 'INFO' -Message "[DRY-RUN] Would execute PowerShell action: $($Action.Name)"
            return @{
                DryRun = $true
                Message = "Action would be executed with parameters: $($Action.Parameters.Keys -join ', ')"
            }
        }
        
        # Create runspace for timeout support
        $runspace = [PowerShell]::Create()
        $runspace.AddScript($Action.Script)
        
        # Add parameters
        foreach ($param in $Action.Parameters.GetEnumerator()) {
            $runspace.AddParameter($param.Key, $param.Value) | Out-Null
        }
        
        # Execute with timeout
        $handle = $runspace.BeginInvoke()
        $completed = $handle.AsyncWaitHandle.WaitOne($Timeout)
        
        if ($completed) {
            $result = $runspace.EndInvoke($handle)
            $runspace.Dispose()
            return $result
        } else {
            $runspace.Stop()
            $runspace.Dispose()
            throw "Action timed out after $($Timeout.TotalSeconds) seconds"
        }
        
    } catch {
        throw "PowerShell action failed: $($_.Exception.Message)"
    }
}

function Invoke-OpenTofuAction {
    param(
        [PSCustomObject]$Action,
        [PSCustomObject]$Plan,
        [PSCustomObject]$Stage,
        [switch]$DryRun,
        [TimeSpan]$Timeout
    )
    
    # Check if ProgressTracking is available for detailed OpenTofu progress
    $useProgressTracking = (Get-Module -Name 'ProgressTracking' -ErrorAction SilentlyContinue) -ne $null
    
    try {
        # Prepare working directory
        $workingDir = Join-Path $script:deploymentDir "opentofu"
        if (-not (Test-Path $workingDir)) {
            New-Item -Path $workingDir -ItemType Directory -Force | Out-Null
        }
        
        # Copy template files
        $templatePath = Get-TemplateWorkingPath -Plan $Plan
        if (Test-Path $templatePath) {
            Copy-Item -Path "$templatePath\*" -Destination $workingDir -Recurse -Force
        }
        
        # Create terraform.tfvars
        $tfvarsPath = Join-Path $workingDir "terraform.tfvars"
        $tfvarsContent = ConvertTo-TerraformVariables -Variables $Plan.Configuration.variables
        $tfvarsContent | Set-Content -Path $tfvarsPath
        
        # Set environment variables
        $env:TF_IN_AUTOMATION = "true"
        $env:TF_INPUT = "false"
        
        # Execute OpenTofu command
        Push-Location $workingDir
        try {
            switch ($Action.Name) {
                'GeneratePlan' {
                    if ($DryRun) {
                        Write-CustomLog -Level 'INFO' -Message "[DRY-RUN] Would run: tofu plan"
                        if ($useProgressTracking) {
                            Write-ProgressLog -Message "[DRY-RUN] Plan generation would be executed" -Level 'Info'
                        }
                        return @{ DryRun = $true; Message = "Plan would be generated" }
                    }
                    
                    # Initialize if needed
                    if (-not (Test-Path ".terraform")) {
                        if ($useProgressTracking) {
                            Write-ProgressLog -Message "Initializing OpenTofu workspace" -Level 'Info'
                        }
                        Write-CustomLog -Level 'INFO' -Message "Initializing OpenTofu"
                        $initResult = & tofu init -no-color 2>&1
                        if ($LASTEXITCODE -ne 0) {
                            if ($useProgressTracking) {
                                Write-ProgressLog -Message "OpenTofu initialization failed" -Level 'Error'
                            }
                            throw "tofu init failed: $initResult"
                        }
                        if ($useProgressTracking) {
                            Write-ProgressLog -Message "OpenTofu workspace initialized successfully" -Level 'Success'
                        }
                    }
                    
                    # Run plan
                    if ($useProgressTracking) {
                        Write-ProgressLog -Message "Generating deployment plan..." -Level 'Info'
                    }
                    Write-CustomLog -Level 'INFO' -Message "Running tofu plan"
                    $planResult = & tofu plan -out=tfplan -no-color 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        if ($useProgressTracking) {
                            Write-ProgressLog -Message "Plan generation failed" -Level 'Error'
                        }
                        throw "tofu plan failed: $planResult"
                    }
                    
                    # Parse plan output
                    $planSummary = Parse-TofuPlanOutput -Output $planResult
                    
                    if ($useProgressTracking) {
                        $summaryMsg = "Plan generated: $($planSummary.ToAdd) to add, $($planSummary.ToChange) to change, $($planSummary.ToDestroy) to destroy"
                        Write-ProgressLog -Message $summaryMsg -Level 'Success'
                    }
                    
                    return @{
                        Success = $true
                        Summary = $planSummary
                        PlanFile = "tfplan"
                    }
                }
                
                'ApplyInfrastructure' {
                    if ($DryRun) {
                        Write-CustomLog -Level 'INFO' -Message "[DRY-RUN] Would run: tofu apply"
                        if ($useProgressTracking) {
                            Write-ProgressLog -Message "[DRY-RUN] Infrastructure deployment would be executed" -Level 'Info'
                        }
                        return @{ DryRun = $true; Message = "Infrastructure would be applied" }
                    }
                    
                    # Check for plan file
                    if (-not (Test-Path "tfplan")) {
                        if ($useProgressTracking) {
                            Write-ProgressLog -Message "No plan file found. Plan stage must be executed first." -Level 'Error'
                        }
                        throw "No plan file found. Run Plan stage first."
                    }
                    
                    # Run apply
                    if ($useProgressTracking) {
                        Write-ProgressLog -Message "Applying infrastructure changes..." -Level 'Info'
                    }
                    Write-CustomLog -Level 'INFO' -Message "Running tofu apply"
                    
                    # Start apply with real-time progress monitoring
                    $startTime = Get-Date
                    $applyResult = & tofu apply -auto-approve tfplan -no-color 2>&1
                    $endTime = Get-Date
                    $duration = $endTime - $startTime
                    
                    if ($LASTEXITCODE -ne 0) {
                        if ($useProgressTracking) {
                            Write-ProgressLog -Message "Infrastructure deployment failed after $([Math]::Round($duration.TotalSeconds, 1))s" -Level 'Error'
                        }
                        throw "tofu apply failed: $applyResult"
                    }
                    
                    if ($useProgressTracking) {
                        Write-ProgressLog -Message "Infrastructure deployment completed in $([Math]::Round($duration.TotalSeconds, 1))s" -Level 'Success'
                    }
                    
                    # Get outputs
                    if ($useProgressTracking) {
                        Write-ProgressLog -Message "Retrieving deployment outputs..." -Level 'Info'
                    }
                    
                    $outputs = & tofu output -json 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $outputData = $outputs | ConvertFrom-Json
                        $convertedOutputs = Convert-TofuOutputs -RawOutputs $outputData
                        
                        if ($useProgressTracking) {
                            $outputCount = $convertedOutputs.Keys.Count
                            Write-ProgressLog -Message "Retrieved $outputCount deployment outputs" -Level 'Success'
                        }
                        
                        return @{
                            Success = $true
                            Outputs = $convertedOutputs
                            Duration = $duration
                        }
                    }
                    
                    return @{ 
                        Success = $true
                        Duration = $duration
                    }
                }
                
                default {
                    throw "Unknown OpenTofu action: $($Action.Name)"
                }
            }
        } finally {
            Pop-Location
        }
        
    } catch {
        throw "OpenTofu action failed: $($_.Exception.Message)"
    }
}

function Get-TemplateWorkingPath {
    param([PSCustomObject]$Plan)
    
    # Get template from repository
    $repoPath = Join-Path $env:PROJECT_ROOT "infrastructure-repos" $Plan.Configuration.repository.name
    $templatePath = Join-Path $repoPath "templates" $Plan.Configuration.template.name
    
    if (Test-Path $templatePath) {
        return $templatePath
    }
    
    # Check for versioned template
    $versionedPath = Join-Path $repoPath "templates" "$($Plan.Configuration.template.name)-v$($Plan.Configuration.template.version)"
    if (Test-Path $versionedPath) {
        return $versionedPath
    }
    
    throw "Template not found: $($Plan.Configuration.template.name)"
}

function ConvertTo-TerraformVariables {
    param([PSCustomObject]$Variables)
    
    $tfvars = @()
    
    if ($Variables) {
        foreach ($prop in $Variables.PSObject.Properties) {
            $value = $prop.Value
            
            # Format value based on type
            if ($value -is [string]) {
                $tfvars += "$($prop.Name) = `"$value`""
            } elseif ($value -is [bool]) {
                $tfvars += "$($prop.Name) = $(if ($value) { 'true' } else { 'false' })"
            } elseif ($value -is [array]) {
                $arrayValues = $value | ForEach-Object { "`"$_`"" }
                $tfvars += "$($prop.Name) = [$($arrayValues -join ', ')]"
            } elseif ($value -is [hashtable] -or $value -is [PSCustomObject]) {
                $jsonValue = $value | ConvertTo-Json -Compress
                $tfvars += "$($prop.Name) = $jsonValue"
            } else {
                $tfvars += "$($prop.Name) = $value"
            }
        }
    }
    
    return $tfvars -join "`n"
}

function Parse-TofuPlanOutput {
    param([string[]]$Output)
    
    $summary = @{
        ToAdd = 0
        ToChange = 0
        ToDestroy = 0
        NoChanges = $false
    }
    
    foreach ($line in $Output) {
        if ($line -match 'Plan: (\d+) to add, (\d+) to change, (\d+) to destroy') {
            $summary.ToAdd = [int]$matches[1]
            $summary.ToChange = [int]$matches[2]
            $summary.ToDestroy = [int]$matches[3]
        } elseif ($line -match 'No changes. Your infrastructure matches the configuration.') {
            $summary.NoChanges = $true
        }
    }
    
    return $summary
}

function Convert-TofuOutputs {
    param([PSCustomObject]$RawOutputs)
    
    $outputs = @{}
    
    foreach ($prop in $RawOutputs.PSObject.Properties) {
        $outputs[$prop.Name] = $prop.Value.value
    }
    
    return $outputs
}

function Get-DeployedResourceInfo {
    param([string]$StateFile)
    
    if (-not (Test-Path $StateFile)) {
        return @{}
    }
    
    try {
        $state = Get-Content $StateFile | ConvertFrom-Json
        $resources = @{}
        
        foreach ($resource in $state.resources) {
            $resources[$resource.type] = @{
                Count = $resource.instances.Count
                Provider = $resource.provider
            }
        }
        
        return $resources
    } catch {
        Write-CustomLog -Level 'WARN' -Message "Could not parse state file: $_"
        return @{}
    }
}

function New-VerificationReport {
    param(
        [PSCustomObject]$StageResult,
        [string]$OutputPath
    )
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Deployment Verification Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        .success { color: green; }
        .failure { color: red; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Deployment Verification Report</h1>
    <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
    <p>Status: <span class="$(if ($StageResult.Success) { 'success' } else { 'failure' })">$(if ($StageResult.Success) { 'PASSED' } else { 'FAILED' })</span></p>
    
    <h2>Test Results</h2>
    <table>
        <tr>
            <th>Test</th>
            <th>Status</th>
            <th>Duration</th>
            <th>Details</th>
        </tr>
"@
    
    foreach ($action in $StageResult.Actions.Values) {
        $status = if ($action.Success) { 'PASS' } else { 'FAIL' }
        $statusClass = if ($action.Success) { 'success' } else { 'failure' }
        $duration = if ($action.Duration) { "$([Math]::Round($action.Duration.TotalSeconds, 2))s" } else { 'N/A' }
        $details = if ($action.Error) { $action.Error } else { 'Success' }
        
        $html += @"
        <tr>
            <td>$($action.Name)</td>
            <td class="$statusClass">$status</td>
            <td>$duration</td>
            <td>$details</td>
        </tr>
"@
    }
    
    $html += @"
    </table>
</body>
</html>
"@
    
    $html | Set-Content -Path $OutputPath
    Write-CustomLog -Level 'INFO' -Message "Verification report generated: $OutputPath"
}