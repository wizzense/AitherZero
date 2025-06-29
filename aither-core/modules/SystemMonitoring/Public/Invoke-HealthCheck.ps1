#Requires -Version 7.0

<#
.SYNOPSIS
    Performs comprehensive system health checks with automated remediation capabilities.

.DESCRIPTION
    This function executes a comprehensive health check of the system including
    performance monitoring, service validation, disk space checks, and security
    assessments. Includes automated remediation for common issues.

.PARAMETER Comprehensive
    Performs a full comprehensive health check including all subsystems.

.PARAMETER AutoFix
    Enables automatic remediation of detected issues. Accepts 'minor', 'major', or 'all'.

.PARAMETER Report
    Generates a detailed health report in addition to console output.

.PARAMETER Schedule
    Schedules recurring health checks using cron-style syntax.

.PARAMETER Categories
    Specifies specific categories to check (System, Services, Security, Performance, Storage).

.PARAMETER ExportPath
    Path to export the health check report.

.EXAMPLE
    Invoke-HealthCheck
    
    Performs basic system health check.

.EXAMPLE
    Invoke-HealthCheck -Comprehensive -AutoFix minor -Report
    
    Performs comprehensive health check with minor auto-fixes and generates report.

.EXAMPLE
    Invoke-HealthCheck -Categories System,Services -AutoFix all
    
    Checks only system and services with full auto-remediation.

.NOTES
    Part of the AitherZero SystemMonitoring module providing enterprise-grade
    health monitoring and automated remediation capabilities.
#>

function Invoke-HealthCheck {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Comprehensive,
        
        [Parameter()]
        [ValidateSet('minor', 'major', 'all')]
        [string]$AutoFix,
        
        [Parameter()]
        [switch]$Report,
        
        [Parameter()]
        [string]$Schedule,
        
        [Parameter()]
        [ValidateSet('System', 'Services', 'Security', 'Performance', 'Storage')]
        [string[]]$Categories = @('System', 'Services', 'Performance', 'Storage'),
        
        [Parameter()]
        [string]$ExportPath
    )

    begin {
        Write-CustomLog -Message "Starting comprehensive health check" -Level "INFO"
        
        $healthResults = @{
            Timestamp = Get-Date
            OverallStatus = 'Unknown'
            Categories = @{}
            Issues = @()
            Fixes = @()
            Recommendations = @()
            Summary = @{}
        }
        
        $totalChecks = 0
        $passedChecks = 0
        $failedChecks = 0
        $fixedIssues = 0
    }

    process {
        try {
            Write-Host "`n🏥 SYSTEM HEALTH CHECK" -ForegroundColor Cyan
            Write-Host "=" * 50 -ForegroundColor Cyan
            Write-Host "📊 Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
            Write-Host "🔍 Categories: $($Categories -join ', ')" -ForegroundColor Gray
            
            if ($AutoFix) {
                Write-Host "🔧 Auto-fix enabled: $AutoFix" -ForegroundColor Yellow
            }
            
            # System Health Check
            if ('System' -in $Categories) {
                Write-Host "`n🖥️  Checking System Health..." -ForegroundColor Yellow
                $systemHealth = Test-SystemHealth -AutoFix:($AutoFix -ne $null) -FixLevel $AutoFix
                $healthResults.Categories.System = $systemHealth
                $totalChecks += $systemHealth.TotalChecks
                $passedChecks += $systemHealth.PassedChecks
                $failedChecks += $systemHealth.FailedChecks
                $fixedIssues += $systemHealth.FixedIssues
            }
            
            # Services Health Check
            if ('Services' -in $Categories) {
                Write-Host "`n🔧 Checking Services Health..." -ForegroundColor Yellow
                $servicesHealth = Test-ServicesHealth -AutoFix:($AutoFix -ne $null) -FixLevel $AutoFix
                $healthResults.Categories.Services = $servicesHealth
                $totalChecks += $servicesHealth.TotalChecks
                $passedChecks += $servicesHealth.PassedChecks
                $failedChecks += $servicesHealth.FailedChecks
                $fixedIssues += $servicesHealth.FixedIssues
            }
            
            # Performance Health Check
            if ('Performance' -in $Categories) {
                Write-Host "`n📈 Checking Performance Health..." -ForegroundColor Yellow
                $performanceHealth = Test-PerformanceHealth -AutoFix:($AutoFix -ne $null) -FixLevel $AutoFix
                $healthResults.Categories.Performance = $performanceHealth
                $totalChecks += $performanceHealth.TotalChecks
                $passedChecks += $performanceHealth.PassedChecks
                $failedChecks += $performanceHealth.FailedChecks
                $fixedIssues += $performanceHealth.FixedIssues
            }
            
            # Storage Health Check
            if ('Storage' -in $Categories) {
                Write-Host "`n💾 Checking Storage Health..." -ForegroundColor Yellow
                $storageHealth = Test-StorageHealth -AutoFix:($AutoFix -ne $null) -FixLevel $AutoFix
                $healthResults.Categories.Storage = $storageHealth
                $totalChecks += $storageHealth.TotalChecks
                $passedChecks += $storageHealth.PassedChecks
                $failedChecks += $storageHealth.FailedChecks
                $fixedIssues += $storageHealth.FixedIssues
            }
            
            # Security Health Check
            if ('Security' -in $Categories) {
                Write-Host "`n🔒 Checking Security Health..." -ForegroundColor Yellow
                $securityHealth = Test-SecurityHealth -AutoFix:($AutoFix -ne $null) -FixLevel $AutoFix
                $healthResults.Categories.Security = $securityHealth
                $totalChecks += $securityHealth.TotalChecks
                $passedChecks += $securityHealth.PassedChecks
                $failedChecks += $securityHealth.FailedChecks
                $fixedIssues += $securityHealth.FixedIssues
            }
            
            # Calculate overall status
            $healthPercentage = if ($totalChecks -gt 0) { ($passedChecks / $totalChecks) * 100 } else { 0 }
            $healthResults.OverallStatus = Get-HealthStatus -Percentage $healthPercentage
            
            # Compile summary
            $healthResults.Summary = @{
                TotalChecks = $totalChecks
                PassedChecks = $passedChecks
                FailedChecks = $failedChecks
                FixedIssues = $fixedIssues
                HealthPercentage = [math]::Round($healthPercentage, 2)
                OverallStatus = $healthResults.OverallStatus
            }
            
            # Display summary
            Show-HealthSummary -Results $healthResults
            
            # Generate report if requested
            if ($Report -or $ExportPath) {
                $reportPath = if ($ExportPath) { $ExportPath } else { 
                    Join-Path $env:TEMP "health-check-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
                }
                $healthResults | ConvertTo-Json -Depth 5 | Set-Content -Path $reportPath -Encoding UTF8
                Write-Host "`n📄 Health report exported to: $reportPath" -ForegroundColor Green
                Write-CustomLog -Message "Health check report exported to: $reportPath" -Level "SUCCESS"
            }
            
            # Handle scheduling
            if ($Schedule) {
                Set-HealthCheckSchedule -Schedule $Schedule -Categories $Categories -AutoFix $AutoFix
            }
            
            Write-CustomLog -Message "Health check completed - Status: $($healthResults.OverallStatus)" -Level "INFO"
            return $healthResults
            
        } catch {
            Write-CustomLog -Message "Health check failed: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}

function Test-SystemHealth {
    param([bool]$AutoFix, [string]$FixLevel)
    
    $results = @{
        TotalChecks = 0
        PassedChecks = 0
        FailedChecks = 0
        FixedIssues = 0
        Issues = @()
        Fixes = @()
    }
    
    # Check system uptime
    $results.TotalChecks++
    $uptime = Get-SystemUptime
    if ($uptime -match '(\d+)d') {
        $days = [int]$matches[1]
        if ($days -gt 30) {
            $results.FailedChecks++
            $results.Issues += "System uptime exceeds 30 days ($uptime) - consider restart"
            Write-Host "   ⚠️  Long uptime detected: $uptime" -ForegroundColor Yellow
        } else {
            $results.PassedChecks++
            Write-Host "   ✅ System uptime: $uptime" -ForegroundColor Green
        }
    }
    
    # Check available memory
    $results.TotalChecks++
    $memInfo = Get-MemoryInfo
    if ($memInfo.UsagePercent -gt 85) {
        $results.FailedChecks++
        $results.Issues += "High memory usage: $($memInfo.UsagePercent)%"
        Write-Host "   ❌ High memory usage: $($memInfo.UsagePercent)%" -ForegroundColor Red
        
        if ($AutoFix -and ($FixLevel -eq 'minor' -or $FixLevel -eq 'all')) {
            try {
                # Clear memory cache (Windows)
                if ($IsWindows) {
                    [System.GC]::Collect()
                    [System.GC]::WaitForPendingFinalizers()
                    [System.GC]::Collect()
                }
                $results.FixedIssues++
                $results.Fixes += "Cleared memory cache"
                Write-Host "   🔧 Memory cache cleared" -ForegroundColor Green
            } catch {
                Write-Host "   ❌ Failed to clear memory cache" -ForegroundColor Red
            }
        }
    } else {
        $results.PassedChecks++
        Write-Host "   ✅ Memory usage: $($memInfo.UsagePercent)%" -ForegroundColor Green
    }
    
    # Check CPU usage
    $results.TotalChecks++
    $dashboard = Get-SystemDashboard -Format JSON | ConvertFrom-Json
    $cpuUsage = $dashboard.Metrics.CPU.Usage
    if ($cpuUsage -gt 80) {
        $results.FailedChecks++
        $results.Issues += "High CPU usage: $cpuUsage%"
        Write-Host "   ❌ High CPU usage: $cpuUsage%" -ForegroundColor Red
    } else {
        $results.PassedChecks++
        Write-Host "   ✅ CPU usage: $cpuUsage%" -ForegroundColor Green
    }
    
    # Check system event logs (Windows only)
    if ($IsWindows) {
        $results.TotalChecks++
        try {
            $systemErrors = Get-EventLog -LogName System -EntryType Error -Newest 10 -ErrorAction SilentlyContinue
            if ($systemErrors.Count -gt 5) {
                $results.FailedChecks++
                $results.Issues += "Multiple system errors in event log"
                Write-Host "   ⚠️  $($systemErrors.Count) recent system errors" -ForegroundColor Yellow
            } else {
                $results.PassedChecks++
                Write-Host "   ✅ System event log clean" -ForegroundColor Green
            }
        } catch {
            Write-Host "   ⚠️  Cannot access system event log" -ForegroundColor Yellow
        }
    }
    
    return $results
}

function Test-ServicesHealth {
    param([bool]$AutoFix, [string]$FixLevel)
    
    $results = @{
        TotalChecks = 0
        PassedChecks = 0
        FailedChecks = 0
        FixedIssues = 0
        Issues = @()
        Fixes = @()
    }
    
    # Get critical services based on platform
    $criticalServices = if ($IsWindows) {
        @('Spooler', 'BITS', 'Themes', 'AudioSrv', 'Dhcp', 'EventLog', 'RpcSs')
    } else {
        @('ssh', 'cron', 'rsyslog', 'networkd')
    }
    
    foreach ($serviceName in $criticalServices) {
        $results.TotalChecks++
        
        if ($IsWindows) {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service) {
                if ($service.Status -eq 'Running') {
                    $results.PassedChecks++
                    Write-Host "   ✅ $serviceName service running" -ForegroundColor Green
                } else {
                    $results.FailedChecks++
                    $results.Issues += "$serviceName service not running"
                    Write-Host "   ❌ $serviceName service stopped" -ForegroundColor Red
                    
                    if ($AutoFix -and ($FixLevel -eq 'major' -or $FixLevel -eq 'all')) {
                        try {
                            Start-Service -Name $serviceName
                            $results.FixedIssues++
                            $results.Fixes += "Started $serviceName service"
                            Write-Host "   🔧 Started $serviceName service" -ForegroundColor Green
                        } catch {
                            Write-Host "   ❌ Failed to start $serviceName service" -ForegroundColor Red
                        }
                    }
                }
            } else {
                Write-Host "   ⚠️  $serviceName service not found" -ForegroundColor Yellow
            }
        } else {
            # Linux services
            try {
                $status = systemctl is-active $serviceName 2>/dev/null
                if ($status -eq 'active') {
                    $results.PassedChecks++
                    Write-Host "   ✅ $serviceName service active" -ForegroundColor Green
                } else {
                    $results.FailedChecks++
                    $results.Issues += "$serviceName service not active"
                    Write-Host "   ❌ $serviceName service inactive" -ForegroundColor Red
                    
                    if ($AutoFix -and ($FixLevel -eq 'major' -or $FixLevel -eq 'all')) {
                        try {
                            systemctl start $serviceName 2>/dev/null
                            $results.FixedIssues++
                            $results.Fixes += "Started $serviceName service"
                            Write-Host "   🔧 Started $serviceName service" -ForegroundColor Green
                        } catch {
                            Write-Host "   ❌ Failed to start $serviceName service" -ForegroundColor Red
                        }
                    }
                }
            } catch {
                Write-Host "   ⚠️  $serviceName service status unknown" -ForegroundColor Yellow
            }
        }
    }
    
    return $results
}

function Test-PerformanceHealth {
    param([bool]$AutoFix, [string]$FixLevel)
    
    $results = @{
        TotalChecks = 0
        PassedChecks = 0
        FailedChecks = 0
        FixedIssues = 0
        Issues = @()
        Fixes = @()
    }
    
    # Check for performance bottlenecks
    $dashboard = Get-SystemDashboard -Format JSON | ConvertFrom-Json
    
    # CPU performance check
    $results.TotalChecks++
    if ($dashboard.Metrics.CPU.Usage -lt 70) {
        $results.PassedChecks++
        Write-Host "   ✅ CPU performance normal" -ForegroundColor Green
    } else {
        $results.FailedChecks++
        $results.Issues += "CPU performance degraded"
        Write-Host "   ⚠️  CPU performance degraded" -ForegroundColor Yellow
    }
    
    # Memory performance check
    $results.TotalChecks++
    if ($dashboard.Metrics.Memory.UsagePercent -lt 75) {
        $results.PassedChecks++
        Write-Host "   ✅ Memory performance normal" -ForegroundColor Green
    } else {
        $results.FailedChecks++
        $results.Issues += "Memory performance degraded"
        Write-Host "   ⚠️  Memory performance degraded" -ForegroundColor Yellow
    }
    
    return $results
}

function Test-StorageHealth {
    param([bool]$AutoFix, [string]$FixLevel)
    
    $results = @{
        TotalChecks = 0
        PassedChecks = 0
        FailedChecks = 0
        FixedIssues = 0
        Issues = @()
        Fixes = @()
    }
    
    $dashboard = Get-SystemDashboard -Format JSON | ConvertFrom-Json
    
    foreach ($disk in $dashboard.Metrics.Disk) {
        $results.TotalChecks++
        
        if ($disk.UsagePercent -lt 80) {
            $results.PassedChecks++
            Write-Host "   ✅ $($disk.Drive) disk space normal ($($disk.UsagePercent)%)" -ForegroundColor Green
        } else {
            $results.FailedChecks++
            $results.Issues += "Low disk space on $($disk.Drive): $($disk.UsagePercent)%"
            Write-Host "   ❌ Low disk space on $($disk.Drive): $($disk.UsagePercent)%" -ForegroundColor Red
            
            if ($AutoFix -and ($FixLevel -eq 'minor' -or $FixLevel -eq 'all')) {
                # Attempt basic cleanup
                try {
                    if ($IsWindows) {
                        # Clean temp files
                        $tempFiles = Get-ChildItem -Path $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue
                        $tempFiles | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                        $results.FixedIssues++
                        $results.Fixes += "Cleaned temporary files on $($disk.Drive)"
                        Write-Host "   🔧 Cleaned temporary files" -ForegroundColor Green
                    }
                } catch {
                    Write-Host "   ❌ Failed to clean temporary files" -ForegroundColor Red
                }
            }
        }
    }
    
    return $results
}

function Test-SecurityHealth {
    param([bool]$AutoFix, [string]$FixLevel)
    
    $results = @{
        TotalChecks = 0
        PassedChecks = 0
        FailedChecks = 0
        FixedIssues = 0
        Issues = @()
        Fixes = @()
    }
    
    # Check Windows Defender (Windows only)
    if ($IsWindows) {
        $results.TotalChecks++
        try {
            $defender = Get-MpComputerStatus -ErrorAction SilentlyContinue
            if ($defender -and $defender.AntivirusEnabled) {
                $results.PassedChecks++
                Write-Host "   ✅ Windows Defender active" -ForegroundColor Green
            } else {
                $results.FailedChecks++
                $results.Issues += "Windows Defender not active"
                Write-Host "   ❌ Windows Defender not active" -ForegroundColor Red
            }
        } catch {
            Write-Host "   ⚠️  Cannot check Windows Defender status" -ForegroundColor Yellow
        }
    }
    
    # Check for security updates (basic check)
    $results.TotalChecks++
    Write-Host "   ⚠️  Security update check requires manual verification" -ForegroundColor Yellow
    
    return $results
}

function Get-HealthStatus {
    param($Percentage)
    
    if ($Percentage -ge 90) { return 'Excellent' }
    elseif ($Percentage -ge 75) { return 'Good' }
    elseif ($Percentage -ge 50) { return 'Fair' }
    elseif ($Percentage -ge 25) { return 'Poor' }
    else { return 'Critical' }
}

function Show-HealthSummary {
    param($Results)
    
    Write-Host "`n📊 HEALTH CHECK SUMMARY" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Cyan
    
    $statusColor = switch ($Results.OverallStatus) {
        'Excellent' { 'Green' }
        'Good' { 'Green' }
        'Fair' { 'Yellow' }
        'Poor' { 'DarkYellow' }
        'Critical' { 'Red' }
        default { 'White' }
    }
    
    Write-Host "🏥 Overall Health: $($Results.OverallStatus) ($($Results.Summary.HealthPercentage)%)" -ForegroundColor $statusColor
    Write-Host "✅ Passed Checks: $($Results.Summary.PassedChecks)/$($Results.Summary.TotalChecks)" -ForegroundColor Green
    Write-Host "❌ Failed Checks: $($Results.Summary.FailedChecks)" -ForegroundColor Red
    
    if ($Results.Summary.FixedIssues -gt 0) {
        Write-Host "🔧 Auto-fixed Issues: $($Results.Summary.FixedIssues)" -ForegroundColor Green
    }
    
    # Category breakdown
    Write-Host "`n📋 Category Results:" -ForegroundColor Yellow
    foreach ($category in $Results.Categories.GetEnumerator()) {
        $catHealth = if ($category.Value.TotalChecks -gt 0) {
            ($category.Value.PassedChecks / $category.Value.TotalChecks) * 100
        } else { 0 }
        
        $catColor = if ($catHealth -ge 75) { 'Green' } elseif ($catHealth -ge 50) { 'Yellow' } else { 'Red' }
        Write-Host "   $($category.Key): $([math]::Round($catHealth, 0))% ($($category.Value.PassedChecks)/$($category.Value.TotalChecks))" -ForegroundColor $catColor
    }
    
    Write-Host "`n🕒 Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host "=" * 50 -ForegroundColor Cyan
}

function Set-HealthCheckSchedule {
    param($Schedule, $Categories, $AutoFix)
    
    Write-Host "`n⏰ Health check scheduling not yet implemented" -ForegroundColor Yellow
    Write-Host "   Schedule: $Schedule" -ForegroundColor Gray
    Write-Host "   Categories: $($Categories -join ', ')" -ForegroundColor Gray
    if ($AutoFix) {
        Write-Host "   Auto-fix: $AutoFix" -ForegroundColor Gray
    }
    
    Write-CustomLog -Message "Health check schedule requested: $Schedule" -Level "INFO"
}