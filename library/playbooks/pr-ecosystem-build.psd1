@{
    Name = "pr-ecosystem-build"
    Description = "Complete PR Build Phase - Container, packages, MCP server"
    Version = "2.0.0"
    Author = "AitherZero"
    Tags = @("pr", "build", "container", "release", "ecosystem")
    
    # Build phase - parallel execution where possible
    Sequence = @(
        # Pre-build validation
        @{
            Script = "0407_Validate-Syntax.ps1"
            Description = "Syntax validation before build"
            Parameters = @{ All = $true }
            ContinueOnError = $false
            Timeout = 120
            Phase = "validate"
        },
        
        # Generate build metadata
        @{
            Script = "0515_Generate-BuildMetadata.ps1"
            Description = "Generate comprehensive build metadata"
            Parameters = @{
                OutputPath = "library/reports/build-metadata.json"
                IncludePRInfo = $true
                IncludeGitInfo = $true
                IncludeEnvironmentInfo = $true
            }
            ContinueOnError = $false
            Timeout = 60
            Phase = "metadata"
        },
        
        # Create release package (executes in parallel with container if supported)
        @{
            Script = "0902_Create-ReleasePackage.ps1"
            Description = "Create deployable package"
            Parameters = @{
                PackageFormat = "Both"  # ZIP and TAR.GZ
                IncludeTests = $false
                OnlyRuntime = $true
            }
            ContinueOnError = $false
            Timeout = 300
            Phase = "package"
            Parallel = $true
        },
        
        # Validate self-deployment capability
        @{
            Script = "0900_Test-SelfDeployment.ps1"
            Description = "Validate self-deployment works"
            Parameters = @{
                QuickTest = $true
            }
            ContinueOnError = $true  # Don't fail build if validation has issues
            Timeout = 300
            Phase = "validate"
            Parallel = $false
        }
    )
    
    # Variables available to all scripts
    Variables = @{
        CI = $env:CI
        AITHERZERO_CI = "true"
        AITHERZERO_NONINTERACTIVE = "true"
        BUILD_PHASE = "pr-ecosystem-build"
        GENERATE_ARTIFACTS = "true"
    }
    
    # Execution options
    Options = @{
        Parallel = $true
        MaxConcurrency = 3
        StopOnError = $true
        CaptureOutput = $true
        GenerateSummary = $true
        SummaryFormat = "JSON"
        SummaryPath = "library/reports/build-summary.json"
    }
    
    # Success criteria
    SuccessCriteria = @{
        RequireAllSuccess = $false  # Allow self-deployment test to fail
        MinimumSuccessCount = 3  # Syntax, metadata, package must succeed
        AllowedFailures = @(
            "0900_Test-SelfDeployment.ps1"  # Validation can fail without breaking build
        )
    }
    
    # Artifacts to track
    Artifacts = @{
        Required = @(
            "library/reports/build-metadata.json",
            "AitherZero-*-runtime.zip"
        )
        Optional = @(
            "AitherZero-*-runtime.tar.gz",
            "library/reports/build-summary.json"
        )
    }
    
    # Reporting
    Reporting = @{
        GenerateReport = $true
        IncludeTimings = $true
        IncludeArtifacts = $true
        ReportPath = "library/reports/build-report.md"
    }
}
