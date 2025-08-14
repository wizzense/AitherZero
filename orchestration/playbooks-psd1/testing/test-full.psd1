#Requires -Version 7.0
<#
.SYNOPSIS
    test-full - Comprehensive test suite
.DESCRIPTION
    Complete test suite including unit tests, integration tests, code coverage,
    static analysis, and performance benchmarks. Suitable for pre-release validation.
.NOTES
    Version: 2.0.0
    Author: AitherZero Testing Framework
#>

@{
    # Metadata
    Name = 'test-full'
    Description = 'Comprehensive test suite with coverage and analysis'
    Version = '2.0.0'
    Author = 'AitherZero Testing Framework'
    Created = '2025-01-13T00:00:00Z'
    
    # Categorization
    Tags = @('testing', 'comprehensive', 'coverage', 'validation', 'pre-release')
    Category = 'Testing'
    
    # Requirements
    Requirements = @{
        Modules = @('Pester', 'PSScriptAnalyzer', 'PSCodeCoverage')
        MinimumVersion = '7.0'
        EstimatedDuration = '30-45 minutes'
        DiskSpace = '500MB'
    }
    
    # Default Variables
    Variables = @{
        TestPath = './tests'
        OutputPath = './tests/results'
        RunCoverage = $true
        CoverageThreshold = 80
        FailFast = $false
        Parallel = $true
        MaxConcurrency = 8
        GenerateReports = $true
    }
    
    # Execution Stages
    Stages = @(
        @{
            Name = 'Environment Preparation'
            Description = 'Prepare test environment and install dependencies'
            Sequence = @('0400', '0401')
            ContinueOnError = $false
            Timeout = 120
        }
        @{
            Name = 'Unit Tests with Coverage'
            Description = 'Run all unit tests with code coverage analysis'
            Sequence = @('0402')
            Variables = @{
                RunCoverage = $true
                OutputFormat = @('NUnitXml', 'JaCoCo')
            }
            ContinueOnError = $false
            Timeout = 900
        }
        @{
            Name = 'Integration Tests'
            Description = 'Run integration and end-to-end tests'
            Sequence = @('0403')
            Variables = @{
                TestType = 'Integration'
                IncludeSlowTests = $true
            }
            ContinueOnError = $false
            Timeout = 600
        }
        @{
            Name = 'Static Code Analysis'
            Description = 'Comprehensive PSScriptAnalyzer validation'
            Sequence = @('0404')
            Variables = @{
                Severity = @('Error', 'Warning', 'Information')
                IncludeDefaultRules = $true
                CustomRulePath = './tests/rules'
            }
            ContinueOnError = $false
            Timeout = 300
        }
        @{
            Name = 'AST Analysis'
            Description = 'Deep syntax and structure validation'
            Sequence = @('0405', '0407')
            Variables = @{
                CheckSyntax = $true
                CheckParameters = $true
                CheckCommands = $true
                CheckModuleDependencies = $true
            }
            ContinueOnError = $true
            Timeout = 240
        }
        @{
            Name = 'Performance Tests'
            Description = 'Run performance benchmarks'
            Sequence = @('0408')
            Variables = @{
                BenchmarkIterations = 10
                WarmupIterations = 3
            }
            ContinueOnError = $true
            Timeout = 600
        }
        @{
            Name = 'Generate Reports'
            Description = 'Create comprehensive test reports'
            Sequence = @('0450', '0510')
            Variables = @{
                Format = @('HTML', 'JSON', 'Markdown')
                IncludeCoverage = $true
                IncludeMetrics = $true
            }
            ContinueOnError = $true
            Timeout = 180
        }
    )
    
    # Quality Gates
    QualityGates = @{
        Coverage = @{
            Threshold = 80
            FailBuild = $true
        }
        Tests = @{
            MinimumPassRate = 100
            AllowSkipped = $false
        }
        Analysis = @{
            MaxErrors = 0
            MaxWarnings = 10
        }
    }
    
    # Notifications
    Notifications = @{
        OnSuccess = @{
            Message = '✅ Full test suite passed with {PassRate}% success rate'
            Level = 'Success'
            ShowSummary = $true
            GenerateBadge = $true
        }
        OnFailure = @{
            Message = '❌ Full test suite failed - {FailedCount} tests failed'
            Level = 'Error'
            ShowDetails = $true
            CreateIssue = $true
        }
        OnCoverageBelowThreshold = @{
            Message = '⚠️ Code coverage {Coverage}% is below threshold {Threshold}%'
            Level = 'Warning'
        }
    }
    
    # Post Actions
    PostActions = @(
        @{
            Name = 'Publish Results'
            Description = 'Publish test results to dashboard'
            Type = 'Script'
            Script = {
                ./automation-scripts/0450_Publish-TestResults.ps1
            }
        }
        @{
            Name = 'Archive Artifacts'
            Description = 'Archive test artifacts for later analysis'
            Type = 'Command'
            Command = 'Compress-Archive -Path ./tests/results/* -DestinationPath ./tests/archive/results-$(Get-Date -Format yyyyMMdd-HHmmss).zip'
        }
    )
    
    # Integration Points
    Integrations = @{
        CI = @{
            Enabled = $true
            ArtifactPaths = @('./tests/results', './tests/coverage')
            PublishTestResults = $true
            PublishCodeCoverage = $true
        }
        GitHub = @{
            Enabled = $true
            StatusCheck = 'required'
            CommentOnPR = $true
        }
    }
}