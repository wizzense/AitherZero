#Requires -Version 7.0
<#
.SYNOPSIS
    Synchronizes AitherZero repository with AitherLabs and upstream repositories
.DESCRIPTION
    Handles repository synchronization across the fork chain (AitherZero → AitherLabs → Aitherium)
    including documentation updates, configuration sync, and selective content mirroring.
    Supports both push and pull synchronization modes.
.PARAMETER SyncMode
    Synchronization mode: 'push' (sync to AitherLabs), 'pull' (sync from upstream), or 'bidirectional'
.PARAMETER TargetRepository
    Target repository for synchronization (default: auto-detect from git remotes)
.PARAMETER SyncType
    Type of content to sync: 'docs', 'config', 'modules', or 'all'
.PARAMETER DryRun
    Preview synchronization without making changes
.PARAMETER Force
    Force synchronization even if there are conflicts
.PARAMETER ExcludePatterns
    Patterns to exclude from synchronization
.EXAMPLE
    ./Sync-ToAitherLabs.ps1 -SyncMode "push" -SyncType "docs"
.EXAMPLE
    ./Sync-ToAitherLabs.ps1 -SyncMode "pull" -DryRun
.EXAMPLE
    ./Sync-ToAitherLabs.ps1 -SyncMode "bidirectional" -SyncType "config" -Force
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('push', 'pull', 'bidirectional')]
    [string]$SyncMode = 'push',
    
    [Parameter(Mandatory = $false)]
    [string]$TargetRepository = '',
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('docs', 'config', 'modules', 'all')]
    [string]$SyncType = 'docs',
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [string[]]$ExcludePatterns = @('*.log', '*.tmp', 'build-output/', '.git/', 'node_modules/')
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# Initialize sync results
$syncResults = @{
    StartTime = Get-Date
    FilesProcessed = 0
    FilesSkipped = 0
    Conflicts = @()
    Warnings = @()
    Errors = @()
    SyncedFiles = @()
}

function Find-ProjectRoot {
    $currentPath = $PSScriptRoot
    while ($currentPath -and -not (Test-Path (Join-Path $currentPath "Start-AitherZero.ps1"))) {
        $currentPath = Split-Path $currentPath -Parent
    }
    if (-not $currentPath) {
        throw "Could not find project root (looking for Start-AitherZero.ps1)"
    }
    return $currentPath
}

function Get-GitRepositoryInfo {
    try {
        $remoteUrl = git remote get-url origin 2>$null
        if ($remoteUrl) {
            # Parse GitHub URL to get owner/repo
            if ($remoteUrl -match '(?:https://github\.com/|git@github\.com:)([^/]+)/([^/\.]+)') {
                return @{
                    Owner = $Matches[1]
                    Name = $Matches[2]
                    Url = $remoteUrl
                    Branch = (git branch --show-current 2>$null) ?? 'main'
                }
            }
        }
        return $null
    } catch {
        Write-Warning "Could not get repository information: $($_.Exception.Message)"
        return $null
    }
}

function Get-UpstreamRepositories {
    $repoInfo = Get-GitRepositoryInfo
    if (-not $repoInfo) {
        return @()
    }
    
    # Define the fork chain
    $forkChain = @(
        @{ Owner = 'wizzense'; Name = 'AitherZero'; Description = 'Main development repository' },
        @{ Owner = 'AitherLabs'; Name = 'AitherZero'; Description = 'Stable/release repository' },
        @{ Owner = 'Aitherium'; Name = 'AitherZero'; Description = 'Upstream/community repository' }
    )
    
    # Find current position in chain
    $currentIndex = -1
    for ($i = 0; $i -lt $forkChain.Count; $i++) {
        if ($forkChain[$i].Owner -eq $repoInfo.Owner -and $forkChain[$i].Name -eq $repoInfo.Name) {
            $currentIndex = $i
            break
        }
    }
    
    if ($currentIndex -eq -1) {
        Write-Warning "Current repository not found in known fork chain"
        return @()
    }
    
    # Return upstream and downstream repositories
    $upstream = if ($currentIndex -lt $forkChain.Count - 1) { $forkChain[$currentIndex + 1] } else { $null }
    $downstream = if ($currentIndex -gt 0) { $forkChain[$currentIndex - 1] } else { $null }
    
    return @{
        Current = $forkChain[$currentIndex]
        Upstream = $upstream
        Downstream = $downstream
        AllRepositories = $forkChain
    }
}

function Get-SyncableContent {
    param(
        [string]$SyncType,
        [string]$ProjectRoot
    )
    
    $syncableContent = @{
        'docs' = @{
            Description = 'Documentation files'
            Paths = @('docs/', 'README.md', '*.md', 'templates/documentation/')
            Exclude = @('CHANGELOG.md', 'VALIDATION-REPORT.md')
        }
        'config' = @{
            Description = 'Configuration files and templates'
            Paths = @('configs/', 'templates/configurations/', '.github/workflows/documentation.yml')
            Exclude = @('*.local.*', '*-private.*', '*.dev.*')
        }
        'modules' = @{
            Description = 'Shared modules and utilities'
            Paths = @('aither-core/modules/ModuleCommunication/', 'aither-core/modules/ConfigurationCore/', 'aither-core/shared/')
            Exclude = @('*test*', '*debug*', '*local*')
        }
        'all' = @{
            Description = 'All syncable content'
            Paths = @('docs/', 'README.md', '*.md', 'configs/', 'templates/', 'aither-core/shared/')
            Exclude = @('CHANGELOG.md', 'VALIDATION-REPORT.md', '*.local.*', '*-private.*', '*.dev.*', '*test*', '*debug*')
        }
    }
    
    return $syncableContent[$SyncType]
}

function Test-SyncConflicts {
    param(
        [string]$SourcePath,
        [string]$TargetPath
    )
    
    if (-not (Test-Path $SourcePath) -or -not (Test-Path $TargetPath)) {
        return $false
    }
    
    $sourceHash = (Get-FileHash $SourcePath -Algorithm SHA256).Hash
    $targetHash = (Get-FileHash $TargetPath -Algorithm SHA256).Hash
    
    return $sourceHash -ne $targetHash
}

function Sync-ContentToRepository {
    param(
        [string]$SourceRoot,
        [string]$TargetRepository,
        [hashtable]$ContentSpec,
        [bool]$DryRun,
        [bool]$Force
    )
    
    Write-Host "🔄 Syncing $($ContentSpec.Description) to $TargetRepository..." -ForegroundColor Cyan
    
    $tempDir = Join-Path $env:TEMP "aither-sync-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    try {
        # Clone target repository
        if (-not $DryRun) {
            Write-Host "📥 Cloning target repository..." -ForegroundColor Yellow
            git clone "https://github.com/$TargetRepository.git" $tempDir 2>$null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to clone target repository: $TargetRepository"
            }
        } else {
            Write-Host "📥 [DRY RUN] Would clone: https://github.com/$TargetRepository.git" -ForegroundColor Gray
        }
        
        # Process each path
        foreach ($path in $ContentSpec.Paths) {
            $sourcePath = Join-Path $SourceRoot $path
            
            if (Test-Path $sourcePath) {
                # Handle wildcards
                if ($path -like '*') {
                    $items = Get-ChildItem -Path $sourcePath -Recurse -File
                } else {
                    $items = if (Test-Path $sourcePath -PathType Container) {
                        Get-ChildItem -Path $sourcePath -Recurse -File
                    } else {
                        Get-Item $sourcePath
                    }
                }
                
                foreach ($item in $items) {
                    $relativePath = $item.FullName.Substring($SourceRoot.Length + 1)
                    
                    # Check exclusions
                    $shouldExclude = $false
                    foreach ($exclude in ($ContentSpec.Exclude + $ExcludePatterns)) {
                        if ($relativePath -like $exclude) {
                            $shouldExclude = $true
                            break
                        }
                    }
                    
                    if ($shouldExclude) {
                        Write-Host "⏭️ Skipping: $relativePath (excluded)" -ForegroundColor Gray
                        $syncResults.FilesSkipped++
                        continue
                    }
                    
                    $targetPath = Join-Path $tempDir $relativePath
                    
                    # Check for conflicts
                    if (Test-Path $targetPath) {
                        $hasConflict = Test-SyncConflicts -SourcePath $item.FullName -TargetPath $targetPath
                        if ($hasConflict -and -not $Force) {
                            Write-Host "⚠️ Conflict detected: $relativePath" -ForegroundColor Yellow
                            $syncResults.Conflicts += $relativePath
                            continue
                        }
                    }
                    
                    # Copy file
                    if (-not $DryRun) {
                        $targetDir = Split-Path $targetPath -Parent
                        if (-not (Test-Path $targetDir)) {
                            New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
                        }
                        Copy-Item -Path $item.FullName -Destination $targetPath -Force
                        Write-Host "✅ Synced: $relativePath" -ForegroundColor Green
                    } else {
                        Write-Host "✅ [DRY RUN] Would sync: $relativePath" -ForegroundColor Gray
                    }
                    
                    $syncResults.FilesProcessed++
                    $syncResults.SyncedFiles += $relativePath
                }
            } else {
                Write-Host "⚠️ Source path not found: $path" -ForegroundColor Yellow
                $syncResults.Warnings += "Source path not found: $path"
            }
        }
        
        # Commit and push changes
        if (-not $DryRun -and $syncResults.FilesProcessed -gt 0) {
            Write-Host "📤 Committing and pushing changes..." -ForegroundColor Yellow
            
            Push-Location $tempDir
            try {
                git add .
                git commit -m "Sync from AitherZero: $($ContentSpec.Description) - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
                git push origin main
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✅ Successfully pushed changes to $TargetRepository" -ForegroundColor Green
                } else {
                    throw "Failed to push changes to $TargetRepository"
                }
            } finally {
                Pop-Location
            }
        }
        
    } catch {
        $syncResults.Errors += $_.Exception.Message
        Write-Error "Sync failed: $($_.Exception.Message)"
    } finally {
        # Cleanup
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Sync-FromUpstream {
    param(
        [string]$ProjectRoot,
        [string]$UpstreamRepository,
        [hashtable]$ContentSpec,
        [bool]$DryRun
    )
    
    Write-Host "🔄 Syncing $($ContentSpec.Description) from $UpstreamRepository..." -ForegroundColor Cyan
    
    $tempDir = Join-Path $env:TEMP "aither-upstream-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    try {
        # Clone upstream repository
        if (-not $DryRun) {
            Write-Host "📥 Cloning upstream repository..." -ForegroundColor Yellow
            git clone "https://github.com/$UpstreamRepository.git" $tempDir 2>$null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to clone upstream repository: $UpstreamRepository"
            }
        } else {
            Write-Host "📥 [DRY RUN] Would clone: https://github.com/$UpstreamRepository.git" -ForegroundColor Gray
        }
        
        # Pull changes from upstream
        foreach ($path in $ContentSpec.Paths) {
            $upstreamPath = Join-Path $tempDir $path
            $localPath = Join-Path $ProjectRoot $path
            
            if (Test-Path $upstreamPath) {
                if (-not $DryRun) {
                    $localDir = Split-Path $localPath -Parent
                    if (-not (Test-Path $localDir)) {
                        New-Item -Path $localDir -ItemType Directory -Force | Out-Null
                    }
                    Copy-Item -Path $upstreamPath -Destination $localPath -Recurse -Force
                    Write-Host "✅ Pulled: $path" -ForegroundColor Green
                } else {
                    Write-Host "✅ [DRY RUN] Would pull: $path" -ForegroundColor Gray
                }
                
                $syncResults.FilesProcessed++
                $syncResults.SyncedFiles += $path
            }
        }
        
    } catch {
        $syncResults.Errors += $_.Exception.Message
        Write-Error "Upstream sync failed: $($_.Exception.Message)"
    } finally {
        # Cleanup
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Write-SyncReport {
    Write-Host "`n📊 Synchronization Report" -ForegroundColor Cyan
    Write-Host "Duration: $(((Get-Date) - $syncResults.StartTime).TotalSeconds.ToString('F1')) seconds" -ForegroundColor Gray
    Write-Host "Files Processed: $($syncResults.FilesProcessed)" -ForegroundColor White
    Write-Host "Files Skipped: $($syncResults.FilesSkipped)" -ForegroundColor Yellow
    Write-Host "Conflicts: $($syncResults.Conflicts.Count)" -ForegroundColor $(if ($syncResults.Conflicts.Count -gt 0) { 'Red' } else { 'Green' })
    Write-Host "Warnings: $($syncResults.Warnings.Count)" -ForegroundColor Yellow
    Write-Host "Errors: $($syncResults.Errors.Count)" -ForegroundColor $(if ($syncResults.Errors.Count -gt 0) { 'Red' } else { 'Green' })
    
    if ($syncResults.Conflicts.Count -gt 0) {
        Write-Host "`n⚠️ Conflicts detected:" -ForegroundColor Yellow
        foreach ($conflict in $syncResults.Conflicts) {
            Write-Host "  - $conflict" -ForegroundColor Gray
        }
    }
    
    if ($syncResults.Errors.Count -gt 0) {
        Write-Host "`n❌ Errors:" -ForegroundColor Red
        foreach ($error in $syncResults.Errors) {
            Write-Host "  - $error" -ForegroundColor Gray
        }
    }
}

# Main execution
try {
    Write-Host "🔄 AitherZero Repository Synchronization" -ForegroundColor Green
    Write-Host "Mode: $SyncMode" -ForegroundColor Gray
    Write-Host "Type: $SyncType" -ForegroundColor Gray
    Write-Host "Dry Run: $DryRun" -ForegroundColor Gray
    Write-Host ""
    
    $projectRoot = Find-ProjectRoot
    $repositories = Get-UpstreamRepositories
    $contentSpec = Get-SyncableContent -SyncType $SyncType -ProjectRoot $projectRoot
    
    if (-not $contentSpec) {
        throw "Invalid sync type: $SyncType"
    }
    
    Write-Host "📋 Content to sync: $($contentSpec.Description)" -ForegroundColor Cyan
    Write-Host "Paths: $($contentSpec.Paths -join ', ')" -ForegroundColor Gray
    Write-Host ""
    
    # Determine target repository if not specified
    if (-not $TargetRepository) {
        if ($SyncMode -eq 'push' -and $repositories.Upstream) {
            $TargetRepository = "$($repositories.Upstream.Owner)/$($repositories.Upstream.Name)"
        } elseif ($SyncMode -eq 'pull' -and $repositories.Downstream) {
            $TargetRepository = "$($repositories.Downstream.Owner)/$($repositories.Downstream.Name)"
        } else {
            throw "Could not determine target repository for sync mode: $SyncMode"
        }
    }
    
    Write-Host "🎯 Target repository: $TargetRepository" -ForegroundColor Cyan
    
    # Perform synchronization
    switch ($SyncMode) {
        'push' {
            Sync-ContentToRepository -SourceRoot $projectRoot -TargetRepository $TargetRepository -ContentSpec $contentSpec -DryRun $DryRun -Force $Force
        }
        'pull' {
            Sync-FromUpstream -ProjectRoot $projectRoot -UpstreamRepository $TargetRepository -ContentSpec $contentSpec -DryRun $DryRun
        }
        'bidirectional' {
            # First pull from upstream, then push to downstream
            if ($repositories.Upstream) {
                Sync-FromUpstream -ProjectRoot $projectRoot -UpstreamRepository "$($repositories.Upstream.Owner)/$($repositories.Upstream.Name)" -ContentSpec $contentSpec -DryRun $DryRun
            }
            if ($repositories.Downstream) {
                Sync-ContentToRepository -SourceRoot $projectRoot -TargetRepository "$($repositories.Downstream.Owner)/$($repositories.Downstream.Name)" -ContentSpec $contentSpec -DryRun $DryRun -Force $Force
            }
        }
    }
    
    Write-SyncReport
    
    if ($syncResults.Errors.Count -eq 0) {
        Write-Host "`n✅ Repository synchronization completed successfully!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "`n❌ Repository synchronization completed with errors!" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Error "Repository synchronization failed: $($_.Exception.Message)"
    exit 1
}