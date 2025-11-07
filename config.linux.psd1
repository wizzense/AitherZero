#Requires -Version 7.0

<#
.SYNOPSIS
    Linux-specific configuration for AitherZero
.DESCRIPTION
    Comprehensive Linux operating system configuration including:
    - System settings and kernel parameters
    - Package management
    - Service configuration
    - Security and firewall settings
    - Development environment
    - Network configuration
    
    This file is loaded AFTER config.psd1 and BEFORE config.local.psd1
    Settings here override base config.psd1 but are overridden by config.local.psd1
    
    Can be used to generate Linux deployment artifacts:
    - Cloud-init configurations
    - Kickstart files (RHEL/CentOS)
    - Preseed files (Debian/Ubuntu)
    - Ansible playbooks
    - Docker images
.NOTES
    Platform: Ubuntu, Debian, RHEL, CentOS, Fedora
    Requires: PowerShell 7.0+
    Version: 1.0.0
#>

@{
    # ===================================================================
    # LINUX OPERATING SYSTEM CONFIGURATION
    # ===================================================================
    Linux = @{
        # Operating system metadata
        Metadata = @{
            TargetDistributions = @('Ubuntu 20.04+', 'Debian 11+', 'RHEL 8+', 'CentOS 8+', 'Fedora 35+')
            ConfigVersion = '1.0.0'
            LastUpdated = '2025-11-07'
        }
        
        # ===================================================================
        # SYSTEM SETTINGS
        # ===================================================================
        System = @{
            # Hostname configuration
            Hostname = @{
                Name = 'linux-dev'
                UpdateHosts = $true
                FQDN = 'linux-dev.local'
            }
            
            # Timezone
            Timezone = 'America/New_York'
            
            # Locale
            Locale = @{
                Language = 'en_US.UTF-8'
                Generate = @('en_US.UTF-8', 'en_US')
            }
            
            # Keyboard layout
            Keyboard = @{
                Layout = 'us'
                Variant = ''
            }
        }
        
        # ===================================================================
        # KERNEL PARAMETERS (sysctl)
        # ===================================================================
        KernelParameters = @{
            AutoApply = $true
            BackupBeforeChanges = $true
            ConfigFile = '/etc/sysctl.d/99-aitherzero.conf'
            
            Parameters = @{
                # Network performance
                'net.core.rmem_max' = 134217728                    # 128MB receive buffer
                'net.core.wmem_max' = 134217728                    # 128MB send buffer
                'net.ipv4.tcp_rmem' = '4096 87380 67108864'       # TCP receive buffer
                'net.ipv4.tcp_wmem' = '4096 65536 67108864'       # TCP send buffer
                'net.core.netdev_max_backlog' = 5000              # Network device backlog
                'net.ipv4.tcp_congestion_control' = 'bbr'         # BBR congestion control
                
                # File system
                'fs.file-max' = 2097152                           # Maximum file descriptors
                'fs.inotify.max_user_watches' = 524288            # inotify watches (for IDEs)
                'fs.inotify.max_user_instances' = 512             # inotify instances
                
                # Virtual memory
                'vm.swappiness' = 10                              # Reduce swap usage
                'vm.dirty_ratio' = 10                             # Dirty page cache ratio
                'vm.dirty_background_ratio' = 5                   # Background dirty ratio
                'vm.vfs_cache_pressure' = 50                      # Cache pressure
                
                # Security
                'kernel.dmesg_restrict' = 1                       # Restrict dmesg to root
                'kernel.kptr_restrict' = 2                        # Hide kernel pointers
                'net.ipv4.conf.all.rp_filter' = 1                # Enable reverse path filtering
                'net.ipv4.conf.default.rp_filter' = 1
                'net.ipv4.icmp_echo_ignore_broadcasts' = 1       # Ignore ICMP broadcasts
                'net.ipv4.conf.all.accept_source_route' = 0      # Disable source routing
                'net.ipv4.conf.default.accept_source_route' = 0
                'net.ipv4.conf.all.send_redirects' = 0           # Disable ICMP redirects
                'net.ipv4.conf.default.send_redirects' = 0
                'net.ipv4.tcp_syncookies' = 1                    # Enable SYN cookies
            }
        }
        
        # ===================================================================
        # PACKAGE MANAGEMENT
        # ===================================================================
        Packages = @{
            AutoInstall = $false  # Manual control
            AutoUpdate = $false   # Manual control
            
            # Essential packages
            Essential = @(
                'build-essential'   # Compilation tools (Debian/Ubuntu)
                'git'
                'curl'
                'wget'
                'vim'
                'htop'
                'tmux'
                'tree'
                'jq'
                'net-tools'
                'dnsutils'
            )
            
            # Development tools
            Development = @(
                'gcc'
                'g++'
                'make'
                'cmake'
                'gdb'
                'valgrind'
                'strace'
                'lsof'
                'iotop'
            )
            
            # Docker and containers
            Containers = @(
                'docker.io'         # Docker (Ubuntu/Debian)
                'docker-compose'
                'containerd'
            )
            
            # Security tools
            Security = @(
                'ufw'              # Uncomplicated Firewall
                'fail2ban'         # Intrusion prevention
                'rkhunter'         # Rootkit hunter
                'aide'             # File integrity checker
            )
            
            # Monitoring
            Monitoring = @(
                'prometheus-node-exporter'
                'netdata'
                'sysstat'
            )
            
            # Package repositories to add
            Repositories = @(
                # Example: Docker official repo
                @{
                    Name = 'docker'
                    Enabled = $false
                    Type = 'deb'  # deb or rpm
                    URL = 'https://download.docker.com/linux/ubuntu'
                    Distribution = '$RELEASE'
                    Components = 'stable'
                    GPGKey = 'https://download.docker.com/linux/ubuntu/gpg'
                }
            )
        }
        
        # ===================================================================
        # SERVICES (systemd)
        # ===================================================================
        Services = @{
            AutoApply = $false  # Manual control for safety
            
            # Services to enable
            Enable = @(
                @{
                    Name = 'ssh'
                    Enabled = $true
                    StartOnBoot = $true
                    State = 'running'
                }
                @{
                    Name = 'ufw'
                    Enabled = $false  # Opt-in
                    StartOnBoot = $true
                    State = 'running'
                }
            )
            
            # Services to disable
            Disable = @(
                @{
                    Name = 'bluetooth'
                    Enabled = $false  # Opt-in to disable
                    Reason = 'Not needed on server'
                }
            )
        }
        
        # ===================================================================
        # FIREWALL (UFW)
        # ===================================================================
        Firewall = @{
            AutoApply = $false  # Manual control for security
            Enabled = $true
            DefaultPolicy = @{
                Incoming = 'deny'
                Outgoing = 'allow'
                Routed = 'deny'
            }
            
            Rules = @(
                @{
                    Name = 'SSH'
                    Port = 22
                    Protocol = 'tcp'
                    Action = 'allow'
                    From = 'any'
                    Description = 'Allow SSH'
                }
                @{
                    Name = 'HTTP'
                    Port = 80
                    Protocol = 'tcp'
                    Action = 'allow'
                    From = 'any'
                    Description = 'Allow HTTP'
                    Enabled = $false
                }
                @{
                    Name = 'HTTPS'
                    Port = 443
                    Protocol = 'tcp'
                    Action = 'allow'
                    From = 'any'
                    Description = 'Allow HTTPS'
                    Enabled = $false
                }
            )
        }
        
        # ===================================================================
        # USERS AND GROUPS
        # ===================================================================
        Users = @{
            AutoApply = $false
            
            Create = @(
                @{
                    Username = 'devuser'
                    FullName = 'Development User'
                    Groups = @('sudo', 'docker')
                    Shell = '/bin/bash'
                    CreateHome = $true
                    Password = $null  # Set in config.local.psd1 or prompt
                    SSHKeys = @()     # Add SSH public keys
                }
            )
        }
        
        # ===================================================================
        # ENVIRONMENT VARIABLES
        # ===================================================================
        EnvironmentVariables = @{
            # System-wide variables (/etc/environment)
            System = @{
                'EDITOR' = 'vim'
                'VISUAL' = 'vim'
                'PAGER' = 'less'
            }
            
            # Profile variables (/etc/profile.d/aitherzero.sh)
            Profile = @{
                'AITHERZERO_PROFILE' = 'Developer'
                'AITHERZERO_PLATFORM' = 'Linux'
            }
        }
        
        # ===================================================================
        # PATH CONFIGURATION
        # ===================================================================
        Path = @{
            # Paths to add to system PATH
            System = @(
                '/usr/local/bin'
                '/opt/bin'
            )
            
            # Paths to add to user PATH
            User = @(
                '$HOME/.local/bin'
                '$HOME/bin'
            )
        }
        
        # ===================================================================
        # SSH CONFIGURATION
        # ===================================================================
        SSH = @{
            AutoApply = $false
            ConfigFile = '/etc/ssh/sshd_config'
            BackupBefore = $true
            
            Settings = @{
                # Security
                'PermitRootLogin' = 'no'
                'PasswordAuthentication' = 'yes'
                'PubkeyAuthentication' = 'yes'
                'PermitEmptyPasswords' = 'no'
                'X11Forwarding' = 'no'
                'MaxAuthTries' = '3'
                'MaxSessions' = '10'
                
                # Performance
                'UseDNS' = 'no'
                'GSSAPIAuthentication' = 'no'
                
                # Limits
                'ClientAliveInterval' = '300'
                'ClientAliveCountMax' = '2'
            }
        }
        
        # ===================================================================
        # DOCKER CONFIGURATION
        # ===================================================================
        Docker = @{
            AutoApply = $false
            
            # Daemon configuration (/etc/docker/daemon.json)
            DaemonConfig = @{
                'log-driver' = 'json-file'
                'log-opts' = @{
                    'max-size' = '10m'
                    'max-file' = '3'
                }
                'storage-driver' = 'overlay2'
                'userland-proxy' = $false
                'experimental' = $false
                'metrics-addr' = '127.0.0.1:9323'
                'live-restore' = $true
            }
            
            # Users to add to docker group
            DockerGroupUsers = @('devuser')
        }
        
        # ===================================================================
        # CRON JOBS
        # ===================================================================
        CronJobs = @{
            AutoApply = $false
            
            Jobs = @(
                @{
                    Name = 'Update Package List'
                    Enabled = $false
                    Schedule = '0 2 * * *'  # Daily at 2 AM
                    User = 'root'
                    Command = 'apt-get update -qq'
                }
                @{
                    Name = 'Clean Old Logs'
                    Enabled = $false
                    Schedule = '0 3 * * 0'  # Weekly on Sunday at 3 AM
                    User = 'root'
                    Command = 'find /var/log -name "*.log" -mtime +30 -delete'
                }
            )
        }
        
        # ===================================================================
        # SECURITY SETTINGS
        # ===================================================================
        Security = @{
            # SELinux (RHEL/CentOS/Fedora)
            SELinux = @{
                Enabled = $false  # Not applicable on Ubuntu/Debian
                Mode = 'enforcing'  # enforcing, permissive, disabled
            }
            
            # AppArmor (Ubuntu/Debian)
            AppArmor = @{
                Enabled = $true
                Mode = 'enforce'  # enforce, complain
            }
            
            # Fail2Ban configuration
            Fail2Ban = @{
                Enabled = $false
                Jails = @{
                    'sshd' = @{
                        Enabled = $true
                        MaxRetry = 3
                        BanTime = 3600
                        FindTime = 600
                    }
                }
            }
            
            # Automatic security updates
            AutomaticUpdates = @{
                Enabled = $false  # Opt-in
                ApplySecurityUpdates = $true
                ApplyAllUpdates = $false
                EmailOnError = $null
            }
        }
        
        # ===================================================================
        # LIMITS (ulimit)
        # ===================================================================
        Limits = @{
            AutoApply = $false
            ConfigFile = '/etc/security/limits.d/99-aitherzero.conf'
            
            Settings = @(
                @{
                    Domain = '*'
                    Type = 'soft'
                    Item = 'nofile'
                    Value = 65536
                    Description = 'Soft limit for open files'
                }
                @{
                    Domain = '*'
                    Type = 'hard'
                    Item = 'nofile'
                    Value = 65536
                    Description = 'Hard limit for open files'
                }
                @{
                    Domain = '*'
                    Type = 'soft'
                    Item = 'nproc'
                    Value = 4096
                    Description = 'Soft limit for processes'
                }
            )
        }
        
        # ===================================================================
        # DEPLOYMENT ARTIFACT GENERATION
        # ===================================================================
        DeploymentArtifacts = @{
            # Cloud-init configuration
            CloudInit = @{
                Generate = $false
                OutputPath = './artifacts/linux'
                Format = 'yaml'  # yaml or json
                
                # Cloud-init modules to include
                Modules = @(
                    'package-update-upgrade-install'
                    'users-groups'
                    'write-files'
                    'runcmd'
                    'ssh'
                )
            }
            
            # Kickstart file (RHEL/CentOS)
            Kickstart = @{
                Generate = $false
                OutputPath = './artifacts/linux'
                FileName = 'aitherzero-kickstart.cfg'
                
                # Installation method
                InstallMethod = 'cdrom'  # cdrom, url, nfs
                
                # Partitioning
                Partitioning = 'auto'  # auto, custom
            }
            
            # Preseed file (Debian/Ubuntu)
            Preseed = @{
                Generate = $false
                OutputPath = './artifacts/linux'
                FileName = 'aitherzero-preseed.cfg'
                
                # Installation settings
                MirrorCountry = 'US'
                MirrorHostname = 'archive.ubuntu.com'
            }
            
            # Ansible playbook
            Ansible = @{
                Generate = $false
                OutputPath = './artifacts/linux'
                PlaybookName = 'aitherzero-setup.yml'
            }
            
            # Shell script
            ShellScript = @{
                Generate = $true
                OutputPath = './artifacts/linux'
                FileName = 'aitherzero-setup.sh'
                Shebang = '#!/bin/bash'
            }
            
            # Dockerfile
            Dockerfile = @{
                Generate = $false
                OutputPath = './artifacts/linux'
                FileName = 'Dockerfile.aitherzero'
                BaseImage = 'ubuntu:22.04'
            }
        }
    }
}
