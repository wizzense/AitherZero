<#
.SYNOPSIS
Permanently removes problematic files and prevents their future creation

.DESCRIPTION
Identifies and permanently removes files that cause issues in the project,
such as duplicate files, corrupted backups, and problematic configurations.
Also creates prevention mechanisms to avoid recreating these files.

.PARAMETER ProjectRoot
The root directory of the project to clean

.PARAMETER ProblematicPatterns
Array of file patterns that should be permanently removed

.PARAMETER CreatePreventionRules
Create .gitignore and other rules to prevent recreation

.PARAMETER Force
Skip confirmation prompts

.EXAMPLE
Invoke-PermanentCleanup -ProjectRoot "." -Force -CreatePreventionRules

.NOTES
This function implements aggressive cleanup following maintenance standards
#>
function Invoke-PermanentCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        
        [string[]]$ProblematicPatterns = @(),
        
        [switch]$CreatePreventionRules,
        
        [switch]$Force
    )
    
    $ErrorActionPreference = "Stop"
    
    try {
        # Import LabRunner for logging
        if (Get-Module LabRunner -ErrorAction SilentlyContinue) {
            Write-CustomLog "Starting permanent cleanup process" "INFO"
        } else {
            Write-Host "[INFO] Starting permanent cleanup process" -ForegroundColor Green
        }
        
        # Import Logging module for enhanced logging capabilities
        Import-Module "//pwsh/modules/CodeFixerLogging/" -Force
        
        # Fallback definition for Write-CustomLog if not available
        if (-not (Get-Command "Write-CustomLog" -ErrorAction SilentlyContinue)) {
            function Write-CustomLog {
                param([string]$Message, [string]$Level = "INFO")
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                $color = switch ($Level) {
                    "ERROR" { "Red" }
                    "WARN" { "Yellow" }
                    "INFO" { "Green" }
                    default { "White" }
                }
                Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
            }
        }
        
        # Default problematic patterns based on common issues
        $DefaultProblematicPatterns = @(
            # Duplicate mega-consolidated files
            "*mega-consolidated*.yml.bak",
            "*mega-consolidated-fixed-backup*",
            
            # Problematic backup files
            "*.ps1.bak.bak",
            "*.backup.backup",
            "*-backup-*-backup*",
            
            # Temporary and cache files
            "*.tmp.*",
            "*.cache.*",
            "*.lock.*",
            
            # Corrupted or partial files
            "*.partial",
            "*.corrupt",
            "*.incomplete",
            
            # OS generated files
            "Thumbs.db",
            ".DS_Store",
            "desktop.ini",
            
            # Legacy and deprecated files
            "*-deprecated-*",
            "*-legacy-*",
            "*-old-*",
            
            # Test artifacts that shouldn't persist
            "TestResults*.xml.bak",
            "coverage*.xml.old",
            "*.test.log",
            
            # Duplicate configuration files
            "*.config.backup",
            "*.json.orig",
            "*.yaml.bak"
        )
        
        $AllPatterns = $DefaultProblematicPatterns + $ProblematicPatterns
        $ProjectRoot = Resolve-Path $ProjectRoot -ErrorAction Stop
        
        # Find problematic files
        $ProblematicFiles = @()
        foreach ($Pattern in $AllPatterns) {
            $Files = Get-ChildItem -Path $ProjectRoot -Recurse -File -Filter $Pattern -ErrorAction SilentlyContinue
            # Exclude files in the consolidated backup directory
            $FilteredFiles = $Files | Where-Object {
                $_.FullName -notlike "*backups/consolidated-backups*" -and
                $_.FullName -notlike "*.git*"
            }
            $ProblematicFiles += $FilteredFiles
        }
        
        if ($ProblematicFiles.Count -eq 0) {
            Write-Host "[INFO] No problematic files found" -ForegroundColor Green
            return @{
                Success = $true
                FilesRemoved = 0
                Message = "No problematic files found"
            }
        }
        
        # Show what will be removed
        Write-Host "[WARNING] Found $($ProblematicFiles.Count) problematic files:" -ForegroundColor Yellow
        $ProblematicFiles | ForEach-Object {
            $RelativePath = $_.FullName.Replace($ProjectRoot, "").TrimStart('\', '/')
            Write-Host "  - $RelativePath" -ForegroundColor Yellow
        }
        
        # Confirm operation unless Force is specified
        if (-not $Force) {
            Write-Host ""
            Write-Host "[WARNING] This will PERMANENTLY DELETE these files!" -ForegroundColor Red
            $Confirmation = Read-Host "Are you sure you want to proceed? (type 'DELETE' to confirm)"
            if ($Confirmation -ne "DELETE") {
                Write-Host "[INFO] Operation cancelled" -ForegroundColor Yellow
                return @{ Success = $false; Message = "Cancelled by user" }
            }
        }
        
        # Remove problematic files
        $RemovedCount = 0
        $Errors = @()
        
        foreach ($File in $ProblematicFiles) {
            try {
                Remove-Item -Path $File.FullName -Force
                $RemovedCount++
                
                if (Get-Module LabRunner -ErrorAction SilentlyContinue) {
                    Write-CustomLog "Permanently removed: $($File.Name)" "INFO"
                }
                
            } catch {
                $Errors += "Failed to remove $($File.FullName): $($_.Exception.Message)"
                Write-Warning "Failed to remove $($File.FullName): $($_.Exception.Message)"
            }
        }
        
        # Update prevention rules if specified
        if ($CreatePreventionRules) {
            try {
                # Use the New-BackupExclusion function to update .gitignore and other relevant files
                New-BackupExclusion -ProjectRoot $ProjectRoot -Patterns $AllPatterns -Verbose:$false
                if (Get-Module LabRunner -ErrorAction SilentlyContinue) {
                    Write-CustomLog "Prevention rules updated for problematic patterns" "INFO"
                } else {
                    Write-Host "[INFO] Prevention rules updated for problematic patterns"
                }
            } catch {
                $Errors += "Failed to update prevention rules: $($_.Exception.Message)"
                Write-Warning "Failed to update prevention rules: $($_.Exception.Message)"
            }
        }

        $SummaryMessage = "Permanent cleanup completed: $RemovedCount files removed"
        
        if (Get-Module LabRunner -ErrorAction SilentlyContinue) {
            Write-CustomLog $SummaryMessage "INFO"
        } else {
            Write-Host "[INFO] $SummaryMessage" -ForegroundColor Green
        }
        
        return @{
            Success = $Errors.Count -eq 0
            FilesRemoved = $RemovedCount
            Errors = $Errors
            PatternsUsed = $AllPatterns
            PreventionRulesCreated = $CreatePreventionRules
            Timestamp = Get-Date
        }
        
    } catch {
        $ErrorMessage = "Permanent cleanup failed: $($_.Exception.Message)"
        if (Get-Module LabRunner -ErrorAction SilentlyContinue) {
            Write-CustomLog $ErrorMessage "ERROR"
        } else {
            Write-Error $ErrorMessage
        }
        throw
    }
}

