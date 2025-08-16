@{
    Name = 'ai-orchestration-config'
    Description = 'AI Agent Orchestration Configuration for Claude Code'
    Version = '1.0.0'
    Author = 'AitherZero AI Integration'
    
    # AI Agent Types and Their Capabilities
    Agents = @{
        'test-runner' = @{
            Description = 'Executes tests and fixes failures'
            Capabilities = @('test-execution', 'test-fixing', 'coverage-analysis')
            Playbooks = @('test-fix-workflow', 'test-full', 'test-coverage')
        }
        
        'code-reviewer' = @{
            Description = 'Reviews code for quality and best practices'
            Capabilities = @('code-review', 'pattern-detection', 'refactoring')
            Playbooks = @('ai-review-code', 'ai-refactor', 'ai-patterns')
        }
        
        'security-scanner' = @{
            Description = 'Scans for security vulnerabilities'
            Capabilities = @('vulnerability-scan', 'dependency-check', 'secrets-detection')
            Playbooks = @('ai-security-scan', 'ai-dependency-audit')
        }
        
        'performance-optimizer' = @{
            Description = 'Optimizes code performance'
            Capabilities = @('performance-analysis', 'optimization', 'profiling')
            Playbooks = @('ai-optimize', 'ai-profile')
        }
        
        'documentation-generator' = @{
            Description = 'Generates and updates documentation'
            Capabilities = @('doc-generation', 'api-docs', 'readme-update')
            Playbooks = @('ai-generate-docs', 'ai-update-readme')
        }
        
        'deployment-manager' = @{
            Description = 'Manages deployment pipelines'
            Capabilities = @('deployment', 'rollback', 'environment-config')
            Playbooks = @('deploy-dev', 'deploy-staging', 'deploy-prod')
        }
    }
    
    # Workflow Templates for Common Tasks
    Workflows = @{
        'complete-fix' = @{
            Description = 'Complete test fix and validation workflow'
            Stages = @(
                @{Name = 'RunTests'; Playbook = 'test-full'}
                @{Name = 'FixFailures'; Playbook = 'test-fix-workflow'}
                @{Name = 'Validate'; Playbook = 'test-quick'}
                @{Name = 'Commit'; Playbook = 'commit-changes'}
            )
        }
        
        'pre-commit' = @{
            Description = 'Pre-commit validation workflow'
            Stages = @(
                @{Name = 'Lint'; Playbook = 'lint-check'}
                @{Name = 'Test'; Playbook = 'test-quick'}
                @{Name = 'Security'; Playbook = 'security-quick'}
            )
        }
        
        'full-review' = @{
            Description = 'Comprehensive code review workflow'
            Stages = @(
                @{Name = 'CodeReview'; Playbook = 'ai-review-code'}
                @{Name = 'Security'; Playbook = 'ai-security-scan'}
                @{Name = 'Performance'; Playbook = 'ai-optimize'}
                @{Name = 'Documentation'; Playbook = 'ai-generate-docs'}
            )
        }
        
        'release' = @{
            Description = 'Full release workflow'
            Stages = @(
                @{Name = 'Test'; Playbook = 'test-full'}
                @{Name = 'Build'; Playbook = 'build-release'}
                @{Name = 'Deploy'; Playbook = 'deploy-staging'}
                @{Name = 'Validate'; Playbook = 'validate-deployment'}
                @{Name = 'Release'; Playbook = 'create-release'}
            )
        }
    }
    
    # Control Mechanisms
    Controls = @{
        # Approval requirements for sensitive operations
        RequireApproval = @(
            'deploy-prod'
            'rollback-prod'
            'delete-resources'
        )
        
        # Automatic triggers
        AutoTriggers = @{
            'test-fix-workflow' = @{
                Condition = 'TestFailures'
                Threshold = 1
            }
            'ai-security-scan' = @{
                Condition = 'PreCommit'
                FilePatterns = @('*.ps1', '*.psm1', '*.yml')
            }
        }
        
        # Parallel execution settings
        ParallelExecution = @{
            Enabled = $true
            MaxConcurrency = 4
            Stages = @('test-quick', 'lint-check', 'security-quick')
        }
        
        # Timeout settings (in seconds)
        Timeouts = @{
            Default = 300
            'test-full' = 600
            'test-fix-workflow' = 900
            'deploy-prod' = 1800
        }
        
        # Retry policies
        RetryPolicies = @{
            Default = @{
                MaxAttempts = 3
                DelaySeconds = 10
            }
            'test-fix-workflow' = @{
                MaxAttempts = 5
                DelaySeconds = 30
            }
        }
    }
    
    # Integration Points
    Integrations = @{
        Claude = @{
            Enabled = $true
            DefaultAgent = 'test-runner'
            AutoFix = $true
            MaxConcurrentAgents = 3
        }
        
        GitHub = @{
            Enabled = $true
            AutoCreateIssues = $true
            AutoCreatePR = $false
            RequireChecks = @('test-full', 'security-scan')
        }
        
        Monitoring = @{
            Enabled = $true
            LogPath = './logs/orchestration'
            MetricsEnabled = $true
            AlertThresholds = @{
                FailureRate = 0.1
                Duration = 3600
            }
        }
    }
    
    # Environment-specific settings
    Environments = @{
        Development = @{
            AutoDeploy = $true
            RequireApproval = $false
            TestLevel = 'quick'
        }
        
        Staging = @{
            AutoDeploy = $false
            RequireApproval = $true
            TestLevel = 'full'
        }
        
        Production = @{
            AutoDeploy = $false
            RequireApproval = $true
            TestLevel = 'full'
            RequireMultipleApprovers = $true
            MinApprovers = 2
        }
    }
}