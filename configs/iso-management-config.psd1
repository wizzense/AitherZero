# ISO Management Configuration for AitherZero Lab Infrastructure

@{
    # =========================================
    # ISO Repository Configuration
    # =========================================    Repository = @{
        Name = "AitherZero-Lab-ISOs"
        Description = "Enterprise lab infrastructure ISO repository"
        Path = "${env:TEMP}/AitherZero-ISOs"
        AutoCreate = $true
        Structure = @{
            Windows = "Windows"
            Linux = "Linux"
            Custom = "Custom"
            Metadata = "Metadata"
            Logs = "Logs"
            Temp = "Temp"
        }
    }

    # =========================================
    # ISO Download Configurations
    # =========================================
    ISODownloads = @{
        # Windows Server ISOs
        WindowsServer2025 = @{
            ISOName = "Server2025"
            Version = "latest"
            ISOType = "Windows"
            Architecture = "x64"
            Language = "en-US"
            VerifyIntegrity = $true
            Priority = "High"
        }

        WindowsServer2022 = @{
            ISOName = "Server2022"
            Version = "latest"
            ISOType = "Windows"
            Architecture = "x64"
            Language = "en-US"
            VerifyIntegrity = $true
            Priority = "Medium"
        }

        # Windows Client ISOs
        Windows11 = @{
            ISOName = "Windows11"
            Version = "latest"
            ISOType = "Windows"
            Architecture = "x64"
            Language = "en-US"
            VerifyIntegrity = $true
            Priority = "Medium"
        }

        # Linux Distribution ISOs
        Ubuntu2204 = @{
            ISOName = "UbuntuServer"
            Version = "22.04"
            ISOType = "Linux"
            Architecture = "x64"
            VerifyIntegrity = $true
            Priority = "Medium"
        }

        # Custom ISOs (for existing lab infrastructure)
        CustomLabISO = @{
            ISOName = "LabInfrastructure"
            ISOType = "Custom"
            CustomURL = "https://lab.internal/isos/custom-lab-v1.0.iso"
            VerifyIntegrity = $false
            Priority = "Low"
        }
    }

    # =========================================
    # ISO Customization Configurations
    # =========================================
    ISOCustomizations = @{
        # Windows Server 2025 Lab Configuration
        WindowsServer2025Lab = @{
            OSType = "Server2025"
            Edition = "Datacenter"
            ComputerName = "LAB-SRV-{0:D2}"  # Will be formatted with VM number
            AdminPassword = "LabAdmin123!"
            ProductKey = ""  # Use evaluation or provide your key
            TimeZone = "UTC"
            EnableRDP = $true
            AutoLogon = $true
            AutoLogonCount = 3
            DisableFirewall = $true
            DisableUAC = $true
            JoinDomain = $false
            FirstLogonCommands = @(
                @{
                    CommandLine = "powershell.exe -ExecutionPolicy Bypass -File C:\Windows\bootstrap.ps1"
                    Description = "Execute lab bootstrap script"
                    Order = 1
                },
                @{
                    CommandLine = "powershell.exe -Command 'Set-NetConnectionProfile -NetworkCategory Private'"
                    Description = "Set network profile to private"
                    Order = 2
                },
                @{
                    CommandLine = "powershell.exe -Command 'Enable-PSRemoting -Force'"
                    Description = "Enable PowerShell remoting"
                    Order = 3
                }
            )
        }

        # Windows Server Core Configuration
        WindowsServerCore = @{
            OSType = "Server2025"
            Edition = "Core"
            ComputerName = "LAB-CORE-{0:D2}"
            AdminPassword = "LabAdmin123!"
            TimeZone = "UTC"
            EnableRDP = $true
            AutoLogon = $false
            DisableFirewall = $true
            FirstLogonCommands = @(
                @{
                    CommandLine = "powershell.exe -ExecutionPolicy Bypass -File C:\Windows\bootstrap.ps1"
                    Description = "Execute core lab bootstrap script"
                    Order = 1
                }
            )
        }

        # Ubuntu Server Configuration (using cloud-init style)
        UbuntuServerLab = @{
            OSType = "Ubuntu"
            Edition = "Server"
            Hostname = "lab-ubuntu-{0:D2}"
            Username = "labadmin"
            Password = "LabAdmin123!"
            PackageUpdates = $true
            InstallPackages = @("openssh-server", "curl", "wget", "git", "docker.io")
            EnableSSH = $true
            AllowPasswordAuth = $true
        }
    }    # =========================================
    # Integration with AitherCore Modules
    # =========================================
    AitherCoreIntegration = @{
        # Use ISOManager module instead of standalone scripts
        UseModules = $true

        # Bootstrap script integration
        BootstrapScript = @{
            Source = "bootstrap.ps1"  # Your existing bootstrap script
            TargetPath = "C:\Windows\bootstrap.ps1"
            Execute = $true
        }

        # Autounattend templates (keep these as they're used by ISOManager)
        AutounattendTemplates = @{
            Generic = "tools/iso/autounattend - generic.xml"
            Headless = "tools/iso/headlessunattend.xml"
        }

        # Windows ADK Integration (used by ISOManager module)
        WindowsADK = @{
            Required = $true
            InstallPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit"
            OSCDImgPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
            AutoInstall = $true
        }
    }

    # =========================================
    # Lab Environment Specific Settings
    # =========================================
    LabEnvironment = @{
        # Default VM configurations for customized ISOs
        DefaultVMConfig = @{
            Memory = "2GB"
            Processors = 2
            HardDiskSize = "60GB"
            Generation = 2
            SecureBoot = $false
        }

        # Network configuration for lab VMs
        NetworkConfig = @{
            SwitchName = "Lab-Internal-Switch"
            IPRange = "192.168.100.0/24"
            Gateway = "192.168.100.1"
            DNSServers = @("192.168.100.1", "8.8.8.8")
        }

        # Domain configuration
        DomainConfig = @{
            DomainName = "lab.local"
            DomainController = "192.168.100.10"
            JoinDomain = $false  # Set to $true to auto-join domain
            DomainAdmin = "lab\administrator"
        }
    }

    # =========================================
    # Integration with AitherCore
    # =========================================
    AitherCoreIntegration = @{
        # Use with LabRunner module
        LabRunnerIntegration = $true

        # Parallel execution for multiple ISO processing
        ParallelExecution = @{
            Enabled = $true
            MaxJobs = 3
            BatchSize = 2
        }        # Backup management for original ISOs
        BackupManagement = @{
            BackupOriginals = $true
            BackupPath = "${env:TEMP}/AitherZero/Backups/ISOs"
            RetentionDays = 30
        }

        # Logging configuration
        Logging = @{
            Level = "INFO"
            LogPath = "logs/iso-management.log"
            IncludeTimestamp = $true
            RotateDaily = $true
        }
    }

    # =========================================
    # Workflow Automation
    # =========================================
    Workflows = @{
        # Complete lab ISO preparation workflow
        LabISOPreparation = @{
            Enabled = $true
            Steps = @(
                "Download-RequiredISOs",
                "Verify-ISOIntegrity",
                "Create-CustomizedISOs",
                "Test-BootConfiguration",
                "Update-Repository"
            )
            ScheduleDaily = $false
            NotifyOnCompletion = $true
        }

        # Maintenance workflow
        MaintenanceWorkflow = @{
            Enabled = $true
            ScheduleWeekly = $true
            Steps = @(
                "Cleanup-TempFiles",
                "Verify-RepositoryIntegrity",
                "Update-ISOMetadata",
                "Generate-Reports"
            )
        }
    }

    # =========================================
    # Security and Compliance
    # =========================================
    Security = @{
        # Hash verification for downloads
        VerifyChecksums = $true

        # Encryption for sensitive data in autounattend
        EncryptPasswords = $false  # Set to $true for production

        # Audit logging
        AuditLog = @{
            Enabled = $true
            LogAllOperations = $true
            RetentionDays = 90
        }

        # Access control
        AccessControl = @{
            RequireElevation = $true
            RestrictedOperations = @("Download", "Customize", "Deploy")
        }
    }

    # =========================================
    # Reporting and Monitoring
    # =========================================
    Reporting = @{
        # Generate inventory reports
        InventoryReports = @{
            Enabled = $true
            Format = "JSON"  # JSON, CSV, XML
            Schedule = "Weekly"
            OutputPath = "reports/iso-inventory"
        }

        # Performance monitoring
        PerformanceMonitoring = @{
            TrackDownloadSpeeds = $true
            TrackCustomizationTimes = $true
            AlertOnFailures = $true
        }

        # Integration reporting
        IntegrationReports = @{
            TrackScriptUsage = $true
            MonitorExistingScriptIntegration = $true
            ReportCompatibilityIssues = $true
        }
    }
}
