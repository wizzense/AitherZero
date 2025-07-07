function Reset-UtilityServices {
    <#
    .SYNOPSIS
        Resets all utility services to initial state
    
    .DESCRIPTION
        Performs a comprehensive reset of all utility services including:
        - Clearing active operations
        - Resetting configuration to defaults
        - Clearing event history
        - Re-initializing services
    
    .PARAMETER Services
        Specific services to reset (default: all)
    
    .PARAMETER KeepConfiguration
        Whether to preserve current configuration
    
    .PARAMETER KeepEventHistory
        Whether to preserve event history
    
    .PARAMETER Force
        Force reset without confirmation
    
    .EXAMPLE
        Reset-UtilityServices -Force
        
        Reset all services without confirmation
    
    .EXAMPLE
        Reset-UtilityServices -Services @('ProgressTracking') -KeepConfiguration
        
        Reset only ProgressTracking service while keeping configuration
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [string[]]$Services = @('SemanticVersioning', 'ProgressTracking', 'TestingFramework', 'ScriptManager'),
        
        [switch]$KeepConfiguration,
        
        [switch]$KeepEventHistory,
        
        [switch]$Force
    )
    
    begin {
        Write-UtilityLog "🔄 Initiating UtilityServices reset" -Level "WARN"
        
        if (-not $Force -and -not $PSCmdlet.ShouldProcess("UtilityServices", "Reset all utility services")) {
            return
        }
    }
    
    process {
        try {
            $resetResults = @{
                Services = @{}
                Configuration = @{ Reset = $false; Preserved = $KeepConfiguration }
                EventSystem = @{ Reset = $false; Preserved = $KeepEventHistory }
                ActiveOperations = @{ Cleared = 0 }
                Success = $false
                StartTime = Get-Date
            }
            
            # Step 1: Clear active integrated operations
            Write-UtilityLog "Clearing active integrated operations" -Level "INFO"
            
            $activeCount = $script:UtilityServices.IntegratedServices.Active.Count
            if ($activeCount -gt 0) {
                foreach ($operation in $script:UtilityServices.IntegratedServices.Active) {
                    Write-UtilityLog "Terminating operation: $($operation.OperationId)" -Level "WARN"
                }
                $script:UtilityServices.IntegratedServices.Active = @()
                $resetResults.ActiveOperations.Cleared = $activeCount
            }
            
            # Step 2: Reset individual services
            Write-UtilityLog "Resetting individual services" -Level "INFO"
            
            foreach ($serviceName in $Services) {
                try {
                    Write-UtilityLog "Resetting service: $serviceName" -Level "INFO" -Service $serviceName
                    
                    # Reset service state
                    $script:UtilityServices[$serviceName] = @{
                        Loaded = $false
                        Functions = @()
                    }
                    
                    # Re-initialize service
                    $initResult = switch ($serviceName) {
                        'SemanticVersioning' { Initialize-SemanticVersioningService }
                        'ProgressTracking' { Initialize-ProgressTrackingService }
                        'TestingFramework' { Initialize-TestingFrameworkService }
                        'ScriptManager' { Initialize-ScriptManagerService }
                        default { @{ Success = $false; Error = "Unknown service: $serviceName" } }
                    }
                    
                    $resetResults.Services[$serviceName] = $initResult
                    
                    if ($initResult.Success) {
                        $script:UtilityServices[$serviceName] = $initResult
                        Write-UtilityLog "✅ Service reset successful: $serviceName" -Level "SUCCESS" -Service $serviceName
                    } else {
                        Write-UtilityLog "❌ Service reset failed: $serviceName - $($initResult.Error)" -Level "ERROR" -Service $serviceName
                    }
                    
                } catch {
                    $resetResults.Services[$serviceName] = @{
                        Success = $false
                        Error = $_.Exception.Message
                    }
                    Write-UtilityLog "❌ Exception during service reset: $serviceName - $($_.Exception.Message)" -Level "ERROR" -Service $serviceName
                }
            }
            
            # Step 3: Reset configuration (if not preserving)
            if (-not $KeepConfiguration) {
                Write-UtilityLog "Resetting configuration to defaults" -Level "INFO"
                Reset-UtilityConfiguration
                $resetResults.Configuration.Reset = $true
            }
            
            # Step 4: Reset event system (if not preserving)
            if (-not $KeepEventHistory) {
                Write-UtilityLog "Clearing event history" -Level "INFO"
                Clear-UtilityEvents -Force
                $resetResults.EventSystem.Reset = $true
            }
            
            # Step 5: Re-initialize integrated services
            Write-UtilityLog "Re-initializing integrated services" -Level "INFO"
            Initialize-IntegratedServices
            
            # Step 6: Publish reset event
            Publish-UtilityEvent -EventType "ServicesReset" -Data @{
                Services = $Services
                Results = $resetResults
                Timestamp = Get-Date
            }
            
            $resetResults.Success = $true
            $resetResults.EndTime = Get-Date
            $resetResults.Duration = ($resetResults.EndTime - $resetResults.StartTime).TotalSeconds
            
            # Summary
            $successfulResets = ($resetResults.Services.Values | Where-Object Success).Count
            $totalServices = $resetResults.Services.Count
            
            Write-UtilityLog "🎯 UtilityServices reset completed" -Level "SUCCESS"
            Write-UtilityLog "  Services: $successfulResets/$totalServices successful" -Level "INFO"
            Write-UtilityLog "  Active operations cleared: $($resetResults.ActiveOperations.Cleared)" -Level "INFO"
            Write-UtilityLog "  Configuration reset: $($resetResults.Configuration.Reset)" -Level "INFO"
            Write-UtilityLog "  Event history cleared: $($resetResults.EventSystem.Reset)" -Level "INFO"
            Write-UtilityLog "  Duration: $([Math]::Round($resetResults.Duration, 2))s" -Level "INFO"
            
            return $resetResults
            
        } catch {
            $resetResults.Success = $false
            $resetResults.Error = $_.Exception.Message
            Write-UtilityLog "❌ UtilityServices reset failed: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}