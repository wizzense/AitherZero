#Requires -Version 7.0
#Requires -Modules Pester

<#
.SYNOPSIS
    Validates the mocking framework for AitherZero tests

.DESCRIPTION
    This script validates that the mocking framework is working correctly by:
    - Testing all mock helper functions
    - Validating mock isolation between tests
    - Checking mock setup and cleanup
    - Verifying mock behavior consistency
    - Testing integration with Pester

.PARAMETER Verbose
    Show detailed output during validation

.PARAMETER TestType
    Type of mock validation to perform: All, Git, FileSystem, Network, SystemServices, ExternalTools

.EXAMPLE
    ./Validate-MockingFramework.ps1
    
.EXAMPLE
    ./Validate-MockingFramework.ps1 -TestType Git -Verbose

.NOTES
    Author: AitherZero Development Team
    Version: 1.0.0
    Created: 2025-07-08
#>

param(
    [switch]$Verbose,
    [ValidateSet("All", "Git", "FileSystem", "Network", "SystemServices", "ExternalTools")]
    [string]$TestType = "All"
)

# Import mock helpers
$MockHelpersPath = Join-Path $PSScriptRoot "shared" "MockHelpers.ps1"
if (-not (Test-Path $MockHelpersPath)) {
    throw "Mock helpers not found at: $MockHelpersPath"
}

. $MockHelpersPath

Write-Host "=== AitherZero Mocking Framework Validation ===" -ForegroundColor Cyan
Write-Host "Testing Type: $TestType" -ForegroundColor Yellow

$validationResults = @{
    Passed = 0
    Failed = 0
    Skipped = 0
    Details = @()
}

function Test-MockFunction {
    param(
        [string]$TestName,
        [scriptblock]$TestScript,
        [switch]$ShouldSkip
    )
    
    if ($ShouldSkip) {
        Write-Host "SKIP: $TestName" -ForegroundColor Yellow
        $validationResults.Skipped++
        return
    }
    
    try {
        & $TestScript
        Write-Host "PASS: $TestName" -ForegroundColor Green
        $validationResults.Passed++
        $validationResults.Details += [PSCustomObject]@{
            Test = $TestName
            Result = "PASS"
            Error = $null
        }
    } catch {
        Write-Host "FAIL: $TestName - $($_.Exception.Message)" -ForegroundColor Red
        $validationResults.Failed++
        $validationResults.Details += [PSCustomObject]@{
            Test = $TestName
            Result = "FAIL"
            Error = $_.Exception.Message
        }
    }
}

# Test Git Mocking
if ($TestType -eq "All" -or $TestType -eq "Git") {
    Write-Host "`n--- Testing Git Mocking ---" -ForegroundColor Cyan
    
    Test-MockFunction -TestName "Initialize Git Mocking" -TestScript {
        Initialize-GitMocking
        if (-not $script:MockConfig.Git.Enabled) {
            throw "Git mocking not enabled"
        }
    }
    
    Test-MockFunction -TestName "Git Status Mock" -TestScript {
        Initialize-GitMocking
        $status = git status
        if (-not ($status -contains "On branch main")) {
            throw "Git status mock not working correctly"
        }
    }
    
    Test-MockFunction -TestName "Git Branch Operations" -TestScript {
        Initialize-GitMocking
        $branch = git branch --show-current
        if ($branch -ne "main") {
            throw "Git branch mock not working correctly"
        }
        
        git checkout -b "test-branch"
        $newBranch = git branch --show-current
        if ($newBranch -ne "test-branch") {
            throw "Git branch switching mock not working correctly"
        }
    }
    
    Test-MockFunction -TestName "Git Repository State Management" -TestScript {
        Initialize-GitMocking
        Set-GitRepositoryState -Branch "develop" -IsDirty
        
        $branch = git branch --show-current
        if ($branch -ne "develop") {
            throw "Git repository state not updated correctly"
        }
        
        $status = git status
        if (-not ($status -contains "Changes not staged for commit")) {
            throw "Git dirty state not working correctly"
        }
    }
    
    Test-MockFunction -TestName "Git Conflict Markers" -TestScript {
        $conflictContent = Add-GitConflictMarkers -Content "Base" -HeadContent "HEAD" -BranchContent "Branch"
        if (-not ($conflictContent -match "<<<<<<< HEAD")) {
            throw "Git conflict markers not generated correctly"
        }
    }
}

# Test File System Mocking
if ($TestType -eq "All" -or $TestType -eq "FileSystem") {
    Write-Host "`n--- Testing File System Mocking ---" -ForegroundColor Cyan
    
    Test-MockFunction -TestName "Initialize File System Mocking" -TestScript {
        Initialize-FileSystemMocking
        if (-not $script:MockConfig.FileSystem.Enabled) {
            throw "File system mocking not enabled"
        }
    }
    
    Test-MockFunction -TestName "Virtual Path Operations" -TestScript {
        Initialize-FileSystemMocking
        Add-VirtualPath -Path "/test/file.txt" -Content "test content"
        
        if (-not (Test-Path "/test/file.txt")) {
            throw "Virtual path not created correctly"
        }
        
        $content = Get-Content "/test/file.txt"
        if ($content -ne "test content") {
            throw "Virtual file content not correct"
        }
    }
    
    Test-MockFunction -TestName "File System Operations" -TestScript {
        Initialize-FileSystemMocking
        Add-VirtualPath -Path "/test/original.txt" -Content "original"
        
        # Test file modification
        Set-Content "/test/original.txt" -Value "modified"
        $content = Get-Content "/test/original.txt"
        if ($content -ne "modified") {
            throw "File content modification not working"
        }
        
        # Test file deletion
        Remove-Item "/test/original.txt"
        if (Test-Path "/test/original.txt") {
            throw "File deletion not working"
        }
    }
    
    Test-MockFunction -TestName "Directory Operations" -TestScript {
        Initialize-FileSystemMocking
        Add-VirtualPath -Path "/test/dir" -IsDirectory
        Add-VirtualPath -Path "/test/dir/file1.txt" -Content "content1"
        Add-VirtualPath -Path "/test/dir/file2.txt" -Content "content2"
        
        $files = Get-ChildItem "/test/dir"
        if ($files.Count -ne 2) {
            throw "Directory listing not working correctly"
        }
    }
}

# Test Network Mocking
if ($TestType -eq "All" -or $TestType -eq "Network") {
    Write-Host "`n--- Testing Network Mocking ---" -ForegroundColor Cyan
    
    Test-MockFunction -TestName "Initialize Network Mocking" -TestScript {
        Initialize-NetworkMocking
        if (-not $script:MockConfig.Network.Enabled) {
            throw "Network mocking not enabled"
        }
    }
    
    Test-MockFunction -TestName "REST API Mock Responses" -TestScript {
        Initialize-NetworkMocking
        Add-MockResponse -Url "https://api.test.com/data" -Response @{ test = "data" }
        
        $response = Invoke-RestMethod -Uri "https://api.test.com/data"
        if ($response.test -ne "data") {
            throw "Mock REST API response not working correctly"
        }
    }
    
    Test-MockFunction -TestName "Web Request Mock Responses" -TestScript {
        Initialize-NetworkMocking
        Add-MockResponse -Url "https://web.test.com/page" -Response @{ content = "page content" }
        
        $response = Invoke-WebRequest -Uri "https://web.test.com/page"
        if ($response.StatusCode -ne 200) {
            throw "Mock web request response not working correctly"
        }
    }
    
    Test-MockFunction -TestName "Network Failure Simulation" -TestScript {
        Initialize-NetworkMocking
        Add-FailingUrl -Url "https://failing.test.com/endpoint"
        
        try {
            Invoke-RestMethod -Uri "https://failing.test.com/endpoint"
            throw "Network failure simulation not working"
        } catch {
            if ($_.Exception.Message -notmatch "Network request failed") {
                throw "Network failure simulation not working correctly"
            }
        }
    }
}

# Test System Services Mocking
if ($TestType -eq "All" -or $TestType -eq "SystemServices") {
    Write-Host "`n--- Testing System Services Mocking ---" -ForegroundColor Cyan
    
    Test-MockFunction -TestName "Initialize System Services Mocking" -TestScript {
        Initialize-SystemServicesMocking
        if (-not $script:MockConfig.System.Enabled) {
            throw "System services mocking not enabled"
        }
    }
    
    Test-MockFunction -TestName "Service Operations" -TestScript {
        Initialize-SystemServicesMocking
        Add-MockService -Name "TestService" -Status "Running"
        
        $service = Get-Service -Name "TestService"
        if ($service.Status -ne "Running") {
            throw "Mock service not working correctly"
        }
        
        Stop-Service -Name "TestService"
        $service = Get-Service -Name "TestService"
        if ($service.Status -ne "Stopped") {
            throw "Mock service control not working correctly"
        }
    }
    
    Test-MockFunction -TestName "Process Operations" -TestScript {
        Initialize-SystemServicesMocking
        Add-MockProcess -Name "TestProcess" -Id 1234
        
        $process = Get-Process -Name "TestProcess"
        if ($process.Id -ne 1234) {
            throw "Mock process not working correctly"
        }
    }
}

# Test External Tools Mocking
if ($TestType -eq "All" -or $TestType -eq "ExternalTools") {
    Write-Host "`n--- Testing External Tools Mocking ---" -ForegroundColor Cyan
    
    Test-MockFunction -TestName "Initialize External Tools Mocking" -TestScript {
        Initialize-ExternalToolsMocking
        # No specific enabled flag for external tools
        $true
    }
    
    Test-MockFunction -TestName "External Tool Commands" -TestScript {
        Initialize-ExternalToolsMocking
        
        $terraformResult = terraform version
        if ($terraformResult -ne "Mock terraform output") {
            throw "Terraform mock not working correctly"
        }
        
        $dockerResult = docker version
        if ($dockerResult -ne "Mock docker output") {
            throw "Docker mock not working correctly"
        }
    }
    
    Test-MockFunction -TestName "Process Execution" -TestScript {
        Initialize-ExternalToolsMocking
        
        $result = Start-Process -FilePath "test.exe" -ArgumentList "arg1"
        if ($result.ExitCode -ne 0) {
            throw "Process execution mock not working correctly"
        }
    }
}

# Test Mock Management and Isolation
if ($TestType -eq "All") {
    Write-Host "`n--- Testing Mock Management ---" -ForegroundColor Cyan
    
    Test-MockFunction -TestName "Mock Configuration Reset" -TestScript {
        Initialize-ComprehensiveMocking -IncludeGit -IncludeFileSystem -IncludeNetwork
        
        # Add some state
        Add-VirtualPath -Path "/test/state.txt" -Content "test state"
        Add-MockResponse -Url "https://test.com/api" -Response @{ test = "data" }
        
        # Reset configuration
        Reset-MockConfiguration
        
        # Verify state is reset
        $config = Get-MockConfiguration
        if ($config.Git.Enabled) {
            throw "Git mocking not reset correctly"
        }
        if ($config.FileSystem.VirtualPaths.Count -gt 0) {
            throw "File system mocking not reset correctly"
        }
        if ($config.Network.Responses.Count -gt 0) {
            throw "Network mocking not reset correctly"
        }
    }
    
    Test-MockFunction -TestName "Mock Isolation Testing" -TestScript {
        Reset-MockConfiguration
        
        # Test isolation should pass with clean state
        $isolationResult = Test-MockIsolation
        if (-not $isolationResult) {
            throw "Mock isolation test failed"
        }
    }
    
    Test-MockFunction -TestName "Comprehensive Mock Initialization" -TestScript {
        Initialize-ComprehensiveMocking -IncludeGit -IncludeFileSystem -IncludeNetwork -IncludeSystemServices -IncludeExternalTools
        
        $config = Get-MockConfiguration
        if (-not $config.Git.Enabled) {
            throw "Git not enabled in comprehensive initialization"
        }
        if (-not $config.FileSystem.Enabled) {
            throw "File system not enabled in comprehensive initialization"
        }
        if (-not $config.Network.Enabled) {
            throw "Network not enabled in comprehensive initialization"
        }
        if (-not $config.System.Enabled) {
            throw "System services not enabled in comprehensive initialization"
        }
    }
}

# Test Pester Integration
if ($TestType -eq "All") {
    Write-Host "`n--- Testing Pester Integration ---" -ForegroundColor Cyan
    
    Test-MockFunction -TestName "Test Environment Setup" -TestScript {
        Set-TestMockEnvironment -MockTypes @("Git", "FileSystem")
        
        $config = Get-MockConfiguration
        if (-not $config.Git.Enabled) {
            throw "Test environment setup not working for Git"
        }
        if (-not $config.FileSystem.Enabled) {
            throw "Test environment setup not working for FileSystem"
        }
    }
    
    Test-MockFunction -TestName "Test Environment Cleanup" -TestScript {
        Set-TestMockEnvironment -MockTypes @("Git", "FileSystem")
        Add-VirtualPath -Path "/test/cleanup.txt" -Content "cleanup test"
        
        Clear-TestMockEnvironment
        
        $config = Get-MockConfiguration
        if ($config.Git.Enabled) {
            throw "Test environment cleanup not working for Git"
        }
        if ($config.FileSystem.VirtualPaths.Count -gt 0) {
            throw "Test environment cleanup not working for FileSystem"
        }
    }
}

# Final Results
Write-Host "`n=== Validation Results ===" -ForegroundColor Cyan
Write-Host "Passed: $($validationResults.Passed)" -ForegroundColor Green
Write-Host "Failed: $($validationResults.Failed)" -ForegroundColor Red
Write-Host "Skipped: $($validationResults.Skipped)" -ForegroundColor Yellow

if ($validationResults.Failed -gt 0) {
    Write-Host "`n=== Failed Tests Details ===" -ForegroundColor Red
    $validationResults.Details | Where-Object Result -eq "FAIL" | ForEach-Object {
        Write-Host "- $($_.Test): $($_.Error)" -ForegroundColor Red
    }
}

if ($Verbose) {
    Write-Host "`n=== All Test Details ===" -ForegroundColor Cyan
    $validationResults.Details | Format-Table -AutoSize
}

# Summary
$totalTests = $validationResults.Passed + $validationResults.Failed + $validationResults.Skipped
Write-Host "`nTotal Tests: $totalTests" -ForegroundColor Cyan

if ($validationResults.Failed -eq 0) {
    Write-Host "🎉 All mocking framework tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ Some mocking framework tests failed." -ForegroundColor Red
    exit 1
}