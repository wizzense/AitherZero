@{
    Name = "integration-tests-full"
    Description = "Complete integration test suite - mirrors comprehensive-test-execution.yml"
    Version = "1.0.0"
    Author = "AitherZero"
    
    # Execute these scripts in sequence
    Sequence = @(
        @{
            Script = "0400"
            Description = "Phase 1: Install testing dependencies"
            Parameters = @{}
            ContinueOnError = $false
            Timeout = 300
            RetryCount = 1
        },
        @{
            Script = "0402"
            Description = "Phase 2: Run unit tests"
            Parameters = @{}
            ContinueOnError = $false
            Timeout = 300
            RetryCount = 1
        },
        @{
            Script = "0403"
            Description = "Phase 3: Run integration tests"
            Parameters = @{}
            ContinueOnError = $true
            Timeout = 600
            RetryCount = 1
        },
        @{
            Script = "0406"
            Description = "Phase 4: Generate code coverage report"
            Parameters = @{
                Format = "Html"
            }
            ContinueOnError = $true
            Timeout = 180
            RetryCount = 0
        },
        @{
            Script = "0512"
            Description = "Phase 5: Generate test dashboard"
            Parameters = @{
                Format = "HTML"
                IncludeTests = $true
            }
            ContinueOnError = $true
            Timeout = 120
            RetryCount = 0
        }
    )
    
    # Variables available to all scripts
    Variables = @{
        CI = "true"
        AITHERZERO_CI = "true"
        AITHERZERO_NONINTERACTIVE = "true"
        ReportsPath = "./reports"
        TestResultsPath = "./library/tests/results"
        CoverageThreshold = 70
    }
    
    # Execution options
    Options = @{
        Parallel = $false
        MaxConcurrency = 1
        StopOnError = $false
        CaptureOutput = $true
        GenerateSummary = $true
        SummaryFormat = "Markdown"
    }
    
    # Success criteria
    SuccessCriteria = @{
        RequireAllSuccess = $false
        MinimumSuccessCount = 3  # Unit tests, integration tests, and tools install must pass
        CriticalScripts = @(
            "0400_Install-TestingTools.ps1"
            "0402_Run-UnitTests.ps1"
        )
    }
    
    # Reporting
    Reporting = @{
        GenerateReport = $true
        ReportPath = "./reports/integration-test-summary.md"
        ReportFormat = "Markdown"
        IncludeTimings = $true
        IncludeLogs = $true
        IncludeCoverage = $true
    }
}
