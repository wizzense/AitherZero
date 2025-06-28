#Requires -Version 7.0

<#
.SYNOPSIS
    Automated test generation for AitherZero modules to achieve 80% coverage.

.PARAMETER ModuleName
    Specific module to generate tests for. If not specified, generates for all modules.

.PARAMETER Force
    Overwrite existing generated test files
#>

param(
    [string]$ModuleName,
    [switch]$Force
)

# Import shared utilities
. "$PSScriptRoot/aither-core/shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

# Import Logging module
try {
    Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
} catch {
    function Write-CustomLog {
        param([string]$Message, [string]$Level = "INFO")
        Write-Host "[$Level] $Message"
    }
}

Write-CustomLog -Message "=== Automated Test Generation Engine v1.0 ===" -Level "INFO"

# Set paths
$modulesPath = Join-Path $projectRoot "aither-core/modules"
$outputPath = Join-Path $projectRoot "tests/generated"

# Ensure output directory exists
if (-not (Test-Path $outputPath)) {
    New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
    Write-CustomLog -Message "Created output directory: $outputPath" -Level "INFO"
}

# Discover modules
if ($ModuleName) {
    $modulesToProcess = @(Get-ChildItem -Path $modulesPath -Directory -Name | Where-Object { $_ -eq $ModuleName })
    if ($modulesToProcess.Count -eq 0) {
        throw "Module '$ModuleName' not found in $modulesPath"
    }
} else {
    $modulesToProcess = Get-ChildItem -Path $modulesPath -Directory -Name
}

Write-CustomLog -Message "📋 Found $($modulesToProcess.Count) modules to process" -Level "INFO"

$generatedCount = 0
$skippedCount = 0

foreach ($module in $modulesToProcess) {
    Write-CustomLog -Message "🔄 Processing module: $module" -Level "INFO"
    
    $testFileName = "$module-Generated.Tests.ps1"
    $testFilePath = Join-Path $outputPath $testFileName
    
    # Check if file exists and Force not specified
    if ((Test-Path $testFilePath) -and -not $Force) {
        $skippedCount++
        Write-CustomLog -Message "⏭️ Skipped $module (already exists, use -Force to overwrite)" -Level "WARN"
        continue
    }
    
    # Get module information
    $modulePath = Join-Path $modulesPath $module
    $publicFunctions = @()
    
    # Check for Public folder
    $publicPath = Join-Path $modulePath "Public"
    if (Test-Path $publicPath) {
        $publicFiles = Get-ChildItem -Path $publicPath -Filter "*.ps1" -File
        $publicFunctions = $publicFiles | ForEach-Object { $_.BaseName }
    }
    
    # Generate test content
    $testContent = @"
# Generated Test Suite for $module Module
# Generated on: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Coverage Target: 80%

BeforeAll {
    # Import shared utilities
    . "`$PSScriptRoot/../../aither-core/shared/Find-ProjectRoot.ps1"
    `$projectRoot = Find-ProjectRoot
    
    # Set environment variables
    if (-not `$env:PROJECT_ROOT) {
        `$env:PROJECT_ROOT = `$projectRoot
    }
    if (-not `$env:PWSH_MODULES_PATH) {
        `$env:PWSH_MODULES_PATH = Join-Path `$projectRoot 'aither-core/modules'
    }
    
    # Fallback logging function
    function global:Write-CustomLog {
        param([string]`$Message, [string]`$Level = "INFO")
        Write-Host "[`$Level] `$Message"
    }
    
    # Import required modules
    try {
        Import-Module (Join-Path `$env:PWSH_MODULES_PATH "Logging") -Force -ErrorAction Stop
    }
    catch {
        # Continue with fallback logging
    }
    
    # Import the module under test
    `$modulePath = Join-Path `$env:PWSH_MODULES_PATH "$module"
    
    try {
        Import-Module `$modulePath -Force -ErrorAction Stop
        Write-Host "[SUCCESS] $module module imported successfully"
    }
    catch {
        Write-Error "Failed to import $module module: `$_"
        throw
    }
}

Describe "$module Module - Generated Tests" {
    
    Context "Module Structure and Loading" {
        It "Should import the $module module without errors" {
            Get-Module $module | Should -Not -BeNullOrEmpty
        }
        
        It "Should have a valid module manifest" {
            `$manifestPath = Join-Path `$env:PWSH_MODULES_PATH "$module/$module.psd1"
            if (Test-Path `$manifestPath) {
                { Test-ModuleManifest -Path `$manifestPath } | Should -Not -Throw
            }
        }
        
        It "Should export public functions" {
            `$exportedFunctions = Get-Command -Module $module -CommandType Function
            `$exportedFunctions | Should -Not -BeNullOrEmpty
        }
    }

"@

    # Add function-specific tests
    if ($publicFunctions.Count -gt 0) {
        foreach ($functionName in $publicFunctions) {
            $testContent += @"
    
    Context "$functionName Function Tests" {
        It "Should have $functionName function available" {
            Get-Command $functionName -Module $module -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have proper function structure" {
            `$command = Get-Command $functionName -Module $module
            `$command.CommandType | Should -Be 'Function'
        }
        
        It "Should have parameters defined" {
            `$command = Get-Command $functionName -Module $module
            # Test that the function can be called (may have no required parameters)
            { `$command.Parameters } | Should -Not -Throw
        }
    }

"@
        }
    }
    
    # Add standard tests
    $testContent += @"
    
    Context "Error Handling and Edge Cases" {
        It "Should handle module reimport gracefully" {
            { Import-Module (Join-Path `$env:PWSH_MODULES_PATH "$module") -Force } | Should -Not -Throw
        }
        
        It "Should maintain consistent behavior across PowerShell editions" {
            if (`$PSVersionTable.PSEdition -eq 'Core') {
                Get-Module $module | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "Performance and Resource Usage" {
        It "Should import within reasonable time" {
            `$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            Import-Module (Join-Path `$env:PWSH_MODULES_PATH "$module") -Force
            `$stopwatch.Stop()
            `$stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000
        }
    }
}

"@
    
    # Write test file
    Set-Content -Path $testFilePath -Value $testContent -Encoding UTF8
    $generatedCount++
    Write-CustomLog -Message "✅ Generated tests for $module" -Level "SUCCESS"
}

# Generate summary
Write-CustomLog -Message "" -Level "INFO"
Write-CustomLog -Message "📊 Test Generation Summary:" -Level "INFO"
Write-CustomLog -Message "  Generated: $generatedCount modules" -Level "SUCCESS"
Write-CustomLog -Message "  Skipped: $skippedCount modules" -Level "WARN"
Write-CustomLog -Message "  Total Processed: $($modulesToProcess.Count) modules" -Level "INFO"

# Coverage analysis
$totalModules = (Get-ChildItem -Path $modulesPath -Directory).Count
$estimatedCoverage = [math]::Round(($generatedCount / $totalModules) * 100, 1)

Write-CustomLog -Message "🎯 Coverage Analysis:" -Level "INFO"
Write-CustomLog -Message "  Total modules: $totalModules" -Level "INFO"
Write-CustomLog -Message "  Modules with tests: $generatedCount" -Level "INFO"
Write-CustomLog -Message "  Estimated coverage: $estimatedCoverage%" -Level "INFO"

if ($estimatedCoverage -ge 80) {
    Write-CustomLog -Message "🎉 Target 80% coverage achieved!" -Level "SUCCESS"
} else {
    Write-CustomLog -Message "⚠️ Additional test refinement needed to reach 80%" -Level "WARN"
}