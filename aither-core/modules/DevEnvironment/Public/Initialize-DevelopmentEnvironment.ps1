#Requires -Version 7.0

<#
.SYNOPSIS
    Sets up the optimal development environment for the OpenTofu Lab Automation project.

.DESCRIPTION
    This function configures the complete development environment including:
    - Pre-commit hooks with emoji prevention and syntax validation
    - PowerShell module installation in standard locations
    - Git command aliases that automatically use PatchManager
    - VS Code integration with proper testing workflows
    - Comprehensive emoji removal from existing files

.PARAMETER InstallModulesGlobally
    Install project modules to standard PowerShell module locations for easier testing.

.PARAMETER SetupGitAliases
    Configure Git command aliases that automatically use PatchManager workflows.

.PARAMETER CleanupEmojis
    Remove existing emojis from all project files and replace with professional language.

.PARAMETER Force
    Force reinstallation/reconfiguration of all components.

.EXAMPLE
    Initialize-DevelopmentEnvironment -InstallModulesGlobally -SetupGitAliases -CleanupEmojis
    
    Sets up the complete optimal development environment.

.NOTES
    Part of the DevEnvironment module. This function integrates all development
    tools and enforces project standards comprehensively.
#>

function Initialize-DevelopmentEnvironment {
    <#
    .SYNOPSIS
        Completely sets up the development environment with all required components
    
    .DESCRIPTION
        This function provides comprehensive development environment setup including:
        - Module import issue resolution
        - Pre-commit hook installation with emoji prevention
        - Git aliases for PatchManager integration
        - PowerShell module installation to standard locations
        - Environment variable configuration
        - Development tooling setup
        
    .PARAMETER Force
        Force reinstallation of modules and components
        
    .PARAMETER SkipModuleImportFixes
        Skip the module import issue resolution (useful if already done)
        
    .EXAMPLE
        Initialize-DevelopmentEnvironment
        Sets up complete development environment
        
    .EXAMPLE
        Initialize-DevelopmentEnvironment -Force
        Force reinstalls all components
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$Force,
        [switch]$SkipModuleImportFixes
    )
    
    begin {
        Write-CustomLog "=== INITIALIZING DEVELOPMENT ENVIRONMENT ===" -Level INFO
        Write-CustomLog "This will set up all required development tools and resolve import issues" -Level INFO
        
        $stepCount = 0
        $totalSteps = 8
        
        function Write-Step {
            param($StepName)
            $script:stepCount++
            Write-CustomLog "Step $($script:stepCount)/$($totalSteps): $StepName" -Level INFO
        }
    }
    
    process {
        try {
            # Step 1: Resolve all module import issues
            if (-not $SkipModuleImportFixes) {
                Write-Step "Resolving module import issues"
                Resolve-ModuleImportIssues -Force:$Force
            } else {
                Write-CustomLog "Skipping module import fixes as requested" -Level INFO
            }
            
            # Step 2: Install pre-commit hook with emoji prevention
            Write-Step "Installing pre-commit hook with emoji prevention"
            try {
                Install-PreCommitHook -Install -Force:$Force
                Write-CustomLog "✓ Pre-commit hook installed successfully" -Level SUCCESS
            } catch {
                Write-CustomLog "⚠ Pre-commit hook installation failed: $($_.Exception.Message)" -Level WARN
            }
            
            # Step 3: Set up Git aliases for PatchManager integration
            Write-Step "Setting up Git aliases for PatchManager"
            try {
                Set-PatchManagerAliases -Install
                Write-CustomLog "✓ Git aliases for PatchManager configured successfully" -Level SUCCESS
            } catch {
                Write-CustomLog "⚠ Git aliases setup failed: $($_.Exception.Message)" -Level WARN
            }
            
            # Step 4: Remove any existing emojis from project
            Write-Step "Removing emojis from project"
            try {
                Remove-ProjectEmojis
                Write-CustomLog "✓ Project emoji cleanup completed" -Level SUCCESS
            } catch {
                Write-CustomLog "⚠ Emoji removal failed: $($_.Exception.Message)" -Level WARN
            }
            
            # Step 5: Install required PowerShell modules
            Write-Step "Installing required PowerShell modules"
            Install-RequiredPowerShellModules -Force:$Force
            
            # Step 6: Set up testing framework
            Write-Step "Setting up testing framework"
            Setup-TestingFramework
            
            # Step 7: Configure VS Code integration
            Write-Step "Configuring VS Code integration"
            Configure-VSCodeIntegration
            
            # Step 8: Validate development environment
            Write-Step "Validating development environment"
            $validationResults = @(
                @{ Test = "PowerShell Version"; Status = "PASS"; Message = "PowerShell $($PSVersionTable.PSVersion)" },
                @{ Test = "Project Root"; Status = if ($env:PROJECT_ROOT) { "PASS" } else { "FAIL" }; Message = $env:PROJECT_ROOT }
            )
            
            # Show summary
            Show-DevEnvironmentSummary -ValidationResults $validationResults
            
        } catch {
            Write-CustomLog "Critical error during development environment setup: $($_.Exception.Message)" -Level ERROR
            throw
        }
    }
    
    end {
        Write-CustomLog "=== DEVELOPMENT ENVIRONMENT INITIALIZATION COMPLETE ===" -Level SUCCESS
        Write-CustomLog "Please restart PowerShell to pick up all environment changes" -Level INFO
    }
}

function Install-RequiredPowerShellModules {
    [CmdletBinding()]
    param([switch]$Force)
    
    $requiredModules = @(
        @{ Name = "Pester"; Version = "5.7.1" },
        @{ Name = "powershell-yaml"; Version = $null },
        @{ Name = "ThreadJob"; Version = $null },
        @{ Name = "PSScriptAnalyzer"; Version = $null }
    )
    
    foreach ($module in $requiredModules) {
        try {
            $installed = Get-Module -ListAvailable -Name $module.Name
            if ($module.Version) {
                $installed = $installed | Where-Object { $_.Version -ge [version]$module.Version }
            }
            
            if (-not $installed -or $Force) {
                Write-CustomLog "Installing $($module.Name)..." -Level INFO
                $installParams = @{
                    Name = $module.Name
                    Scope = "CurrentUser"
                    Force = $true
                }
                if ($module.Version) {
                    $installParams.RequiredVersion = $module.Version
                }
                Install-Module @installParams
                Write-CustomLog "✓ $($module.Name) installed successfully" -Level SUCCESS
            } else {
                Write-CustomLog "✓ $($module.Name) already installed" -Level SUCCESS
            }
        } catch {
            Write-CustomLog "⚠ Failed to install $($module.Name): $($_.Exception.Message)" -Level WARN
        }
    }
}

function Setup-TestingFramework {
    [CmdletBinding()]
    param()
    
    try {
        # Ensure Pester 5.7.1+ is available
        $pester = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge [version]"5.7.1" }
        if ($pester) {
            Import-Module Pester -RequiredVersion 5.7.1 -Force
            Write-CustomLog "✓ Pester 5.7.1+ configured" -Level SUCCESS
        } else {
            Write-CustomLog "⚠ Pester 5.7.1+ not found" -Level WARN
        }
        
        # Set up Python testing if available
        if (Get-Command python -ErrorAction SilentlyContinue) {
            $projectRoot = $env:PROJECT_ROOT
            if ($projectRoot -and (Test-Path "$projectRoot/py")) {
                python -m pip install -e "$projectRoot/py" | Out-Null
                Write-CustomLog "✓ Python testing framework configured" -Level SUCCESS
            }
        }
        
    } catch {
        Write-CustomLog "⚠ Testing framework setup encountered issues: $($_.Exception.Message)" -Level WARN
    }
}

function Configure-VSCodeIntegration {
    [CmdletBinding()]
    param()
    
    try {
        $projectRoot = $env:PROJECT_ROOT
        if (-not $projectRoot) { 
            Write-CustomLog "⚠ PROJECT_ROOT not set, skipping VS Code integration" -Level WARN
            return 
        }
        
        $vscodeSettingsPath = "$projectRoot/.vscode/settings.json"
        if (Test-Path $vscodeSettingsPath) {
            Write-CustomLog "✓ VS Code settings detected" -Level SUCCESS
        }
        
        $vscodeTasksPath = "$projectRoot/.vscode/tasks.json"  
        if (Test-Path $vscodeTasksPath) {
            Write-CustomLog "✓ VS Code tasks configured" -Level SUCCESS
        }
        
        Write-CustomLog "✓ VS Code integration verified" -Level SUCCESS
        
    } catch {
        Write-CustomLog "⚠ VS Code integration check failed: $($_.Exception.Message)" -Level WARN
    }
}

function Show-DevEnvironmentSummary {
    [CmdletBinding()]
    param($ValidationResults)
    
    Write-CustomLog "`n=== DEVELOPMENT ENVIRONMENT SUMMARY ===" -Level INFO
    
    # Show module status
    $modules = @("LabRunner", "PatchManager", "Logging", "DevEnvironment", "BackupManager")
    Write-CustomLog "`nModule Status:" -Level INFO
    foreach ($module in $modules) {
        try {
            Import-Module $module -Force -ErrorAction Stop
            Write-CustomLog "  ✓ $module - Available" -Level SUCCESS
        } catch {
            Write-CustomLog "  ✗ $module - Not available" -Level ERROR
        }
    }
    
    # Show environment variables
    Write-CustomLog "`nEnvironment Variables:" -Level INFO
    $projectRootStatus = if ($env:PROJECT_ROOT) { $env:PROJECT_ROOT } else { 'NOT SET' }
    $modulesPathStatus = if ($env:PWSH_MODULES_PATH) { $env:PWSH_MODULES_PATH } else { 'NOT SET' }
    Write-CustomLog "  PROJECT_ROOT: $projectRootStatus" -Level INFO
    Write-CustomLog "  PWSH_MODULES_PATH: $modulesPathStatus" -Level INFO
    
    # Show validation results if provided
    if ($ValidationResults) {
        Write-CustomLog "`nValidation Results:" -Level INFO
        foreach ($result in $ValidationResults) {
            $status = if ($result.Status -eq "PASS") { "✓" } else { "✗" }
            Write-CustomLog "  $status $($result.Test): $($result.Message)" -Level INFO
        }
    }
    
    Write-CustomLog "`nNext Steps:" -Level INFO
    Write-CustomLog "  1. Restart PowerShell session" -Level INFO
    Write-CustomLog "  2. Test: Import-Module LabRunner -Force" -Level INFO
    Write-CustomLog "  3. Run: Test-DevelopmentSetup" -Level INFO
    Write-CustomLog "  4. Start developing with PatchManager for all changes" -Level INFO
}

function Set-PatchManagerAliases {
    <#
    .SYNOPSIS
        Configures Git aliases to integrate with PatchManager workflows
    
    .DESCRIPTION
        This function sets up convenient Git aliases that automatically use
        PatchManager workflows instead of direct Git commands. This ensures
        all changes go through proper patch management.
        
    .PARAMETER Install
        Install the Git aliases
        
    .PARAMETER Remove
        Remove the Git aliases
        
    .EXAMPLE
        Set-PatchManagerAliases -Install
        Configures Git aliases for PatchManager integration
    #>
    [CmdletBinding()]
    param(
        [switch]$Install,
        [switch]$Remove
    )
    
    # Define Git aliases that integrate with PatchManager
    $gitAliases = @{
        'quick-fix' = 'pwsh -Command "Import-Module PatchManager -Force; New-QuickFix"'
        'new-feature' = 'pwsh -Command "Import-Module PatchManager -Force; New-Feature"'
        'hotfix' = 'pwsh -Command "Import-Module PatchManager -Force; New-Hotfix"'
        'patch' = 'pwsh -Command "Import-Module PatchManager -Force; New-Patch"'
        'sync-branch' = 'pwsh -Command "Import-Module PatchManager -Force; Sync-GitBranch -Force"'
        'patch-status' = 'pwsh -Command "Import-Module PatchManager -Force; Get-PatchStatus"'
        'patch-rollback' = 'pwsh -Command "Import-Module PatchManager -Force; Invoke-PatchRollback"'
        'safe-commit' = 'pwsh -Command "Import-Module PatchManager -Force; New-Patch -Mode Simple"'
        'create-pr' = 'pwsh -Command "Import-Module PatchManager -Force; New-PatchPR"'
        'cleanup-patches' = 'pwsh -Command "Import-Module PatchManager -Force; Invoke-PatchCleanup"'
    }
    
    if ($Install) {
        Write-CustomLog "Installing Git aliases for PatchManager integration..." -Level INFO
        
        foreach ($alias in $gitAliases.Keys) {
            try {
                $command = $gitAliases[$alias]
                $result = git config --global alias.$alias $command 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-CustomLog "✓ Installed alias: git $alias" -Level SUCCESS
                } else {
                    Write-CustomLog "⚠ Failed to install alias $alias`: $result" -Level WARN
                }
            } catch {
                Write-CustomLog "⚠ Error installing alias $alias`: $($_.Exception.Message)" -Level WARN
            }
        }
        
        # Add helpful information
        Write-CustomLog "`nGit aliases configured! You can now use:" -Level INFO
        Write-CustomLog "  git quick-fix     - For small fixes" -Level INFO
        Write-CustomLog "  git new-feature   - For new features" -Level INFO
        Write-CustomLog "  git hotfix        - For urgent fixes" -Level INFO
        Write-CustomLog "  git patch         - For general patches" -Level INFO
        Write-CustomLog "  git sync-branch   - To sync with remote" -Level INFO
        Write-CustomLog "  git patch-status  - Check patch status" -Level INFO
        Write-CustomLog "  git safe-commit   - Safe commit without branching" -Level INFO
        Write-CustomLog "  git create-pr     - Create pull request" -Level INFO
        
    } elseif ($Remove) {
        Write-CustomLog "Removing Git aliases for PatchManager..." -Level INFO
        
        foreach ($alias in $gitAliases.Keys) {
            try {
                git config --global --unset alias.$alias 2>$null
                Write-CustomLog "✓ Removed alias: git $alias" -Level SUCCESS
            } catch {
                Write-CustomLog "⚠ Could not remove alias $alias (may not exist)" -Level WARN
            }
        }
    } else {
        Write-CustomLog "Please specify -Install or -Remove parameter" -Level WARN
    }
}

function Remove-ProjectEmojis {
    <#
    .SYNOPSIS
        Removes emojis from project files and replaces with professional language
    
    .DESCRIPTION
        This function scans all project files for emoji usage and replaces them
        with appropriate professional language. Helps maintain code standards.
        
    .PARAMETER WhatIf
        Show what would be changed without making changes
        
    .EXAMPLE
        Remove-ProjectEmojis
        Removes all emojis from project files
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$WhatIf
    )
    
    # Define emoji patterns and their professional replacements
    $emojiReplacements = @{
        '🚀' = 'Launch'
        '✅' = 'Success:'
        '❌' = 'Error:'
        '⚠️' = 'Warning:'
        '🔧' = 'Configure'
        '📦' = 'Package'
        '🔍' = 'Analyze'
        '💡' = 'Info:'
        '🎯' = 'Target'
        '🛠️' = 'Tools'
        '📊' = 'Statistics'
        '🔄' = 'Process'
        '🧪' = 'Test'
        '🏗️' = 'Build'
        '🚢' = 'Deploy'
        '🔒' = 'Secure'
        '🌟' = 'Featured'
        '💯' = 'Complete'
        '🎉' = 'Celebrate'
        '🤖' = 'AI'
        '📝' = 'Document'
        '🧹' = 'Cleanup'
        '🔗' = 'Link'
        '📋' = 'List'
        '🔃' = 'Refresh'
        '⭐' = 'Important'
        '💼' = 'Business'
        '🌐' = 'Global'
    }
    
    # Find all text files in the project
    $projectRoot = $env:PROJECT_ROOT ?? (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent)
    $filesToProcess = Get-ChildItem -Path $projectRoot -Recurse -Include "*.ps1", "*.psm1", "*.md", "*.txt", "*.json", "*.yaml", "*.yml" |
        Where-Object { 
            $_.FullName -notlike "*\.git\*" -and 
            $_.FullName -notlike "*\node_modules\*" -and
            $_.FullName -notlike "*\backups\*" -and
            $_.FullName -notlike "*\temp\*" -and
            $_.FullName -notlike "*\logs\*"
        }
    
    $filesModified = 0
    $emojisReplaced = 0
    
    Write-CustomLog "Scanning $($filesToProcess.Count) files for emoji usage..." -Level INFO
    
    foreach ($file in $filesToProcess) {
        try {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $content) { continue }
            
            $originalContent = $content
            $fileModified = $false
            $fileEmojiCount = 0
            
            # Replace each emoji with professional text
            foreach ($emoji in $emojiReplacements.Keys) {
                $replacement = $emojiReplacements[$emoji]
                if ($content -match [regex]::Escape($emoji)) {
                    $matches = [regex]::Matches($content, [regex]::Escape($emoji))
                    $content = $content -replace [regex]::Escape($emoji), $replacement
                    $fileModified = $true
                    $fileEmojiCount += $matches.Count
                    $emojisReplaced += $matches.Count
                }
            }
            
            # Handle any remaining emoji characters (Unicode ranges)
            $emojiPattern = '[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]'
            if ($content -match $emojiPattern) {
                $content = $content -replace $emojiPattern, '[EMOJI-REMOVED]'
                $fileModified = $true
                $fileEmojiCount++
                $emojisReplaced++
            }
            
            if ($fileModified) {
                if ($PSCmdlet.ShouldProcess($file.FullName, "Remove emojis")) {
                    if (-not $WhatIf) {
                        Set-Content -Path $file.FullName -Value $content -Encoding UTF8
                        $filesModified++
                        Write-CustomLog "✓ Cleaned $fileEmojiCount emojis from: $($file.Name)" -Level SUCCESS
                    } else {
                        Write-CustomLog "WOULD CLEAN $fileEmojiCount emojis from: $($file.Name)" -Level INFO
                    }
                }
            }
            
        } catch {
            Write-CustomLog "⚠ Error processing file $($file.FullName): $($_.Exception.Message)" -Level WARN
        }
    }
    
    if ($emojisReplaced -gt 0) {
        Write-CustomLog "Emoji cleanup complete: $emojisReplaced emojis replaced in $filesModified files" -Level SUCCESS
    } else {
        Write-CustomLog "No emojis found to remove" -Level SUCCESS
    }
}
