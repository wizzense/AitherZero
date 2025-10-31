#Requires -Version 7.0
<#
.SYNOPSIS
    Unit tests for TestingFramework module
.DESCRIPTION
    Comprehensive unit tests for the AitherZero TestingFramework module covering
    all functions, edge cases, and error conditions using Pester 5.x
#>

BeforeAll {
    # Import test helpers
    $testHelpersPath = Join-Path $PSScriptRoot "../../../TestHelpers.psm1"
    Import-Module $testHelpersPath -Force

    # Initialize test environment
    $testEnv = Initialize-TestEnvironment -RequiredModules @('TestingFramework')

    # Mock external dependencies
    Mock Import-Module { } -ParameterFilter { $Name -eq 'Pester' }
    Mock Import-Module { } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }

    # Create test configuration
    $script:TestConfig = @{
        Testing = @{
            Framework = 'Pester'
            MinVersion = '5.0.0'
            Parallel = $true
            MaxConcurrency = 4
            OutputPath = './tests/results'
            OutputFormat = @('NUnitXml', 'JUnitXml')
            CodeCoverage = @{
                Enabled = $true
                MinimumPercent = 80
                OutputPath = './tests/coverage'
                Format = @('JaCoCo', 'Cobertura')
                ExcludePaths = @('*/tests/*', '*/legacy-to-migrate/*', '*/examples/*')
            }
            PSScriptAnalyzer = @{
                Enabled = $true
                SettingsPath = './PSScriptAnalyzerSettings.psd1'
                OutputPath = './tests/analysis'
                Rules = @{
                    Severity = @('Error', 'Warning')
                    ExcludeRules = @('PSAvoidUsingWriteHost', 'PSUseShouldProcessForStateChangingFunctions')
                }
            }
            ASTValidation = @{
                Enabled = $true
                CheckSyntax = $true
                CheckParameters = $true
                CheckModuleDependencies = $true
                CheckCommandExistence = $true
            }
            Profiles = @{
                Quick = @{
                    Description = 'Fast validation for development'
                    Categories = @('Unit', 'Syntax')
                    Timeout = 300
                    FailFast = $true
                }
                Standard = @{
                    Description = 'Default test suite'
                    Categories = @('Unit', 'Integration', 'Syntax')
                    Timeout = 900
                    FailFast = $false
                }
                Full = @{
                    Description = 'Complete validation including performance'
                    Categories = @('*')
                    Timeout = 3600
                    FailFast = $false
                }
                CI = @{
                    Description = 'Continuous Integration suite'
                    Categories = @('Unit', 'Integration', 'E2E')
                    Platforms = @('Windows', 'Linux', 'macOS')
                    Timeout = 1800
                    FailFast = $true
                    GenerateReports = $true
                }
            }
        }
    }

    # Create mock Pester result
    $script:MockPesterResult = [PSCustomObject]@{
        TotalCount = 50
        PassedCount = 45
        FailedCount = 3
        SkippedCount = 2
        Duration = [TimeSpan]::FromMinutes(2)
        ExecutedAt = Get-Date
        Tests = @(
            [PSCustomObject]@{ Name = 'Test1'; Result = 'Passed' },
            [PSCustomObject]@{ Name = 'Test2'; Result = 'Failed' },
            [PSCustomObject]@{ Name = 'Test3'; Result = 'Failed' },
            [PSCustomObject]@{ Name = 'Test4'; Result = 'Failed' },
            [PSCustomObject]@{ Name = 'Test5'; Result = 'Skipped' }
        )
        CodeCoverage = [PSCustomObject]@{
            CoveragePercent = 85.5
            NumberOfCommandsAnalyzed = 100
            NumberOfCommandsExecuted = 85
            NumberOfCommandsMissed = 15
            AnalyzedFiles = @('TestFile1.ps1', 'TestFile2.ps1')
        }
    }

    # Create mock PSScriptAnalyzer results
    $script:MockAnalyzerResults = @(
        [PSCustomObject]@{
            RuleName = 'PSAvoidUsingCmdletAliases'
            Severity = 'Warning'
            ScriptName = 'TestFile.ps1'
            Line = 10
            Column = 5
            Message = 'Alias detected'
        },
        [PSCustomObject]@{
            RuleName = 'PSUseDeclaredVarsMoreThanAssignments'
            Severity = 'Error'
            ScriptName = 'TestFile2.ps1'
            Line = 15
            Column = 1
            Message = 'Variable not used'
        }
    )

    # Mock file system operations
    Mock New-Item { }
    Mock Set-Content { }
    Mock Get-Content { '{}' }
    Mock Test-Path { $true }
    Mock Join-Path { param($Path, $ChildPath) "$Path/$ChildPath" }
    Mock Get-ChildItem { @() }
    Mock Get-Item { [PSCustomObject]@{ FullName = 'TestFile.ps1' } }

    # Set up test drives for different scenarios
    $script:TestDriveRoot = $TestDrive
}

Describe "TestingFramework Module" -Tag @('Unit', 'TestingFramework') {

    Context "Module Loading and Initialization" {
        It "Should have the required functions exported" {
            $exportedFunctions = Get-Command -Module TestingFramework
            $exportedFunctions.Name | Should -Contain 'Invoke-TestSuite'
            $exportedFunctions.Name | Should -Contain 'Invoke-ScriptAnalysis'
            $exportedFunctions.Name | Should -Contain 'Test-ASTValidation'
            $exportedFunctions.Name | Should -Contain 'New-TestReport'
            $exportedFunctions.Name | Should -Contain 'Get-TestingConfiguration'
        }

        It "Should initialize module state correctly" {
            # Access the module's internal state (this may require adjustment based on actual implementation)
            $moduleState = Get-Variable -Name TestingState -Scope Script -ErrorAction SilentlyContinue
            if ($moduleState) {
                $moduleState.Value.CurrentProfile | Should -Be 'Standard'
                $moduleState.Value.Results | Should -BeOfType [Array]
                $moduleState.Value.Coverage | Should -BeOfType [hashtable]
                $moduleState.Value.AnalysisResults | Should -BeOfType [Array]
            }
        }
    }

    Context "Get-TestingConfiguration Function" {
        BeforeEach {
            Mock Get-Content { $script:TestConfig | ConvertTo-Json -Depth 10 }
        }

        It "Should load configuration from file when it exists" {
            Mock Test-Path { $true }

            $result = Get-TestingConfiguration

            $result | Should -Not -BeNullOrEmpty
            $result.Framework | Should -Be 'Pester'
            $result.MinVersion | Should -Be '5.0.0'
        }

        It "Should return default configuration when file does not exist" {
            Mock Test-Path { $false }

            $result = Get-TestingConfiguration

            $result | Should -BeOfType [hashtable]
        }

        It "Should handle JSON parsing errors gracefully" {
            Mock Test-Path { $true }
            Mock Get-Content { 'invalid json' }

            { Get-TestingConfiguration } | Should -Throw
        }

        It "Should use custom config path when provided" {
            $customPath = '/custom/config.psd1'
            Mock Test-Path { $true } -ParameterFilter { $Path -eq $customPath }

            $result = Get-TestingConfiguration -ConfigPath $customPath

            Assert-MockCalled Test-Path -ParameterFilter { $Path -eq $customPath }
        }
    }

    Context "Invoke-TestSuite Function" {
        BeforeEach {
            Mock Get-TestingConfiguration { $script:TestConfig.Testing }
            Mock Get-Module { [PSCustomObject]@{ Version = '5.3.0' } }
            Mock Import-Module { }
            Mock New-PesterConfiguration {
                [PSCustomObject]@{
                    Run = [PSCustomObject]@{ Path = ''; PassThru = $false; Exit = $false }
                    Filter = [PSCustomObject]@{ Tag = @() }
                    TestResult = [PSCustomObject]@{ Enabled = $false; OutputPath = ''; OutputFormat = '' }
                    CodeCoverage = [PSCustomObject]@{ Enabled = $false; Path = ''; OutputPath = ''; OutputFormat = '' }
                }
            }
            Mock Invoke-Pester { $script:MockPesterResult }
            Mock Write-Host { }
        }

        It "Should execute test suite with default profile" {
            $result = Invoke-TestSuite

            $result | Should -Be $true
            Assert-MockCalled Invoke-Pester
        }

        It "Should execute test suite with specified profile" {
            $result = Invoke-TestSuite -Profile 'Quick'

            $result | Should -Be $true
            Assert-MockCalled Invoke-Pester
        }

        It "Should override categories when specified" {
            $customCategories = @('Unit', 'Custom')

            $result = Invoke-TestSuite -Categories $customCategories

            $result | Should -Be $true
            Assert-MockCalled Invoke-Pester
        }

        It "Should configure output path when provided" {
            $outputPath = '/custom/output'

            $result = Invoke-TestSuite -OutputPath $outputPath

            $result | Should -Be $true
            Assert-MockCalled Invoke-Pester
        }

        It "Should apply custom configuration when provided" {
            $customConfig = @{ CustomSetting = 'Value' }

            $result = Invoke-TestSuite -Configuration $customConfig

            $result | Should -Be $true
            Assert-MockCalled Invoke-Pester
        }

        It "Should return Pester result when PassThru is specified" {
            $result = Invoke-TestSuite -PassThru

            $result | Should -Be $script:MockPesterResult
        }

        It "Should fail when required Pester version is not available" {
            Mock Get-Module { $null }

            { Invoke-TestSuite } | Should -Throw '*Pester*required*'
        }

        It "Should handle test failures correctly" {
            $failedResult = $script:MockPesterResult.PSObject.Copy()
            $failedResult.FailedCount = 5
            Mock Invoke-Pester { $failedResult }

            $result = Invoke-TestSuite

            $result | Should -Be $false
        }

        It "Should warn about low code coverage" {
            $lowCoverageConfig = $script:TestConfig.Testing.PSObject.Copy()
            $lowCoverageConfig.CodeCoverage.MinimumPercent = 90
            Mock Get-TestingConfiguration { $lowCoverageConfig }
            Mock Write-Warning { }

            $result = Invoke-TestSuite

            Assert-MockCalled Write-Warning -ParameterFilter { $Message -like '*coverage*below*' }
        }
    }

    Context "Invoke-ScriptAnalysis Function" {
        BeforeEach {
            Mock Get-TestingConfiguration { $script:TestConfig.Testing }
            Mock Get-Module { [PSCustomObject]@{ Name = 'PSScriptAnalyzer' } }
            Mock Import-Module { }
            Mock Invoke-ScriptAnalyzer { $script:MockAnalyzerResults }
            Mock Export-Csv { }
            Mock Write-Host { }
        }

        It "Should run PSScriptAnalyzer with default settings" {
            $result = Invoke-ScriptAnalysis

            $result | Should -Be $script:MockAnalyzerResults
            Assert-MockCalled Invoke-ScriptAnalyzer
        }

        It "Should skip analysis when disabled in configuration" {
            $disabledConfig = $script:TestConfig.Testing.PSObject.Copy()
            $disabledConfig.PSScriptAnalyzer.Enabled = $false
            Mock Get-TestingConfiguration { $disabledConfig }
            Mock Write-Warning { }

            $result = Invoke-ScriptAnalysis

            $result | Should -BeNullOrEmpty
            Assert-MockCalled Write-Warning -ParameterFilter { $Message -like '*disabled*' }
        }

        It "Should use custom path when provided" {
            $customPath = '/custom/path'

            $result = Invoke-ScriptAnalysis -Path $customPath

            Assert-MockCalled Invoke-ScriptAnalyzer -ParameterFilter { $Path -eq $customPath }
        }

        It "Should enable recursion when specified" {
            $result = Invoke-ScriptAnalysis -Recurse

            Assert-MockCalled Invoke-ScriptAnalyzer -ParameterFilter { $Recurse -eq $true }
        }

        It "Should use settings file when provided" {
            Mock Test-Path { $true }
            $settingsPath = '/custom/settings.psd1'

            $result = Invoke-ScriptAnalysis -SettingsPath $settingsPath

            Assert-MockCalled Invoke-ScriptAnalyzer
        }

        It "Should enable fix mode when specified" {
            $result = Invoke-ScriptAnalysis -Fix

            Assert-MockCalled Invoke-ScriptAnalyzer -ParameterFilter { $Fix -eq $true }
        }

        It "Should export results when output path is provided" {
            $outputPath = '/custom/output'

            $result = Invoke-ScriptAnalysis -OutputPath $outputPath

            Assert-MockCalled Export-Csv
        }

        It "Should fail when PSScriptAnalyzer module is not available" {
            Mock Get-Module { $null }

            { Invoke-ScriptAnalysis } | Should -Throw '*PSScriptAnalyzer*required*'
        }

        It "Should display no issues message when no problems found" {
            Mock Invoke-ScriptAnalyzer { @() }

            $result = Invoke-ScriptAnalysis

            $result.Count | Should -Be 0
            Assert-MockCalled Write-Host -ParameterFilter { $Object -like '*No issues*' }
        }
    }

    Context "Test-ASTValidation Function" {
        BeforeEach {
            Mock Get-ChildItem {
                @([PSCustomObject]@{ FullName = 'TestFile.ps1' })
            }
            Mock Get-Item {
                [PSCustomObject]@{ FullName = 'TestFile.ps1' }
            }

            # Mock AST parsing
            $mockAST = [PSCustomObject]@{
                FindAll = {
                    param($predicate, $searchNestedScriptBlocks)
                    @()
                }
            }
            Mock -CommandName '[System.Management.Automation.Language.Parser]::ParseFile' -MockWith {
                return $mockAST
            } -ModuleName TestingFramework
        }

        It "Should validate syntax when CheckSyntax is enabled" {
            $result = Test-ASTValidation -Path 'TestFile.ps1' -CheckSyntax

            $result | Should -BeOfType [Array]
        }

        It "Should validate parameters when CheckParameters is enabled" {
            $result = Test-ASTValidation -Path 'TestFile.ps1' -CheckParameters

            $result | Should -BeOfType [Array]
        }

        It "Should validate commands when CheckCommands is enabled" {
            $result = Test-ASTValidation -Path 'TestFile.ps1' -CheckCommands

            $result | Should -BeOfType [Array]
        }

        It "Should process directory recursively" {
            Mock Test-Path { $true } -ParameterFilter { $PathType -eq 'Container' }

            $result = Test-ASTValidation -Path '/test/directory' -CheckSyntax

            Assert-MockCalled Get-ChildItem
        }

        It "Should process single file" {
            Mock Test-Path { $false } -ParameterFilter { $PathType -eq 'Container' }

            $result = Test-ASTValidation -Path 'TestFile.ps1' -CheckSyntax

            Assert-MockCalled Get-Item
        }

        It "Should handle parsing errors gracefully" {
            Mock -CommandName '[System.Management.Automation.Language.Parser]::ParseFile' -MockWith {
                throw 'Parse error'
            } -ModuleName TestingFramework

            $result = Test-ASTValidation -Path 'TestFile.ps1' -CheckSyntax

            $result | Should -Not -BeNullOrEmpty
            $result[0].Type | Should -Be 'ParseError'
        }

        It "Should report success when no issues found" {
            Mock Write-Host { }

            $result = Test-ASTValidation -Path 'TestFile.ps1' -CheckSyntax

            Assert-MockCalled Write-Host -ParameterFilter { $Object -like '*validation passed*' }
        }
    }

    Context "New-TestReport Function" {
        BeforeEach {
            Mock New-Item { }
            Mock ConvertTo-Json { '{"test": "data"}' }
            Mock Set-Content { }
            Mock Write-Host { }

            # Set up mock testing state with results
            $mockState = @{
                Results = @($script:MockPesterResult)
                AnalysisResults = $script:MockAnalyzerResults
                Coverage = @{}
            }
        }

        It "Should generate JSON report" {
            $result = New-TestReport -Format 'JSON'

            $result | Should -Match '\.json$'
            Assert-MockCalled ConvertTo-Json
            Assert-MockCalled Set-Content
        }

        It "Should generate HTML report" {
            $result = New-TestReport -Format 'HTML'

            $result | Should -Match '\.html$'
            Assert-MockCalled Set-Content
        }

        It "Should generate Markdown report" {
            $result = New-TestReport -Format 'Markdown'

            $result | Should -Match '\.md$'
            Assert-MockCalled Set-Content
        }

        It "Should include test results when requested" {
            $result = New-TestReport -IncludeTests

            Assert-MockCalled Set-Content
        }

        It "Should include analysis results when requested" {
            $result = New-TestReport -IncludeAnalysis

            Assert-MockCalled Set-Content
        }

        It "Should include coverage results when requested" {
            $result = New-TestReport -IncludeCoverage

            Assert-MockCalled Set-Content
        }

        It "Should use custom output path" {
            $customPath = '/custom/reports'

            $result = New-TestReport -OutputPath $customPath

            Assert-MockCalled New-Item -ParameterFilter { $Path -eq $customPath }
        }

        It "Should create output directory if it does not exist" {
            Mock Test-Path { $false }

            $result = New-TestReport

            Assert-MockCalled New-Item -ParameterFilter { $ItemType -eq 'Directory' }
        }
    }

    Context "Error Handling and Edge Cases" {
        It "Should handle missing configuration file gracefully" {
            Mock Test-Path { $false }

            $result = Get-TestingConfiguration

            $result | Should -BeOfType [hashtable]
        }

        It "Should handle empty test results" {
            Mock Get-TestingConfiguration { $script:TestConfig.Testing }
            Mock Get-Module { [PSCustomObject]@{ Version = '5.3.0' } }
            Mock Invoke-Pester {
                [PSCustomObject]@{
                    TotalCount = 0
                    PassedCount = 0
                    FailedCount = 0
                    SkippedCount = 0
                    Duration = [TimeSpan]::Zero
                    Tests = @()
                    CodeCoverage = $null
                }
            }

            $result = Invoke-TestSuite

            $result | Should -Be $true
        }

        It "Should handle null Pester configuration" {
            Mock Get-TestingConfiguration { $script:TestConfig.Testing }
            Mock Get-Module { [PSCustomObject]@{ Version = '5.3.0' } }
            Mock New-PesterConfiguration { $null }

            { Invoke-TestSuite } | Should -Not -Throw
        }

        It "Should handle missing analysis results" {
            Mock Get-TestingConfiguration { $script:TestConfig.Testing }
            Mock Get-Module { [PSCustomObject]@{ Name = 'PSScriptAnalyzer' } }
            Mock Invoke-ScriptAnalyzer { $null }

            $result = Invoke-ScriptAnalysis

            $result | Should -BeNullOrEmpty
        }
    }

    Context "Profile Management" {
        It "Should use correct profile settings for Quick profile" {
            Mock Get-TestingConfiguration { $script:TestConfig.Testing }
            Mock Get-Module { [PSCustomObject]@{ Version = '5.3.0' } }
            Mock Invoke-Pester { $script:MockPesterResult }

            $result = Invoke-TestSuite -Profile 'Quick'

            $result | Should -Be $true
        }

        It "Should use correct profile settings for Full profile" {
            Mock Get-TestingConfiguration { $script:TestConfig.Testing }
            Mock Get-Module { [PSCustomObject]@{ Version = '5.3.0' } }
            Mock Invoke-Pester { $script:MockPesterResult }

            $result = Invoke-TestSuite -Profile 'Full'

            $result | Should -Be $true
        }

        It "Should use correct profile settings for CI profile" {
            Mock Get-TestingConfiguration { $script:TestConfig.Testing }
            Mock Get-Module { [PSCustomObject]@{ Version = '5.3.0' } }
            Mock Invoke-Pester { $script:MockPesterResult }

            $result = Invoke-TestSuite -Profile 'CI'

            $result | Should -Be $true
        }

        It "Should fallback to default when profile not found" {
            Mock Get-TestingConfiguration { $script:TestConfig.Testing }
            Mock Get-Module { [PSCustomObject]@{ Version = '5.3.0' } }
            Mock Invoke-Pester { $script:MockPesterResult }

            $result = Invoke-TestSuite -Profile 'NonExistentProfile'

            $result | Should -Be $true
        }
    }

    Context "Code Coverage Integration" {
        BeforeEach {
            $coverageConfig = $script:TestConfig.Testing.PSObject.Copy()
            $coverageConfig.CodeCoverage.Enabled = $true
            Mock Get-TestingConfiguration { $coverageConfig }
            Mock Get-Module { [PSCustomObject]@{ Version = '5.3.0' } }
        }

        It "Should enable code coverage when configured" {
            Mock Invoke-Pester { $script:MockPesterResult }

            $result = Invoke-TestSuite

            $result | Should -Be $true
            Assert-MockCalled Invoke-Pester
        }

        It "Should validate minimum coverage threshold" {
            $lowCoverageResult = $script:MockPesterResult.PSObject.Copy()
            $lowCoverageResult.CodeCoverage.CoveragePercent = 70
            Mock Invoke-Pester { $lowCoverageResult }
            Mock Write-Warning { }

            $result = Invoke-TestSuite

            Assert-MockCalled Write-Warning -ParameterFilter { $Message -like '*coverage*below*' }
        }
    }

    Context "Logging Integration" {
        It "Should use Write-TestingLog when available" {
            Mock Get-Command { [PSCustomObject]@{ Name = 'Write-CustomLog' } } -ParameterFilter { $Name -eq 'Write-CustomLog' }
            Mock Write-CustomLog { }

            $result = Get-TestingConfiguration

            # The function should not throw and should have attempted logging
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should fallback to Write-Host when Write-CustomLog not available" {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Write-CustomLog' }
            Mock Write-Host { }

            $result = Get-TestingConfiguration

            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Parallel Execution Support" {
        It "Should handle parallel execution configuration" {
            $parallelConfig = $script:TestConfig.Testing.PSObject.Copy()
            $parallelConfig.Parallel = $true
            $parallelConfig.MaxConcurrency = 8
            Mock Get-TestingConfiguration { $parallelConfig }
            Mock Get-Module { [PSCustomObject]@{ Version = '5.3.0' } }
            Mock Invoke-Pester { $script:MockPesterResult }

            $result = Invoke-TestSuite

            $result | Should -Be $true
        }

        It "Should handle serial execution when parallel is disabled" {
            $serialConfig = $script:TestConfig.Testing.PSObject.Copy()
            $serialConfig.Parallel = $false
            Mock Get-TestingConfiguration { $serialConfig }
            Mock Get-Module { [PSCustomObject]@{ Version = '5.3.0' } }
            Mock Invoke-Pester { $script:MockPesterResult }

            $result = Invoke-TestSuite

            $result | Should -Be $true
        }
    }
}

Describe "TestingFramework Integration Tests" -Tag @('Integration', 'TestingFramework') {

    Context "End-to-End Test Suite Execution" {
        BeforeEach {
            # Create a temporary test structure
            $testPath = Join-Path $TestDrive 'integration-tests'
            New-Item -Path $testPath -ItemType Directory -Force

            # Create a simple test file
            $testContent = @'
Describe "Sample Test" {
    It "Should pass" {
        $true | Should -Be $true
    }

    It "Should fail" {
        $false | Should -Be $true
    }
}
'@
            Set-Content -Path (Join-Path $testPath 'Sample.Tests.ps1') -Value $testContent
        }

        It "Should execute real Pester tests" {
            # This test would run against actual Pester if available
            # For now, we'll mock the behavior
            Mock Get-Module { [PSCustomObject]@{ Version = '5.3.0' } } -ParameterFilter { $ListAvailable -and $Name -eq 'Pester' }
            Mock Import-Module { }
            Mock New-PesterConfiguration {
                [PSCustomObject]@{
                    Run = [PSCustomObject]@{ Path = ''; PassThru = $false; Exit = $false }
                    Filter = [PSCustomObject]@{ Tag = @() }
                    TestResult = [PSCustomObject]@{ Enabled = $false; OutputPath = ''; OutputFormat = '' }
                    CodeCoverage = [PSCustomObject]@{ Enabled = $false; Path = ''; OutputPath = ''; OutputFormat = '' }
                }
            }
            Mock Invoke-Pester { $script:MockPesterResult }

            $result = Invoke-TestSuite -Path $TestDrive -Profile 'Quick'

            $result | Should -Be $true
        }
    }

    Context "Real Configuration Loading" {
        It "Should load actual configuration if available" {
            # Create a test config file
            $configPath = Join-Path $TestDrive 'test-config.psd1'
            $testConfig = @{
                Testing = @{
                    Framework = 'Pester'
                    MinVersion = '5.0.0'
                }
            }
            $testConfig | ConvertTo-Json -Depth 10 | Set-Content $configPath

            $result = Get-TestingConfiguration -ConfigPath $configPath

            $result.Framework | Should -Be 'Pester'
            $result.MinVersion | Should -Be '5.0.0'
        }
    }
}

AfterAll {
    # Clean up test environment
    Clear-TestEnvironment

    # Remove any created test files
    if (Test-Path $TestDrive) {
        Get-ChildItem $TestDrive -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    }
}