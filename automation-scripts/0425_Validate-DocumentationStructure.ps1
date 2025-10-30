#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Validates and maintains documentation structure and organization
.DESCRIPTION
    This script validates that documentation follows the AitherZero documentation standards:
    - Root directory should only contain essential markdown files
    - Strategic docs should be in docs/strategic/
    - Technical guides should be in docs/guides/
    - Old summaries should be in docs/archive/
    - Checks for broken internal links
    - Validates documentation structure
    
    Exit Codes:
    0   - All validations passed
    1   - Validation issues found
    2   - Validation error

.PARAMETER Fix
    Automatically fix certain issues (like broken links to moved files)
.PARAMETER CheckLinks
    Check for broken internal documentation links
.PARAMETER Strict
    Fail on warnings (for CI/CD environments)
.EXAMPLE
    az 0425
    Validates documentation structure
.EXAMPLE
    az 0425 -CheckLinks
    Validates structure and checks for broken links
.EXAMPLE
    az 0425 -Strict
    Validates with strict mode (fail on warnings)
.NOTES
    Stage: Testing
    Order: 0425
    Dependencies: None
    Tags: testing, documentation, validation, structure
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Fix,
    [switch]$CheckLinks,
    [switch]$Strict
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata
$scriptInfo = @{
    Stage = 'Testing'
    Number = '0425'
    Name = 'Validate-DocumentationStructure'
    Description = 'Validates documentation organization and structure'
    Tags = @('testing', 'documentation', 'validation')
}

# Import logging if available
$projectRoot = Split-Path $PSScriptRoot -Parent
$loggingModule = Join-Path $projectRoot "domains/utilities/Logging.psm1"

$useLogging = $false
if (Test-Path $loggingModule) {
    try {
        Import-Module $loggingModule -Force -ErrorAction Stop
        $useLogging = $true
    } catch {
        Write-Verbose "Custom logging not available: $_"
    }
}

function Write-ValidationLog {
    param(
        [string]$Message,
        [ValidateSet('Information', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Information'
    )
    
    if ($useLogging -and (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
        # Map Success to Information for the logging module
        $logLevel = if ($Level -eq 'Success') { 'Information' } else { $Level }
        Write-CustomLog -Message $Message -Level $logLevel
    } else {
        $colors = @{
            'Information' = 'Cyan'
            'Warning' = 'Yellow'
            'Error' = 'Red'
            'Success' = 'Green'
        }
        $color = $colors[$Level]
        
        $prefix = switch ($Level) {
            'Error' { '❌' }
            'Warning' { '⚠️ ' }
            'Success' { '✅' }
            default { 'ℹ️ ' }
        }
        
        Write-Host "$prefix $Message" -ForegroundColor $color
    }
}

# Documentation structure rules
$docRules = @{
    # Files that MUST stay in root
    RequiredRootFiles = @(
        'README.md'
        'QUICK-REFERENCE.md'
        'DOCKER.md'
        'FUNCTIONALITY-INDEX.md'
        'index.md'
    )
    
    # Patterns for files that should NOT be in root
    ForbiddenRootPatterns = @(
        '*SUMMARY*.md'
        '*ROADMAP*.md'
        '*STRATEGIC*.md'
        '*IMPLEMENTATION*.md'
        '*ACTIONS*.md'
        '*RELEASE*.md'
        '*WORKFLOW*.md'
        '*RESTORATION*.md'
        '*CONSOLIDATION*.md'
    )
    
    # Expected directory structure
    RequiredDirectories = @(
        'docs'
        'docs/strategic'
        'docs/archive'
        'docs/guides'
        'docs/troubleshooting'
    )
    
    # Directories that should NOT exist
    ForbiddenDirectories = @(
        'generated-issues'
        'legacy-to-migrate'
    )
}

$validationResults = @{
    Passed = 0
    Warnings = 0
    Errors = 0
    Issues = @()
}

function Add-ValidationIssue {
    param(
        [string]$Type,
        [string]$Message,
        [string]$File,
        [string]$Severity = 'Warning'
    )
    
    $validationResults.Issues += [PSCustomObject]@{
        Type = $Type
        Message = $Message
        File = $File
        Severity = $Severity
    }
    
    if ($Severity -eq 'Error') {
        $validationResults.Errors++
        Write-ValidationLog $Message -Level Error
    } elseif ($Severity -eq 'Warning') {
        $validationResults.Warnings++
        Write-ValidationLog $Message -Level Warning
    }
}

# Start validation
Write-ValidationLog "Starting documentation structure validation..." -Level Information
Write-ValidationLog "Project root: $projectRoot" -Level Information

# Check 1: Validate required directories exist
Write-ValidationLog "`nChecking required directories..." -Level Information
foreach ($dir in $docRules.RequiredDirectories) {
    $fullPath = Join-Path $projectRoot $dir
    if (Test-Path $fullPath) {
        Write-ValidationLog "  ✓ $dir exists" -Level Success
        $validationResults.Passed++
    } else {
        Add-ValidationIssue -Type 'MissingDirectory' -Message "Required directory missing: $dir" -File $dir -Severity 'Error'
    }
}

# Check 2: Validate forbidden directories don't exist
Write-ValidationLog "`nChecking for forbidden directories..." -Level Information
foreach ($dir in $docRules.ForbiddenDirectories) {
    $fullPath = Join-Path $projectRoot $dir
    if (Test-Path $fullPath) {
        Add-ValidationIssue -Type 'ForbiddenDirectory' -Message "Obsolete directory should be removed: $dir" -File $dir -Severity 'Warning'
    } else {
        Write-ValidationLog "  ✓ $dir does not exist (good)" -Level Success
        $validationResults.Passed++
    }
}

# Check 3: Validate root directory only has essential files
Write-ValidationLog "`nChecking root directory markdown files..." -Level Information
$rootMdFiles = @(Get-ChildItem -Path $projectRoot -Filter "*.md" -File | Where-Object {
    $_.Name -notin $docRules.RequiredRootFiles
})

if ($rootMdFiles.Count -eq 0) {
    Write-ValidationLog "  ✓ Root directory only contains essential files" -Level Success
    $validationResults.Passed++
} else {
    foreach ($file in $rootMdFiles) {
        # Check if it matches forbidden patterns
        $isForbidden = $false
        foreach ($pattern in $docRules.ForbiddenRootPatterns) {
            if ($file.Name -like $pattern) {
                $isForbidden = $true
                break
            }
        }
        
        if ($isForbidden) {
            Add-ValidationIssue -Type 'MisplacedFile' -Message "File should be moved to appropriate docs subdirectory" -File $file.Name -Severity 'Warning'
        } else {
            # Non-forbidden file in root - might be intentional, but warn
            Add-ValidationIssue -Type 'UnexpectedRootFile' -Message "Unexpected markdown file in root (verify if intentional)" -File $file.Name -Severity 'Warning'
        }
    }
}

# Check 4: Validate required root files exist
Write-ValidationLog "`nChecking required root files..." -Level Information
foreach ($file in $docRules.RequiredRootFiles) {
    $fullPath = Join-Path $projectRoot $file
    if (Test-Path $fullPath) {
        Write-ValidationLog "  ✓ $file exists" -Level Success
        $validationResults.Passed++
    } else {
        Add-ValidationIssue -Type 'MissingFile' -Message "Required root file missing: $file" -File $file -Severity 'Error'
    }
}

# Check 5: Validate docs subdirectories have README files
Write-ValidationLog "`nChecking subdirectory README files..." -Level Information
$docsSubdirs = @('strategic', 'archive', 'guides')
foreach ($subdir in $docsSubdirs) {
    $readmePath = Join-Path $projectRoot "docs/$subdir/README.md"
    if (Test-Path $readmePath) {
        Write-ValidationLog "  ✓ docs/$subdir/README.md exists" -Level Success
        $validationResults.Passed++
    } else {
        Add-ValidationIssue -Type 'MissingReadme' -Message "README.md missing in docs/$subdir/" -File "docs/$subdir/README.md" -Severity 'Warning'
    }
}

# Check 6: Check for broken internal links (if requested)
if ($CheckLinks) {
    Write-ValidationLog "`nChecking for broken internal documentation links..." -Level Information
    
    $allMdFiles = Get-ChildItem -Path $projectRoot -Filter "*.md" -Recurse -File | 
                  Where-Object { $_.FullName -notlike "*\.git\*" }
    
    $brokenLinks = @()
    
    foreach ($mdFile in $allMdFiles) {
        $content = Get-Content $mdFile.FullName -Raw
        
        # Find markdown links: [text](path)
        $linkPattern = '\[([^\]]+)\]\(([^)]+)\)'
        $matches = [regex]::Matches($content, $linkPattern)
        
        foreach ($match in $matches) {
            $linkPath = $match.Groups[2].Value
            
            # Skip external links and anchors
            if ($linkPath -match '^(http|https|#|mailto)') {
                continue
            }
            
            # Resolve relative path
            $basePath = Split-Path $mdFile.FullName -Parent
            $targetPath = Join-Path $basePath $linkPath
            $targetPath = [System.IO.Path]::GetFullPath($targetPath)
            
            if (-not (Test-Path $targetPath)) {
                $relativePath = $mdFile.FullName.Replace($projectRoot, '').TrimStart('\', '/')
                Add-ValidationIssue -Type 'BrokenLink' -Message "Broken link to '$linkPath'" -File $relativePath -Severity 'Warning'
                $brokenLinks += [PSCustomObject]@{
                    File = $relativePath
                    Link = $linkPath
                    Target = $targetPath
                }
            }
        }
    }
    
    if ($brokenLinks.Count -eq 0) {
        Write-ValidationLog "  ✓ No broken internal links found" -Level Success
        $validationResults.Passed++
    } else {
        Write-ValidationLog "  Found $($brokenLinks.Count) broken link(s)" -Level Warning
    }
}

# Summary
Write-ValidationLog "`n" + ("=" * 60) -Level Information
Write-ValidationLog "DOCUMENTATION VALIDATION SUMMARY" -Level Information
Write-ValidationLog ("=" * 60) -Level Information

Write-ValidationLog "Passed:   $($validationResults.Passed)" -Level Success
Write-ValidationLog "Warnings: $($validationResults.Warnings)" -Level Warning
Write-ValidationLog "Errors:   $($validationResults.Errors)" -Level Error

if ($validationResults.Issues.Count -gt 0) {
    Write-ValidationLog "`nIssues found:" -Level Information
    
    # Group by type
    $issuesByType = $validationResults.Issues | Group-Object -Property Type
    
    foreach ($group in $issuesByType) {
        Write-ValidationLog "`n$($group.Name):" -Level Information
        foreach ($issue in $group.Group) {
            $severity = if ($issue.Severity -eq 'Error') { '🔴' } else { '🟡' }
            Write-Host "  $severity $($issue.File): $($issue.Message)"
        }
    }
}

# Determine exit code
$exitCode = 0

if ($validationResults.Errors -gt 0) {
    $exitCode = 1
    Write-ValidationLog "`n❌ Validation FAILED with errors" -Level Error
} elseif ($Strict -and $validationResults.Warnings -gt 0) {
    $exitCode = 1
    Write-ValidationLog "`n❌ Validation FAILED (strict mode - warnings treated as errors)" -Level Error
} elseif ($validationResults.Warnings -gt 0) {
    Write-ValidationLog "`n⚠️  Validation PASSED with warnings" -Level Warning
} else {
    Write-ValidationLog "`n✅ Validation PASSED - documentation structure is compliant!" -Level Success
}

# Save results to file
$reportPath = Join-Path $projectRoot "reports/documentation-validation.json"
$reportDir = Split-Path $reportPath -Parent
if (-not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

$validationResults | ConvertTo-Json -Depth 10 | Set-Content $reportPath
Write-ValidationLog "`nResults saved to: $reportPath" -Level Information

exit $exitCode
