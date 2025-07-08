# Update-DocumentationIndex.ps1 - Root README Table of Contents Generator
# Part of AitherZero Smart Documentation Automation

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$StateFilePath = ".github/documentation-state.json",

    [Parameter(Mandatory = $false)]
    [string]$ProjectRoot = (Get-Location),

    [Parameter(Mandatory = $false)]
    [string]$ReadmePath = "README.md",

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [string]$SectionMarker = "<!-- DOCUMENTATION_INDEX -->",

    [Parameter(Mandatory = $false)]
    [string]$EndMarker = "<!-- END_DOCUMENTATION_INDEX -->"
)

# Find project root if not specified
if (-not (Test-Path $ProjectRoot)) {
    . "$PSScriptRoot/../../aither-core/shared/Find-ProjectRoot.ps1"
    $ProjectRoot = Find-ProjectRoot
}

# Import required modules
if (Test-Path "$ProjectRoot/aither-core/modules/Logging") {
    Import-Module "$ProjectRoot/aither-core/modules/Logging" -Force -ErrorAction SilentlyContinue
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level
    } else {
        Write-Host "[$Level] $Message" -ForegroundColor $(if($Level -eq "ERROR"){"Red"} elseif($Level -eq "WARN"){"Yellow"} else{"Green"})
    }
}

function Get-DocumentationIndex {
    <#
    .SYNOPSIS
    Generates a comprehensive documentation index from the state file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$State
    )

    $index = @{
        lastUpdated = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"
        totalDirectories = $State.directories.Count
        documentedDirectories = 0
        coveragePercent = 0
        categories = @{
            modules = @()
            infrastructure = @()
            configuration = @()
            scripts = @()
            tests = @()
            build = @()
            tooling = @()
            other = @()
        }
        statistics = @{
            byType = @{}
            byStatus = @{
                documented = 0
                missing = 0
                stale = 0
                current = 0
            }
        }
    }

    Write-Log "Building documentation index from $($State.directories.Count) directories..." -Level "INFO"

    foreach ($dirPath in ($State.directories.Keys | Sort-Object)) {
        $dirState = $State.directories[$dirPath]
        $relativePath = $dirPath.TrimStart('/')

        # Count documented directories
        if ($dirState.readmeExists) {
            $index.documentedDirectories++
        }

        # Categorize by type
        $category = switch ($dirState.directoryType) {
            "powershell-module" { "modules" }
            "infrastructure" { "infrastructure" }
            "configuration" { "configuration" }
            "scripts" { "scripts" }
            "tests" { "tests" }
            "build" { "build" }
            "tooling" { "tooling" }
            default { "other" }
        }

        # Create directory entry
        $entry = @{
            path = $relativePath
            name = Split-Path $relativePath -Leaf
            type = $dirState.directoryType
            hasReadme = $dirState.readmeExists
            status = Get-DirectoryStatus -DirectoryState $dirState
            description = Get-DirectoryDescription -DirectoryPath $relativePath -DirectoryType $dirState.directoryType -DirectoryState $dirState
            fileCount = $dirState.fileCount
            lastModified = $dirState.readmeLastModified
        }

        $index.categories[$category] += $entry

        # Update statistics
        if (-not $index.statistics.byType.ContainsKey($dirState.directoryType)) {
            $index.statistics.byType[$dirState.directoryType] = 0
        }
        $index.statistics.byType[$dirState.directoryType]++

        $index.statistics.byStatus[$entry.status]++
    }

    # Calculate coverage percentage
    $index.coveragePercent = if ($index.totalDirectories -gt 0) {
        [Math]::Round(($index.documentedDirectories / $index.totalDirectories) * 100, 1)
    } else { 0 }

    Write-Log "Documentation index built: $($index.documentedDirectories)/$($index.totalDirectories) directories documented ($($index.coveragePercent)%)" -Level "SUCCESS"

    return $index
}

function Get-DirectoryStatus {
    param([hashtable]$DirectoryState)

    if (-not $DirectoryState.readmeExists) {
        return "missing"
    }

    if ($DirectoryState.flaggedForReview) {
        return "stale"
    }

    return "current"
}

function Get-DirectoryDescription {
    param(
        [string]$DirectoryPath,
        [string]$DirectoryType,
        [hashtable]$DirectoryState
    )

    $dirName = Split-Path $DirectoryPath -Leaf

    # Try to extract description from existing README if available
    if ($DirectoryState.readmeExists) {
        try {
            $readmeFullPath = Join-Path $ProjectRoot $DirectoryPath "README.md"
            if (Test-Path $readmeFullPath) {
                $readmeContent = Get-Content $readmeFullPath -Raw -ErrorAction SilentlyContinue
                if ($readmeContent -match '## (?:Overview|Module Overview)\s*\n\s*([^\n]+)') {
                    $extractedDesc = $matches[1].Trim()
                    if ($extractedDesc.Length -gt 10 -and $extractedDesc.Length -lt 150) {
                        return $extractedDesc
                    }
                }
            }
        } catch {
            # Continue with generated description
        }
    }

    # Generate description based on directory type and name
    switch ($DirectoryType) {
        "powershell-module" {
            switch -Regex ($dirName) {
                ".*Manager" { "$dirName - Resource management and orchestration module" }
                ".*Provider" { "$dirName - Provider integration and abstraction layer" }
                ".*Core" { "$dirName - Core functionality and utilities" }
                ".*Integration" { "$dirName - External system integration services" }
                ".*Automation" { "$dirName - Automation workflows and processes" }
                "Logging" { "$dirName - Centralized logging and monitoring system" }
                "Security.*" { "$dirName - Security automation and hardening tools" }
                default { "$dirName - PowerShell module for AitherZero automation" }
            }
        }
        "infrastructure" {
            if ($DirectoryPath -match "examples") {
                "Example infrastructure configurations and templates"
            } elseif ($DirectoryPath -match "modules") {
                "Reusable infrastructure modules and components"
            } else {
                "OpenTofu/Terraform infrastructure configuration"
            }
        }
        "configuration" {
            if ($DirectoryPath -match "carousel") {
                "Multi-environment configuration management"
            } elseif ($DirectoryPath -match "labs") {
                "Laboratory environment configurations"
            } else {
                "Configuration files and settings"
            }
        }
        "scripts" {
            "Automation and utility scripts"
        }
        "tests" {
            "Test suites and validation scripts"
        }
        "build" {
            "Build automation and packaging scripts"
        }
        "tooling" {
            "Development tools and IDE configurations"
        }
        default {
            "Project component for AitherZero framework"
        }
    }
}

function Generate-DocumentationTOC {
    <#
    .SYNOPSIS
    Generates the table of contents section for the main README
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Index
    )

    $toc = @"
$SectionMarker

## 📚 Documentation Index

**Last Updated:** $($Index.lastUpdated)
**Coverage:** $($Index.documentedDirectories)/$($Index.totalDirectories) directories ($($Index.coveragePercent)%)

### 📊 Documentation Statistics

| Status | Count | Percentage |
|--------|-------|------------|
| ✅ Current | $($Index.statistics.byStatus.current) | $([Math]::Round($Index.statistics.byStatus.current / $Index.totalDirectories * 100, 1))% |
| ⚠️ Stale | $($Index.statistics.byStatus.stale) | $([Math]::Round($Index.statistics.byStatus.stale / $Index.totalDirectories * 100, 1))% |
| ❌ Missing | $($Index.statistics.byStatus.missing) | $([Math]::Round($Index.statistics.byStatus.missing / $Index.totalDirectories * 100, 1))% |

"@

    # Add category sections
    foreach ($categoryName in @('modules', 'infrastructure', 'configuration', 'scripts', 'tests', 'build', 'tooling', 'other')) {
        $categoryData = $Index.categories[$categoryName]
        if ($categoryData.Count -eq 0) { continue }

        $categoryTitle = switch ($categoryName) {
            'modules' { '🧩 PowerShell Modules' }
            'infrastructure' { '🏗️ Infrastructure' }
            'configuration' { '⚙️ Configuration' }
            'scripts' { '📜 Scripts' }
            'tests' { '🧪 Tests' }
            'build' { '🔨 Build' }
            'tooling' { '🛠️ Tooling' }
            'other' { '📁 Other' }
        }

        $toc += "`n### $categoryTitle`n`n"

        # Sort by status (current first, then missing/stale)
        $sortedEntries = $categoryData | Sort-Object @{Expression = {if($_.status -eq 'current') {0} elseif($_.status -eq 'stale') {1} else {2}}}, name

        foreach ($entry in $sortedEntries) {
            $statusIcon = switch ($entry.status) {
                'current' { '✅' }
                'stale' { '⚠️' }
                'missing' { '❌' }
                default { '❓' }
            }

            $linkText = if ($entry.hasReadme) {
                "[$($entry.name)]($($entry.path)/README.md)"
            } else {
                $entry.name
            }

            $fileInfo = if ($entry.fileCount -gt 0) { " ($($entry.fileCount) files)" } else { "" }

            $toc += "- $statusIcon **$linkText** - $($entry.description)$fileInfo`n"
        }
    }

    # Add navigation links
    $toc += @"

### 🔗 Quick Navigation

| Category | Documentation | Count |
|----------|---------------|-------|
| [Core Modules](aither-core/modules/) | PowerShell automation modules | $($Index.categories.modules.Count) |
| [Infrastructure](opentofu/) | OpenTofu/Terraform configurations | $($Index.categories.infrastructure.Count) |
| [Configuration](configs/) | Settings and configuration files | $($Index.categories.configuration.Count) |
| [Scripts](scripts/) | Utility and automation scripts | $($Index.categories.scripts.Count) |
| [Tests](tests/) | Test suites and validation | $($Index.categories.tests.Count) |

### 📋 Documentation Status Legend

- ✅ **Current** - Documentation is up to date
- ⚠️ **Stale** - Documentation needs review (outdated or significant changes detected)
- ❌ **Missing** - No README file exists

> 💡 **Tip**: Click on any linked component name to view its detailed documentation.

$EndMarker
"@

    return $toc
}

function Update-ReadmeWithIndex {
    <#
    .SYNOPSIS
    Updates the main README file with the generated documentation index
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReadmeFilePath,

        [Parameter(Mandatory = $true)]
        [string]$NewTOC,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    if (-not (Test-Path $ReadmeFilePath)) {
        Write-Log "README file not found: $ReadmeFilePath" -Level "ERROR"
        return $false
    }

    try {
        $currentContent = Get-Content -Path $ReadmeFilePath -Raw -Encoding UTF8

        # Find existing documentation index section
        $startPattern = [regex]::Escape($SectionMarker)
        $endPattern = [regex]::Escape($EndMarker)
        $sectionRegex = "(?s)$startPattern.*?$endPattern"

        $updatedContent = if ($currentContent -match $sectionRegex) {
            # Replace existing section
            $currentContent -replace $sectionRegex, $NewTOC
        } else {
            # Append at the end
            $currentContent.TrimEnd() + "`n`n" + $NewTOC
        }

        if ($DryRun) {
            Write-Log "DRY RUN: Would update $ReadmeFilePath with documentation index" -Level "INFO"
            Write-Log "New section length: $($NewTOC.Length) characters" -Level "INFO"
            return $true
        }

        # Create backup
        $backupPath = "$ReadmeFilePath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -Path $ReadmeFilePath -Destination $backupPath

        # Write updated content
        Set-Content -Path $ReadmeFilePath -Value $updatedContent -Encoding UTF8

        Write-Log "Updated README with documentation index (backup: $backupPath)" -Level "SUCCESS"
        return $true

    } catch {
        Write-Log "Error updating README: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Main execution
try {
    $stateFilePath = Join-Path $ProjectRoot $StateFilePath
    $readmeFilePath = Join-Path $ProjectRoot $ReadmePath

    # Load current state
    if (-not (Test-Path $stateFilePath)) {
        Write-Log "State file not found: $stateFilePath" -Level "ERROR"
        Write-Log "Run Track-DocumentationState.ps1 -Initialize first" -Level "ERROR"
        exit 1
    }

    $content = Get-Content -Path $stateFilePath -Raw -Encoding UTF8
    $state = $content | ConvertFrom-Json -AsHashtable

    Write-Log "Generating documentation index for root README..." -Level "INFO"

    # Generate documentation index
    $index = Get-DocumentationIndex -State $state

    # Generate table of contents
    $tocContent = Generate-DocumentationTOC -Index $index

    # Update README file
    $success = Update-ReadmeWithIndex -ReadmeFilePath $readmeFilePath -NewTOC $tocContent -DryRun:$DryRun

    if ($success) {
        # Output summary
        Write-Host "`n📖 Documentation Index Update Summary:" -ForegroundColor Cyan
        Write-Host "  Total Directories: $($index.totalDirectories)" -ForegroundColor White
        Write-Host "  Documented: $($index.documentedDirectories)" -ForegroundColor Green
        Write-Host "  Coverage: $($index.coveragePercent)%" -ForegroundColor $(if($index.coveragePercent -ge 80){"Green"}elseif($index.coveragePercent -ge 60){"Yellow"}else{"Red"})
        Write-Host "  Missing Documentation: $($index.statistics.byStatus.missing)" -ForegroundColor Red
        Write-Host "  Stale Documentation: $($index.statistics.byStatus.stale)" -ForegroundColor Yellow

        Write-Host "`n📋 By Category:" -ForegroundColor Yellow
        foreach ($category in $index.categories.Keys) {
            $count = $index.categories[$category].Count
            if ($count -gt 0) {
                Write-Host "  $category`: $count" -ForegroundColor Gray
            }
        }

        if (-not $DryRun) {
            Write-Log "README updated successfully with documentation index" -Level "SUCCESS"
        }
    } else {
        Write-Log "Failed to update README with documentation index" -Level "ERROR"
        exit 1
    }

} catch {
    Write-Log "Documentation index update failed: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
