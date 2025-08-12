#!/usr/bin/env pwsh
#requires -version 7

<#
.SYNOPSIS
    Claude Code Pre-Tool-Use Hook
.DESCRIPTION
    Executed before Claude Code uses any tool. Validates operations and provides context.
.NOTES
    This hook receives JSON input via stdin and can block tool usage or add context.
#>

param()

# Read JSON input from stdin
$hookInput = @()
$inputValueStream = [Console]::In
while ($null -ne ($line = $inputValueStream.ReadLine())) {
    $hookInput += $line
}

if ($hookInput.Count -eq 0) {
    # No input provided, allow operation with proper response
    @{ action = "allow" } | ConvertTo-Json -Compress | Write-Host
    exit 0
}

try {
    $hookData = $hookInput -join "`n" | ConvertFrom-Json
    
    # Initialize logging if available
    $logPath = "$env:CLAUDE_PROJECT_DIR/logs/claude-hooks.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    function Write-HookLog {
        param([string]$Message, [string]$Level = "INFO")
        $logEntry = "[$timestamp] [$Level] PreToolUse: $Message"
        if ($env:CLAUDE_PROJECT_DIR -and (Test-Path (Split-Path $logPath -Parent))) {
            $logEntry | Add-Content -Path $logPath -Force
        }
        Write-Host $logEntry
    }
    
    Write-HookLog "Tool use intercepted: $($hookData.tool_name ?? 'unknown')"
    
    # Get tool information
    $toolName = $hookData.tool_name
    $toolArgs = $hookData.arguments
    
    # Validation rules based on tool type
    $blocked = $false
    $contextToAdd = @()
    
    switch ($toolName) {
        "Bash" {
            $command = $toolArgs.command
            Write-HookLog "Bash command: $command"
            
            # Block dangerous commands
            $dangerousPatterns = @(
                'rm\s+-rf\s+/',
                'sudo\s+rm',
                'mkfs\.',
                'dd\s+if=',
                '>\s*/dev/sd[a-z]',
                'curl.*\|\s*sh',
                'wget.*\|\s*sh'
            )
            
            foreach ($pattern in $dangerousPatterns) {
                if ($command -match $pattern) {
                    Write-HookLog "BLOCKED: Potentially dangerous command detected: $pattern" "ERROR"
                    $blocked = $true
                    break
                }
            }
            
            # INTELLIGENT TEST EXECUTION MANAGEMENT
            $testPatterns = @(
                'az\s+040[23]',  # Unit/Integration tests
                'az\s+0409',     # All tests
                'Invoke-Pester',
                'Run-.*Test',
                '0402_.*\.ps1',
                '0403_.*\.ps1'
            )
            
            $isTestCommand = $false
            foreach ($pattern in $testPatterns) {
                if ($command -match $pattern) {
                    $isTestCommand = $true
                    break
                }
            }
            
            if ($isTestCommand -and -not ($command -match '-ForceRun|-Force')) {
                Write-HookLog "Test execution detected - checking cache and recent runs" "INFO"
                
                # Import test cache module if available
                $testCacheModule = "$env:CLAUDE_PROJECT_DIR/domains/testing/TestCacheManager.psm1"
                if (Test-Path $testCacheModule) {
                    try {
                        Import-Module $testCacheModule -Force
                        
                        # Check if tests should run
                        $testDecision = Test-ShouldRunTests -SourcePath "$env:CLAUDE_PROJECT_DIR/domains" -MinutesSinceLastRun 5
                        
                        if (-not $testDecision.ShouldRun) {
                            Write-HookLog "Tests recently passed - suggesting cache usage" "WARN"
                            $contextToAdd += "⚠️ TEST OPTIMIZATION AVAILABLE"
                            $contextToAdd += ""
                            $contextToAdd += "Recent successful test run detected ($($testDecision.Reason))."
                            $contextToAdd += ""
                            
                            if ($testDecision.LastRun) {
                                $contextToAdd += "Last test results:"
                                $contextToAdd += "  ✅ Passed: $($testDecision.LastRun.Summary.Passed)"
                                $contextToAdd += "  ❌ Failed: $($testDecision.LastRun.Summary.Failed)"
                                $contextToAdd += "  ⏱️ Duration: $($testDecision.LastRun.Summary.Duration)s"
                                $contextToAdd += ""
                            }
                            
                            $contextToAdd += "RECOMMENDED: Use smart test runner instead:"
                            $contextToAdd += "  ./automation-scripts/0411_Test-Smart.ps1"
                            $contextToAdd += "  OR: ./az 0411"
                            $contextToAdd += ""
                            $contextToAdd += "This will:"
                            $contextToAdd += "  • Check cache for recent results"
                            $contextToAdd += "  • Run only changed module tests"
                            $contextToAdd += "  • Save significant execution time"
                            $contextToAdd += ""
                            $contextToAdd += "To force full test run anyway, add -ForceRun parameter"
                            
                            # Check recent test results
                            $resultsPath = "$env:CLAUDE_PROJECT_DIR/tests/results"
                            if (Test-Path $resultsPath) {
                                $recentResults = Get-ChildItem -Path $resultsPath -Filter "*Tests-Summary-*.json" -ErrorAction SilentlyContinue |
                                    Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-10) } |
                                    Sort-Object LastWriteTime -Descending |
                                    Select-Object -First 1
                                
                                if ($recentResults) {
                                    $summary = Get-Content $recentResults.FullName -Raw | ConvertFrom-Json
                                    if ($summary.Failed -eq 0) {
                                        $contextToAdd += ""
                                        $contextToAdd += "✅ All tests passed in recent run - consider skipping redundant execution"
                                    }
                                }
                            }
                        }
                    } catch {
                        Write-HookLog "Could not check test cache: $_" "DEBUG"
                    }
                }
            }
            
            # ENFORCE ORCHESTRATION FOR GIT OPERATIONS
            $gitOperationsRequiringOrchestration = @(
                'git\s+commit',
                'git\s+push',
                'git\s+merge',
                'gh\s+pr\s+create',
                'gh\s+pr\s+merge'
            )
            
            foreach ($pattern in $gitOperationsRequiringOrchestration) {
                if ($command -match $pattern) {
                    Write-HookLog "Git operation requiring orchestration detected: $pattern" "WARN"
                    $contextToAdd += "⚠️ GIT OPERATION DETECTED: This operation should use orchestrated playbooks!"
                    $contextToAdd += "Recommended playbooks:"
                    $contextToAdd += "  • claude-commit-workflow - For commits"
                    $contextToAdd += "  • git-workflow - For general git operations"
                    $contextToAdd += "  • claude-feature-workflow - For feature development"
                    $contextToAdd += "Use: ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook <playbook-name>"
                    
                    # Check if orchestration marker exists
                    if (-not (Test-Path ".claude/.orchestration-active")) {
                        $contextToAdd += "❌ ORCHESTRATION NOT ACTIVE - Consider using playbook workflow instead!"
                    }
                }
            }
            
            # Add context for AitherZero commands
            if ($command -match '^(\./)?az\s+\d+' -or $command -match '\.ps1') {
                $contextToAdd += "AitherZero automation script execution detected. Ensure environment is properly initialized."
                
                # Check if environment is initialized
                if (-not $env:AITHERZERO_INITIALIZED) {
                    $contextToAdd += "WARNING: AitherZero environment may not be initialized. Consider running Initialize-AitherModules.ps1 first."
                }
            }
            
            # Suggest using orchestration for sequences
            if ($command -match 'az\s+\d+.*&&.*az\s+\d+') {
                $contextToAdd += "Consider using orchestration sequences (seq command) for multiple automation scripts."
            }
        }
        
        { $_ -in @("Edit", "MultiEdit", "Write") } {
            $filePath = $toolArgs.file_path ?? $toolArgs.path
            Write-HookLog "File modification: $filePath"
            
            # Protect critical files
            $protectedFiles = @(
                'bootstrap\.ps1$',
                'Initialize-.*\.ps1$',
                'Start-AitherZero\.ps1$',
                '\.github/workflows/.*\.yml$',
                'config\.json$'
            )
            
            foreach ($pattern in $protectedFiles) {
                if ($filePath -match $pattern) {
                    $contextToAdd += "CAUTION: Modifying critical system file. Ensure changes are tested thoroughly."
                    Write-HookLog "Critical file modification detected: $filePath" "WARN"
                    break
                }
            }
            
            # Suggest testing for automation scripts
            if ($filePath -match 'automation-scripts/.*\.ps1$') {
                $contextToAdd += "Automation script modification detected. Consider running validation (az 0404, az 0407) after changes."
            }
            
            # Suggest documentation updates
            if ($filePath -match '\.psm1$' -or $filePath -match 'automation-scripts/.*\.ps1$') {
                $contextToAdd += "PowerShell module/script modified. Consider updating documentation if public functions changed."
            }
        }
        
        "TodoWrite" {
            Write-HookLog "Todo list modification detected"
            $contextToAdd += "Todo list being updated. This helps track development progress."
        }
        
        "Task" {
            $agentType = $toolArgs.subagent_type
            Write-HookLog "Subagent task: $agentType"
            
            # Add context for specific agent types
            switch ($agentType) {
                "security-scanner" {
                    $contextToAdd += "Security scan initiated. Results will include vulnerability analysis and recommendations."
                }
                "syntax-validator" {
                    $contextToAdd += "Syntax validation initiated. This validates PowerShell syntax and best practices."
                }
                "test-runner" {
                    $contextToAdd += "Test execution initiated. Results will include coverage and performance metrics."
                }
            }
        }
        
        default {
            Write-HookLog "Tool: $toolName (no specific validation rules)"
        }
    }
    
    # Check project context
    if ($env:CLAUDE_PROJECT_DIR) {
        # Check if we're in a git repository
        Push-Location $env:CLAUDE_PROJECT_DIR
        try {
            $gitStatus = git status --porcelain 2>$null
            if ($gitStatus) {
                $changedFiles = ($gitStatus | Measure-Object).Count
                $contextToAdd += "Git repository has $changedFiles uncommitted changes. Consider committing or stashing before major operations."
            }
        } catch {
            # Not a git repository or git not available
            Write-HookLog "Git status check failed: not a git repository or git not available" "DEBUG"
        } finally {
            Pop-Location
        }
        
        # Check if tests are passing
        $testResultsPath = "$env:CLAUDE_PROJECT_DIR/tests/results"
        if (Test-Path $testResultsPath) {
            $latestResults = Get-ChildItem $testResultsPath -Filter "*.xml" -ErrorAction SilentlyContinue | 
                           Sort-Object LastWriteTime -Descending | 
                           Select-Object -First 1
            
            if ($latestResults -and $latestResults.LastWriteTime -gt (Get-Date).AddHours(-1)) {
                try {
                    [xml]$testXml = Get-Content $latestResults.FullName
                    $failures = $testXml.SelectNodes("//failure").Count
                    if ($failures -gt 0) {
                        $contextToAdd += "WARNING: Recent tests show $failures failures. Consider fixing tests before major changes."
                    }
                } catch {
                    # Could not parse test results
                    Write-HookLog "Could not parse test results: $_" "DEBUG"
                }
            }
        }
    }
    
    # Generate response
    if ($blocked) {
        # Block the operation
        $response = @{
            action = "block"
            message = "Tool use blocked by pre-tool-use hook due to safety concerns."
        } | ConvertTo-Json -Compress
        
        Write-Host $response
        exit 1
        
    } elseif ($contextToAdd.Count -gt 0) {
        # Allow operation but add context
        $response = @{
            action = "add_context"
            context = $contextToAdd -join "`n`n"
        } | ConvertTo-Json -Compress
        
        Write-Host $response
        exit 0
        
    } else {
        # Allow operation without changes
        @{ action = "allow" } | ConvertTo-Json -Compress | Write-Host
        exit 0
    }
    
} catch {
    Write-Error "Hook execution failed: $_"
    # On error, allow the operation to proceed with proper response
    @{ action = "allow" } | ConvertTo-Json -Compress | Write-Host
    exit 0
}