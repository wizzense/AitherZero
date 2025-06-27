<#
.SYNOPSIS
Creates backup exclusion rules in project configuration files

.DESCRIPTION
Updates .gitignore, PSScriptAnalyzer settings, and other configuration files
to exclude backup files and problematic patterns from version control and validation.

.PARAMETER ProjectRoot
The root directory of the project

.PARAMETER Patterns
Array of file patterns to exclude

.PARAMETER ConfigFiles
Specific configuration files to update (optional)

.EXAMPLE
New-BackupExclusion -ProjectRoot "." -Patterns @("*.bak", "*.backup")

.NOTES
Follows OpenTofu Lab Automation maintenance standards
#>
function New-BackupExclusion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        
        [Parameter(Mandatory = $true)]
        [string[]]$Patterns,
        
        [string[]]$ConfigFiles = @()
    )
    
    $ErrorActionPreference = "Stop"
    
    try {
        # Import LabRunner for logging
        if (Get-Module LabRunner -ErrorAction SilentlyContinue) {
            Write-CustomLog "Creating backup exclusion rules" "INFO"
        } else {
            Write-Host "INFO Creating backup exclusion rules" -ForegroundColor Green
        }
        
        # Resolve project root
        $ProjectRoot = Resolve-Path $ProjectRoot -ErrorAction Stop
        
        # Default configuration files to update
        $DefaultConfigFiles = @(
            ".gitignore",
            "configs/yamllint.yaml",
            ".psscriptanalyzer.psd1"
        )
        
        $AllConfigFiles = if ($ConfigFiles.Count -gt 0) { $ConfigFiles } else { $DefaultConfigFiles }
        $UpdatedFiles = 0
        
        foreach ($ConfigFile in $AllConfigFiles) {
            $ConfigPath = Join-Path $ProjectRoot $ConfigFile
            
            if (Test-Path $ConfigPath) {
                try {
                    $content = Get-Content $ConfigPath -Raw
                    $originalContent = $content
                    
                    # Add patterns based on file type
                    switch ($ConfigFile) {
                        ".gitignore" {
                            foreach ($Pattern in $Patterns) {
                                if ($content -notlike "*$Pattern*") {
                                    $content += "`n# Backup exclusions`n$Pattern"
                                }
                            }
                        }
                        
                        { $_ -like "*.yaml" -or $_ -like "*.yml" } {
                            # For YAML files, add to ignore patterns if supported
                            if ($content -like "*ignore:*") {
                                foreach ($Pattern in $Patterns) {
                                    if ($content -notlike "*$Pattern*") {
                                        $content = $content -replace "(ignore:.*)", "`$1`n  - '$Pattern'"
                                    }
                                }
                            }
                        }
                        
                        { $_ -like "*.psd1" } {
                            # For PowerShell data files, add to ExcludeRules if it exists
                            if ($content -like "*ExcludeRules*") {
                                foreach ($Pattern in $Patterns) {
                                    if ($content -notlike "*$Pattern*") {
                                        $content = $content -replace "(ExcludeRules\s*=\s*@\(^)*)", "`$1, '$Pattern'"
                                    }
                                }
                            }
                        }
                    }
                    
                    # Only update if content changed
                    if ($content -ne $originalContent) {
                        Set-Content -Path $ConfigPath -Value $content
                        $UpdatedFiles++
                        
                        if (Get-Module LabRunner -ErrorAction SilentlyContinue) {
                            Write-CustomLog "Updated exclusions in $ConfigFile" "INFO"
                        }
                    }
                    
                } catch {
                    Write-Warning "Failed to update $ConfigFile : $($_.Exception.Message)"
                }
            } else {
                Write-Verbose "Configuration file not found: $ConfigFile"
            }
        }
        
        $summaryMessage = "Backup exclusion rules created for $UpdatedFiles configuration files"
        if (Get-Module LabRunner -ErrorAction SilentlyContinue) {
            Write-CustomLog $summaryMessage "INFO"
        } else {
            Write-Host "INFO $summaryMessage" -ForegroundColor Green
        }
        
        return @{
            Success = $true
            UpdatedFiles = $UpdatedFiles
            Patterns = $Patterns
        }
        
    } catch {
        $ErrorMessage = "Failed to create backup exclusions: $($_.Exception.Message)"
        if (Get-Module LabRunner -ErrorAction SilentlyContinue) {
            Write-CustomLog $ErrorMessage "ERROR"
        } else {
            Write-Host "ERROR $ErrorMessage" -ForegroundColor Red
        }
        throw $_
    }
}
