#Requires -Version 7.0
<#
.SYNOPSIS
    dev-environment - Developer environment setup
.DESCRIPTION
    Sets up a complete development environment with all necessary tools,
    configurations, and dependencies for AitherZero development.
.NOTES
    Version: 2.0.0
    Author: AitherZero Platform Team
#>

@{
    # Metadata
    Name = 'dev-environment'
    Description = 'Complete developer environment setup'
    Version = '2.0.0'
    Author = 'AitherZero Platform Team'
    Created = '2025-01-13T00:00:00Z'
    
    # Categorization
    Tags = @('setup', 'development', 'environment', 'tools', 'configuration')
    Category = 'Setup'
    
    # Requirements
    Requirements = @{
        MinimumVersion = '7.0'
        EstimatedDuration = '15-30 minutes'
        DiskSpace = '5GB'
        AdminRequired = $false
    }
    
    # Default Variables
    Variables = @{
        Profile = 'Developer'
        InstallOptional = $true
        ConfigureGit = $true
        SetupVSCode = $true
        InstallModules = $true
    }
    
    # Execution Stages
    Stages = @(
        @{
            Name = 'Environment Check'
            Description = 'Verify system requirements and prerequisites'
            Sequence = @('0001')
            ContinueOnError = $false
            Variables = @{
                CheckPowerShell7 = $true
                CheckDiskSpace = $true
            }
        }
        @{
            Name = 'Core Tools'
            Description = 'Install essential development tools'
            Sequence = @('0201', '0207', '0208')  # Git, Node.js, Python
            ContinueOnError = $false
            Variables = @{
                GitConfig = $true
                NodeVersion = 'lts'
                PythonVersion = '3.11'
            }
        }
        @{
            Name = 'PowerShell Modules'
            Description = 'Install required PowerShell modules'
            Sequence = @('0400', '0443')  # Testing tools, powershell-yaml
            ContinueOnError = $false
            Variables = @{
                Scope = 'CurrentUser'
                Force = $true
            }
        }
        @{
            Name = 'VS Code Setup'
            Description = 'Install and configure Visual Studio Code'
            Sequence = @('0209')
            ContinueOnError = $true
            Variables = @{
                InstallExtensions = $true
                ConfigureSettings = $true
                Extensions = @(
                    'ms-vscode.powershell'
                    'redhat.vscode-yaml'
                    'esbenp.prettier-vscode'
                    'eamodio.gitlens'
                )
            }
        }
        @{
            Name = 'AI Tools'
            Description = 'Set up AI development tools'
            Sequence = @('0730', '0731')  # AI agents and code review
            ContinueOnError = $true
            Variables = @{
                SetupClaude = $true
                SetupCopilot = $false
            }
        }
        @{
            Name = 'Configuration'
            Description = 'Apply development configurations'
            Sequence = @('0050')  # Load configuration
            ContinueOnError = $false
            Variables = @{
                CreateLocalConfig = $true
                Profile = 'Developer'
            }
        }
        @{
            Name = 'Validation'
            Description = 'Validate environment setup'
            Sequence = @('0407', '0500')  # Syntax validation, system info
            ContinueOnError = $true
        }
    )
    
    # Profile Configurations
    Profiles = @{
        Minimal = @{
            Description = 'Minimal setup for basic development'
            Variables = @{
                InstallOptional = $false
                SetupVSCode = $false
            }
        }
        Standard = @{
            Description = 'Standard developer setup'
            Variables = @{
                InstallOptional = $true
                SetupVSCode = $true
            }
        }
        Full = @{
            Description = 'Complete setup with all tools'
            Variables = @{
                InstallOptional = $true
                SetupVSCode = $true
                InstallDocker = $true
                InstallAzureCLI = $true
            }
        }
    }
    
    # Notifications
    Notifications = @{
        OnSuccess = @{
            Message = '✅ Development environment setup complete!'
            Level = 'Success'
            ShowNextSteps = $true
        }
        OnFailure = @{
            Message = '❌ Environment setup failed - check logs for details'
            Level = 'Error'
        }
    }
    
    # Post Actions
    PostActions = @(
        @{
            Name = 'Show Environment Info'
            Description = 'Display environment configuration'
            Type = 'Script'
            Script = {
                Write-Host "`n=== Development Environment Ready ===" -ForegroundColor Green
                Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)"
                Write-Host "Git Version: $(git --version)"
                Write-Host "Node Version: $(node --version)"
                Write-Host "Python Version: $(python --version)"
                Write-Host "`nRun 'Start-AitherZero.ps1' to begin!" -ForegroundColor Cyan
            }
        }
    )
}