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
    Import-Module "$env:PROJECT_ROO(Join-Path $env:PWSH_MODULES_PATH "PatchManager")" -Force -ErrorAction Stop
} catch {
    Write-CustomLog -Level 'WARN' -Message "Could not import PatchManager module. Please ensure modules are available."
    Write-CustomLog -Level 'INFO' -Message "Expected path: $env:PROJECT_ROO(Join-Path $env:PWSH_MODULES_PATH "PatchManager")"
    exit 1
}

Write-CustomLog -Level 'INFO' -Message "Real-World PatchManager Example"
Write-CustomLog -Level 'INFO' -Message "Finding and fixing documentation typos across the project"

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
    Write-CustomLog -Level 'INFO' -Message "This example will demonstrate:"
    Write-CustomLog -Level 'INFO' -Message "  • Scanning project files for common typos"
    Write-CustomLog -Level 'INFO' -Message "  • Creating a patch with multiple file changes"
    Write-CustomLog -Level 'INFO' -Message "  • Using validation to ensure changes are correct"
    Write-CustomLog -Level 'INFO' -Message "  • Demonstrating real-world PatchManager workflow"
    Read-Host "Press Enter to continue..."
}

# Create the patch
$patchResult = Invoke-GitControlledPatch `
    -PatchDescription "Fix common documentation typos across project files" `
    -PatchOperation {

        Write-CustomLog -Level 'INFO' -Message "Scanning project files for typos..."

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
                        Write-CustomLog -Level 'SUCCESS' -Message "  Fixed '$typo' → '$correct' in $($file.Name)"
                    }
                }

                if ($fileChanged) {
                    Set-Content -Path $file.FullName -Value $content -NoNewline
                    $filesFixed++
                }

            } catch {
                Write-Warning "Could not process file: $($file.FullName)"
            }
        }        Write-CustomLog -Level 'INFO' -Message "Typo Fixing Results:"
        Write-CustomLog -Level 'INFO' -Message "  Files checked: $($filesToCheck.Count)"
        Write-CustomLog -Level 'SUCCESS' -Message "  Files fixed: $filesFixed"
        Write-CustomLog -Level 'SUCCESS' -Message "  Typos fixed: $typosFixed"

        if ($filesFixed -eq 0) {
            Write-CustomLog -Level 'INFO' -Message "  Creating demo file to show patch functionality..."

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
                    Write-CustomLog -Level 'SUCCESS' -Message "  Fixed '$typo' → '$correct' in demo-typos.md"
                    $typosFixed++
                }
            }
            Set-Content -Path "demo-typos.md" -Value $content -NoNewline
            $filesFixed = 1
        }

    } `
    -DryRun:$DryRun

# Show results
if ($patchResult.Success) {
    Write-CustomLog -Level 'SUCCESS' -Message "Patch completed successfully!"
    Write-CustomLog -Level 'INFO' -Message "   Branch: $($patchResult.BranchName)"

    if (-not $DryRun) {
        Write-CustomLog -Level 'INFO' -Message "What happened:"
        Write-CustomLog -Level 'INFO' -Message "  • Created patch branch: $($patchResult.BranchName)"
        Write-CustomLog -Level 'INFO' -Message "  • Scanned project files for common typos"
        Write-CustomLog -Level 'INFO' -Message "  • Fixed typos and committed changes"
        Write-CustomLog -Level 'INFO' -Message "  • Branch ready for review and merge"

        Write-CustomLog -Level 'INFO' -Message "Next steps:"
        Write-CustomLog -Level 'INFO' -Message "  1. Review the changes: git show HEAD"
        Write-CustomLog -Level 'INFO' -Message "  2. Push the branch: git push origin $($patchResult.BranchName)"
        Write-CustomLog -Level 'INFO' -Message "  3. Create a pull request for review"
        Write-CustomLog -Level 'INFO' -Message "  4. Or rollback if needed: Invoke-PatchRollback"
    } else {
        Write-CustomLog -Level 'INFO' -Message "Dry run completed - no actual changes made"
        Write-CustomLog -Level 'INFO' -Message "   Run without -DryRun to apply the changes"
    }

} else {
    Write-CustomLog -Level 'ERROR' -Message "Patch failed!"
    Write-CustomLog -Level 'ERROR' -Message "   Error: $($patchResult.Error)"
}

Write-CustomLog -Level 'INFO' -Message "This example demonstrates:"
Write-CustomLog -Level 'INFO' -Message "  • Real-world patch scenarios (fixing typos)"
Write-CustomLog -Level 'INFO' -Message "  • Processing multiple files in a single patch"
Write-CustomLog -Level 'INFO' -Message "  • Providing meaningful patch descriptions"
Write-CustomLog -Level 'INFO' -Message "  • Using PatchManager for maintenance tasks"
Write-CustomLog -Level 'INFO' -Message "  • Safe dry-run testing before applying changes"

