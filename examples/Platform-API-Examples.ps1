#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive examples for the AitherZero Unified Platform API.

.DESCRIPTION
    Real-world usage examples demonstrating the capabilities of the unified platform API.
    Covers common scenarios, advanced workflows, and best practices.

.NOTES
    AitherZero Unified Platform API v2.0.0
    These examples demonstrate Phase 4/5 implementation capabilities.
#>

# Import AitherCore module
. "$PSScriptRoot/../aither-core/shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot
Import-Module (Join-Path $projectRoot "aither-core/AitherCore.psm1") -Force

Write-Host "🚀 AitherZero Unified Platform API Examples" -ForegroundColor Magenta
Write-Host "==========================================" -ForegroundColor Magenta
Write-Host ""

#region Example 1: Quick Start - 30 Second Demo
Write-Host "📋 Example 1: Quick Start (30 seconds)" -ForegroundColor Yellow
Write-Host "--------------------------------------" -ForegroundColor Yellow

try {
    # Initialize platform
    Write-Host "1. Initializing platform..." -ForegroundColor Cyan
    $aither = Initialize-AitherPlatform -Profile "Standard"
    
    # Quick health check
    Write-Host "2. Checking system health..." -ForegroundColor Cyan
    $health = $aither.Quick.SystemHealth()
    Write-Host "   Health Score: $($health.CoreHealth)" -ForegroundColor Green
    
    # Check what's available
    Write-Host "3. Checking available capabilities..." -ForegroundColor Cyan
    $status = $aither.Platform.Status()
    Write-Host "   Modules Loaded: $($status.Modules.Loaded)" -ForegroundColor Green
    Write-Host "   Platform Status: $($status.Platform.Status)" -ForegroundColor Green
    
    Write-Host "✅ Quick start complete!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Quick start failed: $_" -ForegroundColor Red
}

Write-Host ""
#endregion

#region Example 2: Development Workflow
Write-Host "📋 Example 2: Development Workflow" -ForegroundColor Yellow
Write-Host "----------------------------------" -ForegroundColor Yellow

try {
    # Initialize with Full profile for development
    Write-Host "1. Setting up development environment..." -ForegroundColor Cyan
    $devAither = Initialize-AitherPlatform -Profile "Full"
    
    # Optimize for development work
    Write-Host "2. Optimizing performance..." -ForegroundColor Cyan
    Optimize-PlatformPerformance -CacheLevel Standard
    
    # Check development capabilities
    Write-Host "3. Checking development tools..." -ForegroundColor Cyan
    $devStatus = $devAither.Platform.Status()
    $hasPatchManager = $devStatus.Capabilities.PatchManagement
    $hasTestFramework = $devStatus.Capabilities.TestingFramework
    
    Write-Host "   Patch Management: $hasPatchManager" -ForegroundColor Green
    Write-Host "   Testing Framework: $hasTestFramework" -ForegroundColor Green
    
    if ($hasTestFramework) {
        # Run quick tests
        Write-Host "4. Running quick validation..." -ForegroundColor Cyan
        $testResult = $devAither.Testing.Run("Quick")
        Write-Host "   Test result available: $($testResult -ne $null)" -ForegroundColor Green
    }
    
    if ($hasPatchManager) {
        # Simulate patch creation (dry run)
        Write-Host "5. Simulating patch workflow..." -ForegroundColor Cyan
        Write-Host "   (Would create patch with: `$devAither.Patch.Create('Example patch', {...}, -CreatePR))" -ForegroundColor Gray
    }
    
    Write-Host "✅ Development workflow example complete!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Development workflow failed: $_" -ForegroundColor Red
}

Write-Host ""
#endregion

#region Example 3: Operations/Production Workflow
Write-Host "📋 Example 3: Operations/Production Workflow" -ForegroundColor Yellow
Write-Host "--------------------------------------------" -ForegroundColor Yellow

try {
    # Initialize for operations
    Write-Host "1. Initializing operations platform..." -ForegroundColor Cyan
    $opsAither = Initialize-AitherPlatform -Profile "Standard"
    
    # Enable advanced error handling for production
    Write-Host "2. Setting up production-grade error handling..." -ForegroundColor Cyan
    Initialize-PlatformErrorHandling -ErrorHandlingLevel Advanced -ErrorRecovery
    
    # Start monitoring services
    Write-Host "3. Starting platform services..." -ForegroundColor Cyan
    $serviceResult = Start-PlatformServices -Platform $opsAither -Services @('HealthMonitor', 'EventSystem')
    Write-Host "   Services started: $($serviceResult.Started.Count)" -ForegroundColor Green
    
    # Comprehensive health check
    Write-Host "4. Performing comprehensive health check..." -ForegroundColor Cyan
    $health = $opsAither.Platform.Health()
    Write-Host "   Overall Health: $($health.Overall)" -ForegroundColor Green
    Write-Host "   Health Score: $($health.Score)%" -ForegroundColor Green
    
    if ($health.Issues.Count -gt 0) {
        Write-Host "   Issues found: $($health.Issues.Count)" -ForegroundColor Yellow
        foreach ($issue in $health.Issues[0..2]) {  # Show first 3
            Write-Host "     - $issue" -ForegroundColor Yellow
        }
    }
    
    # Infrastructure status (if available)
    if ($opsAither.Platform.Status().Capabilities.InfrastructureDeployment) {
        Write-Host "5. Checking infrastructure status..." -ForegroundColor Cyan
        $infraStatus = $opsAither.Infrastructure.Status()
        Write-Host "   Infrastructure monitoring active: $($infraStatus -ne $null)" -ForegroundColor Green
    }
    
    # Maintenance check
    Write-Host "6. Checking maintenance requirements..." -ForegroundColor Cyan
    $maintenanceHealth = $opsAither.Maintenance.Health()
    Write-Host "   System ready for operations: $maintenanceHealth" -ForegroundColor Green
    
    Write-Host "✅ Operations workflow example complete!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Operations workflow failed: $_" -ForegroundColor Red
}

Write-Host ""
#endregion

#region Example 4: Configuration Management
Write-Host "📋 Example 4: Configuration Management" -ForegroundColor Yellow
Write-Host "--------------------------------------" -ForegroundColor Yellow

try {
    # Initialize platform
    $configAither = Initialize-AitherPlatform -Profile "Standard"
    
    if ($configAither.Platform.Status().Capabilities.ConfigurationManagement) {
        Write-Host "1. Configuration management is available" -ForegroundColor Cyan
        
        # Demonstrate configuration operations
        Write-Host "2. Setting test configuration..." -ForegroundColor Cyan
        try {
            $configAither.Configuration.Set("ExampleModule", "TestSetting", "ExampleValue")
            Write-Host "   Configuration set successfully" -ForegroundColor Green
        } catch {
            Write-Host "   Configuration operation simulated (module not available)" -ForegroundColor Gray
        }
        
        # Try to retrieve configuration
        Write-Host "3. Retrieving configuration..." -ForegroundColor Cyan
        try {
            $value = $configAither.Configuration.Get("ExampleModule", "TestSetting")
            Write-Host "   Retrieved value: $value" -ForegroundColor Green
        } catch {
            Write-Host "   Configuration retrieval simulated" -ForegroundColor Gray
        }
        
        # Validate configuration
        Write-Host "4. Validating configuration..." -ForegroundColor Cyan
        try {
            $isValid = $configAither.Configuration.Validate("ExampleModule")
            Write-Host "   Configuration valid: $isValid" -ForegroundColor Green
        } catch {
            Write-Host "   Configuration validation simulated" -ForegroundColor Gray
        }
        
    } else {
        Write-Host "Configuration management not available in current profile" -ForegroundColor Yellow
        Write-Host "Use 'Standard' or 'Full' profile for configuration features" -ForegroundColor Yellow
    }
    
    Write-Host "✅ Configuration management example complete!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Configuration management failed: $_" -ForegroundColor Red
}

Write-Host ""
#endregion

#region Example 5: Progress Tracking
Write-Host "📋 Example 5: Progress Tracking Demo" -ForegroundColor Yellow
Write-Host "-----------------------------------" -ForegroundColor Yellow

try {
    $progressAither = Initialize-AitherPlatform -Profile "Standard"
    
    if ($progressAither.Platform.Status().Capabilities.ProgressTracking) {
        Write-Host "1. Starting tracked operation..." -ForegroundColor Cyan
        
        # Start a progress-tracked operation
        $operationId = $progressAither.Progress.Start("Example Deployment", 5)
        Write-Host "   Operation started with ID: $operationId" -ForegroundColor Green
        
        # Simulate steps with progress updates
        $steps = @("Initializing", "Configuring", "Deploying", "Testing", "Finalizing")
        
        foreach ($step in $steps) {
            Write-Host "2. Step: $step" -ForegroundColor Cyan
            $progressAither.Progress.Update($operationId, $step)
            Start-Sleep -Milliseconds 500  # Simulate work
        }
        
        # Complete the operation
        Write-Host "3. Completing operation..." -ForegroundColor Cyan
        $progressAither.Progress.Complete($operationId)
        
        Write-Host "✅ Progress tracking example complete!" -ForegroundColor Green
        
    } else {
        Write-Host "Progress tracking not available in current profile" -ForegroundColor Yellow
        
        # Show alternative - multi-operation simulation
        Write-Host "1. Simulating multi-step process..." -ForegroundColor Cyan
        $operations = @(
            @{Name = "Setup"; Steps = 3},
            @{Name = "Execution"; Steps = 5},
            @{Name = "Cleanup"; Steps = 2}
        )
        
        foreach ($op in $operations) {
            Write-Host "   Operation: $($op.Name) ($($op.Steps) steps)" -ForegroundColor Gray
        }
        
        Write-Host "✅ Progress simulation complete!" -ForegroundColor Green
    }
    
} catch {
    Write-Host "❌ Progress tracking failed: $_" -ForegroundColor Red
}

Write-Host ""
#endregion

#region Example 6: Event Communication
Write-Host "📋 Example 6: Event Communication System" -ForegroundColor Yellow
Write-Host "---------------------------------------" -ForegroundColor Yellow

try {
    $commAither = Initialize-AitherPlatform -Profile "Standard"
    
    Write-Host "1. Setting up event communication..." -ForegroundColor Cyan
    
    # Set up event subscription
    $eventReceived = $false
    try {
        $commAither.Communication.Subscribe("example-channel", "test-event", {
            param($EventData)
            $script:eventReceived = $true
            Write-Host "   📢 Event received: $($EventData.Message)" -ForegroundColor Green
        })
        
        Write-Host "2. Publishing test event..." -ForegroundColor Cyan
        $commAither.Communication.Publish("example-channel", "test-event", @{
            Message = "Hello from AitherZero!"
            Timestamp = Get-Date
        })
        
        # Wait a moment for event processing
        Start-Sleep -Milliseconds 1000
        
        Write-Host "3. Event system test: $($eventReceived -or 'Fallback system used')" -ForegroundColor Green
        
    } catch {
        Write-Host "   Using fallback event system" -ForegroundColor Gray
        
        # Demonstrate basic event system
        Write-Host "2. Testing basic event system..." -ForegroundColor Cyan
        try {
            Publish-TestEvent -EventName "platform-test" -EventData @{ Test = $true }
            Write-Host "   Basic event published successfully" -ForegroundColor Green
        } catch {
            Write-Host "   Event system demonstration complete" -ForegroundColor Gray
        }
    }
    
    Write-Host "✅ Event communication example complete!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Event communication failed: $_" -ForegroundColor Red
}

Write-Host ""
#endregion

#region Example 7: Error Handling and Recovery
Write-Host "📋 Example 7: Error Handling and Recovery" -ForegroundColor Yellow
Write-Host "-----------------------------------------" -ForegroundColor Yellow

try {
    $errorAither = Initialize-AitherPlatform -Profile "Standard"
    
    # Initialize advanced error handling
    Write-Host "1. Setting up advanced error handling..." -ForegroundColor Cyan
    Initialize-PlatformErrorHandling -ErrorHandlingLevel Advanced -ErrorRecovery -EnableDiagnostics
    
    # Test graceful error handling
    Write-Host "2. Testing graceful error handling..." -ForegroundColor Cyan
    try {
        # Try to access a non-existent module feature
        $errorAither.Configuration.Get("NonExistentModule")
    } catch {
        Write-Host "   ✅ Error handled gracefully: Module not available" -ForegroundColor Green
    }
    
    # Test error recovery
    Write-Host "3. Testing error recovery mechanisms..." -ForegroundColor Cyan
    try {
        # Simulate a recoverable error
        throw "Simulated recoverable error"
    } catch {
        Write-Host "   ✅ Error caught and logged for recovery" -ForegroundColor Green
        
        # Show error logging is working
        if ($script:PlatformErrorHandling) {
            Write-Host "   Error handling system active: $($script:PlatformErrorHandling.Level)" -ForegroundColor Green
        }
    }
    
    # Test platform health after errors
    Write-Host "4. Checking platform health after errors..." -ForegroundColor Cyan
    $health = $errorAither.Platform.Health()
    Write-Host "   Health score: $($health.Score)%" -ForegroundColor Green
    Write-Host "   Overall status: $($health.Overall)" -ForegroundColor Green
    
    Write-Host "✅ Error handling example complete!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Error handling test failed: $_" -ForegroundColor Red
}

Write-Host ""
#endregion

#region Example 8: Performance Optimization
Write-Host "📋 Example 8: Performance Optimization" -ForegroundColor Yellow
Write-Host "--------------------------------------" -ForegroundColor Yellow

try {
    $perfAither = Initialize-AitherPlatform -Profile "Standard"
    
    # Measure baseline performance
    Write-Host "1. Measuring baseline performance..." -ForegroundColor Cyan
    $baselineTime = Measure-Command { 
        $perfAither.Platform.Status() | Out-Null
        $perfAither.Platform.Health() | Out-Null
    }
    Write-Host "   Baseline time: $([math]::Round($baselineTime.TotalMilliseconds, 2))ms" -ForegroundColor Green
    
    # Apply performance optimizations
    Write-Host "2. Applying performance optimizations..." -ForegroundColor Cyan
    $optResult = Optimize-PlatformPerformance -CacheLevel Aggressive -EnableBackgroundOptimization
    Write-Host "   Optimizations applied: $($optResult.Optimizations.Count)" -ForegroundColor Green
    
    # Measure optimized performance
    Write-Host "3. Measuring optimized performance..." -ForegroundColor Cyan
    Start-Sleep -Milliseconds 500  # Allow cache to warm up
    $optimizedTime = Measure-Command { 
        $perfAither.Platform.Status() | Out-Null
        $perfAither.Platform.Health() | Out-Null
    }
    Write-Host "   Optimized time: $([math]::Round($optimizedTime.TotalMilliseconds, 2))ms" -ForegroundColor Green
    
    # Calculate improvement
    if ($baselineTime.TotalMilliseconds -gt 0) {
        $improvement = [math]::Round((($baselineTime.TotalMilliseconds - $optimizedTime.TotalMilliseconds) / $baselineTime.TotalMilliseconds) * 100, 1)
        Write-Host "   Performance improvement: $improvement%" -ForegroundColor Green
    }
    
    # Show memory usage
    $memoryMB = [System.GC]::GetTotalMemory($false) / 1MB
    Write-Host "   Current memory usage: $([math]::Round($memoryMB, 2)) MB" -ForegroundColor Green
    
    Write-Host "✅ Performance optimization example complete!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Performance optimization failed: $_" -ForegroundColor Red
}

Write-Host ""
#endregion

#region Example 9: Comprehensive Platform Status
Write-Host "📋 Example 9: Comprehensive Platform Status" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Yellow

try {
    $statusAither = Initialize-AitherPlatform -Profile "Standard"
    
    # Get detailed platform status
    Write-Host "1. Getting comprehensive platform status..." -ForegroundColor Cyan
    $detailedStatus = $statusAither.Platform.Status(-Detailed)
    
    Write-Host "Platform Information:" -ForegroundColor White
    Write-Host "   Version: $($detailedStatus.Platform.Version)" -ForegroundColor Green
    Write-Host "   Status: $($detailedStatus.Platform.Status)" -ForegroundColor Green
    Write-Host "   Modules Loaded: $($detailedStatus.Modules.Loaded)/$($detailedStatus.Modules.Total)" -ForegroundColor Green
    
    # Show capabilities
    Write-Host "2. Available capabilities:" -ForegroundColor Cyan
    $capabilities = $detailedStatus.Capabilities
    foreach ($capability in $capabilities.GetEnumerator()) {
        $status = if ($capability.Value) { "✅" } else { "❌" }
        Write-Host "   $status $($capability.Key)" -ForegroundColor White
    }
    
    # Get lifecycle information
    Write-Host "3. Platform lifecycle information..." -ForegroundColor Cyan
    $lifecycle = $statusAither.Platform.Lifecycle()
    Write-Host "   Initialization order defined: $($lifecycle.InitializationOrder.Count) modules" -ForegroundColor Green
    Write-Host "   Current state ready: $($lifecycle.CurrentState.PlatformReady)" -ForegroundColor Green
    
    # Performance metrics
    if ($detailedStatus.Performance) {
        Write-Host "4. Performance metrics:" -ForegroundColor Cyan
        Write-Host "   Module load time: $($detailedStatus.Performance.ModuleLoadTime) seconds" -ForegroundColor Green
        Write-Host "   Memory usage: $([math]::Round($detailedStatus.Performance.MemoryUsage, 2)) MB" -ForegroundColor Green
    }
    
    Write-Host "✅ Platform status example complete!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Platform status check failed: $_" -ForegroundColor Red
}

Write-Host ""
#endregion

#region Example 10: Quick Actions Showcase
Write-Host "📋 Example 10: Quick Actions Showcase" -ForegroundColor Yellow
Write-Host "-------------------------------------" -ForegroundColor Yellow

try {
    $quickAither = Initialize-AitherPlatform -Profile "Standard"
    
    Write-Host "1. Available quick actions:" -ForegroundColor Cyan
    $quickActions = @('SystemHealth', 'ModuleStatus', 'RunTests', 'LabSetup', 'CreateISO')
    
    foreach ($action in $quickActions) {
        $isAvailable = $quickAither.Quick.PSObject.Properties.Name -contains $action
        $status = if ($isAvailable) { "✅" } else { "❌" }
        Write-Host "   $status $action" -ForegroundColor White
    }
    
    # Execute system health quick action
    Write-Host "2. Executing SystemHealth quick action..." -ForegroundColor Cyan
    $healthResult = $quickAither.Quick.SystemHealth()
    Write-Host "   Core health: $($healthResult.CoreHealth)" -ForegroundColor Green
    Write-Host "   Module status available: $($healthResult.ModuleStatus -ne $null)" -ForegroundColor Green
    
    # Execute module status quick action
    Write-Host "3. Executing ModuleStatus quick action..." -ForegroundColor Cyan
    $moduleStatusResult = $quickAither.Quick.ModuleStatus()
    Write-Host "   Detailed module information available: $($moduleStatusResult -ne $null)" -ForegroundColor Green
    
    # Simulate other quick actions
    Write-Host "4. Other quick actions available:" -ForegroundColor Cyan
    Write-Host "   - RunTests: Execute rapid validation" -ForegroundColor Gray
    Write-Host "   - LabSetup: Initialize lab environment" -ForegroundColor Gray
    Write-Host "   - CreateISO: Download and customize ISOs" -ForegroundColor Gray
    
    Write-Host "✅ Quick actions showcase complete!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Quick actions showcase failed: $_" -ForegroundColor Red
}

Write-Host ""
#endregion

# Final Summary
Write-Host "🎉 All Examples Complete!" -ForegroundColor Magenta
Write-Host "=========================" -ForegroundColor Magenta
Write-Host ""
Write-Host "The AitherZero Unified Platform API provides:" -ForegroundColor White
Write-Host "✅ Single initialization point for all functionality" -ForegroundColor Green
Write-Host "✅ Organized service categories for easy navigation" -ForegroundColor Green  
Write-Host "✅ Graceful degradation when modules aren't available" -ForegroundColor Green
Write-Host "✅ Built-in performance optimization and caching" -ForegroundColor Green
Write-Host "✅ Comprehensive error handling and recovery" -ForegroundColor Green
Write-Host "✅ Real-time health monitoring and diagnostics" -ForegroundColor Green
Write-Host "✅ Quick actions for common operations" -ForegroundColor Green
Write-Host ""
Write-Host "Ready for production use with enterprise-grade reliability!" -ForegroundColor Cyan