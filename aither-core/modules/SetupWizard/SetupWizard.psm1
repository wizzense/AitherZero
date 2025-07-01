# AitherZero Intelligent Setup Wizard Module
# Provides enhanced first-time setup experience with progress tracking

function Start-IntelligentSetup {
    <#
    .SYNOPSIS
        Intelligent setup wizard for AitherZero with auto-detection and installation profiles
    .DESCRIPTION
        Provides a guided setup experience with:
        - Platform detection
        - Installation profiles (minimal, developer, full)
        - AI tools integration
        - Dependency checking
        - Configuration templates
        - Progress tracking
    #>
    [CmdletBinding()]
    param(
        [switch]$SkipOptional,
        [switch]$MinimalSetup,
        [string]$ConfigPath,
        [ValidateSet('minimal', 'developer', 'full', 'interactive')]
        [string]$InstallationProfile = 'interactive'
    )
    
    # Initialize setup state
    $setupState = @{
        StartTime = Get-Date
        Platform = Get-PlatformInfo
        InstallationProfile = $InstallationProfile
        Steps = @()
        CurrentStep = 0
        TotalSteps = 12
        Errors = @()
        Warnings = @()
        Recommendations = @()
        AIToolsToInstall = @()
    }
    
    # Determine installation profile if interactive
    if ($InstallationProfile -eq 'interactive') {
        $setupState.InstallationProfile = Get-InstallationProfile
    }
    
    # Override for legacy parameter
    if ($MinimalSetup) {
        $setupState.InstallationProfile = 'minimal'
    }
    
    # Display welcome
    Show-WelcomeMessage -SetupState $setupState
    
    # Check if progress tracking is available
    $progressAvailable = Get-Module -Name 'ProgressTracking' -ListAvailable
    if ($progressAvailable) {
        Import-Module ProgressTracking -Force -ErrorAction SilentlyContinue
    }
    
    # Create progress operation if available
    if (Get-Command Start-ProgressOperation -ErrorAction SilentlyContinue) {
        $progressId = Start-ProgressOperation `
            -OperationName "AitherZero Intelligent Setup" `
            -TotalSteps $setupState.TotalSteps `
            -ShowTime `
            -ShowETA
    }
    Show-SetupBanner
    
    # Run setup steps based on profile
    $setupSteps = Get-SetupSteps -Profile $setupState.InstallationProfile
    
    # Show profile information
    Show-InstallationProfile -Profile $setupState.InstallationProfile
    
    $setupState.TotalSteps = $setupSteps.Count
    
    foreach ($step in $setupSteps) {
        $setupState.CurrentStep++
        Show-Progress -State $setupState -StepName $step.Name
        
        try {
            $result = & $step.Function -SetupState $setupState
            $setupState.Steps += $result
            
            if ($result.Status -eq 'Failed' -and -not $SkipOptional) {
                if (-not (Show-SetupPrompt -Message "Step failed. Continue anyway?" -DefaultYes)) {
                    Write-Host "`n❌ Setup cancelled by user" -ForegroundColor Red
                    return $setupState
                }
            }
        } catch {
            $setupState.Errors += "Error in $($step.Name): $_"
            Write-Host "❌ Error: $_" -ForegroundColor Red
        }
        
        Start-Sleep -Milliseconds 500  # Brief pause for visual feedback
    }
    
    # Show summary
    Show-SetupSummary -State $setupState
    
    return $setupState
}

function Get-PlatformInfo {
    @{
        OS = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
        Version = if ($IsWindows) { 
            [System.Environment]::OSVersion.Version.ToString() 
        } elseif ($IsLinux) {
            if (Test-Path /etc/os-release) {
                (Get-Content /etc/os-release | Select-String '^VERSION=' | ForEach-Object { $_.ToString().Split('=')[1].Trim('"') })
            }
        } elseif ($IsMacOS) {
            sw_vers -productVersion
        }
        Architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
        PowerShell = $PSVersionTable.PSVersion.ToString()
    }
}

function Show-SetupBanner {
    Clear-Host
    Write-Host ""
    Write-Host "    ╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "    ║          AitherZero Intelligent Setup Wizard          ║" -ForegroundColor Cyan
    Write-Host "    ║                    Version 2.0                        ║" -ForegroundColor Cyan
    Write-Host "    ╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    Welcome! This wizard will help you set up AitherZero" -ForegroundColor White
    Write-Host "    for optimal performance on your system." -ForegroundColor White
    Write-Host ""
}

function Show-Progress {
    param(
        $State,
        [string]$StepName
    )
    
    $percentage = [math]::Round(($State.CurrentStep / $State.TotalSteps) * 100)
    $progressBar = "[" + ("█" * [math]::Floor($percentage / 5)) + ("░" * (20 - [math]::Floor($percentage / 5))) + "]"
    
    Write-Host ""
    Write-Host "  $progressBar $percentage% - Step $($State.CurrentStep)/$($State.TotalSteps)" -ForegroundColor Cyan
    Write-Host "  🔍 $StepName..." -ForegroundColor Yellow
}

function Test-PlatformRequirements {
    param($SetupState)
    
    $result = @{
        Name = 'Platform Detection'
        Status = 'Unknown'
        Details = @()
        Data = @{}
    }
    
    $platform = $SetupState.Platform
    $result.Data = $platform
    
    $result.Details += "Operating System: $($platform.OS) $($platform.Version)"
    $result.Details += "Architecture: $($platform.Architecture)"
    $result.Details += "PowerShell: $($platform.PowerShell)"
    
    # Platform-specific checks
    switch ($platform.OS) {
        'Windows' {
            # Check Windows-specific requirements
            if ([System.Environment]::OSVersion.Version.Major -ge 10) {
                $result.Details += "✓ Windows version supported"
            } else {
                $result.Details += "⚠️ Older Windows version - some features may be limited"
                $SetupState.Warnings += "Windows version is older than Windows 10"
            }
            
            # Check execution policy
            $execPolicy = Get-ExecutionPolicy
            if ($execPolicy -in @('Restricted', 'AllSigned')) {
                $result.Details += "⚠️ Restrictive execution policy: $execPolicy"
                $SetupState.Recommendations += "Run: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
            }
        }
        'Linux' {
            # Check Linux-specific requirements
            $result.Details += "✓ Linux platform detected"
            
            # Check for systemd
            if (Get-Command systemctl -ErrorAction SilentlyContinue) {
                $result.Details += "✓ Systemd available"
            }
        }
        'macOS' {
            # Check macOS-specific requirements
            $result.Details += "✓ macOS platform detected"
            
            # Check for Homebrew
            if (Get-Command brew -ErrorAction SilentlyContinue) {
                $result.Details += "✓ Homebrew available"
            } else {
                $SetupState.Recommendations += "Install Homebrew for easier package management"
            }
        }
    }
    
    $result.Status = if ($SetupState.Warnings.Count -eq 0) { 'Passed' } else { 'Warning' }
    return $result
}

function Test-PowerShellVersion {
    param($SetupState)
    
    $result = @{
        Name = 'PowerShell Version'
        Status = 'Unknown'
        Details = @()
    }
    
    $psVersion = $PSVersionTable.PSVersion
    
    if ($psVersion.Major -ge 7) {
        $result.Status = 'Passed'
        $result.Details += "✓ PowerShell $psVersion - Full compatibility"
    } elseif ($psVersion.Major -eq 5 -and $psVersion.Minor -ge 1) {
        $result.Status = 'Warning'
        $result.Details += "⚠️ PowerShell $psVersion - Limited compatibility"
        $result.Details += "  Recommend upgrading to PowerShell 7+"
        $SetupState.Recommendations += "Install PowerShell 7: https://aka.ms/powershell"
    } else {
        $result.Status = 'Failed'
        $result.Details += "❌ PowerShell $psVersion - Not supported"
        $result.Details += "  Minimum required: PowerShell 5.1"
    }
    
    # Check for available PowerShell versions
    if ($SetupState.Platform.OS -eq 'Windows') {
        if (Test-Path "$env:ProgramFiles\PowerShell\7\pwsh.exe") {
            $result.Details += "ℹ️ PowerShell 7 is installed but not currently running"
        }
    }
    
    return $result
}

function Test-GitInstallation {
    param($SetupState)
    
    $result = @{
        Name = 'Git Installation'
        Status = 'Unknown'
        Details = @()
    }
    
    try {
        $gitVersion = git --version 2>$null
        if ($gitVersion) {
            $result.Status = 'Passed'
            $result.Details += "✓ $gitVersion"
            
            # Check Git configuration
            $userName = git config --global user.name 2>$null
            $userEmail = git config --global user.email 2>$null
            
            if ($userName -and $userEmail) {
                $result.Details += "✓ Git configured for: $userName <$userEmail>"
            } else {
                $result.Details += "⚠️ Git user configuration incomplete"
                $SetupState.Recommendations += "Configure Git: git config --global user.name 'Your Name'"
                $SetupState.Recommendations += "Configure Git: git config --global user.email 'your@email.com'"
            }
        }
    } catch {
        $result.Status = 'Warning'
        $result.Details += "⚠️ Git not found - PatchManager features will be limited"
        
        # Platform-specific installation instructions
        switch ($SetupState.Platform.OS) {
            'Windows' {
                $SetupState.Recommendations += "Install Git: winget install Git.Git"
            }
            'Linux' {
                $SetupState.Recommendations += "Install Git: sudo apt-get install git (Ubuntu/Debian)"
            }
            'macOS' {
                $SetupState.Recommendations += "Install Git: brew install git"
            }
        }
    }
    
    return $result
}

function Test-InfrastructureTools {
    param($SetupState)
    
    $result = @{
        Name = 'Infrastructure Tools'
        Status = 'Unknown'
        Details = @()
    }
    
    # Check for OpenTofu/Terraform
    $tofu = Get-Command tofu -ErrorAction SilentlyContinue
    $terraform = Get-Command terraform -ErrorAction SilentlyContinue
    
    if ($tofu) {
        $result.Status = 'Passed'
        $version = tofu version 2>&1 | Select-String -Pattern 'OpenTofu v([\d.]+)' | ForEach-Object { $_.Matches[0].Groups[1].Value }
        $result.Details += "✓ OpenTofu v$version installed"
    } elseif ($terraform) {
        $result.Status = 'Warning'
        $version = terraform version 2>&1 | Select-String -Pattern 'Terraform v([\d.]+)' | ForEach-Object { $_.Matches[0].Groups[1].Value }
        $result.Details += "⚠️ Terraform v$version found (consider OpenTofu)"
        $SetupState.Recommendations += "Consider migrating to OpenTofu: https://opentofu.org"
    } else {
        $result.Status = 'Warning'
        $result.Details += "⚠️ No infrastructure tool found"
        $result.Details += "  Infrastructure automation features will be limited"
        $SetupState.Recommendations += "Install OpenTofu: https://opentofu.org/docs/intro/install/"
    }
    
    # Check for Docker (optional)
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        $result.Details += "✓ Docker available for container infrastructure"
    }
    
    # Check for cloud CLIs (optional)
    $cloudCLIs = @{
        'az' = 'Azure CLI'
        'aws' = 'AWS CLI'
        'gcloud' = 'Google Cloud SDK'
    }
    
    foreach ($cli in $cloudCLIs.GetEnumerator()) {
        if (Get-Command $cli.Key -ErrorAction SilentlyContinue) {
            $result.Details += "✓ $($cli.Value) available"
        }
    }
    
    return $result
}

function Test-ModuleDependencies {
    param($SetupState)
    
    $result = @{
        Name = 'Module Dependencies'
        Status = 'Unknown'
        Details = @()
    }
    
    # Check AitherZero modules
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "modules"
    $requiredModules = @(
        'Logging',
        'PatchManager',
        'OpenTofuProvider',
        'LabRunner',
        'BackupManager'
    )
    
    $foundModules = 0
    $missingModules = @()
    
    foreach ($module in $requiredModules) {
        $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "modules/$module"
        if (Test-Path $modulePath) {
            $foundModules++
        } else {
            $missingModules += $module
        }
    }
    
    if ($foundModules -eq $requiredModules.Count) {
        $result.Status = 'Passed'
        $result.Details += "✓ All $($requiredModules.Count) core modules found"
    } else {
        $result.Status = 'Warning'
        $result.Details += "⚠️ Found $foundModules/$($requiredModules.Count) modules"
        if ($missingModules.Count -gt 0) {
            $result.Details += "  Missing: $($missingModules -join ', ')"
        }
    }
    
    # Check for optional PowerShell modules
    $optionalModules = @('Pester', 'PSScriptAnalyzer', 'platyPS')
    foreach ($module in $optionalModules) {
        if (Get-Module -ListAvailable -Name $module) {
            $result.Details += "✓ Optional module available: $module"
        }
    }
    
    return $result
}

function Test-NetworkConnectivity {
    param($SetupState)
    
    $result = @{
        Name = 'Network Connectivity'
        Status = 'Unknown'
        Details = @()
    }
    
    # Test connectivity to key services
    $endpoints = @(
        @{Name = 'GitHub'; Url = 'https://api.github.com'; Required = $true},
        @{Name = 'PowerShell Gallery'; Url = 'https://www.powershellgallery.com'; Required = $false},
        @{Name = 'OpenTofu Registry'; Url = 'https://registry.opentofu.org'; Required = $false}
    )
    
    $failedRequired = $false
    
    foreach ($endpoint in $endpoints) {
        try {
            $response = Invoke-WebRequest -Uri $endpoint.Url -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                $result.Details += "✓ $($endpoint.Name) reachable"
            }
        } catch {
            if ($endpoint.Required) {
                $failedRequired = $true
                $result.Details += "❌ $($endpoint.Name) unreachable (required)"
            } else {
                $result.Details += "⚠️ $($endpoint.Name) unreachable (optional)"
            }
        }
    }
    
    # Check for proxy settings
    if ($env:HTTP_PROXY -or $env:HTTPS_PROXY) {
        $result.Details += "ℹ️ Proxy configuration detected"
    }
    
    $result.Status = if ($failedRequired) { 'Failed' } else { 'Passed' }
    return $result
}

function Test-SecuritySettings {
    param($SetupState)
    
    $result = @{
        Name = 'Security Settings'
        Status = 'Unknown'
        Details = @()
    }
    
    # Platform-specific security checks
    switch ($SetupState.Platform.OS) {
        'Windows' {
            # Check Windows Defender exclusions
            try {
                $defenderPrefs = Get-MpPreference -ErrorAction SilentlyContinue
                if ($defenderPrefs) {
                    $result.Details += "✓ Windows Defender is active"
                    
                    # Check if project path is excluded
                    $projectPath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
                    if ($defenderPrefs.ExclusionPath -contains $projectPath) {
                        $result.Details += "✓ Project path is excluded from scanning"
                    } else {
                        $result.Details += "ℹ️ Consider adding project to Defender exclusions for performance"
                    }
                }
            } catch {
                $result.Details += "ℹ️ Could not check Windows Defender status"
            }
        }
        'Linux' {
            # Check SELinux status
            if (Get-Command getenforce -ErrorAction SilentlyContinue) {
                $selinuxStatus = getenforce 2>$null
                if ($selinuxStatus) {
                    $result.Details += "SELinux status: $selinuxStatus"
                }
            }
            
            # Check AppArmor status
            if (Get-Command aa-status -ErrorAction SilentlyContinue) {
                $result.Details += "✓ AppArmor is available"
            }
        }
        'macOS' {
            # Check Gatekeeper status
            $gatekeeperStatus = spctl --status 2>&1
            if ($gatekeeperStatus -match 'assessments enabled') {
                $result.Details += "✓ Gatekeeper is enabled"
                $result.Details += "ℹ️ You may need to approve scripts on first run"
            }
        }
    }
    
    # Check for secure credential storage
    $credPath = Join-Path $env:USERPROFILE ".aitherzero/credentials" -ErrorAction SilentlyContinue
    if (Test-Path $credPath) {
        $result.Details += "✓ Secure credential store exists"
    } else {
        $result.Details += "ℹ️ Secure credential store will be created when needed"
    }
    
    $result.Status = 'Passed'
    return $result
}

function Initialize-Configuration {
    param($SetupState)
    
    $result = @{
        Name = 'Configuration Files'
        Status = 'Unknown'
        Details = @()
    }
    
    # Determine config directory
    $configDir = if ($SetupState.Platform.OS -eq 'Windows') {
        Join-Path $env:APPDATA "AitherZero"
    } else {
        Join-Path $env:HOME ".config/aitherzero"
    }
    
    # Create config directory if needed
    if (-not (Test-Path $configDir)) {
        try {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
            $result.Details += "✓ Created configuration directory: $configDir"
        } catch {
            $result.Status = 'Failed'
            $result.Details += "❌ Failed to create config directory: $_"
            return $result
        }
    } else {
        $result.Details += "✓ Configuration directory exists: $configDir"
    }
    
    # Create default configuration
    $defaultConfig = @{
        Version = '1.0'
        Platform = $SetupState.Platform.OS
        CreatedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Settings = @{
            Verbosity = 'normal'
            AutoUpdate = $true
            TelemetryEnabled = $false
            MaxParallelJobs = 4
        }
        Modules = @{
            EnabledByDefault = @('Logging', 'PatchManager', 'LabRunner')
            AutoLoad = $true
        }
    }
    
    $configFile = Join-Path $configDir "config.json"
    
    if (-not (Test-Path $configFile)) {
        try {
            $defaultConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $configFile
            $result.Details += "✓ Created default configuration file"
        } catch {
            $result.Details += "⚠️ Could not create config file: $_"
        }
    } else {
        $result.Details += "✓ Configuration file already exists"
    }
    
    # Save setup state
    $setupStateFile = Join-Path $configDir "setup-state.json"
    try {
        $SetupState | ConvertTo-Json -Depth 10 | Set-Content -Path $setupStateFile
        $result.Details += "✓ Saved setup state for future reference"
    } catch {
        $result.Details += "⚠️ Could not save setup state"
    }
    
    $result.Status = 'Passed'
    return $result
}

function Generate-QuickStartGuide {
    param($SetupState)
    
    $result = @{
        Name = 'Quick Start Guide'
        Status = 'Unknown'
        Details = @()
    }
    
    # Generate platform-specific guide
    $guide = @"
# AitherZero Quick Start Guide
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')
Platform: $($SetupState.Platform.OS) $($SetupState.Platform.Version)

## 🚀 Getting Started

### 1. Basic Usage
``````powershell
# Interactive mode (recommended for beginners)
./Start-AitherZero.ps1

# Run specific module
./Start-AitherZero.ps1 -Scripts 'LabRunner'

# Automated mode
./Start-AitherZero.ps1 -Auto
``````

### 2. Common Tasks

#### Deploy Infrastructure
``````powershell
# Initialize OpenTofu provider
Import-Module ./aither-core/modules/OpenTofuProvider
Initialize-OpenTofuProvider

# Deploy a lab
New-LabInfrastructure -ConfigFile ./configs/lab-configs/dev-lab.json
``````

#### Manage Patches
``````powershell
# Create a patch with PR
Import-Module ./aither-core/modules/PatchManager
Invoke-PatchWorkflow -PatchDescription "Fix issue #123" -PatchOperation {
    # Your changes here
} -CreatePR
``````

#### Backup Operations
``````powershell
# Run backup
Import-Module ./aither-core/modules/BackupManager
Start-Backup -SourcePath ./important-data -DestinationPath ./backups
``````

## 📋 Your Setup Summary

### ✅ What's Ready:
"@
    
    foreach ($step in $SetupState.Steps | Where-Object { $_.Status -eq 'Passed' }) {
        $guide += "`n- $($step.Name)"
    }
    
    if ($SetupState.Warnings.Count -gt 0) {
        $guide += "`n`n### ⚠️ Things to Consider:"
        foreach ($warning in $SetupState.Warnings) {
            $guide += "`n- $warning"
        }
    }
    
    if ($SetupState.Recommendations.Count -gt 0) {
        $guide += "`n`n### 💡 Recommendations:"
        foreach ($rec in $SetupState.Recommendations) {
            $guide += "`n- $rec"
        }
    }
    
    $guide += @"

## 🔗 Resources

- Documentation: ./docs/
- Examples: ./opentofu/examples/
- Module Help: Get-Help <ModuleName> -Full
- Issues: https://github.com/wizzense/AitherZero/issues

## 🎯 Next Steps

1. Review the generated configuration in:
   $(if ($SetupState.Platform.OS -eq 'Windows') { "$env:APPDATA\AitherZero" } else { "~/.config/aitherzero" })

2. Try the interactive menu:
   ./Start-AitherZero.ps1

3. Explore available modules:
   Get-Module -ListAvailable -Name *AitherZero*

Happy automating! 🚀
"@
    
    # Save guide
    try {
        $guidePath = "QuickStart-$($SetupState.Platform.OS)-$(Get-Date -Format 'yyyyMMdd').md"
        Set-Content -Path $guidePath -Value $guide
        $result.Details += "✓ Generated quick start guide: $guidePath"
        $result.Status = 'Passed'
        
        # Also display key info
        Write-Host ""
        Write-Host "  📖 Quick Start Commands:" -ForegroundColor Green
        Write-Host "     Interactive:  ./Start-AitherZero.ps1" -ForegroundColor White
        Write-Host "     Automated:    ./Start-AitherZero.ps1 -Auto" -ForegroundColor White
        Write-Host "     Get Help:     ./Start-AitherZero.ps1 -Help" -ForegroundColor White
    } catch {
        $result.Status = 'Warning'
        $result.Details += "⚠️ Could not save guide: $_"
    }
    
    return $result
}

function Test-SetupCompletion {
    param($SetupState)
    
    $result = @{
        Name = 'Final Validation'
        Status = 'Unknown'
        Details = @()
    }
    
    # Count successes and failures
    $passed = ($SetupState.Steps | Where-Object { $_.Status -eq 'Passed' }).Count
    $failed = ($SetupState.Steps | Where-Object { $_.Status -eq 'Failed' }).Count
    $warnings = ($SetupState.Steps | Where-Object { $_.Status -eq 'Warning' }).Count
    
    $result.Details += "Setup completed with:"
    $result.Details += "  ✅ Passed: $passed"
    $result.Details += "  ❌ Failed: $failed"
    $result.Details += "  ⚠️ Warnings: $warnings"
    
    if ($failed -eq 0) {
        $result.Status = 'Passed'
        $result.Details += ""
        $result.Details += "🎉 Setup completed successfully!"
    } elseif ($failed -le 2) {
        $result.Status = 'Warning'
        $result.Details += ""
        $result.Details += "⚠️ Setup completed with minor issues"
    } else {
        $result.Status = 'Failed'
        $result.Details += ""
        $result.Details += "❌ Setup encountered significant issues"
    }
    
    # Calculate setup time
    $duration = (Get-Date) - $SetupState.StartTime
    $result.Details += "Total time: $([math]::Round($duration.TotalSeconds, 1)) seconds"
    
    return $result
}

function Show-SetupSummary {
    param($State)
    
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                    Setup Summary                      ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # Overall status
    $failed = ($State.Steps | Where-Object { $_.Status -eq 'Failed' }).Count
    if ($failed -eq 0) {
        Write-Host "  🎉 Setup Status: SUCCESS" -ForegroundColor Green
    } elseif ($failed -le 2) {
        Write-Host "  ⚠️  Setup Status: COMPLETED WITH WARNINGS" -ForegroundColor Yellow
    } else {
        Write-Host "  ❌ Setup Status: FAILED" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "  Setup Results:" -ForegroundColor White
    foreach ($step in $State.Steps) {
        $icon = switch ($step.Status) {
            'Passed' { '✅' }
            'Failed' { '❌' }
            'Warning' { '⚠️' }
            default { '❓' }
        }
        
        Write-Host "    $icon $($step.Name)" -ForegroundColor $(
            switch ($step.Status) {
                'Passed' { 'Green' }
                'Failed' { 'Red' }
                'Warning' { 'Yellow' }
                default { 'Gray' }
            }
        )
    }
    
    if ($State.Recommendations.Count -gt 0) {
        Write-Host ""
        Write-Host "  💡 Recommendations:" -ForegroundColor Yellow
        $State.Recommendations | Select-Object -First 3 | ForEach-Object {
            Write-Host "     • $_" -ForegroundColor White
        }
        if ($State.Recommendations.Count -gt 3) {
            Write-Host "     • ... and $($State.Recommendations.Count - 3) more" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "  📁 Configuration saved to:" -ForegroundColor Cyan
    Write-Host "     $(if ($State.Platform.OS -eq 'Windows') { "$env:APPDATA\AitherZero" } else { "~/.config/aitherzero" })" -ForegroundColor White
    
    Write-Host ""
    Write-Host "  🚀 Ready to use AitherZero!" -ForegroundColor Green
    Write-Host ""
}

function Show-SetupPrompt {
    param(
        [string]$Message,
        [switch]$DefaultYes
    )
    
    $choices = '&Yes', '&No'
    $decision = $Host.UI.PromptForChoice('', $Message, $choices, $(if ($DefaultYes) { 0 } else { 1 }))
    
    return $decision -eq 0
}

function Get-InstallationProfile {
    <#
    .SYNOPSIS
        Interactive profile selection for AitherZero installation
    #>
    
    Write-Host ""
    Write-Host "  📦 Choose your installation profile:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    1. 🏃 Minimal     - Core AitherZero + Infrastructure tools only" -ForegroundColor Green
    Write-Host "    2. 👨‍💻 Developer   - Minimal + AI tools + Development utilities" -ForegroundColor Blue
    Write-Host "    3. 🚀 Full        - Everything including advanced integrations" -ForegroundColor Magenta
    Write-Host ""
    
    do {
        $choice = Read-Host "  Enter your choice (1-3)"
        switch ($choice) {
            '1' { return 'minimal' }
            '2' { return 'developer' }
            '3' { return 'full' }
            default { 
                Write-Host "  ❌ Invalid choice. Please enter 1, 2, or 3." -ForegroundColor Red
            }
        }
    } while ($true)
}

function Show-InstallationProfile {
    param(
        [string]$Profile
    )
    
    Write-Host ""
    Write-Host "  🎯 Installation Profile: $($Profile.ToUpper())" -ForegroundColor Cyan
    
    switch ($Profile) {
        'minimal' {
            Write-Host "     • Core AitherZero modules" -ForegroundColor White
            Write-Host "     • OpenTofu/Terraform support" -ForegroundColor White
            Write-Host "     • Basic configuration management" -ForegroundColor White
        }
        'developer' {
            Write-Host "     • Everything in Minimal profile" -ForegroundColor White
            Write-Host "     • Claude Code integration" -ForegroundColor White
            Write-Host "     • MCP server setup" -ForegroundColor White
            Write-Host "     • AI tools integration" -ForegroundColor White
            Write-Host "     • Development utilities" -ForegroundColor White
        }
        'full' {
            Write-Host "     • Everything in Developer profile" -ForegroundColor White
            Write-Host "     • Advanced AI integrations" -ForegroundColor White
            Write-Host "     • All optional modules" -ForegroundColor White
            Write-Host "     • Cloud provider CLIs" -ForegroundColor White
            Write-Host "     • Enterprise features" -ForegroundColor White
        }
    }
    Write-Host ""
}

function Get-SetupSteps {
    param(
        [string]$Profile
    )
    
    $baseSteps = @(
        @{Name = 'Platform Detection'; Function = 'Test-PlatformRequirements'; AllProfiles = $true},
        @{Name = 'PowerShell Version'; Function = 'Test-PowerShellVersion'; AllProfiles = $true},
        @{Name = 'Git Installation'; Function = 'Test-GitInstallation'; AllProfiles = $true},
        @{Name = 'Infrastructure Tools'; Function = 'Test-InfrastructureTools'; AllProfiles = $true},
        @{Name = 'Module Dependencies'; Function = 'Test-ModuleDependencies'; AllProfiles = $true}
    )
    
    $profileSpecificSteps = @{
        'minimal' = @(
            @{Name = 'Network Connectivity'; Function = 'Test-NetworkConnectivity'},
            @{Name = 'Security Settings'; Function = 'Test-SecuritySettings'},
            @{Name = 'Configuration Files'; Function = 'Initialize-Configuration'},
            @{Name = 'Configuration Review'; Function = 'Review-Configuration'},
            @{Name = 'Quick Start Guide'; Function = 'Generate-QuickStartGuide'},
            @{Name = 'Final Validation'; Function = 'Test-SetupCompletion'}
        )
        'developer' = @(
            @{Name = 'Network Connectivity'; Function = 'Test-NetworkConnectivity'},
            @{Name = 'Node.js Detection'; Function = 'Test-NodeJsInstallation'},
            @{Name = 'AI Tools Setup'; Function = 'Install-AITools'},
            @{Name = 'MCP Server Setup'; Function = 'Setup-MCPServer'},
            @{Name = 'Security Settings'; Function = 'Test-SecuritySettings'},
            @{Name = 'Configuration Files'; Function = 'Initialize-Configuration'},
            @{Name = 'Configuration Review'; Function = 'Review-Configuration'},
            @{Name = 'Quick Start Guide'; Function = 'Generate-QuickStartGuide'},
            @{Name = 'Final Validation'; Function = 'Test-SetupCompletion'}
        )
        'full' = @(
            @{Name = 'Network Connectivity'; Function = 'Test-NetworkConnectivity'},
            @{Name = 'Node.js Detection'; Function = 'Test-NodeJsInstallation'},
            @{Name = 'AI Tools Setup'; Function = 'Install-AITools'},
            @{Name = 'MCP Server Setup'; Function = 'Setup-MCPServer'},
            @{Name = 'Cloud CLIs Detection'; Function = 'Test-CloudCLIs'},
            @{Name = 'Security Settings'; Function = 'Test-SecuritySettings'},
            @{Name = 'Configuration Files'; Function = 'Initialize-Configuration'},
            @{Name = 'Configuration Review'; Function = 'Review-Configuration'},
            @{Name = 'Quick Start Guide'; Function = 'Generate-QuickStartGuide'},
            @{Name = 'Final Validation'; Function = 'Test-SetupCompletion'}
        )
    }
    
    $allSteps = $baseSteps + $profileSpecificSteps[$Profile]
    return $allSteps
}

function Test-NodeJsInstallation {
    param($SetupState)
    
    $result = @{
        Name = 'Node.js Detection'
        Status = 'Unknown'
        Details = @()
    }
    
    try {
        $nodeVersion = node --version 2>$null
        if ($nodeVersion) {
            $result.Status = 'Passed'
            $result.Details += "✓ Node.js $nodeVersion installed"
            
            # Check npm
            $npmVersion = npm --version 2>$null
            if ($npmVersion) {
                $result.Details += "✓ npm $npmVersion available"
            }
        }
    } catch {
        $result.Status = 'Warning'
        $result.Details += "⚠️ Node.js not found - AI tools installation will be limited"
        
        # Platform-specific installation instructions
        switch ($SetupState.Platform.OS) {
            'Windows' {
                $SetupState.Recommendations += "Install Node.js: winget install OpenJS.NodeJS"
            }
            'Linux' {
                $SetupState.Recommendations += "Install Node.js: curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt-get install -y nodejs"
            }
            'macOS' {
                $SetupState.Recommendations += "Install Node.js: brew install node"
            }
        }
    }
    
    return $result
}

function Install-AITools {
    param($SetupState)
    
    $result = @{
        Name = 'AI Tools Setup'
        Status = 'Unknown'
        Details = @()
    }
    
    # Import AIToolsIntegration module
    try {
        $aiToolsModule = Join-Path (Split-Path $PSScriptRoot -Parent) "AIToolsIntegration"
        if (Test-Path $aiToolsModule) {
            Import-Module $aiToolsModule -Force -ErrorAction Stop
        } else {
            throw "AIToolsIntegration module not found"
        }
    } catch {
        $result.Status = 'Warning'
        $result.Details += "⚠️ Could not load AIToolsIntegration module: $_"
        return $result
    }
    
    # Determine which AI tools to install based on profile
    $aiTools = @()
    switch ($SetupState.InstallationProfile) {
        'developer' {
            $aiTools = @('claude-code')
        }
        'full' {
            $aiTools = @('claude-code', 'gemini-cli')
        }
    }
    
    if ($aiTools.Count -eq 0) {
        $result.Status = 'Passed'
        $result.Details += "ℹ️ No AI tools installation required for this profile"
        return $result
    }
    
    $successCount = 0
    
    foreach ($tool in $aiTools) {
        switch ($tool) {
            'claude-code' {
                $result.Details += "⏳ Installing Claude Code..."
                $installResult = Install-ClaudeCode
                if ($installResult.Success) {
                    $result.Details += "✓ Claude Code: $($installResult.Message)"
                    if ($installResult.Version) {
                        $result.Details += "  Version: $($installResult.Version)"
                    }
                    $successCount++
                } else {
                    $result.Details += "❌ Claude Code: $($installResult.Message)"
                }
            }
            'gemini-cli' {
                $result.Details += "⏳ Installing Gemini CLI..."
                $installResult = Install-GeminiCLI
                if ($installResult.Success) {
                    $result.Details += "✓ Gemini CLI: $($installResult.Message)"
                    $successCount++
                } else {
                    $result.Details += "⚠️ Gemini CLI: $($installResult.Message)"
                    if ($installResult.ManualSteps) {
                        $SetupState.Recommendations += "Manual Gemini CLI setup required"
                    }
                }
            }
        }
    }
    
    # Determine overall status
    if ($successCount -eq $aiTools.Count) {
        $result.Status = 'Passed'
        $result.Details += "🎉 All AI tools installed successfully"
    } elseif ($successCount -gt 0) {
        $result.Status = 'Warning'
        $result.Details += "⚠️ Some AI tools installed, others may require manual setup"
    } else {
        $result.Status = 'Warning'
        $result.Details += "⚠️ AI tools installation had issues - manual setup may be required"
    }
    
    return $result
}

function Setup-MCPServer {
    param($SetupState)
    
    $result = @{
        Name = 'MCP Server Setup'
        Status = 'Unknown'
        Details = @()
    }
    
    # Check if MCP server directory exists
    $mcpServerPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "mcp-server"
    
    if (Test-Path $mcpServerPath) {
        try {
            Push-Location $mcpServerPath
            
            # Install dependencies
            $result.Details += "⏳ Installing MCP server dependencies..."
            $installResult = npm install 2>&1
            if ($LASTEXITCODE -eq 0) {
                $result.Details += "✓ MCP server dependencies installed"
                
                # Test MCP server
                $result.Details += "⏳ Testing MCP server..."
                $testResult = npm test 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $result.Details += "✓ MCP server tests passed"
                    $result.Status = 'Passed'
                } else {
                    $result.Details += "⚠️ MCP server tests had issues"
                    $result.Status = 'Warning'
                }
                
                # Setup Claude Code integration
                $setupScript = Join-Path $mcpServerPath "setup-claude-code-mcp.sh"
                if (Test-Path $setupScript) {
                    $result.Details += "ℹ️ Claude Code MCP setup script available"
                    $SetupState.Recommendations += "Run: cd mcp-server && ./setup-claude-code-mcp.sh to complete Claude Code integration"
                }
            } else {
                $result.Details += "❌ Failed to install MCP server dependencies"
                $result.Status = 'Failed'
            }
        } catch {
            $result.Details += "❌ Error setting up MCP server: $_"
            $result.Status = 'Failed'
        } finally {
            Pop-Location
        }
    } else {
        $result.Status = 'Warning'
        $result.Details += "⚠️ MCP server directory not found at: $mcpServerPath"
    }
    
    return $result
}

function Test-CloudCLIs {
    param($SetupState)
    
    $result = @{
        Name = 'Cloud CLIs Detection'
        Status = 'Unknown'
        Details = @()
    }
    
    # Extended cloud CLI checks for full profile
    $cloudCLIs = @{
        'az' = 'Azure CLI'
        'aws' = 'AWS CLI'
        'gcloud' = 'Google Cloud SDK'
        'kubectl' = 'Kubernetes CLI'
        'helm' = 'Helm'
        'docker' = 'Docker'
    }
    
    $foundCount = 0
    
    foreach ($cli in $cloudCLIs.GetEnumerator()) {
        if (Get-Command $cli.Key -ErrorAction SilentlyContinue) {
            $result.Details += "✓ $($cli.Value) available"
            $foundCount++
        } else {
            $result.Details += "ℹ️ $($cli.Value) not found (optional)"
        }
    }
    
    if ($foundCount -ge 2) {
        $result.Status = 'Passed'
        $result.Details += "✓ $foundCount cloud tools available - good coverage"
    } elseif ($foundCount -ge 1) {
        $result.Status = 'Warning'
        $result.Details += "⚠️ $foundCount cloud tool available - consider installing more"
    } else {
        $result.Status = 'Warning'
        $result.Details += "⚠️ No cloud tools found - cloud features will be limited"
        $SetupState.Recommendations += "Consider installing cloud CLIs for enhanced cloud integration"
    }
    
    return $result
}

# Load public functions
$publicFunctions = Get-ChildItem -Path "$PSScriptRoot/Public" -Filter '*.ps1' -ErrorAction SilentlyContinue
foreach ($function in $publicFunctions) {
    . $function.FullName
}

# Export functions
Export-ModuleMember -Function @(
    'Start-IntelligentSetup',
    'Get-PlatformInfo',
    'Generate-QuickStartGuide',
    'Get-InstallationProfile',
    'Install-AITools',
    'Setup-MCPServer',
    'Edit-Configuration',
    'Review-Configuration'
)