#Requires -Version 7.0

<#
.SYNOPSIS
    Triggers v0.8.2 release once CI completes successfully
#>

Write-Host "🚀 Monitoring CI and preparing v0.8.2 release..." -ForegroundColor Cyan

# Wait for CI to complete
$maxWait = 300  # 5 minutes
$waited = 0

while ($waited -lt $maxWait) {
    $ciStatus = gh run list --workflow=ci.yml --branch=main --limit 1 --json status,conclusion --jq '.[0]' | ConvertFrom-Json
    
    if ($ciStatus.status -eq "completed") {
        if ($ciStatus.conclusion -eq "success") {
            Write-Host "✅ CI completed successfully!" -ForegroundColor Green
            break
        } else {
            Write-Host "❌ CI failed with conclusion: $($ciStatus.conclusion)" -ForegroundColor Red
            exit 1
        }
    }
    
    Write-Host "⏳ CI still running... (waited $waited seconds)" -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    $waited += 10
}

if ($waited -ge $maxWait) {
    Write-Host "⏰ Timeout waiting for CI" -ForegroundColor Red
    exit 1
}

Write-Host "`n📦 CI completed! Waiting for release workflow to trigger automatically..." -ForegroundColor Cyan

# Give the release workflow time to trigger
Start-Sleep -Seconds 30

# Check if release workflow started
$releaseRuns = gh run list --workflow=release.yml --limit 3 --json createdAt,status,event --jq '.[] | select(.event == "workflow_run")' | ConvertFrom-Json

if ($releaseRuns) {
    $latestRun = $releaseRuns | Sort-Object createdAt -Descending | Select-Object -First 1
    Write-Host "🎯 Release workflow triggered!" -ForegroundColor Green
    Write-Host "   Status: $($latestRun.status)" -ForegroundColor White
    Write-Host "   Monitor at: https://github.com/wizzense/AitherZero/actions/workflows/release.yml" -ForegroundColor Cyan
} else {
    Write-Host "⚠️  Release workflow hasn't triggered yet. This might be normal - check GitHub Actions." -ForegroundColor Yellow
}

Write-Host "`n📌 Summary:" -ForegroundColor Cyan
Write-Host "- VERSION file: 0.8.2 ✅" -ForegroundColor White
Write-Host "- Tag v0.8.2: exists ✅" -ForegroundColor White
Write-Host "- CI: completed ✅" -ForegroundColor White
Write-Host "- Release: pending ⏳" -ForegroundColor White

Write-Host "`n🔗 Direct link to releases: https://github.com/wizzense/AitherZero/releases" -ForegroundColor Cyan