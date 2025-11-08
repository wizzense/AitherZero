@{
    Name = "validate-pr"
    Description = "Complete PR validation - syntax, config, manifests"
    Version = "2.0.0"
    Author = "AitherZero"
    Tags = @("pr", "validation", "quick")
    
    Sequence = @(
        @{
            Script = "0407_Validate-Syntax.ps1"
            Description = "Validate PowerShell syntax"
            Parameters = @{ All = $true }
            ContinueOnError = $false
            Timeout = 120
        },
        @{
            Script = "0413_Validate-ConfigManifest.ps1"
            Description = "Validate config.psd1"
            Parameters = @{}
            ContinueOnError = $false
            Timeout = 60
        },
        @{
            Script = "0416_Validate-ModuleManifest.ps1"
            Description = "Validate module manifests"
            Parameters = @{}
            ContinueOnError = $false
            Timeout = 60
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
