#Requires -Version 7.0

<#
.SYNOPSIS
    Initializes and configures VS Code workspace for AitherZero development.

.DESCRIPTION
    This function sets up a complete VS Code workspace environment including:
    - PowerShell-specific settings configuration
    - Recommended extensions installation
    - Debug configurations for PowerShell scripts and modules
    - Integrated terminal profiles
    - Task configurations aligned with project scripts
    - Multi-root workspace file creation
    - Cross-platform support for VS Code, VS Code Insiders, and VSCodium

.PARAMETER WorkspacePath
    Path to the workspace root. Defaults to project root detection.

.PARAMETER InstallExtensions
    Automatically install recommended extensions if VS Code CLI is available.

.PARAMETER UpdateSettings
    Update existing settings.json with recommended configurations.

.PARAMETER CreateWorkspaceFile
    Create a .code-workspace file for multi-root workspace support.

.PARAMETER VSCodeExecutable
    Specify VS Code executable (code, code-insiders, codium). Auto-detected if not specified.

.PARAMETER Force
    Overwrite existing configurations instead of merging.

.PARAMETER WhatIf
    Show what would be configured without making changes.

.EXAMPLE
    Initialize-VSCodeWorkspace
    
    Sets up complete VS Code workspace with all recommended configurations.

.EXAMPLE
    Initialize-VSCodeWorkspace -InstallExtensions -CreateWorkspaceFile
    
    Sets up workspace, installs extensions, and creates workspace file.

.EXAMPLE
    Initialize-VSCodeWorkspace -VSCodeExecutable "code-insiders" -Force
    
    Forces setup using VS Code Insiders, overwriting existing configs.

.NOTES
    This function is part of the DevEnvironment module and provides comprehensive
    VS Code integration for the AitherZero project.
#>

function Initialize-VSCodeWorkspace {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string]$WorkspacePath,
        
        [Parameter()]
        [switch]$InstallExtensions,
        
        [Parameter()]
        [switch]$UpdateSettings = $true,
        
        [Parameter()]
        [switch]$CreateWorkspaceFile,
        
        [Parameter()]
        [ValidateSet('code', 'code-insiders', 'codium')]
        [string]$VSCodeExecutable,
        
        [Parameter()]
        [switch]$Force
    )

    begin {
        # Use shared utility for project root detection
        if (-not $WorkspacePath) {
            . "$PSScriptRoot/../../../shared/Find-ProjectRoot.ps1"
            $WorkspacePath = Find-ProjectRoot
        }
        
        Write-CustomLog -Message "=== Initializing VS Code Workspace ===" -Level "INFO"
        Write-CustomLog -Message "Workspace Path: $WorkspacePath" -Level "INFO"
        
        # Detect VS Code executable if not specified
        if (-not $VSCodeExecutable) {
            $VSCodeExecutable = Find-VSCodeExecutable
            if (-not $VSCodeExecutable) {
                Write-CustomLog -Message "VS Code executable not found. Some features will be limited." -Level "WARN"
            } else {
                Write-CustomLog -Message "Detected VS Code: $VSCodeExecutable" -Level "INFO"
            }
        }
        
        # Ensure .vscode directory exists
        $vscodeDir = Join-Path $WorkspacePath ".vscode"
        if (-not (Test-Path $vscodeDir)) {
            if ($PSCmdlet.ShouldProcess($vscodeDir, "Create directory")) {
                New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null
                Write-CustomLog -Message "Created .vscode directory" -Level "SUCCESS"
            }
        }
    }

    process {
        try {
            $setupTasks = @()
            
            # Task 1: Configure VS Code Settings
            if ($UpdateSettings) {
                $setupTasks += @{
                    Name = "VS Code Settings"
                    Action = {
                        $settingsPath = Join-Path $vscodeDir "settings.json"
                        $settings = Get-RecommendedVSCodeSettings
                        
                        if ($Force -or -not (Test-Path $settingsPath)) {
                            if ($PSCmdlet.ShouldProcess($settingsPath, "Create settings.json")) {
                                $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding UTF8
                                Write-CustomLog -Message "Created VS Code settings.json" -Level "SUCCESS"
                            }
                        } else {
                            if ($PSCmdlet.ShouldProcess($settingsPath, "Update settings.json")) {
                                # Create a temporary file with the recommended settings for merging
                                $tempSettingsFile = [System.IO.Path]::GetTempFileName() + ".json"
                                $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $tempSettingsFile -Encoding UTF8
                                
                                try {
                                    Update-VSCodeSettings -DefaultSettingsPath $tempSettingsFile -UserSettingsPath $settingsPath -BackupUserSettings
                                    Write-CustomLog -Message "Updated VS Code settings.json" -Level "SUCCESS"
                                } finally {
                                    Remove-Item $tempSettingsFile -ErrorAction SilentlyContinue
                                }
                            }
                        }
                    }
                }
            }
            
            # Task 2: Configure Recommended Extensions
            $setupTasks += @{
                Name = "Recommended Extensions"
                Action = {
                    $extensionsPath = Join-Path $vscodeDir "extensions.json"
                    $extensions = Get-RecommendedVSCodeExtensions
                    
                    if ($PSCmdlet.ShouldProcess($extensionsPath, "Create extensions.json")) {
                        $extensions | ConvertTo-Json -Depth 10 | Set-Content -Path $extensionsPath -Encoding UTF8
                        Write-CustomLog -Message "Created VS Code extensions.json" -Level "SUCCESS"
                    }
                    
                    if ($InstallExtensions -and $VSCodeExecutable) {
                        Install-VSCodeExtensions -VSCodeExecutable $VSCodeExecutable -ExtensionsPath $extensionsPath -WhatIf:$WhatIfPreference
                    }
                }
            }
            
            # Task 3: Configure Debug Configurations
            $setupTasks += @{
                Name = "Debug Configurations"
                Action = {
                    $launchPath = Join-Path $vscodeDir "launch.json"
                    $launch = Get-VSCodeLaunchConfiguration
                    
                    if ($Force -or -not (Test-Path $launchPath)) {
                        if ($PSCmdlet.ShouldProcess($launchPath, "Create launch.json")) {
                            $launch | ConvertTo-Json -Depth 10 | Set-Content -Path $launchPath -Encoding UTF8
                            Write-CustomLog -Message "Created VS Code launch.json" -Level "SUCCESS"
                        }
                    }
                }
            }
            
            # Task 4: Update VS Code Tasks (merge with existing)
            $setupTasks += @{
                Name = "Task Integration"
                Action = {
                    $tasksPath = Join-Path $vscodeDir "tasks.json"
                    if (Test-Path $tasksPath) {
                        Write-CustomLog -Message "VS Code tasks.json already exists, preserving current tasks" -Level "INFO"
                    } else {
                        $tasks = Get-VSCodeTasksTemplate
                        if ($PSCmdlet.ShouldProcess($tasksPath, "Create tasks.json")) {
                            $tasks | ConvertTo-Json -Depth 10 | Set-Content -Path $tasksPath -Encoding UTF8
                            Write-CustomLog -Message "Created VS Code tasks.json template" -Level "SUCCESS"
                        }
                    }
                }
            }
            
            # Task 5: Create Workspace File
            if ($CreateWorkspaceFile) {
                $setupTasks += @{
                    Name = "Workspace File"
                    Action = {
                        $workspaceFile = Join-Path $WorkspacePath "AitherZero.code-workspace"
                        if ($PSCmdlet.ShouldProcess($workspaceFile, "Create workspace file")) {
                            New-VSCodeWorkspaceFile -WorkspacePath $WorkspacePath -OutputPath $workspaceFile
                            Write-CustomLog -Message "Created workspace file: $workspaceFile" -Level "SUCCESS"
                        }
                    }
                }
            }
            
            # Execute all setup tasks
            foreach ($task in $setupTasks) {
                try {
                    Write-CustomLog -Message "Configuring $($task.Name)..." -Level "INFO"
                    & $task.Action
                } catch {
                    Write-CustomLog -Message "Failed to configure $($task.Name): $($_.Exception.Message)" -Level "ERROR"
                    if (-not $Force) { throw }
                }
            }
            
            # Validate setup
            if (-not $WhatIfPreference) {
                $validation = Test-VSCodeIntegration -WorkspacePath $WorkspacePath
                if ($validation.IsValid) {
                    Write-CustomLog -Message "VS Code workspace setup completed successfully!" -Level "SUCCESS"
                } else {
                    Write-CustomLog -Message "VS Code workspace setup completed with warnings" -Level "WARN"
                    foreach ($issue in $validation.Issues) {
                        Write-CustomLog -Message "  - $issue" -Level "WARN"
                    }
                }
            }
            
        } catch {
            Write-CustomLog -Message "Failed to initialize VS Code workspace: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
    
    end {
        if (-not $WhatIfPreference) {
            Write-CustomLog -Message "" -Level "INFO"
            Write-CustomLog -Message "Next steps:" -Level "INFO"
            Write-CustomLog -Message "1. Open VS Code in the workspace: $VSCodeExecutable $WorkspacePath" -Level "INFO"
            Write-CustomLog -Message "2. Install recommended extensions when prompted" -Level "INFO"
            Write-CustomLog -Message "3. Reload window to apply all settings" -Level "INFO"
            
            if ($CreateWorkspaceFile) {
                Write-CustomLog -Message "4. Open the workspace file for multi-root support" -Level "INFO"
            }
        }
    }
}

# Helper function to find VS Code executable
function Find-VSCodeExecutable {
    [CmdletBinding()]
    param()
    
    $executables = @('code', 'code-insiders', 'codium')
    
    foreach ($exe in $executables) {
        if (Get-Command $exe -ErrorAction SilentlyContinue) {
            return $exe
        }
    }
    
    # Windows-specific paths
    if ($IsWindows) {
        $windowsPaths = @(
            "${env:LOCALAPPDATA}\Programs\Microsoft VS Code\bin\code.cmd",
            "${env:LOCALAPPDATA}\Programs\Microsoft VS Code Insiders\bin\code-insiders.cmd",
            "${env:ProgramFiles}\Microsoft VS Code\bin\code.cmd",
            "${env:ProgramFiles}\Microsoft VS Code Insiders\bin\code-insiders.cmd"
        )
        
        foreach ($path in $windowsPaths) {
            if (Test-Path $path) {
                return $path
            }
        }
    }
    
    return $null
}

# Helper function to get recommended VS Code settings
function Get-RecommendedVSCodeSettings {
    [CmdletBinding()]
    param()
    
    return @{
        # PowerShell settings - Enhanced
        "powershell.powerShellDefaultVersion" = "PowerShell 7"
        "powershell.integratedConsole.suppressStartupBanner" = $true
        "powershell.codeFormatting.preset" = "OTBS"
        "powershell.codeFormatting.openBraceOnSameLine" = $true
        "powershell.codeFormatting.newLineAfterOpenBrace" = $true
        "powershell.codeFormatting.newLineAfterCloseBrace" = $true
        "powershell.codeFormatting.whitespaceBeforeOpenBrace" = $true
        "powershell.codeFormatting.whitespaceBeforeOpenParen" = $true
        "powershell.codeFormatting.whitespaceAroundOperator" = $true
        "powershell.codeFormatting.whitespaceAfterSeparator" = $true
        "powershell.codeFormatting.autoCorrectAliases" = $true
        "powershell.pester.useLegacyCodeLens" = $false
        "powershell.pester.outputVerbosity" = "Detailed"
        "powershell.scriptAnalysis.enable" = $true
        "powershell.scriptAnalysis.settingsPath" = "PSScriptAnalyzerSettings.psd1"
        "powershell.developer.featureFlags" = @("PSReadLinePrompt")
        
        # Terminal settings - Enhanced with multiple profiles
        "terminal.integrated.defaultProfile.windows" = "PowerShell 7"
        "terminal.integrated.defaultProfile.linux" = "pwsh"
        "terminal.integrated.defaultProfile.osx" = "pwsh"
        "terminal.integrated.profiles.windows" = @{
            "PowerShell 7" = @{
                "path" = "pwsh.exe"
                "args" = @("-NoProfile")
                "icon" = "terminal-powershell"
            }
            "PowerShell 7 (Profile)" = @{
                "path" = "pwsh.exe"
                "icon" = "terminal-powershell"
            }
            "Windows PowerShell" = @{
                "path" = "powershell.exe"
                "args" = @("-NoProfile")
                "icon" = "terminal-powershell"
            }
        }
        "terminal.integrated.profiles.linux" = @{
            "PowerShell" = @{
                "path" = "pwsh"
                "icon" = "terminal-powershell"
            }
        }
        "terminal.integrated.profiles.osx" = @{
            "PowerShell" = @{
                "path" = "pwsh"
                "icon" = "terminal-powershell"
            }
        }
        "terminal.integrated.fontSize" = 14
        "terminal.integrated.fontFamily" = "'Cascadia Code', 'Fira Code', 'JetBrains Mono', 'Source Code Pro', monospace"
        "terminal.integrated.cursorBlinking" = $true
        "terminal.integrated.cursorStyle" = "line"
        
        # Editor settings - Enhanced with modern features
        "editor.formatOnSave" = $true
        "editor.formatOnPaste" = $false
        "editor.tabSize" = 4
        "editor.insertSpaces" = $true
        "editor.rulers" = @(80, 120, 150)
        "editor.wordWrap" = "off"
        "editor.minimap.enabled" = $true
        "editor.minimap.size" = "proportional"
        "editor.bracketPairColorization.enabled" = $true
        "editor.guides.bracketPairs" = "active"
        "editor.inlineSuggest.enabled" = $true
        "editor.suggestSelection" = "first"
        "editor.acceptSuggestionOnCommitCharacter" = $false
        "editor.acceptSuggestionOnEnter" = "on"
        "editor.semanticHighlighting.enabled" = $true
        "editor.fontFamily" = "'Cascadia Code', 'Fira Code', 'JetBrains Mono', 'Source Code Pro', monospace"
        "editor.fontLigatures" = $true
        "editor.fontSize" = 14
        "editor.lineHeight" = 1.6
        
        # File settings - Enhanced
        "files.trimTrailingWhitespace" = $true
        "files.insertFinalNewline" = $true
        "files.trimFinalNewlines" = $true
        "files.autoSave" = "afterDelay"
        "files.autoSaveDelay" = 1000
        "files.encoding" = "utf8"
        "files.eol" = "\n"
        
        # File associations - Enhanced
        "files.associations" = @{
            "*.ps1xml" = "xml"
            "*.psm1" = "powershell"
            "*.psd1" = "powershell"
            "*.pssc" = "powershell"
            "*.psrc" = "powershell"
            "*.tf" = "terraform"
            "*.tfvars" = "terraform"
            "*.hcl" = "terraform"
            "Dockerfile*" = "dockerfile"
            "*.dockerignore" = "ignore"
            ".gitignore" = "ignore"
            ".gitattributes" = "gitattributes"
        }
        
        # Git settings - Enhanced
        "git.autofetch" = $true
        "git.confirmSync" = $false
        "git.enableSmartCommit" = $true
        "git.suggestSmartCommit" = $false
        "git.enableCommitSigning" = $false
        "git.rebaseWhenSync" = $true
        "git.pruneOnFetch" = $true
        "git.fetchOnPull" = $true
        "git.pullTags" = $true
        "gitlens.hovers.currentLine.over" = "line"
        "gitlens.currentLine.enabled" = $true
        "gitlens.blame.compact" = $false
        "gitlens.blame.heatmap.enabled" = $false
        
        # Search and exclude settings - Enhanced
        "search.exclude" = @{
            "**/node_modules" = $true
            "**/.git" = $true
            "**/dist" = $true
            "**/build" = $true
            "**/logs" = $true
            "**/*.log" = $true
            "**/bin" = $true
            "**/obj" = $true
            "**/.terraform" = $true
            "**/.vscode-test" = $true
        }
        
        # Project-specific settings - Enhanced
        "files.exclude" = @{
            "**/.git" = $true
            "**/.DS_Store" = $true
            "**/Thumbs.db" = $true
            "**/.vscode-test" = $true
        }
        
        # Workbench settings - Enhanced UI
        "workbench.colorTheme" = "Dark+ (default dark)"
        "workbench.iconTheme" = "vs-seti"
        "workbench.startupEditor" = "welcomePageInEmptyWorkbench"
        "workbench.enableExperiments" = $false
        "workbench.settings.enableNaturalLanguageSearch" = $false
        "workbench.tips.enabled" = $false
        "workbench.tree.indent" = 20
        "workbench.tree.renderIndentGuides" = "always"
        
        # Explorer settings
        "explorer.confirmDelete" = $true
        "explorer.confirmDragAndDrop" = $true
        "explorer.openEditors.visible" = 0
        "explorer.autoReveal" = $true
        "explorer.compactFolders" = $false
        
        # Intellisense and suggestions
        "vsintellicode.modify.editor.suggestSelection" = "automaticallyOverrodeDefaultValue"
        "github.copilot.enable" = @{
            "*" = $true
            "yaml" = $false
            "plaintext" = $false
            "markdown" = $true
            "powershell" = $true
        }
        
        # Testing settings
        "testExplorer.useNativeTesting" = $true
        "pester.useLegacyCodeLens" = $false
        "pester.outputVerbosity" = "FromPreference"
        
        # Security settings
        "security.workspace.trust.untrustedFiles" = "prompt"
        "security.workspace.trust.banner" = "always"
        "security.workspace.trust.startupPrompt" = "always"
        
        # Remote development settings
        "remote.SSH.remotePlatform" = @{}
        "remote.SSH.showLoginTerminal" = $true
        "remote.containers.copyGitConfig" = $true
        "remote.containers.gitCredentialHelperConfigLocation" = "system"
        
        # AitherZero specific settings
        "AitherZero.autoDetectProjects" = $true
        "AitherZero.enableLogging" = $true
        "AitherZero.logLevel" = "INFO"
    }
}

# Helper function to get recommended extensions
function Get-RecommendedVSCodeExtensions {
    [CmdletBinding()]
    param()
    
    return @{
        recommendations = @(
            # PowerShell - Enhanced
            "ms-vscode.powershell",
            "ms-vscode.powershell-preview",
            
            # Git - Enhanced with more tools
            "eamodio.gitlens",
            "mhutchie.git-graph",
            "donjayamanne.githistory",
            "github.vscode-pull-request-github",
            "ms-vscode.vscode-github-issue-notebooks",
            
            # General development - Enhanced
            "editorconfig.editorconfig",
            "streetsidesoftware.code-spell-checker",
            "yzhang.markdown-all-in-one",
            "redhat.vscode-yaml",
            "ms-vscode.hexeditor",
            "formulahendry.auto-rename-tag",
            "bradlc.vscode-tailwindcss",
            
            # Testing - Enhanced with more frameworks
            "hbenl.vscode-test-explorer",
            "ms-vscode.test-adapter-converter",
            "pspester.pester-test",
            
            # Remote development - Complete suite
            "ms-vscode-remote.remote-wsl",
            "ms-vscode-remote.remote-ssh",
            "ms-vscode-remote.remote-containers",
            "ms-vscode-remote.remote-ssh-edit",
            "ms-vscode.remote-explorer",
            
            # AI assistance - Enhanced
            "github.copilot",
            "github.copilot-chat",
            "ms-toolsai.jupyter",
            "ms-toolsai.vscode-jupyter-cell-tags",
            
            # Code quality and formatting
            "esbenp.prettier-vscode",
            "ms-vscode.vscode-json",
            "ms-vsliveshare.vsliveshare",
            "visualstudioexptteam.vscodeintellicode",
            
            # Infrastructure and DevOps
            "hashicorp.terraform",
            "ms-vscode.vscode-docker",
            "ms-kubernetes-tools.vscode-kubernetes-tools",
            
            # Productivity
            "aaron-bond.better-comments",
            "alefragnani.bookmarks",
            "gruntfuggly.todo-tree",
            "oderwat.indent-rainbow"
        );
        "unwantedRecommendations" = @(
            # Extensions that conflict with our setup
            "ms-vscode.vscode-typescript-next",
            "bradlc.vscode-tailwindcss"
        )
    }
}

# Helper function to get launch configurations
function Get-VSCodeLaunchConfiguration {
    [CmdletBinding()]
    param()
    
    return @{
        version = "0.2.0"
        configurations = @(
            @{
                name = "PowerShell: Launch Current File"
                type = "PowerShell"
                request = "launch"
                script = '${file}'
                cwd = '${workspaceFolder}'
                presentation = @{
                    hidden = $false
                    group = "powershell"
                    order = 1
                }
            },
            @{
                name = "PowerShell: Launch Start-AitherZero (Preview)"
                type = "PowerShell"
                request = "launch"
                script = '${workspaceFolder}/Start-AitherZero.ps1'
                cwd = '${workspaceFolder}'
                args = @("-WhatIf")
                presentation = @{
                    hidden = $false
                    group = "aitherzero"
                    order = 1
                }
            },
            @{
                name = "PowerShell: Launch Start-AitherZero (Full)"
                type = "PowerShell"
                request = "launch"
                script = '${workspaceFolder}/Start-AitherZero.ps1'
                cwd = '${workspaceFolder}'
                presentation = @{
                    hidden = $false
                    group = "aitherzero"
                    order = 2
                }
            },
            @{
                name = "PowerShell: Setup Wizard"
                type = "PowerShell"
                request = "launch"
                script = '${workspaceFolder}/Start-AitherZero.ps1'
                cwd = '${workspaceFolder}'
                args = @("-Setup", "-InstallationProfile", "developer")
                presentation = @{
                    hidden = $false
                    group = "aitherzero"
                    order = 3
                }
            },
            @{
                name = "PowerShell: Interactive Session"
                type = "PowerShell"
                request = "launch"
                cwd = '${workspaceFolder}'
                presentation = @{
                    hidden = $false
                    group = "powershell"
                    order = 2
                }
            },
            @{
                name = "PowerShell: Run Quick Tests"
                type = "PowerShell"
                request = "launch"
                script = '${workspaceFolder}/tests/Run-Tests.ps1'
                cwd = '${workspaceFolder}'
                presentation = @{
                    hidden = $false
                    group = "testing"
                    order = 1
                }
            },
            @{
                name = "PowerShell: Run All Tests"
                type = "PowerShell"
                request = "launch"
                script = '${workspaceFolder}/tests/Run-Tests.ps1'
                cwd = '${workspaceFolder}'
                args = @("-All")
                presentation = @{
                    hidden = $false
                    group = "testing"
                    order = 2
                }
            },
            @{
                name = "PowerShell: Run Setup Tests"
                type = "PowerShell"
                request = "launch"
                script = '${workspaceFolder}/tests/Run-Tests.ps1'
                cwd = '${workspaceFolder}'
                args = @("-Setup")
                presentation = @{
                    hidden = $false
                    group = "testing"
                    order = 3
                }
            },
            @{
                name = "PowerShell: Debug Module"
                type = "PowerShell"
                request = "launch"
                script = '${workspaceFolder}/Start-AitherZero.ps1'
                cwd = '${workspaceFolder}'
                args = @("-Debug")
                presentation = @{
                    hidden = $false
                    group = "debug"
                    order = 1
                }
            },
            @{
                name = "PowerShell: Release Workflow"
                type = "PowerShell"
                request = "launch"
                script = '${workspaceFolder}/release.ps1'
                cwd = '${workspaceFolder}'
                args = @("-WhatIf")
                presentation = @{
                    hidden = $false
                    group = "release"
                    order = 1
                }
            }
        )
        compounds = @(
            @{
                name = "AitherZero: Full Development Session"
                configurations = @(
                    "PowerShell: Interactive Session",
                    "PowerShell: Launch Start-AitherZero (Preview)"
                )
                presentation = @{
                    hidden = $false
                    group = "compounds"
                    order = 1
                }
            }
        )
    }
}

# Helper function to get task template
function Get-VSCodeTasksTemplate {
    [CmdletBinding()]
    param()
    
    return @{
        version = "2.0.0"
        tasks = @(
            # Testing Tasks
            @{
                label = "🧪 Run Quick Tests"
                type = "shell"
                command = "pwsh"
                args = @("-File", "tests/Run-Tests.ps1")
                group = @{
                    kind = "test"
                    isDefault = $true
                }
                presentation = @{
                    reveal = "always"
                    panel = "new"
                    clear = $true
                    showReuseMessage = $false
                }
                problemMatcher = @("\$pester")
            },
            @{
                label = "🧪 Run All Tests"
                type = "shell"
                command = "pwsh"
                args = @("-File", "tests/Run-Tests.ps1", "-All")
                group = "test"
                presentation = @{
                    reveal = "always"
                    panel = "new"
                    clear = $true
                }
                problemMatcher = @("\$pester")
            },
            @{
                label = "🧪 Run Setup Tests"
                type = "shell"
                command = "pwsh"
                args = @("-File", "tests/Run-Tests.ps1", "-Setup")
                group = "test"
                presentation = @{
                    reveal = "always"
                    panel = "new"
                    clear = $true
                }
            },
            
            # AitherZero Operations
            @{
                label = "🚀 Start AitherZero (Preview)"
                type = "shell"
                command = "pwsh"
                args = @("-File", "Start-AitherZero.ps1", "-WhatIf")
                group = @{
                    kind = "build"
                    isDefault = $true
                }
                presentation = @{
                    reveal = "always"
                    panel = "new"
                    clear = $true
                }
            },
            @{
                label = "🚀 Start AitherZero (Full)"
                type = "shell"
                command = "pwsh"
                args = @("-File", "Start-AitherZero.ps1")
                group = "build"
                presentation = @{
                    reveal = "always"
                    panel = "new"
                }
            },
            @{
                label = "🔧 Setup Wizard (Developer)"
                type = "shell"
                command = "pwsh"
                args = @("-File", "Start-AitherZero.ps1", "-Setup", "-InstallationProfile", "developer")
                group = "build"
                presentation = @{
                    reveal = "always"
                    panel = "new"
                }
            },
            
            # Development Environment
            @{
                label = "🛠️ Initialize Dev Environment"
                type = "shell"
                command = "pwsh"
                args = @("-Command", "Import-Module ./aither-core/modules/DevEnvironment -Force; Initialize-DevelopmentEnvironment")
                group = "build"
                presentation = @{
                    reveal = "always"
                    panel = "new"
                }
            },
            @{
                label = "🛠️ Install AI Tools"
                type = "shell"
                command = "pwsh"
                args = @("-Command", "Import-Module ./aither-core/modules/AIToolsIntegration -Force; Install-ClaudeCode; Install-GeminiCLI")
                group = "build"
                presentation = @{
                    reveal = "always"
                    panel = "new"
                }
            },
            @{
                label = "📊 Check Environment Status"
                type = "shell"
                command = "pwsh"
                args = @("-Command", "Import-Module ./aither-core/modules/DevEnvironment -Force; Get-DevEnvironmentStatus | ConvertTo-Json -Depth 3")
                group = "build"
                presentation = @{
                    reveal = "always"
                    panel = "new"
                }
            },
            
            # Code Quality
            @{
                label = "🔍 Run PSScriptAnalyzer"
                type = "shell"
                command = "pwsh"
                args = @("-Command", "Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning,Error,Information | Format-Table")
                group = "test"
                presentation = @{
                    reveal = "always"
                    panel = "new"
                    clear = $true
                }
                problemMatcher = @("\$PSScriptAnalyzer")
            },
            @{
                label = "📝 Format PowerShell Files"
                type = "shell"
                command = "pwsh"
                args = @("-Command", "Get-ChildItem -Recurse -Filter '*.ps1' | ForEach-Object { Invoke-Formatter -ScriptDefinition (Get-Content \$_.FullName -Raw) | Set-Content \$_.FullName }")
                group = "build"
                presentation = @{
                    reveal = "silent"
                    panel = "shared"
                }
            },
            
            # Git Operations
            @{
                label = "📋 Git Status"
                type = "shell"
                command = "git"
                args = @("status", "--porcelain")
                group = "build"
                presentation = @{
                    reveal = "always"
                    panel = "new"
                }
            },
            @{
                label = "🔄 Sync with Remote"
                type = "shell"
                command = "pwsh"
                args = @("-Command", "Import-Module ./aither-core/modules/PatchManager -Force; Sync-GitBranch -Force")
                group = "build"
                presentation = @{
                    reveal = "always"
                    panel = "new"
                }
            },
            
            # Release and Build
            @{
                label = "🏗️ Build Package (All Platforms)"
                type = "shell"
                command = "pwsh"
                args = @("-File", "build/Build-Package.ps1")
                group = "build"
                presentation = @{
                    reveal = "always"
                    panel = "new"
                }
            },
            @{
                label = "🚢 Create Release (Preview)"
                type = "shell"
                command = "pwsh"
                args = @("-File", "release.ps1", "-WhatIf")
                group = "build"
                presentation = @{
                    reveal = "always"
                    panel = "new"
                }
            },
            
            # Module Development
            @{
                label = "🔄 Reload All Modules"
                type = "shell"
                command = "pwsh"
                args = @("-Command", "Get-Module | Where-Object Path -Like '*aither-core/modules*' | Remove-Module -Force; Import-Module ./aither-core/modules/*/")
                group = "build"
                presentation = @{
                    reveal = "silent"
                    panel = "shared"
                }
            },
            @{
                label = "📦 Import Module: DevEnvironment"
                type = "shell"
                command = "pwsh"
                args = @("-Command", "Import-Module ./aither-core/modules/DevEnvironment -Force -Verbose")
                group = "build"
                presentation = @{
                    reveal = "always"
                    panel = "shared"
                }
            },
            
            # Cleanup Operations
            @{
                label = "🧹 Clean Workspace"
                type = "shell"
                command = "pwsh"
                args = @("-Command", "Remove-Item -Path './logs/*' -Force -ErrorAction SilentlyContinue; Remove-Item -Path './temp/*' -Recurse -Force -ErrorAction SilentlyContinue")
                group = "build"
                presentation = @{
                    reveal = "silent"
                    panel = "shared"
                }
            }
        )
        inputs = @(
            @{
                id = "releaseType"
                description = "Release Type"
                default = "patch"
                type = "pickString"
                options = @(
                    @{ label = "Patch"; value = "patch" },
                    @{ label = "Minor"; value = "minor" },
                    @{ label = "Major"; value = "major" }
                )
            },
            @{
                id = "moduleSelection"
                description = "Select Module"
                default = "DevEnvironment"
                type = "pickString"
                options = @(
                    @{ label = "DevEnvironment"; value = "DevEnvironment" },
                    @{ label = "AIToolsIntegration"; value = "AIToolsIntegration" },
                    @{ label = "PatchManager"; value = "PatchManager" },
                    @{ label = "SetupWizard"; value = "SetupWizard" },
                    @{ label = "All Modules"; value = "*" }
                )
            }
        )
    }
}