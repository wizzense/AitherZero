function Get-ModuleDependencies {
    <#
    .SYNOPSIS
        Extracts module dependencies from manifest files
    .DESCRIPTION
        Reads module manifest files (.psd1) and extracts RequiredModules information
        to build a dependency graph for all modules in the AitherZero ecosystem
    .PARAMETER ModulePath
        Path to the modules directory. Defaults to aither-core/modules
    .PARAMETER IncludeOptional
        Include optional dependencies in the analysis
    .EXAMPLE
        Get-ModuleDependencies
        Returns a hashtable with module names as keys and arrays of dependencies as values
    .EXAMPLE
        Get-ModuleDependencies -IncludeOptional
        Returns dependencies including optional ones
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ModulePath = (Join-Path $PSScriptRoot "../modules"),

        [Parameter()]
        [switch]$IncludeOptional
    )

    process {
        try {
            Write-CustomLog -Message "Analyzing module dependencies in: $ModulePath" -Level 'INFO'
            
            $dependencyGraph = @{}
            
            # Get all module directories
            $moduleDirs = Get-ChildItem -Path $ModulePath -Directory -ErrorAction SilentlyContinue
            
            foreach ($moduleDir in $moduleDirs) {
                $manifestPath = Join-Path $moduleDir.FullName "$($moduleDir.Name).psd1"
                
                if (Test-Path $manifestPath) {
                    try {
                        # Import the manifest data
                        $manifestData = Import-PowerShellDataFile -Path $manifestPath -ErrorAction Stop
                        
                        $dependencies = @()
                        
                        # Extract RequiredModules
                        if ($manifestData.RequiredModules) {
                            if ($manifestData.RequiredModules -is [array]) {
                                foreach ($requiredModule in $manifestData.RequiredModules) {
                                    if ($requiredModule -is [hashtable]) {
                                        $dependencies += $requiredModule.ModuleName
                                    } else {
                                        $dependencies += $requiredModule
                                    }
                                }
                            } elseif ($manifestData.RequiredModules -is [string]) {
                                $dependencies += $manifestData.RequiredModules
                            }
                        }
                        
                        # Extract NestedModules if requested
                        if ($IncludeOptional -and $manifestData.NestedModules) {
                            if ($manifestData.NestedModules -is [array]) {
                                $dependencies += $manifestData.NestedModules
                            } elseif ($manifestData.NestedModules -is [string]) {
                                $dependencies += $manifestData.NestedModules
                            }
                        }
                        
                        # Add to dependency graph
                        $dependencyGraph[$moduleDir.Name] = @{
                            Dependencies = $dependencies
                            ManifestPath = $manifestPath
                            Version = $manifestData.ModuleVersion ?? '0.0.0'
                            Description = $manifestData.Description ?? ''
                        }
                        
                        Write-CustomLog -Message "Module $($moduleDir.Name): Found $($dependencies.Count) dependencies" -Level 'DEBUG'
                        
                    } catch {
                        Write-CustomLog -Message "Failed to parse manifest for $($moduleDir.Name): $($_.Exception.Message)" -Level 'WARNING'
                        # Still add the module but with no dependencies
                        $dependencyGraph[$moduleDir.Name] = @{
                            Dependencies = @()
                            ManifestPath = $manifestPath
                            Version = 'Unknown'
                            Description = 'Failed to parse manifest'
                            Error = $_.Exception.Message
                        }
                    }
                } else {
                    Write-CustomLog -Message "No manifest found for module: $($moduleDir.Name)" -Level 'WARNING'
                }
            }
            
            # Add special handling for Logging module (always first)
            if ($dependencyGraph.ContainsKey('Logging')) {
                $dependencyGraph['Logging'].Priority = 1
            }
            
            Write-CustomLog -Message "Dependency analysis complete. Found $($dependencyGraph.Count) modules" -Level 'INFO'
            return $dependencyGraph
            
        } catch {
            Write-CustomLog -Message "Failed to analyze module dependencies: $($_.Exception.Message)" -Level 'ERROR'
            throw
        }
    }
}