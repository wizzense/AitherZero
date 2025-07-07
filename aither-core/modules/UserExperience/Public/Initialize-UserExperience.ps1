function Initialize-UserExperience {
    <#
    .SYNOPSIS
        Initializes the UserExperience module and prepares the user environment
    .DESCRIPTION
        Sets up the user environment, detects capabilities, loads preferences,
        and prepares the system for optimal user experience
    .PARAMETER Force
        Force reinitialization even if already initialized
    .PARAMETER SkipCapabilityDetection
        Skip terminal capability detection for faster initialization
    .EXAMPLE
        Initialize-UserExperience
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Force,
        
        [Parameter()]
        [switch]$SkipCapabilityDetection
    )
    
    try {
        Write-CustomLog -Level 'INFO' -Message "Initializing UserExperience module" -Source 'UserExperience'
        
        # Check if already initialized
        if ($script:UserExperienceState.Initialized -and -not $Force) {
            Write-Verbose "UserExperience already initialized. Use -Force to reinitialize."
            return $script:UserExperienceState
        }
        
        # Reset state for reinitialization
        if ($Force) {
            Write-Verbose "Force reinitializing UserExperience"
            Reset-UserExperience -Force
        }
        
        # Detect system and terminal capabilities
        if (-not $SkipCapabilityDetection) {
            Write-Verbose "Detecting system capabilities..."
            $script:UserExperienceState.UICapabilities = Get-TerminalCapabilities
            $script:UserExperienceState.SystemInfo = Get-SystemInfo
            $script:UserExperienceState.PlatformInfo = Get-PlatformInfo
        }
        
        # Load user preferences if they exist
        Write-Verbose "Loading user preferences..."
        $userPreferences = Initialize-UserPreferences
        $script:UserExperienceState.UserPreferences = $userPreferences
        
        # Initialize configuration management
        Write-Verbose "Initializing configuration management..."
        Initialize-ConfigurationManagement
        
        # Set up logging preferences
        if ($userPreferences.Logging) {
            try {
                Set-LoggingPreferences -Preferences $userPreferences.Logging
            } catch {
                Write-Verbose "Could not apply logging preferences: $_"
            }
        }
        
        # Initialize module discovery cache
        Write-Verbose "Initializing module discovery..."
        Initialize-ModuleDiscovery
        
        # Set up event handling
        Initialize-EventHandling
        
        # Detect available profiles
        $availableProfiles = Get-AvailableUserProfiles
        $script:UserExperienceState.AvailableProfiles = $availableProfiles
        
        # Load default profile if available
        $defaultProfile = Get-DefaultUserProfile
        if ($defaultProfile) {
            try {
                Set-UserProfile -Name $defaultProfile.Name -Quiet
                Write-Verbose "Loaded default profile: $($defaultProfile.Name)"
            } catch {
                Write-Verbose "Could not load default profile: $_"
            }
        }
        
        # Initialize feature flags
        Initialize-FeatureFlags
        
        # Set up performance monitoring
        Initialize-PerformanceMonitoring
        
        # Mark as initialized
        $script:UserExperienceState.Initialized = $true
        $script:UserExperienceState.CurrentMode = 'Initialized'
        $script:UserExperienceState.InitializationTime = Get-Date
        
        Write-CustomLog -Level 'INFO' -Message "UserExperience initialization completed successfully" -Source 'UserExperience'
        
        return $script:UserExperienceState
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to initialize UserExperience: $_" -Source 'UserExperience'
        $script:UserExperienceState.Initialized = $false
        $script:UserExperienceState.CurrentMode = 'Failed'
        $script:UserExperienceState.LastError = $_
        throw
    }
}

function Initialize-UserPreferences {
    <#
    .SYNOPSIS
        Loads or creates user preferences
    #>
    
    $preferencesFile = $script:UserConfigPaths.Preferences
    
    if (Test-Path $preferencesFile) {
        try {
            $preferences = Get-Content $preferencesFile -Raw | ConvertFrom-Json
            Write-Verbose "Loaded user preferences from: $preferencesFile"
            return $preferences
        } catch {
            Write-Warning "Could not load user preferences: $_"
        }
    }
    
    # Create default preferences
    $defaultPreferences = @{
        Version = '1.0'
        DefaultMode = 'Interactive'
        Theme = 'Auto'
        Verbosity = 'Normal'
        ExpertMode = $false
        TutorialCompleted = $false
        Accessibility = @{
            HighContrast = $false
            LargeText = $false
            ScreenReader = $false
        }
        UI = @{
            ShowWelcome = $true
            ShowTips = $true
            AnimationSpeed = 'Normal'
            CompactMode = $false
        }
        Logging = @{
            Level = 'INFO'
            EnableFileLogging = $true
            MaxLogSize = '10MB'
        }
        Performance = @{
            EnableCaching = $true
            MaxCacheSize = '50MB'
            EnableTelemetry = $false
        }
        CreatedDate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        LastModified = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    }
    
    # Save default preferences
    try {
        $defaultPreferences | ConvertTo-Json -Depth 5 | Set-Content -Path $preferencesFile
        Write-Verbose "Created default user preferences at: $preferencesFile"
    } catch {
        Write-Warning "Could not save default preferences: $_"
    }
    
    return $defaultPreferences
}

function Initialize-ConfigurationManagement {
    <#
    .SYNOPSIS
        Initializes configuration management integration
    #>
    
    try {
        # Check if ConfigurationCore is available
        if (Get-Command Initialize-ConfigurationCore -ErrorAction SilentlyContinue) {
            Initialize-ConfigurationCore
            
            # Register UserExperience configuration schema
            Register-ModuleConfiguration -ModuleName 'UserExperience' -Schema @{
                UserPreferences = @{
                    Type = 'object'
                    Properties = @{
                        DefaultMode = @{ Type = 'string'; Default = 'Interactive' }
                        Theme = @{ Type = 'string'; Default = 'Auto' }
                        ExpertMode = @{ Type = 'boolean'; Default = $false }
                    }
                }
                Profiles = @{
                    Type = 'array'
                    Default = @()
                }
                SessionHistory = @{
                    Type = 'array'
                    Default = @()
                }
            }
            
            Write-Verbose "ConfigurationCore integration initialized"
        } else {
            Write-Verbose "ConfigurationCore not available, using legacy configuration"
        }
    } catch {
        Write-Verbose "Could not initialize configuration management: $_"
    }
}

function Initialize-ModuleDiscovery {
    <#
    .SYNOPSIS
        Initializes module discovery and caching
    #>
    
    try {
        $cacheFile = Join-Path $script:UserConfigPaths.Cache 'module-discovery.json'
        
        # Load existing cache if available and recent
        if (Test-Path $cacheFile) {
            $cacheInfo = Get-Item $cacheFile
            $cacheAge = (Get-Date) - $cacheInfo.LastWriteTime
            
            if ($cacheAge.TotalHours -lt 24) {
                try {
                    $cachedModules = Get-Content $cacheFile -Raw | ConvertFrom-Json
                    $script:UserExperienceState.ModuleCache = $cachedModules
                    Write-Verbose "Loaded module discovery cache (age: $($cacheAge.ToString('hh\:mm')))"
                    return
                } catch {
                    Write-Verbose "Could not load module cache: $_"
                }
            }
        }
        
        # Discover available modules
        $discoveredModules = Get-ModuleDiscovery -Refresh
        $script:UserExperienceState.ModuleCache = $discoveredModules
        
        # Save to cache
        try {
            $discoveredModules | ConvertTo-Json -Depth 5 | Set-Content -Path $cacheFile
            Write-Verbose "Saved module discovery cache"
        } catch {
            Write-Verbose "Could not save module cache: $_"
        }
        
    } catch {
        Write-Verbose "Could not initialize module discovery: $_"
    }
}

function Initialize-EventHandling {
    <#
    .SYNOPSIS
        Sets up event handling for user experience
    #>
    
    try {
        # Subscribe to relevant events if event system is available
        if (Get-Command Subscribe-ModuleEvent -ErrorAction SilentlyContinue) {
            
            # Subscribe to configuration changes
            Subscribe-ModuleEvent -EventName 'ConfigurationChanged' -Action {
                param($EventData)
                Write-Verbose "Configuration changed, refreshing user experience"
                Refresh-UserExperience -Reason 'ConfigurationChanged'
            }
            
            # Subscribe to profile changes
            Subscribe-ModuleEvent -EventName 'ProfileChanged' -Action {
                param($EventData)
                Write-Verbose "Profile changed to: $($EventData.ProfileName)"
                Update-UserExperienceForProfile -ProfileName $EventData.ProfileName
            }
            
            # Subscribe to module loading events
            Subscribe-ModuleEvent -EventName 'ModuleLoaded' -Action {
                param($EventData)
                Write-Verbose "Module loaded: $($EventData.ModuleName)"
                Update-ModuleDiscoveryCache -ModuleName $EventData.ModuleName
            }
            
            Write-Verbose "Event handling initialized"
        }
    } catch {
        Write-Verbose "Could not initialize event handling: $_"
    }
}

function Initialize-FeatureFlags {
    <#
    .SYNOPSIS
        Initializes feature flags for the user experience
    #>
    
    $script:UserExperienceState.FeatureFlags = @{
        EnableAdvancedUI = $true
        EnableTutorialMode = $true
        EnableExpertMode = $true
        EnableAnalytics = $false
        EnableBetaFeatures = $false
        EnableDebugMode = $false
    }
    
    # Load feature flags from configuration if available
    try {
        if (Get-Command Get-ModuleConfiguration -ErrorAction SilentlyContinue) {
            $config = Get-ModuleConfiguration -ModuleName 'UserExperience' -ErrorAction SilentlyContinue
            if ($config -and $config.FeatureFlags) {
                foreach ($flag in $config.FeatureFlags.GetEnumerator()) {
                    $script:UserExperienceState.FeatureFlags[$flag.Key] = $flag.Value
                }
                Write-Verbose "Loaded feature flags from configuration"
            }
        }
    } catch {
        Write-Verbose "Could not load feature flags from configuration: $_"
    }
}

function Initialize-PerformanceMonitoring {
    <#
    .SYNOPSIS
        Sets up performance monitoring for user experience
    #>
    
    try {
        $script:UserExperienceState.PerformanceMetrics = @{
            InitializationTime = 0
            FunctionCallCount = @{}
            AverageResponseTime = @{}
            ErrorCount = 0
            LastPerformanceCheck = Get-Date
        }
        
        # Record initialization time
        if ($script:UserExperienceState.StartTime) {
            $initTime = (Get-Date) - $script:UserExperienceState.StartTime
            $script:UserExperienceState.PerformanceMetrics.InitializationTime = $initTime.TotalMilliseconds
        }
        
        Write-Verbose "Performance monitoring initialized"
    } catch {
        Write-Verbose "Could not initialize performance monitoring: $_"
    }
}

function Get-SystemInfo {
    <#
    .SYNOPSIS
        Gets comprehensive system information
    #>
    
    return @{
        OS = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        PowerShellEdition = $PSVersionTable.PSEdition
        Architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
        ProcessorCount = [System.Environment]::ProcessorCount
        TotalMemory = if ($IsWindows) {
            try {
                [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
            } catch { 'Unknown' }
        } else { 'Unknown' }
        UserName = [System.Environment]::UserName
        MachineName = [System.Environment]::MachineName
        CurrentDirectory = $PWD.Path
        ExecutionPolicy = Get-ExecutionPolicy
        ModulePath = $env:PSModulePath -split [System.IO.Path]::PathSeparator
        Timestamp = Get-Date
    }
}