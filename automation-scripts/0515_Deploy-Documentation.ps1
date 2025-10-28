#Requires -Version 7.0

<#
.SYNOPSIS
    Deploy documentation and reports to GitHub Pages
.DESCRIPTION
    Prepares and deploys project documentation, dashboards, reports, and
    API documentation to GitHub Pages for public access and monitoring.

    Exit Codes:
    0   - Deployment prepared successfully
    1   - Deployment failed
    2   - Configuration error

.NOTES
    Stage: Deployment
    Order: 0515
    Dependencies: 0510, 0512
    Tags: deployment, documentation, github-pages, reporting
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ProjectPath = ($PSScriptRoot | Split-Path -Parent),
    [string]$OutputPath = (Join-Path $ProjectPath "docs-deploy"),
    [string]$BaseURL = "/AitherZero",
    [switch]$LocalPreview,
    [switch]$GenerateNav,
    [string]$ThemeColor = '#667eea'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata
$scriptMetadata = @{
    Stage = 'Deployment'
    Order = 0515
    Dependencies = @('0510', '0512')
    Tags = @('deployment', 'documentation', 'github-pages')
    RequiresAdmin = $false
    SupportsWhatIf = $true
}

# Import modules
$loggingModule = Join-Path $ProjectPath "domains/utilities/Logging.psm1"
if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force
}

function Write-ScriptLog {
    param(
        [string]$Level = 'Information',
        [string]$Message,
        [hashtable]$Data = @{}
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "0515_Deploy-Documentation" -Data $Data
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] [$Level] $Message"
    }
}

function New-GitHubPagesStructure {
    Write-ScriptLog -Message "Creating GitHub Pages directory structure"

    $structure = @(
        "reports/latest",
        "reports/archive",
        "reports/trends",
        "api",
        "assets/css",
        "assets/js",
        "assets/images"
    )

    foreach ($dir in $structure) {
        $fullPath = Join-Path $OutputPath $dir
        if (-not (Test-Path $fullPath)) {
            New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        }
    }

    Write-ScriptLog -Message "Directory structure created"
}

function New-NavigationIndex {
    Write-ScriptLog -Message "Creating main navigation index"

    $indexHTML = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AitherZero - Documentation Portal</title>
    <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>🚀</text></svg>">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, $ThemeColor 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
        }

        .hero {
            text-align: center;
            padding: 80px 20px;
            color: white;
        }

        .hero h1 {
            font-size: 3.5rem;
            margin-bottom: 20px;
            text-shadow: 0 2px 10px rgba(0,0,0,0.3);
        }

        .hero .subtitle {
            font-size: 1.3rem;
            opacity: 0.9;
            margin-bottom: 40px;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 0 20px;
        }

        .nav-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 30px;
            margin-top: -50px;
            padding-bottom: 60px;
        }

        .nav-card {
            background: white;
            border-radius: 16px;
            padding: 30px;
            text-align: center;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
            transition: transform 0.3s, box-shadow 0.3s;
            text-decoration: none;
            color: inherit;
        }

        .nav-card:hover {
            transform: translateY(-8px);
            box-shadow: 0 20px 60px rgba(0,0,0,0.15);
        }

        .nav-icon {
            font-size: 3rem;
            margin-bottom: 20px;
            display: block;
        }

        .nav-title {
            font-size: 1.5rem;
            font-weight: 600;
            margin-bottom: 15px;
            color: #333;
        }

        .nav-description {
            color: #666;
            line-height: 1.6;
        }

        .status-bar {
            background: white;
            margin: 40px 0;
            border-radius: 12px;
            padding: 20px;
            box-shadow: 0 5px 20px rgba(0,0,0,0.08);
        }

        .status-title {
            font-size: 1.2rem;
            font-weight: 600;
            margin-bottom: 15px;
            text-align: center;
        }

        .status-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
        }

        .status-item {
            text-align: center;
            padding: 15px;
            background: #f8f9fa;
            border-radius: 8px;
        }

        .status-value {
            font-size: 1.5rem;
            font-weight: bold;
            margin-bottom: 5px;
            color: $ThemeColor;
        }

        .status-label {
            font-size: 0.9rem;
            color: #666;
        }

        .footer {
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            color: white;
            text-align: center;
            padding: 30px 20px;
            margin-top: 40px;
        }

        .badge {
            display: inline-block;
            padding: 5px 12px;
            background: rgba(255,255,255,0.2);
            border-radius: 20px;
            font-size: 0.8rem;
            margin: 0 5px;
            backdrop-filter: blur(10px);
        }

        @media (max-width: 768px) {
            .hero h1 {
                font-size: 2.5rem;
            }

            .nav-grid {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <div class="hero">
        <div class="container">
            <h1>🚀 AitherZero</h1>
            <p class="subtitle">Infrastructure Automation Platform</p>
            <div>
                <span class="badge">v1.0.0</span>
                <span class="badge">PowerShell 7+</span>
                <span class="badge">Cross-Platform</span>
            </div>
        </div>
    </div>

    <div class="container">
        <div class="status-bar">
            <div class="status-title">📊 Project Overview</div>
            <div class="status-grid" id="projectStats">
                <div class="status-item">
                    <div class="status-value" id="totalFiles">Loading...</div>
                    <div class="status-label">Total Files</div>
                </div>
                <div class="status-item">
                    <div class="status-value" id="linesOfCode">Loading...</div>
                    <div class="status-label">Lines of Code</div>
                </div>
                <div class="status-item">
                    <div class="status-value" id="totalTests">Loading...</div>
                    <div class="status-label">Tests</div>
                </div>
                <div class="status-item">
                    <div class="status-value" id="coverage">Loading...</div>
                    <div class="status-label">Coverage</div>
                </div>
            </div>
        </div>

        <div class="nav-grid">
            <a href="reports/latest/dashboard.html" class="nav-card">
                <span class="nav-icon">📊</span>
                <h3 class="nav-title">Live Dashboard</h3>
                <p class="nav-description">Real-time project health, metrics, and status monitoring</p>
            </a>

            <a href="reports/latest/test-report.html" class="nav-card">
                <span class="nav-icon">🧪</span>
                <h3 class="nav-title">Test Results</h3>
                <p class="nav-description">Comprehensive test reports, coverage analysis, and trends</p>
            </a>

            <a href="reports/latest/security-report.html" class="nav-card">
                <span class="nav-icon">🔒</span>
                <h3 class="nav-title">Security Scan</h3>
                <p class="nav-description">Security vulnerability reports and compliance status</p>
            </a>

            <a href="api/" class="nav-card">
                <span class="nav-icon">📚</span>
                <h3 class="nav-title">API Documentation</h3>
                <p class="nav-description">Complete function reference and usage examples</p>
            </a>

            <a href="reports/trends/" class="nav-card">
                <span class="nav-icon">📈</span>
                <h3 class="nav-title">Trends & Analytics</h3>
                <p class="nav-description">Historical data, performance trends, and insights</p>
            </a>

            <a href="https://github.com/wizzense/AitherZero" target="_blank" class="nav-card">
                <span class="nav-icon">🏠</span>
                <h3 class="nav-title">GitHub Repository</h3>
                <p class="nav-description">Source code, issues, releases, and contributions</p>
            </a>
        </div>
    </div>

    <div class="footer">
        <div class="container">
            <p>Generated by AitherZero CI/CD Pipeline | Last updated: <span id="lastUpdate">$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</span></p>
            <p style="margin-top: 10px; font-size: 0.9rem;">
                <a href="https://github.com/wizzense/AitherZero/actions" target="_blank" style="color: white; text-decoration: none;">🔄 View CI/CD Status</a> |
                <a href="https://github.com/wizzense/AitherZero/releases" target="_blank" style="color: white; text-decoration: none;">📦 Latest Release</a> |
                <a href="https://github.com/wizzense/AitherZero/issues" target="_blank" style="color: white; text-decoration: none;">🐛 Report Issues</a>
            </p>
        </div>
    </div>

    <script>
        // Load project statistics
        fetch('$BaseURL/reports/latest/dashboard.json')
            .then(response => response.json())
            .then(data => {
                if (data && data.Metrics) {
                    document.getElementById('totalFiles').textContent = data.Metrics.Files.Total || 'N/A';
                    document.getElementById('linesOfCode').textContent = (data.Metrics.LinesOfCode || 0).toLocaleString();
                    document.getElementById('totalTests').textContent = data.Metrics.Tests.Total || 'N/A';
                    document.getElementById('coverage').textContent = (data.Metrics.Coverage.Percentage || 0) + '%';
                }
            })
            .catch(() => {
                document.getElementById('totalFiles').textContent = 'N/A';
                document.getElementById('linesOfCode').textContent = 'N/A';
                document.getElementById('totalTests').textContent = 'N/A';
                document.getElementById('coverage').textContent = 'N/A';
            });

        // Auto-refresh every 10 minutes
        setTimeout(() => {
            window.location.reload();
        }, 600000);
    </script>
</body>
</html>
"@

    $indexPath = Join-Path $OutputPath "index.html"
    if ($PSCmdlet.ShouldProcess($indexPath, "Create main index page")) {
        $indexHTML | Set-Content -Path $indexPath -Encoding UTF8
        Write-ScriptLog -Message "Main index page created: $indexPath"
    }
}

function Copy-ExistingReports {
    Write-ScriptLog -Message "Copying existing reports and documentation"

    # Copy reports from various locations
    $reportSources = @(
        @{ Source = Join-Path $ProjectPath "reports"; Destination = Join-Path $OutputPath "reports/latest" }
        @{ Source = Join-Path $ProjectPath "tests/reports"; Destination = Join-Path $OutputPath "reports/latest" }
        @{ Source = Join-Path $ProjectPath "docs"; Destination = Join-Path $OutputPath "docs" }
    )

    foreach ($source in $reportSources) {
        if (Test-Path $source.Source) {
            Write-ScriptLog -Message "Copying from $($source.Source) to $($source.Destination)"

            # Ensure destination exists
            if (-not (Test-Path $source.Destination)) {
                New-Item -ItemType Directory -Path $source.Destination -Force | Out-Null
            }

            # Copy files
            try {
                Get-ChildItem -Path $source.Source -Recurse | ForEach-Object {
                    $relativePath = $_.FullName.Substring($source.Source.Length + 1)
                    $destPath = Join-Path $source.Destination $relativePath

                    if ($_.PSIsContainer) {
                        if (-not (Test-Path $destPath)) {
                            New-Item -ItemType Directory -Path $destPath -Force | Out-Null
                        }
                    } else {
                        $destDir = Split-Path $destPath -Parent
                        if (-not (Test-Path $destDir)) {
                            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                        }
                        Copy-Item -Path $_.FullName -Destination $destPath -Force
                    }
                }
            } catch {
                Write-ScriptLog -Level Warning -Message "Failed to copy from $($source.Source): $_"
            }
        }
    }
}

function New-APIDocumentation {
    Write-ScriptLog -Message "Generating API documentation"

    # Generate API documentation from PowerShell modules
    $apiPath = Join-Path $OutputPath "api"

    try {
        # Import the main module
        $moduleManifest = Join-Path $ProjectPath "AitherZero.psd1"
        if (Test-Path $moduleManifest) {
            Import-Module $moduleManifest -Force -Global

            # Get all exported functions
            $module = Get-Module AitherZero
            $functions = Get-Command -Module $module.Name -CommandType Function

            $apiDocs = @{
                Generated = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
                ModuleName = $module.Name
                ModuleVersion = $module.Version.ToString()
                Functions = @()
            }

            foreach ($function in $functions) {
                try {
                    $help = Get-Help $function.Name -Full -ErrorAction SilentlyContinue

                    $functionDoc = @{
                        Name = $function.Name
                        Synopsis = $help.Synopsis
                        Description = $help.Description.Text -join ' '
                        Parameters = @()
                        Examples = @()
                        Module = $function.ModuleName
                    }

                    # Add parameters
                    if ($help.Parameters -and $help.Parameters.Parameter) {
                        foreach ($param in $help.Parameters.Parameter) {
                            $functionDoc.Parameters += @{
                                Name = $param.Name
                                Type = $param.Type.Name
                                Required = $param.Required -eq 'true'
                                Description = $param.Description.Text -join ' '
                            }
                        }
                    }

                    # Add examples
                    if ($help.Examples -and $help.Examples.Example) {
                        foreach ($example in $help.Examples.Example) {
                            $functionDoc.Examples += @{
                                Title = $example.Title
                                Code = $example.Code
                                Remarks = $example.Remarks.Text -join ' '
                            }
                        }
                    }

                    $apiDocs.Functions += $functionDoc
                } catch {
                    Write-ScriptLog -Level Warning -Message "Failed to document function $($function.Name): $_"
                }
            }

            # Save JSON API docs
            $jsonPath = Join-Path $apiPath "api.json"
            if ($PSCmdlet.ShouldProcess($jsonPath, "Create API JSON documentation")) {
                $apiDocs | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8
            }

            # Generate HTML API docs
            $apiHTML = New-APIIndexHTML -APIData $apiDocs
            $htmlPath = Join-Path $apiPath "index.html"
            if ($PSCmdlet.ShouldProcess($htmlPath, "Create API HTML documentation")) {
                $apiHTML | Set-Content -Path $htmlPath -Encoding UTF8
            }

            Write-ScriptLog -Message "API documentation generated for $($apiDocs.Functions.Count) functions"
        }
    } catch {
        Write-ScriptLog -Level Error -Message "Failed to generate API documentation: $_"
    }
}

function New-APIIndexHTML {
    param([hashtable]$APIData)

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AitherZero API Documentation</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6; color: #333;
        }
        .header {
            background: linear-gradient(135deg, $ThemeColor 0%, #764ba2 100%);
            color: white; padding: 30px; text-align: center;
        }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        .function-grid {
            display: grid; grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
            gap: 20px; margin-top: 20px;
        }
        .function-card {
            border: 1px solid #e9ecef; border-radius: 8px;
            padding: 20px; background: white;
        }
        .function-name {
            font-size: 1.3rem; font-weight: bold; color: $ThemeColor;
            margin-bottom: 10px;
        }
        .function-synopsis { color: #666; margin-bottom: 15px; }
        .parameters {
            background: #f8f9fa; padding: 10px; border-radius: 4px;
            margin: 10px 0;
        }
        .parameter {
            margin: 5px 0; font-family: 'Courier New', monospace;
            font-size: 0.9rem;
        }
        code {
            background: #f1f3f4; padding: 2px 6px; border-radius: 3px;
            font-family: 'Courier New', monospace;
        }
        .search-box {
            width: 100%; padding: 12px; border: 1px solid #ddd;
            border-radius: 6px; font-size: 1rem; margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 AitherZero API</h1>
        <p>Module: $($APIData.ModuleName) v$($APIData.ModuleVersion)</p>
        <p>Generated: $($APIData.Generated)</p>
    </div>

    <div class="container">
        <input type="text" class="search-box" placeholder="Search functions..." id="searchBox">

        <div class="function-grid" id="functionGrid">
$(foreach ($function in $APIData.Functions) {
@"
            <div class="function-card" data-name="$($function.Name.ToLower())">
                <div class="function-name">$($function.Name)</div>
                <div class="function-synopsis">$($function.Synopsis)</div>
                <div class="parameters">
                    <strong>Parameters:</strong>
$(if ($function.Parameters.Count -gt 0) {
    $function.Parameters | ForEach-Object {
        "                    <div class='parameter'>-$($_.Name) [$($_.Type)]$(if($_.Required){'*'})</div>"
    } | Join-String -Separator "`n"
} else {
    "                    <div class='parameter'>None</div>"
})
                </div>
            </div>
"@
})
        </div>
    </div>

    <script>
        document.getElementById('searchBox').addEventListener('input', function(e) {
            const query = e.target.value.toLowerCase();
            const cards = document.querySelectorAll('.function-card');

            cards.forEach(card => {
                const name = card.dataset.name;
                card.style.display = name.includes(query) ? 'block' : 'none';
            });
        });
    </script>
</body>
</html>
"@

    return $html
}

function New-JekyllConfig {
    Write-ScriptLog -Message "Creating Jekyll configuration for GitHub Pages"

    $jekyllConfig = @"
# Jekyll configuration for AitherZero GitHub Pages
title: AitherZero Documentation
description: Infrastructure Automation Platform
url: "https://wizzense.github.io"
baseurl: "$BaseURL"

# Build settings
markdown: kramdown
theme: minima
plugins:
  - jekyll-feed
  - jekyll-sitemap
  - jekyll-seo-tag

# Exclude from processing
exclude:
  - README.md
  - Gemfile
  - Gemfile.lock
  - node_modules
  - vendor/bundle/
  - vendor/cache/
  - vendor/gems/
  - vendor/ruby/

# Collections
collections:
  reports:
    output: true
    permalink: /:collection/:name/

# Defaults
defaults:
  - scope:
      path: ""
      type: "reports"
    values:
      layout: "default"
"@

    $configPath = Join-Path $OutputPath "_config.yml"
    if ($PSCmdlet.ShouldProcess($configPath, "Create Jekyll config")) {
        $jekyllConfig | Set-Content -Path $configPath -Encoding UTF8
    }
}

function Start-LocalPreview {
    param([string]$Port = "4000")

    Write-ScriptLog -Message "Starting local preview server"

    # Check if we can start a simple HTTP server
    if (Get-Command python -ErrorAction SilentlyContinue) {
        Write-Host "Starting local server at http://localhost:$Port" -ForegroundColor Green
        Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow

        Push-Location $OutputPath
        try {
            python -m http.server $Port
        } finally {
            Pop-Location
        }
    } elseif (Get-Command ruby -ErrorAction SilentlyContinue) {
        Write-Host "Starting Jekyll server at http://localhost:$Port" -ForegroundColor Green
        Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow

        Push-Location $OutputPath
        try {
            bundle exec jekyll serve --port $Port
        } finally {
            Pop-Location
        }
    } else {
        Write-Host "Opening documentation in default browser..." -ForegroundColor Green
        $indexPath = Join-Path $OutputPath "index.html"
        if (Test-Path $indexPath) {
            Start-Process $indexPath
        }
    }
}

try {
    Write-ScriptLog -Message "Starting documentation deployment preparation"

    # Create output directory structure
    if (Test-Path $OutputPath) {
        Remove-Item -Path $OutputPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

    # Create GitHub Pages structure
    New-GitHubPagesStructure

    # Generate main index
    New-NavigationIndex

    # Copy existing reports and documentation
    Copy-ExistingReports

    # Generate fresh dashboard and reports
    Write-ScriptLog -Message "Generating fresh reports for deployment"
    & (Join-Path $ProjectPath "automation-scripts/0512_Generate-Dashboard.ps1") -OutputPath (Join-Path $OutputPath "reports/latest") -Format All

    # Generate API documentation
    New-APIDocumentation

    # Create Jekyll configuration
    New-JekyllConfig

    # Create deployment summary
    $deploymentSummary = @{
        Generated = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        OutputPath = $OutputPath
        BaseURL = $BaseURL
        Files = @{
            Total = if (Test-Path $OutputPath) { (Get-ChildItem -Path $OutputPath -Recurse -File -ErrorAction SilentlyContinue).Count } else { 0 }
            HTML = if (Test-Path $OutputPath) { (Get-ChildItem -Path $OutputPath -Recurse -Filter "*.html" -ErrorAction SilentlyContinue).Count } else { 0 }
            JSON = if (Test-Path $OutputPath) { (Get-ChildItem -Path $OutputPath -Recurse -Filter "*.json" -ErrorAction SilentlyContinue).Count } else { 0 }
            Markdown = if (Test-Path $OutputPath) { (Get-ChildItem -Path $OutputPath -Recurse -Filter "*.md" -ErrorAction SilentlyContinue).Count } else { 0 }
        }
        Structure = @(
            "index.html - Main navigation portal",
            "reports/latest/ - Current reports and dashboards",
            "api/ - API documentation",
            "docs/ - General documentation",
            "_config.yml - Jekyll configuration"
        )
    }

    $summaryPath = Join-Path $OutputPath "deployment-summary.json"
    $deploymentSummary | ConvertTo-Json -Depth 10 | Set-Content -Path $summaryPath -Encoding UTF8

    # Create .nojekyll file to disable Jekyll processing if needed
    $nojekyllPath = Join-Path $OutputPath ".nojekyll"
    "" | Set-Content -Path $nojekyllPath

    # Summary
    Write-Host "`n🎉 Documentation Deployment Ready!" -ForegroundColor Green
    Write-Host "📁 Output Directory: $OutputPath" -ForegroundColor Cyan
    Write-Host "🌐 Main Index: $(Join-Path $OutputPath 'index.html')" -ForegroundColor Green
    Write-Host "📊 Dashboard: $(Join-Path $OutputPath 'reports/latest/dashboard.html')" -ForegroundColor Green
    Write-Host "📚 API Docs: $(Join-Path $OutputPath 'api/index.html')" -ForegroundColor Green

    Write-Host "`n📈 Deployment Statistics:" -ForegroundColor Cyan
    Write-Host "  Total Files: $($deploymentSummary.Files.Total)" -ForegroundColor White
    Write-Host "  HTML Files: $($deploymentSummary.Files.HTML)" -ForegroundColor White
    Write-Host "  JSON Reports: $($deploymentSummary.Files.JSON)" -ForegroundColor White
    Write-Host "  Markdown Files: $($deploymentSummary.Files.Markdown)" -ForegroundColor White

    Write-Host "`n🚀 Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Review generated files in: $OutputPath" -ForegroundColor White
    Write-Host "2. Test locally with: -LocalPreview switch" -ForegroundColor White
    Write-Host "3. Deploy to GitHub Pages via Actions workflow" -ForegroundColor White
    Write-Host "4. Configure custom domain (optional)" -ForegroundColor White

    if ($LocalPreview) {
        Start-LocalPreview
    }

    Write-ScriptLog -Message "Documentation deployment preparation completed successfully" -Data $deploymentSummary
    exit 0

} catch {
    $errorMsg = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
    Write-ScriptLog -Level Error -Message "Documentation deployment failed: $_" -Data @{ Exception = $errorMsg }
    exit 1
}