#!/usr/bin/env pwsh
#requires -version 7

<#
.SYNOPSIS
    Claude Code Post-Tool-Use Hook
.DESCRIPTION
    Executed after Claude Code uses a tool. Logs actions and triggers follow-up operations.
.NOTES
    This hook receives JSON input via stdin and can trigger additional actions.
#>

param()

# Read JSON input from stdin
$input = @()
$inputStream = [Console]::In
while ($null -ne ($line = $inputStream.ReadLine())) {
    $input += $line
}

if ($input.Count -eq 0) {
    exit 0
}

try {
    $hookData = $input -join "`n" | ConvertFrom-Json
    
    # Initialize logging
    $logPath = "$env:CLAUDE_PROJECT_DIR/logs/claude-hooks.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    function Write-HookLog {
        param([string]$Message, [string]$Level = "INFO")
        $logEntry = "[$timestamp] [$Level] PostToolUse: $Message"
        if ($env:CLAUDE_PROJECT_DIR -and (Test-Path (Split-Path $logPath -Parent))) {
            $logEntry | Add-Content -Path $logPath -Force
        }
        Write-Host $logEntry
    }
    
    # Get tool information
    $toolName = $hookData.tool_name
    $toolArgs = $hookData.arguments
    $success = $hookData.success ?? $true
    
    Write-HookLog "Tool completed: $toolName (Success: $success)"
    
    # Tool-specific post-processing
    switch ($toolName) {
        "Edit" -or "MultiEdit" -or "Write" {
            $filePath = $toolArgs.file_path ?? $toolArgs.path
            Write-HookLog "File modified: $filePath"
            
            if ($success) {
                # Trigger validation for PowerShell files
                if ($filePath -match '\.ps1$' -or $filePath -match '\.psm1$') {
                    Write-HookLog "PowerShell file modified, consider running syntax validation"
                    
                    # Auto-trigger syntax validation in the background
                    if ($env:CLAUDE_PROJECT_DIR -and $env:AITHERZERO_AUTO_VALIDATE) {
                        try {
                            Push-Location $env:CLAUDE_PROJECT_DIR
                            Start-Job -ScriptBlock {
                                param($FilePath, $ProjectDir)
                                Set-Location $ProjectDir
                                if (Test-Path "./az.ps1") {
                                    & ./az.ps1 0407 -CI -FilePath $FilePath 2>&1 | Out-Null
                                }
                            } -ArgumentList $filePath, $env:CLAUDE_PROJECT_DIR | Out-Null
                            Pop-Location
                        } catch {
                            Write-HookLog "Auto-validation failed: $_" "ERROR"
                        }
                    }
                }
                
                # Trigger documentation update for modules
                if ($filePath -match 'domains/.*\.psm1$' -or $filePath -match 'automation-scripts/.*\.ps1$') {
                    Write-HookLog "Module/script modified, documentation may need updating"
                }
                
                # Update version info for critical files
                if ($filePath -match 'AitherZero\.psd1$' -or $filePath -match 'config\.json$') {
                    Write-HookLog "Critical configuration file modified"
                }
            }
        }
        
        "Bash" {
            $command = $toolArgs.command
            Write-HookLog "Command executed: $command"
            
            if ($success) {
                # Check for specific command patterns
                if ($command -match '^(\./)?az\s+(\d+)') {
                    $scriptNumber = $matches[2]
                    Write-HookLog "AitherZero script $scriptNumber executed successfully"
                    
                    # Trigger follow-up actions for specific scripts
                    switch ($scriptNumber) {
                        "0404" -or "0407" {
                            Write-HookLog "Code analysis completed, results available for review"
                        }
                        "0402" -or "0403" {
                            Write-HookLog "Tests completed, consider reviewing coverage and results"
                        }
                        "0700" -or "0701" -or "0702" -or "0703" {
                            Write-HookLog "Git workflow action completed, consider next development steps"
                        }
                        "0720" -or "0721" -or "0722" -or "0723" {
                            Write-HookLog "Runner configuration completed, validate with GitHub Actions"
                        }
                    }
                }
                
                # Git operations
                if ($command -match '^git\s+') {
                    Write-HookLog "Git operation completed"
                    
                    if ($command -match 'git\s+commit') {
                        Write-HookLog "Commit created, consider running CI validation"
                        
                        # Auto-trigger CI tests if enabled
                        if ($env:AITHERZERO_AUTO_CI) {
                            Write-HookLog "Triggering automated CI validation"
                            # This would trigger CI pipeline or local validation
                        }
                    }
                    
                    if ($command -match 'git\s+(checkout|switch).*-b') {
                        Write-HookLog "New branch created, consider setting up tracking"
                    }
                }
                
                # Package installations
                if ($command -match 'Install-Module|npm\s+install|pip\s+install') {
                    Write-HookLog "Package installation completed, consider updating dependencies documentation"
                }
            } else {
                Write-HookLog "Command failed: $command" "ERROR"
            }
        }
        
        "Task" {
            $agentType = $toolArgs.subagent_type
            $description = $toolArgs.description
            Write-HookLog "Subagent task completed: $agentType - $description"
            
            if ($success) {
                # Agent-specific post-processing
                switch ($agentType) {
                    "security-scanner" {
                        Write-HookLog "Security scan completed, review findings and implement fixes"
                    }
                    "test-runner" {
                        Write-HookLog "Test execution completed, review coverage and performance metrics"
                    }
                    "syntax-validator" {
                        Write-HookLog "Syntax validation completed, address any identified issues"
                    }
                    "compliance-enforcer" {
                        Write-HookLog "Compliance check completed, ensure standards are met"
                    }
                }
            }
        }
        
        "TodoWrite" {
            Write-HookLog "Todo list updated, tracking development progress"
            
            if ($success) {
                # Check for completed todos and suggest next actions
                try {
                    $todos = $toolArgs.todos
                    $completed = @($todos | Where-Object { $_.status -eq 'completed' })
                    $inProgress = @($todos | Where-Object { $_.status -eq 'in_progress' })
                    $pending = @($todos | Where-Object { $_.status -eq 'pending' })
                    
                    Write-HookLog "Todo status: $($completed.Count) completed, $($inProgress.Count) in progress, $($pending.Count) pending"
                    
                    if ($completed.Count -gt 0 -and $pending.Count -gt 0) {
                        Write-HookLog "Consider starting next pending task"
                    }
                } catch {
                    Write-HookLog "Could not analyze todo structure: $_" "WARN"
                }
            }
        }
    }
    
    # Global post-processing
    if ($success) {
        # Update project activity log
        $activityLogPath = "$env:CLAUDE_PROJECT_DIR/logs/activity.json"
        if ($env:CLAUDE_PROJECT_DIR -and (Test-Path (Split-Path $activityLogPath -Parent))) {
            try {
                $activity = @{
                    timestamp = $timestamp
                    tool = $toolName
                    success = $success
                    details = @{
                        arguments = $toolArgs
                    }
                }
                
                $activityEntry = $activity | ConvertTo-Json -Compress
                $activityEntry | Add-Content -Path $activityLogPath -Force
            } catch {
                Write-HookLog "Could not update activity log: $_" "WARN"
            }
        }
        
        # Trigger periodic maintenance
        $lastMaintenance = Get-Variable -Name "CLAUDE_LAST_MAINTENANCE" -Scope Global -ErrorAction SilentlyContinue
        $now = Get-Date
        
        if (-not $lastMaintenance -or ($now - $lastMaintenance.Value).Hours -gt 4) {
            Write-HookLog "Triggering periodic maintenance"
            Set-Variable -Name "CLAUDE_LAST_MAINTENANCE" -Value $now -Scope Global -Force
            
            # Background maintenance tasks
            if ($env:CLAUDE_PROJECT_DIR) {
                Start-Job -ScriptBlock {
                    param($ProjectDir)
                    Set-Location $ProjectDir
                    
                    # Clean up old log files
                    Get-ChildItem "./logs" -Filter "*.log" -ErrorAction SilentlyContinue | 
                        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
                        Remove-Item -Force -ErrorAction SilentlyContinue
                    
                    # Clean up test results
                    Get-ChildItem "./tests/results" -ErrorAction SilentlyContinue |
                        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-3) } |
                        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                        
                } -ArgumentList $env:CLAUDE_PROJECT_DIR | Out-Null
            }
        }
    }
    
    Write-HookLog "Post-tool processing completed"
    exit 0
    
} catch {
    Write-Error "Post-tool hook execution failed: $_"
    # On error, don't block anything
    exit 0
}