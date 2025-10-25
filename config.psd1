#Requires -Version 7.0

<#
.SYNOPSIS
    AitherZero Configuration File
.DESCRIPTION
    Main configuration for the AitherZero infrastructure automation platform.
    Auto-updated on 2025-10-25 06:12:38
#>

# AitherZero Configuration
@{
    AI =     @{
        CodeReview =         @{
            Enabled = $true
            PerformanceChecks =             @{
                ArrayConcatenation = $true
                CachingOpportunities = $true
                IneffientFiltering = $true
                MemoryLeaks = $true
                RedundantModuleLoading = $true
            }
            Profiles =             @{
                Comprehensive =                 @{
                    Checks = @('security', 'quality', 'performance', 'compliance')
                    Description = 'Full analysis with all providers'
                    FailOnHighSeverity = $true
                    Providers = @('Claude', 'Gemini', 'Codex')
                    Timeout = 600
                }
                Quick =                 @{
                    Checks = @('syntax', 'quality')
                    Description = 'Fast validation for development'
                    Providers = @('Codex')
                    Timeout = 60
                }
                Standard =                 @{
                    Checks = @('security', 'quality', 'performance')
                    Description = 'Default review process'
                    Providers = @('Claude', 'Codex')
                    Timeout = 300
                }
            }
            QualityChecks =             @{
                Complexity = $true
                Documentation = $true
                DuplicateCode = $true
                ErrorHandling = $true
                NamingConventions = $true
                TechnicalDebt = $true
            }
            SecurityChecks =             @{
                AccessControl = $true
                CredentialExposure = $true
                Cryptography = $true
                InformationDisclosure = $true
                InjectionVulnerabilities = $true
                InputValidation = $true
            }
        }
        ContextManagement =         @{
            CacheExpiry = 86400
            CreateEmbeddings = $true
            Enabled = $true
            GenerateKnowledgeBase = $true
            IndexCodebase = $true
            UpdatePrompts = $true
            VersionControl = $true
        }
        Documentation =         @{
            AutoUpdateChangelog = $true
            DiagramFormat = 'Mermaid'
            Enabled = $true
            GenerateTypes = @('CommentBasedHelp', 'README', 'API', 'Architecture')
            IncludeExamples = $true
            Provider = 'Gemini'
        }
        Enabled = $true
        Fallback =         @{
            Enabled = $true
            RetryCount = 3
            RetryDelay = 2
            Strategy = 'Sequential'
        }
        OutputValidation =         @{
            BestPracticesCompliance = $true
            Enabled = $true
            HumanReviewWorkflow = $true
            PerformanceImpactAssessment = $true
            SecurityValidation = $true
            SyntaxChecking = $true
        }
        PerformanceOptimization =         @{
            BenchmarkEnabled = $true
            Enabled = $true
            GenerateComparisons = $true
            OptimizationTargets = @('Speed', 'Memory', 'Efficiency')
            ProfilingEnabled = $true
            Provider = 'Codex'
        }
        Providers =         @{
            Claude =             @{
                ApiKeyEnvVar = 'ANTHROPIC_API_KEY'
                BaseUrl = 'https://api.anthropic.com/v1'
                Enabled = $true
                MaxTokens = 4096
                Model = 'claude-3-sonnet-20240229'
                Priority = 1
                RateLimits =                 @{
                    ConcurrentRequests = 5
                    RequestsPerMinute = 50
                    TokensPerMinute = 100000
                }
                Temperature = 0.7
                UsageTracking = $true
                Version = '2023-06-01'
            }
            Codex =             @{
                ApiKeyEnvVar = 'OPENAI_API_KEY'
                BaseUrl = 'https://api.openai.com/v1'
                Enabled = $true
                MaxTokens = 8192
                Model = 'gpt-4'
                Priority = 3
                RateLimits =                 @{
                    ConcurrentRequests = 8
                    RequestsPerMinute = 60
                    TokensPerMinute = 150000
                }
                Temperature = 0.5
                UsageTracking = $true
            }
            Gemini =             @{
                ApiKeyEnvVar = 'GOOGLE_API_KEY'
                BaseUrl = 'https://generativelanguage.googleapis.com/v1beta'
                Enabled = $true
                MaxTokens = 2048
                Model = 'gemini-pro'
                Priority = 2
                RateLimits =                 @{
                    ConcurrentRequests = 10
                    RequestsPerMinute = 60
                    TokensPerMinute = 120000
                }
                Temperature = 0.9
                UsageTracking = $true
            }
        }
        SecurityAnalysis =         @{
            ComplianceChecks = @('SOC2', 'PCI-DSS', 'HIPAA')
            Enabled = $true
            GenerateRemediation = $true
            Provider = 'Claude'
            ThreatModeling = $true
            VulnerabilityScanning = $true
        }
        SessionManagement =         @{
            AutoIssueCreation =             @{
                BatchIssues = $true
                MaxIssuesPerRun = 10
                OnAnalyzerViolation = $true
                OnError = $false
                OnTestFailure = $true
            }
            AutoRestoreOnStart = $false
            AutoSaveOnExit = $true
            CompressContext = $true
            ContextPath = './.claude/session-context.json'
            ContinuationPrompt =             @{
                CopyToClipboard = $false
                GenerateOnSave = $true
                IncludeNextSteps = $true
                IncludePriorities = $true
                IncludeQuickCommands = $true
            }
            Enabled = $true
            GitHubActions =             @{
                CreateIssuesAutomatically = $true
                PostSummaryToPR = $true
                SaveContextOnFailure = $true
                UploadArtifacts = $true
            }
            HistoryCount = 50
            IncludeInContext =             @{
                CommandHistory = $true
                EnvironmentVariables = $false
                Errors = $true
                GitStatus = $true
                LoadedModules = $true
                ModifiedFiles = $true
                OpenIssues = $true
                TestResults = $true
                TodoItems = $true
            }
            MaxTokens = 4000
            PromptPath = './.claude/continuation-prompt.md'
        }
        TestGeneration =         @{
            CoverageTarget = 80
            Enabled = $true
            Framework = 'Pester'
            GenerateTypes = @('Unit', 'Integration', 'E2E')
            IncludeEdgeCases = $true
            IncludeErrorConditions = $true
            IncludeMocking = $true
            Provider = 'Claude'
            Version = '5.0+'
        }
        UsageMonitoring =         @{
            BudgetAlerts =             @{
                AlertThreshold = 80
                DailyLimit = 100
                Enabled = $true
                MonthlyLimit = 1000
            }
            Enabled = $true
            GenerateReports = $true
            OptimizationRecommendations = $true
            TrackCosts = $true
        }
        WorkflowGeneration =         @{
            DependencyResolution = $true
            Enabled = $true
            ErrorHandlingStrategies = $true
            GeneratePlaybooks = $true
            MultiAgentDistribution = $true
            Provider = 'Gemini'
            VisualizationEnabled = $true
        }
    }
    Automation =     @{
        AutoInstallDependencies = $true
        AutoRun = $false
        ContinueOnError = $false
        DefaultTimeout = 3600
        DryRunByDefault = $false
        MaxConcurrency = 4
        NotificationEnabled = $true
        ParallelExecution = $true
        Profiles =         @{
            Developer =             @{
                Description = 'Complete development environment'
                Scripts = @('0000-0499')
            }
            Full =             @{
                Description = 'Everything including optional components'
                Scripts = @('*')
            }
            Minimal =             @{
                Description = 'Core infrastructure deployment only'
                Scripts = @('0000-0099', '0100-0199')
            }
            Standard =             @{
                Description = 'Production-ready automation'
                Scripts = @('0000-0299', '0400-0499')
            }
        }
        ProgressDisplay = $true
        RequiredModules = @('ThreadJob')
        ScriptsPath = './automation-scripts'
        SoundAlerts = $false
        VerboseOutput = $false
    }
    CertificateAuthority =     @{
        CommonName = 'default-lab-RootCA'
        InstallCA = $false
        ValidityYears = 5
    }
    Core =     @{
        AutoStart = $true
        AutoUpdateConfig = $true
        CheckForUpdates = $true
        ConfigVersion = '1.0.0'
        DebugMode = $false
        Environment = 'Development'
        ErrorReporting = $true
        LastUpdated = '2025-10-25T06:12:38Z'
        Name = 'AitherZero'
        Platform = 'auto'
        Profile = 'Standard'
        TelemetryEnabled = $false
        UsageAnalytics = $false
        Version = '1.0.0'
    }
    Dependencies =     @{
        EnforceDependencies = $false
        External =         @{
            Pester =             @{
                Description = 'Testing framework'
                Required = $false
                Version = '5.0.0+'
            }
            PSScriptAnalyzer =             @{
                Description = 'Code quality analysis'
                Required = $false
                Version = '1.20.0+'
            }
            ThreadJob =             @{
                Description = 'Required for parallel execution'
                Required = $true
                Version = '2.0.3+'
            }
        }
        Modules =         @{
        }
        Scripts =         @{
        }
        UpdateFrequency = 'OnChange'
        ValidateOnStart = $true
    }
    Development =     @{
        AIAgenticCoding =         @{
            AutoTestGeneration = $true
            CodeReview =             @{
                ComplexityCheck = $true
                DependencyCheck = $true
                PSScriptAnalyzer = $true
                SecurityScan = $true
            }
            Enabled = $true
            Guardrails =             @{
                AllowedFileTypes = @('.ps1', '.psm1', '.psd1', '.json', '.md', '.yml', '.yaml')
                BlockPatterns = @('password', 'secret', 'key', 'token')
                MaxFilesPerCommit = 10
                MaxLinesPerFile = 500
                RequireApproval = $true
                RequireDocumentation = $true
                RequireTests = $true
            }
            Prompts =             @{
                CodeReview = 'Review for security, performance, and PowerShell best practices'
                Documentation = 'Generate comment-based help following PowerShell standards'
                TestGeneration = 'Generate Pester 5 tests with proper mocking and edge cases'
            }
            Provider = 'auto'
            ValidationRequired = $true
        }
        CodeQuality =         @{
            EnforceCodingStandards = $true
            MaxCyclomaticComplexity = 10
            MaxFunctionLength = 100
            RequireCommentBasedHelp = $true
            RequireTypeDeclarations = $false
            StrictMode = 'Latest'
        }
        GitAutomation =         @{
            AIWorkflowDefaults =             @{
                BranchType = 'feature'
                CommitType = 'feat'
                CreatePR = $true
                FilePatterns = @('*.ps1', '*.psm1', '*.psd1', '*.json', '*.md')
                Force = $true
                NonInteractive = $true
                PRBase = 'main'
            }
            AutoCommit = $false
            AutoPR = $false
            BranchConflictOptions =             @{
                AIAgentResolution = 'suffix'
                AutoPullOnCheckout = $true
                DefaultResolution = 'checkout'
                MaxSuffixAttempts = 10
                PreserveUncommittedChanges = $true
                ResolutionStrategies = @('checkout', 'suffix', 'recreate', 'abort')
                SuffixPattern = '-{number}'
            }
            BranchConflictResolution = 'checkout'
            BranchNaming =             @{
                MaxLength = 63
                Pattern = '{type}/{issue-number}-{description}'
                Types = @('feature', 'fix', 'docs', 'test', 'refactor', 'chore')
            }
            CommitConventions =             @{
                Format = 'conventional'
                IssueReferences = $true
                MaxBodyLineLength = 100
                MaxSubjectLength = 72
                Scopes = @('core', 'orchestration', 'infrastructure', 'tests', 'config', 'domains', 'ai', 'ui', 'automation')
                SignOff = $true
            }
            DefaultBranch = 'main'
            Enabled = $true
            IssueTracking =             @{
                AutoCreateIssues = $true
                CloseOnMerge = $true
                Labels =                 @{
                    AutoApply = $true
                    Categories = @('bug', 'enhancement', 'documentation', 'testing')
                }
                LinkCommits = $true
            }
            PullRequestTemplates =             @{
                Default = '.github/pull_request_template.md'
                Types =                 @{
                    bugfix = '.github/PULL_REQUEST_TEMPLATE/bugfix.md'
                    feature = '.github/PULL_REQUEST_TEMPLATE/feature.md'
                    hotfix = '.github/PULL_REQUEST_TEMPLATE/hotfix.md'
                }
            }
            SignCommits = $false
        }
    }
    Infrastructure =     @{
        DefaultCPU = 2
        DefaultMemory = '2GB'
        DefaultVMPath = 'C:\VMs'
        Directories =         @{
            HyperVPath = 'C:/HyperV'
            InfraRepoPath = 'C:/Temp/base-infra'
            IsoSharePath = 'C:/iso_share'
            LocalPath = 'C:/temp'
        }
        HyperV =         @{
            CacertPath = ''
            CertPath = ''
            EnableManagementTools = $true
            Host = ''
            Https = $true
            Insecure = $true
            KeyPath = ''
            Password = ''
            Port = 5986
            ProviderVersion = '1.2.1'
            ScriptPath = 'C:/Temp/tofu_%RAND%.cmd'
            Timeout = '30s'
            TlsServerName = ''
            UseNtlm = $true
            User = ''
        }
        Hypervisor = 'hyperv'
        Provider = 'opentofu'
        Repositories =         @{
            InfraRepoUrl = 'https://github.com/Aitherium/aitherium-infrastructure.git'
            RepoUrl = 'https://github.com/Aitherium/AitherLabs.git'
        }
        WorkingDirectory = './infrastructure'
    }
    InstallationOptions =     @{
        7Zip =         @{
            Install = $false
        }
        AWSCLI =         @{
            Install = $false
        }
        AzureCLI =         @{
            Install = $false
        }
        Chocolatey =         @{
            Install = $false
        }
        Cosign =         @{
            Install = $false
            Path = 'C:/temp/cosign'
            URL = 'https://github.com/sigstore/cosign/releases/download/v2.4.3/cosign-windows-amd64.exe'
        }
        DockerDesktop =         @{
            Install = $false
        }
        Git =         @{
            Install = $true
            Required = $true
            Version = '2.0+'
        }
        GitHubCLI =         @{
            Install = $true
            InstallerUrl = 'https://github.com/cli/cli/releases/download/v2.67.0/gh_2.67.0_windows_amd64.msi'
            Required = $false
        }
        Go =         @{
            Install = $false
            InstallerUrl = 'https://go.dev/dl/go1.24.1.windows-amd64.msi'
            Version = '1.20+'
        }
        GPG =         @{
            Install = $false
        }
        HyperV =         @{
            Install = $false
            PrepareHost = $false
        }
        Node =         @{
            CreateNpmPath = $false
            GlobalPackages = @('yarn', 'vite', 'nodemon')
            Install = $true
            InstallerUrl = 'https://nodejs.org/dist/latest-v20.x/node-v20-x64.msi'
            InstallNodemon = $true
            InstallNpm = $true
            InstallVite = $true
            InstallYarn = $true
            NpmPath = 'C:/Projects/vde-mvp/frontend'
        }
        OpenTofu =         @{
            Initialize = $false
            Install = $false
            Version = 'latest'
        }
        Packer =         @{
            Install = $false
        }
        Poetry =         @{
            Install = $false
            Version = 'latest'
        }
        PowerShell7 =         @{
            Install = $true
            Required = $true
            Version = '7.0+'
        }
        Python =         @{
            Install = $false
        }
        VSBuildTools =         @{
            Install = $false
        }
        VSCode =         @{
            Install = $false
        }
        WAC =         @{
            Install = $false
            InstallPort = 443
        }
        WSL2 =         @{
            AdditionalDistros = @()
            DefaultUser = ''
            Distribution = 'Ubuntu'
            Install = $false
            InstallTools = $true
            Settings =             @{
                LocalhostForwarding = $true
                Memory = '4GB'
                Processors = 2
                SwapSize = '2GB'
            }
            Tools = @('curl', 'wget', 'git', 'build-essential', 'python3', 'python3-pip', 'docker.io')
            Version = '2'
        }
    }
    Logging =     @{
        AuditLogging =         @{
            ComplianceMode = $true
            Enabled = $true
            IncludeCorrelationId = $true
            IncludeSystemInfo = $true
            IncludeUserInfo = $true
            Level = 'All'
            RetentionDays = 90
        }
        Console = $true
        File = 'logs/aitherzero.log'
        Level = 'Information'
        MaxFileSize = '10MB'
        Path = './logs'
        RetentionDays = 30
        Targets = @('Console', 'File')
    }
    Orchestration =     @{
        CacheExecutionPlans = $true
        CheckpointInterval = 10
        DefaultMode = 'Parallel'
        EmailNotifications = $false
        EnableRollback = $false
        ExecutionHistory = $true
        HistoryRetentionDays = 30
        MaxRetries = 3
        NotifyOnMilestone = $true
        RetryDelay = 5
        ShowDependencies = $true
        SkipConfirmation = $false
        SlackIntegration = $false
        TeamsIntegration = $false
        ValidateBeforeRun = $true
        WebhookNotifications = $false
    }
    Reporting =     @{
        AutoGenerateReports = $true
        ClearScreenOnStart = $false
        CompressReports = $false
        DashboardAutoOpen = $false
        DashboardEnabled = $true
        DashboardPort = 8080
        DefaultFormat = 'HTML'
        EmailReports = $false
        ExportFormats = @('HTML', 'JSON', 'CSV', 'PDF', 'Markdown')
        IncludeExecutionLogs = $true
        IncludeScreenshots = $false
        IncludeSystemInfo = $true
        MetricsCollection = $true
        MetricsRetentionDays = 90
        ReportPath = './reports'
        TechDebtReporting =         @{
            AutoTrack = $true
            Enabled = $true
            Schedule = 'Weekly'
            Thresholds =             @{
                CodeQuality = 70
                ConfigUsage = 80
                Documentation = 80
                Security = 90
            }
        }
        TemplateEngine = 'Default'
        UploadToCloud = $false
    }
    Security =     @{
        AllowUnsignedScripts = $true
        CredentialStore = 'LocalMachine'
        EnableMFA = $false
        EncryptionType = 'AES256'
        EnforceExecutionPolicy = $false
        MaxLoginAttempts = 3
        PasswordComplexity = 'Medium'
        RequireAdminForInstall = $false
        RequireSecureTransport = $true
        SessionTimeout = 3600
    }
    System =     @{
        AllowRemoteDesktop = $false
        ComputerName = 'default-lab'
        ConfigPXE = $false
        ConfigureFirewall = $false
        DisableTCPIP6 = $false
        DNSServers = '8.8.8.8,1.1.1.1'
        FirewallPorts = @(3389, 5985, 5986, 445, 135, '49152-65535')
        SetComputerName = $false
        SetDNSServers = $false
        SetTrustedHosts = $false
        SetupLabProfile = $false
        TrustedHosts = ''
    }
    Testing =     @{
        ASTValidation =         @{
            CheckCommandExistence = $true
            CheckModuleDependencies = $true
            CheckParameters = $true
            CheckSyntax = $true
            Enabled = $true
        }
        CodeCoverage =         @{
            Enabled = $true
            ExcludePaths = @('*/tests/*', '*/legacy-to-migrate/*', '*/examples/*')
            Format = @('JaCoCo', 'Cobertura')
            MinimumPercent = 80
            OutputPath = './tests/coverage'
        }
        ExitOnFailure = $false
        FailFastThreshold = 10
        Framework = 'Pester'
        GenerateReport = $true
        MaxConcurrency = 4
        MinVersion = '5.0.0'
        NotifyOnCompletion = $true
        OpenReportAfterRun = $false
        OutputFormat = @('NUnitXml', 'JUnitXml')
        OutputPath = './tests/results'
        Parallel = $true
        Performance =         @{
            CacheMinutes = 10
            CacheResults = $true
            DisableConfigWatch = $true
            FastStartup = $true
            MinimalLogging = $true
        }
        Pester =         @{
            Debug =             @{
                ReturnRawResultObject = $false
                ShowFullErrors = $false
                ShowNavigationMarkers = $false
                WriteDebugMessages = $false
                WriteDebugMessagesFrom = @()
            }
            Filter =             @{
                ExcludeTag = @()
                FullNameFilter = @()
                ScriptBlockFilter = @()
                Tag = @()
            }
            Output =             @{
                CIFormat = $true
                ShowPassedTests = $false
                StackTraceVerbosity = 'FirstLine'
                Verbosity = 'Minimal'
            }
            Parallel =             @{
                BlockSize = 5
                Enabled = $true
                ProcessIsolation = $true
                Workers = 6
            }
            Run =             @{
                Container = @()
                Exit = $false
                PassThru = $true
                SkipRemainingOnFailure = 'None'
                TestExtension = '.Tests.ps1'
            }
            Should =             @{
                DisableV5 = $false
                ErrorAction = 'Stop'
            }
            TestDrive =             @{
                Enabled = $true
            }
            TestRegistry =             @{
                Enabled = $true
            }
        }
        Profiles =         @{
            CI =             @{
                Categories = @('Unit', 'Integration', 'E2E')
                Description = 'Continuous Integration suite'
                FailFast = $true
                GenerateReports = $true
                Platforms = @('Windows', 'Linux', 'macOS')
                Timeout = 1800
            }
            Full =             @{
                Categories = @('*')
                Description = 'Complete validation including performance'
                FailFast = $false
                Timeout = 3600
            }
            Quick =             @{
                Categories = @('Unit', 'Syntax')
                Description = 'Fast validation for development'
                FailFast = $true
                Timeout = 300
            }
            Standard =             @{
                Categories = @('Unit', 'Integration', 'Syntax')
                Description = 'Default test suite'
                FailFast = $false
                Timeout = 900
            }
        }
        PSScriptAnalyzer =         @{
            Enabled = $true
            ExcludeRules = @('PSAvoidUsingWriteHost', 'PSUseShouldProcessForStateChangingFunctions')
            IncludeRules = @('*')
            OutputPath = './tests/analysis'
            Rules =             @{
                PSProvideCommentHelp =                 @{
                    BlockComment = $true
                    Enable = $true
                    ExportedOnly = $false
                    Placement = 'begin'
                }
                PSUseCompatibleSyntax =                 @{
                    Enable = $true
                    TargetVersions = @('7.0')
                }
                PSUseCorrectCasing =                 @{
                    Enable = $true
                }
            }
            Severity = @('Error', 'Warning', 'Information')
        }
        ShowInconclusive = $true
        ShowPending = $true
        ShowProgress = $true
        ShowSkipped = $true
    }
    TestIssueAutomation =     @{
        AutoCloseOnMerge = $true
        AutoCreateIssues = $true
        AutoLinkToPR = $true
        Enabled = $true
        IssueCreation =         @{
            GroupByFile = $true
            IncludeLogs = $true
            IncludeSystemContext = $true
            Labels =             @{
                Coverage = @('coverage', 'automated')
                Performance = @('performance', 'automated')
                PSScriptAnalyzer = @('code-quality', 'automated')
                TestFailure = @('bug', 'test-failure', 'automated')
            }
            MaxIssuesPerRun = 20
            Priority =             @{
                Error = 'P1'
                Information = 'P3'
                TestFailure = 'P1'
                Warning = 'P2'
            }
            Templates =             @{
                CodeViolation = '.github/ISSUE_TEMPLATE/code-violation.md'
                TestFailure = '.github/ISSUE_TEMPLATE/test-failure.md'
            }
            UpdateExisting = $true
        }
        LogCollection =         @{
            CompressLogs = $true
            IncludeSystemInfo = $true
            IncludeTestLogs = $true
            IncludeTranscripts = $true
            MaxLogSize = 1048576
            RedactSecrets = $true
        }
        Notifications =         @{
            EmailRecipients = @()
            OnIssueClosed = $true
            OnIssueCreated = $true
            OnPRLinked = $true
            SlackWebhook = ''
        }
        PRLinkage =         @{
            AutomaticKeywords = @('fix', 'fixes', 'resolve', 'resolves', 'close', 'closes')
            LinkTypes =             @{
                HighConfidence = 'Closes'
                LowConfidence = 'Refs'
                MediumConfidence = 'Fixes'
            }
            MatchThreshold = 0.7
            RequireIssueReference = $false
            UseAIMatching = $false
        }
    }
    UI =     @{
        AutoRefreshInterval = 5
        ClearScreenOnStart = $true
        EnableAnimations = $false
        EnableColors = $true
        EnableEmoji = $true
        MenuStyle = 'Interactive'
        NotificationPosition = 'TopRight'
        ProgressBarStyle = 'Classic'
        ShowExecutionTime = $true
        ShowHints = $true
        ShowMemoryUsage = $false
        ShowWelcomeMessage = $true
        TerminalWidth = 'auto'
        Theme = 'Default'
        Themes =         @{
            Dark =             @{
                Error = 'DarkRed'
                Info = 'Gray'
                Muted = 'DarkGray'
                Primary = 'DarkCyan'
                Secondary = 'DarkBlue'
                Success = 'DarkGreen'
                Warning = 'DarkYellow'
            }
            Default =             @{
                Error = 'Red'
                Info = 'White'
                Muted = 'DarkGray'
                Primary = 'Cyan'
                Secondary = 'Blue'
                Success = 'Green'
                Warning = 'Yellow'
            }
        }
    }
}
