#Requires -Version 7.0

<#
.SYNOPSIS
    Dashboard Generation Module - Modular, focused dashboard generation
.DESCRIPTION
    Provides core dashboard generation functionality through composable functions.
    Designed to be called by automation scripts and playbooks for flexible dashboard creation.
.NOTES
    Copyright © 2025 Aitherium Corporation
    Module extracted from monolithic 0512_Generate-Dashboard.ps1 for better maintainability
#>

# Module-level variables
$script:DashboardConfig = @{}
$script:CollectedMetrics = @{}

#region Core Dashboard Functions

<#
.SYNOPSIS
    Initialize dashboard generation session
.DESCRIPTION
    Sets up configuration and prepares for metrics collection
#>
function Initialize-DashboardSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProjectPath,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [hashtable]$Configuration = @{}
    )
    
    $script:DashboardConfig = @{
        ProjectPath = $ProjectPath
        OutputPath = $OutputPath
        SessionStart = Get-Date
        Configuration = $Configuration
    }
    
    # Ensure output directory exists
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }
    
    Write-Verbose "Dashboard session initialized: $OutputPath"
    return $script:DashboardConfig
}

<#
.SYNOPSIS
    Register metrics data for dashboard inclusion
.DESCRIPTION
    Stores collected metrics for later processing and rendering
#>
function Register-DashboardMetrics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Category,
        
        [Parameter(Mandatory)]
        [hashtable]$Metrics
    )
    
    $script:CollectedMetrics[$Category] = $Metrics
    Write-Verbose "Registered metrics for category: $Category"
}

<#
.SYNOPSIS
    Get collected metrics by category
#>
function Get-DashboardMetrics {
    [CmdletBinding()]
    param(
        [string]$Category
    )
    
    if ($Category) {
        return $script:CollectedMetrics[$Category]
    }
    
    return $script:CollectedMetrics
}

<#
.SYNOPSIS
    Generate dashboard HTML from template and metrics
.DESCRIPTION
    Renders HTML dashboard using templates and collected metrics
#>
function New-DashboardHTML {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TemplateName,
        
        [Parameter(Mandatory)]
        [string]$OutputFile,
        
        [hashtable]$Data = @{}
    )
    
    $templatePath = Join-Path $script:DashboardConfig.ProjectPath "library/_templates/dashboard/$TemplateName.html"
    
    if (-not (Test-Path $templatePath)) {
        Write-Warning "Template not found: $templatePath"
        return $false
    }
    
    try {
        $template = Get-Content -Path $templatePath -Raw
        
        # Simple template variable replacement
        foreach ($key in $Data.Keys) {
            $template = $template -replace "\{\{$key\}\}", $Data[$key]
        }
        
        $outputPath = Join-Path $script:DashboardConfig.OutputPath $OutputFile
        $template | Out-File -FilePath $outputPath -Encoding utf8 -Force
        
        Write-Verbose "Generated HTML: $outputPath"
        return $true
    }
    catch {
        Write-Error "Failed to generate HTML from template: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Generate dashboard JSON for API/programmatic access
#>
function New-DashboardJSON {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OutputFile,
        
        [hashtable]$Data = @{}
    )
    
    try {
        $outputPath = Join-Path $script:DashboardConfig.OutputPath $OutputFile
        $Data | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputPath -Encoding utf8 -Force
        
        Write-Verbose "Generated JSON: $outputPath"
        return $true
    }
    catch {
        Write-Error "Failed to generate JSON: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Finalize dashboard generation session
.DESCRIPTION
    Completes dashboard generation and creates index/summary files
#>
function Complete-DashboardSession {
    [CmdletBinding()]
    param(
        [switch]$GenerateIndex
    )
    
    $sessionEnd = Get-Date
    $duration = $sessionEnd - $script:DashboardConfig.SessionStart
    
    $summary = @{
        SessionStart = $script:DashboardConfig.SessionStart
        SessionEnd = $sessionEnd
        Duration = $duration.TotalSeconds
        MetricsCollected = $script:CollectedMetrics.Keys.Count
        OutputPath = $script:DashboardConfig.OutputPath
    }
    
    if ($GenerateIndex) {
        New-DashboardJSON -OutputFile "dashboard-session.json" -Data $summary
    }
    
    Write-Verbose "Dashboard session completed in $($duration.TotalSeconds) seconds"
    return $summary
}

#endregion

#region Metrics Collection Helpers

<#
.SYNOPSIS
    Load metrics from JSON file
#>
function Import-MetricsFromJSON {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        
        [Parameter(Mandatory)]
        [string]$Category
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Warning "Metrics file not found: $FilePath"
        return @{}
    }
    
    try {
        $metrics = Get-Content -Path $FilePath -Raw | ConvertFrom-Json -AsHashtable
        Register-DashboardMetrics -Category $Category -Metrics $metrics
        return $metrics
    }
    catch {
        Write-Error "Failed to import metrics from $FilePath : $_"
        return @{}
    }
}

<#
.SYNOPSIS
    Aggregate test results from multiple sources
#>
function Get-AggregatedTestResults {
    [CmdletBinding()]
    param(
        [string]$TestResultsPath
    )
    
    $aggregated = @{
        TotalTests = 0
        PassedTests = 0
        FailedTests = 0
        SkippedTests = 0
        Duration = 0
        Coverage = 0
        ResultFiles = @()
    }
    
    if (Test-Path $TestResultsPath) {
        $resultFiles = Get-ChildItem -Path $TestResultsPath -Filter "*.xml" -Recurse
        
        foreach ($file in $resultFiles) {
            # Parse NUnit XML or other test result formats
            # This is a placeholder - actual implementation would parse XML
            $aggregated.ResultFiles += $file.FullName
        }
    }
    
    return $aggregated
}

#endregion

# Export module members
Export-ModuleMember -Function @(
    'Initialize-DashboardSession'
    'Register-DashboardMetrics'
    'Get-DashboardMetrics'
    'New-DashboardHTML'
    'New-DashboardJSON'
    'Complete-DashboardSession'
    'Import-MetricsFromJSON'
    'Get-AggregatedTestResults'
)
