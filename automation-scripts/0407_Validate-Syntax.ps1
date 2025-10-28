#Requires -Version 7.0
<#
.SYNOPSIS
    Validates PowerShell script syntax using AST parser
.DESCRIPTION
    Uses the PowerShell AST parser to validate script syntax without executing the code.
    Useful for pre-commit hooks, CI/CD pipelines, and development workflows.
.PARAMETER FilePath
    Path to the PowerShell script file to validate
.PARAMETER Detailed
    Show detailed AST information including function counts and statistics
.EXAMPLE
    ./0407_Validate-Syntax.ps1 -FilePath ./script.ps1
.EXAMPLE
    Get-ChildItem *.ps1 -Recurse | ForEach-Object { ./0407_Validate-Syntax.ps1 -FilePath $_.FullName }
.EXAMPLE
    seq 0407 -Variables @{FilePath="./domains/utilities/Logging.psm1"; Detailed=$true}
#>

# Script metadata
# Stage: Testing
# Dependencies: 0400
# Description: PowerShell syntax validation using AST parser
# Tags: testing, validation, syntax, ast, quality
param(
    [Parameter(Mandatory=$false)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$FilePath,

    [switch]$Detailed,

    # When called from CI/orchestration without FilePath, validate all PowerShell files
    [switch]$All
)

# Validate parameters: either FilePath or All must be specified
if (-not $FilePath -and -not $All) {
    throw "Either FilePath parameter or All switch must be specified"
}

try {
    # If All switch is specified, validate all PowerShell files
    if ($All) {
        Write-Host "Validating all PowerShell files..." -ForegroundColor Cyan
        $filesToValidate = @(
            Get-ChildItem -Path . -Filter "*.ps1" -Recurse -File |
                Where-Object { $_.FullName -notmatch '[\\/](\.git|node_modules|\.vscode|legacy-to-migrate|examples)[\\/]' }
        )

        Write-Host "Found $($filesToValidate.Count) PowerShell files to validate" -ForegroundColor Gray

        $totalErrors = 0
        $validatedFiles = 0

        foreach ($file in $filesToValidate) {
            $parseErrors = $null
            $tokens = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)

            if ($parseErrors -and $parseErrors.Count -gt 0) {
                Write-Host "✗ $($file.FullName -replace [regex]::Escape($PWD), '.')" -ForegroundColor Red
                foreach ($parseError in $parseErrors) {
                    Write-Host "  Line $($parseError.Extent.StartLineNumber): $($parseError.Message)" -ForegroundColor Yellow
                }
                $totalErrors += $parseErrors.Count
            } else {
                $validatedFiles++
                if ($Detailed) {
                    Write-Host "✓ $($file.FullName -replace [regex]::Escape($PWD), '.')" -ForegroundColor Green
                }
            }
        }

        Write-Host "`nValidation Complete:" -ForegroundColor Cyan
        Write-Host "  Total Files: $($filesToValidate.Count)"
        Write-Host "  Valid: $validatedFiles" -ForegroundColor Green
        Write-Host "  Errors: $totalErrors" -ForegroundColor $(if ($totalErrors -gt 0) { 'Red' } else { 'Green' })

        exit $(if ($totalErrors -gt 0) { 1 } else { 0 })
    }

    # Validate single file
    # Check if file contains only null bytes or is effectively empty/binary
    $fileContent = Get-Content -Path $FilePath -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrEmpty($fileContent) -or $fileContent -match '^\x00+$' -or $fileContent.Trim().Length -eq 0) {
        # Check if file only contains null bytes or non-text characters
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        $nullByteCount = ($bytes | Where-Object { $_ -eq 0 }).Count
        if ($nullByteCount -eq $bytes.Length -or $bytes.Length -eq 0) {
            Write-Host "Error parsing file: File appears to be empty or contains only null bytes" -ForegroundColor Red
            exit 1
        }
    }
    
    $parseErrors = $null
    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$tokens, [ref]$parseErrors)

    if ($parseErrors -and $parseErrors.Count -gt 0) {
        Write-Host "Syntax errors found in $FilePath`:" -ForegroundColor Red
        foreach ($parseError in $parseErrors) {
            Write-Host "  Line $($parseError.Extent.StartLineNumber), Column $($parseError.Extent.StartColumnNumber): $($parseError.Message)" -ForegroundColor Yellow
            if ($Detailed) {
                Write-Host "  Context: $($parseError.Extent.Text)" -ForegroundColor DarkYellow
            }
        }
        exit 1
    } else {
        Write-Host "✓ Script syntax is valid: $FilePath" -ForegroundColor Green

        if ($Detailed -and $ast) {
            Write-Host "`nScript Statistics:" -ForegroundColor Cyan
            $functions = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
            Write-Host "  Functions: $($functions.Count)"

            $commands = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)
            Write-Host "  Commands: $($commands.Count)"

            Write-Host "  Total Lines: $($ast.Extent.EndLineNumber)"
            Write-Host "  Tokens: $($tokens.Count)"
        }
        exit 0
    }
} catch {
    Write-Host "Error parsing file: $_" -ForegroundColor Red
    exit 1
}