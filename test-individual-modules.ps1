#!/usr/bin/env pwsh
#Requires -Version 7.0

# Test script for individual module imports and dependency validation

param(
    [string[]]$TestModules = @(),
    [switch]$Detailed
)

$ErrorActionPreference = 'Stop'

# Define all modules with their dependencies
$ModuleRegistry = @{
    'Logging' = @{
        Path = './aither-core/modules/Logging'
        Dependencies = @()
        Required = $true
        Description = 'Centralized logging system'
    }
    'ModuleCommunication' = @{
        Path = './aither-core/modules/ModuleCommunication'
        Dependencies = @()
        Required = $true
        Description = 'Inter-module communication bus'
    }
    'ConfigurationCore' = @{
        Path = './aither-core/modules/ConfigurationCore'
        Dependencies = @()
        Required = $true
        Description = 'Core configuration management'
    }
    'LabRunner' = @{
        Path = './aither-core/modules/LabRunner'
        Dependencies = @('Logging')
        Required = $true
        Description = 'Lab automation and script execution'
    }
    'OpenTofuProvider' = @{
        Path = './aither-core/modules/OpenTofuProvider'
        Dependencies = @('Logging')
        Required = $true
        Description = 'OpenTofu/Terraform infrastructure deployment'
    }
    'PatchManager' = @{
        Path = './aither-core/modules/PatchManager'
        Dependencies = @('Logging')
        Required = $false
        Description = 'Git-controlled patch management'
    }
    'TestingFramework' = @{
        Path = './aither-core/modules/TestingFramework'
        Dependencies = @('Logging')
        Required = $false
        Description = 'Unified testing framework'
    }
    'SetupWizard' = @{
        Path = './aither-core/modules/SetupWizard'
        Dependencies = @('Logging', 'ConfigurationCore')
        Required = $false
        Description = 'Intelligent setup and onboarding wizard'
    }
    'DevEnvironment' = @{
        Path = './aither-core/modules/DevEnvironment'
        Dependencies = @('Logging')
        Required = $false
        Description = 'Development environment management'
    }
    'BackupManager' = @{
        Path = './aither-core/modules/BackupManager'
        Dependencies = @('Logging')
        Required = $false
        Description = 'Backup and maintenance operations'
    }
}

function Test-ModuleImport {
    param(
        [string]$ModuleName,
        [hashtable]$ModuleInfo
    )
    
    $result = @{
        Name = $ModuleName
        Success = $false
        Functions = 0
        LoadTime = $null
        Dependencies = $ModuleInfo.Dependencies
        Error = $null
        Issues = @()
    }
    
    try {
        Write-Host "  Testing module: $ModuleName" -ForegroundColor Cyan
        
        # Check if module path exists
        if (-not (Test-Path $ModuleInfo.Path)) {
            $result.Error = "Module path not found: $($ModuleInfo.Path)"
            $result.Issues += "Missing module directory"
            return $result
        }
        
        # Check for manifest file
        $manifestPath = Join-Path $ModuleInfo.Path "$ModuleName.psd1"
        if (-not (Test-Path $manifestPath)) {
            $result.Issues += "Missing module manifest (.psd1)"
        }
        
        # Check for module script file
        $scriptPath = Join-Path $ModuleInfo.Path "$ModuleName.psm1"
        if (-not (Test-Path $scriptPath)) {
            $result.Issues += "Missing module script (.psm1)"
        }
        
        # Import dependencies first
        foreach ($dep in $ModuleInfo.Dependencies) {
            if ($dep -in $ModuleRegistry.Keys) {
                $depPath = $ModuleRegistry[$dep].Path
                Write-Host "    Loading dependency: $dep" -ForegroundColor Gray
                Import-Module $depPath -Force -Global -ErrorAction Stop
            }
        }
        
        # Measure import time
        $startTime = Get-Date
        Import-Module $ModuleInfo.Path -Force -Global -ErrorAction Stop
        $endTime = Get-Date
        
        $result.LoadTime = ($endTime - $startTime).TotalMilliseconds
        
        # Count exported functions
        $commands = Get-Command -Module $ModuleName -ErrorAction SilentlyContinue
        $result.Functions = $commands.Count
        
        # Verify some basic functionality if it's a critical module
        if ($ModuleName -eq 'Logging' -and (Get-Command 'Write-CustomLog' -ErrorAction SilentlyContinue)) {
            Write-CustomLog -Message "Test log from $ModuleName" -Level 'DEBUG'
        }
        
        $result.Success = $true
        Write-Host "    ✓ $ModuleName imported successfully ($($result.Functions) functions, $([math]::Round($result.LoadTime, 1))ms)" -ForegroundColor Green
        
    } catch {
        $result.Error = $_.Exception.Message
        Write-Host "    ✗ $ModuleName failed to import: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    return $result
}

function Test-ModuleDependencies {
    param([hashtable]$TestResults)
    
    Write-Host "`n=== Dependency Validation ===" -ForegroundColor Cyan
    
    $dependencyIssues = @()
    
    foreach ($moduleName in $TestResults.Keys) {
        $result = $TestResults[$moduleName]
        $moduleInfo = $ModuleRegistry[$moduleName]
        
        foreach ($dependency in $moduleInfo.Dependencies) {
            if ($dependency -notin $TestResults.Keys) {
                $dependencyIssues += "$moduleName depends on $dependency, but $dependency was not tested"
                continue
            }
            
            $depResult = $TestResults[$dependency]
            if (-not $depResult.Success) {
                $dependencyIssues += "$moduleName depends on $dependency, but $dependency failed to load"
            }
        }
    }
    
    if ($dependencyIssues.Count -eq 0) {
        Write-Host "✓ All dependencies resolved successfully" -ForegroundColor Green
    } else {
        Write-Host "⚠ Found $($dependencyIssues.Count) dependency issues:" -ForegroundColor Yellow
        foreach ($issue in $dependencyIssues) {
            Write-Host "  - $issue" -ForegroundColor Yellow
        }
    }
    
    return $dependencyIssues
}

try {
    Write-Host "=== Individual Module Testing ===" -ForegroundColor Cyan
    
    # Determine which modules to test
    $modulesToTest = if ($TestModules.Count -gt 0) {
        $TestModules | Where-Object { $_ -in $ModuleRegistry.Keys }
    } else {
        $ModuleRegistry.Keys
    }
    
    Write-Host "Testing $($modulesToTest.Count) modules..." -ForegroundColor Yellow
    
    $testResults = @{}
    $totalStartTime = Get-Date
    
    # Test each module individually
    foreach ($moduleName in $modulesToTest) {
        $moduleInfo = $ModuleRegistry[$moduleName]
        $testResults[$moduleName] = Test-ModuleImport -ModuleName $moduleName -ModuleInfo $moduleInfo
    }
    
    $totalEndTime = Get-Date
    $totalTime = ($totalEndTime - $totalStartTime).TotalSeconds
    
    # Analyze results
    Write-Host "`n=== Test Results Summary ===" -ForegroundColor Cyan
    
    $successful = ($testResults.Values | Where-Object { $_.Success }).Count
    $failed = ($testResults.Values | Where-Object { -not $_.Success }).Count
    $totalFunctions = ($testResults.Values | Measure-Object -Property Functions -Sum).Sum
    $avgLoadTime = ($testResults.Values | Where-Object { $_.LoadTime } | Measure-Object -Property LoadTime -Average).Average
    
    Write-Host "✓ Successfully imported: $successful modules" -ForegroundColor Green
    Write-Host "✗ Failed to import: $failed modules" -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Green' })
    Write-Host "📊 Total functions discovered: $totalFunctions" -ForegroundColor White
    Write-Host "⏱ Average load time: $([math]::Round($avgLoadTime, 1))ms" -ForegroundColor White
    Write-Host "🕐 Total test time: $([math]::Round($totalTime, 1))s" -ForegroundColor White
    
    # Show detailed results if requested
    if ($Detailed) {
        Write-Host "`nDetailed Results:" -ForegroundColor Cyan
        $testResults.Values | Sort-Object Name | Format-Table Name, Success, Functions, @{Name="LoadTime(ms)"; Expression={[math]::Round($_.LoadTime, 1)}}, @{Name="Issues"; Expression={$_.Issues -join "; "}} -AutoSize
    }
    
    # Test dependencies
    $dependencyIssues = Test-ModuleDependencies -TestResults $testResults
    
    # Test module integration points
    Write-Host "`n=== Integration Testing ===" -ForegroundColor Cyan
    
    $integrationTests = @()
    
    # Test Logging + other modules integration
    if ($testResults['Logging'].Success) {
        Write-Host "Testing Logging integration..." -ForegroundColor Yellow
        try {
            Write-CustomLog -Message "Integration test message" -Level 'INFO'
            $integrationTests += @{ Test = "Logging integration"; Success = $true }
            Write-Host "✓ Logging integration working" -ForegroundColor Green
        } catch {
            $integrationTests += @{ Test = "Logging integration"; Success = $false; Error = $_.Exception.Message }
            Write-Host "✗ Logging integration failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Test ConfigurationCore if available
    if ($testResults['ConfigurationCore'].Success) {
        Write-Host "Testing ConfigurationCore integration..." -ForegroundColor Yellow
        try {
            $configStore = Get-ConfigurationStore -ErrorAction SilentlyContinue
            $integrationTests += @{ Test = "ConfigurationCore integration"; Success = $true }
            Write-Host "✓ ConfigurationCore integration working" -ForegroundColor Green
        } catch {
            $integrationTests += @{ Test = "ConfigurationCore integration"; Success = $false; Error = $_.Exception.Message }
            Write-Host "✗ ConfigurationCore integration failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Final assessment
    Write-Host "`n=== Final Assessment ===" -ForegroundColor Cyan
    
    $criticalModulesFailed = ($testResults.Values | Where-Object { $_.Required -and -not $_.Success }).Count
    $overallSuccess = ($failed -eq 0 -and $dependencyIssues.Count -eq 0 -and $criticalModulesFailed -eq 0)
    
    if ($overallSuccess) {
        Write-Host "🎉 All individual module tests PASSED" -ForegroundColor Green
    } else {
        Write-Host "❌ Individual module tests had issues:" -ForegroundColor Red
        if ($criticalModulesFailed -gt 0) {
            Write-Host "  - $criticalModulesFailed critical modules failed" -ForegroundColor Red
        }
        if ($dependencyIssues.Count -gt 0) {
            Write-Host "  - $($dependencyIssues.Count) dependency issues" -ForegroundColor Red
        }
    }
    
    return @{
        Success = $overallSuccess
        TestResults = $testResults
        DependencyIssues = $dependencyIssues
        IntegrationTests = $integrationTests
        Summary = @{
            Successful = $successful
            Failed = $failed
            TotalFunctions = $totalFunctions
            AverageLoadTime = $avgLoadTime
            TotalTime = $totalTime
        }
    }
    
} catch {
    Write-Host "`n=== Individual Module Testing FAILED ===" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    
    return @{
        Success = $false
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    }
}