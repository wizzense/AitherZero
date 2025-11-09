@{
    Name = 'test-orchestration'
    Description = 'Simple test playbook for validation'
    Version = '1.0.0'
    
    # Simple sequence - just syntax validation
    Sequence = @(
        @{
            Script = '0407_Validate-Syntax.ps1'
            Description = 'Validate PowerShell syntax'
            Parameters = @{ All = $true }
            ContinueOnError = $false
            Timeout = 120
        }
    )
    
    Variables = @{
        CI = $true
    }
    
    Options = @{
        Parallel = $false
        MaxConcurrency = 1
        StopOnError = $true
    }
}
