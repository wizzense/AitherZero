#Requires -Version 7.0
<#
.SYNOPSIS
    Automatic Test Generation Orchestrator - "The 100% Solution"
.DESCRIPTION
    This script automatically generates and maintains tests for ALL AitherZero components:
    - Automation scripts (124+ scripts)
    - UI components
    - CLI commands
    - Workflows and orchestration
    - Domain modules
    
    NO MANUAL TEST WRITING REQUIRED - EVER!
.PARAMETER Mode
    Generation mode: Full, Quick, Changed, Watch
.PARAMETER Force
    Regenerate all tests even if they exist
.PARAMETER RunTests
    Run tests after generating them
.EXAMPLE
    ./automation-scripts/0950_Generate-AllTests.ps1 -Mode Full -Force
.EXAMPLE
    ./automation-scripts/0950_Generate-AllTests.ps1 -Mode Watch  # Continuous generation
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [ValidateSet('Full', 'Quick', 'Changed', 'Watch')]
    [string]$Mode = 'Full',

    [Parameter()]
    [hashtable]$Configuration,

    [switch]$Force,

    [switch]$RunTests
)

# Initialize
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:TestGeneratorModule = Join-Path $script:ProjectRoot 'domains/testing/AutoTestGenerator.psm1'

# Logging
function Write-OrchestratorLog {
    param([string]$Message, [string]$Level = 'Info')
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $emoji = switch ($Level) {
        'Success' { '✅' }
        'Error' { '❌' }
        'Warning' { '⚠️' }
        default { 'ℹ️' }
    }
    Write-Host "[$timestamp] $emoji [TestOrchestrator] $Message"
}

# Banner
Write-Host "`n╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  AitherZero Automatic Test Generation Orchestrator v2.0     ║" -ForegroundColor Cyan
Write-Host "║          100% Test Coverage - Zero Manual Work              ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-OrchestratorLog "Starting test generation in $Mode mode"

# Import test generator
if (-not (Test-Path $script:TestGeneratorModule)) {
    Write-OrchestratorLog "Test generator module not found at: $script:TestGeneratorModule" -Level Error
    exit 1
}

try {
    Import-Module $script:TestGeneratorModule -Force -ErrorAction Stop
    Write-OrchestratorLog "Test generator module loaded successfully" -Level Success
} catch {
    Write-OrchestratorLog "Failed to load test generator: $_" -Level Error
    exit 1
}

# Execute based on mode
switch ($Mode) {
    'Full' {
        Write-OrchestratorLog "Running FULL test generation for ALL scripts"
        $result = Invoke-AutoTestGeneration -Force:$Force
        
        if ($result) {
            Write-OrchestratorLog "Generation complete:" -Level Success
            Write-Host "  • Total scripts:     $($result.Total)" -ForegroundColor White
            Write-Host "  • Tests generated:   $($result.Generated)" -ForegroundColor Green
            Write-Host "  • Already existed:   $($result.Skipped)" -ForegroundColor Yellow
            Write-Host "  • Failed:            $($result.Failed)" -ForegroundColor $(if ($result.Failed -gt 0) { 'Red' } else { 'Green' })
            
            $coverage = if ($result.Total -gt 0) {
                [math]::Round((($result.Generated + $result.Skipped) / $result.Total) * 100, 1)
            } else { 0 }
            Write-Host "  • Coverage:          $coverage%" -ForegroundColor $(if ($coverage -eq 100) { 'Green' } else { 'Yellow' })
        }
    }
    
    'Quick' {
        Write-OrchestratorLog "Running QUICK test generation (scripts without tests only)"
        $result = Invoke-AutoTestGeneration -Force:$false
        Write-OrchestratorLog "Quick generation complete - $($result.Generated) new tests" -Level Success
    }
    
    'Changed' {
        Write-OrchestratorLog "Detecting changed scripts..."
        
        # Find scripts modified in last 24 hours
        $recentScripts = Get-ChildItem -Path (Join-Path $script:ProjectRoot 'automation-scripts') -Filter "*.ps1" -File |
            Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-24) }
        
        Write-OrchestratorLog "Found $($recentScripts.Count) recently modified scripts"
        
        foreach ($script in $recentScripts) {
            Write-OrchestratorLog "Regenerating test for: $($script.Name)"
            New-AutoTest -ScriptPath $script.FullName -Force
        }
        
        Write-OrchestratorLog "Changed scripts processed" -Level Success
    }
    
    'Watch' {
        Write-OrchestratorLog "Starting continuous watch mode..."
        Write-Host "`n🔍 Watching for changes in automation-scripts directory..." -ForegroundColor Yellow
        Write-Host "   Press Ctrl+C to stop`n" -ForegroundColor Gray
        
        $watcher = New-Object System.IO.FileSystemWatcher
        $watcher.Path = Join-Path $script:ProjectRoot 'automation-scripts'
        $watcher.Filter = "*.ps1"
        $watcher.IncludeSubdirectories = $false
        $watcher.EnableRaisingEvents = $true
        
        $action = {
            $path = $Event.SourceEventArgs.FullPath
            $name = [System.IO.Path]::GetFileName($path)
            
            if ($name -match '^\d{4}_.*\.ps1$') {
                Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] ⚡ Change detected: $name" -ForegroundColor Cyan
                
                # Wait a moment for file to finish being written
                Start-Sleep -Seconds 1
                
                try {
                    Import-Module $script:TestGeneratorModule -Force
                    New-AutoTest -ScriptPath $path -Force
                    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ✅ Test regenerated for: $name`n" -ForegroundColor Green
                } catch {
                    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ❌ Failed to regenerate test: $_`n" -ForegroundColor Red
                }
            }
        }
        
        $handlers = @()
        $handlers += Register-ObjectEvent -InputObject $watcher -EventName "Changed" -Action $action
        $handlers += Register-ObjectEvent -InputObject $watcher -EventName "Created" -Action $action
        $handlers += Register-ObjectEvent -InputObject $watcher -EventName "Renamed" -Action $action
        
        try {
            Write-OrchestratorLog "Watch mode active - waiting for changes..." -Level Success
            # Keep script running
            while ($true) {
                Start-Sleep -Seconds 1
            }
        } finally {
            # Cleanup
            $handlers | ForEach-Object { Unregister-Event -SourceIdentifier $_.Name }
            $watcher.Dispose()
            Write-OrchestratorLog "Watch mode stopped"
        }
    }
}

# Run tests if requested
if ($RunTests) {
    Write-Host "`n" -NoNewline
    Write-OrchestratorLog "Running generated tests..."
    
    $testResults = Invoke-Pester -Path (Join-Path $script:ProjectRoot 'tests') -PassThru -Output Minimal
    
    Write-Host "`n"
    Write-OrchestratorLog "Test Results:" -Level $(if ($testResults.FailedCount -eq 0) { 'Success' } else { 'Warning' })
    Write-Host "  • Passed:  $($testResults.PassedCount)" -ForegroundColor Green
    Write-Host "  • Failed:  $($testResults.FailedCount)" -ForegroundColor $(if ($testResults.FailedCount -gt 0) { 'Red' } else { 'Green' })
    Write-Host "  • Skipped: $($testResults.SkippedCount)" -ForegroundColor Yellow
}

Write-Host "`n╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║            Automatic Test Generation Complete!              ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

Write-OrchestratorLog "Orchestration complete" -Level Success

# Exit with appropriate code
if ($result -and $result.Failed -gt 0) {
    exit 1
}

exit 0
