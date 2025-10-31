#Requires -Version 7.0

<#
.SYNOPSIS
    Validates the config.psd1 manifest for accuracy and completeness
    
.DESCRIPTION
    Performs comprehensive validation of config.psd1 including:
    - Syntax validation (can be loaded as PowerShell data file)
    - Structure validation (all required sections present)
    - Domain/module count accuracy
    - Script inventory accuracy
    - Script reference validation
    - PSScriptAnalyzer checks
    
    Script Number: 0408
    Category: Testing & Quality
    
.PARAMETER ConfigPath
    Path to the config.psd1 file to validate
    
.PARAMETER Fix
    Attempt to automatically fix counts where possible
    
.EXAMPLE
    ./automation-scripts/0408_Validate-ConfigManifest.ps1
    
.EXAMPLE
    ./automation-scripts/0408_Validate-ConfigManifest.ps1 -Fix
    
.NOTES
    This script should be run as part of CI/CD to ensure config.psd1 stays synchronized
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ConfigPath = './config.psd1',
    
    [Parameter()]
    [switch]$Fix
)

$ErrorActionPreference = 'Stop'
$script:ValidationErrors = @()
$script:ValidationWarnings = @()

function Write-ValidationResult {
    param(
        [string]$Message,
        [ValidateSet('Success', 'Error', 'Warning', 'Info')]
        [string]$Level = 'Info'
    )
    
    $colors = @{
        'Success' = 'Green'
        'Error' = 'Red'
        'Warning' = 'Yellow'
        'Info' = 'Cyan'
    }
    
    $symbols = @{
        'Success' = '✓'
        'Error' = '✗'
        'Warning' = '⚠'
        'Info' = 'ℹ'
    }
    
    Write-Host "$($symbols[$Level]) $Message" -ForegroundColor $colors[$Level]
    
    if ($Level -eq 'Error') {
        $script:ValidationErrors += $Message
    } elseif ($Level -eq 'Warning') {
        $script:ValidationWarnings += $Message
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "     CONFIG.PSD1 MANIFEST VALIDATION" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# 1. Syntax Validation
Write-Host "1. SYNTAX VALIDATION" -ForegroundColor Yellow
try {
    $config = Import-PowerShellDataFile -Path $ConfigPath -ErrorAction Stop
    Write-ValidationResult "Config file loads successfully" -Level Success
} catch {
    Write-ValidationResult "Failed to load config file: $($_.Exception.Message)" -Level Error
    Write-Host ""
    Write-Host "Fix the syntax errors before running other validations." -ForegroundColor Red
    exit 1
}

# 2. Structure Validation
Write-Host ""
Write-Host "2. STRUCTURE VALIDATION" -ForegroundColor Yellow
$requiredSections = @('Manifest', 'Core', 'Features', 'Automation', 'UI', 'Testing', 'Development', 'AI', 'Infrastructure', 'System', 'Security', 'Reporting', 'Logging', 'Dependencies')
$missing = $requiredSections | Where-Object { -not $config.$_ }
if ($missing) {
    Write-ValidationResult "Missing sections: $($missing -join ', ')" -Level Error
} else {
    Write-ValidationResult "All $($requiredSections.Count) required sections present" -Level Success
}

# 3. Manifest Subsections
Write-Host ""
Write-Host "3. MANIFEST SUBSECTIONS" -ForegroundColor Yellow
$manifestSections = @('Name', 'Version', 'Type', 'Description', 'SupportedPlatforms', 'Domains', 'ScriptInventory', 'FeatureDependencies', 'ExecutionProfiles', 'SchemaVersion', 'LastUpdated')
$missingManifest = $manifestSections | Where-Object { -not $config.Manifest.$_ }
if ($missingManifest) {
    Write-ValidationResult "Missing Manifest sections: $($missingManifest -join ', ')" -Level Error
} else {
    Write-ValidationResult "All $($manifestSections.Count) Manifest subsections present" -Level Success
}

# 4. Domain/Module Count Validation
Write-Host ""
Write-Host "4. DOMAIN/MODULE COUNT VALIDATION" -ForegroundColor Yellow

if (Test-Path './domains') {
    $actualDomains = Get-ChildItem -Path './domains' -Directory | Sort-Object Name
    $actualModules = (Get-ChildItem -Path './domains' -Filter '*.psm1' -Recurse).Count
    $configDomains = $config.Manifest.Domains.Count
    $configModules = ($config.Manifest.Domains.Values | ForEach-Object { $_.Modules } | Measure-Object -Sum).Sum
    
    Write-Host "  Actual domains: $($actualDomains.Count)" -ForegroundColor Gray
    Write-Host "  Config domains: $configDomains" -ForegroundColor Gray
    Write-Host "  Actual modules: $actualModules" -ForegroundColor Gray
    Write-Host "  Config modules: $configModules" -ForegroundColor Gray
    
    if ($actualDomains.Count -ne $configDomains) {
        Write-ValidationResult "Domain count mismatch: actual=$($actualDomains.Count), config=$configDomains" -Level Error
    } elseif ($actualModules -ne $configModules) {
        Write-ValidationResult "Module count mismatch: actual=$actualModules, config=$configModules" -Level Error
    } else {
        Write-ValidationResult "Domain and module counts match" -Level Success
    }
} else {
    Write-ValidationResult "Domains directory not found, skipping domain validation" -Level Warning
}

# 5. Script Inventory Validation
Write-Host ""
Write-Host "5. SCRIPT INVENTORY VALIDATION" -ForegroundColor Yellow

if (Test-Path './automation-scripts') {
    $allScripts = Get-ChildItem -Path './automation-scripts' -Filter '*.ps1'
    # Filter only numbered scripts (e.g., 0100_ScriptName.ps1), exclude non-numbered helpers
    $numberedScripts = $allScripts | Where-Object { $_.Name -match '^\d{4}_' }
    $uniqueNumbers = $numberedScripts | ForEach-Object { [int]($_.Name -replace '(\d+)_.*', '$1') } | Sort-Object -Unique
    
    Write-Host "  Total script files: $($allScripts.Count)" -ForegroundColor Gray
    Write-Host "  Numbered scripts: $($numberedScripts.Count)" -ForegroundColor Gray
    Write-Host "  Unique script numbers: $($uniqueNumbers.Count)" -ForegroundColor Gray
    
    $inventorySum = ($config.Manifest.ScriptInventory.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
    Write-Host "  ScriptInventory sum: $inventorySum" -ForegroundColor Gray
    
    if ($uniqueNumbers.Count -ne $inventorySum) {
        Write-ValidationResult "Script inventory mismatch: actual=$($uniqueNumbers.Count), config=$inventorySum" -Level Error
        
        # Show detailed breakdown
        $ranges = @{
            '0000-0099' = @(0, 99)
            '0100-0199' = @(100, 199)
            '0200-0299' = @(200, 299)
            '0300-0399' = @(300, 399)
            '0400-0499' = @(400, 499)
            '0500-0599' = @(500, 599)
            '0700-0799' = @(700, 799)
            '0800-0899' = @(800, 899)
            '0900-0999' = @(900, 999)
            '9000-9999' = @(9000, 9999)
        }
        
        Write-Host ""
        Write-Host "  Detailed count comparison:" -ForegroundColor Yellow
        foreach ($range in $ranges.Keys | Sort-Object) {
            $min = $ranges[$range][0]
            $max = $ranges[$range][1]
            $actualCount = ($uniqueNumbers | Where-Object { $_ -ge $min -and $_ -le $max }).Count
            $configCount = $config.Manifest.ScriptInventory[$range].Count
            
            if ($actualCount -ne $configCount) {
                Write-Host "    $range`: actual=$actualCount, config=$configCount" -ForegroundColor Red
            } else {
                Write-Host "    $range`: $actualCount" -ForegroundColor Green
            }
        }
    } else {
        Write-ValidationResult "Script inventory count matches unique numbers" -Level Success
    }
} else {
    Write-ValidationResult "Automation scripts directory not found, skipping script validation" -Level Warning
}

# 5a. Non-Numbered Helper Scripts Validation
Write-Host ""
Write-Host "5a. NON-NUMBERED HELPER SCRIPTS VALIDATION" -ForegroundColor Yellow

if (Test-Path './automation-scripts') {
    $allScripts = Get-ChildItem -Path './automation-scripts' -Filter '*.ps1'
    $nonNumberedScripts = $allScripts | Where-Object { $_.Name -notmatch '^\d{4}_' }
    
    Write-Host "  Non-numbered helper scripts: $($nonNumberedScripts.Count)" -ForegroundColor Gray
    
    if ($nonNumberedScripts.Count -gt 0) {
        $syntaxErrors = @()
        $analyzerIssues = @()
        
        foreach ($script in $nonNumberedScripts) {
            Write-Host "    Validating: $($script.Name)" -ForegroundColor Gray
            
            # Syntax validation
            $scriptContent = Get-Content -Path $script.FullName -Raw -ErrorAction SilentlyContinue
            if ($scriptContent) {
                $syntaxCheck = [System.Management.Automation.PSParser]::Tokenize($scriptContent, [ref]$null)
                $errors = $null
                [void][System.Management.Automation.PSParser]::Tokenize($scriptContent, [ref]$errors)
                
                if ($errors -and $errors.Count -gt 0) {
                    $syntaxErrors += @{
                        Script = $script.Name
                        Errors = $errors
                    }
                }
            }
            
            # PSScriptAnalyzer check if available
            if (Get-Module -ListAvailable -Name PSScriptAnalyzer) {
                $analysis = Invoke-ScriptAnalyzer -Path $script.FullName -Severity Error,Warning -ErrorAction SilentlyContinue
                if ($analysis) {
                    $analyzerIssues += @{
                        Script = $script.Name
                        Issues = $analysis
                    }
                }
            }
        }
        
        # Report syntax errors
        if ($syntaxErrors.Count -gt 0) {
            Write-ValidationResult "Found syntax errors in $($syntaxErrors.Count) helper script(s)" -Level Error
            foreach ($item in $syntaxErrors) {
                Write-Host "    ❌ $($item.Script):" -ForegroundColor Red
                foreach ($error in $item.Errors) {
                    Write-Host "       Line $($error.Token.StartLine): $($error.Message)" -ForegroundColor Yellow
                }
            }
        } else {
            Write-ValidationResult "All helper scripts have valid syntax" -Level Success
        }
        
        # Report analyzer issues
        if ($analyzerIssues.Count -gt 0) {
            Write-Host "  ⚠️  Found PSScriptAnalyzer issues in $($analyzerIssues.Count) helper script(s):" -ForegroundColor Yellow
            foreach ($item in $analyzerIssues) {
                Write-Host "    $($item.Script):" -ForegroundColor Yellow
                foreach ($issue in $item.Issues) {
                    Write-Host "      [$($issue.Severity)] $($issue.RuleName): $($issue.Message)" -ForegroundColor Gray
                }
            }
        } else {
            Write-ValidationResult "No PSScriptAnalyzer issues in helper scripts" -Level Success
        }
    } else {
        Write-ValidationResult "No non-numbered helper scripts found" -Level Warning
    }
} else {
    Write-ValidationResult "Automation scripts directory not found" -Level Warning
}

# 6. Script Reference Validation
Write-Host ""
Write-Host "6. SCRIPT REFERENCE VALIDATION" -ForegroundColor Yellow

$allScriptRefs = @()
foreach ($category in $config.Manifest.FeatureDependencies.Keys) {
    foreach ($feature in $config.Manifest.FeatureDependencies[$category].Keys) {
        $featureData = $config.Manifest.FeatureDependencies[$category][$feature]
        if ($featureData.Scripts) {
            $allScriptRefs += $featureData.Scripts
        }
    }
}

$invalidRefs = @()
foreach ($scriptNum in $allScriptRefs | Sort-Object -Unique) {
    $pattern = "$scriptNum`_*.ps1"
    if (-not (Test-Path "./automation-scripts/$pattern")) {
        $invalidRefs += $scriptNum
    }
}

if ($invalidRefs) {
    Write-ValidationResult "Invalid script references: $($invalidRefs -join ', ')" -Level Error
} else {
    Write-ValidationResult "All $($allScriptRefs.Count) script references are valid" -Level Success
}

# 7. PSScriptAnalyzer Check
Write-Host ""
Write-Host "7. PSSCRIPTANALYZER CHECK" -ForegroundColor Yellow

if (Get-Module -ListAvailable -Name PSScriptAnalyzer) {
    $analysisResults = Invoke-ScriptAnalyzer -Path $ConfigPath -Severity Error,Warning -ErrorAction SilentlyContinue
    if ($analysisResults) {
        Write-ValidationResult "Found $($analysisResults.Count) PSScriptAnalyzer issues" -Level Error
        $analysisResults | ForEach-Object {
            Write-Host "    [$($_.Severity)] $($_.RuleName): $($_.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-ValidationResult "No PSScriptAnalyzer issues" -Level Success
    }
} else {
    Write-ValidationResult "PSScriptAnalyzer not installed, skipping analysis" -Level Warning
}

# 8. Summary
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                   VALIDATION SUMMARY" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "Manifest Information:" -ForegroundColor Cyan
Write-Host "  Name: $($config.Manifest.Name)"
Write-Host "  Version: $($config.Manifest.Version)"
Write-Host "  Schema: $($config.Manifest.SchemaVersion)"
Write-Host "  Last Updated: $($config.Manifest.LastUpdated)"
Write-Host ""

if ($script:ValidationErrors.Count -eq 0) {
    Write-Host "✅ VALIDATION PASSED - No errors found" -ForegroundColor Green
    if ($script:ValidationWarnings.Count -gt 0) {
        Write-Host ""
        Write-Host "Warnings ($($script:ValidationWarnings.Count)):" -ForegroundColor Yellow
        $script:ValidationWarnings | ForEach-Object { Write-Host "  • $_" -ForegroundColor Yellow }
    }
    exit 0
} else {
    Write-Host "❌ VALIDATION FAILED - $($script:ValidationErrors.Count) error(s) found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Errors:" -ForegroundColor Red
    $script:ValidationErrors | ForEach-Object { Write-Host "  • $_" -ForegroundColor Red }
    
    if ($script:ValidationWarnings.Count -gt 0) {
        Write-Host ""
        Write-Host "Warnings ($($script:ValidationWarnings.Count)):" -ForegroundColor Yellow
        $script:ValidationWarnings | ForEach-Object { Write-Host "  • $_" -ForegroundColor Yellow }
    }
    
    Write-Host ""
    Write-Host "To fix these issues:" -ForegroundColor Cyan
    Write-Host "  1. Update the config.psd1 file to match actual repository state" -ForegroundColor White
    Write-Host "  2. Run this script again to verify" -ForegroundColor White
    Write-Host "  3. Or use: ./automation-scripts/0413_Validate-ConfigManifest.ps1 -Fix (if available)" -ForegroundColor White
    
    exit 1
}
