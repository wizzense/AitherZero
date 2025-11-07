# Deployment Environment Setup Playbook
# Minimal deployment-only environment (no dev tools)
# Optimized for production/staging servers

@{
    Name = 'deployment-environment'
    Description = 'Deployment-only environment with infrastructure tools (no development tools)'
    Version = '1.0.0'
    Author = 'AitherZero Team'
    
    # Configuration
    Configuration = @{
        Profile = 'Deployment'
        NonInteractive = $true  # Always non-interactive for deployment
        ContinueOnError = $false
        Parallel = $false
        OptimizeForDeployment = $true
    }
    
    # Environment detection
    Environment = @{
        DetectCI = $true
        RequireAdmin = $true  # Deployment tools may need elevated permissions
        ValidatePrerequisites = $true
    }
    
    # Script execution sequence
    Sequence = @(
        # Phase 1: System Configuration
        @{
            Name = 'System Setup'
            Scripts = @('0001', '0002')  # Environment config, directories
            Description = 'Configure system environment'
            Required = $true
            Timeout = 300
        }
        
        # Phase 2: Version Control (minimal)
        @{
            Name = 'Version Control'
            Scripts = @('0207')  # Git only
            Description = 'Install Git for deployment pulls'
            Required = $true
            Timeout = 300
        }
        
        # Phase 3: Container Runtime
        @{
            Name = 'Container Runtime'
            Scripts = @('0208')  # Docker
            Description = 'Install Docker for containerized deployments'
            Required = $true
            Timeout = 900
        }
        
        # Phase 4: Infrastructure as Code
        @{
            Name = 'Infrastructure Tools'
            Scripts = @('0008', '0009')  # OpenTofu, Initialize
            Description = 'Install and configure OpenTofu'
            Required = $true
            Timeout = 600
        }
        
        # Phase 5: Orchestration Setup
        @{
            Name = 'Orchestration'
            Scripts = @()  # AitherZero orchestration already available
            Description = 'Validate orchestration engine'
            Required = $true
            Timeout = 60
        }
    )
    
    # Skip these categories entirely
    SkipCategories = @(
        'Development',
        'Testing',
        'AI',
        'IDEs'
    )
    
    # Post-execution actions
    PostExecution = @{
        GenerateReport = $true
        ValidateDeploymentReadiness = $true
        TestConnectivity = $true
    }
    
    # GitHub Actions configuration (for deployment pipelines)
    GitHubActions = @{
        RunsOn = 'ubuntu-latest'
        Timeout = 20
        Environment = @{
            AITHERZERO_PROFILE = 'Deployment'
            AITHERZERO_NONINTERACTIVE = 'true'
        }
        Secrets = @('DEPLOY_KEY', 'REGISTRY_TOKEN')
    }
}
