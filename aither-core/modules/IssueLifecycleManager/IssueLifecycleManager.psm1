#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    IssueLifecycleManager - Automated GitHub issue lifecycle management
    
.DESCRIPTION
    This module provides comprehensive automated issue lifecycle management including:
    - Automatic issue creation from various sources
    - Issue status tracking and updates
    - Automatic closure of resolved issues
    - Dependency tracking between issues
    - Assignment based on CODEOWNERS
    - Complete audit trail
    - Metrics and reporting
#>

# Module initialization
$script:ModuleName = "IssueLifecycleManager"
$script:ProjectRoot = Split-Path -Path $PSScriptRoot -Parent -Parent -Parent
$script:ConfigPath = Join-Path $script:ProjectRoot ".claude/issue-lifecycle-config.json"
$script:AuditLogPath = Join-Path $script:ProjectRoot "logs/issue-lifecycle-audit.json"
$script:MetricsPath = Join-Path $script:ProjectRoot "logs/issue-metrics.json"

# Import required modules
Import-Module (Join-Path $script:ProjectRoot "aither-core/modules/Logging") -Force

# Load configuration
$script:Config = if (Test-Path $script:ConfigPath) {
    Get-Content $script:ConfigPath | ConvertFrom-Json
} else {
    @{
        autoClose = @{
            enabled = $true
            checkInterval = 3600  # 1 hour
            resolutionPatterns = @(
                'fixes #(\d+)',
                'resolves #(\d+)',
                'closes #(\d+)'
            )
        }
        assignment = @{
            useCodeOwners = $true
            autoAssign = $true
            defaultAssignee = $null
        }
        labeling = @{
            autoApply = $true
            severityLabels = $true
            categoryLabels = $true
            stateLabels = $true
        }
        metrics = @{
            trackResolutionTime = $true
            trackAssignmentTime = $true
            generateReports = $true
        }
    }
}

# Initialize metrics tracking
$script:Metrics = @{
    IssuesCreated = 0
    IssuesClosed = 0
    AverageResolutionTime = 0
    IssuesByCategory = @{}
    IssuesBySeverity = @{}
    ActiveIssues = @()
}

# Load module functions
$publicFunctions = Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue
$privateFunctions = Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue

foreach ($function in ($publicFunctions + $privateFunctions)) {
    try {
        . $function.FullName
    } catch {
        Write-Error "Failed to load function $($function.Name): $_"
    }
}

# Export public functions
Export-ModuleMember -Function $publicFunctions.BaseName

# Module initialization complete
Write-CustomLog -Level INFO -Message "$script:ModuleName module loaded successfully"