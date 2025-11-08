#Requires -Version 7.0

<#
.SYNOPSIS
    macOS-specific configuration for AitherZero
.DESCRIPTION
    Comprehensive macOS operating system configuration including:
    - System preferences and defaults
    - Homebrew package management
    - LaunchAgents and LaunchDaemons
    - Security and privacy settings
    - Development environment
    - Network configuration
    
    This file is loaded AFTER config.psd1 and BEFORE config.local.psd1
    Settings here override base config.psd1 but are overridden by config.local.psd1
    
    Can be used to generate macOS deployment artifacts:
    - Shell scripts for system configuration
    - Homebrew bundle files (Brewfile)
    - LaunchAgent/LaunchDaemon plists
    - Configuration profiles (.mobileconfig)
.NOTES
    Platform: macOS 11.0+ (Big Sur and later)
    Requires: PowerShell 7.0+
    Version: 1.0.0
#>

@{
    # ===================================================================
    # MACOS OPERATING SYSTEM CONFIGURATION
    # ===================================================================
    macOS = @{
        # Operating system metadata
        Metadata = @{
            TargetVersions = @('11.0+', '12.0+', '13.0+', '14.0+')  # Big Sur+
            ConfigVersion = '1.0.0'
            LastUpdated = '2025-11-07'
        }
        
        # ===================================================================
        # SYSTEM PREFERENCES (defaults)
        # ===================================================================
        SystemPreferences = @{
            AutoApply = $true
            BackupBeforeChanges = $true
            
            # General UI/UX
            General = @{
                # Expand save panel by default
                'NSGlobalDomain NSNavPanelExpandedStateForSaveMode' = @{
                    Value = $true
                    Type = 'bool'
                    Description = 'Expand save panel by default'
                }
                
                # Expand print panel by default
                'NSGlobalDomain PMPrintingExpandedStateForPrint' = @{
                    Value = $true
                    Type = 'bool'
                    Description = 'Expand print panel by default'
                }
                
                # Save to disk (not iCloud) by default
                'NSGlobalDomain NSDocumentSaveNewDocumentsToCloud' = @{
                    Value = $false
                    Type = 'bool'
                    Description = 'Save to disk by default, not iCloud'
                }
                
                # Disable automatic termination of inactive apps
                'NSGlobalDomain NSDisableAutomaticTermination' = @{
                    Value = $true
                    Type = 'bool'
                    Description = 'Disable automatic termination'
                }
                
                # Show scrollbars always
                'NSGlobalDomain AppleShowScrollBars' = @{
                    Value = 'Always'
                    Type = 'string'
                    Description = 'Show scrollbars (Always, Automatic, WhenScrolling)'
                }
            }
            
            # Finder
            Finder = @{
                # Show all filename extensions
                'NSGlobalDomain AppleShowAllExtensions' = @{
                    Value = $true
                    Type = 'bool'
                    Description = 'Show all file extensions'
                }
                
                # Show hidden files
                'com.apple.finder AppleShowAllFiles' = @{
                    Value = $true
                    Type = 'bool'
                    Description = 'Show hidden files'
                }
                
                # Show path bar
                'com.apple.finder ShowPathbar' = @{
                    Value = $true
                    Type = 'bool'
                    Description = 'Show path bar in Finder'
                }
                
                # Show status bar
                'com.apple.finder ShowStatusBar' = @{
                    Value = $true
                    Type = 'bool'
                    Description = 'Show status bar in Finder'
                }
                
                # Default view style (icnv, clmv, Flwv, Nlsv)
                'com.apple.finder FXPreferredViewStyle' = @{
                    Value = 'clmv'
                    Type = 'string'
                    Description = 'Default to column view'
                }
                
                # Search current folder by default
                'com.apple.finder FXDefaultSearchScope' = @{
                    Value = 'SCcf'
                    Type = 'string'
                    Description = 'Search current folder by default'
                }
                
                # Disable warning when changing file extension
                'com.apple.finder FXEnableExtensionChangeWarning' = @{
                    Value = $false
                    Type = 'bool'
                    Description = 'Disable extension change warning'
                }
                
                # Empty Trash securely
                'com.apple.finder EmptyTrashSecurely' = @{
                    Value = $false  # Slower, opt-in
                    Type = 'bool'
                    Description = 'Secure empty trash'
                }
            }
            
            # Dock
            Dock = @{
                # Minimize windows into application icon
                'com.apple.dock minimize-to-application' = @{
                    Value = $true
                    Type = 'bool'
                    Description = 'Minimize into app icon'
                }
                
                # Show indicator lights for open applications
                'com.apple.dock show-process-indicators' = @{
                    Value = $true
                    Type = 'bool'
                    Description = 'Show app indicators'
                }
                
                # Autohide dock
                'com.apple.dock autohide' = @{
                    Value = $false
                    Type = 'bool'
                    Description = 'Auto-hide dock'
                }
                
                # Speed up Mission Control animations
                'com.apple.dock expose-animation-duration' = @{
                    Value = 0.1
                    Type = 'float'
                    Description = 'Mission Control animation speed'
                }
                
                # Don't show recent applications
                'com.apple.dock show-recents' = @{
                    Value = $false
                    Type = 'bool'
                    Description = 'Hide recent applications'
                }
            }
            
            # Screen
            Screen = @{
                # Require password immediately after sleep
                'com.apple.screensaver askForPassword' = @{
                    Value = 1
                    Type = 'int'
                    Description = 'Require password after sleep'
                }
                
                # Delay before asking for password
                'com.apple.screensaver askForPasswordDelay' = @{
                    Value = 0
                    Type = 'int'
                    Description = 'Password delay in seconds'
                }
                
                # Enable subpixel font rendering on non-Apple LCDs
                'NSGlobalDomain AppleFontSmoothing' = @{
                    Value = 1
                    Type = 'int'
                    Description = 'Font smoothing level (0-3)'
                }
            }
            
            # Keyboard and Input
            Keyboard = @{
                # Enable full keyboard access for all controls
                'NSGlobalDomain AppleKeyboardUIMode' = @{
                    Value = 3
                    Type = 'int'
                    Description = 'Full keyboard access'
                }
                
                # Set fast key repeat rate
                'NSGlobalDomain KeyRepeat' = @{
                    Value = 2
                    Type = 'int'
                    Description = 'Key repeat rate (lower = faster)'
                }
                
                # Set short delay until key repeat
                'NSGlobalDomain InitialKeyRepeat' = @{
                    Value = 15
                    Type = 'int'
                    Description = 'Delay until key repeat'
                }
                
                # Disable auto-correct
                'NSGlobalDomain NSAutomaticSpellingCorrectionEnabled' = @{
                    Value = $false
                    Type = 'bool'
                    Description = 'Disable auto-correct'
                }
            }
            
            # Trackpad
            Trackpad = @{
                # Enable tap to click
                'com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking' = @{
                    Value = $true
                    Type = 'bool'
                    Description = 'Enable tap to click'
                }
                
                # Enable three finger drag
                'com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag' = @{
                    Value = $true
                    Type = 'bool'
                    Description = 'Enable three finger drag'
                }
            }
            
            # Terminal
            Terminal = @{
                # Only use UTF-8 in Terminal.app
                'com.apple.terminal StringEncodings' = @{
                    Value = @(4)
                    Type = 'array'
                    Description = 'UTF-8 only in Terminal'
                }
            }
            
            # Time Machine
            TimeMachine = @{
                # Prevent prompting to use new hard drives as backup
                'com.apple.TimeMachine DoNotOfferNewDisksForBackup' = @{
                    Value = $true
                    Type = 'bool'
                    Description = "Don't prompt for Time Machine"
                }
            }
            
            # Developer
            Developer = @{
                # Show debug menu in various apps
                'com.apple.DiskUtility DUDebugMenuEnabled' = @{
                    Value = $true
                    Type = 'bool'
                    Description = 'Show debug menu in Disk Utility'
                }
                
                # Enable developer extras in Safari
                'com.apple.Safari IncludeDevelopMenu' = @{
                    Value = $true
                    Type = 'bool'
                    Description = 'Enable Safari developer menu'
                }
            }
        }
        
        # ===================================================================
        # HOMEBREW PACKAGES
        # ===================================================================
        Homebrew = @{
            AutoInstall = $false
            AutoUpdate = $false
            
            # Command line tools
            Formulae = @(
                'git'
                'wget'
                'curl'
                'jq'
                'tree'
                'htop'
                'tmux'
                'vim'
                'neovim'
                'powershell'
                'node'
                'python@3.11'
                'go'
                'docker'
                'docker-compose'
            )
            
            # GUI applications
            Casks = @(
                'visual-studio-code'
                'iterm2'
                'docker'
                'google-chrome'
                'firefox'
                'rectangle'  # Window management
                'alfred'
                'stats'      # Menu bar system monitor
            )
            
            # Mac App Store apps (requires mas CLI)
            MAS = @(
                # Format: 'AppName AppStoreID'
                # Example: 'Xcode 497799835'
            )
            
            # Taps (third-party repositories)
            Taps = @(
                'homebrew/cask-fonts'
                'homebrew/cask-versions'
            )
        }
        
        # ===================================================================
        # LAUNCH AGENTS/DAEMONS
        # ===================================================================
        LaunchAgents = @{
            AutoApply = $false
            
            Agents = @(
                @{
                    Name = 'com.aitherzero.environment'
                    Enabled = $false
                    Label = 'com.aitherzero.environment'
                    ProgramArguments = @(
                        '/usr/local/bin/pwsh'
                        '-File'
                        '$HOME/.aitherzero/scripts/set-environment.ps1'
                    )
                    RunAtLoad = $true
                    StandardOutPath = '$HOME/Library/Logs/aitherzero-environment.log'
                    StandardErrorPath = '$HOME/Library/Logs/aitherzero-environment-error.log'
                }
            )
        }
        
        # ===================================================================
        # ENVIRONMENT VARIABLES
        # ===================================================================
        EnvironmentVariables = @{
            # System-wide variables (requires sudo)
            System = @{
                # Set in /etc/paths.d/ or /etc/launchd.conf
            }
            
            # User variables (in shell profile)
            User = @{
                'EDITOR' = 'vim'
                'VISUAL' = 'vim'
                'AITHERZERO_PROFILE' = 'Developer'
                'AITHERZERO_PLATFORM' = 'macOS'
            }
        }
        
        # ===================================================================
        # PATH CONFIGURATION
        # ===================================================================
        Path = @{
            # Paths to add
            Paths = @(
                '/usr/local/bin'
                '/usr/local/sbin'
                '/opt/homebrew/bin'      # Apple Silicon
                '/opt/homebrew/sbin'
                '$HOME/.local/bin'
                '$HOME/bin'
            )
        }
        
        # ===================================================================
        # SHELL CONFIGURATION
        # ===================================================================
        Shell = @{
            # Default shell
            DefaultShell = '/bin/zsh'
            
            # Shell profiles to configure
            Profiles = @(
                @{
                    Shell = 'zsh'
                    ConfigFile = '$HOME/.zshrc'
                    Initialize = $true
                }
                @{
                    Shell = 'bash'
                    ConfigFile = '$HOME/.bash_profile'
                    Initialize = $false
                }
            )
        }
        
        # ===================================================================
        # SECURITY
        # ===================================================================
        Security = @{
            # Firewall
            Firewall = @{
                Enabled = $true
                StealthMode = $true
                BlockAllIncoming = $false
            }
            
            # FileVault (disk encryption)
            FileVault = @{
                Enabled = $false  # Requires manual setup
                CheckStatus = $true
            }
            
            # Gatekeeper
            Gatekeeper = @{
                Enabled = $true
                AllowUnidentifiedDevelopers = $false
            }
        }
        
        # ===================================================================
        # DEVELOPMENT TOOLS
        # ===================================================================
        Development = @{
            # Xcode Command Line Tools
            XcodeTools = @{
                Install = $true
                AcceptLicense = $true
            }
            
            # Git configuration
            Git = @{
                UserName = ''  # Set in config.local.psd1
                UserEmail = ''  # Set in config.local.psd1
                DefaultBranch = 'main'
                
                # Global .gitignore
                GlobalIgnore = @(
                    '.DS_Store'
                    '._*'
                    '.Spotlight-V100'
                    '.Trashes'
                    'Thumbs.db'
                )
            }
        }
        
        # ===================================================================
        # NETWORK CONFIGURATION
        # ===================================================================
        Network = @{
            # DNS servers
            DNS = @{
                Servers = @('8.8.8.8', '1.1.1.1')
                ApplyToAllInterfaces = $false
            }
            
            # Hostname
            Hostname = @{
                ComputerName = 'macos-dev'
                LocalHostName = 'macos-dev'  # Bonjour name
                HostName = 'macos-dev.local'  # FQDN
            }
        }
        
        # ===================================================================
        # DEPLOYMENT ARTIFACT GENERATION
        # ===================================================================
        DeploymentArtifacts = @{
            # Shell script for configuration
            ShellScript = @{
                Generate = $true
                OutputPath = './artifacts/macos'
                FileName = 'aitherzero-setup.sh'
                Shebang = '#!/bin/bash'
            }
            
            # Homebrew bundle file (Brewfile)
            Brewfile = @{
                Generate = $true
                OutputPath = './artifacts/macos'
                FileName = 'Brewfile'
                IncludeFormulae = $true
                IncludeCasks = $true
                IncludeMAS = $true
                IncludeTaps = $true
            }
            
            # Configuration profile (.mobileconfig)
            ConfigurationProfile = @{
                Generate = $false
                OutputPath = './artifacts/macos'
                FileName = 'aitherzero.mobileconfig'
                Organization = 'AitherZero'
                Identifier = 'com.aitherzero.config'
            }
            
            # Ansible playbook
            Ansible = @{
                Generate = $false
                OutputPath = './artifacts/macos'
                PlaybookName = 'aitherzero-macos.yml'
            }
        }
    }
}
