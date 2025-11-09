@{
    Name = "pr-ecosystem-report"
    Description = "Complete PR Reporting Phase - Dashboard, changelog, deployment"
    Version = "2.0.0"
    Author = "AitherZero"
    Tags = @("pr", "report", "dashboard", "changelog", "ecosystem")
    
    # Reporting phase - sequential to aggregate all prior data
    Sequence = @(
        # Generate quality metrics artifacts FIRST (for dashboard ingestion)
        @{
            Script = "0528_Generate-QualityMetrics.ps1"
            Description = "Generate quality metrics with historical tracking"
            Parameters = @{
                IncludeHistory = $true
                OutputPath = "library/reports"
            }
            ContinueOnError = $false
            Timeout = 180
            Phase = "quality-metrics"
        },
        
        # Generate PR changelog
        @{
            Script = "0513_Generate-Changelog.ps1"
            Description = "Generate PR changelog from commits"
            Parameters = @{
                BaseBranch = $env:GITHUB_BASE_REF
                HeadBranch = $env:GITHUB_HEAD_REF
                OutputPath = "library/reports/CHANGELOG-PR$($env:PR_NUMBER).md"
                IncludeIssueLinks = $true
                CategorizCommits = $true
                Format = "Markdown"
            }
            ContinueOnError = $false
            Timeout = 120
            Phase = "changelog"
        },
        
        # Generate actionable recommendations
        @{
            Script = "0518_Generate-Recommendations.ps1"
            Description = "Generate actionable recommendations"
            Parameters = @{
                AnalysisPath = "library/reports/analysis-summary.json"
                QualityPath = "library/reports/quality-analysis.json"
                TestResultsPath = "library/tests/results"
                OutputPath = "library/reports/recommendations.json"
                PrioritizeByImpact = $true
            }
            ContinueOnError = $true
            Timeout = 60
            Phase = "recommendations"
        },
        
        # Generate comprehensive dashboard
        @{
            Script = "0512_Generate-Dashboard.ps1"
            Description = "Generate comprehensive PR dashboard"
            Parameters = @{
                ProjectPath = $env:GITHUB_WORKSPACE
                OutputPath = "library/reports"
                Format = "All"  # HTML, Markdown, JSON
                IncludeBootstrapQuickstart = $true
                IncludeContainerInfo = $true
                IncludePRContext = $true
                IncludeDiffAnalysis = $true
                IncludeChangelog = $true
                IncludeRecommendations = $true
                IncludeHistoricalTrends = $true
                PRNumber = $env:PR_NUMBER
                BaseBranch = $env:GITHUB_BASE_REF
            }
            ContinueOnError = $false
            Timeout = 300
            Phase = "dashboard"
        },
        
        # Generate detailed reports
        @{
            Script = "0510_Generate-ProjectReport.ps1"
            Description = "Generate detailed project report"
            Parameters = @{
                OutputFormat = "Markdown"
                IncludeMetrics = $true
                IncludeTrends = $true
                ShowAll = $true
            }
            ContinueOnError = $true
            Timeout = 180
            Phase = "detailed-report"
        },
        
        # Create PR comment content
        @{
            Script = "0519_Generate-PRComment.ps1"
            Description = "Generate consolidated PR comment"
            Parameters = @{
                BuildMetadataPath = "library/reports/build-metadata.json"
                AnalysisSummaryPath = "library/reports/analysis-summary.json"
                DashboardPath = "library/reports/dashboard.html"
                ChangelogPath = "library/reports/CHANGELOG-PR$($env:PR_NUMBER).md"
                RecommendationsPath = "library/reports/recommendations.json"
                OutputPath = "library/reports/pr-comment.md"
                IncludeDeploymentInstructions = $true
                IncludeQuickActions = $true
            }
            ContinueOnError = $false
            Timeout = 60
            Phase = "pr-comment"
        }
    )
    
    # Variables available to all scripts
    Variables = @{
        CI = $env:CI
        AITHERZERO_CI = "true"
        AITHERZERO_NONINTERACTIVE = "true"
        REPORT_PHASE = "pr-ecosystem-report"
        PR_NUMBER = $env:PR_NUMBER
        GITHUB_BASE_REF = $env:GITHUB_BASE_REF
        GITHUB_HEAD_REF = $env:GITHUB_HEAD_REF
        GITHUB_REPOSITORY = $env:GITHUB_REPOSITORY
        GITHUB_SHA = $env:GITHUB_SHA
        GITHUB_RUN_NUMBER = $env:GITHUB_RUN_NUMBER
        PAGES_URL = "https://$($env:GITHUB_REPOSITORY_OWNER).github.io/$($env:GITHUB_REPOSITORY -replace '.*/','')/"
    }
    
    # Execution options
    Options = @{
        Parallel = $false  # Sequential for proper data aggregation
        MaxConcurrency = 1
        StopOnError = $false  # Try to generate what we can
        CaptureOutput = $true
        GenerateSummary = $true
        SummaryFormat = "JSON"
        SummaryPath = "library/reports/report-orchestration-summary.json"
    }
    
    # Success criteria
    SuccessCriteria = @{
        RequireAllSuccess = $false
        MinimumSuccessCount = 3  # At least changelog, dashboard, and PR comment
        CriticalScripts = @(
            "0513_Generate-Changelog.ps1",
            "0512_Generate-Dashboard.ps1",
            "0519_Generate-PRComment.ps1"
        )
    }
    
    # Artifacts to track
    Artifacts = @{
        Required = @(
            "library/reports/dashboard.html",
            "library/reports/dashboard.json",
            "library/reports/dashboard.md",
            "library/reports/CHANGELOG-PR*.md",
            "library/reports/pr-comment.md"
        )
        Optional = @(
            "library/reports/recommendations.json",
            "library/reports/project-report.md",
            "library/reports/code-map.html"
        )
    }
    
    # Reporting
    Reporting = @{
        GenerateReport = $true
        IncludeTimings = $true
        IncludeArtifacts = $true
        ReportPath = "library/reports/reporting-summary.md"
    }
    
    # Post-execution hooks
    PostExecution = @{
        ValidateArtifacts = $true
        CreateIndex = $true
        IndexPath = "library/reports/index.md"
    }
}
