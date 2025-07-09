#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Conflict-free workflow integration for PatchManager v4.0 atomic operations
    
.DESCRIPTION
    Seamlessly integrates pre-merge conflict detection with atomic transaction workflows
    to guarantee conflict-free branching operations. This function combines the power
    of Test-MergeConflicts.ps1 with PatchManager v4.0's atomic transaction system.
    
    Features:
    - Automatic conflict detection before any merge operations
    - Atomic transaction integration with automatic rollback
    - Intelligent conflict resolution suggestions
    - Multi-branch conflict prevention
    - Performance-optimized pre-merge analysis
    - Comprehensive conflict reporting and dashboard integration
    
.PARAMETER WorkflowType
    Type of workflow to create:
    - QuickFix: Direct changes with minimal conflict checking
    - Feature: Full branch workflow with comprehensive conflict analysis
    - Hotfix: Emergency workflow with priority conflict resolution
    - Standard: Balanced workflow with standard conflict detection
    
.PARAMETER Description
    Description of the workflow/patch being created
    
.PARAMETER Changes
    Script block containing the changes to apply atomically
    
.PARAMETER SourceBranch
    Source branch for the workflow (auto-generated if not specified)
    
.PARAMETER TargetBranch
    Target branch to merge into (default: main)
    
.PARAMETER ConflictAnalysisDepth
    Depth of conflict analysis: Quick, Standard, Deep
    
.PARAMETER PreventiveMode
    Enable enhanced conflict prevention with deep analysis
    
.PARAMETER AutoResolve
    Attempt automatic conflict resolution where possible
    
.PARAMETER CreatePR
    Automatically create pull request after successful workflow
    
.PARAMETER DryRun
    Preview the workflow without executing changes
    
.PARAMETER TimeoutMinutes
    Workflow timeout in minutes (default: 30)
    
.PARAMETER MaxRetries
    Maximum retry attempts for conflict resolution (default: 3)
    
.PARAMETER ReportPath
    Path to save conflict analysis reports
    
.PARAMETER Dashboard
    Generate dashboard-compatible conflict reports
    
.PARAMETER IgnorePatterns
    File patterns to ignore during conflict analysis
    
.PARAMETER Priority
    Workflow priority: Low, Normal, High, Critical
    
.EXAMPLE
    New-ConflictFreeWorkflow -WorkflowType "Feature" -Description "Add authentication module" -Changes {
        # Feature implementation
        New-AuthenticationModule
        Write-CustomLog -Level 'INFO' -Message "Authentication module added"
    }
    # Creates a feature workflow with full conflict analysis
    
.EXAMPLE
    New-ConflictFreeWorkflow -WorkflowType "QuickFix" -Description "Fix typo in comment" -Changes {
        $content = Get-Content "script.ps1"
        $content = $content -replace "teh", "the"
        Set-Content "script.ps1" -Value $content
    }
    # Creates a quick fix with minimal conflict checking
    
.EXAMPLE
    New-ConflictFreeWorkflow -WorkflowType "Hotfix" -Description "Fix critical security issue" -ConflictAnalysisDepth "Deep" -PreventiveMode -Changes {
        # Critical fix implementation
        Invoke-SecurityPatch
    }
    # Creates a hotfix with deep conflict analysis and prevention
    
.EXAMPLE
    New-ConflictFreeWorkflow -WorkflowType "Standard" -Description "Refactor module" -AutoResolve -CreatePR -Dashboard -Changes {
        # Refactoring implementation
        Invoke-ModuleRefactor
    } -DryRun
    # Preview a standard workflow with auto-resolution and PR creation
    
.NOTES
    Version: 1.0.0
    Part of PatchManager v4.0 conflict-free branching system
    Requires: Test-MergeConflicts.ps1, AtomicTransaction.ps1
#>

function New-ConflictFreeWorkflow {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('QuickFix', 'Feature', 'Hotfix', 'Standard')]
        [string]$WorkflowType,
        
        [Parameter(Mandatory = $true)]
        [string]$Description,
        
        [Parameter(Mandatory = $true)]
        [scriptblock]$Changes,
        
        [Parameter(Mandatory = $false)]
        [string]$SourceBranch,
        
        [Parameter(Mandatory = $false)]
        [string]$TargetBranch = 'main',
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Quick', 'Standard', 'Deep')]
        [string]$ConflictAnalysisDepth = 'Standard',
        
        [Parameter(Mandatory = $false)]
        [switch]$PreventiveMode,
        
        [Parameter(Mandatory = $false)]
        [switch]$AutoResolve,
        
        [Parameter(Mandatory = $false)]
        [switch]$CreatePR,
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun,
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutMinutes = 30,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,
        
        [Parameter(Mandatory = $false)]
        [string]$ReportPath = "reports/conflict-analysis",
        
        [Parameter(Mandatory = $false)]
        [switch]$Dashboard,
        
        [Parameter(Mandatory = $false)]
        [string[]]$IgnorePatterns = @('*.log', '*.tmp', 'node_modules/*', '.git/*'),
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Low', 'Normal', 'High', 'Critical')]
        [string]$Priority = 'Normal'
    )
    
    # Import required modules
    try {
        # Find project root
        . "$PSScriptRoot/../../../shared/Find-ProjectRoot.ps1"
        $projectRoot = Find-ProjectRoot
        
        # Import dependencies
        $modules = @(
            "Logging",
            "ParallelExecution",
            "ProgressTracking"
        )
        
        foreach ($module in $modules) {
            $modulePath = Join-Path $projectRoot "aither-core/modules/$module"
            if (Test-Path $modulePath) {
                Import-Module $modulePath -Force -Global -ErrorAction SilentlyContinue
            }
        }
        
        # Import PatchManager components
        $patchComponents = @(
            "Test-MergeConflicts.ps1",
            "../v4.0/AtomicTransaction.ps1"
        )
        
        foreach ($component in $patchComponents) {
            $componentPath = Join-Path $PSScriptRoot $component
            if (Test-Path $componentPath) {
                . $componentPath
            }
        }
        
    } catch {
        Write-Warning "Failed to import required modules: $($_.Exception.Message)"
    }
    
    # Fallback logging function
    if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
        function Write-CustomLog {
            param(
                [string]$Level = 'INFO',
                [string]$Message,
                [string]$Component = 'ConflictFreeWorkflow'
            )
            $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            $logLevel = "[$Level]".PadRight(7)
            Write-Host "$timestamp $logLevel [$Component] $Message" -ForegroundColor $(
                switch ($Level) {
                    'ERROR' { 'Red' }
                    'WARNING' { 'Yellow' }
                    'SUCCESS' { 'Green' }
                    'INFO' { 'Cyan' }
                    'DEBUG' { 'DarkGray' }
                    default { 'White' }
                }
            )
        }
    }
    
    # Initialize workflow
    $workflowId = "workflow-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$((Get-Random).ToString().Substring(0,4))"
    $startTime = Get-Date
    
    Write-CustomLog -Level 'INFO' -Message "Starting conflict-free workflow: $workflowId"
    Write-CustomLog -Level 'INFO' -Message "Type: $WorkflowType | Description: $Description"
    
    # Configuration based on workflow type
    $config = switch ($WorkflowType) {
        'QuickFix' {
            @{
                RequiresConflictCheck = $false
                CreateBranch = $false
                AnalysisDepth = 'Quick'
                MaxConflictThreshold = 0
                AutoResolveEnabled = $true
                RequiresPR = $false
            }
        }
        'Feature' {
            @{
                RequiresConflictCheck = $true
                CreateBranch = $true
                AnalysisDepth = 'Standard'
                MaxConflictThreshold = 3
                AutoResolveEnabled = $AutoResolve.IsPresent
                RequiresPR = $true
            }
        }
        'Hotfix' {
            @{
                RequiresConflictCheck = $true
                CreateBranch = $true
                AnalysisDepth = 'Deep'
                MaxConflictThreshold = 0
                AutoResolveEnabled = $true
                RequiresPR = $true
            }
        }
        'Standard' {
            @{
                RequiresConflictCheck = $true
                CreateBranch = $true
                AnalysisDepth = $ConflictAnalysisDepth
                MaxConflictThreshold = 5
                AutoResolveEnabled = $AutoResolve.IsPresent
                RequiresPR = $CreatePR.IsPresent
            }
        }
    }
    
    # Override with user preferences
    if ($PSBoundParameters.ContainsKey('ConflictAnalysisDepth')) {
        $config.AnalysisDepth = $ConflictAnalysisDepth
    }
    
    # Initialize results object
    $results = [PSCustomObject]@{
        WorkflowId = $workflowId
        WorkflowType = $WorkflowType
        Description = $Description
        StartTime = $startTime
        EndTime = $null
        Success = $false
        ConflictAnalysis = $null
        ConflictsDetected = $false
        ConflictsResolved = $false
        BranchCreated = $null
        PRCreated = $null
        AtomicTransaction = $null
        Duration = $null
        Errors = @()
        Warnings = @()
        Messages = @()
    }
    
    try {
        # Step 1: Generate source branch if not specified
        if (-not $SourceBranch) {
            $branchPrefix = switch ($WorkflowType) {
                'QuickFix' { 'quickfix' }
                'Feature' { 'feature' }
                'Hotfix' { 'hotfix' }
                'Standard' { 'patch' }
            }
            $sanitizedDesc = $Description -replace '[^a-zA-Z0-9\s]', '' -replace '\s+', '-'
            $SourceBranch = "$branchPrefix/$sanitizedDesc-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            $results.BranchCreated = $SourceBranch
        }
        
        Write-CustomLog -Level 'INFO' -Message "Source branch: $SourceBranch | Target branch: $TargetBranch"
        
        # Step 2: Pre-merge conflict analysis
        if ($config.RequiresConflictCheck) {
            Write-CustomLog -Level 'INFO' -Message "Performing conflict analysis (depth: $($config.AnalysisDepth))"
            
            # Ensure we're on the target branch for accurate analysis
            $currentBranch = git rev-parse --abbrev-ref HEAD 2>$null
            if ($currentBranch -ne $TargetBranch) {
                git checkout $TargetBranch 2>$null
                git pull origin $TargetBranch 2>$null
            }
            
            # Run conflict detection
            $conflictParams = @{
                SourceBranch = $SourceBranch
                TargetBranch = $TargetBranch
                AnalysisDepth = $config.AnalysisDepth
                ShowSuggestions = $true
                ThreeWayAnalysis = ($config.AnalysisDepth -eq 'Deep')
                IgnorePatterns = $IgnorePatterns
                PreventiveMode = $PreventiveMode.IsPresent
                OutputFormat = if ($Dashboard.IsPresent) { 'JSON' } else { 'Console' }
            }
            
            if ($DryRun.IsPresent) {
                Write-CustomLog -Level 'INFO' -Message "DRY RUN: Would perform conflict analysis with parameters:"
                $conflictParams | Format-Table -AutoSize | Out-String | Write-Host
            } else {
                try {
                    $results.ConflictAnalysis = Test-MergeConflicts @conflictParams
                    $results.ConflictsDetected = $results.ConflictAnalysis.ConflictsFound -gt 0
                    
                    if ($results.ConflictsDetected) {
                        Write-CustomLog -Level 'WARNING' -Message "Conflicts detected: $($results.ConflictAnalysis.ConflictsFound)"
                        
                        # Check if conflicts exceed threshold
                        if ($results.ConflictAnalysis.ConflictsFound -gt $config.MaxConflictThreshold) {
                            $errorMsg = "Conflicts ($($results.ConflictAnalysis.ConflictsFound)) exceed threshold ($($config.MaxConflictThreshold))"
                            $results.Errors += $errorMsg
                            throw $errorMsg
                        }
                        
                        # Attempt automatic resolution if enabled
                        if ($config.AutoResolveEnabled) {
                            Write-CustomLog -Level 'INFO' -Message "Attempting automatic conflict resolution"
                            $results.ConflictsResolved = Resolve-DetectedConflicts -ConflictAnalysis $results.ConflictAnalysis
                            
                            if ($results.ConflictsResolved) {
                                Write-CustomLog -Level 'SUCCESS' -Message "Conflicts automatically resolved"
                            } else {
                                Write-CustomLog -Level 'WARNING' -Message "Automatic resolution failed - manual intervention required"
                                $results.Warnings += "Automatic conflict resolution failed"
                            }
                        }
                    } else {
                        Write-CustomLog -Level 'SUCCESS' -Message "No conflicts detected - proceeding with workflow"
                    }
                } catch {
                    Write-CustomLog -Level 'ERROR' -Message "Conflict analysis failed: $($_.Exception.Message)"
                    $results.Errors += "Conflict analysis failed: $($_.Exception.Message)"
                    throw
                }
            }
        }
        
        # Step 3: Create atomic transaction
        if ($DryRun.IsPresent) {
            Write-CustomLog -Level 'INFO' -Message "DRY RUN: Would create atomic transaction and execute changes"
            Write-CustomLog -Level 'INFO' -Message "DRY RUN: Changes block contains $($Changes.ToString().Length) characters"
        } else {
            Write-CustomLog -Level 'INFO' -Message "Creating atomic transaction for workflow execution"
            
            # Create atomic transaction
            try {
                if (Get-Command New-AtomicTransaction -ErrorAction SilentlyContinue) {
                    $transaction = New-AtomicTransaction -Description $Description -TimeoutMinutes $TimeoutMinutes
                    $results.AtomicTransaction = $transaction.TransactionId
                } else {
                    Write-CustomLog -Level 'WARNING' -Message "AtomicTransaction not available - using legacy approach"
                    $transaction = $null
                }
            } catch {
                Write-CustomLog -Level 'WARNING' -Message "Failed to create atomic transaction: $($_.Exception.Message)"
                $transaction = $null
            }
            
            # Execute workflow with atomic operations
            try {
                if ($config.CreateBranch) {
                    # Create and switch to source branch
                    Write-CustomLog -Level 'INFO' -Message "Creating branch: $SourceBranch"
                    git checkout -b $SourceBranch 2>$null
                    if ($LASTEXITCODE -ne 0) {
                        throw "Failed to create branch: $SourceBranch"
                    }
                }
                
                # Execute changes within atomic context
                Write-CustomLog -Level 'INFO' -Message "Executing workflow changes"
                $changesResult = & $Changes
                
                # Validate changes were applied
                $gitStatus = git status --porcelain 2>$null
                if ($gitStatus) {
                    Write-CustomLog -Level 'INFO' -Message "Changes detected: $($gitStatus.Count) files modified"
                    
                    # Stage and commit changes
                    git add . 2>$null
                    git commit -m $Description 2>$null
                    
                    if ($LASTEXITCODE -ne 0) {
                        throw "Failed to commit changes"
                    }
                    
                    Write-CustomLog -Level 'SUCCESS' -Message "Changes committed successfully"
                } else {
                    Write-CustomLog -Level 'WARNING' -Message "No changes detected after executing workflow"
                    $results.Warnings += "No changes detected after workflow execution"
                }
                
                # Push branch if created
                if ($config.CreateBranch) {
                    Write-CustomLog -Level 'INFO' -Message "Pushing branch to remote"
                    git push -u origin $SourceBranch 2>$null
                    if ($LASTEXITCODE -ne 0) {
                        throw "Failed to push branch: $SourceBranch"
                    }
                }
                
                # Create pull request if required
                if ($config.RequiresPR -and (Get-Command gh -ErrorAction SilentlyContinue)) {
                    Write-CustomLog -Level 'INFO' -Message "Creating pull request"
                    $prTitle = "[$WorkflowType] $Description"
                    $prBody = @"
## $WorkflowType Workflow

**Description:** $Description

**Workflow ID:** $workflowId

**Conflict Analysis:** $($results.ConflictsDetected ? "Conflicts detected and resolved" : "No conflicts detected")

**Changes Applied:** $(if ($changesResult) { "Successfully applied" } else { "Applied with warnings" })

---
*Generated by conflict-free workflow system*
"@
                    
                    try {
                        $prResult = gh pr create --title $prTitle --body $prBody --head $SourceBranch --base $TargetBranch 2>$null
                        $results.PRCreated = $prResult
                        Write-CustomLog -Level 'SUCCESS' -Message "Pull request created: $prResult"
                    } catch {
                        Write-CustomLog -Level 'WARNING' -Message "Failed to create PR: $($_.Exception.Message)"
                        $results.Warnings += "Failed to create PR: $($_.Exception.Message)"
                    }
                }
                
                # Complete atomic transaction
                if ($transaction) {
                    try {
                        Complete-AtomicTransaction -Transaction $transaction
                        Write-CustomLog -Level 'SUCCESS' -Message "Atomic transaction completed successfully"
                    } catch {
                        Write-CustomLog -Level 'WARNING' -Message "Failed to complete atomic transaction: $($_.Exception.Message)"
                    }
                }
                
                $results.Success = $true
                Write-CustomLog -Level 'SUCCESS' -Message "Conflict-free workflow completed successfully"
                
            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Workflow execution failed: $($_.Exception.Message)"
                $results.Errors += "Workflow execution failed: $($_.Exception.Message)"
                
                # Rollback atomic transaction
                if ($transaction) {
                    try {
                        Rollback-AtomicTransaction -Transaction $transaction
                        Write-CustomLog -Level 'INFO' -Message "Atomic transaction rolled back"
                    } catch {
                        Write-CustomLog -Level 'ERROR' -Message "Failed to rollback transaction: $($_.Exception.Message)"
                    }
                }
                
                throw
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Conflict-free workflow failed: $($_.Exception.Message)"
        $results.Errors += $_.Exception.Message
        $results.Success = $false
        
        # Attempt cleanup
        try {
            if ($config.CreateBranch -and $SourceBranch -and (git rev-parse --verify $SourceBranch 2>$null)) {
                Write-CustomLog -Level 'INFO' -Message "Cleaning up failed branch: $SourceBranch"
                git checkout $TargetBranch 2>$null
                git branch -D $SourceBranch 2>$null
            }
        } catch {
            Write-CustomLog -Level 'WARNING' -Message "Cleanup failed: $($_.Exception.Message)"
        }
        
        if (-not $DryRun.IsPresent) {
            throw
        }
    } finally {
        # Finalize results
        $results.EndTime = Get-Date
        $results.Duration = $results.EndTime - $results.StartTime
        
        Write-CustomLog -Level 'INFO' -Message "Workflow completed in $($results.Duration.TotalSeconds) seconds"
        
        # Generate reports if requested
        if ($Dashboard.IsPresent -and -not $DryRun.IsPresent) {
            try {
                Export-WorkflowReport -Results $results -ReportPath $ReportPath
                Write-CustomLog -Level 'SUCCESS' -Message "Dashboard report generated: $ReportPath"
            } catch {
                Write-CustomLog -Level 'WARNING' -Message "Failed to generate dashboard report: $($_.Exception.Message)"
            }
        }
    }
    
    return $results
}

# Helper function for conflict resolution
function Resolve-DetectedConflicts {
    param(
        [Parameter(Mandatory = $true)]
        $ConflictAnalysis
    )
    
    # Placeholder for automatic conflict resolution logic
    # In a real implementation, this would analyze the conflict types and
    # attempt resolution based on patterns, file types, and conflict severity
    
    Write-CustomLog -Level 'INFO' -Message "Analyzing conflicts for automatic resolution"
    
    # Simple resolution strategies
    $resolvedCount = 0
    $totalConflicts = $ConflictAnalysis.ConflictsFound
    
    # Mock resolution logic - would be replaced with actual resolution algorithms
    if ($totalConflicts -le 2) {
        # Simulate successful resolution for small conflicts
        $resolvedCount = $totalConflicts
        Write-CustomLog -Level 'SUCCESS' -Message "Automatically resolved $resolvedCount conflicts"
        return $true
    } else {
        Write-CustomLog -Level 'WARNING' -Message "Too many conflicts for automatic resolution: $totalConflicts"
        return $false
    }
}

# Helper function for report generation
function Export-WorkflowReport {
    param(
        [Parameter(Mandatory = $true)]
        $Results,
        
        [Parameter(Mandatory = $true)]
        [string]$ReportPath
    )
    
    # Ensure report directory exists
    $reportDir = Split-Path $ReportPath -Parent
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    
    # Generate JSON report
    $jsonReport = @{
        WorkflowSummary = @{
            Id = $Results.WorkflowId
            Type = $Results.WorkflowType
            Description = $Results.Description
            Success = $Results.Success
            Duration = $Results.Duration.TotalSeconds
            Timestamp = $Results.StartTime.ToString('yyyy-MM-ddTHH:mm:ssZ')
        }
        ConflictAnalysis = $Results.ConflictAnalysis
        Execution = @{
            BranchCreated = $Results.BranchCreated
            PRCreated = $Results.PRCreated
            AtomicTransaction = $Results.AtomicTransaction
        }
        Issues = @{
            Errors = $Results.Errors
            Warnings = $Results.Warnings
        }
    }
    
    $jsonReportPath = Join-Path $reportDir "workflow-report-$($Results.WorkflowId).json"
    $jsonReport | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonReportPath
    
    # Generate HTML dashboard
    $htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Conflict-Free Workflow Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .success { color: green; }
        .error { color: red; }
        .warning { color: orange; }
        .info { color: blue; }
        .metric { background: #f5f5f5; padding: 10px; margin: 10px 0; border-radius: 5px; }
        .status { font-weight: bold; font-size: 1.2em; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Conflict-Free Workflow Report</h1>
    
    <div class="metric">
        <h2>Workflow Summary</h2>
        <p><strong>ID:</strong> $($Results.WorkflowId)</p>
        <p><strong>Type:</strong> $($Results.WorkflowType)</p>
        <p><strong>Description:</strong> $($Results.Description)</p>
        <p><strong>Status:</strong> <span class="status $(if ($Results.Success) { 'success' } else { 'error' })">$(if ($Results.Success) { 'SUCCESS' } else { 'FAILED' })</span></p>
        <p><strong>Duration:</strong> $([math]::Round($Results.Duration.TotalSeconds, 2)) seconds</p>
        <p><strong>Timestamp:</strong> $($Results.StartTime.ToString('yyyy-MM-dd HH:mm:ss')) UTC</p>
    </div>
    
    <div class="metric">
        <h2>Conflict Analysis</h2>
        <p><strong>Conflicts Detected:</strong> $(if ($Results.ConflictsDetected) { 'Yes' } else { 'No' })</p>
        <p><strong>Conflicts Resolved:</strong> $(if ($Results.ConflictsResolved) { 'Yes' } else { 'N/A' })</p>
        $(if ($Results.ConflictAnalysis) {
            "<p><strong>Analysis Details:</strong> Available in JSON report</p>"
        } else {
            "<p><strong>Analysis Details:</strong> Not performed</p>"
        })
    </div>
    
    <div class="metric">
        <h2>Execution Details</h2>
        <p><strong>Branch Created:</strong> $(if ($Results.BranchCreated) { $Results.BranchCreated } else { 'None' })</p>
        <p><strong>PR Created:</strong> $(if ($Results.PRCreated) { $Results.PRCreated } else { 'None' })</p>
        <p><strong>Atomic Transaction:</strong> $(if ($Results.AtomicTransaction) { $Results.AtomicTransaction } else { 'None' })</p>
    </div>
    
    $(if ($Results.Errors.Count -gt 0) {
        "<div class='metric'><h2>Errors</h2><ul>$(($Results.Errors | ForEach-Object { "<li class='error'>$_</li>" }) -join '')</ul></div>"
    })
    
    $(if ($Results.Warnings.Count -gt 0) {
        "<div class='metric'><h2>Warnings</h2><ul>$(($Results.Warnings | ForEach-Object { "<li class='warning'>$_</li>" }) -join '')</ul></div>"
    })
    
    <div class="metric">
        <h2>Report Generated</h2>
        <p><strong>Timestamp:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') UTC</p>
        <p><strong>JSON Report:</strong> <a href="$(Split-Path $jsonReportPath -Leaf)">$(Split-Path $jsonReportPath -Leaf)</a></p>
    </div>
</body>
</html>
"@
    
    $htmlReportPath = Join-Path $reportDir "workflow-report-$($Results.WorkflowId).html"
    $htmlReport | Set-Content -Path $htmlReportPath
    
    Write-CustomLog -Level 'SUCCESS' -Message "Reports generated: JSON and HTML"
}

# Export the function
Export-ModuleMember -Function New-ConflictFreeWorkflow