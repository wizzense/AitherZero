@{
    Name = "pr-ecosystem-complete"
    Description = "Complete PR Ecosystem - Build, Analyze, Report with full deployment artifacts"
    Version = "2.0.0"
    Author = "AitherZero"
    Tags = @("pr", "ecosystem", "complete", "deployment", "dashboard", "release")
    
    # Master orchestration - runs all three PR ecosystem phases
    Sequence = @(
        # Phase 1: Build - Create deployable artifacts
        @{
            Playbook = "pr-ecosystem-build"
            Description = "Build phase - packages, containers, metadata"
            ContinueOnError = $false
            Timeout = 600
            Phase = "build"
        },
        
        # Phase 2: Analyze - Comprehensive testing and analysis
        @{
            Playbook = "pr-ecosystem-analyze"
            Description = "Analysis phase - tests, quality, security"
            ContinueOnError = $true  # Don't stop if tests fail
            Timeout = 900
            Phase = "analyze"
        },
        
        # Phase 3: Report - Generate dashboard and deploy to GitHub Pages
        @{
            Playbook = "pr-ecosystem-report"
            Description = "Reporting phase - dashboard, changelog, deployment"
            ContinueOnError = $false
            Timeout = 600
            Phase = "report"
        }
    )
    
    # Variables available to all phases
    Variables = @{
        CI = $env:CI
        AITHERZERO_CI = "true"
        AITHERZERO_NONINTERACTIVE = "true"
        PR_NUMBER = $env:PR_NUMBER
        GITHUB_BASE_REF = $env:GITHUB_BASE_REF
        GITHUB_HEAD_REF = $env:GITHUB_HEAD_REF
        GITHUB_REPOSITORY = $env:GITHUB_REPOSITORY
        GITHUB_SHA = $env:GITHUB_SHA
        GITHUB_RUN_NUMBER = $env:GITHUB_RUN_NUMBER
        COMPLETE_ECOSYSTEM = "true"
    }
    
    # Execution options
    Options = @{
        Parallel = $false  # Sequential phases for proper data flow
        MaxConcurrency = 1
        StopOnError = $false  # Continue through phases even if some fail
        CaptureOutput = $true
        GenerateSummary = $true
        SummaryFormat = "JSON"
        SummaryPath = "library/reports/pr-ecosystem-complete-summary.json"
    }
    
    # Success criteria - all critical phases must succeed
    SuccessCriteria = @{
        RequireAllSuccess = $false
        MinimumSuccessCount = 2  # Build and Report phases are critical
        CriticalPhases = @(
            "build",    # Must create artifacts
            "report"    # Must generate dashboard
        )
        AllowedFailures = @(
            "analyze"   # Analysis can fail but we still want dashboard
        )
    }
    
    # Artifacts to track across all phases
    Artifacts = @{
        Required = @(
            # Build artifacts
            "library/reports/build-metadata.json",
            "AitherZero-*-runtime.zip",
            
            # Analysis artifacts
            "library/reports/analysis-summary.json",
            
            # Report artifacts
            "library/reports/dashboard.html",
            "library/reports/dashboard.json",
            "library/reports/quality-metrics.json",
            "library/reports/pr-comment.md"
        )
        Optional = @(
            # Build
            "AitherZero-*-runtime.tar.gz",
            "AitherZero-*-full.zip",
            "library/reports/build-summary.json",
            
            # Analysis
            "library/tests/results/**",
            "library/tests/coverage/**",
            "library/reports/quality-analysis.json",
            "library/reports/security-report.json",
            "library/reports/diff-analysis.json",
            
            # Report
            "library/reports/dashboard.md",
            "library/reports/quality-trends.json",
            "library/reports/quality-history/*.json",
            "library/reports/CHANGELOG-PR*.md",
            "library/reports/recommendations.json",
            "library/reports/project-report.md"
        )
    }
    
    # Reporting
    Reporting = @{
        GenerateReport = $true
        IncludeTimings = $true
        IncludeArtifacts = $true
        IncludeFailures = $true
        IncludePhaseDetails = $true
        ReportPath = "library/reports/pr-ecosystem-complete-report.md"
    }
    
    # Post-execution hooks
    PostExecution = @{
        ValidateArtifacts = $true
        CreateIndex = $true
        IndexPath = "library/reports/index.md"
        GenerateManifest = $true
        ManifestPath = "library/reports/artifacts-manifest.json"
    }
    
    # Deployment readiness checks
    DeploymentReadiness = @{
        CheckBuildArtifacts = $true
        CheckTestResults = $true
        CheckQualityMetrics = $true
        CheckDashboard = $true
        MinimumQualityScore = 70
        RequiredArtifacts = @(
            "dashboard.html",
            "AitherZero-*-runtime.zip",
            "quality-metrics.json"
        )
    }
}
