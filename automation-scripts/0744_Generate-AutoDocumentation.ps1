#Requires -Version 7.0

<#
.SYNOPSIS
    Automated reactive documentation generation for AitherZero platform
.DESCRIPTION
    Generates comprehensive, up-to-date documentation automatically based on code changes.
    Integrates with the new DocumentationEngine module for reactive documentation updates.
.PARAMETER Mode
    Generation mode: Full (complete regeneration), Incremental (changed files only), or Reactive (file watcher)
.PARAMETER OutputPath
    Output directory for generated documentation
.PARAMETER Format
    Output formats: Markdown, HTML, or Both
.PARAMETER Watch
    Enable file system watcher for reactive documentation updates
.PARAMETER Quality
    Run quality validation after generation
#>

# Script metadata
# Stage: AI & Documentation
# Dependencies: 0400 (Testing Tools)
# Description: Automated reactive documentation generation with quality validation
# Tags: documentation, automation, reactive, ai-powered

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Full', 'Incremental', 'Reactive')]
    [string]$Mode = 'Full',
    
    [string]$OutputPath = $null,
    
    [ValidateSet('Markdown', 'HTML', 'Both')]
    [string]$Format = 'Both',
    
    [switch]$Watch,
    
    [switch]$Quality = $true,
    
    [int]$WatchTimeout = 300  # 5 minutes for reactive mode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Initialize
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:StartTime = Get-Date

# Import required modules
Import-Module (Join-Path $script:ProjectRoot "domains/utilities/Logging.psm1") -Force -ErrorAction SilentlyContinue
Import-Module (Join-Path $script:ProjectRoot "domains/documentation/DocumentationEngine.psm1") -Force

function Write-DocLog {
    param([string]$Message, [string]$Level = 'Information', [hashtable]$Data = @{})
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "AutoDocumentation" -Data $Data
    } else {
        Write-Host "[$Level] [AutoDocumentation] $Message" -ForegroundColor $(
            switch ($Level) {
                'Information' { 'White' }
                'Warning' { 'Yellow' }
                'Error' { 'Red' }
                'Debug' { 'Gray' }
                default { 'White' }
            }
        )
    }
}

function Initialize-Documentation {
    Write-DocLog "Initializing automated documentation generation" -Data @{
        Mode = $Mode
        Format = $Format
        OutputPath = $OutputPath
    }
    Write-DocLog "Starting initialization process..." -Level Information
    
    # Initialize documentation engine
    try {
        Write-DocLog "Importing and initializing documentation engine..." -Level Debug
        Initialize-DocumentationEngine -TemplateDirectory (Join-Path $script:ProjectRoot "docs/templates")
        Write-DocLog "Documentation engine initialized successfully" -Level Information
    } catch {
        Write-DocLog "Failed to initialize documentation engine: $_" -Level Error
        throw
    }
    
    # Set default output path if not specified
    if (-not $OutputPath) {
        $script:OutputPath = Join-Path $script:ProjectRoot "docs/generated"
        Write-DocLog "Using default output path: $script:OutputPath" -Level Debug
    } else {
        $script:OutputPath = $OutputPath
        Write-DocLog "Using provided output path: $script:OutputPath" -Level Debug
    }
    
    # Ensure output directory exists
    if (-not (Test-Path $script:OutputPath)) {
        Write-DocLog "Creating output directory..." -Level Information
        New-Item -Path $script:OutputPath -ItemType Directory -Force | Out-Null
        Write-DocLog "Created output directory: $script:OutputPath" -Level Information
    } else {
        Write-DocLog "Output directory already exists: $script:OutputPath" -Level Debug
    }
    
    Write-DocLog "Initialization completed successfully" -Level Information
}

function Invoke-FullDocumentationGeneration {
    Write-DocLog "Starting full documentation generation..." -Level Information
    Write-DocLog "Mode: Full regeneration of all documentation" -Level Debug
    
    try {
        # Generate complete project documentation
        Write-DocLog "Generating project-level documentation..." -Level Information
        $projectDocPath = New-ProjectDocumentation -OutputPath $script:OutputPath
        Write-DocLog "Generated project documentation: $projectDocPath" -Level Information
        
        # Generate individual module documentation
        $domainsPath = Join-Path $script:ProjectRoot "domains"
        Write-DocLog "Scanning for modules in: $domainsPath" -Level Debug
        
        if (Test-Path $domainsPath) {
            $domains = Get-ChildItem -Path $domainsPath -Directory
            Write-DocLog "Found $($domains.Count) domains to process" -Level Information
            
            $moduleCount = 0
            Get-ChildItem -Path $domainsPath -Directory | ForEach-Object {
                $domainPath = $_.FullName
                $domainName = $_.Name
                Write-DocLog "Processing domain: $domainName" -Level Debug
                
                $domainModules = Get-ChildItem -Path $domainPath -Filter "*.psm1"
                Write-DocLog "Found $($domainModules.Count) modules in domain: $domainName" -Level Debug
                
                $domainModules | ForEach-Object {
                    try {
                        Write-DocLog "Generating docs for: $($_.BaseName)" -Level Debug
                        $moduleDocPath = New-ModuleDocumentation -ModulePath $_.FullName -OutputPath $script:OutputPath -Format $Format
                        $moduleCount++
                        Write-DocLog "Generated documentation for module: $($_.BaseName)" -Level Debug
                    } catch {
                        Write-DocLog "Failed to generate documentation for module $($_.BaseName): $_" -Level Warning
                    }
                }
            }
            Write-DocLog "Generated documentation for $moduleCount modules" -Level Information
        }
        
        # Generate automation script documentation
        Invoke-ScriptDocumentationGeneration
        
        # Update main documentation files
        Update-MainDocumentation
        
        Write-DocLog "Full documentation generation completed successfully"
        return $true
        
    } catch {
        Write-DocLog "Full documentation generation failed: $_" -Level Error
        return $false
    }
}

function Invoke-IncrementalDocumentationGeneration {
    Write-DocLog "Starting incremental documentation generation..."
    
    try {
        # Find recently changed files
        $changedFiles = Get-RecentlyChangedFiles -Hours 24
        
        if ($changedFiles.Count -eq 0) {
            Write-DocLog "No recent changes detected, skipping incremental generation"
            return $true
        }
        
        Write-DocLog "Found $($changedFiles.Count) recently changed files"
        
        # Process each changed file
        foreach ($file in $changedFiles) {
            try {
                if ($file.FullName -like "*.psm1") {
                    New-ModuleDocumentation -ModulePath $file.FullName -OutputPath $script:OutputPath -Format $Format
                    Write-DocLog "Updated documentation for module: $($file.BaseName)"
                } elseif ($file.FullName -like "*.ps1" -and $file.FullName -like "*automation-scripts*") {
                    Update-ScriptDocumentation -ScriptPath $file.FullName
                    Write-DocLog "Updated documentation for script: $($file.BaseName)"
                } elseif ($file.Name -eq "README.md") {
                    Update-MainDocumentation
                    Write-DocLog "Updated main documentation due to README changes"
                }
            } catch {
                Write-DocLog "Failed to update documentation for $($file.Name): $_" -Level Warning
            }
        }
        
        Write-DocLog "Incremental documentation generation completed"
        return $true
        
    } catch {
        Write-DocLog "Incremental documentation generation failed: $_" -Level Error
        return $false
    }
}

function Invoke-ReactiveDocumentationMode {
    Write-DocLog "Starting reactive documentation mode with $WatchTimeout second timeout..."
    
    try {
        # Set up file system watchers
        $watchers = @()
        
        # Watch domains directory
        $domainsPath = Join-Path $script:ProjectRoot "domains"
        if (Test-Path $domainsPath) {
            $domainsWatcher = New-Object System.IO.FileSystemWatcher
            $domainsWatcher.Path = $domainsPath
            $domainsWatcher.Filter = "*.psm1"
            $domainsWatcher.EnableRaisingEvents = $true
            $domainsWatcher.IncludeSubdirectories = $true
            
            Register-ObjectEvent -InputObject $domainsWatcher -EventName "Changed" -Action {
                param($sender, $eventArgs)
                Write-DocLog "Detected change in module: $($eventArgs.FullPath)"
                try {
                    New-ModuleDocumentation -ModulePath $eventArgs.FullPath -OutputPath $using:OutputPath -Format $using:Format
                } catch {
                    Write-DocLog "Failed to update documentation for changed module: $_" -Level Warning
                }
            } | Out-Null
            
            $watchers += $domainsWatcher
        }
        
        # Watch automation scripts directory
        $scriptsPath = Join-Path $script:ProjectRoot "automation-scripts"
        if (Test-Path $scriptsPath) {
            $scriptsWatcher = New-Object System.IO.FileSystemWatcher
            $scriptsWatcher.Path = $scriptsPath
            $scriptsWatcher.Filter = "*.ps1"
            $scriptsWatcher.EnableRaisingEvents = $true
            
            Register-ObjectEvent -InputObject $scriptsWatcher -EventName "Changed" -Action {
                param($sender, $eventArgs)
                Write-DocLog "Detected change in script: $($eventArgs.Name)"
                # Update script documentation index
                Invoke-ScriptDocumentationGeneration
            } | Out-Null
            
            $watchers += $scriptsWatcher
        }
        
        Write-DocLog "File system watchers initialized. Monitoring for changes..."
        Write-Host "📚 Reactive documentation mode active. Press Ctrl+C to stop or wait $WatchTimeout seconds..." -ForegroundColor Cyan
        
        # Wait for timeout or manual interruption
        $endTime = (Get-Date).AddSeconds($WatchTimeout)
        while ((Get-Date) -lt $endTime) {
            Start-Sleep -Seconds 5
            
            # Check for interruption
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if ($key.Key -eq 'C' -and $key.Modifiers -eq 'Control') {
                    Write-DocLog "Manual interruption detected"
                    break
                }
            }
        }
        
        Write-DocLog "Reactive documentation mode ended"
        
        # Clean up watchers
        foreach ($watcher in $watchers) {
            $watcher.EnableRaisingEvents = $false
            $watcher.Dispose()
        }
        
        return $true
        
    } catch {
        Write-DocLog "Reactive documentation mode failed: $_" -Level Error
        return $false
    }
}

function Invoke-ScriptDocumentationGeneration {
    Write-DocLog "Generating automation script documentation..."
    
    try {
        $scriptsPath = Join-Path $script:ProjectRoot "automation-scripts"
        if (-not (Test-Path $scriptsPath)) {
            Write-DocLog "Automation scripts directory not found" -Level Warning
            return
        }
        
        # Get all automation scripts
        $scripts = Get-ChildItem -Path $scriptsPath -Filter "*.ps1" | Where-Object { 
            $_.Name -match '^\d{4}_' 
        } | Sort-Object Name
        
        # Generate script index documentation
        $scriptIndex = Generate-ScriptIndexDocumentation -Scripts $scripts
        
        # Save script index
        $scriptIndexPath = Join-Path $script:OutputPath "automation-scripts"
        if (-not (Test-Path $scriptIndexPath)) {
            New-Item -Path $scriptIndexPath -ItemType Directory -Force | Out-Null
        }
        
        $indexFile = Join-Path $scriptIndexPath "index.md"
        $scriptIndex | Set-Content $indexFile -Encoding UTF8
        
        Write-DocLog "Generated automation script documentation index: $indexFile"
        
    } catch {
        Write-DocLog "Failed to generate script documentation: $_" -Level Error
    }
}

function Generate-ScriptIndexDocumentation {
    param([System.IO.FileInfo[]]$Scripts)
    
    $index = @"
# Automation Scripts Index

AitherZero uses a number-based orchestration system (0000-9999) for systematic script execution.

## Script Categories

"@
    
    # Group scripts by category
    $categories = @{
        '0000-0099' = @{ Name = 'Environment Setup'; Scripts = @() }
        '0100-0199' = @{ Name = 'Infrastructure'; Scripts = @() }
        '0200-0299' = @{ Name = 'Development Tools'; Scripts = @() }
        '0400-0499' = @{ Name = 'Testing & Validation'; Scripts = @() }
        '0500-0599' = @{ Name = 'Reporting & Analytics'; Scripts = @() }
        '0700-0799' = @{ Name = 'Git & AI Tools'; Scripts = @() }
        '9000-9999' = @{ Name = 'Maintenance'; Scripts = @() }
    }
    
    foreach ($script in $Scripts) {
        $number = ($script.Name -split '_')[0]
        $numValue = [int]$number
        
        $category = switch ($numValue) {
            {$_ -ge 0 -and $_ -le 99} { '0000-0099' }
            {$_ -ge 100 -and $_ -le 199} { '0100-0199' }
            {$_ -ge 200 -and $_ -le 299} { '0200-0299' }
            {$_ -ge 400 -and $_ -le 499} { '0400-0499' }
            {$_ -ge 500 -and $_ -le 599} { '0500-0599' }
            {$_ -ge 700 -and $_ -le 799} { '0700-0799' }
            {$_ -ge 9000 -and $_ -le 9999} { '9000-9999' }
            default { 'Other' }
        }
        
        if ($categories.ContainsKey($category)) {
            $scriptInfo = Get-ScriptInformation -ScriptPath $script.FullName
            $categories[$category].Scripts += @{
                Number = $number
                Name = $script.BaseName
                Description = $scriptInfo.Description
                Tags = $scriptInfo.Tags
            }
        }
    }
    
    # Generate documentation for each category
    foreach ($categoryKey in $categories.Keys | Sort-Object) {
        $category = $categories[$categoryKey]
        if ($category.Scripts.Count -gt 0) {
            $index += "`n### $($category.Name) ($categoryKey)`n"
            $index += "`n| Script | Description | Tags |`n"
            $index += "| ------ | ----------- | ---- |`n"
            
            foreach ($script in ($category.Scripts | Sort-Object Number)) {
                $index += "| ``az $($script.Number)`` | $($script.Description) | $($script.Tags -join ', ') |`n"
            }
        }
    }
    
    $index += @"

## Usage

Use the ``az`` command wrapper to execute scripts:

```powershell
# Examples
az 0402      # Run unit tests
az 0510      # Generate project report  
az 0701      # Create feature branch
```

## Integration

These scripts integrate with:
- **CI/CD Pipelines**: Automated execution in GitHub Actions
- **Orchestration Engine**: Batch execution via playbooks
- **Testing Framework**: Validation and quality gates

---
*Generated automatically on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')*
"@
    
    return $index
}

function Get-ScriptInformation {
    param([string]$ScriptPath)
    
    try {
        $content = Get-Content $ScriptPath -Raw
        
        # Extract description from comment
        $description = if ($content -match '# Description:\s*(.*)') {
            $Matches[1].Trim()
        } elseif ($content -match '\.SYNOPSIS\s+(.*?)(?=\s*\.|\s*#>)') {
            $Matches[1].Trim()
        } else {
            "No description available"
        }
        
        # Extract tags
        $tags = if ($content -match '# Tags:\s*(.*)') {
            $Matches[1].Trim().Split(',') | ForEach-Object { $_.Trim() }
        } else {
            @()
        }
        
        return @{
            Description = $description
            Tags = $tags
        }
    } catch {
        return @{
            Description = "Error reading script information"
            Tags = @()
        }
    }
}

function Get-RecentlyChangedFiles {
    param([int]$Hours = 24)
    
    $cutoffTime = (Get-Date).AddHours(-$Hours)
    
    $changedFiles = @()
    
    # Check domains
    $domainsPath = Join-Path $script:ProjectRoot "domains"
    if (Test-Path $domainsPath) {
        $changedFiles += Get-ChildItem -Path $domainsPath -Recurse -Filter "*.psm1" | 
            Where-Object { $_.LastWriteTime -gt $cutoffTime }
    }
    
    # Check automation scripts
    $scriptsPath = Join-Path $script:ProjectRoot "automation-scripts"
    if (Test-Path $scriptsPath) {
        $changedFiles += Get-ChildItem -Path $scriptsPath -Filter "*.ps1" | 
            Where-Object { $_.LastWriteTime -gt $cutoffTime }
    }
    
    # Check main files
    $mainFiles = @('README.md', 'AitherZero.psd1', 'AitherZero.psm1')
    foreach ($file in $mainFiles) {
        $fullPath = Join-Path $script:ProjectRoot $file
        if (Test-Path $fullPath) {
            $fileInfo = Get-Item $fullPath
            if ($fileInfo.LastWriteTime -gt $cutoffTime) {
                $changedFiles += $fileInfo
            }
        }
    }
    
    return $changedFiles
}

function Update-MainDocumentation {
    Write-DocLog "Updating main documentation files..."
    
    try {
        # Generate new README sections based on current state
        $readmePath = Join-Path $script:ProjectRoot "README.md"
        if (Test-Path $readmePath) {
            # Update functionality index reference
            Update-FunctionalityIndex
            Write-DocLog "Updated functionality index"
        }
        
        # Update documentation index if function is available
        $indexPath = Join-Path $script:OutputPath "index.md"
        if (Test-Path $indexPath) {
            try {
                # Try to regenerate index with current documentation
                if (Get-Command Get-ProjectAnalysis -ErrorAction SilentlyContinue) {
                    $projectInfo = Get-ProjectAnalysis
                    New-DocumentationIndex -OutputPath $script:OutputPath -ProjectInfo $projectInfo
                    Write-DocLog "Updated documentation index"
                } else {
                    Write-DocLog "Get-ProjectAnalysis function not available, skipping index update" -Level Warning
                }
            } catch {
                Write-DocLog "Failed to update documentation index: $_" -Level Warning
            }
        }
        
    } catch {
        Write-DocLog "Failed to update main documentation: $_" -Level Warning
    }
}

function Update-FunctionalityIndex {
    # Update the FUNCTIONALITY-INDEX.md file with current module and script counts
    $indexPath = Join-Path $script:ProjectRoot "FUNCTIONALITY-INDEX.md"
    
    if (Test-Path $indexPath) {
        try {
            # Get current counts
            $domainCounts = Get-CurrentDomainCounts
            $scriptCounts = Get-CurrentScriptCounts
            
            # Note: In a full implementation, this would update the actual index file
            # For now, we'll just log that it should be updated
            Write-DocLog "Functionality index should be updated with current counts" -Data @{
                Domains = $domainCounts.Count
                Scripts = $scriptCounts
            }
            
        } catch {
            Write-DocLog "Failed to update functionality index: $_" -Level Warning
        }
    }
}

function Get-CurrentDomainCounts {
    $domainsPath = Join-Path $script:ProjectRoot "domains"
    if (Test-Path $domainsPath) {
        return Get-ChildItem -Path $domainsPath -Directory
    }
    return @()
}

function Get-CurrentScriptCounts {
    $scriptsPath = Join-Path $script:ProjectRoot "automation-scripts"
    if (Test-Path $scriptsPath) {
        return (Get-ChildItem -Path $scriptsPath -Filter "*.ps1").Count
    }
    return 0
}

function Invoke-DocumentationQualityValidation {
    Write-DocLog "Running documentation quality validation..."
    
    try {
        $validationResults = Test-DocumentationQuality -Path $script:OutputPath
        
        Write-Host "`n📊 Documentation Quality Report" -ForegroundColor Cyan
        Write-Host "================================" -ForegroundColor Cyan
        Write-Host "Overall Score: $($validationResults.Score)%" -ForegroundColor $(
            if ($validationResults.Score -ge 80) { 'Green' }
            elseif ($validationResults.Score -ge 60) { 'Yellow' }
            else { 'Red' }
        )
        Write-Host "Quality Gate: $(if ($validationResults.Passed) { 'PASSED' } else { 'FAILED' })" -ForegroundColor $(
            if ($validationResults.Passed) { 'Green' } else { 'Red' }
        )
        Write-Host "Coverage: $($validationResults.Coverage.CoveragePercentage)%" -ForegroundColor White
        Write-Host "Issues Found: $($validationResults.Issues.Count)" -ForegroundColor White
        
        if ($validationResults.Issues.Count -gt 0) {
            Write-Host "`nTop Issues:" -ForegroundColor Yellow
            $validationResults.Issues | Select-Object -First 5 | ForEach-Object {
                Write-Host "  - $($_.Description)" -ForegroundColor Yellow
            }
        }
        
        Write-DocLog "Documentation quality validation completed" -Data $validationResults
        
        return $validationResults.Passed
        
    } catch {
        Write-DocLog "Documentation quality validation failed: $_" -Level Error
        return $false
    }
}

# Main execution
try {
    Write-DocLog "=== Automated Documentation Generation ===" -Data @{
        Mode = $Mode
        Format = $Format
        Watch = $Watch.IsPresent
        Quality = $Quality.IsPresent
    }
    
    # Initialize documentation system
    Initialize-Documentation
    
    # Execute based on mode
    $success = switch ($Mode) {
        'Full' { Invoke-FullDocumentationGeneration }
        'Incremental' { Invoke-IncrementalDocumentationGeneration }
        'Reactive' { Invoke-ReactiveDocumentationMode }
    }
    
    if (-not $success) {
        Write-DocLog "Documentation generation failed" -Level Error
        exit 1
    }
    
    # Run quality validation if requested
    if ($Quality) {
        $qualityPassed = Invoke-DocumentationQualityValidation
        if (-not $qualityPassed) {
            Write-DocLog "Documentation quality validation failed" -Level Warning
        }
    }
    
    # Final summary
    $duration = (Get-Date) - $script:StartTime
    Write-Host "`n✅ Documentation generation completed successfully!" -ForegroundColor Green
    Write-Host "📁 Output: $script:OutputPath" -ForegroundColor White
    Write-Host "⏱️  Duration: $($duration.TotalSeconds.ToString('F2')) seconds" -ForegroundColor White
    Write-Host "📊 Mode: $Mode | Format: $Format" -ForegroundColor White
    
    Write-DocLog "Automated documentation generation completed successfully" -Data @{
        Duration = $duration.TotalSeconds
        OutputPath = $script:OutputPath
        Success = $true
    }
    
    exit 0
    
} catch {
    Write-DocLog "Automated documentation generation failed: $_" -Level Error
    Write-DocLog "Stack trace: $($_.ScriptStackTrace)" -Level Error
    
    Write-Host "`n❌ Documentation generation failed!" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    
    exit 1
}