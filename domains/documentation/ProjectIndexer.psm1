#Requires -Version 7.0

<#
.SYNOPSIS
    AitherZero Project Indexer - Automated index and navigation generation
.DESCRIPTION
    Provides comprehensive project indexing with intelligent directory analysis:
    - Automatic index.md generation for all directories
    - Hierarchical breadcrumb navigation (parent ← current → children)
    - Change detection via content hashing
    - AI-powered directory content analysis
    - Bidirectional navigation between directories
    - README.md auto-generation for empty directories
.NOTES
    Copyright © 2025 Aitherium Corporation
    Part of AitherZero infrastructure automation platform
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module state
$script:IndexerState = @{
    Config = $null
    ContentHashes = @{}
    LastIndexTime = $null
    IndexedPaths = @()
    ChangeLog = @()
}

# Import dependencies
$script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:LoggingModule = Join-Path $script:ProjectRoot "domains/utilities/Logging.psm1"

if (Test-Path $script:LoggingModule) {
    Import-Module $script:LoggingModule -Force -ErrorAction SilentlyContinue
}

$script:LoggingAvailable = $null -ne (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)

function Write-IndexLog {
    param(
        [string]$Message,
        [ValidateSet('Debug', 'Information', 'Warning', 'Error')]
        [string]$Level = 'Information',
        [hashtable]$Data = @{}
    )
    
    if ($script:LoggingAvailable) {
        Write-CustomLog -Level $Level -Message $Message -Source "ProjectIndexer" -Data $Data
    } else {
        $color = switch ($Level) {
            'Debug' { 'Gray' }
            'Information' { 'White' }
            'Warning' { 'Yellow' }
            'Error' { 'Red' }
        }
        Write-Host "[$Level] [ProjectIndexer] $Message" -ForegroundColor $color
    }
}

#region Configuration

function Initialize-ProjectIndexer {
    <#
    .SYNOPSIS
        Initialize the project indexer with configuration
    .PARAMETER RootPath
        Root path of the project to index
    .PARAMETER ExcludePaths
        Array of paths/patterns to exclude from indexing
    .PARAMETER EnableAI
        Enable AI-powered content analysis (requires API key)
    #>
    [CmdletBinding()]
    param(
        [string]$RootPath = $script:ProjectRoot,
        [string[]]$ExcludePaths = @('.git', 'node_modules', '.vscode', 'bin', 'obj', 'dist', 'build'),
        [switch]$EnableAI
    )
    
    Write-IndexLog "Initializing Project Indexer" -Data @{
        RootPath = $RootPath
        ExcludePaths = $ExcludePaths -join ', '
        AIEnabled = $EnableAI.IsPresent
    }
    
    $script:IndexerState.Config = @{
        RootPath = $RootPath
        ExcludePaths = $ExcludePaths
        EnableAI = $EnableAI.IsPresent
        IndexFileName = 'index.md'
        ReadmeFileName = 'README.md'
        HashCacheFile = Join-Path $RootPath '.aitherzero-index-cache.json'
    }
    
    # Load cached hashes if available
    if (Test-Path $script:IndexerState.Config.HashCacheFile) {
        try {
            $cache = Get-Content $script:IndexerState.Config.HashCacheFile | ConvertFrom-Json -AsHashtable
            $script:IndexerState.ContentHashes = $cache.Hashes ?? @{}
            Write-IndexLog "Loaded hash cache with $($script:IndexerState.ContentHashes.Count) entries"
        } catch {
            Write-IndexLog "Failed to load hash cache: $_" -Level Warning
        }
    }
    
    Write-IndexLog "Project Indexer initialized successfully"
}

function Get-DefaultIndexerConfig {
    return @{
        RootPath = $script:ProjectRoot
        ExcludePaths = @('.git', 'node_modules', '.vscode', 'bin', 'obj', 'dist', 'build', 'reports', 'logs')
        EnableAI = $false
        IndexFileName = 'index.md'
        ReadmeFileName = 'README.md'
        NavigationStyle = 'Breadcrumb'  # Options: Breadcrumb, Tree, Both
        GenerateIndexForRoot = $true
        UpdateReadmeIfMissing = $true
        MinFilesForIndex = 0  # Always generate index
    }
}

function Get-IndexerConfig {
    <#
    .SYNOPSIS
        Get current indexer configuration
    #>
    [CmdletBinding()]
    param()
    
    return $script:IndexerState.Config
}

#endregion

#region Content Analysis

function Get-DirectoryContent {
    <#
    .SYNOPSIS
        Analyze directory contents and categorize items
    .PARAMETER Path
        Directory path to analyze
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path -PathType Container)) {
        Write-IndexLog "Path is not a directory: $Path" -Level Warning
        return $null
    }
    
    $config = $script:IndexerState.Config
    $items = Get-ChildItem -Path $Path -Force | Where-Object {
        $name = $_.Name
        -not ($config.ExcludePaths | Where-Object { $name -like $_ -or $name -eq $_ })
    }
    
    $analysis = @{
        Path = $Path
        Name = Split-Path $Path -Leaf
        Directories = @($items | Where-Object { $_.PSIsContainer })
        Files = @($items | Where-Object { -not $_.PSIsContainer })
        Scripts = @($items | Where-Object { $_.Extension -in @('.ps1', '.psm1', '.psd1') })
        Documentation = @($items | Where-Object { $_.Name -match '^(README|index|CHANGELOG|LICENSE)' })
        HasIndex = (Test-Path (Join-Path $Path $config.IndexFileName))
        HasReadme = (Test-Path (Join-Path $Path $config.ReadmeFileName))
    }
    
    return $analysis
}

function Get-ContentHash {
    <#
    .SYNOPSIS
        Calculate hash of directory contents for change detection
    .PARAMETER Path
        Directory path to hash
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    $content = Get-DirectoryContent -Path $Path
    if (-not $content) { return $null }
    
    # Create hash based on directory structure and file list
    $hashInput = @(
        $content.Directories | ForEach-Object { $_.Name }
        $content.Files | ForEach-Object { "$($_.Name)|$($_.Length)|$($_.LastWriteTime.Ticks)" }
    ) | Sort-Object | Out-String
    
    $hashBytes = [System.Text.Encoding]::UTF8.GetBytes($hashInput)
    $hash = [System.Security.Cryptography.SHA256]::HashData($hashBytes)
    return [System.BitConverter]::ToString($hash).Replace('-', '')
}

function Test-ContentChanged {
    <#
    .SYNOPSIS
        Check if directory content has changed since last index
    .PARAMETER Path
        Directory path to check
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    $currentHash = Get-ContentHash -Path $Path
    $cachedHash = $script:IndexerState.ContentHashes[$Path]
    
    $changed = ($null -eq $cachedHash) -or ($currentHash -ne $cachedHash)
    
    if ($changed) {
        Write-IndexLog "Content changed detected for: $Path" -Level Debug
    }
    
    return $changed
}

#endregion

#region Navigation Generation

function Get-NavigationPath {
    <#
    .SYNOPSIS
        Get breadcrumb navigation path for a directory
    .PARAMETER Path
        Directory path
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    $config = $script:IndexerState.Config
    $rootPath = $config.RootPath
    $relativePath = [System.IO.Path]::GetRelativePath($rootPath, $Path)
    
    if ($relativePath -eq '.') {
        return @{
            IsRoot = $true
            Parts = @()
            FullPath = $rootPath
            Parent = $null
        }
    }
    
    $parts = $relativePath.Split([IO.Path]::DirectorySeparatorChar) | Where-Object { $_ }
    $breadcrumb = @()
    
    $currentPath = $rootPath
    foreach ($part in $parts) {
        $currentPath = Join-Path $currentPath $part
        $breadcrumb += @{
            Name = $part
            Path = $currentPath
            RelativePath = [System.IO.Path]::GetRelativePath($Path, $currentPath)
        }
    }
    
    # Determine parent - either the last breadcrumb before current, or root
    $parent = $null
    if ($breadcrumb.Count -gt 1) {
        $parent = $breadcrumb[-2]
    } elseif ($breadcrumb.Count -eq 1) {
        # Parent is root
        $parent = @{
            Name = 'Root'
            Path = $rootPath
            RelativePath = [System.IO.Path]::GetRelativePath($Path, $rootPath)
        }
    }
    
    return @{
        IsRoot = $false
        Parts = $breadcrumb
        FullPath = $Path
        Parent = $parent
    }
}

function New-NavigationMarkdown {
    <#
    .SYNOPSIS
        Generate navigation markdown for index file
    .PARAMETER Path
        Directory path
    .PARAMETER Content
        Directory content analysis
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [hashtable]$Content
    )
    
    $nav = Get-NavigationPath -Path $Path
    $config = $script:IndexerState.Config
    $rootPath = $config.RootPath
    
    $md = [System.Text.StringBuilder]::new()
    
    # Header with navigation
    $null = $md.AppendLine("# $($Content.Name)")
    $null = $md.AppendLine()
    
    # Breadcrumb navigation
    if (-not $nav.IsRoot) {
        $null = $md.Append("**Navigation**: ")
        $null = $md.Append("[🏠 Root](")
        $rootIndexPath = [System.IO.Path]::GetRelativePath($Path, (Join-Path $rootPath $config.IndexFileName))
        $null = $md.Append($rootIndexPath.Replace('\', '/'))
        $null = $md.Append(")")
        
        if ($nav.Parts.Count -gt 1) {
            foreach ($part in $nav.Parts[0..($nav.Parts.Count - 2)]) {
                $null = $md.Append(" → ")
                $indexPath = [System.IO.Path]::GetRelativePath($Path, (Join-Path $part.Path $config.IndexFileName))
                $null = $md.Append("[$($part.Name)]($($indexPath.Replace('\', '/')))")
            }
        }
        
        $null = $md.Append(" → **$($Content.Name)**")
        $null = $md.AppendLine()
        $null = $md.AppendLine()
    }
    
    # Parent directory link
    if ($nav.Parent) {
        $parentIndexPath = [System.IO.Path]::GetRelativePath($Path, (Join-Path $nav.Parent.Path $config.IndexFileName))
        $null = $md.AppendLine("⬆️ **Parent**: [$($nav.Parent.Name)]($($parentIndexPath.Replace('\', '/')))")
        $null = $md.AppendLine()
    }
    
    # Description section
    $null = $md.AppendLine("## 📖 Overview")
    $null = $md.AppendLine()
    
    # Check if README exists for description
    $readmePath = Join-Path $Path $config.ReadmeFileName
    if (Test-Path $readmePath) {
        $null = $md.AppendLine("See [README.md](./$($config.ReadmeFileName)) for detailed information about this directory.")
    } else {
        $null = $md.AppendLine("*This directory contains AitherZero project files.*")
    }
    $null = $md.AppendLine()
    
    # Statistics
    $null = $md.AppendLine("### 📊 Contents")
    $null = $md.AppendLine()
    $null = $md.AppendLine("- **Subdirectories**: $($Content.Directories.Count)")
    $null = $md.AppendLine("- **Files**: $($Content.Files.Count)")
    if ($Content.Scripts.Count -gt 0) {
        $null = $md.AppendLine("- **PowerShell Scripts**: $($Content.Scripts.Count)")
    }
    $null = $md.AppendLine()
    
    # Subdirectories section
    if ($Content.Directories.Count -gt 0) {
        $null = $md.AppendLine("## 📁 Subdirectories")
        $null = $md.AppendLine()
        
        foreach ($dir in ($Content.Directories | Sort-Object Name)) {
            $dirIndexPath = Join-Path $dir.FullName $config.IndexFileName
            $hasIndex = Test-Path $dirIndexPath
            
            if ($hasIndex) {
                $relPath = "./$($dir.Name)/$($config.IndexFileName)"
                $null = $md.AppendLine("- [📂 **$($dir.Name)**]($relPath)")
            } else {
                $null = $md.AppendLine("- 📂 **$($dir.Name)**")
            }
            
            # Try to get description from README if exists
            $dirReadme = Join-Path $dir.FullName $config.ReadmeFileName
            if (Test-Path $dirReadme) {
                $readmeContent = Get-Content $dirReadme -TotalCount 20 -ErrorAction SilentlyContinue
                $description = $readmeContent | Where-Object { $_ -match '^\s*[^#\s]' } | Select-Object -First 1
                if ($description) {
                    $description = $description.Trim()
                    if ($description.Length -gt 100) {
                        $description = $description.Substring(0, 97) + "..."
                    }
                    $null = $md.AppendLine("  - *$description*")
                }
            }
        }
        $null = $md.AppendLine()
    }
    
    # Files section
    if ($Content.Files.Count -gt 0) {
        $null = $md.AppendLine("## 📄 Files")
        $null = $md.AppendLine()
        
        # Group files by type
        $fileGroups = $Content.Files | Group-Object Extension | Sort-Object Name
        
        foreach ($group in $fileGroups) {
            $extension = if ($group.Name) { $group.Name } else { "(no extension)" }
            $null = $md.AppendLine("### $extension Files")
            $null = $md.AppendLine()
            
            foreach ($file in ($group.Group | Sort-Object Name)) {
                $icon = switch -Regex ($file.Extension) {
                    '\.ps1$|\.psm1$|\.psd1$' { '⚙️' }
                    '\.md$' { '📝' }
                    '\.json$|\.yml$|\.yaml$|\.toml$' { '⚙️' }
                    '\.txt$|\.log$' { '📋' }
                    default { '📄' }
                }
                
                $null = $md.AppendLine("- $icon [$($file.Name)](./$($file.Name))")
                
                # Add description for scripts
                if ($file.Extension -in @('.ps1', '.psm1')) {
                    $synopsis = Get-ScriptSynopsis -Path $file.FullName
                    if ($synopsis) {
                        $null = $md.AppendLine("  - *$synopsis*")
                    }
                }
            }
            $null = $md.AppendLine()
        }
    }
    
    # Footer
    $null = $md.AppendLine("---")
    $null = $md.AppendLine()
    $null = $md.AppendLine("*Generated by AitherZero Project Indexer* • Last updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')")
    
    return $md.ToString()
}

function Get-ScriptSynopsis {
    <#
    .SYNOPSIS
        Extract synopsis from PowerShell script comment-based help
    .PARAMETER Path
        Script file path
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    try {
        $content = Get-Content $Path -TotalCount 50 -ErrorAction SilentlyContinue
        $inSynopsis = $false
        $synopsis = ""
        
        foreach ($line in $content) {
            if ($line -match '^\s*\.SYNOPSIS\s*$') {
                $inSynopsis = $true
                continue
            }
            
            if ($inSynopsis) {
                if ($line -match '^\s*\.(DESCRIPTION|PARAMETER|EXAMPLE|NOTES|LINK)') {
                    break
                }
                if ($line -match '^\s*#>') {
                    break
                }
                
                $trimmed = $line.Trim().TrimStart('#').Trim()
                if ($trimmed) {
                    $synopsis += " $trimmed"
                }
            }
        }
        
        return $synopsis.Trim()
    } catch {
        return $null
    }
}

#endregion

#region Index Generation

function Compare-IndexContent {
    <#
    .SYNOPSIS
        Compare generated index content with existing content, ignoring timestamp
    .PARAMETER ExistingContent
        Existing index file content
    .PARAMETER NewContent
        Newly generated index content
    .RETURNS
        $true if content differs (excluding timestamp), $false if identical
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ExistingContent,
        [Parameter(Mandatory)]
        [string]$NewContent
    )
    
    # Remove timestamp lines from both contents for comparison
    $timestampPattern = '\*Generated by AitherZero Project Indexer\* • Last updated:.*'
    
    $existingNormalized = $ExistingContent -replace $timestampPattern, ''
    $newNormalized = $NewContent -replace $timestampPattern, ''
    
    # Compare normalized content
    return $existingNormalized -ne $newNormalized
}

function New-DirectoryIndex {
    <#
    .SYNOPSIS
        Generate index.md for a specific directory
    .PARAMETER Path
        Directory path
    .PARAMETER Force
        Force regeneration even if content hasn't changed
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [switch]$Force
    )
    
    $config = $script:IndexerState.Config
    $indexPath = Join-Path $Path $config.IndexFileName
    
    # Skip root index.md - it's managed manually for GitHub Pages dashboard redirect
    $isRoot = ($Path -eq $config.RootPath) -or 
              ([System.IO.Path]::GetFullPath($Path) -eq [System.IO.Path]::GetFullPath($config.RootPath))
    if ($isRoot) {
        Write-IndexLog "Skipping root index.md (managed manually for GitHub Pages)" -Level Information
        return @{
            Success = $true
            Updated = $false
            Path = $indexPath
            Reason = 'RootProtected'
        }
    }
    
    # Check if update is needed
    if (-not $Force -and -not (Test-ContentChanged -Path $Path)) {
        Write-IndexLog "No changes detected for: $Path - skipping" -Level Debug
        return @{
            Success = $true
            Updated = $false
            Path = $indexPath
            Reason = 'NoChanges'
        }
    }
    
    Write-IndexLog "Generating index for: $Path"
    
    # Analyze directory content
    $content = Get-DirectoryContent -Path $Path
    if (-not $content) {
        return @{
            Success = $false
            Updated = $false
            Path = $indexPath
            Reason = 'InvalidPath'
        }
    }
    
    # Generate navigation markdown
    $markdown = New-NavigationMarkdown -Path $Path -Content $content
    
    # Check if index file exists and compare content (excluding timestamp)
    if ((Test-Path $indexPath) -and -not $Force) {
        try {
            $existingContent = Get-Content -Path $indexPath -Raw -ErrorAction Stop
            $contentChanged = Compare-IndexContent -ExistingContent $existingContent -NewContent $markdown
            
            if (-not $contentChanged) {
                Write-IndexLog "Index content unchanged for: $Path - skipping write" -Level Debug
                return @{
                    Success = $true
                    Updated = $false
                    Path = $indexPath
                    Reason = 'ContentUnchanged'
                }
            }
        } catch {
            Write-IndexLog "Could not read existing index for comparison: $_" -Level Debug
            # Continue with write if we can't read existing content
        }
    }
    
    # Write index file
    if ($PSCmdlet.ShouldProcess($indexPath, "Create/Update index file")) {
        try {
            Set-Content -Path $indexPath -Value $markdown -Encoding UTF8 -Force
            
            # Update hash cache
            $hash = Get-ContentHash -Path $Path
            $script:IndexerState.ContentHashes[$Path] = $hash
            
            Write-IndexLog "Index generated successfully: $indexPath"
            
            return @{
                Success = $true
                Updated = $true
                Path = $indexPath
                Reason = 'Generated'
            }
        } catch {
            Write-IndexLog "Failed to write index file: $_" -Level Error
            return @{
                Success = $false
                Updated = $false
                Path = $indexPath
                Reason = "Error: $_"
            }
        }
    }
    
    return @{
        Success = $true
        Updated = $false
        Path = $indexPath
        Reason = 'WhatIf'
    }
}

function New-ProjectIndexes {
    <#
    .SYNOPSIS
        Generate indexes for entire project tree
    .PARAMETER RootPath
        Root path to start indexing from
    .PARAMETER Recursive
        Generate indexes recursively for all subdirectories
    .PARAMETER Force
        Force regeneration even if content hasn't changed
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$RootPath = $script:IndexerState.Config.RootPath,
        [switch]$Recursive = $true,
        [switch]$Force
    )
    
    Write-IndexLog "Starting project indexing" -Data @{
        RootPath = $RootPath
        Recursive = $Recursive.IsPresent
        Force = $Force.IsPresent
    }
    
    $results = @{
        TotalDirectories = 0
        UpdatedIndexes = 0
        SkippedIndexes = 0
        FailedIndexes = 0
        IndexedPaths = @()
    }
    
    $config = $script:IndexerState.Config
    
    # Get all directories to process
    $directories = @($RootPath)
    
    if ($Recursive) {
        $allDirs = Get-ChildItem -Path $RootPath -Directory -Recurse -Force | Where-Object {
            $dirName = $_.Name
            $fullPath = $_.FullName
            -not ($config.ExcludePaths | Where-Object { $dirName -like $_ -or $dirName -eq $_ -or $fullPath -like "*$_*" })
        }
        $directories += $allDirs.FullName
    }
    
    Write-IndexLog "Found $($directories.Count) directories to process"
    
    foreach ($dir in $directories) {
        $results.TotalDirectories++
        
        $result = New-DirectoryIndex -Path $dir -Force:$Force
        
        if ($result.Success) {
            if ($result.Updated) {
                $results.UpdatedIndexes++
                $results.IndexedPaths += $result.Path
            } else {
                $results.SkippedIndexes++
            }
        } else {
            $results.FailedIndexes++
            Write-IndexLog "Failed to generate index for: $dir - $($result.Reason)" -Level Warning
        }
    }
    
    # Save hash cache
    Save-IndexCache
    
    Write-IndexLog "Project indexing completed" -Data @{
        Total = $results.TotalDirectories
        Updated = $results.UpdatedIndexes
        Skipped = $results.SkippedIndexes
        Failed = $results.FailedIndexes
    }
    
    return $results
}

function Save-IndexCache {
    <#
    .SYNOPSIS
        Save content hash cache to disk
    #>
    [CmdletBinding()]
    param()
    
    $config = $script:IndexerState.Config
    $cacheFile = $config.HashCacheFile
    
    try {
        $cache = @{
            Version = '1.0'
            LastUpdate = (Get-Date).ToString('o')
            Hashes = $script:IndexerState.ContentHashes
        }
        
        $cache | ConvertTo-Json -Depth 10 | Set-Content -Path $cacheFile -Encoding UTF8 -Force
        Write-IndexLog "Hash cache saved: $cacheFile"
    } catch {
        Write-IndexLog "Failed to save hash cache: $_" -Level Warning
    }
}

#endregion

#region Manifest Update

function Update-ProjectManifest {
    <#
    .SYNOPSIS
        Update AitherZero.psd1 manifest with indexer functions
    .PARAMETER ManifestPath
        Path to manifest file
    .PARAMETER DryRun
        Show what would be updated without making changes
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ManifestPath = (Join-Path $script:ProjectRoot "AitherZero.psd1"),
        [switch]$DryRun
    )
    
    Write-IndexLog "Checking manifest for indexer functions: $ManifestPath"
    
    $functionsToExport = @(
        'Initialize-ProjectIndexer',
        'New-ProjectIndexes',
        'New-DirectoryIndex',
        'Get-DirectoryContent',
        'Test-ContentChanged',
        'Update-ProjectManifest'
    )
    
    # Read manifest
    if (-not (Test-Path $ManifestPath)) {
        Write-IndexLog "Manifest not found: $ManifestPath" -Level Error
        return $false
    }
    
    $manifestContent = Get-Content $ManifestPath -Raw
    
    # Check if functions are already in manifest
    $missingFunctions = @()
    foreach ($func in $functionsToExport) {
        if ($manifestContent -notmatch [regex]::Escape("'$func'")) {
            $missingFunctions += $func
        }
    }
    
    if ($missingFunctions.Count -eq 0) {
        Write-IndexLog "All indexer functions already in manifest"
        return $true
    }
    
    Write-IndexLog "Missing functions in manifest: $($missingFunctions -join ', ')"
    
    if ($DryRun) {
        Write-IndexLog "DryRun mode - would add: $($missingFunctions -join ', ')"
        return $true
    }
    
    # Note: Actual manifest update would require careful parsing of the .psd1 file
    # For now, we'll just report what needs to be added
    Write-IndexLog "Manifest update required - add these functions to FunctionsToExport:" -Level Warning
    foreach ($func in $missingFunctions) {
        Write-IndexLog "  - $func" -Level Warning
    }
    
    return $false
}

#endregion

# Export module members
Export-ModuleMember -Function @(
    'Initialize-ProjectIndexer',
    'New-ProjectIndexes',
    'New-DirectoryIndex',
    'Compare-IndexContent',
    'Get-DirectoryContent',
    'Get-ContentHash',
    'Test-ContentChanged',
    'Get-NavigationPath',
    'New-NavigationMarkdown',
    'Update-ProjectManifest',
    'Save-IndexCache',
    'Get-IndexerConfig',
    'Get-DefaultIndexerConfig'
)
