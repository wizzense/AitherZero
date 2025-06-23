<#
.SYNOPSIS
Centralized management for one-off scripts in OpenTofu Lab Automation.

.DESCRIPTION
This module provides functions to register, validate, and execute one-off scripts.
It ensures scripts are integrated into the project framework without breaking dependencies.

#>

function Register-OneOffScript {
    param(
        [string]$ScriptPath,
        [string]$Purpose,
        [string]$Author,
        [switch]$Force
    )

    $MetadataFile = (Join-Path (Get-Location) "scripts/one-off-scripts.json")

    $scriptMetadata = @{
        ScriptPath = $ScriptPath
        Purpose = $Purpose
        Author = $Author
        RegisteredDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Executed = $false
        ExecutionDate = $null
        ExecutionResult = $null
    }

    if (-not (Test-Path $MetadataFile)) {
        $allScripts = @()
    } else {
        $allScripts = Get-Content $MetadataFile  ConvertFrom-Json
    }

    $existingScript = $allScripts | Where-Object { $_.ScriptPath -eq $ScriptPath }

    if ($existingScript -and -not $Force) {
        Write-Host "Script already registered: $ScriptPath" -ForegroundColor Yellow
        return
    }

    if ($existingScript -and $Force) {
        $allScripts = $allScripts | Where-Object { $_.ScriptPath -ne $ScriptPath }
        Write-Host "Re-registering script: $ScriptPath" -ForegroundColor Cyan
    }

    $allScripts += $scriptMetadata
    $allScripts | ConvertTo-Json -Depth 10 | Set-Content $MetadataFile

    Write-Host "Script registered successfully: $ScriptPath" -ForegroundColor Green
}

function Test-OneOffScript {
    param(
        [string]$ScriptPath
    )

    $MetadataFile = (Join-Path $PSScriptRoot "one-off-scripts.json") # Corrected path and ensure usage

    if (-not (Test-Path $MetadataFile)) {
        Write-Warning "Metadata file not found: $MetadataFile"
        return $false
    }

    $allScripts = Get-Content $MetadataFile | ConvertFrom-Json
    $scriptMetadata = $allScripts | Where-Object { $_.Path -eq $ScriptPath }

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
        [string]$ScriptPath,
        [switch]$Force
    )

    $MetadataFile = (Join-Path $PSScriptRoot "one-off-scripts.json") # Corrected path

    $allScripts = Get-Content $MetadataFile | ConvertFrom-Json
    $script = $allScripts | Where-Object { $_.Path -eq $ScriptPath } # Corrected property name

    if (-not $script) {
        Write-Error "Script '$ScriptPath' not found in metadata."
        return
    }

    if ($script.Executed -and -not $Force) {
        Write-Error "Script '$ScriptPath' already executed. Use -Force to re-run."
        return
    }

    try {
        Write-Host "Executing script: $ScriptPath" -ForegroundColor Cyan
        & $ScriptPath
        $script.Executed = $true
        $script.ExecutionDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $script.ExecutionResult = "Success"
        Write-Host "Script executed successfully: $ScriptPath" -ForegroundColor Green
    } catch {
        $script.ExecutionResult = "Failed: $($_.Exception.Message)"
        Write-Host "Script execution failed: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        $allScripts | ConvertTo-Json -Depth 10 | Set-Content $MetadataFile
    }
}
