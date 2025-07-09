function Import-CoreModulesParallel {
    <#
    .SYNOPSIS
        Imports all available CoreApp modules with parallel loading for improved performance
    .DESCRIPTION
        Dynamically discovers and imports modules using parallel execution for modules
        at the same dependency depth. Uses topological sorting to ensure dependencies
        are loaded before dependent modules. Logging module is always loaded first.
    .PARAMETER RequiredOnly
        Import only modules marked as required
    .PARAMETER Force
        Force reimport of modules
    .PARAMETER MaxParallel
        Maximum number of modules to load in parallel (default: ProcessorCount)
    .PARAMETER UseLegacyMode
        Fall back to sequential loading if parallel loading fails
    .EXAMPLE
        Import-CoreModulesParallel
        Loads all modules using parallel execution where possible
    .EXAMPLE
        Import-CoreModulesParallel -RequiredOnly -MaxParallel 4
        Loads only required modules with max 4 parallel operations
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$RequiredOnly,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [int]$MaxParallel = [Environment]::ProcessorCount,

        [Parameter()]
        [switch]$UseLegacyMode
    )

    process {
        $importResults = @{
            ImportedCount = 0
            FailedCount = 0
            SkippedCount = 0
            Details = @()
            LoadOrder = @()
            DependencyInfo = $null
            StartTime = Get-Date
            ParallelGroups = @()
        }

        try {
            # CRITICAL: Ensure Logging module is loaded and Write-CustomLog is available
            $loggingModule = $script:CoreModules | Where-Object { $_.Name -eq 'Logging' } | Select-Object -First 1
            
            # Check if Logging module is already loaded and Write-CustomLog is available
            $loggingAlreadyLoaded = $false
            $writeCustomLogAvailable = Get-Command Write-CustomLog -ErrorAction SilentlyContinue
            $existingLoggingModule = Get-Module -Name 'Logging' -ErrorAction SilentlyContinue
            
            if ($writeCustomLogAvailable -and $existingLoggingModule) {
                Write-CustomLog -Message "✓ Logging module already loaded and Write-CustomLog available" -Level 'SUCCESS'
                $loggingAlreadyLoaded = $true
                
                # Register in LoadedModules if not already registered
                if (-not $script:LoadedModules.ContainsKey('Logging')) {
                    $script:LoadedModules['Logging'] = @{
                        Path = $existingLoggingModule.Path
                        ImportTime = Get-Date
                        Description = $loggingModule.Description
                    }
                }
            }
            
            # If Logging module is not properly loaded, load it now
            if (-not $loggingAlreadyLoaded) {
                if ($loggingModule) {
                    $loggingPath = Join-Path $PSScriptRoot "../$($loggingModule.Path)"
                    if (Test-Path $loggingPath) {
                        try {
                            Write-Verbose "Loading Logging module from: $loggingPath"
                            Import-Module $loggingPath -Force -Global -ErrorAction Stop
                            
                            # Ensure the module is properly registered in the module table
                            $loadedModule = Get-Module -Name 'Logging'
                            if (-not $loadedModule) {
                                throw "Logging module not properly registered after import"
                            }
                            $script:LoadedModules['Logging'] = @{
                                Path = $loggingPath
                                ImportTime = Get-Date
                                Description = $loggingModule.Description
                            }
                            $importResults.ImportedCount++
                            $importResults.Details += @{
                                Name = 'Logging'
                                Status = 'Success'
                                Message = $loggingModule.Description
                                LoadTime = (Get-Date) - $importResults.StartTime
                            }
                            
                            # Verify Write-CustomLog is available
                            if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
                                throw "Write-CustomLog command not found after loading Logging module"
                            }
                            
                            Write-CustomLog -Message "✓ Logging module loaded successfully" -Level 'SUCCESS'
                        } catch {
                            # If Logging module fails, we can't use Write-CustomLog, so use Write-Host
                            Write-Host "[ERROR] Failed to load Logging module: $_" -ForegroundColor Red
                            throw "Critical: Unable to load Logging module - $_"
                        }
                    } else {
                        Write-Host "[ERROR] Logging module path not found: $loggingPath" -ForegroundColor Red
                        throw "Critical: Logging module path not found"
                    }
                } else {
                    Write-Host "[ERROR] Logging module not found in module registry" -ForegroundColor Red
                    throw "Critical: Logging module not found in registry"
                }
            }
            
            # Get modules to import based on RequiredOnly flag (excluding Logging since it's already loaded)
            $requestedModules = if ($RequiredOnly) {
                $script:CoreModules | Where-Object { $_.Required -and $_.Name -ne 'Logging' } | Select-Object -ExpandProperty Name
            } else {
                $script:CoreModules | Where-Object { $_.Name -ne 'Logging' } | Select-Object -ExpandProperty Name
            }

            Write-CustomLog -Message "Preparing to import $($requestedModules.Count) remaining modules in parallel mode..." -Level 'INFO'

            # Get module dependencies
            $dependencyGraph = Get-ModuleDependencies -ModulePath (Join-Path $PSScriptRoot "../modules")
            
            # Remove Logging from dependency graph since it's already loaded
            if ($dependencyGraph.ContainsKey('Logging')) {
                $dependencyGraph.Remove('Logging') | Out-Null
            }
            
            # Also remove Logging from any module's dependencies
            foreach ($module in $dependencyGraph.Keys) {
                if ($dependencyGraph[$module] -contains 'Logging') {
                    $dependencyGraph[$module] = $dependencyGraph[$module] | Where-Object { $_ -ne 'Logging' }
                }
            }
            
            # Resolve load order
            $loadOrderResult = Resolve-ModuleLoadOrder -DependencyGraph $dependencyGraph -ModulesToLoad $requestedModules
            
            $importResults.LoadOrder = $loadOrderResult.LoadOrder
            $importResults.DependencyInfo = $loadOrderResult
            
            # Group modules by dependency depth for parallel loading
            $depthGroups = @{}
            foreach ($module in $loadOrderResult.LoadOrder) {
                $depth = $loadOrderResult.DependencyDepth[$module]
                if (-not $depthGroups.ContainsKey($depth)) {
                    $depthGroups[$depth] = @()
                }
                $depthGroups[$depth] += $module
            }
            
            # Sort depths to process in order
            $sortedDepths = $depthGroups.Keys | Sort-Object
            
            Write-CustomLog -Message "Identified $($sortedDepths.Count) dependency levels for parallel loading" -Level 'INFO'
            
            # Process each dependency level
            foreach ($depth in $sortedDepths) {
                $modulesAtDepth = $depthGroups[$depth]
                $importResults.ParallelGroups += @{
                    Depth = $depth
                    Modules = $modulesAtDepth
                    Count = $modulesAtDepth.Count
                }
                
                Write-CustomLog -Message "Loading dependency level $depth with $($modulesAtDepth.Count) module(s): $($modulesAtDepth -join ', ')" -Level 'INFO'
                
                if ($modulesAtDepth.Count -eq 1 -or $UseLegacyMode) {
                    # Single module or legacy mode - load sequentially
                    foreach ($moduleName in $modulesAtDepth) {
                        $result = Import-SingleModule -ModuleName $moduleName -Force:$Force
                        Update-ImportResults -ImportResults $importResults -ModuleResult $result
                    }
                } else {
                    # Multiple modules at same depth - load in parallel
                    try {
                        # Prepare module information for parallel processing
                        $moduleInfoList = @()
                        foreach ($moduleName in $modulesAtDepth) {
                            $moduleInfo = $script:CoreModules | Where-Object { $_.Name -eq $moduleName } | Select-Object -First 1
                            if ($moduleInfo) {
                                $moduleInfoList += @{
                                    Name = $moduleName
                                    Path = Join-Path $PSScriptRoot "../$($moduleInfo.Path)"
                                    Description = $moduleInfo.Description
                                    Force = $Force
                                    AlreadyLoaded = $script:LoadedModules.ContainsKey($moduleName)
                                }
                            }
                        }
                        
                        # Import ParallelExecution module if available and not already loaded
                        $parallelAvailable = $false
                        if (-not (Get-Module -Name 'ParallelExecution' -ErrorAction SilentlyContinue)) {
                            $parallelExecPath = Join-Path $PSScriptRoot "../modules/ParallelExecution"
                            if (Test-Path $parallelExecPath) {
                                try {
                                    Import-Module $parallelExecPath -Force -Global -ErrorAction Stop
                                    $parallelAvailable = $true
                                } catch {
                                    Write-CustomLog -Message "Failed to load ParallelExecution module: $_" -Level 'WARNING'
                                }
                            }
                        } else {
                            $parallelAvailable = $true
                        }
                        
                        if ($parallelAvailable -and (Get-Command Invoke-ParallelForEach -ErrorAction SilentlyContinue)) {
                            # Use ParallelExecution module with Logging module available in each runspace
                            $loggingModulePath = $null
                            $loggingLoadedModule = Get-Module -Name 'Logging'
                            if ($loggingLoadedModule) {
                                $loggingModulePath = $loggingLoadedModule.Path
                            }
                            
                            $parallelResults = Invoke-ParallelForEach -InputObject $moduleInfoList -ThrottleLimit $MaxParallel -ScriptBlock {
                                param($moduleInfo)
                                
                                # Import Logging module in this runspace to make Write-CustomLog available
                                if ($using:loggingModulePath -and (Test-Path $using:loggingModulePath)) {
                                    try {
                                        Import-Module $using:loggingModulePath -Force -Global -ErrorAction SilentlyContinue
                                    } catch {
                                        # If Logging import fails in runspace, continue without it
                                    }
                                }
                                
                                $result = @{
                                    Name = $moduleInfo.Name
                                    Status = 'Unknown'
                                    Message = ''
                                    LoadTime = $null
                                }
                                
                                try {
                                    if ($moduleInfo.AlreadyLoaded -and -not $moduleInfo.Force) {
                                        $result.Status = 'Skipped'
                                        $result.Message = 'Already loaded'
                                    } elseif (-not (Test-Path $moduleInfo.Path)) {
                                        $result.Status = 'Failed'
                                        $result.Message = 'Path not found'
                                    } else {
                                        $startTime = Get-Date
                                        Import-Module $moduleInfo.Path -Force:$moduleInfo.Force -Global -ErrorAction Stop
                                        $result.Status = 'Success'
                                        $result.Message = $moduleInfo.Description
                                        $result.LoadTime = (Get-Date) - $startTime
                                    }
                                } catch {
                                    $result.Status = 'Failed'
                                    $result.Message = $_.Exception.Message
                                }
                                
                                return $result
                            }
                            
                            # Process parallel results
                            foreach ($result in $parallelResults) {
                                Update-ImportResults -ImportResults $importResults -ModuleResult $result
                                
                                # Update loaded modules tracking
                                if ($result.Status -eq 'Success') {
                                    $moduleInfo = $moduleInfoList | Where-Object { $_.Name -eq $result.Name } | Select-Object -First 1
                                    if ($moduleInfo) {
                                        $script:LoadedModules[$result.Name] = @{
                                            Path = $moduleInfo.Path
                                            ImportTime = Get-Date
                                            Description = $moduleInfo.Description
                                        }
                                    }
                                }
                            }
                        } else {
                            # Fallback to PowerShell native parallel if ParallelExecution not available
                            $parallelResults = $moduleInfoList | ForEach-Object -Parallel {
                                $moduleInfo = $_
                                $result = @{
                                    Name = $moduleInfo.Name
                                    Status = 'Unknown'
                                    Message = ''
                                    LoadTime = $null
                                }
                                
                                try {
                                    if ($moduleInfo.AlreadyLoaded -and -not $moduleInfo.Force) {
                                        $result.Status = 'Skipped'
                                        $result.Message = 'Already loaded'
                                    } elseif (-not (Test-Path $moduleInfo.Path)) {
                                        $result.Status = 'Failed'
                                        $result.Message = 'Path not found'
                                    } else {
                                        $startTime = Get-Date
                                        Import-Module $moduleInfo.Path -Force:$moduleInfo.Force -Global -ErrorAction Stop
                                        $result.Status = 'Success'
                                        $result.Message = $moduleInfo.Description
                                        $result.LoadTime = (Get-Date) - $startTime
                                    }
                                } catch {
                                    $result.Status = 'Failed'
                                    $result.Message = $_.Exception.Message
                                }
                                
                                return $result
                            } -ThrottleLimit $MaxParallel
                            
                            # Process results
                            foreach ($result in $parallelResults) {
                                Update-ImportResults -ImportResults $importResults -ModuleResult $result
                                
                                # Update loaded modules tracking
                                if ($result.Status -eq 'Success') {
                                    $moduleInfo = $moduleInfoList | Where-Object { $_.Name -eq $result.Name } | Select-Object -First 1
                                    if ($moduleInfo) {
                                        $script:LoadedModules[$result.Name] = @{
                                            Path = $moduleInfo.Path
                                            ImportTime = Get-Date
                                            Description = $moduleInfo.Description
                                        }
                                    }
                                }
                            }
                        }
                        
                    } catch {
                        Write-CustomLog -Message "Parallel loading failed for depth $depth, falling back to sequential: $_" -Level 'WARNING'
                        
                        # Fallback to sequential loading for this depth level
                        foreach ($moduleName in $modulesAtDepth) {
                            $result = Import-SingleModule -ModuleName $moduleName -Force:$Force
                            Update-ImportResults -ImportResults $importResults -ModuleResult $result
                        }
                    }
                }
            }
            
            # Calculate and log performance metrics
            $importResults.EndTime = Get-Date
            $importResults.Duration = $importResults.EndTime - $importResults.StartTime
            
            Write-CustomLog -Message "Module import complete in $($importResults.Duration.TotalSeconds.ToString('F2')) seconds" -Level 'INFO'
            Write-CustomLog -Message "Results: $($importResults.ImportedCount) imported, $($importResults.FailedCount) failed, $($importResults.SkippedCount) skipped" -Level 'INFO'
            
            if ($loadOrderResult.CircularDependencies.Count -gt 0) {
                Write-CustomLog -Message "Circular dependencies detected: $($loadOrderResult.CircularDependencies -join ', ')" -Level 'WARNING'
            }
            
            return $importResults
            
        } catch {
            Write-CustomLog -Message "Failed to import modules in parallel: $($_.Exception.Message)" -Level 'ERROR'
            
            # If parallel import completely fails, try legacy sequential mode
            if (-not $UseLegacyMode) {
                Write-CustomLog -Message "Attempting legacy sequential import as fallback..." -Level 'WARNING'
                return Import-CoreModules -RequiredOnly:$RequiredOnly -Force:$Force -UseDependencyResolution:$false
            }
            
            throw
        }
    }
}

function Import-SingleModule {
    <#
    .SYNOPSIS
        Helper function to import a single module
    .DESCRIPTION
        Imports a single module with proper error handling and result formatting
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,
        
        [Parameter()]
        [switch]$Force
    )
    
    $result = @{
        Name = $ModuleName
        Status = 'Unknown'
        Message = ''
        LoadTime = $null
    }
    
    try {
        $moduleInfo = $script:CoreModules | Where-Object { $_.Name -eq $ModuleName } | Select-Object -First 1
        if (-not $moduleInfo) {
            $result.Status = 'Failed'
            $result.Message = 'Module not found in registry'
            return $result
        }
        
        $modulePath = Join-Path $PSScriptRoot "../$($moduleInfo.Path)"
        
        if (-not (Test-Path $modulePath)) {
            $result.Status = 'Failed'
            $result.Message = 'Path not found'
            return $result
        }
        
        # Check if already loaded
        if ($script:LoadedModules.ContainsKey($ModuleName) -and -not $Force) {
            $result.Status = 'Skipped'
            $result.Message = 'Already loaded'
            $result.LoadTime = $script:LoadedModules[$ModuleName].ImportTime
            return $result
        }
        
        # Import the module
        $startTime = Get-Date
        Import-Module $modulePath -Force:$Force -Global -ErrorAction Stop
        $result.LoadTime = (Get-Date) - $startTime
        
        # Update tracking
        $script:LoadedModules[$ModuleName] = @{
            Path = $modulePath
            ImportTime = Get-Date
            Description = $moduleInfo.Description
        }
        
        $result.Status = 'Success'
        $result.Message = $moduleInfo.Description
        
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "✓ Imported: $ModuleName ($('{0:F3}' -f $result.LoadTime.TotalSeconds)s)" -Level 'SUCCESS'
        } else {
            Write-Host "[✓] Imported: $ModuleName ($('{0:F3}' -f $result.LoadTime.TotalSeconds)s)" -ForegroundColor Green
        }
        
    } catch {
        $result.Status = 'Failed'
        $result.Message = $_.Exception.Message
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "✗ Failed to import $ModuleName : $($_.Exception.Message)" -Level 'ERROR'
        } else {
            Write-Host "[✗] Failed to import $ModuleName : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    return $result
}

function Update-ImportResults {
    <#
    .SYNOPSIS
        Helper function to update import results based on module result
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ImportResults,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$ModuleResult
    )
    
    switch ($ModuleResult.Status) {
        'Success' {
            $ImportResults.ImportedCount++
            if ($ModuleResult.LoadTime) {
                if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                    Write-CustomLog -Message "✓ Imported: $($ModuleResult.Name) ($('{0:F3}' -f $ModuleResult.LoadTime.TotalSeconds)s)" -Level 'SUCCESS'
                } else {
                    Write-Host "[✓] Imported: $($ModuleResult.Name) ($('{0:F3}' -f $ModuleResult.LoadTime.TotalSeconds)s)" -ForegroundColor Green
                }
            }
        }
        'Failed' {
            $ImportResults.FailedCount++
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Message "✗ Failed: $($ModuleResult.Name) - $($ModuleResult.Message)" -Level 'ERROR'
            } else {
                Write-Host "[✗] Failed: $($ModuleResult.Name) - $($ModuleResult.Message)" -ForegroundColor Red
            }
        }
        'Skipped' {
            $ImportResults.SkippedCount++
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Message "⚬ Skipped: $($ModuleResult.Name) - $($ModuleResult.Message)" -Level 'DEBUG'
            } else {
                Write-Host "[⚬] Skipped: $($ModuleResult.Name) - $($ModuleResult.Message)" -ForegroundColor Gray
            }
        }
    }
    
    $ImportResults.Details += $ModuleResult
}

# Export the function
Export-ModuleMember -Function Import-CoreModulesParallel