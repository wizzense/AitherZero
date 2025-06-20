#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive validation of PowerShell modules and syntax

.DESCRIPTION
    Performs comprehensive validation including:
    - Module import testing
    - PowerShell syntax validation
    - Emoji usage detection
    - Cross-platform compatibility checks

.PARAMETER DryRun
    Run validation without making changes

.PARAMETER Path
    Path to validate (defaults to PROJECT_ROOT)

.EXAMPLE
    Invoke-ComprehensiveValidation

.EXAMPLE
    Invoke-ComprehensiveValidation -DryRun -Path "C:\MyProject"
#>

function Invoke-ComprehensiveValidation {
    [CmdletBinding()]
    param(
        [switch]$DryRun,

        [Parameter()]
        [string]$Path = $env:PROJECT_ROOT
    )

    try {
        # Function for logging
        function Write-PatchLog {
            param([string]$Message, [string]$Level = "INFO")
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
            $color = switch ($Level) {
                "ERROR" { "Red" }
                "WARN" { "Yellow" }
                "SUCCESS" { "Green" }
                default { "White" }
            }
            Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
        }

        Write-PatchLog "Running module import validation..." -Level "INFO"

        # Test module imports
        $modules = @("LabRunner", "PatchManager", "DevEnvironment", "BackupManager")
        $failedModules = @()

        foreach ($module in $modules) {
            try {
                $modulePath = "$Path/core-runner/modules/$module"
                if (Test-Path $modulePath) {
                    Import-Module $modulePath -Force -ErrorAction Stop
                    Write-PatchLog "✅ Module $module imported successfully" -Level "INFO"
                } else {
                    $failedModules += "$module (path not found)"
                }
            }
            catch {
                $failedModules += "$module ($($_.Exception.Message))"
            }
        }

        # Run syntax validation
        Write-PatchLog "Running PowerShell syntax validation..." -Level "INFO"
        $syntaxErrors = @()

        $psFiles = Get-ChildItem -Path $Path -Filter "*.ps1" -Recurse | Where-Object {
            $_.FullName -notmatch "\\\\archive\\\\" -and $_.FullName -notmatch "\\\\backup"
        }

        foreach ($file in $psFiles) {
            try {
                $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $file.FullName -Raw), [ref]$null)
                Write-PatchLog "✅ Syntax OK: $($file.Name)" -Level "INFO"
            }
            catch {
                $syntaxErrors += "$($file.Name): $($_.Exception.Message)"
            }
        }

        # Check for emoji usage
        Write-PatchLog "Checking for emoji usage..." -Level "INFO"
        $emojiFiles = @()

        # Use a simpler approach to detect common emoji patterns
        $emojiPatterns = @(
            '[\u2600-\u26FF]',  # Miscellaneous Symbols
            '[\u2700-\u27BF]',  # Dingbats
            '[\uD83C-\uD83E]',  # Surrogate pairs for emoji
            '[\u1F300-\u1F5FF]', # Miscellaneous Symbols and Pictographs (in BMP)
            '[\u1F600-\u1F64F]', # Emoticons (in BMP)
            '[\u1F680-\u1F6FF]', # Transport and Map Symbols
            '[\u1F700-\u1F77F]', # Alchemical Symbols
            '[😀-🙏]',           # Direct character ranges
            '[🌀-🗿]',           # Direct character ranges
            '[🚀-🛿]',           # Direct character ranges
            '[🤀-🧿]'            # Direct character ranges
        )

        foreach ($file in $psFiles) {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if ($content) {
                foreach ($pattern in $emojiPatterns) {
                    try {
                        if ($content -match $pattern) {
                            $emojiFiles += $file.Name
                            break
                        }
                    }
                    catch {
                        # Skip problematic patterns
                        continue
                    }
                }
            }
        }

        # Compile results with detailed information
        $issues = @()
        $validationResults = @{
            ModuleImportFailures = $failedModules
            SyntaxErrors = $syntaxErrors
            EmojiUsageFiles = $emojiFiles
            ModulesTestedCount = $modules.Count
            FilesTestedCount = $psFiles.Count
            ValidationTimestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC'
        }

        if ($failedModules.Count -gt 0) {
            $issues += "Failed module imports: $($failedModules -join ', ')"
        }
        if ($syntaxErrors.Count -gt 0) {
            $issues += "Syntax errors: $($syntaxErrors -join ', ')"
        }
        if ($emojiFiles.Count -gt 0) {
            $issues += "Emoji usage detected: $($emojiFiles -join ', ')"
        }

        if ($issues.Count -eq 0) {
            return @{
                Success = $true
                Message = "All validation checks passed"
                ValidationResults = $validationResults
            }
        } else {
            return @{
                Success = $false
                Message = "Validation issues: $($issues -join '; ')"
                ValidationResults = $validationResults
            }
        }
    }
    catch {
        return @{
            Success = $false
            Message = "Validation failed: $($_.Exception.Message)"
            ValidationResults = @{
                ValidationError = $_.Exception.Message
                ValidationTimestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC'
            }
        }
    }
}
