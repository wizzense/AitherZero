#!/usr/bin/env pwsh

<#
.SYNOPSIS
Module Loading Performance Optimizer for AitherZero
.DESCRIPTION
Optimizes module loading performance by implementing caching, parallel loading,
and intelligent dependency resolution
#>

class ModuleLoadingOptimizer {
    [hashtable]$ModuleCache = @{}
    [hashtable]$LoadTimes = @{}
    [hashtable]$Dependencies = @{}
    [string]$CacheFile
    [datetime]$CacheExpiry = (Get-Date).AddHours(24)
    
    ModuleLoadingOptimizer([string]$cacheDirectory) {
        $this.CacheFile = Join-Path $cacheDirectory "module-cache.json"
        $this.LoadCache()
    }
    
    [void]LoadCache() {
        if (Test-Path $this.CacheFile) {
            try {
                $cacheData = Get-Content $this.CacheFile -Raw | ConvertFrom-Json
                if ($cacheData.Expiry -and [datetime]$cacheData.Expiry -gt (Get-Date)) {
                    $this.ModuleCache = $cacheData.ModuleCache
                    $this.LoadTimes = $cacheData.LoadTimes
                    $this.Dependencies = $cacheData.Dependencies
                    Write-CustomLog "Module cache loaded successfully" -Level "DEBUG"
                } else {
                    Write-CustomLog "Module cache expired, starting fresh" -Level "INFO"
                }
            } catch {
                Write-CustomLog "Failed to load module cache: $_" -Level "WARN"
            }
        }
    }
    
    [void]SaveCache() {
        try {
            $cacheData = @{
                Expiry = $this.CacheExpiry
                ModuleCache = $this.ModuleCache
                LoadTimes = $this.LoadTimes
                Dependencies = $this.Dependencies
            }
            
            $cacheDir = Split-Path $this.CacheFile -Parent
            if (-not (Test-Path $cacheDir)) {
                New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
            }
            
            $cacheData | ConvertTo-Json -Depth 10 | Out-File $this.CacheFile -Encoding UTF8
            Write-CustomLog "Module cache saved successfully" -Level "DEBUG"
        } catch {
            Write-CustomLog "Failed to save module cache: $_" -Level "WARN"
        }
    }
    
    [object]OptimizeModuleLoading([array]$modules) {
        $startTime = Get-Date
        $loadResults = @{
            Successful = @()
            Failed = @()
            Skipped = @()
            TotalTime = 0
            OptimizationStats = @{}
        }
        
        Write-CustomLog "Starting optimized module loading for $($modules.Count) modules" -Level "INFO"
        
        # Sort modules by load priority (cached load times)
        $sortedModules = $modules | Sort-Object {
            if ($this.LoadTimes.ContainsKey($_.Name)) {
                $this.LoadTimes[$_.Name]
            } else {
                999  # Unknown modules get lower priority
            }
        }
        
        # Identify modules that can be loaded in parallel
        $parallelGroups = $this.CreateParallelGroups($sortedModules)
        
        foreach ($group in $parallelGroups) {
            if ($group.Count -eq 1) {
                # Single module - load sequentially
                $module = $group[0]
                $result = $this.LoadSingleModule($module)
                if ($result.Success) {
                    $loadResults.Successful += $result
                } else {
                    $loadResults.Failed += $result
                }
            } else {
                # Multiple modules - load in parallel
                $parallelResults = $this.LoadModulesInParallel($group)
                $loadResults.Successful += $parallelResults.Successful
                $loadResults.Failed += $parallelResults.Failed
            }
        }
        
        $loadResults.TotalTime = ((Get-Date) - $startTime).TotalSeconds
        $loadResults.OptimizationStats = @{
            CacheHits = ($loadResults.Successful | Where-Object { $_.FromCache }).Count
            ParallelGroups = $parallelGroups.Count
            AverageLoadTime = if ($loadResults.Successful.Count -gt 0) {
                ($loadResults.Successful | Measure-Object LoadTime -Average).Average
            } else { 0 }
        }
        
        # Update cache with new timing data
        $this.UpdateCache($loadResults.Successful)
        $this.SaveCache()
        
        Write-CustomLog "Optimized module loading completed in $($loadResults.TotalTime.ToString('F2'))s" -Level "SUCCESS"
        
        return $loadResults
    }
    
    [array]CreateParallelGroups([array]$modules) {
        $groups = @()
        $processed = @{}
        
        foreach ($module in $modules) {
            if ($processed.ContainsKey($module.Name)) {
                continue
            }
            
            # Find modules that can be loaded together (no dependencies between them)
            $group = @($module)
            $processed[$module.Name] = $true
            
            # Add other modules that don't depend on this one or each other
            foreach ($otherModule in $modules) {
                if ($processed.ContainsKey($otherModule.Name)) {
                    continue
                }
                
                $canParallel = $true
                foreach ($groupMember in $group) {
                    if ($this.HasDependency($otherModule.Name, $groupMember.Name) -or 
                        $this.HasDependency($groupMember.Name, $otherModule.Name)) {
                        $canParallel = $false
                        break
                    }
                }
                
                if ($canParallel -and $group.Count -lt 4) {  # Limit parallel group size
                    $group += $otherModule
                    $processed[$otherModule.Name] = $true
                }
            }
            
            $groups += ,@($group)
        }
        
        return $groups
    }
    
    [bool]HasDependency([string]$moduleName, [string]$dependencyName) {
        if ($this.Dependencies.ContainsKey($moduleName)) {
            return $dependencyName -in $this.Dependencies[$moduleName]
        }
        return $false
    }
    
    [object]LoadSingleModule([object]$moduleInfo) {
        $startTime = Get-Date
        
        try {
            # Check if module is already loaded
            if (Get-Module -Name $moduleInfo.Name -ErrorAction SilentlyContinue) {
                return @{
                    Name = $moduleInfo.Name
                    Success = $true
                    LoadTime = 0.001
                    FromCache = $true
                    Message = "Already loaded"
                }
            }
            
            # Load the module
            Import-Module $moduleInfo.Path -Force -Global -ErrorAction Stop
            
            $loadTime = ((Get-Date) - $startTime).TotalSeconds
            
            return @{
                Name = $moduleInfo.Name
                Success = $true
                LoadTime = $loadTime
                FromCache = $false
                Message = "Loaded successfully"
            }
            
        } catch {
            $loadTime = ((Get-Date) - $startTime).TotalSeconds
            
            return @{
                Name = $moduleInfo.Name
                Success = $false
                LoadTime = $loadTime
                FromCache = $false
                Error = $_.Exception.Message
                Message = "Load failed"
            }
        }
    }
    
    [object]LoadModulesInParallel([array]$modules) {
        Write-CustomLog "Loading $($modules.Count) modules in parallel" -Level "DEBUG"
        
        $jobs = @()
        foreach ($module in $modules) {
            $job = Start-Job -ScriptBlock {
                param($ModulePath, $ModuleName)
                
                try {
                    $startTime = Get-Date
                    Import-Module $ModulePath -Force -Global -ErrorAction Stop
                    $loadTime = ((Get-Date) - $startTime).TotalSeconds
                    
                    return @{
                        Name = $ModuleName
                        Success = $true
                        LoadTime = $loadTime
                        FromCache = $false
                        Message = "Loaded successfully (parallel)"
                    }
                } catch {
                    $loadTime = ((Get-Date) - $startTime).TotalSeconds
                    return @{
                        Name = $ModuleName
                        Success = $false
                        LoadTime = $loadTime
                        FromCache = $false
                        Error = $_.Exception.Message
                        Message = "Load failed (parallel)"
                    }
                }
            } -ArgumentList $module.Path, $module.Name
            
            $jobs += $job
        }
        
        # Wait for all parallel jobs to complete
        $results = @{
            Successful = @()
            Failed = @()
        }
        
        foreach ($job in $jobs) {
            $jobResult = Wait-Job $job | Receive-Job
            Remove-Job $job -Force
            
            if ($jobResult.Success) {
                $results.Successful += $jobResult
            } else {
                $results.Failed += $jobResult
            }
        }
        
        return $results
    }
    
    [void]UpdateCache([array]$successfulLoads) {
        foreach ($result in $successfulLoads) {
            if (-not $result.FromCache) {
                $this.LoadTimes[$result.Name] = $result.LoadTime
            }
        }
    }
}

function Optimize-ModuleBootstrap {
    <#
    .SYNOPSIS
    Optimizes the module bootstrap process for faster startup
    .DESCRIPTION
    Implements caching, parallel loading, and intelligent dependency resolution
    to significantly improve module loading performance
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$ModuleList,
        
        [Parameter(Mandatory = $false)]
        [string]$CacheDirectory = (Join-Path $env:TEMP "AitherZero-Cache"),
        
        [switch]$DisableParallelLoading,
        
        [switch]$ClearCache
    )
    
    try {
        if ($ClearCache -and (Test-Path $CacheDirectory)) {
            Remove-Item $CacheDirectory -Recurse -Force
            Write-CustomLog "Module cache cleared" -Level "INFO"
        }
        
        $optimizer = [ModuleLoadingOptimizer]::new($CacheDirectory)
        
        if ($DisableParallelLoading) {
            Write-CustomLog "Parallel loading disabled, using sequential loading" -Level "INFO"
            # Fall back to sequential loading
            $results = @{
                Successful = @()
                Failed = @()
                TotalTime = 0
            }
            
            $startTime = Get-Date
            foreach ($module in $ModuleList) {
                $result = $optimizer.LoadSingleModule($module)
                if ($result.Success) {
                    $results.Successful += $result
                } else {
                    $results.Failed += $result
                }
            }
            $results.TotalTime = ((Get-Date) - $startTime).TotalSeconds
        } else {
            $results = $optimizer.OptimizeModuleLoading($ModuleList)
        }
        
        # Generate performance report
        $report = @{
            TotalModules = $ModuleList.Count
            SuccessfulLoads = $results.Successful.Count
            FailedLoads = $results.Failed.Count
            TotalTime = $results.TotalTime
            AverageLoadTime = if ($results.Successful.Count -gt 0) {
                ($results.Successful | Measure-Object LoadTime -Average).Average
            } else { 0 }
            OptimizationStats = $results.OptimizationStats
            Performance = @{
                ModulesPerSecond = if ($results.TotalTime -gt 0) {
                    $results.Successful.Count / $results.TotalTime
                } else { 0 }
                TimeImprovement = "N/A"  # Would need baseline comparison
            }
        }
        
        Write-CustomLog "Module bootstrap optimization completed:" -Level "SUCCESS"
        Write-CustomLog "  - Total: $($report.TotalModules) modules" -Level "INFO"
        Write-CustomLog "  - Successful: $($report.SuccessfulLoads)" -Level "INFO"
        Write-CustomLog "  - Failed: $($report.FailedLoads)" -Level "INFO"
        Write-CustomLog "  - Total time: $($report.TotalTime.ToString('F2'))s" -Level "INFO"
        Write-CustomLog "  - Speed: $($report.Performance.ModulesPerSecond.ToString('F2')) modules/sec" -Level "INFO"
        
        return $report
        
    } catch {
        Write-CustomLog "Module bootstrap optimization failed: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Optimize-ModuleBootstrap'
)