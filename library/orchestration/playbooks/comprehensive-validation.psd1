@{
    Name = 'comprehensive-validation'
    Description = 'Complete three-tier validation with functional testing'
    Version = '1.0.0'
    
    # Three-tier validation: AST → PSScriptAnalyzer → Pester
    Sequence = @(
        @{
            Script = '0407_Validate-Syntax.ps1'
            Description = 'Tier 0: Basic syntax validation'
            Parameters = @{ All = $true }
            ContinueOnError = $false
            Timeout = 120
        }
        @{
            Script = '0404_Run-PSScriptAnalyzer.ps1'
            Description = 'Tier 2: PSScriptAnalyzer code quality validation'
            Parameters = @{ 
                Severity = @('Error', 'Warning')
            }
            ContinueOnError = $true
            Timeout = 300
        }
        @{
            Script = '0969_Validate-BranchDeployments.ps1'
            Description = 'Tier 1: Branch-specific deployment configuration validation'
            Parameters = @{ 
                All = $true
            }
            ContinueOnError = $false
            Timeout = 60
        }
        @{
            Script = '0402_Run-UnitTests.ps1'
            Description = 'Tier 3: Pester unit tests with functional validation'
            Parameters = @{
                Path = './tests/unit'
                Tag = @('Unit', 'Functional')
                OutputFormat = 'NUnitXml'
                OutputPath = './library/tests/results/unit-tests.xml'
            }
            ContinueOnError = $true
            Timeout = 600
        }
        @{
            Script = '0403_Run-IntegrationTests.ps1'
            Description = 'Tier 3: Integration and playbook tests'
            Parameters = @{
                Path = './tests/integration'
                Tag = @('Integration', 'Playbook')
                OutputFormat = 'NUnitXml'
                OutputPath = './library/tests/results/integration-tests.xml'
            }
            ContinueOnError = $true
            Timeout = 900
        }
        @{
            Script = '0510_Generate-ProjectReport.ps1'
            Description = 'Generate comprehensive validation report'
            Parameters = @{
                IncludeMetrics = $true
                IncludeQualityScore = $true
                OutputPath = './library/reports/validation-report.json'
            }
            ContinueOnError = $false
            Timeout = 180
        }
    )
    
    Variables = @{
        CI = $true
        EnableFunctionalTests = $true
        ThreeTierValidation = $true
        QualityThreshold = 70
    }
    
    Options = @{
        Parallel = $false  # Sequential for proper tier execution
        MaxConcurrency = 1
        StopOnError = $false  # Collect all results
        ShowProgress = $true
        GenerateReport = $true
    }
    
    SuccessCriteria = @{
        RequireAllSuccess = $false  # Allow warnings
        MinimumSuccessPercent = 80
        MinimumQualityScore = 70
        AllowedFailures = @()
    }
}
