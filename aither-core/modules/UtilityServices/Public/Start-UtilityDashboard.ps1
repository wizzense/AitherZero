function Start-UtilityDashboard {
    <#
    .SYNOPSIS
        Starts an interactive utility services dashboard
    
    .DESCRIPTION
        Provides a real-time dashboard showing the status of all utility services,
        active operations, metrics, and system health
    
    .PARAMETER RefreshInterval
        Dashboard refresh interval in seconds
    
    .PARAMETER ShowMetrics
        Whether to display detailed metrics
    
    .EXAMPLE
        Start-UtilityDashboard
        
        Start the dashboard with default settings
    
    .EXAMPLE
        Start-UtilityDashboard -RefreshInterval 5 -ShowMetrics
        
        Start dashboard with 5-second refresh and detailed metrics
    #>
    [CmdletBinding()]
    param(
        [int]$RefreshInterval = 10,
        [switch]$ShowMetrics
    )
    
    Write-UtilityLog "🖥️ Starting UtilityServices Dashboard" -Level "INFO"
    
    try {
        $dashboardActive = $true
        
        Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║                          AitherZero UtilityServices Dashboard                  ║" -ForegroundColor Cyan  
        Write-Host "║                              Press 'Q' to quit                                ║" -ForegroundColor Cyan
        Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        
        while ($dashboardActive) {
            # Clear screen for refresh
            Clear-Host
            
            # Header
            Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
            Write-Host "║                          AitherZero UtilityServices Dashboard                  ║" -ForegroundColor Cyan
            Write-Host "║                      $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Refresh: ${RefreshInterval}s | Press 'Q' to quit                    ║" -ForegroundColor Cyan
            Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
            Write-Host ""
            
            # Service Status
            $status = Get-UtilityServiceStatus
            Write-Host "🔧 Service Status" -ForegroundColor Yellow
            Write-Host "├─ Overall Health: " -NoNewline -ForegroundColor White
            
            $healthColor = switch ($status.SystemHealth) {
                'Healthy' { 'Green' }
                'Degraded' { 'Yellow' }
                'Critical' { 'Red' }
                default { 'White' }
            }
            Write-Host $status.SystemHealth -ForegroundColor $healthColor
            
            foreach ($serviceName in $status.Services.Keys) {
                $service = $status.Services[$serviceName]
                $statusIcon = if ($service.Loaded) { "✅" } else { "❌" }
                $functionCount = $service.FunctionCount
                
                Write-Host "├─ $statusIcon $serviceName`: " -NoNewline -ForegroundColor White
                if ($service.Loaded) {
                    Write-Host "$($service.Status) ($functionCount functions)" -ForegroundColor Green
                } else {
                    Write-Host "$($service.Status)" -ForegroundColor Red
                }
            }
            
            Write-Host "└─ Active Integrated Operations: $($status.IntegratedOperations)" -ForegroundColor White
            Write-Host ""
            
            # Event System Status
            Write-Host "📡 Event System" -ForegroundColor Yellow
            Write-Host "├─ Status: " -NoNewline -ForegroundColor White
            if ($status.EventSystem.Enabled) {
                Write-Host "Active" -ForegroundColor Green
            } else {
                Write-Host "Disabled" -ForegroundColor Red
            }
            Write-Host "├─ Subscribers: $($status.EventSystem.Subscribers)" -ForegroundColor White
            Write-Host "└─ Event History: $($status.EventSystem.EventHistory) events" -ForegroundColor White
            Write-Host ""
            
            # Metrics (if enabled)
            if ($ShowMetrics) {
                $metrics = Get-UtilityMetrics -TimeRange "LastHour"
                
                Write-Host "📊 Metrics (Last Hour)" -ForegroundColor Yellow
                Write-Host "├─ Integrated Operations" -ForegroundColor White
                Write-Host "│  ├─ Total: $($metrics.IntegratedOperations.Total)" -ForegroundColor White
                Write-Host "│  ├─ Successful: $($metrics.IntegratedOperations.Successful)" -ForegroundColor Green
                Write-Host "│  ├─ Failed: $($metrics.IntegratedOperations.Failed)" -ForegroundColor Red
                if ($metrics.IntegratedOperations.AverageExecutionTime -gt 0) {
                    Write-Host "│  └─ Avg Execution Time: $([Math]::Round($metrics.IntegratedOperations.AverageExecutionTime, 2))s" -ForegroundColor White
                }
                Write-Host "└─ Events Published: $($metrics.EventSystem.EventsPublished)" -ForegroundColor White
                Write-Host ""
            }
            
            # Recent Activity
            $recentEvents = Get-UtilityEvents -Count 5
            if ($recentEvents) {
                Write-Host "📋 Recent Activity" -ForegroundColor Yellow
                foreach ($event in $recentEvents) {
                    $timeAgo = ((Get-Date) - $event.Timestamp).TotalMinutes
                    $timeDisplay = if ($timeAgo -lt 1) { "< 1m ago" } else { "$([Math]::Floor($timeAgo))m ago" }
                    Write-Host "├─ [$timeDisplay] $($event.EventType) from $($event.Source)" -ForegroundColor Gray
                }
                Write-Host "└─ (Use Get-UtilityEvents for full history)" -ForegroundColor Gray
                Write-Host ""
            }
            
            # Configuration
            $config = Get-UtilityConfiguration
            Write-Host "⚙️ Configuration" -ForegroundColor Yellow
            Write-Host "├─ Log Level: $($config.LogLevel)" -ForegroundColor White
            Write-Host "├─ Progress Tracking: $(if ($config.EnableProgressTracking) { 'Enabled' } else { 'Disabled' })" -ForegroundColor White
            Write-Host "├─ Versioning: $(if ($config.EnableVersioning) { 'Enabled' } else { 'Disabled' })" -ForegroundColor White
            Write-Host "├─ Max Concurrency: $($config.MaxConcurrency)" -ForegroundColor White
            Write-Host "└─ Default Timeout: $($config.DefaultTimeout)s" -ForegroundColor White
            Write-Host ""
            
            Write-Host "Press 'Q' to quit, any other key to refresh..." -ForegroundColor Cyan
            
            # Check for user input
            $timeout = $RefreshInterval * 1000 # Convert to milliseconds
            $startTime = Get-Date
            
            while (((Get-Date) - $startTime).TotalMilliseconds -lt $timeout) {
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    if ($key.Key -eq 'Q' -or $key.Key -eq 'Escape') {
                        $dashboardActive = $false
                        break
                    }
                }
                Start-Sleep -Milliseconds 100
            }
        }
        
        Clear-Host
        Write-UtilityLog "✅ UtilityServices Dashboard stopped" -Level "INFO"
        
    } catch {
        Write-UtilityLog "❌ Dashboard error: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}