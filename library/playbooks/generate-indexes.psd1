@{
    Name = "generate-indexes"
    Description = "Generate all project indexes"
    Version = "2.0.0"
    Author = "AitherZero"
    Tags = @("indexing", "automation")
    
    Sequence = @(
        @{
            Script = "0745"
            Description = "Generate project navigation indexes"
            Parameters = @{}
            ContinueOnError = $false
            Timeout = 180
        }
    )
    
    Variables = @{
        # CI variable is automatically set by GitHub Actions and other CI platforms
        # Non-interactive mode is derived from CI detection in Configuration module
    }
    
    Options = @{
        Parallel = $false
        StopOnError = $true
        CaptureOutput = $true
        GenerateSummary = $true
    }
    
    SuccessCriteria = @{
        RequireAllSuccess = $true
    }
}
