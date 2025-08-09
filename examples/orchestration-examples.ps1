#Requires -Version 7.0
# Example orchestration sequences for AitherZero

# Import the orchestration engine
Import-Module ../domains/automation/OrchestrationEngine.psm1 -Force

# Example 1: Basic setup sequence
Write-Host "`n=== Example 1: Basic Setup ===" -ForegroundColor Cyan
seq 0000-0002,0001,0207 -DryRun

# Example 2: Development environment
Write-Host "`n=== Example 2: Development Environment ===" -ForegroundColor Cyan
seq stage:Prepare,stage:Core,0201,0207,0210 -DryRun

# Example 3: Infrastructure deployment
Write-Host "`n=== Example 3: Infrastructure Deployment ===" -ForegroundColor Cyan
$infraConfig = @{
    Environment = "Lab"
    Features = @("HyperV", "OpenTofu")
}
Invoke-OrchestrationSequence -Sequence "0000-0099,0105,0008,0300" -Variables $infraConfig -DryRun

# Example 4: Conditional execution
Write-Host "`n=== Example 4: Conditional Execution ===" -ForegroundColor Cyan
$conditions = @{
    Environment = "Production"
    Features = @("Docker", "Kubernetes")
    SkipTests = $false
}
seq 0000-0299 -Conditions $conditions -DryRun

# Example 5: Save and load playbook
Write-Host "`n=== Example 5: Playbook Management ===" -ForegroundColor Cyan
# Save a custom sequence
seq 0001,0207,0201,0105,0008 -SavePlaybook "my-custom-setup" -DryRun

# Load and execute
seq -LoadPlaybook "my-custom-setup" -DryRun

# Example 6: Complex orchestration with error handling
Write-Host "`n=== Example 6: Complex Orchestration ===" -ForegroundColor Cyan
$result = Invoke-OrchestrationSequence -Sequence @(
    "stage:Prepare",
    "0207",  # Git
    "0201",  # Node
    "!0208", # Exclude Docker
    "stage:Infrastructure",
    "0500"   # Validation
) -MaxConcurrency 2 -ContinueOnError -DryRun

# Example 7: Non-interactive CI/CD usage
Write-Host "`n=== Example 7: CI/CD Pipeline ===" -ForegroundColor Cyan
@'
# Azure DevOps Pipeline
- task: PowerShell@2
  inputs:
    targetType: 'inline'
    script: |
      # Setup environment
      $env:AITHERZERO_PROFILE = "Production"
      $env:AITHERZERO_SEQUENCE = "0000-0299,0300,0500"
      
      # Import and run
      Import-Module ./domains/automation/OrchestrationEngine.psm1
      $result = seq $env:AITHERZERO_SEQUENCE -Profile $env:AITHERZERO_PROFILE
      
      # Check results
      if ($result.Failed -gt 0) {
          throw "Deployment failed: $($result.Failed) scripts failed"
      }
'@ | Write-Host -ForegroundColor DarkGray

# Example 8: Dynamic sequence based on system
Write-Host "`n=== Example 8: Dynamic Sequence ===" -ForegroundColor Cyan
$dynamicSequence = @("0000-0099")  # Always prep

if ($IsWindows) {
    Write-Host "Windows detected - adding Hyper-V" -ForegroundColor Yellow
    $dynamicSequence += "0105"
}

if ($IsMacOS) {
    Write-Host "macOS detected - adding Homebrew tools" -ForegroundColor Yellow
    $dynamicSequence += "tag:homebrew"
}

if (Test-Path "../infrastructure") {
    Write-Host "Infrastructure directory found - adding deployment" -ForegroundColor Yellow
    $dynamicSequence += "0300"
}

seq $dynamicSequence -DryRun

# Example 9: Parallel vs Sequential
Write-Host "`n=== Example 9: Execution Modes ===" -ForegroundColor Cyan
Write-Host "Parallel execution (default):" -ForegroundColor Yellow
seq 0201,0207,0208 -Parallel $true -MaxConcurrency 3 -DryRun

Write-Host "`nSequential execution:" -ForegroundColor Yellow
seq 0201,0207,0208 -Parallel $false -DryRun

# Example 10: Using wildcards and exclusions
Write-Host "`n=== Example 10: Wildcards and Exclusions ===" -ForegroundColor Cyan
Write-Host "All 0200 series except Docker:" -ForegroundColor Yellow
seq 02*,!0208 -DryRun

Write-Host "`nAll infrastructure except system config:" -ForegroundColor Yellow
seq 01*,!0100 -DryRun

# Show available playbooks
Write-Host "`n=== Available Playbooks ===" -ForegroundColor Cyan
Get-ChildItem ../orchestration/playbooks/*.json | ForEach-Object {
    $playbook = Get-Content $_.FullName | ConvertFrom-Json
    Write-Host "- $($playbook.Name): $($playbook.Description)" -ForegroundColor Green
}