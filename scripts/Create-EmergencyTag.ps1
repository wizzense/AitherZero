#!/usr/bin/env pwsh
# Emergency tag creation script
# When automated tagging fails, this provides a bulletproof manual fallback

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$TagVersion,
    
    [Parameter(Mandatory)]
    [string]$TagMessage,
    
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Creating emergency tag: v$TagVersion" -ForegroundColor Green
    Write-Host "Message: $TagMessage" -ForegroundColor Yellow
    Write-Host ""
    
    # Ensure we're on main and up-to-date
    Write-Host "Syncing with remote..." -ForegroundColor Cyan
    git fetch origin main
    git checkout main
    git reset --hard origin/main
    
    # Create and push the tag
    Write-Host "Creating tag..." -ForegroundColor Cyan
    git tag -a "v$TagVersion" -m "$TagMessage"
    
    Write-Host "Pushing tag..." -ForegroundColor Cyan
    git push origin "v$TagVersion"
    
    Write-Host ""
    Write-Host "✅ Emergency tag v$TagVersion created and pushed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Monitoring build pipeline..." -ForegroundColor Cyan
    
    # Wait a moment then check workflow
    Start-Sleep -Seconds 5
    
    $workflows = gh run list --workflow="Build & Release Pipeline" --limit 1 --json status,conclusion,workflowName,createdAt,htmlUrl
    if ($workflows) {
        $workflow = $workflows | ConvertFrom-Json | Select-Object -First 1
        Write-Host "Latest workflow: $($workflow.status)" -ForegroundColor Cyan
        Write-Host "URL: $($workflow.htmlUrl)" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "🚀 Build pipeline should now be running with the fixed launcher!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Error creating emergency tag:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}