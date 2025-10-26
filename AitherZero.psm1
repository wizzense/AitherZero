#Requires -Version 7.0
<#
.SYNOPSIS
    AitherZero root module that loads all nested modules
.DESCRIPTION
    Aitherium™ Enterprise Infrastructure Automation Platform
    AitherZero - Imports all modules and re-exports their functions

.NOTES
    Copyright © 2025 Aitherium Corporation
    Version: 1.0.0
#>

# Set environment variables
$env:AITHERZERO_ROOT = $PSScriptRoot
$env:AITHERZERO_INITIALIZED = "1"

# Transcript logging configuration (can be disabled via environment variable)
$script:TranscriptEnabled = if ($env:AITHERZERO_DISABLE_TRANSCRIPT -eq '1') { $false } else { $true }

# Start PowerShell transcription for complete activity logging (if enabled)
if ($script:TranscriptEnabled) {
    $transcriptPath = Join-Path $PSScriptRoot "logs/transcript-$(Get-Date -Format 'yyyy-MM-dd').log"
    $logsDir = Split-Path $transcriptPath -Parent
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }

    try {
        # Try to start transcript, stop any existing one first
        try { Stop-Transcript -ErrorAction Stop | Out-Null } catch { }
        Start-Transcript -Path $transcriptPath -Append -IncludeInvocationHeader | Out-Null
    } catch {
        # Transcript functionality not available or failed
    }
}

# Add automation scripts to PATH
$automationPath = Join-Path $PSScriptRoot "automation-scripts"
$pathSeparator = [IO.Path]::PathSeparator
if ($env:PATH -notlike "*$automationPath*") {
    $env:PATH = "$automationPath$pathSeparator$env:PATH"
}

# Import all nested modules and re-export their functions
$modulesToLoad = @(
    # Core utilities first
    './domains/utilities/Logging.psm1',

    # Configuration
    './domains/configuration/Configuration.psm1',

    # User interface (BetterMenu first, then UserInterface)
    './domains/experience/BetterMenu.psm1',
    './domains/experience/UserInterface.psm1',

    # Development tools
    './domains/development/GitAutomation.psm1',
    './domains/development/IssueTracker.psm1',
    './domains/development/PullRequestManager.psm1',

    # Testing (Legacy and New)
    './domains/testing/TestingFramework.psm1',
    './domains/testing/AitherTestFramework.psm1',
    './domains/testing/CoreTestSuites.psm1',

    # Reporting
    './domains/reporting/ReportingEngine.psm1',
    './domains/reporting/TechDebtAnalysis.psm1',

    # Automation (exports Invoke-OrchestrationSequence)
    './domains/automation/OrchestrationEngine.psm1',
    './domains/automation/DeploymentAutomation.psm1',

    # Infrastructure
    './domains/infrastructure/Infrastructure.psm1',
    
    # Documentation
    './domains/documentation/DocumentationEngine.psm1'
)

# Parallel module loading for better performance
$jobs = @()
$loadedModules = [System.Collections.Concurrent.ConcurrentBag[string]]::new()

# Load critical modules first (synchronously)
$criticalModules = @(
    './domains/utilities/Logging.psm1',
    './domains/configuration/Configuration.psm1'
)

foreach ($modulePath in $criticalModules) {
    $fullPath = Join-Path $PSScriptRoot $modulePath
    if (Test-Path $fullPath) {
        try {
            Import-Module $fullPath -Force -Global -ErrorAction Stop
        } catch {
            Write-Error "Failed to load critical module: $modulePath - $_"
        }
    }
}

# Load remaining modules sequentially (parallel loading doesn't work well with module scope)
$parallelModules = $modulesToLoad | Where-Object { $_ -notin $criticalModules }

foreach ($modulePath in $parallelModules) {
    $fullPath = Join-Path $PSScriptRoot $modulePath
    if (Test-Path $fullPath) {
        try {
            Import-Module $fullPath -Force -Global -ErrorAction Stop
        } catch {
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Level 'Warning' -Message "Failed to load module: $modulePath" -Source "ModuleLoader" -Data @{ Error = $_.ToString() }
            } else {
                Write-Warning "Failed to load module: $modulePath - $_"
            }
        }
    }
}

# Create the az/Invoke-AitherScript function with dynamic parameters
function global:Invoke-AitherScript {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$ScriptNumber
    )

    DynamicParam {
        $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        # Common parameters that many scripts accept
        $commonParams = @{
            'Path' = [string]
            'OutputPath' = [string]
            'DryRun' = [switch]
            'PassThru' = [switch]
            'NoCoverage' = [switch]
            'CI' = [switch]
            'UseCache' = [switch]
            'ForceRun' = [switch]
            'CacheMinutes' = [int]
            'CoverageThreshold' = [int]
            'ShowAll' = [switch]
            'NonInteractive' = [switch]
            'Force' = [switch]
            'Type' = [string]
            'Name' = [string]
            'Message' = [string]
            'Title' = [string]
            'All' = [switch]
            'Strict' = [switch]
            'AutoFix' = [switch]
            'CheckDependencies' = [switch]
            'CheckSecrets' = [switch]
            'CheckDeprecated' = [switch]
            'CheckBestPractices' = [switch]
            'OutputFormat' = [string]
            'InstallDependencies' = [switch]
            'WorkflowFile' = [string]
            'Event' = [string]
            'Job' = [string]
            'VerboseOutput' = [switch]
            'NoCache' = [switch]
        }

        foreach ($paramName in $commonParams.Keys) {
            $paramType = $commonParams[$paramName]
            $paramAttribute = New-Object System.Management.Automation.ParameterAttribute
            $paramAttribute.Mandatory = $false

            $attributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $attributeCollection.Add($paramAttribute)

            $param = New-Object System.Management.Automation.RuntimeDefinedParameter($paramName, $paramType, $attributeCollection)
            $paramDictionary.Add($paramName, $param)
        }

        return $paramDictionary
    }

    Process {
        # Capture all parameters including dynamic ones
        $allParams = @{}
        foreach ($key in $PSBoundParameters.Keys) {
            if ($key -ne 'ScriptNumber') {
                $allParams[$key] = $PSBoundParameters[$key]
            }
        }

        # Pass global Config as Configuration if it exists and not already specified
        if ($global:Config -and -not $allParams.ContainsKey('Configuration')) {
            $allParams['Configuration'] = $global:Config
        }

        $scriptPath = Join-Path $env:AITHERZERO_ROOT "automation-scripts"
        $scripts = Get-ChildItem -Path $scriptPath -Filter "${ScriptNumber}*.ps1" -ErrorAction SilentlyContinue

        if ($scripts.Count -eq 0) {
            Write-Error "No script found matching pattern: ${ScriptNumber}*.ps1"
            return
        } elseif ($scripts.Count -gt 1) {
            Write-Host "Multiple scripts found:" -ForegroundColor Yellow
            $scripts | ForEach-Object { Write-Host "  $_" }
            return
        }

        # Execute the script with all parameters
        $scriptFile = $scripts[0].FullName

        if ($allParams.Count -gt 0) {
            & $scriptFile @allParams
        } else {
            & $scriptFile
        }
    }
}

# Set up aliases
Set-Alias -Name 'az' -Value 'Invoke-AitherScript' -Scope Global -Force

# Export the main function
Export-ModuleMember -Function 'Invoke-AitherScript' -Alias 'az'