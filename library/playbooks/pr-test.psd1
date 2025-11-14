@{
    Name = "pr-test"
    Description = "PR Test Phase - Tests, quality, security, diffs"
    Version = "2.0.0"
    Author = "AitherZero"
    Tags = @("pr", "test", "quality", "security", "analysis")
    
    # Analysis phase - parallel execution for speed
    Sequence = @(
        # Test execution (parallel group 1)
        @{
            Script = "0402"
            Description = "Execute unit tests with coverage"
            Parameters = @{
                CodeCoverage = $true
                OutputFormat = "NUnitXml"
                PassThru = $true
            }
            ContinueOnError = $true  # Don't stop analysis if tests fail
            Timeout = 600
            Phase = "test"
            Parallel = $true
            Group = 1
        },
        @{
            Script = "0403"
            Description = "Execute integration tests"
            Parameters = @{
                OutputFormat = "NUnitXml"
                PassThru = $true
            }
            ContinueOnError = $true
            Timeout = 600
            Phase = "test"
            Parallel = $true
            Group = 1
        },
        
        # Quality analysis (parallel group 2)
        @{
            Script = "0404"
            Description = "Code quality analysis"
            Parameters = @{
                Fast = $false
                ReportPath = "library/reports/quality-analysis.json"
                CompareBranch = $env:GITHUB_BASE_REF
            }
            ContinueOnError = $true
            Timeout = 300
            Phase = "quality"
            Parallel = $true
            Group = 2
        },
        @{
            Script = "0420"
            Description = "Component quality validation"
            Parameters = @{
                Path = "./aithercore"
                Recursive = $true
                GenerateReport = $true
            }
            ContinueOnError = $true
            Timeout = 300
            Phase = "quality"
            Parallel = $true
            Group = 2
        },
        
        # Documentation analysis (parallel group 3)
        @{
            Script = "0521"
            Description = "Documentation coverage analysis"
            Parameters = @{
                IncludeMetrics = $true
                GenerateReport = $true
            }
            ContinueOnError = $true
            Timeout = 180
            Phase = "documentation"
            Parallel = $true
            Group = 3
        },
        @{
            Script = "0425"
            Description = "Documentation structure validation"
            Parameters = @{}
            ContinueOnError = $true
            Timeout = 120
            Phase = "documentation"
            Parallel = $true
            Group = 3
        },
        
        # Security analysis (parallel group 4)
        @{
            Script = "0523"
            Description = "Security vulnerability scan"
            Parameters = @{
                ScanCredentials = $true
                ScanDependencies = $true
                GenerateReport = $true
            }
            ContinueOnError = $true
            Timeout = 300
            Phase = "security"
            Parallel = $true
            Group = 4
        },
        
        # Diff and change analysis (sequential, after all parallel)
        @{
            Script = "0514"
            Description = "PR diff and impact analysis"
            Parameters = @{
                BaseBranch = $env:GITHUB_BASE_REF
                HeadBranch = $env:GITHUB_HEAD_REF
                IncludeComplexity = $true
                IncludeFunctionLevel = $true
                OutputPath = "library/reports/diff-analysis.json"
            }
            ContinueOnError = $false
            Timeout = 180
            Phase = "diff"
            Parallel = $false
        },
        
        # Aggregate results (sequential, final step)
        @{
            Script = "0517"
            Description = "Aggregate all analysis results"
            Parameters = @{
                SourcePath = "library/reports"
                OutputPath = "library/reports/analysis-summary.json"
                IncludeComparison = $true
                GenerateRecommendations = $true
            }
            ContinueOnError = $false
            Timeout = 120
            Phase = "aggregate"
            Parallel = $false
        }
    )
    
    # Variables available to all scripts
    Variables = @{
        CI = $env:CI
        AITHERZERO_CI = "true"
        AITHERZERO_NONINTERACTIVE = "true"
        ANALYSIS_PHASE = "pr-test"
        GITHUB_BASE_REF = $env:GITHUB_BASE_REF
        GITHUB_HEAD_REF = $env:GITHUB_HEAD_REF
        PR_NUMBER = $env:PR_NUMBER
    }
    
    # Execution options
    Options = @{
        Parallel = $true
        MaxConcurrency = 4  # 4 parallel groups
        StopOnError = $false  # Continue even if some tests fail
        CaptureOutput = $true
        GenerateSummary = $true
        SummaryFormat = "JSON"
        SummaryPath = "library/reports/analysis-orchestration-summary.json"
    }
    
    # Success criteria - allow some failures in analysis
    SuccessCriteria = @{
        RequireAllSuccess = $false
        MinimumSuccessCount = 6  # At least 6 of 9 must succeed
        AllowedFailures = @(
            "0402_Run-UnitTests.ps1",  # Tests can fail but we still want results
            "0403_Run-IntegrationTests.ps1",
            "0420_Validate-ComponentQuality.ps1"
        )
    }
    
    # Artifacts to track
    Artifacts = @{
        Required = @(
            "library/reports/analysis-summary.json",
            "library/reports/diff-analysis.json"
        )
        Optional = @(
            "library/tests/results/*.xml",
            "library/tests/coverage/**",
            "library/reports/quality-analysis.json",
            "library/reports/security-report.json"
        )
    }
    
    # Reporting
    Reporting = @{
        GenerateReport = $true
        IncludeTimings = $true
        IncludeArtifacts = $true
        IncludeFailures = $true
        ReportPath = "library/reports/analysis-report.md"
    }
}
