@{
    Name = 'fix-ci-validation'
    Description = 'Fix common CI validation failures systematically'
    Version = '1.0.0'
    Author = 'AitherZero'
    
    # Execution configuration
    Configuration = @{
        Mode = 'Sequential'
        ContinueOnError = $false
        Timeout = 600
    }
    
    # Scripts to execute in order
    Scripts = @(
        @{
            Number = '0407'
            Name = 'Validate-Syntax'
            Description = 'Validate PowerShell syntax for all scripts'
            Parameters = @{
                All = $true
            }
            Required = $true
            Stage = 'Validation'
        }
        @{
            Number = '0413'
            Name = 'Validate-ConfigManifest'
            Description = 'Validate config.psd1 manifest'
            Parameters = @{}
            Required = $true
            Stage = 'Validation'
        }
        @{
            Number = '0405'
            Name = 'Validate-ModuleManifests'
            Description = 'Validate all PowerShell module manifests'
            Parameters = @{}
            Required = $true
            Stage = 'Validation'
        }
        @{
            Number = '0404'
            Name = 'Run-PSScriptAnalyzer'
            Description = 'Run quality analysis'
            Parameters = @{}
            Required = $false
            Stage = 'Quality'
        }
        @{
            Number = '0402'
            Name = 'Run-UnitTests'
            Description = 'Run unit tests'
            Parameters = @{}
            Required = $false
            Stage = 'Testing'
        }
        @{
            Number = '0531'
            Name = 'Get-WorkflowRunReport'
            Description = 'Generate diagnostic report'
            Parameters = @{
                List = $true
                Status = 'failure'
                Limit = 5
            }
            Required = $false
            Stage = 'Reporting'
        }
    )
    
    # Variables available to scripts
    Variables = @{
        FixIssues = $true
        GenerateReport = $true
        FailFast = $false
    }
    
    # Reporting configuration
    Reporting = @{
        Enabled = $true
        Format = 'Comprehensive'
        OutputPath = './reports/validation-fixes'
        IncludeMetrics = $true
    }
    
    # Success criteria
    SuccessCriteria = @{
        RequireAllSuccess = $false
        MinimumSuccessRate = 0.8
    }
}
