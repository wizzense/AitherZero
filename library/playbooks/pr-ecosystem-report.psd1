@{
    Name = "pr-ecosystem-report"
    Description = "Complete PR Reporting Phase - Dashboard, changelog, deployment, Docker status"
    Version = "2.1.0"
    Author = "AitherZero"
    Tags = @("pr", "report", "dashboard", "changelog", "ecosystem", "docker")
    
    # Reporting phase - sequential to aggregate all prior data
    Sequence = @(
        # Generate PR changelog
        @{
            Script = "0513"
            Description = "Generate PR changelog from commits"
            Parameters = @{
                BaseBranch = $env:GITHUB_BASE_REF
                HeadBranch = $env:GITHUB_HEAD_REF
                OutputPath = "library/reports/CHANGELOG-PR$($env:PR_NUMBER).md"
                IncludeIssueLinks = $true
                CategorizeCommits = $true
                Format = "Markdown"
            }
            ContinueOnError = $false
            Timeout = 120
            Phase = "changelog"
        },
        
        # Generate actionable recommendations
        @{
            Script = "0518"
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
            Script = "0512"
            Description = "Generate ULTIMATE comprehensive dashboard with ALL metrics"
            Parameters = @{
                ProjectPath = $env:GITHUB_WORKSPACE
                OutputPath = "library/reports"
                Format = "All"  # HTML, Markdown, JSON
                
                # PR & Git Context
                PRNumber = $env:PR_NUMBER
                BaseBranch = $env:GITHUB_BASE_REF
                HeadBranch = $env:GITHUB_HEAD_REF
                
                # Core Features - ALL ENABLED!
                IncludeBootstrapQuickstart = $true
                IncludeContainerInfo = $true
                IncludeDockerImageInfo = $true
                IncludePRContext = $true
                IncludeDiffAnalysis = $true
                IncludeChangelog = $true
                IncludeRecommendations = $true
                IncludeHistoricalTrends = $true
                IncludeCodeMap = $true
                IncludeDependencyGraph = $true
                IncludeTestResults = $true
                IncludeQualityMetrics = $true
                IncludeBuildArtifacts = $true
                
                # Data Paths
                TestResultsPath = "library/tests/results"
                QualityAnalysisPath = "library/tests/analysis"
                BuildMetadataPath = "library/reports/build-metadata.json"
                ChangelogPath = "library/reports/CHANGELOG-PR$($env:PR_NUMBER).md"
                RecommendationsPath = "library/reports/recommendations.json"
                
                # Docker Integration
                DockerRegistry = "ghcr.io"
                DockerImageTag = "pr-$($env:PR_NUMBER)"
            }
            ContinueOnError = $false
            Timeout = 600  # Increased for comprehensive generation
            Phase = "dashboard"
        },
        
        # Generate detailed reports
        @{
            Script = "0510"
            Description = "Generate detailed project report"
            Parameters = @{
                ProjectPath = $env:GITHUB_WORKSPACE
                OutputPath = "library/reports"
                Format = "All"
            }
            ContinueOnError = $true
            Timeout = 180
            Phase = "detailed-report"
        },
        
        # Create PR comment content
        @{
            Script = "0519"
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
        PR_Script = $env:PR_NUMBER
        GITHUB_BASE_REF = $env:GITHUB_BASE_REF
        GITHUB_HEAD_REF = $env:GITHUB_HEAD_REF
        GITHUB_REPOSITORY = $env:GITHUB_REPOSITORY
        GITHUB_SHA = $env:GITHUB_SHA
        GITHUB_RUN_Script = $env:GITHUB_RUN_NUMBER
        PAGES_URL = "https://$($env:GITHUB_REPOSITORY_OWNER).github.io/$($env:GITHUB_REPOSITORY -replace '.*/','')/"
        DOCKER_REGISTRY = "ghcr.io"
        DOCKER_IMAGE_TAG = "pr-$($env:PR_NUMBER)"
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
            "0513",
            "0512",
            "0519"
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
        Container = @{
            Registry = "ghcr.io"
            ImageFormat = "pr-{PR_NUMBER}"
            IncludeInDashboard = $true
            IncludeInComment = $true
        }
    }
    
    # Reporting
    Reporting = @{
        GenerateReport = $true
        IncludeTimings = $true
        IncludeArtifacts = $true
        IncludeContainerStatus = $true
        ReportPath = "library/reports/reporting-summary.md"
    }
    
    # Post-execution hooks
    PostExecution = @{
        ValidateArtifacts = $true
        CreateIndex = $true
        IndexPath = "library/reports/index.md"
        IncludeDockerImageInfo = $true
    }
}
