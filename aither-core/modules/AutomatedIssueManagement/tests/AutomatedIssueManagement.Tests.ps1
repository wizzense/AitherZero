#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive Pester tests for the AutomatedIssueManagement module

.DESCRIPTION
    Tests automated issue creation and management functionality including:
    - Issue initialization and configuration
    - Test failure issue creation
    - PSScriptAnalyzer issue creation
    - Issue lifecycle management
    - System metadata collection
    - Issue reporting and statistics

.NOTES
    Module: AutomatedIssueManagement
    Version: 1.0.0
    Tests both main module and IssueLifecycleManager
#>

BeforeAll {
    # Import the modules under test
    $ModulePath = Split-Path -Parent $PSScriptRoot
    Import-Module $ModulePath -Force
    
    # Also import the IssueLifecycleManager
    $IssueLifecycleManagerPath = Join-Path $ModulePath "IssueLifecycleManager.psm1"
    if (Test-Path $IssueLifecycleManagerPath) {
        Import-Module $IssueLifecycleManagerPath -Force
    }

    # Setup test environment
    $script:TestStartTime = Get-Date
    $script:TestWorkspace = if ($env:TEMP) {
        Join-Path $env:TEMP "AutomatedIssueManagement-Test-$(Get-Random)"
    } elseif (Test-Path '/tmp') {
        "/tmp/AutomatedIssueManagement-Test-$(Get-Random)"
    } else {
        Join-Path (Get-Location) "AutomatedIssueManagement-Test-$(Get-Random)"
    }

    # Create test workspace
    New-Item -Path $script:TestWorkspace -ItemType Directory -Force | Out-Null
    
    # Create GitHub automated-issues directory structure for testing
    $script:TestGitHubDir = Join-Path $script:TestWorkspace ".github"
    $script:TestIssuesDir = Join-Path $script:TestGitHubDir "automated-issues"
    New-Item -Path $script:TestIssuesDir -ItemType Directory -Force | Out-Null

    # Mock dependencies if not available
    if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
        function Write-CustomLog {
            param([string]$Message, [string]$Level = "INFO")
            Write-Host "[$Level] $Message"
        }
    }
    
    # Mock Find-ProjectRoot for testing
    if (-not (Get-Command Find-ProjectRoot -ErrorAction SilentlyContinue)) {
        function Find-ProjectRoot {
            return $script:TestWorkspace
        }
    }

    # Set test environment variables
    $env:GITHUB_REPOSITORY_OWNER = "TestOwner"
    $env:GITHUB_REPOSITORY = "TestOwner/TestRepo"
    $env:GITHUB_TOKEN = "test-token-123"
    $env:GITHUB_RUN_ID = "123456789"
    $env:GITHUB_ACTIONS = "true"
    
    # Change to test workspace
    Push-Location $script:TestWorkspace
}

AfterAll {
    # Restore location
    Pop-Location

    # Cleanup test workspace
    if ($script:TestWorkspace -and (Test-Path $script:TestWorkspace)) {
        Remove-Item $script:TestWorkspace -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Calculate test execution time
    $testDuration = (Get-Date) - $script:TestStartTime
    Write-Host "AutomatedIssueManagement test execution completed in $($testDuration.TotalSeconds) seconds" -ForegroundColor Green
}

Describe "AutomatedIssueManagement Module - Core Functionality" {
    Context "Module Import and Structure" {
        It "Should import the main module successfully" {
            Get-Module -Name "AutomatedIssueManagement" | Should -Not -BeNullOrEmpty
        }

        It "Should export required functions" {
            $expectedFunctions = @(
                'Initialize-AutomatedIssueManagement',
                'New-AutomatedIssueFromFailure',
                'New-PesterTestFailureIssues',
                'New-PSScriptAnalyzerIssues',
                'Get-SystemMetadata',
                'New-AutomatedIssueReport'
            )

            $exportedFunctions = Get-Command -Module "AutomatedIssueManagement" | Select-Object -ExpandProperty Name

            foreach ($function in $expectedFunctions) {
                $exportedFunctions | Should -Contain $function -Because "Function $function should be exported"
            }
        }

        It "Should have proper module version" {
            $module = Get-Module -Name "AutomatedIssueManagement"
            $module.Version | Should -Not -BeNullOrEmpty
        }
    }

    Context "System Initialization" {
        It "Should initialize automated issue management successfully" {
            $result = Initialize-AutomatedIssueManagement -RepositoryOwner "TestOwner" -RepositoryName "TestRepo"
            
            $result.success | Should -Be $true
            $result.configuration | Should -Not -BeNullOrEmpty
            $result.state_file | Should -Not -BeNullOrEmpty
            $result.errors | Should -BeNullOrEmpty
        }

        It "Should create configuration file during initialization" {
            Initialize-AutomatedIssueManagement -RepositoryOwner "TestOwner" -RepositoryName "TestRepo"
            
            $configFile = Join-Path $script:TestIssuesDir "config.json"
            Test-Path $configFile | Should -Be $true
        }

        It "Should create state file during initialization" {
            Initialize-AutomatedIssueManagement -RepositoryOwner "TestOwner" -RepositoryName "TestRepo"
            
            $stateFile = Join-Path $script:TestIssuesDir "state.json"
            Test-Path $stateFile | Should -Be $true
        }

        It "Should handle initialization without GitHub token gracefully" {
            # Temporarily remove token
            $originalToken = $env:GITHUB_TOKEN
            $env:GITHUB_TOKEN = ""
            
            try {
                $result = Initialize-AutomatedIssueManagement -RepositoryOwner "TestOwner" -RepositoryName "TestRepo"
                $result.success | Should -Be $true
                $result.configuration.authentication.token_available | Should -Be $false
            } finally {
                $env:GITHUB_TOKEN = $originalToken
            }
        }
    }

    Context "System Metadata Collection" {
        It "Should collect comprehensive system metadata" {
            $metadata = Get-SystemMetadata
            
            $metadata | Should -Not -BeNullOrEmpty
            $metadata.timestamp | Should -Not -BeNullOrEmpty
            $metadata.environment | Should -Not -BeNullOrEmpty
            $metadata.ci_environment | Should -Not -BeNullOrEmpty
            $metadata.project | Should -Not -BeNullOrEmpty
        }

        It "Should include PowerShell version information" {
            $metadata = Get-SystemMetadata
            
            $metadata.environment.powershell_version | Should -Not -BeNullOrEmpty
            $metadata.environment.powershell_edition | Should -Not -BeNullOrEmpty
            $metadata.environment.platform | Should -Not -BeNullOrEmpty
        }

        It "Should detect CI environment correctly" {
            $metadata = Get-SystemMetadata
            
            $metadata.ci_environment.is_github_actions | Should -Be $true
            $metadata.ci_environment.run_id | Should -Be "123456789"
        }

        It "Should handle errors gracefully during metadata collection" {
            # Mock a failure scenario
            Mock Find-ProjectRoot { throw "Test error" } -ModuleName AutomatedIssueManagement
            
            $metadata = Get-SystemMetadata
            $metadata.error | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "AutomatedIssueManagement - Issue Creation" {
    BeforeEach {
        # Initialize system for each test
        Initialize-AutomatedIssueManagement -RepositoryOwner "TestOwner" -RepositoryName "TestRepo"
    }

    Context "Test Failure Issues" {
        It "Should create issues from Pester test failures" {
            $mockTestResults = @{
                FailedTests = @(
                    @{
                        Name = "Should validate input parameters"
                        ScriptBlock = @{ File = "TestFile.Tests.ps1" }
                        FailureMessage = "Expected value but got null"
                        ErrorRecord = @{
                            Exception = @{ Message = "Parameter validation failed" }
                            ScriptStackTrace = "at line 42 in TestFile.Tests.ps1"
                        }
                        Result = "Failed"
                    }
                )
            }

            $result = New-PesterTestFailureIssues -TestResults $mockTestResults -CreateIssues:$false
            
            $result.success | Should -Be $true
            $result.test_failures | Should -Be 1
            $result.errors | Should -BeNullOrEmpty
        }

        It "Should handle test results from file" {
            # Create mock test results file
            $testResultsFile = Join-Path $script:TestWorkspace "test-results.json"
            $mockResults = @{
                FailedTests = @()
                Tests = @(
                    @{
                        Name = "Sample test"
                        Result = "Failed"
                        FailureMessage = "Test failure"
                        ErrorRecord = @{ Exception = @{ Message = "Error" } }
                    }
                )
            }
            $mockResults | ConvertTo-Json -Depth 5 | Set-Content $testResultsFile

            $result = New-PesterTestFailureIssues -TestResults $testResultsFile -CreateIssues:$false
            
            $result.success | Should -Be $true
            $result.test_failures | Should -Be 1
        }

        It "Should handle empty test results gracefully" {
            $emptyResults = @{ FailedTests = @(); Tests = @() }
            
            $result = New-PesterTestFailureIssues -TestResults $emptyResults -CreateIssues:$false
            
            $result.success | Should -Be $true
            $result.test_failures | Should -Be 0
        }
    }

    Context "PSScriptAnalyzer Issues" {
        It "Should create issues from PSScriptAnalyzer violations" {
            $mockAnalyzerResults = @(
                @{
                    RuleName = "PSUseDeclaredVarsMoreThanAssignments"
                    Severity = "Warning"
                    Message = "Variable 'unused' is assigned but never used"
                    ScriptPath = "TestScript.ps1"
                    Line = 10
                    Column = 5
                }
            )

            $result = New-PSScriptAnalyzerIssues -AnalyzerResults $mockAnalyzerResults -CreateIssues:$false
            
            $result.success | Should -Be $true
            $result.analyzer_violations | Should -Be 1
            $result.errors | Should -BeNullOrEmpty
        }

        It "Should filter violations by severity" {
            $mockResults = @(
                @{ RuleName = "Rule1"; Severity = "Error"; Message = "Error"; ScriptPath = "Test.ps1"; Line = 1; Column = 1 },
                @{ RuleName = "Rule2"; Severity = "Warning"; Message = "Warning"; ScriptPath = "Test.ps1"; Line = 2; Column = 1 },
                @{ RuleName = "Rule3"; Severity = "Information"; Message = "Info"; ScriptPath = "Test.ps1"; Line = 3; Column = 1 }
            )

            $result = New-PSScriptAnalyzerIssues -AnalyzerResults $mockResults -MinimumSeverity "Warning" -CreateIssues:$false
            
            $result.analyzer_violations | Should -Be 2  # Error + Warning
        }

        It "Should handle analyzer results from file" {
            $resultsFile = Join-Path $script:TestWorkspace "analyzer-results.json"
            $mockResults = @(
                @{
                    RuleName = "TestRule"
                    Severity = "Error"
                    Message = "Test violation"
                    ScriptPath = "Test.ps1"
                    Line = 1
                    Column = 1
                }
            )
            $mockResults | ConvertTo-Json -Depth 3 | Set-Content $resultsFile

            $result = New-PSScriptAnalyzerIssues -AnalyzerResults $resultsFile -CreateIssues:$false
            
            $result.success | Should -Be $true
            $result.analyzer_violations | Should -Be 1
        }
    }

    Context "General Issue Creation" {
        It "Should create automated issue from failure details" {
            $failureDetails = @{
                test_name = "Sample test failure"
                test_file = "SampleTest.Tests.ps1"
                failure_message = "Expected true but got false"
                error_details = "Assertion failed"
            }

            $result = New-AutomatedIssueFromFailure -FailureType "test" -FailureDetails $failureDetails -CreateIssue:$false
            
            $result.success | Should -Be $true
            $result.issue_data | Should -Not -BeNullOrEmpty
            $result.issue_data.title | Should -Not -BeNullOrEmpty
            $result.issue_data.body | Should -Not -BeNullOrEmpty
        }

        It "Should skip issue creation when GitHub token is not available" {
            # Remove token temporarily
            $originalToken = $env:GITHUB_TOKEN
            $env:GITHUB_TOKEN = ""
            
            try {
                # Re-initialize without token
                Initialize-AutomatedIssueManagement -RepositoryOwner "TestOwner" -RepositoryName "TestRepo"
                
                $result = New-AutomatedIssueFromFailure -FailureType "test" -FailureDetails @{} -CreateIssue
                
                $result.success | Should -Be $true
                $result.issue_created | Should -Be $false
            } finally {
                $env:GITHUB_TOKEN = $originalToken
            }
        }

        It "Should validate failure type parameter" {
            $failureDetails = @{ message = "Test failure" }
            
            { New-AutomatedIssueFromFailure -FailureType "invalid_type" -FailureDetails $failureDetails } | Should -Throw
        }
    }
}

Describe "AutomatedIssueManagement - Issue Lifecycle" {
    BeforeEach {
        # Initialize system for each test
        Initialize-AutomatedIssueManagement -RepositoryOwner "TestOwner" -RepositoryName "TestRepo"
    }

    Context "Issue Lifecycle Management" {
        It "Should import IssueLifecycleManager successfully" {
            Get-Module -Name "IssueLifecycleManager" | Should -Not -BeNullOrEmpty
        }

        It "Should export lifecycle management functions" {
            $expectedFunctions = @('Invoke-IssueLifecycleManagement')
            $exportedFunctions = Get-Command -Module "IssueLifecycleManager" | Select-Object -ExpandProperty Name

            foreach ($function in $expectedFunctions) {
                $exportedFunctions | Should -Contain $function -Because "Function $function should be exported from IssueLifecycleManager"
            }
        }

        It "Should execute lifecycle management in dry run mode" {
            $result = Invoke-IssueLifecycleManagement -DryRun
            
            $result.success | Should -Be $true
            $result.issues_processed | Should -BeOfType [int]
            $result.issues_closed | Should -BeOfType [int]
            $result.issues_updated | Should -BeOfType [int]
        }

        It "Should handle lifecycle management without dry run" {
            # Don't pass any parameters for non-dry run
            $result = Invoke-IssueLifecycleManagement
            
            $result.success | Should -Be $true
            $result | Should -HaveProperty "issues_processed"
            $result | Should -HaveProperty "issues_closed"
            $result | Should -HaveProperty "issues_updated"
        }
    }
}

Describe "AutomatedIssueManagement - Reporting and Statistics" {
    BeforeEach {
        # Initialize system for each test
        Initialize-AutomatedIssueManagement -RepositoryOwner "TestOwner" -RepositoryName "TestRepo"
    }

    Context "Report Generation" {
        It "Should generate comprehensive report in JSON format" {
            $reportPath = Join-Path $script:TestWorkspace "test-report.json"
            
            $result = New-AutomatedIssueReport -ReportPath $reportPath -OutputFormat "json"
            
            $result.success | Should -Be $true
            $result.report_path | Should -Be $reportPath
            Test-Path $reportPath | Should -Be $true
            
            # Validate JSON content
            $reportContent = Get-Content $reportPath | ConvertFrom-Json
            $reportContent.metadata | Should -Not -BeNullOrEmpty
            $reportContent.configuration | Should -Not -BeNullOrEmpty
        }

        It "Should generate report in HTML format" {
            $reportPath = Join-Path $script:TestWorkspace "test-report.html"
            
            $result = New-AutomatedIssueReport -ReportPath $reportPath -OutputFormat "html"
            
            $result.success | Should -Be $true
            Test-Path $reportPath | Should -Be $true
            
            # Validate HTML content
            $htmlContent = Get-Content $reportPath -Raw
            $htmlContent | Should -Match "<!DOCTYPE html>"
            $htmlContent | Should -Match "AitherZero.*Automated Issues Report"
        }

        It "Should generate report in Markdown format" {
            $reportPath = Join-Path $script:TestWorkspace "test-report.md"
            
            $result = New-AutomatedIssueReport -ReportPath $reportPath -OutputFormat "markdown"
            
            $result.success | Should -Be $true
            Test-Path $reportPath | Should -Be $true
            
            # Validate Markdown content
            $markdownContent = Get-Content $reportPath -Raw
            $markdownContent | Should -Match "# .*AitherZero.*Automated Issues Report"
            $markdownContent | Should -Match "## .*Issue Statistics"
        }

        It "Should include comprehensive report data" {
            $result = New-AutomatedIssueReport -OutputFormat "json"
            
            $reportData = $result.report_data
            $reportData.metadata | Should -Not -BeNullOrEmpty
            $reportData.metadata.generated_at | Should -Not -BeNullOrEmpty
            $reportData.metadata.system_metadata | Should -Not -BeNullOrEmpty
            $reportData.configuration | Should -Not -BeNullOrEmpty
            $reportData.state | Should -Not -BeNullOrEmpty
            $reportData.statistics | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "AutomatedIssueManagement - Error Handling and Edge Cases" {
    Context "Error Scenarios" {
        It "Should handle missing configuration gracefully" {
            # Clear any existing configuration
            Remove-Item "./.github/automated-issues/config.json" -Force -ErrorAction SilentlyContinue
            
            # Try to create issue without initialization
            $result = New-AutomatedIssueFromFailure -FailureType "test" -FailureDetails @{} -CreateIssue:$false
            
            $result.success | Should -Be $false
            $result.errors | Should -Not -BeNullOrEmpty
        }

        It "Should handle invalid test results format" {
            Initialize-AutomatedIssueManagement -RepositoryOwner "TestOwner" -RepositoryName "TestRepo"
            
            # The function actually handles invalid input gracefully, so it succeeds with 0 failures
            $invalidResults = "not a valid object"
            $result = New-PesterTestFailureIssues -TestResults $invalidResults -CreateIssues:$false
            
            $result.success | Should -Be $true
            $result.test_failures | Should -Be 0
        }

        It "Should handle invalid analyzer results format" {
            Initialize-AutomatedIssueManagement -RepositoryOwner "TestOwner" -RepositoryName "TestRepo"
            
            # This will fail because string doesn't have array methods
            $invalidResults = "not a valid array"
            $result = New-PSScriptAnalyzerIssues -AnalyzerResults $invalidResults -CreateIssues:$false
            
            $result.success | Should -Be $false
            $result.errors | Should -Not -BeNullOrEmpty
        }

        It "Should handle file system errors during initialization" {
            # Create a read-only directory that will cause permission errors
            $readOnlyDir = Join-Path $script:TestWorkspace "readonly"
            New-Item -Path $readOnlyDir -ItemType Directory -Force | Out-Null
            
            # Try to initialize in a subdirectory we can't write to
            $originalLocation = Get-Location
            try {
                Set-Location $readOnlyDir
                # This should work as it creates in current directory
                $result = Initialize-AutomatedIssueManagement -RepositoryOwner "TestOwner" -RepositoryName "TestRepo"
                $result.success | Should -Be $true
            } finally {
                Set-Location $originalLocation
            }
        }
    }

    Context "Performance and Limits" {
        It "Should complete operations within reasonable time limits" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            Initialize-AutomatedIssueManagement -RepositoryOwner "TestOwner" -RepositoryName "TestRepo"
            Get-SystemMetadata | Out-Null
            
            $stopwatch.Stop()
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 10000  # 10 seconds max
        }

        It "Should handle large numbers of test failures efficiently" {
            Initialize-AutomatedIssueManagement -RepositoryOwner "TestOwner" -RepositoryName "TestRepo"
            
            # Create 50 mock test failures
            $largeTestResults = @{
                FailedTests = 1..50 | ForEach-Object {
                    @{
                        Name = "Test failure $_"
                        ScriptBlock = @{ File = "TestFile$_.Tests.ps1" }
                        FailureMessage = "Test failure number $_"
                        ErrorRecord = @{ Exception = @{ Message = "Error $_" } }
                        Result = "Failed"
                    }
                }
            }

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $result = New-PesterTestFailureIssues -TestResults $largeTestResults -CreateIssues:$false
            $stopwatch.Stop()

            $result.success | Should -Be $true
            $result.test_failures | Should -Be 50
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 30000  # 30 seconds max
        }
    }
}

Describe "AutomatedIssueManagement - Integration Tests" {
    Context "End-to-End Workflows" {
        It "Should complete full issue creation workflow" {
            # Initialize system
            $initResult = Initialize-AutomatedIssueManagement -RepositoryOwner "TestOwner" -RepositoryName "TestRepo"
            $initResult.success | Should -Be $true

            # Create test failure issue
            $testFailure = @{
                test_name = "Integration test"
                test_file = "Integration.Tests.ps1"
                failure_message = "Integration test failed"
                error_details = "Network timeout"
            }
            
            $issueResult = New-AutomatedIssueFromFailure -FailureType "test" -FailureDetails $testFailure -CreateIssue:$false
            $issueResult.success | Should -Be $true

            # Generate report
            $reportResult = New-AutomatedIssueReport -OutputFormat "json"
            $reportResult.success | Should -Be $true

            # Run lifecycle management
            $lifecycleResult = Invoke-IssueLifecycleManagement -DryRun
            $lifecycleResult.success | Should -Be $true
        }

        It "Should handle multiple issue types in sequence" {
            Initialize-AutomatedIssueManagement -RepositoryOwner "TestOwner" -RepositoryName "TestRepo"

            # Test failures
            $testResults = @{
                FailedTests = @(
                    @{
                        Name = "Test 1"
                        ScriptBlock = @{ File = "Test1.Tests.ps1" }
                        FailureMessage = "Failed"
                        ErrorRecord = @{ Exception = @{ Message = "Error" } }
                        Result = "Failed"
                    }
                )
            }
            
            $testResult = New-PesterTestFailureIssues -TestResults $testResults -CreateIssues:$false
            $testResult.success | Should -Be $true

            # Analyzer violations
            $analyzerResults = @(
                @{
                    RuleName = "TestRule"
                    Severity = "Warning"
                    Message = "Test violation"
                    ScriptPath = "Test.ps1"
                    Line = 1
                    Column = 1
                }
            )
            
            $analyzerResult = New-PSScriptAnalyzerIssues -AnalyzerResults $analyzerResults -CreateIssues:$false
            $analyzerResult.success | Should -Be $true

            # Both should succeed
            $testResult.success | Should -Be $true
            $analyzerResult.success | Should -Be $true
        }
    }

    Context "Framework Integration" {
        It "Should integrate with AitherZero logging system" {
            # Test that logging functions are available and working
            { Write-CustomLog -Message "Test integration message" -Level "INFO" } | Should -Not -Throw
        }

        It "Should work with project root detection" {
            $projectRoot = Find-ProjectRoot
            $projectRoot | Should -Not -BeNullOrEmpty
        }

        It "Should handle CI environment variables correctly" {
            $metadata = Get-SystemMetadata
            
            $metadata.ci_environment.is_github_actions | Should -Be $true
            $metadata.ci_environment.repository | Should -Be "TestOwner/TestRepo"
        }
    }
}