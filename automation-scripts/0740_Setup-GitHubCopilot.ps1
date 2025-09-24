#!/usr/bin/env pwsh
#requires -version 7

<#
.SYNOPSIS
    Setup and configure GitHub Copilot for AitherZero development

.DESCRIPTION
    Installs GitHub Copilot CLI, configures authentication, sets up aliases,
    and integrates with AitherZero workflows for optimal AI-assisted development.

.PARAMETER InstallCLI
    Install GitHub Copilot CLI tool

.PARAMETER ConfigureAuth
    Setup GitHub authentication for Copilot

.PARAMETER CreateAliases
    Create helpful Copilot aliases for AitherZero development

.PARAMETER ValidateOnly
    Only validate existing Copilot configuration

.EXAMPLE
    ./0740_Setup-GitHubCopilot.ps1 -InstallCLI -ConfigureAuth
    
.EXAMPLE
    ./0740_Setup-GitHubCopilot.ps1 -ValidateOnly
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$InstallCLI,
    [switch]$ConfigureAuth,
    [switch]$CreateAliases,
    [switch]$ValidateOnly
)

#region Metadata
$script:Stage = "DevelopmentTools"
$script:Dependencies = @('0001', '0200')
$script:Tags = @('github', 'copilot', 'ai', 'cli', 'development')
$script:Condition = '$true'
$script:Platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
#endregion

#region Module Imports
$projectRoot = Split-Path $PSScriptRoot -Parent
$modulePaths = @(
    "$projectRoot/domains/utilities/Logging.psm1"
    "$projectRoot/domains/configuration/Configuration.psm1"
)

foreach ($modulePath in $modulePaths) {
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force
    }
}
#endregion

function Write-CopilotLog {
    param([string]$Message, [string]$Level = 'Information')
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level -Source "GitHubCopilot"
    } else {
        Write-Host "[$Level] GitHub Copilot: $Message"
    }
}

function Test-GitHubCLI {
    <#
    .SYNOPSIS
        Check if GitHub CLI is installed and authenticated
    #>
    [CmdletBinding()]
    param()
    
    try {
        $ghVersion = & gh --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-CopilotLog "GitHub CLI is installed: $($ghVersion[0])" -Level Information
            
            # Check authentication
            $authStatus = & gh auth status 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-CopilotLog "GitHub CLI is authenticated" -Level Information
                return $true
            } else {
                Write-CopilotLog "GitHub CLI is not authenticated" -Level Warning
                return $false
            }
        } else {
            Write-CopilotLog "GitHub CLI is not installed" -Level Warning
            return $false
        }
    }
    catch {
        Write-CopilotLog "Failed to check GitHub CLI: $_" -Level Error
        return $false
    }
}

function Install-GitHubCLI {
    <#
    .SYNOPSIS
        Install GitHub CLI based on platform
    #>
    [CmdletBinding()]
    param()
    
    Write-CopilotLog "Installing GitHub CLI for $script:Platform" -Level Information
    
    try {
        switch ($script:Platform) {
            'Windows' {
                if (Get-Command winget -ErrorAction SilentlyContinue) {
                    Write-CopilotLog "Installing GitHub CLI via winget" -Level Information
                    & winget install --id GitHub.cli
                } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
                    Write-CopilotLog "Installing GitHub CLI via Chocolatey" -Level Information
                    & choco install gh -y
                } else {
                    Write-CopilotLog "Please install GitHub CLI manually from https://cli.github.com/" -Level Warning
                    return $false
                }
            }
            'Linux' {
                if (Get-Command apt -ErrorAction SilentlyContinue) {
                    Write-CopilotLog "Installing GitHub CLI via apt" -Level Information
                    & sudo apt update
                    & sudo apt install gh -y
                } elseif (Get-Command yum -ErrorAction SilentlyContinue) {
                    Write-CopilotLog "Installing GitHub CLI via yum" -Level Information
                    & sudo yum install gh -y
                } elseif (Get-Command snap -ErrorAction SilentlyContinue) {
                    Write-CopilotLog "Installing GitHub CLI via snap" -Level Information
                    & sudo snap install gh
                } else {
                    Write-CopilotLog "Please install GitHub CLI manually from https://cli.github.com/" -Level Warning
                    return $false
                }
            }
            'macOS' {
                if (Get-Command brew -ErrorAction SilentlyContinue) {
                    Write-CopilotLog "Installing GitHub CLI via Homebrew" -Level Information
                    & brew install gh
                } else {
                    Write-CopilotLog "Please install Homebrew first, then run: brew install gh" -Level Warning
                    return $false
                }
            }
            default {
                Write-CopilotLog "Unsupported platform: $script:Platform" -Level Error
                return $false
            }
        }
        
        # Verify installation
        Start-Sleep -Seconds 2
        return Test-GitHubCLI
    }
    catch {
        Write-CopilotLog "Failed to install GitHub CLI: $_" -Level Error
        return $false
    }
}

function Install-CopilotCLI {
    <#
    .SYNOPSIS
        Install GitHub Copilot CLI extension
    #>
    [CmdletBinding()]
    param()
    
    Write-CopilotLog "Installing GitHub Copilot CLI extension" -Level Information
    
    try {
        # Install Copilot CLI extension
        & gh extension install github/gh-copilot
        
        if ($LASTEXITCODE -eq 0) {
            Write-CopilotLog "GitHub Copilot CLI extension installed successfully" -Level Information
            return $true
        } else {
            Write-CopilotLog "Failed to install GitHub Copilot CLI extension" -Level Error
            return $false
        }
    }
    catch {
        Write-CopilotLog "Error installing Copilot CLI: $_" -Level Error
        return $false
    }
}

function Test-CopilotCLI {
    <#
    .SYNOPSIS
        Test GitHub Copilot CLI functionality
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Test if Copilot CLI is available
        $result = & gh copilot --help 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-CopilotLog "GitHub Copilot CLI is working" -Level Information
            return $true
        } else {
            Write-CopilotLog "GitHub Copilot CLI is not available" -Level Warning
            return $false
        }
    }
    catch {
        Write-CopilotLog "Failed to test Copilot CLI: $_" -Level Error
        return $false
    }
}

function Setup-CopilotAliases {
    <#
    .SYNOPSIS
        Create helpful aliases for GitHub Copilot CLI
    #>
    [CmdletBinding()]
    param()
    
    Write-CopilotLog "Setting up GitHub Copilot aliases" -Level Information
    
    try {
        # Create aliases for common AitherZero tasks
        $aliases = @{
            'copilot-explain' = 'gh copilot explain'
            'copilot-suggest' = 'gh copilot suggest'
            'az-copilot-powershell' = 'gh copilot suggest -t shell "PowerShell command to"'
            'az-copilot-git' = 'gh copilot suggest -t git'
            'az-copilot-fix' = 'gh copilot suggest -t shell "Fix this AitherZero issue:"'
        }
        
        # Create PowerShell profile function for aliases
        $profileContent = @"
# AitherZero GitHub Copilot Aliases
function copilot-explain { gh copilot explain `$args }
function copilot-suggest { gh copilot suggest `$args }
function az-copilot-powershell { gh copilot suggest -t shell "PowerShell command to `$(`$args -join ' ')" }
function az-copilot-git { gh copilot suggest -t git `$args }
function az-copilot-fix { gh copilot suggest -t shell "Fix this AitherZero issue: `$(`$args -join ' ')" }

# AitherZero-specific Copilot helpers
function az-copilot-script { 
    param([string]`$Description)
    gh copilot suggest -t shell "Create AitherZero automation script that `$Description"
}

function az-copilot-module {
    param([string]`$Description)  
    gh copilot suggest -t shell "Create AitherZero PowerShell module that `$Description"
}

function az-copilot-test {
    param([string]`$FilePath)
    gh copilot suggest -t shell "Generate Pester tests for AitherZero file `$FilePath"
}
"@
        
        # Add to PowerShell profile
        $profilePath = $PROFILE.CurrentUserAllHosts
        if (-not (Test-Path (Split-Path $profilePath -Parent))) {
            New-Item -Path (Split-Path $profilePath -Parent) -ItemType Directory -Force | Out-Null
        }
        
        if (Test-Path $profilePath) {
            $existingContent = Get-Content $profilePath -Raw
            if ($existingContent -notlike "*AitherZero GitHub Copilot Aliases*") {
                Add-Content -Path $profilePath -Value "`n$profileContent"
                Write-CopilotLog "Added Copilot aliases to PowerShell profile" -Level Information
            } else {
                Write-CopilotLog "Copilot aliases already exist in PowerShell profile" -Level Information
            }
        } else {
            Set-Content -Path $profilePath -Value $profileContent
            Write-CopilotLog "Created PowerShell profile with Copilot aliases" -Level Information
        }
        
        return $true
    }
    catch {
        Write-CopilotLog "Failed to setup Copilot aliases: $_" -Level Error
        return $false
    }
}

function New-CopilotConfiguration {
    <#
    .SYNOPSIS
        Create Copilot configuration file for AitherZero
    #>
    [CmdletBinding()]
    param()
    
    Write-CopilotLog "Creating Copilot configuration for AitherZero" -Level Information
    
    try {
        $configDir = "$projectRoot/.copilot"
        if (-not (Test-Path $configDir)) {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
        }
        
        $copilotConfig = @{
            version = "1.0"
            project = @{
                name = "AitherZero"
                type = "powershell-infrastructure"
                description = "Infrastructure automation platform with AI-powered development workflows"
            }
            context = @{
                files = @(
                    ".github/copilot-instructions.md"
                    "README.md"
                    "config.psd1"
                    "config.example.psd1"
                )
                patterns = @(
                    "**/*.ps1"
                    "**/*.psm1" 
                    "**/*.psd1"
                    "automation-scripts/**"
                    "domains/**"
                    "tests/**"
                )
                exclude = @(
                    "logs/**"
                    "backups/**"
                    "archive/**"
                    "*.log"
                )
            }
            suggestions = @{
                powershell = @{
                    enabled = $true
                    style = "aitherzero-standards"
                    patterns = @(
                        "#requires -version 7"
                        "[CmdletBinding()]"
                        "Write-CustomLog"
                        "Export-ModuleMember"
                    )
                }
                infrastructure = @{
                    enabled = $true
                    focus = @("opentofu", "terraform", "automation", "cross-platform")
                }
                testing = @{
                    enabled = $true
                    framework = "pester"
                    coverage = $true
                }
            }
        }
        
        $configPath = "$configDir/config.json"
        $copilotConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
        
        Write-CopilotLog "Created Copilot configuration at $configPath" -Level Information
        return $true
    }
    catch {
        Write-CopilotLog "Failed to create Copilot configuration: $_" -Level Error
        return $false
    }
}

function Test-CopilotIntegration {
    <#
    .SYNOPSIS
        Validate complete GitHub Copilot integration
    #>
    [CmdletBinding()]
    param()
    
    Write-CopilotLog "Validating GitHub Copilot integration" -Level Information
    
    $results = @{
        GitHubCLI = Test-GitHubCLI
        CopilotCLI = Test-CopilotCLI
        Configuration = Test-Path "$projectRoot/.copilot/config.json"
        VSCodeExtensions = Test-Path "$projectRoot/.vscode/extensions.json"
        CopilotInstructions = Test-Path "$projectRoot/.github/copilot-instructions.md"
    }
    
    $allPassed = $true
    foreach ($test in $results.Keys) {
        $status = if ($results[$test]) { "✓ PASS" } else { "✗ FAIL"; $allPassed = $false }
        Write-CopilotLog "$test : $status" -Level Information
    }
    
    if ($allPassed) {
        Write-CopilotLog "All GitHub Copilot integration tests passed" -Level Information
        return $true
    } else {
        Write-CopilotLog "Some GitHub Copilot integration tests failed" -Level Warning
        return $false
    }
}

# Main execution
function Main {
    Write-CopilotLog "Starting GitHub Copilot setup for AitherZero (Platform: $script:Platform)" -Level Information
    
    try {
        if ($ValidateOnly) {
            return Test-CopilotIntegration
        }
        
        $success = $true
        
        # Install GitHub CLI if needed
        if ($InstallCLI) {
            if (-not (Test-GitHubCLI)) {
                $success = $success -and (Install-GitHubCLI)
            }
            
            # Install Copilot CLI extension
            if ($success -and -not (Test-CopilotCLI)) {
                $success = $success -and (Install-CopilotCLI)
            }
        }
        
        # Setup authentication
        if ($ConfigureAuth -and $success) {
            if (-not (Test-GitHubCLI)) {
                Write-CopilotLog "GitHub CLI authentication required. Run: gh auth login" -Level Warning
                Write-CopilotLog "Then run: gh auth refresh -s copilot" -Level Information
            }
        }
        
        # Create aliases
        if ($CreateAliases -and $success) {
            $success = $success -and (Setup-CopilotAliases)
        }
        
        # Create configuration 
        if ($success) {
            $success = $success -and (New-CopilotConfiguration)
        }
        
        # Final validation
        if ($success) {
            $success = Test-CopilotIntegration
        }
        
        if ($success) {
            Write-CopilotLog "GitHub Copilot setup completed successfully" -Level Information
            Write-CopilotLog "Restart your terminal to use the new aliases" -Level Information
        } else {
            Write-CopilotLog "GitHub Copilot setup completed with issues" -Level Warning
        }
        
        return $success
    }
    catch {
        Write-CopilotLog "Failed to setup GitHub Copilot: $_" -Level Error
        return $false
    }
}

# Run main function
if (-not $MyInvocation.ScriptName) {
    # Running interactively
    Main
} else {
    # Running as script
    $result = Main
    exit if ($result) { 0 } else { 1 }
}