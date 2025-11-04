@{
    Name = "code-quality-fast"
    Description = "Fast code quality validation for CI/CD pipelines"
    Version = "1.0.0"
    
    # Execute these scripts in sequence
    Sequence = @(
        @{
            Script = "0404_Run-PSScriptAnalyzer.ps1"
            Description = "Fast PSScriptAnalyzer scan (core files only)"
            Parameters = @{
                Fast = $true
                MaxFiles = 25
                UseCache = $true
            }
            ContinueOnError = $false
            Timeout = 60
        },
        @{
            Script = "0407_Validate-Syntax.ps1"
            Description = "Validate PowerShell syntax"
            Parameters = @{
                All = $true
            }
            ContinueOnError = $false
            Timeout = 30
        }
    )
    
    # Variables available to all scripts
    Variables = @{
        ReportsPath = "./reports"
        FastMode = $true
    }
    
    # Success criteria
    SuccessCriteria = @{
        RequireAllSuccess = $true
        MinimumSuccessCount = 2
    }
}
