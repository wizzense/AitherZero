# Development Environment Setup Playbook
# Comprehensive development environment configuration
# Runs identically in local environment and GitHub Actions

@{
    Name = 'dev-environment-setup'
    Description = 'Complete development environment setup with IDE, tools, and AI integrations'
    Version = '1.0.0'
    Author = 'AitherZero Team'
    
    # Configuration
    Configuration = @{
        Profile = 'Development'  # Development, AI-Development, Full-Stack, Deployment
        NonInteractive = $false  # Set to true in CI
        ContinueOnError = $false
        Parallel = $false  # Sequential for proper dependency handling
    }
    
    # Environment detection
    Environment = @{
        DetectCI = $true
        AdaptToCI = $true  # Adjust settings for CI environment
        RequireAdmin = $false  # Most tools don't need admin
    }
    
    # Script execution sequence
    Sequence = @(
        # Phase 1: Core Setup
        @{
            Name = 'Environment Configuration'
            Scripts = @('0001')
            Description = 'Configure system environment (long path, env vars)'
            Required = $true
            Timeout = 300
        }
        
        # Phase 2: Core Development Tools
        @{
            Name = 'Core Tools'
            Scripts = @('0207', '0201')  # Git, Node
            Description = 'Install Git and Node.js'
            Required = $true
            Timeout = 600
        }
        
        # Phase 3: Additional Languages
        @{
            Name = 'Programming Languages'
            Scripts = @('0206', '0212')  # Python, Go
            Description = 'Install Python and Go'
            Required = $false
            Timeout = 600
            SkipIfExists = @('python', 'go')
        }
        
        # Phase 4: IDEs and Editors
        @{
            Name = 'Development Environment'
            Scripts = @('0210', '0211')  # VS Code, GitHub CLI
            Description = 'Install VS Code and GitHub CLI'
            Required = $false
            Timeout = 600
        }
        
        # Phase 5: Containers and Infrastructure
        @{
            Name = 'Infrastructure Tools'
            Scripts = @('0208', '0008')  # Docker, OpenTofu
            Description = 'Install Docker and OpenTofu'
            Required = $false
            Timeout = 900
            RequireAdmin = $true  # Docker may need admin
        }
        
        # Phase 6: AI Tools
        @{
            Name = 'AI Development Tools'
            Scripts = @('0220', '0010')  # AI CLIs, MCP Servers
            Description = 'Install AI CLI tools and MCP servers'
            Required = $false
            Timeout = 300
            SkipInCI = $false  # Can run in CI if API keys available
        }
        
        # Phase 7: Testing and Quality
        @{
            Name = 'Testing Tools'
            Scripts = @('0400', '0401')  # Install testing tools
            Description = 'Install Pester and testing frameworks'
            Required = $false
            Timeout = 300
        }
    )
    
    # Post-execution actions
    PostExecution = @{
        GenerateReport = $true
        ValidateInstallation = $true
        ConfigureTools = $true  # Run post-install configuration
    }
    
    # GitHub Actions specific configuration
    GitHubActions = @{
        RunsOn = 'ubuntu-latest'  # Default runner
        Timeout = 30  # Minutes
        CacheEnabled = $true
        CachePaths = @(
            '$HOME/.npm'
            '$HOME/.cache/go-build'
            '$HOME/.cache/pip'
        )
        Environment = @{
            AITHERZERO_PROFILE = 'Development'
            # Non-interactive mode is derived from CI detection
        }
    }
    
    # Local execution configuration
    LocalExecution = @{
        Interactive = $true
        PromptForOptional = $true
        ShowProgress = $true
    }
}
