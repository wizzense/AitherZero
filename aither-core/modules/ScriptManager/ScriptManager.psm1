<#
.SYNOPSIS
Centralized management for one-off scripts in OpenTofu Lab Automation.

.DESCRIPTION
This module provides functions to register, validate, and execute one-off scripts.
It ensures scripts are integrated into the project framework without breaking dependencies.

#>

# Load all public functions
$PublicFunctions = Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue
foreach ($Function in $PublicFunctions) {
    try {
        . $Function.FullName
    } catch {
        Write-Error "Failed to load function $($Function.Name): $($_.Exception.Message)"
    }
}

# Load all private functions
$PrivateFunctions = Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue
foreach ($Function in $PrivateFunctions) {
    try {
        . $Function.FullName
    } catch {
        Write-Error "Failed to load function $($Function.Name): $($_.Exception.Message)"
    }
}

function Register-OneOffScript {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [string]$Description = "",

        [hashtable]$Parameters = @{},

        [switch]$Force
    )

    # Validate inputs
    if ([string]::IsNullOrWhiteSpace($ScriptPath)) {
        throw "ScriptPath cannot be null or empty"
    }

    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw "Name cannot be null or empty"
    }

    $MetadataFile = (Join-Path $PSScriptRoot "one-off-scripts.json")

    $scriptMetadata = @{
        ScriptPath = $ScriptPath
        Name = $Name
        Description = $Description
        Parameters = $Parameters
        RegisteredDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Executed = $false
        ExecutionDate = $null
        ExecutionResult = $null
    }

    if (-not (Test-Path $MetadataFile)) {
        $allScripts = [System.Collections.ArrayList]@()
    } else {
        $content = Get-Content $MetadataFile | ConvertFrom-Json
        $allScripts = [System.Collections.ArrayList]@($content)
    }

    $existingScript = $allScripts | Where-Object { $_.ScriptPath -eq $ScriptPath }

    if ($existingScript -and -not $Force) {
        Write-Host "Script already registered: $ScriptPath" -ForegroundColor Yellow
        return
    }

    if ($existingScript -and $Force) {
        # Remove existing script
        for ($i = $allScripts.Count - 1; $i -ge 0; $i--) {
            if ($allScripts[$i].ScriptPath -eq $ScriptPath) {
                $allScripts.RemoveAt($i)
                break
            }
        }
        Write-Host "Re-registering script: $ScriptPath" -ForegroundColor Cyan
    }

    $allScripts.Add($scriptMetadata) | Out-Null
    $allScripts | ConvertTo-Json -Depth 10 | Set-Content $MetadataFile

    Write-Host "Script registered successfully: $ScriptPath" -ForegroundColor Green
}

function Test-OneOffScript {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptPath
    )

    # Validate inputs
    if ([string]::IsNullOrWhiteSpace($ScriptPath)) {
        throw "ScriptPath cannot be null or empty"
    }

    $MetadataFile = (Join-Path $PSScriptRoot "one-off-scripts.json")

    if (-not (Test-Path $MetadataFile)) {
        Write-Warning "Metadata file not found: $MetadataFile"
        return $false
    }

    $allScripts = Get-Content $MetadataFile | ConvertFrom-Json
    $scriptMetadata = $allScripts | Where-Object { $_.ScriptPath -eq $ScriptPath }

    if (-not $scriptMetadata) {
        Write-Warning "Script '$ScriptPath' not found in metadata."
        return $false
    }

    if (-not (Test-Path $ScriptPath)) {
        Write-Warning "Script file not found: $ScriptPath"
        return $false
    }

    $content = Get-Content $ScriptPath -Raw
    if ($content -notmatch "Import-Module") {
        Write-Host "Script does not import required modules: $ScriptPath" -ForegroundColor Yellow
        return $false
    }

    if ($content -match "Invoke-ParallelScriptAnalyzer") {
        Write-Host "Script uses modern function: Invoke-ParallelScriptAnalyzer" -ForegroundColor Green
        return $true
    }

    Write-Host "Script uses deprecated function: Invoke-BatchScriptAnalysis" -ForegroundColor Red
    return $false
}

function Invoke-OneOffScript {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptPath,

        [hashtable]$Parameters = @{},
        [switch]$Force
    )

    # Validate inputs
    if ([string]::IsNullOrWhiteSpace($ScriptPath)) {
        throw "ScriptPath cannot be null or empty"
    }

    # Validate script file exists
    if (-not (Test-Path $ScriptPath)) {
        throw "Script file not found: $ScriptPath"
    }

    $MetadataFile = (Join-Path $PSScriptRoot "one-off-scripts.json")

    # Check if metadata file exists
    if (-not (Test-Path $MetadataFile)) {
        Write-Warning "Metadata file not found, creating empty metadata"
        @() | ConvertTo-Json | Set-Content $MetadataFile
    }

    $allScripts = Get-Content $MetadataFile | ConvertFrom-Json
    $script = $allScripts | Where-Object { $_.ScriptPath -eq $ScriptPath } # Use ScriptPath property

    if (-not $script) {
        # Auto-register script for one-off execution
        Write-Verbose "Script '$ScriptPath' not found in metadata, auto-registering for execution"
        Register-OneOffScript -ScriptPath $ScriptPath -Name "Auto-registered" -Description "Auto-registered for testing" -Force
        $allScripts = Get-Content $MetadataFile | ConvertFrom-Json
        $script = $allScripts | Where-Object { $_.ScriptPath -eq $ScriptPath }
    }

    if (-not $script) {
        Write-Error "Script '$ScriptPath' could not be registered or found."
        return
    }

    if ($script.Executed -and -not $Force) {
        Write-Error "Script '$ScriptPath' already executed. Use -Force to re-run."
        return
    }

    try {
        Write-Host "Executing script: $ScriptPath" -ForegroundColor Cyan

        # Execute script with parameters if provided
        if ($Parameters.Count -gt 0) {
            $result = & $ScriptPath @Parameters
        } else {
            $result = & $ScriptPath
        }

        $script.Executed = $true
        $script.ExecutionDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $script.ExecutionResult = "Success"
        Write-Host "Script executed successfully: $ScriptPath" -ForegroundColor Green

        return $result
    } catch {
        $script.ExecutionResult = "Failed: $($_.Exception.Message)"
        Write-Host "Script execution failed: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        $allScripts | ConvertTo-Json -Depth 10 | Set-Content $MetadataFile
    }
}

# ============================================================================
# SCRIPT MANAGEMENT COMPATIBILITY FUNCTIONS
# ============================================================================

# Import or create logging function
if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
    function Write-CustomLog {
        param([string]$Message, [string]$Level = "INFO")
        Write-Host "[$Level] $Message"
    }
}

function Get-ScriptRepository {
    <#
    .SYNOPSIS
        Gets information about the script repository

    .DESCRIPTION
        Retrieves information about available scripts and repository status

    .PARAMETER Path
        Path to script repository
    #>
    [CmdletBinding()]
    param(
        [string]$Path = (Join-Path $env:PROJECT_ROOT "aither-core/scripts")
    )

    Write-CustomLog -Message "📚 Retrieving script repository information" -Level "INFO"

    try {
        if (-not (Test-Path $Path)) {
            throw "Script repository path does not exist: $Path"
        }

        $scripts = Get-ChildItem -Path $Path -Filter "*.ps1" | ForEach-Object {
            @{
                Name = $_.BaseName
                FullName = $_.Name
                Path = $_.FullName
                Size = $_.Length
                LastModified = $_.LastWriteTime
                IsValid = Test-ModernScript -ScriptPath $_.FullName
            }
        }

        $repository = @{
            Path = $Path
            TotalScripts = $scripts.Count
            ValidScripts = ($scripts | Where-Object IsValid).Count
            Scripts = $scripts
            Status = 'Available'
        }

        Write-CustomLog -Message "✅ Found $($repository.TotalScripts) scripts in repository" -Level "INFO"
        return $repository
    } catch {
        Write-CustomLog -Message "❌ Failed to get script repository: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Start-ScriptExecution {
    <#
    .SYNOPSIS
        Starts execution of a specified script

    .DESCRIPTION
        Executes a script with specified parameters and monitoring

    .PARAMETER ScriptName
        Name of the script to execute

    .PARAMETER Parameters
        Parameters to pass to the script

    .PARAMETER Background
        Whether to run the script in background
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptName,

        [hashtable]$Parameters = @{},

        [switch]$Background
    )

    Write-CustomLog -Message "🚀 Starting script execution: $ScriptName" -Level "INFO"

    try {
        $scriptPath = Get-ChildItem -Path (Join-Path $env:PROJECT_ROOT "aither-core/scripts") -Filter "*$ScriptName*" | Select-Object -First 1

        if (-not $scriptPath) {
            throw "Script not found: $ScriptName"
        }

        if ($Background) {
            $job = Start-Job -ScriptBlock {
                param($Path, $Params)
                & $Path @Params
            } -ArgumentList $scriptPath.FullName, $Parameters

            $result = @{
                Status = 'Started'
                JobId = $job.Id
                ScriptPath = $scriptPath.FullName
                Background = $true
            }
        } else {
            Invoke-OneOffScript -ScriptPath $scriptPath.FullName
            $result = @{
                Status = 'Completed'
                ScriptPath = $scriptPath.FullName
                Background = $false
            }
        }

        Write-CustomLog -Message "✅ Script execution initiated successfully" -Level "SUCCESS"
        return $result
    } catch {
        Write-CustomLog -Message "❌ Script execution failed: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Get-ScriptTemplate {
    <#
    .SYNOPSIS
        Gets available script templates

    .DESCRIPTION
        Retrieves information about available script templates for creating new scripts

    .PARAMETER TemplateName
        Specific template name to retrieve
    #>
    [CmdletBinding()]
    param(
        [string]$TemplateName
    )

    Write-CustomLog -Message "📋 Retrieving script templates" -Level "INFO"

    try {
        $templates = @{
            'Basic' = @{
                Name = 'Basic PowerShell Script'
                Description = 'Simple PowerShell script template'
                Content = @'
#Requires -Version 7.0
param()

Write-Host "Script started" -ForegroundColor Green
# Your code here
Write-Host "Script completed" -ForegroundColor Green
'@
            }
            'Module' = @{
                Name = 'Module Function Script'
                Description = 'Script template for module functions'
                Content = @'
#Requires -Version 7.0
Import-Module Logging -Force

function Your-Function {
    param()
    Write-CustomLog -Message "Function executed" -Level "INFO"
}
'@
            }
            'Lab' = @{
                Name = 'Lab Automation Script'
                Description = 'Template for lab automation scripts'
                Content = @'
#Requires -Version 7.0
Import-Module LabRunner -Force

param(
    [switch]$WhatIf
)

Write-CustomLog -Message "Lab script started" -Level "INFO"
# Lab automation code here
Write-CustomLog -Message "Lab script completed" -Level "SUCCESS"
'@
            }
        }

        if ($TemplateName) {
            if ($templates.ContainsKey($TemplateName)) {
                return $templates[$TemplateName]
            } else {
                throw "Template not found: $TemplateName"
            }
        }

        Write-CustomLog -Message "✅ Retrieved $($templates.Count) script templates" -Level "INFO"
        return $templates
    } catch {
        Write-CustomLog -Message "❌ Failed to get script templates: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

# Export all functions for verification
Export-ModuleMember -Function @(
    'Register-OneOffScript',
    'Test-OneOffScript',
    'Invoke-OneOffScript',
    'Get-ScriptRepository',
    'Start-ScriptExecution',
    'Get-ScriptTemplate'
)
