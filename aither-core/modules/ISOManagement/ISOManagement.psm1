#Requires -Version 7.0

<#
.SYNOPSIS
    Unified enterprise-grade ISO management module combining download, customization, and deployment capabilities.

.DESCRIPTION
    This module consolidates the functionality of ISOManager and ISOCustomizer into a comprehensive
    ISO lifecycle management system. It provides integrated workflows for downloading, customizing,
    and deploying ISO images with advanced features for enterprise lab automation.

    Key capabilities include:
    - ISO download from multiple sources (Windows, Linux, custom URLs)
    - Repository management with metadata and integrity validation
    - ISO customization with autounattend files and script injection
    - Integrated workflows for complete ISO lifecycle automation
    - Template management and library system
    - Cross-platform compatibility and enterprise-grade validation

.NOTES
    - Replaces separate ISOManager and ISOCustomizer modules
    - Maintains full backward compatibility with existing function calls
    - Integrates with AitherZero logging and configuration systems
    - Supports Windows, Linux, and macOS with platform-specific features
    - Requires PowerShell 7.0+ for cross-platform compatibility

.VERSION
    3.0.0 - Unified module combining ISOManager v2.0.0 and ISOCustomizer v1.0.0

.AUTHOR
    AitherZero Contributors

.COPYRIGHT
    (c) 2025 AitherZero. All rights reserved.
#>

# Module initialization
Write-Verbose "Initializing ISOManagement module v3.0.0"

# Import required modules
try {
    Import-Module (Join-Path $PSScriptRoot '../Logging/Logging.psm1') -Force -ErrorAction Stop
    Write-CustomLog -Level 'DEBUG' -Message "Successfully imported Logging module"
} catch {
    Write-Warning "Failed to import Logging module: $_"
    # Fallback to Write-Host if logging module not available
    function Write-CustomLog {
        param(
            [string]$Level = 'INFO',
            [string]$Message
        )
        Write-Host "[$Level] $Message"
    }
}

# Module-wide variables
$script:ModuleConfig = @{
    # Default paths
    DefaultRepositoryPath = Join-Path $env:USERPROFILE "ISO-Repository"
    DefaultExtractPath = Join-Path $env:TEMP "ISOExtract"
    DefaultMountPath = Join-Path $env:TEMP "ISOMount"
    
    # Templates
    TemplateDirectory = Join-Path $PSScriptRoot "Templates"
    
    # Windows ADK paths (auto-detected)
    OscdimgPath = $null
    DismPath = "dism.exe"
    
    # Default settings
    DefaultWIMIndex = 3
    DefaultRetryCount = 3
    DefaultTimeoutSeconds = 3600
    
    # Workflow tracking
    WorkflowHistoryPath = Join-Path $PSScriptRoot "WorkflowHistory.json"
    MaxHistoryEntries = 100
    
    # Version info
    Version = "3.0.0"
    ConsolidatedModules = @("ISOManager v2.0.0", "ISOCustomizer v1.0.0")
}

# Auto-detect Windows ADK oscdimg path
if ($IsWindows) {
    $possiblePaths = @(
        "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe",
        "C:\Program Files\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe",
        "C:\Program Files (x86)\Windows Kits\11\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe",
        "C:\Program Files\Windows Kits\11\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $script:ModuleConfig.OscdimgPath = $path
            Write-CustomLog -Level 'DEBUG' -Message "Auto-detected oscdimg.exe at: $path"
            break
        }
    }
}

# Import all public functions
$PublicFunctions = @()
if (Test-Path (Join-Path $PSScriptRoot 'Public')) {
    Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public/*.ps1') -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            . $_.FullName
            $PublicFunctions += $_.BaseName
            Write-CustomLog -Level 'DEBUG' -Message "Loaded public function: $($_.BaseName)"
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to load public function $($_.BaseName): $_"
        }
    }
}

# Import all private functions
if (Test-Path (Join-Path $PSScriptRoot 'Private')) {
    Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private/*.ps1') -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            . $_.FullName
            Write-CustomLog -Level 'DEBUG' -Message "Loaded private function: $($_.BaseName)"
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to load private function $($_.BaseName): $_"
        }
    }
}

# Initialize workflow history if it doesn't exist
if (-not (Test-Path $script:ModuleConfig.WorkflowHistoryPath)) {
    try {
        $initialHistory = @{
            Version = $script:ModuleConfig.Version
            Created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Workflows = @()
        }
        $initialHistory | ConvertTo-Json -Depth 10 | Out-File -FilePath $script:ModuleConfig.WorkflowHistoryPath -Encoding UTF8
        Write-CustomLog -Level 'DEBUG' -Message "Initialized workflow history file"
    } catch {
        Write-CustomLog -Level 'WARNING' -Message "Failed to initialize workflow history: $_"
    }
}

# Create default repository if it doesn't exist
if (-not (Test-Path $script:ModuleConfig.DefaultRepositoryPath)) {
    try {
        Write-CustomLog -Level 'INFO' -Message "Creating default ISO repository at: $($script:ModuleConfig.DefaultRepositoryPath)"
        New-Item -ItemType Directory -Path $script:ModuleConfig.DefaultRepositoryPath -Force | Out-Null
        
        # Create repository structure
        $repoStructure = @('Windows', 'Linux', 'Custom', 'Metadata', 'Logs', 'Temp', 'Archive', 'Backup', 'Templates')
        foreach ($folder in $repoStructure) {
            New-Item -ItemType Directory -Path (Join-Path $script:ModuleConfig.DefaultRepositoryPath $folder) -Force | Out-Null
        }
        
        # Create repository configuration
        $repoConfig = @{
            Name = "Default-ISO-Repository"
            Description = "Default ISO repository created by ISOManagement module"
            Path = $script:ModuleConfig.DefaultRepositoryPath
            Created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Version = $script:ModuleConfig.Version
            ModuleVersion = $script:ModuleConfig.Version
            ConsolidatedFrom = $script:ModuleConfig.ConsolidatedModules
        }
        
        $configPath = Join-Path $script:ModuleConfig.DefaultRepositoryPath "repository.config.json"
        $repoConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $configPath -Encoding UTF8
        
        Write-CustomLog -Level 'INFO' -Message "Default repository created with configuration"
    } catch {
        Write-CustomLog -Level 'WARNING' -Message "Failed to create default repository: $_"
    }
}

# Export public functions
Export-ModuleMember -Function $PublicFunctions

# Module startup complete
Write-CustomLog -Level 'INFO' -Message "ISOManagement module v$($script:ModuleConfig.Version) loaded successfully"
Write-CustomLog -Level 'INFO' -Message "Consolidated modules: $($script:ModuleConfig.ConsolidatedModules -join ', ')"
Write-CustomLog -Level 'INFO' -Message "Default repository: $($script:ModuleConfig.DefaultRepositoryPath)"

# Display module information if verbose
if ($VerbosePreference -eq 'Continue') {
    Write-Host ""
    Write-Host "=== ISOManagement Module v$($script:ModuleConfig.Version) ===" -ForegroundColor Green
    Write-Host "Unified ISO lifecycle management system" -ForegroundColor White
    Write-Host ""
    Write-Host "Key Features:" -ForegroundColor Yellow
    Write-Host "  • Download ISOs from multiple sources" -ForegroundColor Gray
    Write-Host "  • Repository management with metadata" -ForegroundColor Gray
    Write-Host "  • ISO customization and deployment" -ForegroundColor Gray
    Write-Host "  • Integrated automation workflows" -ForegroundColor Gray
    Write-Host "  • Template management system" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Quick Start:" -ForegroundColor Yellow
    Write-Host "  Get-Help Start-ISOLifecycleWorkflow -Full" -ForegroundColor Cyan
    Write-Host "  New-DeploymentReadyISO -Help" -ForegroundColor Cyan
    Write-Host "  Get-ISOTemplateLibrary" -ForegroundColor Cyan
    Write-Host ""
}

# Export module configuration for use by functions
$script:ISOManagementConfig = $script:ModuleConfig