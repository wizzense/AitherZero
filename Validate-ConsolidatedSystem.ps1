#Requires -Version 7.0
<#
.SYNOPSIS
    Validate the consolidated AitherZero system
.DESCRIPTION
    Comprehensive validation script to ensure the consolidated architecture
    works correctly and maintains backward compatibility.
.NOTES
    Run this after implementing the consolidated architecture to validate
    all functionality is preserved.
#>

[CmdletBinding()]
param(
    [switch]$Detailed,
    [switch]$ExportReport
)

$ErrorActionPreference = 'Stop'
$results = @{
    Timestamp = Get-Date
    Tests = @()
    Summary = @{
        Total = 0
        Passed = 0
        Failed = 0
        Warnings = 0
    }
}

function Test-ModuleLoading {
    Write-Host "🔍 Testing consolidated module loading..." -ForegroundColor Cyan
    
    $test = @{
        Name = "Module Loading"
        Status = "Unknown"
        Details = @()
        Errors = @()
    }
    
    try {
        # Test new consolidated module system
        Import-Module "./AitherZero-New.psm1" -Force -ErrorAction Stop
        $test.Details += "✅ AitherZero-New.psm1 loaded successfully"
        
        # Test critical functions are available
        $criticalFunctions = @(
            'Write-CustomLog',
            'Get-Configuration', 
            'Show-BetterMenu',
            'Invoke-OrchestrationSequence',
            'Test-OpenTofu',
            'Initialize-TestFramework'
        )
        
        foreach ($func in $criticalFunctions) {
            if (Get-Command $func -ErrorAction SilentlyContinue) {
                $test.Details += "✅ Function available: $func"
            } else {
                $test.Errors += "❌ Missing function: $func"
            }
        }
        
        # Test az alias
        if (Get-Alias az -ErrorAction SilentlyContinue) {
            $test.Details += "✅ 'az' alias configured correctly"
        } else {
            $test.Errors += "❌ 'az' alias not found"
        }
        
        $test.Status = if ($test.Errors.Count -eq 0) { "Passed" } else { "Failed" }
    }
    catch {
        $test.Status = "Failed"
        $test.Errors += "❌ Module loading failed: $($_.Exception.Message)"
    }
    
    return $test
}

function Test-AutomationScripts {
    Write-Host "🔍 Testing automation script execution..." -ForegroundColor Cyan
    
    $test = @{
        Name = "Automation Scripts"
        Status = "Unknown"
        Details = @()
        Errors = @()
    }
    
    try {
        # Test duplicate numbers are fixed
        $duplicates = Get-ChildItem "./automation-scripts/" -Name "*.ps1" | 
            ForEach-Object { $_ -replace "_.*", "" } | 
            Group-Object | Where-Object { $_.Count -gt 1 }
            
        if ($duplicates.Count -eq 0) {
            $test.Details += "✅ No duplicate script numbers found"
        } else {
            $test.Errors += "❌ Found duplicate numbers: $($duplicates.Name -join ', ')"
        }
        
        # Test az command with dry run
        $azTest = & { az 0402 -DryRun 2>&1 }
        if ($LASTEXITCODE -eq 0) {
            $test.Details += "✅ 'az 0402 -DryRun' executed successfully" 
        } else {
            $test.Errors += "❌ 'az 0402 -DryRun' failed with exit code $LASTEXITCODE"
        }
        
        $test.Status = if ($test.Errors.Count -eq 0) { "Passed" } else { "Failed" }
    }
    catch {
        $test.Status = "Failed"
        $test.Errors += "❌ Script testing failed: $($_.Exception.Message)"
    }
    
    return $test
}

function Test-PlaybookSystem {
    Write-Host "🔍 Testing orchestration playbooks..." -ForegroundColor Cyan
    
    $test = @{
        Name = "Playbook System"
        Status = "Unknown"
        Details = @()
        Errors = @()
    }
    
    try {
        # Test new playbook structure
        if (Test-Path "./orchestration-new") {
            $test.Details += "✅ New orchestration structure exists"
            
            $categories = @("setup", "testing", "development", "deployment")
            foreach ($category in $categories) {
                $categoryPath = "./orchestration-new/$category"
                if (Test-Path $categoryPath) {
                    $test.Details += "✅ Category exists: $category"
                    
                    $playbooks = Get-ChildItem $categoryPath -Filter "*.json" -ErrorAction SilentlyContinue
                    if ($playbooks.Count -gt 0) {
                        $test.Details += "✅ Found $($playbooks.Count) playbook(s) in $category"
                    }
                } else {
                    $test.Errors += "❌ Missing category: $category"
                }
            }
        } else {
            $test.Errors += "❌ New orchestration structure not found"
        }
        
        # Test orchestration function
        if (Get-Command Invoke-OrchestrationSequence -ErrorAction SilentlyContinue) {
            $test.Details += "✅ Orchestration function available"
        } else {
            $test.Errors += "❌ Orchestration function missing"
        }
        
        $test.Status = if ($test.Errors.Count -eq 0) { "Passed" } else { "Failed" }
    }
    catch {
        $test.Status = "Failed" 
        $test.Errors += "❌ Playbook testing failed: $($_.Exception.Message)"
    }
    
    return $test
}

function Test-ConsolidatedDomains {
    Write-Host "🔍 Testing consolidated domain structure..." -ForegroundColor Cyan
    
    $test = @{
        Name = "Consolidated Domains"
        Status = "Unknown"
        Details = @()
        Errors = @()
    }
    
    try {
        # Test new domain structure
        if (Test-Path "./domains-new") {
            $test.Details += "✅ New domains structure exists"
            
            $expectedDomains = @{
                "core" = @("Configuration.psm1", "Logging.psm1")
                "interface" = @("UserInterface.psm1")
                "development" = @("DevTools.psm1") 
                "automation" = @("Orchestration.psm1")
                "infrastructure" = @("Infrastructure.psm1")
            }
            
            foreach ($domain in $expectedDomains.Keys) {
                $domainPath = "./domains-new/$domain"
                if (Test-Path $domainPath) {
                    $test.Details += "✅ Domain exists: $domain"
                    
                    foreach ($module in $expectedDomains[$domain]) {
                        $modulePath = "$domainPath/$module"
                        if (Test-Path $modulePath) {
                            $test.Details += "✅ Module exists: $domain/$module"
                        } else {
                            $test.Errors += "❌ Missing module: $domain/$module"
                        }
                    }
                } else {
                    $test.Errors += "❌ Missing domain: $domain"
                }
            }
        } else {
            $test.Errors += "❌ New domains structure not found"
        }
        
        $test.Status = if ($test.Errors.Count -eq 0) { "Passed" } else { "Failed" }
    }
    catch {
        $test.Status = "Failed"
        $test.Errors += "❌ Domain testing failed: $($_.Exception.Message)"
    }
    
    return $test
}

function Test-BackwardCompatibility {
    Write-Host "🔍 Testing backward compatibility..." -ForegroundColor Cyan
    
    $test = @{
        Name = "Backward Compatibility" 
        Status = "Unknown"
        Details = @()
        Errors = @()
    }
    
    try {
        # Test that original functionality still works
        $originalFunctions = @(
            'Invoke-AitherScript'
        )
        
        foreach ($func in $originalFunctions) {
            if (Get-Command $func -ErrorAction SilentlyContinue) {
                $test.Details += "✅ Legacy function available: $func"
            } else {
                $test.Errors += "❌ Missing legacy function: $func"
            }
        }
        
        # Test original config loading
        if (Test-Path "./config.psd1") {
            $test.Details += "✅ Original config file still accessible"
        }
        
        # Test original automation-scripts still work
        if (Test-Path "./automation-scripts") {
            $scriptCount = (Get-ChildItem "./automation-scripts" -Filter "*.ps1").Count
            $test.Details += "✅ Original automation-scripts directory ($scriptCount scripts)"
        }
        
        $test.Status = if ($test.Errors.Count -eq 0) { "Passed" } else { "Failed" }
    }
    catch {
        $test.Status = "Failed"
        $test.Errors += "❌ Compatibility testing failed: $($_.Exception.Message)"
    }
    
    return $test
}

# Run all tests
Write-Host "🚀 AitherZero Consolidated System Validation" -ForegroundColor Green
Write-Host "=" * 50

$tests = @(
    (Test-ModuleLoading),
    (Test-AutomationScripts),
    (Test-PlaybookSystem),
    (Test-ConsolidatedDomains),
    (Test-BackwardCompatibility)
)

foreach ($test in $tests) {
    $results.Tests += $test
    $results.Summary.Total++
    
    switch ($test.Status) {
        "Passed" { 
            $results.Summary.Passed++
            Write-Host "✅ $($test.Name): PASSED" -ForegroundColor Green
        }
        "Failed" { 
            $results.Summary.Failed++
            Write-Host "❌ $($test.Name): FAILED" -ForegroundColor Red
        }
        default { 
            $results.Summary.Warnings++
            Write-Host "⚠️ $($test.Name): UNKNOWN" -ForegroundColor Yellow
        }
    }
    
    if ($Detailed) {
        foreach ($detail in $test.Details) {
            Write-Host "   $detail" -ForegroundColor Gray
        }
        foreach ($error in $test.Errors) {
            Write-Host "   $error" -ForegroundColor Red
        }
        Write-Host ""
    }
}

# Display summary
Write-Host "`n📊 Validation Summary:" -ForegroundColor Cyan
Write-Host "Total Tests: $($results.Summary.Total)"
Write-Host "Passed: $($results.Summary.Passed)" -ForegroundColor Green
Write-Host "Failed: $($results.Summary.Failed)" -ForegroundColor Red  
Write-Host "Warnings: $($results.Summary.Warnings)" -ForegroundColor Yellow

$successRate = [math]::Round(($results.Summary.Passed / $results.Summary.Total) * 100, 1)
Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 80) { "Green" } else { "Red" })

# Export report if requested
if ($ExportReport) {
    $reportPath = "./validation-report-$(Get-Date -Format 'yyyy-MM-dd-HHmm').json"
    $results | ConvertTo-Json -Depth 10 | Set-Content $reportPath -Encoding UTF8
    Write-Host "`n📄 Report exported to: $reportPath" -ForegroundColor Cyan
}

# Exit with appropriate code
if ($results.Summary.Failed -gt 0) {
    Write-Host "`n❌ Validation completed with failures" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n✅ Validation completed successfully" -ForegroundColor Green
    exit 0
}