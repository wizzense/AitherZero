#Requires -Version 7.0
<#
.SYNOPSIS
    Update orchestration index with auto-discovered automation scripts
.DESCRIPTION
    Automatically maintains orchestration playbooks based on discovered automation scripts.
    Creates smart playbooks that group related scripts by functionality.
.PARAMETER GeneratePlaybooks
    Generate new playbooks based on script discovery
.PARAMETER UpdateIndex
    Update the orchestration index file
.EXAMPLE
    ./Update-OrchestrationIndex.ps1 -GeneratePlaybooks -UpdateIndex
#>

param(
    [switch]$GeneratePlaybooks,
    [switch]$UpdateIndex
)

$ErrorActionPreference = 'Stop'
$rootPath = $PSScriptRoot

Write-Host "🔄 Updating Orchestration Index..." -ForegroundColor Green

# Load the latest auto-discovery report
$reportsPath = Join-Path $rootPath "tests/reports"
$latestReport = Get-ChildItem -Path $reportsPath -Filter "AutoDiscovery-*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $latestReport) {
    Write-Warning "No auto-discovery report found. Run ./Test-AllSystems.ps1 -Mode Orchestration first."
    exit 1
}

$discoveryData = Get-Content -Path $latestReport.FullName | ConvertFrom-Json
Write-Host "📊 Loaded discovery data: $($discoveryData.TotalScripts) scripts in $($discoveryData.Categories.PSObject.Properties.Count) categories" -ForegroundColor Cyan

if ($GeneratePlaybooks) {
    Write-Host "`n🔨 Generating Smart Playbooks..." -ForegroundColor Yellow
    
    # Generate environment setup playbook
    $setupScripts = $discoveryData.Categories.'0000-0099'.Scripts | Sort-Object { [int]$_.Number }
    if ($setupScripts.Count -gt 0) {
        $setupPlaybook = @{
            name = "Environment Setup - Complete"
            description = "Complete environment setup and preparation"
            version = "1.0.0"
            category = "setup"
            tags = @("environment", "setup", "preparation")
            variables = @{
                SkipOptional = $false
                ForceReinstall = $false
                ValidateAfterInstall = $true
            }
            workflow = @{
                steps = @()
            }
        }
        
        foreach ($script in $setupScripts | Select-Object -First 10) {
            $setupPlaybook.workflow.steps += @{
                id = "step_$($script.Number)"
                name = $script.Name -replace '^\d{4}_', ''
                script = $script.Number
                description = "Execute $($script.Name)"
                continueOnError = $false
                timeout = 300
            }
        }
        
        $playbookPath = Join-Path $rootPath "orchestration/setup/environment-complete.json"
        $setupPlaybook | ConvertTo-Json -Depth 5 | Out-File -Path $playbookPath -Encoding UTF8
        Write-Host "✅ Generated: environment-complete.json" -ForegroundColor Green
    }
    
    # Generate testing playbook
    $testScripts = $discoveryData.Categories.'0400-0499'.Scripts | Sort-Object { [int]$_.Number }
    if ($testScripts.Count -gt 0) {
        $testPlaybook = @{
            name = "Comprehensive Testing Suite"
            description = "Run all validation and testing scripts"
            version = "1.0.0"
            category = "testing"
            tags = @("testing", "validation", "quality")
            variables = @{
                CoverageTarget = 80
                FailFast = $false
                GenerateReports = $true
            }
            workflow = @{
                steps = @()
            }
        }
        
        foreach ($script in $testScripts | Select-Object -First 8) {
            $testPlaybook.workflow.steps += @{
                id = "test_$($script.Number)"
                name = $script.Name -replace '^\d{4}_', ''
                script = $script.Number
                description = "Execute $($script.Name)"
                continueOnError = $true
                timeout = 600
            }
        }
        
        $playbookPath = Join-Path $rootPath "orchestration/testing/comprehensive-testing.json"
        $testPlaybook | ConvertTo-Json -Depth 5 | Out-File -Path $playbookPath -Encoding UTF8
        Write-Host "✅ Generated: comprehensive-testing.json" -ForegroundColor Green
    }
    
    # Generate development workflow playbook
    $devScripts = @()
    $devScripts += $discoveryData.Categories.'0200-0299'.Scripts | Where-Object { $_.Name -match 'Git|Node|Python|Docker' } | Select-Object -First 5
    $devScripts += $discoveryData.Categories.'0700-0799'.Scripts | Where-Object { $_.Name -match 'Git|AI|Claude' } | Select-Object -First 5
    
    if ($devScripts.Count -gt 0) {
        $devPlaybook = @{
            name = "Development Environment Setup"
            description = "Setup complete development environment with tools and AI integration"
            version = "1.0.0"
            category = "development"
            tags = @("development", "tools", "ai", "git")
            variables = @{
                InstallOptional = $true
                ConfigureAI = $true
                SetupGitHooks = $true
            }
            workflow = @{
                steps = @()
            }
        }
        
        foreach ($script in $devScripts) {
            $devPlaybook.workflow.steps += @{
                id = "dev_$($script.Number)"
                name = $script.Name -replace '^\d{4}_', ''
                script = $script.Number
                description = "Execute $($script.Name)"
                continueOnError = $false
                timeout = 300
            }
        }
        
        $playbookPath = Join-Path $rootPath "orchestration/development/development-complete.json"
        $devPlaybook | ConvertTo-Json -Depth 5 | Out-File -Path $playbookPath -Encoding UTF8
        Write-Host "✅ Generated: development-complete.json" -ForegroundColor Green
    }
}

if ($UpdateIndex) {
    Write-Host "`n📋 Updating Orchestration Index..." -ForegroundColor Yellow
    
    $orchestrationPath = Join-Path $rootPath "orchestration"
    $indexData = @{
        lastUpdated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        totalScripts = $discoveryData.TotalScripts
        categories = @{}
        playbooks = @{}
    }
    
    # Index script categories
    foreach ($categoryProp in $discoveryData.Categories.PSObject.Properties) {
        $category = $categoryProp.Value
        $indexData.categories[$categoryProp.Name] = @{
            name = $category.Name
            scriptCount = $category.Scripts.Count
            scripts = @($category.Scripts | ForEach-Object { 
                @{
                    number = $_.Number
                    name = $_.Name
                    description = if ($_.Description) { $_.Description } else { "Automation script" }
                }
            })
        }
    }
    
    # Index available playbooks
    $categories = @('setup', 'testing', 'development', 'deployment')
    foreach ($cat in $categories) {
        $catPath = Join-Path $orchestrationPath $cat
        if (Test-Path $catPath) {
            $playbooks = Get-ChildItem -Path $catPath -Filter "*.json"
            $indexData.playbooks[$cat] = @($playbooks | ForEach-Object {
                try {
                    $content = Get-Content -Path $_.FullName | ConvertFrom-Json
                    @{
                        file = $_.Name
                        name = $content.name
                        description = $content.description
                        version = $content.version
                        tags = $content.tags
                        stepCount = if ($content.workflow.steps) { $content.workflow.steps.Count } else { 0 }
                    }
                }
                catch {
                    @{
                        file = $_.Name
                        name = $_.BaseName
                        description = "Playbook file"
                        version = "unknown"
                        tags = @()
                        stepCount = 0
                    }
                }
            })
        }
    }
    
    # Save index
    $indexPath = Join-Path $orchestrationPath "orchestration-index.json"
    $indexData | ConvertTo-Json -Depth 6 | Out-File -Path $indexPath -Encoding UTF8
    Write-Host "📄 Orchestration index saved: $indexPath" -ForegroundColor Green
    
    # Generate human-readable summary
    $summaryPath = Join-Path $orchestrationPath "README.md"
    $readme = @"
# AitherZero Orchestration System

*Auto-generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')*

## Overview

The AitherZero orchestration system provides automated workflow execution using a collection of $($discoveryData.TotalScripts) automation scripts organized into logical categories.

## Script Categories

"@

    foreach ($categoryProp in $discoveryData.Categories.PSObject.Properties) {
        $category = $categoryProp.Value
        $readme += @"

### $($categoryProp.Name): $($category.Name)
**Scripts:** $($category.Scripts.Count)

"@
        foreach ($script in ($category.Scripts | Select-Object -First 5)) {
            $readme += "- `$($script.Number)` - $($script.Name -replace '^\d{4}_', '')`n"
        }
        if ($category.Scripts.Count -gt 5) {
            $readme += "- ... and $($category.Scripts.Count - 5) more scripts`n"
        }
    }
    
    $readme += @"

## Available Playbooks

"@
    
    foreach ($cat in $categories) {
        if ($indexData.playbooks.$cat -and $indexData.playbooks.$cat.Count -gt 0) {
            $readme += @"

### $($cat.ToUpper()) ($($indexData.playbooks.$cat.Count) playbooks)

"@
            foreach ($playbook in $indexData.playbooks.$cat) {
                $readme += "- **$($playbook.name)** - $($playbook.description)`n"
            }
        }
    }
    
    $readme += @"

## Usage

```powershell
# Run a specific playbook
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook setup/environment-complete

# List available playbooks
./Start-AitherZero.ps1 -Mode CLI help

# Update orchestration index
./Update-OrchestrationIndex.ps1 -UpdateIndex -GeneratePlaybooks
```

## Auto-Discovery

This orchestration system automatically discovers and catalogs automation scripts. The index is updated each time you run system validation or orchestration cleanup.

**Last Updated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
**Total Scripts Discovered:** $($discoveryData.TotalScripts)

"@
    
    $readme | Out-File -Path $summaryPath -Encoding UTF8
    Write-Host "📖 Updated orchestration README: $summaryPath" -ForegroundColor Green
}

Write-Host "`n✅ Orchestration Index Update Complete!" -ForegroundColor Green