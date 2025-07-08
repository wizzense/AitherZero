@{
    # Module metadata
    RootModule = 'SystemMonitoring.psm1'
    ModuleVersion = '2.0.0'
    GUID = '12345678-1234-1234-1234-123456781234'
    Author = 'AitherZero Contributors'
    CompanyName = 'AitherZero'
    Copyright = '(c) 2024 AitherZero. All rights reserved.'
    Description = 'Advanced system monitoring with real-time analytics, intelligent alerting, and predictive capabilities for AitherZero infrastructure'
    
    # PowerShell version compatibility
    PowerShellVersion = '7.0'
    
    # Required modules (optional - handled with try/catch in psm1)
    RequiredModules = @()
    
    # Functions to export
    FunctionsToExport = @(
        'Get-SystemDashboard',
        'Get-SystemAlerts',
        'Get-SystemPerformance',
        'Get-ServiceStatus',
        'Search-SystemLogs',
        'Set-PerformanceBaseline',
        'Invoke-HealthCheck',
        'Start-SystemMonitoring',
        'Stop-SystemMonitoring',
        'Get-MonitoringConfiguration',
        'Set-MonitoringConfiguration',
        'Export-MonitoringData',
        'Import-MonitoringData',
        'Enable-PredictiveAlerting',
        'Get-MonitoringInsights'
    )
    
    # Cmdlets to export
    CmdletsToExport = @()
    
    # Variables to export
    VariablesToExport = @()
    
    # Aliases to export
    AliasesToExport = @()
    
    # File extensions
    FileList = @()
    
    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('Monitoring', 'SystemHealth', 'Performance', 'Alerts', 'AitherZero')
            LicenseUri = ''
            ProjectUri = ''
            IconUri = ''
            ReleaseNotes = 'Initial release of SystemMonitoring module for AitherZero'
        }
    }
}