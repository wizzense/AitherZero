#!/usr/bin/env pwsh
#requires -version 7

<#
.SYNOPSIS
    Enable and configure the comprehensive automated copilot system
.DESCRIPTION
    Initializes the automated copilot orchestrator and sets up continuous
    AI-powered workflows for code review, testing, security, and optimization
.PARAMETER Mode
    Operation mode: Enable, Disable, Configure, Status
.PARAMETER Workflows
    Specific workflows to enable (default: all)
.PARAMETER Trigger
    Test a specific trigger manually
.PARAMETER ConfigPath
    Path to copilot configuration file
.EXAMPLE
    ./0743_Enable-AutomatedCopilot.ps1 -Mode Enable
.EXAMPLE
    ./0743_Enable-AutomatedCopilot.ps1 -Mode Configure -Workflows @("code-review", "security-scan")
.EXAMPLE
    ./0743_Enable-AutomatedCopilot.ps1 -Trigger commit
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Enable', 'Disable', 'Configure', 'Status', 'Test')]
    [string]$Mode = 'Enable',
    
    [string[]]$Workflows = @("code-review", "auto-test", "security-scan", "documentation"),
    
    [ValidateSet('commit', 'pullrequest', 'schedule', 'security-alert', 'test-failure', 'manual')]
    [string]$Trigger,
    
    [string]$ConfigPath,
    
    [switch]$DryRun
)

# Script metadata
# Stage: AIAutomation
# Dependencies: 0730, 0731
# Description: Comprehensive automated copilot system enablement
# Tags: ai, automation, copilot, continuous-improvement

# Initialize
$ErrorActionPreference = 'Stop'
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent

# Import required modules
$requiredModules = @(
    "$script:ProjectRoot/domains/utilities/Logging.psm1"
    "$script:ProjectRoot/domains/ai-agents/CopilotOrchestrator.psm1"
    "$script:ProjectRoot/domains/ai-agents/AIWorkflowOrchestrator.psm1"
)

foreach ($module in $requiredModules) {
    if (Test-Path $module) {
        try {
            Import-Module $module -Force
            Write-Verbose "Imported module: $module"
        } catch {
            Write-Warning "Failed to import $module`: $_"
        }
    } else {
        Write-Warning "Module not found: $module"
    }
}

function Write-CopilotSetupLog {
    param([string]$Message, [string]$Level = 'Information')
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level -Source "CopilotSetup"
    } else {
        $color = switch ($Level) {
            'Error' { 'Red' }
            'Warning' { 'Yellow' }
            'Success' { 'Green' }
            default { 'Cyan' }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
}

function Get-CopilotConfiguration {
    param([string]$ConfigPath)
    
    $defaultConfig = @{
        AutoExecution = @{
            CodeReview = $true
            TestGeneration = $true
            SecurityAnalysis = $true
            Documentation = $env:CI -ne 'true'  # Skip docs in CI for speed
            PerformanceOptimization = $false
        }
        Triggers = @{
            OnCommit = $true
            OnPullRequest = $true
            OnSchedule = $env:CI -eq 'true'  # Only scheduled in CI
            OnSecurityIssue = $true
            OnTestFailure = $true
        }
        Thresholds = @{
            CriticalSecurityIssues = 0
            TestCoverageMinimum = if ($env:CI -eq 'true') { 60 } else { 70 }
            CodeQualityMinimum = 75
            MaxExecutionTime = if ($env:CI -eq 'true') { 900 } else { 1800 }  # Shorter in CI
        }
        Agents = @{
            PrimaryReviewer = "claude"
            SecurityAnalyzer = "claude"  
            TestGenerator = "gemini"
            DocumentationWriter = "claude"
            PerformanceOptimizer = "gemini"
        }
        CI = @{
            EnableParallelExecution = $true
            MaxConcurrency = 2  # Conservative for CI
            FailOnCriticalIssues = $true
            GenerateReports = $true
        }
    }
    
    # Load custom configuration if provided
    if ($ConfigPath -and (Test-Path $ConfigPath)) {
        try {
            $customConfig = Get-Content $ConfigPath -Raw | ConvertFrom-Json -AsHashtable
            return Merge-CopilotConfiguration $defaultConfig $customConfig
        } catch {
            Write-CopilotSetupLog "Failed to load config from $ConfigPath`: $_" -Level Warning
        }
    }
    
    return $defaultConfig
}

function Merge-CopilotConfiguration {
    param([hashtable]$Default, [hashtable]$Override)
    
    $merged = $Default.Clone()
    
    foreach ($key in $Override.Keys) {
        if ($merged.ContainsKey($key) -and $merged[$key] -is [hashtable] -and $Override[$key] -is [hashtable]) {
            $merged[$key] = Merge-CopilotConfiguration $merged[$key] $Override[$key]
        } else {
            $merged[$key] = $Override[$key]
        }
    }
    
    return $merged
}

function Enable-AutomatedCopilot {
    param(
        [string[]]$EnabledWorkflows,
        [hashtable]$Configuration
    )
    
    Write-CopilotSetupLog "🚀 Enabling Automated Copilot System" -Level Information
    
    try {
        # Initialize the copilot orchestrator
        if (Get-Command Initialize-CopilotOrchestrator -ErrorAction SilentlyContinue) {
            $initResult = Initialize-CopilotOrchestrator -Configuration $Configuration -EnabledWorkflows $EnabledWorkflows
            
            if ($initResult) {
                Write-CopilotSetupLog "✅ Copilot orchestrator initialized successfully" -Level Success
                
                # Set up git hooks for automated triggers (if not in CI)
                if ($env:CI -ne 'true') {
                    Setup-GitHooks
                }
                
                # Configure workflow triggers
                Setup-WorkflowTriggers -Configuration $Configuration
                
                Write-CopilotSetupLog "🎉 Automated Copilot System enabled with workflows: $($EnabledWorkflows -join ', ')" -Level Success
                return $true
            } else {
                Write-CopilotSetupLog "❌ Failed to initialize copilot orchestrator" -Level Error
                return $false
            }
        } else {
            Write-CopilotSetupLog "❌ CopilotOrchestrator module not available" -Level Error
            return $false
        }
        
    } catch {
        Write-CopilotSetupLog "❌ Error enabling copilot system: $_" -Level Error
        return $false
    }
}

function Setup-GitHooks {
    Write-CopilotSetupLog "🔗 Setting up git hooks for automated triggers" -Level Information
    
    $gitHooksDir = Join-Path $script:ProjectRoot '.git/hooks'
    
    if (-not (Test-Path $gitHooksDir)) {
        Write-CopilotSetupLog "⚠️ Git hooks directory not found. Skipping git hook setup." -Level Warning
        return
    }
    
    # Create pre-commit hook for automated copilot
    $preCommitHook = Join-Path $gitHooksDir 'pre-commit'
    $hookContent = @'
#!/bin/bash
# AitherZero Automated Copilot Pre-Commit Hook

echo "🤖 Running AitherZero Automated Copilot..."

# Get changed files
CHANGED_FILES=$(git diff --cached --name-only)

# Run copilot workflow
pwsh -Command "
    Import-Module './domains/ai-agents/CopilotOrchestrator.psm1' -Force
    Start-AutomatedCopilotWorkflow -Trigger 'commit' -ChangedFiles @($CHANGED_FILES) -DryRun:$false
"

exit 0
'@
    
    if ($PSCmdlet.ShouldProcess($preCommitHook, "Create git pre-commit hook")) {
        Set-Content -Path $preCommitHook -Value $hookContent -Force
        
        # Make executable on Unix systems
        if (-not $IsWindows) {
            chmod +x $preCommitHook 2>$null
        }
        
        Write-CopilotSetupLog "✅ Pre-commit hook created" -Level Success
    }
}

function Setup-WorkflowTriggers {
    param([hashtable]$Configuration)
    
    Write-CopilotSetupLog "⚙️ Setting up workflow triggers" -Level Information
    
    # Create workflow configuration file
    $workflowConfigPath = Join-Path $script:ProjectRoot '.aitherzero/copilot-config.json'
    $configDir = Split-Path $workflowConfigPath -Parent
    
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    
    if ($PSCmdlet.ShouldProcess($workflowConfigPath, "Save copilot configuration")) {
        $Configuration | ConvertTo-Json -Depth 10 | Set-Content -Path $workflowConfigPath -Force
        Write-CopilotSetupLog "📄 Workflow configuration saved to $workflowConfigPath" -Level Success
    }
    
    # Set environment variables for CI integration
    if ($env:CI -eq 'true') {
        $env:AITHERZERO_COPILOT_ENABLED = 'true'
        $env:AITHERZERO_COPILOT_CONFIG = $workflowConfigPath
        Write-CopilotSetupLog "🔧 CI environment variables configured" -Level Success
    }
}

function Test-CopilotWorkflow {
    param([string]$TestTrigger)
    
    Write-CopilotSetupLog "🧪 Testing copilot workflow with trigger: $TestTrigger" -Level Information
    
    try {
        if (Get-Command Start-AutomatedCopilotWorkflow -ErrorAction SilentlyContinue) {
            # Get some sample files to test with
            $testFiles = @()
            if (Test-Path "$script:ProjectRoot/domains") {
                $testFiles = Get-ChildItem "$script:ProjectRoot/domains" -Filter "*.psm1" -Recurse | 
                             Select-Object -First 3 | 
                             ForEach-Object { $_.FullName.Replace($script:ProjectRoot, '.').Replace('\', '/') }
            }
            
            $testContext = @{
                TestMode = $true
                Timestamp = Get-Date
                ProjectRoot = $script:ProjectRoot
            }
            
            $result = Start-AutomatedCopilotWorkflow -Trigger $TestTrigger -ChangedFiles $testFiles -Context $testContext -DryRun:$DryRun
            
            if ($result) {
                Write-CopilotSetupLog "✅ Test workflow completed successfully" -Level Success
            } else {
                Write-CopilotSetupLog "❌ Test workflow failed" -Level Error
            }
            
            return $result
        } else {
            Write-CopilotSetupLog "❌ Copilot workflow function not available" -Level Error
            return $false
        }
        
    } catch {
        Write-CopilotSetupLog "❌ Test workflow error: $_" -Level Error
        return $false
    }
}

function Show-CopilotStatus {
    Write-CopilotSetupLog "📊 Copilot System Status" -Level Information
    
    if (Get-Command Get-CopilotStatus -ErrorAction SilentlyContinue) {
        try {
            $status = Get-CopilotStatus
            
            Write-Host "`n🤖 AitherZero Automated Copilot System Status" -ForegroundColor Cyan
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
            Write-Host "Initialized: " -NoNewline -ForegroundColor Yellow
            Write-Host $(if ($status.IsInitialized) { "✅ Yes" } else { "❌ No" }) -ForegroundColor $(if ($status.IsInitialized) { "Green" } else { "Red" })
            Write-Host "Active Workflows: " -NoNewline -ForegroundColor Yellow
            Write-Host $status.ActiveWorkflows -ForegroundColor White
            Write-Host "Registered Pipelines: " -NoNewline -ForegroundColor Yellow
            Write-Host $status.RegisteredPipelines -ForegroundColor White
            
            Write-Host "`n📈 Metrics:" -ForegroundColor Cyan
            Write-Host "  Workflows Executed: $($status.Metrics.WorkflowsExecuted)" -ForegroundColor White
            Write-Host "  Issues Found: $($status.Metrics.IssuesFound)" -ForegroundColor White
            Write-Host "  Issues Resolved: $($status.Metrics.IssuesResolved)" -ForegroundColor White
            Write-Host "  Code Changes Generated: $($status.Metrics.CodeChangesGenerated)" -ForegroundColor White
            
            return $true
        } catch {
            Write-CopilotSetupLog "❌ Error getting status: $_" -Level Error
            return $false
        }
    } else {
        Write-CopilotSetupLog "❌ Copilot system not available" -Level Error
        return $false
    }
}

# Main execution
try {
    Write-CopilotSetupLog "🤖 AitherZero Automated Copilot System Setup" -Level Information
    Write-CopilotSetupLog "Mode: $Mode" -Level Information
    
    # Load configuration
    $config = Get-CopilotConfiguration -ConfigPath $ConfigPath
    
    switch ($Mode) {
        'Enable' {
            $success = Enable-AutomatedCopilot -EnabledWorkflows $Workflows -Configuration $config
            if (-not $success) {
                Write-CopilotSetupLog "❌ Failed to enable copilot system" -Level Error
                exit 1
            }
        }
        'Disable' {
            Write-CopilotSetupLog "🛑 Disabling automated copilot system" -Level Information
            # Remove git hooks and configuration
            $hooksPath = Join-Path $script:ProjectRoot '.git/hooks/pre-commit'
            if (Test-Path $hooksPath -and $PSCmdlet.ShouldProcess($hooksPath, "Remove git hook")) {
                Remove-Item $hooksPath -Force
                Write-CopilotSetupLog "✅ Git hooks removed" -Level Success
            }
        }
        'Configure' {
            Write-CopilotSetupLog "⚙️ Configuring copilot workflows: $($Workflows -join ', ')" -Level Information
            Setup-WorkflowTriggers -Configuration $config
        }
        'Status' {
            Show-CopilotStatus
        }
        'Test' {
            if (-not $Trigger) {
                $Trigger = 'manual'
            }
            $success = Test-CopilotWorkflow -TestTrigger $Trigger
            if (-not $success) {
                exit 1
            }
        }
    }
    
    Write-CopilotSetupLog "✅ Copilot setup completed successfully" -Level Success
    exit 0
    
} catch {
    Write-CopilotSetupLog "❌ Copilot setup failed: $_" -Level Error
    Write-CopilotSetupLog "Stack trace: $($_.ScriptStackTrace)" -Level Error
    exit 1
}