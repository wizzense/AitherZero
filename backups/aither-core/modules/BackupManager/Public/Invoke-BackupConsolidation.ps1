<#
.SYNOPSIS
Consolidates scattered backup files into a centralized location

.DESCRIPTION
This function discovers backup files throughout the project directory structure
and consolidates them into a central backup directory with organized structure.
Handles naming conflicts and provides detailed progress reporting.

.PARAMETER SourcePath
The root directory to search for backup files (default: current directory)

.PARAMETER BackupPath
The destination directory for consolidated backups (default: ./backups/consolidated)

.PARAMETER ExcludePaths
Array of paths to exclude from backup consolidation

.PARAMETER Force
Skip confirmation prompts and overwrite existing files

.PARAMETER MaxFileAge
Maximum age in days for files to be considered for backup (default: no limit)

.EXAMPLE
Invoke-BackupConsolidation -SourcePath "." -Force

.EXAMPLE
Invoke-BackupConsolidation -SourcePath "." -BackupPath "./archive/backups" -ExcludePaths @("special/*") -Force

.NOTES
Follows AitherZero project standards and integrates with logging system
#>
function Invoke-BackupConsolidation {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string]$SourcePath = ".",

        [Parameter()]
        [string]$BackupPath = "./backups/consolidated",

        [Parameter()]
        [string[]]$ExcludePaths = @(),

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [int]$MaxFileAge = 0
    )

    $ErrorActionPreference = "Stop"

    try {
        # Import shared utilities
        . "$PSScriptRoot/../../../shared/Find-ProjectRoot.ps1"
        $projectRoot = Find-ProjectRoot

        # Write-CustomLog is guaranteed to be available from AitherCore orchestration
        # No explicit Logging import needed - trust the orchestration system
        Write-CustomLog "Starting backup consolidation process" -Level INFO

        # Resolve paths
        $SourcePath = Resolve-Path $SourcePath -ErrorAction Stop
        $BackupPath = Join-Path $projectRoot $BackupPath

        # Create backup directory if it doesn't exist
        if (-not (Test-Path $BackupPath)) {
            New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog "Created backup directory: $BackupPath" -Level INFO
            }
        }

        # Define backup file patterns
        $BackupPatterns = @(
            "*.bak", "*.backup", "*.old", "*.orig", "*~", "*.backup.*",
            "*backup*", "*-backup-*", "*.bak.*"
        )

        # Default exclusions
        $defaultExclusions = @(
            "*.git*", "*node_modules*", "*\.vscode*", "*backups*",
            "*packages*", "*bin*", "*obj*", "*\.vs*"
        )
        $allExclusions = $defaultExclusions + $ExcludePaths

        # Find backup files
        $backupFiles = @()
        foreach ($pattern in $BackupPatterns) {
            $files = Get-ChildItem -Path $SourcePath -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue

            # Apply exclusions
            $filteredFiles = $files | Where-Object {
                $file = $_
                $include = $true

                foreach ($exclusion in $allExclusions) {
                    if ($file.FullName -like "*$exclusion*") {
                        $include = $false
                        break
                    }
                }

                # Apply age filter if specified
                if ($include -and $MaxFileAge -gt 0) {
                    $cutoffDate = (Get-Date).AddDays(-$MaxFileAge)
                    $include = $file.LastWriteTime -ge $cutoffDate
                }

                return $include
            }

            $backupFiles += $filteredFiles
        }

        if ($backupFiles.Count -eq 0) {
            $result = @{
                Success = $true
                FilesProcessed = 0
                DirectoriesProcessed = 0
                Message = "No backup files found to consolidate"
            }

            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog $result.Message -Level INFO
            } else {
                Write-Host "INFO $($result.Message)" -ForegroundColor Green
            }

            return $result
        }

        # Show what will be processed unless Force is specified
        if (-not $Force) {
            Write-Host "Found $($backupFiles.Count) backup files to consolidate:" -ForegroundColor Yellow
            $backupFiles | ForEach-Object {
                $relativePath = $_.FullName.Replace($SourcePath, "").TrimStart('\', '/')
                Write-Host "  - $relativePath" -ForegroundColor Yellow
            }

            $confirmation = Read-Host "Proceed with consolidation? (y/N)"
            if ($confirmation -notmatch '^[Yy]') {
                return @{
                    Success = $false
                    Message = "Operation cancelled by user"
                    FilesProcessed = 0
                    DirectoriesProcessed = 0
                }
            }
        }

        # Process files
        $processedFiles = 0
        $processedDirectories = @()
        $errors = @()

        foreach ($file in $backupFiles) {
            try {
                # Create relative path structure in backup directory
                $relativePath = $file.FullName.Replace($SourcePath, "").TrimStart('\', '/')
                $destinationPath = Join-Path $BackupPath $relativePath
                $destinationDir = Split-Path $destinationPath -Parent

                # Create destination directory
                if (-not (Test-Path $destinationDir)) {
                    New-Item -Path $destinationDir -ItemType Directory -Force | Out-Null
                    if ($destinationDir -notin $processedDirectories) {
                        $processedDirectories += $destinationDir
                    }
                }

                # Handle naming conflicts
                $finalDestination = $destinationPath
                $counter = 1
                while (Test-Path $finalDestination) {
                    $directory = Split-Path $destinationPath -Parent
                    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($destinationPath)
                    $extension = [System.IO.Path]::GetExtension($destinationPath)
                    $finalDestination = Join-Path $directory "$baseName-$counter$extension"
                    $counter++
                }

                # Copy file to consolidated location
                if ($PSCmdlet.ShouldProcess($file.FullName, "Consolidate to $finalDestination")) {
                    Copy-Item -Path $file.FullName -Destination $finalDestination -Force
                    $processedFiles++

                    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                        Write-CustomLog "Consolidated: $($file.Name) -> $finalDestination" -Level DEBUG
                    }
                }

            } catch {
                $errorMessage = "Failed to consolidate $($file.FullName): $($_.Exception.Message)"
                $errors += $errorMessage

                if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                    Write-CustomLog $errorMessage -Level WARN
                } else {
                    Write-Warning $errorMessage
                }
            }
        }

        # Create consolidation report
        $timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
        $reportPath = Join-Path $BackupPath "consolidation-report-$timestamp.json"

        $report = @{
            Timestamp = Get-Date
            SourcePath = $SourcePath
            BackupPath = $BackupPath
            FilesProcessed = $processedFiles
            DirectoriesProcessed = $processedDirectories.Count
            TotalFilesFound = $backupFiles.Count
            Errors = $errors
            ExclusionsApplied = $allExclusions
            BackupPatterns = $BackupPatterns
            Success = ($errors.Count -eq 0)
        }

        $report | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath -Encoding UTF8

        # Log completion
        $completionMessage = "Backup consolidation completed: $processedFiles files processed, $($processedDirectories.Count) directories created"
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog $completionMessage -Level SUCCESS
        } else {
            Write-Host "SUCCESS $completionMessage" -ForegroundColor Green
        }

        return @{
            Success = ($errors.Count -eq 0)
            FilesProcessed = $processedFiles
            DirectoriesProcessed = $processedDirectories.Count
            TotalFilesFound = $backupFiles.Count
            BackupPath = $BackupPath
            ReportPath = $reportPath
            Errors = $errors
        }

    } catch {
        $errorMessage = "Backup consolidation failed: $($_.Exception.Message)"

        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog $errorMessage -Level ERROR
        } else {
            Write-Error $errorMessage
        }

        throw
    }
}
