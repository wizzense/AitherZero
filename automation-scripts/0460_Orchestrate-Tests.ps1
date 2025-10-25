#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Orchestrated test execution using AitherZero's own automation capabilities
.DESCRIPTION
    Leverages AitherZero's orchestration engine to run tests in the most efficient way:
    - Uses number-based sequencing for parallel execution
    - Leverages playbook system for complex test scenarios  
    - Provides intelligent test selection and batching
    - Integrates with CI/CD pipelines seamlessly
    
    Exit Codes:
    0   - All tests passed
    1   - One or more tests failed
    2   - Test execution error
    
.NOTES
    Stage: Testing
    Order: 0460
    Dependencies: 0400
    Tags: testing, orchestration, parallel, intelligent, aitherzeero-native
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('lightning', 'quick', 'full', 'ci', 'smart')]
    [string]$Profile = 'smart',
    
    [string]$TestPath = "./tests",
    [string]$OutputPath = "./tests/results/orchestrated",
    
    [switch]$DryRun,
    [switch]$ShowProgress,
    [switch]$CI
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata for orchestration
$scriptMetadata = @{
    Stage = 'Testing'
    Order = 0460
    Dependencies = @('0400')
    Tags = @('testing', 'orchestration', 'parallel', 'intelligent')
    RequiresAdmin = $false
    SupportsWhatIf = $true
}

# Initialize
$projectRoot = Split-Path $PSScriptRoot -Parent
$startTime = Get-Date

# Logging helper
function Write-OrchLog {
    param([string]$Message, [string]$Level = 'Info')
    $time = (Get-Date).ToString("HH:mm:ss.fff")
    $icon = switch ($Level) {
        'Error' { '🔴' }
        'Warning' { '🟡' }
        'Success' { '🟢' }
        'Info' { '🔵' }
        'Orchestration' { '🎼' }
        default { '⚪' }
    }
    Write-Host "[$time] $icon $Message" -ForegroundColor $(
        switch ($Level) {
            'Error' { 'Red' }
            'Warning' { 'Yellow' }
            'Success' { 'Green' }
            'Info' { 'Cyan' }
            'Orchestration' { 'Magenta' }
            default { 'White' }
        }
    )
}

Write-OrchLog "🎼 Starting AitherZero Orchestrated Testing" "Orchestration"
Write-OrchLog "Profile: $Profile | CI Mode: $CI | Dry Run: $DryRun"

# Test profile configurations
$testProfiles = @{
    'lightning' = @{
        Description = "Ultra-fast development testing (30s-2min)"
        Playbook = "test-lightning"
        MaxDuration = 120
        Parallel = $true
        FastFail = $true
        Coverage = $false
        Tests = @('Unit:Smart', 'Syntax:Changed')
    }
    'quick' = @{
        Description = "Fast validation testing (2-5min)" 
        Playbook = "test-quick"
        MaxDuration = 300
        Parallel = $true
        FastFail = $false
        Coverage = $false
        Tests = @('Unit', 'Syntax', 'StaticAnalysis:Fast')
    }
    'full' = @{
        Description = "Comprehensive testing (10-20min)"
        Playbook = "test-full"
        MaxDuration = 1200
        Parallel = $true
        FastFail = $false
        Coverage = $true
        Tests = @('Unit', 'Integration', 'StaticAnalysis', 'Coverage')
    }
    'ci' = @{
        Description = "CI/CD optimized testing (5-15min)"
        Playbook = "test-ci"
        MaxDuration = 900
        Parallel = $true
        FastFail = $true
        Coverage = $true
        Tests = @('Unit', 'Integration:Fast', 'StaticAnalysis', 'Coverage')
    }
    'smart' = @{
        Description = "Intelligent test selection based on changes"
        Playbook = $null  # Dynamic selection
        MaxDuration = 300
        Parallel = $true
        FastFail = $false
        Coverage = $false
        Tests = @()  # Determined dynamically
    }
}

# Get the selected profile
$selectedProfile = $testProfiles[$Profile]
if (-not $selectedProfile) {
    throw "Invalid profile: $Profile. Available: $($testProfiles.Keys -join ', ')"
}

Write-OrchLog "📋 Profile: $($selectedProfile.Description)" "Info"

# Smart profile logic - determine tests based on changes
if ($Profile -eq 'smart') {
    Write-OrchLog "🧠 Analyzing changes for smart test selection..." "Info"
    
    # Check for git changes (simplified logic)
    $hasChanges = $false
    try {
        $gitStatus = git status --porcelain 2>$null
        $hasChanges = $gitStatus -and $gitStatus.Length -gt 0
        
        if ($hasChanges) {
            # Has uncommitted changes - run lightning tests
            $selectedProfile.Playbook = "test-lightning"
            $selectedProfile.Tests = @('Unit:Smart', 'Syntax:Changed')
            Write-OrchLog "📝 Uncommitted changes detected - using lightning profile" "Info"
        } else {
            # No changes - run quick validation
            $selectedProfile.Playbook = "test-quick" 
            $selectedProfile.Tests = @('Unit', 'Syntax')
            Write-OrchLog "✅ No changes detected - using quick validation" "Info"
        }
    } catch {
        # Fallback to quick tests if git not available
        $selectedProfile.Playbook = "test-quick"
        $selectedProfile.Tests = @('Unit', 'Syntax')
        Write-OrchLog "⚠️  Cannot detect changes - using quick profile fallback" "Warning"
    }
}

# Prepare orchestration
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

# Performance environment setup
$env:AITHERZERO_TEST_MODE = 'orchestrated'
$env:AITHERZERO_NO_CONFIG_WATCH = 'true'
$env:AITHERZERO_MINIMAL_LOGGING = if ($Profile -eq 'lightning') { 'true' } else { 'false' }
$env:AITHERZERO_FAST_STARTUP = if ($Profile -in @('lightning', 'smart')) { 'true' } else { 'false' }

# Main orchestration execution
if ($PSCmdlet.ShouldProcess("Test orchestration ($Profile profile)", "Execute tests")) {
    
    Write-OrchLog "🚀 Executing orchestrated testing..." "Orchestration"
    
    if ($selectedProfile.Playbook) {
        # Use playbook-based orchestration
        Write-OrchLog "📖 Using playbook: $($selectedProfile.Playbook)" "Info"
        
        $playbookPath = Join-Path $projectRoot "orchestration/playbooks/testing/$($selectedProfile.Playbook).json"
        
        if (-not (Test-Path $playbookPath)) {
            Write-OrchLog "❌ Playbook not found: $playbookPath" "Error"
            exit 2
        }
        
        # Execute using Start-AitherZero orchestration
        try {
            $orchestrationArgs = @(
                '-Mode', 'Orchestrate'
                '-Playbook', $selectedProfile.Playbook
                '-NonInteractive'
            )
            
            if ($ShowProgress) { $orchestrationArgs += '-Verbose' }
            if ($DryRun) { $orchestrationArgs += '-WhatIf' }
            
            Write-OrchLog "🎼 Launching orchestration: ./Start-AitherZero.ps1 $($orchestrationArgs -join ' ')" "Orchestration"
            
            $result = & (Join-Path $projectRoot "Start-AitherZero.ps1") @orchestrationArgs
            
            $exitCode = $LASTEXITCODE
            Write-OrchLog "🎯 Orchestration completed with exit code: $exitCode" $(if ($exitCode -eq 0) { "Success" } else { "Error" })
            
        } catch {
            Write-OrchLog "💥 Orchestration failed: $($_.Exception.Message)" "Error"
            exit 2
        }
        
    } else {
        # Direct script-based orchestration for custom scenarios
        Write-OrchLog "🔧 Using direct script orchestration" "Info"
        
        $testSequences = @()
        
        # Build test sequence based on profile tests
        foreach ($testType in $selectedProfile.Tests) {
            $sequence = switch ($testType) {
                'Unit' { '0402' }
                'Unit:Smart' { '0450' }
                'Integration' { '0403' }
                'Integration:Fast' { '0403' }  # Could add fast parameter
                'Syntax' { '0407' }
                'Syntax:Changed' { '0407' }  # Could add changed files filter  
                'StaticAnalysis' { '0404' }
                'StaticAnalysis:Fast' { '0404' }
                'Coverage' { '0406' }
                default { $null }
            }
            
            if ($sequence) {
                $testSequences += $sequence
            }
        }
        
        if ($testSequences.Count -eq 0) {
            Write-OrchLog "⚠️  No test sequences defined for profile" "Warning"
            exit 0
        }
        
        Write-OrchLog "📋 Executing sequences: $($testSequences -join ', ')" "Info"
        
        # Use AitherZero's orchestration capabilities
        try {
            Import-Module (Join-Path $projectRoot "domains/automation/Orchestration.psm1") -Force
            
            $orchestrationResult = Invoke-OrchestrationSequence -Sequence ($testSequences -join ',') -Parallel:$selectedProfile.Parallel -ContinueOnError:(-not $selectedProfile.FastFail) -DryRun:$DryRun
            
            $success = $orchestrationResult -and $orchestrationResult.Success
            $exitCode = if ($success) { 0 } else { 1 }
            
        } catch {
            Write-OrchLog "💥 Direct orchestration failed: $($_.Exception.Message)" "Error"
            exit 2
        }
    }
    
    # Collect and display results
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    Write-Host "`n" -NoNewline
    Write-OrchLog "📊 Test Orchestration Results" "Orchestration"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "🔄 Profile:      $Profile ($($selectedProfile.Description))" -ForegroundColor White
    Write-Host "⏱️  Duration:     $([math]::Round($duration, 1))s (limit: $($selectedProfile.MaxDuration)s)" -ForegroundColor $(if ($duration -lt $selectedProfile.MaxDuration) { "Green" } else { "Yellow" })
    Write-Host "📁 Results:      $OutputPath" -ForegroundColor White
    Write-Host "🎯 Status:       $(if ($exitCode -eq 0) { "✅ SUCCESS" } else { "❌ FAILED" })" -ForegroundColor $(if ($exitCode -eq 0) { "Green" } else { "Red" })
    
    # Performance feedback
    if ($duration -gt $selectedProfile.MaxDuration) {
        Write-OrchLog "⚠️  Tests exceeded expected duration. Consider using a faster profile." "Warning"
    }
    
    if ($Profile -eq 'smart' -and $duration -lt 30) {
        Write-OrchLog "🚀 Tests completed very quickly! Consider contributing to AitherZero's test optimization." "Success"
    }
    
    exit $exitCode
    
} else {
    Write-OrchLog "👀 DryRun: Would execute $Profile profile testing" "Info"
    Write-OrchLog "   Playbook: $($selectedProfile.Playbook)" "Info"
    Write-OrchLog "   Tests: $($selectedProfile.Tests -join ', ')" "Info"
    Write-OrchLog "   Max Duration: $($selectedProfile.MaxDuration)s" "Info"
    Write-OrchLog "   Parallel: $($selectedProfile.Parallel)" "Info"
    exit 0
}
