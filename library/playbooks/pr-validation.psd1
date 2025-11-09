@{
    Name = "pr-validation"
    Description = "Comprehensive PR validation - syntax, config, quality, and tests"
    Version = "2.0.0"
    Author = "AitherZero"
    Tags = @("pr", "validation", "quality", "ci")
    
    # Execute these scripts in sequence - complete PR validation
    Sequence = @(
        @{
            Script = "0003"
            Description = "Phase 1: Sync and validate config manifest with repository"
            Parameters = @{}
            ContinueOnError = $false
            Timeout = 60
            RetryCount = 0
        },
        @{
            Script = "0407"
            Description = "Phase 2: Validate PowerShell syntax"
            Parameters = @{
                All = $true
            }
            ContinueOnError = $false
            Timeout = 120
            RetryCount = 0
        },
        @{
            Script = "0413"
            Description = "Phase 3: Validate config.psd1 manifest"
            Parameters = @{}
            ContinueOnError = $false
            Timeout = 60
            RetryCount = 0
        },
        @{
            Script = "0405"
            Description = "Phase 4: Validate module manifests"
            Parameters = @{}
            ContinueOnError = $false
            Timeout = 60
            RetryCount = 0
        },
        @{
            Script = "0404"
            Description = "Phase 5: PSScriptAnalyzer code quality check"
            Parameters = @{
                UseCache = $true
            }
            ContinueOnError = $true
            Timeout = 300
            RetryCount = 1
        },
        @{
            Script = "0420"
            Description = "Phase 6: Component quality validation"
            Parameters = @{
                Path = "./aithercore"
                Recursive = $true
            }
            ContinueOnError = $true
            Timeout = 180
            RetryCount = 0
        },
        @{
            Script = "0402"
            Description = "Phase 7: Unit test execution"
            Parameters = @{}
            ContinueOnError = $false
            Timeout = 300
            RetryCount = 1
        },
        @{
            Script = "0426"
            Description = "Phase 8: Test-script synchronization check"
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
        TestResultsPath = "./tests/results"
        EnableCache = $true
        FailFast = $false
    }
    
    # Execution options
    Options = @{
        Parallel = $false
        MaxConcurrency = 1
        StopOnError = $false  # Continue through quality checks
        CaptureOutput = $true
        GenerateSummary = $true
        SummaryFormat = "Markdown"
    }
    
    # Success criteria - critical scripts must pass
    SuccessCriteria = @{
        RequireAllSuccess = $false
        MinimumSuccessCount = 5  # At least 5 of 8 scripts must pass
        # Critical scripts that MUST pass for PR approval
        CriticalScripts = @(
            "0003_Sync-ConfigManifest.ps1"      # Config must be in sync
            "0407_Validate-Syntax.ps1"           # No syntax errors
            "0413_Validate-ConfigManifest.ps1"   # Config must be valid
            "0405_Validate-ModuleManifests.ps1"  # Module manifests valid
            "0402_Run-UnitTests.ps1"             # Unit tests must pass
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
