@{
    ModuleVersion = '2.0.0'
    GUID = 'b8e5f9a2-3c4d-5e6f-7a8b-9c0d1e2f3a4b'
    Author = 'AitherZero Team'
    Description = 'AitherZero CLI - Powerful CI/CD automation interface with comprehensive cmdlets for infrastructure automation, orchestration, and DevOps workflows'
    PowerShellVersion = '7.0'
    
    RootModule = 'AitherZeroCLI.psm1'
    
    FunctionsToExport = @(
        # Script Execution
        'Invoke-AitherScript',
        'Get-AitherScript',
        'Invoke-AitherSequence',
        
        # Playbook & Orchestration
        'Invoke-AitherPlaybook',
        'Get-AitherPlaybook',
        
        # Configuration
        'Get-AitherConfig',
        'Set-AitherConfig',
        'Switch-AitherEnvironment',
        
        # Reporting & Metrics
        'Show-AitherDashboard',
        'Get-AitherMetrics',
        'Export-AitherMetrics',
        
        # Utilities
        'Get-AitherPlatform',
        'Test-AitherAdmin',
        'Get-AitherVersion',
        'Test-AitherCommand',
        
        # Logging
        'Write-AitherLog'
    )
    
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @('az-script', 'az-playbook', 'az-config', 'az-dashboard', 'az-metrics')
    
    PrivateData = @{
        PSData = @{
            Tags = @('CLI', 'Automation', 'CI/CD', 'DevOps', 'Infrastructure', 'Orchestration', 'PowerShell')
            ProjectUri = 'https://github.com/wizzense/AitherZero'
            LicenseUri = 'https://github.com/wizzense/AitherZero/blob/main/LICENSE'
            ReleaseNotes = 'v2.0.0 - Complete CLI redesign with professional cmdlet interface'
        }
    }
}
