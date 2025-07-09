#Requires -Version 7.0

<#
.SYNOPSIS
    Standardized module import utility for AitherZero (SHARED UTILITY)

.DESCRIPTION
    This shared utility provides a standardized way to import modules across the AitherZero
    codebase, with consistent error handling, logging, and fallback mechanisms.

.PARAMETER ModuleName
    Name of the module to import (e.g., "Logging", "PatchManager")

.PARAMETER ModulePath
    Full path to the module directory (overrides ModuleName)

.PARAMETER Force
    Force reimport of the module

.PARAMETER Required
    Throw an error if the module cannot be imported

.PARAMETER Quiet
    Suppress informational messages

.PARAMETER ProjectRoot
    Project root path (will be detected if not provided)

.EXAMPLE
    # Import a core module:
    . "$PSScriptRoot/../../shared/Import-AitherModule.ps1"
    Import-AitherModule -ModuleName "Logging"

.EXAMPLE
    # Import multiple modules:
    Import-AitherModule -ModuleName "Logging", "PatchManager" -Required

.EXAMPLE
    # Import with specific path:
    Import-AitherModule -ModulePath "/path/to/CustomModule" -Force

.NOTES
    This utility:
    1. Provides consistent module import patterns
    2. Handles cross-platform path construction
    3. Includes proper error handling and logging
    4. Supports both single and batch imports
    5. Integrates with project structure detection

    Usage pattern for scripts:
    . "$PSScriptRoot/../../shared/Import-AitherModule.ps1"
    Import-AitherModule -ModuleName "Logging", "PatchManager"
#>

function Import-AitherModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [string[]]$ModuleName,

        [Parameter(Mandatory, ParameterSetName = 'ByPath')]
        [string]$ModulePath,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Required,

        [Parameter()]
        [switch]$Quiet,

        [Parameter()]
        [string]$ProjectRoot
    )

    begin {
        # Detect project root if not provided
        if (-not $ProjectRoot) {
            if (Test-Path "$PSScriptRoot/Find-ProjectRoot.ps1") {
                . "$PSScriptRoot/Find-ProjectRoot.ps1"
                $ProjectRoot = Find-ProjectRoot
            } else {
                # Fallback detection
                $currentPath = $PSScriptRoot
                while ($currentPath -and $currentPath -ne (Split-Path $currentPath -Parent)) {
                    if (Test-Path (Join-Path $currentPath "aither-core")) {
                        $ProjectRoot = $currentPath
                        break
                    }
                    $currentPath = Split-Path $currentPath -Parent
                }
            }
        }

        if (-not $ProjectRoot) {
            $errorMsg = "Could not detect project root. Please provide -ProjectRoot parameter."
            if ($Required) {
                throw $errorMsg
            } else {
                Write-Warning $errorMsg
                return
            }
        }

        $results = @()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByPath') {
            # Import by specific path
            $ModuleName = @(Split-Path $ModulePath -Leaf)
            $modulesToImport = @(@{
                Name = $ModuleName[0]
                Path = $ModulePath
            })
        } else {
            # Import by module name(s)
            $modulesToImport = $ModuleName | ForEach-Object {
                $moduleDir = Join-Path $ProjectRoot "aither-core" "modules" $_
                @{
                    Name = $_
                    Path = $moduleDir
                }
            }
        }

        foreach ($module in $modulesToImport) {
            try {
                $moduleName = $module.Name
                $modulePath = $module.Path

                # Check if module path exists
                if (-not (Test-Path $modulePath)) {
                    $errorMsg = "Module path not found: $modulePath"
                    if ($Required) {
                        throw $errorMsg
                    } else {
                        if (-not $Quiet) {
                            Write-Warning $errorMsg
                        }
                        $results += @{
                            ModuleName = $moduleName
                            Success = $false
                            Error = $errorMsg
                        }
                        continue
                    }
                }

                # Check if module is already imported (unless Force)
                if (-not $Force -and (Get-Module -Name $moduleName -ErrorAction SilentlyContinue)) {
                    if (-not $Quiet) {
                        Write-Verbose "Module '$moduleName' is already imported"
                    }
                    $results += @{
                        ModuleName = $moduleName
                        Success = $true
                        AlreadyImported = $true
                    }
                    continue
                }

                # Import the module
                $importParams = @{
                    Path = $modulePath
                    ErrorAction = 'Stop'
                }
                if ($Force) {
                    $importParams.Force = $true
                }

                Import-Module @importParams

                if (-not $Quiet) {
                    Write-Verbose "Successfully imported module: $moduleName"
                }

                $results += @{
                    ModuleName = $moduleName
                    Success = $true
                    Path = $modulePath
                }

            } catch {
                $errorMsg = "Failed to import module '$moduleName': $($_.Exception.Message)"
                if ($Required) {
                    throw $errorMsg
                } else {
                    if (-not $Quiet) {
                        Write-Warning $errorMsg
                    }
                    $results += @{
                        ModuleName = $moduleName
                        Success = $false
                        Error = $errorMsg
                    }
                }
            }
        }
    }

    end {
        # Return results for programmatic use
        if ($results.Count -eq 1) {
            return $results[0]
        } elseif ($results.Count -gt 1) {
            return $results
        }
    }
}

function Import-AitherModules {
    <#
    .SYNOPSIS
        Batch import multiple AitherZero modules with dependency resolution
    
    .DESCRIPTION
        Convenience function for importing multiple modules with automatic dependency resolution
        and proper error handling.
    
    .PARAMETER ModuleNames
        Array of module names to import
    
    .PARAMETER CommonModules
        Import commonly used modules (Logging, PatchManager, etc.)
    
    .PARAMETER Force
        Force reimport of modules
    
    .PARAMETER Required
        Throw error if any module fails to import
    
    .EXAMPLE
        Import-AitherModules -CommonModules
        Import-AitherModules -ModuleNames "Logging", "PatchManager", "DevEnvironment"
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$ModuleNames,

        [Parameter()]
        [switch]$CommonModules,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Required
    )

    if ($CommonModules) {
        $ModuleNames = @(
            "Logging",
            "PatchManager", 
            "DevEnvironment",
            "ParallelExecution",
            "TestingFramework"
        )
    }

    if (-not $ModuleNames) {
        throw "Either -ModuleNames or -CommonModules must be specified"
    }

    # Import modules in dependency order
    $dependencyOrder = @(
        "Logging",           # Base dependency
        "ParallelExecution", # Used by many modules
        "TestingFramework",  # Testing infrastructure
        "DevEnvironment",    # Development tools
        "PatchManager",      # Git operations
        "AIToolsIntegration", # AI tools
        "ConfigurationCarousel", # Configuration management
        "OrchestrationEngine", # Workflow execution
        "BackupManager",     # Backup operations
        "RemoteConnection",  # Remote operations
        "SystemMonitoring",  # System monitoring
        "SecureCredentials", # Credential management
        "SetupWizard",       # Setup processes
        "ISOManager",        # ISO operations
        "OpenTofuProvider",  # Infrastructure deployment
        "LabRunner"          # Lab automation
    )

    # Order modules by dependencies
    $orderedModules = @()
    foreach ($depModule in $dependencyOrder) {
        if ($ModuleNames -contains $depModule) {
            $orderedModules += $depModule
        }
    }

    # Add any remaining modules not in the dependency list
    foreach ($module in $ModuleNames) {
        if ($orderedModules -notcontains $module) {
            $orderedModules += $module
        }
    }

    # Import modules
    $results = @()
    foreach ($moduleName in $orderedModules) {
        $result = Import-AitherModule -ModuleName $moduleName -Force:$Force -Required:$Required
        $results += $result
    }

    return $results
}

# Export functions for use when this file is imported as a module
if ($MyInvocation.InvocationName -ne '.') {
    Export-ModuleMember -Function Import-AitherModule, Import-AitherModules
}