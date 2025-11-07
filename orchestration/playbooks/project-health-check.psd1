@{
    # ===================================================================
    # PROJECT HEALTH CHECK PLAYBOOK
    # ===================================================================
    Name = 'project-health-check'
    Description = 'Complete project health validation (matches GitHub Actions)'
    Version = '1.0.0'
    Profile = 'Full'
    
    # Sequential execution of all validation checks
    Sequence = @(
        @{
            Script = '0407_Validate-Syntax.ps1'
            Description = 'Syntax Validation (matches quick-health-check.yml)'
            Parameters = @{ All = $true }
            ContinueOnError = $false
            Timeout = 120
        },
        @{
            Script = '0404_Run-PSScriptAnalyzer.ps1'
            Description = 'Code Quality (matches pr-validation.yml)'
            Parameters = @{}
            ContinueOnError = $false
            Timeout = 300
        },
        @{
            Script = '0413_Validate-ConfigManifest.ps1'
            Description = 'Configuration Validation'
            Parameters = @{}
            ContinueOnError = $false
            Timeout = 60
        },
        @{
            Script = '0402_Run-UnitTests.ps1'
            Description = 'Unit Tests (matches parallel-testing.yml)'
            Parameters = @{}
            ContinueOnError = $true  # Continue to see all results
            Timeout = 600
        },
        @{
            Script = '0403_Run-IntegrationTests.ps1'
            Description = 'Integration Tests'
            Parameters = @{}
            ContinueOnError = $true
            Timeout = 600
        },
        @{
            Script = '0420_Validate-ComponentQuality.ps1'
            Description = 'Component Quality (matches quality-validation.yml)'
            Parameters = @{
                Path = './domains'
                Recursive = $true
            }
            ContinueOnError = $true
            Timeout = 600
        },
        @{
            Script = '0426_Validate-TestScriptSync.ps1'
            Description = 'Test Coverage Check'
            Parameters = @{}
            ContinueOnError = $true
            Timeout = 120
        },
        @{
            Script = '0510_Generate-ProjectReport.ps1'
            Description = 'Project Health Report'
            Parameters = @{ ShowAll = $true }
            ContinueOnError = $true
            Timeout = 180
        }
    )
    
    # Variables for all scripts
    Variables = @{
        CI = $true
        AITHERZERO_CI = $true
        AITHERZERO_NONINTERACTIVE = $true
    }
    
    # Execution options
    Options = @{
        Parallel = $false
        MaxConcurrency = 1
        StopOnError = $false  # Continue through all checks
        CaptureOutput = $true
        GenerateSummary = $true
    }
    
    # Success criteria
    SuccessCriteria = @{
        RequireAllSuccess = $false  # Report all results
        MinimumSuccessCount = 5  # At least 5 checks must pass
    }
}
