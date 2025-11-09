@{
    Name = 'test-orchestration'
    Description = 'Enhanced test orchestration with three-tier validation'
    Version = '2.0.0'
    
    # Three-tier approach: AST validation → Code quality → Functional tests
    Sequence = @(
        @{
            Script = '0407_Validate-Syntax.ps1'
            Description = 'Tier 1: AST-based syntax validation'
            Parameters = @{ All = $true }
            ContinueOnError = $false
            Timeout = 120
        }
        @{
            Script = '0404_Run-PSScriptAnalyzer.ps1'
            Description = 'Tier 2: PSScriptAnalyzer quality validation'
            Parameters = @{ 
                Fast = $true
                Severity = @('Error', 'Warning')
            }
            ContinueOnError = $true
            Timeout = 180
        }
        @{
            Script = '0402_Run-UnitTests.ps1'
            Description = 'Tier 3: Pester functional validation'
            Parameters = @{
                Tag = @('Unit', 'Functional')
            }
            ContinueOnError = $true
            Timeout = 300
        }
    )
    
    Variables = @{
        CI = $true
        ThreeTierValidation = $true
    }
    
    Options = @{
        Parallel = $false
        MaxConcurrency = 1
        StopOnError = $false
    }
}
