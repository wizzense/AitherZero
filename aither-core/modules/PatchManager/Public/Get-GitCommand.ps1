function Get-GitCommand {
    <#
    .SYNOPSIS
        Cross-platform git command detection for PatchManager v3.0
    
    .DESCRIPTION
        Robustly detects git installation across different development environments:
        - Standard PATH (Linux, macOS, Windows)
        - WSL + Windows git integration
        - Homebrew installations (macOS)
        - Direct Windows installations
        - Development container environments
    
    .PARAMETER TestConnection
        Test if git is functional (can run git --version)
    
    .EXAMPLE
        $gitCmd = Get-GitCommand
        & $gitCmd status
    
    .NOTES
        This fixes the fundamental PatchManager v3.0 flaw where git detection
        failed in cross-platform environments, particularly WSL on Windows.
    #>
    [CmdletBinding()]
    param(
        [switch]$TestConnection
    )
    
    # Cache the git command to avoid repeated detection
    if ($script:GitCommand -and -not $TestConnection) {
        return $script:GitCommand
    }
    
    # Define git paths for different environments
    $gitPaths = @(
        # Standard PATH - try this first
        'git',
        
        # WSL + Windows integration
        '/mnt/c/Program Files/Git/cmd/git.exe',
        '/mnt/c/Program Files/Git/bin/git.exe',
        '/mnt/c/Program Files (x86)/Git/cmd/git.exe',
        '/mnt/c/Program Files (x86)/Git/bin/git.exe',
        
        # Direct Windows paths
        'C:\Program Files\Git\cmd\git.exe',
        'C:\Program Files\Git\bin\git.exe',
        'C:\Program Files (x86)\Git\cmd\git.exe',
        'C:\Program Files (x86)\Git\bin\git.exe',
        
        # Linux standard locations
        '/usr/bin/git',
        '/usr/local/bin/git',
        '/bin/git',
        
        # macOS locations
        '/usr/local/bin/git',           # Standard macOS
        '/opt/homebrew/bin/git',        # Homebrew on Apple Silicon
        '/usr/local/homebrew/bin/git',  # Homebrew on Intel
        '/Applications/Xcode.app/Contents/Developer/usr/bin/git', # Xcode git
        
        # Windows alternatives
        "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe",
        "$env:ProgramFiles\Git\cmd\git.exe",
        "${env:ProgramFiles(x86)}\Git\cmd\git.exe",
        
        # Snap packages (Linux)
        '/snap/bin/git',
        
        # Development containers
        '/workspaces/.devcontainer/usr/bin/git',
        '/vscode/vscode-server/bin/git'
    )
    
    $workingGitCommand = $null
    $detectionLog = @()
    
    foreach ($gitPath in $gitPaths) {
        try {
            # Expand environment variables if present
            $expandedPath = [System.Environment]::ExpandEnvironmentVariables($gitPath)
            
            # Test if command exists
            $gitCommand = Get-Command $expandedPath -ErrorAction Stop 2>$null
            
            if ($gitCommand) {
                $detectionLog += "✅ Found git at: $expandedPath"
                
                # Test if git actually works
                if ($TestConnection) {
                    $version = & $expandedPath --version 2>$null
                    if ($LASTEXITCODE -eq 0 -and $version) {
                        $detectionLog += "✅ Git functional test passed: $version"
                        $workingGitCommand = $expandedPath
                        break
                    } else {
                        $detectionLog += "❌ Git found but not functional at: $expandedPath"
                        continue
                    }
                } else {
                    $workingGitCommand = $expandedPath
                    break
                }
            }
        } catch {
            $detectionLog += "❌ Git not found at: $expandedPath"
            continue
        }
    }
    
    # Log detection results if verbose
    if ($VerbosePreference -eq 'Continue' -or $env:AITHER_DEBUG) {
        Write-Host "🔍 Git Detection Results:" -ForegroundColor Cyan
        $detectionLog | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
    }
    
    if (-not $workingGitCommand) {
        $errorMessage = @"
❌ Git not found in any expected location!

Searched locations:
$($gitPaths | ForEach-Object { "  • $_" } | Out-String)

Platform Detection:
  • OS: $([System.Environment]::OSVersion.Platform)
  • PowerShell: $($PSVersionTable.PSVersion)
  • Environment: $(if ($env:WSL_DISTRO_NAME) { "WSL ($env:WSL_DISTRO_NAME)" } elseif ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } elseif ($IsMacOS) { "macOS" } else { "Unknown" })

Solutions:
  1. Install Git: https://git-scm.com/downloads
  2. Add Git to PATH environment variable
  3. For WSL: Install Git in Windows and/or Linux
  4. For macOS: Install via Homebrew or Xcode Command Line Tools

PatchManager v3.0 requires Git for atomic operations.
"@
        
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Level 'ERROR' -Message $errorMessage
        } else {
            Write-Error $errorMessage
        }
        
        throw "Git command not found. PatchManager v3.0 requires Git for atomic operations."
    }
    
    # Cache the working command
    $script:GitCommand = $workingGitCommand
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level 'SUCCESS' -Message "Git detected: $workingGitCommand"
    } else {
        Write-Verbose "Git detected: $workingGitCommand"
    }
    
    return $workingGitCommand
}

function Invoke-GitCommand {
    <#
    .SYNOPSIS
        Safe git command execution wrapper for PatchManager v3.0
    
    .DESCRIPTION
        Executes git commands using the detected git path with proper error handling
    
    .PARAMETER Arguments
        Git command arguments (e.g., 'status', 'commit -m "message"')
    
    .PARAMETER AllowFailure
        Don't throw on non-zero exit codes
    
    .EXAMPLE
        Invoke-GitCommand "status --porcelain"
        Invoke-GitCommand "commit -m 'Fix issue'" -AllowFailure
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Arguments,
        
        [switch]$AllowFailure,
        
        [switch]$Quiet
    )
    
    $gitCmd = Get-GitCommand
    
    if (-not $Quiet -and (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
        Write-CustomLog -Level 'DEBUG' -Message "Executing: $gitCmd $Arguments"
    }
    
    try {
        # Split arguments properly to handle quoted strings
        $argList = @()
        if ($Arguments) {
            # Simple argument parsing - could be enhanced for complex cases
            $argList = $Arguments -split ' (?=(?:[^"]*"[^"]*")*[^"]*$)'
        }
        
        $result = & $gitCmd @argList 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -ne 0 -and -not $AllowFailure) {
            $errorMessage = "Git command failed with exit code $exitCode`nCommand: $gitCmd $Arguments`nOutput: $result"
            
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Level 'ERROR' -Message $errorMessage
            } else {
                Write-Error $errorMessage
            }
            
            throw "Git command failed: $gitCmd $Arguments"
        }
        
        return @{
            Output = $result
            ExitCode = $exitCode
            Success = ($exitCode -eq 0)
        }
        
    } catch {
        if (-not $AllowFailure) {
            throw
        }
        
        return @{
            Output = $_.Exception.Message
            ExitCode = -1
            Success = $false
        }
    }
}

Export-ModuleMember -Function Get-GitCommand, Invoke-GitCommand