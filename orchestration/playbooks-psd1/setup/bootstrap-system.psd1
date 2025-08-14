#Requires -Version 7.0
<#
.SYNOPSIS
    bootstrap-system - Bootstrap playbook used by bootstrap.ps1
.DESCRIPTION
    This playbook is executed by bootstrap.ps1 after downloading minimal AitherZero.
    It handles all the complex setup logic using the orchestration engine.
.NOTES
    Version: 1.0.0
    Author: AitherZero Platform Team
#>

@{
    # Metadata
    Name = 'bootstrap-system'
    Description = 'Bootstrap AitherZero installation using orchestration'
    Version = '1.0.0'
    Author = 'AitherZero Platform Team'
    Created = '2025-01-13T00:00:00Z'
    
    # Categorization
    Tags = @('bootstrap', 'setup', 'installation', 'core')
    Category = 'Setup'
    
    # Requirements
    Requirements = @{
        MinimumVersion = '7.0'
        EstimatedDuration = '5-15 minutes'
    }
    
    # Default Variables - can be overridden by bootstrap.ps1
    Variables = @{
        Profile = 'Standard'  # Core, Standard, Developer, Full
        InstallDependencies = $true
        ConfigureGit = $false
        InstallModules = $true
        RunTests = $false
    }
    
    # Execution Stages
    Stages = @(
        @{
            Name = 'Environment Check'
            Description = 'Verify system meets requirements'
            Sequence = @('0001')  # Environment check
            ContinueOnError = $false
            Variables = @{
                CheckPowerShell7 = $true
                CheckDiskSpace = $true
                MinDiskSpaceGB = 1
            }
        }
        @{
            Name = 'Clean Legacy Systems'
            Description = 'Remove conflicting modules and systems'
            Sequence = @('0000')  # Cleanup script
            ContinueOnError = $true
            Variables = @{
                SafeMode = $true
                PreserveUserData = $true
            }
        }
        @{
            Name = 'Install PowerShell 7'
            Description = 'Ensure PowerShell 7 is installed'
            Sequence = @('0010')  # PS7 installer
            ContinueOnError = $false
            Conditional = @{
                When = '$PSVersionTable.PSVersion.Major -lt 7'
            }
        }
        @{
            Name = 'Core Dependencies'
            Description = 'Install core dependencies based on profile'
            Sequence = @('0201')  # Git (always needed)
            ContinueOnError = $false
            Variables = @{
                ForceInstall = $false
            }
        }
        @{
            Name = 'Standard Dependencies'
            Description = 'Install standard profile dependencies'
            Sequence = @('0400')  # Testing tools
            ContinueOnError = $true
            Conditional = @{
                When = 'Variables.Profile -in @("Standard", "Developer", "Full")'
            }
        }
        @{
            Name = 'Developer Dependencies'
            Description = 'Install developer profile dependencies'
            Sequence = @('0207', '0208', '0209')  # Node, Python, VS Code
            ContinueOnError = $true
            Conditional = @{
                When = 'Variables.Profile -in @("Developer", "Full")'
            }
        }
        @{
            Name = 'Full Dependencies'
            Description = 'Install full profile dependencies'
            Sequence = @('0210', '0211', '0212')  # Docker, VS Build Tools, Azure CLI
            ContinueOnError = $true
            Conditional = @{
                When = 'Variables.Profile -eq "Full"'
            }
        }
        @{
            Name = 'Configure Environment'
            Description = 'Apply configuration and set up paths'
            Sequence = @('0050')  # Load configuration
            ContinueOnError = $false
            Variables = @{
                CreateLocalConfig = $true
                SetEnvironmentVars = $true
            }
        }
        @{
            Name = 'Validate Installation'
            Description = 'Verify everything is working'
            Sequence = @('0407', '0500')  # Syntax check, System info
            ContinueOnError = $true
        }
        @{
            Name = 'Run Initial Tests'
            Description = 'Run basic tests to verify installation'
            Sequence = @('0402')  # Unit tests
            ContinueOnError = $true
            Variables = @{
                NoCoverage = $true
                QuickTest = $true
            }
            Conditional = @{
                When = 'Variables.RunTests -eq $true'
            }
        }
    )
    
    # Profile-specific configurations
    Profiles = @{
        Core = @{
            Description = 'Minimal installation'
            Variables = @{
                InstallDependencies = $false
                RunTests = $false
            }
        }
        Standard = @{
            Description = 'Standard installation with testing'
            Variables = @{
                InstallDependencies = $true
                RunTests = $false
            }
        }
        Developer = @{
            Description = 'Developer installation with all tools'
            Variables = @{
                InstallDependencies = $true
                ConfigureGit = $true
                RunTests = $true
            }
        }
        Full = @{
            Description = 'Complete installation'
            Variables = @{
                InstallDependencies = $true
                ConfigureGit = $true
                RunTests = $true
                InstallOptional = $true
            }
        }
    }
    
    # Notifications
    Notifications = @{
        OnSuccess = @{
            Message = '✅ AitherZero bootstrapped successfully!'
            Level = 'Success'
            ShowNextSteps = $true
        }
        OnFailure = @{
            Message = '❌ Bootstrap failed - check logs for details'
            Level = 'Error'
        }
    }
    
    # Post Actions
    PostActions = @(
        @{
            Name = 'Show Summary'
            Description = 'Display installation summary'
            Type = 'Script'
            Script = {
                Write-Host "`n════════════════════════════════════════" -ForegroundColor Blue
                Write-Host " AitherZero Bootstrap Complete!" -ForegroundColor Green
                Write-Host "════════════════════════════════════════" -ForegroundColor Blue
                Write-Host "`nProfile: $($Variables.Profile)" -ForegroundColor Cyan
                Write-Host "Location: $(Get-Location)" -ForegroundColor Cyan
                Write-Host "`nTo start AitherZero, run:" -ForegroundColor White
                Write-Host "  ./Start-AitherZero.ps1" -ForegroundColor Yellow
                Write-Host "`nOr use the 'az' command wrapper:" -ForegroundColor White
                Write-Host "  az" -ForegroundColor Yellow
            }
        }
    )
}