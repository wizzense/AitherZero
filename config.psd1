#Requires -Version 7.0

<#
.SYNOPSIS
    AitherZero Configuration File
.DESCRIPTION
    Main configuration for the AitherZero infrastructure automation platform.
    
    This file uses PowerShell Data File format (.psd1) which provides:
    - Native PowerShell IntelliSense support
    - Syntax highlighting in editors
    - Comment support for documentation
    - No JSON escaping issues
    
    Configuration Precedence (highest to lowest):
    1. Command-line parameters
    2. Environment variables (AITHERZERO_*)
    3. config.local.psd1 (if exists, gitignored)
    4. This file (config.psd1)
    
    For CI/CD environments:
    - Set environment variable CI=true for automatic CI defaults
    - Or use AITHERZERO_* environment variables to override specific settings
    
.EXAMPLE
    # Override a setting via environment variable:
    $env:AITHERZERO_PROFILE = "Full"
    
.EXAMPLE
    # Load configuration in a script:
    $config = Import-PowerShellDataFile ./config.psd1
    
.NOTES
    Main configuration file for AitherZero platform
    Use config.example.psd1 for a fully documented template
#>

# AitherZero Configuration
@{
    Core = @{
        Platform = 'auto'
        UsageAnalytics = $false
        DebugMode = $false
        CheckForUpdates = $true
        Name = 'AitherZero'
        Profile = 'Standard'
        Version = '1.0.0'
        AutoStart = $true
        TelemetryEnabled = $false
        Environment = 'Development'
        ErrorReporting = $true
        # Auto-update settings
        AutoUpdateConfig = $true
        ConfigVersion = '1.0.0'
        LastUpdated = '2025-10-25 07:23:46'
    }
    InstallationOptions = @{
        HyperV = @{
            Install = $false
            PrepareHost = $false
        }
        Go = @{
            InstallerUrl = 'https://go.dev/dl/go1.24.1.windows-amd64.msi'
            Version = '1.20+'
            Install = $false
        }
        VSCode = @{
            Install = $false
        }
        Poetry = @{
            Install = $false
            Version = 'latest'
        }
        Node = @{
            InstallNpm = $true
            InstallYarn = $true
            CreateNpmPath = $false
            InstallVite = $true
            InstallerUrl = 'https://nodejs.org/dist/latest-v20.x/node-v20-x64.msi'
            Install = $true
            InstallNodemon = $true
            NpmPath = 'C:/Projects/vde-mvp/frontend'
            GlobalPackages = @('yarn', 'vite', 'nodemon')
        }
        Python = @{
            Install = $false
        }
        AWSCLI = @{
            Install = $false
        }
        OpenTofu = @{
            Initialize = $false
            Version = 'latest'
            Install = $false
        }
        DockerDesktop = @{
            Install = $false
        }
        GitHubCLI = @{
            InstallerUrl = 'https://github.com/cli/cli/releases/download/v2.67.0/gh_2.67.0_windows_amd64.msi'
            Install = $true
            Required = $false
        }
        WAC = @{
            Install = $false
            InstallPort = 443
        }
        WSL2 = @{
            Settings = @{
                SwapSize = '2GB'
                Memory = '4GB'
                LocalhostForwarding = $true
                Processors = 2
            }
            Tools = @(
                'curl'
                'wget'
                'git'
                'build-essential'
                'python3'
                'python3-pip'
                'docker.io'
            )
            InstallTools = $true
            Distribution = 'Ubuntu'
            DefaultUser = ''
            Version = '2'
            Install = $false
            AdditionalDistros = @()
        }
        VSBuildTools = @{
            Install = $false
        }
        Chocolatey = @{
            Install = $false
        }
        AzureCLI = @{
            Install = $false
        }
        Cosign = @{
            Path = 'C:/temp/cosign'
            Install = $false
            URL = 'https://github.com/sigstore/cosign/releases/download/v2.4.3/cosign-windows-amd64.exe'
        }
        Git = @{
            Version = '2.0+'
            Install = $true
            Required = $true
        }
        Packer = @{
            Install = $false
        }
        PowerShell7 = @{
            Version = '7.0+'
            Install = $true
            Required = $true
        }
        '7Zip' = @{
            Install = $false
        }
        GPG = @{
            Install = $false
        }
    }
    Orchestration = @{
        MaxRetries = 3
        EnableRollback = $false
        ExecutionHistory = $true
        CheckpointInterval = 10
        SlackIntegration = $false
        TeamsIntegration = $false
        ShowDependencies = $true
        ValidateBeforeRun = $true
        WebhookNotifications = $false
        CacheExecutionPlans = $true
        NotifyOnMilestone = $true
        RetryDelay = 5
        HistoryRetentionDays = 30
        DefaultMode = 'Parallel'
        EmailNotifications = $false
        SkipConfirmation = $false
    }
    UI = @{
        ShowHints = $true
        MenuStyle = 'Interactive'
        ClearScreenOnStart = $true
        TerminalWidth = 'auto'
        EnableAnimations = $false
        EnableColors = $true
        ShowWelcomeMessage = $true
        ProgressBarStyle = 'Classic'
        NotificationPosition = 'TopRight'
        ShowMemoryUsage = $false
        Themes = @{
            Default = @{
                Primary = 'Cyan'
                Warning = 'Yellow'
                Success = 'Green'
                Muted = 'DarkGray'
                Secondary = 'Blue'
                Info = 'White'
                Error = 'Red'
            }
            Dark = @{
                Primary = 'DarkCyan'
                Warning = 'DarkYellow'
                Success = 'DarkGreen'
                Muted = 'DarkGray'
                Secondary = 'DarkBlue'
                Info = 'Gray'
                Error = 'DarkRed'
            }
        }
        Theme = 'Default'
        EnableEmoji = $true
        ShowExecutionTime = $true
        AutoRefreshInterval = 5
    }
    Development = @{
        GitAutomation = @{
            BranchConflictOptions = @{
                AIAgentResolution = 'suffix'
                AutoPullOnCheckout = $true
                MaxSuffixAttempts = 10
                SuffixPattern = '-{number}'
                PreserveUncommittedChanges = $true
                ResolutionStrategies = @('checkout', 'suffix', 'recreate', 'abort')
                DefaultResolution = 'checkout'
            }
            SignCommits = $false
            Enabled = $true
            CommitConventions = @{
                Format = 'conventional'
                SignOff = $true
                IssueReferences = $true
                Scopes = @(
                    'core'
                    'orchestration'
                    'infrastructure'
                    'tests'
                    'config'
                    'domains'
                    'ai'
                    'ui'
                    'automation'
                )
                MaxSubjectLength = 72
                MaxBodyLineLength = 100
            }
            IssueTracking = @{
                Labels = @{
                    Categories = @('bug', 'enhancement', 'documentation', 'testing')
                    AutoApply = $true
                }
                LinkCommits = $true
                CloseOnMerge = $true
                AutoCreateIssues = $true
            }
            BranchConflictResolution = 'checkout'
            AutoPR = $false
            AutoCommit = $false
            DefaultBranch = 'main'
            BranchNaming = @{
                MaxLength = 63
                Pattern = '{type}/{issue-number}-{description}'
                Types = @(
                    'feature'
                    'fix'
                    'docs'
                    'test'
                    'refactor'
                    'chore'
                )
            }
            AIWorkflowDefaults = @{
                CreatePR = $true
                PRBase = 'main'
                FilePatterns = @('*.ps1', '*.psm1', '*.psd1', '*.json', '*.md')
                Force = $true
                BranchType = 'feature'
                CommitType = 'feat'
                NonInteractive = $true
            }
            PullRequestTemplates = @{
                Default = '.github/pull_request_template.md'
                Types = @{
                    feature = '.github/PULL_REQUEST_TEMPLATE/feature.md'
                    hotfix = '.github/PULL_REQUEST_TEMPLATE/hotfix.md'
                    bugfix = '.github/PULL_REQUEST_TEMPLATE/bugfix.md'
                }
            }
        }
        AIAgenticCoding = @{
            Prompts = @{
                Documentation = 'Generate comment-based help following PowerShell standards'
                CodeReview = 'Review for security, performance, and PowerShell best practices'
                TestGeneration = 'Generate Pester 5 tests with proper mocking and edge cases'
            }
            Enabled = $true
            CodeReview = @{
                PSScriptAnalyzer = $true
                DependencyCheck = $true
                ComplexityCheck = $true
                SecurityScan = $true
            }
            Provider = 'auto'
            Guardrails = @{
                RequireDocumentation = $true
                BlockPatterns = @('password', 'secret', 'key', 'token')
                AllowedFileTypes = @(
                    '.ps1'
                    '.psm1'
                    '.psd1'
                    '.json'
                    '.md'
                    '.yml'
                    '.yaml'
                )
                MaxFilesPerCommit = 10
                RequireTests = $true
                MaxLinesPerFile = 500
                RequireApproval = $true
            }
            AutoTestGeneration = $true
            ValidationRequired = $true
        }
        CodeQuality = @{
            EnforceCodingStandards = $true
            StrictMode = 'Latest'
            MaxCyclomaticComplexity = 10
            MaxFunctionLength = 100
            RequireCommentBasedHelp = $true
            RequireTypeDeclarations = $false
        }
    }
    CertificateAuthority = @{
        CommonName = 'default-lab-RootCA'
        ValidityYears = 5
        InstallCA = $false
    }
    TestIssueAutomation = @{
        AutoCreateIssues = $true
        Enabled = $true
        PRLinkage = @{
            LinkTypes = @{
                MediumConfidence = 'Fixes'
                HighConfidence = 'Closes'
                LowConfidence = 'Refs'
            }
            UseAIMatching = $false
            AutomaticKeywords = @(
                'fix'
                'fixes'
                'resolve'
                'resolves'
                'close'
                'closes'
            )
            RequireIssueReference = $false
            MatchThreshold = 0.7
        }
        IssueCreation = @{
            IncludeSystemContext = $true
            GroupByFile = $true
            Priority = @{
                Error = 'P1'
                Information = 'P3'
                Warning = 'P2'
                TestFailure = 'P1'
            }
            Labels = @{
                PSScriptAnalyzer = @('code-quality', 'automated')
                Coverage = @('coverage', 'automated')
                Performance = @('performance', 'automated')
                TestFailure = @('bug', 'test-failure', 'automated')
            }
            UpdateExisting = $true
            MaxIssuesPerRun = 20
            Templates = @{
                TestFailure = '.github/ISSUE_TEMPLATE/test-failure.md'
                CodeViolation = '.github/ISSUE_TEMPLATE/code-violation.md'
            }
            IncludeLogs = $true
        }
        LogCollection = @{
            MaxLogSize = 1048576
            RedactSecrets = $true
            CompressLogs = $true
            IncludeSystemInfo = $true
            IncludeTranscripts = $true
            IncludeTestLogs = $true
        }
        AutoLinkToPR = $true
        AutoCloseOnMerge = $true
        Notifications = @{
            OnPRLinked = $true
            OnIssueClosed = $true
            EmailRecipients = @()
            OnIssueCreated = $true
            SlackWebhook = ''
        }
    }
    Security = @{
        EncryptionType = 'AES256'
        PasswordComplexity = 'Medium'
        CredentialStore = 'LocalMachine'
        EnforceExecutionPolicy = $false
        RequireAdminForInstall = $false
        RequireSecureTransport = $true
        EnableMFA = $false
        MaxLoginAttempts = 3
        SessionTimeout = 3600
        AllowUnsignedScripts = $true
    }
    Testing = @{
        ShowProgress = $true
        NotifyOnCompletion = $true
        ShowSkipped = $true
        Framework = 'Pester'
        
        # Performance optimizations
        Performance = @{
            DisableConfigWatch = $true    # Prevent config file watching during tests
            MinimalLogging = $true        # Reduce logging overhead
            CacheResults = $true          # Enable test result caching
            CacheMinutes = 10            # Cache validity period
            FastStartup = $true          # Skip non-essential initializations
        }
        
        # Pester configuration
        Pester = @{
            # Parallel execution settings - optimized for performance
            Parallel = @{
                Enabled = $true
                BlockSize = 5   # Smaller batches for faster feedback  
                Workers = 6     # More workers for better parallelization
                ProcessIsolation = $true  # Run batches in separate processes
            }
            
            # Output settings - optimized for CI/CD
            Output = @{
                Verbosity = 'Minimal'     # Minimal output for speed
                CIFormat = $true          # Use CI-friendly output format
                StackTraceVerbosity = 'FirstLine'  # Reduce verbose output
                ShowPassedTests = $false  # Only show failures for speed
            }
            
            # Test filtering
            Filter = @{
                Tag = @()  # Tags to include (empty = all)
                ExcludeTag = @()  # Tags to exclude
                FullNameFilter = @()  # Test name patterns to include
                ScriptBlockFilter = @()  # ScriptBlock filters
            }
            
            # Run settings
            Run = @{
                PassThru = $true  # Return result object
                Exit = $false     # Don't exit PowerShell after tests
                SkipRemainingOnFailure = 'None'  # None, Run, Container, Block
                Container = @()   # Specific containers to run
                TestExtension = '.Tests.ps1'  # Test file extension
            }
            
            # Should assertion settings
            Should = @{
                ErrorAction = 'Stop'  # Stop, Continue, SilentlyContinue
                DisableV5 = $false    # Disable Pester v5 assertions
            }
            
            # Debug settings
            Debug = @{
                ShowFullErrors = $false
                WriteDebugMessages = $false
                WriteDebugMessagesFrom = @()  # Specific sources
                ShowNavigationMarkers = $false
                ReturnRawResultObject = $false
            }
            
            # TestDrive and TestRegistry
            TestDrive = @{
                Enabled = $true
            }
            
            TestRegistry = @{
                Enabled = $true
            }
        }
        PSScriptAnalyzer = @{
            Enabled = $true
            OutputPath = './tests/analysis'
            # SettingsPath removed - settings now inline in this config
            
            # Select which rules to run
            IncludeRules = @('*')
            
            # Exclude specific rules
            ExcludeRules = @(
                'PSAvoidUsingWriteHost'  # We use Write-Host for UI output
                'PSUseShouldProcessForStateChangingFunctions'  # Not all functions need ShouldProcess
            )
            
            # Severity levels to check
            Severity = @('Error', 'Warning', 'Information')
            
            # Rule-specific settings
            Rules = @{
                PSProvideCommentHelp = @{
                    Enable = $true
                    ExportedOnly = $false
                    BlockComment = $true
                    Placement = 'begin'
                }
                
                PSUseCompatibleSyntax = @{
                    Enable = $true
                    TargetVersions = @('7.0')
                }
                
                PSUseCorrectCasing = @{
                    Enable = $true
                }
            }
        }
        OutputPath = './tests/results'
        CodeCoverage = @{
            ExcludePaths = @('*/tests/*', '*/legacy-to-migrate/*', '*/examples/*')
            Enabled = $true
            OutputPath = './tests/coverage'
            Format = @('JaCoCo', 'Cobertura')
            MinimumPercent = 80
        }
        MinVersion = '5.0.0'
        OpenReportAfterRun = $false
        Profiles = @{
            CI = @{
                FailFast = $true
                Categories = @('Unit', 'Integration', 'E2E')
                Description = 'Continuous Integration suite'
                GenerateReports = $true
                Platforms = @('Windows', 'Linux', 'macOS')
                Timeout = 1800
            }
            Quick = @{
                FailFast = $true
                Description = 'Fast validation for development'
                Categories = @('Unit', 'Syntax')
                Timeout = 300
            }
            Standard = @{
                FailFast = $false
                Description = 'Default test suite'
                Categories = @('Unit', 'Integration', 'Syntax')
                Timeout = 900
            }
            Full = @{
                FailFast = $false
                Description = 'Complete validation including performance'
                Categories = @('*')
                Timeout = 3600
            }
        }
        FailFastThreshold = 10
        GenerateReport = $true
        Parallel = $true
        MaxConcurrency = 4
        ASTValidation = @{
            Enabled = $true
            CheckParameters = $true
            CheckSyntax = $true
            CheckCommandExistence = $true
            CheckModuleDependencies = $true
        }
        ShowInconclusive = $true
        ExitOnFailure = $false
        OutputFormat = @('NUnitXml', 'JUnitXml')
        ShowPending = $true
    }
    System = @{
        ConfigPXE = $false
        DisableTCPIP6 = $false
        DNSServers = '8.8.8.8,1.1.1.1'
        SetupLabProfile = $false
        SetDNSServers = $false
        ComputerName = 'default-lab'
        FirewallPorts = @(
            3389
            5985
            5986
            445
            135
            '49152-65535'
        )
        ConfigureFirewall = $false
        SetTrustedHosts = $false
        SetComputerName = $false
        TrustedHosts = ''
        AllowRemoteDesktop = $false
    }
    Infrastructure = @{
        Directories = @{
            InfraRepoPath = 'C:/Temp/base-infra'
            IsoSharePath = 'C:/iso_share'
            HyperVPath = 'C:/HyperV'
            LocalPath = 'C:/temp'
        }
        DefaultMemory = '2GB'
        HyperV = @{
            UseNtlm = $true
            Timeout = '30s'
            KeyPath = ''
            Password = ''
            Port = 5986
            CertPath = ''
            TlsServerName = ''
            Host = ''
            ProviderVersion = '1.2.1'
            CacertPath = ''
            ScriptPath = 'C:/Temp/tofu_%RAND%.cmd'
            EnableManagementTools = $true
            Https = $true
            Insecure = $true
            User = ''
        }
        DefaultVMPath = 'C:\VMs'
        WorkingDirectory = './infrastructure'
        Provider = 'opentofu'
        Repositories = @{
            RepoUrl = 'https://github.com/Aitherium/AitherLabs.git'
            InfraRepoUrl = 'https://github.com/Aitherium/aitherium-infrastructure.git'
        }
        Hypervisor = 'hyperv'
        DefaultCPU = 2
    }
    AI = @{
        ContextManagement = @{
            CreateEmbeddings = $true
            Enabled = $true
            IndexCodebase = $true
            CacheExpiry = 86400
            VersionControl = $true
            UpdatePrompts = $true
            GenerateKnowledgeBase = $true
        }
        TestGeneration = @{
            Enabled = $true
            IncludeErrorConditions = $true
            CoverageTarget = 80
            Provider = 'Claude'
            IncludeEdgeCases = $true
            Version = '5.0+'
            GenerateTypes = @('Unit', 'Integration', 'E2E')
            IncludeMocking = $true
            Framework = 'Pester'
        }
        UsageMonitoring = @{
            Enabled = $true
            TrackCosts = $true
            GenerateReports = $true
            OptimizationRecommendations = $true
            BudgetAlerts = @{
                MonthlyLimit = 1000
                Enabled = $true
                AlertThreshold = 80
                DailyLimit = 100
            }
        }
        OutputValidation = @{
            HumanReviewWorkflow = $true
            SyntaxChecking = $true
            SecurityValidation = $true
            Enabled = $true
            BestPracticesCompliance = $true
            PerformanceImpactAssessment = $true
        }
        Enabled = $true
        PerformanceOptimization = @{
            GenerateComparisons = $true
            Enabled = $true
            Provider = 'Codex'
            OptimizationTargets = @('Speed', 'Memory', 'Efficiency')
            ProfilingEnabled = $true
            BenchmarkEnabled = $true
        }
        CodeReview = @{
            Enabled = $true
            SecurityChecks = @{
                Cryptography = $true
                InjectionVulnerabilities = $true
                InputValidation = $true
                InformationDisclosure = $true
                AccessControl = $true
                CredentialExposure = $true
            }
            Profiles = @{
                Comprehensive = @{
                    FailOnHighSeverity = $true
                    Checks = @('security', 'quality', 'performance', 'compliance')
                    Providers = @('Claude', 'Gemini', 'Codex')
                    Description = 'Full analysis with all providers'
                    Timeout = 600
                }
                Quick = @{
                    Checks = @('syntax', 'quality')
                    Providers = @('Codex')
                    Description = 'Fast validation for development'
                    Timeout = 60
                }
                Standard = @{
                    Checks = @('security', 'quality', 'performance')
                    Providers = @('Claude', 'Codex')
                    Description = 'Default review process'
                    Timeout = 300
                }
            }
            PerformanceChecks = @{
                RedundantModuleLoading = $true
                IneffientFiltering = $true
                MemoryLeaks = $true
                CachingOpportunities = $true
                ArrayConcatenation = $true
            }
            QualityChecks = @{
                Documentation = $true
                TechnicalDebt = $true
                DuplicateCode = $true
                NamingConventions = $true
                Complexity = $true
                ErrorHandling = $true
            }
        }
        Fallback = @{
            RetryDelay = 2
            Enabled = $true
            RetryCount = 3
            Strategy = 'Sequential'
        }
        SessionManagement = @{
            PromptPath = './.claude/continuation-prompt.md'
            MaxTokens = 4000
            Enabled = $true
            AutoIssueCreation = @{
                MaxIssuesPerRun = 10
                OnTestFailure = $true
                BatchIssues = $true
                OnError = $false
                OnAnalyzerViolation = $true
            }
            ContinuationPrompt = @{
                CopyToClipboard = $false
                GenerateOnSave = $true
                IncludePriorities = $true
                IncludeNextSteps = $true
                IncludeQuickCommands = $true
            }
            AutoRestoreOnStart = $false
            GitHubActions = @{
                UploadArtifacts = $true
                PostSummaryToPR = $true
                SaveContextOnFailure = $true
                CreateIssuesAutomatically = $true
            }
            CompressContext = $true
            IncludeInContext = @{
                ModifiedFiles = $true
                GitStatus = $true
                TodoItems = $true
                LoadedModules = $true
                TestResults = $true
                CommandHistory = $true
                EnvironmentVariables = $false
                OpenIssues = $true
                Errors = $true
            }
            HistoryCount = 50
            AutoSaveOnExit = $true
            ContextPath = './.claude/session-context.json'
        }
        WorkflowGeneration = @{
            VisualizationEnabled = $true
            GeneratePlaybooks = $true
            Enabled = $true
            Provider = 'Gemini'
            ErrorHandlingStrategies = $true
            MultiAgentDistribution = $true
            DependencyResolution = $true
        }
        Providers = @{
            Codex = @{
                MaxTokens = 8192
                Enabled = $true
                RateLimits = @{
                    ConcurrentRequests = 8
                    TokensPerMinute = 150000
                    RequestsPerMinute = 60
                }
                Priority = 3
                Temperature = 0.5
                BaseUrl = 'https://api.openai.com/v1'
                ApiKeyEnvVar = 'OPENAI_API_KEY'
                UsageTracking = $true
                Model = 'gpt-4'
            }
            Claude = @{
                MaxTokens = 4096
                Enabled = $true
                RateLimits = @{
                    ConcurrentRequests = 5
                    TokensPerMinute = 100000
                    RequestsPerMinute = 50
                }
                Priority = 1
                Temperature = 0.7
                BaseUrl = 'https://api.anthropic.com/v1'
                Version = '2023-06-01'
                ApiKeyEnvVar = 'ANTHROPIC_API_KEY'
                UsageTracking = $true
                Model = 'claude-3-sonnet-20240229'
            }
            Gemini = @{
                MaxTokens = 2048
                Enabled = $true
                RateLimits = @{
                    ConcurrentRequests = 10
                    TokensPerMinute = 120000
                    RequestsPerMinute = 60
                }
                Priority = 2
                Temperature = 0.9
                BaseUrl = 'https://generativelanguage.googleapis.com/v1beta'
                ApiKeyEnvVar = 'GOOGLE_API_KEY'
                UsageTracking = $true
                Model = 'gemini-pro'
            }
        }
        Documentation = @{
            IncludeExamples = $true
            Enabled = $true
            Provider = 'Gemini'
            AutoUpdateChangelog = $true
            GenerateTypes = @('CommentBasedHelp', 'README', 'API', 'Architecture')
            DiagramFormat = 'Mermaid'
        }
        SecurityAnalysis = @{
            ComplianceChecks = @('SOC2', 'PCI-DSS', 'HIPAA')
            Enabled = $true
            GenerateRemediation = $true
            Provider = 'Claude'
            VulnerabilityScanning = $true
            ThreatModeling = $true
        }
    }
    Dependencies = @{
        External = @{
            PSScriptAnalyzer = @{
                Version = '1.20.0+'
                Required = $false
                Description = 'Code quality analysis'
            }
            Pester = @{
                Version = '5.0.0+'
                Required = $false
                Description = 'Testing framework'
            }
            ThreadJob = @{
                Version = '2.0.3+'
                Required = $true
                Description = 'Required for parallel execution'
            }
        }
        ValidateOnStart = $true
        Scripts = @{}
        UpdateFrequency = 'OnChange'
        EnforceDependencies = $false
        Modules = @{}
    }
    Automation = @{
        ScriptsPath = './automation-scripts'
        DefaultTimeout = 3600
        ContinueOnError = $false
        RequiredModules = @('ThreadJob')
        AutoRun = $false
        NotificationEnabled = $true
        Profiles = @{
            Developer = @{
                Description = 'Complete development environment'
                Scripts = @('0000-0499')
            }
            Minimal = @{
                Description = 'Core infrastructure deployment only'
                Scripts = @('0000-0099', '0100-0199')
            }
            Standard = @{
                Description = 'Production-ready automation'
                Scripts = @('0000-0299', '0400-0499')
            }
            Full = @{
                Description = 'Everything including optional components'
                Scripts = @('*')
            }
        }
        ParallelExecution = $true
        ProgressDisplay = $true
        AutoInstallDependencies = $true
        MaxConcurrency = 4
        SoundAlerts = $false
        DryRunByDefault = $false
        VerboseOutput = $false
    }
    Reporting = @{
        ClearScreenOnStart = $false  # Fix missing config key
        TechDebtReporting = @{
            Thresholds = @{
                Documentation = 80
                ConfigUsage = 80
                Security = 90
                CodeQuality = 70
            }
            Enabled = $true
            AutoTrack = $true
            Schedule = 'Weekly'
        }
        DashboardEnabled = $true
        ReportPath = './reports'
        DashboardPort = 8080
        ExportFormats = @('HTML', 'JSON', 'CSV', 'PDF', 'Markdown')
        CompressReports = $false
        UploadToCloud = $false
        DashboardAutoOpen = $false
        EmailReports = $false
        IncludeScreenshots = $false
        IncludeSystemInfo = $true
        DefaultFormat = 'HTML'
        AutoGenerateReports = $true
        MetricsCollection = $true
        MetricsRetentionDays = 90
        IncludeExecutionLogs = $true
        TemplateEngine = 'Default'
    }
    Logging = @{
        MaxFileSize = '10MB'
        Console = $true
        File = 'logs/aitherzero.log'
        AuditLogging = @{
            Enabled = $true
            IncludeCorrelationId = $true
            ComplianceMode = $true
            IncludeUserInfo = $true
            IncludeSystemInfo = $true
            RetentionDays = 90
            Level = 'All'
        }
        RetentionDays = 30
        Targets = @('Console', 'File')
        Path = './logs'
        Level = 'Information'
    }
}


