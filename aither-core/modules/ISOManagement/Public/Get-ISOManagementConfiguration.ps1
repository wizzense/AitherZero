function Get-ISOManagementConfiguration {
    <#
    .SYNOPSIS
        Retrieves current configuration settings for the ISOManagement module.

    .DESCRIPTION
        This function provides access to the current configuration settings used by the
        ISOManagement module, including paths, default values, and runtime settings.
        It supports both viewing and exporting configuration for backup or transfer.

    .PARAMETER Section
        Specific configuration section to retrieve:
        - 'All' - All configuration sections (default)
        - 'Paths' - File and directory paths
        - 'Defaults' - Default values and settings
        - 'Runtime' - Runtime and performance settings
        - 'Templates' - Template configuration
        - 'Workflow' - Workflow and history settings

    .PARAMETER OutputFormat
        Format for configuration output:
        - 'Object' - PowerShell objects (default)
        - 'Json' - JSON format
        - 'Table' - Formatted table
        - 'Export' - Export to configuration file

    .PARAMETER ExportPath
        Path for configuration export (used with OutputFormat 'Export')

    .PARAMETER IncludeAdvanced
        Include advanced and internal configuration settings

    .EXAMPLE
        # Get all configuration settings
        Get-ISOManagementConfiguration

    .EXAMPLE
        # Get only path settings in table format
        Get-ISOManagementConfiguration -Section 'Paths' -OutputFormat 'Table'

    .EXAMPLE
        # Export configuration to JSON file
        Get-ISOManagementConfiguration -OutputFormat 'Export' -ExportPath 'C:\Config\iso-management-config.json'

    .EXAMPLE
        # Get advanced configuration including internal settings
        Get-ISOManagementConfiguration -IncludeAdvanced

    .OUTPUTS
        Configuration object or formatted output based on parameters
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('All', 'Paths', 'Defaults', 'Runtime', 'Templates', 'Workflow')]
        [string]$Section = 'All',

        [Parameter(Mandatory = $false)]
        [ValidateSet('Object', 'Json', 'Table', 'Export')]
        [string]$OutputFormat = 'Object',

        [Parameter(Mandatory = $false)]
        [string]$ExportPath,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeAdvanced
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Retrieving ISOManagement configuration: Section=$Section"
        
        # Validate export path if needed
        if ($OutputFormat -eq 'Export' -and -not $ExportPath) {
            throw "ExportPath is required when OutputFormat is 'Export'"
        }
    }

    process {
        # Build configuration object
        $config = [PSCustomObject]@{
            ModuleInfo = @{
                Name = 'ISOManagement'
                Version = $script:ISOManagementConfig.Version
                ConsolidatedModules = $script:ISOManagementConfig.ConsolidatedModules
                LoadedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                PSVersion = $PSVersionTable.PSVersion.ToString()
                Platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
            }
            
            Paths = @{
                DefaultRepositoryPath = $script:ISOManagementConfig.DefaultRepositoryPath
                DefaultExtractPath = $script:ISOManagementConfig.DefaultExtractPath
                DefaultMountPath = $script:ISOManagementConfig.DefaultMountPath
                TemplateDirectory = $script:ISOManagementConfig.TemplateDirectory
                WorkflowHistoryPath = $script:ISOManagementConfig.WorkflowHistoryPath
                OscdimgPath = $script:ISOManagementConfig.OscdimgPath
                DismPath = $script:ISOManagementConfig.DismPath
            }
            
            Defaults = @{
                DefaultWIMIndex = $script:ISOManagementConfig.DefaultWIMIndex
                DefaultRetryCount = $script:ISOManagementConfig.DefaultRetryCount
                DefaultTimeoutSeconds = $script:ISOManagementConfig.DefaultTimeoutSeconds
                MaxHistoryEntries = $script:ISOManagementConfig.MaxHistoryEntries
            }
            
            Runtime = @{
                ModulePath = $PSScriptRoot
                ConfigurationLoaded = $true
                TemplatesAvailable = (Test-Path $script:ISOManagementConfig.TemplateDirectory)
                WorkflowHistoryAvailable = (Test-Path $script:ISOManagementConfig.WorkflowHistoryPath)
                WindowsADKDetected = ($script:ISOManagementConfig.OscdimgPath -and (Test-Path $script:ISOManagementConfig.OscdimgPath))
                DefaultRepositoryExists = (Test-Path $script:ISOManagementConfig.DefaultRepositoryPath)
            }
            
            Templates = @{
                TemplateDirectory = $script:ISOManagementConfig.TemplateDirectory
                BuiltInTemplates = @(
                    'autounattend-generic.xml',
                    'autounattend-headless.xml',
                    'autounattend-headless-modern.xml',
                    'bootstrap.ps1',
                    'kickstart.cfg'
                )
                CustomTemplatesAvailable = if (Test-Path $script:ISOManagementConfig.TemplateDirectory) {
                    (Get-ChildItem -Path $script:ISOManagementConfig.TemplateDirectory -File).Count
                } else { 0 }
            }
            
            Workflow = @{
                HistoryPath = $script:ISOManagementConfig.WorkflowHistoryPath
                MaxHistoryEntries = $script:ISOManagementConfig.MaxHistoryEntries
                HistoryFileExists = (Test-Path $script:ISOManagementConfig.WorkflowHistoryPath)
                CurrentHistoryEntries = if (Test-Path $script:ISOManagementConfig.WorkflowHistoryPath) {
                    try {
                        $history = Get-Content $script:ISOManagementConfig.WorkflowHistoryPath | ConvertFrom-Json
                        $history.Workflows.Count
                    } catch { 0 }
                } else { 0 }
            }
        }
        
        # Add advanced settings if requested
        if ($IncludeAdvanced) {
            $config | Add-Member -NotePropertyName 'Advanced' -NotePropertyValue @{
                InternalConfig = $script:ISOManagementConfig
                EnvironmentVariables = @{
                    TEMP = $env:TEMP
                    USERPROFILE = $env:USERPROFILE
                    ProgramFiles = $env:ProgramFiles
                    ProgramFilesX86 = ${env:ProgramFiles(x86)}
                }
                ModuleLoadOrder = @(
                    'Logging Module',
                    'Private Functions',
                    'Public Functions',
                    'Template Detection',
                    'History Initialization',
                    'Repository Creation'
                )
                FeatureAvailability = @{
                    WindowsISOSupport = $IsWindows
                    LinuxISOSupport = $true
                    MacOSISOSupport = $IsMacOS
                    ParallelProcessing = $true
                    WorkflowTracking = $true
                    TemplateLibrary = $true
                }
            }
        }
        
        # Filter by section
        $outputConfig = switch ($Section) {
            'Paths' { [PSCustomObject]@{ Paths = $config.Paths } }
            'Defaults' { [PSCustomObject]@{ Defaults = $config.Defaults } }
            'Runtime' { [PSCustomObject]@{ Runtime = $config.Runtime } }
            'Templates' { [PSCustomObject]@{ Templates = $config.Templates } }
            'Workflow' { [PSCustomObject]@{ Workflow = $config.Workflow } }
            'All' { $config }
        }
        
        # Format output
        switch ($OutputFormat) {
            'Object' {
                return $outputConfig
            }
            
            'Json' {
                return $outputConfig | ConvertTo-Json -Depth 10
            }
            
            'Table' {
                Write-Host ""
                Write-Host "=== ISOManagement Configuration ===" -ForegroundColor Green
                Write-Host "Module Version: $($config.ModuleInfo.Version)" -ForegroundColor White
                Write-Host "Platform: $($config.ModuleInfo.Platform)" -ForegroundColor White
                Write-Host ""
                
                if ($Section -eq 'All' -or $Section -eq 'Paths') {
                    Write-Host "File and Directory Paths:" -ForegroundColor Yellow
                    foreach ($path in $config.Paths.PSObject.Properties) {
                        $exists = if ($path.Value) { if (Test-Path $path.Value) { "✓" } else { "✗" } } else { "N/A" }
                        Write-Host "  $($path.Name): $($path.Value) [$exists]" -ForegroundColor Gray
                    }
                    Write-Host ""
                }
                
                if ($Section -eq 'All' -or $Section -eq 'Defaults') {
                    Write-Host "Default Settings:" -ForegroundColor Yellow
                    foreach ($setting in $config.Defaults.PSObject.Properties) {
                        Write-Host "  $($setting.Name): $($setting.Value)" -ForegroundColor Gray
                    }
                    Write-Host ""
                }
                
                if ($Section -eq 'All' -or $Section -eq 'Runtime') {
                    Write-Host "Runtime Status:" -ForegroundColor Yellow
                    foreach ($status in $config.Runtime.PSObject.Properties) {
                        $value = if ($status.Value -is [bool]) { 
                            if ($status.Value) { "✓ Enabled" } else { "✗ Disabled" }
                        } else { 
                            $status.Value 
                        }
                        Write-Host "  $($status.Name): $value" -ForegroundColor Gray
                    }
                    Write-Host ""
                }
                
                if ($Section -eq 'All' -or $Section -eq 'Templates') {
                    Write-Host "Template Configuration:" -ForegroundColor Yellow
                    Write-Host "  Template Directory: $($config.Templates.TemplateDirectory)" -ForegroundColor Gray
                    Write-Host "  Built-in Templates: $($config.Templates.BuiltInTemplates.Count)" -ForegroundColor Gray
                    Write-Host "  Custom Templates: $($config.Templates.CustomTemplatesAvailable)" -ForegroundColor Gray
                    Write-Host ""
                }
                
                if ($Section -eq 'All' -or $Section -eq 'Workflow') {
                    Write-Host "Workflow Configuration:" -ForegroundColor Yellow
                    Write-Host "  History Enabled: $(if ($config.Workflow.HistoryFileExists) { '✓ Yes' } else { '✗ No' })" -ForegroundColor Gray
                    Write-Host "  Current Entries: $($config.Workflow.CurrentHistoryEntries)" -ForegroundColor Gray
                    Write-Host "  Max Entries: $($config.Workflow.MaxHistoryEntries)" -ForegroundColor Gray
                    Write-Host ""
                }
                
                return
            }
            
            'Export' {
                try {
                    # Ensure export directory exists
                    $exportDir = Split-Path $ExportPath -Parent
                    if ($exportDir -and -not (Test-Path $exportDir)) {
                        New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
                    }
                    
                    # Export configuration
                    $exportData = @{
                        ExportInfo = @{
                            ExportedBy = 'Get-ISOManagementConfiguration'
                            ExportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                            ModuleVersion = $config.ModuleInfo.Version
                            Platform = $config.ModuleInfo.Platform
                        }
                        Configuration = $outputConfig
                    }
                    
                    $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $ExportPath -Encoding UTF8
                    
                    Write-CustomLog -Level 'SUCCESS' -Message "Configuration exported to: $ExportPath"
                    
                    return [PSCustomObject]@{
                        Success = $true
                        ExportPath = $ExportPath
                        ExportedDate = Get-Date
                        ConfigurationSections = if ($Section -eq 'All') { @('ModuleInfo', 'Paths', 'Defaults', 'Runtime', 'Templates', 'Workflow') } else { @($Section) }
                    }
                    
                } catch {
                    Write-CustomLog -Level 'ERROR' -Message "Failed to export configuration: $($_.Exception.Message)"
                    throw
                }
            }
        }
    }
}