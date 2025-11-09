@{
    Name = "run-tests"
    Description = "Execute complete test suite"
    Version = "2.0.0"
    Author = "AitherZero"
    Tags = @("testing", "quality")
    
    Sequence = @(
        @{
            Script = "0402"
            Description = "Run unit tests"
            Parameters = @{
                CodeCoverage = $true
                OutputFormat = "NUnitXml"
            }
            ContinueOnError = $true
            Timeout = 600
            Parallel = $false  # Run sequentially to avoid module loading conflicts in ThreadJobs
            Group = 1
        },
        @{
            Script = "0403"
            Description = "Run integration tests"
            Parameters = @{
                OutputFormat = "NUnitXml"
            }
            ContinueOnError = $true
            Timeout = 600
            Parallel = $false  # Run sequentially to avoid module loading conflicts in ThreadJobs
            Group = 1
        }
    )
    
    Variables = @{
        CI = $env:CI
        AITHERZERO_CI = "true"
        AITHERZERO_NONINTERACTIVE = "true"
    }
    
    Options = @{
        Parallel = $false  # Disable parallel execution to prevent deadlocks with module loading
        MaxConcurrency = 1  # Run tests sequentially - each script uses internal parallelism
        StopOnError = $false
        CaptureOutput = $true
        GenerateSummary = $true
    }
    
    SuccessCriteria = @{
        RequireAllSuccess = $false
        MinimumSuccessCount = 1
    }
}
