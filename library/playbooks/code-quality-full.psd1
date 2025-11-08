@{
    Name = "code-quality-full"
    Description = "Comprehensive code quality analysis with full PSScriptAnalyzer scan"
    Version = "1.0.0"
    
    # Execute these scripts in sequence
    Sequence = @(
        @{
            Script = "0404"
            Description = "Run comprehensive PSScriptAnalyzer with caching"
            Parameters = @{
                UseCache = $true
            }
            ContinueOnError = $false
            Timeout = 300
        },
        @{
            Script = "0407"
            Description = "Validate PowerShell syntax"
            Parameters = @{
                All = $true
            }
            ContinueOnError = $false
            Timeout = 60
        },
        @{
            Script = "0512"
            Description = "Generate updated dashboard with new quality metrics"
            Parameters = @{
                Format = "HTML"
            }
            ContinueOnError = $true
            Timeout = 120
        }
    )
    
    # Variables available to all scripts
    Variables = @{
        ReportsPath = "./reports"
        EnableCache = $true
    }
    
    # Success criteria
    SuccessCriteria = @{
        RequireAllSuccess = $false
        MinimumSuccessCount = 2
    }
}
