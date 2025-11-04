#Requires -Version 7.0

<#
.SYNOPSIS
    Run orchestration playbooks - wrapper for easy local CI/CD workflow execution

.DESCRIPTION
    This script provides an easy way to run AitherZero orchestration playbooks that mirror
    GitHub Actions workflows. Run workflows locally before pushing to catch issues early.

.PARAMETER Playbook
    Name of the playbook to run. Tab completion available for all playbooks.
    
    Common playbooks:
    - ci-all-validations: Run all CI validation checks
    - ci-pr-validation: Quick PR validation (syntax, PSScriptAnalyzer)
    - ci-comprehensive-test: Run full test suite
    - ci-quality-validation: Quality checks on code
    - test-quick: Fast validation for development

.PARAMETER Profile
    Profile to use within the playbook (e.g., quick, standard, full, ci)

.PARAMETER DryRun
    Show what would be executed without actually running scripts

.PARAMETER List
    List all available playbooks with descriptions

.PARAMETER Variables
    Additional variables to pass to the playbook as a hashtable

.EXAMPLE
    .\0960_Run-Playbook.ps1 -List
    List all available playbooks

.EXAMPLE
    .\0960_Run-Playbook.ps1 -Playbook ci-all-validations -Profile quick
    Run quick validation checks before pushing code

.EXAMPLE
    .\0960_Run-Playbook.ps1 -Playbook ci-pr-validation -DryRun
    Preview what PR validation would do

.EXAMPLE
    .\0960_Run-Playbook.ps1 -Playbook ci-comprehensive-test -Profile unit-only
    Run only unit tests

.EXAMPLE
    .\0960_Run-Playbook.ps1 -Playbook test-quick
    Quick development validation

.NOTES
    Stage: Validation
    Dependencies: OrchestrationEngine
    Tags: orchestration, playbooks, ci, testing
    
    This script makes it easy to run the same workflows that GitHub Actions runs,
    but locally on your machine for faster iteration and debugging.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)]
    [string]$Playbook,

    [Parameter()]
    [string]$Profile,

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [switch]$List,

    [Parameter()]
    [hashtable]$Variables = @{}
)

# Script metadata
$script:StartTime = Get-Date
$script:ScriptPath = $PSScriptRoot
$script:ProjectRoot = Split-Path $script:ScriptPath -Parent

# Import required modules
$startAitherZeroPath = Join-Path $script:ProjectRoot "Start-AitherZero.ps1"
$orchestrationPath = Join-Path $script:ProjectRoot "orchestration/playbooks"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    Write-Host $Message -ForegroundColor $Color
}

function Get-AvailablePlaybooks {
    <#
    .SYNOPSIS
        Get all available playbooks with metadata
    #>
    $playbooks = @()
    
    # Find all playbook JSON files
    $playbookFiles = Get-ChildItem -Path $orchestrationPath -Filter "*.json" -Recurse -ErrorAction SilentlyContinue
    
    foreach ($file in $playbookFiles) {
        try {
            $content = Get-Content $file.FullName -Raw | ConvertFrom-Json
            
            $playbook = [PSCustomObject]@{
                Name = if ($content.metadata.name) { $content.metadata.name } else { $file.BaseName }
                Description = if ($content.metadata.description) { $content.metadata.description } else { "No description" }
                Category = if ($content.metadata.category) { $content.metadata.category } else { "general" }
                EstimatedDuration = if ($content.metadata.estimatedDuration) { $content.metadata.estimatedDuration } else { "N/A" }
                Workflow = if ($content.metadata.githubWorkflow) { $content.metadata.githubWorkflow } else { "N/A" }
                Path = $file.FullName
            }
            
            $playbooks += $playbook
        }
        catch {
            # Skip invalid playbooks
            continue
        }
    }
    
    return $playbooks | Sort-Object Category, Name
}

function Show-PlaybookList {
    <#
    .SYNOPSIS
        Display formatted list of available playbooks
    #>
    $playbooks = Get-AvailablePlaybooks
    
    if ($playbooks.Count -eq 0) {
        Write-ColorOutput "No playbooks found in $orchestrationPath" -Color Red
        return
    }
    
    Write-ColorOutput "`n=== Available Playbooks ===" -Color Cyan
    Write-ColorOutput ""
    
    $categories = $playbooks | Group-Object -Property Category
    
    foreach ($category in $categories) {
        Write-ColorOutput "[$($category.Name.ToUpper())]" -Color Yellow
        Write-ColorOutput ""
        
        foreach ($playbook in $category.Group) {
            Write-ColorOutput "  $($playbook.Name)" -Color Green
            Write-ColorOutput "    $($playbook.Description)" -Color Gray
            
            if ($playbook.Workflow -ne "N/A") {
                Write-ColorOutput "    Mirrors: $($playbook.Workflow)" -Color DarkGray
            }
            
            Write-ColorOutput "    Duration: $($playbook.EstimatedDuration)" -Color DarkGray
            Write-ColorOutput ""
        }
    }
    
    Write-ColorOutput "Usage Examples:" -Color Cyan
    Write-ColorOutput "  .\0960_Run-Playbook.ps1 -Playbook ci-all-validations -Profile quick" -Color White
    Write-ColorOutput "  .\0960_Run-Playbook.ps1 -Playbook ci-pr-validation -DryRun" -Color White
    Write-ColorOutput "  .\0960_Run-Playbook.ps1 -Playbook test-quick" -Color White
    Write-ColorOutput ""
}

# Main execution
try {
    # Handle -List parameter
    if ($List) {
        Show-PlaybookList
        exit 0
    }
    
    # Validate playbook parameter
    if (-not $Playbook) {
        Write-ColorOutput "ERROR: Playbook parameter is required" -Color Red
        Write-ColorOutput ""
        Write-ColorOutput "Run with -List to see available playbooks:" -Color Yellow
        Write-ColorOutput "  .\0960_Run-Playbook.ps1 -List" -Color White
        Write-ColorOutput ""
        exit 1
    }
    
    # Build parameters for Start-AitherZero.ps1
    $params = @{
        Mode = 'Orchestrate'
        Playbook = $Playbook
        NonInteractive = $true
    }
    
    if ($Profile) {
        $params['PlaybookProfile'] = $Profile
    }
    
    if ($DryRun) {
        $params['DryRun'] = $true
    }
    
    if ($Variables.Count -gt 0) {
        $params['Variables'] = $Variables
    }
    
    # Display execution info
    Write-ColorOutput "`n=== AitherZero Playbook Execution ===" -Color Cyan
    Write-ColorOutput "Playbook: $Playbook" -Color White
    
    if ($Profile) {
        Write-ColorOutput "Profile: $Profile" -Color White
    }
    
    if ($DryRun) {
        Write-ColorOutput "Mode: DRY RUN (no scripts will be executed)" -Color Yellow
    }
    
    Write-ColorOutput "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Color Gray
    Write-ColorOutput ""
    
    # Check if we should proceed with execution
    $target = "playbook '$Playbook'"
    if ($Profile) {
        $target += " with profile '$Profile'"
    }
    
    if ($PSCmdlet.ShouldProcess($target, "Execute orchestration playbook")) {
        # Execute playbook
        & $startAitherZeroPath @params
        $exitCode = $LASTEXITCODE
    }
    else {
        # WhatIf mode - just show what would be executed
        Write-ColorOutput "What if: Would execute playbook '$Playbook'" -Color Yellow
        if ($Profile) {
            Write-ColorOutput "What if: Would use profile '$Profile'" -Color Yellow
        }
        $exitCode = 0
    }
    
    # Display completion info
    $duration = (Get-Date) - $script:StartTime
    Write-ColorOutput ""
    Write-ColorOutput "=== Execution Complete ===" -Color Cyan
    Write-ColorOutput "Duration: $($duration.ToString('mm\:ss'))" -Color Gray
    
    if ($exitCode -eq 0) {
        Write-ColorOutput "Status: SUCCESS" -Color Green
    }
    else {
        Write-ColorOutput "Status: FAILED (Exit Code: $exitCode)" -Color Red
    }
    
    Write-ColorOutput ""
    
    exit $exitCode
}
catch {
    Write-ColorOutput "ERROR: $($_.Exception.Message)" -Color Red
    Write-ColorOutput ""
    Write-ColorOutput "Stack trace:" -Color DarkGray
    Write-ColorOutput $_.ScriptStackTrace -Color DarkGray
    exit 1
}
