#Requires -Version 7.0

<#
.SYNOPSIS
    Sets up the Claude Requirements Gathering System for AitherZero.

.DESCRIPTION
    This function installs and configures the Claude Requirements Gathering System,
    which provides an intelligent requirements gathering process for Claude Code.
    It creates the necessary directory structure, command definitions, and integrates
    with the AitherZero project structure.

.PARAMETER ProjectRoot
    The root directory of the AitherZero project. Defaults to auto-detection.

.PARAMETER ClaudeCommandsPath
    Path where Claude commands should be installed. Defaults to .claude/commands
    in the project root.

.PARAMETER Force
    Force reinstallation even if the requirements system already exists.

.PARAMETER WhatIf
    Show what would be installed without actually installing anything.

.EXAMPLE
    Install-ClaudeRequirementsSystem

    Sets up the Claude Requirements System in the current project.

.EXAMPLE
    Install-ClaudeRequirementsSystem -Force

    Reinstalls the Claude Requirements System, overwriting existing files.

.NOTES
    This function is part of the DevEnvironment module and integrates with
    the AitherZero automation framework.
#>

function Install-ClaudeRequirementsSystem {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string]$ProjectRoot,

        [Parameter()]
        [string]$ClaudeCommandsPath,

        [Parameter()]
        [switch]$Force
    )

    begin {
        # Use shared utility for project root detection
        if (-not $ProjectRoot) {
            . "$PSScriptRoot/../../../shared/Find-ProjectRoot.ps1"
            $ProjectRoot = Find-ProjectRoot
        }

        Write-CustomLog -Message "=== Claude Requirements System Installation ===" -Level "INFO"
        Write-CustomLog -Message "Project Root: $ProjectRoot" -Level "INFO"

        # Set default Claude commands path
        if (-not $ClaudeCommandsPath) {
            $ClaudeCommandsPath = Join-Path $ProjectRoot ".claude" "commands"
        }

        # Define source and destination paths
        $sourcePath = Join-Path $ProjectRoot "claude-requirements"
        $commandsSource = Join-Path $sourcePath "commands"
    }

    process {
        try {
            # Check if source exists
            if (-not (Test-Path $sourcePath)) {
                Write-CustomLog -Message "❌ Claude Requirements source not found at: $sourcePath" -Level "ERROR"
                Write-CustomLog -Message "Please ensure claude-requirements directory exists in the project root" -Level "INFO"
                throw "Claude Requirements source directory not found"
            }

            # Check if already installed
            $isInstalled = Test-Path $ClaudeCommandsPath
            if ($isInstalled -and -not $Force) {
                Write-CustomLog -Message "✅ Claude Requirements System already installed" -Level "SUCCESS"
                Write-CustomLog -Message "Use -Force to reinstall" -Level "INFO"
                return
            }

            if ($PSCmdlet.ShouldProcess("Claude Requirements System", "Install")) {
                # Create .claude/commands directory
                Write-CustomLog -Message "📁 Creating Claude commands directory..." -Level "INFO"
                if (-not (Test-Path $ClaudeCommandsPath)) {
                    New-Item -ItemType Directory -Path $ClaudeCommandsPath -Force | Out-Null
                }

                # Copy command definitions
                Write-CustomLog -Message "📋 Installing command definitions..." -Level "INFO"
                $commandFiles = Get-ChildItem -Path $commandsSource -Filter "*.md" -File

                foreach ($file in $commandFiles) {
                    $destFile = Join-Path $ClaudeCommandsPath $file.Name

                    if ($WhatIf) {
                        Write-CustomLog -Message "[WHATIF] Would copy $($file.Name) to $destFile" -Level "INFO"
                    } else {
                        Copy-Item -Path $file.FullName -Destination $destFile -Force
                        Write-CustomLog -Message "✅ Installed: $($file.Name)" -Level "SUCCESS"
                    }
                }

                # Create .claude directory structure if needed
                $claudeDir = Join-Path $ProjectRoot ".claude"
                if (-not (Test-Path $claudeDir)) {
                    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
                }

                # Create a requirements system configuration
                $configPath = Join-Path $claudeDir "requirements-config.json"
                $config = @{
                    version = "1.0.0"
                    installedDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    requirementsPath = Join-Path $ProjectRoot "claude-requirements" "requirements"
                    commands = @{
                        start = "/requirements-start"
                        status = "/requirements-status"
                        current = "/requirements-current"
                        end = "/requirements-end"
                        list = "/requirements-list"
                        remind = "/remind"
                    }
                }

                if (-not $WhatIf) {
                    $config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Encoding UTF8
                    Write-CustomLog -Message "✅ Created configuration file" -Level "SUCCESS"
                }

                # Add to .gitignore if not already present
                $gitignorePath = Join-Path $ProjectRoot ".gitignore"
                if (Test-Path $gitignorePath) {
                    $gitignoreContent = Get-Content $gitignorePath -Raw
                    $requiredEntries = @(
                        ".claude/",
                        "claude-requirements/requirements/*",
                        "!claude-requirements/requirements/index.md",
                        "!claude-requirements/requirements/.current-requirement"
                    )

                    $entriesToAdd = @()
                    foreach ($entry in $requiredEntries) {
                        if ($gitignoreContent -notmatch [regex]::Escape($entry)) {
                            $entriesToAdd += $entry
                        }
                    }

                    if ($entriesToAdd.Count -gt 0 -and -not $WhatIf) {
                        Add-Content -Path $gitignorePath -Value "`n# Claude Requirements System`n$($entriesToAdd -join "`n")"
                        Write-CustomLog -Message "✅ Updated .gitignore" -Level "SUCCESS"
                    }
                }

                Write-CustomLog -Message "✅ Claude Requirements System installed successfully!" -Level "SUCCESS"
                Write-CustomLog -Message "" -Level "INFO"
                Write-CustomLog -Message "Available commands:" -Level "INFO"
                Write-CustomLog -Message "  /requirements-start   - Start gathering requirements" -Level "INFO"
                Write-CustomLog -Message "  /requirements-status  - Check progress" -Level "INFO"
                Write-CustomLog -Message "  /requirements-current - View current requirement" -Level "INFO"
                Write-CustomLog -Message "  /requirements-end     - End requirement gathering" -Level "INFO"
                Write-CustomLog -Message "  /requirements-list    - List all requirements" -Level "INFO"
                Write-CustomLog -Message "  /remind              - Remind AI of rules" -Level "INFO"
            }

        } catch {
            Write-CustomLog -Message "❌ Failed to install Claude Requirements System: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}

# Companion function to verify installation
function Test-ClaudeRequirementsSystem {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ProjectRoot
    )

    if (-not $ProjectRoot) {
        . "$PSScriptRoot/../../../shared/Find-ProjectRoot.ps1"
        $ProjectRoot = Find-ProjectRoot
    }

    $claudeCommandsPath = Join-Path $ProjectRoot ".claude" "commands"
    $configPath = Join-Path $ProjectRoot ".claude" "requirements-config.json"

    $isInstalled = (Test-Path $claudeCommandsPath) -and (Test-Path $configPath)

    if ($isInstalled) {
        Write-CustomLog -Message "✅ Claude Requirements System is installed" -Level "SUCCESS"

        # Check command files
        $expectedCommands = @(
            "requirements-start.md",
            "requirements-status.md",
            "requirements-current.md",
            "requirements-end.md",
            "requirements-list.md",
            "requirements-remind.md"
        )

        $missingCommands = @()
        foreach ($cmd in $expectedCommands) {
            if (-not (Test-Path (Join-Path $claudeCommandsPath $cmd))) {
                $missingCommands += $cmd
            }
        }

        if ($missingCommands.Count -gt 0) {
            Write-CustomLog -Message "⚠️ Missing command files: $($missingCommands -join ', ')" -Level "WARN"
            return $false
        }

        return $true
    } else {
        Write-CustomLog -Message "❌ Claude Requirements System is not installed" -Level "WARN"
        Write-CustomLog -Message "Run Install-ClaudeRequirementsSystem to set it up" -Level "INFO"
        return $false
    }
}
