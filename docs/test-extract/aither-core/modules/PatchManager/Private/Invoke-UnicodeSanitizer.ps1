#Requires -Version 7.0

<#
.SYNOPSIS
    Sanitizes files by removing emoji and Unicode characters that can cause commit/output issues

.DESCRIPTION
    This function scans and cleans files of problematic Unicode characters, emoji, and 
    other non-standard characters that can cause issues with Git commits, console output,
    and cross-platform compatibility.

.PARAMETER FilePaths
    Array of file paths to sanitize

.PARAMETER ProjectRoot
    Project root directory (defaults to current location)

.PARAMETER DryRun
    Preview changes without applying them

.EXAMPLE
    Invoke-UnicodeSanitizer -FilePaths @("file1.ps1", "file2.md") -DryRun

.NOTES
    This is a core helper function for PatchManager to ensure clean commits.
#>

function Invoke-UnicodeSanitizer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$FilePaths = @(),
        
        [Parameter(Mandatory = $false)]
        [string]$ProjectRoot = (Get-Location).Path,
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )
    
    begin {
        Write-Verbose "Starting Unicode/Emoji sanitization process..."
        
        # Define problematic Unicode ranges and characters to remove/replace
        $ProblematicPatterns = @{
            # Emoji ranges (most common)
            '[\u{1F600}-\u{1F64F}]' = ''  # Emoticons
            '[\u{1F300}-\u{1F5FF}]' = ''  # Misc Symbols and Pictographs
            '[\u{1F680}-\u{1F6FF}]' = ''  # Transport and Map Symbols
            '[\u{1F700}-\u{1F77F}]' = ''  # Alchemical Symbols
            '[\u{1F780}-\u{1F7FF}]' = ''  # Geometric Shapes Extended
            '[\u{1F800}-\u{1F8FF}]' = ''  # Supplemental Arrows-C
            '[\u{1F900}-\u{1F9FF}]' = ''  # Supplemental Symbols and Pictographs
            '[\u{1FA00}-\u{1FA6F}]' = ''  # Chess Symbols
            '[\u{1FA70}-\u{1FAFF}]' = ''  # Symbols and Pictographs Extended-A
            '[\u{2600}-\u{26FF}]'   = ''  # Miscellaneous Symbols
            '[\u{2700}-\u{27BF}]'   = ''  # Dingbats
            
            # Common problematic characters
            '✅' = '[OK]'     # Green checkmark
            '❌' = '[FAIL]'   # Red X
            '⚠️' = '[WARN]'   # Warning
            '🎯' = '[TARGET]' # Target
            '🔥' = '[FIRE]'   # Fire
            '🚀' = '[ROCKET]' # Rocket
            '🎉' = '[PARTY]'  # Party
            '🔧' = '[TOOL]'   # Wrench
            '📊' = '[CHART]'  # Chart
            '🧹' = '[CLEAN]'  # Broom
            '🏆' = '[TROPHY]' # Trophy
            '⭐' = '[STAR]'   # Star
            '💡' = '[IDEA]'   # Lightbulb
            
            # Zero-width and invisible characters
            '[\u{200B}-\u{200F}]' = ''  # Zero-width characters
            '[\u{2060}-\u{206F}]' = ''  # Invisible characters
            '[\u{FFF0}-\u{FFFF}]' = ''  # Specials block
        }
        
        $SanitizationResults = @{
            FilesProcessed = 0
            FilesModified = 0
            CharactersRemoved = 0
            Errors = @()
            ModifiedFiles = @()
        }
    }
    
    process {
        try {
            # If no specific files provided, scan common file types
            if ($FilePaths.Count -eq 0) {
                Write-Verbose "No specific files provided, scanning project for common file types..."
                $FilePaths = Get-ChildItem -Path $ProjectRoot -Recurse -File | 
                    Where-Object { $_.Extension -in @('.ps1', '.psm1', '.psd1', '.md', '.txt', '.json', '.yml', '.yaml', '.py', '.js', '.ts') } |
                    Select-Object -ExpandProperty FullName
            }
            
            foreach ($FilePath in $FilePaths) {
                try {
                    if (-not (Test-Path $FilePath)) {
                        Write-Warning "File not found: $FilePath"
                        continue
                    }
                    
                    $SanitizationResults.FilesProcessed++
                    Write-Verbose "Processing file: $FilePath"
                    
                    # Read file content
                    $OriginalContent = Get-Content -Path $FilePath -Raw -Encoding UTF8
                    if (-not $OriginalContent) {
                        Write-Verbose "File is empty or could not be read: $FilePath"
                        continue
                    }
                    
                    $ModifiedContent = $OriginalContent
                    $CharacterCount = 0
                    
                    # Combine all patterns into a single regex
                    $CombinedPattern = [string]::Join('|', $ProblematicPatterns.Keys)
                    
                    # Apply the combined regex with dynamic replacement
                    $ModifiedContent = $ModifiedContent -replace $CombinedPattern, {
                        param($match)
                        $CharacterCount += $match.Length
                        return $ProblematicPatterns[$match.Value]
                    }
                    
                    # Check if content was modified
                    if ($ModifiedContent -ne $OriginalContent) {
                        $SanitizationResults.FilesModified++
                        $SanitizationResults.CharactersRemoved += $CharacterCount
                        $SanitizationResults.ModifiedFiles += $FilePath
                        
                        $RelativePath = $FilePath.Replace($ProjectRoot, '').TrimStart('\', '/')
                        
                        if ($DryRun) {
                            Write-Host "  [DRY RUN] Would sanitize: $RelativePath ($CharacterCount characters removed)" -ForegroundColor Yellow
                        } else {
                            # Write sanitized content back to file
                            Set-Content -Path $FilePath -Value $ModifiedContent -Encoding UTF8
                            Write-Host "  ✓ Sanitized: $RelativePath ($CharacterCount characters removed)" -ForegroundColor Green
                        }
                    }
                    
                } catch {
                    $ErrorMsg = "Failed to process file $FilePath : $($_.Exception.Message)"
                    $SanitizationResults.Errors += $ErrorMsg
                    Write-Warning $ErrorMsg
                }
            }
            
            # Summary
            if ($DryRun) {
                Write-Host "`n[DRY RUN] Unicode Sanitization Summary:" -ForegroundColor Cyan
            } else {
                Write-Host "`nUnicode Sanitization Complete:" -ForegroundColor Green
            }
            
            Write-Host "  Files Processed: $($SanitizationResults.FilesProcessed)" -ForegroundColor White
            Write-Host "  Files Modified: $($SanitizationResults.FilesModified)" -ForegroundColor White
            Write-Host "  Characters Removed: $($SanitizationResults.CharactersRemoved)" -ForegroundColor White
            
            if ($SanitizationResults.Errors.Count -gt 0) {
                Write-Host "  Errors: $($SanitizationResults.Errors.Count)" -ForegroundColor Red
            }
            
            return $SanitizationResults
            
        } catch {
            Write-Error "Unicode sanitization failed: $($_.Exception.Message)"
            throw
        }
    }
}

Export-ModuleMember -Function Invoke-UnicodeSanitizer
