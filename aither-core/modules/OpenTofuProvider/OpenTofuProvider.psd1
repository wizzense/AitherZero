@{
    RootModule = 'OpenTofuProvider.psm1'
    ModuleVersion = '1.2.0'
    GUID = 'a1b2c3d4-e5f6-78ab-9012-123456789abc'
    Author = 'Aitherium Infrastructure Automation'
    CompanyName = 'Aitherium'
    Copyright = '(c) 2025 Aitherium. All rights reserved.'
    Description = 'PowerShell module for secure OpenTofu infrastructure automation with Taliesins Hyper-V provider integration'

    PowerShellVersion = '7.0'

    FunctionsToExport = @(
        # Original functions
        'Install-OpenTofuSecure',
        'Initialize-OpenTofuProvider',
        'Test-OpenTofuSecurity',
        'New-LabInfrastructure',
        'Get-TaliesinsProviderConfig',
        'Set-SecureCredentials',
        'Test-InfrastructureCompliance',
        'Export-LabTemplate',
        'Import-LabConfiguration',
        
        # Repository Management
        'Register-InfrastructureRepository',
        'Sync-InfrastructureRepository',
        'Get-InfrastructureRepository',
        'Test-RepositoryCompatibility',
        'New-TemplateRepository',
        
        # Template Management
        'New-VersionedTemplate',
        'Get-TemplateVersion',
        'Test-TemplateDependencies',
        'Update-TemplateVersion',
        
        # Configuration Management
        'Read-DeploymentConfiguration',
        'New-DeploymentConfiguration',
        
        # ISO Automation
        'Initialize-DeploymentISOs',
        'Test-ISORequirements',
        'Update-DeploymentISOs',
        'Get-ISOConfiguration',
        
        # Deployment Orchestration
        'Start-InfrastructureDeployment',
        'New-DeploymentPlan',
        'Invoke-DeploymentStage',
        'Get-DeploymentStatus',
        
        # Provider Abstraction
        'Get-InfrastructureProvider',
        'Register-InfrastructureProvider',
        'Unregister-InfrastructureProvider',
        'Test-ProviderCapability',
        'Test-ProviderConfiguration',
        'ConvertTo-ProviderResource',
        
        # Advanced Features
        'Test-InfrastructureDrift',
        'Start-DeploymentRollback',
        'New-DeploymentSnapshot',
        'Get-DeploymentSnapshot',
        'Remove-DeploymentSnapshot',
        'Compare-DeploymentSnapshots',
        'Get-DeploymentHistory',
        'New-DeploymentVersion',
        'Get-DeploymentVersion',
        'Start-DeploymentAutomation',
        'Stop-DeploymentAutomation',
        'Get-DeploymentAutomation',
        
        # Performance Optimization
        'Optimize-DeploymentPerformance',
        'Test-ConcurrentDeployments',
        'Optimize-MemoryUsage',
        'Optimize-DeploymentCaching'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()

    PrivateData = @{
        PSData = @{
            Tags = @('OpenTofu', 'Terraform', 'Infrastructure', 'Security', 'HyperV', 'Automation')
            LicenseUri = ''
            ProjectUri = 'https://github.com/wizzense/opentofu-lab-automation'
            ReleaseNotes = 'v1.2.0: Added Advanced Features (Drift Detection, Rollback, Snapshots, History, Automation) and Performance Optimization (Memory Management, Caching, Concurrent Testing). Complete Infrastructure Abstraction Layer with comprehensive testing and integration capabilities.'
            Licensing = @{
                Tier = 'pro'
                Feature = 'infrastructure'
                RequiresLicense = $true
            }
        }
    }
}