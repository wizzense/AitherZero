#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Simple testing orchestrator that eliminates configuration complexity
.DESCRIPTION
    Ultra-simplified orchestrator that:
    - Uses AitherZero's orchestration engine without configuration overhead
    - Provides simple, predictable test execution
    - Automatically selects the best testing strategy
    - Easy for AI agents to understand and extend
    - Zero configuration reloading during execution
    
.PARAMETER Profile
    Testing profile: lightning (fastest), development (balanced), validation (thorough)
.PARAMETER TestType
    Override test type selection: unit, integration, all, smart, changed  
.PARAMETER MaxTime
    Maximum time to spend on testing (auto-adjusts strategy)
    
.NOTES
    Stage: Testing
    Order: 0470
    Dependencies: 0480, 0490 (simple test runners)
    Tags: orchestration, simple, fast, ai-friendly
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('lightning', 'development', 'validation', 'ai')]
    [string]$Profile = 'development',
    
    [ValidateSet('unit', 'integration', 'all', 'smart', 'changed')]
    [string]$TestType,
    
    [int]$MaxTime = 300,  # 5 minutes
    [switch]$AI,
    [switch]$Learn,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Performance settings
$ProgressPreference = 'SilentlyContinue'

$projectRoot = Split-Path $PSScriptRoot -Parent
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

# Simple logging (no dependencies)
function Write-SimpleLog {
    param([string]$Message, [string]$Level = 'INFO')
    if ($Quiet) { return }
    
    $time = (Get-Date).ToString("HH:mm:ss")
    $emoji = @{ 'INFO' = '🎯'; 'SUCCESS' = '✅'; 'ERROR' = '❌'; 'WARNING' = '⚠️' }[$Level]
    Write-Host "[$time] $emoji $Message" -ForegroundColor $(
        @{ 'INFO' = 'Cyan'; 'SUCCESS' = 'Green'; 'ERROR' = 'Red'; 'WARNING' = 'Yellow' }[$Level]
    )
}

Write-SimpleLog "🎯 Simple Test Orchestrator starting (Profile: $Profile)"

# Profile definitions (static - no dynamic loading)
$profiles = @{
    'lightning' = @{
        Description = 'Ultra-fast testing for immediate feedback'
        TestType = 'unit'
        Runner = '0480_Test-Simple.ps1'
        Parameters = @{
            Mode = 'unit'
            Workers = 2
            BatchSize = 5
            Quiet = $true
        }
        MaxTime = 60
    }
    
    'development' = @{
        Description = 'Balanced testing for development workflow' 
        TestType = 'fast'
        Runner = '0480_Test-Simple.ps1'
        Parameters = @{
            Mode = 'fast'
            Workers = 4
            BatchSize = 3
            Quiet = $false
        }
        MaxTime = 180
    }
    
    'validation' = @{
        Description = 'Comprehensive testing for validation'
        TestType = 'all'
        Runner = '0480_Test-Simple.ps1'
        Parameters = @{
            Mode = 'all'
            Workers = 6
            BatchSize = 2
            Quiet = $false
        }
        MaxTime = 600
    }
    
    'ai' = @{
        Description = 'AI-powered adaptive testing with learning'
        TestType = 'smart'
        Runner = '0490_AI-TestRunner.ps1'
        Parameters = @{
            TestType = 'smart'
            Mode = 'adaptive'
            Learn = $Learn
            Predict = $true
            Quiet = $Quiet
        }
        MaxTime = 300
    }
}

# Get profile configuration
$profileConfig = $profiles[$Profile]
if (-not $profileConfig) {
    Write-SimpleLog "Unknown profile: $Profile" "ERROR"
    exit 2
}

# Override test type if specified
if ($TestType) {
    $profileConfig.TestType = $TestType
    if ($profileConfig.Parameters.ContainsKey('TestType')) {
        $profileConfig.Parameters.TestType = $TestType
    }
    if ($profileConfig.Parameters.ContainsKey('Mode')) {
        $profileConfig.Parameters.Mode = $TestType
    }
}

# Override max time if specified
if ($PSBoundParameters.ContainsKey('MaxTime')) {
    $profileConfig.MaxTime = $MaxTime
    $profileConfig.Parameters.MaxDuration = $MaxTime
}

Write-SimpleLog "📋 $($profileConfig.Description)"
Write-SimpleLog "🏃 Runner: $($profileConfig.Runner)"
Write-SimpleLog "⏰ Max Time: $($profileConfig.MaxTime)s"

# Build execution command
$runnerPath = Join-Path $PSScriptRoot $profileConfig.Runner
if (-not (Test-Path $runnerPath)) {
    Write-SimpleLog "Test runner not found: $runnerPath" "ERROR"
    exit 2
}

# Convert parameters to argument string
$arguments = @()
foreach ($param in $profileConfig.Parameters.GetEnumerator()) {
    if ($param.Value -is [bool]) {
        if ($param.Value) {
            $arguments += "-$($param.Key)"
        }
    } else {
        $arguments += "-$($param.Key)"
        $arguments += $param.Value
    }
}

$argumentString = $arguments -join ' '

Write-SimpleLog "🚀 Executing: $($profileConfig.Runner) $argumentString"

if ($PSCmdlet.ShouldProcess("Test execution via $($profileConfig.Runner)", "Run tests")) {
    
    $startTime = Get-Date
    
    try {
        # Execute the test runner with timeout
        $job = Start-Job -ScriptBlock {
            param($RunnerPath, $Arguments)
            & $RunnerPath @Arguments
        } -ArgumentList $runnerPath, $profileConfig.Parameters
        
        # Wait with timeout
        $completed = Wait-Job $job -Timeout $profileConfig.MaxTime
        
        if (-not $completed) {
            Write-SimpleLog "⏰ Test execution timed out after $($profileConfig.MaxTime)s" "WARNING"
            Stop-Job $job
            Remove-Job $job
            exit 3
        }
        
        # Get results
        $result = Receive-Job $job
        $exitCode = $job.State -eq 'Completed' ? 0 : 1
        Remove-Job $job
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        # Create simple execution summary
        $summary = @{
            Profile = $Profile
            TestType = $profileConfig.TestType
            Runner = $profileConfig.Runner
            Duration = [Math]::Round($duration, 2)
            Success = ($exitCode -eq 0)
            Timestamp = Get-Date
            Parameters = $profileConfig.Parameters
        }
        
        # Save summary
        $summaryFile = Join-Path $projectRoot "tests/results/orchestration-summary-$timestamp.json"
        $resultsDir = [System.IO.Path]::GetDirectoryName($summaryFile)
        if (-not (Test-Path $resultsDir)) {
            New-Item -Path $resultsDir -ItemType Directory -Force | Out-Null
        }
        $summary | ConvertTo-Json -Depth 10 | Set-Content $summaryFile
        
        # Display orchestration summary
        if ($summary.Success) {
            Write-SimpleLog "🎉 Test orchestration completed successfully!" "SUCCESS"
        } else {
            Write-SimpleLog "❌ Test orchestration completed with failures" "ERROR"
        }
        
        Write-Host @"

🎯 Simple Test Orchestration Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Profile:        $Profile
Test Type:      $($summary.TestType)
Runner:         $($summary.Runner)
Duration:       $($summary.Duration)s
Success:        $($summary.Success)

📁 Summary:     $summaryFile

"@

        Write-SimpleLog "📊 Orchestration summary saved to: $summaryFile"
        
        exit $exitCode
        
    } catch {
        Write-SimpleLog "Test orchestration failed: $_" "ERROR"
        exit 2
    }
    
} else {
    Write-SimpleLog "👀 DryRun: Would execute $($profileConfig.Runner) with profile '$Profile'"
    Write-SimpleLog "   Parameters: $argumentString"
    exit 0
}