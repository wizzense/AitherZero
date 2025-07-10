#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Final comprehensive YAML structure fix for GitHub Actions workflows
    
.DESCRIPTION
    This script performs a final comprehensive fix of YAML structure issues
    that prevent GitHub Actions workflows from parsing correctly.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$WorkflowPath = ".github/workflows"
)

function Fix-FinalYAMLStructure {
    param(
        [string]$FilePath
    )
    
    Write-Host "🔧 Processing: $(Split-Path $FilePath -Leaf)" -ForegroundColor Cyan
    
    $content = Get-Content $FilePath -Raw
    $originalContent = $content
    
    # Split into lines for detailed processing
    $lines = $content -split "`r?`n"
    $fixedLines = @()
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        
        # Critical Fix 1: Restore proper "on:" structure
        if ($line -match '^(\s*)on:\s*(.+)$' -and $matches[2] -ne '') {
            $indent = $matches[1]
            $restContent = $matches[2].Trim()
            
            # If it's not a comment, fix the structure
            if (-not $restContent.StartsWith('#')) {
                $fixedLines += "${indent}on:"
                $fixedLines += "$indent  $restContent"
                continue
            }
        }
        
        # Critical Fix 2: Restore proper "jobs:" structure  
        if ($line -match '^(\s*)jobs:\s*(.+)$' -and $matches[2] -ne '') {
            $indent = $matches[1]
            $restContent = $matches[2].Trim()
            
            # If it's not a comment, fix the structure
            if (-not $restContent.StartsWith('#')) {
                $fixedLines += "${indent}jobs:"
                $fixedLines += "$indent  $restContent"
                continue
            }
        }
        
        # Critical Fix 3: Restore proper "env:" structure
        if ($line -match '^(\s*)env:\s*([A-Z_][A-Z0-9_]*):\s*(.+)$') {
            $indent = $matches[1]
            $envName = $matches[2]
            $envValue = $matches[3]
            
            $fixedLines += "${indent}env:"
            $fixedLines += "$indent  ${envName}: $envValue"
            continue
        }
        
        # Critical Fix 4: Restore proper "permissions:" structure
        if ($line -match '^(\s*)permissions:\s*([a-z_-]+):\s*(.+)$') {
            $indent = $matches[1]
            $permName = $matches[2]
            $permValue = $matches[3]
            
            $fixedLines += "${indent}permissions:"
            $fixedLines += "$indent  ${permName}: $permValue"
            continue
        }
        
        # Critical Fix 5: Restore proper "concurrency:" structure
        if ($line -match '^(\s*)concurrency:\s*([a-z_-]+):\s*(.+)$') {
            $indent = $matches[1]
            $concurrencyName = $matches[2]
            $concurrencyValue = $matches[3]
            
            $fixedLines += "${indent}concurrency:"
            $fixedLines += "$indent  ${concurrencyName}: $concurrencyValue"
            continue
        }
        
        # Critical Fix 6: Restore proper "steps:" structure
        if ($line -match '^(\s*)steps:\s*-\s*name:\s*(.+)$') {
            $indent = $matches[1]
            $stepName = $matches[2]
            
            $fixedLines += "${indent}steps:"
            $fixedLines += "$indent  - name: $stepName"
            continue
        }
        
        # Critical Fix 7: Restore proper "with:" structure
        if ($line -match '^(\s*)with:\s*([a-zA-Z_-]+):\s*(.+)$') {
            $indent = $matches[1]
            $withName = $matches[2]
            $withValue = $matches[3]
            
            $fixedLines += "${indent}with:"
            $fixedLines += "$indent  ${withName}: $withValue"
            continue
        }
        
        # Critical Fix 8: Restore proper "outputs:" structure
        if ($line -match '^(\s*)outputs:\s*([a-zA-Z_-]+):\s*(.+)$') {
            $indent = $matches[1]
            $outputName = $matches[2]
            $outputValue = $matches[3]
            
            $fixedLines += "${indent}outputs:"
            $fixedLines += "$indent  ${outputName}: $outputValue"
            continue
        }
        
        # Critical Fix 9: Restore proper "strategy:" structure
        if ($line -match '^(\s*)strategy:\s*([a-z_-]+):\s*(.+)$') {
            $indent = $matches[1]
            $strategyName = $matches[2]
            $strategyValue = $matches[3]
            
            $fixedLines += "${indent}strategy:"
            $fixedLines += "$indent  ${strategyName}: $strategyValue"
            continue
        }
        
        # Add line as-is
        $fixedLines += $line
    }
    
    # Rejoin content
    $newContent = $fixedLines -join "`n"
    
    # Ensure proper newline at end
    if (-not $newContent.EndsWith("`n")) {
        $newContent = $newContent + "`n"
    }
    
    # Only write if changed
    if ($newContent -ne $originalContent) {
        Set-Content -Path $FilePath -Value $newContent -Encoding UTF8 -NoNewline
        Write-Host "✅ Fixed YAML structure in $(Split-Path $FilePath -Leaf)" -ForegroundColor Green
        return $true
    } else {
        Write-Host "✅ $(Split-Path $FilePath -Leaf) - structure already correct" -ForegroundColor Green
        return $true
    }
}

# Main execution
Write-Host "🔧 Final YAML Structure Fix" -ForegroundColor Cyan
Write-Host "===========================" -ForegroundColor Cyan

if (Test-Path $WorkflowPath -PathType Container) {
    $workflowFiles = Get-ChildItem -Path $WorkflowPath -Filter "*.yml" -File
} else {
    Write-Host "❌ Path not found: $WorkflowPath" -ForegroundColor Red
    exit 1
}

$totalFiles = $workflowFiles.Count
$successCount = 0

Write-Host "📁 Found $totalFiles workflow files to process" -ForegroundColor White

foreach ($file in $workflowFiles) {
    if (Fix-FinalYAMLStructure -FilePath $file.FullName) {
        $successCount++
    }
}

Write-Host "`n📊 Summary:" -ForegroundColor Cyan
Write-Host "  📁 Total files: $totalFiles" -ForegroundColor White
Write-Host "  ✅ Success: $successCount" -ForegroundColor Green

Write-Host "`n✅ Final YAML structure fix completed!" -ForegroundColor Green