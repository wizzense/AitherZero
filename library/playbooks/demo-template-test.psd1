@{
    Name = 'demo-template-test'
    Description = 'Playbook created 2025-11-11'
    Version = '1.0.0'
    
    # Execute these scripts in sequence
    Sequence = @(
        @{
            Script = '0407'
            Description = 'TODO: Add description for script 0407'
            Parameters = @{}
            ContinueOnError = $false
            Timeout = 300
        },
        @{
            Script = '0413'
            Description = 'TODO: Add description for script 0413'
            Parameters = @{}
            ContinueOnError = $false
            Timeout = 300
        }
    )
    
    # Variables available to all scripts
    Variables = @{
        # Testing-specific variables
        TestMode = $true
        FailFast = $true
    }
    
    # Execution options
    Options = @{
        Parallel = $false
        MaxConcurrency = 1
        StopOnError = $true
    }
    
    # Success criteria
    SuccessCriteria = @{
        RequireAllSuccess = $true
        MinimumSuccessCount = 2
    }
}
