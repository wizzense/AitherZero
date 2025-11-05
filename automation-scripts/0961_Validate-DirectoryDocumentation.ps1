<#
.SYNOPSIS
    Validate that directories have proper documentation (README.md).

.DESCRIPTION
    Checks that important directories contain README.md files to document their purpose and contents.
    Ensures documentation lives with the code it documents.
    Can auto-generate skeleton README files for missing documentation.

.PARAMETER CheckMissing
    Check for directories without README.md files.

.PARAMETER GenerateSkeletons
    Auto-generate skeleton README.md files for directories missing documentation.

.PARAMETER ExcludeDirs
    Directories to exclude from validation (e.g., .git, node_modules).

.PARAMETER MinFiles
    Minimum number of files a directory must have to require documentation (default: 3).

.EXAMPLE
    ./automation-scripts/0961_Validate-DirectoryDocumentation.ps1 -CheckMissing
    Check for directories without README.md.

.EXAMPLE
    ./automation-scripts/0961_Validate-DirectoryDocumentation.ps1 -GenerateSkeletons
    Auto-generate skeleton README files for undocumented directories.

.NOTES
    Stage: 0961 (Documentation Validation)
    Dependencies: None
    Tags: documentation, validation, readme
#>

[CmdletBinding()]
param(
    [switch]$CheckMissing,
    [switch]$GenerateSkeletons,
    [string[]]$ExcludeDirs = @('.git', 'node_modules', '.cache', '.vscode', 'bin', 'obj', 'dist', 'build'),
    [int]$MinFiles = 3
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Initialize
$reportDir = Join-Path $PSScriptRoot ".." "reports"
if (-not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

Write-Host "📋 Directory Documentation Validator" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Get repository root
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    $repoRoot = Split-Path $PSScriptRoot -Parent
}

Write-Host "📁 Repository: $repoRoot" -ForegroundColor Gray
Write-Host "📌 Minimum files to require README: $MinFiles" -ForegroundColor Gray
Write-Host ""

# Find all directories
Write-Host "🔍 Analyzing directory structure..." -ForegroundColor Yellow

$allDirs = Get-ChildItem -Path $repoRoot -Directory -Recurse -ErrorAction SilentlyContinue |
    Where-Object {
        $dirPath = $_.FullName
        $relativePath = $dirPath.Replace($repoRoot, '').TrimStart('\', '/')
        
        # Exclude specified directories
        $excluded = $false
        foreach ($excludeDir in $ExcludeDirs) {
            if ($relativePath -like "*$excludeDir*") {
                $excluded = $true
                break
            }
        }
        -not $excluded
    }

Write-Host "   Found $($allDirs.Count) directories to check" -ForegroundColor Green
Write-Host ""

# Check each directory for README.md
$missingDocs = @()
$existingDocs = @()

foreach ($dir in $allDirs) {
    try {
        $relativePath = $dir.FullName.Replace($repoRoot, '').TrimStart('\', '/')
        
        # Count files in directory (excluding subdirectories)
        $fileCount = (Get-ChildItem -Path $dir.FullName -File -ErrorAction SilentlyContinue).Count
        
        # Skip if too few files
        if ($fileCount -lt $MinFiles) {
            continue
        }
        
        # Check for README.md or index.md
        $readmePath = Join-Path $dir.FullName "README.md"
        $indexPath = Join-Path $dir.FullName "index.md"
        $hasReadme = Test-Path $readmePath
        $hasIndex = Test-Path $indexPath
        $hasDocumentation = $hasReadme -or $hasIndex
        
        if ($hasDocumentation) {
            $existingDocs += [PSCustomObject]@{
                Path = $relativePath
                FileCount = $fileCount
                HasREADME = $hasReadme
                HasIndex = $hasIndex
            }
        } else {
            $missingDocs += [PSCustomObject]@{
                Path = $relativePath
                FileCount = $fileCount
                HasREADME = $false
                HasIndex = $false
            }
        }
    } catch {
        Write-Warning "Failed to process $($dir.FullName): $_"
    }
}

# Generate reports
Write-Host "📊 Validation Results" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Cyan
Write-Host ""

$totalChecked = $existingDocs.Count + $missingDocs.Count
$missingCount = $missingDocs.Count
$coveragePercent = if ($totalChecked -gt 0) { [math]::Round((($totalChecked - $missingCount) / $totalChecked) * 100, 1) } else { 100 }

Write-Host "📈 Statistics:" -ForegroundColor Yellow
Write-Host "   Directories checked: $totalChecked" -ForegroundColor White
Write-Host "   With documentation (README.md or index.md): $($existingDocs.Count)" -ForegroundColor Green
Write-Host "   Missing documentation: $missingCount" -ForegroundColor $(if ($missingCount -gt 0) { 'Red' } else { 'Green' })
Write-Host "   Documentation coverage: $coveragePercent%" -ForegroundColor $(if ($coveragePercent -lt 80) { 'Yellow' } else { 'Green' })
Write-Host ""

# Save missing docs report
if ($missingDocs.Count -gt 0) {
    $missingReportPath = Join-Path $reportDir "missing-documentation.json"
    @{ 
        missingDocs = $missingDocs.Path
        totalMissing = $missingDocs.Count 
        generatedDate = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    } | ConvertTo-Json -Depth 10 | Set-Content $missingReportPath
    Write-Host "⚠️  Saved missing documentation report: $missingReportPath" -ForegroundColor Yellow
    
    Write-Host ""
    Write-Host "📂 Directories Missing Documentation (README.md or index.md):" -ForegroundColor Yellow
    foreach ($dir in $missingDocs | Select-Object -First 15) {
        Write-Host "   • $($dir.Path) ($($dir.FileCount) files)" -ForegroundColor White
    }
    
    if ($missingDocs.Count -gt 15) {
        Write-Host "   ... and $($missingDocs.Count - 15) more" -ForegroundColor Gray
    }
    Write-Host ""
}

# Generate skeleton README files if requested
if ($GenerateSkeletons -and $missingDocs.Count -gt 0) {
    Write-Host "📝 Generating Skeleton README Files" -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host ""
    
    $generated = 0
    foreach ($dir in $missingDocs) {
        try {
            $fullPath = Join-Path $repoRoot $dir.Path
            $dirName = Split-Path $dir.Path -Leaf
            $parentDir = Split-Path $dir.Path -Parent
            
            # Determine directory purpose based on path
            $purpose = "Documentation for the $dirName directory"
            if ($dir.Path -match 'domains[\\/]([^\\\/]+)') {
                $domain = $matches[1]
                $purpose = "PowerShell modules for the $domain domain"
            } elseif ($dir.Path -match 'automation-scripts[\\/](\d+)') {
                $range = $matches[1]
                $purpose = "Automation scripts in the $range range"
            } elseif ($dir.Path -match 'tests[\\/]') {
                $purpose = "Test files for $dirName"
            } elseif ($dir.Path -match 'docs[\\/]') {
                $purpose = "Documentation for $dirName"
            }
            
            # Get list of files in directory
            $files = Get-ChildItem -Path $fullPath -File -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty Name |
                ForEach-Object { "- ``$_``" }
            
            # Generate README content
            $readmeContent = @"
# $dirName

$purpose.

## Contents

This directory contains:

$($files -join "`n")

## Usage

_TODO: Add usage instructions_

## Related

- Parent directory: [$parentDir](../)
- See main [project README](../../README.md) for overview

---

_Last updated: $(Get-Date -Format 'yyyy-MM-dd')_  
_Auto-generated skeleton - please enhance with specific details_
"@
            
            $readmePath = Join-Path $fullPath "README.md"
            $readmeContent | Set-Content $readmePath
            
            Write-Host "✅ Generated: $($dir.Path)/README.md" -ForegroundColor Green
            $generated++
        } catch {
            Write-Warning "Failed to generate README for $($dir.Path): $_"
        }
    }
    
    Write-Host ""
    Write-Host "✅ Generated $generated skeleton README files" -ForegroundColor Green
    Write-Host "📝 Please review and enhance with specific details" -ForegroundColor Yellow
    Write-Host ""
}

# Save full validation report for dashboard integration
$validationReportPath = Join-Path $reportDir "directory-documentation-validation.json"
@{
    totalDirectories = $totalChecked
    documented = $existingDocs.Count
    missingDocumentation = $missingCount
    coveragePercent = $coveragePercent
    missingDocs = $missingDocs
    existingDocs = $existingDocs
    generatedDate = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    thresholds = @{
        minCoverage = 80
        passed = $coveragePercent -ge 80
    }
} | ConvertTo-Json -Depth 10 | Set-Content $validationReportPath
Write-Host "💾 Saved validation report for dashboard: $validationReportPath" -ForegroundColor Cyan
Write-Host ""

# Exit with appropriate code
if ($CheckMissing -and $missingDocs.Count -gt 0) {
    Write-Host "❌ Found $missingCount director(ies) without README.md or index.md" -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ Directory documentation validation complete" -ForegroundColor Green
    exit 0
}
