#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Example script demonstrating centralized logging features
.DESCRIPTION
    Shows how to use the AitherZero centralized logging system in your scripts.
    Demonstrates all logging levels, structured logging, operation tracking, and more.
.NOTES
    Copyright © 2025 Aitherium Corporation
#>

# Import the centralized logging module
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$CentralizedLoggingModule = Join-Path $ProjectRoot "domains/utilities/CentralizedLogging.psm1"

if (Test-Path $CentralizedLoggingModule) {
    Import-Module $CentralizedLoggingModule -Force
} else {
    Write-Host "ERROR: CentralizedLogging module not found!" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== AitherZero Centralized Logging Examples ===`n" -ForegroundColor Cyan

# Example 1: Basic logging with different levels
Write-Host "Example 1: Basic logging with different levels" -ForegroundColor Yellow
Write-Log "This is a trace message" -Level Trace
Write-Log "This is a debug message" -Level Debug
Write-Log "This is an informational message" -Level Information
Write-Log "This is a warning message" -Level Warning
Write-Log "This is an error message" -Level Error
Write-Log "This is a critical message" -Level Critical

Write-Host ""
Start-Sleep -Seconds 1

# Example 2: Using convenience functions
Write-Host "Example 2: Using convenience functions" -ForegroundColor Yellow
Write-TraceLog "Entering detailed execution path"
Write-DebugLog "Variable value: x = 42"
Write-InfoLog "Processing completed successfully"
Write-WarningLog "Resource usage is approaching limit"
Write-ErrorLog "Failed to connect to database"
Write-CriticalLog "System component unavailable"

Write-Host ""
Start-Sleep -Seconds 1

# Example 3: Structured logging with additional data
Write-Host "Example 3: Structured logging with additional data" -ForegroundColor Yellow
Write-Log "User authentication succeeded" -Level Information -Data @{
    Username = "john.doe"
    IPAddress = "192.168.1.100"
    SessionId = "abc123"
    AuthMethod = "OAuth2"
}

Write-Log "Configuration loaded" -Level Information -Data @{
    ConfigFile = "config.psd1"
    SettingsCount = 42
    LoadTime = "150ms"
}

Write-Host ""
Start-Sleep -Seconds 1

# Example 4: Logging with exceptions
Write-Host "Example 4: Logging with exceptions" -ForegroundColor Yellow
try {
    # Simulate an error
    throw "Simulated database connection failure"
} catch {
    Write-ErrorLog "Database operation failed" -Exception $_.Exception -Data @{
        Operation = "Connect"
        Server = "db.example.com"
        Database = "production"
    }
}

Write-Host ""
Start-Sleep -Seconds 1

# Example 5: Operation tracking with performance metrics
Write-Host "Example 5: Operation tracking with automatic performance metrics" -ForegroundColor Yellow

$operation = Start-LoggedOperation -Name "DataProcessing" -Description "Processing user data batch" -Data @{
    BatchSize = 1000
    Source = "UserImport"
}

# Simulate some work
Start-Sleep -Seconds 2

Stop-LoggedOperation -Operation $operation -Success $true -Data @{
    RecordsProcessed = 1000
    RecordsSkipped = 5
    RecordsFailed = 0
}

Write-Host ""
Start-Sleep -Seconds 1

# Example 6: Test result logging
Write-Host "Example 6: Test result logging" -ForegroundColor Yellow
Write-TestResultLog -TestName "UserAuthentication" -TestType "Unit" -Result "Passed" -Duration 1.5 -Details @{
    Assertions = 5
    Coverage = "95%"
}

Write-TestResultLog -TestName "DatabaseConnection" -TestType "Integration" -Result "Failed" -Duration 5.2 -Details @{
    ErrorMessage = "Connection timeout"
    RetryAttempts = 3
}

Write-TestResultLog -TestName "UIRendering" -TestType "E2E" -Result "Skipped" -Duration 0 -Details @{
    Reason = "Browser not available"
}

Write-Host ""
Start-Sleep -Seconds 1

# Example 7: Code analysis result logging
Write-Host "Example 7: Code analysis result logging" -ForegroundColor Yellow
Write-CodeAnalysisLog `
    -FilePath "scripts/MyScript.ps1" `
    -Severity "Warning" `
    -RuleName "PSAvoidUsingCmdletAliases" `
    -Message "The alias 'ls' was used instead of Get-ChildItem" `
    -Details @{
        Line = 42
        Column = 5
        Suggestion = "Replace 'ls' with 'Get-ChildItem'"
    }

Write-CodeAnalysisLog `
    -FilePath "scripts/AnotherScript.ps1" `
    -Severity "Error" `
    -RuleName "PSUseDeclaredVarsMoreThanAssignments" `
    -Message "Variable 'unused' is assigned but never used" `
    -Details @{
        Line = 10
        VariableName = "unused"
    }

Write-Host ""
Start-Sleep -Seconds 1

# Example 8: Custom source identification
Write-Host "Example 8: Custom source identification" -ForegroundColor Yellow
Write-Log "Message from custom component" -Level Information -Source "MyCustomModule"
Write-Log "Message from data layer" -Level Information -Source "DataAccess"
Write-Log "Message from business logic" -Level Information -Source "BusinessLogic"

Write-Host ""
Start-Sleep -Seconds 1

# Example 9: Complex operation with multiple steps
Write-Host "Example 9: Complex operation with multiple steps" -ForegroundColor Yellow

$operation = Start-LoggedOperation -Name "DeploymentProcess" -Description "Deploying application to production"

Write-Log "Step 1: Validating configuration" -Level Information
Start-Sleep -Milliseconds 500

Write-Log "Step 2: Building application" -Level Information -Data @{
    BuildConfiguration = "Release"
    TargetPlatform = "Linux-x64"
}
Start-Sleep -Milliseconds 500

Write-Log "Step 3: Running tests" -Level Information
Start-Sleep -Milliseconds 500

Write-Log "Step 4: Deploying to server" -Level Information -Data @{
    Server = "prod-01.example.com"
    DeploymentSlot = "production"
}
Start-Sleep -Milliseconds 500

Stop-LoggedOperation -Operation $operation -Success $true -Data @{
    DeploymentId = "deploy-2025-001"
    Version = "1.2.3"
}

Write-Host ""
Start-Sleep -Seconds 1

# Display summary
Write-Host "`n=== Logging Examples Completed ===`n" -ForegroundColor Green
Write-Host "All log messages have been written to:" -ForegroundColor Cyan

$logPath = Get-CentralizedLogPath
Write-Host "  $logPath" -ForegroundColor White

Write-Host "`nLog files created:" -ForegroundColor Cyan
Write-Host "  - aitherzero-$(Get-Date -Format 'yyyy-MM-dd').log (all levels)" -ForegroundColor Gray
Write-Host "  - errors-$(Get-Date -Format 'yyyy-MM-dd').log (errors only)" -ForegroundColor Gray
Write-Host "  - warnings-$(Get-Date -Format 'yyyy-MM-dd').log (warnings only)" -ForegroundColor Gray
Write-Host "  - critical-$(Get-Date -Format 'yyyy-MM-dd').log (critical only)" -ForegroundColor Gray
Write-Host "  - debug-$(Get-Date -Format 'yyyy-MM-dd').log (debug only)" -ForegroundColor Gray
Write-Host "  - trace-$(Get-Date -Format 'yyyy-MM-dd').log (trace only)" -ForegroundColor Gray

Write-Host "`nTo view the centralized dashboard, run:" -ForegroundColor Cyan
Write-Host "  ./Show-Dashboard.ps1 -ShowAll" -ForegroundColor White

Write-Host "`nTo view log summary:" -ForegroundColor Cyan
Write-Host "  Show-LogSummary" -ForegroundColor White

Write-Host ""
