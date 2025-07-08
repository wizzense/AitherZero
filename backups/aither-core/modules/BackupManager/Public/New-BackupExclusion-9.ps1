<#
.SYNOPSIS
Creates and updates backup exclusion rules in configuration files

.DESCRIPTION
This function manages backup exclusion patterns across various configuration files
to prevent backup files from being included in version control, linting, and testing.
Supports .gitignore, PSScriptAnalyzer settings, and Pester configuration.

.PARAMETER ProjectRoot
The root directory of the project (default: auto-detected)

.PARAMETER Patterns
Additional patterns to add to exclusion rules

.PARAMETER ConfigFiles
Specific configuration files to update (default: all supported)

.PARAMETER Force
Update files without confirmation

.EXAMPLE
New-BackupExclusion -ProjectRoot "."

.EXAMPLE
New-BackupExclusion -ProjectRoot "." -Patterns @("*.temp", "*.cache") -Force

.EXAMPLE
New-BackupExclusion -ConfigFiles @(".gitignore") -Patterns @("*.custom-backup")

.NOTES
Integrates with AitherZero project structure and follows best practices
#>
function New-BackupExclusion {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string]$ProjectRoot,

        [Parameter()]
        [string[]]$Patterns = @(),

        [Parameter()]
        [ValidateSet(".gitignore", "PSScriptAnalyzer", "Pester", "All")]
        [string[]]$ConfigFiles = @("All"),

        [Parameter()]
        [switch]$Force
    )

    $ErrorActionPreference = "Stop"

    try {
        # Import shared utilities and detect project root
        if (-not $ProjectRoot) {
            . "$PSScriptRoot/../../../shared/Find-ProjectRoot.ps1"
            $ProjectRoot = Find-ProjectRoot
        } else {
            $ProjectRoot = Resolve-Path $ProjectRoot -ErrorAction Stop
        }

        # Import logging if available
        $loggingPath = Join-Path $ProjectRoot "aither-core/modules/Logging"
        if (Test-Path $loggingPath) {
            Import-Module $loggingPath -Force -ErrorAction SilentlyContinue
            Write-CustomLog "Creating backup exclusion rules" -Level INFO
        } else {
            Write-Host "INFO Creating backup exclusion rules" -ForegroundColor Green
        }

        # Define default backup exclusion patterns
        $defaultPatterns = @(
            # Standard backup patterns
            "*.bak",
            "*.backup",
            "*.old",
            "*.orig",
            "*~",
            "*.backup.*",
            "*backup*",
            "*-backup-*",
            "*.bak.*",

            # Duplicate and problematic files
            "*mega-consolidated*.yml.bak",
            "*mega-consolidated-fixed-backup*",
            "*.ps1.bak.bak",
            "*.backup.backup",
            "*-backup-*-backup*",

            # Temporary files
            "*.tmp.*",
            "*.cache.*",
            "*.lock.*",
            "*.partial",
            "*.corrupt",
            "*.incomplete",

            # OS generated files
            "Thumbs.db",
            ".DS_Store",
            "desktop.ini",

            # Legacy files
            "*-deprecated-*",
            "*-legacy-*",
            "*-old-*",

            # Test artifacts
            "TestResults*.xml.bak",
            "coverage*.xml.old",
            "*.test.log",

            # Configuration backups
            "*.config.backup",
            "*.json.orig",
            "*.yaml.bak",

            # Consolidated backup directories
            "backups/",
            "archive/",
            "**/consolidated-backups/**"
        )

        # Combine with additional patterns
        $allPatterns = $defaultPatterns + $Patterns | Sort-Object -Unique

        $results = @{
            UpdatedFiles = @()
            Errors = @()
            ExclusionsUpdated = 0
        }

        # Process each configuration file type
        if ($ConfigFiles -contains "All" -or $ConfigFiles -contains ".gitignore") {
            $gitignoreResult = Update-GitignoreFile -ProjectRoot $ProjectRoot -Patterns $allPatterns -Force:$Force
            if ($gitignoreResult.Success) {
                $results.UpdatedFiles += $gitignoreResult.FilePath
                $results.ExclusionsUpdated += $gitignoreResult.PatternsAdded
            } else {
                $results.Errors += $gitignoreResult.Error
            }
        }

        if ($ConfigFiles -contains "All" -or $ConfigFiles -contains "PSScriptAnalyzer") {
            $psaResult = Update-PSScriptAnalyzerSettings -ProjectRoot $ProjectRoot -Patterns $allPatterns -Force:$Force
            if ($psaResult.Success) {
                $results.UpdatedFiles += $psaResult.FilePath
                $results.ExclusionsUpdated += $psaResult.PatternsAdded
            } else {
                $results.Errors += $psaResult.Error
            }
        }

        if ($ConfigFiles -contains "All" -or $ConfigFiles -contains "Pester") {
            $pesterResult = Update-PesterConfig -ProjectRoot $ProjectRoot -Patterns $allPatterns -Force:$Force
            if ($pesterResult.Success) {
                $results.UpdatedFiles += $pesterResult.FilePath
                $results.ExclusionsUpdated += $pesterResult.PatternsAdded
            } else {
                $results.Errors += $pesterResult.Error
            }
        }

        # Log results
        $successMessage = "Backup exclusion rules updated: $($results.UpdatedFiles.Count) files, $($results.ExclusionsUpdated) patterns added"
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog $successMessage -Level SUCCESS
        } else {
            Write-Host "SUCCESS $successMessage" -ForegroundColor Green
        }

        if ($results.Errors.Count -gt 0) {
            foreach ($error in $results.Errors) {
                if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                    Write-CustomLog $error -Level WARN
                } else {
                    Write-Warning $error
                }
            }
        }

        return $results

    } catch {
        $errorMessage = "Failed to create backup exclusions: $($_.Exception.Message)"

        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog $errorMessage -Level ERROR
        } else {
            Write-Error $errorMessage
        }

        throw
    }
}

function Update-GitignoreFile {
    [CmdletBinding()]
    param(
        [string]$ProjectRoot,
        [string[]]$Patterns,
        [switch]$Force
    )

    try {
        $gitignorePath = Join-Path $ProjectRoot ".gitignore"
        $sectionHeader = "# Backup files (managed by BackupManager)"
        $sectionFooter = "# End backup files section"

        # Read existing content or create new
        $content = if (Test-Path $gitignorePath) {
            Get-Content $gitignorePath -ErrorAction Stop
        } else {
            @()
        }

        # Check if section already exists
        $headerIndex = $content.IndexOf($sectionHeader)
        $footerIndex = $content.IndexOf($sectionFooter)

        $newContent = @()
        $patternsAdded = 0

        if ($headerIndex -ge 0 -and $footerIndex -gt $headerIndex) {
            # Replace existing section
            $newContent += $content[0..($headerIndex-1)]
            $newContent += $sectionHeader
            foreach ($pattern in $Patterns) {
                $newContent += $pattern
                $patternsAdded++
            }
            $newContent += $sectionFooter
            if ($footerIndex + 1 -lt $content.Count) {
                $newContent += $content[($footerIndex+1)..($content.Count-1)]
            }
        } else {
            # Add new section
            $newContent = $content
            if ($newContent.Count -gt 0 -and $newContent[-1] -ne "") {
                $newContent += ""
            }
            $newContent += $sectionHeader
            foreach ($pattern in $Patterns) {
                $newContent += $pattern
                $patternsAdded++
            }
            $newContent += $sectionFooter
        }

        # Write updated content
        Set-Content -Path $gitignorePath -Value $newContent -Encoding UTF8

        return @{
            Success = $true
            FilePath = $gitignorePath
            PatternsAdded = $patternsAdded
        }

    } catch {
        return @{
            Success = $false
            Error = "Failed to update .gitignore: $($_.Exception.Message)"
            PatternsAdded = 0
        }
    }
}

function Update-PSScriptAnalyzerSettings {
    [CmdletBinding()]
    param(
        [string]$ProjectRoot,
        [string[]]$Patterns,
        [switch]$Force
    )

    try {
        $psaPath = Join-Path $ProjectRoot ".PSScriptAnalyzerSettings.psd1"

        # Basic PSScriptAnalyzer settings with backup exclusions
        $psaContent = @"
@{
    # Include default rules
    IncludeDefaultRules = `$true

    # Exclude backup files from analysis
    ExcludeRules = @()

    # Exclude backup file patterns
    ExcludePath = @(
$(($Patterns | ForEach-Object { "        '$_'" }) -join ",`n")
    )

    # Severity levels
    Severity = @('Error', 'Warning', 'Information')
}
"@

        # Only create if doesn't exist or Force is specified
        if (-not (Test-Path $psaPath) -or $Force) {
            Set-Content -Path $psaPath -Value $psaContent -Encoding UTF8

            return @{
                Success = $true
                FilePath = $psaPath
                PatternsAdded = $Patterns.Count
            }
        } else {
            return @{
                Success = $true
                FilePath = $psaPath
                PatternsAdded = 0
            }
        }

    } catch {
        return @{
            Success = $false
            Error = "Failed to update PSScriptAnalyzer settings: $($_.Exception.Message)"
            PatternsAdded = 0
        }
    }
}

function Update-PesterConfig {
    [CmdletBinding()]
    param(
        [string]$ProjectRoot,
        [string[]]$Patterns,
        [switch]$Force
    )

    try {
        $pesterPath = Join-Path $ProjectRoot "Pester.config.ps1"

        # Basic Pester configuration with backup exclusions
        $pesterContent = @"
@{
    Run = @{
        Path = @('.')
        ExcludePath = @(
$(($Patterns | ForEach-Object { "            '$_'" }) -join ",`n")
        )
    }
    TestResult = @{
        Enabled = `$true
        OutputFormat = 'NUnitXml'
        OutputPath = './TestResults.xml'
    }
    CodeCoverage = @{
        Enabled = `$false
        Path = @('.')
        ExcludeTests = `$true
    }
}
"@

        # Only create if doesn't exist or Force is specified
        if (-not (Test-Path $pesterPath) -or $Force) {
            Set-Content -Path $pesterPath -Value $pesterContent -Encoding UTF8

            return @{
                Success = $true
                FilePath = $pesterPath
                PatternsAdded = $Patterns.Count
            }
        } else {
            return @{
                Success = $true
                FilePath = $pesterPath
                PatternsAdded = 0
            }
        }

    } catch {
        return @{
            Success = $false
            Error = "Failed to update Pester config: $($_.Exception.Message)"
            PatternsAdded = 0
        }
    }
}
