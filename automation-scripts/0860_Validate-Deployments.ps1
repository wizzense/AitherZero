#Requires -Version 7.0
<#
.SYNOPSIS
    Validates deployment configuration and status for GitHub Pages and containers.

.DESCRIPTION
    Comprehensive validation script that checks:
    - GitHub Pages workflow configuration
    - Container deployment workflows
    - Repository settings (requires gh CLI with auth)
    - Build artifacts and reports
    - Deployment history
    
    This script helps diagnose deployment issues, especially when deployments
    haven't run for extended periods (e.g., 3+ hours).

.PARAMETER CheckPages
    Check GitHub Pages deployment status and configuration

.PARAMETER CheckContainers
    Check container deployment status to GHCR

.PARAMETER CheckLocal
    Check local build artifacts and configuration files

.PARAMETER Detailed
    Show detailed output including file listings and diagnostics

.EXAMPLE
    ./0860_Validate-Deployments.ps1
    Runs all checks with standard output

.EXAMPLE
    ./0860_Validate-Deployments.ps1 -CheckPages -Detailed
    Detailed check of GitHub Pages deployment only

.EXAMPLE
    ./0860_Validate-Deployments.ps1 -CheckLocal
    Check local configuration without requiring GitHub CLI

.NOTES
    Author: AitherZero Team
    Date: 2025-11-02
    Version: 1.0.0
    
    This script can run without GitHub CLI for local checks,
    but requires 'gh' CLI with authentication for remote checks.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$CheckPages,
    [switch]$CheckContainers,
    [switch]$CheckLocal,
    [switch]$Detailed,
    
    [Parameter(Mandatory = $false)]
    [hashtable]$Configuration
)

# Handle test mode (WhatIf or DryRun)
if ($WhatIfPreference -or ($Configuration -and $Configuration.Automation.DryRun)) {
    Write-Verbose "Running in test mode (WhatIf/DryRun) - script would validate deployments"
    return
}

# If no specific checks selected, run all
if (-not ($CheckPages -or $CheckContainers -or $CheckLocal)) {
    $CheckPages = $true
    $CheckContainers = $true
    $CheckLocal = $true
}

$script:TotalChecks = 0
$script:PassedChecks = 0
$script:FailedChecks = 0
$script:WarningChecks = 0

function Write-CheckResult {
    param(
        [string]$Check,
        [string]$Status,  # Pass, Fail, Warn, Info
        [string]$Message
    )
    
    $script:TotalChecks++
    
    $icon = switch ($Status) {
        'Pass' { '✅'; $script:PassedChecks++ }
        'Fail' { '❌'; $script:FailedChecks++ }
        'Warn' { '⚠️'; $script:WarningChecks++ }
        'Info' { 'ℹ️' }
    }
    
    $color = switch ($Status) {
        'Pass' { 'Green' }
        'Fail' { 'Red' }
        'Warn' { 'Yellow' }
        'Info' { 'Cyan' }
    }
    
    Write-Host "$icon " -NoNewline -ForegroundColor $color
    Write-Host "$Check`: " -NoNewline -ForegroundColor White
    Write-Host $Message -ForegroundColor $color
}

function Test-GitHubCLI {
    try {
        $null = Get-Command gh -ErrorAction Stop
        $authStatus = gh auth status 2>&1
        if ($authStatus -like "*Logged in to github.com*") {
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

# ============================================================================
# Local Configuration Checks
# ============================================================================
if ($CheckLocal) {
    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "📋 LOCAL CONFIGURATION CHECKS" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    
    # Check Jekyll config
    $configPath = "./_config.yml"
    if (Test-Path $configPath) {
        Write-CheckResult "Jekyll Config" "Pass" "Found at $configPath"
        
        $config = Get-Content $configPath
        $url = $config | Select-String -Pattern "^url:" | Select-Object -First 1
        $baseurl = $config | Select-String -Pattern "^baseurl:" | Select-Object -First 1
        
        if ($Detailed) {
            Write-Host "  URL: $url" -ForegroundColor Gray
            Write-Host "  BaseURL: $baseurl" -ForegroundColor Gray
        }
        
        if ($url -like "*wizzense.github.io/AitherZero*") {
            Write-CheckResult "Pages URL" "Pass" "Correctly configured for GitHub Pages"
        } else {
            Write-CheckResult "Pages URL" "Warn" "URL may not match GitHub Pages format"
        }
    } else {
        Write-CheckResult "Jekyll Config" "Fail" "Not found at $configPath"
    }
    
    # Check workflow files
    $jekyllWorkflow = "./.github/workflows/jekyll-gh-pages.yml"
    if (Test-Path $jekyllWorkflow) {
        Write-CheckResult "Jekyll Workflow" "Pass" "Found at $jekyllWorkflow"
        
        $workflow = Get-Content $jekyllWorkflow -Raw
        if ($workflow -like "*actions/deploy-pages*") {
            Write-CheckResult "Deploy Action" "Pass" "Using actions/deploy-pages"
        }
        
        if ($workflow -like "*permissions*pages: write*") {
            Write-CheckResult "Permissions" "Pass" "Pages write permission configured"
        } else {
            Write-CheckResult "Permissions" "Warn" "Check if pages write permission is set"
        }
    } else {
        Write-CheckResult "Jekyll Workflow" "Fail" "Not found at $jekyllWorkflow"
    }
    
    $containerWorkflow = "./.github/workflows/deploy-pr-environment.yml"
    if (Test-Path $containerWorkflow) {
        Write-CheckResult "Container Workflow" "Pass" "Found at $containerWorkflow"
    } else {
        Write-CheckResult "Container Workflow" "Warn" "Not found at $containerWorkflow"
    }
    
    # Check reports directory
    if (Test-Path "./reports") {
        $htmlFiles = @(Get-ChildItem "./reports" -Filter "*.html" -File)
        $jsonFiles = @(Get-ChildItem "./reports" -Filter "*.json" -File)
        
        Write-CheckResult "Reports Directory" "Pass" "$($htmlFiles.Count) HTML, $($jsonFiles.Count) JSON files"
        
        if (Test-Path "./reports/dashboard.html") {
            $dashboardSize = (Get-Item "./reports/dashboard.html").Length
            Write-CheckResult "Dashboard" "Pass" "Found ($('{0:N0}' -f $dashboardSize) bytes)"
        } else {
            Write-CheckResult "Dashboard" "Warn" "dashboard.html not found"
        }
        
        if ($Detailed) {
            Write-Host "`n  Recent reports:" -ForegroundColor Gray
            Get-ChildItem "./reports" -Filter "*.html" | 
                Sort-Object LastWriteTime -Descending | 
                Select-Object -First 5 | 
                ForEach-Object {
                    Write-Host "    - $($_.Name) ($($_.LastWriteTime.ToString('yyyy-MM-dd HH:mm')))" -ForegroundColor Gray
                }
        }
    } else {
        Write-CheckResult "Reports Directory" "Fail" "Not found at ./reports"
    }
    
    # Check Docker files
    if (Test-Path "./Dockerfile") {
        Write-CheckResult "Dockerfile" "Pass" "Found"
    } else {
        Write-CheckResult "Dockerfile" "Warn" "Not found"
    }
}

# ============================================================================
# GitHub Pages Deployment Checks
# ============================================================================
if ($CheckPages) {
    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "🌐 GITHUB PAGES DEPLOYMENT CHECKS" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    
    $hasGH = Test-GitHubCLI
    if ($hasGH) {
        Write-CheckResult "GitHub CLI" "Pass" "Authenticated and ready"
        
        # Get recent workflow runs
        try {
            $runs = gh run list --workflow="jekyll-gh-pages.yml" --limit 5 --json status,conclusion,createdAt,displayTitle 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $runsData = $runs | ConvertFrom-Json
                
                Write-CheckResult "Recent Runs" "Info" "Found $($runsData.Count) recent deployments"
                
                # Check most recent run
                if ($runsData.Count -gt 0) {
                    $latest = $runsData[0]
                    $timeSince = (Get-Date) - [DateTime]$latest.createdAt
                    
                    if ($latest.status -eq 'completed') {
                        if ($latest.conclusion -eq 'success') {
                            Write-CheckResult "Latest Deploy" "Pass" "Succeeded $([math]::Round($timeSince.TotalHours, 1))h ago"
                        } else {
                            Write-CheckResult "Latest Deploy" "Fail" "$($latest.conclusion) $([math]::Round($timeSince.TotalHours, 1))h ago"
                            
                            if ($timeSince.TotalHours -gt 3) {
                                Write-CheckResult "Deploy Staleness" "Fail" "No successful deployment in $([math]::Round($timeSince.TotalHours, 1)) hours!"
                                Write-Host "`n  🚨 CRITICAL: Deployments have been failing for 3+ hours" -ForegroundColor Red
                                Write-Host "  📖 See DEPLOYMENT-DIAGNOSIS.md for resolution steps" -ForegroundColor Yellow
                            }
                        }
                    } else {
                        Write-CheckResult "Latest Deploy" "Info" "Status: $($latest.status)"
                    }
                    
                    if ($Detailed) {
                        Write-Host "`n  Recent deployment history:" -ForegroundColor Gray
                        foreach ($run in $runsData) {
                            $icon = if ($run.conclusion -eq 'success') { '✅' } 
                                   elseif ($run.conclusion -eq 'failure') { '❌' } 
                                   else { '⏳' }
                            $time = [DateTime]$run.createdAt
                            Write-Host "    $icon $($run.conclusion) - $($time.ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor Gray
                        }
                    }
                }
                
                # Check for pattern of failures
                $failures = @($runsData | Where-Object { $_.conclusion -eq 'failure' })
                if ($failures.Count -eq $runsData.Count -and $failures.Count -gt 0) {
                    Write-CheckResult "Failure Pattern" "Fail" "All recent runs failed - systematic issue"
                    Write-Host "  💡 Likely causes:" -ForegroundColor Yellow
                    Write-Host "     1. GitHub Pages not enabled in Settings" -ForegroundColor Yellow
                    Write-Host "     2. Incorrect workflow permissions" -ForegroundColor Yellow
                    Write-Host "     3. Pages source not set to 'GitHub Actions'" -ForegroundColor Yellow
                }
            }
        }
        catch {
            Write-CheckResult "Workflow Runs" "Warn" "Could not fetch runs: $_"
        }
    } else {
        Write-CheckResult "GitHub CLI" "Warn" "Not authenticated - install 'gh' and run 'gh auth login'"
        Write-Host "  ℹ️  Install: https://cli.github.com/" -ForegroundColor Cyan
    }
    
    # Test if Pages site is accessible
    $pagesUrl = "https://wizzense.github.io/AitherZero/"
    try {
        $response = Invoke-WebRequest -Uri $pagesUrl -Method Head -TimeoutSec 10 -ErrorAction Stop
        Write-CheckResult "Pages Site" "Pass" "Accessible at $pagesUrl"
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            Write-CheckResult "Pages Site" "Fail" "404 Not Found - site not deployed"
        } else {
            Write-CheckResult "Pages Site" "Warn" "Could not verify: $($_.Exception.Message)"
        }
    }
}

# ============================================================================
# Container Deployment Checks
# ============================================================================
if ($CheckContainers) {
    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "🐳 CONTAINER DEPLOYMENT CHECKS" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    
    $hasGH = Test-GitHubCLI
    if ($hasGH) {
        try {
            $runs = gh run list --workflow="deploy-pr-environment.yml" --limit 5 --json status,conclusion,createdAt 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $runsData = $runs | ConvertFrom-Json
                Write-CheckResult "Container Workflow" "Pass" "Found $($runsData.Count) recent runs"
                
                $successCount = @($runsData | Where-Object { $_.conclusion -eq 'success' }).Count
                $actionRequiredCount = @($runsData | Where-Object { $_.conclusion -eq 'action_required' }).Count
                
                if ($successCount -gt 0) {
                    Write-CheckResult "Successful Builds" "Pass" "$successCount of $($runsData.Count) runs succeeded"
                }
                
                if ($actionRequiredCount -gt 0) {
                    Write-CheckResult "Validation Status" "Warn" "$actionRequiredCount runs need validation approval"
                    Write-Host "  ℹ️  This is normal - Docker validation checks require approval" -ForegroundColor Cyan
                }
            }
        }
        catch {
            Write-CheckResult "Container Runs" "Warn" "Could not fetch runs"
        }
    }
    
    # Check if Docker is available
    try {
        $null = docker --version 2>&1
        Write-CheckResult "Docker CLI" "Pass" "Available for local testing"
        
        # Check if we can reach GHCR
        $packageUrl = "https://github.com/wizzense/AitherZero/pkgs/container/aitherzero"
        try {
            $response = Invoke-WebRequest -Uri $packageUrl -Method Head -TimeoutSec 10 -ErrorAction Stop
            Write-CheckResult "Container Registry" "Pass" "GHCR accessible at $packageUrl"
        }
        catch {
            Write-CheckResult "Container Registry" "Warn" "Could not verify GHCR access"
        }
    }
    catch {
        Write-CheckResult "Docker CLI" "Info" "Not installed (optional for validation)"
    }
}

# ============================================================================
# Summary
# ============================================================================
Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📊 VALIDATION SUMMARY" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Write-Host "`nTotal Checks: $TotalChecks" -ForegroundColor White
Write-Host "  ✅ Passed: $PassedChecks" -ForegroundColor Green
Write-Host "  ❌ Failed: $FailedChecks" -ForegroundColor Red
Write-Host "  ⚠️  Warnings: $WarningChecks" -ForegroundColor Yellow

$overallStatus = if ($FailedChecks -eq 0 -and $WarningChecks -eq 0) {
    "All systems operational ✅"
} elseif ($FailedChecks -gt 0) {
    "Critical issues found ❌ - See DEPLOYMENT-DIAGNOSIS.md"
} else {
    "Minor issues or warnings ⚠️"
}

Write-Host "`nOverall Status: " -NoNewline
Write-Host $overallStatus -ForegroundColor $(if ($FailedChecks -gt 0) { 'Red' } elseif ($WarningChecks -gt 0) { 'Yellow' } else { 'Green' })

if ($FailedChecks -gt 0) {
    Write-Host "`n📖 Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Read DEPLOYMENT-DIAGNOSIS.md for detailed resolution steps" -ForegroundColor White
    Write-Host "  2. Check repository Settings > Pages" -ForegroundColor White
    Write-Host "  3. Check repository Settings > Actions > General > Workflow permissions" -ForegroundColor White
    Write-Host "  4. Run manual workflow deployment to test fixes" -ForegroundColor White
}

Write-Host ""

# Exit with appropriate code
if ($FailedChecks -gt 0) {
    exit 1
} elseif ($WarningChecks -gt 0) {
    exit 2
} else {
    exit 0
}
