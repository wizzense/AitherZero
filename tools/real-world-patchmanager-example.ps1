#Requires -Version 7.0

<#
.SYNOPSIS
    Real-world PatchManager Example - Fix Documentation Typos

.DESCRIPTION
    This script demonstrates a realistic PatchManager workflow by finding and fixing
    common documentation typos across the project. It shows practical usage patterns.

.EXAMPLE
    .\real-world-patchmanager-example.ps1 -DryRun

.EXAMPLE
    .\real-world-patchmanager-example.ps1 -Interactive
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Interactive
)

# Import PatchManager
if (-not $env:PROJECT_ROOT) {
    $env:PROJECT_ROOT = (Get-Location).Path
}

try {
    Import-Module "$env:PROJECT_ROOT/aither-core/modules/PatchManager" -Force -ErrorAction Stop
} catch {
    Write-Host "⚠️  Could not import PatchManager module. Please ensure modules are available." -ForegroundColor Yellow
    Write-Host "   Expected path: $env:PROJECT_ROOT/aither-core/modules/PatchManager" -ForegroundColor Gray
    exit 1
}

Write-Host "🔧 Real-World PatchManager Example" -ForegroundColor Cyan
Write-Host "Finding and fixing documentation typos across the project" -ForegroundColor Gray
Write-Host ""

# Define common typos to fix
$typoFixes = @{
    'teh ' = 'the '
    'recieve' = 'receive'
    'seperate' = 'separate'
    'occured' = 'occurred'
    'thier' = 'their'
    'sucessful' = 'successful'
    'begining' = 'beginning'
    'lenght' = 'length'
}

if ($Interactive) {
    Write-Host "📋 This example will demonstrate:" -ForegroundColor Yellow
    Write-Host "  • Scanning project files for common typos" -ForegroundColor White
    Write-Host "  • Creating a patch with multiple file changes" -ForegroundColor White
    Write-Host "  • Using validation to ensure changes are correct" -ForegroundColor White
    Write-Host "  • Demonstrating real-world PatchManager workflow" -ForegroundColor White
    Write-Host ""
    Read-Host "Press Enter to continue..."
}

# Create the patch
$patchResult = Invoke-GitControlledPatch `
    -PatchDescription "Fix common documentation typos across project files" `
    -PatchOperation {

        Write-Host "🔍 Scanning project files for typos..." -ForegroundColor Blue

        # Find markdown and text files
        $filesToCheck = Get-ChildItem -Path $env:PROJECT_ROOT -Recurse -Include "*.md", "*.txt", "*.ps1" |
            Where-Object {
                $_.FullName -notmatch '\.git' -and
                $_.FullName -notmatch 'node_modules' -and
                $_.FullName -notmatch 'backups'
            } |
            Select-Object -First 10  # Limit for demo purposes

        $filesFixed = 0
        $typosFixed = 0

        foreach ($file in $filesToCheck) {
            try {
                $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
                if (-not $content) { continue }
                  $fileChanged = $false

                foreach ($typo in $typoFixes.Keys) {
                    $correct = $typoFixes[$typo]
                    if ($content -match [regex]::Escape($typo)) {
                        $content = $content -replace [regex]::Escape($typo), $correct
                        $fileChanged = $true
                        $typosFixed++
                        Write-Host "  Fixed '$typo' → '$correct' in $($file.Name)" -ForegroundColor Green
                    }
                }

                if ($fileChanged) {
                    Set-Content -Path $file.FullName -Value $content -NoNewline
                    $filesFixed++
                }

            } catch {
                Write-Warning "Could not process file: $($file.FullName)"
            }
        }

        Write-Host ""
        Write-Host "📊 Typo Fixing Results:" -ForegroundColor Yellow
        Write-Host "  Files checked: $($filesToCheck.Count)" -ForegroundColor White
        Write-Host "  Files fixed: $filesFixed" -ForegroundColor Green
        Write-Host "  Typos fixed: $typosFixed" -ForegroundColor Green

        if ($filesFixed -eq 0) {
            Write-Host "  Creating demo file to show patch functionality..." -ForegroundColor Cyan

            # Create a demo file with intentional typos for demonstration
            $demoContent = @"
# Demo Documentation

This is a demonstration file that contains some common typos that will be fixed.

## Overview
This project demonstrates sucessful implementation of automated patching.
The begining of this document explains teh main concepts.

## Features
- Recieve automated updates
- Seperate concerns properly
- Handle occured errors gracefully
- Maintain thier original functionality

## Length
The lenght of this documentation shows comprehensive coverage.
"@
            Set-Content -Path "demo-typos.md" -Value $demoContent

            # Now fix the typos in the demo file
            $content = Get-Content "demo-typos.md" -Raw
            foreach ($typo in $typoFixes.Keys) {
                $correct = $typoFixes[$typo]
                if ($content -match [regex]::Escape($typo)) {
                    $content = $content -replace [regex]::Escape($typo), $correct
                    Write-Host "  Fixed '$typo' → '$correct' in demo-typos.md" -ForegroundColor Green
                    $typosFixed++
                }
            }
            Set-Content -Path "demo-typos.md" -Value $content -NoNewline
            $filesFixed = 1
        }

    } `
    -DryRun:$DryRun

# Show results
Write-Host ""
if ($patchResult.Success) {
    Write-Host "✅ Patch completed successfully!" -ForegroundColor Green
    Write-Host "   Branch: $($patchResult.BranchName)" -ForegroundColor Cyan

    if (-not $DryRun) {
        Write-Host ""
        Write-Host "🎯 What happened:" -ForegroundColor Yellow
        Write-Host "  • Created patch branch: $($patchResult.BranchName)" -ForegroundColor White
        Write-Host "  • Scanned project files for common typos" -ForegroundColor White
        Write-Host "  • Fixed typos and committed changes" -ForegroundColor White
        Write-Host "  • Branch ready for review and merge" -ForegroundColor White

        Write-Host ""
        Write-Host "📚 Next steps:" -ForegroundColor Yellow
        Write-Host "  1. Review the changes: git show HEAD" -ForegroundColor White
        Write-Host "  2. Push the branch: git push origin $($patchResult.BranchName)" -ForegroundColor White
        Write-Host "  3. Create a pull request for review" -ForegroundColor White
        Write-Host "  4. Or rollback if needed: Invoke-PatchRollback" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "🔍 Dry run completed - no actual changes made" -ForegroundColor Yellow
        Write-Host "   Run without -DryRun to apply the changes" -ForegroundColor Gray
    }

} else {
    Write-Host " FAILPatch failed!" -ForegroundColor Red
    Write-Host "   Error: $($patchResult.Error)" -ForegroundColor Red
}

Write-Host ""
Write-Host "💡 This example demonstrates:" -ForegroundColor Magenta
Write-Host "  • Real-world patch scenarios (fixing typos)" -ForegroundColor White
Write-Host "  • Processing multiple files in a single patch" -ForegroundColor White
Write-Host "  • Providing meaningful patch descriptions" -ForegroundColor White
Write-Host "  • Using PatchManager for maintenance tasks" -ForegroundColor White
Write-Host "  • Safe dry-run testing before applying changes" -ForegroundColor White
