# Aitherium Organization Setup Playbook
# Complete zero-to-deployment setup for an AitherZero organization owner
#
# This playbook orchestrates the full setup process including:
# - Environment and development tools
# - Certificate Authority and PKI infrastructure
# - License generation and management system
# - Secure credential management
# - GitHub integration for license distribution
#
# Usage:
#   Start-AitherZero -Mode Orchestrate -Playbook aitherium-org-setup
#   OR
#   Invoke-OrchestrationSequence -PlaybookPath "./orchestration/playbooks/aitherium-org-setup.psd1"

@{
    # Playbook metadata
    Name = 'aitherium-org-setup'
    Description = 'Complete setup for AitherZero organization owner (Aitherium)'
    Version = '1.0.0'
    Author = 'AitherZero Team'
    Tags = @('Setup', 'Organization', 'Infrastructure', 'Licensing', 'CA', 'PKI')
    
    # Playbook configuration
    Configuration = @{
        # Organization name
        OrganizationName = 'aitherium'
        
        # Whether to continue on non-critical errors
        ContinueOnError = $false
        
        # Parallel execution where possible
        MaxParallelJobs = 4
        
        # Timeout for entire playbook (minutes)
        TimeoutMinutes = 60
    }
    
    # Variables available to all scripts
    Variables = @{
        OrgName = 'aitherium'
        GitHubOwner = 'aitherium'
        LicenseRepo = 'licenses'
        SetupMode = 'Full'
        InstallProfile = 'Developer'  # Minimal, Standard, Developer, Full
    }
    
    # Modern Sequence format for execution
    Sequence = @(
        # Phase 1: Environment Setup
        @{
            Script = '0000'
            Description = 'Bootstrap PowerShell 7 and basic environment'
            ContinueOnError = $false
            Timeout = 300
        }
        
        # Phase 2: Development Tools
        @{
            Script = '0207'
            Description = 'Install Git'
            ContinueOnError = $false
            Timeout = 300
        }
        @{
            Script = '0201'
            Description = 'Install Node.js'
            ContinueOnError = $true
            Timeout = 300
        }
        @{
            Script = '0210'
            Description = 'Install VS Code'
            ContinueOnError = $true
            Timeout = 300
        }
        
        # Phase 3: Infrastructure Setup
        @{
            Script = '0100'
            Description = 'Configure system environment'
            Parameters = @{}
            ContinueOnError = $false
            Condition = { $IsWindows }
            Timeout = 300
        }
        @{
            Script = '0104'
            Description = 'Install and configure Certificate Authority for PKI'
            Parameters = @{
                CAName = "Aitherium Root CA"
                ValidityYears = 10
            }
            ContinueOnError = $false
            Condition = { $IsWindows }
            Timeout = 600
        }
        
        # Phase 4: License Infrastructure
        @{
            Script = '0803'
            Description = 'Set up license generation and management system'
            Parameters = @{
                OrganizationName = '$Variables:OrgName'
                GitHubOwner = '$Variables:GitHubOwner'
                GitHubRepo = '$Variables:LicenseRepo'
                SetupCA = $true
                GenerateMasterKeys = $true
            }
            ContinueOnError = $false
            Timeout = 300
        }
    )
    
    # Post-execution hooks
    OnComplete = @{
        Success = @{
            Message = 'Aitherium organization setup completed successfully!'
            LogPath = '~/.aitherzero/logs/org-setup-$(Get-Date -Format "yyyyMMdd-HHmmss").log'
        }
        Failure = @{
            Message = 'Organization setup failed - check logs for details'
            LogPath = '~/.aitherzero/logs/org-setup-$(Get-Date -Format "yyyyMMdd-HHmmss")-FAILED.log'
        }
    }
}
