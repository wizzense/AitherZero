@{
    Name = "generate-documentation"
    Description = "Generate all project documentation"
    Version = "2.0.0"
    Author = "AitherZero"
    Tags = @("documentation", "automation")
    
    Sequence = @(
        @{
            Script = "0744"
            Description = "Generate code documentation"
            Parameters = @{
                Mode = "Incremental"
                Format = "Both"
                Quality = $true
            }
            ContinueOnError = $false
            Timeout = 300
        }
    )
    
    Variables = @{
        CI = "true"
        AITHERZERO_CI = "true"
        AITHERZERO_NONINTERACTIVE = "true"
        DOC_MODE = "Incremental"
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
