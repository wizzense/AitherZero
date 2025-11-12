@{
    Name = "pr-build"
    Description = "PR Build Phase - Packages and validation"
    Version = "2.1.0"
    Author = "AitherZero"
    Tags = @("pr", "build", "packages", "validation")
    
    # Build phase - parallel execution where possible
    Sequence = @(
        # Pre-build validation
        @{
            Script = "0407"
            Description = "Syntax validation before build"
            Parameters = @{ All = $true }
            ContinueOnError = $false
            Timeout = 120
            Phase = "validate"
        },
        
        # Generate build metadata
        @{
            Script = "0515"
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
            Script = "0902"
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
        
        # Validate self-deployment capability - COMPREHENSIVE (no quick modes)
        @{
            Script = "0900"
            Description = "Comprehensive self-deployment validation (full bootstrap + all tests)"
            Parameters = @{
                # No parameters - run full comprehensive test
            }
            ContinueOnError = $true  # Don't fail build if validation has issues
            Timeout = 1800  # Increased: Full bootstrap(600s) + comprehensive playbook(1000s) = ~1600s + buffer
            Phase = "validate"
            Parallel = $false
        }
    )
    
    # Variables available to all scripts
    Variables = @{
        CI = $env:CI
        AITHERZERO_CI = "true"
        AITHERZERO_NONINTERACTIVE = "true"
        BUILD_PHASE = "pr-build"
        GENERATE_ARTIFACTS = "true"
        DOCKER_BUILD_ENABLED = "true"
        DOCKER_REGISTRY = "ghcr.io"
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
        Container = @{
            Enabled = $true
            Registry = "ghcr.io"
            ImageName = $env:GITHUB_REPOSITORY
            TagFormat = "pr-{PR_NUMBER}"
            Platforms = @("linux/amd64", "linux/arm64")
        }
    }
    
    # Reporting
    Reporting = @{
        GenerateReport = $true
        IncludeTimings = $true
        IncludeArtifacts = $true
        IncludeContainerInfo = $true
        ReportPath = "library/reports/build-report.md"
    }
}
