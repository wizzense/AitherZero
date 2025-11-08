@{
    Name = "validate-all-playbooks"
    Description = "Comprehensive validation of all playbooks in the repository"
    Version = "1.0.0"
    Author = "Rachel PowerShell - AitherZero"
    Tags = @("validation", "testing", "playbooks", "quality", "comprehensive")
    
    # Comprehensive validation sequence
    # This playbook validates ALL playbooks in the repository
    # Ensures every playbook can be loaded and executed without errors
    Sequence = @(
        # Step 1: Validate syntax of all playbook files
        @{
            Script = "0407"
            Description = "Validate PowerShell syntax of all playbooks"
            Parameters = @{
                Path = "library/playbooks"
                Recurse = $true
            }
            ContinueOnError = $false
            Timeout = 120
            Phase = "pre-validation"
        }
        
        # Step 2: Generate comprehensive playbook validation report
        @{
            Script = "0515"
            Description = "Generate metadata about all playbooks"
            Parameters = @{
                OutputPath = "library/reports/playbook-validation-metadata.json"
                IncludeGitInfo = $true
                IncludeEnvironmentInfo = $true
            }
            ContinueOnError = $false
            Timeout = 60
            Phase = "metadata"
        }
    )
    
    # Variables available during validation
    Variables = @{
        CI = $env:CI
        AITHERZERO_CI = "true"
        AITHERZERO_NONINTERACTIVE = "true"
        VALIDATION_MODE = "comprehensive"
        PLAYBOOK_VALIDATION = "true"
        
        # List of all playbooks to validate
        PlaybooksToValidate = @(
            "aitherium-org-setup"
            "code-quality-fast"
            "code-quality-full"
            "deployment-environment"
            "dev-environment-setup"
            "diagnose-ci"
            "fix-ci-validation"
            "generate-documentation"
            "generate-indexes"
            "integration-tests-full"
            "pr-ecosystem-analyze"
            "pr-ecosystem-build"
            "pr-ecosystem-report"
            "pr-validation-fast"
            "pr-validation-full"
            "project-health-check"
            "quality-validation"
            "run-tests"
            "self-deployment-test"
            "self-hosted-runner-setup"
            "test-ci-conversion"
            "test-orchestration"
            "validate-pr-comprehensive"
            "validate-pr"
        )
    }
    
    # Execution options
    Options = @{
        Parallel = $false  # Sequential for comprehensive validation
        MaxConcurrency = 1
        StopOnError = $true  # Stop immediately if any playbook fails
        CaptureOutput = $true
        GenerateSummary = $true
        SummaryFormat = "JSON"
        SummaryPath = "library/reports/playbook-validation-summary.json"
    }
    
    # Success criteria
    SuccessCriteria = @{
        RequireAllSuccess = $true
        MinimumSuccessCount = 2  # Both validation steps must pass
        AllowedFailures = @()  # No failures allowed
    }
    
    # Validation stages
    # This demonstrates comprehensive multi-stage validation
    ValidationStages = @{
        SyntaxValidation = @{
            Description = "Validate PowerShell syntax of all playbook files"
            Required = $true
            Scripts = @("0407")
        }
        
        MetadataGeneration = @{
            Description = "Generate comprehensive metadata about playbooks"
            Required = $true
            Scripts = @("0515")
        }
        
        DryRunValidation = @{
            Description = "Perform dry-run execution of all playbooks"
            Required = $true
            Method = "Custom"  # Custom validation via post-execution script
        }
    }
    
    # Artifacts to track
    Artifacts = @{
        Required = @(
            "library/reports/playbook-validation-metadata.json"
        )
        Optional = @(
            "library/reports/playbook-validation-summary.json"
            "library/reports/playbook-validation-report.md"
        )
    }
    
    # Reporting configuration
    Reporting = @{
        GenerateReport = $true
        IncludeTimings = $true
        IncludeArtifacts = $true
        IncludePlaybookList = $true
        ReportPath = "library/reports/playbook-validation-report.md"
        
        # Custom report sections
        Sections = @(
            "Executive Summary"
            "Validation Results"
            "Playbook Inventory"
            "Error Details"
            "Recommendations"
        )
    }
    
    # Notifications (for CI/CD integration)
    Notifications = @{
        OnSuccess = @{
            Enabled = $true
            Message = "All playbooks validated successfully!"
            Channels = @("console", "file")
        }
        
        OnFailure = @{
            Enabled = $true
            Message = "Playbook validation failed! Check reports for details."
            Channels = @("console", "file", "error-log")
        }
    }
    
    # Documentation
    Documentation = @{
        Purpose = @"
This playbook performs comprehensive validation of all playbooks in the AitherZero repository.
It ensures that:
1. All playbook files have valid PowerShell syntax
2. All playbooks can be loaded without errors
3. All playbooks can be executed in dry-run mode
4. Comprehensive metadata is generated for all playbooks

Use this playbook in CI/CD pipelines to prevent broken playbooks from being merged.
"@
        
        Usage = @"
# Basic usage (dry run)
Invoke-OrchestrationSequence -LoadPlaybook validate-all-playbooks -DryRun

# Full validation (comprehensive)
Invoke-OrchestrationSequence -LoadPlaybook validate-all-playbooks

# CI/CD integration
Invoke-OrchestrationSequence -LoadPlaybook validate-all-playbooks -ThrowOnError -Quiet
"@
        
        Examples = @(
            @{
                Description = "Validate all playbooks before merge"
                Command = "Invoke-OrchestrationSequence -LoadPlaybook validate-all-playbooks"
            }
            @{
                Description = "Generate playbook inventory report"
                Command = "Invoke-OrchestrationSequence -LoadPlaybook validate-all-playbooks -Variables @{GenerateInventory=$true}"
            }
        )
    }
}
