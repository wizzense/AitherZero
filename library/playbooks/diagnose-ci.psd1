@{
    Name = 'diagnose-ci'
    Description = 'Diagnose and report on CI workflow failures'
    Version = '1.0.0'
    Author = 'AitherZero'
    
    # Execution configuration
    Configuration = @{
        Mode = 'Sequential'
        ContinueOnError = $true
        Timeout = 300
    }
    
    # Scripts to execute in order
    Scripts = @(
        @{
            Script = '0531'
            Name = 'Get-WorkflowRunReport'
            Description = 'Fetch and analyze workflow run failures'
            Parameters = @{
                List = $true
                Status = 'failure'
                Limit = 10
            }
            Required = $true
            Stage = 'Diagnostic'
        }
    )
    
    # Variables available to scripts
    Variables = @{
        OutputFormat = 'Both'
        Detailed = $true
        IncludeJobs = $true
        IncludeLogs = $false  # Set to true for full log download
    }
    
    # Reporting configuration
    Reporting = @{
        Enabled = $true
        Format = 'Detailed'
        OutputPath = './reports/ci-diagnostics'
        IncludeMetrics = $true
    }
    
    # Success criteria
    SuccessCriteria = @{
        RequireAllSuccess = $false
        MinimumSuccessRate = 0  # Always succeed, this is diagnostic
    }
}
