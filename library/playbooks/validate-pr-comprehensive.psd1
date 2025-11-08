@{
    Name        = 'validate-pr-comprehensive'
    Description = 'Comprehensive PR validation - tests all scripts, playbooks, config, and modules'
    Version     = '1.0.0'
    Author      = 'AitherZero'
    Tags        = @('validation', 'pr', 'ci', 'quality')

    # Default variables for this playbook
    DefaultVariables = @{
        CI                         = 'true'
        AITHERZERO_NONINTERACTIVE = 'true'
        AITHERZERO_CI             = 'true'
        VALIDATION_MODE           = 'comprehensive'
    }

    # Scripts to execute in order
    Sequences = @(
        @{
            Name        = 'validate-all-scripts'
            Description = 'Validate syntax of all playbook scripts'
            Scripts     = @(
                @{
                    Number      = '0407'
                    Description = 'Validate syntax of all PowerShell files'
                    Stage       = 'Validation'
                    Parameters  = @{
                        All = $true
                    }
                }
            )
        }
        @{
            Name        = 'validate-config'
            Description = 'Validate configuration manifest accuracy'
            Scripts     = @(
                @{
                    Number      = '0413'
                    Description = 'Validate config manifest matches reality'
                    Stage       = 'Validation'
                    Parameters  = @{}
                }
            )
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
