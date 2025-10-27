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
                    Scripts = @('0206', '0204')  # Install Python and Poetry
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
                DevTools = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0205', '0209', '0211', '0214', '0215', '0216')  # Sysinternals, 7Zip, VS Build Tools, Packer, Chocolatey, PowerShell Profile
                    Description = 'Additional development utilities'
                }
                AITools = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0217', '0218')  # Claude Code, Gemini CLI
                    Description = 'AI-powered development tools'
                }
            }
            
            # Infrastructure components  
            Infrastructure = @{
                System = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0100')  # Configure-System
                    Description = 'Base system configuration'
                }
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
                WindowsAdminCenter = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0106')  # Script 0106 is used for both WSL2 and WindowsAdminCenter setup. The orchestration engine distinguishes usage by the parent key (WSL2 vs. WindowsAdminCenter) and passes context-specific parameters to the script. No conflict occurs as each domain invokes 0106 with its own configuration.
                    RequiresElevation = $true
                    PlatformRestrictions = @('Windows')
                }
                CertificateAuthority = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0104')
                    RequiresElevation = $true
                    PlatformRestrictions = @('Windows')
                }
                PXE = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0112')
                    RequiresElevation = $true
                    PlatformRestrictions = @('Windows')
                }
                OpenTofu = @{
                    DependsOn = @('Core.PowerShell7', 'Core.Git')
                    Scripts = @('0008', '0009')
                }
                Go = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0007')
                    Description = 'Go language runtime'
                }
                ValidationTools = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0006')
                    Description = 'Code validation and analysis tools'
                }
            }
            
            # Testing and quality assurance
            Testing = @{
                TestingTools = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0400')
                    Description = 'Install Pester and PSScriptAnalyzer'
                }
                Pester = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0400', '0402', '0403', '0409', '0411', '0480', '0490')
                    MinVersion = '5.0.0'
                    Description = 'Unit, integration, and smart testing'
                }
                PSScriptAnalyzer = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0400', '0404')
                    MinVersion = '1.20.0'
                    Description = 'Static code analysis'
                }
                CodeQuality = @{
                    DependsOn = @('Core.PowerShell7', 'Testing.Pester', 'Testing.PSScriptAnalyzer')
                    Scripts = @('0405', '0406', '0407', '0408')
                    Description = 'AST validation, syntax checks, coverage generation'
                }
                WorkflowTesting = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0440', '0441', '0442', '0443')
                    Description = 'GitHub Actions workflow validation and local testing'
                }
                TestOrchestration = @{
                    DependsOn = @('Testing.Pester')
                    Scripts = @('0450', '0460', '0470')
                    Description = 'Test orchestration and result publishing'
                }
            }
            
            # Reporting and analytics
            Reporting = @{
                SystemInfo = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0500', '0501')
                    Description = 'Environment validation and system information'
                }
                ProjectReports = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0510', '0511', '0512', '0513')
                    Description = 'Project reports, dashboards, and scheduling'
                }
                Analysis = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0520', '0521', '0522', '0523', '0524')
                    Description = 'Configuration, documentation, code quality, security, and tech debt analysis'
                }
                Logging = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0530', '0550')
                    Description = 'Log viewing and health dashboard'
                }
                CI = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0599')
                    Description = 'CI progress reporting'
                }
            }
            
            # Git automation and workflows
            Git = @{
                GitSetup = @{
                    DependsOn = @('Core.Git')
                    Scripts = @('0700')
                    Description = 'Git environment configuration'
                }
                GitWorkflow = @{
                    DependsOn = @('Core.Git')
                    Scripts = @('0701', '0702', '0703', '0704', '0705', '0709')
                    Description = 'Branch creation, commits, PRs, and comments'
                }
                GitHubRunners = @{
                    DependsOn = @('Core.Git', 'Core.PowerShell7')
                    Scripts = @('0720', '0721', '0722', '0723')
                    Description = 'GitHub Actions runner setup and configuration'
                }
            }
            
            # AI agents and automation
            AIAgents = @{
                Setup = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0730')
                    Description = 'AI agent setup and configuration'
                }
                CodeReview = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0731', '0735')
                    Description = 'AI-powered code review and security analysis'
                }
                TestGeneration = @{
                    DependsOn = @('Core.PowerShell7', 'Testing.Pester')
                    Scripts = @('0732')
                    Description = 'AI-powered test generation'
                }
                Documentation = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0733')
                    Description = 'AI-powered documentation generation'
                }
                Optimization = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0734', '0737', '0738', '0739')
                    Description = 'AI performance optimization, monitoring, training, and validation'
                }
                Workflows = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0736', '0740', '0741', '0742', '0743')
                    Description = 'AI workflow generation, integration, and automation'
                }
            }
            
            # Issue management and tracking
            IssueManagement = @{
                Creation = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0800', '0810', '0825', '0830', '0835')
                    Description = 'Issue creation from tests and manual triggers'
                }
                Analysis = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0801', '0805', '0815')
                    Description = 'Result parsing, issue analysis, and health monitoring'
                }
                Workflow = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0820', '0821', '0830', '0831')
                    Description = 'Work context, continuation prompts, and templates'
                }
            }
            
            # Deployment and validation
            Deployment = @{
                Infrastructure = @{
                    DependsOn = @('Infrastructure.OpenTofu')
                    Scripts = @('0300')
                    Description = 'Infrastructure deployment automation'
                }
                Validation = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0900', '0901')
                    Description = 'Self-deployment and local deployment testing'
                }
            }
            
            # Maintenance and cleanup
            Maintenance = @{
                Environment = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('0000', '0002')
                    Description = 'Environment cleanup and directory setup'
                }
                Reset = @{
                    DependsOn = @('Core.PowerShell7')
                    Scripts = @('9999')
                    Description = 'Complete machine reset'
                    RequiresElevation = $true
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
        
        # Domain module structure (actual repository state)
        Domains = @{
            'ai-agents' = @{ Modules = 3; Description = 'AI integration and workflow orchestration' }
            'automation' = @{ Modules = 2; Description = 'Orchestration engine and deployment automation' }
            'configuration' = @{ Modules = 1; Description = 'Unified configuration management' }
            'development' = @{ Modules = 4; Description = 'Developer tools and Git automation' }
            'documentation' = @{ Modules = 1; Description = 'Documentation generation engine' }
            'experience' = @{ Modules = 8; Description = 'UI/UX components and interactive menus' }
            'infrastructure' = @{ Modules = 1; Description = 'Infrastructure automation and management' }
            'reporting' = @{ Modules = 2; Description = 'Analytics, reporting, and tech debt analysis' }
            'security' = @{ Modules = 1; Description = 'Security and credential management' }
            'testing' = @{ Modules = 5; Description = 'Testing framework and test generation' }
            'utilities' = @{ Modules = 9; Description = 'Core utilities, logging, and maintenance' }
        }
        
        # Script inventory by range (111 total files, 101 unique numbers - some numbers have variants)
        ScriptInventory = @{
            '0000-0099' = @{ Count = 7; Category = 'Environment Setup' }
            '0100-0199' = @{ Count = 5; Category = 'Infrastructure' }
            '0200-0299' = @{ Count = 16; Category = 'Development Tools' }
            '0300-0399' = @{ Count = 1; Category = 'Deployment' }
            '0400-0499' = @{ Count = 19; Category = 'Testing & Quality' }
            '0500-0599' = @{ Count = 14; Category = 'Reporting & Analytics' }
            '0700-0799' = @{ Count = 25; Category = 'Git & AI Automation' }
            '0800-0899' = @{ Count = 11; Category = 'Issue Management' }
            '0900-0999' = @{ Count = 2; Category = 'Validation' }
            '9000-9999' = @{ Count = 1; Category = 'Maintenance' }
        }
        
        # Configuration schema version for validation
        SchemaVersion = '2.0'
        LastUpdated = '2025-10-27'
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
                Installer = @{
                    Windows = 'https://github.com/git-for-windows/git/releases/download/v2.48.1.windows.1/Git-2.48.1-64-bit.exe'
                    Linux = 'package-manager'
                    macOS = 'package-manager'
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
            System = @{
                Enabled = $false
                InstallScript = '0100'
                Platforms = @('Windows', 'Linux', 'macOS')
                Description = 'Base system configuration'
            }
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
            WindowsAdminCenter = @{
                Enabled = $false
                InstallScript = '0106'
                Platforms = @('Windows')
                RequiresElevation = $true
                Description = 'Windows Admin Center for remote management'
            }
            CertificateAuthority = @{
                Enabled = $false
                InstallScript = '0104'
                Platforms = @('Windows')
                RequiresElevation = $true
                Description = 'Certificate Authority installation'
            }
            PXE = @{
                Enabled = $false
                InstallScript = '0112'
                Platforms = @('Windows')
                RequiresElevation = $true
                Description = 'PXE boot configuration'
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
            Go = @{
                Enabled = $false
                Version = 'latest'
                InstallScript = '0007'
                Platforms = @('Windows', 'Linux', 'macOS')
                Description = 'Go programming language'
            }
            ValidationTools = @{
                Enabled = $true  # Enabled by default for code quality
                InstallScript = '0006'
                Platforms = @('Windows', 'Linux', 'macOS')
                Description = 'Validation and linting tools (actionlint, etc.)'
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
                    Linux = 'package-manager'
                    macOS = 'package-manager'
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
        
        # AI Development Tools
        AITools = @{
            ClaudeCode = @{
                Enabled = $false
                InstallScript = '0217'
                Platforms = @('Windows', 'Linux', 'macOS')
                Configuration = @{
                    APIKeyEnvVar = 'ANTHROPIC_API_KEY'
                    Model = 'claude-3-sonnet-20240229'
                }
            }
            GeminiCLI = @{
                Enabled = $false
                InstallScript = '0218'
                Platforms = @('Windows', 'Linux', 'macOS')
                Configuration = @{
                    APIKeyEnvVar = 'GOOGLE_API_KEY'
                    Model = 'gemini-pro'
                }
            }
        }
        
        # Additional Development Tools
        DevTools = @{
            Sysinternals = @{
                Enabled = $false
                InstallScript = '0205'
                Platforms = @('Windows')
                Description = 'Windows Sysinternals Suite'
            }
            SevenZip = @{
                Enabled = $false
                InstallScript = '0209'
                Platforms = @('Windows')
                Description = 'File compression utility'
            }
            VSBuildTools = @{
                Enabled = $false
                InstallScript = '0211'
                Platforms = @('Windows')
                Description = 'Visual Studio Build Tools'
                RequiresElevation = $true
            }
            Packer = @{
                Enabled = $false
                InstallScript = '0214'
                Platforms = @('Windows', 'Linux', 'macOS')
                Description = 'HashiCorp Packer for image building'
            }
            Chocolatey = @{
                Enabled = $false
                InstallScript = '0215'
                Platforms = @('Windows')
                Description = 'Windows package manager'
                RequiresElevation = $true
            }
            Poetry = @{
                Enabled = $false
                InstallScript = '0204'
                Platforms = @('Windows', 'Linux', 'macOS')
                Description = 'Python dependency management'
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
            Act = @{
                Enabled = $false
                InstallScript = '0442'
                Platforms = @('Windows', 'Linux', 'macOS')
                Description = 'Local GitHub Actions testing with nektos/act'
            }
            PowerShellYaml = @{
                Enabled = $false
                InstallScript = '0443'
                Platforms = @('Windows', 'Linux', 'macOS')
                Description = 'YAML parsing for workflow validation'
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