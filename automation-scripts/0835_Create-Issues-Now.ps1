#Requires -Version 7.0
<#
.SYNOPSIS
    IMMEDIATE GitHub issue creation - no hanging, no dependencies, just results
.DESCRIPTION
    Creates GitHub issues right now using multiple fallback methods
    Generates files that can be immediately used to create issues manually
.PARAMETER Force
    Skip all confirmations and create issues immediately
.PARAMETER GenerateOnly
    Only generate issue files, don't attempt to create via GitHub CLI
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$GenerateOnly
)

# Script metadata
$scriptInfo = @{
    Stage = 'Immediate'
    Number = '0835'
    Name = 'Create-Issues-Now'
    Description = 'IMMEDIATE GitHub issue creation without hanging'
    Dependencies = @('0830')
    Tags = @('immediate', 'github', 'issues', 'no-hang')
}

function Write-ImmediateStatus {
    param([string]$Message, [string]$Level = "Info")
    $color = switch ($Level) {
        "Error" { "Red" }
        "Warning" { "Yellow" }
        "Success" { "Green" }
        "Critical" { "Magenta" }
        "Urgent" { "Red" }
        default { "Cyan" }
    }
    Write-Host "⚡ $Message" -ForegroundColor $color
}

try {
    Write-ImmediateStatus "🚨 IMMEDIATE GITHUB ISSUE CREATION STARTING..." "Urgent"
    Write-Host "=" * 60 -ForegroundColor Red
    Write-Host ""
    
    # Step 1: Generate issue files (this always works)
    Write-ImmediateStatus "Step 1: Generating issue files..." "Info"
    
    $generateScript = "./automation-scripts/0830_Generate-IssueFiles.ps1"
    if (-not (Test-Path $generateScript)) {
        Write-ImmediateStatus "❌ Issue generation script not found!" "Error"
        exit 1
    }
    
    # Run the generation
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $generateScript
    $generateResult = $LASTEXITCODE
    
    if ($generateResult -ne 0) {
        Write-ImmediateStatus "❌ Issue generation failed!" "Error"
        exit 1
    }
    
    Write-ImmediateStatus "✅ Issue files generated successfully!" "Success"
    Write-Host ""
    
    # Check what was generated
    $issueDir = "./generated-issues"
    if (-not (Test-Path $issueDir)) {
        Write-ImmediateStatus "❌ Generated issues directory not found!" "Error"
        exit 1
    }
    
    $issueFiles = Get-ChildItem -Path $issueDir -Filter "issue-*.md"
    $summaryFile = Join-Path $issueDir "CREATE-ISSUES.md"
    
    Write-ImmediateStatus "📁 Generated $($issueFiles.Count) issue files:" "Success"
    foreach ($file in $issueFiles) {
        Write-Host "  • $($file.Name)" -ForegroundColor Green
    }
    Write-Host ""
    
    if ($GenerateOnly) {
        Write-ImmediateStatus "✅ GENERATION COMPLETE - Files ready for manual creation!" "Success"
        Write-Host ""
        Write-ImmediateStatus "🔗 NEXT STEPS:" "Critical"
        Write-Host "1. Open: $summaryFile" -ForegroundColor Yellow
        Write-Host "2. Go to: https://github.com/wizzense/AitherZero/issues/new" -ForegroundColor Yellow
        Write-Host "3. Copy content from generated .md files" -ForegroundColor Yellow
        Write-Host "4. Create issues manually (fastest method)" -ForegroundColor Yellow
        exit 0
    }
    
    # Step 2: Try GitHub CLI (if available)
    Write-ImmediateStatus "Step 2: Checking GitHub CLI availability..." "Info"
    
    $ghAvailable = Get-Command gh -ErrorAction SilentlyContinue
    if ($ghAvailable) {
        Write-ImmediateStatus "✅ GitHub CLI found - attempting authentication check..." "Success"
        
        try {
            $authCheck = & gh auth status 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-ImmediateStatus "✅ GitHub CLI authenticated!" "Success"
                
                if (-not $Force) {
                    Write-Host ""
                    Write-ImmediateStatus "⚠️ About to create REAL GitHub issues!" "Warning"
                    $confirm = Read-Host "Continue with GitHub CLI creation? (y/N)"
                    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
                        Write-ImmediateStatus "User cancelled - files are ready for manual creation" "Info"
                        Write-Host "Open: $summaryFile" -ForegroundColor Yellow
                        exit 0
                    }
                }
                
                Write-Host ""
                Write-ImmediateStatus "🚀 Creating GitHub issues via CLI..." "Critical"
                
                $createdCount = 0
                $failedCount = 0
                
                foreach ($file in $issueFiles) {
                    $content = Get-Content $file.FullName -Raw
                    
                    # Extract title (first line after #)
                    $titleMatch = $content | Select-String -Pattern "^# (.+)" | Select-Object -First 1
                    if (-not $titleMatch) {
                        Write-ImmediateStatus "⚠️ Could not extract title from $($file.Name)" "Warning"
                        $failedCount++
                        continue
                    }
                    $title = $titleMatch.Matches[0].Groups[1].Value
                    
                    # Extract labels
                    $labelsMatch = $content | Select-String -Pattern "\*\*Labels\*\*: (.+)" | Select-Object -First 1
                    $labels = if ($labelsMatch) { $labelsMatch.Matches[0].Groups[1].Value } else { "automated-issue" }
                    
                    # Extract assignee  
                    $assigneeMatch = $content | Select-String -Pattern "\*\*Assignee\*\*: (.+)" | Select-Object -First 1
                    $assignee = if ($assigneeMatch) { $assigneeMatch.Matches[0].Groups[1].Value } else { "copilot" }
                    
                    Write-ImmediateStatus "Creating: $title" "Info"
                    
                    try {
                        $result = & gh issue create --title $title --body-file $file.FullName --label $labels --assignee $assignee 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            Write-ImmediateStatus "✅ Created: $result" "Success"
                            $createdCount++
                        } else {
                            Write-ImmediateStatus "❌ Failed: $result" "Error"
                            $failedCount++
                        }
                    }
                    catch {
                        Write-ImmediateStatus "❌ Exception: $_" "Error"
                        $failedCount++
                    }
                }
                
                Write-Host ""
                Write-ImmediateStatus "📊 RESULTS:" "Success"
                Write-Host "  ✅ Created: $createdCount issues" -ForegroundColor Green
                Write-Host "  ❌ Failed: $failedCount issues" -ForegroundColor Red
                
                if ($createdCount -gt 0) {
                    Write-Host ""
                    Write-ImmediateStatus "🎉 SUCCESS! GitHub issues have been created!" "Success"
                    Write-Host "🔗 View at: https://github.com/wizzense/AitherZero/issues" -ForegroundColor Cyan
                }
                
                exit 0
            }
        }
        catch {
            Write-ImmediateStatus "⚠️ GitHub CLI authentication failed: $_" "Warning"
        }
    }
    
    # Fallback: Manual creation instructions
    Write-Host ""
    Write-ImmediateStatus "❌ GitHub CLI not available or not authenticated" "Error"
    Write-Host ""
    Write-ImmediateStatus "📋 MANUAL CREATION REQUIRED (FASTEST METHOD)" "Critical"
    Write-Host "=" * 50 -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "🔗 Go to: https://github.com/wizzense/AitherZero/issues/new" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📁 Use these generated files:" -ForegroundColor Yellow
    foreach ($file in $issueFiles) {
        $title = (Get-Content $file.FullName | Select-String "^# " | Select-Object -First 1) -replace '^# ', ''
        Write-Host "  📄 $($file.Name): $title" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "📋 Instructions:" -ForegroundColor Yellow
    Write-Host "1. Open the URL above" -ForegroundColor White
    Write-Host "2. Copy title and content from each .md file" -ForegroundColor White
    Write-Host "3. Add labels: P0-Critical, security, automated-issue" -ForegroundColor White
    Write-Host "4. Assign to: @copilot" -ForegroundColor White
    Write-Host "5. Click 'Submit new issue'" -ForegroundColor White
    
    Write-Host ""
    Write-ImmediateStatus "📖 Detailed instructions: $summaryFile" "Info"
    
    Write-Host ""
    Write-ImmediateStatus "🚨 PRIORITY: Start with P0-Critical issues first!" "Urgent"
    
    exit 0
}
catch {
    Write-ImmediateStatus "❌ CRITICAL ERROR: $_" "Error"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    
    Write-Host ""
    Write-ImmediateStatus "🆘 FALLBACK: Check if issue files were generated" "Warning"
    if (Test-Path "./generated-issues") {
        Write-Host "✅ Files available at: ./generated-issues/" -ForegroundColor Green
        Write-Host "📖 Instructions: ./generated-issues/CREATE-ISSUES.md" -ForegroundColor Green
    }
    
    exit 1
}