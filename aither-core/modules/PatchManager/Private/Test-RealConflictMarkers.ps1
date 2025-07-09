#Requires -Version 7.0

<#
.SYNOPSIS
    Smart detection of real git conflict markers vs test content

.DESCRIPTION
    This function distinguishes between actual git merge conflicts and legitimate
    test code that contains conflict markers as part of its functionality.
    
    Real conflicts are detected by:
    1. Git status showing conflicted files
    2. Conflict markers in files that aren't test-related
    3. Conflict markers outside of string literals or test functions
    
.PARAMETER ExcludeTestFiles
    Whether to exclude test files from conflict detection (default: true)

.EXAMPLE
    Test-RealConflictMarkers
    
.EXAMPLE  
    Test-RealConflictMarkers -ExcludeTestFiles:$false
#>

function Test-RealConflictMarkers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$ExcludeTestFiles
    )

    begin {
        # Initialize logging
        if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
            function Write-CustomLog {
                param($Message, $Level = "INFO")
                Write-Information "[$Level] $Message" -InformationAction Continue
            }
        }
    }

    process {
        # First check git status for actual conflicted files
        $gitStatus = git status --porcelain 2>&1
        $conflictedFiles = @()
        
        if ($gitStatus) {
            $conflictedFiles = $gitStatus | Where-Object { $_ -match '^UU|^AA|^DD|^AU|^UA|^DU|^UD' } | ForEach-Object { $_.Substring(3) }
        }
        
        if ($conflictedFiles.Count -gt 0) {
            Write-CustomLog "Git reports conflicted files: $($conflictedFiles -join ', ')" -Level "WARN"
            return @{
                HasRealConflicts = $true
                ConflictedFiles = $conflictedFiles
                DetectionMethod = "Git Status"
                Message = "Git status reports unresolved merge conflicts"
            }
        }
        
        # Search for conflict markers in files
        $allConflictFiles = git grep -l "^<<<<<<< " 2>$null
        if (-not $allConflictFiles) {
            return @{
                HasRealConflicts = $false
                ConflictedFiles = @()
                DetectionMethod = "Content Analysis"
                Message = "No conflict markers found"
            }
        }
        
        $realConflicts = @()
        
        foreach ($file in $allConflictFiles) {
            # Skip test files if requested
            if ($ExcludeTestFiles.IsPresent -and ($file -match '\.Tests?\.' -or $file -match '/tests?/' -or $file -match '\\tests?\\' -or $file -match 'MockHelpers' -or $file -match 'TestHelpers')) {
                Write-CustomLog "Skipping test file: $file" -Level "DEBUG"
                continue
            }
            
            # Analyze file content for legitimate vs real conflicts
            try {
                $content = Get-Content $file -Raw -ErrorAction Stop
                $isRealConflict = Test-ConflictMarkersInContent -Content $content -FilePath $file
                
                if ($isRealConflict) {
                    $realConflicts += $file
                }
            } catch {
                Write-CustomLog "Could not analyze file $file : $($_.Exception.Message)" -Level "WARN"
                # If we can't read the file, assume it might be a real conflict
                $realConflicts += $file
            }
        }
        
        return @{
            HasRealConflicts = $realConflicts.Count -gt 0
            ConflictedFiles = $realConflicts
            DetectionMethod = "Smart Analysis"
            Message = if ($realConflicts.Count -gt 0) { 
                "Real merge conflicts detected in: $($realConflicts -join ', ')" 
            } else { 
                "Conflict markers found but appear to be test content" 
            }
        }
    }
}

<#
.SYNOPSIS
    Analyze content to determine if conflict markers are real or test code

.PARAMETER Content
    File content to analyze

.PARAMETER FilePath
    Path to the file for context
#>
function Test-ConflictMarkersInContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,
        
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    # Look for conflict marker patterns
    $conflictStartPattern = '<<<<<<< .*'
    $conflictSeparatorPattern = '======='
    $conflictEndPattern = '>>>>>>> .*'
    
    $conflictStarts = [regex]::Matches($Content, $conflictStartPattern, [Text.RegularExpressions.RegexOptions]::Multiline)
    $conflictSeparators = [regex]::Matches($Content, $conflictSeparatorPattern, [Text.RegularExpressions.RegexOptions]::Multiline)
    $conflictEnds = [regex]::Matches($Content, $conflictEndPattern, [Text.RegularExpressions.RegexOptions]::Multiline)
    
    # Check if we have a complete conflict marker set
    if ($conflictStarts.Count -eq 0) {
        return $false
    }
    
    # Heuristics to detect if this is test code vs real conflicts:
    
    # 1. If it's in a string literal or here-string, likely test code
    $lines = $Content -split "`n"
    $inHereString = $false
    $hereStringPattern = $null
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].Trim()
        
        # Track here-strings
        if ($line -match '^@["'']$') {
            $inHereString = $true
            $hereStringPattern = $line
            continue
        }
        
        if ($inHereString -and $line -match "^$([regex]::Escape($hereStringPattern.Substring(1)))$") {
            $inHereString = $false
            continue
        }
        
        # If conflict marker is in here-string, it's likely test code
        if ($inHereString -and $line -match $conflictStartPattern) {
            Write-CustomLog "Conflict marker found in here-string (test code): ${FilePath}:$($i+1)" -Level "DEBUG"
            return $false
        }
        
        # 2. Check for test-related function context
        if ($line -match $conflictStartPattern) {
            # Look at surrounding context for test indicators
            $contextStart = [Math]::Max(0, $i - 10)
            $contextEnd = [Math]::Min($lines.Count - 1, $i + 10)
            $context = $lines[$contextStart..$contextEnd] -join "`n"
            
            # Test function patterns
            if ($context -match 'function.*(?:Add-GitConflictMarkers|Test-.*Conflict|Mock.*Conflict|.*ConflictMarkers)') {
                Write-CustomLog "Conflict marker found in test function context: ${FilePath}:$($i+1)" -Level "DEBUG"
                return $false
            }
            
            # Test description patterns
            if ($context -match '(?:\.SYNOPSIS|\.DESCRIPTION|\.EXAMPLE).*conflict.*markers?' -or 
                $context -match 'test.*conflict.*markers?' -or
                $context -match 'simulated.*conflict' -or
                $context -match 'Add.*conflict.*markers') {
                Write-CustomLog "Conflict marker found in test documentation: ${FilePath}:$($i+1)" -Level "DEBUG"
                return $false
            }
            
            # If we get here, it might be a real conflict
            Write-CustomLog "Potential real conflict marker found: ${FilePath}:$($i+1)" -Level "WARN"
            return $true
        }
    }
    
    # 3. Check if conflict markers are properly balanced (real conflicts should be)
    if ($conflictStarts.Count -ne $conflictSeparators.Count -or 
        $conflictStarts.Count -ne $conflictEnds.Count) {
        Write-CustomLog "Unbalanced conflict markers - likely test content: ${FilePath}" -Level "DEBUG"
        return $false
    }
    
    # 4. If we found conflict markers but no clear test indicators, assume real conflict
    if ($conflictStarts.Count -gt 0) {
        Write-CustomLog "Conflict markers found outside test context - assuming real conflict: ${FilePath}" -Level "WARN"
        return $true
    }
    
    return $false
}

Export-ModuleMember -Function Test-RealConflictMarkers