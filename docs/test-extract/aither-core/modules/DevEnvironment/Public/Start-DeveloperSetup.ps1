function Start-DeveloperSetup {
    <#
    .SYNOPSIS
        Unified developer setup command for AitherZero development environment
    
    .DESCRIPTION
        One-stop command to set up a complete AitherZero development environment.
        Consolidates all developer setup tasks into a single, streamlined process.
    
    .PARAMETER Profile
        Development profile to install (Quick, Standard, Full, Custom)
    
    .PARAMETER SkipPrerequisites
        Skip prerequisite checks (PowerShell 7, Git, etc.)
    
    .PARAMETER SkipAITools
        Skip AI development tools installation
    
    .PARAMETER SkipVSCode
        Skip VS Code configuration
    
    .PARAMETER SkipGitHooks
        Skip Git hooks installation
    
    .PARAMETER Force
        Force reinstallation of existing components
    
    .EXAMPLE
        Start-DeveloperSetup
        # Interactive setup with all options
    
    .EXAMPLE
        Start-DeveloperSetup -Profile Standard
        # Standard developer setup
    
    .EXAMPLE
        Start-DeveloperSetup -Profile Quick -SkipAITools
        # Quick setup without AI tools
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [ValidateSet('Quick', 'Standard', 'Full', 'Custom')]
        [string]$Profile = 'Standard',
        
        [Parameter()]
        [switch]$SkipPrerequisites,
        
        [Parameter()]
        [switch]$SkipAITools,
        
        [Parameter()]
        [switch]$SkipVSCode,
        
        [Parameter()]
        [switch]$SkipGitHooks,
        
        [Parameter()]
        [switch]$Force
    )
    
    begin {
        # Import required functions
        $requiredFunctions = @(
            'Write-CustomLog',
            'Test-DevEnvironment',
            'Initialize-DevelopmentEnvironment',
            'Install-VSCodeExtensions',
            'Install-PreCommitHook',
            'Get-AIToolsStatus',
            'Install-AITools'
        )
        
        $missingFunctions = $requiredFunctions | Where-Object { 
            -not (Get-Command $_ -ErrorAction SilentlyContinue) 
        }
        
        if ($missingFunctions) {
            Write-Warning "Missing required functions. Attempting to import modules..."
            
            # Try to import DevEnvironment module
            try {
                $projectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
                Import-Module (Join-Path $projectRoot "aither-core/modules/DevEnvironment") -Force
                Import-Module (Join-Path $projectRoot "aither-core/modules/AIToolsIntegration") -Force
            } catch {
                throw "Failed to import required modules: $_"
            }
        }
        
        # Define setup profiles
        $setupProfiles = @{
            Quick = @{
                Name = "Quick Developer Setup"
                Description = "Minimal setup for quick development"
                Prerequisites = $true
                VSCode = $true
                GitHooks = $false
                AITools = $false
                OptionalTools = @()
            }
            Standard = @{
                Name = "Standard Developer Setup"
                Description = "Recommended setup for most developers"
                Prerequisites = $true
                VSCode = $true
                GitHooks = $true
                AITools = $true
                OptionalTools = @('claude-code')
            }
            Full = @{
                Name = "Full Developer Setup"
                Description = "Complete setup with all tools and features"
                Prerequisites = $true
                VSCode = $true
                GitHooks = $true
                AITools = $true
                OptionalTools = @('claude-code', 'gemini-cli', 'continue-dev')
            }
            Custom = @{
                Name = "Custom Developer Setup"
                Description = "Choose individual components to install"
                Prerequisites = $true
                VSCode = $true
                GitHooks = $true
                AITools = $true
                OptionalTools = @()
            }
        }
        
        $selectedProfile = $setupProfiles[$Profile]
        
        Write-Host "`n🚀 AitherZero Developer Setup" -ForegroundColor Cyan
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host "Profile: $($selectedProfile.Name)" -ForegroundColor Green
        Write-Host "Description: $($selectedProfile.Description)" -ForegroundColor Gray
        Write-Host ""
    }
    
    process {
        $setupSteps = @()
        $setupResults = @{
            Success = @()
            Warning = @()
            Error = @()
            Skipped = @()
        }
        
        try {
            # Step 1: Prerequisites Check
            if (-not $SkipPrerequisites -and $selectedProfile.Prerequisites) {
                $setupSteps += @{
                    Name = "Prerequisites Check"
                    Action = {
                        Write-Host "🔍 Checking prerequisites..." -ForegroundColor Cyan
                        
                        $prereqResult = Test-DevEnvironment -ReturnDetails
                        
                        if ($prereqResult.AllTestsPassed) {
                            Write-Host "   ✅ All prerequisites met" -ForegroundColor Green
                            return $true
                        } else {
                            Write-Host "   ⚠️  Some prerequisites missing:" -ForegroundColor Yellow
                            $prereqResult.FailedTests | ForEach-Object {
                                Write-Host "      - $_" -ForegroundColor Yellow
                            }
                            
                            if ($Force) {
                                Write-Host "   ⚡ Force flag set, continuing anyway..." -ForegroundColor Magenta
                                return $true
                            } else {
                                return $false
                            }
                        }
                    }
                }
            }
            
            # Step 2: Core Development Environment
            $setupSteps += @{
                Name = "Core Development Environment"
                Action = {
                    Write-Host "`n🔧 Setting up core development environment..." -ForegroundColor Cyan
                    
                    try {
                        Initialize-DevelopmentEnvironment -Force:$Force
                        Write-Host "   ✅ Core environment configured" -ForegroundColor Green
                        return $true
                    } catch {
                        Write-Host "   ❌ Failed to initialize environment: $_" -ForegroundColor Red
                        return $false
                    }
                }
            }
            
            # Step 3: VS Code Configuration
            if (-not $SkipVSCode -and $selectedProfile.VSCode) {
                $setupSteps += @{
                    Name = "VS Code Configuration"
                    Action = {
                        Write-Host "`n📝 Configuring VS Code..." -ForegroundColor Cyan
                        
                        try {
                            # Update VS Code settings
                            Initialize-VSCodeWorkspace -Force:$Force
                            
                            # Install extensions
                            $extensionResult = Install-VSCodeExtensions -Force:$Force
                            
                            if ($extensionResult.Installed.Count -gt 0) {
                                Write-Host "   ✅ Installed $($extensionResult.Installed.Count) VS Code extensions" -ForegroundColor Green
                            } else {
                                Write-Host "   ✅ VS Code already configured" -ForegroundColor Green
                            }
                            
                            return $true
                        } catch {
                            Write-Host "   ❌ VS Code configuration failed: $_" -ForegroundColor Red
                            return $false
                        }
                    }
                }
            }
            
            # Step 4: Git Hooks
            if (-not $SkipGitHooks -and $selectedProfile.GitHooks) {
                $setupSteps += @{
                    Name = "Git Hooks Installation"
                    Action = {
                        Write-Host "`n🪝 Installing Git hooks..." -ForegroundColor Cyan
                        
                        try {
                            Install-PreCommitHook -Force:$Force
                            Write-Host "   ✅ Git hooks installed" -ForegroundColor Green
                            return $true
                        } catch {
                            Write-Host "   ⚠️  Git hooks installation failed: $_" -ForegroundColor Yellow
                            return $false
                        }
                    }
                }
            }
            
            # Step 5: AI Development Tools
            if (-not $SkipAITools -and $selectedProfile.AITools) {
                $setupSteps += @{
                    Name = "AI Development Tools"
                    Action = {
                        Write-Host "`n🤖 Setting up AI development tools..." -ForegroundColor Cyan
                        
                        try {
                            $aiTools = if ($selectedProfile.OptionalTools) {
                                $selectedProfile.OptionalTools
                            } else {
                                @('claude-code')
                            }
                            
                            foreach ($tool in $aiTools) {
                                Write-Host "   Installing $tool..." -ForegroundColor Gray
                                
                                try {
                                    Install-AITools -Tools @($tool) -Force:$Force
                                    Write-Host "   ✅ $tool installed" -ForegroundColor Green
                                } catch {
                                    Write-Host "   ⚠️  Failed to install $tool : $_" -ForegroundColor Yellow
                                }
                            }
                            
                            return $true
                        } catch {
                            Write-Host "   ❌ AI tools setup failed: $_" -ForegroundColor Red
                            return $false
                        }
                    }
                }
            }
            
            # Step 6: PatchManager Aliases (always install)
            $setupSteps += @{
                Name = "PatchManager Aliases"
                Action = {
                    Write-Host "`n🔧 Setting up PatchManager aliases..." -ForegroundColor Cyan
                    
                    try {
                        Set-PatchManagerAliases
                        Write-Host "   ✅ PatchManager aliases configured" -ForegroundColor Green
                        return $true
                    } catch {
                        Write-Host "   ⚠️  PatchManager aliases failed: $_" -ForegroundColor Yellow
                        return $false
                    }
                }
            }
            
            # Execute setup steps
            foreach ($step in $setupSteps) {
                if ($PSCmdlet.ShouldProcess($step.Name, "Execute setup step")) {
                    $result = & $step.Action
                    
                    if ($result -eq $true) {
                        $setupResults.Success += $step.Name
                    } elseif ($result -eq $false) {
                        $setupResults.Error += $step.Name
                        
                        # Ask to continue on error (unless Force)
                        if (-not $Force) {
                            $continue = Read-Host "`nError occurred. Continue with setup? (Y/N)"
                            if ($continue -ne 'Y') {
                                throw "Setup aborted by user"
                            }
                        }
                    } else {
                        $setupResults.Warning += $step.Name
                    }
                }
            }
            
            # Final setup tasks
            Write-Host "`n📋 Running final setup tasks..." -ForegroundColor Cyan
            
            # Show development tips
            $devTips = @(
                "Use 'Start-AitherZero.ps1 -Setup' for first-time configuration",
                "Run './tests/Run-Tests.ps1' to validate your environment",
                "Use 'New-Patch' from PatchManager for Git workflows",
                "Check './docs/README.md' for documentation",
                "Join our Discord for support: https://discord.gg/aitherzero"
            )
            
            Write-Host "`n💡 Developer Tips:" -ForegroundColor Yellow
            foreach ($tip in $devTips) {
                Write-Host "   • $tip" -ForegroundColor Gray
            }
            
        } catch {
            Write-Error "Developer setup failed: $_"
            throw
        }
    }
    
    end {
        # Display summary
        Write-Host "`n📊 Setup Summary" -ForegroundColor Cyan
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        
        if ($setupResults.Success.Count -gt 0) {
            Write-Host "✅ Successful ($($setupResults.Success.Count)):" -ForegroundColor Green
            $setupResults.Success | ForEach-Object {
                Write-Host "   • $_" -ForegroundColor Green
            }
        }
        
        if ($setupResults.Warning.Count -gt 0) {
            Write-Host "`n⚠️  Warnings ($($setupResults.Warning.Count)):" -ForegroundColor Yellow
            $setupResults.Warning | ForEach-Object {
                Write-Host "   • $_" -ForegroundColor Yellow
            }
        }
        
        if ($setupResults.Error.Count -gt 0) {
            Write-Host "`n❌ Errors ($($setupResults.Error.Count)):" -ForegroundColor Red
            $setupResults.Error | ForEach-Object {
                Write-Host "   • $_" -ForegroundColor Red
            }
        }
        
        # Overall status
        if ($setupResults.Error.Count -eq 0) {
            Write-Host "`n✅ Developer setup completed successfully!" -ForegroundColor Green
            Write-Host "🚀 You're ready to start developing with AitherZero!" -ForegroundColor Cyan
        } else {
            Write-Host "`n⚠️  Developer setup completed with errors" -ForegroundColor Yellow
            Write-Host "Please address the errors above before continuing." -ForegroundColor Yellow
        }
        
        # Return results object
        return $setupResults
    }
}