#Requires -Version 7.0

<#
.SYNOPSIS
    Run continuous test-fix loop until all issues are resolved or max attempts reached
.DESCRIPTION
    Orchestrates the test-fix workflow in a loop, processing one issue at a time
    until all are resolved or have failed max attempts.
    
    Exit Codes:
    0   - All issues resolved or no issues to fix
    1   - Error during execution
    2   - Some issues remain unfixed after max loops
    
.NOTES
    Stage: Testing
    Order: 0758
    Dependencies: 0751-0757, OrchestrationEngine
    Tags: testing, automation, loop, orchestration
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TrackerPath = './test-fix-tracker.json',
    [int]$MaxLoops = 50,  # Maximum number of loop iterations
    [int]$MaxAttempts = 3,  # Maximum attempts per issue
    [switch]$CreateGitHubIssues,
    [switch]$NonInteractive,
    [switch]$CreatePullRequest,  # Create PR when all issues are resolved
    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata
$scriptMetadata = @{
    Stage = 'Testing'
    Order = 0758
    Dependencies = @('0751', '0752', '0753', '0754', '0755', '0756', '0757')
    Tags = @('testing', 'automation', 'loop', 'orchestration')
    RequiresAdmin = $false
    SupportsWhatIf = $true
}

# Import required modules
$projectRoot = Split-Path $PSScriptRoot -Parent
Import-Module "$projectRoot/AitherZero.psd1" -Force -ErrorAction Stop

function Write-ScriptLog {
    param(
        [string]$Level = 'Information',
        [string]$Message
    )
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message "[TestFixLoop] $Message" -Source "0758_Run-TestFixLoop"
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $color = @{
            'Error' = 'Red'
            'Warning' = 'Yellow'
            'Information' = 'White'
            'Debug' = 'Gray'
            'Success' = 'Green'
        }[$Level]
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    }
}

function Get-TrackerStatus {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        return $null
    }
    
    $tracker = Get-Content $Path -Raw | ConvertFrom-Json -AsHashtable
    
    # Ensure issues is an array
    if ($tracker.issues -isnot [array]) {
        $tracker.issues = @($tracker.issues)
    }
    
    $status = @{
        Total = $tracker.issues.Count
        Open = @($tracker.issues | Where-Object { $_.status -eq 'open' }).Count
        Fixing = @($tracker.issues | Where-Object { $_.status -eq 'fixing' }).Count
        Validating = @($tracker.issues | Where-Object { $_.status -eq 'validating' }).Count
        Resolved = @($tracker.issues | Where-Object { $_.status -eq 'resolved' }).Count
        Failed = @($tracker.issues | Where-Object { $_.status -eq 'failed' }).Count
        CanFix = @($tracker.issues | Where-Object { 
            $_.status -eq 'open' -and $_.attempts -lt $MaxAttempts 
        }).Count
    }
    
    return $status
}

function Show-Progress {
    param($Status, $LoopCount)
    
    Write-Host "`n" -NoNewline
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "TEST FIX LOOP - Iteration $LoopCount" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
    
    if ($Status) {
        Write-Host "📊 Current Status:" -ForegroundColor Yellow
        Write-Host "  Total Issues:    $($Status.Total)" -ForegroundColor White
        Write-Host "  ✅ Resolved:     $($Status.Resolved)" -ForegroundColor Green
        Write-Host "  🔧 In Progress:  $($Status.Fixing + $Status.Validating)" -ForegroundColor Yellow
        Write-Host "  📝 Open:         $($Status.Open)" -ForegroundColor Cyan
        Write-Host "  ❌ Failed:       $($Status.Failed)" -ForegroundColor Red
        Write-Host "  🎯 Can Fix:      $($Status.CanFix)" -ForegroundColor Magenta
    }
    
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host ""
}

try {
    Write-ScriptLog -Message "Starting test-fix loop (Max loops: $MaxLoops, Max attempts per issue: $MaxAttempts)"
    
    # Set environment for non-interactive execution
    if ($NonInteractive) {
        $env:AITHERZERO_NONINTERACTIVE = 'true'
        Write-ScriptLog -Message "Running in non-interactive mode"
    }
    
    # Initialize tracker if it doesn't exist or check test results age
    if (-not (Test-Path $TrackerPath)) {
        Write-ScriptLog -Message "Initializing tracker..."
        
        if ($PSCmdlet.ShouldProcess("0751_Load-TestTracker.ps1", "Initialize tracker")) {
            & "$PSScriptRoot/0751_Load-TestTracker.ps1" `
                -TrackerPath $TrackerPath `
                -CreateBranch `
                -CheckTestResults
            
            # Process test results
            & "$PSScriptRoot/0752_Process-TestResults.ps1" `
                -TrackerPath $TrackerPath `
                -MaxAgeHours 24
        }
    } else {
        # Check if we need fresh test results
        Write-ScriptLog -Message "Checking existing tracker and test results..."
        & "$PSScriptRoot/0751_Load-TestTracker.ps1" `
            -TrackerPath $TrackerPath `
            -CheckTestResults
        
        # Process any new test results
        & "$PSScriptRoot/0752_Process-TestResults.ps1" `
            -TrackerPath $TrackerPath `
            -MaxAgeHours 24
    }
    
    $loopCount = 0
    $consecutiveFailures = 0
    $maxConsecutiveFailures = 5
    
    # Main loop
    while ($loopCount -lt $MaxLoops) {
        $loopCount++
        
        # Get current status
        $status = Get-TrackerStatus -Path $TrackerPath
        
        if (-not $status) {
            Write-ScriptLog -Level Error -Message "Failed to load tracker"
            exit 1
        }
        
        Show-Progress -Status $status -LoopCount $loopCount
        
        # Check if we're done
        if ($status.CanFix -eq 0) {
            Write-ScriptLog -Level Success -Message "No more issues to fix!"
            break
        }
        
        # Create GitHub issues if requested and not already created
        if ($CreateGitHubIssues) {
            $tracker = Get-Content $TrackerPath -Raw | ConvertFrom-Json -AsHashtable
            $needsGitHubIssue = @($tracker.issues | Where-Object { 
                $_.status -eq 'open' -and (
                    -not ($_.PSObject.Properties.Name -contains 'githubIssue') -or 
                    -not $_.githubIssue
                )
            })
            
            if ($needsGitHubIssue.Count -gt 0) {
                Write-ScriptLog -Message "Creating GitHub issue for next test failure..."
                
                if ($PSCmdlet.ShouldProcess("0753_Create-GitHubIssue.ps1", "Create GitHub issue")) {
                    & "$PSScriptRoot/0753_Create-GitHubIssue.ps1" -TrackerPath $TrackerPath
                }
            }
        }
        
        # Fix next issue
        Write-ScriptLog -Message "Attempting to fix next issue..."
        
        if ($PSCmdlet.ShouldProcess("0754_Fix-SingleTestFailure.ps1", "Fix test failure")) {
            $fixResult = & "$PSScriptRoot/0754_Fix-SingleTestFailure.ps1" `
                -TrackerPath $TrackerPath `
                -MaxAttempts $MaxAttempts `
                -PassThru
            
            if ($LASTEXITCODE -ne 0) {
                $consecutiveFailures++
                Write-ScriptLog -Level Warning -Message "Fix attempt failed (consecutive failures: $consecutiveFailures)"
                
                if ($consecutiveFailures -ge $maxConsecutiveFailures) {
                    Write-ScriptLog -Level Error -Message "Too many consecutive failures. Stopping loop."
                    break
                }
            } else {
                $consecutiveFailures = 0
            }
        }
        
        # Validate fixes with automatic retry
        Write-ScriptLog -Message "Validating fixes (with retry on failure)..."
        
        if ($PSCmdlet.ShouldProcess("0755_Validate-TestFix.ps1", "Validate fixes")) {
            & "$PSScriptRoot/0755_Validate-TestFix.ps1" `
                -TrackerPath $TrackerPath `
                -ValidateAll `
                -RetryOnFailure `
                -MaxRetries $MaxAttempts
        }
        
        # Commit resolved fixes
        $tracker = Get-Content $TrackerPath -Raw | ConvertFrom-Json -AsHashtable
        $toCommit = @($tracker.issues | Where-Object { 
            $_.status -eq 'resolved' -and (
                -not ($_.PSObject.Properties.Name -contains 'fixCommit') -or 
                -not $_.fixCommit
            )
        })
        
        if ($toCommit.Count -gt 0) {
            Write-ScriptLog -Message "Committing $($toCommit.Count) resolved fix(es)..."
            
            if ($PSCmdlet.ShouldProcess("0756_Commit-TestFix.ps1", "Commit fixes")) {
                & "$PSScriptRoot/0756_Commit-TestFix.ps1" -TrackerPath $TrackerPath -CommitAll
            }
        }
        
        # Brief pause between iterations
        if ($loopCount -lt $MaxLoops) {
            Write-ScriptLog -Message "Pausing before next iteration..."
            Start-Sleep -Seconds 2
        }
    }
    
    # Final status
    $finalStatus = Get-TrackerStatus -Path $TrackerPath
    
    Write-Host "`n" -NoNewline
    Write-Host ("=" * 60) -ForegroundColor Green
    Write-Host "FINAL RESULTS" -ForegroundColor Green
    Write-Host ("=" * 60) -ForegroundColor Green
    
    if ($finalStatus) {
        Write-Host "📊 Final Status after $loopCount iteration(s):" -ForegroundColor Cyan
        Write-Host "  Total Issues:    $($finalStatus.Total)" -ForegroundColor White
        Write-Host "  ✅ Resolved:     $($finalStatus.Resolved)" -ForegroundColor Green
        Write-Host "  ❌ Failed:       $($finalStatus.Failed)" -ForegroundColor Red
        Write-Host "  📝 Still Open:   $($finalStatus.Open)" -ForegroundColor Yellow
        
        if ($finalStatus.Resolved -gt 0) {
            Write-Host "`n🎉 Successfully fixed $($finalStatus.Resolved) test failure(s)!" -ForegroundColor Green
            
            if ($CreatePullRequest) {
                Write-Host "`n📤 Creating pull request..." -ForegroundColor Cyan
                
                if ($PSCmdlet.ShouldProcess("0757_Create-FixPR.ps1", "Create pull request")) {
                    & "$PSScriptRoot/0757_Create-FixPR.ps1" -TrackerPath $TrackerPath
                }
            } else {
                Write-Host "💡 Run 0757_Create-FixPR.ps1 to create a pull request" -ForegroundColor Yellow
            }
        }
        
        if ($finalStatus.Failed -gt 0) {
            Write-Host "`n⚠️ $($finalStatus.Failed) issue(s) require manual intervention" -ForegroundColor Red
            Write-Host "   These issues exceeded the maximum fix attempts." -ForegroundColor Red
        }
        
        if ($finalStatus.Open -gt 0 -and $loopCount -ge $MaxLoops) {
            Write-Host "`n⚠️ Maximum loop iterations reached ($MaxLoops)" -ForegroundColor Yellow
            Write-Host "   $($finalStatus.Open) issue(s) remain open" -ForegroundColor Yellow
        }
    }
    
    Write-Host ("=" * 60) -ForegroundColor Green
    Write-Host ""
    
    # Clean up environment
    if ($NonInteractive) {
        $env:AITHERZERO_NONINTERACTIVE = $null
    }
    
    if ($PassThru) {
        return $finalStatus
    }
    
    # Exit code based on results
    if ($finalStatus.Failed -gt 0 -or ($finalStatus.Open -gt 0 -and $loopCount -ge $MaxLoops)) {
        exit 2  # Some issues remain unfixed
    }
    
    exit 0
}
catch {
    Write-ScriptLog -Level Error -Message "Test-fix loop failed: $_"
    
    # Clean up environment
    if ($NonInteractive) {
        $env:AITHERZERO_NONINTERACTIVE = $null
    }
    
    exit 1
}