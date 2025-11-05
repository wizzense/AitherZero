#Requires -Version 7.0

<#
.SYNOPSIS
    GitHub Actions Workflow Parser for AitherZero Orchestration Engine

.DESCRIPTION
    Converts GitHub Actions YAML workflow files into AitherZero orchestration playbooks.
    Enables direct execution of GitHub Actions workflows locally using the orchestration engine.

.NOTES
    Part of Orchestration Engine Phase 2 enhancements
    
    Supported GitHub Actions Features:
    - jobs with steps
    - matrix strategy
    - environment variables
    - job dependencies (needs)
    - conditional execution (if)
    - job outputs
    - runs-on (mapped to platform)
    
    Limitations:
    - actions/checkout, actions/cache etc. are mapped to equivalent local operations
    - GitHub context variables (${{ github.* }}) are substituted with local equivalents
    - Service containers require Docker to be available
#>

function ConvertFrom-GitHubWorkflow {
    <#
    .SYNOPSIS
    Parse a GitHub Actions YAML workflow and convert it to an orchestration playbook
    
    .DESCRIPTION
    Takes a GitHub Actions workflow YAML file and converts it into an AitherZero
    orchestration playbook that can be executed locally.
    
    .PARAMETER WorkflowPath
    Path to the GitHub Actions workflow YAML file
    
    .PARAMETER OutputPath
    Optional path to save the converted playbook. If not specified, returns the playbook object.
    
    .PARAMETER VariableSubstitutions
    Hashtable of variable substitutions for GitHub context variables
    
    .EXAMPLE
    ConvertFrom-GitHubWorkflow -WorkflowPath ".github/workflows/test.yml"
    
    .EXAMPLE
    ConvertFrom-GitHubWorkflow -WorkflowPath ".github/workflows/test.yml" -OutputPath "orchestration/playbooks/test.json"
    
    .EXAMPLE
    $playbook = ConvertFrom-GitHubWorkflow -WorkflowPath ".github/workflows/test.yml"
    Invoke-OrchestrationSequence -LoadPlaybook $playbook
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$WorkflowPath,
        
        [Parameter()]
        [string]$OutputPath,
        
        [Parameter()]
        [hashtable]$VariableSubstitutions = @{}
    )
    
    # Ensure powershell-yaml module is available
    if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
        throw "powershell-yaml module is required. Install it with: Install-Module powershell-yaml"
    }
    
    Import-Module powershell-yaml -ErrorAction Stop
    
    # Load and parse the workflow YAML
    if (-not (Test-Path $WorkflowPath)) {
        throw "Workflow file not found: $WorkflowPath"
    }
    
    $workflowContent = Get-Content $WorkflowPath -Raw
    $workflow = ConvertFrom-Yaml $workflowContent
    
    # Extract workflow metadata
    $workflowName = if ($workflow.name) { $workflow.name } else { [System.IO.Path]::GetFileNameWithoutExtension($WorkflowPath) }
    
    Write-Verbose "Converting workflow: $workflowName"
    
    # Build the playbook structure
    $playbook = @{
        metadata = @{
            name = ConvertTo-KebabCase $workflowName
            description = "Converted from GitHub Actions workflow: $workflowName"
            version = "1.0.0"
            category = "operations"
            tags = @("github-actions", "converted", "workflow")
            estimatedDuration = "Variable"
            githubWorkflow = [System.IO.Path]::GetFileName($WorkflowPath)
            convertedFrom = $WorkflowPath
            convertedAt = (Get-Date -Format 'o')
        }
        requirements = @{
            minimumPowerShellVersion = "7.0"
            requiredModules = @()
            requiredTools = @()
            platforms = @()
        }
        orchestration = @{
            defaultVariables = @{}
            env = @{}
            jobs = @{}
        }
    }
    
    # Parse global environment variables
    if ($workflow.env) {
        foreach ($key in $workflow.env.Keys) {
            $value = $workflow.env[$key]
            $playbook.orchestration.env[$key] = Expand-GitHubContextVariables -Value $value -Substitutions $VariableSubstitutions
        }
    }
    
    # Parse concurrency settings
    if ($workflow.concurrency) {
        $playbook.orchestration.concurrency = @{
            group = $workflow.concurrency.group
            cancelInProgress = if ($workflow.concurrency.'cancel-in-progress') { $true } else { $false }
        }
    }
    
    # Parse jobs
    if ($workflow.jobs) {
        foreach ($jobId in $workflow.jobs.Keys) {
            $job = $workflow.jobs[$jobId]
            
            Write-Verbose "Processing job: $jobId"
            
            $convertedJob = ConvertFrom-GitHubJob -JobId $jobId -Job $job -VariableSubstitutions $VariableSubstitutions
            $playbook.orchestration.jobs[$jobId] = $convertedJob
            
            # Collect requirements
            if ($job.'runs-on') {
                $platform = Convert-RunsOnToPlatform $job.'runs-on'
                if ($platform -and $platform -notin $playbook.requirements.platforms) {
                    $playbook.requirements.platforms += $platform
                }
            }
        }
    }
    
    # Save or return the playbook
    if ($OutputPath) {
        $playbookDir = Split-Path $OutputPath -Parent
        if ($playbookDir -and -not (Test-Path $playbookDir)) {
            New-Item -ItemType Directory -Path $playbookDir -Force | Out-Null
        }
        
        $playbook | ConvertTo-Json -Depth 20 | Set-Content -Path $OutputPath
        Write-Verbose "Playbook saved to: $OutputPath"
        return $OutputPath
    } else {
        return $playbook
    }
}

function ConvertFrom-GitHubJob {
    <#
    .SYNOPSIS
    Convert a GitHub Actions job to an orchestration job
    #>
    param(
        [string]$JobId,
        [hashtable]$Job,
        [hashtable]$VariableSubstitutions
    )
    
    $convertedJob = @{
        name = if ($Job.name) { $Job.name } else { $JobId }
        steps = @()
    }
    
    # Handle job description
    if ($Job.description) {
        $convertedJob.description = $Job.description
    }
    
    # Handle job dependencies
    if ($Job.needs) {
        $convertedJob.needs = if ($Job.needs -is [array]) { $Job.needs } else { @($Job.needs) }
    }
    
    # Handle conditional execution
    if ($Job.if) {
        $convertedJob.if = Convert-GitHubConditional $Job.if
    }
    
    # Handle job environment variables
    if ($Job.env) {
        $convertedJob.env = @{}
        foreach ($key in $Job.env.Keys) {
            $value = $Job.env[$key]
            $convertedJob.env[$key] = Expand-GitHubContextVariables -Value $value -Substitutions $VariableSubstitutions
        }
    }
    
    # Handle job outputs
    if ($Job.outputs) {
        $convertedJob.outputs = @{}
        foreach ($key in $Job.outputs.Keys) {
            $convertedJob.outputs[$key] = $Job.outputs[$key]
        }
    }
    
    # Handle matrix strategy
    if ($Job.strategy -and $Job.strategy.matrix) {
        $convertedJob.strategy = @{
            matrix = @{}
            failFast = if ($null -ne $Job.strategy.'fail-fast') { $Job.strategy.'fail-fast' } else { $true }
        }
        
        foreach ($dimension in $Job.strategy.matrix.Keys) {
            if ($dimension -ne 'include' -and $dimension -ne 'exclude') {
                $convertedJob.strategy.matrix[$dimension] = $Job.strategy.matrix[$dimension]
            }
        }
        
        if ($Job.strategy.'max-parallel') {
            $convertedJob.strategy.maxParallel = $Job.strategy.'max-parallel'
        }
    }
    
    # Handle timeout
    if ($Job.'timeout-minutes') {
        $convertedJob.timeout = $Job.'timeout-minutes' * 60  # Convert to seconds
    }
    
    # Handle continue-on-error
    if ($Job.'continue-on-error') {
        $convertedJob.continueOnError = $Job.'continue-on-error'
    }
    
    # Convert steps
    if ($Job.steps) {
        foreach ($step in $Job.steps) {
            $convertedStep = ConvertFrom-GitHubStep -Step $step -VariableSubstitutions $VariableSubstitutions
            if ($convertedStep) {
                $convertedJob.steps += $convertedStep
            }
        }
    }
    
    return $convertedJob
}

function ConvertFrom-GitHubStep {
    <#
    .SYNOPSIS
    Convert a GitHub Actions step to an orchestration step
    #>
    param(
        [hashtable]$Step,
        [hashtable]$VariableSubstitutions
    )
    
    $convertedStep = @{
        name = $Step.name
    }
    
    # Handle step ID
    if ($Step.id) {
        $convertedStep.id = $Step.id
    }
    
    # Handle conditional execution
    if ($Step.if) {
        $convertedStep.if = Convert-GitHubConditional $Step.if
    }
    
    # Handle environment variables
    if ($Step.env) {
        $convertedStep.env = @{}
        foreach ($key in $Step.env.Keys) {
            $convertedStep.env[$key] = Expand-GitHubContextVariables -Value $Step.env[$key] -Substitutions $VariableSubstitutions
        }
    }
    
    # Handle continue-on-error
    if ($Step.'continue-on-error') {
        $convertedStep.continueOnError = $Step.'continue-on-error'
    }
    
    # Handle timeout
    if ($Step.'timeout-minutes') {
        $convertedStep.timeout = $Step.'timeout-minutes' * 60
    }
    
    # Determine the action type
    if ($Step.uses) {
        # Action usage - map to equivalent local operation
        $convertedStep.uses = $Step.uses
        $convertedStep.with = if ($Step.with) { $Step.with } else { @{} }
        
        # Map common actions to AitherZero scripts
        $action = $Step.uses -split '@' | Select-Object -First 1
        switch -Wildcard ($action) {
            'actions/checkout*' {
                # Checkout is implicit in local execution
                $convertedStep.script = 'Write-Host "Repository already available locally"'
            }
            'actions/cache*' {
                # Map to UseCache parameter
                $convertedStep.script = 'Write-Host "Caching handled by orchestration engine -UseCache parameter"'
            }
            'actions/setup-node*' {
                $version = if ($Step.with -and $Step.with.'node-version') { $Step.with.'node-version' } else { 'latest' }
                $convertedStep.run = "0201"  # Install-Node script
                $convertedStep.with = @{ version = $version }
            }
            'actions/setup-python*' {
                $version = if ($Step.with -and $Step.with.'python-version') { $Step.with.'python-version' } else { 'latest' }
                $convertedStep.run = "0206"  # Install-Python script
                $convertedStep.with = @{ version = $version }
            }
            default {
                # Unknown action - add as comment
                $convertedStep.script = "# Action not implemented: $($Step.uses)"
            }
        }
    }
    elseif ($Step.run) {
        # Shell command - convert to PowerShell if possible
        $command = $Step.run
        $shell = if ($Step.shell) { $Step.shell } else { 'bash' }
        
        # Expand GitHub context variables in the command
        $command = Expand-GitHubContextVariables -Value $command -Substitutions $VariableSubstitutions
        
        if ($shell -eq 'pwsh' -or $shell -eq 'powershell') {
            $convertedStep.script = $command
        } else {
            # For bash/sh commands, wrap in bash execution
            $convertedStep.script = @"
# Original shell: $shell
bash -c @'
$command
'@
"@
        }
    }
    
    return $convertedStep
}

function Expand-GitHubContextVariables {
    <#
    .SYNOPSIS
    Expand GitHub context variables like ${{ github.* }} to local equivalents
    #>
    param(
        [string]$Value,
        [hashtable]$Substitutions
    )
    
    if (-not $Value) { return $Value }
    
    # Common GitHub context mappings
    $defaultMappings = @{
        'github.workspace' = '$PWD'
        'github.repository' = Split-Path -Leaf (Split-Path (Get-Location) -Parent)
        'github.ref' = (git rev-parse --abbrev-ref HEAD 2>$null)
        'github.sha' = (git rev-parse HEAD 2>$null)
        'github.run_number' = '1'
        'github.run_id' = (Get-Random -Minimum 1000 -Maximum 9999)
        'runner.os' = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
        'runner.temp' = $env:TEMP ?? '/tmp'
    }
    
    # Merge with user substitutions
    $allMappings = $defaultMappings + $Substitutions
    
    # Replace ${{ }} patterns
    $pattern = '\$\{\{\s*([^}]+)\s*\}\}'
    $result = [regex]::Replace($Value, $pattern, {
        param($match)
        $expression = $match.Groups[1].Value.Trim()
        
        # Check if we have a mapping
        if ($allMappings.ContainsKey($expression)) {
            return $allMappings[$expression]
        }
        
        # Check for env variables
        if ($expression -match '^env\.(.+)$') {
            $envVar = $Matches[1]
            return "`$env:$envVar"
        }
        
        # Check for secrets
        if ($expression -match '^secrets\.(.+)$') {
            $secret = $Matches[1]
            return "`$env:$secret  # GitHub secret - set in environment"
        }
        
        # Return unchanged if no mapping found
        return $match.Value
    })
    
    return $result
}

function Convert-GitHubConditional {
    <#
    .SYNOPSIS
    Convert GitHub Actions conditional expressions to PowerShell
    #>
    param([string]$Condition)
    
    # Simple mappings
    $condition = $Condition -replace "github\.event_name == 'push'", "`$true  # Local execution"
    $condition = $condition -replace "success\(\)", "`$true"
    $condition = $condition -replace "failure\(\)", "`$false"
    $condition = $condition -replace "always\(\)", "`$true"
    
    # Remove ${{ }} wrapper if present
    $condition = $condition -replace '^\$\{\{\s*', '' -replace '\s*\}\}$', ''
    
    return $condition
}

function Convert-RunsOnToPlatform {
    <#
    .SYNOPSIS
    Convert GitHub Actions runs-on to platform name
    #>
    param([string]$RunsOn)
    
    switch -Wildcard ($RunsOn) {
        'ubuntu-*' { return 'Linux' }
        'windows-*' { return 'Windows' }
        'macos-*' { return 'macOS' }
        default { return 'CrossPlatform' }
    }
}

function ConvertTo-KebabCase {
    <#
    .SYNOPSIS
    Convert string to kebab-case
    #>
    param([string]$Value)
    
    $Value = $Value -replace '\s+', '-'
    $Value = $Value -replace '[^a-zA-Z0-9-]', ''
    $Value = $Value.ToLower()
    
    return $Value
}

function Invoke-GitHubWorkflow {
    <#
    .SYNOPSIS
    Parse and execute a GitHub Actions workflow file locally
    
    .DESCRIPTION
    Converts a GitHub Actions YAML workflow to an orchestration playbook
    and executes it using the orchestration engine.
    
    .PARAMETER WorkflowPath
    Path to the GitHub Actions workflow YAML file
    
    .PARAMETER JobId
    Optional specific job to run. If not specified, runs all jobs.
    
    .PARAMETER Matrix
    Optional matrix parameters to override workflow matrix
    
    .PARAMETER UseCache
    Enable caching for workflow execution
    
    .PARAMETER GenerateSummary
    Generate execution summary report
    
    .PARAMETER DryRun
    Show what would be executed without running
    
    .PARAMETER VariableSubstitutions
    Hashtable of variable substitutions for GitHub context variables
    
    .EXAMPLE
    Invoke-GitHubWorkflow -WorkflowPath ".github/workflows/test.yml"
    
    .EXAMPLE
    Invoke-GitHubWorkflow -WorkflowPath ".github/workflows/test.yml" -JobId "test" -UseCache -GenerateSummary
    
    .EXAMPLE
    Invoke-GitHubWorkflow -WorkflowPath ".github/workflows/test.yml" -DryRun
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$WorkflowPath,
        
        [Parameter()]
        [string]$JobId,
        
        [Parameter()]
        [hashtable]$Matrix,
        
        [Parameter()]
        [switch]$UseCache,
        
        [Parameter()]
        [switch]$GenerateSummary,
        
        [Parameter()]
        [switch]$DryRun,
        
        [Parameter()]
        [hashtable]$VariableSubstitutions = @{}
    )
    
    Write-Host "Converting GitHub Actions workflow to orchestration playbook..." -ForegroundColor Cyan
    
    # Convert the workflow
    $playbook = ConvertFrom-GitHubWorkflow -WorkflowPath $WorkflowPath -VariableSubstitutions $VariableSubstitutions
    
    Write-Host "Workflow: $($playbook.metadata.name)" -ForegroundColor Green
    Write-Host "Jobs: $($playbook.orchestration.jobs.Count)" -ForegroundColor Green
    
    if ($DryRun) {
        Write-Host "`nPlaybook structure:" -ForegroundColor Yellow
        $playbook | ConvertTo-Json -Depth 10 | Write-Host
        return
    }
    
    # TODO: Execute the playbook using orchestration engine
    # This requires implementing the v3 schema playbook execution
    Write-Host "`nNote: Full execution of v3 schema playbooks is in development." -ForegroundColor Yellow
    Write-Host "The playbook has been converted successfully and can be saved for manual execution." -ForegroundColor Yellow
    
    # Save the converted playbook
    $playbookPath = "orchestration/playbooks/converted/$(Split-Path $WorkflowPath -Leaf).json"
    $playbookDir = Split-Path $playbookPath -Parent
    if (-not (Test-Path $playbookDir)) {
        New-Item -ItemType Directory -Path $playbookDir -Force | Out-Null
    }
    
    $playbook | ConvertTo-Json -Depth 20 | Set-Content -Path $playbookPath
    Write-Host "Converted playbook saved to: $playbookPath" -ForegroundColor Green
    
    return $playbook
}

# Export functions
Export-ModuleMember -Function @(
    'ConvertFrom-GitHubWorkflow'
    'Invoke-GitHubWorkflow'
)
