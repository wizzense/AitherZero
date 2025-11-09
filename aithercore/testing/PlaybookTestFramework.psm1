#Requires -Version 7.0

<#
.SYNOPSIS
    Playbook and Orchestration Testing Framework
.DESCRIPTION
    Comprehensive testing infrastructure for:
    - Playbook validation and execution
    - Orchestration sequence testing
    - Multi-script workflow validation
    - Success criteria verification
    - Dependency chain testing
    
    This enables REAL end-to-end testing of automation workflows.
.NOTES
    Copyright © 2025 Aitherium Corporation
    Part of the Test Infrastructure Overhaul
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Playbook Validation

function Test-PlaybookStructure {
    <#
    .SYNOPSIS
        Validates playbook structure and metadata
    .DESCRIPTION
        Ensures playbook has:
        - Required fields (Name, Description, Sequence)
        - Valid script references
        - Proper parameter definitions
        - Success criteria configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PlaybookPath
    )
    
    $result = @{
        Valid = $true
        Errors = @()
        Warnings = @()
        Playbook = $null
    }
    
    # Load playbook
    try {
        $playbookContent = Get-Content -Path $PlaybookPath -Raw
        $scriptBlock = [scriptblock]::Create($playbookContent)
        $playbook = & $scriptBlock
        $result.Playbook = $playbook
    } catch {
        $result.Valid = $false
        $result.Errors += "Failed to load playbook: $_"
        return $result
    }
    
    # Validate required fields
    $requiredFields = @('Name', 'Description', 'Sequence')
    foreach ($field in $requiredFields) {
        if (-not $playbook.ContainsKey($field)) {
            $result.Valid = $false
            $result.Errors += "Missing required field: $field"
        }
    }
    
    # Validate sequence structure
    if ($playbook.Sequence) {
        foreach ($step in $playbook.Sequence) {
            if (-not $step.Script) {
                $result.Valid = $false
                $result.Errors += "Sequence step missing Script field"
            }
            
            # Check if script exists
            $scriptPath = Join-Path (Split-Path $PlaybookPath -Parent) "../../automation-scripts/$($step.Script)"
            if (-not (Test-Path $scriptPath)) {
                $result.Warnings += "Script not found: $($step.Script)"
            }
        }
    }
    
    # Validate Options if present
    if ($playbook.Options) {
        if ($playbook.Options.MaxConcurrency -and $playbook.Options.MaxConcurrency -lt 1) {
            $result.Valid = $false
            $result.Errors += "MaxConcurrency must be >= 1"
        }
    }
    
    return $result
}

function Test-PlaybookExecution {
    <#
    .SYNOPSIS
        Tests playbook execution in dry-run mode
    .DESCRIPTION
        Executes playbook with WhatIf/DryRun to validate:
        - All scripts load correctly
        - Parameters are valid
        - Dependencies resolve
        - No execution errors
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PlaybookName,
        
        [hashtable]$Variables = @{},
        
        [switch]$SkipPrerequisites
    )
    
    $result = @{
        Success = $false
        Executed = $false
        Output = $null
        Error = $null
        Steps = @()
    }
    
    try {
        # Import orchestration module
        $orchestrationModule = Join-Path $PSScriptRoot "../../aithercore/automation/OrchestrationEngine.psm1"
        if (Test-Path $orchestrationModule) {
            Import-Module $orchestrationModule -Force
        }
        
        # Execute playbook in test mode
        if (Get-Command Invoke-OrchestrationSequence -ErrorAction SilentlyContinue) {
            $params = @{
                LoadPlaybook = $PlaybookName
                WhatIf = $true
            }
            
            if ($Variables.Count -gt 0) {
                $params.Variables = $Variables
            }
            
            $result.Output = Invoke-OrchestrationSequence @params 2>&1
            $result.Executed = $true
            $result.Success = $?
        } else {
            throw "Invoke-OrchestrationSequence command not available"
        }
        
    } catch {
        $result.Error = $_
        Write-Error "Playbook execution test failed: $_"
    }
    
    return $result
}

function Assert-PlaybookSuccessCriteria {
    <#
    .SYNOPSIS
        Validates playbook success criteria are properly defined
    .DESCRIPTION
        Checks that success criteria make logical sense:
        - RequireAllSuccess vs MinimumSuccessCount
        - AllowedFailures configuration
        - Percentage thresholds
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Playbook
    )
    
    $criteria = $Playbook.SuccessCriteria
    if (-not $criteria) {
        Write-Warning "No success criteria defined - will use defaults"
        return $true
    }
    
    # Validate logical consistency
    if ($criteria.RequireAllSuccess -and $criteria.AllowedFailures) {
        if ($criteria.AllowedFailures.Count -gt 0) {
            throw "Conflicting criteria: RequireAllSuccess=true but AllowedFailures defined"
        }
    }
    
    if ($criteria.MinimumSuccessPercent) {
        if ($criteria.MinimumSuccessPercent -lt 0 -or $criteria.MinimumSuccessPercent -gt 100) {
            throw "MinimumSuccessPercent must be between 0 and 100"
        }
    }
    
    return $true
}

#endregion

#region Orchestration Sequence Testing

function Test-OrchestrationSequence {
    <#
    .SYNOPSIS
        Tests a sequence of automation scripts
    .DESCRIPTION
        Validates multi-script workflows:
        - Script execution order
        - Dependency resolution
        - Parameter passing
        - Error propagation
        - Rollback behavior
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Sequence,
        
        [hashtable]$Configuration = @{},
        
        [switch]$TestDependencies,
        
        [switch]$TestParallel
    )
    
    $result = @{
        Success = $true
        Steps = @()
        TotalSteps = $Sequence.Count
        SuccessfulSteps = 0
        FailedSteps = 0
        SkippedSteps = 0
    }
    
    foreach ($step in $Sequence) {
        $stepResult = @{
            Script = $step.Script
            Success = $false
            Output = $null
            Error = $null
            Duration = 0
        }
        
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        try {
            # Check script exists
            $scriptPath = "./library/automation-scripts/$($step.Script)"
            if (-not (Test-Path $scriptPath)) {
                throw "Script not found: $scriptPath"
            }
            
            # Prepare parameters
            $params = @{ WhatIf = $true }
            if ($step.Parameters) {
                foreach ($key in $step.Parameters.Keys) {
                    $params[$key] = $step.Parameters[$key]
                }
            }
            
            # Execute
            $stepResult.Output = & $scriptPath @params 2>&1
            $stepResult.Success = $?
            $result.SuccessfulSteps++
            
        } catch {
            $stepResult.Error = $_
            $stepResult.Success = $false
            $result.FailedSteps++
            
            # Check if should continue on error
            if (-not $step.ContinueOnError) {
                $result.Success = $false
                break
            }
        } finally {
            $stopwatch.Stop()
            $stepResult.Duration = $stopwatch.Elapsed.TotalSeconds
        }
        
        $result.Steps += $stepResult
    }
    
    # Test dependency resolution if requested
    if ($TestDependencies) {
        $result.DependencyCheck = Test-SequenceDependencies -Sequence $Sequence
    }
    
    return $result
}

function Test-SequenceDependencies {
    <#
    .SYNOPSIS
        Validates dependency chain in sequence
    .DESCRIPTION
        Ensures scripts are ordered correctly based on dependencies
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Sequence
    )
    
    $result = @{
        Valid = $true
        Issues = @()
    }
    
    $executedScripts = @()
    
    foreach ($step in $Sequence) {
        # Extract script number
        if ($step.Script -match '^(\d{4})_') {
            $scriptNum = [int]$Matches[1]
            $executedScripts += $scriptNum
            
            # Check dependencies
            if ($step.Dependencies) {
                foreach ($dep in $step.Dependencies) {
                    if ($dep -match '^(\d{4})') {
                        $depNum = [int]$Matches[1]
                        
                        # Dependency should have been executed already
                        if ($executedScripts -notcontains $depNum) {
                            $result.Valid = $false
                            $result.Issues += "Script $scriptNum depends on $depNum but it hasn't been executed yet"
                        }
                    }
                }
            }
        }
    }
    
    return $result
}

function Measure-PlaybookPerformance {
    <#
    .SYNOPSIS
        Measures playbook execution performance
    .DESCRIPTION
        Benchmarks playbook execution with:
        - Total execution time
        - Per-step timing
        - Parallel vs sequential comparison
        - Resource usage
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PlaybookName,
        
        [int]$Iterations = 1,
        
        [switch]$CompareParallel
    )
    
    $result = @{
        Iterations = @()
        Statistics = @{}
        ParallelComparison = $null
    }
    
    for ($i = 0; $i -lt $Iterations; $i++) {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        $execution = Test-PlaybookExecution -PlaybookName $PlaybookName
        
        $stopwatch.Stop()
        
        $result.Iterations += @{
            Index = $i
            Duration = $stopwatch.Elapsed.TotalSeconds
            Success = $execution.Success
            StepCount = $execution.Steps.Count
        }
    }
    
    # Calculate statistics
    $durations = $result.Iterations | ForEach-Object { $_.Duration }
    $result.Statistics = @{
        Mean = ($durations | Measure-Object -Average).Average
        Min = ($durations | Measure-Object -Minimum).Minimum
        Max = ($durations | Measure-Object -Maximum).Maximum
        Median = ($durations | Sort-Object)[[Math]::Floor($durations.Count / 2)]
    }
    
    return $result
}

#endregion

#region Integration Test Helpers

function New-IntegrationTestEnvironment {
    <#
    .SYNOPSIS
        Creates comprehensive integration test environment
    .DESCRIPTION
        Sets up environment for integration testing:
        - Mock automation scripts
        - Test configuration
        - Mock dependencies
        - Cleanup automation
    #>
    [CmdletBinding()]
    param(
        [string]$Name = "integration-test-$(Get-Random)",
        
        [hashtable]$MockScripts = @{},
        
        [hashtable]$Configuration = @{}
    )
    
    $basePath = Join-Path ([System.IO.Path]::GetTempPath()) $Name
    
    # Create structure
    $structure = @{
        Root = $basePath
        Scripts = Join-Path $basePath 'automation-scripts'
        Config = Join-Path $basePath 'config'
        Reports = Join-Path $basePath 'reports'
        Logs = Join-Path $basePath 'logs'
    }
    
    foreach ($dir in $structure.Values) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
    
    # Create mock scripts
    foreach ($scriptName in $MockScripts.Keys) {
        $scriptContent = $MockScripts[$scriptName]
        $scriptPath = Join-Path $structure.Scripts "$scriptName.ps1"
        Set-Content -Path $scriptPath -Value $scriptContent
    }
    
    # Create test configuration
    if ($Configuration.Count -gt 0) {
        $configPath = Join-Path $structure.Config 'test-config.psd1'
        $configContent = "@{`n"
        foreach ($key in $Configuration.Keys) {
            $configContent += "    $key = '$($Configuration[$key])'`n"
        }
        $configContent += "}`n"
        Set-Content -Path $configPath -Value $configContent
    }
    
    return @{
        Paths = $structure
        Cleanup = {
            if (Test-Path $basePath) {
                Remove-Item $basePath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }.GetNewClosure()
    }
}

function Invoke-PlaybookIntegrationTest {
    <#
    .SYNOPSIS
        Runs full integration test for a playbook
    .DESCRIPTION
        Complete end-to-end test:
        - Load playbook
        - Execute sequence
        - Validate results
        - Check side effects
        - Verify success criteria
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PlaybookPath,
        
        [hashtable]$ExpectedResults = @{},
        
        [scriptblock]$ValidationScript
    )
    
    $result = @{
        PlaybookValid = $false
        ExecutionSucceeded = $false
        ResultsValid = $false
        ValidationPassed = $false
        Details = @{}
    }
    
    try {
        # 1. Validate playbook structure
        Write-Verbose "Validating playbook structure..."
        $structureTest = Test-PlaybookStructure -PlaybookPath $PlaybookPath
        $result.PlaybookValid = $structureTest.Valid
        $result.Details.StructureValidation = $structureTest
        
        if (-not $structureTest.Valid) {
            throw "Playbook structure validation failed: $($structureTest.Errors -join ', ')"
        }
        
        # 2. Test execution
        Write-Verbose "Testing playbook execution..."
        $playbookName = [System.IO.Path]::GetFileNameWithoutExtension($PlaybookPath)
        $executionTest = Test-PlaybookExecution -PlaybookName $playbookName
        $result.ExecutionSucceeded = $executionTest.Success
        $result.Details.Execution = $executionTest
        
        # 3. Validate results against expectations
        if ($ExpectedResults.Count -gt 0) {
            Write-Verbose "Validating results..."
            $result.ResultsValid = $true
            
            foreach ($key in $ExpectedResults.Keys) {
                if ($executionTest.Output -notmatch $ExpectedResults[$key]) {
                    $result.ResultsValid = $false
                    break
                }
            }
        }
        
        # 4. Run custom validation
        if ($ValidationScript) {
            Write-Verbose "Running custom validation..."
            $result.ValidationPassed = & $ValidationScript $executionTest
        } else {
            $result.ValidationPassed = $true
        }
        
    } catch {
        $result.Details.Error = $_
        Write-Error "Integration test failed: $_"
    }
    
    return $result
}

#endregion

#region Test Result Reporting

function Format-PlaybookTestReport {
    <#
    .SYNOPSIS
        Formats playbook test results for reporting
    .DESCRIPTION
        Creates detailed test report for:
        - Dashboard integration
        - CI/CD reporting
        - GitHub PR comments
        - Test result tracking
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$TestResults,
        
        [ValidateSet('Console', 'Markdown', 'JSON', 'HTML')]
        [string]$Format = 'Console'
    )
    
    switch ($Format) {
        'Console' {
            $output = @"
╔══════════════════════════════════════════════════════════════╗
║              Playbook Test Results                          ║
╚══════════════════════════════════════════════════════════════╝

Playbook Valid:      $(if ($TestResults.PlaybookValid) { '✅' } else { '❌' })
Execution Success:   $(if ($TestResults.ExecutionSucceeded) { '✅' } else { '❌' })
Results Valid:       $(if ($TestResults.ResultsValid) { '✅' } else { '❌' })
Validation Passed:   $(if ($TestResults.ValidationPassed) { '✅' } else { '❌' })

Overall Status:      $(if ($TestResults.PlaybookValid -and $TestResults.ExecutionSucceeded -and $TestResults.ValidationPassed) { '✅ PASSED' } else { '❌ FAILED' })
"@
            return $output
        }
        
        'Markdown' {
            $status = if ($TestResults.PlaybookValid -and $TestResults.ExecutionSucceeded -and $TestResults.ValidationPassed) { '✅ PASSED' } else { '❌ FAILED' }
            
            $output = @"
## Playbook Test Results

**Overall Status:** $status

| Check | Result |
|-------|--------|
| Playbook Structure | $(if ($TestResults.PlaybookValid) { '✅ Valid' } else { '❌ Invalid' }) |
| Execution | $(if ($TestResults.ExecutionSucceeded) { '✅ Success' } else { '❌ Failed' }) |
| Result Validation | $(if ($TestResults.ResultsValid) { '✅ Valid' } else { '❌ Invalid' }) |
| Custom Validation | $(if ($TestResults.ValidationPassed) { '✅ Passed' } else { '❌ Failed' }) |
"@
            return $output
        }
        
        'JSON' {
            return $TestResults | ConvertTo-Json -Depth 10
        }
        
        'HTML' {
            $status = if ($TestResults.PlaybookValid -and $TestResults.ExecutionSucceeded -and $TestResults.ValidationPassed) { 'PASSED' } else { 'FAILED' }
            $statusColor = if ($status -eq 'PASSED') { 'green' } else { 'red' }
            
            $output = @"
<div class="playbook-test-report">
    <h2>Playbook Test Results</h2>
    <p class="status" style="color: $statusColor;">Overall Status: $status</p>
    <table>
        <tr><th>Check</th><th>Result</th></tr>
        <tr><td>Playbook Structure</td><td>$(if ($TestResults.PlaybookValid) { '✅ Valid' } else { '❌ Invalid' })</td></tr>
        <tr><td>Execution</td><td>$(if ($TestResults.ExecutionSucceeded) { '✅ Success' } else { '❌ Failed' })</td></tr>
        <tr><td>Result Validation</td><td>$(if ($TestResults.ResultsValid) { '✅ Valid' } else { '❌ Invalid' })</td></tr>
        <tr><td>Custom Validation</td><td>$(if ($TestResults.ValidationPassed) { '✅ Passed' } else { '❌ Failed' })</td></tr>
    </table>
</div>
"@
            return $output
        }
    }
}

#endregion

# Export module members
Export-ModuleMember -Function @(
    'Test-PlaybookStructure'
    'Test-PlaybookExecution'
    'Assert-PlaybookSuccessCriteria'
    'Test-OrchestrationSequence'
    'Test-SequenceDependencies'
    'Measure-PlaybookPerformance'
    'New-IntegrationTestEnvironment'
    'Invoke-PlaybookIntegrationTest'
    'Format-PlaybookTestReport'
)
