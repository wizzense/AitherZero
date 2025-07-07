#Requires -Version 7.0

<#
.SYNOPSIS
    Unified User Experience module for AitherZero
.DESCRIPTION
    Provides comprehensive user experience management combining intelligent setup,
    interactive UI, configuration management, and user guidance systems.
    
    This module consolidates the functionality from SetupWizard and StartupExperience
    into a single, cohesive user experience system.
    
.NOTES
    - Supports both first-time setup and ongoing interactive usage
    - Provides intelligent platform detection and configuration
    - Offers rich terminal UI with fallback to basic mode
    - Includes comprehensive user guidance and help systems
    - Manages user profiles and preferences
    - Supports progressive disclosure from beginner to expert workflows
#>

# Module initialization and error handling
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Get module paths and project root
$moduleRoot = $PSScriptRoot
if (-not $moduleRoot) {
    $moduleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

# Import shared utilities with multiple fallback paths
$sharedPaths = @(
    (Join-Path (Split-Path (Split-Path $moduleRoot -Parent) -Parent) "shared" "Find-ProjectRoot.ps1"),
    (Join-Path (Split-Path $moduleRoot -Parent) "shared" "Find-ProjectRoot.ps1"),
    (Join-Path $moduleRoot ".." ".." "shared" "Find-ProjectRoot.ps1")
)

$foundSharedUtil = $false
foreach ($sharedPath in $sharedPaths) {
    if (Test-Path $sharedPath) {
        . $sharedPath
        Write-Verbose "UserExperience: Loaded Find-ProjectRoot from: $sharedPath"
        $foundSharedUtil = $true
        break
    }
}

if (-not $foundSharedUtil) {
    # Define Find-ProjectRoot locally as fallback
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
    Write-Verbose "UserExperience: Using fallback Find-ProjectRoot function"
}

# Get project root for module dependencies
try {
    $projectRoot = Find-ProjectRoot -StartPath $moduleRoot
    Write-Verbose "UserExperience: Project root located at: $projectRoot"
} catch {
    Write-Warning "UserExperience: Could not locate project root: $_"
    $projectRoot = Split-Path (Split-Path $moduleRoot -Parent) -Parent
}

# Module-level variables for state management
$script:UserExperienceState = @{
    Initialized = $false
    CurrentMode = 'Unknown'
    UserProfile = $null
    UICapabilities = $null
    ModuleRoot = $moduleRoot
    ProjectRoot = $projectRoot
    StartTime = Get-Date
    SessionId = [System.Guid]::NewGuid().ToString()
}

# User configuration and profile paths
$script:UserConfigPaths = @{
    UserProfile = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.aitherzero'
    Profiles = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.aitherzero' 'profiles'
    Preferences = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.aitherzero' 'preferences.json'
    Sessions = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.aitherzero' 'sessions'
    Cache = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.aitherzero' 'cache'
}

# Ensure user directories exist
foreach ($pathKey in $script:UserConfigPaths.Keys) {
    $path = $script:UserConfigPaths[$pathKey]
    if ($pathKey -ne 'Preferences') {  # Skip file paths
        try {
            if (-not (Test-Path $path)) {
                New-Item -Path $path -ItemType Directory -Force | Out-Null
                Write-Verbose "UserExperience: Created directory: $path"
            }
        } catch {
            Write-Warning "UserExperience: Could not create directory $path`: $_"
        }
    }
}

# Import dependent modules with error handling
$dependentModules = @{
    'ConfigurationCore' = @{
        Path = Join-Path (Split-Path $moduleRoot -Parent) "ConfigurationCore"
        Required = $false
        LoadedSuccessfully = $false
    }
    'Logging' = @{
        Path = Join-Path (Split-Path $moduleRoot -Parent) "Logging"
        Required = $false
        LoadedSuccessfully = $false
    }
    'LicenseManager' = @{
        Path = Join-Path (Split-Path $moduleRoot -Parent) "LicenseManager"
        Required = $false
        LoadedSuccessfully = $false
    }
    'ProgressTracking' = @{
        Path = Join-Path (Split-Path $moduleRoot -Parent) "ProgressTracking"
        Required = $false
        LoadedSuccessfully = $false
    }
}

foreach ($moduleName in $dependentModules.Keys) {
    $moduleInfo = $dependentModules[$moduleName]
    try {
        if (Test-Path $moduleInfo.Path) {
            Import-Module $moduleInfo.Path -Force -ErrorAction Stop
            $moduleInfo.LoadedSuccessfully = $true
            Write-Verbose "UserExperience: Successfully loaded $moduleName module"
        } else {
            Write-Verbose "UserExperience: Module $moduleName not found at: $($moduleInfo.Path)"
        }
    } catch {
        Write-Verbose "UserExperience: Could not load $moduleName module: $_"
        if ($moduleInfo.Required) {
            throw "Required module $moduleName could not be loaded: $_"
        }
    }
}

# Provide fallback functions for optional dependencies
if (-not $dependentModules['Logging'].LoadedSuccessfully) {
    function Write-CustomLog {
        param(
            [string]$Level = 'INFO',
            [string]$Message,
            [string]$Source = 'UserExperience'
        )
        
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $logEntry = "[$timestamp] [$Level] [$Source] $Message"
        
        switch ($Level.ToUpper()) {
            'ERROR' { Write-Error $logEntry }
            'WARNING' { Write-Warning $logEntry }
            'DEBUG' { Write-Debug $logEntry }
            default { Write-Verbose $logEntry }
        }
    }
    Write-Verbose "UserExperience: Using fallback Write-CustomLog function"
}

if (-not $dependentModules['LicenseManager'].LoadedSuccessfully) {
    function Test-FeatureAccess {
        param(
            [string]$FeatureName,
            [string]$ModuleName = 'UserExperience',
            [switch]$ThrowOnDenied
        )
        # Without license management, all features are accessible
        return $true
    }
    
    function Get-LicenseStatus {
        return @{
            Tier = 'free'
            Status = 'Active'
            Features = @('core', 'setup', 'interactive')
        }
    }
    Write-Verbose "UserExperience: Using fallback license management functions"
}

if (-not $dependentModules['ProgressTracking'].LoadedSuccessfully) {
    function Start-ProgressOperation {
        param($OperationName, $TotalSteps, [switch]$ShowTime, [switch]$ShowETA)
        return [System.Guid]::NewGuid().ToString()
    }
    
    function Update-ProgressOperation {
        param($OperationId, [switch]$IncrementStep, $StepName)
        # No-op fallback
    }
    
    function Complete-ProgressOperation {
        param($OperationId, [switch]$ShowSummary)
        # No-op fallback
    }
    Write-Verbose "UserExperience: Using fallback progress tracking functions"
}

# Load all private functions with comprehensive error handling
$privateFunctions = Get-ChildItem -Path (Join-Path $moduleRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue
$privateLoadCount = 0
$privateFailCount = 0

foreach ($function in $privateFunctions) {
    try {
        . $function.FullName
        $privateLoadCount++
        Write-Verbose "UserExperience: Loaded private function: $($function.BaseName)"
    } catch {
        $privateFailCount++
        Write-Warning "UserExperience: Failed to load private function $($function.BaseName): $_"
    }
}

# Load all public functions with comprehensive error handling
$publicFunctions = Get-ChildItem -Path (Join-Path $moduleRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue
$publicLoadCount = 0
$publicFailCount = 0

foreach ($function in $publicFunctions) {
    try {
        . $function.FullName
        $publicLoadCount++
        Write-Verbose "UserExperience: Loaded public function: $($function.BaseName)"
    } catch {
        $publicFailCount++
        Write-Warning "UserExperience: Failed to load public function $($function.BaseName): $_"
    }
}

# Initialize module state
$script:UserExperienceState.Initialized = $true
$script:UserExperienceState.CurrentMode = 'Ready'

# Log module initialization results
$initMessage = "UserExperience module initialized successfully. " +
              "Loaded $publicLoadCount public functions, $privateLoadCount private functions. " +
              "Failed to load $publicFailCount public, $privateFailCount private functions."

Write-CustomLog -Level 'INFO' -Message $initMessage -Source 'UserExperience'

# Create module initialization event for other modules
if (Get-Command Publish-ModuleEvent -ErrorAction SilentlyContinue) {
    try {
        Publish-ModuleEvent -EventName 'ModuleInitialized' -EventData @{
            ModuleName = 'UserExperience'
            Version = '1.0.0'
            LoadedFunctions = @{
                Public = $publicLoadCount
                Private = $privateLoadCount
            }
            Dependencies = $dependentModules
            InitializationTime = (Get-Date) - $script:UserExperienceState.StartTime
        }
    } catch {
        Write-Verbose "UserExperience: Could not publish module initialization event: $_"
    }
}

# Export module state for diagnostics
function Get-UserExperienceState {
    <#
    .SYNOPSIS
        Gets the current state of the UserExperience module
    .DESCRIPTION
        Returns diagnostic information about the UserExperience module state,
        loaded dependencies, and configuration
    #>
    [CmdletBinding()]
    param()
    
    return [PSCustomObject]@{
        State = $script:UserExperienceState.Clone()
        ConfigPaths = $script:UserConfigPaths.Clone()
        Dependencies = $dependentModules.Clone()
        LoadedFunctions = @{
            Public = $publicLoadCount
            Private = $privateLoadCount
        }
        FailedFunctions = @{
            Public = $publicFailCount
            Private = $privateFailCount
        }
        ModuleVersion = '1.0.0'
        LastInitialized = $script:UserExperienceState.StartTime
    }
}

# Module cleanup function
function Reset-UserExperience {
    <#
    .SYNOPSIS
        Resets the UserExperience module to initial state
    .DESCRIPTION
        Cleans up module state, resets UI, and prepares for reinitialization
    #>
    [CmdletBinding()]
    param([switch]$Force)
    
    try {
        Write-CustomLog -Level 'INFO' -Message "Resetting UserExperience module state" -Source 'UserExperience'
        
        # Reset UI if applicable
        if (Get-Command Reset-TerminalUI -ErrorAction SilentlyContinue) {
            Reset-TerminalUI
        }
        
        # Clear module state
        $script:UserExperienceState = @{
            Initialized = $false
            CurrentMode = 'Reset'
            UserProfile = $null
            UICapabilities = $null
            ModuleRoot = $moduleRoot
            ProjectRoot = $projectRoot
            StartTime = Get-Date
            SessionId = [System.Guid]::NewGuid().ToString()
        }
        
        Write-CustomLog -Level 'INFO' -Message "UserExperience module reset completed" -Source 'UserExperience'
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Error resetting UserExperience module: $_" -Source 'UserExperience'
        if (-not $Force) {
            throw
        }
    }
}

# Final module initialization log
Write-Verbose "UserExperience module loaded from $moduleRoot with $($publicFunctions.Count) public functions available"
Write-CustomLog -Level 'INFO' -Message "UserExperience module initialization complete" -Source 'UserExperience'