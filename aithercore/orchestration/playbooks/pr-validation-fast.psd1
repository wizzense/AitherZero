@{
    Name = "pr-validation-fast"
    Description = "Fast PR validation - essential checks only (< 2 min)"
    Version = "1.0.0"
    Author = "AitherZero"
    
    # Execute these scripts in sequence - fast feedback
    Sequence = @(
        @{
            Script = "0407_Validate-Syntax.ps1"
            Description = "Quick syntax validation"
            Parameters = @{
                All = $true
            }
            ContinueOnError = $false
            Timeout = 60
            RetryCount = 0
        },
        @{
            Script = "0413_Validate-ConfigManifest.ps1"
            Description = "Config validation"
            Parameters = @{}
            ContinueOnError = $false
            Timeout = 30
            RetryCount = 0
        }
    )
    
    # Variables available to all scripts
    Variables = @{
        CI = "true"
        AITHERZERO_CI = "true"
        AITHERZERO_NONINTERACTIVE = "true"
        FailFast = $true
    }
    
    # Execution options
    Options = @{
        Parallel = $false
        MaxConcurrency = 1
        StopOnError = $true
        CaptureOutput = $true
        GenerateSummary = $true
        SummaryFormat = "Console"
    }
    
    # Success criteria - all must pass
    SuccessCriteria = @{
        RequireAllSuccess = $true
        MinimumSuccessCount = 2
    }
    
    # Reporting
    Reporting = @{
        GenerateReport = $false
        IncludeTimings = $true
    }
}
