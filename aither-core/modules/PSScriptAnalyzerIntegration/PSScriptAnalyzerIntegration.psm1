# PSScriptAnalyzer Integration Module for AitherZero
# Provides comprehensive code quality analysis, auditing, and remediation

#Requires -Version 7.0
#Requires -Modules PSScriptAnalyzer

# Import shared utilities
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$script:ProjectRoot = Find-ProjectRoot

# Import all private functions
$privateFunctions = @(Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue)
foreach ($import in $privateFunctions) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error "Failed to import function $($import.FullName): $($_.Exception.Message)"
    }
}

# Import all public functions
$publicFunctions = @(Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue)
foreach ($import in $publicFunctions) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error "Failed to import function $($import.FullName): $($_.Exception.Message)"
    }
}

# Module variables
$script:ModuleName = 'PSScriptAnalyzerIntegration'
$script:ModuleVersion = '1.0.0'

# Configuration cache
$script:ConfigurationCache = @{}
$script:StatusCache = @{}

# Default settings
$script:DefaultSettings = @{
    StatusFileName = '.pssa-status'
    BugzFileName = '.bugz'
    ConfigFileName = '.pssa-config.json'
    GlobalConfigPath = Join-Path $script:ProjectRoot 'PSScriptAnalyzerSettings.psd1'
    ReportFormats = @('JSON', 'HTML', 'XML')
    MaxCacheAge = (New-TimeSpan -Hours 1)
    ParallelAnalysis = $true
    AutoRemediation = $false
    VerboseLogging = $false
}

# Quality thresholds
$script:QualityThresholds = @{
    ErrorThreshold = 0      # No errors allowed
    WarningThreshold = 10   # Max 10 warnings per module
    InfoThreshold = 50      # Max 50 info messages per module
    CoverageThreshold = 80  # 80% rule coverage required
}

# Severity mapping
$script:SeverityMapping = @{
    'Error' = 0
    'Warning' = 1
    'Information' = 2
    'Verbose' = 3
}

# Initialize logging if available
if (Get-Command 'Write-CustomLog' -ErrorAction SilentlyContinue) {
    $script:UseCustomLogging = $true
    Write-CustomLog -Level 'INFO' -Message "PSScriptAnalyzerIntegration module loaded successfully"
} else {
    $script:UseCustomLogging = $false
    Write-Verbose "PSScriptAnalyzerIntegration module loaded successfully"
}

# Module cleanup
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    # Clear caches
    $script:ConfigurationCache.Clear()
    $script:StatusCache.Clear()
    
    if ($script:UseCustomLogging) {
        Write-CustomLog -Level 'INFO' -Message "PSScriptAnalyzerIntegration module unloaded"
    } else {
        Write-Verbose "PSScriptAnalyzerIntegration module unloaded"
    }
}

# Export module variables for internal use
Export-ModuleMember -Variable 'ProjectRoot', 'ModuleName', 'ModuleVersion'