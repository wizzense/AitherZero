@{
    Name = "pr-validation-full"
    Description = "Complete PR validation - mirrors GitHub Actions workflow checks"
    Version = "1.0.0"
    Author = "AitherZero"
    
    # Execute these scripts in sequence - mirrors .github/workflows/pr-validation.yml
    Sequence = @(
        @{
            Script = "0407"
            Description = "Phase 1: Syntax validation (fast feedback)"
            Parameters = @{
                All = $true
            }
            ContinueOnError = $false
            Timeout = 120
            RetryCount = 0
        },
        @{
            Script = "0404"
            Description = "Phase 2: PSScriptAnalyzer code quality check"
            Parameters = @{
                UseCache = $true
            }
            ContinueOnError = $false
            Timeout = 300
            RetryCount = 1
        },
        @{
            Script = "0402"
            Description = "Phase 3: Unit test execution"
            Parameters = @{}
            ContinueOnError = $false
            Timeout = 300
            RetryCount = 1
        },
        @{
            Script = "0420"
            Description = "Phase 4: Component quality validation"
            Parameters = @{
                Path = "./domains"
                Recursive = $true
            }
            ContinueOnError = $true
            Timeout = 180
            RetryCount = 0
        },
        @{
            Script = "0413"
            Description = "Phase 5: Configuration validation"
            Parameters = @{}
            ContinueOnError = $false
            Timeout = 60
            RetryCount = 0
        },
        @{
            Script = "0426"
            Description = "Phase 6: Test-script synchronization check"
            Parameters = @{}
            ContinueOnError = $true
            Timeout = 60
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
        EnableCache = $true
        FailFast = $false
    }
    
    # Execution options
    Options = @{
        Parallel = $false
        MaxConcurrency = 1
        StopOnError = $true
        CaptureOutput = $true
        GenerateSummary = $true
        SummaryFormat = "Markdown"
    }
    
    # Success criteria - all critical scripts listed below must pass for overall success
    SuccessCriteria = @{
        RequireAllSuccess = $false
        MinimumSuccessCount = 4  # At least 4 of 6 total scripts must pass
        # All scripts in CriticalScripts must pass; other scripts are optional
        CriticalScripts = @(
            "0407_Validate-Syntax.ps1"
            "0404_Run-PSScriptAnalyzer.ps1"
            "0402_Run-UnitTests.ps1"
            "0413_Validate-ConfigManifest.ps1"
        )
    }
    
    # Reporting
    Reporting = @{
        GenerateReport = $true
        ReportPath = "./reports/pr-validation-summary.md"
        ReportFormat = "Markdown"
        IncludeTimings = $true
        IncludeLogs = $true
    }
}
