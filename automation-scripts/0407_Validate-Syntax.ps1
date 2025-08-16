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
    [Parameter()]
    [string]$FilePath,
    
    [string]$Path,  # Alternative parameter name used by orchestration
    
    [switch]$Detailed,
    
    [switch]$All  # Validate all PowerShell files in project
)

try {
    # Handle different parameter scenarios
    if ($All -or (-not $FilePath -and -not $Path)) {
        # Validate all PowerShell files in project
        Write-Host "Validating all PowerShell files in project..." -ForegroundColor Cyan
        $projectRoot = Split-Path $PSScriptRoot -Parent
        $files = Get-ChildItem -Path $projectRoot -Recurse -Include "*.ps1","*.psm1","*.psd1" | 
                 Where-Object { 
                     $_.FullName -notmatch '[/\\](\.git|node_modules|temp|logs|output|legacy-to-migrate)[/\\]'
                 }
        
        $hasErrors = $false
        $validCount = 0
        $errorCount = 0
        
        foreach ($file in $files) {
            $parseErrors = $null
            $tokens = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
            
            if ($parseErrors -and $parseErrors.Count -gt 0) {
                Write-Host "✗ $($file.FullName -replace [regex]::Escape($projectRoot), '.')" -ForegroundColor Red
                foreach ($parseError in $parseErrors) {
                    Write-Host "  Line $($parseError.Extent.StartLineNumber): $($parseError.Message)" -ForegroundColor Yellow
                }
                $errorCount++
                $hasErrors = $true
            } else {
                $validCount++
                if ($Detailed) {
                    Write-Host "✓ $($file.FullName -replace [regex]::Escape($projectRoot), '.')" -ForegroundColor Green
                }
            }
        }
        
        Write-Host "`nSyntax Validation Summary:" -ForegroundColor Cyan
        Write-Host "  Total files: $($files.Count)" -ForegroundColor White
        Write-Host "  Valid: $validCount" -ForegroundColor Green
        Write-Host "  Errors: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { 'Red' } else { 'Green' })
        
        if ($hasErrors) {
            exit 1
        }
        exit 0
    }
    
    # Use FilePath or Path parameter
    $targetFile = if ($FilePath) { $FilePath } elseif ($Path) { $Path } else { $null }
    
    if (-not $targetFile) {
        Write-Host "No file specified. Use -FilePath, -Path, or -All parameter." -ForegroundColor Yellow
        Write-Host "Examples:" -ForegroundColor Gray
        Write-Host "  ./0407_Validate-Syntax.ps1 -FilePath ./script.ps1" -ForegroundColor Gray
        Write-Host "  ./0407_Validate-Syntax.ps1 -All" -ForegroundColor Gray
        Write-Host "  az 0407 -All" -ForegroundColor Gray
        exit 0
    }
    
    if (-not (Test-Path $targetFile -PathType Leaf)) {
        Write-Host "File not found: $targetFile" -ForegroundColor Red
        exit 1
    }
    
    $parseErrors = $null
    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($targetFile, [ref]$tokens, [ref]$parseErrors)

    if ($parseErrors -and $parseErrors.Count -gt 0) {
        Write-Host "Syntax errors found in $targetFile`:" -ForegroundColor Red
        foreach ($parseError in $parseErrors) {
            Write-Host "  Line $($parseError.Extent.StartLineNumber), Column $($parseError.Extent.StartColumnNumber): $($parseError.Message)" -ForegroundColor Yellow
            if ($Detailed) {
                Write-Host "  Context: $($parseError.Extent.Text)" -ForegroundColor DarkYellow
            }
        }
        exit 1
    } else {
        Write-Host "✓ Script syntax is valid: $targetFile" -ForegroundColor Green

        if ($Detailed -and $ast) {
            Write-Host "`nScript Statistics:" -ForegroundColor Cyan
            $functions = $ast.FindAll({ $arguments[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
            Write-Host "  Functions: $($functions.Count)"

            $commands = $ast.FindAll({ $arguments[0] -is [System.Management.Automation.Language.CommandAst] }, $true)
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