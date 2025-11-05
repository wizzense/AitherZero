#Requires -Version 7.0

<#
.SYNOPSIS
    Manage ring-based deployment strategy for AitherZero.

.DESCRIPTION
    This script provides utilities for managing the ring-based deployment system:
    - View ring status and hierarchy
    - Promote/demote changes between rings
    - Validate ring configurations
    - Generate ring reports
    - Manage ring labels

.PARAMETER Action
    The action to perform: status, promote, demote, validate, report

.PARAMETER SourceRing
    The source ring for promotion/demotion operations

.PARAMETER TargetRing
    The target ring for promotion/demotion operations

.PARAMETER CreatePR
    Create a pull request for the promotion/demotion

.PARAMETER Format
    Output format: console, json, markdown

.EXAMPLE
    ./0710_Manage-RingDeployment.ps1 -Action status
    Display current ring status

.EXAMPLE
    ./0710_Manage-RingDeployment.ps1 -Action promote -SourceRing ring-0 -TargetRing ring-0-integrations -CreatePR
    Promote changes from ring-0 to ring-0-integrations with PR creation

.EXAMPLE
    ./0710_Manage-RingDeployment.ps1 -Action validate
    Validate ring configuration

.NOTES
    Author: AitherZero Team
    Stage: Development
    Dependencies: Git, GitHub CLI (gh)
    Tags: rings, deployment, promotion, ci-cd
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('status', 'promote', 'demote', 'validate', 'report', 'list')]
    [string]$Action = 'status',

    [Parameter(Mandatory = $false)]
    [ValidateSet('ring-0', 'ring-0-integrations', 'ring-1', 'ring-1-integrations', 'ring-2', 'dev', 'main')]
    [string]$SourceRing,

    [Parameter(Mandatory = $false)]
    [ValidateSet('ring-0', 'ring-0-integrations', 'ring-1', 'ring-1-integrations', 'ring-2', 'dev', 'main')]
    [string]$TargetRing,

    [Parameter(Mandatory = $false)]
    [switch]$CreatePR,

    [Parameter(Mandatory = $false)]
    [ValidateSet('console', 'json', 'markdown')]
    [string]$Format = 'console'
)

# Import common functions if available
$ProjectRoot = if ($PSScriptRoot) {
    Split-Path $PSScriptRoot -Parent
} else {
    Get-Location | Select-Object -ExpandProperty Path
}

if (Test-Path (Join-Path $ProjectRoot "domains/automation/ScriptUtilities.psm1")) {
    Import-Module (Join-Path $ProjectRoot "domains/automation/ScriptUtilities.psm1") -Force
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Information', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Information'
    )
    
    $color = switch ($Level) {
        'Information' { 'Cyan' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Success' { 'Green' }
    }
    
    $prefix = switch ($Level) {
        'Information' { 'ℹ️' }
        'Warning' { '⚠️' }
        'Error' { '❌' }
        'Success' { '✅' }
    }
    
    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Get-RingConfiguration {
    <#
    .SYNOPSIS
        Load ring configuration from JSON file
    #>
    $configPath = Join-Path $ProjectRoot ".github/ring-config.json"
    
    if (-not (Test-Path $configPath)) {
        Write-Log "Ring configuration file not found: $configPath" -Level Error
        return $null
    }
    
    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        return $config
    } catch {
        Write-Log "Failed to parse ring configuration: $_" -Level Error
        return $null
    }
}

function Get-RingStatus {
    <#
    .SYNOPSIS
        Get current status of all rings
    #>
    Write-Log "Fetching ring status..." -Level Information
    
    $config = Get-RingConfiguration
    if (-not $config) {
        return
    }
    
    $status = @{
        Rings = @()
        Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
    }
    
    # Get all branches
    $branches = git branch -a | ForEach-Object { $_.TrimStart('* ').Trim() }
    
    foreach ($ringName in $config.rings.PSObject.Properties.Name) {
        $ring = $config.rings.$ringName
        
        # Check if branch exists
        $branchExists = $branches -contains $ringName -or $branches -contains "remotes/origin/$ringName"
        
        # Get latest commit info if branch exists
        $latestCommit = $null
        if ($branchExists) {
            try {
                $commitInfo = git log $ringName -1 --format="%H|%an|%ae|%s|%ci" 2>$null
                if ($commitInfo) {
                    $parts = $commitInfo -split '\|'
                    $latestCommit = @{
                        Hash = $parts[0]
                        Author = $parts[1]
                        Email = $parts[2]
                        Message = $parts[3]
                        Date = $parts[4]
                    }
                }
            } catch {
                Write-Log "Could not get commit info for $ringName" -Level Warning
            }
        }
        
        $ringStatus = @{
            Name = $ringName
            Level = $ring.level
            DisplayName = $ring.name
            Description = $ring.description
            Type = $ring.type
            TestProfile = $ring.testProfile
            RequiredApprovals = $ring.requiredApprovals
            BranchExists = $branchExists
            LatestCommit = $latestCommit
            NextRing = $ring.nextRing
            PreviousRing = $ring.previousRing
            Protected = $ring.protected -eq $true
        }
        
        $status.Rings += $ringStatus
    }
    
    return $status
}

function Show-RingStatus {
    <#
    .SYNOPSIS
        Display ring status in formatted output
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$Status,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputFormat = 'console'
    )
    
    switch ($OutputFormat) {
        'json' {
            $Status | ConvertTo-Json -Depth 10
        }
        
        'markdown' {
            $md = "# Ring Deployment Status`n`n"
            $md += "**Generated:** $($Status.Timestamp)`n`n"
            $md += "## Ring Hierarchy`n`n"
            $md += "| Level | Ring | Type | Test Profile | Approvals | Status | Latest Commit |`n"
            $md += "|-------|------|------|--------------|-----------|--------|---------------|`n"
            
            foreach ($ring in ($Status.Rings | Sort-Object Level)) {
                $statusIcon = if ($ring.BranchExists) { '✅' } else { '❌' }
                $commitInfo = if ($ring.LatestCommit) {
                    $ring.LatestCommit.Hash.Substring(0, 7)
                } else {
                    'N/A'
                }
                
                $md += "| $($ring.Level) | $($ring.Name) | $($ring.Type) | $($ring.TestProfile) | $($ring.RequiredApprovals) | $statusIcon | $commitInfo |`n"
            }
            
            $md += "`n## Ring Details`n`n"
            
            foreach ($ring in ($Status.Rings | Sort-Object Level)) {
                $md += "### $($ring.DisplayName) ($($ring.Name))`n`n"
                $md += "**Description:** $($ring.Description)`n`n"
                $md += "**Configuration:**`n"
                $md += "- Level: $($ring.Level)`n"
                $md += "- Type: $($ring.Type)`n"
                $md += "- Test Profile: $($ring.TestProfile)`n"
                $md += "- Required Approvals: $($ring.RequiredApprovals)`n"
                $md += "- Protected: $(if ($ring.Protected) { 'Yes' } else { 'No' })`n"
                
                if ($ring.NextRing) {
                    $md += "- Next Ring: $($ring.NextRing)`n"
                }
                if ($ring.PreviousRing) {
                    $md += "- Previous Ring: $($ring.PreviousRing)`n"
                }
                
                if ($ring.LatestCommit) {
                    $md += "`n**Latest Commit:**`n"
                    $md += "- Hash: ``$($ring.LatestCommit.Hash.Substring(0, 7))```n"
                    $md += "- Author: $($ring.LatestCommit.Author)`n"
                    $md += "- Message: $($ring.LatestCommit.Message)`n"
                    $md += "- Date: $($ring.LatestCommit.Date)`n"
                }
                
                $md += "`n"
            }
            
            Write-Output $md
        }
        
        'console' {
            Write-Host ""
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
            Write-Host "🎯 RING DEPLOYMENT STATUS" -ForegroundColor Cyan
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Generated: $($Status.Timestamp)" -ForegroundColor Gray
            Write-Host ""
            
            foreach ($ring in ($Status.Rings | Sort-Object Level)) {
                $statusIcon = if ($ring.BranchExists) { '✅' } else { '❌' }
                $protectedIcon = if ($ring.Protected) { '🔒' } else { '  ' }
                
                Write-Host "$statusIcon $protectedIcon " -NoNewline
                Write-Host "Level $($ring.Level.ToString().PadRight(3)) | " -NoNewline -ForegroundColor Yellow
                Write-Host "$($ring.Name.PadRight(20))" -NoNewline -ForegroundColor Cyan
                Write-Host " | $($ring.TestProfile.PadRight(15))" -NoNewline -ForegroundColor White
                Write-Host " | Approvals: $($ring.RequiredApprovals)" -ForegroundColor Gray
                
                if ($ring.LatestCommit) {
                    Write-Host "     └─ Latest: " -NoNewline -ForegroundColor DarkGray
                    Write-Host "$($ring.LatestCommit.Hash.Substring(0, 7)) " -NoNewline -ForegroundColor Magenta
                    Write-Host "by $($ring.LatestCommit.Author) " -NoNewline -ForegroundColor Gray
                    Write-Host "- $($ring.LatestCommit.Message.Substring(0, [Math]::Min(50, $ring.LatestCommit.Message.Length)))" -ForegroundColor DarkGray
                }
                
                Write-Host ""
            }
            
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Legend:" -ForegroundColor Cyan
            Write-Host "  ✅ - Branch exists" -ForegroundColor Green
            Write-Host "  ❌ - Branch missing" -ForegroundColor Red
            Write-Host "  🔒 - Protected branch" -ForegroundColor Yellow
            Write-Host ""
        }
    }
}

function Invoke-RingPromotion {
    <#
    .SYNOPSIS
        Promote changes from source ring to target ring
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        
        [Parameter(Mandatory = $true)]
        [string]$Target,
        
        [Parameter(Mandatory = $false)]
        [bool]$CreatePullRequest = $false
    )
    
    Write-Log "Initiating ring promotion: $Source → $Target" -Level Information
    
    # Validate rings exist
    $config = Get-RingConfiguration
    if (-not $config) {
        return
    }
    
    if (-not $config.rings.$Source) {
        Write-Log "Source ring '$Source' not found in configuration" -Level Error
        return
    }
    
    if (-not $config.rings.$Target) {
        Write-Log "Target ring '$Target' not found in configuration" -Level Error
        return
    }
    
    # Check if promotion is valid (target level should be higher)
    $sourceLevel = $config.rings.$Source.level
    $targetLevel = $config.rings.$Target.level
    
    if ($targetLevel -le $sourceLevel) {
        Write-Log "Invalid promotion: Target ring level ($targetLevel) must be higher than source ring level ($sourceLevel)" -Level Error
        return
    }
    
    # Check if branches exist
    $branches = git branch -a | ForEach-Object { $_.TrimStart('* ').Trim() }
    
    if (-not ($branches -contains $Source -or $branches -contains "remotes/origin/$Source")) {
        Write-Log "Source branch '$Source' does not exist" -Level Error
        return
    }
    
    if (-not ($branches -contains $Target -or $branches -contains "remotes/origin/$Target")) {
        Write-Log "Target branch '$Target' does not exist" -Level Error
        return
    }
    
    if ($CreatePullRequest) {
        # Check if gh CLI is available
        if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
            Write-Log "GitHub CLI (gh) is not available. Please install it or create PR manually." -Level Error
            Write-Log "Visit: https://cli.github.com/" -Level Information
            return
        }
        
        Write-Log "Creating promotion PR..." -Level Information
        
        $prTitle = "🎯 Promote: $Source → $Target"
        $prBody = @"
## 🎯 Ring Promotion

This PR promotes changes from **$Source** to **$Target**.

**Promotion Type:** Manual
**Source Ring:** $Source (Level $sourceLevel)
**Target Ring:** $Target (Level $targetLevel)

### ✅ Pre-Promotion Checklist

- [ ] All tests passed in source ring
- [ ] Code review completed
- [ ] Security scan passed
- [ ] Documentation updated
- [ ] Breaking changes documented (if any)

### 🧪 Test Requirements

**Test Profile:** $($config.rings.$Target.testProfile)
**Estimated Duration:** $($config.testProfiles.($config.rings.$Target.testProfile).estimatedDuration)

**Required Gates:**
"@
        
        $gates = $config.rings.$Target.deploymentGates
        foreach ($gate in $gates.PSObject.Properties) {
            $icon = if ($gate.Value) { '✅' } else { '⏭️' }
            $prBody += "`n- $icon $($gate.Name)"
        }
        
        $prBody += @"

### 🚀 Post-Merge Actions

1. Monitor automated tests
2. Verify deployment to $Target environment
3. Check for any issues in $Target ring
4. Prepare for next promotion (if applicable)

---
*🤖 Automated Ring Promotion*
"@
        
        try {
            $result = gh pr create --base $Target --head $Source --title $prTitle --body $prBody 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "PR created successfully!" -Level Success
                Write-Host $result
            } else {
                Write-Log "Failed to create PR: $result" -Level Error
            }
        } catch {
            Write-Log "Error creating PR: $_" -Level Error
        }
    } else {
        Write-Log "Promotion planned but not executed (use -CreatePR to create pull request)" -Level Information
        Write-Log "To promote manually, run:" -Level Information
        Write-Host "  gh pr create --base $Target --head $Source --title '🎯 Promote: $Source → $Target'" -ForegroundColor Yellow
    }
}

function Test-RingConfiguration {
    <#
    .SYNOPSIS
        Validate ring configuration
    #>
    Write-Log "Validating ring configuration..." -Level Information
    
    $config = Get-RingConfiguration
    if (-not $config) {
        return $false
    }
    
    $isValid = $true
    
    # Check ring levels are sequential
    $levels = @()
    foreach ($ringName in $config.rings.PSObject.Properties.Name) {
        $ring = $config.rings.$ringName
        $levels += $ring.level
    }
    
    $sortedLevels = $levels | Sort-Object
    for ($i = 0; $i -lt $sortedLevels.Count; $i++) {
        if ($sortedLevels[$i] -ne $levels[$i]) {
            Write-Log "Ring levels are not in sequential order" -Level Warning
        }
    }
    
    # Validate ring references
    foreach ($ringName in $config.rings.PSObject.Properties.Name) {
        $ring = $config.rings.$ringName
        
        if ($ring.nextRing -and -not $config.rings.($ring.nextRing)) {
            Write-Log "Ring '$ringName' references non-existent nextRing: $($ring.nextRing)" -Level Error
            $isValid = $false
        }
        
        if ($ring.previousRing -and -not $config.rings.($ring.previousRing)) {
            Write-Log "Ring '$ringName' references non-existent previousRing: $($ring.previousRing)" -Level Error
            $isValid = $false
        }
        
        if ($ring.testProfile -and -not $config.testProfiles.($ring.testProfile)) {
            Write-Log "Ring '$ringName' references non-existent testProfile: $($ring.testProfile)" -Level Error
            $isValid = $false
        }
    }
    
    if ($isValid) {
        Write-Log "Ring configuration is valid ✅" -Level Success
    } else {
        Write-Log "Ring configuration has errors ❌" -Level Error
    }
    
    return $isValid
}

# Main execution
try {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "🎯 Ring Deployment Manager" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host ""
    
    switch ($Action) {
        'status' {
            $status = Get-RingStatus
            if ($status) {
                Show-RingStatus -Status $status -OutputFormat $Format
            }
        }
        
        'list' {
            $status = Get-RingStatus
            if ($status) {
                Show-RingStatus -Status $status -OutputFormat $Format
            }
        }
        
        'promote' {
            if (-not $SourceRing -or -not $TargetRing) {
                Write-Log "Source and target rings are required for promotion" -Level Error
                Write-Host "Usage: ./0710_Manage-RingDeployment.ps1 -Action promote -SourceRing ring-0 -TargetRing ring-1 -CreatePR" -ForegroundColor Yellow
                exit 1
            }
            
            Invoke-RingPromotion -Source $SourceRing -Target $TargetRing -CreatePullRequest $CreatePR
        }
        
        'demote' {
            if (-not $SourceRing -or -not $TargetRing) {
                Write-Log "Source and target rings are required for demotion" -Level Error
                Write-Host "Usage: ./0710_Manage-RingDeployment.ps1 -Action demote -SourceRing ring-1 -TargetRing ring-0 -CreatePR" -ForegroundColor Yellow
                exit 1
            }
            
            Write-Log "Demotion is similar to promotion but in reverse" -Level Warning
            Invoke-RingPromotion -Source $SourceRing -Target $TargetRing -CreatePullRequest $CreatePR
        }
        
        'validate' {
            $isValid = Test-RingConfiguration
            exit $(if ($isValid) { 0 } else { 1 })
        }
        
        'report' {
            $status = Get-RingStatus
            if ($status) {
                $reportPath = Join-Path $ProjectRoot "reports/ring-status-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
                $reportDir = Split-Path $reportPath -Parent
                
                if (-not (Test-Path $reportDir)) {
                    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
                }
                
                Show-RingStatus -Status $status -OutputFormat 'markdown' | Out-File -FilePath $reportPath -Encoding UTF8
                Write-Log "Report generated: $reportPath" -Level Success
            }
        }
        
        default {
            Write-Log "Unknown action: $Action" -Level Error
            exit 1
        }
    }
    
    Write-Host ""
    
} catch {
    Write-Log "Error: $_" -Level Error
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
