#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Docker container entrypoint script for AitherZero
.DESCRIPTION
    Initializes the AitherZero environment, generates reports/dashboards,
    and starts a web server to provide browser access to the platform.
.PARAMETER Port
    Port for the web server (default: 8080)
.PARAMETER SkipValidation
    Skip initial environment validation
.PARAMETER SkipReports
    Skip report generation
#>

[CmdletBinding()]
param(
    [int]$Port = 8080,
    [switch]$SkipValidation,
    [switch]$SkipReports
)

$ErrorActionPreference = 'Continue'
$script:ProjectRoot = '/app'

Write-Host "🚀 AitherZero Container Starting..." -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# Step 1: Initialize AitherZero
if (-not $SkipValidation) {
    Write-Host "`n📋 Step 1: Initializing AitherZero..." -ForegroundColor Yellow
    try {
        & "$script:ProjectRoot/Start-AitherZero.ps1" -Mode Validate
        Write-Host "✅ AitherZero initialized successfully" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Initialization completed with warnings: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n⏭️  Skipping validation" -ForegroundColor Gray
}

# Step 2: Generate reports and dashboards
if (-not $SkipReports) {
    Write-Host "`n📊 Step 2: Generating reports and dashboards..." -ForegroundColor Yellow
    try {
        # Generate project reports
        $reportScript = Join-Path $script:ProjectRoot "automation-scripts/0510_Generate-ProjectReport.ps1"
        if (Test-Path $reportScript) {
            & $reportScript -ErrorAction SilentlyContinue
        }
        
        # Generate dashboard
        $dashboardScript = Join-Path $script:ProjectRoot "automation-scripts/0512_Generate-Dashboard.ps1"
        if (Test-Path $dashboardScript) {
            $cmd = Get-Command $dashboardScript -ErrorAction SilentlyContinue
            if ($cmd -and $cmd.Parameters.ContainsKey('Format')) {
                & $dashboardScript -Format All -ErrorAction SilentlyContinue
            } else {
                & $dashboardScript -ErrorAction SilentlyContinue
            }
        }
        
        Write-Host "✅ Reports generated" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Report generation completed with warnings: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n⏭️  Skipping report generation" -ForegroundColor Gray
}

# Step 3: Prepare web content
Write-Host "`n🌐 Step 3: Preparing web interface..." -ForegroundColor Yellow
$webRoot = Join-Path $script:ProjectRoot "docs-deploy"
if (-not (Test-Path $webRoot)) {
    New-Item -ItemType Directory -Path $webRoot -Force | Out-Null
}

# Generate documentation deployment
try {
    $deployDocScript = Join-Path $script:ProjectRoot "automation-scripts/0515_Deploy-Documentation.ps1"
    if (Test-Path $deployDocScript) {
        & $deployDocScript -OutputPath $webRoot -ErrorAction SilentlyContinue
        # Verify expected output was created
        if (Test-Path (Join-Path $webRoot "index.html")) {
            Write-Host "✅ Web content prepared" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Documentation deployment did not produce expected output, using fallback." -ForegroundColor Yellow
        }
    }
    
    # Create fallback index page if needed
    if (-not (Test-Path (Join-Path $webRoot "index.html"))) {
        $simpleIndex = @"
<!DOCTYPE html>
<html>
<head>
    <title>AitherZero</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            margin: 0;
            padding: 20px;
        }
        .container {
            text-align: center;
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            padding: 60px 40px;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        h1 { font-size: 3rem; margin-bottom: 20px; }
        p { font-size: 1.2rem; opacity: 0.9; }
        .commands {
            background: rgba(0,0,0,0.2);
            padding: 20px;
            border-radius: 10px;
            margin-top: 30px;
            text-align: left;
            font-family: 'Courier New', monospace;
            font-size: 0.9rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 AitherZero</h1>
        <p>Infrastructure Automation Platform</p>
        <p style="font-size: 1rem; margin-top: 20px;">Container is running successfully</p>
        <div class="commands">
            <div><strong>Interactive Shell:</strong></div>
            <div>docker exec -it <container> pwsh</div>
            <br>
            <div><strong>Run Script:</strong></div>
            <div>docker exec -it <container> pwsh -Command "./Start-AitherZero.ps1 -Mode Run -Target script -ScriptNumber 0402"</div>
            <br>
            <div><strong>View Logs:</strong></div>
            <div>docker logs <container></div>
        </div>
    </div>
</body>
</html>
"@
        $simpleIndex | Set-Content -Path (Join-Path $webRoot "index.html") -Encoding UTF8
        Write-Host "✅ Simple web page created" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  Web content preparation completed with warnings: $_" -ForegroundColor Yellow
}

# Step 4: Start web server
Write-Host "`n🌍 Step 4: Starting web server on port $Port..." -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✅ Container is ready!" -ForegroundColor Green
Write-Host "" -ForegroundColor White
Write-Host "🌐 Web Interface: http://localhost:$Port" -ForegroundColor Cyan
Write-Host "🖥️  Interactive CLI: docker exec -it <container> pwsh" -ForegroundColor Cyan
Write-Host "📊 View Logs: docker logs <container>" -ForegroundColor Cyan
Write-Host "" -ForegroundColor White
Write-Host "Press Ctrl+C to stop the container" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# Start the web server
Push-Location $webRoot
try {
    # Check if Python is available for HTTP server
    Write-Host "`n🔵 Starting Python HTTP server..." -ForegroundColor Cyan
    if (Get-Command python3 -ErrorAction SilentlyContinue) {
        python3 -m http.server $Port
    } elseif (Get-Command python -ErrorAction SilentlyContinue) {
        python -m http.server $Port
    } else {
        # Fallback: Keep container alive without web server
        Write-Host "⚠️  Python not found, web server unavailable" -ForegroundColor Yellow
        Write-Host "   Container will stay alive for CLI access" -ForegroundColor Gray
        Write-Host "`n⏳ Container running (use docker exec for CLI access)..." -ForegroundColor Cyan
        
        # Keep the container running indefinitely
        while ($true) {
            Start-Sleep -Seconds 3600
        }
    }
} catch {
    Write-Host "`n❌ Web server stopped: $_" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}
