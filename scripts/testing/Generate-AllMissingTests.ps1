#Requires -Version 7.0

<#
.SYNOPSIS
    Generates test files for all modules that don't have tests

.DESCRIPTION
    This script crawls all AitherZero modules and automatically generates comprehensive 
    test files for modules that don't have tests. It uses intelligent templates based 
    on module type analysis (Manager, Provider, Core, Utility).
    
    Implements the "spawn subagents" approach by using parallel execution to generate
    multiple test files concurrently.

.PARAMETER MaxConcurrency
    Maximum number of test generation operations to run in parallel (default: 5)

.PARAMETER ModuleNames
    Specific modules to generate tests for (default: all modules without tests)

.PARAMETER Force
    Overwrite existing test files

.PARAMETER WhatIf
    Show what would be generated without actually creating files

.EXAMPLE
    ./Generate-AllMissingTests.ps1
    Generates tests for all modules missing tests

.EXAMPLE
    ./Generate-AllMissingTests.ps1 -ModuleNames @("PatchManager", "OpenTofuProvider") -Force
    Generate tests for specific modules, overwriting existing files

.EXAMPLE
    ./Generate-AllMissingTests.ps1 -WhatIf
    Preview what tests would be generated

.NOTES
    This script implements the user's request for "documentation and tests will no longer 
    live separately from the code they exist for in the first place" by creating co-located
    test files in each module's directory.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [int]$MaxConcurrency = 5,
    
    [Parameter()]
    [string[]]$ModuleNames = @(),
    
    [Parameter()]
    [switch]$Force,
    
    [Parameter()]
    [switch]$WhatIf
)

# Initialize script
$ErrorActionPreference = 'Stop'
$startTime = Get-Date

# Find project root
$projectRoot = $PSScriptRoot
while ($projectRoot -and -not (Test-Path (Join-Path $projectRoot ".git"))) {
    $projectRoot = Split-Path $projectRoot -Parent
}

if (-not $projectRoot) {
    throw "Could not find project root (no .git directory found)"
}

Write-Host "🧪 AitherZero Distributed Test Generation" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Project Root: $projectRoot" -ForegroundColor Gray
Write-Host "Max Concurrency: $MaxConcurrency" -ForegroundColor Gray
Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

try {
    # Import TestingFramework module
    $testingFrameworkPath = Join-Path $projectRoot "aither-core/modules/TestingFramework"
    if (-not (Test-Path $testingFrameworkPath)) {
        throw "TestingFramework module not found at: $testingFrameworkPath"
    }
    
    Write-Host "📦 Importing TestingFramework module..." -ForegroundColor Yellow
    Import-Module $testingFrameworkPath -Force
    
    # Discover modules without tests
    Write-Host "🔍 Discovering modules without tests..." -ForegroundColor Yellow
    $allModules = Get-DiscoveredModules -IncludeDistributedTests:$true -IncludeCentralizedTests:$false
    $modulesWithoutTests = $allModules | Where-Object { $_.TestDiscovery.TestStrategy -eq "None" }
    
    if ($ModuleNames.Count -gt 0) {
        $modulesWithoutTests = $modulesWithoutTests | Where-Object { $_.Name -in $ModuleNames }
        Write-Host "🎯 Filtering to specific modules: $($ModuleNames -join ', ')" -ForegroundColor Cyan
    }
    
    Write-Host ""
    Write-Host "📊 Discovery Results:" -ForegroundColor Green
    Write-Host "  Total modules found: $($allModules.Count)" -ForegroundColor White
    Write-Host "  Modules with distributed tests: $(($allModules | Where-Object { $_.TestDiscovery.TestStrategy -eq 'Distributed' }).Count)" -ForegroundColor Green
    Write-Host "  Modules with centralized tests: $(($allModules | Where-Object { $_.TestDiscovery.TestStrategy -eq 'Centralized' }).Count)" -ForegroundColor Blue
    Write-Host "  Modules without tests: $($modulesWithoutTests.Count)" -ForegroundColor Red
    Write-Host ""
    
    if ($modulesWithoutTests.Count -eq 0) {
        Write-Host "✅ All modules already have tests! Nothing to generate." -ForegroundColor Green
        return
    }
    
    # Display modules that will get tests
    Write-Host "🎯 Modules that will get test files:" -ForegroundColor Yellow
    foreach ($module in $modulesWithoutTests) {
        $moduleAnalysis = Get-ModuleAnalysis -ModulePath $module.Path -ModuleName $module.Name
        $templateType = switch ($moduleAnalysis.ModuleType) {
            "Manager" { "Manager Template (management operations)" }
            "Provider" { "Provider Template (resource operations)" }
            "Core" { "Core Template (framework functionality)" }
            default { "Utility Template (general functionality)" }
        }
        Write-Host "  📁 $($module.Name) - $templateType" -ForegroundColor Gray
    }
    Write-Host ""
    
    if ($WhatIf) {
        Write-Host "🔮 WhatIf Mode: Test generation simulation completed" -ForegroundColor Magenta
        Write-Host "   Run without -WhatIf to actually generate the test files" -ForegroundColor Gray
        return
    }
    
    # Confirm before proceeding (unless Force is specified)
    if (-not $Force -and -not $PSCmdlet.ShouldContinue("Generate test files for $($modulesWithoutTests.Count) modules?", "Test Generation Confirmation")) {
        Write-Host "❌ Test generation cancelled by user" -ForegroundColor Yellow
        return
    }
    
    # Generate tests using bulk generation
    Write-Host "🏭 Starting bulk test generation with $MaxConcurrency concurrent operations..." -ForegroundColor Cyan
    Write-Host ""
    
    $generationParams = @{
        ModuleNames = $modulesWithoutTests.Name
        MaxConcurrency = $MaxConcurrency
        Force = $Force.IsPresent
        Verbose = $VerbosePreference -eq 'Continue'
    }
    
    $results = Invoke-BulkTestGeneration @generationParams
    
    # Process results
    $successful = $results | Where-Object { $_.Success }
    $failed = $results | Where-Object { -not $_.Success }
    
    Write-Host ""
    Write-Host "📈 Test Generation Results:" -ForegroundColor Green
    Write-Host "===============================================" -ForegroundColor Green
    Write-Host "✅ Successfully generated: $($successful.Count) test files" -ForegroundColor Green
    Write-Host "❌ Failed: $($failed.Count) test files" -ForegroundColor $(if($failed.Count -gt 0){'Red'}else{'Green'})"
    
    if ($successful.Count -gt 0) {
        Write-Host ""
        Write-Host "📋 Successfully Generated Tests:" -ForegroundColor Green
        foreach ($result in $successful) {
            Write-Host "  ✅ $($result.ModuleName)" -ForegroundColor Green
        }
    }
    
    if ($failed.Count -gt 0) {
        Write-Host ""
        Write-Host "💥 Failed Generations:" -ForegroundColor Red
        foreach ($result in $failed) {
            Write-Host "  ❌ $($result.ModuleName): $($result.Error)" -ForegroundColor Red
        }
    }
    
    # Calculate execution time
    $executionTime = (Get-Date) - $startTime
    Write-Host ""
    Write-Host "⏱️  Total execution time: $($executionTime.TotalSeconds) seconds" -ForegroundColor Cyan
    
    # Provide next steps
    Write-Host ""
    Write-Host "🚀 Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Review generated test files and customize them for your modules" -ForegroundColor White
    Write-Host "  2. Run tests to verify they work: ./tests/Run-Tests.ps1 -All" -ForegroundColor White
    Write-Host "  3. Add specific test cases for your module's functionality" -ForegroundColor White
    Write-Host "  4. Remove TODO comments and implement actual tests" -ForegroundColor White
    Write-Host ""
    Write-Host "📖 Test files follow the pattern: {ModuleName}/tests/{ModuleName}.Tests.ps1" -ForegroundColor Cyan
    Write-Host "🧪 Templates are optimized for AI + Human engineering teams" -ForegroundColor Cyan
    
    if ($successful.Count -gt 0) {
        Write-Host ""
        Write-Host "🎉 Distributed test generation completed successfully!" -ForegroundColor Green
        Write-Host "Documentation and tests now live with the code they test! 🤝" -ForegroundColor Green
    }
    
} catch {
    Write-Host ""
    Write-Host "💥 Error during test generation:" -ForegroundColor Red
    Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "🔧 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Ensure you're running from the project root" -ForegroundColor White
    Write-Host "  2. Verify TestingFramework module is available" -ForegroundColor White
    Write-Host "  3. Check that templates exist in scripts/testing/templates/" -ForegroundColor White
    
    exit 1
}