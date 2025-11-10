#Requires -Version 7.0

<#
.SYNOPSIS
    Collect ring strategy health metrics for dashboard visualization
.DESCRIPTION
    Gathers metrics for all rings in the ring-based branching strategy including:
    - Branch health status
    - Active PRs per ring
    - Commit activity
    - Test pass rates
    - Quality scores
    - Deployment status
    
    Exit Codes:
    0   - Success
    1   - Failure
    
.NOTES
    Stage: Reporting
    Order: 0520
    Dependencies: None
    Tags: reporting, ring, metrics, dashboard, health
    
.PARAMETER OutputPath
    Path to write ring metrics JSON file
.PARAMETER Rings
    Array of ring branch names to collect metrics for
.PARAMETER IncludeHistory
    Include historical trend data (last 30 days)
    
.EXAMPLE
    ./0520_Collect-RingMetrics.ps1 -OutputPath "./reports/ring-metrics.json"
#>

[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "library/reports/ring-metrics.json"),
    
    [string[]]$Rings = @('main', 'dev-staging', 'dev', 'ring-0', 'ring-0-integrations', 'ring-1', 'ring-1-integrations', 'ring-2'),
    
    [switch]$IncludeHistory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Import modules
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$loggingModule = Join-Path $projectRoot "aithercore/utilities/Logging.psm1"

if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force
}

function Write-ScriptLog {
    param([string]$Level = 'Information', [string]$Message)
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "0520_Collect-RingMetrics"
    } else {
        Write-Host "[$Level] $Message"
    }
}

try {
    Write-ScriptLog "Collecting ring metrics for $($Rings.Count) rings..."
    
    $ringMetrics = @{
        Timestamp = (Get-Date).ToString("o")
        Rings = @()
    }
    
    foreach ($ring in $Rings) {
        Write-ScriptLog "Processing ring: $ring"
        
        $ringData = @{
            Name = $ring
            DisplayName = switch ($ring) {
                'main' { '🎯 Main (Production)' }
                'dev-staging' { '🔄 Dev-Staging (Pre-Release)' }
                'dev' { '🛠️ Dev (Integration)' }
                'ring-0' { '⚙️ Ring 0 (Core)' }
                'ring-0-integrations' { '🔗 Ring 0 Integrations' }
                'ring-1' { '✨ Ring 1 (Features)' }
                'ring-1-integrations' { '🧩 Ring 1 Integrations' }
                'ring-2' { '🧪 Ring 2 (Experimental)' }
                default { $ring }
            }
            Health = 'Unknown'
            ActivePRs = 0
            CommitsLast7Days = 0
            TestPassRate = 0
            QualityScore = 0
            DeploymentStatus = 'Unknown'
            LastCommit = @{
                SHA = ''
                Author = ''
                Date = ''
                Message = ''
            }
        }
        
        # Check if running in GitHub Actions with access to git
        if (Get-Command git -ErrorAction SilentlyContinue) {
            try {
                # Get last commit info for the ring
                Push-Location $projectRoot
                $branchExists = git rev-parse --verify "origin/$ring" 2>$null
                
                if ($LASTEXITCODE -eq 0) {
                    $commitInfo = git log "origin/$ring" -1 --pretty=format:"%H|%an|%ai|%s" 2>$null
                    
                    if ($commitInfo) {
                        $parts = $commitInfo -split '\|'
                        $ringData.LastCommit = @{
                            SHA = $parts[0].Substring(0, [Math]::Min(7, $parts[0].Length))
                            Author = $parts[1]
                            Date = $parts[2]
                            Message = $parts[3]
                        }
                        $ringData.Health = 'Healthy'
                    }
                    
                    # Count commits in last 7 days
                    $since = (Get-Date).AddDays(-7).ToString("yyyy-MM-dd")
                    $commitCount = git rev-list --count --since="$since" "origin/$ring" 2>$null
                    if ($LASTEXITCODE -eq 0 -and $commitCount) {
                        $ringData.CommitsLast7Days = [int]$commitCount
                    }
                } else {
                    $ringData.Health = 'Branch Not Found'
                }
                
                Pop-Location
            }
            catch {
                Write-ScriptLog -Level Warning "Failed to get git info for $ring : $_"
                $ringData.Health = 'Error'
            }
        }
        
        # If in GitHub Actions, get PR count via gh CLI
        if ($env:GITHUB_ACTIONS -eq 'true' -and (Get-Command gh -ErrorAction SilentlyContinue)) {
            try {
                $prCount = gh pr list --base $ring --json number --jq '. | length' 2>$null
                if ($LASTEXITCODE -eq 0 -and $prCount) {
                    $ringData.ActivePRs = [int]$prCount
                }
            }
            catch {
                Write-ScriptLog -Level Warning "Failed to get PR count for $ring : $_"
            }
        }
        
        # Placeholder for test pass rate and quality score
        # These would be loaded from previous test run results
        $testResultsPath = Join-Path $projectRoot "library/tests/results/ring-$ring.json"
        if (Test-Path $testResultsPath) {
            $testResults = Get-Content $testResultsPath | ConvertFrom-Json
            $ringData.TestPassRate = $testResults.PassRate
        }
        
        $qualityMetricsPath = Join-Path $projectRoot "library/reports/quality-ring-$ring.json"
        if (Test-Path $qualityMetricsPath) {
            $qualityMetrics = Get-Content $qualityMetricsPath | ConvertFrom-Json
            $ringData.QualityScore = $qualityMetrics.Score
        }
        
        $ringMetrics.Rings += $ringData
    }
    
    # Ensure output directory exists
    $outputDir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $outputDir)) {
        New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
    }
    
    # Write metrics to JSON
    $ringMetrics | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding utf8 -Force
    
    Write-ScriptLog "Ring metrics collected successfully: $OutputPath"
    Write-ScriptLog "Rings processed: $($ringMetrics.Rings.Count)"
    
    exit 0
}
catch {
    Write-ScriptLog -Level Error "Failed to collect ring metrics: $_"
    exit 1
}
