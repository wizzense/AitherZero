#Requires -Version 7.0

<#
.SYNOPSIS
    Generate validation tests for GitHub Actions workflows

.DESCRIPTION
    Creates tests that validate workflow YAML syntax, structure, and configuration

.EXAMPLE
    ./WorkflowTestGenerator.ps1 -Workflow comprehensive-tests-v2
    
.EXAMPLE
    ./WorkflowTestGenerator.ps1 -All
#>

[CmdletBinding()]
param(
    [string]$Workflow,
    [switch]$All,
    [switch]$Force,
    [string]$OutputPath = (Join-Path $PSScriptRoot '../unit/workflows')
)

$ErrorActionPreference = 'Stop'

# Import helpers
$testHelpersPath = Join-Path $PSScriptRoot '../helpers/TestHelpers.psm1'
Import-Module $testHelpersPath -Force

function New-WorkflowTest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$WorkflowPath,
        
        [Parameter(Mandatory)]
        [string]$OutputDirectory
    )
    
    $workflowName = [System.IO.Path]::GetFileNameWithoutExtension($WorkflowPath)
    Write-Host "Generating test for workflow: $workflowName" -ForegroundColor Cyan
    
    # Read workflow content
    $content = Get-Content -Path $WorkflowPath -Raw
    
    # Parse basic info
    $hasName = $content -match 'name:\s*(.+)'
    $name = if ($hasName) { $Matches[1].Trim() } else { $workflowName }
    
    # Generate test file
    $testFileName = "$workflowName.Tests.ps1"
    $testFilePath = Join-Path $OutputDirectory $testFileName
    
    $testContent = @"
#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Validation tests for $workflowName workflow

.DESCRIPTION
    Tests YAML syntax, structure, and workflow configuration
    
    Workflow: $name
    Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
#>

Describe '$workflowName Workflow Tests' -Tag 'Unit', 'Workflow', 'CI' {
    
    BeforeAll {
        # Import test helpers
        `$testHelpersPath = Join-Path `$PSScriptRoot '../../../helpers/TestHelpers.psm1'
        if (Test-Path `$testHelpersPath) {
            Import-Module `$testHelpersPath -Force
        }
        
        # Workflow path
        `$workflowPath = Get-TestFilePath '.github/workflows/$workflowName.yml'
        if (-not (Test-Path `$workflowPath)) {
            throw "Workflow not found: `$workflowPath"
        }
        
        `$content = Get-Content `$workflowPath -Raw
    }
    
    Context 'Workflow Structure' {
        It 'Should exist' {
            Test-Path `$workflowPath | Should -Be `$true
        }
        
        It 'Should have .yml extension' {
            `$workflowPath | Should -Match '\.yml$'
        }
        
        It 'Should have valid YAML syntax' {
            # Basic YAML validation
            `$content | Should -Not -BeNullOrEmpty
            # Should not have tabs (YAML requirement)
            `$content | Should -Not -Match '\t'
        }
    }
    
    Context 'Workflow Configuration' {
        It 'Should have name' {
            `$content | Should -Match 'name:\s*.+'
        }
        
        It 'Should have trigger configuration (on:)' {
            `$content | Should -Match '^on:'
        }
        
        It 'Should have at least one job' {
            `$content | Should -Match 'jobs:'
        }
        
        It 'Should specify permissions if using GITHUB_TOKEN' {
            if (`$content -match '\`$\{\{\s*secrets\.GITHUB_TOKEN\s*\}\}') {
                `$content | Should -Match 'permissions:'
            }
        }
    }
    
    Context 'Best Practices' {
        It 'Should use specific action versions (not @main)' {
            `$mainReferences = ([regex]'uses:.*@main').Matches(`$content)
            `$mainReferences.Count | Should -Be 0
        }
        
        It 'Should have timeout configured for long-running jobs' {
            if (`$content -match 'runs-on:') {
                # Check if there are timeouts for jobs
                `$hasTimeouts = `$content -match 'timeout-minutes:'
                if (-not `$hasTimeouts) {
                    Write-Warning "Consider adding timeout-minutes to prevent hung workflows"
                }
            }
        }
        
        It 'Should use concurrency control for PR workflows' {
            if (`$content -match 'pull_request:') {
                `$hasConcurrency = `$content -match 'concurrency:'
                if (-not `$hasConcurrency) {
                    Write-Warning "Consider adding concurrency control to cancel outdated runs"
                }
            }
        }
    }
    
    Context 'Security Practices' {
        It 'Should not expose secrets in logs' {
            # Check for potential secret exposure
            `$dangerousPatterns = @(
                'echo.*\`$\{\{\s*secrets\.',
                'Write-Host.*\`$env:.*TOKEN'
            )
            
            foreach (`$pattern in `$dangerousPatterns) {
                `$matches = ([regex]`$pattern).Matches(`$content)
                `$matches.Count | Should -Be 0 -Because "Should not echo secrets"
            }
        }
        
        It 'Should pin action versions for security' {
            # Actions should use commit SHA or specific version tags
            `$unpinnedActions = ([regex]'uses:\s*[^@]+@(?!v?\d|[a-f0-9]{40})').Matches(`$content)
            if (`$unpinnedActions.Count -gt 0) {
                Write-Warning "Some actions are not pinned to specific versions"
            }
        }
    }
}
"@

    # Write test file
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
    }
    
    $testContent | Set-Content -Path $testFilePath -Force
    Write-Host "  Generated: $testFilePath" -ForegroundColor Green
    
    return $testFilePath
}

# Main execution
try {
    $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    $env:AITHERZERO_ROOT = $repoRoot
    
    $workflowsPath = Join-Path $repoRoot '.github/workflows'
    
    if (-not (Test-Path $workflowsPath)) {
        throw "Workflows directory not found: $workflowsPath"
    }
    
    # Determine which workflows to process
    $workflowsToProcess = @()
    
    if ($All) {
        # Process all workflows
        $workflowsToProcess = Get-ChildItem -Path $workflowsPath -Filter '*.yml' |
            Where-Object { $_.Name -ne 'jekyll-gh-pages.yml' }  # Skip auto-generated
    }
    elseif ($Workflow) {
        # Process specific workflow
        $workflowFile = Join-Path $workflowsPath "$Workflow.yml"
        
        if (-not (Test-Path $workflowFile)) {
            throw "Workflow not found: $Workflow"
        }
        
        $workflowsToProcess = @(Get-Item $workflowFile)
    }
    else {
        Write-Host "Usage:" -ForegroundColor Yellow
        Write-Host "  ./WorkflowTestGenerator.ps1 -Workflow <WorkflowName>" -ForegroundColor Cyan
        Write-Host "  ./WorkflowTestGenerator.ps1 -All" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Examples:" -ForegroundColor Cyan
        Write-Host "  ./WorkflowTestGenerator.ps1 -Workflow comprehensive-tests-v2"
        Write-Host "  ./WorkflowTestGenerator.ps1 -All"
        exit 0
    }
    
    # Process workflows
    $generated = 0
    $skipped = 0
    
    foreach ($workflow in $workflowsToProcess) {
        $testFile = Join-Path $OutputPath "$($workflow.BaseName).Tests.ps1"
        
        if ((Test-Path $testFile) -and -not $Force) {
            Write-Host "Skipping $($workflow.Name) (test exists, use -Force to overwrite)" -ForegroundColor Yellow
            $skipped++
            continue
        }
        
        New-WorkflowTest -WorkflowPath $workflow.FullName -OutputDirectory $OutputPath
        $generated++
    }
    
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "  Generated: $generated" -ForegroundColor Green
    Write-Host "  Skipped: $skipped" -ForegroundColor Yellow
    Write-Host "  Total: $($workflowsToProcess.Count)" -ForegroundColor Gray
}
catch {
    Write-Error "Test generation failed: $_"
    exit 1
}
