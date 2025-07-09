function Resolve-ModuleLoadOrder {
    <#
    .SYNOPSIS
        Performs topological sorting to determine correct module load order
    .DESCRIPTION
        Takes a dependency graph and returns modules in the correct load order,
        ensuring dependencies are loaded before dependent modules.
        Handles circular dependencies gracefully and ensures Logging is always first.
    .PARAMETER DependencyGraph
        Hashtable containing module dependencies from Get-ModuleDependencies
    .PARAMETER ModulesToLoad
        Optional array of specific modules to load. If not specified, all modules are included.
    .EXAMPLE
        $deps = Get-ModuleDependencies
        $loadOrder = Resolve-ModuleLoadOrder -DependencyGraph $deps
    .EXAMPLE
        $loadOrder = Resolve-ModuleLoadOrder -DependencyGraph $deps -ModulesToLoad @('PatchManager', 'TestingFramework')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$DependencyGraph,

        [Parameter()]
        [string[]]$ModulesToLoad
    )

    process {
        try {
            Write-CustomLog -Message "Resolving module load order..." -Level 'INFO'
            
            # If specific modules requested, filter the graph
            $workingGraph = if ($ModulesToLoad) {
                $filteredGraph = @{}
                $modulesToProcess = New-Object System.Collections.Generic.Queue[string]
                
                # Add requested modules to queue
                foreach ($module in $ModulesToLoad) {
                    if ($DependencyGraph.ContainsKey($module)) {
                        $modulesToProcess.Enqueue($module)
                    }
                }
                
                # Process queue to find all dependencies
                $processedModules = @{}
                while ($modulesToProcess.Count -gt 0) {
                    $currentModule = $modulesToProcess.Dequeue()
                    
                    if (-not $processedModules.ContainsKey($currentModule)) {
                        $processedModules[$currentModule] = $true
                        $filteredGraph[$currentModule] = $DependencyGraph[$currentModule]
                        
                        # Add dependencies to queue
                        foreach ($dep in $DependencyGraph[$currentModule].Dependencies) {
                            if ($DependencyGraph.ContainsKey($dep) -and -not $processedModules.ContainsKey($dep)) {
                                $modulesToProcess.Enqueue($dep)
                            }
                        }
                    }
                }
                
                $filteredGraph
            } else {
                $DependencyGraph.Clone()
            }
            
            # Perform topological sort using Kahn's algorithm
            $loadOrder = @()
            $inDegree = @{}
            $adjList = @{}
            
            # Initialize data structures
            foreach ($module in $workingGraph.Keys) {
                $inDegree[$module] = 0
                $adjList[$module] = @()
            }
            
            # Build adjacency list and calculate in-degrees
            foreach ($module in $workingGraph.Keys) {
                foreach ($dep in $workingGraph[$module].Dependencies) {
                    if ($workingGraph.ContainsKey($dep)) {
                        $adjList[$dep] += $module
                        $inDegree[$module]++
                    }
                }
            }
            
            # Find all nodes with no incoming edges
            $queue = New-Object System.Collections.Generic.Queue[string]
            
            # Special handling: Logging module always goes first if present
            if ($inDegree.ContainsKey('Logging')) {
                $queue.Enqueue('Logging')
                $inDegree.Remove('Logging')
            }
            
            # Add other modules with no dependencies
            foreach ($module in $inDegree.Keys) {
                if ($inDegree[$module] -eq 0) {
                    $queue.Enqueue($module)
                }
            }
            
            # Process the queue
            while ($queue.Count -gt 0) {
                $currentModule = $queue.Dequeue()
                $loadOrder += $currentModule
                
                # Reduce in-degree for dependent modules
                foreach ($dependent in $adjList[$currentModule]) {
                    $inDegree[$dependent]--
                    if ($inDegree[$dependent] -eq 0) {
                        $queue.Enqueue($dependent)
                    }
                }
            }
            
            # Check for circular dependencies
            $remainingModules = $inDegree.Keys | Where-Object { $inDegree[$_] -gt 0 }
            if ($remainingModules.Count -gt 0) {
                Write-CustomLog -Message "Circular dependency detected involving modules: $($remainingModules -join ', ')" -Level 'WARNING'
                
                # Add remaining modules in alphabetical order
                $remainingModules | Sort-Object | ForEach-Object {
                    $loadOrder += $_
                }
            }
            
            # Return the load order with additional metadata
            $result = @{
                LoadOrder = $loadOrder
                CircularDependencies = $remainingModules
                TotalModules = $loadOrder.Count
                DependencyDepth = @{}
            }
            
            # Calculate dependency depth for each module
            foreach ($module in $loadOrder) {
                $depth = 0
                $visited = @{}
                $stack = New-Object System.Collections.Generic.Stack[string]
                $stack.Push($module)
                
                while ($stack.Count -gt 0) {
                    $current = $stack.Pop()
                    if (-not $visited.ContainsKey($current)) {
                        $visited[$current] = $true
                        if ($workingGraph.ContainsKey($current)) {
                            foreach ($dep in $workingGraph[$current].Dependencies) {
                                if ($workingGraph.ContainsKey($dep)) {
                                    $stack.Push($dep)
                                    $depth = [Math]::Max($depth, $result.DependencyDepth[$dep] + 1)
                                }
                            }
                        }
                    }
                }
                
                $result.DependencyDepth[$module] = $depth
            }
            
            Write-CustomLog -Message "Module load order resolved. Total modules: $($loadOrder.Count)" -Level 'INFO'
            if ($remainingModules.Count -gt 0) {
                Write-CustomLog -Message "Circular dependencies found but handled gracefully" -Level 'WARNING'
            }
            
            return $result
            
        } catch {
            Write-CustomLog -Message "Failed to resolve module load order: $($_.Exception.Message)" -Level 'ERROR'
            throw
        }
    }
}