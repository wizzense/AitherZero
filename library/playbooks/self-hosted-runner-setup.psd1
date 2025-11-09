# Self-Hosted Runner Setup Playbook
# Configure GitHub Actions self-hosted runner environment
# Includes all tools needed for CI/CD pipelines

@{
    Name = 'self-hosted-runner-setup'
    Description = 'Setup GitHub Actions self-hosted runner with CI/CD tools'
    Version = '1.0.0'
    Author = 'AitherZero Team'
    
    # Configuration
    Configuration = @{
        Profile = 'Self-Hosted-Runner'
        NonInteractive = $true
        ContinueOnError = $false
        Parallel = $false
    }
    
    # Environment detection
    Environment = @{
        DetectCI = $false  # Not in CI when setting up runner
        RequireAdmin = $true  # Runner service needs admin
        ValidatePrerequisites = $true
    }
    
    # Script execution sequence
    Sequence = @(
        # Phase 1: System Configuration
        @{
            Name = 'System Setup'
            Scripts = @('0001', '0002')
            Description = 'Configure system environment'
            Required = $true
            Timeout = 300
        }
        
        # Phase 2: Core Tools
        @{
            Name = 'Core Development Tools'
            Scripts = @('0207', '0201')  # Git, Node
            Description = 'Install Git and Node.js for CI/CD'
            Required = $true
            Timeout = 600
        }
        
        # Phase 3: Container Runtime
        @{
            Name = 'Container Support'
            Scripts = @('0208')  # Docker
            Description = 'Install Docker for containerized builds'
            Required = $true
            Timeout = 900
        }
        
        # Phase 4: Testing Tools
        @{
            Name = 'Testing Frameworks'
            Scripts = @('0400', '0401')  # Testing tools
            Description = 'Install Pester and testing frameworks'
            Required = $true
            Timeout = 300
        }
        
        # Phase 5: Infrastructure Tools
        @{
            Name = 'Infrastructure Tools'
            Scripts = @('0008')  # OpenTofu
            Description = 'Install OpenTofu for infrastructure automation'
            Required = $false
            Timeout = 300
        }
        
        # Phase 6: Runner Installation
        @{
            Name = 'GitHub Runner'
            Scripts = @('0850')  # Install runner
            Description = 'Install and configure GitHub Actions runner'
            Required = $true
            Timeout = 600
            Parameters = @{
                InstallAsService = $true
            }
        }
    )
    
    # Runner-specific configuration
    RunnerConfiguration = @{
        AutoRegister = $true
        InstallAsService = $true
        StartOnBoot = $true
        RunnerGroup = 'Default'
        Labels = @('self-hosted', 'aitherzero', 'docker', 'opentofu')
    }
    
    # Post-execution actions
    PostExecution = @{
        GenerateReport = $true
        ValidateRunnerStatus = $true
        TestRunnerConnection = $true
        ConfigureAutoUpdates = $true
    }
    
    # Validation checks
    Validation = @{
        RequiredCommands = @('git', 'docker', 'node', 'pwsh')
        RequiredServices = @('actions.runner.*')
        NetworkConnectivity = @('https://github.com', 'https://api.github.com')
    }
}
