function Get-DevEnvironmentStatus {
    <#
    .SYNOPSIS
        Gets the current status of the development environment

    .DESCRIPTION
        Retrieves comprehensive status information about the development environment

    .PARAMETER IncludeMetrics
        Whether to include performance and usage metrics
    #>
    [CmdletBinding()]
    param(
        [switch]$IncludeMetrics
    )

    Write-CustomLog -Message "📊 Retrieving development environment status" -Level "INFO"

    try {
        $status = @{
            Timestamp = Get-Date
            Environment = @{
                PowerShellVersion = $PSVersionTable.PSVersion.ToString()
                Platform = $PSVersionTable.Platform
                OS = $PSVersionTable.OS
                ProjectRoot = $env:PROJECT_ROOT
            }
            Modules = @{
                Available = @()
                Loaded = @()
                Total = 0
            }
            Health = 'Unknown'
        }

        # Check available modules
        $modulesPath = Join-Path $env:PROJECT_ROOT "aither-core/modules" -ErrorAction SilentlyContinue
        if ($modulesPath -and (Test-Path $modulesPath)) {
            $availableModules = Get-ChildItem -Path $modulesPath -Directory
            $status.Modules.Available = $availableModules.Name
            $status.Modules.Total = $availableModules.Count
        }

        # Check loaded modules
        $loadedModules = Get-Module | Where-Object { $_.Path -like "*aither-core/modules*" }
        $status.Modules.Loaded = $loadedModules.Name

        # Perform health check
        $healthCheck = Test-DevEnvironment
        $status.Health = $healthCheck.Status
        $status.HealthMetrics = @{
            TestsPassed = $healthCheck.TestsPassed
            TestsTotal = $healthCheck.TestsTotal
            SuccessRate = $healthCheck.SuccessRate
        }

        if ($IncludeMetrics) {
            $status.Metrics = @{
                MemoryUsage = [System.GC]::GetTotalMemory($false)
                ProcessId = $PID
                SessionStartTime = (Get-Process -Id $PID).StartTime
                WorkingSet = (Get-Process -Id $PID).WorkingSet64
            }
        }

        Write-CustomLog -Message "✅ Environment status retrieved successfully" -Level "INFO"
        return $status
    } catch {
        Write-CustomLog -Message "❌ Failed to get environment status: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}
