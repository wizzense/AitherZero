#Requires -Version 7.0

<#
.SYNOPSIS
    Automatically generates comprehensive test files for modules lacking tests

.DESCRIPTION
    This function analyzes modules in the AitherZero project and automatically generates
    standardized test files for modules that don't have existing tests. It uses intelligent
    template selection based on module type and structure.

.PARAMETER ModuleName
    Specific module name to generate tests for

.PARAMETER ModuleType
    Force a specific module type template (Manager, Provider, Core, Utility, Critical)

.PARAMETER Force
    Overwrite existing test files

.PARAMETER UseDistributedTests
    Generate tests in module directories rather than centralized location

.PARAMETER IncludeIntegrationTests
    Also generate integration test files

.PARAMETER IncludePerformanceTests
    Generate performance test suites for critical modules

.PARAMETER DryRun
    Show what would be generated without actually creating files

.EXAMPLE
    Invoke-AutomatedTestGeneration -ModuleName "ProgressTracking"

.EXAMPLE
    Invoke-AutomatedTestGeneration -Force -UseDistributedTests -IncludeIntegrationTests

.EXAMPLE
    Invoke-AutomatedTestGeneration -DryRun -ModuleName "PatchManager" -ModuleType "Critical"
#>

function Invoke-AutomatedTestGeneration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string]$ModuleName,

        [Parameter()]
        [ValidateSet("Manager", "Provider", "Core", "Utility", "Critical")]
        [string]$ModuleType,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$UseDistributedTests = $true,

        [Parameter()]
        [switch]$IncludeIntegrationTests,

        [Parameter()]
        [switch]$IncludePerformanceTests,

        [Parameter()]
        [switch]$DryRun
    )

    begin {
        # Find project root
        $projectRoot = $PSScriptRoot
        while ($projectRoot -and -not (Test-Path (Join-Path $projectRoot ".git"))) {
            $projectRoot = Split-Path $projectRoot -Parent
        }

        if (-not $projectRoot) {
            throw "Could not find project root directory"
        }

        Write-TestLog "🚀 Starting automated test generation" -Level "INFO"

        # Template directory
        $templateDir = Join-Path $projectRoot "scripts/testing/templates"
        if (-not (Test-Path $templateDir)) {
            throw "Template directory not found: $templateDir"
        }

        # Load template mappings
        $templateMappings = @{
            "Manager" = "manager-module-test-template.ps1"
            "Provider" = "provider-module-test-template.ps1"
            "Core" = "module-test-template.ps1"
            "Utility" = "module-test-template.ps1"
            "Critical" = "critical-module-test-template.ps1"
        }

        $integrationTemplate = "integration-test-template.ps1"
        $criticalModules = @("ProgressTracking", "ModuleCommunication", "SetupWizard", "TestingFramework", "Logging", "ConfigurationCore")

        $results = @{
            Generated = @()
            Skipped = @()
            Errors = @()
            Summary = @{
                Total = 0
                Generated = 0
                Skipped = 0
                Errors = 0
            }
        }
    }

    process {
        try {
            # Discover modules
            $modules = if ($ModuleName) {
                # Single module
                $modulePath = Join-Path $projectRoot "aither-core/modules/$ModuleName"
                if (Test-Path $modulePath) {
                    @(Get-ModuleForTesting -ModulePath $modulePath -ModuleName $ModuleName)
                } else {
                    throw "Module not found: $ModuleName"
                }
            } else {
                # All modules
                Get-ModulesForTesting -ProjectRoot $projectRoot
            }

            Write-TestLog "Found $($modules.Count) modules to process" -Level "INFO"

            foreach ($module in $modules) {
                $results.Summary.Total++
                
                Write-TestLog "Processing module: $($module.Name)" -Level "INFO"

                try {
                    # Analyze module
                    $moduleAnalysis = Get-ModuleAnalysis -ModulePath $module.Path -ModuleName $module.Name

                    # Determine template type
                    $templateType = if ($ModuleType) {
                        $ModuleType
                    } elseif ($module.Name -in $criticalModules) {
                        "Critical"
                    } else {
                        Get-OptimalTemplateType -ModuleAnalysis $moduleAnalysis
                    }

                    # Check if tests already exist
                    $testExists = Test-ModuleHasTests -ModulePath $module.Path -ModuleName $module.Name -UseDistributedTests:$UseDistributedTests

                    if ($testExists -and -not $Force) {
                        Write-TestLog "⚠️  Tests already exist for $($module.Name), skipping (use -Force to overwrite)" -Level "WARN"
                        $results.Skipped += @{
                            Module = $module.Name
                            Reason = "Tests already exist"
                        }
                        $results.Summary.Skipped++
                        continue
                    }

                    # Generate main test file
                    $testGenerated = $false
                    if ($PSCmdlet.ShouldProcess($module.Name, "Generate test file")) {
                        if (-not $DryRun) {
                            $testGenerated = New-ModuleTestFile -ModuleAnalysis $moduleAnalysis -TemplateType $templateType -TemplateDirectory $templateDir -UseDistributedTests:$UseDistributedTests -Force:$Force
                        } else {
                            Write-TestLog "🔍 DRY RUN: Would generate $templateType test for $($module.Name)" -Level "INFO"
                            $testGenerated = $true
                        }
                    }

                    if ($testGenerated) {
                        $results.Generated += @{
                            Module = $module.Name
                            TemplateType = $templateType
                            TestLocation = if ($UseDistributedTests) { "Distributed" } else { "Centralized" }
                        }
                        $results.Summary.Generated++
                    }

                    # Generate integration tests if requested
                    if ($IncludeIntegrationTests) {
                        if ($PSCmdlet.ShouldProcess($module.Name, "Generate integration test file")) {
                            if (-not $DryRun) {
                                $integrationGenerated = New-IntegrationTestFile -ModuleAnalysis $moduleAnalysis -TemplateDirectory $templateDir -ProjectRoot $projectRoot -Force:$Force
                            } else {
                                Write-TestLog "🔍 DRY RUN: Would generate integration test for $($module.Name)" -Level "INFO"
                                $integrationGenerated = $true
                            }

                            if ($integrationGenerated) {
                                $results.Generated += @{
                                    Module = $module.Name
                                    TemplateType = "Integration"
                                    TestLocation = "Centralized"
                                }
                            }
                        }
                    }

                    # Generate performance tests for critical modules
                    if ($IncludePerformanceTests -and ($templateType -eq "Critical" -or $module.Name -in $criticalModules)) {
                        if ($PSCmdlet.ShouldProcess($module.Name, "Generate performance test file")) {
                            if (-not $DryRun) {
                                $performanceGenerated = New-PerformanceTestFile -ModuleAnalysis $moduleAnalysis -TemplateDirectory $templateDir -ProjectRoot $projectRoot -Force:$Force
                            } else {
                                Write-TestLog "🔍 DRY RUN: Would generate performance test for $($module.Name)" -Level "INFO"
                                $performanceGenerated = $true
                            }

                            if ($performanceGenerated) {
                                $results.Generated += @{
                                    Module = $module.Name
                                    TemplateType = "Performance"
                                    TestLocation = "Centralized"
                                }
                            }
                        }
                    }

                } catch {
                    Write-TestLog "❌ Error processing module $($module.Name): $($_.Exception.Message)" -Level "ERROR"
                    $results.Errors += @{
                        Module = $module.Name
                        Error = $_.Exception.Message
                    }
                    $results.Summary.Errors++
                }
            }

        } catch {
            Write-TestLog "❌ Error in automated test generation: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }

    end {
        # Generate summary report
        Write-TestLog "`n🎯 Automated Test Generation Summary:" -Level "SUCCESS"
        Write-TestLog "  Total Modules Processed: $($results.Summary.Total)" -Level "INFO"
        Write-TestLog "  Tests Generated: $($results.Summary.Generated)" -Level "SUCCESS"
        Write-TestLog "  Skipped: $($results.Summary.Skipped)" -Level "WARN"
        Write-TestLog "  Errors: $($results.Summary.Errors)" -Level "ERROR"

        if ($results.Generated.Count -gt 0) {
            Write-TestLog "`n✅ Generated Tests:" -Level "SUCCESS"
            foreach ($generated in $results.Generated) {
                Write-TestLog "  - $($generated.Module) ($($generated.TemplateType), $($generated.TestLocation))" -Level "INFO"
            }
        }

        if ($results.Skipped.Count -gt 0) {
            Write-TestLog "`n⚠️  Skipped Modules:" -Level "WARN"
            foreach ($skipped in $results.Skipped) {
                Write-TestLog "  - $($skipped.Module): $($skipped.Reason)" -Level "WARN"
            }
        }

        if ($results.Errors.Count -gt 0) {
            Write-TestLog "`n❌ Errors:" -Level "ERROR"
            foreach ($error in $results.Errors) {
                Write-TestLog "  - $($error.Module): $($error.Error)" -Level "ERROR"
            }
        }

        # Generate next steps
        if ($results.Summary.Generated -gt 0) {
            Write-TestLog "`n📋 Next Steps:" -Level "INFO"
            Write-TestLog "  1. Review and customize generated tests" -Level "INFO"
            Write-TestLog "  2. Run tests: ./tests/Run-Tests.ps1" -Level "INFO"
            Write-TestLog "  3. Update README.md files: Update-ReadmeTestStatus -UpdateAll" -Level "INFO"
            if ($IncludeIntegrationTests) {
                Write-TestLog "  4. Run integration tests: ./tests/Run-Tests.ps1 -All" -Level "INFO"
            }
        }

        return $results
    }
}

function Get-ModulesForTesting {
    param([string]$ProjectRoot)
    
    $modulesPath = Join-Path $ProjectRoot "aither-core/modules"
    $modules = @()
    
    if (Test-Path $modulesPath) {
        $moduleDirectories = Get-ChildItem -Path $modulesPath -Directory
        
        foreach ($moduleDir in $moduleDirectories) {
            $moduleScript = Join-Path $moduleDir.FullName "$($moduleDir.Name).psm1"
            if (Test-Path $moduleScript) {
                $modules += @{
                    Name = $moduleDir.Name
                    Path = $moduleDir.FullName
                }
            }
        }
    }
    
    return $modules
}

function Get-ModuleForTesting {
    param([string]$ModulePath, [string]$ModuleName)
    
    return @{
        Name = $ModuleName
        Path = $ModulePath
    }
}

function Test-ModuleHasTests {
    param([string]$ModulePath, [string]$ModuleName, [switch]$UseDistributedTests)
    
    if ($UseDistributedTests) {
        # Check for distributed tests
        $distributedTestPath = Join-Path $ModulePath "tests/$ModuleName.Tests.ps1"
        return Test-Path $distributedTestPath
    } else {
        # Check for centralized tests
        $centralizedTestPath = Join-Path (Split-Path $ModulePath -Parent) "../../tests/unit/modules/$ModuleName"
        return Test-Path $centralizedTestPath
    }
}

function New-ModuleTestFile {
    param(
        [hashtable]$ModuleAnalysis,
        [string]$TemplateType,
        [string]$TemplateDirectory,
        [switch]$UseDistributedTests,
        [switch]$Force
    )
    
    # Select template file
    $templateMappings = @{
        "Manager" = "manager-module-test-template.ps1"
        "Provider" = "provider-module-test-template.ps1"
        "Core" = "module-test-template.ps1"
        "Utility" = "module-test-template.ps1"
        "Critical" = "critical-module-test-template.ps1"
    }
    
    $templateFileName = $templateMappings[$TemplateType]
    if (-not $templateFileName) {
        $templateFileName = "module-test-template.ps1"
    }
    
    $templatePath = Join-Path $TemplateDirectory $templateFileName
    if (-not (Test-Path $templatePath)) {
        throw "Template file not found: $templatePath"
    }
    
    # Generate test content
    $testContent = New-TestContentFromTemplate -ModuleAnalysis $ModuleAnalysis -TemplateType $TemplateType -TemplateDirectory $TemplateDirectory
    
    # Determine output location
    if ($UseDistributedTests) {
        $testDir = Join-Path $ModuleAnalysis.ModulePath "tests"
        $testFile = Join-Path $testDir "$($ModuleAnalysis.ModuleName).Tests.ps1"
    } else {
        $testDir = Join-Path (Split-Path $ModuleAnalysis.ModulePath -Parent) "../../tests/unit/modules/$($ModuleAnalysis.ModuleName)"
        $testFile = Join-Path $testDir "$($ModuleAnalysis.ModuleName).Tests.ps1"
    }
    
    # Create test directory if it doesn't exist
    if (-not (Test-Path $testDir)) {
        New-Item -Path $testDir -ItemType Directory -Force | Out-Null
    }
    
    # Write test file
    if ($Force -or -not (Test-Path $testFile)) {
        Set-Content -Path $testFile -Value $testContent -Encoding UTF8
        Write-TestLog "✅ Generated test file: $testFile" -Level "SUCCESS"
        return $true
    } else {
        Write-TestLog "⚠️  Test file already exists: $testFile" -Level "WARN"
        return $false
    }
}

function New-IntegrationTestFile {
    param(
        [hashtable]$ModuleAnalysis,
        [string]$TemplateDirectory,
        [string]$ProjectRoot,
        [switch]$Force
    )
    
    $templatePath = Join-Path $TemplateDirectory "integration-test-template.ps1"
    if (-not (Test-Path $templatePath)) {
        Write-TestLog "⚠️  Integration test template not found: $templatePath" -Level "WARN"
        return $false
    }
    
    # Generate integration test content
    $template = Get-Content -Path $templatePath -Raw
    $substitutions = Get-TemplateSubstitutions -ModuleAnalysis $ModuleAnalysis
    
    $content = $template
    foreach ($substitution in $substitutions.GetEnumerator()) {
        $placeholder = "{{$($substitution.Key)}}"
        $content = $content -replace [regex]::Escape($placeholder), $substitution.Value
    }
    
    # Clean up any remaining placeholders
    $content = $content -replace '\{\{[^}]+\}\}', '# TODO: Customize this section'
    
    # Output location
    $testDir = Join-Path $ProjectRoot "tests/integration"
    $testFile = Join-Path $testDir "$($ModuleAnalysis.ModuleName).Integration.Tests.ps1"
    
    # Create test directory if it doesn't exist
    if (-not (Test-Path $testDir)) {
        New-Item -Path $testDir -ItemType Directory -Force | Out-Null
    }
    
    # Write integration test file
    if ($Force -or -not (Test-Path $testFile)) {
        Set-Content -Path $testFile -Value $content -Encoding UTF8
        Write-TestLog "✅ Generated integration test file: $testFile" -Level "SUCCESS"
        return $true
    } else {
        Write-TestLog "⚠️  Integration test file already exists: $testFile" -Level "WARN"
        return $false
    }
}

function New-PerformanceTestFile {
    param(
        [hashtable]$ModuleAnalysis,
        [string]$TemplateDirectory,
        [string]$ProjectRoot,
        [switch]$Force
    )
    
    # For now, use the critical template for performance tests
    $templatePath = Join-Path $TemplateDirectory "critical-module-test-template.ps1"
    if (-not (Test-Path $templatePath)) {
        Write-TestLog "⚠️  Performance test template not found: $templatePath" -Level "WARN"
        return $false
    }
    
    # Generate performance test content (enhanced version of critical template)
    $template = Get-Content -Path $templatePath -Raw
    $substitutions = Get-TemplateSubstitutions -ModuleAnalysis $ModuleAnalysis
    
    $content = $template
    foreach ($substitution in $substitutions.GetEnumerator()) {
        $placeholder = "{{$($substitution.Key)}}"
        $content = $content -replace [regex]::Escape($placeholder), $substitution.Value
    }
    
    # Add performance-specific enhancements
    $content = $content -replace 'Describe ".*Module - Critical Module Validation"', 'Describe "{{MODULE_NAME}} Module - Performance Validation"'
    $content = $content -replace 'Critical Module Validation', 'Performance Module Validation'
    
    # Clean up any remaining placeholders
    $content = $content -replace '\{\{[^}]+\}\}', '# TODO: Customize this section'
    
    # Output location
    $testDir = Join-Path $ProjectRoot "tests/performance"
    $testFile = Join-Path $testDir "$($ModuleAnalysis.ModuleName).Performance.Tests.ps1"
    
    # Create test directory if it doesn't exist
    if (-not (Test-Path $testDir)) {
        New-Item -Path $testDir -ItemType Directory -Force | Out-Null
    }
    
    # Write performance test file
    if ($Force -or -not (Test-Path $testFile)) {
        Set-Content -Path $testFile -Value $content -Encoding UTF8
        Write-TestLog "✅ Generated performance test file: $testFile" -Level "SUCCESS"
        return $true
    } else {
        Write-TestLog "⚠️  Performance test file already exists: $testFile" -Level "WARN"
        return $false
    }
}

Export-ModuleMember -Function Invoke-AutomatedTestGeneration