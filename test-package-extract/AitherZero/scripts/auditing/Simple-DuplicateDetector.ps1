# Simple-DuplicateDetector.ps1 - Basic Duplicate File Detection
# Simplified version focusing on AI-generated duplicate patterns

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ProjectRoot = (Get-Location),

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "./duplicate-files-simple.json",

    [Parameter(Mandatory = $false)]
    [int]$DaysThreshold = 30
)

# Find project root if not specified
if (-not (Test-Path $ProjectRoot)) {
    . "$PSScriptRoot/../../aither-core/shared/Find-ProjectRoot.ps1"
    $ProjectRoot = Find-ProjectRoot
}

# Import logging if available
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

function Test-AIPattern {
    param([string]$FileName)

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($FileName).ToLower()
    $suspiciousWords = @("fix", "fixed", "enhanced", "improved", "updated", "new", "revised", "modified", "corrected", "optimized", "refactored", "better", "final", "clean", "working", "temp", "tmp", "backup", "copy", "duplicate", "alternative", "alt", "version", "ver", "v2", "v3", "latest", "current")

    $confidence = 0
    $patterns = @()

    foreach ($word in $suspiciousWords) {
        if ($baseName -match $word) {
            $confidence += 20
            $patterns += "Contains: '$word'"
        }
    }

    # Check for number suffixes
    if ($baseName -match '\d+$' -or $baseName -match '-\d+$' -or $baseName -match '_\d+$') {
        $confidence += 15
        $patterns += "Has numbered suffix"
    }

    # Check for parenthetical additions
    if ($baseName -match '\([^)]+\)') {
        $confidence += 10
        $patterns += "Contains parenthetical text"
    }

    return @{
        confidence = [Math]::Min(100, $confidence)
        patterns = $patterns
        isLikelySuspicious = $confidence -gt 30
    }
}

function Get-SimpleSimilarity {
    param([string]$Name1, [string]$Name2)

    $base1 = [System.IO.Path]::GetFileNameWithoutExtension($Name1).ToLower()
    $base2 = [System.IO.Path]::GetFileNameWithoutExtension($Name2).ToLower()

    # Simple character-based similarity
    $maxLen = [Math]::Max($base1.Length, $base2.Length)
    if ($maxLen -eq 0) { return 100 }

    $commonChars = 0
    $minLen = [Math]::Min($base1.Length, $base2.Length)

    for ($i = 0; $i -lt $minLen; $i++) {
        if ($base1[$i] -eq $base2[$i]) {
            $commonChars++
        }
    }

    # Also check for common substrings
    $similarity = ($commonChars / $maxLen) * 100

    # Boost similarity for obvious patterns
    if ($base1.StartsWith($base2) -or $base2.StartsWith($base1)) {
        $similarity += 20
    }

    return [Math]::Min(100, [Math]::Round($similarity, 1))
}

try {
    Write-Log "Starting simple duplicate file detection..." -Level "INFO"

    # Get all relevant files
    $allFiles = @()
    $patterns = @("*.ps1", "*.psm1", "*.psd1", "*.md", "*.txt", "*.py", "*.js", "*.ts")

    foreach ($pattern in $patterns) {
        $files = Get-ChildItem -Path $ProjectRoot -Filter $pattern -Recurse -ErrorAction SilentlyContinue | Where-Object {
            $_.FullName -notmatch '(\.git|node_modules|bin|obj|target|\.vscode)' -and
            -not $_.PSIsContainer
        }
        $allFiles += $files
    }

    Write-Log "Scanning $($allFiles.Count) files..." -Level "INFO"

    $results = @{
        scanTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        totalFiles = $allFiles.Count
        suspiciousFiles = @()
        potentialDuplicates = @()
        summary = @{
            aiSuspicious = 0
            similarPairs = 0
            recentFiles = 0
        }
    }

    # Check each file for AI patterns
    foreach ($file in $allFiles) {
        $aiCheck = Test-AIPattern -FileName $file.Name

        if ($aiCheck.isLikelySuspicious) {
            $daysOld = ((Get-Date) - $file.LastWriteTime).TotalDays

            $results.suspiciousFiles += @{
                path = $file.FullName.Replace($ProjectRoot, "").TrimStart('\', '/')
                name = $file.Name
                confidence = $aiCheck.confidence
                patterns = $aiCheck.patterns
                daysOld = [Math]::Round($daysOld, 1)
                isRecent = $daysOld -le $DaysThreshold
                size = $file.Length
                lastModified = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            }

            $results.summary.aiSuspicious++

            if ($daysOld -le $DaysThreshold) {
                $results.summary.recentFiles++
            }
        }
    }

    # Group files by directory for similarity checking
    $filesByDir = $allFiles | Group-Object { $_.DirectoryName }

    foreach ($dirGroup in $filesByDir) {
        $dirFiles = @($dirGroup.Group)

        if ($dirFiles.Count -lt 2) { continue }

        for ($i = 0; $i -lt $dirFiles.Count; $i++) {
            for ($j = $i + 1; $j -lt $dirFiles.Count; $j++) {
                $file1 = $dirFiles[$i]
                $file2 = $dirFiles[$j]

                $similarity = Get-SimpleSimilarity -Name1 $file1.Name -Name2 $file2.Name

                if ($similarity -gt 70) {
                    $timeDiff = [Math]::Abs(($file1.LastWriteTime - $file2.LastWriteTime).TotalDays)

                    $results.potentialDuplicates += @{
                        file1 = @{
                            path = $file1.FullName.Replace($ProjectRoot, "").TrimStart('\', '/')
                            name = $file1.Name
                            size = $file1.Length
                            modified = $file1.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                        }
                        file2 = @{
                            path = $file2.FullName.Replace($ProjectRoot, "").TrimStart('\', '/')
                            name = $file2.Name
                            size = $file2.Length
                            modified = $file2.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                        }
                        similarity = $similarity
                        timeDifference = [Math]::Round($timeDiff, 1)
                        isRecent = $timeDiff -le $DaysThreshold
                        priority = if ($similarity -gt 90 -and $timeDiff -le 7) { "HIGH" } elseif ($similarity -gt 80) { "MEDIUM" } else { "LOW" }
                    }

                    $results.summary.similarPairs++
                }
            }
        }
    }

    # Export results
    $results | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
    Write-Log "Results exported to: $OutputPath" -Level "SUCCESS"

    # Display summary
    Write-Host "`n🔍 Simple Duplicate Detection Results:" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "  Files Scanned: $($results.totalFiles)" -ForegroundColor White
    Write-Host "  AI-Suspicious Files: $($results.summary.aiSuspicious)" -ForegroundColor Yellow
    Write-Host "  Similar File Pairs: $($results.summary.similarPairs)" -ForegroundColor Blue
    Write-Host "  Recent Duplicates: $($results.summary.recentFiles)" -ForegroundColor Red

    if ($results.suspiciousFiles.Count -gt 0) {
        Write-Host "`n🤖 Top AI-Suspicious Files:" -ForegroundColor Yellow
        $topSuspicious = $results.suspiciousFiles | Sort-Object confidence -Descending | Select-Object -First 5
        foreach ($file in $topSuspicious) {
            $patternsText = $file.patterns -join ", "
            Write-Host "  - $($file.name) ($($file.confidence)% confidence: $patternsText)" -ForegroundColor Gray
        }
    }

    if ($results.potentialDuplicates.Count -gt 0) {
        Write-Host "`n🔄 Top Similar File Pairs:" -ForegroundColor Blue
        $topDuplicates = $results.potentialDuplicates | Sort-Object similarity -Descending | Select-Object -First 5
        foreach ($dup in $topDuplicates) {
            Write-Host "  - $($dup.file1.name) vs $($dup.file2.name) ($($dup.similarity)% similar, $($dup.priority) priority)" -ForegroundColor Gray
        }
    }

    Write-Log "Simple duplicate detection completed successfully" -Level "SUCCESS"

} catch {
    Write-Log "Simple duplicate detection failed: $($_.Exception.Message)" -Level "ERROR"
    Write-Host "Error details: $($_.Exception)" -ForegroundColor Red
    exit 1
}
