#!/usr/bin/env pwsh
#requires -version 7

<#
.SYNOPSIS
    Claude Code Subagent Stop Hook
.DESCRIPTION
    Executed when a subagent completes its task. Processes results and triggers follow-up actions.
.NOTES
    This hook receives JSON input via stdin about the completed subagent task.
#>

param()

# Read JSON input from stdin
$inputValue = @()
$inputValueStream = [Console]::In
while ($null -ne ($line = $inputValueStream.ReadLine())) {
    $inputValue += $line
}

if ($inputValue.Count -eq 0) {
    exit 0
}

try {
    $hookData = $inputValue -join "`n" | ConvertFrom-Json

    # Initialize logging
    $logPath = "$env:CLAUDE_PROJECT_DIR/logs/claude-hooks.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    function Write-HookLog {
        param([string]$Message, [string]$Level = "INFO")
        $logEntry = "[$timestamp] [$Level] SubagentStop: $Message"
        if ($env:CLAUDE_PROJECT_DIR -and (Test-Path (Split-Path $logPath -Parent))) {
            $logEntry | Add-Content -Path $logPath -Force
        }
        Write-Host $logEntry
    }

    # Get subagent information
    $agentType = $hookData.agent_type ?? $hookData.subagent_type ?? "unknown"
    $success = $hookData.success ?? $true
    $result = $hookData.result ?? $hookData.output
    $taskDescription = $hookData.task ?? $hookData.description ?? "No description"

    Write-HookLog "Subagent completed: $agentType (Success: $success)"
    Write-HookLog "Task: $taskDescription"

    # Agent-specific post-processing
    switch ($agentType) {
        "security-scanner" {
            Write-HookLog "Security scan completed"

            if ($success -and $result) {
                try {
                    # Process security scan results
                    $securityResults = if ($result -is [string]) {
                        $result | ConvertFrom-Json
                    } else {
                        $result
                    }

                    # Extract key findings
                    $criticalIssues = @()
                    $warnings = @()

                    if ($securityResults.vulnerabilities) {
                        $critical = @($securityResults.vulnerabilities | Where-Object { $_.severity -eq 'Critical' -or $_.severity -eq 'High' })
                        $warning = @($securityResults.vulnerabilities | Where-Object { $_.severity -eq 'Medium' -or $_.severity -eq 'Low' })

                        Write-HookLog "Security scan found: $($critical.Count) critical/high, $($warning.Count) medium/low issues"

                        if ($critical.Count -gt 0) {
                            Write-HookLog "CRITICAL: High-priority security issues found - immediate attention required" "ERROR"

                            # Trigger security workflow if available
                            if ($env:CLAUDE_PROJECT_DIR -and $env:AITHERZERO_AUTO_SECURITY) {
                                Write-HookLog "Triggering automated security response"
                                # This would trigger security remediation workflow
                            }
                        }
                    }

                } catch {
                    Write-HookLog "Could not process security results: $_" "WARN"
                }
            }

            # Suggest follow-up actions
            $followUpActions = @(
                "Review security scan results in detail",
                "Address high/critical severity findings first",
                "Update dependencies if vulnerabilities found",
                "Run ``az 0523`` again after fixes to verify resolution"
            )
            Write-HookLog "Security follow-up actions: $($followUpActions -join '; ')"
        }

        "syntax-validator" {
            Write-HookLog "Syntax validation completed"

            if ($success -and $result) {
                try {
                    # Process syntax validation results
                    $syntaxResults = if ($result -is [string]) {
                        $result | ConvertFrom-Json
                    } else {
                        $result
                    }

                    if ($syntaxResults.errors) {
                        $errorCount = @($syntaxResults.errors).Count
                        Write-HookLog "Syntax validation found $errorCount errors" "WARN"

                        # Log first few errors for context
                        @($syntaxResults.errors) | Select-Object -First 3 | ForEach-Object {
                            Write-HookLog "Syntax error: $($_.file):$($_.line) - $($_.message)" "ERROR"
                        }
                    } else {
                        Write-HookLog "Syntax validation passed - no errors found" "SUCCESS"
                    }

                } catch {
                    Write-HookLog "Could not process syntax validation results: $_" "WARN"
                }
            }

            # Suggest next steps based on results
            if ($success) {
                Write-HookLog "Consider running PSScriptAnalyzer (az 0404) for additional quality checks"
            }
        }

        "test-runner" {
            Write-HookLog "Test execution completed"

            if ($success -and $result) {
                try {
                    # Process test results
                    $testResults = if ($result -is [string]) {
                        $result | ConvertFrom-Json
                    } else {
                        $result
                    }

                    $passed = $testResults.passed ?? 0
                    $failed = $testResults.failed ?? 0
                    $total = $passed + $failed
                    $coverage = $testResults.coverage ?? "unknown"

                    Write-HookLog "Test results: $passed passed, $failed failed (Total: $total)"
                    Write-HookLog "Code coverage: $coverage"

                    if ($failed -gt 0) {
                        Write-HookLog "Test failures detected - investigation required" "WARN"

                        # Auto-generate failure report if configured
                        if ($env:CLAUDE_PROJECT_DIR -and $env:AITHERZERO_AUTO_REPORTS) {
                            Write-HookLog "Generating test failure report"
                            # This would trigger test report generation
                        }
                    } else {
                        Write-HookLog "All tests passed successfully" "SUCCESS"
                    }

                    # Coverage analysis
                    if ($coverage -match '(\d+)%') {
                        $coveragePercent = [int]$Matches[1]
                        if ($coveragePercent -lt 80) {
                            Write-HookLog "Code coverage below recommended threshold (80%): $coverage" "WARN"
                        }
                    }

                } catch {
                    Write-HookLog "Could not process test results: $_" "WARN"
                }
            }

            # Test-related follow-up suggestions
            $testFollowUp = @()
            if ($success) {
                $testFollowUp += "Review test coverage report for gaps"
                $testFollowUp += "Consider performance tests if not included"
                $testFollowUp += "Update test documentation if needed"
            } else {
                $testFollowUp += "Investigate test failures"
                $testFollowUp += "Check test environment configuration"
                $testFollowUp += "Review test logs for detailed error information"
            }
            Write-HookLog "Test follow-up: $($testFollowUp -join '; ')"
        }

        "compliance-enforcer" {
            Write-HookLog "Compliance check completed"

            if ($success -and $result) {
                try {
                    $complianceResults = if ($result -is [string]) {
                        $result | ConvertFrom-Json
                    } else {
                        $result
                    }

                    $violations = @($complianceResults.violations ?? @())
                    $warnings = @($complianceResults.warnings ?? @())

                    Write-HookLog "Compliance check: $($violations.Count) violations, $($warnings.Count) warnings"

                    if ($violations.Count -gt 0) {
                        Write-HookLog "Compliance violations found - must be addressed" "ERROR"

                        # Log top violations
                        $violations | Select-Object -First 3 | ForEach-Object {
                            Write-HookLog "Compliance violation: $($_.rule) - $($_.message)" "ERROR"
                        }
                    }

                } catch {
                    Write-HookLog "Could not process compliance results: $_" "WARN"
                }
            }
        }

        "performance-optimizer" {
            Write-HookLog "Performance analysis completed"

            if ($success -and $result) {
                try {
                    $perfResults = if ($result -is [string]) {
                        $result | ConvertFrom-Json
                    } else {
                        $result
                    }

                    $recommendations = @($perfResults.recommendations ?? @())
                    $metrics = $perfResults.metrics

                    Write-HookLog "Performance analysis: $($recommendations.Count) optimization recommendations"

                    if ($metrics) {
                        Write-HookLog "Performance metrics captured: execution time, memory usage, etc."
                    }

                    # Highlight critical performance issues
                    $critical = @($recommendations | Where-Object { $_.priority -eq 'Critical' -or $_.priority -eq 'High' })
                    if ($critical.Count -gt 0) {
                        Write-HookLog "Critical performance issues found: $($critical.Count)" "WARN"
                    }

                } catch {
                    Write-HookLog "Could not process performance results: $_" "WARN"
                }
            }
        }

        "dependency-analyzer" {
            Write-HookLog "Dependency analysis completed"

            if ($success -and $result) {
                try {
                    $depResults = if ($result -is [string]) {
                        $result | ConvertFrom-Json
                    } else {
                        $result
                    }

                    $outdated = @($depResults.outdated ?? @())
                    $vulnerable = @($depResults.vulnerable ?? @())
                    $unused = @($depResults.unused ?? @())

                    Write-HookLog "Dependency analysis: $($outdated.Count) outdated, $($vulnerable.Count) vulnerable, $($unused.Count) unused"

                    if ($vulnerable.Count -gt 0) {
                        Write-HookLog "Vulnerable dependencies found - security risk" "ERROR"
                    }

                    if ($outdated.Count -gt 10) {
                        Write-HookLog "Many outdated dependencies - consider batch update" "WARN"
                    }

                } catch {
                    Write-HookLog "Could not process dependency results: $_" "WARN"
                }
            }
        }

        "reranker-agent" {
            Write-HookLog "Document reranking completed"
            # Reranking is typically used for search/retrieval - less actionable follow-up
        }

        "summarizer-agent" {
            Write-HookLog "Content summarization completed"

            if ($success -and $result) {
                try {
                    $summary = if ($result -is [string]) { $result } else { $result.summary ?? "Summary completed" }
                    $wordCount = ($summary -split '\s+').Count
                    Write-HookLog "Generated summary: $wordCount words"
                } catch {
                    Write-HookLog "Could not analyze summary: $_" "WARN"
                }
            }
        }

        default {
            Write-HookLog "Generic subagent completed: $agentType"

            if ($success) {
                Write-HookLog "Subagent task completed successfully"
            } else {
                Write-HookLog "Subagent task failed - review results and retry if needed" "WARN"
            }
        }
    }

    # Global post-processing for all subagents
    if ($env:CLAUDE_PROJECT_DIR) {
        # Update subagent activity log
        $agentLogPath = "$env:CLAUDE_PROJECT_DIR/logs/subagent-activity.json"
        if (Test-Path (Split-Path $agentLogPath -Parent)) {
            try {
                $agentActivity = @{
                    timestamp = $timestamp
                    agent_type = $agentType
                    success = $success
                    task = $taskDescription
                    result_summary = if ($result -is [string]) {
                        $result.Substring(0, [Math]::Min($result.Length, 200))
                    } else {
                        "Object result"
                    }
                }

                $activityEntry = $agentActivity | ConvertTo-Json -Compress
                $activityEntry | Add-Content -Path $agentLogPath -Force

                Write-HookLog "Subagent activity logged"
            } catch {
                Write-HookLog "Could not update subagent activity log: $_" "WARN"
            }
        }

        # Trigger related automation if configured
        if ($success -and $env:AITHERZERO_AUTO_FOLLOWUP) {
            switch ($agentType) {
                "test-runner" {
                    # Auto-generate test report after test execution
                    Write-HookLog "Triggering test report generation"
                    Start-Job -ScriptBlock {
                        param($ProjectDir)
                        Set-Location $ProjectDir
                        if (Test-Path "./az.ps1") {
                            & ./az.ps1 0501 -CI 2>&1 | Out-Null
                        }
                    } -ArgumentList $env:CLAUDE_PROJECT_DIR | Out-Null
                }

                "security-scanner" {
                    # Auto-update security baseline
                    Write-HookLog "Updating security baseline"
                }

                "syntax-validator" {
                    # Auto-trigger style formatter if no errors
                    if ($success) {
                        Write-HookLog "Consider running code formatter for consistent style"
                    }
                }
            }
        }
    }

    Write-HookLog "Subagent post-processing completed"
    exit 0

} catch {
    Write-Error "Subagent stop hook execution failed: $_"
    # On error, don't block anything
    exit 0
}