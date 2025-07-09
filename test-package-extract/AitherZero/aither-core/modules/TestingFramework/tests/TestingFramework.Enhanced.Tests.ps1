#Requires -Version 7.0

<#
.SYNOPSIS
    Enhanced integration tests for the TestingFramework module v2.1.0

.DESCRIPTION
    Comprehensive tests for the enhanced TestingFramework module including:
    - Automated test generation functionality
    - README.md status update system
    - Test execution monitoring
    - Integration testing capabilities
    - Performance testing features
    - Template system validation

.NOTES
    These tests validate the new capabilities added in v2.1.0
#>

BeforeAll {
    # Import the module being tested
    $modulePath = Join-Path $PSScriptRoot ".." "TestingFramework.psm1"
    Import-Module $modulePath -Force -ErrorAction Stop

    # Setup test environment
    $script:TestStartTime = Get-Date
    $script:TestProjectRoot = Split-Path -Path $PSScriptRoot -Parent
    while ($script:TestProjectRoot -and -not (Test-Path (Join-Path $script:TestProjectRoot ".git"))) {
        $script:TestProjectRoot = Split-Path $script:TestProjectRoot -Parent
    }

    # Create temporary test directory
    $script:TestTempDir = Join-Path $env:TEMP "TestingFramework-Tests-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -Path $script:TestTempDir -ItemType Directory -Force | Out-Null

    # Mock Write-CustomLog if not available
    if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
        function Write-CustomLog {
            param([string]$Message, [string]$Level = "INFO")
            Write-Host "[$Level] $Message"
        }
    }
}

AfterAll {
    # Cleanup test environment
    if (Test-Path $script:TestTempDir) {
        Remove-Item -Path $script:TestTempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Calculate test execution time
    $testDuration = (Get-Date) - $script:TestStartTime
    Write-Host "Enhanced TestingFramework tests completed in $($testDuration.TotalSeconds) seconds" -ForegroundColor Green
}

Describe "TestingFramework v2.1.0 - Enhanced Features" {
    Context "Module Structure and New Functions" {
        It "Should export all new functions" {
            $expectedNewFunctions = @(
                'Update-ReadmeTestStatus',
                'Invoke-AutomatedTestGeneration',
                'Start-TestExecutionMonitoring'
            )

            foreach ($function in $expectedNewFunctions) {
                Get-Command $function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }

        It "Should have proper module version" {
            $module = Get-Module "TestingFramework"
            $module.Version | Should -BeGreaterOrEqual ([Version]"2.1.0")
        }

        It "Should maintain backward compatibility" {
            $legacyFunctions = @(
                'Invoke-UnifiedTestExecution',
                'Get-DiscoveredModules',
                'New-TestReport',
                'Submit-TestEvent'
            )

            foreach ($function in $legacyFunctions) {
                Get-Command $function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Automated Test Generation" {
        It "Should analyze module structure correctly" {
            # Test with the TestingFramework module itself
            $analysis = Get-ModuleAnalysis -ModulePath $script:TestProjectRoot -ModuleName "TestingFramework"
            
            $analysis | Should -Not -BeNullOrEmpty
            $analysis.ModuleName | Should -Be "TestingFramework"
            $analysis.ModuleType | Should -Be "Core"
            $analysis.ExportedFunctions.Count | Should -BeGreaterThan 0
        }

        It "Should generate test content from templates" {
            # Create a mock module analysis
            $mockAnalysis = @{
                ModuleName = "TestModule"
                ModuleType = "Utility"
                ExportedFunctions = @("Test-Function1", "Test-Function2")
                HasManifest = $true
                HasPrivatePublic = $false
                Description = "Test module for testing"
                ModuleVersion = "1.0.0"
            }

            # Test template content generation
            $templateDir = Join-Path $script:TestProjectRoot "scripts/testing/templates"
            if (Test-Path $templateDir) {
                $testContent = New-TestContentFromTemplate -ModuleAnalysis $mockAnalysis -TemplateType "Utility" -TemplateDirectory $templateDir
                
                $testContent | Should -Not -BeNullOrEmpty
                $testContent | Should -Match "TestModule"
                $testContent | Should -Match "Test-Function1"
                $testContent | Should -Match "Test-Function2"
            } else {
                Set-ItResult -Skipped -Because "Template directory not found"
            }
        }

        It "Should handle dry run mode correctly" {
            $result = Invoke-AutomatedTestGeneration -ModuleName "TestingFramework" -DryRun
            
            $result | Should -Not -BeNullOrEmpty
            $result.Summary | Should -Not -BeNullOrEmpty
            $result.Summary.Total | Should -BeGreaterOrEqual 0
        }

        It "Should support different template types" {
            $templateTypes = @("Manager", "Provider", "Core", "Utility", "Critical")
            
            foreach ($templateType in $templateTypes) {
                $mockAnalysis = @{
                    ModuleName = "Test$templateType"
                    ModuleType = $templateType
                    ExportedFunctions = @("Test-Function")
                    HasManifest = $true
                    HasPrivatePublic = $false
                    Description = "Test $templateType module"
                    ModuleVersion = "1.0.0"
                }

                $templateDir = Join-Path $script:TestProjectRoot "scripts/testing/templates"
                if (Test-Path $templateDir) {
                    { New-TestContentFromTemplate -ModuleAnalysis $mockAnalysis -TemplateType $templateType -TemplateDirectory $templateDir } | Should -Not -Throw
                }
            }
        }
    }

    Context "README.md Status Updates" {
        BeforeEach {
            # Create a temporary README.md file
            $script:TestReadmePath = Join-Path $script:TestTempDir "README.md"
            $initialContent = @"
# Test Module

This is a test module for testing README.md updates.

## Features

- Feature 1
- Feature 2

## Usage

Usage instructions here.
"@
            Set-Content -Path $script:TestReadmePath -Value $initialContent -Encoding UTF8
        }

        It "Should update README.md with test status" {
            $mockTestResults = @(
                @{
                    Module = "TestModule"
                    Phase = "Unit"
                    TestsRun = 10
                    TestsPassed = 8
                    TestsFailed = 2
                    Duration = 5.5
                }
            )

            { Update-ReadmeTestStatus -ModulePath (Split-Path $script:TestReadmePath) -TestResults $mockTestResults } | Should -Not -Throw
            
            $updatedContent = Get-Content -Path $script:TestReadmePath -Raw
            $updatedContent | Should -Match "🧪 Test Status"
            $updatedContent | Should -Match "Total Tests: 10"
            $updatedContent | Should -Match "Passed: 8"
            $updatedContent | Should -Match "Failed: 2"
        }

        It "Should handle empty test results gracefully" {
            { Update-ReadmeTestStatus -ModulePath (Split-Path $script:TestReadmePath) -TestResults @() } | Should -Not -Throw
        }

        It "Should preserve existing README.md content" {
            $originalContent = Get-Content -Path $script:TestReadmePath -Raw
            
            $mockTestResults = @(
                @{
                    Module = "TestModule"
                    Phase = "Unit"
                    TestsRun = 5
                    TestsPassed = 5
                    TestsFailed = 0
                    Duration = 2.0
                }
            )

            Update-ReadmeTestStatus -ModulePath (Split-Path $script:TestReadmePath) -TestResults $mockTestResults
            
            $updatedContent = Get-Content -Path $script:TestReadmePath -Raw
            $updatedContent | Should -Match "This is a test module"
            $updatedContent | Should -Match "## Features"
            $updatedContent | Should -Match "Feature 1"
        }

        It "Should update existing test status section" {
            # First update
            $mockTestResults1 = @(
                @{
                    Module = "TestModule"
                    Phase = "Unit"
                    TestsRun = 10
                    TestsPassed = 8
                    TestsFailed = 2
                    Duration = 5.5
                }
            )

            Update-ReadmeTestStatus -ModulePath (Split-Path $script:TestReadmePath) -TestResults $mockTestResults1
            
            # Second update
            $mockTestResults2 = @(
                @{
                    Module = "TestModule"
                    Phase = "Unit"
                    TestsRun = 12
                    TestsPassed = 12
                    TestsFailed = 0
                    Duration = 3.0
                }
            )

            Update-ReadmeTestStatus -ModulePath (Split-Path $script:TestReadmePath) -TestResults $mockTestResults2
            
            $updatedContent = Get-Content -Path $script:TestReadmePath -Raw
            $updatedContent | Should -Match "Total Tests: 12"
            $updatedContent | Should -Match "Passed: 12"
            $updatedContent | Should -Match "Failed: 0"
            
            # Should not have duplicate test status sections
            $testStatusMatches = [regex]::Matches($updatedContent, "🧪 Test Status")
            $testStatusMatches.Count | Should -Be 1
        }
    }

    Context "Test Execution Monitoring" {
        It "Should initialize monitoring state correctly" {
            # This test requires actual test execution, so we'll test the parameter validation
            { Start-TestExecutionMonitoring -TestSuite "Quick" -UpdateReadme:$false -GenerateReport:$false -WhatIf } | Should -Not -Throw
        }

        It "Should validate test suite parameter" {
            $validSuites = @("All", "Unit", "Integration", "Performance", "Quick", "Setup")
            
            foreach ($suite in $validSuites) {
                { Start-TestExecutionMonitoring -TestSuite $suite -WhatIf } | Should -Not -Throw
            }
        }

        It "Should handle module filtering" {
            $moduleFilter = @("TestModule1", "TestModule2")
            { Start-TestExecutionMonitoring -TestSuite "Unit" -ModuleFilter $moduleFilter -WhatIf } | Should -Not -Throw
        }

        It "Should support different output paths" {
            $customOutputPath = Join-Path $script:TestTempDir "custom-results"
            { Start-TestExecutionMonitoring -TestSuite "Unit" -OutputPath $customOutputPath -WhatIf } | Should -Not -Throw
        }
    }

    Context "Integration with Existing Functions" {
        It "Should integrate with unified test execution" {
            # Test that new functions work with existing test execution
            $testResults = Invoke-UnifiedTestExecution -TestSuite "Unit" -TestProfile "Development" -OutputPath $script:TestTempDir
            
            $testResults | Should -Not -BeNullOrEmpty
            $testResults.Count | Should -BeGreaterThan 0
            
            # Test that README update works with real results
            { Update-ReadmeTestStatus -ModulePath $script:TestTempDir -TestResults $testResults } | Should -Not -Throw
        }

        It "Should work with event system" {
            # Test event submission and retrieval
            Submit-TestEvent -EventType "TestEnhancement" -Data @{ Version = "2.1.0"; Feature = "README Updates" }
            
            $events = Get-TestEvents -EventType "TestEnhancement"
            $events | Should -Not -BeNullOrEmpty
            $events.Count | Should -BeGreaterThan 0
        }

        It "Should integrate with module discovery" {
            $discoveredModules = Get-DiscoveredModules
            $discoveredModules | Should -Not -BeNullOrEmpty
            
            # Test that generation works with discovered modules
            $result = Invoke-AutomatedTestGeneration -DryRun
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Template System Validation" {
        It "Should have all required templates" {
            $templateDir = Join-Path $script:TestProjectRoot "scripts/testing/templates"
            
            if (Test-Path $templateDir) {
                $requiredTemplates = @(
                    "module-test-template.ps1",
                    "manager-module-test-template.ps1",
                    "provider-module-test-template.ps1",
                    "critical-module-test-template.ps1",
                    "integration-test-template.ps1"
                )

                foreach ($template in $requiredTemplates) {
                    $templatePath = Join-Path $templateDir $template
                    Test-Path $templatePath | Should -Be $true -Because "Template $template should exist"
                }
            } else {
                Set-ItResult -Skipped -Because "Template directory not found"
            }
        }

        It "Should validate template content" {
            $templateDir = Join-Path $script:TestProjectRoot "scripts/testing/templates"
            
            if (Test-Path $templateDir) {
                $templatePath = Join-Path $templateDir "module-test-template.ps1"
                
                if (Test-Path $templatePath) {
                    $templateContent = Get-Content -Path $templatePath -Raw
                    $templateContent | Should -Match "{{MODULE_NAME}}"
                    $templateContent | Should -Match "{{EXPECTED_FUNCTIONS}}"
                    $templateContent | Should -Match "BeforeAll"
                    $templateContent | Should -Match "AfterAll"
                    $templateContent | Should -Match "Describe"
                    $templateContent | Should -Match "Context"
                    $templateContent | Should -Match "It"
                }
            } else {
                Set-ItResult -Skipped -Because "Template directory not found"
            }
        }

        It "Should handle template substitution correctly" {
            $templateDir = Join-Path $script:TestProjectRoot "scripts/testing/templates"
            
            if (Test-Path $templateDir) {
                $mockAnalysis = @{
                    ModuleName = "TestSubstitution"
                    ModuleType = "Utility"
                    ExportedFunctions = @("Test-Function")
                    Description = "Test substitution module"
                    ModuleVersion = "1.0.0"
                }

                $substitutions = Get-TemplateSubstitutions -ModuleAnalysis $mockAnalysis
                $substitutions | Should -Not -BeNullOrEmpty
                $substitutions['MODULE_NAME'] | Should -Be "TestSubstitution"
                $substitutions['MODULE_DESCRIPTION'] | Should -Be "Test substitution module"
                $substitutions['MODULE_VERSION'] | Should -Be "1.0.0"
            } else {
                Set-ItResult -Skipped -Because "Template directory not found"
            }
        }
    }

    Context "Performance and Reliability" {
        It "Should execute functions within acceptable time limits" {
            $functions = @(
                'Get-DiscoveredModules',
                'Get-TestConfiguration',
                'Submit-TestEvent',
                'Get-TestEvents'
            )

            foreach ($function in $functions) {
                $executionTime = Measure-Command {
                    try {
                        switch ($function) {
                            'Get-DiscoveredModules' { Get-DiscoveredModules }
                            'Get-TestConfiguration' { Get-TestConfiguration -Profile "Development" }
                            'Submit-TestEvent' { Submit-TestEvent -EventType "PerfTest" -Data @{} }
                            'Get-TestEvents' { Get-TestEvents }
                        }
                    } catch {
                        # Some functions may fail without proper parameters, but shouldn't take long
                    }
                }

                $executionTime.TotalMilliseconds | Should -BeLessThan 5000 -Because "$function should execute quickly"
            }
        }

        It "Should handle large test result sets" {
            $largeTestResults = @()
            for ($i = 1; $i -le 100; $i++) {
                $largeTestResults += @{
                    Module = "TestModule$i"
                    Phase = "Unit"
                    TestsRun = 50
                    TestsPassed = 45
                    TestsFailed = 5
                    Duration = 10.0
                }
            }

            # Should handle large result sets without errors
            { Update-ReadmeTestStatus -ModulePath $script:TestTempDir -TestResults $largeTestResults } | Should -Not -Throw
        }

        It "Should be memory efficient" {
            $initialMemory = [System.GC]::GetTotalMemory($false)
            
            # Perform multiple operations
            for ($i = 1; $i -le 10; $i++) {
                $testResults = @(
                    @{
                        Module = "MemoryTest$i"
                        Phase = "Unit"
                        TestsRun = 10
                        TestsPassed = 8
                        TestsFailed = 2
                        Duration = 5.0
                    }
                )
                
                Update-ReadmeTestStatus -ModulePath $script:TestTempDir -TestResults $testResults
            }
            
            # Force garbage collection
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            [System.GC]::Collect()
            
            $finalMemory = [System.GC]::GetTotalMemory($false)
            $memoryIncrease = $finalMemory - $initialMemory
            
            # Memory increase should be reasonable (less than 50MB)
            $memoryIncrease | Should -BeLessThan 50MB -Because "Memory usage should be efficient"
        }
    }

    Context "Error Handling and Edge Cases" {
        It "Should handle missing project root gracefully" {
            # Test with invalid path
            { Invoke-AutomatedTestGeneration -ModuleName "NonExistent" -DryRun } | Should -Not -Throw
        }

        It "Should handle missing template directory" {
            $mockAnalysis = @{
                ModuleName = "TestModule"
                ModuleType = "Utility"
                ExportedFunctions = @("Test-Function")
                Description = "Test module"
                ModuleVersion = "1.0.0"
            }

            { New-TestContentFromTemplate -ModuleAnalysis $mockAnalysis -TemplateType "Utility" -TemplateDirectory "/nonexistent/path" } | Should -Throw
        }

        It "Should handle invalid README.md paths" {
            $mockTestResults = @(
                @{
                    Module = "TestModule"
                    Phase = "Unit"
                    TestsRun = 10
                    TestsPassed = 8
                    TestsFailed = 2
                    Duration = 5.5
                }
            )

            { Update-ReadmeTestStatus -ModulePath "/nonexistent/path" -TestResults $mockTestResults } | Should -Not -Throw
        }

        It "Should handle malformed test results" {
            $malformedResults = @(
                @{
                    Module = "TestModule"
                    # Missing required properties
                }
            )

            { Update-ReadmeTestStatus -ModulePath $script:TestTempDir -TestResults $malformedResults } | Should -Not -Throw
        }

        It "Should handle Unicode and special characters" {
            $unicodeResults = @(
                @{
                    Module = "测试模块🧪"
                    Phase = "Unit"
                    TestsRun = 5
                    TestsPassed = 5
                    TestsFailed = 0
                    Duration = 2.0
                }
            )

            { Update-ReadmeTestStatus -ModulePath $script:TestTempDir -TestResults $unicodeResults } | Should -Not -Throw
        }
    }

    Context "Cross-Platform Compatibility" {
        It "Should work on current platform" {
            $platform = if ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } elseif ($IsMacOS) { "macOS" } else { "Unknown" }
            $platform | Should -BeIn @("Windows", "Linux", "macOS")

            # Test platform-specific path handling
            $testPath = Join-Path $script:TestTempDir "platform-test"
            New-Item -Path $testPath -ItemType Directory -Force | Out-Null
            
            $testResults = @(
                @{
                    Module = "PlatformTest"
                    Phase = "Unit"
                    TestsRun = 1
                    TestsPassed = 1
                    TestsFailed = 0
                    Duration = 1.0
                }
            )

            { Update-ReadmeTestStatus -ModulePath $testPath -TestResults $testResults } | Should -Not -Throw
        }

        It "Should handle different path separators" {
            $pathSeparators = if ($IsWindows) { @('\', '/') } else { @('/') }
            
            foreach ($separator in $pathSeparators) {
                $testPath = $script:TestTempDir -replace [regex]::Escape([System.IO.Path]::DirectorySeparatorChar), $separator
                
                $testResults = @(
                    @{
                        Module = "PathTest"
                        Phase = "Unit"
                        TestsRun = 1
                        TestsPassed = 1
                        TestsFailed = 0
                        Duration = 1.0
                    }
                )

                { Update-ReadmeTestStatus -ModulePath $testPath -TestResults $testResults } | Should -Not -Throw
            }
        }
    }
}

Describe "TestingFramework v2.1.0 - Integration Scenarios" {
    Context "End-to-End Workflow" {
        It "Should support complete testing workflow" {
            # This test validates the entire enhanced workflow
            
            # Step 1: Module discovery
            $discoveredModules = Get-DiscoveredModules
            $discoveredModules | Should -Not -BeNullOrEmpty
            
            # Step 2: Test generation (dry run)
            $generationResult = Invoke-AutomatedTestGeneration -DryRun
            $generationResult | Should -Not -BeNullOrEmpty
            
            # Step 3: Test execution
            $testResults = Invoke-UnifiedTestExecution -TestSuite "Unit" -TestProfile "Development" -OutputPath $script:TestTempDir
            $testResults | Should -Not -BeNullOrEmpty
            
            # Step 4: README update
            { Update-ReadmeTestStatus -ModulePath $script:TestTempDir -TestResults $testResults } | Should -Not -Throw
            
            # Step 5: Event submission
            Submit-TestEvent -EventType "WorkflowCompleted" -Data @{ Modules = $discoveredModules.Count; Results = $testResults.Count }
            
            # Step 6: Event retrieval
            $events = Get-TestEvents -EventType "WorkflowCompleted"
            $events | Should -Not -BeNullOrEmpty
        }

        It "Should handle concurrent operations" {
            $jobs = @()
            
            for ($i = 1; $i -le 3; $i++) {
                $jobs += Start-Job -ScriptBlock {
                    param($ModulePath, $JobId)
                    
                    Import-Module $ModulePath -Force
                    
                    $testResults = @(
                        @{
                            Module = "ConcurrentTest$JobId"
                            Phase = "Unit"
                            TestsRun = 5
                            TestsPassed = 5
                            TestsFailed = 0
                            Duration = 2.0
                        }
                    )
                    
                    Submit-TestEvent -EventType "ConcurrentTest" -Data @{ JobId = $JobId }
                    
                    return $JobId
                } -ArgumentList $modulePath, $i
            }
            
            # Wait for all jobs
            $results = $jobs | Wait-Job | Receive-Job
            $jobs | Remove-Job
            
            # All jobs should complete successfully
            $results.Count | Should -Be 3
            $results | Should -Contain 1
            $results | Should -Contain 2
            $results | Should -Contain 3
        }
    }

    Context "Advanced Features Integration" {
        It "Should integrate with ProgressTracking if available" {
            $progressModule = Get-Module -Name "ProgressTracking" -ErrorAction SilentlyContinue
            if ($progressModule) {
                $operationId = Start-ProgressOperation -OperationName "TestingFramework Integration" -TotalSteps 3
                $operationId | Should -Not -BeNullOrEmpty
                
                Update-ProgressOperation -OperationId $operationId -CurrentStep 1 -StepName "Testing integration"
                Update-ProgressOperation -OperationId $operationId -CurrentStep 2 -StepName "Validating results"
                Update-ProgressOperation -OperationId $operationId -CurrentStep 3 -StepName "Completing"
                
                Complete-ProgressOperation -OperationId $operationId
            } else {
                Set-ItResult -Skipped -Because "ProgressTracking module not available"
            }
        }

        It "Should integrate with ModuleCommunication if available" {
            $commModule = Get-Module -Name "ModuleCommunication" -ErrorAction SilentlyContinue
            if ($commModule) {
                { Register-ModuleAPI -ModuleName "TestingFramework" -APIVersion "2.1.0" -Endpoints @("health", "status") } | Should -Not -Throw
                
                $apiResult = Invoke-ModuleAPI -ModuleName "TestingFramework" -Endpoint "health" -ErrorAction SilentlyContinue
                # Should not throw even if endpoint is not implemented
                
                { Submit-ModuleMessage -MessageType "TestingFrameworkEvent" -MessageData @{ Version = "2.1.0" } } | Should -Not -Throw
            } else {
                Set-ItResult -Skipped -Because "ModuleCommunication module not available"
            }
        }
    }

    Context "Real-World Scenarios" {
        It "Should handle typical project structure" {
            # Test with a typical AitherZero project structure
            $projectStructure = @{
                "aither-core/modules/TestModule1" = @{
                    "TestModule1.psm1" = "# Test module 1"
                    "TestModule1.psd1" = "@{ ModuleVersion = '1.0.0'; Description = 'Test module 1' }"
                    "tests/TestModule1.Tests.ps1" = "# Test file 1"
                }
                "aither-core/modules/TestModule2" = @{
                    "TestModule2.psm1" = "# Test module 2"
                    "TestModule2.psd1" = "@{ ModuleVersion = '1.0.0'; Description = 'Test module 2' }"
                    "README.md" = "# TestModule2"
                }
            }

            # Create test project structure
            $testProjectPath = Join-Path $script:TestTempDir "test-project"
            New-Item -Path $testProjectPath -ItemType Directory -Force | Out-Null
            
            foreach ($dirPath in $projectStructure.Keys) {
                $fullDirPath = Join-Path $testProjectPath $dirPath
                New-Item -Path $fullDirPath -ItemType Directory -Force | Out-Null
                
                foreach ($fileName in $projectStructure[$dirPath].Keys) {
                    $filePath = Join-Path $fullDirPath $fileName
                    $content = $projectStructure[$dirPath][$fileName]
                    Set-Content -Path $filePath -Value $content -Encoding UTF8
                }
            }

            # Test module discovery with this structure
            $oldRoot = $script:TestProjectRoot
            $script:TestProjectRoot = $testProjectPath
            
            try {
                $discoveredModules = Get-DiscoveredModules
                $discoveredModules.Count | Should -BeGreaterOrEqual 2
                
                # Test with one module having tests and one without
                $moduleWithTests = $discoveredModules | Where-Object { $_.Name -eq "TestModule1" }
                $moduleWithoutTests = $discoveredModules | Where-Object { $_.Name -eq "TestModule2" }
                
                if ($moduleWithTests) {
                    $moduleWithTests.TestDiscovery.HasDistributedTests | Should -Be $true
                }
                
                if ($moduleWithoutTests) {
                    $moduleWithoutTests.TestDiscovery.HasDistributedTests | Should -Be $false
                }
                
            } finally {
                $script:TestProjectRoot = $oldRoot
            }
        }
    }
}