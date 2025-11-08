@{
    Name = "generate-indexes"
    Description = "Generate all project indexes"
    Version = "2.0.0"
    Author = "AitherZero"
    Tags = @("indexing", "automation")
    
    Sequence = @(
        @{
            Script = "0745_Generate-ProjectIndexes.ps1"
            Description = "Generate project navigation indexes"
            Parameters = @{}
            ContinueOnError = $false
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
        StopOnError = $true
        CaptureOutput = $true
        GenerateSummary = $true
    }
    
    SuccessCriteria = @{
        RequireAllSuccess = $true
    }
}
