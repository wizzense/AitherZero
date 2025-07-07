#Requires -Version 7.0

<#
.SYNOPSIS
    Semantic Versioning Engine with Conventional Commit Parsing
.DESCRIPTION
    Provides intelligent semantic versioning capabilities with conventional commit parsing,
    automated version bumping, and comprehensive release management
#>

# Module variables
$script:ConventionalCommitPattern = '^(?<type>\w+)(?:\((?<scope>[\w\-]+)\))?(?<breaking>!)?: (?<description>.+)$'
$script:CommitTypeMapping = @{
    'feat'     = @{ Impact = 'Minor'; Description = 'New feature' }
    'fix'      = @{ Impact = 'Patch'; Description = 'Bug fix' }
    'docs'     = @{ Impact = 'Patch'; Description = 'Documentation change' }
    'style'    = @{ Impact = 'Patch'; Description = 'Style/formatting change' }
    'refactor' = @{ Impact = 'Patch'; Description = 'Code refactoring' }
    'perf'     = @{ Impact = 'Patch'; Description = 'Performance improvement' }
    'test'     = @{ Impact = 'Patch'; Description = 'Test addition/modification' }
    'chore'    = @{ Impact = 'Patch'; Description = 'Maintenance task' }
    'ci'       = @{ Impact = 'Patch'; Description = 'CI/CD change' }
    'build'    = @{ Impact = 'Patch'; Description = 'Build system change' }
    'revert'   = @{ Impact = 'Patch'; Description = 'Revert previous change' }
    'hotfix'   = @{ Impact = 'Patch'; Description = 'Emergency hotfix' }
    'security' = @{ Impact = 'Patch'; Description = 'Security fix' }
    'breaking' = @{ Impact = 'Major'; Description = 'Breaking change' }
}

function Get-NextSemanticVersion {
    <#
    .SYNOPSIS
        Calculates the next semantic version based on commit history
    
    .DESCRIPTION
        Analyzes conventional commits since the last release to determine
        the appropriate version bump (major, minor, or patch) and generates
        the next semantic version number.
    
    .PARAMETER CurrentVersion
        The current version (defaults to latest git tag or VERSION file)
    
    .PARAMETER FromCommit
        Starting commit for analysis (defaults to last release tag)
    
    .PARAMETER ToCommit
        Ending commit for analysis (defaults to HEAD)
    
    .PARAMETER PreReleaseLabel
        Pre-release label to append (e.g., 'alpha', 'beta', 'rc')
    
    .PARAMETER BuildMetadata
        Build metadata to append after '+' symbol
    
    .PARAMETER ForceVersionType
        Force a specific version bump (Major, Minor, Patch)
    
    .PARAMETER AnalyzeCommits
        Whether to analyze commit messages for version determination
    
    .EXAMPLE
        Get-NextSemanticVersion
        
        Analyzes commits and returns the next appropriate version
    
    .EXAMPLE
        Get-NextSemanticVersion -CurrentVersion "1.2.3" -PreReleaseLabel "alpha"
        
        Returns next version with alpha pre-release label
    
    .OUTPUTS
        PSCustomObject with version information and analysis details
    #>
    [CmdletBinding()]
    param(
        [string]$CurrentVersion,
        
        [string]$FromCommit,
        
        [string]$ToCommit = 'HEAD',
        
        [string]$PreReleaseLabel,
        
        [string]$BuildMetadata,
        
        [ValidateSet('Major', 'Minor', 'Patch')]
        [string]$ForceVersionType,
        
        [switch]$AnalyzeCommits = $true
    )
    
    begin {
        Write-Verbose "Starting semantic version analysis"
        
        # Get current version if not provided
        if (-not $CurrentVersion) {
            $CurrentVersion = Get-CurrentVersion
        }
        
        # Parse current version
        $currentSemVer = Parse-SemanticVersion -Version $CurrentVersion
        if (-not $currentSemVer) {
            throw "Invalid current version: $CurrentVersion"
        }
        
        Write-Verbose "Current version: $($currentSemVer.Original)"
    }
    
    process {
        try {
            # Initialize version bump analysis
            $versionAnalysis = @{
                CurrentVersion = $currentSemVer
                HasMajorChanges = $false
                HasMinorChanges = $false
                HasPatchChanges = $false
                BreakingChanges = @()
                Features = @()
                Fixes = @()
                OtherChanges = @()
                CommitCount = 0
                RecommendedBump = 'None'
            }
            
            # Analyze commits if requested
            if ($AnalyzeCommits) {
                Write-Verbose "Analyzing commits for version impact"
                
                # Get commit range
                $commitRange = Get-CommitRange -FromCommit $FromCommit -ToCommit $ToCommit
                Write-Verbose "Analyzing $($commitRange.Count) commits"
                
                # Parse conventional commits
                $commitAnalysis = Parse-ConventionalCommits -Commits $commitRange
                
                foreach ($commit in $commitAnalysis) {
                    $versionAnalysis.CommitCount++
                    
                    # Categorize commit impact
                    switch ($commit.Impact) {
                        'Major' {
                            $versionAnalysis.HasMajorChanges = $true
                            if ($commit.IsBreaking) {
                                $versionAnalysis.BreakingChanges += $commit
                            }
                        }
                        'Minor' {
                            $versionAnalysis.HasMinorChanges = $true
                            $versionAnalysis.Features += $commit
                        }
                        'Patch' {
                            $versionAnalysis.HasPatchChanges = $true
                            if ($commit.Type -eq 'fix') {
                                $versionAnalysis.Fixes += $commit
                            } else {
                                $versionAnalysis.OtherChanges += $commit
                            }
                        }
                    }
                }
                
                # Determine recommended version bump
                if ($versionAnalysis.HasMajorChanges) {
                    $versionAnalysis.RecommendedBump = 'Major'
                } elseif ($versionAnalysis.HasMinorChanges) {
                    $versionAnalysis.RecommendedBump = 'Minor'
                } elseif ($versionAnalysis.HasPatchChanges) {
                    $versionAnalysis.RecommendedBump = 'Patch'
                } else {
                    $versionAnalysis.RecommendedBump = 'None'
                }
            }
            
            # Apply forced version type if specified
            if ($ForceVersionType) {
                $versionAnalysis.RecommendedBump = $ForceVersionType
                Write-Verbose "Forced version bump: $ForceVersionType"
            }
            
            # Calculate next version
            $nextVersion = Calculate-NextVersion -Current $currentSemVer -BumpType $versionAnalysis.RecommendedBump
            
            # Apply pre-release label if specified
            if ($PreReleaseLabel) {
                $nextVersion.PreRelease = $PreReleaseLabel
                if ($nextVersion.PreReleaseNumber) {
                    $nextVersion.Version = "$($nextVersion.Major).$($nextVersion.Minor).$($nextVersion.Patch)-$($nextVersion.PreRelease).$($nextVersion.PreReleaseNumber)"
                } else {
                    $nextVersion.Version = "$($nextVersion.Major).$($nextVersion.Minor).$($nextVersion.Patch)-$($nextVersion.PreRelease)"
                }
            }
            
            # Apply build metadata if specified
            if ($BuildMetadata) {
                $nextVersion.BuildMetadata = $BuildMetadata
                $nextVersion.Version = "$($nextVersion.Version)+$BuildMetadata"
            }
            
            # Create result object
            $result = [PSCustomObject]@{
                CurrentVersion = $currentSemVer.Version
                NextVersion = $nextVersion.Version
                VersionBump = $versionAnalysis.RecommendedBump
                Major = $nextVersion.Major
                Minor = $nextVersion.Minor
                Patch = $nextVersion.Patch
                PreRelease = $nextVersion.PreRelease
                BuildMetadata = $nextVersion.BuildMetadata
                Analysis = $versionAnalysis
                CommitsSinceLastRelease = $versionAnalysis.CommitCount
                BreakingChanges = $versionAnalysis.BreakingChanges.Count
                NewFeatures = $versionAnalysis.Features.Count
                BugFixes = $versionAnalysis.Fixes.Count
                OtherChanges = $versionAnalysis.OtherChanges.Count
                IsPreRelease = -not [string]::IsNullOrEmpty($PreReleaseLabel)
                ReleaseNotes = @{
                    BreakingChanges = $versionAnalysis.BreakingChanges
                    Features = $versionAnalysis.Features
                    Fixes = $versionAnalysis.Fixes
                    Other = $versionAnalysis.OtherChanges
                }
            }
            
            Write-Verbose "Next version calculated: $($result.NextVersion)"
            return $result
            
        } catch {
            Write-Error "Failed to calculate next semantic version: $($_.Exception.Message)"
            throw
        }
    }
}

function Parse-ConventionalCommits {
    <#
    .SYNOPSIS
        Parses git commits using conventional commit format
    
    .DESCRIPTION
        Analyzes commit messages to extract conventional commit information
        including type, scope, breaking changes, and impact on versioning.
    
    .PARAMETER Commits
        Array of commit objects or commit messages to parse
    
    .PARAMETER IncludeNonConventional
        Whether to include commits that don't follow conventional format
    
    .EXAMPLE
        Parse-ConventionalCommits -Commits $commitList
        
        Parses the provided commits for conventional commit information
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Commits,
        
        [switch]$IncludeNonConventional
    )
    
    $parsedCommits = @()
    
    foreach ($commit in $Commits) {
        $commitMessage = if ($commit -is [string]) { $commit } else { $commit.Message }
        $commitHash = if ($commit -is [string]) { $null } else { $commit.Hash }
        
        # Parse conventional commit format
        if ($commitMessage -match $script:ConventionalCommitPattern) {
            $type = $matches['type'].ToLower()
            $scope = $matches['scope']
            $isBreaking = $matches['breaking'] -eq '!'
            $description = $matches['description']
            
            # Get impact for this commit type
            $typeInfo = $script:CommitTypeMapping[$type]
            $impact = if ($typeInfo) { $typeInfo.Impact } else { 'Patch' }
            
            # Breaking changes are always major
            if ($isBreaking -or $description -match '\bBREAKING CHANGE\b') {
                $impact = 'Major'
                $isBreaking = $true
            }
            
            $parsedCommit = [PSCustomObject]@{
                Hash = $commitHash
                Type = $type
                Scope = $scope
                Description = $description
                IsBreaking = $isBreaking
                Impact = $impact
                IsConventional = $true
                OriginalMessage = $commitMessage
                TypeDescription = if ($typeInfo) { $typeInfo.Description } else { "Unknown type: $type" }
            }
            
            $parsedCommits += $parsedCommit
            
        } elseif ($IncludeNonConventional) {
            # Include non-conventional commits as patch-level changes
            $parsedCommit = [PSCustomObject]@{
                Hash = $commitHash
                Type = 'unknown'
                Scope = $null
                Description = $commitMessage
                IsBreaking = $false
                Impact = 'Patch'
                IsConventional = $false
                OriginalMessage = $commitMessage
                TypeDescription = 'Non-conventional commit'
            }
            
            $parsedCommits += $parsedCommit
        }
    }
    
    Write-Verbose "Parsed $($parsedCommits.Count) commits ($($parsedCommits | Where-Object IsConventional | Measure-Object).Count conventional)"
    return $parsedCommits
}

function Get-CommitTypeImpact {
    <#
    .SYNOPSIS
        Gets the version impact for a specific commit type
    
    .DESCRIPTION
        Returns the semantic version impact (Major, Minor, Patch) for
        conventional commit types.
    
    .PARAMETER CommitType
        The conventional commit type (feat, fix, etc.)
    
    .EXAMPLE
        Get-CommitTypeImpact -CommitType 'feat'
        Returns 'Minor'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommitType
    )
    
    $typeInfo = $script:CommitTypeMapping[$CommitType.ToLower()]
    if ($typeInfo) {
        return $typeInfo.Impact
    } else {
        return 'Patch'  # Default for unknown types
    }
}

function New-VersionTag {
    <#
    .SYNOPSIS
        Creates a new version tag in the git repository
    
    .DESCRIPTION
        Creates an annotated git tag for the specified version with
        optional release notes and signing.
    
    .PARAMETER Version
        The version to tag
    
    .PARAMETER Message
        Tag annotation message
    
    .PARAMETER ReleaseNotes
        Detailed release notes for the tag
    
    .PARAMETER Sign
        Whether to sign the tag with GPG
    
    .PARAMETER Push
        Whether to push the tag to remote repository
    
    .EXAMPLE
        New-VersionTag -Version "1.2.3" -Message "Release version 1.2.3"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version,
        
        [string]$Message,
        
        [string]$ReleaseNotes,
        
        [switch]$Sign,
        
        [switch]$Push
    )
    
    try {
        # Validate version format
        $semVer = Parse-SemanticVersion -Version $Version
        if (-not $semVer) {
            throw "Invalid semantic version: $Version"
        }
        
        # Create tag name
        $tagName = "v$Version"
        
        # Create tag message
        if (-not $Message) {
            $Message = "Release version $Version"
        }
        
        if ($ReleaseNotes) {
            $Message += "`n`n$ReleaseNotes"
        }
        
        # Create git tag command
        $gitArgs = @('tag', '-a', $tagName, '-m', $Message)
        
        if ($Sign) {
            $gitArgs += '-s'
        }
        
        # Execute git tag command
        Write-Verbose "Creating tag: $tagName"
        $result = & git @gitArgs
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create git tag: $result"
        }
        
        # Push tag if requested
        if ($Push) {
            Write-Verbose "Pushing tag to remote"
            $pushResult = & git push origin $tagName
            
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to push tag: $pushResult"
            }
        }
        
        Write-Verbose "Successfully created tag: $tagName"
        return @{
            TagName = $tagName
            Version = $Version
            Message = $Message
            Pushed = $Push.IsPresent
        }
        
    } catch {
        Write-Error "Failed to create version tag: $($_.Exception.Message)"
        throw
    }
}

function Get-VersionHistory {
    <#
    .SYNOPSIS
        Gets version history from git tags
    
    .DESCRIPTION
        Retrieves and analyzes version history from git tags,
        providing information about releases and version progression.
    
    .PARAMETER Count
        Maximum number of versions to return
    
    .PARAMETER IncludePreRelease
        Whether to include pre-release versions
    
    .EXAMPLE
        Get-VersionHistory -Count 10
    #>
    [CmdletBinding()]
    param(
        [int]$Count = 50,
        
        [switch]$IncludePreRelease
    )
    
    try {
        # Get git tags
        $tags = & git tag -l --sort=-version:refname
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get git tags"
        }
        
        $versionHistory = @()
        
        foreach ($tag in $tags) {
            # Remove 'v' prefix if present
            $versionString = $tag -replace '^v', ''
            
            # Parse semantic version
            $semVer = Parse-SemanticVersion -Version $versionString
            if ($semVer) {
                # Skip pre-releases if not requested
                if (-not $IncludePreRelease -and $semVer.PreRelease) {
                    continue
                }
                
                # Get tag information
                $tagInfo = & git show --format="%H%n%ci%n%s%n%b" --no-patch $tag
                
                if ($tagInfo) {
                    $lines = $tagInfo -split "`n"
                    $hash = $lines[0]
                    $date = if ($lines[1]) { [DateTime]::Parse($lines[1]) } else { Get-Date }
                    $subject = if ($lines[2]) { $lines[2] } else { '' }
                    $body = if ($lines.Length -gt 3) { ($lines[3..$($lines.Length-1)] -join "`n").Trim() } else { '' }
                }
                
                $versionInfo = [PSCustomObject]@{
                    Version = $semVer.Version
                    Tag = $tag
                    Major = $semVer.Major
                    Minor = $semVer.Minor
                    Patch = $semVer.Patch
                    PreRelease = $semVer.PreRelease
                    BuildMetadata = $semVer.BuildMetadata
                    Hash = $hash
                    Date = $date
                    Subject = $subject
                    Body = $body
                    IsPreRelease = -not [string]::IsNullOrEmpty($semVer.PreRelease)
                }
                
                $versionHistory += $versionInfo
                
                if ($versionHistory.Count -ge $Count) {
                    break
                }
            }
        }
        
        Write-Verbose "Retrieved $($versionHistory.Count) version entries"
        return $versionHistory
        
    } catch {
        Write-Error "Failed to get version history: $($_.Exception.Message)"
        throw
    }
}

function Update-ProjectVersion {
    <#
    .SYNOPSIS
        Updates project version files with new version
    
    .DESCRIPTION
        Updates various project files (VERSION, package.json, manifests)
        with the new version number.
    
    .PARAMETER Version
        The new version to set
    
    .PARAMETER UpdateFiles
        Specific files to update (defaults to auto-detection)
    
    .EXAMPLE
        Update-ProjectVersion -Version "1.2.3"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version,
        
        [string[]]$UpdateFiles = @()
    )
    
    try {
        # Validate version
        $semVer = Parse-SemanticVersion -Version $Version
        if (-not $semVer) {
            throw "Invalid semantic version: $Version"
        }
        
        $updatedFiles = @()
        
        # Auto-detect files if not specified
        if ($UpdateFiles.Count -eq 0) {
            $UpdateFiles = Get-VersionFiles
        }
        
        foreach ($file in $UpdateFiles) {
            if (Test-Path $file) {
                try {
                    $updated = Update-VersionInFile -FilePath $file -Version $Version
                    if ($updated) {
                        $updatedFiles += $file
                        Write-Verbose "Updated version in: $file"
                    }
                } catch {
                    Write-Warning "Failed to update version in $file`: $($_.Exception.Message)"
                }
            }
        }
        
        Write-Verbose "Updated version in $($updatedFiles.Count) files"
        return $updatedFiles
        
    } catch {
        Write-Error "Failed to update project version: $($_.Exception.Message)"
        throw
    }
}

function Get-ReleaseNotes {
    <#
    .SYNOPSIS
        Generates release notes from commit history
    
    .DESCRIPTION
        Creates formatted release notes based on conventional commits
        between version tags.
    
    .PARAMETER FromVersion
        Starting version for release notes
    
    .PARAMETER ToVersion
        Ending version for release notes
    
    .PARAMETER Format
        Output format (Markdown, Text, JSON)
    
    .EXAMPLE
        Get-ReleaseNotes -FromVersion "1.2.0" -ToVersion "1.3.0" -Format Markdown
    #>
    [CmdletBinding()]
    param(
        [string]$FromVersion,
        
        [string]$ToVersion,
        
        [ValidateSet('Markdown', 'Text', 'JSON')]
        [string]$Format = 'Markdown'
    )
    
    try {
        # Get commit range
        $commitRange = Get-CommitRange -FromCommit $FromVersion -ToCommit $ToVersion
        
        # Parse commits
        $commits = Parse-ConventionalCommits -Commits $commitRange -IncludeNonConventional
        
        # Group commits by type
        $groupedCommits = $commits | Group-Object -Property Type
        
        # Generate release notes based on format
        switch ($Format) {
            'Markdown' {
                return Format-ReleaseNotesMarkdown -GroupedCommits $groupedCommits -FromVersion $FromVersion -ToVersion $ToVersion
            }
            'Text' {
                return Format-ReleaseNotesText -GroupedCommits $groupedCommits -FromVersion $FromVersion -ToVersion $ToVersion
            }
            'JSON' {
                return $groupedCommits | ConvertTo-Json -Depth 5
            }
        }
        
    } catch {
        Write-Error "Failed to generate release notes: $($_.Exception.Message)"
        throw
    }
}

function Test-SemanticVersion {
    <#
    .SYNOPSIS
        Validates semantic version format
    
    .DESCRIPTION
        Tests whether a version string follows semantic versioning specification.
    
    .PARAMETER Version
        Version string to validate
    
    .EXAMPLE
        Test-SemanticVersion -Version "1.2.3-alpha.1+build.123"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version
    )
    
    $parsed = Parse-SemanticVersion -Version $Version
    return $null -ne $parsed
}

function Compare-SemanticVersions {
    <#
    .SYNOPSIS
        Compares two semantic versions
    
    .DESCRIPTION
        Compares semantic versions and returns comparison result.
    
    .PARAMETER Version1
        First version to compare
    
    .PARAMETER Version2
        Second version to compare
    
    .EXAMPLE
        Compare-SemanticVersions -Version1 "1.2.3" -Version2 "1.2.4"
        Returns -1 (Version1 is less than Version2)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version1,
        
        [Parameter(Mandatory = $true)]
        [string]$Version2
    )
    
    $v1 = Parse-SemanticVersion -Version $Version1
    $v2 = Parse-SemanticVersion -Version $Version2
    
    if (-not $v1 -or -not $v2) {
        throw "Invalid semantic version provided"
    }
    
    # Compare major.minor.patch
    if ($v1.Major -ne $v2.Major) {
        return $v1.Major - $v2.Major
    }
    
    if ($v1.Minor -ne $v2.Minor) {
        return $v1.Minor - $v2.Minor
    }
    
    if ($v1.Patch -ne $v2.Patch) {
        return $v1.Patch - $v2.Patch
    }
    
    # Handle pre-release comparison
    if ($v1.PreRelease -and -not $v2.PreRelease) {
        return -1  # Pre-release is less than release
    }
    
    if (-not $v1.PreRelease -and $v2.PreRelease) {
        return 1   # Release is greater than pre-release
    }
    
    if ($v1.PreRelease -and $v2.PreRelease) {
        return [string]::Compare($v1.PreRelease, $v2.PreRelease)
    }
    
    return 0  # Versions are equal
}

function Get-VersionBump {
    <#
    .SYNOPSIS
        Gets the type of version bump between two versions
    
    .DESCRIPTION
        Analyzes two semantic versions to determine the type of bump (major, minor, patch).
    
    .PARAMETER FromVersion
        Starting version
    
    .PARAMETER ToVersion
        Target version
    
    .EXAMPLE
        Get-VersionBump -FromVersion "1.2.3" -ToVersion "1.3.0"
        Returns "Minor"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FromVersion,
        
        [Parameter(Mandatory = $true)]
        [string]$ToVersion
    )
    
    $from = Parse-SemanticVersion -Version $FromVersion
    $to = Parse-SemanticVersion -Version $ToVersion
    
    if (-not $from -or -not $to) {
        throw "Invalid semantic version provided"
    }
    
    if ($to.Major -gt $from.Major) {
        return 'Major'
    } elseif ($to.Minor -gt $from.Minor) {
        return 'Minor'
    } elseif ($to.Patch -gt $from.Patch) {
        return 'Patch'
    } else {
        return 'None'
    }
}

# Private helper functions
function Parse-SemanticVersion {
    param([string]$Version)
    
    # Semantic version regex pattern
    $pattern = '^(?<major>0|[1-9]\d*)\.(?<minor>0|[1-9]\d*)\.(?<patch>0|[1-9]\d*)(?:-(?<prerelease>(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+(?<buildmetadata>[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$'
    
    if ($Version -match $pattern) {
        return [PSCustomObject]@{
            Version = $Version
            Original = $Version
            Major = [int]$matches['major']
            Minor = [int]$matches['minor']
            Patch = [int]$matches['patch']
            PreRelease = $matches['prerelease']
            BuildMetadata = $matches['buildmetadata']
        }
    }
    
    return $null
}

function Get-CurrentVersion {
    # Try VERSION file first
    $versionFile = Join-Path (Get-Location) "VERSION"
    if (Test-Path $versionFile) {
        $version = Get-Content $versionFile -Raw | ForEach-Object { $_.Trim() }
        if ($version -match '^\d+\.\d+\.\d+') {
            return $version
        }
    }
    
    # Try git tags
    try {
        $latestTag = & git describe --tags --abbrev=0 2>$null
        if ($latestTag -and $latestTag -match '^v?(\d+\.\d+\.\d+.*)') {
            return $matches[1]
        }
    } catch {}
    
    # Default
    return "0.0.0"
}

function Get-CommitRange {
    param(
        [string]$FromCommit,
        [string]$ToCommit = 'HEAD'
    )
    
    if (-not $FromCommit) {
        # Get commits since last tag
        try {
            $lastTag = & git describe --tags --abbrev=0 2>$null
            if ($lastTag) {
                $FromCommit = $lastTag
            }
        } catch {}
    }
    
    # Get commit range
    $gitArgs = @('log', '--oneline', '--no-merges')
    
    if ($FromCommit) {
        $gitArgs += "$FromCommit..$ToCommit"
    } else {
        $gitArgs += $ToCommit
    }
    
    $commits = & git @gitArgs
    
    if ($LASTEXITCODE -ne 0) {
        return @()
    }
    
    return $commits | ForEach-Object {
        $parts = $_ -split ' ', 2
        [PSCustomObject]@{
            Hash = $parts[0]
            Message = if ($parts.Length -gt 1) { $parts[1] } else { '' }
        }
    }
}

function Calculate-NextVersion {
    param(
        [PSCustomObject]$Current,
        [string]$BumpType
    )
    
    $next = [PSCustomObject]@{
        Major = $Current.Major
        Minor = $Current.Minor
        Patch = $Current.Patch
        PreRelease = $null
        BuildMetadata = $null
        Version = $null
        PreReleaseNumber = $null
    }
    
    switch ($BumpType) {
        'Major' {
            $next.Major = $Current.Major + 1
            $next.Minor = 0
            $next.Patch = 0
        }
        'Minor' {
            $next.Minor = $Current.Minor + 1
            $next.Patch = 0
        }
        'Patch' {
            $next.Patch = $Current.Patch + 1
        }
        'None' {
            # No change
        }
    }
    
    $next.Version = "$($next.Major).$($next.Minor).$($next.Patch)"
    return $next
}

function Get-VersionFiles {
    $files = @()
    
    # Common version files
    $versionFiles = @(
        'VERSION',
        'package.json',
        'pom.xml',
        'Cargo.toml',
        'setup.py',
        'pyproject.toml'
    )
    
    foreach ($file in $versionFiles) {
        if (Test-Path $file) {
            $files += $file
        }
    }
    
    # PowerShell module manifests
    $manifestFiles = Get-ChildItem -Path . -Recurse -Filter "*.psd1" | Where-Object { $_.Directory.Name -ne 'bin' }
    $files += $manifestFiles.FullName
    
    return $files
}

function Update-VersionInFile {
    param(
        [string]$FilePath,
        [string]$Version
    )
    
    $content = Get-Content $FilePath -Raw
    $originalContent = $content
    
    # Handle different file types
    $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
    
    switch ($extension) {
        '.psd1' {
            # PowerShell module manifest
            $content = $content -replace "ModuleVersion\s*=\s*'[^']*'", "ModuleVersion = '$Version'"
        }
        '.json' {
            # package.json or similar
            $content = $content -replace '"version"\s*:\s*"[^"]*"', "`"version`": `"$Version`""
        }
        default {
            # VERSION file or similar
            if ($FilePath -match 'VERSION$') {
                $content = $Version
            }
        }
    }
    
    if ($content -ne $originalContent) {
        Set-Content -Path $FilePath -Value $content -Encoding UTF8
        return $true
    }
    
    return $false
}

function Format-ReleaseNotesMarkdown {
    param(
        [Microsoft.PowerShell.Commands.GroupInfo[]]$GroupedCommits,
        [string]$FromVersion,
        [string]$ToVersion
    )
    
    $releaseNotes = @()
    
    if ($ToVersion) {
        $releaseNotes += "# Release $ToVersion"
    } else {
        $releaseNotes += "# Release Notes"
    }
    
    $releaseNotes += ""
    
    # Breaking changes first
    $breaking = $GroupedCommits | Where-Object { $_.Group | Where-Object IsBreaking }
    if ($breaking) {
        $releaseNotes += "## ⚠️ BREAKING CHANGES"
        $releaseNotes += ""
        foreach ($commit in $breaking.Group | Where-Object IsBreaking) {
            $releaseNotes += "- $($commit.Description)"
        }
        $releaseNotes += ""
    }
    
    # Features
    $features = $GroupedCommits | Where-Object Name -eq 'feat'
    if ($features) {
        $releaseNotes += "## 🚀 Features"
        $releaseNotes += ""
        foreach ($commit in $features.Group) {
            $scope = if ($commit.Scope) { "**$($commit.Scope)**: " } else { "" }
            $releaseNotes += "- $scope$($commit.Description)"
        }
        $releaseNotes += ""
    }
    
    # Bug fixes
    $fixes = $GroupedCommits | Where-Object Name -eq 'fix'
    if ($fixes) {
        $releaseNotes += "## 🐛 Bug Fixes"
        $releaseNotes += ""
        foreach ($commit in $fixes.Group) {
            $scope = if ($commit.Scope) { "**$($commit.Scope)**: " } else { "" }
            $releaseNotes += "- $scope$($commit.Description)"
        }
        $releaseNotes += ""
    }
    
    # Other changes
    $others = $GroupedCommits | Where-Object { $_.Name -notin @('feat', 'fix') }
    if ($others) {
        $releaseNotes += "## 📝 Other Changes"
        $releaseNotes += ""
        foreach ($group in $others) {
            foreach ($commit in $group.Group) {
                $scope = if ($commit.Scope) { "**$($commit.Scope)**: " } else { "" }
                $releaseNotes += "- **$($commit.Type)**: $scope$($commit.Description)"
            }
        }
    }
    
    return $releaseNotes -join "`n"
}

function Format-ReleaseNotesText {
    param(
        [Microsoft.PowerShell.Commands.GroupInfo[]]$GroupedCommits,
        [string]$FromVersion,
        [string]$ToVersion
    )
    
    # Simple text format version of markdown
    $markdown = Format-ReleaseNotesMarkdown -GroupedCommits $GroupedCommits -FromVersion $FromVersion -ToVersion $ToVersion
    
    # Remove markdown formatting
    $text = $markdown -replace '^#+\s*', '' -replace '\*\*([^*]+)\*\*', '$1' -replace '\*([^*]+)\*', '$1'
    
    return $text
}

# Export module members
Export-ModuleMember -Function @(
    'Get-NextSemanticVersion',
    'Parse-ConventionalCommits',
    'Get-CommitTypeImpact',
    'New-VersionTag',
    'Get-VersionHistory',
    'Update-ProjectVersion',
    'Get-ReleaseNotes',
    'Test-SemanticVersion',
    'Compare-SemanticVersions',
    'Get-VersionBump'
)