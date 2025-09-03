#Requires -Version 5.1

<#
.SYNOPSIS
    CI/CD Environment Configuration for AitherZero
.DESCRIPTION
    Configuration optimized for CI/CD environments (GitHub Actions, Azure DevOps, etc.)
    This file is automatically loaded when CI environment is detected.
    
    Environment Detection:
    - GitHub Actions: GITHUB_ACTIONS=true
    - Azure DevOps: TF_BUILD=true
    - GitLab CI: GITLAB_CI=true
    - Generic: CI=true
.NOTES
    This configuration takes precedence over config.psd1 in CI environments
#>

@{
    # Core Configuration
    Core = @{
        Platform = 'auto'
        Profile = 'Full'  # Always use Full profile in CI
        Environment = 'CI'
        AutoStart = $false
        NonInteractive = $true
        DebugMode = $false
        CheckForUpdates = $false
        UsageAnalytics = $false
        TelemetryEnabled = $false
        Version = '1.0.0'
        Name = 'AitherZero-CI'
    }
    
    # System Configuration
    System = @{
        MaxConcurrentJobs = 4
        CommandTimeout = 600  # 10 minutes
        RetryAttempts = 2
        RetryDelay = 5
        EnableTranscript = $true
        TranscriptPath = './logs/ci-transcript.log'
        CleanupOnExit = $false  # Keep artifacts for debugging
        ErrorActionPreference = 'Stop'
        VerbosePreference = 'Continue'
        DebugPreference = 'SilentlyContinue'
        InformationPreference = 'Continue'
    }
    
    # Logging Configuration
    Logging = @{
        Enabled = $true
        Level = 'Information'
        Targets = 'Console, File'
        ConsoleLevelThreshold = 'Information'
        FileLevelThreshold = 'Debug'
        Path = './logs'
        FileNameFormat = 'ci-{timestamp:yyyy-MM-dd-HHmmss}.log'
        RetentionDays = 30
        MaxFileSize = '100MB'
        UseJsonFormat = $true  # Structured logging for CI
        IncludeTimestamp = $true
        IncludeScriptName = $true
        IncludeLineNumber = $true
        AuditEnabled = $true
        AuditPath = './logs/ci-audit.log'
    }
    
    # Testing Configuration
    Testing = @{
        Enabled = $true
        Framework = 'Pester'
        CodeCoverage = $true
        CoverageThreshold = 70
        OutputFormat = 'NUnitXml, JaCoCo'
        OutputPath = './tests/results'
        ReportsPath = './tests/reports'
        CoveragePath = './tests/coverage'
        ExitOnFailure = $false  # Complete all tests even if some fail
        Shuffle = $false  # Predictable test order in CI
        Parallel = $true
        MaxParallelJobs = 4
        TestTimeout = 300  # 5 minutes per test
        FailFast = $false
        SkipFlaky = $true  # Skip tests marked as flaky in CI
    }
    
    # Automation Configuration
    Automation = @{
        OrchestrationMode = 'Sequential'  # Predictable execution in CI
        MaxRetries = 2
        RetryDelay = 5
        ContinueOnError = $false
        ValidatePrerequisites = $true
        ValidateOutputs = $true
        EnableCheckpoints = $true
        CheckpointPath = './checkpoints'
        EnableRollback = $false  # CI should fail, not rollback
        ScriptTimeout = 600  # 10 minutes
        LogAllCommands = $true
        DryRun = $false
    }
    
    # Infrastructure Configuration
    Infrastructure = @{
        Provider = 'None'  # Don't provision infrastructure in CI
        ValidateOnly = $true
        MockProviders = $true  # Use mocks for infrastructure tests
        SkipProvisioning = $true
        SkipDestroy = $true
    }
    
    # Reporting Configuration
    Reporting = @{
        Enabled = $true
        GenerateHtml = $true
        GenerateMarkdown = $true
        GenerateJson = $true
        OutputPath = './reports'
        IncludeMetrics = $true
        IncludeTrends = $false  # No historical data in CI
        IncludeScreenshots = $false
        PublishToGitHub = $true
        PublishToAzure = $false
        PublishToS3 = $false
    }
    
    # CI-Specific Settings
    CI = @{
        Provider = 'auto'  # Auto-detect: GitHub, Azure, GitLab, etc.
        BuildNumber = $env:GITHUB_RUN_NUMBER ?? $env:BUILD_BUILDNUMBER ?? '0'
        BuildId = $env:GITHUB_RUN_ID ?? $env:BUILD_BUILDID ?? '0'
        Repository = $env:GITHUB_REPOSITORY ?? $env:BUILD_REPOSITORY_NAME ?? 'unknown'
        Branch = $env:GITHUB_REF_NAME ?? $env:BUILD_SOURCEBRANCHNAME ?? 'unknown'
        Commit = $env:GITHUB_SHA ?? $env:BUILD_SOURCEVERSION ?? 'unknown'
        PullRequest = $env:GITHUB_EVENT_NAME -eq 'pull_request'
        Actor = $env:GITHUB_ACTOR ?? $env:BUILD_REQUESTEDFOR ?? 'unknown'
        
        # Artifact settings
        ArtifactPath = './artifacts'
        ArtifactRetention = 30
        UploadTestResults = $true
        UploadCoverage = $true
        UploadLogs = $true
        
        # Notification settings
        NotifyOnFailure = $true
        NotifyOnSuccess = $false
        SlackWebhook = $env:SLACK_WEBHOOK_URL
        TeamsWebhook = $env:TEAMS_WEBHOOK_URL
        EmailRecipients = $env:EMAIL_RECIPIENTS
    }
    
    # Performance Thresholds (for CI validation)
    Performance = @{
        ModuleLoadTime = 5000  # 5 seconds max
        OrchestrationOverhead = 2000  # 2 seconds max
        ScriptExecutionTime = 30000  # 30 seconds max
        TestExecutionTime = 300000  # 5 minutes max
        MemoryLimit = '2GB'
        CPULimit = 80  # 80% max CPU
    }
    
    # Security Settings
    Security = @{
        EnableSecurityScanning = $true
        EnableDependencyCheck = $true
        EnableCredentialScanning = $true
        BlockOnHighSeverity = $true
        BlockOnCriticalSeverity = $true
        AllowedLicenses = @('MIT', 'Apache-2.0', 'BSD-3-Clause', 'BSD-2-Clause', 'ISC')
        BlockedLicenses = @('GPL', 'AGPL', 'LGPL')
    }
    
    # Bootstrap Settings
    Bootstrap = @{
        AutoInstallDependencies = $true
        InstallProfile = 'Full'
        SkipGitConfig = $true
        SkipSSHConfig = $true
        SkipUserPrompts = $true
        UseSystemPackageManager = $true
        ValidateInstallation = $true
        CleanupTempFiles = $true
    }
}