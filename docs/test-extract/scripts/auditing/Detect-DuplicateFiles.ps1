# Detect-DuplicateFiles.ps1 - AI-Generated Duplicate File Detection System
# Part of AitherZero Unified Documentation & Test Automation

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ProjectRoot = (Get-Location),
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "./duplicate-files-report.json",
    
    [Parameter(Mandatory = $false)]
    [switch]$GenerateHTML,
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeDocumentation,
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeTests,
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeCode,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("High", "Medium", "Low", "All")]
    [string]$MinimumConfidence = "Medium",
    
    [Parameter(Mandatory = $false)]
    [int]$DaysThreshold = 30,
    
    [Parameter(Mandatory = $false)]
    [switch]$DetailedAnalysis
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

function Get-SimilarityScore {
    <#
    .SYNOPSIS
    Calculates similarity score between two file names using multiple algorithms
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name1,
        
        [Parameter(Mandatory = $true)]
        [string]$Name2
    )
    
    # Normalize names for comparison (remove extensions, convert to lowercase)
    $base1 = [System.IO.Path]::GetFileNameWithoutExtension($Name1).ToLower()
    $base2 = [System.IO.Path]::GetFileNameWithoutExtension($Name2).ToLower()
    
    # Calculate Levenshtein distance
    $distance = Get-LevenshteinDistance -String1 $base1 -String2 $base2
    $maxLength = [Math]::Max($base1.Length, $base2.Length)
    $levenshteinSimilarity = if ($maxLength -gt 0) { (1 - ($distance / $maxLength)) * 100 } else { 100 }
    
    # Calculate common substring ratio
    $commonLength = Get-LongestCommonSubstring -String1 $base1 -String2 $base2
    $substringRatio = if ($maxLength -gt 0) { ($commonLength / $maxLength) * 100 } else { 100 }
    
    # Calculate word similarity (for hyphenated or camelCase names)
    $words1 = Split-IntoWords -Text $base1
    $words2 = Split-IntoWords -Text $base2
    $wordSimilarity = Get-WordSetSimilarity -Words1 $words1 -Words2 $words2
    
    # Combined score (weighted average)
    $combinedScore = ($levenshteinSimilarity * 0.4) + ($substringRatio * 0.3) + ($wordSimilarity * 0.3)
    
    return [Math]::Round($combinedScore, 1)
}

function Get-LevenshteinDistance {
    <#
    .SYNOPSIS
    Calculates Levenshtein distance between two strings
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$String1,
        
        [Parameter(Mandatory = $true)]
        [string]$String2
    )
    
    $len1 = $String1.Length
    $len2 = $String2.Length
    
    if ($len1 -eq 0) { return $len2 }
    if ($len2 -eq 0) { return $len1 }
    
    $matrix = New-Object 'int[,]' ($len1 + 1), ($len2 + 1)
    
    for ($i = 0; $i -le $len1; $i++) { $matrix[$i, 0] = $i }
    for ($j = 0; $j -le $len2; $j++) { $matrix[0, $j] = $j }
    
    for ($i = 1; $i -le $len1; $i++) {
        for ($j = 1; $j -le $len2; $j++) {
            $cost = if ($String1[$i-1] -eq $String2[$j-1]) { 0 } else { 1 }
            $matrix[$i, $j] = [Math]::Min(
                [Math]::Min($matrix[$i-1, $j] + 1, $matrix[$i, $j-1] + 1),
                $matrix[$i-1, $j-1] + $cost
            )
        }
    }
    
    return $matrix[$len1, $len2]
}

function Get-LongestCommonSubstring {
    <#
    .SYNOPSIS
    Finds the length of the longest common substring
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$String1,
        
        [Parameter(Mandatory = $true)]
        [string]$String2
    )
    
    $len1 = $String1.Length
    $len2 = $String2.Length
    $maxLength = 0
    
    for ($i = 0; $i -lt $len1; $i++) {
        for ($j = 0; $j -lt $len2; $j++) {
            $length = 0
            while (($i + $length -lt $len1) -and ($j + $length -lt $len2) -and ($String1[$i + $length] -eq $String2[$j + $length])) {
                $length++
            }
            if ($length -gt $maxLength) {
                $maxLength = $length
            }
        }
    }
    
    return $maxLength
}

function Split-IntoWords {
    <#
    .SYNOPSIS
    Splits text into words using common separators and camelCase detection
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )
    
    # Split on common separators
    $words = $Text -split '[-_\s\.]' | Where-Object { $_ -ne '' }
    
    # Further split camelCase words
    $expandedWords = @()
    foreach ($word in $words) {
        # Split camelCase/PascalCase
        $camelSplit = $word -creplace '([a-z])([A-Z])', '$1 $2' -split '\s+'
        $expandedWords += $camelSplit | Where-Object { $_ -ne '' }
    }
    
    return $expandedWords | ForEach-Object { $_.ToLower() }
}

function Get-WordSetSimilarity {
    <#
    .SYNOPSIS
    Calculates similarity between two sets of words
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Words1,
        
        [Parameter(Mandatory = $true)]
        [string[]]$Words2
    )
    
    if ($Words1.Count -eq 0 -and $Words2.Count -eq 0) { return 100 }
    if ($Words1.Count -eq 0 -or $Words2.Count -eq 0) { return 0 }
    
    $intersection = $Words1 | Where-Object { $Words2 -contains $_ }
    $union = ($Words1 + $Words2) | Sort-Object -Unique
    
    return ($intersection.Count / $union.Count) * 100
}

function Test-AIGeneratedPattern {
    <#
    .SYNOPSIS
    Checks if a file name matches patterns typical of AI-generated duplicates
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileName,
        
        [Parameter(Mandatory = $false)]
        [string]$BaseName = ""
    )
    
    $suspiciousPatterns = @{
        "AI_VARIANT_WORDS" = @("fix", "fixed", "enhanced", "improved", "updated", "new", "revised", "modified", "corrected", "optimized", "refactored", "better", "final", "clean", "working", "temp", "tmp", "backup", "copy", "duplicate", "alternative", "alt", "version", "ver", "v2", "v3", "latest", "current")
        "AI_SUFFIXES" = @("-fix", "-fixed", "-enhanced", "-improved", "-updated", "-new", "-revised", "-modified", "-corrected", "-optimized", "-refactored", "-better", "-final", "-clean", "-working", "-temp", "-backup", "-copy", "-alt", "-v2", "-v3", "-latest")
        "AI_PREFIXES" = @("new-", "updated-", "fixed-", "improved-", "enhanced-", "revised-", "modified-", "corrected-", "optimized-", "refactored-", "better-", "final-", "clean-", "working-", "temp-", "backup-", "copy-", "alt-")
        "TIMESTAMP_PATTERNS" = @('\d{4}-\d{2}-\d{2}', '\d{8}', '\d{6}', '\d{4}\d{2}\d{2}')
        "NUMBER_SUFFIXES" = @('\d+$', '-\d+$', '_\d+$', '\(\d+\)$')
    }
    
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($FileName).ToLower()
    $confidence = 0
    $detectedPatterns = @()
    
    # Check for AI variant words
    foreach ($word in $suspiciousPatterns["AI_VARIANT_WORDS"]) {
        if ($baseName -match $word) {
            $confidence += 15
            $detectedPatterns += "Contains word: '$word'"
        }
    }
    
    # Check for AI suffixes
    foreach ($suffix in $suspiciousPatterns["AI_SUFFIXES"]) {
        if ($baseName.EndsWith($suffix)) {
            $confidence += 25
            $detectedPatterns += "Ends with: '$suffix'"
        }
    }
    
    # Check for AI prefixes
    foreach ($prefix in $suspiciousPatterns["AI_PREFIXES"]) {
        if ($baseName.StartsWith($prefix)) {
            $confidence += 25
            $detectedPatterns += "Starts with: '$prefix'"
        }
    }
    
    # Check for timestamp patterns
    foreach ($pattern in $suspiciousPatterns["TIMESTAMP_PATTERNS"]) {
        if ($baseName -match $pattern) {
            $confidence += 20
            $detectedPatterns += "Contains timestamp pattern"
        }
    }
    
    # Check for number suffixes
    foreach ($pattern in $suspiciousPatterns["NUMBER_SUFFIXES"]) {
        if ($baseName -match $pattern) {
            $confidence += 10
            $detectedPatterns += "Has numbered suffix"
        }
    }
    
    # Check for parenthetical additions
    if ($baseName -match '\([^)]+\)') {
        $confidence += 15
        $detectedPatterns += "Contains parenthetical text"
    }
    
    # Cap confidence at 100
    $confidence = [Math]::Min(100, $confidence)
    
    return @{
        confidence = $confidence
        patterns = $detectedPatterns
        isLikelyAIGenerated = $confidence -gt 60
    }
}

function Get-DuplicateFileAnalysis {
    <#
    .SYNOPSIS
    Performs comprehensive duplicate file analysis across the project
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        
        [Parameter(Mandatory = $false)]
        [bool]$IncludeDocumentation = $true,
        
        [Parameter(Mandatory = $false)]
        [bool]$IncludeTests = $true,
        
        [Parameter(Mandatory = $false)]
        [bool]$IncludeCode = $true,
        
        [Parameter(Mandatory = $false)]
        [int]$DaysThreshold = 30
    )
    
    Write-Log "Starting comprehensive duplicate file analysis..." -Level "INFO"
    
    $analysis = @{
        scanTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        projectRoot = $ProjectRoot
        configuration = @{
            includeDocumentation = $IncludeDocumentation
            includeTests = $IncludeTests
            includeCode = $IncludeCode
            daysThreshold = $DaysThreshold
            minimumSimilarity = 70
            minimumAIConfidence = 60
        }
        results = @{
            totalFilesScanned = 0
            suspiciousFiles = @()
            duplicateGroups = @()
            aiGeneratedCandidates = @()
            recentSimilarFiles = @()
        }
        summary = @{
            highConfidenceDuplicates = 0
            mediumConfidenceDuplicates = 0
            lowConfidenceDuplicates = 0
            aiGeneratedCandidates = 0
            recentDuplicates = 0
            totalFlagged = 0
        }
    }
    
    # Define file type patterns
    $fileTypePatterns = @{
        documentation = @("*.md", "*.txt", "*.rst", "*.adoc")
        tests = @("*.Tests.ps1", "*Test*.ps1", "*Spec*.ps1")
        code = @("*.ps1", "*.psm1", "*.psd1", "*.py", "*.js", "*.ts", "*.cs", "*.go", "*.java")
    }
    
    # Build file inclusion list
    $includePatterns = @()
    if ($IncludeDocumentation) { $includePatterns += $fileTypePatterns.documentation }
    if ($IncludeTests) { $includePatterns += $fileTypePatterns.tests }
    if ($IncludeCode) { $includePatterns += $fileTypePatterns.code }
    
    if ($includePatterns.Count -eq 0) {
        Write-Log "No file types selected for analysis" -Level "WARN"
        return $analysis
    }
    
    # Get all relevant files
    $allFiles = @()
    foreach ($pattern in $includePatterns) {
        $files = Get-ChildItem -Path $ProjectRoot -Filter $pattern -Recurse -ErrorAction SilentlyContinue | Where-Object {
            $_.FullName -notmatch '(\.git|node_modules|bin|obj|target|\.vscode)' -and
            -not $_.PSIsContainer
        }
        $allFiles += $files
    }
    
    $analysis.results.totalFilesScanned = $allFiles.Count
    Write-Log "Scanning $($allFiles.Count) files for duplicates..." -Level "INFO"
    
    # Group files by directory for more focused comparison
    $fileGroups = $allFiles | Group-Object { $_.DirectoryName }
    
    foreach ($group in $fileGroups) {
        $directoryFiles = @($group.Group)  # Force array
        
        # Skip if only one file in directory
        if ($directoryFiles.Count -lt 2) { continue }
        
        # Compare each file with every other file in the directory
        for ($i = 0; $i -lt $directoryFiles.Count; $i++) {
            for ($j = $i + 1; $j -lt $directoryFiles.Count; $j++) {
                $file1 = $directoryFiles[$i]
                $file2 = $directoryFiles[$j]
                
                # Skip if same file
                if ($file1.FullName -eq $file2.FullName) { continue }
                
                # Calculate similarity
                $similarity = Get-SimilarityScore -Name1 $file1.Name -Name2 $file2.Name
                
                if ($similarity -gt 70) {
                    try {
                        # Check AI generation patterns
                        $aiPattern1 = Test-AIGeneratedPattern -FileName $file1.Name
                        $aiPattern2 = Test-AIGeneratedPattern -FileName $file2.Name
                        
                        # Determine which is likely the original vs duplicate
                        $olderFile = if ($file1.LastWriteTime -lt $file2.LastWriteTime) { $file1 } else { $file2 }
                        $newerFile = if ($file1.LastWriteTime -ge $file2.LastWriteTime) { $file1 } else { $file2 }
                        
                        # Ensure we have proper DateTime objects and calculate time delta
                        $olderTime = $olderFile.LastWriteTime
                        $newerTime = $newerFile.LastWriteTime
                        $timeDelta = ($newerTime - $olderTime).TotalDays
                    
                    $duplicateGroup = @{
                        id = [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
                        similarity = $similarity
                        files = @(
                            @{
                                path = $file1.FullName.Replace($ProjectRoot, "").TrimStart('\', '/')
                                name = $file1.Name
                                size = $file1.Length
                                lastModified = $file1.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
                                isLikelyOriginal = ($file1 -eq $olderFile)
                                aiGeneratedConfidence = $aiPattern1.confidence
                                aiPatterns = $aiPattern1.patterns
                            },
                            @{
                                path = $file2.FullName.Replace($ProjectRoot, "").TrimStart('\', '/')
                                name = $file2.Name
                                size = $file2.Length
                                lastModified = $file2.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
                                isLikelyOriginal = ($file2 -eq $olderFile)
                                aiGeneratedConfidence = $aiPattern2.confidence
                                aiPatterns = $aiPattern2.patterns
                            }
                        )
                        timeDeltaDays = [Math]::Round($timeDelta, 1)
                        isRecentDuplicate = $timeDelta -le $DaysThreshold
                        confidence = Get-DuplicateConfidence -Similarity $similarity -TimeDelta $timeDelta -AIConfidence1 $aiPattern1.confidence -AIConfidence2 $aiPattern2.confidence
                        recommendedAction = Get-RecommendedAction -Similarity $similarity -TimeDelta $timeDelta -AIPattern1 $aiPattern1 -AIPattern2 $aiPattern2
                        category = Get-DuplicateCategory -File1 $file1 -File2 $file2
                    }
                    
                    $analysis.results.duplicateGroups += $duplicateGroup
                    
                    # Update summary counters
                    switch ($duplicateGroup.confidence) {
                        { $_ -gt 80 } { $analysis.summary.highConfidenceDuplicates++ }
                        { $_ -gt 60 } { $analysis.summary.mediumConfidenceDuplicates++ }
                        default { $analysis.summary.lowConfidenceDuplicates++ }
                    }
                    
                    if ($duplicateGroup.isRecentDuplicate) {
                        $analysis.summary.recentDuplicates++
                    }
                    
                    # Track AI-generated candidates
                    if ($aiPattern1.isLikelyAIGenerated -or $aiPattern2.isLikelyAIGenerated) {
                        $analysis.summary.aiGeneratedCandidates++
                    }
                    
                    } catch {
                        Write-Log "Error processing duplicate comparison for $($file1.Name) vs $($file2.Name): $($_.Exception.Message)" -Level "WARN"
                    }
                }
            }
        }
        
        # Also check for single files with AI patterns (potential orphaned duplicates)
        foreach ($file in $directoryFiles) {
            $aiPattern = Test-AIGeneratedPattern -FileName $file.Name
            if ($aiPattern.isLikelyAIGenerated) {
                $analysis.results.aiGeneratedCandidates += @{
                    path = $file.FullName.Replace($ProjectRoot, "").TrimStart('\', '/')
                    name = $file.Name
                    confidence = $aiPattern.confidence
                    patterns = $aiPattern.patterns
                    lastModified = $file.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
                    category = Get-FileCategory -File $file
                    recommendedAction = "Review for potential cleanup - likely AI-generated variant"
                }
            }
        }
    }
    
    $analysis.summary.totalFlagged = $analysis.results.duplicateGroups.Count + $analysis.results.aiGeneratedCandidates.Count
    
    Write-Log "Duplicate analysis completed: $($analysis.summary.totalFlagged) items flagged for review" -Level "SUCCESS"
    
    return $analysis
}

function Get-DuplicateConfidence {
    <#
    .SYNOPSIS
    Calculates overall confidence that files are duplicates needing cleanup
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [double]$Similarity,
        
        [Parameter(Mandatory = $true)]
        [double]$TimeDelta,
        
        [Parameter(Mandatory = $true)]
        [int]$AIConfidence1,
        
        [Parameter(Mandatory = $true)]
        [int]$AIConfidence2
    )
    
    $baseConfidence = $Similarity
    
    # Boost confidence if one file has high AI generation likelihood
    $maxAIConfidence = [Math]::Max($AIConfidence1, $AIConfidence2)
    if ($maxAIConfidence -gt 70) {
        $baseConfidence += 15
    } elseif ($maxAIConfidence -gt 50) {
        $baseConfidence += 10
    }
    
    # Boost confidence for recent duplicates
    if ($TimeDelta -le 7) {
        $baseConfidence += 10
    } elseif ($TimeDelta -le 30) {
        $baseConfidence += 5
    }
    
    return [Math]::Min(100, [Math]::Round($baseConfidence, 1))
}

function Get-RecommendedAction {
    <#
    .SYNOPSIS
    Provides recommended action for handling duplicate files
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [double]$Similarity,
        
        [Parameter(Mandatory = $true)]
        [double]$TimeDelta,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$AIPattern1,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$AIPattern2
    )
    
    # High similarity + recent creation + AI patterns = likely safe to delete newer
    if ($Similarity -gt 90 -and $TimeDelta -le 7 -and ($AIPattern1.isLikelyAIGenerated -or $AIPattern2.isLikelyAIGenerated)) {
        return "HIGH PRIORITY: Review and likely delete newer AI-generated duplicate"
    }
    
    # High similarity + AI patterns = review needed
    if ($Similarity -gt 85 -and ($AIPattern1.isLikelyAIGenerated -or $AIPattern2.isLikelyAIGenerated)) {
        return "Review for consolidation - likely AI-generated duplicate"
    }
    
    # Recent + AI patterns = investigate
    if ($TimeDelta -le 14 -and ($AIPattern1.confidence -gt 60 -or $AIPattern2.confidence -gt 60)) {
        return "Recent potential AI duplicate - investigate and compare content"
    }
    
    # High similarity = manual review
    if ($Similarity -gt 80) {
        return "Manual review recommended - high similarity detected"
    }
    
    return "Monitor - moderate similarity detected"
}

function Get-DuplicateCategory {
    <#
    .SYNOPSIS
    Categorizes the duplicate based on file types
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File1,
        
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File2
    )
    
    $ext1 = $File1.Extension.ToLower()
    $ext2 = $File2.Extension.ToLower()
    
    if ($ext1 -in @('.md', '.txt', '.rst') -or $ext2 -in @('.md', '.txt', '.rst')) {
        return "Documentation"
    } elseif ($File1.Name -match 'Test' -or $File2.Name -match 'Test') {
        return "Tests"
    } elseif ($ext1 -in @('.ps1', '.psm1', '.psd1') -or $ext2 -in @('.ps1', '.psm1', '.psd1')) {
        return "PowerShell Code"
    } elseif ($ext1 -in @('.py', '.js', '.ts', '.cs') -or $ext2 -in @('.py', '.js', '.ts', '.cs')) {
        return "Source Code"
    } else {
        return "Other"
    }
}

function Get-FileCategory {
    <#
    .SYNOPSIS
    Categorizes a single file by type
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File
    )
    
    $ext = $File.Extension.ToLower()
    
    if ($ext -in @('.md', '.txt', '.rst')) {
        return "Documentation"
    } elseif ($File.Name -match 'Test') {
        return "Tests"
    } elseif ($ext -in @('.ps1', '.psm1', '.psd1')) {
        return "PowerShell Code"
    } elseif ($ext -in @('.py', '.js', '.ts', '.cs')) {
        return "Source Code"
    } else {
        return "Other"
    }
}

function Export-DuplicateAnalysisReport {
    <#
    .SYNOPSIS
    Exports duplicate analysis results to JSON and optionally HTML
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Analysis,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $false)]
        [switch]$GenerateHTML
    )
    
    try {
        # Export JSON report
        $Analysis | ConvertTo-Json -Depth 15 | Set-Content -Path $OutputPath -Encoding UTF8
        Write-Log "Duplicate analysis report exported to: $OutputPath" -Level "SUCCESS"
        
        if ($GenerateHTML) {
            $htmlPath = $OutputPath -replace '\.json$', '.html'
            $htmlReport = Generate-DuplicateHTMLReport -Analysis $Analysis
            Set-Content -Path $htmlPath -Value $htmlReport -Encoding UTF8
            Write-Log "HTML report exported to: $htmlPath" -Level "SUCCESS"
        }
        
    } catch {
        Write-Log "Error exporting duplicate analysis report: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Generate-DuplicateHTMLReport {
    <#
    .SYNOPSIS
    Generates an HTML report for duplicate file analysis
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Analysis
    )
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>AitherZero Duplicate Files Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1, h2, h3 { color: #2c3e50; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }
        .summary-card { background: #ecf0f1; padding: 15px; border-radius: 6px; text-align: center; }
        .summary-card h3 { margin: 0 0 10px 0; font-size: 14px; color: #7f8c8d; }
        .summary-card .value { font-size: 24px; font-weight: bold; color: #2c3e50; }
        .high-confidence { background: #e74c3c; color: white; }
        .medium-confidence { background: #f39c12; color: white; }
        .low-confidence { background: #f1c40f; color: black; }
        .ai-generated { background: #9b59b6; color: white; }
        .recent { background: #3498db; color: white; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #34495e; color: white; }
        tr:hover { background-color: #f5f5f5; }
        .confidence-high { background-color: #ffebee; }
        .confidence-medium { background-color: #fff3e0; }
        .confidence-low { background-color: #f3e5f5; }
        .action-high { font-weight: bold; color: #c62828; }
        .action-medium { color: #f57c00; }
        .action-low { color: #388e3c; }
        .patterns { font-size: 12px; color: #666; }
        .file-path { font-family: monospace; font-size: 12px; color: #37474f; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔍 AitherZero Duplicate Files Report</h1>
        <p><strong>Generated:</strong> $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
        <p><strong>Scan Time:</strong> $($Analysis.scanTime)</p>
        <p><strong>Files Scanned:</strong> $($Analysis.results.totalFilesScanned)</p>
        
        <h2>📊 Summary</h2>
        <div class="summary">
            <div class="summary-card high-confidence">
                <h3>High Confidence</h3>
                <div class="value">$($Analysis.summary.highConfidenceDuplicates)</div>
            </div>
            <div class="summary-card medium-confidence">
                <h3>Medium Confidence</h3>
                <div class="value">$($Analysis.summary.mediumConfidenceDuplicates)</div>
            </div>
            <div class="summary-card low-confidence">
                <h3>Low Confidence</h3>
                <div class="value">$($Analysis.summary.lowConfidenceDuplicates)</div>
            </div>
            <div class="summary-card ai-generated">
                <h3>AI Generated</h3>
                <div class="value">$($Analysis.summary.aiGeneratedCandidates)</div>
            </div>
            <div class="summary-card recent">
                <h3>Recent Duplicates</h3>
                <div class="value">$($Analysis.summary.recentDuplicates)</div>
            </div>
        </div>
        
        <h2>🔄 Duplicate Groups</h2>
"@

    if ($Analysis.results.duplicateGroups.Count -gt 0) {
        $html += @"
        <table>
            <thead>
                <tr>
                    <th>Files</th>
                    <th>Similarity</th>
                    <th>Confidence</th>
                    <th>Category</th>
                    <th>Time Delta</th>
                    <th>Recommended Action</th>
                </tr>
            </thead>
            <tbody>
"@
        
        foreach ($group in $Analysis.results.duplicateGroups) {
            $confidenceClass = switch ($group.confidence) {
                { $_ -gt 80 } { "confidence-high" }
                { $_ -gt 60 } { "confidence-medium" }
                default { "confidence-low" }
            }
            
            $actionClass = switch ($group.confidence) {
                { $_ -gt 80 } { "action-high" }
                { $_ -gt 60 } { "action-medium" }
                default { "action-low" }
            }
            
            $filesInfo = ""
            foreach ($file in $group.files) {
                $aiInfo = if ($file.aiGeneratedConfidence -gt 50) { " (AI: $($file.aiGeneratedConfidence)%)" } else { "" }
                $originalBadge = if ($file.isLikelyOriginal) { " [ORIGINAL]" } else { " [DUPLICATE]" }
                $filesInfo += "<div class='file-path'>$($file.path)$originalBadge$aiInfo</div>"
            }
            
            $html += @"
                <tr class="$confidenceClass">
                    <td>$filesInfo</td>
                    <td>$($group.similarity)%</td>
                    <td>$($group.confidence)%</td>
                    <td>$($group.category)</td>
                    <td>$($group.timeDeltaDays) days</td>
                    <td class="$actionClass">$($group.recommendedAction)</td>
                </tr>
"@
        }
        
        $html += @"
            </tbody>
        </table>
"@
    } else {
        $html += "<p>No duplicate groups found.</p>"
    }

    if ($Analysis.results.aiGeneratedCandidates.Count -gt 0) {
        $html += @"
        <h2>🤖 AI-Generated File Candidates</h2>
        <table>
            <thead>
                <tr>
                    <th>File Path</th>
                    <th>AI Confidence</th>
                    <th>Patterns Detected</th>
                    <th>Category</th>
                    <th>Last Modified</th>
                    <th>Recommended Action</th>
                </tr>
            </thead>
            <tbody>
"@
        
        foreach ($candidate in $Analysis.results.aiGeneratedCandidates) {
            $patternsText = $candidate.patterns -join ", "
            $html += @"
                <tr>
                    <td class="file-path">$($candidate.path)</td>
                    <td>$($candidate.confidence)%</td>
                    <td class="patterns">$patternsText</td>
                    <td>$($candidate.category)</td>
                    <td>$($candidate.lastModified)</td>
                    <td class="action-medium">$($candidate.recommendedAction)</td>
                </tr>
"@
        }
        
        $html += @"
            </tbody>
        </table>
"@
    }

    $html += @"
        <h2>⚙️ Configuration</h2>
        <ul>
            <li><strong>Include Documentation:</strong> $($Analysis.configuration.includeDocumentation)</li>
            <li><strong>Include Tests:</strong> $($Analysis.configuration.includeTests)</li>
            <li><strong>Include Code:</strong> $($Analysis.configuration.includeCode)</li>
            <li><strong>Days Threshold:</strong> $($Analysis.configuration.daysThreshold)</li>
            <li><strong>Minimum Similarity:</strong> $($Analysis.configuration.minimumSimilarity)%</li>
            <li><strong>Minimum AI Confidence:</strong> $($Analysis.configuration.minimumAIConfidence)%</li>
        </ul>
        
        <hr>
        <p style="text-align: center; color: #7f8c8d; font-size: 12px;">
            Generated by AitherZero Duplicate File Detection System<br>
            🤖 Designed for AI + Human Engineering Teams
        </p>
    </div>
</body>
</html>
"@

    return $html
}

# Main execution
try {
    Write-Log "Starting AitherZero duplicate file detection..." -Level "INFO"
    
    # Set default inclusion based on parameters
    $includeDoc = if ($PSBoundParameters.ContainsKey('IncludeDocumentation')) { $IncludeDocumentation.IsPresent } else { $true }
    $includeTest = if ($PSBoundParameters.ContainsKey('IncludeTests')) { $IncludeTests.IsPresent } else { $true }
    $includeCode = if ($PSBoundParameters.ContainsKey('IncludeCode')) { $IncludeCode.IsPresent } else { $true }
    
    # Perform duplicate analysis
    $analysis = Get-DuplicateFileAnalysis -ProjectRoot $ProjectRoot -IncludeDocumentation $includeDoc -IncludeTests $includeTest -IncludeCode $includeCode -DaysThreshold $DaysThreshold
    
    # Filter results by minimum confidence if specified
    if ($MinimumConfidence -ne "All") {
        $confidenceThreshold = switch ($MinimumConfidence) {
            "High" { 80 }
            "Medium" { 60 }
            "Low" { 40 }
        }
        
        $analysis.results.duplicateGroups = $analysis.results.duplicateGroups | Where-Object { $_.confidence -ge $confidenceThreshold }
        $analysis.results.aiGeneratedCandidates = $analysis.results.aiGeneratedCandidates | Where-Object { $_.confidence -ge $confidenceThreshold }
    }
    
    # Export results
    Export-DuplicateAnalysisReport -Analysis $analysis -OutputPath $OutputPath -GenerateHTML:$GenerateHTML
    
    # Display summary
    Write-Host "`n🔍 Duplicate File Detection Summary:" -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "  Files Scanned: $($analysis.results.totalFilesScanned)" -ForegroundColor White
    Write-Host "  Duplicate Groups: $($analysis.results.duplicateGroups.Count)" -ForegroundColor Yellow
    Write-Host "  AI-Generated Candidates: $($analysis.results.aiGeneratedCandidates.Count)" -ForegroundColor Magenta
    Write-Host "  High Confidence: $($analysis.summary.highConfidenceDuplicates)" -ForegroundColor Red
    Write-Host "  Medium Confidence: $($analysis.summary.mediumConfidenceDuplicates)" -ForegroundColor Yellow
    Write-Host "  Recent Duplicates: $($analysis.summary.recentDuplicates)" -ForegroundColor Blue
    Write-Host "  Total Flagged: $($analysis.summary.totalFlagged)" -ForegroundColor Magenta
    
    if ($analysis.summary.totalFlagged -gt 0) {
        Write-Host "`n🚨 Action Required:" -ForegroundColor Red
        
        # Show top priority items
        $highPriorityGroups = $analysis.results.duplicateGroups | Where-Object { $_.recommendedAction -match "HIGH PRIORITY" } | Select-Object -First 5
        if ($highPriorityGroups.Count -gt 0) {
            Write-Host "  High Priority Duplicates:" -ForegroundColor Red
            foreach ($group in $highPriorityGroups) {
                $file1 = $group.files[0].path
                $file2 = $group.files[1].path
                Write-Host "    - $file1 vs $file2 ($($group.similarity)% similar)" -ForegroundColor Gray
            }
        }
        
        # Show AI-generated candidates
        $aiCandidates = $analysis.results.aiGeneratedCandidates | Where-Object { $_.confidence -gt 70 } | Select-Object -First 5
        if ($aiCandidates.Count -gt 0) {
            Write-Host "  High-Confidence AI Generated Files:" -ForegroundColor Magenta
            foreach ($candidate in $aiCandidates) {
                Write-Host "    - $($candidate.path) ($($candidate.confidence)% AI confidence)" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "`n✅ No significant duplicates detected!" -ForegroundColor Green
    }
    
    Write-Log "Duplicate file detection completed successfully" -Level "SUCCESS"
    
} catch {
    Write-Log "Duplicate file detection failed: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}