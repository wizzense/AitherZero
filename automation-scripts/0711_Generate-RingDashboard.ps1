#Requires -Version 7.0

<#
.SYNOPSIS
    Generate a visual ring deployment dashboard

.DESCRIPTION
    Creates an HTML dashboard showing the current state of all rings,
    recent promotions, test results, and promotion readiness.

.PARAMETER OutputPath
    Path where the HTML dashboard should be saved

.PARAMETER OpenBrowser
    Open the dashboard in the default browser after generation

.EXAMPLE
    ./0711_Generate-RingDashboard.ps1
    Generate dashboard in default location

.EXAMPLE
    ./0711_Generate-RingDashboard.ps1 -OpenBrowser
    Generate dashboard and open in browser

.NOTES
    Author: AitherZero Team
    Stage: Development
    Dependencies: Git, PowerShell 7+
    Tags: rings, dashboard, visualization, reporting
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "./reports/ring-dashboard.html",
    
    [Parameter(Mandatory = $false)]
    [switch]$OpenBrowser
)

# Get project root
$ProjectRoot = if ($PSScriptRoot) {
    Split-Path $PSScriptRoot -Parent
} else {
    Get-Location | Select-Object -ExpandProperty Path
}

function Get-RingConfiguration {
    $configPath = Join-Path $ProjectRoot ".github/ring-config.json"
    
    if (-not (Test-Path $configPath)) {
        Write-Error "Ring configuration not found: $configPath"
        return $null
    }
    
    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        return $config
    } catch {
        Write-Error "Failed to parse ring configuration: $_"
        return $null
    }
}

function Get-RingStatus {
    $config = Get-RingConfiguration
    if (-not $config) {
        return $null
    }
    
    $rings = @()
    
    foreach ($ringName in ($config.rings.PSObject.Properties.Name | Sort-Object { $config.rings.$_.level })) {
        $ring = $config.rings.$ringName
        
        # Check if branch exists
        $branchExists = $false
        $latestCommit = $null
        
        try {
            $commitInfo = git log origin/$ringName -1 --format="%H|%an|%s|%ci|%cr" 2>$null
            if ($commitInfo) {
                $parts = $commitInfo -split '\|'
                $latestCommit = @{
                    Hash = $parts[0]
                    ShortHash = $parts[0].Substring(0, 7)
                    Author = $parts[1]
                    Message = $parts[2]
                    Date = $parts[3]
                    RelativeDate = $parts[4]
                }
                $branchExists = $true
            }
        } catch {
            # Branch doesn't exist
        }
        
        $rings += @{
            Name = $ringName
            Level = $ring.level
            DisplayName = $ring.name
            Description = $ring.description
            Type = $ring.type
            TestProfile = $ring.testProfile
            TestDuration = $config.testProfiles.($ring.testProfile).estimatedDuration
            RequiredApprovals = $ring.requiredApprovals
            BranchExists = $branchExists
            LatestCommit = $latestCommit
            NextRing = $ring.nextRing
            PreviousRing = $ring.previousRing
            Protected = $ring.protected -eq $true
            Color = $ring.color
            Gates = $ring.deploymentGates
        }
    }
    
    return $rings
}

function Generate-DashboardHTML {
    param(
        [array]$Rings
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🎯 Ring Deployment Dashboard - AitherZero</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            color: #fff;
            padding: 20px;
            min-height: 100vh;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
        }
        
        .header {
            text-align: center;
            margin-bottom: 40px;
            padding: 20px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        
        .header .subtitle {
            font-size: 1.2em;
            opacity: 0.9;
        }
        
        .header .timestamp {
            margin-top: 10px;
            font-size: 0.9em;
            opacity: 0.7;
        }
        
        .rings-container {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 20px;
            margin-bottom: 40px;
        }
        
        .ring-card {
            background: rgba(255, 255, 255, 0.1);
            border-radius: 10px;
            padding: 20px;
            backdrop-filter: blur(10px);
            border: 2px solid rgba(255, 255, 255, 0.2);
            transition: all 0.3s ease;
            position: relative;
        }
        
        .ring-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
            border-color: rgba(255, 255, 255, 0.4);
        }
        
        .ring-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 15px;
            padding-bottom: 15px;
            border-bottom: 1px solid rgba(255, 255, 255, 0.2);
        }
        
        .ring-name {
            font-size: 1.3em;
            font-weight: bold;
        }
        
        .ring-level {
            background: rgba(255, 255, 255, 0.2);
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 0.9em;
        }
        
        .ring-description {
            margin-bottom: 15px;
            font-size: 0.95em;
            opacity: 0.9;
            line-height: 1.5;
        }
        
        .ring-info {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 10px;
            margin-bottom: 15px;
        }
        
        .info-item {
            background: rgba(0, 0, 0, 0.2);
            padding: 10px;
            border-radius: 5px;
        }
        
        .info-label {
            font-size: 0.8em;
            opacity: 0.7;
            margin-bottom: 5px;
        }
        
        .info-value {
            font-size: 1.1em;
            font-weight: 600;
        }
        
        .ring-status {
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 10px;
            background: rgba(0, 0, 0, 0.2);
            border-radius: 5px;
            margin-bottom: 15px;
        }
        
        .status-indicator {
            width: 12px;
            height: 12px;
            border-radius: 50%;
        }
        
        .status-active {
            background: #4CAF50;
            box-shadow: 0 0 10px #4CAF50;
        }
        
        .status-missing {
            background: #f44336;
            box-shadow: 0 0 10px #f44336;
        }
        
        .commit-info {
            background: rgba(0, 0, 0, 0.3);
            padding: 10px;
            border-radius: 5px;
            font-size: 0.9em;
        }
        
        .commit-hash {
            font-family: 'Courier New', monospace;
            color: #81C784;
        }
        
        .commit-message {
            margin-top: 5px;
            opacity: 0.9;
        }
        
        .commit-author {
            margin-top: 5px;
            font-size: 0.85em;
            opacity: 0.7;
        }
        
        .gates {
            display: flex;
            flex-wrap: wrap;
            gap: 5px;
            margin-top: 10px;
        }
        
        .gate {
            background: rgba(0, 0, 0, 0.2);
            padding: 5px 10px;
            border-radius: 15px;
            font-size: 0.8em;
            display: flex;
            align-items: center;
            gap: 5px;
        }
        
        .gate-enabled {
            color: #4CAF50;
        }
        
        .gate-disabled {
            color: #9E9E9E;
            opacity: 0.5;
        }
        
        .hierarchy {
            background: rgba(255, 255, 255, 0.1);
            border-radius: 10px;
            padding: 30px;
            backdrop-filter: blur(10px);
            margin-bottom: 40px;
        }
        
        .hierarchy h2 {
            margin-bottom: 20px;
            text-align: center;
        }
        
        .hierarchy-visual {
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 10px;
        }
        
        .hierarchy-ring {
            background: rgba(255, 255, 255, 0.1);
            padding: 15px 30px;
            border-radius: 10px;
            min-width: 300px;
            text-align: center;
            border: 2px solid rgba(255, 255, 255, 0.2);
        }
        
        .hierarchy-arrow {
            font-size: 2em;
            opacity: 0.5;
        }
        
        .legend {
            background: rgba(255, 255, 255, 0.1);
            border-radius: 10px;
            padding: 20px;
            backdrop-filter: blur(10px);
            display: flex;
            justify-content: center;
            gap: 30px;
            flex-wrap: wrap;
        }
        
        .legend-item {
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .protected-badge {
            background: #FF9800;
            color: #000;
            padding: 2px 8px;
            border-radius: 10px;
            font-size: 0.8em;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎯 Ring Deployment Dashboard</h1>
            <div class="subtitle">AitherZero Progressive Deployment System</div>
            <div class="timestamp">Last Updated: $timestamp</div>
        </div>
        
        <div class="hierarchy">
            <h2>Ring Hierarchy</h2>
            <div class="hierarchy-visual">
"@
    
    # Add hierarchy visualization
    foreach ($ring in $Rings) {
        $statusClass = if ($ring.BranchExists) { 'status-active' } else { 'status-missing' }
        $protectedBadge = if ($ring.Protected) { '<span class="protected-badge">🔒 Protected</span>' } else { '' }
        
        $html += @"
                <div class="hierarchy-ring">
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                        <div>
                            <div class="status-indicator $statusClass" style="display: inline-block;"></div>
                            <strong>$($ring.DisplayName)</strong> $protectedBadge
                        </div>
                        <div style="opacity: 0.7;">Level $($ring.Level)</div>
                    </div>
                    <div style="margin-top: 5px; font-size: 0.9em; opacity: 0.7;">$($ring.TestProfile) • $($ring.TestDuration)</div>
                </div>
"@
        
        if ($ring.NextRing) {
            $html += '                <div class="hierarchy-arrow">↓</div>' + "`n"
        }
    }
    
    $html += @"
            </div>
        </div>
        
        <div class="rings-container">
"@
    
    # Add ring cards
    foreach ($ring in $Rings) {
        $statusClass = if ($ring.BranchExists) { 'status-active' } else { 'status-missing' }
        $statusText = if ($ring.BranchExists) { '✅ Active' } else { '❌ Branch Missing' }
        $protectedBadge = if ($ring.Protected) { '<span class="protected-badge">🔒 Protected</span>' } else { '' }
        
        $html += @"
            <div class="ring-card">
                <div class="ring-header">
                    <div class="ring-name">$($ring.Name) $protectedBadge</div>
                    <div class="ring-level">Level $($ring.Level)</div>
                </div>
                
                <div class="ring-description">$($ring.Description)</div>
                
                <div class="ring-info">
                    <div class="info-item">
                        <div class="info-label">Type</div>
                        <div class="info-value">$($ring.Type)</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Test Profile</div>
                        <div class="info-value">$($ring.TestProfile)</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Duration</div>
                        <div class="info-value">$($ring.TestDuration)</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Approvals</div>
                        <div class="info-value">$($ring.RequiredApprovals)</div>
                    </div>
                </div>
                
                <div class="ring-status">
                    <div class="status-indicator $statusClass"></div>
                    <div>$statusText</div>
                </div>
"@
        
        if ($ring.LatestCommit) {
            $html += @"
                <div class="commit-info">
                    <div><span class="commit-hash">$($ring.LatestCommit.ShortHash)</span> • $($ring.LatestCommit.RelativeDate)</div>
                    <div class="commit-message">$($ring.LatestCommit.Message)</div>
                    <div class="commit-author">by $($ring.LatestCommit.Author)</div>
                </div>
"@
        } else {
            $html += @"
                <div class="commit-info">
                    <div style="opacity: 0.5;">No commits yet</div>
                </div>
"@
        }
        
        # Add deployment gates
        $html += '                <div class="gates">' + "`n"
        foreach ($gate in $ring.Gates.PSObject.Properties) {
            $gateClass = if ($gate.Value) { 'gate-enabled' } else { 'gate-disabled' }
            $gateIcon = if ($gate.Value) { '✅' } else { '⏭️' }
            $html += "                    <div class=`"gate $gateClass`">$gateIcon $($gate.Name)</div>`n"
        }
        $html += '                </div>' + "`n"
        
        $html += '            </div>' + "`n"
    }
    
    $html += @"
        </div>
        
        <div class="legend">
            <div class="legend-item">
                <div class="status-indicator status-active"></div>
                <div>Branch Active</div>
            </div>
            <div class="legend-item">
                <div class="status-indicator status-missing"></div>
                <div>Branch Missing</div>
            </div>
            <div class="legend-item">
                <span class="protected-badge">🔒 Protected</span>
                <div>Protected Branch</div>
            </div>
        </div>
    </div>
</body>
</html>
"@
    
    return $html
}

# Main execution
try {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "🎯 Generating Ring Deployment Dashboard" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "📊 Fetching ring status..." -ForegroundColor Yellow
    $rings = Get-RingStatus
    
    if (-not $rings) {
        Write-Error "Failed to get ring status"
        exit 1
    }
    
    Write-Host "✅ Found $($rings.Count) rings" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "📝 Generating HTML dashboard..." -ForegroundColor Yellow
    $html = Generate-DashboardHTML -Rings $rings
    
    # Ensure output directory exists
    $outputDir = Split-Path $OutputPath -Parent
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    # Write HTML file
    $html | Out-File -FilePath $OutputPath -Encoding UTF8
    
    Write-Host "✅ Dashboard saved to: $OutputPath" -ForegroundColor Green
    Write-Host ""
    
    if ($OpenBrowser) {
        Write-Host "🌐 Opening dashboard in browser..." -ForegroundColor Yellow
        $fullPath = Resolve-Path $OutputPath
        
        if ($IsWindows) {
            Start-Process $fullPath
        } elseif ($IsMacOS) {
            open $fullPath
        } elseif ($IsLinux) {
            xdg-open $fullPath 2>$null || Write-Host "ℹ️ Please open $fullPath manually" -ForegroundColor Yellow
        }
    } else {
        Write-Host "ℹ️ To view the dashboard, open: $OutputPath" -ForegroundColor Cyan
    }
    
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    
} catch {
    Write-Error "Failed to generate dashboard: $_"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
