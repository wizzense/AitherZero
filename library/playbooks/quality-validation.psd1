@{
    Name = "quality-validation"
    Description = "Complete code quality validation - PSScriptAnalyzer and component quality"
    Version = "2.0.0"
    Author = "AitherZero"
    Tags = @("quality", "validation", "analysis")
    
    Sequence = @(
        @{
            Script = "0003"
            Description = "Sync and validate config manifest with repository"
            Parameters = @{}
            ContinueOnError = $false
            Timeout = 60
        },
        @{
            Script = "0404"
            Description = "Run PSScriptAnalyzer"
            Parameters = @{}
            ContinueOnError = $true
            Timeout = 300
        },
        @{
            Script = "0420"
            Description = "Validate component quality"
            Parameters = @{ Path = "./aithercore" }
            ContinueOnError = $true
            Timeout = 180
        }
    )
    
    Variables = @{
        CI = $env:CI
        AITHERZERO_CI = "true"
        AITHERZERO_NONINTERACTIVE = "true"
    }
    
    Options = @{
        Parallel = $false
        StopOnError = $false
        CaptureOutput = $true
        GenerateSummary = $true
    }
    
    SuccessCriteria = @{
        RequireAllSuccess = $false
        MinimumSuccessCount = 1
    }
}
