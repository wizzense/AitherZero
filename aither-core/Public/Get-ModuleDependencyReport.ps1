function Get-ModuleDependencyReport {
    <#
    .SYNOPSIS
        Generates a comprehensive report of module dependencies and load order
    .DESCRIPTION
        Analyzes all AitherZero modules, their dependencies, and generates a
        report showing the dependency graph and recommended load order.
        Useful for troubleshooting module loading issues.
    .PARAMETER OutputFormat
        Format for the report output: Table, List, Json, or Graph
    .PARAMETER IncludeOptional
        Include optional dependencies in the analysis
    .PARAMETER ModulesToAnalyze
        Specific modules to analyze. If not specified, all modules are analyzed.
    .EXAMPLE
        Get-ModuleDependencyReport
        Shows a table view of all module dependencies
    .EXAMPLE
        Get-ModuleDependencyReport -OutputFormat Graph
        Shows a visual dependency graph representation
    .EXAMPLE
        Get-ModuleDependencyReport -OutputFormat Json | Out-File dependencies.json
        Exports dependency information as JSON
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Table', 'List', 'Json', 'Graph')]
        [string]$OutputFormat = 'Table',

        [Parameter()]
        [switch]$IncludeOptional,

        [Parameter()]
        [string[]]$ModulesToAnalyze
    )

    process {
        try {
            Write-CustomLog -Message "Generating module dependency report..." -Level 'INFO'
            
            # Get dependencies
            $dependencyGraph = Get-ModuleDependencies -IncludeOptional:$IncludeOptional
            
            # Resolve load order
            $loadOrderResult = Resolve-ModuleLoadOrder -DependencyGraph $dependencyGraph -ModulesToLoad $ModulesToAnalyze
            
            # Build report data
            $reportData = @{
                Timestamp = Get-Date
                TotalModules = $dependencyGraph.Count
                LoadOrder = $loadOrderResult.LoadOrder
                CircularDependencies = $loadOrderResult.CircularDependencies
                DependencyDepth = $loadOrderResult.DependencyDepth
                ModuleDetails = @()
            }
            
            # Add detailed module information
            foreach ($moduleName in $loadOrderResult.LoadOrder) {
                if ($dependencyGraph.ContainsKey($moduleName)) {
                    $moduleData = $dependencyGraph[$moduleName]
                    $reportData.ModuleDetails += @{
                        Name = $moduleName
                        Version = $moduleData.Version
                        Dependencies = $moduleData.Dependencies
                        DependencyCount = $moduleData.Dependencies.Count
                        DependencyDepth = $loadOrderResult.DependencyDepth[$moduleName]
                        LoadPosition = $loadOrderResult.LoadOrder.IndexOf($moduleName) + 1
                        Status = if ($moduleData.Error) { 'Error' } else { 'OK' }
                        Error = $moduleData.Error
                    }
                }
            }
            
            # Format output based on requested format
            switch ($OutputFormat) {
                'Table' {
                    Write-Host "`n=== Module Dependency Report ===" -ForegroundColor Cyan
                    Write-Host "Generated: $($reportData.Timestamp)" -ForegroundColor Gray
                    Write-Host "Total Modules: $($reportData.TotalModules)" -ForegroundColor Gray
                    
                    if ($reportData.CircularDependencies.Count -gt 0) {
                        Write-Host "`nWARNING: Circular dependencies detected!" -ForegroundColor Yellow
                        Write-Host "Modules involved: $($reportData.CircularDependencies -join ', ')" -ForegroundColor Yellow
                    }
                    
                    Write-Host "`nLoad Order:" -ForegroundColor Green
                    $reportData.ModuleDetails | ForEach-Object {
                        $depList = if ($_.Dependencies.Count -gt 0) { "→ $($_.Dependencies -join ', ')" } else { "(no dependencies)" }
                        Write-Host "$($_.LoadPosition.ToString().PadLeft(3)). $($_.Name.PadRight(25)) $depList"
                    }
                    
                    Write-Host "`nDependency Summary:" -ForegroundColor Green
                    $reportData.ModuleDetails | 
                        Sort-Object DependencyCount -Descending | 
                        Select-Object -First 10 |
                        Format-Table Name, DependencyCount, DependencyDepth, Status -AutoSize
                }
                
                'List' {
                    foreach ($module in $reportData.ModuleDetails) {
                        Write-Host "`n--- $($module.Name) ---" -ForegroundColor Cyan
                        Write-Host "Version: $($module.Version)"
                        Write-Host "Load Position: $($module.LoadPosition)"
                        Write-Host "Dependency Depth: $($module.DependencyDepth)"
                        Write-Host "Status: $($module.Status)"
                        
                        if ($module.Dependencies.Count -gt 0) {
                            Write-Host "Dependencies:"
                            $module.Dependencies | ForEach-Object { Write-Host "  - $_" }
                        } else {
                            Write-Host "Dependencies: None"
                        }
                        
                        if ($module.Error) {
                            Write-Host "Error: $($module.Error)" -ForegroundColor Red
                        }
                    }
                }
                
                'Json' {
                    $reportData | ConvertTo-Json -Depth 10
                }
                
                'Graph' {
                    Write-Host "`n=== Module Dependency Graph ===" -ForegroundColor Cyan
                    Write-Host "→ indicates 'depends on'" -ForegroundColor Gray
                    Write-Host ""
                    
                    # Group modules by dependency depth
                    $depthGroups = $reportData.ModuleDetails | Group-Object DependencyDepth | Sort-Object Name
                    
                    foreach ($group in $depthGroups) {
                        Write-Host "`nLevel $($group.Name) (Depth: $($group.Name)):" -ForegroundColor Green
                        foreach ($module in $group.Group) {
                            $prefix = "  " * [int]$group.Name
                            Write-Host "$prefix├─ $($module.Name)" -ForegroundColor White
                            
                            if ($module.Dependencies.Count -gt 0) {
                                foreach ($dep in $module.Dependencies) {
                                    Write-Host "$prefix│  → $dep" -ForegroundColor Gray
                                }
                            }
                        }
                    }
                    
                    if ($reportData.CircularDependencies.Count -gt 0) {
                        Write-Host "`n⚠ Circular Dependencies:" -ForegroundColor Yellow
                        $reportData.CircularDependencies | ForEach-Object {
                            Write-Host "  ↻ $_" -ForegroundColor Yellow
                        }
                    }
                }
            }
            
            # Return raw data for programmatic use
            if ($OutputFormat -ne 'Json') {
                return $reportData
            }
            
        } catch {
            Write-CustomLog -Message "Failed to generate dependency report: $($_.Exception.Message)" -Level 'ERROR'
            throw
        }
    }
}