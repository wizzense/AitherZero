#!/usr/bin/env pwsh
#requires -version 7

<#
.SYNOPSIS
    Configure GitHub Actions Runner Environment
.DESCRIPTION
    Configures the environment for GitHub Actions self-hosted runners with all necessary dependencies
.PARAMETER Profile
    Environment profile: Minimal, Standard, Developer, Full (default: Standard)
.PARAMETER Platform
    Target platform: Windows, Linux, macOS, Auto (default: Auto)
.PARAMETER RunnerUser
    User account for runner service (default: current user)
.PARAMETER InstallDependencies
    Automatically install missing dependencies (default: true)
.PARAMETER ConfigurePowerShell
    Configure PowerShell for runner use (default: true)
.PARAMETER SetupTools
    Install development tools (Git, Node, Python, etc.)
.PARAMETER DryRun
    Validate configuration without making changes
.PARAMETER CI
    Run in CI mode with minimal output
.EXAMPLE
    ./0721_Configure-RunnerEnvironment.ps1 -Profile Developer
.EXAMPLE
    ./0721_Configure-RunnerEnvironment.ps1 -Platform Linux -SetupTools
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Minimal', 'Standard', 'Developer', 'Full')]
    [string]$ProfileName = 'Standard',
    [ValidateSet('Windows', 'Linux', 'macOS', 'Auto')]
    [string]$Platform = 'Auto',
    [string]$RunnerUser = $env:USER,
    [bool]$InstallDependencies = $true,
    [bool]$ConfigurePowerShell = $true,
    [switch]$SetupTools,
    [switch]$DryRun,
    [switch]$CI
)

#region Metadata
$script:Stage = "Infrastructure"
$script:Dependencies = @('0720')
$script:Tags = @('github', 'runners', 'environment', 'dependencies')
$script:Condition = '(Get-Command pwsh -ErrorAction SilentlyContinue) -and $PSVersionTable.PSVersion.Major -ge 7'
#endregion

# Import required modules and functions
if (Test-Path "$PSScriptRoot/../domains/core/Logging.psm1") {
    Import-Module "$PSScriptRoot/../domains/core/Logging.psm1" -Force
}

function Write-RunnerLog {
    param([string]$Message, [string]$Level = 'Information')
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level -Source "RunnerEnvironment"
    } else {
        Write-Host "[$Level] $Message"
    }
}

function Get-TargetPlatform {
    if ($Platform -eq 'Auto') {
        if ($IsWindows) { return 'Windows' }
        elseif ($IsLinux) { return 'Linux' }
        elseif ($IsMacOS) { return 'macOS' }
        else { return 'Linux' }
    }
    return $Platform
}

function Get-ProfileConfiguration {
    param([string]$ProfileNameName)
    
    $ProfileNames = @{
        'Minimal' = @{
            Tools = @('PowerShell7', 'Git')
            Modules = @('ThreadJob')
            Features = @('BasicLogging')
        }
        'Standard' = @{
            Tools = @('PowerShell7', 'Git', 'Node')
            Modules = @('ThreadJob', 'Pester', 'PSScriptAnalyzer')
            Features = @('BasicLogging', 'TestingFramework')
        }
        'Developer' = @{
            Tools = @('PowerShell7', 'Git', 'Node', 'Python', 'VSCode', 'Docker')
            Modules = @('ThreadJob', 'Pester', 'PSScriptAnalyzer', 'platyPS')
            Features = @('FullLogging', 'TestingFramework', 'CodeAnalysis', 'Documentation')
        }
        'Full' = @{
            Tools = @('PowerShell7', 'Git', 'Node', 'Python', 'VSCode', 'Docker', 'AzureCLI', 'AWSCLI', 'OpenTofu', 'Packer')
            Modules = @('ThreadJob', 'Pester', 'PSScriptAnalyzer', 'platyPS', 'Microsoft.Graph')
            Features = @('FullLogging', 'TestingFramework', 'CodeAnalysis', 'Documentation', 'CloudTools', 'Infrastructure')
        }
    }
    
    return $ProfileNames[$ProfileNameName]
}

function Test-RunnerEnvironment {
    Write-RunnerLog "Testing runner environment..." -Level Information
    
    $issues = @()
    $targetPlatform = Get-TargetPlatform
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        $issues += "PowerShell 7+ required (current: $($PSVersionTable.PSVersion))"
    }
    
    # Check Git
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $issues += "Git is not installed or not in PATH"
    }
    
    # Platform-specific checks
    switch ($targetPlatform) {
        'Windows' {
            # Check Windows-specific requirements
            if (-not $env:PROCESSOR_ARCHITECTURE) {
                $issues += "PROCESSOR_ARCHITECTURE environment variable not set"
            }
        }
        'Linux' {
            # Check Linux-specific requirements
            if (-not (Get-Command which -ErrorAction SilentlyContinue)) {
                $issues += "which command not available"
            }
        }
        'macOS' {
            # Check macOS-specific requirements
            if (-not (Get-Command which -ErrorAction SilentlyContinue)) {
                $issues += "which command not available"
            }
        }
    }
    
    if ($issues.Count -gt 0) {
        Write-RunnerLog "Environment issues found:" -Level Warning
        $issues | ForEach-Object { Write-RunnerLog "  - $_" -Level Warning }
        return $false
    }
    
    Write-RunnerLog "Environment validation passed" -Level Success
    return $true
}

function Install-RequiredTools {
    param(
        [string[]]$Tools,
        [string]$TargetPlatform
    )
    
    Write-RunnerLog "Installing required tools for $ProfileName profile..." -Level Information
    
    foreach ($tool in $Tools) {
        Write-RunnerLog "Checking tool: $tool" -Level Information
        
        $installScript = $null
        $isInstalled = $false
        
        switch ($tool) {
            'PowerShell7' {
                $isInstalled = (Get-Command pwsh -ErrorAction SilentlyContinue) -and ($PSVersionTable.PSVersion.Major -ge 7)
                $installScript = '0001'
            }
            'Git' {
                $isInstalled = Get-Command git -ErrorAction SilentlyContinue
                $installScript = '0207'
            }
            'Node' {
                $isInstalled = Get-Command node -ErrorAction SilentlyContinue
                $installScript = '0201'
            }
            'Python' {
                $isInstalled = (Get-Command python -ErrorAction SilentlyContinue) -or (Get-Command python3 -ErrorAction SilentlyContinue)
                $installScript = '0206'
            }
            'VSCode' {
                $isInstalled = Get-Command code -ErrorAction SilentlyContinue
                $installScript = '0210'
            }
            'Docker' {
                $isInstalled = Get-Command docker -ErrorAction SilentlyContinue
                $installScript = '0208'
            }
            'AzureCLI' {
                $isInstalled = Get-Command az -ErrorAction SilentlyContinue
                $installScript = '0212'
            }
            'AWSCLI' {
                $isInstalled = Get-Command aws -ErrorAction SilentlyContinue
                $installScript = '0213'
            }
            'OpenTofu' {
                $isInstalled = Get-Command tofu -ErrorAction SilentlyContinue
                $installScript = '0008'
            }
            'Packer' {
                $isInstalled = Get-Command packer -ErrorAction SilentlyContinue
                $installScript = '0214'
            }
        }
        
        if ($isInstalled) {
            Write-RunnerLog "✓ $tool is already installed" -Level Success
            continue
        }
        
        if (-not $InstallDependencies) {
            Write-RunnerLog "⚠ $tool is not installed (use -InstallDependencies to install)" -Level Warning
            continue
        }
        
        if ($installScript -and (Test-Path "$PSScriptRoot/$installScript*.ps1")) {
            Write-RunnerLog "Installing $tool..." -Level Information
            
            if ($DryRun) {
                Write-RunnerLog "[DRY RUN] Would install $tool using script $installScript" -Level Information
                continue
            }
            
            try {
                $scriptPath = Get-ChildItem "$PSScriptRoot/$installScript*.ps1" | Select-Object -First 1
                & $scriptPath.FullName -CI:$CI
                
                if ($LASTEXITCODE -eq 0) {
                    Write-RunnerLog "✓ $tool installed successfully" -Level Success
                } else {
                    Write-RunnerLog "✗ Failed to install $tool (exit code: $LASTEXITCODE)" -Level Warning
                }
            } catch {
                Write-RunnerLog "Failed to install ${tool}: $($_.Exception.Message)" -Level Warning
            }
        } else {
            Write-RunnerLog "⚠ No installation script available for $tool" -Level Warning
        }
    }
}

function Install-PowerShellModules {
    param([string[]]$Modules)
    
    Write-RunnerLog "Installing PowerShell modules..." -Level Information
    
    # Ensure PSGallery is trusted
    if (-not $DryRun) {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    }
    
    foreach ($module in $Modules) {
        Write-RunnerLog "Checking module: $module" -Level Information
        
        $installed = Get-Module -ListAvailable -Name $module -ErrorAction SilentlyContinue
        if ($installed) {
            Write-RunnerLog "✓ $module is already installed (version: $($installed.Version -join ', '))" -Level Success
            continue
        }
        
        if ($DryRun) {
            Write-RunnerLog "[DRY RUN] Would install module $module" -Level Information
            continue
        }
        
        try {
            Write-RunnerLog "Installing module $module..." -Level Information
            Install-Module -Name $module -Force -SkipPublisherCheck -AllowClobber -ErrorAction Stop
            Write-RunnerLog "✓ $module installed successfully" -Level Success
        } catch {
            Write-RunnerLog "Failed to install module ${module}: $($_.Exception.Message)" -Level Warning
        }
    }
}

function Set-RunnerEnvironmentVariables {
    param([string]$TargetPlatform)
    
    Write-RunnerLog "Setting runner environment variables..." -Level Information
    
    $envVars = @{
        'AITHERZERO_RUNNER' = 'true'
        'AITHERZERO_PLATFORM' = $TargetPlatform
        'AITHERZERO_PROFILE' = $ProfileName
        'CI' = 'true'
        'RUNNER_ENVIRONMENT' = 'GitHub-Actions'
    }
    
    # Add platform-specific variables
    switch ($TargetPlatform) {
        'Windows' {
            $envVars['RUNNER_OS'] = 'Windows'
            $envVars['RUNNER_ARCH'] = if ([Environment]::Is64BitOperatingSystem) { 'X64' } else { 'X86' }
        }
        'Linux' {
            $envVars['RUNNER_OS'] = 'Linux'
            $envVars['RUNNER_ARCH'] = & uname -m
        }
        'macOS' {
            $envVars['RUNNER_OS'] = 'macOS'
            $envVars['RUNNER_ARCH'] = & uname -m
        }
    }
    
    foreach ($key in $envVars.Keys) {
        $value = $envVars[$key]
        Write-RunnerLog "Setting $key = $value" -Level Information
        
        if ($DryRun) {
            Write-RunnerLog "[DRY RUN] Would set environment variable $key = $value" -Level Information
            continue
        }
        
        # Set for current session
        [Environment]::SetEnvironmentVariable($key, $value, 'Process')
        
        # Set persistently
        if ($IsWindows) {
            [Environment]::SetEnvironmentVariable($key, $value, 'Machine')
        } else {
            # Add to shell profiles
            $ProfileNameFiles = @('~/.bashrc', '~/.zshrc', '~/.profile')
            foreach ($ProfileNameFile in $ProfileNameFiles) {
                $expandedPath = [Environment]::ExpandEnvironmentVariables($ProfileNameFile)
                if (Test-Path $expandedPath) {
                    $exportLine = "export $key='$value'"
                    $content = Get-Content $expandedPath -Raw -ErrorAction SilentlyContinue
                    if ($content -notlike "*export $key=*") {
                        Add-Content -Path $expandedPath -Value $exportLine
                        Write-RunnerLog "Added to $ProfileNameFile" -Level Information
                    }
                }
            }
        }
    }
}

function Configure-RunnerSecurity {
    param([string]$TargetPlatform)
    
    Write-RunnerLog "Configuring runner security settings..." -Level Information
    
    if ($DryRun) {
        Write-RunnerLog "[DRY RUN] Would configure security settings" -Level Information
        return
    }
    
    switch ($TargetPlatform) {
        'Windows' {
            # Configure Windows security
            try {
                # Set execution policy for runner
                Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
                Write-RunnerLog "✓ Set PowerShell execution policy to RemoteSigned" -Level Success
                
                # Configure Windows Defender exclusions for runner directories
                $runnerDirs = @(
                    "$env:ProgramFiles\GitHub-Runner",
                    "$env:RUNNER_TOOL_CACHE",
                    "C:\hostedtoolcache"
                )
                
                foreach ($dir in $runnerDirs) {
                    if ($dir -and (Test-Path $dir)) {
                        Add-MpPreference -ExclusionPath $dir -ErrorAction SilentlyContinue
                        Write-RunnerLog "Added Windows Defender exclusion: $dir" -Level Information
                    }
                }
                
            } catch {
                Write-RunnerLog "Warning: Could not configure all security settings: $($_.Exception.Message)" -Level Warning
            }
        }
        'Linux' {
            # Configure Linux security
            try {
                # Ensure runner user has necessary permissions
                if ($RunnerUser -ne 'root') {
                    & sudo usermod -aG docker $RunnerUser 2>$null
                    Write-RunnerLog "Added $RunnerUser to docker group" -Level Information
                }
            } catch {
                Write-RunnerLog "Warning: Could not configure user permissions: $($_.Exception.Message)" -Level Warning
            }
        }
    }
}

function Test-RunnerConfiguration {
    Write-RunnerLog "Testing runner configuration..." -Level Information
    
    $tests = @(
        @{
            Name = 'PowerShell Version'
            Test = { $PSVersionTable.PSVersion.Major -ge 7 }
            Expected = 'PowerShell 7+'
        },
        @{
            Name = 'Git Availability'
            Test = { Get-Command git -ErrorAction SilentlyContinue }
            Expected = 'Git command available'
        },
        @{
            Name = 'Environment Variables'
            Test = { $env:AITHERZERO_RUNNER -eq 'true' }
            Expected = 'Runner environment variables set'
        }
    )
    
    $passed = 0
    $total = $tests.Count
    
    foreach ($test in $tests) {
        try {
            $result = & $test.Test
            if ($result) {
                Write-RunnerLog "✓ $($test.Name): Passed" -Level Success
                $passed++
            } else {
                Write-RunnerLog "✗ $($test.Name): Failed - $($test.Expected)" -Level Warning
            }
        } catch {
            Write-RunnerLog "✗ $($test.Name): Error - $($_.Exception.Message)" -Level Warning
        }
    }
    
    Write-RunnerLog "Configuration test results: $passed/$total passed" -Level Information
    return $passed -eq $total
}

# Main execution
try {
    $targetPlatform = Get-TargetPlatform
    
    Write-RunnerLog "Configuring GitHub Actions runner environment..." -Level Information
    Write-RunnerLog "Profile: $ProfileName" -Level Information
    Write-RunnerLog "Platform: $targetPlatform" -Level Information
    Write-RunnerLog "Runner User: $RunnerUser" -Level Information
    
    if ($DryRun) {
        Write-RunnerLog "Running in DRY RUN mode - no changes will be made" -Level Warning
    }
    
    # Test current environment
    if (-not (Test-RunnerEnvironment)) {
        if ($InstallDependencies) {
            Write-RunnerLog "Attempting to fix environment issues..." -Level Information
        } else {
            Write-RunnerLog "Environment issues found. Use -InstallDependencies to fix automatically." -Level Warning
        }
    }
    
    # Get profile configuration
    $ProfileNameConfig = Get-ProfileConfiguration -ProfileName $ProfileName
    
    # Install required tools
    if ($ProfileNameConfig.Tools) {
        Install-RequiredTools -Tools $ProfileNameConfig.Tools -TargetPlatform $targetPlatform
    }
    
    # Install PowerShell modules
    if ($ProfileNameConfig.Modules) {
        Install-PowerShellModules -Modules $ProfileNameConfig.Modules
    }
    
    # Set environment variables
    Set-RunnerEnvironmentVariables -TargetPlatform $targetPlatform
    
    # Configure security
    Configure-RunnerSecurity -TargetPlatform $targetPlatform
    
    # Final configuration test
    if (-not $DryRun) {
        Start-Sleep -Seconds 2
        $configSuccess = Test-RunnerConfiguration
        
        if ($configSuccess) {
            Write-RunnerLog "Runner environment configured successfully!" -Level Success
        } else {
            Write-RunnerLog "Runner environment configured with some issues" -Level Warning
        }
    }
    
    if (-not $CI) {
        Write-Host "`nRunner environment setup complete!" -ForegroundColor Green
        Write-Host "Profile: $ProfileName" -ForegroundColor Cyan
        Write-Host "Platform: $targetPlatform" -ForegroundColor Cyan
        
        Write-Host "`nNext steps:" -ForegroundColor Yellow
        Write-Host "1. Test the runner with a simple workflow" -ForegroundColor White
        Write-Host "2. Run 'az 0722' to install additional runner services" -ForegroundColor White
        Write-Host "3. Monitor runner performance in GitHub Actions" -ForegroundColor White
    }
    
    exit 0
    
} catch {
    Write-RunnerLog "Runner environment configuration failed: $($_.Exception.Message)" -Level Error
    exit 1
}
