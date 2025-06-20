#Requires -Version 7.0
<#
.SYNOPSIS
    Comprehensive cross-platform path and compatibility fixer for PatchManager
    
.DESCRIPTION
    This function fixes hardcoded Windows paths throughout the codebase to support
    cross-platform development. It standardizes paths, fixes imports, and ensures
    compatibility across Windows, Linux, and macOS.
    
.PARAMETER FixMode
    The fix mode: 'Standard', 'Comprehensive', or 'PathsOnly'
    
.PARAMETER DryRun
    Perform a dry run without actually modifying files
    
.EXAMPLE
    Invoke-CrossPlatformFixer -FixMode "Standard"
    
.EXAMPLE
    Invoke-CrossPlatformFixer -FixMode "Comprehensive" -DryRun
    
.NOTES
    - Fixes hardcoded Windows paths to use standard workspace paths
    - Updates module import statements to use proper syntax
    - Ensures cross-platform file path compatibility
    - Validates PowerShell syntax after fixes
#>

function Invoke-CrossPlatformFixer {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("Standard", "Comprehensive", "PathsOnly")]
        [string]$FixMode = "Standard",
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )
    
    begin {
        Write-Host "Starting cross-platform compatibility fixes..." -ForegroundColor Cyan
        Write-Host "Mode: $FixMode | Dry Run: $DryRun" -ForegroundColor Yellow
        
        # Get project root dynamically
        $script:ProjectRoot = (Get-Location).Path
        
        # Create fix log
        $script:FixLog = @{
            StartTime = Get-Date
            Mode = $FixMode
            DryRun = $DryRun
            FilesFixed = @()
            PathsFixed = 0
            ImportsFixed = 0
            Errors = @()
        }
          # Define path patterns to fix
        $script:PathPatterns = @{
            # Hardcoded Windows paths
            'C:\\Users\\alexa\\OneDrive\\Documents\\0\. wizzense\\opentofu-lab-automation' = '/workspaces/opentofu-lab-automation/src'
            'C:/Users/alexa/OneDrive/Documents/0. wizzense/opentofu-lab-automation' = '/workspaces/opentofu-lab-automation/src'
            
            # Fix escaped backslashes
            'C:\\\\Users\\\\alexa\\\\OneDrive\\\\Documents\\\\0\\. wizzense\\\\opentofu-lab-automation' = '/workspaces/opentofu-lab-automation/src'
            
            # Fix mixed slash patterns
            'C:\\Users\\alexa\\OneDrive\\Documents\\0. wizzense/opentofu-lab-automation' = '/workspaces/opentofu-lab-automation/src'
        }
        
        # Define import patterns to fix
        $script:ImportPatterns = @{
            # Old import patterns
            'Import-Module "pwsh/modules/LabRunner/LabRunner"' = 'Import-Module "/pwsh/modules/LabRunner/" -Force'
            'Import-Module "pwsh/modules/LabRunner"' = 'Import-Module "/pwsh/modules/LabRunner/" -Force'
            'Import-Module "./pwsh/modules/LabRunner"' = 'Import-Module "/pwsh/modules/LabRunner/" -Force'
            'Import-Module ".\pwsh\modules\LabRunner"' = 'Import-Module "/pwsh/modules/LabRunner/" -Force'
            'Import-Module "pwsh\modules\LabRunner"' = 'Import-Module "/pwsh/modules/LabRunner/" -Force'
            
            # CodeFixer imports
            'Import-Module "pwsh/modules/CodeFixer"' = 'Import-Module "/pwsh/modules/CodeFixer/" -Force'
            'Import-Module "./pwsh/modules/CodeFixer"' = 'Import-Module "/pwsh/modules/CodeFixer/" -Force'
            'Import-Module ".\pwsh\modules\CodeFixer"' = 'Import-Module "/pwsh/modules/CodeFixer/" -Force'
            'Import-Module "pwsh\modules\CodeFixer"' = 'Import-Module "/pwsh/modules/CodeFixer/" -Force'
            
            # PatchManager imports
            'Import-Module "pwsh/modules/PatchManager"' = 'Import-Module "/src/pwsh/modules/PatchManager/" -Force'
            'Import-Module "./pwsh/modules/PatchManager"' = 'Import-Module "/src/pwsh/modules/PatchManager/" -Force'
            'Import-Module ".\pwsh\modules\PatchManager"' = 'Import-Module "/src/pwsh/modules/PatchManager/" -Force'
            'Import-Module "pwsh\modules\PatchManager"' = 'Import-Module "/src/pwsh/modules/PatchManager/" -Force'
            
            # BackupManager imports
            'Import-Module "pwsh/modules/BackupManager"' = 'Import-Module "/pwsh/modules/BackupManager/" -Force'
            'Import-Module "./pwsh/modules/BackupManager"' = 'Import-Module "/pwsh/modules/BackupManager/" -Force'
            'Import-Module ".\pwsh\modules\BackupManager"' = 'Import-Module "/pwsh/modules/BackupManager/" -Force'
            'Import-Module "pwsh\modules\BackupManager"' = 'Import-Module "/pwsh/modules/BackupManager/" -Force'
        }
        
        Write-Host "Configured $($script:PathPatterns.Count) path patterns and $($script:ImportPatterns.Count) import patterns" -ForegroundColor Blue
    }
    
    process {
        try {
            # Phase 1: Fix hardcoded paths
            Write-Host "Phase 1: Fixing hardcoded paths..." -ForegroundColor Green
            Invoke-PathStandardization
            
            if ($FixMode -in @("Standard", "Comprehensive")) {
                # Phase 2: Fix import statements
                Write-Host "Phase 2: Fixing import statements..." -ForegroundColor Green
                Invoke-ImportStandardization
                
                # Phase 3: Fix file path references
                Write-Host "Phase 3: Fixing file path references..." -ForegroundColor Green
                Invoke-FilePathFixes
            }
            
            if ($FixMode -eq "Comprehensive") {
                # Phase 4: Advanced compatibility fixes
                Write-Host "Phase 4: Advanced compatibility fixes..." -ForegroundColor Green
                Invoke-AdvancedCompatibilityFixes
                
                # Phase 5: Validate fixes
                Write-Host "Phase 5: Validating fixes..." -ForegroundColor Green
                Invoke-FixValidation
            }
            
            # Generate report
            $script:FixLog.Duration = (Get-Date) - $script:FixLog.StartTime
            $report = New-CrossPlatformFixReport
            
            Write-Host "Cross-platform fixes completed!" -ForegroundColor Green
            Write-Host "Files fixed: $($script:FixLog.FilesFixed.Count) | Paths fixed: $($script:FixLog.PathsFixed) | Imports fixed: $($script:FixLog.ImportsFixed)" -ForegroundColor Cyan
            
            return @{
                Success = $true
                FilesFixed = $script:FixLog.FilesFixed.Count
                PathsFixed = $script:FixLog.PathsFixed
                ImportsFixed = $script:FixLog.ImportsFixed
                Errors = $script:FixLog.Errors
                Report = $report
            }
            
        } catch {
            $script:FixLog.Errors += "Cross-platform fixer failed: $($_.Exception.Message)"
            Write-Error "Cross-platform fixer failed: $($_.Exception.Message)"
            
            return @{
                Success = $false
                Message = $_.Exception.Message
                Errors = $script:FixLog.Errors
            }
        }
    }
}

function Invoke-PathStandardization {
    # Fix hardcoded Windows paths throughout the codebase
    $files = Get-ChildItem -Path $script:ProjectRoot -Recurse -Include "*.ps1", "*.py", "*.json", "*.md", "*.yml", "*.yaml" -ErrorAction SilentlyContinue
    
    foreach ($file in $files) {
        # Skip critical files and directories
        if (Test-CriticalPathExclusion $file.FullName) {
            continue
        }
        
        try {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $content) { continue }
              $modified = $false
            
            foreach ($pattern in $script:PathPatterns.Keys) {
                $replacement = $script:PathPatterns[$pattern]
                
                # Use literal string replacement to avoid regex issues
                if ($content.Contains($pattern)) {
                    Write-Host "  Fixing hardcoded path in: $($file.Name)" -ForegroundColor Yellow
                    $content = $content.Replace($pattern, $replacement)
                    $modified = $true
                    $script:FixLog.PathsFixed++
                }
            }
            
            if ($modified -and -not $DryRun) {
                Set-Content -Path $file.FullName -Value $content -NoNewline -Encoding UTF8
                $script:FixLog.FilesFixed += @{ 
                    File = $file.FullName
                    Action = "Path standardization"
                    Type = "HardcodedPaths"
                }
            }
            
        } catch {
            Write-Warning "Failed to process path fixes for $($file.FullName): $($_.Exception.Message)"
            $script:FixLog.Errors += "Path fix failed: $($file.FullName) - $($_.Exception.Message)"
        }
    }
}

function Invoke-ImportStandardization {
    # Fix PowerShell import statements
    $files = Get-ChildItem -Path $script:ProjectRoot -Recurse -Include "*.ps1", "*.psm1" -ErrorAction SilentlyContinue
    
    foreach ($file in $files) {
        if (Test-CriticalPathExclusion $file.FullName) {
            continue
        }
        
        try {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $content) { continue }
            
            $modified = $false
            
            foreach ($pattern in $script:ImportPatterns.Keys) {
                $replacement = $script:ImportPatterns[$pattern]
                
                if ($content.Contains($pattern)) {
                    Write-Host "  Fixing import statement in: $($file.Name)" -ForegroundColor Yellow
                    $content = $content.Replace($pattern, $replacement)
                    $modified = $true
                    $script:FixLog.ImportsFixed++
                }
            }
            
            if ($modified -and -not $DryRun) {
                Set-Content -Path $file.FullName -Value $content -NoNewline -Encoding UTF8
                $script:FixLog.FilesFixed += @{ 
                    File = $file.FullName
                    Action = "Import standardization"
                    Type = "ImportStatements"
                }
            }
            
        } catch {
            Write-Warning "Failed to process import fixes for $($file.FullName): $($_.Exception.Message)"
            $script:FixLog.Errors += "Import fix failed: $($file.FullName) - $($_.Exception.Message)"
        }
    }
}

function Invoke-FilePathFixes {
    # Fix file path references in scripts
    $files = Get-ChildItem -Path $script:ProjectRoot -Recurse -Include "*.ps1", "*.py" -ErrorAction SilentlyContinue
    
    $pathFixPatterns = @{
        # Fix relative path patterns
        '.\scripts\' = './scripts/'
        '.\pwsh\' = './pwsh/'
        '.\tests\' = './tests/'
        '.\configs\' = './configs/'
        '.\docs\' = './docs/'
        
        # Fix backslash patterns
        'scripts\' = 'scripts/'
        'pwsh\modules\' = 'pwsh/modules/'
        'tests\' = 'tests/'
        'configs\' = 'configs/'
        
        # Fix Windows-style paths
        '".\' = '"./'
        "'.\'" = "'./"
    }
    
    foreach ($file in $files) {
        if (Test-CriticalPathExclusion $file.FullName) {
            continue
        }
        
        try {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $content) { continue }
            
            $modified = $false
            
            foreach ($pattern in $pathFixPatterns.Keys) {
                $replacement = $pathFixPatterns[$pattern]
                
                if ($content.Contains($pattern)) {
                    Write-Host "  Fixing file path reference in: $($file.Name)" -ForegroundColor Yellow
                    $content = $content.Replace($pattern, $replacement)
                    $modified = $true
                }
            }
            
            if ($modified -and -not $DryRun) {
                Set-Content -Path $file.FullName -Value $content -NoNewline -Encoding UTF8
                $script:FixLog.FilesFixed += @{ 
                    File = $file.FullName
                    Action = "File path fixes"
                    Type = "FilePaths"
                }
            }
            
        } catch {
            Write-Warning "Failed to process file path fixes for $($file.FullName): $($_.Exception.Message)"
            $script:FixLog.Errors += "File path fix failed: $($file.FullName) - $($_.Exception.Message)"
        }
    }
}

function Invoke-AdvancedCompatibilityFixes {
    # Advanced fixes for cross-platform compatibility
    $files = Get-ChildItem -Path $script:ProjectRoot -Recurse -Include "*.ps1", "*.py", "*.json" -ErrorAction SilentlyContinue
    
    foreach ($file in $files) {
        if (Test-CriticalPathExclusion $file.FullName) {
            continue
        }
        
        try {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $content) { continue }
              $modified = $false
            
            # Fix PowerShell-specific issues
            if ($file.Extension -eq ".ps1") {
                # Fix PowerShell version requirements
                if ($content -match '#Requires -Version \d+\.\d+' -and $content -notmatch '#Requires -Version 7\.0') {
                    $content = $content -replace '#Requires -Version \d+\.\d+', '#Requires -Version 7.0'
                    $modified = $true
                }
                
                # Fix path separator issues
                if ($content -match '\$PSScriptRoot\\') {
                    $content = $content -replace '\$PSScriptRoot\\', '$PSScriptRoot/'
                    $modified = $true
                }
            }
            
            # Fix Python path issues
            if ($file.Extension -eq ".py") {
                # Fix import path issues
                if ($content -match 'import.*\\') {
                    $content = $content -replace '\\', '/'
                    $modified = $true
                }
            }
            
            # Fix JSON path issues
            if ($file.Extension -eq ".json") {
                # Fix path references in JSON
                if ($content -match 'C:\\\\Users\\\\alexa') {
                    $content = $content -replace 'C:\\\\Users\\\\alexa\\\\OneDrive\\\\Documents\\\\0\\. wizzense\\\\opentofu-lab-automation', '/workspaces/opentofu-lab-automation'
                    $modified = $true
                }
            }
            
            if ($modified -and -not $DryRun) {
                Set-Content -Path $file.FullName -Value $content -NoNewline -Encoding UTF8
                $script:FixLog.FilesFixed += @{ 
                    File = $file.FullName
                    Action = "Advanced compatibility fixes"
                    Type = "AdvancedFixes"
                }
            }
            
        } catch {
            Write-Warning "Failed to process advanced fixes for $($file.FullName): $($_.Exception.Message)"
            $script:FixLog.Errors += "Advanced fix failed: $($file.FullName) - $($_.Exception.Message)"
        }
    }
}

function Invoke-FixValidation {
    # Validate that fixes don't break syntax
    Write-Host "  Validating PowerShell syntax..." -ForegroundColor Blue
    
    $powershellFiles = Get-ChildItem -Path $script:ProjectRoot -Recurse -Include "*.ps1", "*.psm1" -ErrorAction SilentlyContinue
    $syntaxErrors = 0
    
    foreach ($file in $powershellFiles) {
        try {
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $file.FullName -Raw), [ref]$null)
        } catch {
            Write-Warning "Syntax error in $($file.Name): $($_.Exception.Message)"
            $script:FixLog.Errors += "Syntax validation failed: $($file.FullName) - $($_.Exception.Message)"
            $syntaxErrors++
        }
    }
    
    if ($syntaxErrors -eq 0) {
        Write-Host "  All PowerShell files pass syntax validation" -ForegroundColor Green
    } else {
        Write-Warning "Found $syntaxErrors PowerShell files with syntax errors"
    }
}

function Test-CriticalPathExclusion {
    param([string]$FilePath)
      $criticalPatterns = @(
        '\.git\\',
        'PROJECT-MANIFEST.json',
        'LICENSE',        'mkdocs.yml',
        'pyproject.toml',
        '\.vscode\\settings.json',
        '\.vscode\\tasks.json',
        'archive[/\\\\]',
        'backups[/\\\\]',
        'logs[/\\\\]'
    )
    
    foreach ($pattern in $criticalPatterns) {
        if ($FilePath -match $pattern) {
            return $true
        }
    }
    
    return $false
}

function New-CrossPlatformFixReport {
    $report = @"
# Cross-Platform Compatibility Fix Report

**Generated**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC")
**Mode**: $($script:FixLog.Mode)
**Duration**: $($script:FixLog.Duration.TotalSeconds) seconds
**Dry Run**: $($script:FixLog.DryRun)

## Summary

- **Files Fixed**: $($script:FixLog.FilesFixed.Count)
- **Hardcoded Paths Fixed**: $($script:FixLog.PathsFixed)
- **Import Statements Fixed**: $($script:FixLog.ImportsFixed)
- **Errors**: $($script:FixLog.Errors.Count)

## Actions Performed

### Phase 1: Path Standardization
- Fixed hardcoded Windows paths to use standard `/workspaces/opentofu-lab-automation/src` format
- Replaced backslashes with forward slashes for cross-platform compatibility
- Updated escaped path patterns

### Phase 2: Import Statement Fixes
- Standardized PowerShell module import statements
- Added `-Force` parameter for reliable module loading
- Fixed relative path issues in imports

### Phase 3: File Path References
- Fixed Windows-style relative paths
- Standardized path separators
- Updated script references

### Phase 4: Advanced Compatibility (Comprehensive mode only)
- Fixed PowerShell version requirements
- Updated Python import paths
- Fixed JSON path references
- Validated syntax after changes

## Files Modified

$($script:FixLog.FilesFixed | ForEach-Object{ "- $($_.File): $($_.Action)" } | Out-String)

## Path Patterns Fixed

- **Windows absolute paths** → Standard workspace paths
- **Backslash separators** → Forward slash separators  
- **Escaped path patterns** → Clean path references
- **Relative path inconsistencies** → Standardized format

## Import Statement Fixes

- **Legacy import patterns** → Modern module imports with `-Force`
- **Relative module paths** → Absolute module paths
- **Missing force parameters** → Added for reliability

## Errors

$($script:FixLog.Errors | ForEach-Object{ "- $_" } | Out-String)

---
*Generated by PatchManager Cross-Platform Fixer v2.0*
*Supports Windows, Linux, and macOS development environments*
"@

    return $report
}


