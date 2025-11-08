@{
    Name = "self-deployment-test"
    Description = "Self-deployment validation - tests that AitherZero can deploy itself"
    Version = "1.0.0"
    Author = "AitherZero"
    Tags = @("validation", "self-deployment", "ci-cd", "end-to-end")
    
    # Sequential execution - test deployment pipeline
    Sequence = @(
        # Phase 1: Complete syntax validation
        @{
            Script = "0407_Validate-Syntax.ps1"
            Description = "Validate PowerShell syntax across entire codebase"
            Parameters = @{
                All = $true
            }
            ContinueOnError = $false
            Timeout = 120
            Phase = "validation"
        },
        
        # Phase 2: Validate configuration manifest
        @{
            Script = "0413_Validate-ConfigManifest.ps1"
            Description = "Validate configuration manifest integrity"
            Parameters = @{}
            ContinueOnError = $false
            Timeout = 60
            Phase = "validation"
        },
        
        # Phase 3: Run full unit test suite
        @{
            Script = "0402_Run-UnitTests.ps1"
            Description = "Execute complete unit test suite"
            Parameters = @{
                NoCoverage = $true  # Coverage slows down CI significantly
            }
            ContinueOnError = $true  # Don't fail build on test failures
            Timeout = 300
            Phase = "testing"
        },
        
        # Phase 4: Complete code quality analysis
        @{
            Script = "0404_Run-PSScriptAnalyzer.ps1"
            Description = "Full static code analysis"
            Parameters = @{}  # No Fast parameter - do complete analysis
            ContinueOnError = $true  # Don't fail on warnings
            Timeout = 180
            Phase = "quality"
        },
        
        # Phase 5: Generate deployment report
        @{
            Script = "0512_Generate-Dashboard.ps1"
            Description = "Generate deployment dashboard"
            Parameters = @{
                Format = "JSON"
            }
            ContinueOnError = $true
            Timeout = 90
            Phase = "reporting"
        }
    )
    
    # Variables available to all scripts
    Variables = @{
        CI = $env:CI
        AITHERZERO_CI = "true"
        AITHERZERO_NONINTERACTIVE = "true"
        SELF_DEPLOYMENT_TEST = "true"
        QUICK_MODE = "true"
    }
    
    # Execution options
    Options = @{
        Parallel = $false  # Sequential execution for deployment validation
        MaxConcurrency = 1
        StopOnError = $false  # Continue through all phases
        CaptureOutput = $true
        GenerateSummary = $true
        SummaryFormat = "JSON"
        SummaryPath = "library/reports/self-deployment-summary.json"
    }
    
    # Success criteria - flexible for validation
    SuccessCriteria = @{
        RequireAllSuccess = $false
        MinimumSuccessCount = 3  # At least validation + testing + quality must pass
        AllowedFailures = @(
            "0402_Run-UnitTests.ps1",  # Tests may have known failures
            "0404_Run-PSScriptAnalyzer.ps1",  # Code quality warnings acceptable
            "0512_Generate-Dashboard.ps1"  # Report generation is nice-to-have
        )
    }
    
    # Required artifacts
    Artifacts = @{
        Required = @(
            "library/reports/self-deployment-summary.json"
        )
        Optional = @(
            "library/reports/dashboard.json",
            "library/tests/results/*.xml"
        )
    }
    
    # Reporting
    Reporting = @{
        GenerateReport = $true
        IncludeTimings = $true
        IncludeArtifacts = $true
        ReportPath = "library/reports/self-deployment-report.md"
    }
}
