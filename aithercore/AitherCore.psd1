@{
    ModuleVersion = '1.0.0.0'
    GUID = 'b8e5f9a2-3c4d-5e6f-7a8b-9c0d1e2f3a4b'
    Author = 'AitherZero Team'
    Description = 'AitherCore - Essential modules for basic AitherZero releases. Includes logging, configuration, UI, security, infrastructure, and orchestration.'
    PowerShellVersion = '7.0'

    # Root module - main initialization script
    RootModule = 'AitherCore.psm1'

    # Functions to export from all nested modules
    FunctionsToExport = @(
        # From Logging.psm1
        'Write-CustomLog',
        'Set-LogLevel',
        'Set-LogTargets',
        'Enable-LogRotation',
        'Disable-LogRotation',
        'Start-PerformanceTrace',
        'Stop-PerformanceTrace',
        'Get-Logs',
        'Clear-Logs',
        'Get-LogPath',
        'Initialize-Logging',
        'Clear-LogBuffer',
        'Write-AuditLog',
        'Enable-AuditLogging',
        'Disable-AuditLogging',
        'Get-AuditLogs',
        'Write-StructuredLog',
        'Search-Logs',
        'Export-LogReport',

        # From Configuration.psm1
        'Get-Configuration',
        'Set-Configuration',
        'Get-ConfigValue',
        'Get-ConfiguredValue',
        'Merge-Configuration',
        'Initialize-ConfigurationSystem',
        'Switch-ConfigurationEnvironment',
        'Test-Configuration',
        'Export-Configuration',
        'Import-Configuration',
        'Enable-ConfigurationHotReload',
        'Disable-ConfigurationHotReload',
        'Get-PlatformManifest',
        'Get-FeatureConfiguration',
        'Test-FeatureEnabled',
        'Get-ExecutionProfile',
        'Get-FeatureDependencies',
        'Resolve-FeatureDependencies',

        # From TextUtilities.psm1
        'Repair-TextSpacing',

        # From BetterMenu.psm1
        'Show-BetterMenu',

        # From UserInterface.psm1
        'Show-UIMenu',
        'Show-UIProgress',
        'Show-UINotification',
        'Show-UIWizard',
        'Initialize-AitherUI',
        'Show-UIBorder',
        'Write-UIText',
        'Show-UISpinner',
        'Write-UISection',
        'Write-UIError',
        'Write-UISuccess',
        'Write-UIWarning',
        'Write-UIInfo',
        'Get-UITheme',
        'Set-UITheme',
        'Enable-UIEmoji',
        'Disable-UIEmoji',

        # From Performance.psm1
        'Start-PerformanceTimer',
        'Stop-PerformanceTimer',
        'Measure-Performance',
        'Get-PerformanceMetrics',
        'Get-PerformanceSummary',
        'Show-PerformanceDashboard',
        'Measure-FileProcessing',
        'Initialize-PerformanceMonitoring',
        'Export-PerformanceReport',
        'Test-PerformanceBudget',
        'Set-PerformanceBudget',

        # From Bootstrap.psm1
        'Initialize-AitherEnvironment',
        'Test-PowerShell7',
        'Install-PowerShell7',
        'Initialize-DirectoryStructure',
        'Install-ValidationTools',
        'Install-DevelopmentTools',
        'Install-GoLanguage',
        'Install-OpenTofu',
        'Initialize-OpenTofu',
        'Clear-AitherEnvironment',
        'Get-EnvironmentStatus',

        # From PackageManager.psm1
        'Get-AvailablePackageManagers',
        'Get-PackageId',
        'Test-PackageInstalled',
        'Install-SoftwarePackage',
        'Get-SoftwareVersion',

        # From Infrastructure.psm1
        'Test-OpenTofu',
        'Get-InfrastructureTool',
        'Invoke-InfrastructurePlan',
        'Invoke-InfrastructureApply',
        'Invoke-InfrastructureDestroy',

        # From Security.psm1
        'Invoke-SSHCommand',
        'Test-SSHConnection',

        # From OrchestrationEngine.psm1
        'Invoke-OrchestrationSequence',
        'Invoke-Sequence',
        'Get-OrchestrationPlaybook',
        'Save-OrchestrationPlaybook',
        'ConvertTo-StandardPlaybookFormat',
        'Test-PlaybookConditions',
        'Send-PlaybookNotification',

        # Wildcard for any additional functions
        '*'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @('seq')

    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('Automation', 'Infrastructure', 'Core', 'Essential', 'Minimal')
            ProjectUri = 'https://github.com/wizzense/AitherZero'
            LicenseUri = 'https://github.com/wizzense/AitherZero/blob/main/LICENSE'
            ReleaseNotes = 'AitherCore - Essential modules for basic releases (8 core modules, ~5,500 lines)'
        }
    }
}
