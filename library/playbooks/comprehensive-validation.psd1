@{
    Name = "comprehensive-validation"
    Description = "Three-tier comprehensive validation (AST → PSScriptAnalyzer → Pester)"
    Version = "1.0.0"
    Author = "AitherZero"
    Tags = @("validation", "testing", "quality", "three-tier")
    
    # Three-tier validation: AST analysis, static analysis, and dynamic testing
    Sequence = @(
        # Tier 1: AST (Abstract Syntax Tree) Analysis
        @{
            Script = "0412_Validate-AST.ps1"
            Description = "AST-based validation (Tier 1)"
            Parameters = @{
                All = $true
            }
            ContinueOnError = $false
            Timeout = 120
            Phase = "ast-validation"
        },
        
        # Tier 2: PSScriptAnalyzer Static Analysis
        @{
            Script = "0404_Run-PSScriptAnalyzer.ps1"
            Description = "Static code analysis (Tier 2)"
            Parameters = @{
                UseCache = $true
            }
            ContinueOnError = $false
            Timeout = 300
            Phase = "static-analysis"
        },
        
        # Syntax validation
        @{
            Script = "0407_Validate-Syntax.ps1"
            Description = "PowerShell syntax validation"
            Parameters = @{
                All = $true
            }
            ContinueOnError = $false
            Timeout = 120
            Phase = "syntax-validation"
        },
        
        # Tier 3: Pester Dynamic Testing
        @{
            Script = "0402_Run-UnitTests.ps1"
            Description = "Unit tests (Tier 3)"
            Parameters = @{}
            ContinueOnError = $false
            Timeout = 300
            Phase = "unit-tests"
        },
        
        # Generate quality metrics
        @{
            Script = "0528_Generate-QualityMetrics.ps1"
            Description = "Generate comprehensive quality metrics"
            Parameters = @{
                IncludeHistory = $true
            }
            ContinueOnError = $true
            Timeout = 180
            Phase = "quality-metrics"
        }
    )
    
    # Variables available to all scripts
    Variables = @{
        CI = $env:CI
        AITHERZERO_CI = "true"
        AITHERZERO_NONINTERACTIVE = "true"
        VALIDATION_MODE = "comprehensive"
    }
    
    # Execution options
    Options = @{
        Parallel = $false  # Sequential for proper validation flow
        MaxConcurrency = 1
        StopOnError = $false  # Complete all tiers even if one fails
        CaptureOutput = $true
        GenerateSummary = $true
    }
    
    # Success criteria
    SuccessCriteria = @{
        RequireAllSuccess = $false
        MinimumSuccessCount = 3  # At least AST, PSSA, and syntax must pass
        CriticalScripts = @(
            "0407_Validate-Syntax.ps1",
            "0404_Run-PSScriptAnalyzer.ps1"
        )
    }
    
    # Reporting
    Reporting = @{
        GenerateReport = $true
        IncludeTimings = $true
        ReportPath = "library/reports/comprehensive-validation-summary.md"
    }
}
