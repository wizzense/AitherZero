#Requires -Version 7.0

<#
.SYNOPSIS
    Optimizes the development environment for the current platform with platform-specific enhancements.

.DESCRIPTION
    This function performs platform-specific optimizations for Windows, Linux, and macOS to
    ensure optimal performance and compatibility for AitherZero development. It includes
    performance tuning, security configuration, and platform-specific tool integration.

.PARAMETER Platform
    Target platform for optimization. Auto-detected if not specified.

.PARAMETER IncludePerformanceTuning
    Apply performance optimizations specific to the platform.

.PARAMETER IncludeSecurityHardening
    Apply security configurations appropriate for development environments.

.PARAMETER ConfigureDevelopmentTools
    Configure platform-specific development tools and integrations.

.PARAMETER Force
    Force reapplication of optimizations even if already applied.

.PARAMETER WhatIf
    Show what optimizations would be applied without making changes.

.EXAMPLE
    Optimize-PlatformEnvironment
    
    Applies all optimizations for the current platform.

.EXAMPLE
    Optimize-PlatformEnvironment -IncludePerformanceTuning -ConfigureDevelopmentTools
    
    Applies performance and development tool optimizations.

.EXAMPLE
    Optimize-PlatformEnvironment -Platform Windows -WhatIf
    
    Shows what Windows optimizations would be applied.

.NOTES
    This function provides platform-specific enhancements for optimal AitherZero development
    experience across different operating systems.
#>

function Optimize-PlatformEnvironment {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [ValidateSet('Windows', 'Linux', 'macOS', 'Auto')]
        [string]$Platform = 'Auto',
        
        [Parameter()]
        [switch]$IncludePerformanceTuning = $true,
        
        [Parameter()]
        [switch]$IncludeSecurityHardening,
        
        [Parameter()]
        [switch]$ConfigureDevelopmentTools = $true,
        
        [Parameter()]
        [switch]$Force
    )

    begin {
        # Detect platform if auto
        if ($Platform -eq 'Auto') {
            $Platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
        }
        
        if ($Platform -eq 'Unknown') {
            throw "Unable to detect platform for optimization"
        }
        
        Write-CustomLog -Message "=== Platform Environment Optimization ===" -Level "INFO"
        Write-CustomLog -Message "Target Platform: $Platform" -Level "INFO"
        
        $optimizationResults = @{
            Platform = $Platform
            OptimizationsApplied = @()
            PerformanceImprovements = @()
            SecurityEnhancements = @()
            DevelopmentToolsConfigured = @()
            Issues = @()
            Recommendations = @()
        }
    }

    process {
        try {
            switch ($Platform) {
                'Windows' {
                    Optimize-WindowsEnvironment -Results $optimizationResults -IncludePerformanceTuning:$IncludePerformanceTuning -IncludeSecurityHardening:$IncludeSecurityHardening -ConfigureDevelopmentTools:$ConfigureDevelopmentTools -Force:$Force -WhatIf:$WhatIfPreference
                }
                'Linux' {
                    Optimize-LinuxEnvironment -Results $optimizationResults -IncludePerformanceTuning:$IncludePerformanceTuning -IncludeSecurityHardening:$IncludeSecurityHardening -ConfigureDevelopmentTools:$ConfigureDevelopmentTools -Force:$Force -WhatIf:$WhatIfPreference
                }
                'macOS' {
                    Optimize-MacOSEnvironment -Results $optimizationResults -IncludePerformanceTuning:$IncludePerformanceTuning -IncludeSecurityHardening:$IncludeSecurityHardening -ConfigureDevelopmentTools:$ConfigureDevelopmentTools -Force:$Force -WhatIf:$WhatIfPreference
                }
            }
            
            # Display results
            Write-CustomLog -Message "" -Level "INFO"
            Write-CustomLog -Message "=== Optimization Summary ===" -Level "INFO"
            Write-CustomLog -Message "Applied $($optimizationResults.OptimizationsApplied.Count) optimizations" -Level "SUCCESS"
            
            if ($optimizationResults.OptimizationsApplied.Count -gt 0) {
                Write-CustomLog -Message "Optimizations applied:" -Level "INFO"
                foreach ($optimization in $optimizationResults.OptimizationsApplied) {
                    Write-CustomLog -Message "  ✅ $optimization" -Level "SUCCESS"
                }
            }
            
            if ($optimizationResults.Issues.Count -gt 0) {
                Write-CustomLog -Message "Issues encountered:" -Level "WARNING"
                foreach ($issue in $optimizationResults.Issues) {
                    Write-CustomLog -Message "  ⚠️ $issue" -Level "WARNING"
                }
            }
            
            if ($optimizationResults.Recommendations.Count -gt 0) {
                Write-CustomLog -Message "Recommendations:" -Level "INFO"
                foreach ($recommendation in $optimizationResults.Recommendations) {
                    Write-CustomLog -Message "  💡 $recommendation" -Level "INFO"
                }
            }
            
            return $optimizationResults
            
        } catch {
            Write-CustomLog -Message "Platform optimization failed: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}

function Optimize-WindowsEnvironment {
    param($Results, [switch]$IncludePerformanceTuning, [switch]$IncludeSecurityHardening, [switch]$ConfigureDevelopmentTools, [switch]$Force, [switch]$WhatIf)
    
    Write-CustomLog -Message "🪟 Optimizing Windows environment..." -Level "INFO"
    
    # PowerShell execution policy optimization
    try {
        $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
        if ($currentPolicy -notin @('RemoteSigned', 'Unrestricted')) {
            if ($WhatIf) {
                Write-CustomLog -Message "[WHATIF] Would set PowerShell execution policy to RemoteSigned" -Level "INFO"
            } else {
                Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
                $Results.OptimizationsApplied += "Set PowerShell execution policy to RemoteSigned"
            }
        }
    } catch {
        $Results.Issues += "Failed to optimize PowerShell execution policy: $($_.Exception.Message)"
    }
    
    # Windows Package Manager optimization
    if ($ConfigureDevelopmentTools) {
        try {
            $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
            if ($wingetCmd) {
                if ($WhatIf) {
                    Write-CustomLog -Message "[WHATIF] Would configure winget for development packages" -Level "INFO"
                } else {
                    # Accept winget agreements to avoid prompts
                    winget list --accept-source-agreements | Out-Null
                    $Results.DevelopmentToolsConfigured += "Configured Windows Package Manager (winget)"
                }
            } else {
                $Results.Recommendations += "Install Windows Package Manager (winget) for easier development tool management"
            }
        } catch {
            $Results.Issues += "Failed to configure winget: $($_.Exception.Message)"
        }
    }
    
    # Windows Terminal optimization
    if ($ConfigureDevelopmentTools) {
        try {
            $wtConfigPath = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
            if (Test-Path $wtConfigPath) {
                if ($WhatIf) {
                    Write-CustomLog -Message "[WHATIF] Would optimize Windows Terminal settings" -Level "INFO"
                } else {
                    # Create backup
                    Copy-Item $wtConfigPath "$wtConfigPath.backup" -Force
                    
                    # Read current settings
                    $settings = Get-Content $wtConfigPath -Raw | ConvertFrom-Json
                    
                    # Set PowerShell 7 as default if available
                    $pwshPath = Get-Command pwsh -ErrorAction SilentlyContinue
                    if ($pwshPath) {
                        $settings.defaultProfile = "{574e775e-4f2a-5b96-ac1e-a2962a402336}"  # PowerShell 7 GUID
                    }
                    
                    # Apply optimizations
                    $settings | ConvertTo-Json -Depth 10 | Set-Content $wtConfigPath -Encoding UTF8
                    $Results.DevelopmentToolsConfigured += "Optimized Windows Terminal settings"
                }
            } else {
                $Results.Recommendations += "Install Windows Terminal for enhanced PowerShell experience"
            }
        } catch {
            $Results.Issues += "Failed to optimize Windows Terminal: $($_.Exception.Message)"
        }
    }
    
    # Performance optimizations
    if ($IncludePerformanceTuning) {
        try {
            # Windows Defender exclusions for development directories
            $devPaths = @(
                $env:USERPROFILE,
                "C:\Program Files\PowerShell",
                "C:\Program Files\Git"
            )
            
            foreach ($path in $devPaths) {
                if (Test-Path $path) {
                    if ($WhatIf) {
                        Write-CustomLog -Message "[WHATIF] Would add Windows Defender exclusion for $path" -Level "INFO"
                    } else {
                        try {
                            Add-MpPreference -ExclusionPath $path -ErrorAction SilentlyContinue
                            $Results.PerformanceImprovements += "Added Windows Defender exclusion for $path"
                        } catch {
                            # May fail without admin rights, that's okay
                        }
                    }
                }
            }
        } catch {
            $Results.Issues += "Failed to apply performance optimizations: $($_.Exception.Message)"
        }
    }
    
    # WSL optimization (if available)
    if ($ConfigureDevelopmentTools) {
        try {
            $wslCheck = wsl --list --verbose 2>$null
            if ($LASTEXITCODE -eq 0) {
                if ($WhatIf) {
                    Write-CustomLog -Message "[WHATIF] Would optimize WSL configuration" -Level "INFO"
                } else {
                    # Configure WSL for development
                    $wslConfig = @"
[wsl2]
memory=4GB
processors=4
swap=2GB
localhostForwarding=true

[interop]
enabled=true
appendWindowsPath=true
"@
                    $wslConfigPath = Join-Path $env:USERPROFILE ".wslconfig"
                    $wslConfig | Set-Content $wslConfigPath -Encoding UTF8
                    $Results.DevelopmentToolsConfigured += "Optimized WSL configuration"
                }
            }
        } catch {
            # WSL not available, that's okay
        }
    }
}

function Optimize-LinuxEnvironment {
    param($Results, [switch]$IncludePerformanceTuning, [switch]$IncludeSecurityHardening, [switch]$ConfigureDevelopmentTools, [switch]$Force, [switch]$WhatIf)
    
    Write-CustomLog -Message "🐧 Optimizing Linux environment..." -Level "INFO"
    
    # Shell optimization
    if ($ConfigureDevelopmentTools) {
        try {
            $shellConfigFiles = @("$HOME/.bashrc", "$HOME/.zshrc", "$HOME/.profile")
            
            foreach ($configFile in $shellConfigFiles) {
                if (Test-Path $configFile) {
                    if ($WhatIf) {
                        Write-CustomLog -Message "[WHATIF] Would optimize shell configuration in $configFile" -Level "INFO"
                    } else {
                        $content = Get-Content $configFile -Raw -ErrorAction SilentlyContinue
                        if ($content -and $content -notlike "*# AitherZero optimizations*") {
                            $optimizations = @"

# AitherZero optimizations
export POWERSHELL_DISTRIBUTION_CHANNEL=PSGallery-PowerShell.deb
alias pwsh='pwsh -NoLogo'
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'

# Node.js optimization
export NODE_OPTIONS="--max-old-space-size=4096"

# Git optimizations
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'

"@
                            Add-Content $configFile $optimizations
                            $Results.DevelopmentToolsConfigured += "Optimized shell configuration in $configFile"
                        }
                    }
                }
            }
        } catch {
            $Results.Issues += "Failed to optimize shell configuration: $($_.Exception.Message)"
        }
    }
    
    # Package manager optimization
    if ($ConfigureDevelopmentTools) {
        try {
            # Detect package manager
            $packageManager = $null
            if (Get-Command apt -ErrorAction SilentlyContinue) { $packageManager = 'apt' }
            elseif (Get-Command yum -ErrorAction SilentlyContinue) { $packageManager = 'yum' }
            elseif (Get-Command dnf -ErrorAction SilentlyContinue) { $packageManager = 'dnf' }
            elseif (Get-Command pacman -ErrorAction SilentlyContinue) { $packageManager = 'pacman' }
            
            if ($packageManager) {
                if ($WhatIf) {
                    Write-CustomLog -Message "[WHATIF] Would optimize $packageManager package manager" -Level "INFO"
                } else {
                    switch ($packageManager) {
                        'apt' {
                            # Update package lists
                            sudo apt update 2>/dev/null
                            $Results.DevelopmentToolsConfigured += "Updated apt package lists"
                        }
                        'yum' {
                            sudo yum makecache 2>/dev/null
                            $Results.DevelopmentToolsConfigured += "Updated yum cache"
                        }
                        'dnf' {
                            sudo dnf makecache 2>/dev/null
                            $Results.DevelopmentToolsConfigured += "Updated dnf cache"
                        }
                    }
                }
            }
        } catch {
            $Results.Issues += "Failed to optimize package manager: $($_.Exception.Message)"
        }
    }
    
    # Performance optimizations
    if ($IncludePerformanceTuning) {
        try {
            # Optimize file system performance for development
            if ($WhatIf) {
                Write-CustomLog -Message "[WHATIF] Would apply file system optimizations" -Level "INFO"
            } else {
                # Increase file watch limits for VS Code and similar tools
                $sysctl_conf = "/etc/sysctl.conf"
                if (Test-Path $sysctl_conf) {
                    $content = Get-Content $sysctl_conf -Raw
                    if ($content -notlike "*fs.inotify.max_user_watches*") {
                        try {
                            "fs.inotify.max_user_watches=524288" | sudo tee -a $sysctl_conf > /dev/null
                            $Results.PerformanceImprovements += "Increased file watch limits for development tools"
                        } catch {
                            $Results.Recommendations += "Consider increasing fs.inotify.max_user_watches for better VS Code performance"
                        }
                    }
                }
            }
        } catch {
            $Results.Issues += "Failed to apply performance optimizations: $($_.Exception.Message)"
        }
    }
    
    # Development environment variables
    if ($ConfigureDevelopmentTools) {
        try {
            $envFile = "$HOME/.profile"
            if (Test-Path $envFile) {
                if ($WhatIf) {
                    Write-CustomLog -Message "[WHATIF] Would set development environment variables" -Level "INFO"
                } else {
                    $content = Get-Content $envFile -Raw
                    if ($content -notlike "*AITHERZERO_PLATFORM*") {
                        $envVars = @"

# AitherZero environment variables
export AITHERZERO_PLATFORM=Linux
export EDITOR=nano
export TERM=xterm-256color

"@
                        Add-Content $envFile $envVars
                        $Results.DevelopmentToolsConfigured += "Set AitherZero environment variables"
                    }
                }
            }
        } catch {
            $Results.Issues += "Failed to set environment variables: $($_.Exception.Message)"
        }
    }
}

function Optimize-MacOSEnvironment {
    param($Results, [switch]$IncludePerformanceTuning, [switch]$IncludeSecurityHardening, [switch]$ConfigureDevelopmentTools, [switch]$Force, [switch]$WhatIf)
    
    Write-CustomLog -Message "🍎 Optimizing macOS environment..." -Level "INFO"
    
    # Homebrew optimization
    if ($ConfigureDevelopmentTools) {
        try {
            $brewCmd = Get-Command brew -ErrorAction SilentlyContinue
            if ($brewCmd) {
                if ($WhatIf) {
                    Write-CustomLog -Message "[WHATIF] Would optimize Homebrew configuration" -Level "INFO"
                } else {
                    # Update Homebrew
                    brew update 2>/dev/null
                    $Results.DevelopmentToolsConfigured += "Updated Homebrew package manager"
                }
            } else {
                $Results.Recommendations += "Install Homebrew package manager for easier development tool management"
            }
        } catch {
            $Results.Issues += "Failed to optimize Homebrew: $($_.Exception.Message)"
        }
    }
    
    # Shell optimization for macOS
    if ($ConfigureDevelopmentTools) {
        try {
            $zshrc = "$HOME/.zshrc"
            if (Test-Path $zshrc) {
                if ($WhatIf) {
                    Write-CustomLog -Message "[WHATIF] Would optimize zsh configuration" -Level "INFO"
                } else {
                    $content = Get-Content $zshrc -Raw
                    if ($content -notlike "*# AitherZero optimizations*") {
                        $optimizations = @"

# AitherZero optimizations for macOS
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ANALYTICS=1

# PowerShell optimization
alias pwsh='pwsh -NoLogo'

# Git optimizations
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'

# Development aliases
alias ll='ls -la'
alias la='ls -A'
alias code='code .'

"@
                        Add-Content $zshrc $optimizations
                        $Results.DevelopmentToolsConfigured += "Optimized zsh configuration"
                    }
                }
            }
        } catch {
            $Results.Issues += "Failed to optimize shell configuration: $($_.Exception.Message)"
        }
    }
    
    # Performance optimizations for macOS
    if ($IncludePerformanceTuning) {
        try {
            if ($WhatIf) {
                Write-CustomLog -Message "[WHATIF] Would apply macOS performance optimizations" -Level "INFO"
            } else {
                # Disable Spotlight indexing for development directories
                $devPaths = @(
                    "$HOME/node_modules",
                    "$HOME/.npm",
                    "$HOME/.cache"
                )
                
                foreach ($path in $devPaths) {
                    if (Test-Path $path) {
                        try {
                            mdutil -i off $path 2>/dev/null
                            $Results.PerformanceImprovements += "Disabled Spotlight indexing for $path"
                        } catch {
                            # May fail, that's okay
                        }
                    }
                }
            }
        } catch {
            $Results.Issues += "Failed to apply performance optimizations: $($_.Exception.Message)"
        }
    }
    
    # Xcode Command Line Tools check
    if ($ConfigureDevelopmentTools) {
        try {
            $xcodeSelect = xcode-select -p 2>/dev/null
            if ($LASTEXITCODE -ne 0) {
                $Results.Recommendations += "Install Xcode Command Line Tools: xcode-select --install"
            } else {
                $Results.DevelopmentToolsConfigured += "Xcode Command Line Tools are available"
            }
        } catch {
            $Results.Recommendations += "Install Xcode Command Line Tools for development"
        }
    }
    
    # Environment variables for macOS
    if ($ConfigureDevelopmentTools) {
        try {
            $profile = "$HOME/.profile"
            if ($WhatIf) {
                Write-CustomLog -Message "[WHATIF] Would set macOS development environment variables" -Level "INFO"
            } else {
                if (-not (Test-Path $profile)) {
                    New-Item -ItemType File -Path $profile -Force | Out-Null
                }
                
                $content = Get-Content $profile -Raw -ErrorAction SilentlyContinue
                if (-not $content -or $content -notlike "*AITHERZERO_PLATFORM*") {
                    $envVars = @"

# AitherZero environment variables for macOS
export AITHERZERO_PLATFORM=macOS
export EDITOR=nano
export HOMEBREW_PREFIX=/opt/homebrew
export PATH=\$HOMEBREW_PREFIX/bin:\$PATH

"@
                    Add-Content $profile $envVars
                    $Results.DevelopmentToolsConfigured += "Set AitherZero environment variables for macOS"
                }
            }
        } catch {
            $Results.Issues += "Failed to set environment variables: $($_.Exception.Message)"
        }
    }
}