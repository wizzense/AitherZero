@{
    Name        = 'validate-pr-comprehensive'
    Description = 'Comprehensive PR validation - tests all scripts, playbooks, config, and modules'
    Version     = '1.0.0'
    Author      = 'AitherZero'
    Tags        = @('validation', 'pr', 'ci', 'quality')

    # Default variables for this playbook (use 'Variables' for v1 compatibility)
    Variables = @{
        CI                         = 'true'
        AITHERZERO_NONINTERACTIVE = 'true'
        AITHERZERO_CI             = 'true'
        VALIDATION_MODE           = 'comprehensive'
    }

    # Scripts to execute in order (use 'Sequence' for v1 compatibility)
    Sequence = @(
        @{
            Script      = '0003'
            Description = 'Sync config manifest with repository inventory'
            Parameters  = @{
                # Run in check mode (no -Fix) to validate sync status
            }
        }
        @{
            Script      = '0407'
            Description = 'Validate syntax of all PowerShell files'
            Parameters  = @{
                All = $true
            }
        }
        @{
            Script      = '0413'
            Description = 'Validate config manifest matches reality'
            Parameters  = @{}
        }
    )

    # Execution settings
    Settings = @{
        MaxConcurrency    = 1  # Run sequentially for validation
        StopOnError       = $true
        ContinueOnWarning = $true
        ValidateBeforeRun = $true
        DryRun            = $false
    }

    # Success criteria
    SuccessCriteria = @{
        AllScriptsMustPass = $true
        NoSyntaxErrors     = $true
        ConfigMustMatch    = $true
    }
}
