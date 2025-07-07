# AitherZero Intelligent Setup Wizard Module
# Provides enhanced first-time setup experience with progress tracking

# Load shared utilities
$moduleRoot = $PSScriptRoot
if (-not $moduleRoot) {
    $moduleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

# Try to load Find-ProjectRoot from shared
$sharedPaths = @(
    (Join-Path (Split-Path (Split-Path $moduleRoot -Parent) -Parent) "shared" "Find-ProjectRoot.ps1"),
    (Join-Path (Split-Path $moduleRoot -Parent) "shared" "Find-ProjectRoot.ps1")
)

$foundSharedUtil = $false
foreach ($sharedPath in $sharedPaths) {
    if (Test-Path $sharedPath) {
        . $sharedPath
        Write-Verbose "Loaded Find-ProjectRoot from: $sharedPath"
        $foundSharedUtil = $true
        break
    }
}

if (-not $foundSharedUtil) {
    # Define Find-ProjectRoot locally if shared utility is not found
    function Find-ProjectRoot {
        param([string]$StartPath = $PWD.Path)
        
        $currentPath = $StartPath
        while ($currentPath -and $currentPath -ne (Split-Path $currentPath -Parent)) {
            if (Test-Path (Join-Path $currentPath "Start-AitherZero.ps1")) {
                return $currentPath
            }
            $currentPath = Split-Path $currentPath -Parent
        }
        
        # Fallback to module root's parent parent
        return Split-Path (Split-Path $moduleRoot -Parent) -Parent
    }
    Write-Verbose "Using fallback Find-ProjectRoot function"
}

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
    $useProgress = $false
    if ($progressAvailable -and -not $env:NO_PROGRESS) {
        try {
            Import-Module ProgressTracking -Force -ErrorAction Stop
            # Test if we can use progress in current environment
            if (-not [System.Console]::IsInputRedirected -and $Host.UI.RawUI.WindowSize.Width -gt 0) {
                $useProgress = $true
            }
        } catch {
            Write-Verbose "ProgressTracking module not available: $_"
        }
    }
    
    # Create progress operation if available (skip in non-interactive mode)
    $progressId = $null
    if ($useProgress -and (Get-Command Start-ProgressOperation -ErrorAction SilentlyContinue)) {
        try {
            $progressId = Start-ProgressOperation `
                -OperationName "AitherZero Intelligent Setup" `
                -TotalSteps $setupState.TotalSteps `
                -ShowTime `
                -ShowETA
        } catch {
            Write-Verbose "Progress tracking not available in current environment: $_"
            $useProgress = $false
        }
    }
    Show-SetupBanner
    
    # Run setup steps based on profile
    $setupStepsInfo = Get-SetupSteps -Profile $setupState.InstallationProfile
    $setupSteps = $setupStepsInfo.Steps
    $profileInfo = $setupStepsInfo.Profile
    
    # Show enhanced profile information
    Show-EnhancedInstallationProfile -Profile $setupState.InstallationProfile -ProfileInfo $profileInfo
    
    $setupState.TotalSteps = $setupSteps.Count
    $setupState.ProfileInfo = $profileInfo
    
    foreach ($step in $setupSteps) {
        $setupState.CurrentStep++
        Show-EnhancedProgress -State $setupState -StepName $step.Name -Status 'Running'
        
        $stepAttempts = 0
        $maxAttempts = 2
        $stepCompleted = $false
        
        while ($stepAttempts -lt $maxAttempts -and -not $stepCompleted) {
            $stepAttempts++
            
            try {
                # Validate function exists before calling
                if (-not (Get-Command $step.Function -ErrorAction SilentlyContinue)) {
                    throw "Step function '$($step.Function)' not found"
                }
                
                $result = & $step.Function -SetupState $setupState
                
                # Normalize status values
                if ($result.Status -eq 'Success') { $result.Status = 'Passed' }
                
                $setupState.Steps += $result
                
                if ($result.Status -eq 'Passed' -or $result.Status -eq 'Success') {
                    Show-EnhancedProgress -State $setupState -StepName $step.Name -Status 'Success'
                    $stepCompleted = $true
                } elseif ($result.Status -eq 'Warning') {
                    Show-EnhancedProgress -State $setupState -StepName $step.Name -Status 'Warning'
                    $stepCompleted = $true
                } elseif ($result.Status -eq 'Failed') {
                    Show-EnhancedProgress -State $setupState -StepName $step.Name -Status 'Failed' `
                        -ErrorContext @{ LastError = $result.Details -join '; ' }
                    
                    # Attempt recovery if this is the first attempt
                    if ($stepAttempts -eq 1) {
                        Write-Host "  🔧 Attempting automatic recovery..." -ForegroundColor Blue
                        Show-EnhancedProgress -State $setupState -StepName $step.Name -Status 'Recovering'
                        
                        $recovery = Invoke-ErrorRecovery -StepResult $result -SetupState $setupState -StepName $step.Name
                        
                        if ($recovery.Success) {
                            Write-Host "  ✓ Recovery successful, retrying step..." -ForegroundColor Green
                            Show-EnhancedProgress -State $setupState -StepName $step.Name -Status 'Retrying' `
                                -ErrorContext @{ RecoveryAttempted = $true; RecoveryMethod = $recovery.Method }
                            continue
                        } else {
                            Write-Host "  ⚠️ Recovery failed or not applicable" -ForegroundColor Yellow
                            $result.Details += $recovery.Details
                        }
                    }
                    
                    # Prompt user for action if not in skip mode
                    if (-not $SkipOptional) {
                        Write-Host ""
                        Write-Host "Step Failed: $($step.Name)" -ForegroundColor Red
                        Write-Host "Details: $($result.Details -join '; ')" -ForegroundColor Gray
                        
                        $choice = Show-SetupPrompt -Message "Continue anyway? (y=yes, n=abort setup, r=retry manually)" -DefaultYes:$false
                        
                        if ($choice) {
                            Write-Host "  ⚠️ Continuing with failed step" -ForegroundColor Yellow
                            $stepCompleted = $true
                        } else {
                            Write-Host "`n❌ Setup cancelled by user" -ForegroundColor Red
                            return $setupState
                        }
                    } else {
                        Write-Host "  ⚠️ Skipping failed step (optional components mode)" -ForegroundColor Yellow
                        $stepCompleted = $true
                    }
                }
                
            } catch {
                $errorMessage = "Error in $($step.Name): $_"
                $setupState.Errors += $errorMessage
                
                Show-EnhancedProgress -State $setupState -StepName $step.Name -Status 'Failed' `
                    -ErrorContext @{ LastError = $_.Exception.Message }
                
                Write-Host "  ❌ Exception: $_" -ForegroundColor Red
                
                if ($stepAttempts -eq 1) {
                    Write-Host "  🔄 Retrying step due to exception..." -ForegroundColor Magenta
                    Show-EnhancedProgress -State $setupState -StepName $step.Name -Status 'Retrying'
                    Start-Sleep -Milliseconds 1000
                    continue
                } else {
                    Write-Host "  ❌ Maximum retry attempts reached" -ForegroundColor Red
                    $stepCompleted = $true
                }
            }
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

function Show-WelcomeMessage {
    param($SetupState)
    
    Write-Host ""
    Write-Host "Welcome to AitherZero Setup!" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Platform: $($SetupState.Platform.OS) $($SetupState.Platform.Version)" -ForegroundColor Yellow
    Write-Host "PowerShell: $($SetupState.Platform.PowerShell)" -ForegroundColor Yellow
    Write-Host "Installation Profile: $($SetupState.InstallationProfile)" -ForegroundColor Yellow
    Write-Host ""
}

function Show-SetupBanner {
    # Skip Clear-Host in non-interactive environments
    if (-not [System.Console]::IsInputRedirected -and $Host.UI.RawUI.WindowSize.Width -gt 0) {
        try {
            Clear-Host
        } catch {
            # Ignore Clear-Host errors in restricted environments
        }
    }
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
    
    try {
        # Import ConfigurationCore module for unified configuration management
        $configCoreModule = Join-Path (Split-Path $PSScriptRoot -Parent) "ConfigurationCore"
        if (Test-Path $configCoreModule) {
            Import-Module $configCoreModule -Force -ErrorAction Stop
            $result.Details += "✓ Loaded ConfigurationCore module"
            
            # Initialize ConfigurationCore
            Initialize-ConfigurationCore
            
            # Register SetupWizard module configuration
            Register-ModuleConfiguration -ModuleName 'SetupWizard' -Schema @{
                Platform = @{ Type = 'string'; Required = $true }
                InstallationProfile = @{ Type = 'string'; Required = $true }
                Settings = @{
                    Type = 'object'
                    Properties = @{
                        Verbosity = @{ Type = 'string'; Default = 'normal' }
                        AutoUpdate = @{ Type = 'boolean'; Default = $true }
                        TelemetryEnabled = @{ Type = 'boolean'; Default = $false }
                        MaxParallelJobs = @{ Type = 'integer'; Default = 4 }
                    }
                }
                Modules = @{
                    Type = 'object'
                    Properties = @{
                        EnabledByDefault = @{ Type = 'array'; Default = @('Logging', 'PatchManager', 'LabRunner') }
                        AutoLoad = @{ Type = 'boolean'; Default = $true }
                    }
                }
            }
            
            # Set initial configuration
            $initialConfig = @{
                Platform = $SetupState.Platform.OS
                InstallationProfile = $SetupState.InstallationProfile
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
            
            Set-ModuleConfiguration -ModuleName 'SetupWizard' -Configuration $initialConfig
            $result.Details += "✓ Initialized SetupWizard configuration with ConfigurationCore"
            
            # Save setup state as module configuration
            Register-ModuleConfiguration -ModuleName 'SetupWizard.State' -Schema @{
                SetupHistory = @{ Type = 'array'; Default = @() }
                LastSetupDate = @{ Type = 'string'; Default = '' }
                SetupVersion = @{ Type = 'string'; Default = '1.0.0' }
            }
            
            $setupStateConfig = @{
                SetupHistory = @($SetupState)
                LastSetupDate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                SetupVersion = '1.0.0'
            }
            
            Set-ModuleConfiguration -ModuleName 'SetupWizard.State' -Configuration $setupStateConfig
            $result.Details += "✓ Saved setup state using ConfigurationCore"
            
        } else {
            # Fallback to legacy configuration method
            $result.Details += "⚠️ ConfigurationCore not found, using legacy configuration"
            
            # Determine config directory
            $configDir = if ($SetupState.Platform.OS -eq 'Windows') {
                Join-Path $env:APPDATA "AitherZero"
            } else {
                Join-Path $env:HOME ".config/aitherzero"
            }
            
            # Create config directory if needed
            if (-not (Test-Path $configDir)) {
                New-Item -Path $configDir -ItemType Directory -Force | Out-Null
                $result.Details += "✓ Created configuration directory: $configDir"
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
                $defaultConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $configFile
                $result.Details += "✓ Created legacy configuration file"
            }
        }
        
        $result.Status = 'Passed'
        
    } catch {
        $result.Status = 'Warning'
        $result.Details += "⚠️ Configuration initialization had issues: $_"
        $result.Details += "✓ Setup can continue, configuration can be set up later"
    }
    
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
    $passed = ($SetupState.Steps | Where-Object { $_.Status -eq 'Passed' -or $_.Status -eq 'Success' }).Count
    $failed = ($SetupState.Steps | Where-Object { $_.Status -eq 'Failed' }).Count
    $warnings = ($SetupState.Steps | Where-Object { $_.Status -eq 'Warning' }).Count
    
    $result.Details += "Setup completed with:"
    $result.Details += "  ✅ Passed: $passed"
    if ($failed -gt 0) {
        $result.Details += "  ❌ Failed: $failed"
    }
    if ($warnings -gt 0) {
        $result.Details += "  ⚠️ Warnings: $warnings"
    }
    
    # Be more lenient with validation - setup is still usable even with some issues
    if ($passed -ge 3) {
        # If we have at least 3 passing steps, consider it successful
        $result.Status = 'Passed'
        $result.Details += ""
        if ($failed -eq 0 -and $warnings -eq 0) {
            $result.Details += "🎉 Setup completed successfully!"
        } elseif ($warnings -gt 0) {
            $result.Details += "✅ Setup completed successfully with optional recommendations"
        } else {
            $result.Details += "✅ Setup completed - AitherZero is ready to use!"
        }
    } else {
        # Only fail if we have very few passing steps
        $result.Status = 'Warning'
        $result.Details += ""
        $result.Details += "⚠️ Setup completed with limited functionality"
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
    
    # Define critical vs optional steps
    $criticalSteps = @('Platform Detection', 'PowerShell Version', 'Configuration Files', 'Final Validation')
    
    # Check status of critical vs optional steps
    $criticalFailed = ($State.Steps | Where-Object { 
        $_.Status -eq 'Failed' -and $_.Name -in $criticalSteps 
    }).Count
    
    $optionalWarnings = ($State.Steps | Where-Object { 
        $_.Status -eq 'Warning' -and $_.Name -notin $criticalSteps 
    }).Count
    
    $allPassed = ($State.Steps | Where-Object { $_.Status -eq 'Passed' -or $_.Status -eq 'Success' }).Count
    $totalSteps = $State.Steps.Count
    
    # Overall status based on critical failures
    if ($criticalFailed -gt 0) {
        Write-Host "  ❌ Setup Status: CRITICAL FAILURE" -ForegroundColor Red
        Write-Host "     Critical components failed - AitherZero cannot run!" -ForegroundColor Red
    } elseif ($allPassed -eq $totalSteps) {
        Write-Host "  🎉 Setup Status: PERFECT! ALL COMPONENTS READY" -ForegroundColor Green
    } elseif ($optionalWarnings -gt 0) {
        Write-Host "  ✅ Setup Status: READY TO USE (with optional components missing)" -ForegroundColor Yellow
        Write-Host "     AitherZero will work, but some features may be limited" -ForegroundColor Yellow
    } else {
        Write-Host "  ✅ Setup Status: READY TO USE" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "  Setup Results:" -ForegroundColor White
    foreach ($step in $State.Steps) {
        $icon = switch ($step.Status) {
            'Passed' { '✅' }
            'Success' { '✅' }
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
    Write-Host ""
    Write-Host "  📁 Configuration saved to:" -ForegroundColor White
    Write-Host "     $(if ($State.Platform.OS -eq 'Windows') { "$env:APPDATA\AitherZero" } else { "~/.config/aitherzero" })" -ForegroundColor Gray
    Write-Host ""
    
    # Show clear what to do next
    Write-Host "  🚀 WHAT TO DO NEXT:" -ForegroundColor Green
    Write-Host "  ═══════════════════" -ForegroundColor Green
    Write-Host ""
    
    if ($criticalFailed -eq 0) {
        Write-Host "  Your setup is complete! AitherZero is ready to use." -ForegroundColor White
        Write-Host ""
        Write-Host "  TO START USING AITHERZERO:" -ForegroundColor Cyan
        Write-Host "  1. Close this setup window" -ForegroundColor White
        Write-Host "  2. Run one of these commands:" -ForegroundColor White
        Write-Host ""
        Write-Host "     INTERACTIVE MODE (Recommended for first time):" -ForegroundColor Yellow
        Write-Host "     ./Start-AitherZero.ps1" -ForegroundColor Green
        Write-Host ""
        Write-Host "     RUN SPECIFIC MODULE:" -ForegroundColor Yellow
        Write-Host "     ./Start-AitherZero.ps1 -Scripts 'LabRunner'" -ForegroundColor Green
        Write-Host ""
        Write-Host "     AUTOMATED MODE:" -ForegroundColor Yellow
        Write-Host "     ./Start-AitherZero.ps1 -Auto" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  CRITICAL ISSUES MUST BE FIXED FIRST:" -ForegroundColor Red
        Write-Host ""
        foreach ($critical in ($State.Steps | Where-Object { $_.Status -eq 'Failed' -and $_.Name -in $criticalSteps })) {
            Write-Host "     • Fix: $($critical.Name)" -ForegroundColor Red
            if ($critical.Details) {
                $critical.Details | Where-Object { $_ -match "^❌" } | ForEach-Object {
                    Write-Host "       $_" -ForegroundColor Gray
                }
            }
        }
    }
    
    Write-Host ""
}

function Show-SetupPrompt {
    param(
        [string]$Message,
        [switch]$DefaultYes
    )
    
    # In non-interactive mode or when host doesn't support prompts, use default
    if ([System.Console]::IsInputRedirected -or $env:NO_PROMPT -or $global:WhatIfPreference) {
        Write-Host "$Message [$(if ($DefaultYes) { 'Y' } else { 'N' })]" -ForegroundColor Yellow
        return $DefaultYes
    }
    
    try {
        $choices = '&Yes', '&No'
        $decision = $Host.UI.PromptForChoice('', $Message, $choices, $(if ($DefaultYes) { 0 } else { 1 }))
        return $decision -eq 0
    } catch {
        # Fallback to default if prompt fails
        Write-Host "$Message [$(if ($DefaultYes) { 'Y' } else { 'N' })] (auto-selected)" -ForegroundColor Yellow
        return $DefaultYes
    }
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

function Show-EnhancedInstallationProfile {
    param(
        [string]$Profile,
        [hashtable]$ProfileInfo
    )
    
    Write-Host ""
    Write-Host "  🎯 Installation Profile: $($ProfileInfo.Name.ToUpper())" -ForegroundColor Cyan
    Write-Host "  Description: $($ProfileInfo.Description)" -ForegroundColor Gray
    Write-Host "  Estimated Time: $($ProfileInfo.EstimatedTime)" -ForegroundColor Yellow
    
    if ($ProfileInfo.TargetUse -and $ProfileInfo.TargetUse.Count -gt 0) {
        Write-Host "  Target Use Cases: $($ProfileInfo.TargetUse -join ', ')" -ForegroundColor Blue
    }
    
    Write-Host ""
    Write-Host "  Setup Steps ($($ProfileInfo.Steps.Count + 5) total):" -ForegroundColor White
    
    # Show required vs optional steps
    $requiredSteps = ($ProfileInfo.Steps | Where-Object { $_.Required -eq $true }).Count + 3  # Base required steps
    $optionalSteps = ($ProfileInfo.Steps | Where-Object { $_.Required -ne $true }).Count + 2  # Base optional steps
    
    Write-Host "    ✓ Required Steps: $requiredSteps" -ForegroundColor Green
    Write-Host "    ⚠️ Optional Steps: $optionalSteps" -ForegroundColor Yellow
    
    Write-Host ""
}

function Get-SetupSteps {
    param(
        [string]$Profile,
        [hashtable]$CustomProfile = @{}
    )
    
    # STREAMLINED: Only essential steps for fast startup
    $baseSteps = @(
        @{Name = 'Platform Detection'; Function = 'Test-PlatformRequirements'; AllProfiles = $true; Required = $true},
        @{Name = 'PowerShell Version'; Function = 'Test-PowerShellVersion'; AllProfiles = $true; Required = $true},
        @{Name = 'Configuration Files'; Function = 'Initialize-ConfigurationFiles'; AllProfiles = $true; Required = $true}
    )
    
    # Optional steps moved to Configuration Manager
    # These were causing setup delays: Git, Infrastructure Tools, Module Dependencies
    # Users can install these later through the working AitherZero interface
    
    # Enhanced profile definitions with metadata
    $profileDefinitions = @{
        'minimal' = @{
            Name = 'Minimal'
            Description = 'Core AitherZero functionality only'
            TargetUse = @('CI/CD', 'Containers', 'Basic Infrastructure')
            EstimatedTime = '30 seconds'
            Steps = @(
                # STREAMLINED: No additional steps - base steps are sufficient
            )
        }
        'developer' = @{
            Name = 'Developer'
            Description = 'Development workstation setup with AI tools'
            TargetUse = @('Development', 'AI Tools', 'VS Code Integration')
            EstimatedTime = '1 minute'
            Steps = @(
                # STREAMLINED: Optional tools moved to Configuration Manager
                # Users can install Node.js, AI Tools, etc. from the working AitherZero interface
            )
        }
        'full' = @{
            Name = 'Full'
            Description = 'Complete installation with all features'
            TargetUse = @('Production', 'Enterprise', 'Complete Infrastructure')
            EstimatedTime = '1 minute'
            Steps = @(
                # STREAMLINED: Enterprise features moved to Configuration Manager
                # Users can install Cloud CLIs, Security tools, etc. from working AitherZero interface
            )
        }
        'custom' = @{
            Name = 'Custom'
            Description = 'User-defined custom profile'
            TargetUse = @('Customized Setup')
            EstimatedTime = 'Variable'
            Steps = $CustomProfile.Steps ?? @()
        }
    }
    
    # Handle custom profile
    if ($CustomProfile.Count -gt 0) {
        $Profile = 'custom'
        $profileDefinitions['custom'] = $CustomProfile
    }
    
    # Get the profile definition
    $profileDef = $profileDefinitions[$Profile]
    if (-not $profileDef) {
        Write-Warning "Unknown profile '$Profile', falling back to minimal"
        $profileDef = $profileDefinitions['minimal']
    }
    
    # Combine base steps with profile-specific steps and deduplicate by name
    $combinedSteps = $baseSteps + $profileDef.Steps
    $allSteps = @($combinedSteps | Group-Object Name | ForEach-Object { $_.Group[0] })
    
    return @{
        Steps = $allSteps
        Profile = $profileDef
        EstimatedSteps = $allSteps.Count
    }
}

function Test-DevEnvironment {
    param($SetupState)
    
    $result = @{
        Name = 'Development Environment'
        Status = 'Unknown'
        Details = @()
    }
    
    try {
        # Check for VS Code
        $vsCodeFound = $false
        $vsCodePaths = @(
            "${env:ProgramFiles}\Microsoft VS Code\Code.exe",
            "${env:LOCALAPPDATA}\Programs\Microsoft VS Code\Code.exe",
            "/usr/bin/code",
            "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
        )
        
        foreach ($path in $vsCodePaths) {
            if (Test-Path $path) {
                $vsCodeFound = $true
                $result.Details += "✓ VS Code found at: $path"
                break
            }
        }
        
        if (-not $vsCodeFound -and (Get-Command code -ErrorAction SilentlyContinue)) {
            $vsCodeFound = $true
            $result.Details += "✓ VS Code available in PATH"
        }
        
        if (-not $vsCodeFound) {
            $result.Details += "⚠️ VS Code not found"
            $SetupState.Recommendations += "Install VS Code for enhanced development experience"
        }
        
        # Check for DevEnvironment module
        $devEnvModule = Join-Path (Split-Path $PSScriptRoot -Parent) "DevEnvironment"
        if (Test-Path $devEnvModule) {
            Import-Module $devEnvModule -Force -ErrorAction SilentlyContinue
            $result.Details += "✓ DevEnvironment module available"
            
            # Test VS Code workspace setup
            if ($vsCodeFound -and (Get-Command Initialize-VSCodeWorkspace -ErrorAction SilentlyContinue)) {
                $result.Details += "✓ VS Code workspace setup available"
            }
        } else {
            $result.Details += "⚠️ DevEnvironment module not found"
        }
        
        $result.Status = if ($vsCodeFound) { 'Passed' } else { 'Warning' }
        
    } catch {
        $result.Status = 'Warning'
        $result.Details += "⚠️ Development environment check failed: $_"
    }
    
    return $result
}

function Test-LicenseIntegration {
    param($SetupState)
    
    $result = @{
        Name = 'License Management'
        Status = 'Unknown'
        Details = @()
    }
    
    try {
        # Check for LicenseManager module
        $licenseModule = Join-Path (Split-Path $PSScriptRoot -Parent) "LicenseManager"
        if (Test-Path $licenseModule) {
            Import-Module $licenseModule -Force -ErrorAction SilentlyContinue
            $result.Details += "✓ LicenseManager module available"
            
            # Test basic license functionality
            if (Get-Command Get-LicenseStatus -ErrorAction SilentlyContinue) {
                $result.Details += "✓ License management functions available"
                $result.Status = 'Passed'
            } else {
                $result.Details += "⚠️ License functions not properly loaded"
                $result.Status = 'Warning'
            }
        } else {
            $result.Details += "ℹ️ LicenseManager module not found (optional)"
            $result.Status = 'Passed'
        }
        
    } catch {
        $result.Status = 'Warning'
        $result.Details += "⚠️ License integration check failed: $_"
    }
    
    return $result
}

function Test-ModuleCommunication {
    param($SetupState)
    
    $result = @{
        Name = 'Module Communication'
        Status = 'Unknown'
        Details = @()
    }
    
    try {
        # Check for ModuleCommunication module
        $commModule = Join-Path (Split-Path $PSScriptRoot -Parent) "ModuleCommunication"
        if (Test-Path $commModule) {
            Import-Module $commModule -Force -ErrorAction SilentlyContinue
            $result.Details += "✓ ModuleCommunication module available"
            
            # Test basic communication functionality
            if (Get-Command Get-CommunicationStatus -ErrorAction SilentlyContinue) {
                $result.Details += "✓ Module communication functions available"
                $result.Status = 'Passed'
            } else {
                $result.Details += "⚠️ Communication functions not properly loaded"
                $result.Status = 'Warning'
            }
        } else {
            $result.Details += "ℹ️ ModuleCommunication module not found (optional)"
            $result.Status = 'Passed'
        }
        
    } catch {
        $result.Status = 'Warning'
        $result.Details += "⚠️ Module communication check failed: $_"
    }
    
    return $result
}

function Test-NodeJsInstallation {
    param($SetupState)
    
    $result = @{
        Name = 'Node.js Detection'
        Status = 'Unknown'
        Details = @()
        ErrorDetails = @()
        RecoveryOptions = @()
    }
    
    try {
        # Check if node command exists first
        $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
        
        if ($nodeCmd) {
            $nodeVersion = & $nodeCmd --version 2>$null
            if ($nodeVersion) {
                $result.Status = 'Passed'
                $result.Details += "✓ Node.js $nodeVersion installed"
                
                # Check npm
                $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
                if ($npmCmd) {
                    $npmVersion = & $npmCmd --version 2>$null
                    if ($npmVersion) {
                        $result.Details += "✓ npm $npmVersion available"
                    }
                }
            } else {
                $result.Status = 'Warning'
                $result.Details += "⚠️ Node.js found but version check failed"
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

# Enhanced error handling and recovery functions
function Invoke-ErrorRecovery {
    <#
    .SYNOPSIS
        Enhanced error recovery system for setup failures
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$StepResult,
        
        [Parameter(Mandatory)]
        [hashtable]$SetupState,
        
        [string]$StepName
    )
    
    $recovery = @{
        Attempted = $false
        Success = $false
        Method = ''
        Details = @()
    }
    
    # Determine recovery strategy based on step type and error
    switch ($StepName) {
        'Node.js Detection' {
            $recovery.Method = 'Package Manager Installation'
            $recovery.Details += "Attempting to install Node.js via package manager..."
            
            try {
                if ($IsWindows) {
                    if (Get-Command winget -ErrorAction SilentlyContinue) {
                        & winget install OpenJS.NodeJS --silent
                        $recovery.Success = $true
                        $recovery.Details += "✓ Node.js installed via winget"
                    } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
                        & choco install nodejs -y
                        $recovery.Success = $true
                        $recovery.Details += "✓ Node.js installed via Chocolatey"
                    }
                } elseif ($IsLinux) {
                    if (Get-Command apt -ErrorAction SilentlyContinue) {
                        & sudo apt update && sudo apt install -y nodejs npm
                        $recovery.Success = $true
                        $recovery.Details += "✓ Node.js installed via apt"
                    } elseif (Get-Command yum -ErrorAction SilentlyContinue) {
                        & sudo yum install -y nodejs npm
                        $recovery.Success = $true
                        $recovery.Details += "✓ Node.js installed via yum"
                    }
                } elseif ($IsMacOS) {
                    if (Get-Command brew -ErrorAction SilentlyContinue) {
                        & brew install node
                        $recovery.Success = $true
                        $recovery.Details += "✓ Node.js installed via Homebrew"
                    }
                }
                
                $recovery.Attempted = $true
                
            } catch {
                $recovery.Details += "⚠️ Automatic installation failed: $_"
                $recovery.Details += "Manual installation required: https://nodejs.org"
            }
        }
        
        'Git Installation' {
            $recovery.Method = 'Package Manager Installation'
            $recovery.Details += "Attempting to install Git via package manager..."
            
            try {
                if ($IsWindows) {
                    if (Get-Command winget -ErrorAction SilentlyContinue) {
                        & winget install Git.Git --silent
                        $recovery.Success = $true
                        $recovery.Details += "✓ Git installed via winget"
                    }
                } elseif ($IsLinux) {
                    if (Get-Command apt -ErrorAction SilentlyContinue) {
                        & sudo apt update && sudo apt install -y git
                        $recovery.Success = $true
                        $recovery.Details += "✓ Git installed via apt"
                    }
                } elseif ($IsMacOS) {
                    if (Get-Command brew -ErrorAction SilentlyContinue) {
                        & brew install git
                        $recovery.Success = $true
                        $recovery.Details += "✓ Git installed via Homebrew"
                    }
                }
                
                $recovery.Attempted = $true
                
            } catch {
                $recovery.Details += "⚠️ Automatic installation failed: $_"
                $recovery.Details += "Manual installation required"
            }
        }
        
        'Configuration Files' {
            $recovery.Method = 'Directory Creation and Permissions Fix'
            $recovery.Details += "Attempting to create configuration directories with proper permissions..."
            
            try {
                # Create config directories
                $configDir = if ($IsWindows) {
                    Join-Path $env:APPDATA "AitherZero"
                } else {
                    Join-Path $env:HOME ".config/aitherzero"
                }
                
                New-Item -Path $configDir -ItemType Directory -Force | Out-Null
                
                # Set appropriate permissions
                if (-not $IsWindows) {
                    & chmod 755 $configDir
                }
                
                $recovery.Success = $true
                $recovery.Attempted = $true
                $recovery.Details += "✓ Configuration directory created: $configDir"
                
            } catch {
                $recovery.Details += "⚠️ Directory creation failed: $_"
            }
        }
        
        default {
            $recovery.Method = 'Generic Retry'
            $recovery.Details += "No specific recovery method available for: $StepName"
        }
    }
    
    return $recovery
}

function Show-EnhancedProgress {
    <#
    .SYNOPSIS
        Enhanced progress display with error context
    #>
    param(
        [hashtable]$State,
        [string]$StepName,
        [string]$Status = 'Running',
        [hashtable]$ErrorContext = @{}
    )
    
    $percentage = [math]::Round(($State.CurrentStep / $State.TotalSteps) * 100)
    $progressBar = "[" + ("█" * [math]::Floor($percentage / 5)) + ("░" * (20 - [math]::Floor($percentage / 5))) + "]"
    
    # Status emoji mapping
    $statusEmoji = @{
        'Running' = '🔍'
        'Success' = '✅'
        'Warning' = '⚠️'
        'Failed' = '❌'
        'Retrying' = '🔄'
        'Recovering' = '🔧'
    }
    
    $emoji = $statusEmoji[$Status] ?? '🔍'
    
    Write-Host ""
    Write-Host "  $progressBar $percentage% - Step $($State.CurrentStep)/$($State.TotalSteps)" -ForegroundColor Cyan
    
    # Show status with appropriate color
    $statusColor = switch ($Status) {
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Failed' { 'Red' }
        'Retrying' { 'Magenta' }
        'Recovering' { 'Blue' }
        default { 'Yellow' }
    }
    
    Write-Host "  $emoji $StepName - $Status" -ForegroundColor $statusColor
    
    # Show error context if provided
    if ($ErrorContext.Count -gt 0) {
        if ($ErrorContext.LastError) {
            Write-Host "    Error: $($ErrorContext.LastError)" -ForegroundColor Red
        }
        if ($ErrorContext.RecoveryAttempted) {
            Write-Host "    Recovery: $($ErrorContext.RecoveryMethod)" -ForegroundColor Blue
        }
    }
    
    # Update ProgressTracking if available
    if ($global:ProgressTrackingOperationId) {
        try {
            Update-ProgressOperation -OperationId $global:ProgressTrackingOperationId `
                -IncrementStep -StepName "$StepName ($Status)"
        } catch {
            # Ignore ProgressTracking errors
        }
    }
}

function Get-DetailedSystemInfo {
    <#
    .SYNOPSIS
        Get detailed system information for troubleshooting
    #>
    
    $sysInfo = @{
        OS = @{}
        PowerShell = @{}
        Hardware = @{}
        Network = @{}
        Security = @{}
    }
    
    try {
        # OS Information
        $sysInfo.OS.Platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } else { 'macOS' }
        $sysInfo.OS.Version = [System.Environment]::OSVersion.Version.ToString()
        $sysInfo.OS.Architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
        
        # PowerShell Information
        $sysInfo.PowerShell.Version = $PSVersionTable.PSVersion.ToString()
        $sysInfo.PowerShell.Edition = $PSVersionTable.PSEdition
        $sysInfo.PowerShell.ExecutionPolicy = Get-ExecutionPolicy
        
        # Hardware Information
        if ($IsWindows) {
            $sysInfo.Hardware.Memory = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
            $sysInfo.Hardware.Processor = (Get-CimInstance Win32_Processor).Name
        } else {
            # Basic info for Linux/macOS
            $sysInfo.Hardware.Memory = "N/A (non-Windows)"
            $sysInfo.Hardware.Processor = "N/A (non-Windows)"
        }
        
        # Network Information
        $sysInfo.Network.InternetConnected = Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet
        if ($env:HTTP_PROXY -or $env:HTTPS_PROXY) {
            $sysInfo.Network.ProxyConfigured = $true
            $sysInfo.Network.ProxyDetails = @{
                HTTP = $env:HTTP_PROXY
                HTTPS = $env:HTTPS_PROXY
            }
        } else {
            $sysInfo.Network.ProxyConfigured = $false
        }
        
        # Security Information
        if ($IsWindows) {
            try {
                $defender = Get-MpPreference -ErrorAction SilentlyContinue
                $sysInfo.Security.DefenderEnabled = $defender -ne $null
            } catch {
                $sysInfo.Security.DefenderEnabled = "Unknown"
            }
        }
        
    } catch {
        Write-Verbose "Error gathering system info: $_"
    }
    
    return $sysInfo
}

# Export functions
Export-ModuleMember -Function @(
    'Start-IntelligentSetup',
    'Get-PlatformInfo',
    'Generate-QuickStartGuide',
    'Get-InstallationProfile',
    'Install-AITools',
    'Edit-Configuration',
    'Review-Configuration',
    'Show-WelcomeMessage',
    'Show-SetupBanner',
    'Show-Progress',
    'Show-EnhancedProgress',
    'Show-SetupSummary',
    'Show-SetupPrompt',
    'Show-InstallationProfile',
    'Get-SetupSteps',
    'Invoke-ErrorRecovery',
    'Get-DetailedSystemInfo',
    'Test-*'
)