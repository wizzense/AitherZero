#Requires -Version 7.0

<#
.SYNOPSIS
    AitherZero Configuration Example File

.DESCRIPTION
    This is a fully documented example configuration file for AitherZero.
    Copy this file to 'config.psd1' and customize for your environment.

    For local development overrides, create 'config.local.psd1' (gitignored).

.NOTES
    Configuration Precedence (highest to lowest):
    1. Command-line parameters (e.g., -Profile Full)
    2. Environment variables (e.g., $env:AITHERZERO_PROFILE = "Full")
    3. config.local.psd1 (local overrides, not in source control)
    4. config.psd1 (main configuration)
    5. CI defaults (automatically applied when CI detected)
    6. Script defaults (fallback values in scripts)

    CI Environment Detection:
    The system automatically detects CI environments by checking for:
    - $env:CI = 'true'
    - $env:GITHUB_ACTIONS = 'true'
    - $env:TF_BUILD = 'true' (Azure DevOps)
    - $env:GITLAB_CI = 'true'
    - And other common CI environment variables

    When CI is detected, these defaults are automatically applied:
    - Profile: 'Full' (all features enabled)
    - NonInteractive: $true (no user prompts)
    - WhatIf: $false (execute actions)
    - SkipPrerequisites: $false (check all prerequisites)

.EXAMPLE
    # Set environment variable to override a setting:
    $env:AITHERZERO_PROFILE = "Developer"
    $env:AITHERZERO_DEBUGMODE = "true"

.EXAMPLE
    # Use in a script with Get-ConfiguredValue:
    Import-Module ./domains/configuration/Configuration.psm1
    $ProfileName = Get-ConfiguredValue -Name 'Profile' -Default 'Standard'

.EXAMPLE
    # Load entire configuration:
    $config = Get-Configuration
    Write-Host "Current profile: $($config.Core.Profile)"
#>

@{
    # ===================================================================
    # CORE SETTINGS
    # ===================================================================
    Core = @{
        # Platform detection: 'auto', 'windows', 'linux', 'macos'
        # 'auto' will detect based on $IsWindows, $IsLinux, $IsMacOS
        Platform = 'auto'

        # Installation/Operation profile
        # - 'Minimal': Essential components only
        # - 'Standard': Common development tools (default)
        # - 'Developer': Full development environment
        # - 'Full': Everything including optional components
        Profile = 'Standard'

        # Environment context: 'Development', 'Testing', 'Production', 'CI'
        # Automatically set to 'CI' when CI environment detected
        Environment = 'Development'

        # Project metadata
        Name = 'AitherZero'
        Version = '1.0.0'

        # Diagnostic and telemetry settings
        DebugMode = $false           # Enable verbose debug output
        UsageAnalytics = $false       # Send anonymous usage statistics
        TelemetryEnabled = $false     # Send telemetry data
        ErrorReporting = $true        # Report errors for improvement
        CheckForUpdates = $true       # Check for AitherZero updates

        # Behavior settings
        AutoStart = $true             # Auto-start services after installation
    }

    # ===================================================================
    # AUTOMATION SETTINGS
    # ===================================================================
    Automation = @{
        # Script execution settings
        MaxConcurrency = 4            # Max parallel script executions
        ValidateBeforeRun = $true     # Run validation before execution
        AllowRestart = $false         # Allow automatic system restarts

        # Error handling
        StopOnError = $true           # Stop orchestration on first error
        RetryAttempts = 3             # Number of retry attempts
        RetryDelaySeconds = 5         # Delay between retries

        # Logging
        LogLevel = 'Information'      # Verbose, Debug, Information, Warning, Error
        LogToFile = $true             # Write logs to file
        LogPath = './logs'            # Path for log files

        # CI/CD settings (auto-enabled in CI environments)
        NonInteractive = $false       # No user prompts (true in CI)
        WhatIf = $false              # Preview mode without changes
        SkipPrerequisites = $false   # Skip prerequisite checks
    }

    # ===================================================================
    # TESTING SETTINGS
    # ===================================================================
    Testing = @{
        # Test execution profile
        # - 'Quick': Fast unit tests only (5-10 seconds)
        # - 'Standard': Unit and integration tests (1-2 minutes)
        # - 'Full': All tests including performance (5-10 minutes)
        # - 'CI': CI-optimized test suite with coverage
        Profile = 'Standard'

        # Test configuration
        RunCoverage = $true           # Generate code coverage reports
        CoverageThreshold = 80        # Minimum coverage percentage
        OutputFormat = 'NUnitXml'     # Test output format

        # Pester configuration
        Pester = @{
            # Parallel execution for faster test runs
            Parallel = @{
                Enabled = $true       # Run tests in parallel
                BlockSize = 4         # Tests per parallel batch
                Workers = 4           # Number of parallel workers
            }

            # Output configuration
            Output = @{
                Verbosity = 'Normal'  # None, Normal, Detailed, Diagnostic
                CIFormat = $true      # CI-friendly output
                StackTraceVerbosity = 'Filtered'
            }

            # Test filtering
            Filter = @{
                Tag = @()             # Include specific tags
                ExcludeTag = @()      # Exclude specific tags
            }

            # Run settings
            Run = @{
                PassThru = $true      # Return result object
                Exit = $false         # Don't exit after tests
                TestExtension = '.Tests.ps1'
            }

            # Should assertion behavior
            Should = @{
                ErrorAction = 'Stop'  # How to handle assertion failures
            }
        }

        # PSScriptAnalyzer settings
        PSScriptAnalyzer = @{
            Enable = $true            # Run static code analysis
            OutputPath = './tests/analysis'  # Analysis results output

            # Select which rules to run ('*' for all)
            IncludeRules = @('*')

            # Severity levels to check
            Severity = @('Error', 'Warning', 'Information')

            # Exclude specific rules
            ExcludeRules = @(
                'PSAvoidUsingWriteHost',           # We use Write-Host for UI
                'PSUseShouldProcessForStateChangingFunctions'  # Not all need confirmation
            )

            # Rule-specific settings
            Rules = @{
                PSProvideCommentHelp = @{
                    Enable = $true            # Require comment-based help
                    ExportedOnly = $false     # Check all functions
                    BlockComment = $true      # Use block comments
                    Placement = 'begin'       # Help at beginning
                }

                PSUseCompatibleSyntax = @{
                    Enable = $true            # Check syntax compatibility
                    TargetVersions = @('7.0') # Target PowerShell 7.0+
                }

                PSUseCorrectCasing = @{
                    Enable = $true            # Enforce correct casing
                }
            }
        }

        # Performance testing
        Performance = @{
            Enable = $false           # Run performance tests
            MaxDuration = 30          # Max seconds per test
            MemoryLimit = '1GB'       # Max memory usage
        }
    }

    # ===================================================================
    # REPORTING SETTINGS
    # ===================================================================
    Reporting = @{
        # Report generation
        GenerateReports = $true       # Auto-generate reports
        OutputFormat = 'HTML'         # HTML, Markdown, JSON, XML
        OutputPath = './reports'      # Report output directory

        # Dashboard settings
        Dashboard = @{
            Enable = $true            # Show dashboard UI
            RefreshInterval = 5       # Seconds between refreshes
            ShowMetrics = $true       # Display performance metrics
        }

        # Tech debt tracking
        TechDebt = @{
            Enable = $true            # Track technical debt
            ScanInterval = 'Daily'    # Daily, Weekly, Monthly
            MaxAge = 90               # Days to track debt items
        }
    }

    # ===================================================================
    # INSTALLATION OPTIONS
    # ===================================================================
    InstallationOptions = @{
        # Hyper-V Configuration (Windows only)
        HyperV = @{
            Install = $false          # Install Hyper-V feature
            PrepareHost = $false      # Configure Hyper-V host settings
            VMPath = 'C:\VMs'        # Default VM storage path
            VHDPath = 'C:\VHDs'      # Default VHD storage path
        }

        # Development Tools
        VSCode = @{
            Install = $false          # Install Visual Studio Code
            Extensions = @(           # Extensions to install
                'ms-vscode.powershell',
                'ms-azuretools.vscode-docker',
                'github.copilot'
            )
        }

        # Node.js Configuration
        Node = @{
            Install = $true           # Install Node.js
            Version = 'latest-v20.x'  # Node version to install
            InstallNpm = $true        # Install npm
            InstallYarn = $true       # Install Yarn package manager
            GlobalPackages = @(       # Global npm packages to install
                'yarn',
                'vite',
                'nodemon',
                'typescript'
            )
        }

        # Python Configuration
        Python = @{
            Install = $false          # Install Python
            Version = '3.12'          # Python version
            InstallPip = $true        # Install pip
            VirtualEnv = $true        # Create virtual environments
        }

        # Container Tools
        DockerDesktop = @{
            Install = $false          # Install Docker Desktop
            StartOnBoot = $true       # Auto-start Docker
            WSL2Backend = $true       # Use WSL2 backend (Windows)
        }

        # Cloud Tools
        AWSCLI = @{
            Install = $false          # Install AWS CLI
            ConfigureProfile = $false # Configure AWS profile
        }

        AzureCLI = @{
            Install = $false          # Install Azure CLI
            InstallExtensions = @()   # Azure CLI extensions
        }

        # IaC Tools
        OpenTofu = @{
            Install = $false          # Install OpenTofu
            Version = 'latest'        # OpenTofu version
            Initialize = $false       # Run tofu init
        }

        # Version Control
        GitHubCLI = @{
            Install = $true           # Install GitHub CLI
            Authenticate = $false     # Run gh auth login
        }

        Git = @{
            Install = $true           # Install Git
            ConfigureUser = $true     # Configure git user
            UserName = ''            # Git user name (prompt if empty)
            UserEmail = ''           # Git email (prompt if empty)
        }
    }

    # ===================================================================
    # INFRASTRUCTURE SETTINGS
    # ===================================================================
    Infrastructure = @{
        # Windows-specific settings
        Windows = @{
            EnableWSL2 = $false       # Enable WSL2
            EnableHyperV = $false     # Enable Hyper-V
            EnableContainers = $false # Enable Windows Containers
        }

        # Network configuration
        Network = @{
            ProxyUrl = ''            # HTTP proxy URL (if required)
            NoProxy = 'localhost,127.0.0.1,.local'  # Proxy bypass list
            DNSServers = @()         # Custom DNS servers
        }

        # Security settings
        Security = @{
            EnforceCodeSigning = $false  # Require signed scripts
            CertificateStore = 'CurrentUser'  # Cert store location
            TrustedPublishers = @()   # Trusted certificate thumbprints
        }
    }

    # ===================================================================
    # DEVELOPMENT SETTINGS
    # ===================================================================
    Development = @{
        # Git workflow settings
        Git = @{
            DefaultBranch = 'main'    # Default branch name
            CommitTemplate = ''       # Path to commit template
            PullRequestTemplate = ''  # Path to PR template
            AutoFetch = $true         # Auto-fetch remote changes
        }

        # Code quality
        CodeQuality = @{
            PreCommitHooks = $true    # Enable pre-commit hooks
            FormatOnSave = $true      # Auto-format code on save
            LintOnCommit = $true      # Run linter before commit
        }

        # AI assistance
        AI = @{
            EnableCopilot = $false    # Enable GitHub Copilot
            EnableChatGPT = $false    # Enable ChatGPT integration
            APIKey = ''              # API key (use env var in production)
        }
    }

    # ===================================================================
    # UI/UX SETTINGS
    # ===================================================================
    Experience = @{
        # User interface preferences
        UI = @{
            Theme = 'Default'         # UI theme: Default, Dark, Light
            ColorScheme = 'Auto'      # Terminal colors: Auto, Basic, Full
            ShowProgress = $true      # Show progress indicators
            ShowSpinner = $true       # Show activity spinners
            AnimationSpeed = 'Normal' # Slow, Normal, Fast, Instant
        }

        # Menu system
        Menu = @{
            UseEnhancedMenu = $true   # Use BetterMenu module
            ShowDescriptions = $true  # Show item descriptions
            PageSize = 10            # Items per page
            ShowSearch = $true        # Enable search in menus
        }

        # Notifications
        Notifications = @{
            Enable = $true            # Show notifications
            Sound = $false           # Play notification sounds
            Desktop = $false         # Show desktop notifications
        }
    }

    # ===================================================================
    # SESSION MANAGEMENT
    # ===================================================================
    Session = @{
        # Session tracking
        TrackSessions = $true         # Track user sessions
        SessionTimeout = 3600         # Session timeout (seconds)

        # State management
        SaveState = $true             # Save session state
        RestoreOnStart = $true        # Restore previous session
        StatePath = './state'         # State storage path

        # History
        SaveHistory = $true           # Save command history
        HistorySize = 1000           # Max history entries
        HistoryPath = './history'    # History storage path
    }

    # ===================================================================
    # CUSTOM SETTINGS
    # ===================================================================
    # Add your own custom configuration sections here
    Custom = @{
        # Example custom settings
        # MyApp = @{
        #     Setting1 = 'value1'
        #     Setting2 = 123
        # }
    }
}