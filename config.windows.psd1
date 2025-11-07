#Requires -Version 7.0

<#
.SYNOPSIS
    Windows-specific configuration for AitherZero
.DESCRIPTION
    Comprehensive Windows operating system configuration including:
    - Registry settings and tweaks
    - Windows Features
    - System performance settings
    - Security and privacy settings
    - Development environment
    - Network configuration
    
    This file is loaded AFTER config.psd1 and BEFORE config.local.psd1
    Settings here override base config.psd1 but are overridden by config.local.psd1
    
    Can be used to generate Windows deployment artifacts:
    - Unattend.xml files
    - Registry import files (.reg)
    - PowerShell DSC configurations
    - Group Policy Objects (GPO)
.NOTES
    Platform: Windows 10/11, Server 2019/2022
    Requires: PowerShell 7.0+
    Version: 1.0.0
#>

@{
    # ===================================================================
    # WINDOWS OPERATING SYSTEM CONFIGURATION
    # ===================================================================
    Windows = @{
        # Operating system metadata
        Metadata = @{
            TargetOS = @('Windows 10', 'Windows 11', 'Windows Server 2019', 'Windows Server 2022')
            MinimumVersion = '10.0.19041'  # Windows 10 20H1
            ConfigVersion = '1.0.0'
            LastUpdated = '2025-11-07'
        }
        
        # ===================================================================
        # REGISTRY SETTINGS
        # ===================================================================
        Registry = @{
            # Enable/disable automatic registry modifications
            AutoApply = $true
            BackupBeforeChanges = $true
            
            # File System settings
            FileSystem = @{
                # Enable long path support (> 260 characters)
                LongPathsEnabled = @{
                    Enabled = $true
                    Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
                    Name = 'LongPathsEnabled'
                    Type = 'DWord'
                    Value = 1
                    Description = 'Enable NTFS long path support (paths > 260 characters)'
                    RequiresRestart = $false
                }
                
                # Disable 8.3 filename generation (performance)
                NtfsDisable8dot3NameCreation = @{
                    Enabled = $false  # Opt-in for compatibility
                    Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
                    Name = 'NtfsDisable8dot3NameCreation'
                    Type = 'DWord'
                    Value = 1
                    Description = 'Disable 8.3 filename generation for performance'
                    RequiresRestart = $false
                }
                
                # Disable last access time tracking (performance)
                NtfsDisableLastAccessUpdate = @{
                    Enabled = $false  # Opt-in
                    Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
                    Name = 'NtfsDisableLastAccessUpdate'
                    Type = 'DWord'
                    Value = 1
                    Description = 'Disable last access time updates for performance'
                    RequiresRestart = $false
                }
            }
            
            # Explorer settings
            Explorer = @{
                # Show file extensions
                HideFileExt = @{
                    Enabled = $true
                    Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
                    Name = 'HideFileExt'
                    Type = 'DWord'
                    Value = 0  # 0 = show extensions
                    Description = 'Show file extensions in Explorer'
                }
                
                # Show hidden files
                Hidden = @{
                    Enabled = $true
                    Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
                    Name = 'Hidden'
                    Type = 'DWord'
                    Value = 1  # 1 = show hidden files
                    Description = 'Show hidden files and folders'
                }
                
                # Show system files
                ShowSuperHidden = @{
                    Enabled = $false  # More dangerous
                    Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
                    Name = 'ShowSuperHidden'
                    Type = 'DWord'
                    Value = 1
                    Description = 'Show protected operating system files'
                }
                
                # Launch to This PC instead of Quick Access
                LaunchTo = @{
                    Enabled = $true
                    Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
                    Name = 'LaunchTo'
                    Type = 'DWord'
                    Value = 1  # 1 = This PC, 2 = Quick Access
                    Description = 'Open Explorer to This PC by default'
                }
                
                # Show full path in title bar
                FullPath = @{
                    Enabled = $true
                    Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState'
                    Name = 'FullPath'
                    Type = 'DWord'
                    Value = 1
                    Description = 'Show full path in Explorer title bar'
                }
            }
            
            # Performance settings
            Performance = @{
                # Disable unnecessary visual effects
                VisualFXSetting = @{
                    Enabled = $false  # Opt-in
                    Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
                    Name = 'VisualFXSetting'
                    Type = 'DWord'
                    Value = 2  # 2 = Best performance
                    Description = 'Set visual effects for best performance'
                }
                
                # Disable animations
                TaskbarAnimations = @{
                    Enabled = $false
                    Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
                    Name = 'TaskbarAnimations'
                    Type = 'DWord'
                    Value = 0
                    Description = 'Disable taskbar animations'
                }
            }
            
            # Developer settings
            Developer = @{
                # Enable Developer Mode
                AllowDevelopmentWithoutDevLicense = @{
                    Enabled = $false  # Opt-in for security
                    Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
                    Name = 'AllowDevelopmentWithoutDevLicense'
                    Type = 'DWord'
                    Value = 1
                    Description = 'Enable Windows Developer Mode'
                    RequiresAdmin = $true
                }
                
                # Enable Win32 long paths for applications
                Win32LongPathsEnabled = @{
                    Enabled = $true
                    Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
                    Name = 'LongPathsEnabled'
                    Type = 'DWord'
                    Value = 1
                    Description = 'Enable long paths for Win32 applications'
                    RequiresAdmin = $true
                }
            }
            
            # Privacy settings
            Privacy = @{
                # Disable telemetry
                AllowTelemetry = @{
                    Enabled = $false  # Opt-in
                    Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
                    Name = 'AllowTelemetry'
                    Type = 'DWord'
                    Value = 0  # 0 = Security (Enterprise only), 1 = Basic, 3 = Full
                    Description = 'Disable Windows telemetry'
                    RequiresAdmin = $true
                }
                
                # Disable advertising ID
                DisabledByGroupPolicy = @{
                    Enabled = $true
                    Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'
                    Name = 'DisabledByGroupPolicy'
                    Type = 'DWord'
                    Value = 1
                    Description = 'Disable advertising ID'
                    RequiresAdmin = $true
                }
            }
            
            # PowerShell settings
            PowerShell = @{
                # Enable PowerShell script execution
                ExecutionPolicy = @{
                    Enabled = $true
                    Scope = 'CurrentUser'  # CurrentUser, LocalMachine
                    Value = 'RemoteSigned'
                    Description = 'Set PowerShell execution policy'
                }
            }
        }
        
        # ===================================================================
        # WINDOWS FEATURES
        # ===================================================================
        Features = @{
            AutoApply = $true
            
            # Core Windows Features
            Core = @{
                # Windows Subsystem for Linux
                'Microsoft-Windows-Subsystem-Linux' = @{
                    Enabled = $true
                    RequiresRestart = $true
                    Description = 'Windows Subsystem for Linux (WSL)'
                }
                
                # Virtual Machine Platform (required for WSL2)
                'VirtualMachinePlatform' = @{
                    Enabled = $true
                    RequiresRestart = $true
                    Description = 'Virtual Machine Platform (required for WSL2 and Hyper-V)'
                }
                
                # Hyper-V (Windows 10/11 Pro+)
                'Microsoft-Hyper-V-All' = @{
                    Enabled = $false  # Opt-in (requires Pro+)
                    RequiresRestart = $true
                    Description = 'Hyper-V virtualization platform'
                    RequiresEdition = @('Pro', 'Enterprise', 'Education')
                }
                
                # Containers
                'Containers' = @{
                    Enabled = $false  # Opt-in
                    RequiresRestart = $true
                    Description = 'Windows container support'
                }
            }
            
            # Development features
            Development = @{
                # Windows Sandbox
                'Containers-DisposableClientVM' = @{
                    Enabled = $false  # Opt-in
                    RequiresRestart = $false
                    Description = 'Windows Sandbox for testing'
                    RequiresEdition = @('Pro', 'Enterprise', 'Education')
                }
                
                # .NET Framework 3.5
                'NetFx3' = @{
                    Enabled = $false  # Only if needed for legacy apps
                    RequiresRestart = $false
                    Description = '.NET Framework 3.5 (includes .NET 2.0 and 3.0)'
                }
            }
            
            # Network features
            Network = @{
                # Telnet Client (for debugging)
                'TelnetClient' = @{
                    Enabled = $false  # Opt-in for security
                    RequiresRestart = $false
                    Description = 'Telnet client for network debugging'
                }
                
                # OpenSSH Client
                'OpenSSH.Client' = @{
                    Enabled = $true
                    RequiresRestart = $false
                    Description = 'OpenSSH client for remote connections'
                    Type = 'Capability'  # Windows capability, not DISM feature
                }
                
                # OpenSSH Server
                'OpenSSH.Server' = @{
                    Enabled = $false  # Opt-in for security
                    RequiresRestart = $false
                    Description = 'OpenSSH server for remote access'
                    Type = 'Capability'
                }
            }
        }
        
        # ===================================================================
        # SYSTEM SERVICES
        # ===================================================================
        Services = @{
            AutoApply = $false  # Manual control for safety
            
            # Services to disable (performance/privacy)
            Disable = @(
                # Diagnostics and telemetry
                @{
                    Name = 'DiagTrack'
                    DisplayName = 'Connected User Experiences and Telemetry'
                    Description = 'Disable telemetry service'
                    Enabled = $false  # Opt-in to disable
                }
                @{
                    Name = 'dmwappushservice'
                    DisplayName = 'Device Management Wireless Application Protocol'
                    Description = 'Disable WAP Push service'
                    Enabled = $false
                }
            )
            
            # Services to enable
            Enable = @(
                @{
                    Name = 'WinRM'
                    DisplayName = 'Windows Remote Management'
                    Description = 'Enable WinRM for remote management'
                    Enabled = $false  # Opt-in for security
                    StartupType = 'Automatic'
                }
                @{
                    Name = 'sshd'
                    DisplayName = 'OpenSSH SSH Server'
                    Description = 'Enable SSH server'
                    Enabled = $false  # Opt-in
                    StartupType = 'Automatic'
                }
            )
        }
        
        # ===================================================================
        # SCHEDULED TASKS
        # ===================================================================
        ScheduledTasks = @{
            AutoApply = $false
            
            # Tasks to disable
            Disable = @(
                # Telemetry and diagnostics
                '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser'
                '\Microsoft\Windows\Application Experience\ProgramDataUpdater'
                '\Microsoft\Windows\Autochk\Proxy'
                '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator'
                '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip'
                '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector'
            )
        }
        
        # ===================================================================
        # ENVIRONMENT VARIABLES
        # ===================================================================
        EnvironmentVariables = @{
            # System variables (requires admin)
            System = @{
                # Development paths
                # 'JAVA_HOME' = 'C:\Program Files\Java\jdk-17'
                # 'ANDROID_HOME' = 'C:\Android\sdk'
            }
            
            # User variables
            User = @{
                # AitherZero configuration
                'AITHERZERO_PROFILE' = 'Developer'
                'AITHERZERO_PLATFORM' = 'Windows'
                # Editor preference
                'EDITOR' = 'code'
                'GIT_EDITOR' = 'code --wait'
            }
        }
        
        # ===================================================================
        # PATH CONFIGURATION
        # ===================================================================
        Path = @{
            System = @(
                # Add system-wide paths here (requires admin)
                # 'C:\Tools\bin'
            )
            
            User = @(
                # Add user-specific paths here
                # '%LOCALAPPDATA%\Programs\Python\Python312'
                # '%USERPROFILE%\.local\bin'
            )
        }
        
        # ===================================================================
        # FIREWALL RULES
        # ===================================================================
        Firewall = @{
            AutoApply = $false  # Manual control for security
            
            Rules = @(
                @{
                    Name = 'SSH-In-TCP'
                    DisplayName = 'OpenSSH Server (TCP-In)'
                    Enabled = $false
                    Direction = 'Inbound'
                    Protocol = 'TCP'
                    LocalPort = 22
                    Action = 'Allow'
                    Description = 'Allow SSH connections'
                }
                @{
                    Name = 'WinRM-HTTP-In-TCP'
                    DisplayName = 'Windows Remote Management (HTTP-In)'
                    Enabled = $false
                    Direction = 'Inbound'
                    Protocol = 'TCP'
                    LocalPort = 5985
                    Action = 'Allow'
                    Description = 'Allow WinRM HTTP'
                }
                @{
                    Name = 'WinRM-HTTPS-In-TCP'
                    DisplayName = 'Windows Remote Management (HTTPS-In)'
                    Enabled = $false
                    Direction = 'Inbound'
                    Protocol = 'TCP'
                    LocalPort = 5986
                    Action = 'Allow'
                    Description = 'Allow WinRM HTTPS'
                }
            )
        }
        
        # ===================================================================
        # POWER SETTINGS
        # ===================================================================
        Power = @{
            AutoApply = $false
            
            # Active power plan
            ActivePlan = 'High Performance'  # Balanced, High Performance, Power Saver
            
            # Custom power plan settings
            Settings = @{
                # Sleep settings
                'monitor-timeout-ac' = 0     # Never turn off monitor when plugged in
                'disk-timeout-ac' = 0        # Never turn off disk when plugged in
                'standby-timeout-ac' = 0     # Never sleep when plugged in
                'hibernate-timeout-ac' = 0   # Never hibernate when plugged in
            }
        }
        
        # ===================================================================
        # NETWORK CONFIGURATION
        # ===================================================================
        Network = @{
            AutoApply = $false
            
            # DNS configuration
            DNS = @{
                Primary = '8.8.8.8'
                Secondary = '1.1.1.1'
                ApplyToAllAdapters = $false
            }
            
            # Network profile
            NetworkCategory = 'Private'  # Public, Private, Domain
            
            # Network discovery
            NetworkDiscovery = $true
            FileAndPrinterSharing = $false
        }
        
        # ===================================================================
        # DEPLOYMENT ARTIFACT GENERATION
        # ===================================================================
        DeploymentArtifacts = @{
            # Unattend.xml generation settings
            Unattend = @{
                Generate = $false  # Enable to generate Unattend.xml
                OutputPath = './artifacts/windows'
                
                # Windows Setup settings
                ImageInstall = @{
                    OSImage = @{
                        InstallFrom = @{
                            MetaData = @{
                                Key = '/IMAGE/INDEX'
                                Value = '1'
                            }
                        }
                    }
                }
                
                # User accounts
                UserAccounts = @{
                    AdministratorPassword = $null  # Set in config.local.psd1
                    LocalAccounts = @(
                        @{
                            Name = 'DevUser'
                            Group = 'Administrators'
                            Password = $null  # Set in config.local.psd1
                        }
                    )
                }
                
                # Computer settings
                ComputerName = 'WIN-DEV'
                TimeZone = 'Eastern Standard Time'
                
                # Automation
                AutoLogon = @{
                    Enabled = $false
                    Username = 'DevUser'
                    Password = $null
                    LogonCount = 1
                }
            }
            
            # Registry export (.reg file)
            RegistryExport = @{
                Generate = $true
                OutputPath = './artifacts/windows'
                FileName = 'aitherzero-registry.reg'
            }
            
            # PowerShell DSC configuration
            DSC = @{
                Generate = $false
                OutputPath = './artifacts/windows'
                ConfigurationName = 'AitherZeroDSC'
            }
            
            # Docker Windows container
            Dockerfile = @{
                Generate = $true
                OutputPath = './artifacts/docker'
                FileName = 'Dockerfile.windows'
                BaseImage = 'mcr.microsoft.com/powershell:lts-nanoserver-1809'  # Windows PowerShell container
            }
        }
    }
}
