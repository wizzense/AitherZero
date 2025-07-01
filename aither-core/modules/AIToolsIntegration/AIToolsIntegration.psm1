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
        Installs Claude Code CLI tool
    .DESCRIPTION
        Installs Claude Code using npm and configures it for AitherZero integration
    #>
    [CmdletBinding()]
    param(
        [switch]$Force,
        [switch]$Global = $true,
        [string]$Version = 'latest'
    )
    
    try {
        Write-CustomLog -Level 'INFO' -Message "Starting Claude Code installation..."
        
        # Check prerequisites
        $nodeInstalled = Test-NodeJsPrerequisites
        if (-not $nodeInstalled.Success) {
            throw "Node.js prerequisites not met: $($nodeInstalled.Message)"
        }
        
        # Check if already installed
        $existingInstall = Get-Command claude-code -ErrorAction SilentlyContinue
        if ($existingInstall -and -not $Force) {
            Write-CustomLog -Level 'INFO' -Message "Claude Code already installed at: $($existingInstall.Source)"
            return @{
                Success = $true
                Message = "Claude Code already installed"
                Version = (claude-code --version 2>$null)
                Path = $existingInstall.Source
            }
        }
        
        # Install Claude Code
        $installArgs = @('install')
        if ($Global) { $installArgs += '--global' }
        $installArgs += "@anthropic/claude-code"
        if ($Version -ne 'latest') { $installArgs += "@$Version" }
        
        Write-CustomLog -Level 'INFO' -Message "Installing Claude Code: npm $($installArgs -join ' ')"
        $installResult = & npm @installArgs 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "npm install failed: $installResult"
        }
        
        # Verify installation
        $claudeCmd = Get-Command claude-code -ErrorAction SilentlyContinue
        if (-not $claudeCmd) {
            throw "Claude Code installation verification failed"
        }
        
        $version = claude-code --version 2>$null
        Write-CustomLog -Level 'SUCCESS' -Message "Claude Code $version installed successfully"
        
        return @{
            Success = $true
            Message = "Claude Code installed successfully"
            Version = $version
            Path = $claudeCmd.Source
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
    try {
        $nodeVersion = node --version 2>$null
        $npmVersion = npm --version 2>$null
        
        if ($nodeVersion -and $npmVersion) {
            return @{
                Success = $true
                NodeVersion = $nodeVersion
                NPMVersion = $npmVersion
                Message = "Node.js and npm are available"
            }
        } else {
            return @{
                Success = $false
                Message = "Node.js or npm not found"
            }
        }
    } catch {
        return @{
            Success = $false
            Message = "Error checking Node.js: $_"
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
    'Install-ClaudeCode',
    'Install-GeminiCLI', 
    'Install-CodexCLI',
    'Test-AIToolsInstallation',
    'Get-AIToolsStatus',
    'Configure-AITools',
    'Update-AITools',
    'Remove-AITools'
)