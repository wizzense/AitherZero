#Requires -Version 7.0

function Resolve-ModuleImportIssues {
    <#
    .SYNOPSIS
        Comprehensively resolves all module import issues in the project
    
    .DESCRIPTION
        This function addresses all the widespread module import problems:
        - Installs missing modules to standard PowerShell locations
        - Fixes malformed import paths throughout the codebase
        - Sets up proper environment variables
        - Standardizes import statements
        - Removes duplicate/corrupted imports
        
    .PARAMETER WhatIf
        Show what would be fixed without making changes
        
    .PARAMETER Force
        Force overwrite existing module installations
        
    .EXAMPLE
        Resolve-ModuleImportIssues
        Fixes all import issues in the project
        
    .EXAMPLE
        Resolve-ModuleImportIssues -WhatIf
        Shows what would be fixed without making changes
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$WhatIf,
        [switch]$Force
    )
    
    begin {
        Write-CustomLog "Starting comprehensive module import issue resolution" -Level INFO
        
        # Initialize environment
        $script:ProjectRoot = if ($env:PROJECT_ROOT) { $env:PROJECT_ROOT } else { 
            Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent 
        }
        
        $script:IssuesFound = @{
            MalformedPaths = @()
            MissingModules = @()
            DuplicateForces = @()
            HardcodedPaths = @()
            CorruptedImports = @()
        }
        
        $script:FixesMade = @{
            PathsFixed = 0
            ModulesInstalled = 0
            ImportsStandardized = 0
            DuplicatesRemoved = 0
            EnvironmentVariablesSet = 0
        }
    }
    
    process {
        try {
            # Step 1: Set up proper environment variables
            Write-CustomLog "Step 1: Setting up environment variables" -Level INFO
            Set-ProjectEnvironmentVariables
            
            # Step 2: Install project modules to standard locations
            Write-CustomLog "Step 2: Installing project modules to standard locations" -Level INFO
            Install-ProjectModulesToStandardLocations -Force:$Force -WhatIf:$WhatIf
            
            # Step 3: Fix malformed import statements throughout codebase
            Write-CustomLog "Step 3: Fixing malformed import statements" -Level INFO
            Fix-MalformedImportStatements -WhatIf:$WhatIf
            
            # Step 4: Standardize all import paths
            Write-CustomLog "Step 4: Standardizing import paths" -Level INFO
            Standardize-ImportPaths -WhatIf:$WhatIf
            
            # Step 5: Remove hardcoded Windows paths
            Write-CustomLog "Step 5: Removing hardcoded Windows paths" -Level INFO
            Remove-HardcodedPaths -WhatIf:$WhatIf
            
            # Step 6: Validate all modules can be imported
            Write-CustomLog "Step 6: Validating module imports" -Level INFO
            Test-ModuleImports
            
            # Step 6.5: Validate and fix PowerShell syntax errors
            Write-CustomLog "Step 6.5: Validating and fixing PowerShell syntax errors" -Level INFO
            Fix-PowerShellSyntaxErrors -WhatIf:$WhatIf
            
            # Step 7: Generate summary report
            Write-CustomLog "Step 7: Generating summary report" -Level INFO
            Show-ImportIssuesSummary
            
        } catch {
            Write-CustomLog "Error during import issue resolution: $($_.Exception.Message)" -Level ERROR
            throw
        }
    }
    
    end {
        Write-CustomLog "Module import issue resolution completed" -Level SUCCESS
    }
}

function Set-ProjectEnvironmentVariables {
    [CmdletBinding()]
    param()
    
    # Set PROJECT_ROOT
    if (-not $env:PROJECT_ROOT) {
        $env:PROJECT_ROOT = $script:ProjectRoot
        [Environment]::SetEnvironmentVariable('PROJECT_ROOT', $script:ProjectRoot, 'User')
        Write-CustomLog "Set PROJECT_ROOT: $script:ProjectRoot" -Level SUCCESS
        $script:FixesMade.EnvironmentVariablesSet++
    }
    
    # Set PWSH_MODULES_PATH
    $modulesPath = "$script:ProjectRoot/pwsh/modules"
    if (-not $env:PWSH_MODULES_PATH -or $env:PWSH_MODULES_PATH -ne $modulesPath) {
        $env:PWSH_MODULES_PATH = $modulesPath
        [Environment]::SetEnvironmentVariable('PWSH_MODULES_PATH', $modulesPath, 'User')
        Write-CustomLog "Set PWSH_MODULES_PATH: $modulesPath" -Level SUCCESS
        $script:FixesMade.EnvironmentVariablesSet++
    }
    
    # Add project modules to PSModulePath if not already there
    $currentPSModulePath = $env:PSModulePath
    if ($currentPSModulePath -notlike "*$modulesPath*") {
        $env:PSModulePath = "$modulesPath$([System.IO.Path]::PathSeparator)$currentPSModulePath"
        Write-CustomLog "Added project modules to PSModulePath" -Level SUCCESS
        $script:FixesMade.EnvironmentVariablesSet++
    }
}

function Install-ProjectModulesToStandardLocations {
    [CmdletBinding()]
    param(
        [switch]$Force,
        [switch]$WhatIf
    )
    
    # Define project modules
    $projectModules = @(
        @{
            Name = "LabRunner"
            Path = "$script:ProjectRoot/pwsh/modules/LabRunner"
            Description = "Lab automation and script execution"
        },
        @{
            Name = "PatchManager" 
            Path = "$script:ProjectRoot/pwsh/modules/PatchManager"
            Description = "Git-controlled patch management"
        },
        @{
            Name = "Logging"
            Path = "$script:ProjectRoot/pwsh/modules/Logging"
            Description = "Centralized logging system"
        },
        @{
            Name = "DevEnvironment"
            Path = "$script:ProjectRoot/pwsh/modules/DevEnvironment" 
            Description = "Development environment setup"
        },
        @{
            Name = "BackupManager"
            Path = "$script:ProjectRoot/pwsh/modules/BackupManager"
            Description = "Backup and archival operations"
        },
        @{
            Name = "TestingFramework"
            Path = "$script:ProjectRoot/pwsh/modules/TestingFramework"
            Description = "Unified testing framework"
        },
        @{
            Name = "UnifiedMaintenance"
            Path = "$script:ProjectRoot/pwsh/modules/UnifiedMaintenance"
            Description = "Unified maintenance operations"
        }
    )
    
    # Get standard PowerShell module path for current user
    $documentsPath = [Environment]::GetFolderPath('MyDocuments')
    $standardModulePath = Join-Path $documentsPath "PowerShell\Modules"
    
    foreach ($module in $projectModules) {
        if (-not (Test-Path $module.Path)) {
            Write-CustomLog "Module source not found: $($module.Path)" -Level WARN
            continue
        }
        
        $targetPath = Join-Path $standardModulePath $module.Name
        
        if ($WhatIf) {
            Write-CustomLog "WOULD INSTALL: $($module.Name) to $targetPath" -Level INFO
            continue
        }
        
        try {
            # Remove existing if Force specified
            if ((Test-Path $targetPath) -and $Force) {
                Remove-Item -Path $targetPath -Recurse -Force
                Write-CustomLog "Removed existing module: $($module.Name)" -Level INFO
            }
            
            # Copy module to standard location
            if (-not (Test-Path $targetPath)) {
                Copy-Item -Path $module.Path -Destination $targetPath -Recurse -Force
                Write-CustomLog "Installed module: $($module.Name) - $($module.Description)" -Level SUCCESS
                $script:FixesMade.ModulesInstalled++
            } else {
                Write-CustomLog "Module already installed: $($module.Name)" -Level INFO
            }
            
        } catch {
            Write-CustomLog "Failed to install module $($module.Name): $($_.Exception.Message)" -Level ERROR
            $script:IssuesFound.MissingModules += $module.Name
        }
    }
}

function Fix-MalformedImportStatements {
    [CmdletBinding()]
    param([switch]$WhatIf)
    
    # Find all PowerShell files
    $files = Get-ChildItem -Path $script:ProjectRoot -Recurse -Include "*.ps1", "*.psm1" | 
        Where-Object { $_.FullName -notlike "*\.git\*" -and $_.FullName -notlike "*\backups\*" }
    
    foreach ($file in $files) {
        try {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $content) { continue }
            
            $originalContent = $content
            $fileModified = $false
            
            # Fix 1: Remove duplicate -Force parameters
            $duplicateForcePattern = '(-Force\s+){2,}'
            if ($content -match $duplicateForcePattern) {
                $content = $content -replace $duplicateForcePattern, '-Force '
                $fileModified = $true
                $script:IssuesFound.DuplicateForces += $file.FullName
                Write-CustomLog "Fixed duplicate -Force in: $($file.Name)" -Level INFO
            }
            
            # Fix 2: Fix broken concatenated import statements
            $concatenatedPattern = 'Import-Module\s+"[^"]*"\s+-Force\s*Import-Module'
            if ($content -match $concatenatedPattern) {
                $content = $content -replace $concatenatedPattern, 'Import-Module'
                $fileModified = $true
                $script:IssuesFound.CorruptedImports += $file.FullName
                Write-CustomLog "Fixed concatenated imports in: $($file.Name)" -Level INFO
            }
            
            # Fix 3: Remove malformed paths with double slashes
            $doubleSlashPattern = '//pwsh/modules/'
            if ($content -match $doubleSlashPattern) {
                $content = $content -replace $doubleSlashPattern, '/pwsh/modules/'
                $fileModified = $true
                $script:IssuesFound.MalformedPaths += $file.FullName
                Write-CustomLog "Fixed double slashes in: $($file.Name)" -Level INFO
            }
            
            # Fix 4: Remove hardcoded user paths
            $hardcodedPathPattern = 'C:\\Users\\alexa\\OneDrive\\Documents\\0\. wizzense\\opentofu-lab-automation'
            if ($content -match [regex]::Escape($hardcodedPathPattern)) {
                $content = $content -replace [regex]::Escape($hardcodedPathPattern), '/workspaces/opentofu-lab-automation'
                $fileModified = $true
                $script:IssuesFound.HardcodedPaths += $file.FullName
                Write-CustomLog "Fixed hardcoded path in: $($file.Name)" -Level INFO
            }
            
            # Apply changes if file was modified
            if ($fileModified -and -not $WhatIf) {
                Set-Content -Path $file.FullName -Value $content -Encoding UTF8
                $script:FixesMade.ImportsStandardized++
            } elseif ($fileModified -and $WhatIf) {
                Write-CustomLog "WOULD FIX: $($file.Name)" -Level INFO
            }
            
        } catch {
            Write-CustomLog "Error processing file $($file.FullName): $($_.Exception.Message)" -Level ERROR
        }
    }
}

function Standardize-ImportPaths {
    [CmdletBinding()]
    param([switch]$WhatIf)
    
    # Define standard import patterns
    $importPatterns = @{
        # LabRunner imports
        'Import-Module\s+"?\.?/?pwsh/modules/LabRunner/?"\s*(-Force\s*)*' = 'Import-Module "LabRunner" -Force'
        'Import-Module\s+"?\.?/?pwsh/modules/LabRunner/LabRunner"\s*(-Force\s*)*' = 'Import-Module "LabRunner" -Force'
        
        # PatchManager imports  
        'Import-Module\s+"?\.?/?pwsh/modules/PatchManager/?"\s*(-Force\s*)*' = 'Import-Module "PatchManager" -Force'
        
        # Logging imports
        'Import-Module\s+"?\.?/?pwsh/modules/Logging/?"\s*(-Force\s*)*' = 'Import-Module "Logging" -Force'
        
        # DevEnvironment imports
        'Import-Module\s+"?\.?/?pwsh/modules/DevEnvironment/?"\s*(-Force\s*)*' = 'Import-Module "DevEnvironment" -Force'
        
        # BackupManager imports
        'Import-Module\s+"?\.?/?pwsh/modules/BackupManager/?"\s*(-Force\s*)*' = 'Import-Module "BackupManager" -Force'
        
        # Remove deprecated CodeFixer references
        'Import-Module\s+"?\.?/?pwsh/modules/CodeFixer/?"\s*(-Force\s*)*' = '# CodeFixer module deprecated - functionality moved to other modules'
    }
    
    $files = Get-ChildItem -Path $script:ProjectRoot -Recurse -Include "*.ps1", "*.psm1" |
        Where-Object { $_.FullName -notlike "*\.git\*" -and $_.FullName -notlike "*\backups\*" }
    
    foreach ($file in $files) {
        try {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $content) { continue }
            
            $originalContent = $content
            $fileModified = $false
            
            foreach ($pattern in $importPatterns.Keys) {
                $replacement = $importPatterns[$pattern]
                if ($content -match $pattern) {
                    $content = $content -replace $pattern, $replacement
                    $fileModified = $true
                    Write-CustomLog "Standardized import in: $($file.Name)" -Level INFO
                }
            }
            
            if ($fileModified -and -not $WhatIf) {
                Set-Content -Path $file.FullName -Value $content -Encoding UTF8
                $script:FixesMade.PathsFixed++
            }
            
        } catch {
            Write-CustomLog "Error standardizing imports in $($file.FullName): $($_.Exception.Message)" -Level ERROR
        }
    }
}

function Remove-HardcodedPaths {
    [CmdletBinding()]
    param([switch]$WhatIf)
    
    # Define hardcoded path patterns to fix
    $pathPatterns = @{
        'C:\\Users\\alexa\\OneDrive\\Documents\\0\. wizzense\\opentofu-lab-automation' = '$env:PROJECT_ROOT'
        '/C:\\Users\\alexa\\OneDrive\\Documents\\0\. wizzense\\opentofu-lab-automation' = '$env:PROJECT_ROOT'
        '"C:\\Users\\alexa\\OneDrive\\Documents\\0\. wizzense\\opentofu-lab-automation' = '"$env:PROJECT_ROOT'
    }
    
    $files = Get-ChildItem -Path $script:ProjectRoot -Recurse -Include "*.ps1", "*.psm1" |
        Where-Object { $_.FullName -notlike "*\.git\*" -and $_.FullName -notlike "*\backups\*" }
    
    foreach ($file in $files) {
        try {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $content) { continue }
            
            $fileModified = $false
            
            foreach ($pattern in $pathPatterns.Keys) {
                $replacement = $pathPatterns[$pattern]
                if ($content -match [regex]::Escape($pattern)) {
                    $content = $content -replace [regex]::Escape($pattern), $replacement
                    $fileModified = $true
                    Write-CustomLog "Removed hardcoded path in: $($file.Name)" -Level INFO
                }
            }
            
            if ($fileModified -and -not $WhatIf) {
                Set-Content -Path $file.FullName -Value $content -Encoding UTF8
                $script:FixesMade.PathsFixed++
            }
            
        } catch {
            Write-CustomLog "Error removing hardcoded paths in $($file.FullName): $($_.Exception.Message)" -Level ERROR
        }
    }
}

function Test-ModuleImports {
    [CmdletBinding()]
    param()
    
    $modules = @("LabRunner", "PatchManager", "Logging", "DevEnvironment", "BackupManager")
    $importResults = @{}
    
    foreach ($module in $modules) {
        try {
            Import-Module $module -Force -ErrorAction Stop
            $importResults[$module] = @{
                Status = "SUCCESS"
                Message = "Module imported successfully"
            }
            Write-CustomLog "✓ $module module imports successfully" -Level SUCCESS
        } catch {
            $importResults[$module] = @{
                Status = "FAILED"
                Message = $_.Exception.Message
            }
            Write-CustomLog "✗ $module module failed to import: $($_.Exception.Message)" -Level ERROR
        }
    }
    
    return $importResults
}

function Show-ImportIssuesSummary {
    [CmdletBinding()]
    param()
    
    Write-CustomLog "`n=== MODULE IMPORT ISSUES RESOLUTION SUMMARY ===" -Level INFO
    Write-CustomLog "Environment Variables Set: $($script:FixesMade.EnvironmentVariablesSet)" -Level INFO
    Write-CustomLog "Modules Installed: $($script:FixesMade.ModulesInstalled)" -Level INFO
    Write-CustomLog "Import Statements Fixed: $($script:FixesMade.ImportsStandardized)" -Level INFO
    Write-CustomLog "Paths Standardized: $($script:FixesMade.PathsFixed)" -Level INFO
    Write-CustomLog "Duplicate Forces Removed: $($script:FixesMade.DuplicatesRemoved)" -Level INFO
    
    Write-CustomLog "`n=== ISSUES FOUND ===" -Level INFO
    Write-CustomLog "Malformed Paths: $($script:IssuesFound.MalformedPaths.Count)" -Level INFO
    Write-CustomLog "Missing Modules: $($script:IssuesFound.MissingModules.Count)" -Level INFO
    Write-CustomLog "Duplicate Forces: $($script:IssuesFound.DuplicateForces.Count)" -Level INFO
    Write-CustomLog "Hardcoded Paths: $($script:IssuesFound.HardcodedPaths.Count)" -Level INFO
    Write-CustomLog "Corrupted Imports: $($script:IssuesFound.CorruptedImports.Count)" -Level INFO
    
    Write-CustomLog "`n=== NEXT STEPS ===" -Level INFO
    Write-CustomLog "1. Restart PowerShell to pick up environment variable changes" -Level INFO
    Write-CustomLog "2. Run 'Test-DevelopmentSetup' to validate the environment" -Level INFO
    Write-CustomLog "3. Run comprehensive validation: Initialize-DevelopmentEnvironment" -Level INFO
}

function Fix-PowerShellSyntaxErrors {
    [CmdletBinding()]
    param([switch]$WhatIf)
    
    # Define common syntax error patterns and their fixes
    $syntaxFixes = @{
        # Parameter attribute fixes
        'Parameter\(Mandatory\)' = '[Parameter(Mandatory)]'
        'CmdletBinding\(\)' = '[CmdletBinding()]'
        'ValidateSet\(' = '[ValidateSet('
        'switch\$' = '[switch]$'
        'string\$' = '[string]$'
        'int\$' = '[int]$'
        'array\$' = '[array]$'
        
        # Type accelerator fixes
        'System\.Runtime\.InteropServices\.RuntimeInformation::' = '[System.Runtime.InteropServices.RuntimeInformation]::'
        'System\.Runtime\.InteropServices\.OSPlatform::' = '[System.Runtime.InteropServices.OSPlatform]::'
        'System\.ArgumentException::new' = '[System.ArgumentException]::new'
        'System\.IO\.Path::GetTempPath' = '[System.IO.Path]::GetTempPath'
        'DateTime::Parse' = '[DateTime]::Parse'
        'Environment::ProcessorCount' = '[Environment]::ProcessorCount'
        '[Math]::Round' = '[math]::Round'
        
        # Variable access fixes
        '\$(\w+)\[(\d+)\]' = '$1[$2]'  # Fix array access like $Items$i to $Items[$i]
        '\$(\w+)\["([^"]+)"\]' = '$1["$2"]'  # Fix hashtable access
        '\$(\w+)\[([^]]+)\]' = '$1[$2]'  # Generic array/hashtable access
        
        # Missing variable prefix fixes
        '(?<=\s|^)(\w+)\s+\|' = '$$1 |'  # Fix missing $ before variable in pipeline
    }
    
    # Find PowerShell files in critical modules
    $criticalModules = @("LabRunner", "PatchManager", "DevEnvironment", "Logging", "BackupManager")
    $filesToFix = @()
    
    foreach ($module in $criticalModules) {
        $modulePath = "$script:ProjectRoot/pwsh/modules/$module"
        if (Test-Path $modulePath) {
            $moduleFiles = Get-ChildItem -Path $modulePath -Recurse -Include "*.ps1", "*.psm1" | 
                Where-Object { $_.FullName -notlike "*\.git\*" }
            $filesToFix += $moduleFiles
        }
    }
    
    $syntaxIssuesFixed = 0
    
    foreach ($file in $filesToFix) {
        try {
            # First test if file has syntax errors
            $tokens = $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
            
            if ($errors.Count -eq 0) {
                continue  # No syntax errors, skip
            }
            
            Write-CustomLog "Fixing syntax errors in: $($file.Name)" -Level INFO
            
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $content) { continue }
            
            $originalContent = $content
            $fileModified = $false
            
            # Apply syntax fixes
            foreach ($pattern in $syntaxFixes.Keys) {
                $replacement = $syntaxFixes[$pattern]
                if ($content -match $pattern) {
                    $content = $content -replace $pattern, $replacement
                    $fileModified = $true
                }
            }
            
            # Test syntax after fixes
            if ($fileModified) {
                $tempFile = [System.IO.Path]::GetTempFileName() + ".ps1"
                Set-Content -Path $tempFile -Value $content -Encoding UTF8
                
                try {
                    $tokens = $errors = $null
                    [System.Management.Automation.Language.Parser]::ParseFile($tempFile, [ref]$tokens, [ref]$errors) | Out-Null
                    
                    if ($errors.Count -eq 0) {
                        if (-not $WhatIf) {
                            Set-Content -Path $file.FullName -Value $content -Encoding UTF8
                            Write-CustomLog "✓ Fixed syntax errors in: $($file.Name)" -Level SUCCESS
                            $syntaxIssuesFixed++
                        } else {
                            Write-CustomLog "WOULD FIX syntax errors in: $($file.Name)" -Level INFO
                        }
                    } else {
                        Write-CustomLog "⚠ Still has syntax errors after automated fixes: $($file.Name)" -Level WARN
                        foreach ($error in $errors) {
                            Write-CustomLog "  Error: $($error.Message)" -Level WARN
                        }
                    }
                } finally {
                    Remove-Item $tempFile -ErrorAction SilentlyContinue
                }
            }
            
        } catch {
            Write-CustomLog "Error fixing syntax in $($file.FullName): $($_.Exception.Message)" -Level ERROR
        }
    }
    
    if ($syntaxIssuesFixed -gt 0) {
        Write-CustomLog "Fixed syntax errors in $syntaxIssuesFixed files" -Level SUCCESS
    } else {
        Write-CustomLog "No additional syntax errors found to fix" -Level SUCCESS
    }
}

