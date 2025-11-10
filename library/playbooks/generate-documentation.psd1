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
        # CI variable is automatically set by GitHub Actions and other CI platforms
        # Non-interactive mode is derived from CI detection in Configuration module
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
