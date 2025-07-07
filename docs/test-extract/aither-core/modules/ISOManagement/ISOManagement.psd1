@{
    RootModule        = 'ISOManagement.psm1'
    ModuleVersion     = '3.0.0'
    GUID              = '2F8A9B3C-1D4E-5F6A-7B8C-9D0E1F2A3B4C'
    Author            = 'AitherZero Contributors'
    CompanyName       = 'AitherZero'
    Copyright         = '(c) 2025 AitherZero. All rights reserved.'
    Description       = 'Unified enterprise-grade ISO management module combining download, customization, and deployment capabilities with integrated workflows for complete ISO lifecycle management in automated lab infrastructure'
    PowerShellVersion = '7.0'
    RequiredModules   = @()
    
    # Combined functions from both ISOManager and ISOCustomizer
    FunctionsToExport = @(
        # Download and Repository Management (from ISOManager)
        'Get-ISODownload',
        'Get-ISOInventory',
        'Get-ISOMetadata',
        'New-ISORepository',
        'Remove-ISOFile',
        'Export-ISOInventory',
        'Import-ISOInventory',
        'Sync-ISORepository',
        'Optimize-ISOStorage',
        
        # Customization and Deployment (from ISOCustomizer)
        'New-CustomISO',
        'New-CustomISOWithProgress',
        'New-AutounattendFile',
        'New-AdvancedAutounattendFile',
        'Get-AutounattendTemplate',
        'Get-BootstrapTemplate',
        'Get-KickstartTemplate',
        
        # Unified integrity testing (consolidated from both modules)
        'Test-ISOIntegrity',
        
        # New unified workflow functions
        'Start-ISOLifecycleWorkflow',
        'New-DeploymentReadyISO',
        'Get-ISOWorkflowStatus',
        'Invoke-ISOPipeline',
        'New-ISOFromTemplate',
        'Get-ISOTemplateLibrary',
        'Export-ISOWorkflowConfiguration',
        'Import-ISOWorkflowConfiguration',
        
        # Cross-module utility functions
        'Get-ISOManagementConfiguration',
        'Set-ISOManagementConfiguration',
        'Test-ISOManagementEnvironment',
        'Initialize-ISOManagementRepository',
        'Get-ISOWorkflowHistory',
        'Clear-ISOWorkflowHistory'
    )
    
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    
    PrivateData       = @{
        PSData = @{
            Tags                     = @('ISO', 'Download', 'Customization', 'Management', 'Deployment', 'Lab', 'Infrastructure', 'Automation', 'Windows', 'Linux', 'AitherZero')
            ProjectUri               = 'https://github.com/wizzense/AitherZero'
            RequireLicenseAcceptance = $false
            ReleaseNotes             = @'
# ISOManagement Module v3.0.0

## Major Changes
- Consolidated ISOManager and ISOCustomizer into unified module
- Integrated download-to-deployment workflows
- Enhanced template management system
- Unified progress tracking across all operations
- Streamlined API with backward compatibility

## New Features
- Start-ISOLifecycleWorkflow for complete ISO automation
- New-DeploymentReadyISO for one-step custom ISO creation
- Template library management with Get-ISOTemplateLibrary
- Workflow configuration export/import capabilities
- Enhanced progress tracking and status reporting

## Breaking Changes
- None - Full backward compatibility maintained
- All existing function calls continue to work unchanged
- Enhanced functionality through new unified workflows

## Migration Guide
- No migration required for existing code
- New unified workflows available for enhanced automation
- Template management enhanced with library system
'@
        }
    }
}