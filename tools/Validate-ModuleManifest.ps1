#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Validates PowerShell module manifest files for common issues including Unicode characters
.DESCRIPTION
    This script validates .psd1 module manifest files for:
    - Unicode character issues that can break PowerShell restricted language parsing
    - Proper string termination
    - Encoding issues
    - PowerShell restricted language compliance
.PARAMETER Path
    Path to the .psd1 module manifest file to validate
.PARAMETER Fix
    If specified, attempts to fix common issues automatically
.EXAMPLE
    ./tools/Validate-ModuleManifest.ps1 -Path ./AitherZero.psd1
.EXAMPLE
    ./tools/Validate-ModuleManifest.ps1 -Path ./AitherZero.psd1 -Fix
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    
    [switch]$Fix
)

function Test-UnicodeCharacters {
    param([string]$Content, [string]$FilePath)
    
    $issues = @()
    $lines = $Content -split "`n"
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $lineNumber = $i + 1
        
        # Check for Unicode arrow characters that commonly cause issues
        if ($line -match '[→←↑↓]') {
            $issues += @{
                Type = 'UnicodeArrow'
                Line = $lineNumber
                Content = $line
                Message = "Line $lineNumber contains Unicode arrow characters that may cause parsing issues"
            }
        }
        
        # Check for other problematic Unicode characters
        if ($line -match '[^\x00-\x7F]') {
            # Find non-ASCII characters
            $unicodeChars = [regex]::Matches($line, '[^\x00-\x7F]') | ForEach-Object { $_.Value } | Sort-Object -Unique
            $issues += @{
                Type = 'NonAsciiCharacter'
                Line = $lineNumber
                Content = $line
                Characters = $unicodeChars
                Message = "Line $lineNumber contains non-ASCII characters: $($unicodeChars -join ', ')"
            }
        }
        
        # Check for unterminated strings
        if ($line -match "='[^']*$" -and $line -notmatch "='[^']*'") {
            $issues += @{
                Type = 'UnterminatedString'
                Line = $lineNumber
                Content = $line
                Message = "Line $lineNumber appears to have an unterminated string"
            }
        }
    }
    
    return $issues
}

function Fix-UnicodeIssues {
    param([string]$Content)
    
    # Replace common Unicode arrows with ASCII alternatives
    $fixes = @{
        [char]0x2192 = '->'  # → right arrow
        [char]0x2190 = '<-'  # ← left arrow
        [char]0x2191 = '^'   # ↑ up arrow
        [char]0x2193 = 'v'   # ↓ down arrow
        [char]0x2013 = '-'   # – en dash
        [char]0x2014 = '--'  # — em dash
        [char]0x201C = '"'   # " left double quote
        [char]0x201D = '"'   # " right double quote
        [char]0x2018 = "'"   # ' left single quote
        [char]0x2019 = "'"   # ' right single quote
    }
    
    $fixedContent = $Content
    foreach ($unicode in $fixes.Keys) {
        $replacement = $fixes[$unicode]
        $fixedContent = $fixedContent -replace [regex]::Escape($unicode), $replacement
    }
    
    return $fixedContent
}

function Test-PowerShellSyntax {
    param([string]$FilePath)
    
    try {
        # First check if it's a PowerShell module manifest or a config file
        $content = Get-Content -Path $FilePath -Raw
        
        # Check if it has module manifest properties (ModuleVersion, GUID, etc.)
        $hasModuleProperties = $content -match 'ModuleVersion\s*=' -or $content -match 'GUID\s*=' -or $content -match 'RootModule\s*='
        
        if ($hasModuleProperties) {
            # It's a module manifest - validate with Test-ModuleManifest
            $null = Test-ModuleManifest -Path $FilePath -ErrorAction Stop
        } else {
            # It's likely a configuration file - just test PowerShell syntax
            $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)
        }
        
        return $true
    } catch {
        Write-Error "PowerShell syntax validation failed: $($_.Exception.Message)"
        return $false
    }
}

# Main validation logic
try {
    if (-not (Test-Path $Path)) {
        Write-Error "File not found: $Path"
        exit 1
    }
    
    Write-Host "Validating module manifest: $Path" -ForegroundColor Cyan
    
    # Read file content
    $content = Get-Content -Path $Path -Raw -Encoding UTF8
    
    # Check for BOM issues
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        Write-Warning "File contains UTF-8 BOM which may cause issues. Consider saving without BOM."
    }
    
    # Check for Unicode issues
    $unicodeIssues = Test-UnicodeCharacters -Content $content -FilePath $Path
    
    if ($unicodeIssues.Count -gt 0) {
        Write-Host "Found $($unicodeIssues.Count) Unicode issues:" -ForegroundColor Yellow
        foreach ($issue in $unicodeIssues) {
            Write-Host "  [$($issue.Type)] $($issue.Message)" -ForegroundColor Yellow
            if ($issue.Characters) {
                Write-Host "    Characters: $($issue.Characters -join ', ')" -ForegroundColor Gray
            }
        }
        
        if ($Fix) {
            Write-Host "Attempting to fix Unicode issues..." -ForegroundColor Green
            $fixedContent = Fix-UnicodeIssues -Content $content
            
            # Create backup
            $backupPath = "$Path.bak"
            Copy-Item -Path $Path -Destination $backupPath
            Write-Host "Created backup: $backupPath" -ForegroundColor Gray
            
            # Write fixed content
            Set-Content -Path $Path -Value $fixedContent -Encoding UTF8 -NoNewline
            Write-Host "Applied fixes to: $Path" -ForegroundColor Green
            
            # Re-validate
            $newContent = Get-Content -Path $Path -Raw -Encoding UTF8
            $newIssues = Test-UnicodeCharacters -Content $newContent -FilePath $Path
            
            if ($newIssues.Count -eq 0) {
                Write-Host "✓ All Unicode issues resolved" -ForegroundColor Green
            } else {
                Write-Host "! Some issues remain after fix attempt" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "✓ No Unicode issues found" -ForegroundColor Green
    }
    
    # Test PowerShell syntax
    Write-Host "Testing PowerShell syntax..." -ForegroundColor Cyan
    if (Test-PowerShellSyntax -FilePath $Path) {
        Write-Host "✓ PowerShell syntax validation passed" -ForegroundColor Green
    } else {
        Write-Host "✗ PowerShell syntax validation failed" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Validation completed successfully!" -ForegroundColor Green
    exit 0
    
} catch {
    Write-Error "Validation failed: $($_.Exception.Message)"
    exit 1
}