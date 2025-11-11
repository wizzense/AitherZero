#Requires -Version 7.0

<#
.SYNOPSIS
    Demo script for new playbook helper functions

.DESCRIPTION
    Demonstrates the new PlaybookHelpers module that makes creating
    and validating playbooks much easier.

.PARAMETER Demo
    Which demo to run: Template, Validate, ScriptInfo, All

.EXAMPLE
    .\0969_Demo-PlaybookHelpers.ps1 -Demo Template
    Create a new playbook template

.EXAMPLE
    .\0969_Demo-PlaybookHelpers.ps1 -Demo Validate
    Validate an existing playbook

.NOTES
    Stage: Orchestration
    Dependencies: OrchestrationEngine, PlaybookHelpers
    Tags: orchestration, playbooks, demo, helpers
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Template', 'Validate', 'ScriptInfo', 'All')]
    [string]$Demo = 'All'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Get project root
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

# Import modules
Import-Module (Join-Path $projectRoot "AitherZero.psd1") -Force

Write-Host "`n" -NoNewline
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  PlaybookHelpers Demo" -ForegroundColor Cyan
Write-Host "  Making playbook creation EASY!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

function Show-TemplateDemo {
    Write-Host "📝 Demo 1: Create a Playbook Template" -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host ""
    
    Write-Host "Before: You had to manually create complex hashtable structures..." -ForegroundColor Gray
    Write-Host "Now: Just use New-PlaybookTemplate!" -ForegroundColor Green
    Write-Host ""
    
    # Create a test template
    $tempPath = Join-Path $projectRoot "library/playbooks/demo-template-test.psd1"
    
    Write-Host "Creating a testing playbook template..." -ForegroundColor Cyan
    Write-Host "  Command: New-PlaybookTemplate -Name 'demo-template-test' -Scripts @('0407', '0413') -Type Testing" -ForegroundColor DarkGray
    Write-Host ""
    
    $result = New-PlaybookTemplate -Name 'demo-template-test' -Scripts @('0407', '0413') -Type Testing -WhatIf:$false
    
    if (Test-Path $tempPath) {
        Write-Host "`n📄 Generated template:" -ForegroundColor Cyan
        Write-Host "━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Get-Content $tempPath | Select-Object -First 30 | ForEach-Object {
            Write-Host "   $_" -ForegroundColor White
        }
        Write-Host "   ..." -ForegroundColor DarkGray
        Write-Host ""
        
        # Clean up
        Remove-Item $tempPath -Force
        Write-Host "✓ Demo template cleaned up" -ForegroundColor Green
    }
    
    Write-Host ""
}

function Show-ValidateDemo {
    Write-Host "🔍 Demo 2: Validate a Playbook" -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host ""
    
    Write-Host "Before: Errors only appeared at runtime, often cryptic..." -ForegroundColor Gray
    Write-Host "Now: Pre-flight validation with detailed errors!" -ForegroundColor Green
    Write-Host ""
    
    # Test with a real playbook
    $playbookPath = Join-Path $projectRoot "library/playbooks/test-orchestration.psd1"
    
    Write-Host "Validating 'test-orchestration' playbook..." -ForegroundColor Cyan
    Write-Host "  Command: Test-PlaybookDefinition -Path '$playbookPath'" -ForegroundColor DarkGray
    Write-Host ""
    
    $result = Test-PlaybookDefinition -Path $playbookPath
    
    Write-Host ""
}

function Show-ScriptInfoDemo {
    Write-Host "📚 Demo 3: Get Playbook Script Info" -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host ""
    
    Write-Host "Before: You had to open the file to see what scripts it runs..." -ForegroundColor Gray
    Write-Host "Now: Get a formatted summary instantly!" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Getting script info for 'pr-validation-fast'..." -ForegroundColor Cyan
    Write-Host "  Command: Get-PlaybookScriptInfo -PlaybookName 'pr-validation-fast'" -ForegroundColor DarkGray
    
    Get-PlaybookScriptInfo -PlaybookName 'pr-validation-fast'
    
    Write-Host ""
}

# Run demos
if ($Demo -in @('Template', 'All')) {
    Show-TemplateDemo
}

if ($Demo -in @('Validate', 'All')) {
    Show-ValidateDemo
}

if ($Demo -in @('ScriptInfo', 'All')) {
    Show-ScriptInfoDemo
}

# Summary
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  Summary: PlaybookHelpers Benefits" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ Easy template generation - no more manual hashtables" -ForegroundColor Green
Write-Host "✅ Pre-flight validation - catch errors before running" -ForegroundColor Green
Write-Host "✅ Detailed error messages - know exactly what's wrong" -ForegroundColor Green
Write-Host "✅ Quick script info - understand playbooks at a glance" -ForegroundColor Green
Write-Host ""
Write-Host "💡 Next Steps:" -ForegroundColor Yellow
Write-Host "   • Try: New-PlaybookTemplate -Name 'my-test' -Scripts @('0407') -Type Testing" -ForegroundColor White
Write-Host "   • Try: Test-PlaybookDefinition -Path './library/playbooks/my-test.psd1'" -ForegroundColor White
Write-Host "   • Try: Get-PlaybookScriptInfo -PlaybookName 'my-test'" -ForegroundColor White
Write-Host ""

exit 0
