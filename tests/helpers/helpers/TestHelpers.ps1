#Requires -Version 7.0

<#
.SYNOPSIS
    Common test helper functions for OpenTofu Lab Automation helpers tests

.DESCRIPTION
    This module provides shared testing utilities and helper functions
    used across test files in the helpers directory.
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
    'Test-PowerShellSyntax',
    'Get-TestConfiguration'
)
