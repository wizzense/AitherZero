#Requires -Version 7.0

<#
.SYNOPSIS
    Common test helper functions for OpenTofu Lab Automation unit tests

.DESCRIPTION
    This module provides shared testing utilities and helper functions
    used across all unit test files in the project.
#>

# Ensure environment variables are set using shared utilities
. "$PSScriptRoot/../../../../aither-core/shared/Find-ProjectRoot.ps1"
$script:ProjectRoot = Find-ProjectRoot

if (-not $env:PWSH_MODULES_PATH) {
    $env:PWSH_MODULES_PATH = Join-Path $script:ProjectRoot "aither-core/modules"
}

if (-not $env:PROJECT_ROOT) {
    $env:PROJECT_ROOT = $script:ProjectRoot
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
        Functions = @{
            Exported = @()
            Public = @()
            Private = @()
        }
    }

    if (-not (Test-Path $ModulePath)) {
        $result.Issues += "Module path does not exist: $ModulePath"
        return $result
    }

    # Check for manifest
    $manifestFiles = Get-ChildItem $ModulePath -Filter "*.psd1"
    if ($manifestFiles.Count -gt 0) {
        $result.HasManifest = $true

        # Test manifest validity
        try {
            Test-ModuleManifest $manifestFiles[0].FullName -ErrorAction Stop | Out-Null
        }
        catch {
            $result.Issues += "Invalid module manifest: $($_.Exception.Message)"
        }
    }

    # Check for module file
    $moduleFiles = Get-ChildItem $ModulePath -Filter "*.psm1"
    if ($moduleFiles.Count -gt 0) {
        $result.HasModuleFile = $true
    }

    # Check for Public/Private folders
    $result.HasPublicFolder = Test-Path (Join-Path $ModulePath "Public")
    $result.HasPrivateFolder = Test-Path (Join-Path $ModulePath "Private")

    # Test module import and get functions
    $moduleName = Split-Path $ModulePath -Leaf
    try {
        Import-Module $ModulePath -Force -ErrorAction Stop
        $module = Get-Module $moduleName -ErrorAction SilentlyContinue

        if ($module) {
            $exportedCommands = Get-Command -Module $module.Name -CommandType Function -ErrorAction SilentlyContinue
            $result.Functions.Exported = $exportedCommands | ForEach-Object { $_.Name }

            # Get public functions from files
            $publicPath = Join-Path $ModulePath "Public"
            if (Test-Path $publicPath) {
                $publicFiles = Get-ChildItem $publicPath -Filter "*.ps1"
                $result.Functions.Public = $publicFiles | ForEach-Object { $_.BaseName }
            }

            # Get private functions from files
            if ($IncludePrivate) {
                $privatePath = Join-Path $ModulePath "Private"
                if (Test-Path $privatePath) {
                    $privateFiles = Get-ChildItem $privatePath -Filter "*.ps1"
                    $result.Functions.Private = $privateFiles | ForEach-Object { $_.BaseName }
                }
            }

            # Clean up
            Remove-Module $module.Name -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        $result.Issues += "Module failed to import: $($_.Exception.Message)"
    }

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

# Note: Export-ModuleMember only works in module files (.psm1)
# These functions are available when dot-sourcing this file
