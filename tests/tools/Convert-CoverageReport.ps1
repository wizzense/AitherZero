#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Converts code coverage reports between different formats
.DESCRIPTION
    Converts JaCoCo XML coverage reports to various formats including Cobertura, HTML, and badges
.PARAMETER InputFile
    Path to the input coverage file (JaCoCo XML format)
.PARAMETER OutputFormats
    Array of output formats to generate: Cobertura, HTML, Badge
.PARAMETER OutputDirectory
    Directory where converted reports will be saved
#>

param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ })]
    [string]$InputFile,
    
    [ValidateSet('Cobertura', 'HTML', 'Badge', 'JSON')]
    [string[]]$OutputFormats = @('Cobertura', 'HTML'),
    
    [string]$OutputDirectory = (Split-Path $InputFile -Parent)
)

# Import required modules
. "$PSScriptRoot/../../aither-core/shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

# Ensure output directory exists
if (-not (Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

# Load coverage data
Write-Host "Loading coverage data from: $InputFile"
[xml]$coverageXml = Get-Content $InputFile

# Calculate coverage metrics
$metrics = @{
    Instructions = @{
        Covered = 0
        Missed = 0
        Total = 0
        Percentage = 0
    }
    Lines = @{
        Covered = 0
        Missed = 0
        Total = 0
        Percentage = 0
    }
    Methods = @{
        Covered = 0
        Missed = 0
        Total = 0
        Percentage = 0
    }
    Classes = @{
        Covered = 0
        Missed = 0
        Total = 0
        Percentage = 0
    }
}

# Parse JaCoCo format
if ($coverageXml.report) {
    foreach ($counter in $coverageXml.report.counter) {
        $type = $counter.type
        if ($metrics.ContainsKey($type)) {
            $metrics[$type].Covered = [int]$counter.covered
            $metrics[$type].Missed = [int]$counter.missed
            $metrics[$type].Total = $metrics[$type].Covered + $metrics[$type].Missed
            if ($metrics[$type].Total -gt 0) {
                $metrics[$type].Percentage = [math]::Round(($metrics[$type].Covered / $metrics[$type].Total) * 100, 2)
            }
        }
    }
}

# Generate requested formats
foreach ($format in $OutputFormats) {
    Write-Host "Generating $format format..."
    
    switch ($format) {
        'Cobertura' {
            # Convert to Cobertura format
            $coberturaPath = Join-Path $OutputDirectory "coverage.cobertura"
            
            $coberturaXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE coverage SYSTEM "http://cobertura.sourceforge.net/xml/coverage-04.dtd">
<coverage line-rate="$($metrics.Lines.Percentage / 100)" branch-rate="0" lines-covered="$($metrics.Lines.Covered)" lines-valid="$($metrics.Lines.Total)" branches-covered="0" branches-valid="0" complexity="0" version="1.0" timestamp="$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')">
    <sources>
        <source>$projectRoot</source>
    </sources>
    <packages>
"@
            
            # Add package information (simplified for PowerShell modules)
            $modules = Get-ChildItem -Path "$projectRoot/aither-core/modules" -Directory
            
            foreach ($module in $modules) {
                $coberturaXml += @"
        <package name="$($module.Name)" line-rate="$($metrics.Lines.Percentage / 100)" branch-rate="0" complexity="0">
            <classes>
                <class name="$($module.Name)" filename="$($module.Name).psm1" line-rate="$($metrics.Lines.Percentage / 100)" branch-rate="0" complexity="0">
                    <methods/>
                    <lines/>
                </class>
            </classes>
        </package>
"@
            }
            
            $coberturaXml += @"
    </packages>
</coverage>
"@
            
            Set-Content -Path $coberturaPath -Value $coberturaXml -Encoding UTF8
            Write-Host "  Created: $coberturaPath"
        }
        
        'HTML' {
            # Generate HTML report
            $htmlPath = Join-Path $OutputDirectory "coverage-html"
            New-Item -ItemType Directory -Path $htmlPath -Force | Out-Null
            
            $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Code Coverage Report - AitherZero</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin: 20px 0; }
        .metric { background-color: #f8f9fa; padding: 20px; border-radius: 8px; text-align: center; }
        .metric h3 { margin: 0 0 10px 0; color: #666; }
        .percentage { font-size: 36px; font-weight: bold; margin: 10px 0; }
        .good { color: #28a745; }
        .warning { color: #ffc107; }
        .bad { color: #dc3545; }
        .details { margin-top: 30px; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f8f9fa; font-weight: bold; }
        .bar { background-color: #e0e0e0; height: 20px; border-radius: 4px; overflow: hidden; }
        .bar-fill { height: 100%; transition: width 0.3s ease; }
        .bar-good { background-color: #28a745; }
        .bar-warning { background-color: #ffc107; }
        .bar-bad { background-color: #dc3545; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📊 Code Coverage Report</h1>
        <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        
        <div class="summary">
"@
            
            foreach ($metricType in $metrics.Keys) {
                $metric = $metrics[$metricType]
                $colorClass = if ($metric.Percentage -ge 80) { "good" } elseif ($metric.Percentage -ge 60) { "warning" } else { "bad" }
                
                $htmlContent += @"
            <div class="metric">
                <h3>$metricType Coverage</h3>
                <div class="percentage $colorClass">$($metric.Percentage)%</div>
                <div>$($metric.Covered) / $($metric.Total)</div>
                <div class="bar">
                    <div class="bar-fill bar-$colorClass" style="width: $($metric.Percentage)%"></div>
                </div>
            </div>
"@
            }
            
            $htmlContent += @"
        </div>
        
        <div class="details">
            <h2>Module Coverage Details</h2>
            <table>
                <thead>
                    <tr>
                        <th>Module</th>
                        <th>Line Coverage</th>
                        <th>Method Coverage</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
"@
            
            # Add module details
            $modules = Get-ChildItem -Path "$projectRoot/aither-core/modules" -Directory
            foreach ($module in $modules) {
                $htmlContent += @"
                    <tr>
                        <td>$($module.Name)</td>
                        <td>$($metrics.Lines.Percentage)%</td>
                        <td>$($metrics.Methods.Percentage)%</td>
                        <td>✅</td>
                    </tr>
"@
            }
            
            $htmlContent += @"
                </tbody>
            </table>
        </div>
    </div>
</body>
</html>
"@
            
            $indexPath = Join-Path $htmlPath "index.html"
            Set-Content -Path $indexPath -Value $htmlContent -Encoding UTF8
            Write-Host "  Created: $indexPath"
        }
        
        'Badge' {
            # Generate coverage badge (SVG)
            $badgePath = Join-Path $OutputDirectory "coverage-badge.svg"
            $percentage = $metrics.Lines.Percentage
            $color = if ($percentage -ge 80) { "#4c1" } elseif ($percentage -ge 60) { "#dfb317" } else { "#e05d44" }
            
            $badgeSvg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="114" height="20">
    <linearGradient id="b" x2="0" y2="100%">
        <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
        <stop offset="1" stop-opacity=".1"/>
    </linearGradient>
    <mask id="a">
        <rect width="114" height="20" rx="3" fill="#fff"/>
    </mask>
    <g mask="url(#a)">
        <path fill="#555" d="M0 0h63v20H0z"/>
        <path fill="$color" d="M63 0h51v20H63z"/>
        <path fill="url(#b)" d="M0 0h114v20H0z"/>
    </g>
    <g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">
        <text x="31.5" y="15" fill="#010101" fill-opacity=".3">coverage</text>
        <text x="31.5" y="14">coverage</text>
        <text x="87.5" y="15" fill="#010101" fill-opacity=".3">$percentage%</text>
        <text x="87.5" y="14">$percentage%</text>
    </g>
</svg>
"@
            
            Set-Content -Path $badgePath -Value $badgeSvg -Encoding UTF8
            Write-Host "  Created: $badgePath"
        }
        
        'JSON' {
            # Generate JSON summary
            $jsonPath = Join-Path $OutputDirectory "coverage-summary.json"
            
            $summary = @{
                timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                line = $metrics.Lines.Percentage
                branch = 0  # PowerShell doesn't have branch coverage
                function = $metrics.Methods.Percentage
                overall = $metrics.Lines.Percentage
                details = $metrics
            }
            
            $summary | ConvertTo-Json -Depth 3 | Set-Content -Path $jsonPath -Encoding UTF8
            Write-Host "  Created: $jsonPath"
        }
    }
}

Write-Host ""
Write-Host "✅ Coverage report conversion complete!" -ForegroundColor Green
Write-Host "Overall coverage: $($metrics.Lines.Percentage)%" -ForegroundColor $(if ($metrics.Lines.Percentage -ge 80) { "Green" } elseif ($metrics.Lines.Percentage -ge 60) { "Yellow" } else { "Red" })