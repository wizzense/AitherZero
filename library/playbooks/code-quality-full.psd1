@{
    Name = "code-quality-full"
    Description = "Comprehensive code quality analysis with full PSScriptAnalyzer scan"
    Version = "1.0.0"
    
    # Execute these scripts in sequence
    Sequence = @(
        @{
            Script = "0404_Run-PSScriptAnalyzer.ps1"
            Description = "Run comprehensive PSScriptAnalyzer with caching"
            Parameters = @{
                UseCache = $true
            }
            ContinueOnError = $false
            Timeout = 300
        },
        @{
            Script = "0407_Validate-Syntax.ps1"
            Description = "Validate PowerShell syntax"
            Parameters = @{
                All = $true
            }
            ContinueOnError = $false
            Timeout = 60
        },
        @{
            Script = "0512_Generate-Dashboard.ps1"
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
