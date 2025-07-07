#Requires -Version 7.0

<#
.SYNOPSIS
    Generates a comprehensive test coverage report for AitherZero modules
.DESCRIPTION
    Analyzes all modules to identify which functions have tests and which don't,
    providing detailed coverage metrics and recommendations
.PARAMETER ModuleName
    Specific module to analyze (default: all modules)
.PARAMETER OutputFormat
    Output format: Console, Markdown, or JSON (default: Console)
.PARAMETER IncludePrivateFunctions
    Include private functions in the analysis
#>

param(
    [string]$ModuleName = "*",
    [ValidateSet("Console", "Markdown", "JSON")]
    [string]$OutputFormat = "Console",
    [switch]$IncludePrivateFunctions
)

# Find project root
$projectRoot = Join-Path $PSScriptRoot "../.."
$modulesPath = Join-Path $projectRoot "aither-core/modules"

# Coverage data structure
$coverageData = @{
    Summary = @{
        TotalModules = 0
        ModulesWithTests = 0
        TotalFunctions = 0
        TestedFunctions = 0
        CoveragePercentage = 0
    }
    Modules = @{}
}

# Get all modules
$modules = Get-ChildItem -Path $modulesPath -Directory | 
    Where-Object { $_.Name -notmatch '^\.' -and $_.Name -like $ModuleName }

foreach ($module in $modules) {
    $coverageData.Summary.TotalModules++
    
    $moduleData = @{
        Name = $module.Name
        HasTests = $false
        TestFile = $null
        ExportedFunctions = @()
        TestedFunctions = @()
        UntestedFunctions = @()
        CoveragePercentage = 0
    }
    
    # Check for module manifest
    $manifestPath = Join-Path $module.FullName "$($module.Name).psd1"
    if (Test-Path $manifestPath) {
        # Get exported functions from manifest
        $manifest = Import-PowerShellDataFile $manifestPath
        $exportedFunctions = $manifest.FunctionsToExport
        
        if ($exportedFunctions -and $exportedFunctions -ne @('*')) {
            $moduleData.ExportedFunctions = $exportedFunctions
            $coverageData.Summary.TotalFunctions += $exportedFunctions.Count
        }
    }
    
    # Check for test file
    $testPaths = @(
        (Join-Path $module.FullName "tests" "$($module.Name).Tests.ps1"),
        (Join-Path $projectRoot "tests/modules" "$($module.Name).Tests.ps1"),
        (Join-Path $projectRoot "tests/unit/modules" "$($module.Name).Tests.ps1"),
        (Join-Path $projectRoot "tests" "$($module.Name).Tests.ps1")
    )
    
    foreach ($testPath in $testPaths) {
        if (Test-Path $testPath) {
            $moduleData.HasTests = $true
            $moduleData.TestFile = $testPath
            $coverageData.Summary.ModulesWithTests++
            
            # Analyze test file for function coverage
            $testContent = Get-Content $testPath -Raw
            
            foreach ($function in $moduleData.ExportedFunctions) {
                # Check if function is mentioned in tests (basic heuristic)
                if ($testContent -match "\b$function\b") {
                    $moduleData.TestedFunctions += $function
                    $coverageData.Summary.TestedFunctions++
                } else {
                    $moduleData.UntestedFunctions += $function
                }
            }
            
            break
        }
    }
    
    # If no tests found, all functions are untested
    if (-not $moduleData.HasTests) {
        $moduleData.UntestedFunctions = $moduleData.ExportedFunctions
    }
    
    # Calculate module coverage
    if ($moduleData.ExportedFunctions.Count -gt 0) {
        $moduleData.CoveragePercentage = [math]::Round(
            ($moduleData.TestedFunctions.Count / $moduleData.ExportedFunctions.Count) * 100, 2
        )
    }
    
    $coverageData.Modules[$module.Name] = $moduleData
}

# Calculate overall coverage
if ($coverageData.Summary.TotalFunctions -gt 0) {
    $coverageData.Summary.CoveragePercentage = [math]::Round(
        ($coverageData.Summary.TestedFunctions / $coverageData.Summary.TotalFunctions) * 100, 2
    )
}

# Output results based on format
switch ($OutputFormat) {
    "Console" {
        Write-Host "`n=== AitherZero Test Coverage Report ===" -ForegroundColor Cyan
        Write-Host "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
        
        Write-Host "`n📊 Summary" -ForegroundColor Yellow
        Write-Host "Total Modules: $($coverageData.Summary.TotalModules)"
        Write-Host "Modules with Tests: $($coverageData.Summary.ModulesWithTests) ($([math]::Round($coverageData.Summary.ModulesWithTests / $coverageData.Summary.TotalModules * 100, 2))%)"
        Write-Host "Total Functions: $($coverageData.Summary.TotalFunctions)"
        Write-Host "Tested Functions: $($coverageData.Summary.TestedFunctions) ($($coverageData.Summary.CoveragePercentage)%)"
        
        Write-Host "`n📋 Modules Without Tests" -ForegroundColor Red
        $modulesWithoutTests = $coverageData.Modules.Values | Where-Object { -not $_.HasTests }
        foreach ($module in $modulesWithoutTests | Sort-Object Name) {
            Write-Host "  ❌ $($module.Name) - $($module.ExportedFunctions.Count) functions untested"
        }
        
        Write-Host "`n📈 Module Coverage Details" -ForegroundColor Yellow
        foreach ($module in $coverageData.Modules.Values | Sort-Object CoveragePercentage -Descending) {
            $emoji = if ($module.CoveragePercentage -eq 100) { "✅" }
                    elseif ($module.CoveragePercentage -ge 80) { "🟢" }
                    elseif ($module.CoveragePercentage -ge 50) { "🟡" }
                    else { "🔴" }
            
            Write-Host "$emoji $($module.Name): $($module.CoveragePercentage)% ($($module.TestedFunctions.Count)/$($module.ExportedFunctions.Count) functions)"
            
            if ($module.UntestedFunctions.Count -gt 0 -and $module.UntestedFunctions.Count -le 5) {
                Write-Host "   Untested: $($module.UntestedFunctions -join ', ')" -ForegroundColor DarkGray
            } elseif ($module.UntestedFunctions.Count -gt 5) {
                Write-Host "   Untested: $($module.UntestedFunctions[0..4] -join ', '), and $($module.UntestedFunctions.Count - 5) more..." -ForegroundColor DarkGray
            }
        }
        
        Write-Host "`n🎯 Priority Recommendations" -ForegroundColor Green
        Write-Host "1. Add tests for modules without any test coverage"
        Write-Host "2. Focus on high-risk modules: SecureCredentials, OpenTofuProvider, ConfigurationRepository"
        Write-Host "3. Increase coverage for modules below 50%"
        Write-Host "4. Add integration tests for cross-module functionality"
    }
    
    "Markdown" {
        $markdown = @"
# AitherZero Test Coverage Report

Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## 📊 Summary

| Metric | Value | Percentage |
|--------|-------|------------|
| Total Modules | $($coverageData.Summary.TotalModules) | - |
| Modules with Tests | $($coverageData.Summary.ModulesWithTests) | $([math]::Round($coverageData.Summary.ModulesWithTests / $coverageData.Summary.TotalModules * 100, 2))% |
| Total Functions | $($coverageData.Summary.TotalFunctions) | - |
| Tested Functions | $($coverageData.Summary.TestedFunctions) | $($coverageData.Summary.CoveragePercentage)% |

## 📋 Modules Without Tests

"@
        $modulesWithoutTests = $coverageData.Modules.Values | Where-Object { -not $_.HasTests }
        foreach ($module in $modulesWithoutTests | Sort-Object Name) {
            $markdown += "- **$($module.Name)** - $($module.ExportedFunctions.Count) functions untested`n"
        }
        
        $markdown += @"

## 📈 Module Coverage Details

| Module | Coverage | Tested/Total | Status |
|--------|----------|--------------|--------|
"@
        foreach ($module in $coverageData.Modules.Values | Sort-Object CoveragePercentage -Descending) {
            $status = if ($module.CoveragePercentage -eq 100) { "✅ Complete" }
                     elseif ($module.CoveragePercentage -ge 80) { "🟢 Good" }
                     elseif ($module.CoveragePercentage -ge 50) { "🟡 Moderate" }
                     else { "🔴 Low" }
            
            $markdown += "| $($module.Name) | $($module.CoveragePercentage)% | $($module.TestedFunctions.Count)/$($module.ExportedFunctions.Count) | $status |`n"
        }
        
        $markdown += @"

## 🔍 Untested Functions by Module

"@
        foreach ($module in $coverageData.Modules.Values | Where-Object { $_.UntestedFunctions.Count -gt 0 } | Sort-Object Name) {
            $markdown += "### $($module.Name)`n`n"
            foreach ($function in $module.UntestedFunctions) {
                $markdown += "- ``$function```n"
            }
            $markdown += "`n"
        }
        
        Write-Output $markdown
    }
    
    "JSON" {
        $coverageData | ConvertTo-Json -Depth 5
    }
}

# Return coverage data for programmatic use
return $coverageData