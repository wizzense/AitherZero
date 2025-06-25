#Requires -Version 7.0

<#
.SYNOPSIS
    Common test helper functions for OpenTofu Lab Automation example tests

.DESCRIPTION
    This module provides shared testing utilities and helper functions
    used across all example test files in the project.
#>

# Ensure environment variables are set for admin-friendly module discovery
if (-not $env:PWSH_MODULES_PATH) {
    $env:PWSH_MODULES_PATH = Join-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) "aither-core/modules"
}

if (-not $env:PROJECT_ROOT) {
    $env:PROJECT_ROOT = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
}

function Import-TestModule {
    <#
    .SYNOPSIS
        Safely imports a project module for testing
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        
        [switch]$Force
    )
    
    try {
        $modulePath = Join-Path $env:PWSH_MODULES_PATH $ModuleName
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force:$Force -ErrorAction Stop
            return $true
        } else {
            Write-Warning "Module not found: $modulePath"
            return $false
        }
    } catch {
        Write-Warning "Failed to import module $ModuleName`: $_"
        return $false
    }
}

function Test-ModuleStructure {
    <#
    .SYNOPSIS
        Tests if a module has the expected structure
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModulePath,
        
        [switch]$IncludePrivate
    )
    
    $result = [PSCustomObject]@{
        ModulePath = $ModulePath
        HasManifest = $false
        HasModuleFile = $false
        HasPublicFolder = $false
        HasPrivateFolder = $false
        IsValid = $false
        Issues = @()
    }
    
    if (-not (Test-Path $ModulePath)) {
        $result.Issues += "Module path does not exist: $ModulePath"
        return $result
    }
    
    # Check for manifest
    $manifestFiles = Get-ChildItem $ModulePath -Filter "*.psd1"
    if ($manifestFiles.Count -gt 0) {
        $result.HasManifest = $true
    }
    
    # Check for module file
    $moduleFiles = Get-ChildItem $ModulePath -Filter "*.psm1"
    if ($moduleFiles.Count -gt 0) {
        $result.HasModuleFile = $true
    }
    
    # Check for Public/Private folders
    $result.HasPublicFolder = Test-Path (Join-Path $ModulePath "Public")
    $result.HasPrivateFolder = Test-Path (Join-Path $ModulePath "Private")
    
    # Determine if module is valid
    $result.IsValid = $result.HasManifest -and $result.HasModuleFile -and $result.Issues.Count -eq 0
    
    return $result
}

function Test-PowerShellSyntax {
    <#
    .SYNOPSIS
        Tests PowerShell file for syntax errors
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    
    try {
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $FilePath -Raw), [ref]$errors)
        return @{
            IsValid = $errors.Count -eq 0
            Errors = $errors
            FilePath = $FilePath
        }
    } catch {
        return @{
            IsValid = $false
            Errors = @($_)
            FilePath = $FilePath
        }
    }
}

function Get-TestConfiguration {
    <#
    .SYNOPSIS
        Gets the test configuration for the project
    #>
    [CmdletBinding()]
    param()
      return @{
        ProjectRoot = $env:PROJECT_ROOT
        ModulesPath = $env:PWSH_MODULES_PATH
        TestsPath = Join-Path $env:PROJECT_ROOT "tests"
        PythonPath = Join-Path $env:PROJECT_ROOT "src/python"
        RequiredModules = @('LabRunner', 'PatchManager', 'Logging', 'TestingFramework')
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Import-TestModule',
    'Test-ModuleStructure', 
    'Test-PowerShellSyntax',
    'Get-TestConfiguration'
)