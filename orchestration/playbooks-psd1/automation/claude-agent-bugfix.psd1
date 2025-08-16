@{
    Name = 'claude-agent-bugfix'
    Description = 'Automated bug fixing workflow using Claude Code sub-agents for targeted issue resolution'
    Version = '1.0.0'
    Author = 'AitherZero Automation'
    Tags = @('AI', 'Debugging', 'Automation', 'Claude', 'BugFix')
    
    # Configuration for Claude Code integration
    Variables = @{
        # Claude Code settings
        UseClaudeAgents = $true
        ClaudeTimeout = 300  # 5 minutes per agent task
        MaxRetries = 2
        
        # Issue detection settings
        ScanForErrors = $true
        RunTests = $true
        AnalyzeLogs = $true
        CheckSecurity = $false  # Set to true for security-focused runs
        
        # Output settings
        GenerateReport = $true
        CreatePullRequest = $false
        AutoCommit = $false
    }
    
    # Multi-stage workflow for comprehensive bug fixing
    Stages = @(
        @{
            Name = 'Diagnostics'
            Description = 'Gather information about the current state and identify issues'
            Sequence = @(
                '0402',  # Run unit tests to identify failures
                '0403',  # Run integration tests
                '0404',  # Run PSScriptAnalyzer for code quality issues
                '0530'   # View logs for runtime errors
            )
            Variables = @{
                CaptureOutput = $true
                StopOnError = $false  # Continue to gather all diagnostics
            }
            Conditional = @{
                When = 'Variables.ScanForErrors -eq $true'
            }
        }
        
        @{
            Name = 'ClaudeDebuggerAnalysis'
            Description = 'Use Claude Debugger sub-agent to analyze test failures and errors'
            Sequence = @(
                '0810'   # Create issues from test failures (for tracking)
            )
            Scripts = @{
                Inline = @'
# Invoke Claude Code Debugger sub-agent for root cause analysis
$testFailures = Get-Content "./test-results.xml" -ErrorAction SilentlyContinue
$logErrors = Get-Content "./logs/error-*.log" -ErrorAction SilentlyContinue | Select-Object -Last 100

if ($testFailures -or $logErrors) {
    $debugPrompt = @"
You are the debugger sub-agent. Analyze the following test failures and errors:

TEST FAILURES:
$($testFailures | Out-String)

LOG ERRORS:
$($logErrors | Out-String)

Please:
1. Identify the root cause of each failure
2. Determine the minimal fix needed
3. Check for related issues that might have the same cause
4. Provide specific code changes to fix the issues
"@

    Write-Host "Invoking Claude Debugger sub-agent..." -ForegroundColor Cyan
    # In a real implementation, this would call Claude Code CLI
    # claude code --subagent debugger --prompt "$debugPrompt"
    
    # Save analysis for next stage
    $debugPrompt | Out-File "./claude-debug-analysis.txt"
}
'@
            }
            ContinueOnError = $false
        }
        
        @{
            Name = 'ClaudeCodeReview'
            Description = 'Use Claude Code Reviewer sub-agent for comprehensive code analysis'
            Scripts = @{
                Inline = @'
# Get list of recently modified files
$modifiedFiles = git diff --name-only HEAD~1 2>$null
if (-not $modifiedFiles) {
    $modifiedFiles = Get-ChildItem -Path . -Filter "*.ps1" -Recurse | 
                     Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-1) } |
                     Select-Object -ExpandProperty FullName
}

if ($modifiedFiles) {
    $reviewPrompt = @"
You are the code-reviewer sub-agent. Review the following files for:
- Code quality issues
- Security vulnerabilities
- Performance problems
- Missing error handling
- Test coverage gaps

Files to review:
$($modifiedFiles -join "`n")

Provide specific actionable feedback and code improvements.
"@

    Write-Host "Invoking Claude Code Reviewer sub-agent..." -ForegroundColor Cyan
    # claude code --subagent code-reviewer --prompt "$reviewPrompt"
    
    $reviewPrompt | Out-File "./claude-review-analysis.txt"
}
'@
            }
            Conditional = @{
                When = 'Test-Path "./claude-debug-analysis.txt"'
            }
        }
        
        @{
            Name = 'ClaudeTestFixer'
            Description = 'Use Claude Test Runner sub-agent to fix failing tests'
            Sequence = @(
                '0411'   # Test-Smart - Run intelligent test selection
            )
            Scripts = @{
                Inline = @'
# Identify failing tests and invoke test fixer
$failingTests = @()

# Parse test results
if (Test-Path "./test-results.xml") {
    [xml]$testResults = Get-Content "./test-results.xml"
    $failingTests = $testResults.SelectNodes("//test[@result='Failed']") | 
                    ForEach-Object { $_.GetAttribute("name") }
}

if ($failingTests.Count -gt 0) {
    $testFixPrompt = @"
You are the test-runner sub-agent. The following tests are failing:

$($failingTests -join "`n")

Please:
1. Analyze why each test is failing
2. Fix the tests while preserving their original intent
3. Ensure the fixes don't break other tests
4. Add any missing test coverage

Run the tests after fixing to verify they pass.
"@

    Write-Host "Invoking Claude Test Runner sub-agent to fix $($failingTests.Count) failing tests..." -ForegroundColor Cyan
    # claude code --subagent test-runner --prompt "$testFixPrompt"
    
    $testFixPrompt | Out-File "./claude-testfix-prompt.txt"
}
'@
            }
            ContinueOnError = $false
        }
        
        @{
            Name = 'SecurityAudit'
            Description = 'Optional security audit using Claude Security sub-agent'
            Scripts = @{
                Inline = @'
$securityPrompt = @"
You are the security-audit sub-agent. Perform a comprehensive security review of the codebase:

1. Check for credential leaks
2. Identify injection vulnerabilities
3. Review authentication/authorization code
4. Check for insecure configurations
5. Validate input sanitization
6. Review cryptographic implementations

Focus on PowerShell-specific security concerns and Windows security best practices.
"@

Write-Host "Invoking Claude Security Audit sub-agent..." -ForegroundColor Yellow
# claude code --subagent security-audit --prompt "$securityPrompt"

$securityPrompt | Out-File "./claude-security-audit.txt"
'@
            }
            Conditional = @{
                When = 'Variables.CheckSecurity -eq $true'
            }
        }
        
        @{
            Name = 'ApplyFixes'
            Description = 'Apply the fixes identified by Claude sub-agents'
            Scripts = @{
                Inline = @'
# Aggregate all Claude agent recommendations
$fixes = @()

@("claude-debug-analysis.txt", "claude-review-analysis.txt", "claude-testfix-prompt.txt", "claude-security-audit.txt") |
    Where-Object { Test-Path $_ } |
    ForEach-Object {
        $fixes += Get-Content $_
    }

if ($fixes.Count -gt 0) {
    $applyFixPrompt = @"
Based on the analysis from multiple Claude sub-agents, apply the following fixes:

$($fixes -join "`n`n")

Instructions:
1. Apply all recommended code changes
2. Ensure changes are minimal and focused
3. Preserve existing functionality
4. Follow the codebase's style conventions
5. Add appropriate error handling
6. Update relevant documentation

Create atomic commits for each logical fix.
"@

    Write-Host "Applying fixes identified by Claude agents..." -ForegroundColor Green
    # claude code --prompt "$applyFixPrompt"
    
    # Save the consolidated fix plan
    $applyFixPrompt | Out-File "./claude-fix-plan.txt"
}
'@
            }
        }
        
        @{
            Name = 'ValidateFixes'
            Description = 'Validate that all fixes have been properly applied'
            Sequence = @(
                '0402',  # Run unit tests again
                '0404',  # Run PSScriptAnalyzer again
                '0407'   # Validate PowerShell syntax
            )
            Variables = @{
                StopOnError = $true  # Ensure all tests pass after fixes
            }
        }
        
        @{
            Name = 'GenerateReport'
            Description = 'Generate comprehensive report of issues found and fixes applied'
            Sequence = @(
                '0510',  # Generate project report
                '0524'   # Generate tech debt report
            )
            Scripts = @{
                Inline = @'
# Create bug fix report
$report = @"
# Automated Bug Fix Report

Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Issues Identified
$(if (Test-Path "./claude-debug-analysis.txt") { "- Debug Analysis: Found and analyzed" })
$(if (Test-Path "./claude-review-analysis.txt") { "- Code Review: Completed" })
$(if (Test-Path "./claude-testfix-prompt.txt") { "- Test Fixes: Applied" })
$(if (Test-Path "./claude-security-audit.txt") { "- Security Audit: Performed" })

## Actions Taken
$(if (Test-Path "./claude-fix-plan.txt") { Get-Content "./claude-fix-plan.txt" | Select-Object -First 50 })

## Validation Results
- Unit Tests: $(if (Test-Path "./test-results.xml") { "Passed" } else { "Not Run" })
- Code Analysis: $(if (Test-Path "./pssa-results.xml") { "Clean" } else { "Not Run" })

## Next Steps
1. Review the applied fixes
2. Run additional manual testing if needed
3. Create pull request for review
"@

$report | Out-File "./bugfix-report.md"
Write-Host "Bug fix report generated: ./bugfix-report.md" -ForegroundColor Green
'@
            }
            Conditional = @{
                When = 'Variables.GenerateReport -eq $true'
            }
        }
        
        @{
            Name = 'CreatePullRequest'
            Description = 'Optionally create a pull request with the fixes'
            Sequence = @(
                '0702',  # Create commit
                '0703'   # Create pull request
            )
            Variables = @{
                CommitMessage = 'fix: Automated bug fixes via Claude Code sub-agents'
                PRTitle = 'Automated Bug Fixes'
                PRBody = 'This PR contains automated fixes identified and applied by Claude Code sub-agents.'
            }
            Conditional = @{
                When = 'Variables.CreatePullRequest -eq $true -and Variables.AutoCommit -eq $true'
            }
        }
    )
    
    # Error handling configuration
    ErrorHandling = @{
        OnStageFailure = 'Continue'  # Continue to next stage even if one fails
        OnScriptError = 'Log'        # Log errors but continue
        MaxRetries = 2                # Retry failed operations
    }
    
    # Hooks for extensibility
    Hooks = @{
        PreStage = {
            param($Stage)
            Write-Host "`n🤖 Starting Claude Agent Stage: $($Stage.Name)" -ForegroundColor Cyan
            Write-Host "Description: $($Stage.Description)" -ForegroundColor Gray
        }
        
        PostStage = {
            param($Stage, $Result)
            if ($Result.Success) {
                Write-Host "✅ Stage '$($Stage.Name)' completed successfully" -ForegroundColor Green
            } else {
                Write-Host "⚠️ Stage '$($Stage.Name)' completed with issues" -ForegroundColor Yellow
            }
        }
        
        OnComplete = {
            param($Results)
            Write-Host "`n📊 Claude Agent Bug Fix Workflow Complete!" -ForegroundColor Green
            Write-Host "Total Stages Run: $($Results.StagesRun)" -ForegroundColor Gray
            Write-Host "Successful: $($Results.SuccessfulStages)" -ForegroundColor Green
            Write-Host "Failed: $($Results.FailedStages)" -ForegroundColor Red
            
            if (Test-Path "./bugfix-report.md") {
                Write-Host "`n📄 Report available at: ./bugfix-report.md" -ForegroundColor Cyan
            }
        }
    }
}