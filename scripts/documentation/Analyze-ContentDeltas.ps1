# Analyze-ContentDeltas.ps1 - Content Change Detection and Delta Analysis
# Part of AitherZero Smart Documentation Automation

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$StateFilePath = ".github/documentation-state.json",
    
    [Parameter(Mandatory = $false)]
    [string]$ProjectRoot = (Get-Location),
    
    [Parameter(Mandatory = $false)]
    [string[]]$TargetDirectories = @(),
    
    [Parameter(Mandatory = $false)]
    [switch]$DetailedAnalysis,
    
    [Parameter(Mandatory = $false)]
    [switch]$ExportChanges
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

function Get-DirectoryContentMetrics {
    <#
    .SYNOPSIS
    Calculates comprehensive content metrics for a directory
    
    .DESCRIPTION
    Analyzes file count, character count, modification dates, and content types
    to detect significant changes that warrant documentation updates
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeFileDetails
    )
    
    $metrics = @{
        directoryPath = $DirectoryPath
        scanTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        totalFiles = 0
        totalCharacters = 0
        codeFiles = 0
        codeCharacters = 0
        documentationFiles = 0
        configurationFiles = 0
        mostRecentChange = $null
        fileTypes = @{}
        significantFiles = @()
        contentHash = ""
    }
    
    if (-not (Test-Path $DirectoryPath)) {
        Write-Log "Directory not found: $DirectoryPath" -Level "WARN"
        return $metrics
    }
    
    try {
        # Get all files recursively
        $files = Get-ChildItem -Path $DirectoryPath -File -Recurse -ErrorAction SilentlyContinue | Where-Object {
            # Exclude common non-content files
            $_.Name -notmatch '\.(exe|dll|bin|obj|log|tmp|cache)$' -and
            $_.DirectoryName -notmatch '(node_modules|\.git|bin|obj|target)'
        }
        
        $metrics.totalFiles = $files.Count
        $allContent = @()
        
        foreach ($file in $files) {
            $extension = $file.Extension.ToLower()
            $fileSize = $file.Length
            
            # Track file types
            if (-not $metrics.fileTypes.ContainsKey($extension)) {
                $metrics.fileTypes[$extension] = @{ count = 0; characters = 0 }
            }
            $metrics.fileTypes[$extension].count++
            
            # Categorize files
            $isCodeFile = $extension -in @('.ps1', '.psm1', '.psd1', '.py', '.js', '.ts', '.cs', '.go', '.java', '.cpp', '.c', '.h')
            $isDocFile = $extension -in @('.md', '.txt', '.rst', '.adoc')
            $isConfigFile = $extension -in @('.json', '.yaml', '.yml', '.xml', '.toml', '.ini', '.conf', '.config')
            
            if ($isCodeFile) { $metrics.codeFiles++ }
            if ($isDocFile) { $metrics.documentationFiles++ }
            if ($isConfigFile) { $metrics.configurationFiles++ }
            
            # Track most recent change
            if (-not $metrics.mostRecentChange -or $file.LastWriteTime -gt [DateTime]::Parse($metrics.mostRecentChange)) {
                $metrics.mostRecentChange = $file.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
            }
            
            # Read content for analysis (only for text files under reasonable size)
            if ($fileSize -lt 1MB -and $extension -in @('.ps1', '.psm1', '.psd1', '.md', '.txt', '.json', '.yaml', '.yml', '.xml', '.tf', '.py', '.js', '.ts')) {
                try {
                    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
                    if ($content) {
                        $contentLength = $content.Length
                        $metrics.totalCharacters += $contentLength
                        $metrics.fileTypes[$extension].characters += $contentLength
                        
                        if ($isCodeFile) {
                            $metrics.codeCharacters += $contentLength
                        }
                        
                        # Track significant files (large or important)
                        if ($contentLength -gt 1000 -or $isCodeFile -or $isConfigFile) {
                            $metrics.significantFiles += @{
                                path = $file.FullName.Replace($DirectoryPath, "").TrimStart('\', '/')
                                extension = $extension
                                characters = $contentLength
                                lastModified = $file.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
                                category = if ($isCodeFile) { "code" } elseif ($isConfigFile) { "config" } elseif ($isDocFile) { "docs" } else { "other" }
                            }
                        }
                        
                        # Add to content hash calculation
                        $allContent += $content
                    }
                } catch {
                    Write-Log "Could not read file: $($file.FullName) - $($_.Exception.Message)" -Level "WARN"
                }
            }
        }
        
        # Calculate content hash for change detection
        if ($allContent.Count -gt 0) {
            $combinedContent = $allContent -join ""
            $hash = [System.Security.Cryptography.SHA256]::Create()
            $hashBytes = $hash.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($combinedContent))
            $metrics.contentHash = [System.BitConverter]::ToString($hashBytes).Replace("-", "").ToLower()
            $hash.Dispose()
        }
        
    } catch {
        Write-Log "Error analyzing directory $DirectoryPath : $($_.Exception.Message)" -Level "ERROR"
    }
    
    Write-Log "Analyzed $DirectoryPath : $($metrics.totalFiles) files, $($metrics.totalCharacters) chars, $($metrics.codeFiles) code files" -Level "INFO"
    return $metrics
}

function Compare-DirectoryMetrics {
    <#
    .SYNOPSIS
    Compares current directory metrics with previous state to detect changes
    
    .DESCRIPTION
    Analyzes differences in file count, content size, and modification dates
    to determine if documentation updates are needed
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$CurrentMetrics,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$PreviousState,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration
    )
    
    $analysis = @{
        directoryPath = $CurrentMetrics.directoryPath
        hasSignificantChanges = $false
        changeReasons = @()
        deltaPercent = 0
        fileCountDelta = 0
        characterDelta = 0
        needsReview = $false
        reviewReasons = @()
        changeType = "none"
        confidence = 0
    }
    
    # Calculate deltas
    $analysis.fileCountDelta = $CurrentMetrics.totalFiles - $PreviousState.fileCount
    $analysis.characterDelta = $CurrentMetrics.totalCharacters - $PreviousState.totalCharCount
    
    # Calculate percentage change
    if ($PreviousState.totalCharCount -gt 0) {
        $analysis.deltaPercent = [Math]::Abs($analysis.characterDelta) / $PreviousState.totalCharCount * 100
    } else {
        $analysis.deltaPercent = if ($CurrentMetrics.totalCharacters -gt 0) { 100 } else { 0 }
    }
    
    # Check for significant changes based on thresholds
    $charThreshold = $Configuration.changeThresholds.characterDeltaPercent
    $minChange = $Configuration.changeThresholds.minSignificantChange
    
    if ($analysis.deltaPercent -gt $charThreshold -and [Math]::Abs($analysis.characterDelta) -gt $minChange) {
        $analysis.hasSignificantChanges = $true
        $analysis.changeReasons += "Content changed by $([Math]::Round($analysis.deltaPercent, 1))% ($($analysis.characterDelta) characters)"
        $analysis.changeType = if ($analysis.characterDelta -gt 0) { "expansion" } else { "reduction" }
        $analysis.confidence = [Math]::Min(100, $analysis.deltaPercent)
    }
    
    if ([Math]::Abs($analysis.fileCountDelta) -gt 2) {
        $analysis.hasSignificantChanges = $true
        $analysis.changeReasons += "File count changed by $($analysis.fileCountDelta) files"
        if ($analysis.changeType -eq "none") {
            $analysis.changeType = if ($analysis.fileCountDelta -gt 0) { "addition" } else { "removal" }
        }
        $analysis.confidence = [Math]::Max($analysis.confidence, 50)
    }
    
    # Check for content hash changes (indicates structural changes)
    if ($CurrentMetrics.contentHash -ne $PreviousState.contentHash -and $PreviousState.contentHash) {
        $analysis.hasSignificantChanges = $true
        $analysis.changeReasons += "Content structure changed (hash mismatch)"
        $analysis.confidence = [Math]::Max($analysis.confidence, 30)
    }
    
    # Check README freshness
    $readmeAge = $null
    if ($PreviousState.readmeLastModified) {
        try {
            $readmeDate = [DateTime]::Parse($PreviousState.readmeLastModified)
            $readmeAge = (Get-Date) - $readmeDate
        } catch {
            # Invalid date format
        }
    }
    
    # Time-based review triggers
    if ($readmeAge -and $readmeAge.Days -gt $Configuration.changeThresholds.codeChangeReviewDays -and $CurrentMetrics.mostRecentChange) {
        try {
            $lastChange = [DateTime]::Parse($CurrentMetrics.mostRecentChange)
            $changesSinceReadme = $lastChange -gt [DateTime]::Parse($PreviousState.readmeLastModified)
            
            if ($changesSinceReadme) {
                $analysis.needsReview = $true
                $analysis.reviewReasons += "Code changes detected since README last updated ($($readmeAge.Days) days ago)"
            }
        } catch {
            # Date parsing error
        }
    }
    
    if ($readmeAge -and $readmeAge.Days -gt $Configuration.changeThresholds.staleDays) {
        $analysis.needsReview = $true
        $analysis.reviewReasons += "README is stale (older than $($Configuration.changeThresholds.staleDays) days)"
    }
    
    if (-not $PreviousState.readmeExists) {
        $analysis.needsReview = $true
        $analysis.reviewReasons += "README is missing"
        $analysis.changeType = "new"
        $analysis.confidence = 100
    }
    
    # Determine overall assessment
    if ($analysis.hasSignificantChanges -or $analysis.needsReview) {
        $analysis.needsReview = $true
    }
    
    # Log findings
    if ($analysis.hasSignificantChanges) {
        $reasonText = $analysis.changeReasons -join "; "
        Write-Log "Significant changes detected in $($CurrentMetrics.directoryPath): $reasonText" -Level "WARN"
    }
    
    if ($analysis.needsReview) {
        $reviewText = $analysis.reviewReasons -join "; "
        Write-Log "Review needed for $($CurrentMetrics.directoryPath): $reviewText" -Level "INFO"
    }
    
    return $analysis
}

function Analyze-AllDirectories {
    <#
    .SYNOPSIS
    Analyzes all directories for content changes and documentation needs
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$State,
        
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        
        [Parameter(Mandatory = $false)]
        [string[]]$TargetDirectories = @()
    )
    
    $analysisResults = @{
        scanTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        totalAnalyzed = 0
        significantChanges = 0
        needsReview = 0
        autoGenerationCandidates = @()
        reviewRequired = @()
        detailedResults = @{}
    }
    
    $directoriesToAnalyze = if ($TargetDirectories.Count -gt 0) {
        $TargetDirectories
    } else {
        $State.directories.Keys
    }
    
    Write-Log "Analyzing $($directoriesToAnalyze.Count) directories for content changes..." -Level "INFO"
    
    foreach ($dirPath in $directoriesToAnalyze) {
        if (-not $State.directories.ContainsKey($dirPath)) {
            Write-Log "Directory not in state: $dirPath" -Level "WARN"
            continue
        }
        
        $fullPath = Join-Path $ProjectRoot $dirPath.TrimStart('/')
        if (-not (Test-Path $fullPath)) {
            Write-Log "Directory not found: $fullPath" -Level "WARN"
            continue
        }
        
        $analysisResults.totalAnalyzed++
        
        # Get current metrics
        $currentMetrics = Get-DirectoryContentMetrics -DirectoryPath $fullPath
        
        # Compare with previous state
        $previousState = $State.directories[$dirPath]
        $comparison = Compare-DirectoryMetrics -CurrentMetrics $currentMetrics -PreviousState $previousState -Configuration $State.configuration
        
        # Update state with current metrics
        $State.directories[$dirPath].totalCharCount = $currentMetrics.totalCharacters
        $State.directories[$dirPath].fileCount = $currentMetrics.totalFiles
        $State.directories[$dirPath].contentHash = $currentMetrics.contentHash
        $State.directories[$dirPath].lastContentScan = $currentMetrics.scanTime
        
        if ($currentMetrics.mostRecentChange) {
            $State.directories[$dirPath].mostRecentFileChange = $currentMetrics.mostRecentChange
        }
        
        # Process analysis results
        if ($comparison.hasSignificantChanges) {
            $analysisResults.significantChanges++
            $State.directories[$dirPath].changesSinceLastReadme = $true
            $State.directories[$dirPath].contentDeltaPercent = $comparison.deltaPercent
        }
        
        if ($comparison.needsReview) {
            $analysisResults.needsReview++
            $State.directories[$dirPath].flaggedForReview = $true
            $State.directories[$dirPath].reviewStatus = if (-not $previousState.readmeExists) { "missing" } else { "outdated" }
            
            # Categorize for action
            if ($comparison.changeType -eq "new" -or (-not $previousState.readmeExists)) {
                $analysisResults.autoGenerationCandidates += @{
                    path = $dirPath
                    reason = "Missing README"
                    priority = "high"
                    directoryType = $previousState.directoryType
                    confidence = $comparison.confidence
                }
            } else {
                $analysisResults.reviewRequired += @{
                    path = $dirPath
                    reasons = $comparison.reviewReasons
                    changeType = $comparison.changeType
                    deltaPercent = $comparison.deltaPercent
                    confidence = $comparison.confidence
                }
            }
        } else {
            $State.directories[$dirPath].flaggedForReview = $false
            $State.directories[$dirPath].reviewStatus = "current"
        }
        
        # Store detailed results
        $analysisResults.detailedResults[$dirPath] = @{
            metrics = $currentMetrics
            comparison = $comparison
            actionRequired = $comparison.needsReview
        }
    }
    
    Write-Log "Analysis complete: $($analysisResults.totalAnalyzed) analyzed, $($analysisResults.significantChanges) with significant changes, $($analysisResults.needsReview) need review" -Level "SUCCESS"
    
    return $analysisResults
}

function Export-ChangeAnalysis {
    <#
    .SYNOPSIS
    Exports detailed change analysis results to file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$AnalysisResults,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "change-analysis.json"
    )
    
    $exportData = @{
        analysisTime = $AnalysisResults.scanTime
        summary = @{
            totalAnalyzed = $AnalysisResults.totalAnalyzed
            significantChanges = $AnalysisResults.significantChanges
            needsReview = $AnalysisResults.needsReview
            autoGenerationCandidates = $AnalysisResults.autoGenerationCandidates.Count
            reviewRequired = $AnalysisResults.reviewRequired.Count
        }
        autoGenerationCandidates = $AnalysisResults.autoGenerationCandidates
        reviewRequired = $AnalysisResults.reviewRequired
        detailedResults = $AnalysisResults.detailedResults
    }
    
    try {
        $exportData | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
        Write-Log "Change analysis exported to: $OutputPath" -Level "SUCCESS"
    } catch {
        Write-Log "Error exporting analysis: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Main execution
try {
    $stateFilePath = Join-Path $ProjectRoot $StateFilePath
    
    # Load current state
    if (-not (Test-Path $stateFilePath)) {
        Write-Log "State file not found. Run Track-DocumentationState.ps1 -Initialize first." -Level "ERROR"
        exit 1
    }
    
    $content = Get-Content -Path $stateFilePath -Raw -Encoding UTF8
    $state = $content | ConvertFrom-Json -AsHashtable
    
    # Perform analysis
    $analysisResults = Analyze-AllDirectories -State $state -ProjectRoot $ProjectRoot -TargetDirectories $TargetDirectories
    
    # Save updated state
    $state | ConvertTo-Json -Depth 10 | Set-Content -Path $stateFilePath -Encoding UTF8
    
    # Export results if requested
    if ($ExportChanges) {
        Export-ChangeAnalysis -AnalysisResults $analysisResults -OutputPath (Join-Path $ProjectRoot "change-analysis.json")
    }
    
    # Output summary
    Write-Host "`n📊 Content Delta Analysis Summary:" -ForegroundColor Cyan
    Write-Host "  Total Analyzed: $($analysisResults.totalAnalyzed)" -ForegroundColor White
    Write-Host "  Significant Changes: $($analysisResults.significantChanges)" -ForegroundColor Yellow
    Write-Host "  Needs Review: $($analysisResults.needsReview)" -ForegroundColor Red
    Write-Host "  Auto-Generation Candidates: $($analysisResults.autoGenerationCandidates.Count)" -ForegroundColor Green
    Write-Host "  Manual Review Required: $($analysisResults.reviewRequired.Count)" -ForegroundColor Magenta
    
    if ($analysisResults.autoGenerationCandidates.Count -gt 0) {
        Write-Host "`n🤖 Auto-Generation Candidates:" -ForegroundColor Green
        foreach ($candidate in $analysisResults.autoGenerationCandidates) {
            Write-Host "  - $($candidate.path) ($($candidate.reason))" -ForegroundColor Gray
        }
    }
    
    if ($analysisResults.reviewRequired.Count -gt 0) {
        Write-Host "`n🔍 Manual Review Required:" -ForegroundColor Magenta
        foreach ($review in $analysisResults.reviewRequired) {
            $reasonText = $review.reasons -join ", "
            Write-Host "  - $($review.path) - $reasonText" -ForegroundColor Gray
        }
    }
    
    Write-Log "Content delta analysis completed successfully" -Level "SUCCESS"
    
} catch {
    Write-Log "Content delta analysis failed: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}