#Requires -Version 7.0

<#
.SYNOPSIS
    AitherZero Configuration Manifest - Single Source of Truth
.DESCRIPTION
    This is the master configuration manifest for the AitherZero infrastructure automation platform.
    Every aspect of the system is configuration-driven through this file for true CI/CD automation.
    
    This file serves as both:
    - Configuration store for all components
    - Manifest defining features, dependencies, and capabilities
    - Source of truth for automation workflows
    
    Configuration Features:
    - Native PowerShell Data File (.psd1) format
    - IntelliSense support in IDEs
    - Hierarchical configuration sections
    - Environment-specific overrides
    - Feature dependency mapping
    - Platform abstraction layer
    - CI/CD automation profiles
    
    Configuration Precedence (highest to lowest):
    1. Command-line parameters
    2. Environment variables (AITHERZERO_*)
    3. config.local.psd1 (local overrides, gitignored)
    4. This file (config.psd1) - Master manifest
    5. Module defaults (fallback only)
    
    Automation Philosophy:
    Everything must be configuration-driven. No hardcoded values in scripts.
    All automation scripts read from this configuration manifest.
    
.EXAMPLE
    # Override via environment variable for CI/CD:
    $env:AITHERZERO_PROFILE = "Full"
    $env:AITHERZERO_ENVIRONMENT = "Production"
    
.EXAMPLE
    # Load in automation scripts:
    $config = Get-Configuration
    $shouldInstall = $config.Features.Node.Enabled
    
.NOTES
    Version: 2.0 - Configuration-Driven Architecture
    This file is the single source of truth for all AitherZero operations
#>

# AitherZero Configuration Manifest - Single Source of Truth
@{
    # ===================================================================
    # PLATFORM MANIFEST - System Capabilities and Dependencies
    # ===================================================================
    Manifest = @{
        Name = 'AitherZero'
        Version = '2.0.0'
        Type = 'Infrastructure Automation Platform'
        Description = 'Configuration-driven infrastructure automation with number-based orchestration'
        
        # Platform support matrix
        SupportedPlatforms = @{
            Windows = @{
                Versions = @('10', '11', 'Server2019', 'Server2022')
                MinimumPowerShell = '7.0'
                RequiredFeatures = @('PowerShell7', 'Git')
                OptionalFeatures = @('HyperV', 'WSL2', 'Docker', 'Containers')
            }
            Linux = @{
                Distributions = @('Ubuntu 20.04+', 'Debian 11+', 'RHEL 8+', 'CentOS 8+')
                MinimumPowerShell = '7.0'
                RequiredPackages = @('curl', 'wget', 'git')
                PackageManagers = @('apt', 'yum', 'dnf')
            }
            macOS = @{
                Versions = @('11.0+', '12.0+', '13.0+')
                MinimumPowerShell = '7.0'
                RequiredTools = @('brew', 'git')
            }
        }
        
        # Feature dependency graph
        FeatureDependencies = @{
            # Core features that everything depends on
            Core = @{
                PowerShell7 = @{ Required = $true; MinVersion = '7.0'; Scripts = @('0001') }
                Git = @{ Required = $true; MinVersion = '2.0'; Scripts = @('0207') }
                Configuration = @{ Required = $true; Internal = $true }
                Logging = @{ Required = $true; Internal = $true }
            }
            
            # Development environment
            Development = @{
                Node = @{ 
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0201')
                    Features = @('npm', 'yarn', 'vite', 'nodemon')
                }
                Python = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0206')
                    Features = @('pip', 'poetry', 'virtualenv')
                }
                VSCode = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0210')
                    Extensions = @('ms-vscode.powershell', 'github.copilot')
                }
                Docker = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0208')
                    RequiresElevation = $true
                }
            }
            
            # Infrastructure components  
            Infrastructure = @{
                HyperV = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0105')
                    RequiresElevation = $true
                    PlatformRestrictions = @('Windows')
                }
                WSL2 = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0106')
                    RequiresElevation = $true
                    PlatformRestrictions = @('Windows')
                }
                OpenTofu = @{
                    DependsOn = @('Core.PowerShell7', 'Core.Git')
                    Scripts = @('0008', '0009')
                }
            }
            
            # Testing and quality assurance
            Testing = @{
                Pester = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0400')
                    MinVersion = '5.0.0'
                }
                PSScriptAnalyzer = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0400')
                    MinVersion = '1.20.0'
                }
            }
        }
        
        # Script execution profiles - what gets run for each profile
        ExecutionProfiles = @{
            Minimal = @{
                Description = 'Essential components only for basic operation'
                Features = @('Core.PowerShell7', 'Core.Git')
                ScriptRanges = @('0000-0099')
                EstimatedTime = '2-5 minutes'
            }
            Standard = @{
                Description = 'Common development environment'
                Features = @('Core', 'Development.Node', 'Testing.Pester', 'Testing.PSScriptAnalyzer')
                ScriptRanges = @('0000-0299', '0400-0410')
                EstimatedTime = '5-15 minutes'
            }
            Developer = @{
                Description = 'Full development environment with all tools'
                Features = @('Core', 'Development', 'Testing')
                ScriptRanges = @('0000-0499')
                EstimatedTime = '15-30 minutes'
            }
            Full = @{
                Description = 'Everything including infrastructure components'
                Features = @('*')
                ScriptRanges = @('*')
                EstimatedTime = '30-60 minutes'
            }
            CI = @{
                Description = 'Optimized for CI/CD environments'
                Features = @('Core', 'Testing', 'Development.Node')
                ScriptRanges = @('0000-0010', '0201', '0400-0450')
                Parallel = $true
                NonInteractive = $true
                EstimatedTime = '3-8 minutes'
            }
        }
        
        # Configuration schema version for validation
        SchemaVersion = '2.0'
        LastUpdated = '2025-10-25'
    }
    
    # ===================================================================
    # CORE CONFIGURATION - Fundamental System Settings
    # ===================================================================
    Core = @{
        # Platform and environment
        Name = 'AitherZero'
        Version = '2.0.0'
        Platform = 'auto'  # auto, windows, linux, macos
        Environment = 'Development'  # Development, Testing, Staging, Production, CI
        
        # Execution profiles - determines which features/scripts are enabled
        Profile = 'Standard'  # Minimal, Standard, Developer, Full, CI, Custom
        
        # Behavior settings
        AutoStart = $true
        NonInteractive = $false  # Automatically set to true in CI environments
        CI = $false  # Automatically detected in CI environments
        
        # User experience
        ClearScreenOnStart = $true  # Clear screen when starting interactive mode
        ShowWelcomeMessage = $true
        EnableAnimations = $true    # Disable in CI automatically
        
        # Monitoring and analytics
        UsageAnalytics = $false
        TelemetryEnabled = $false
        ErrorReporting = $true
        CheckForUpdates = $true
        
        # Debugging and development
        DebugMode = $false
        VerboseOutput = $false
        WhatIf = $false  # Preview mode - show what would be done
        DryRun = $false  # Test mode - validate but don't execute
        
        # Execution control
        ContinueOnError = $false
        SkipPrerequisites = $false
        ForceReinstall = $false
        
        # Output and reporting
        OutputFormat = 'Console'  # Console, JSON, XML, Markdown - automatically set to JSON in CI
        ShowProgress = $true
        ShowMemoryUsage = $false
        ShowExecutionTime = $true
        
        # Configuration management
        ConfigValidation = $true
        ConfigHotReload = $true
        ConfigBackup = $true
        
        # Session management
        SaveSession = $true
        RestoreOnStart = $false
        SessionTimeout = 3600
    }
    
    # ===================================================================
    # FEATURES - Component Installation and Configuration
    # ===================================================================
    Features = @{
        # Core requirements - always installed based on dependencies
        Core = @{
            PowerShell7 = @{
                Enabled = $true
                Required = $true
                Version = '7.0+'
                InstallScript = '0001'
                Platforms = @('Windows', 'Linux', 'macOS')
                Installer = @{
                    Windows = 'https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/PowerShell-7.4.6-win-x64.msi'
                    Linux = 'package-manager'  # Handled by bootstrap
                    macOS = 'package-manager'  # Handled by bootstrap
                }
            }
            Git = @{
                Enabled = $true
                Required = $true
                Version = '2.0+'
                InstallScript = '0207'
                Platforms = @('Windows', 'Linux', 'macOS')
                Configuration = @{
                    UserName = ''  # Prompt if empty
                    UserEmail = ''  # Prompt if empty
                    DefaultBranch = 'main'
                    AutoFetch = $true
                }
            }
        }
        
        # Development tools
        Development = @{
            Node = @{
                Enabled = $true  # Enabled by default for Standard+ profiles
                Version = 'latest-v20.x'
                InstallScript = '0201'
                Platforms = @('Windows', 'Linux', 'macOS')
                Configuration = @{
                    InstallNpm = $true
                    InstallYarn = $true
                    InstallPnpm = $false
                    GlobalPackages = @('yarn', 'vite', 'nodemon', '@types/node')
                    PackageManager = 'auto'  # auto, winget, chocolatey, apt, yum, brew
                }
                Installer = @{
                    Windows = 'https://nodejs.org/dist/latest-v20.x/node-v20-x64.msi'
                    Linux = 'package-manager'
                    macOS = 'package-manager'
                }
            }
            Python = @{
                Enabled = $false
                Version = '3.12+'
                InstallScript = '0206'
                Platforms = @('Windows', 'Linux', 'macOS')
                Configuration = @{
                    InstallPip = $true
                    InstallPoetry = $false
                    CreateVirtualEnv = $true
                    DefaultPackages = @('pip', 'setuptools', 'wheel')
                }
            }
            VSCode = @{
                Enabled = $false
                InstallScript = '0210'
                Platforms = @('Windows', 'Linux', 'macOS')
                Configuration = @{
                    Extensions = @(
                        'ms-vscode.powershell'
                        'ms-azuretools.vscode-docker'
                        'github.copilot'
                        'ms-python.python'
                        'ms-vscode.vscode-json'
                    )
                    Settings = @{
                        AutoSave = 'afterDelay'
                        FormatOnSave = $true
                        TabSize = 4
                    }
                }
            }
            Docker = @{
                Enabled = $false
                InstallScript = '0208'
                Platforms = @('Windows', 'Linux', 'macOS')
                RequiresElevation = $true
                Configuration = @{
                    StartOnBoot = $true
                    WSL2Backend = $true  # Windows only
                    Resources = @{
                        Memory = '4GB'
                        CPUs = 2
                        Disk = '60GB'
                    }
                }
            }
        }
        
        # Infrastructure components
        Infrastructure = @{
            HyperV = @{
                Enabled = $false
                InstallScript = '0105'
                Platforms = @('Windows')
                RequiresElevation = $true
                Configuration = @{
                    PrepareHost = $false
                    EnableManagementTools = $true
                    DefaultVMPath = 'C:\VMs'
                    DefaultVHDPath = 'C:\VHDs'
                }
            }
            WSL2 = @{
                Enabled = $false
                InstallScript = '0106'
                Platforms = @('Windows')
                RequiresElevation = $true
                Configuration = @{
                    Distribution = 'Ubuntu'
                    Version = '2'
                    Settings = @{
                        Memory = '4GB'
                        Processors = 2
                        SwapSize = '2GB'
                        LocalhostForwarding = $true
                    }
                }
            }
            OpenTofu = @{
                Enabled = $false
                Version = 'latest'
                InstallScript = '0008'
                InitializeScript = '0009'
                Platforms = @('Windows', 'Linux', 'macOS')
                Configuration = @{
                    Initialize = $false
                    WorkingDirectory = './infrastructure'
                }
            }
        }
        
        # Cloud and DevOps tools
        Cloud = @{
            GitHubCLI = @{
                Enabled = $true  # Required for git automation
                InstallScript = '0207'  # Integrated with Git installation
                Platforms = @('Windows', 'Linux', 'macOS')
                Configuration = @{
                    Authenticate = $false  # Manual auth required
                    Editor = 'code'
                    GitProtocol = 'https'
                }
                Installer = @{
                    Windows = 'https://github.com/cli/cli/releases/download/v2.67.0/gh_2.67.0_windows_amd64.msi'
                }
            }
            AzureCLI = @{
                Enabled = $false
                InstallScript = '0212'
                Platforms = @('Windows', 'Linux', 'macOS')
            }
            AWSCLI = @{
                Enabled = $false
                InstallScript = '0213'
                Platforms = @('Windows', 'Linux', 'macOS')
            }
        }
        
        # Testing and quality tools
        Testing = @{
            Pester = @{
                Enabled = $true  # Always enabled for Standard+ profiles
                Version = '5.0.0+'
                InstallScript = '0400'
                Required = $true
                Platforms = @('Windows', 'Linux', 'macOS')
            }
            PSScriptAnalyzer = @{
                Enabled = $true  # Always enabled for Standard+ profiles
                Version = '1.20.0+'
                InstallScript = '0400'
                Required = $true
                Platforms = @('Windows', 'Linux', 'macOS')
            }
        }
    }
    
    # ===================================================================
    # AUTOMATION - Orchestration and Execution Control
    # ===================================================================
    Automation = @{
        # Script execution settings
        ScriptsPath = './automation-scripts'
        DefaultTimeout = 3600
        MaxConcurrency = 4
        ParallelExecution = $true
        DefaultMode = 'Parallel'  # Parallel, Sequential, Staged, Conditional
        
        # Error handling and retries
        ContinueOnError = $false
        MaxRetries = 3
        RetryDelay = 5
        EnableRollback = $false
        
        # Execution control
        ValidateBeforeRun = $true
        SkipConfirmation = $false
        RequiredModules = @('ThreadJob')
        AutoInstallDependencies = $true
        
        # Progress and monitoring
        ShowProgress = $true
        ShowDependencies = $true
        ExecutionHistory = $true
        HistoryRetentionDays = 30
        CacheExecutionPlans = $true
        NotificationEnabled = $true
        
        # Execution profiles mapping
        Profiles = @{
            Minimal = @{
                Description = 'Core infrastructure deployment only'
                Scripts = @('0000-0099', '0100-0199')
                MaxConcurrency = 2
                Features = @('Core')
            }
            Standard = @{
                Description = 'Production-ready automation'
                Scripts = @('0000-0299', '0400-0499')
                MaxConcurrency = 4
                Features = @('Core', 'Development.Node', 'Testing')
            }
            Developer = @{
                Description = 'Complete development environment'
                Scripts = @('0000-0499')
                MaxConcurrency = 6
                Features = @('Core', 'Development', 'Testing')
            }
            Full = @{
                Description = 'Everything including optional components'
                Scripts = @('*')
                MaxConcurrency = 8
                Features = @('*')
            }
        }
    }
    
    # ===================================================================
    # USER INTERFACE - Display and Interaction Settings
    # ===================================================================
    UI = @{
        # Visual settings
        ShowHints = $true
        MenuStyle = 'Interactive'
        ClearScreenOnStart = $true
        TerminalWidth = 'auto'
        EnableAnimations = $false  # Disabled in CI automatically
        EnableColors = $true
        ShowWelcomeMessage = $true
        ProgressBarStyle = 'Classic'
        EnableEmoji = $true
        ShowExecutionTime = $true
        
        # Themes
        Theme = 'Default'
        Themes = @{
            Default = @{
                Primary = 'Cyan'
                Warning = 'Yellow'
                Success = 'Green'
                Error = 'Red'
                Info = 'White'
                Muted = 'DarkGray'
            }
            Dark = @{
                Primary = 'DarkCyan'
                Warning = 'DarkYellow'
                Success = 'DarkGreen'
                Error = 'DarkRed'
                Info = 'Gray'
                Muted = 'DarkGray'
            }
        }
    }
    
    # ===================================================================
    # TESTING - Test Execution and Quality Assurance
    # ===================================================================
    Testing = @{
        # Testing framework
        Framework = 'Pester'
        ShowProgress = $true
        NotifyOnCompletion = $true
        ShowSkipped = $true
        
        # Test execution profiles
        Profiles = @{
            Quick = @{
                Description = 'Fast validation for development'
                Categories = @('Unit', 'Syntax')
                Timeout = 300
                FailFast = $true
            }
            Standard = @{
                Description = 'Default test suite'
                Categories = @('Unit', 'Integration', 'Syntax')
                Timeout = 900
                FailFast = $false
            }
            Full = @{
                Description = 'Complete validation including performance'
                Categories = @('*')
                Timeout = 3600
                FailFast = $false
            }
            CI = @{
                Description = 'Continuous Integration suite'
                Categories = @('Unit', 'Integration', 'E2E')
                Timeout = 1800
                FailFast = $true
                GenerateReports = $true
                Platforms = @('Windows', 'Linux', 'macOS')
            }
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
            
            # Run settings
            Run = @{
                PassThru = $true  # Return result object
                Exit = $false     # Don't exit PowerShell after tests
                TestExtension = '.Tests.ps1'  # Test file extension
            }
            
            # Should assertion settings
            Should = @{
                ErrorAction = 'Stop'  # Stop, Continue, SilentlyContinue
            }
        }
        
        # PSScriptAnalyzer settings
        PSScriptAnalyzer = @{
            Enabled = $true
            OutputPath = './tests/analysis'
            
            # Select which rules to run
            IncludeRules = @('*')
            
            # Exclude specific rules
            ExcludeRules = @(
                'PSAvoidUsingWriteHost'  # We use Write-Host for UI output
                'PSUseShouldProcessForStateChangingFunctions'  # Not all functions need ShouldProcess
            )
            
            # Severity levels to check
            Severity = @('Error', 'Warning', 'Information')
        }
        
        # Code coverage
        CodeCoverage = @{
            Enabled = $true
            OutputPath = './tests/coverage'
            Format = @('JaCoCo', 'Cobertura')
            MinimumPercent = 80
            ExcludePaths = @('*/tests/*', '*/legacy-to-migrate/*', '*/examples/*')
        }
        
        # Test output
        OutputPath = './tests/results'
        OutputFormat = @('NUnitXml', 'JUnitXml')
        GenerateReport = $true
        OpenReportAfterRun = $false
    }
    
    # ===================================================================
    # DEVELOPMENT - Development Tools and Git Automation
    # ===================================================================
    Development = @{
        # Git automation
        GitAutomation = @{
            Enabled = $true
            DefaultBranch = 'main'
            AutoCommit = $false
            AutoPR = $false
            SignCommits = $false
            
            # Commit conventions
            CommitConventions = @{
                Format = 'conventional'
                SignOff = $true
                IssueReferences = $true
                Scopes = @('core', 'orchestration', 'infrastructure', 'tests', 'config', 'domains', 'ai', 'ui', 'automation')
                MaxSubjectLength = 72
                MaxBodyLineLength = 100
            }
            
            # Branch naming
            BranchNaming = @{
                Pattern = '{type}/{issue-number}-{description}'
                Types = @('feature', 'fix', 'docs', 'test', 'refactor', 'chore')
                MaxLength = 63
            }
        }
        
        # AI assistance
        AIAgenticCoding = @{
            Enabled = $true
            Provider = 'auto'
            ValidationRequired = $true
            AutoTestGeneration = $true
            
            # Code review settings
            CodeReview = @{
                PSScriptAnalyzer = $true
                DependencyCheck = $true
                ComplexityCheck = $true
                SecurityScan = $true
            }
            
            # Guardrails
            Guardrails = @{
                RequireDocumentation = $true
                RequireTests = $true
                RequireApproval = $true
                MaxFilesPerCommit = 10
                MaxLinesPerFile = 500
                AllowedFileTypes = @('.ps1', '.psm1', '.psd1', '.json', '.md', '.yml', '.yaml')
                BlockPatterns = @('password', 'secret', 'key', 'token')
            }
        }
        
        # Code quality
        CodeQuality = @{
            EnforceCodingStandards = $true
            StrictMode = 'Latest'
            MaxCyclomaticComplexity = 10
            MaxFunctionLength = 100
            RequireCommentBasedHelp = $true
            RequireTypeDeclarations = $false
        }
    }
    
    # ===================================================================
    # AI - Artificial Intelligence and Automation
    # ===================================================================
    AI = @{
        # General AI settings
        Enabled = $true
        
        # AI providers
        Providers = @{
            Claude = @{
                Enabled = $true
                Priority = 1
                MaxTokens = 4096
                Temperature = 0.7
                ApiKeyEnvVar = 'ANTHROPIC_API_KEY'
                Model = 'claude-3-sonnet-20240229'
                UsageTracking = $true
            }
            Codex = @{
                Enabled = $true
                Priority = 3
                MaxTokens = 8192
                Temperature = 0.5
                ApiKeyEnvVar = 'OPENAI_API_KEY'
                Model = 'gpt-4'
                UsageTracking = $true
            }
            Gemini = @{
                Enabled = $true
                Priority = 2
                MaxTokens = 2048
                Temperature = 0.9
                ApiKeyEnvVar = 'GOOGLE_API_KEY'
                Model = 'gemini-pro'
                UsageTracking = $true
            }
        }
        
        # AI capabilities
        TestGeneration = @{
            Enabled = $true
            Framework = 'Pester'
            Version = '5.0+'
            Provider = 'Claude'
            CoverageTarget = 80
            GenerateTypes = @('Unit', 'Integration', 'E2E')
            IncludeMocking = $true
            IncludeEdgeCases = $true
            IncludeErrorConditions = $true
        }
        
        CodeReview = @{
            Enabled = $true
            Profiles = @{
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
                Comprehensive = @{
                    Checks = @('security', 'quality', 'performance', 'compliance')
                    Providers = @('Claude', 'Gemini', 'Codex')
                    Description = 'Full analysis with all providers'
                    Timeout = 600
                    FailOnHighSeverity = $true
                }
            }
        }
        
        # Usage monitoring
        UsageMonitoring = @{
            Enabled = $true
            TrackCosts = $true
            GenerateReports = $true
            BudgetAlerts = @{
                Enabled = $true
                DailyLimit = 100
                MonthlyLimit = 1000
                AlertThreshold = 80
            }
        }
    }
    
    # ===================================================================
    # INFRASTRUCTURE - System and Infrastructure Settings
    # ===================================================================
    Infrastructure = @{
        # Provider settings
        Provider = 'opentofu'
        Hypervisor = 'hyperv'
        WorkingDirectory = './infrastructure'
        
        # Default resource settings
        DefaultVMPath = 'C:\VMs'
        DefaultMemory = '2GB'
        DefaultCPU = 2
        
        # Directory paths
        Directories = @{
            LocalPath = 'C:/temp'
            HyperVPath = 'C:/HyperV'
            IsoSharePath = 'C:/iso_share'
            InfraRepoPath = 'C:/Temp/base-infra'
        }
        
        # HyperV specific settings
        HyperV = @{
            EnableManagementTools = $true
            Https = $true
            Insecure = $true
            UseNtlm = $true
            Timeout = '30s'
            Port = 5986
            ScriptPath = 'C:/Temp/tofu_%RAND%.cmd'
            ProviderVersion = '1.2.1'
        }
        
        # Repository settings
        Repositories = @{
            RepoUrl = 'https://github.com/Aitherium/AitherLabs.git'
            InfraRepoUrl = 'https://github.com/Aitherium/aitherium-infrastructure.git'
        }
    }
    
    # ===================================================================
    # SYSTEM - Operating System Configuration
    # ===================================================================
    System = @{
        ComputerName = 'default-lab'
        SetComputerName = $false
        ConfigureFirewall = $false
        FirewallPorts = @(3389, 5985, 5986, 445, 135, '49152-65535')
        AllowRemoteDesktop = $false
        SetTrustedHosts = $false
        TrustedHosts = ''
        SetDNSServers = $false
        DNSServers = '8.8.8.8,1.1.1.1'
        DisableTCPIP6 = $false
        ConfigPXE = $false
        SetupLabProfile = $false
    }
    
    # ===================================================================
    # CERTIFICATE AUTHORITY - CA Configuration
    # ===================================================================
    CertificateAuthority = @{
        CommonName = 'default-lab-RootCA'
        ValidityYears = 5
        InstallCA = $false
    }
    
    # ===================================================================
    # SECURITY - Security and Access Control
    # ===================================================================
    Security = @{
        CredentialStore = 'LocalMachine'
        EncryptionType = 'AES256'
        PasswordComplexity = 'Medium'
        RequireSecureTransport = $true
        RequireAdminForInstall = $false
        EnforceExecutionPolicy = $false
        AllowUnsignedScripts = $true
        EnableMFA = $false
        MaxLoginAttempts = 3
        SessionTimeout = 3600
    }
    
    # ===================================================================
    # REPORTING - Reports and Analytics
    # ===================================================================
    Reporting = @{
        # Report generation
        AutoGenerateReports = $true
        DefaultFormat = 'HTML'
        ReportPath = './reports'
        ExportFormats = @('HTML', 'JSON', 'CSV', 'PDF', 'Markdown')
        CompressReports = $false
        IncludeSystemInfo = $true
        IncludeExecutionLogs = $true
        MetricsCollection = $true
        MetricsRetentionDays = 90
        
        # Dashboard
        DashboardEnabled = $true
        DashboardPort = 8080
        DashboardAutoOpen = $false
        ClearScreenOnStart = $false
        
        # Tech debt tracking
        TechDebtReporting = @{
            Enabled = $true
            AutoTrack = $true
            Schedule = 'Weekly'
            Thresholds = @{
                CodeQuality = 70
                Documentation = 80
                Security = 90
                ConfigUsage = 80
            }
        }
    }
    
    # ===================================================================
    # LOGGING - Logging and Audit Configuration
    # ===================================================================
    Logging = @{
        # General logging
        Level = 'Information'
        Path = './logs'
        File = 'logs/aitherzero.log'
        Console = $true
        MaxFileSize = '10MB'
        RetentionDays = 30
        Targets = @('Console', 'File')

        # Separate log files by level
        # Each log level writes to its own file for easier filtering and analysis
        # Files: errors-YYYY-MM-DD.log, warnings-YYYY-MM-DD.log, critical-YYYY-MM-DD.log,
        #        debug-YYYY-MM-DD.log, trace-YYYY-MM-DD.log, aitherzero-YYYY-MM-DD.log (all levels)
        SeparateLogFiles = $true

        # Centralized logging features
        # Use Import-Module CentralizedLogging for simplified logging across all scripts
        # Functions: Write-Log, Write-ErrorLog, Write-WarningLog, Write-InfoLog, etc.
        CentralizedLogging = @{
            Enabled = $true
            AutoDetectSource = $true  # Automatically detect calling script/module
            LogTestResults = $true    # Automatically log test results
            LogCodeAnalysis = $true   # Automatically log code analysis results
            LogOperations = $true     # Track operation start/stop with performance metrics
        }

        # Audit logging
        AuditLogging = @{
            Enabled = $true
            Level = 'All'
            ComplianceMode = $true
            IncludeUserInfo = $true
            IncludeSystemInfo = $true
            IncludeCorrelationId = $true
            RetentionDays = 90
        }
    }
    
    # ===================================================================
    # DEPENDENCIES - Module and Package Dependencies
    # ===================================================================
    Dependencies = @{
        # Validation settings
        ValidateOnStart = $true
        EnforceDependencies = $false
        UpdateFrequency = 'OnChange'
        
        # External PowerShell modules
        External = @{
            Pester = @{
                Version = '5.0.0+'
                Required = $false
                Description = 'Testing framework'
            }
            PSScriptAnalyzer = @{
                Version = '1.20.0+'
                Required = $false
                Description = 'Code quality analysis'
            }
            ThreadJob = @{
                Version = '2.0.3+'
                Required = $true
                Description = 'Required for parallel execution'
            }
        }
        
        # Internal modules and scripts (placeholder for future expansion)
        Modules = @{}
        Scripts = @{}
    }
}