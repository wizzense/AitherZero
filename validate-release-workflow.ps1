#Requires -Version 7.0

<#
.SYNOPSIS
    Simplified Release Workflow Validation for AitherZero
.DESCRIPTION
    Validates release workflow components and generates a comprehensive report
#>

param(
    [string]$TestVersion = "0.8.0-test",
    [switch]$DryRun
)

# Get project root
$projectRoot = $PWD
$workflowsDir = Join-Path $projectRoot ".github" "workflows"
$buildDir = Join-Path $projectRoot "build"

# Results tracking
$results = @{
    WorkflowValidation = @()
    VersionManagement = @()
    BuildProcess = @()
    ArtifactCreation = @()
    ReleaseAssets = @()
    GitHubPages = @()
    ReleaseNotes = @()
    EndToEnd = @()
}

$totalTests = 0
$passedTests = 0
$failedTests = 0

function Test-Component {
    param(
        [string]$Category,
        [string]$TestName,
        [string]$Status,
        [string]$Message
    )
    
    $script:totalTests++
    if ($Status -eq "PASS") { $script:passedTests++ } else { $script:failedTests++ }
    
    $results[$Category] += @{
        Test = $TestName
        Status = $Status
        Message = $Message
        Timestamp = Get-Date -Format 'HH:mm:ss'
    }
    
    $color = if ($Status -eq "PASS") { "Green" } else { "Red" }
    Write-Host "  [$Status] $TestName - $Message" -ForegroundColor $color
}

Write-Host "`n🚀 AitherZero Release Workflow Validation" -ForegroundColor Magenta
Write-Host "=" * 50 -ForegroundColor Magenta

# 1. Manual Release Trigger Testing
Write-Host "`n1. Manual Release Trigger Workflow" -ForegroundColor Cyan
$triggerWorkflow = Join-Path $workflowsDir "trigger-release.yml"
if (Test-Path $triggerWorkflow) {
    Test-Component "WorkflowValidation" "TriggerWorkflowExists" "PASS" "trigger-release.yml found"
    
    $content = Get-Content $triggerWorkflow -Raw
    if ($content -match "workflow_dispatch") {
        Test-Component "WorkflowValidation" "WorkflowDispatch" "PASS" "workflow_dispatch trigger configured"
    } else {
        Test-Component "WorkflowValidation" "WorkflowDispatch" "FAIL" "workflow_dispatch trigger not found"
    }
    
    if ($content -match "version.*required.*true") {
        Test-Component "WorkflowValidation" "VersionInput" "PASS" "Version input parameter configured"
    } else {
        Test-Component "WorkflowValidation" "VersionInput" "FAIL" "Version input parameter not properly configured"
    }
    
    if ($content -match "create_tag.*boolean") {
        Test-Component "WorkflowValidation" "CreateTagInput" "PASS" "Create tag input parameter configured"
    } else {
        Test-Component "WorkflowValidation" "CreateTagInput" "FAIL" "Create tag input parameter not configured"
    }
    
    if ($content -match "git tag.*git push") {
        Test-Component "WorkflowValidation" "TagCreation" "PASS" "Git tag creation and push logic present"
    } else {
        Test-Component "WorkflowValidation" "TagCreation" "FAIL" "Git tag creation and push logic not found"
    }
    
} else {
    Test-Component "WorkflowValidation" "TriggerWorkflowExists" "FAIL" "trigger-release.yml not found"
}

# 2. Version Management Validation
Write-Host "`n2. Version Management Process" -ForegroundColor Cyan
$versionFile = Join-Path $projectRoot "VERSION"
if (Test-Path $versionFile) {
    Test-Component "VersionManagement" "VersionFileExists" "PASS" "VERSION file found"
    
    $currentVersion = (Get-Content $versionFile -Raw).Trim()
    if ($currentVersion -match '^\d+\.\d+\.\d+$') {
        Test-Component "VersionManagement" "VersionFormatValid" "PASS" "Version format valid: $currentVersion"
    } else {
        Test-Component "VersionManagement" "VersionFormatValid" "FAIL" "Invalid version format: $currentVersion"
    }
} else {
    Test-Component "VersionManagement" "VersionFileExists" "FAIL" "VERSION file not found"
}

# 3. Build Process Validation
Write-Host "`n3. Build Process" -ForegroundColor Cyan
$buildScript = Join-Path $buildDir "Build-Package.ps1"
if (Test-Path $buildScript) {
    Test-Component "BuildProcess" "BuildScriptExists" "PASS" "Build-Package.ps1 found"
    
    $buildContent = Get-Content $buildScript -Raw
    if ($buildContent -match "Platform.*Version.*OutputPath") {
        Test-Component "BuildProcess" "BuildParameters" "PASS" "Build script parameters configured"
    } else {
        Test-Component "BuildProcess" "BuildParameters" "FAIL" "Build script parameters not properly configured"
    }
    
    if ($buildContent -match "windows.*linux.*macos") {
        Test-Component "BuildProcess" "CrossPlatformSupport" "PASS" "Cross-platform build support present"
    } else {
        Test-Component "BuildProcess" "CrossPlatformSupport" "FAIL" "Cross-platform build support not found"
    }
    
} else {
    Test-Component "BuildProcess" "BuildScriptExists" "FAIL" "Build-Package.ps1 not found"
}

# 4. Artifact Creation Testing
Write-Host "`n4. Artifact Creation" -ForegroundColor Cyan
$reportScript = Join-Path $projectRoot "scripts" "reporting" "Generate-ComprehensiveReport.ps1"
if (Test-Path $reportScript) {
    Test-Component "ArtifactCreation" "ReportGeneratorExists" "PASS" "Comprehensive report generator found"
    
    $reportContent = Get-Content $reportScript -Raw
    if ($reportContent -match "ReportPath.*Version.*IncludeDetailedAnalysis") {
        Test-Component "ArtifactCreation" "ReportParameters" "PASS" "Report generator parameters configured"
    } else {
        Test-Component "ArtifactCreation" "ReportParameters" "FAIL" "Report generator parameters not properly configured"
    }
    
} else {
    Test-Component "ArtifactCreation" "ReportGeneratorExists" "FAIL" "Comprehensive report generator not found"
}

# 5. Release Asset Validation
Write-Host "`n5. Release Assets" -ForegroundColor Cyan
$releaseWorkflow = Join-Path $workflowsDir "release.yml"
if (Test-Path $releaseWorkflow) {
    Test-Component "ReleaseAssets" "ReleaseWorkflowExists" "PASS" "release.yml found"
    
    $releaseContent = Get-Content $releaseWorkflow -Raw
    if ($releaseContent -match "softprops/action-gh-release") {
        Test-Component "ReleaseAssets" "GithubReleaseAction" "PASS" "GitHub release action configured"
    } else {
        Test-Component "ReleaseAssets" "GithubReleaseAction" "FAIL" "GitHub release action not found"
    }
    
    if ($releaseContent -match "files.*build/output/AitherZero-") {
        Test-Component "ReleaseAssets" "AssetUpload" "PASS" "Asset upload pattern configured"
    } else {
        Test-Component "ReleaseAssets" "AssetUpload" "FAIL" "Asset upload pattern not found"
    }
    
    if ($releaseContent -match "generate_release_notes.*true") {
        Test-Component "ReleaseAssets" "ReleaseNotesGeneration" "PASS" "Release notes generation enabled"
    } else {
        Test-Component "ReleaseAssets" "ReleaseNotesGeneration" "FAIL" "Release notes generation not enabled"
    }
    
} else {
    Test-Component "ReleaseAssets" "ReleaseWorkflowExists" "FAIL" "release.yml not found"
}

# 6. GitHub Pages Deployment
Write-Host "`n6. GitHub Pages Deployment" -ForegroundColor Cyan
$reportWorkflow = Join-Path $workflowsDir "comprehensive-report.yml"
if (Test-Path $reportWorkflow) {
    Test-Component "GitHubPages" "ReportWorkflowExists" "PASS" "comprehensive-report.yml found"
    
    $reportContent = Get-Content $reportWorkflow -Raw
    if ($reportContent -match "actions/deploy-pages") {
        Test-Component "GitHubPages" "PagesDeployment" "PASS" "GitHub Pages deployment action found"
    } else {
        Test-Component "GitHubPages" "PagesDeployment" "FAIL" "GitHub Pages deployment action not found"
    }
    
} else {
    Test-Component "GitHubPages" "ReportWorkflowExists" "FAIL" "comprehensive-report.yml not found"
}

# 7. Release Notes Generation
Write-Host "`n7. Release Notes Generation" -ForegroundColor Cyan
$changelog = Join-Path $projectRoot "CHANGELOG.md"
if (Test-Path $changelog) {
    Test-Component "ReleaseNotes" "ChangelogExists" "PASS" "CHANGELOG.md found"
    
    $changelogContent = Get-Content $changelog -Raw
    if ($changelogContent -match "##.*\d+\.\d+\.\d+") {
        Test-Component "ReleaseNotes" "ChangelogFormat" "PASS" "Changelog format appears valid"
    } else {
        Test-Component "ReleaseNotes" "ChangelogFormat" "FAIL" "Changelog format may be invalid"
    }
    
} else {
    Test-Component "ReleaseNotes" "ChangelogExists" "FAIL" "CHANGELOG.md not found"
}

# 8. End-to-End Workflow Testing
Write-Host "`n8. End-to-End Workflow" -ForegroundColor Cyan
$triggerExists = Test-Path $triggerWorkflow
$releaseExists = Test-Path $releaseWorkflow
$buildExists = Test-Path $buildScript

if ($triggerExists -and $releaseExists -and $buildExists) {
    Test-Component "EndToEnd" "WorkflowChain" "PASS" "Complete workflow chain present"
} else {
    Test-Component "EndToEnd" "WorkflowChain" "FAIL" "Incomplete workflow chain"
}

if ($triggerExists -and $releaseExists) {
    $triggerContent = Get-Content $triggerWorkflow -Raw
    $releaseContent = Get-Content $releaseWorkflow -Raw
    
    if ($triggerContent -match "git push origin.*tag" -and $releaseContent -match "push.*tags") {
        Test-Component "EndToEnd" "TriggerIntegration" "PASS" "Trigger-to-release integration configured"
    } else {
        Test-Component "EndToEnd" "TriggerIntegration" "FAIL" "Trigger-to-release integration not properly configured"
    }
}

# Generate Summary Report
Write-Host "`n" -NoNewline
Write-Host "=" * 50 -ForegroundColor Magenta
Write-Host "VALIDATION SUMMARY" -ForegroundColor Magenta
Write-Host "=" * 50 -ForegroundColor Magenta

Write-Host "`nTest Results:" -ForegroundColor Cyan
Write-Host "  Total Tests: $totalTests" -ForegroundColor White
Write-Host "  Passed: $passedTests" -ForegroundColor Green
Write-Host "  Failed: $failedTests" -ForegroundColor Red
Write-Host "  Success Rate: $([math]::Round(($passedTests/$totalTests)*100, 1))%" -ForegroundColor $(if ($passedTests -eq $totalTests) { 'Green' } else { 'Yellow' })

$overallStatus = if ($passedTests -eq $totalTests) { "SUCCESS" } else { "NEEDS ATTENTION" }
$statusColor = if ($passedTests -eq $totalTests) { "Green" } else { "Yellow" }
Write-Host "  Overall Status: $overallStatus" -ForegroundColor $statusColor

Write-Host "`nCategory Breakdown:" -ForegroundColor Cyan
foreach ($category in $results.Keys) {
    $categoryTests = $results[$category]
    if ($categoryTests.Count -gt 0) {
        $categoryPassed = ($categoryTests | Where-Object { $_.Status -eq "PASS" }).Count
        $categoryTotal = $categoryTests.Count
        $categoryRate = [math]::Round(($categoryPassed/$categoryTotal)*100, 1)
        
        Write-Host "  $category`: $categoryPassed/$categoryTotal passed ($categoryRate%)" -ForegroundColor White
        
        # Show failed tests
        $failedTests = $categoryTests | Where-Object { $_.Status -eq "FAIL" }
        if ($failedTests.Count -gt 0) {
            foreach ($failed in $failedTests) {
                Write-Host "    ❌ $($failed.Test): $($failed.Message)" -ForegroundColor Red
            }
        }
    }
}

Write-Host "`nRecommendations:" -ForegroundColor Cyan
if ($script:failedTests -gt 0) {
    Write-Host "  • Review and fix failed workflow components" -ForegroundColor Yellow
    Write-Host "  • Ensure all required files are present and properly configured" -ForegroundColor Yellow
    Write-Host "  • Test workflow integration manually before deploying" -ForegroundColor Yellow
} else {
    Write-Host "  • All workflow components validated successfully" -ForegroundColor Green
    Write-Host "  • Ready for release workflow testing" -ForegroundColor Green
}

Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "  1. Fix any failed validation items" -ForegroundColor White
Write-Host "  2. Test manual release trigger with a test version" -ForegroundColor White
Write-Host "  3. Verify build process generates all expected artifacts" -ForegroundColor White
Write-Host "  4. Validate GitHub release creation and asset upload" -ForegroundColor White

Write-Host "`n" -NoNewline
Write-Host "=" * 50 -ForegroundColor Magenta

# Export results to JSON
$reportData = @{
    Summary = @{
        TotalTests = $script:totalTests
        PassedTests = $script:passedTests
        FailedTests = $script:failedTests
        SuccessRate = [math]::Round(($script:passedTests/$script:totalTests)*100, 1)
        OverallStatus = $overallStatus
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC'
        TestVersion = $TestVersion
    }
    Categories = $results
}

$reportPath = Join-Path $projectRoot "release-workflow-validation.json"
$reportData | ConvertTo-Json -Depth 5 | Set-Content $reportPath
Write-Host "`nDetailed report saved to: $reportPath" -ForegroundColor Cyan

return $reportData