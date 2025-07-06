@{
    # Module metadata
    RootModule = 'CICDAgent.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author = 'AitherZero AI Team'
    CompanyName = 'AitherLabs'
    Copyright = '(c) 2025 AitherLabs. All rights reserved.'
    Description = 'AI-Native CI/CD Agent System - Enterprise-grade autonomous development lifecycle management with 5-agent orchestration'
    PowerShellVersion = '7.0'
    
    # Dependencies on existing AitherZero modules
    RequiredModules = @(
        @{ModuleName = 'Logging'; ModuleVersion = '1.0.0'},
        @{ModuleName = 'ModuleCommunication'; ModuleVersion = '2.0.0'},
        @{ModuleName = 'SystemMonitoring'; ModuleVersion = '2.0.0'},
        @{ModuleName = 'PatchManager'; ModuleVersion = '3.0.0'},
        @{ModuleName = 'OrchestrationEngine'; ModuleVersion = '1.0.0'},
        @{ModuleName = 'RestAPIServer'; ModuleVersion = '1.0.0'},
        @{ModuleName = 'AIToolsIntegration'; ModuleVersion = '1.0.0'},
        @{ModuleName = 'ConfigurationCore'; ModuleVersion = '1.0.0'}
    )
    
    # Exported functions - 5 main agents plus orchestration functions
    FunctionsToExport = @(
        # Agent 1: AI-Native CI/CD Architecture
        'Start-IntelligentWorkflowEngine',
        'New-EventDrivenTrigger', 
        'Invoke-SmartBuildOptimization',
        'Start-AdaptiveTestingStrategy',
        
        # Agent 2: GitHub Integration & Automation
        'Initialize-GitHubIntegrationLayer',
        'Start-AutomatedIssueManagement',
        'Invoke-IntelligentBranchStrategy',
        'Enable-AutomatedReleaseWorkflow',
        
        # Agent 3: Build/Test/Release Automation
        'Start-MultiPlatformBuildPipeline',
        'Initialize-IntelligentArtifactManager',
        'Invoke-ProgressiveDeployment',
        'Enable-QualityGateValidation',
        
        # Agent 4: AI Agent Coordination
        'Start-AIAgentCoordinator',
        'Enable-AutonomousIssueResolution',
        'Initialize-MultiAgentOrchestration',
        'Invoke-LearningAdaptationSystem',
        
        # Agent 5: Reporting/Auditing/Quality Gates
        'Start-ComprehensiveReporting',
        'Initialize-RealTimeMonitoring',
        'Enable-QualityMetricsAnalytics',
        'Start-ComplianceAuditSystem',
        
        # Main orchestration functions
        'Start-CICDAgentSystem',
        'Stop-CICDAgentSystem',
        'Get-CICDAgentStatus',
        'Invoke-AgentHealthCheck',
        'Get-CICDMetrics',
        'Reset-CICDAgentSystem',
        
        # Configuration and management
        'Set-CICDConfiguration',
        'Get-CICDConfiguration',
        'Export-CICDConfiguration',
        'Import-CICDConfiguration',
        'Test-CICDSystemHealth'
    )
    
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @(
        'Start-CICD',
        'Stop-CICD', 
        'Get-CICDStatus',
        'CICD-Health'
    )
    
    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('CI/CD', 'DevOps', 'AI', 'Automation', 'GitHub', 'Infrastructure', 'Testing', 'Monitoring', 'Enterprise')
            LicenseUri = 'https://github.com/AitherLabs/AitherZero/LICENSE'
            ProjectUri = 'https://github.com/AitherLabs/AitherZero'
            ReleaseNotes = @'
# CICDAgent v1.0.0 - AI-Native CI/CD System

## Features
- **5-Agent Architecture**: Specialized AI agents for complete development lifecycle automation
- **Event-Driven Workflows**: Intelligent triggers and adaptive pipeline management
- **GitHub Integration**: Advanced API integration with automated issue/PR management
- **Multi-Platform Builds**: Intelligent build pipelines for Windows, Linux, macOS
- **AI Coordination**: Autonomous issue resolution and multi-agent orchestration
- **Real-Time Monitoring**: Comprehensive dashboards and quality gate systems

## Agent Capabilities
1. **Agent 1**: AI-Native CI/CD Architecture with smart optimization
2. **Agent 2**: GitHub Integration & Automation with intelligent strategies
3. **Agent 3**: Build/Test/Release Automation with progressive deployment
4. **Agent 4**: AI Agent Coordination with autonomous resolution
5. **Agent 5**: Reporting/Auditing/Quality Gates with compliance systems

## Enterprise Features
- Machine learning-powered insights and predictions
- Autonomous bug detection and resolution
- Intelligent quality gate validation
- Progressive deployment strategies
- Comprehensive audit trails and compliance reporting
'@
        }
        
        # Module configuration
        Configuration = @{
            DefaultAgentSettings = @{
                EnableLogging = $true
                LogLevel = 'INFO'
                EnableMetrics = $true
                EnableHealthChecks = $true
                AutoRecovery = $true
            }
            
            AgentSettings = @{
                Agent1 = @{
                    Name = 'AI-Native CI/CD Architecture'
                    Priority = 'High'
                    EnableSmartOptimization = $true
                    EnableAdaptiveTesting = $true
                }
                Agent2 = @{
                    Name = 'GitHub Integration & Automation'
                    Priority = 'High'
                    EnableAutoIssueManagement = $true
                    EnableIntelligentBranching = $true
                }
                Agent3 = @{
                    Name = 'Build/Test/Release Automation'
                    Priority = 'High'
                    EnableMultiPlatformBuilds = $true
                    EnableProgressiveDeployment = $true
                }
                Agent4 = @{
                    Name = 'AI Agent Coordination'
                    Priority = 'Critical'
                    EnableAutonomousResolution = $true
                    EnableLearningAdaptation = $true
                }
                Agent5 = @{
                    Name = 'Reporting/Auditing/Quality Gates'
                    Priority = 'Medium'
                    EnableRealTimeReporting = $true
                    EnableComplianceAuditing = $true
                }
            }
        }
    }
}