# AI Tools Integration Module for AitherZero
# Handles installation and configuration of AI development tools

# Import required modules
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

# Import logging if available
$loggingModule = Join-Path $projectRoot "aither-core/modules/Logging"
if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force -ErrorAction SilentlyContinue
}

function Install-ClaudeCode {
    <#
    .SYNOPSIS
        Installs Claude Code CLI tool with enhanced version management
    .DESCRIPTION
        Installs Claude Code using npm with improved error handling, version management,
        and cross-platform compatibility. Supports both global and local installations.
    .PARAMETER Force
        Force reinstallation even if Claude Code is already installed
    .PARAMETER Global
        Install globally (default: true)
    .PARAMETER Version
        Specific version to install (default: 'latest')
    .PARAMETER SkipVerification
        Skip post-installation verification
    .PARAMETER ConfigureIntegration
        Configure Claude Code for AitherZero integration
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$Force,
        [switch]$Global = $true,
        [string]$Version = 'latest',
        [switch]$SkipVerification,
        [switch]$ConfigureIntegration = $true
    )
    
    try {
        Write-CustomLog -Level 'INFO' -Message "🤖 Starting Claude Code installation..."
        
        # Enhanced prerequisites check
        $nodeCheck = Test-NodeJsPrerequisites
        if (-not $nodeCheck.Success) {
            throw "Node.js prerequisites not met: $($nodeCheck.Message). $($nodeCheck.InstallHint)"
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "✅ Node.js prerequisites verified: Node $($nodeCheck.NodeVersion), npm $($nodeCheck.NPMVersion)"
        
        # Enhanced existing installation check
        $existingInstall = Get-Command claude-code -ErrorAction SilentlyContinue
        if ($existingInstall -and -not $Force) {
            try {
                $currentVersion = & claude-code --version 2>$null
                Write-CustomLog -Level 'INFO' -Message "Claude Code already installed: $currentVersion at $($existingInstall.Source)"
                
                if ($ConfigureIntegration) {
                    Configure-ClaudeCodeIntegration
                }
                
                return @{
                    Success = $true
                    Message = "Claude Code already installed"
                    Version = $currentVersion
                    Path = $existingInstall.Source
                    AlreadyInstalled = $true
                }
            } catch {
                Write-CustomLog -Level 'WARNING' -Message "Existing Claude Code installation may be corrupted, proceeding with installation"
            }
        }
        
        # Prepare installation command
        $packageName = if ($Version -eq 'latest') { 
            '@anthropic-ai/claude-code' 
        } else { 
            "@anthropic-ai/claude-code@$Version" 
        }
        
        $installArgs = @('install')
        if ($Global) { $installArgs += '--global' }
        $installArgs += $packageName
        
        # Add npm configuration for better reliability
        $installArgs += '--no-audit'  # Skip audit for faster installation
        $installArgs += '--no-fund'   # Skip funding messages
        
        Write-CustomLog -Level 'INFO' -Message "📦 Installing Claude Code: npm $($installArgs -join ' ')"
        
        if ($PSCmdlet.ShouldProcess("Claude Code $Version", "Install via npm")) {
            # Execute installation with enhanced error handling
            $installProcess = Start-Process -FilePath 'npm' -ArgumentList $installArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput "npm-out.txt" -RedirectStandardError "npm-err.txt"
            
            $installOutput = if (Test-Path "npm-out.txt") { Get-Content "npm-out.txt" -Raw } else { "" }
            $installError = if (Test-Path "npm-err.txt") { Get-Content "npm-err.txt" -Raw } else { "" }
            
            # Clean up temp files
            Remove-Item "npm-out.txt", "npm-err.txt" -ErrorAction SilentlyContinue
            
            if ($installProcess.ExitCode -ne 0) {
                throw "npm install failed (Exit Code: $($installProcess.ExitCode)). Output: $installOutput. Error: $installError"
            }
            
            Write-CustomLog -Level 'SUCCESS' -Message "📦 npm installation completed successfully"
        }
        
        # Enhanced verification with retries
        $maxRetries = 3
        $claudeCmd = $null
        
        for ($retry = 1; $retry -le $maxRetries; $retry++) {
            Start-Sleep -Seconds ($retry * 2)  # Progressive delay
            $claudeCmd = Get-Command claude-code -ErrorAction SilentlyContinue
            if ($claudeCmd) { break }
            
            if ($retry -lt $maxRetries) {
                Write-CustomLog -Level 'WARNING' -Message "Attempt $retry/$maxRetries: Claude Code not found in PATH, retrying..."
            }
        }
        
        if (-not $claudeCmd) {
            # Try to refresh PATH and check again
            if ($IsWindows) {
                $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('PATH', 'User')
            } else {
                # Source common profile locations
                $env:PATH += ":$HOME/.local/bin:$HOME/bin:/usr/local/bin"
            }
            
            $claudeCmd = Get-Command claude-code -ErrorAction SilentlyContinue
        }
        
        if (-not $claudeCmd -and -not $SkipVerification) {
            throw "Claude Code installation verification failed. Command not found in PATH after installation."
        }
        
        # Get version information
        $version = "Unknown"
        if ($claudeCmd) {
            try {
                $version = & claude-code --version 2>$null
                if ([string]::IsNullOrEmpty($version)) {
                    $version = "Installed (version check failed)"
                }
            } catch {
                $version = "Installed (version unavailable)"
            }
        }
        
        # Configure integration if requested
        $integrationResult = $null
        if ($ConfigureIntegration -and $claudeCmd) {
            try {
                $integrationResult = Configure-ClaudeCodeIntegration
                Write-CustomLog -Level 'SUCCESS' -Message "🔧 Claude Code integration configured"
            } catch {
                Write-CustomLog -Level 'WARNING' -Message "Failed to configure Claude Code integration: $($_.Exception.Message)"
            }
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "✅ Claude Code $version installed successfully!"
        
        return @{
            Success = $true
            Message = "Claude Code installed successfully"
            Version = $version
            Path = if ($claudeCmd) { $claudeCmd.Source } else { "Not found in PATH" }
            IntegrationConfigured = $null -ne $integrationResult
            InstallationMethod = "npm"
            Global = $Global
            PackageName = $packageName
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Claude Code installation failed: $_"
        return @{
            Success = $false
            Message = $_.Exception.Message
            Error = $_
        }
    }
}

function Install-GeminiCLI {
    <#
    .SYNOPSIS
        Installs Gemini CLI tool
    .DESCRIPTION
        Installs Gemini CLI and configures it for AitherZero integration
    #>
    [CmdletBinding()]
    param(
        [switch]$Force,
        [string]$InstallMethod = 'auto'
    )
    
    try {
        Write-CustomLog -Level 'INFO' -Message "Starting Gemini CLI installation..."
        
        # Determine installation method based on platform
        $platform = Get-PlatformInfo
        $installMethod = if ($InstallMethod -eq 'auto') {
            switch ($platform.OS) {
                'Windows' { 'winget' }
                'Linux' { 'curl' }
                'macOS' { 'brew' }
                default { 'manual' }
            }
        } else {
            $InstallMethod
        }
        
        # Check if already installed
        $existingInstall = Get-Command gemini -ErrorAction SilentlyContinue
        if ($existingInstall -and -not $Force) {
            Write-CustomLog -Level 'INFO' -Message "Gemini CLI already installed at: $($existingInstall.Source)"
            return @{
                Success = $true
                Message = "Gemini CLI already installed"
                Path = $existingInstall.Source
            }
        }
        
        switch ($installMethod) {
            'winget' {
                # Note: This is speculative - need to verify actual Gemini CLI package
                $installResult = winget install Google.GeminiCLI 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "Winget installation failed: $installResult"
                }
            }
            'brew' {
                # Note: This is speculative - need to verify actual Gemini CLI formula
                $installResult = brew install gemini-cli 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "Brew installation failed: $installResult"
                }
            }
            'curl' {
                # Note: This would need the actual download URL
                Write-CustomLog -Level 'WARNING' -Message "Gemini CLI curl installation not yet implemented"
                return @{
                    Success = $false
                    Message = "Gemini CLI installation method not available for Linux"
                }
            }
            'manual' {
                Write-CustomLog -Level 'WARNING' -Message "Manual Gemini CLI installation required"
                return @{
                    Success = $false
                    Message = "Manual installation required - please visit Google AI documentation"
                    ManualSteps = @(
                        "Visit: https://developers.generativeai.google/",
                        "Download Gemini CLI for your platform",
                        "Add to PATH environment variable",
                        "Configure API credentials"
                    )
                }
            }
        }
        
        # Verify installation
        $geminiCmd = Get-Command gemini -ErrorAction SilentlyContinue
        if (-not $geminiCmd) {
            throw "Gemini CLI installation verification failed"
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "Gemini CLI installed successfully"
        
        return @{
            Success = $true
            Message = "Gemini CLI installed successfully"
            Path = $geminiCmd.Source
            RequiresConfiguration = $true
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Gemini CLI installation failed: $_"
        return @{
            Success = $false
            Message = $_.Exception.Message
            Error = $_
        }
    }
}

function Install-CodexCLI {
    <#
    .SYNOPSIS
        Installs Codex CLI tool (if available)
    .DESCRIPTION
        Attempts to install Codex CLI - note that availability may be limited
    #>
    [CmdletBinding()]
    param(
        [switch]$Force
    )
    
    try {
        Write-CustomLog -Level 'INFO' -Message "Checking Codex CLI availability..."
        
        # Note: OpenAI Codex may not have a public CLI
        # This is a placeholder for future implementation
        
        Write-CustomLog -Level 'WARNING' -Message "Codex CLI is not publicly available"
        
        return @{
            Success = $false
            Message = "Codex CLI is not currently available for public installation"
            Note = "OpenAI Codex access is limited to approved developers"
            Alternative = "Consider using GitHub Copilot CLI or other AI coding assistants"
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Codex CLI check failed: $_"
        return @{
            Success = $false
            Message = $_.Exception.Message
            Error = $_
        }
    }
}

function Test-AIToolsInstallation {
    <#
    .SYNOPSIS
        Tests the installation status of all AI tools
    .DESCRIPTION
        Checks which AI tools are installed and properly configured
    #>
    [CmdletBinding()]
    param()
    
    $results = @{
        ClaudeCode = Test-ClaudeCodeInstallation
        GeminiCLI = Test-GeminiCLIInstallation  
        CodexCLI = Test-CodexCLIInstallation
        Summary = @{}
    }
    
    # Generate summary
    $installed = 0
    $total = 0
    
    foreach ($tool in $results.Keys) {
        if ($tool -eq 'Summary') { continue }
        $total++
        if ($results[$tool].Installed) {
            $installed++
        }
    }
    
    $results.Summary = @{
        InstalledCount = $installed
        TotalCount = $total
        OverallStatus = if ($installed -eq $total) { 'Complete' } 
                       elseif ($installed -gt 0) { 'Partial' } 
                       else { 'None' }
    }
    
    return $results
}

function Test-ClaudeCodeInstallation {
    $claudeCmd = Get-Command claude-code -ErrorAction SilentlyContinue
    if ($claudeCmd) {
        $version = claude-code --version 2>$null
        return @{
            Installed = $true
            Path = $claudeCmd.Source
            Version = $version
            Status = 'Ready'
        }
    }
    return @{ Installed = $false; Status = 'Not installed' }
}

function Test-GeminiCLIInstallation {
    $geminiCmd = Get-Command gemini -ErrorAction SilentlyContinue
    if ($geminiCmd) {
        return @{
            Installed = $true
            Path = $geminiCmd.Source
            Status = 'Ready'
            RequiresConfiguration = $true
        }
    }
    return @{ Installed = $false; Status = 'Not installed' }
}

function Test-CodexCLIInstallation {
    # Codex CLI is not publicly available
    return @{ 
        Installed = $false
        Status = 'Not available'
        Note = 'OpenAI Codex CLI is not publicly available'
    }
}

function Test-NodeJsPrerequisites {
    <#
    .SYNOPSIS
        Enhanced Node.js and npm prerequisites check with version validation
    #>
    [CmdletBinding()]
    param(
        [Version]$MinimumNodeVersion = '16.0.0',
        [Version]$MinimumNpmVersion = '8.0.0'
    )
    
    try {
        $result = @{
            Success = $false
            NodeInstalled = $false
            NPMInstalled = $false
            NodeVersion = $null
            NPMVersion = $null
            NodeVersionParsed = $null
            NPMVersionParsed = $null
            Message = ""
            InstallHint = ""
            Recommendations = @()
        }
        
        # Check if node command exists
        $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
        if (-not $nodeCmd) {
            $result.Message = "Node.js is not installed or not in PATH"
            $result.InstallHint = if ($IsWindows) { 
                "Install with: winget install OpenJS.NodeJS" 
            } elseif ($IsMacOS) {
                "Install with: brew install node"
            } else { 
                "Visit: https://nodejs.org/en/download/ or use package manager" 
            }
            return $result
        }
        
        $result.NodeInstalled = $true
        
        # Check if npm command exists
        $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
        if (-not $npmCmd) {
            $result.Message = "npm is not found (usually comes with Node.js)"
            $result.InstallHint = "Reinstall Node.js to get npm, or install npm separately"
            return $result
        }
        
        $result.NPMInstalled = $true
        
        # Get versions with enhanced error handling
        try {
            $nodeVersionRaw = & $nodeCmd --version 2>$null
            if ($nodeVersionRaw) {
                $result.NodeVersion = $nodeVersionRaw.TrimStart('v')
                $result.NodeVersionParsed = [Version]$result.NodeVersion
            }
        } catch {
            Write-CustomLog -Level 'WARNING' -Message "Failed to get Node.js version: $($_.Exception.Message)"
        }
        
        try {
            $npmVersionRaw = & $npmCmd --version 2>$null
            if ($npmVersionRaw) {
                $result.NPMVersion = $npmVersionRaw
                $result.NPMVersionParsed = [Version]$result.NPMVersion
            }
        } catch {
            Write-CustomLog -Level 'WARNING' -Message "Failed to get npm version: $($_.Exception.Message)"
        }
        
        # Version validation
        if ($result.NodeVersionParsed -and $result.NPMVersionParsed) {
            $nodeVersionOk = $result.NodeVersionParsed -ge $MinimumNodeVersion
            $npmVersionOk = $result.NPMVersionParsed -ge $MinimumNpmVersion
            
            if ($nodeVersionOk -and $npmVersionOk) {
                $result.Success = $true
                $result.Message = "Node.js and npm meet requirements"
            } else {
                $versionIssues = @()
                if (-not $nodeVersionOk) {
                    $versionIssues += "Node.js $($result.NodeVersion) is below minimum $MinimumNodeVersion"
                    $result.Recommendations += "Upgrade Node.js to version $MinimumNodeVersion or later"
                }
                if (-not $npmVersionOk) {
                    $versionIssues += "npm $($result.NPMVersion) is below minimum $MinimumNpmVersion"
                    $result.Recommendations += "Upgrade npm with: npm install -g npm@latest"
                }
                $result.Message = $versionIssues -join "; "
            }
        } else {
            $result.Message = "Failed to validate Node.js or npm versions"
        }
        
        # Additional system checks
        try {
            # Check npm registry connectivity
            $npmConfig = & npm config get registry 2>$null
            if ($npmConfig) {
                $result.NPMRegistry = $npmConfig
            }
            
            # Check global npm packages directory
            $npmGlobalDir = & npm config get prefix 2>$null
            if ($npmGlobalDir) {
                $result.NPMGlobalDir = $npmGlobalDir
                $result.NPMGlobalDirExists = Test-Path $npmGlobalDir
            }
        } catch {
            Write-CustomLog -Level 'DEBUG' -Message "Failed to get npm configuration details: $($_.Exception.Message)"
        }
        
        return $result
        
    } catch {
        return @{
            Success = $false
            Message = "Error checking Node.js prerequisites: $($_.Exception.Message)"
            Error = $_.Exception
        }
    }
}

function Configure-ClaudeCodeIntegration {
    <#
    .SYNOPSIS
        Configures Claude Code for optimal integration with AitherZero
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-CustomLog -Level 'INFO' -Message "Configuring Claude Code integration..."
        
        $configResult = @{
            Success = $false
            ConfigurationsApplied = @()
            Issues = @()
        }
        
        # Check if Claude Code is available
        $claudeCmd = Get-Command claude-code -ErrorAction SilentlyContinue
        if (-not $claudeCmd) {
            throw "Claude Code command not found. Please install Claude Code first."
        }
        
        # Get Claude Code configuration directory
        $configDir = if ($IsWindows) {
            Join-Path $env:APPDATA "claude-code"
        } elseif ($IsMacOS) {
            Join-Path $HOME "Library/Application Support/claude-code"
        } else {
            Join-Path $HOME ".config/claude-code"
        }
        
        # Create configuration directory if it doesn't exist
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
            $configResult.ConfigurationsApplied += "Created configuration directory: $configDir"
        }
        
        # Create AitherZero-specific configuration
        $aitherZeroConfig = @{
            project = "AitherZero"
            language = "powershell"
            framework = "module-based"
            preferences = @{
                codeStyle = "OTBS"
                indentation = "spaces"
                tabSize = 4
                maxLineLength = 120
            }
            integrations = @{
                vscode = $true
                git = $true
                pester = $true
            }
            aiAssistance = @{
                contextAware = $true
                projectSpecific = $true
                includeComments = $true
                suggestOptimizations = $true
            }
        }
        
        $configFile = Join-Path $configDir "aitherzero-config.json"
        $aitherZeroConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $configFile -Encoding UTF8
        $configResult.ConfigurationsApplied += "Created AitherZero configuration: $configFile"
        
        # Set up workspace-specific Claude Code settings
        $workspaceConfig = @{
            ".ps1" = @{
                language = "powershell"
                style = "OTBS"
                analysis = $true
            }
            ".psm1" = @{
                language = "powershell-module"
                moduleStructure = $true
                exportValidation = $true
            }
            ".psd1" = @{
                language = "powershell-manifest"
                manifestValidation = $true
            }
        }
        
        $workspaceConfigFile = Join-Path $configDir "workspace-config.json"
        $workspaceConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $workspaceConfigFile -Encoding UTF8
        $configResult.ConfigurationsApplied += "Created workspace configuration: $workspaceConfigFile"
        
        # Test Claude Code functionality
        try {
            $claudeTest = & claude-code --version 2>$null
            if ($claudeTest) {
                $configResult.ConfigurationsApplied += "Verified Claude Code functionality"
            }
        } catch {
            $configResult.Issues += "Claude Code functionality test failed: $($_.Exception.Message)"
        }
        
        $configResult.Success = $configResult.Issues.Count -eq 0
        
        if ($configResult.Success) {
            Write-CustomLog -Level 'SUCCESS' -Message "Claude Code integration configured successfully"
        } else {
            Write-CustomLog -Level 'WARNING' -Message "Claude Code integration configured with issues: $($configResult.Issues -join '; ')"
        }
        
        return $configResult
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to configure Claude Code integration: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-PlatformInfo {
    return @{
        OS = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
        Architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    }
}

function Get-AIToolsStatus {
    <#
    .SYNOPSIS
        Gets detailed status of AI tools installation
    #>
    [CmdletBinding()]
    param()
    
    $status = Test-AIToolsInstallation
    
    Write-Host ""
    Write-Host "🤖 AI Tools Status:" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($tool in @('ClaudeCode', 'GeminiCLI', 'CodexCLI')) {
        $toolStatus = $status[$tool]
        $icon = if ($toolStatus.Installed) { '✅' } else { '❌' }
        $color = if ($toolStatus.Installed) { 'Green' } else { 'Red' }
        
        Write-Host "  $icon $tool`: $($toolStatus.Status)" -ForegroundColor $color
        if ($toolStatus.Version) {
            Write-Host "     Version: $($toolStatus.Version)" -ForegroundColor Gray
        }
        if ($toolStatus.Path) {
            Write-Host "     Path: $($toolStatus.Path)" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "📊 Summary: $($status.Summary.InstalledCount)/$($status.Summary.TotalCount) tools installed" -ForegroundColor $(
        switch ($status.Summary.OverallStatus) {
            'Complete' { 'Green' }
            'Partial' { 'Yellow' }
            'None' { 'Red' }
        }
    )
    
    return $status
}

function Configure-AITools {
    <#
    .SYNOPSIS
        Interactive configuration of installed AI tools
    #>
    [CmdletBinding()]
    param()
    
    Write-Host "🔧 AI Tools Configuration" -ForegroundColor Cyan
    Write-Host "This will help configure your installed AI tools." -ForegroundColor White
    Write-Host ""
    
    # Implementation would include:
    # - Claude Code API key setup
    # - Gemini API credentials
    # - Integration testing
    
    Write-CustomLog -Level 'INFO' -Message "AI Tools configuration wizard - implementation in progress"
}

function Update-AITools {
    <#
    .SYNOPSIS
        Updates installed AI tools to latest versions
    #>
    [CmdletBinding()]
    param()
    
    Write-CustomLog -Level 'INFO' -Message "Checking for AI tools updates..."
    
    # Update Claude Code if installed
    if (Get-Command claude-code -ErrorAction SilentlyContinue) {
        try {
            npm update -g @anthropic/claude-code
            Write-CustomLog -Level 'SUCCESS' -Message "Claude Code updated"
        } catch {
            Write-CustomLog -Level 'WARNING' -Message "Failed to update Claude Code: $_"
        }
    }
}

function Remove-AITools {
    <#
    .SYNOPSIS
        Removes installed AI tools
    #>
    [CmdletBinding()]
    param(
        [string[]]$Tools = @('all'),
        [switch]$Force
    )
    
    if ($Tools -contains 'all') {
        $Tools = @('claude-code', 'gemini-cli')
    }
    
    foreach ($tool in $Tools) {
        switch ($tool) {
            'claude-code' {
                if (Get-Command claude-code -ErrorAction SilentlyContinue) {
                    try {
                        npm uninstall -g @anthropic/claude-code
                        Write-CustomLog -Level 'SUCCESS' -Message "Claude Code removed"
                    } catch {
                        Write-CustomLog -Level 'ERROR' -Message "Failed to remove Claude Code: $_"
                    }
                }
            }
            'gemini-cli' {
                Write-CustomLog -Level 'WARNING' -Message "Gemini CLI removal method depends on installation method"
            }
        }
    }
}

# Logging fallback functions
if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
    function Write-CustomLog {
        param(
            [string]$Level,
            [string]$Message
        )
        $color = switch ($Level) {
            'SUCCESS' { 'Green' }
            'ERROR' { 'Red' }
            'WARNING' { 'Yellow' }
            'INFO' { 'Cyan' }
            default { 'White' }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
}

# Export functions
Export-ModuleMember -Function @(
    # Installation Functions
    'Install-ClaudeCode',
    'Install-GeminiCLI', 
    'Install-CodexCLI',
    
    # Testing and Status Functions
    'Test-AIToolsInstallation',
    'Test-NodeJsPrerequisites',
    'Get-AIToolsStatus',
    
    # Configuration Functions
    'Configure-AITools',
    'Configure-ClaudeCodeIntegration',
    
    # Management Functions
    'Update-AITools',
    'Remove-AITools'
)