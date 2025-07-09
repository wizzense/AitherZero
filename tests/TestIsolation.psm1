#Requires -Version 7.0

<#
.SYNOPSIS
    Test isolation utilities for AitherZero test infrastructure

.DESCRIPTION
    This module provides test isolation capabilities to prevent module conflicts,
    ensure clean test environments, and maintain test independence.

.NOTES
    - Compatible with PowerShell 7.0+ on Windows, Linux, and macOS
    - Provides module isolation, environment isolation, and resource cleanup
    - Integrates with Pester and AitherZero TestingFramework
#>

# Test isolation state
$script:IsolationState = @{
    OriginalModules = @()
    OriginalEnvironment = @{}
    OriginalLocation = $null
    OriginalErrorPreference = $null
    OriginalVerbosePreference = $null
    OriginalDebugPreference = $null
    OriginalWarningPreference = $null
    OriginalInformationPreference = $null
    TempDirectories = @()
    ModuleImports = @()
    ActiveIsolations = @()
}

# ============================================================================
# CORE ISOLATION FUNCTIONS
# ============================================================================

function Start-TestIsolation {
    <#
    .SYNOPSIS
        Starts test isolation for a test session
    #>
    [CmdletBinding()]
    param(
        [string]$IsolationName = "TestIsolation-$(Get-Random)",
        [switch]$IsolateModules,
        [switch]$IsolateEnvironment,
        [switch]$IsolateLocation,
        [switch]$IsolatePreferences,
        [string[]]$PreserveModules = @('Logging', 'Microsoft.PowerShell.Core', 'Microsoft.PowerShell.Utility', 'Microsoft.PowerShell.Management'),
        [string[]]$PreserveEnvironmentVariables = @()
    )

    $isolation = @{
        Name = $IsolationName
        StartTime = Get-Date
        IsolateModules = $IsolateModules.IsPresent
        IsolateEnvironment = $IsolateEnvironment.IsPresent
        IsolateLocation = $IsolateLocation.IsPresent
        IsolatePreferences = $IsolatePreferences.IsPresent
        PreserveModules = $PreserveModules
        PreserveEnvironmentVariables = $PreserveEnvironmentVariables
        OriginalState = @{}
    }

    # Store original modules
    if ($IsolateModules) {
        $isolation.OriginalState.Modules = Get-Module | Where-Object { $_.Name -notin $PreserveModules }
        Write-Verbose "Isolated $($isolation.OriginalState.Modules.Count) modules"
    }

    # Store original environment variables
    if ($IsolateEnvironment) {
        $isolation.OriginalState.Environment = @{}
        foreach ($env in [Environment]::GetEnvironmentVariables().GetEnumerator()) {
            if ($env.Key -notin $PreserveEnvironmentVariables) {
                $isolation.OriginalState.Environment[$env.Key] = $env.Value
            }
        }
        Write-Verbose "Isolated $($isolation.OriginalState.Environment.Count) environment variables"
    }

    # Store original location
    if ($IsolateLocation) {
        $isolation.OriginalState.Location = Get-Location
        Write-Verbose "Isolated current location: $($isolation.OriginalState.Location)"
    }

    # Store original preferences
    if ($IsolatePreferences) {
        $isolation.OriginalState.Preferences = @{
            ErrorActionPreference = $ErrorActionPreference
            VerbosePreference = $VerbosePreference
            DebugPreference = $DebugPreference
            WarningPreference = $WarningPreference
            InformationPreference = $InformationPreference
        }
        Write-Verbose "Isolated PowerShell preferences"
    }

    # Add to active isolations
    $script:IsolationState.ActiveIsolations += $isolation

    Write-Host "Started test isolation: $IsolationName" -ForegroundColor Green
    return $isolation
}

function Stop-TestIsolation {
    <#
    .SYNOPSIS
        Stops test isolation and restores original state
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Isolation
    )

    try {
        Write-Verbose "Stopping test isolation: $($Isolation.Name)"

        # Restore modules
        if ($Isolation.IsolateModules -and $Isolation.OriginalState.Modules) {
            $currentModules = Get-Module | Where-Object { $_.Name -notin $Isolation.PreserveModules }
            
            # Remove modules that weren't originally loaded
            foreach ($module in $currentModules) {
                if ($module.Name -notin $Isolation.OriginalState.Modules.Name) {
                    Remove-Module $module.Name -Force -ErrorAction SilentlyContinue
                    Write-Verbose "Removed module: $($module.Name)"
                }
            }
        }

        # Restore environment variables
        if ($Isolation.IsolateEnvironment -and $Isolation.OriginalState.Environment) {
            foreach ($env in $Isolation.OriginalState.Environment.GetEnumerator()) {
                [Environment]::SetEnvironmentVariable($env.Key, $env.Value, 'Process')
                Write-Verbose "Restored environment variable: $($env.Key)"
            }
        }

        # Restore location
        if ($Isolation.IsolateLocation -and $Isolation.OriginalState.Location) {
            Set-Location $Isolation.OriginalState.Location
            Write-Verbose "Restored location: $($Isolation.OriginalState.Location)"
        }

        # Restore preferences
        if ($Isolation.IsolatePreferences -and $Isolation.OriginalState.Preferences) {
            $prefs = $Isolation.OriginalState.Preferences
            $script:ErrorActionPreference = $prefs.ErrorActionPreference
            $script:VerbosePreference = $prefs.VerbosePreference
            $script:DebugPreference = $prefs.DebugPreference
            $script:WarningPreference = $prefs.WarningPreference
            $script:InformationPreference = $prefs.InformationPreference
            Write-Verbose "Restored PowerShell preferences"
        }

        # Remove from active isolations
        $script:IsolationState.ActiveIsolations = $script:IsolationState.ActiveIsolations | Where-Object { $_.Name -ne $Isolation.Name }

        Write-Host "Stopped test isolation: $($Isolation.Name)" -ForegroundColor Green

    } catch {
        Write-Warning "Error stopping test isolation $($Isolation.Name): $($_.Exception.Message)"
        throw
    }
}

function Invoke-IsolatedTest {
    <#
    .SYNOPSIS
        Executes a test in an isolated environment
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$TestScript,
        
        [string]$TestName = "IsolatedTest",
        
        [switch]$IsolateModules,
        [switch]$IsolateEnvironment,
        [switch]$IsolateLocation,
        [switch]$IsolatePreferences,
        
        [string[]]$PreserveModules = @('Microsoft.PowerShell.Core', 'Microsoft.PowerShell.Utility', 'Microsoft.PowerShell.Management'),
        [string[]]$PreserveEnvironmentVariables = @('PATH', 'HOME', 'USERPROFILE', 'TEMP', 'TMP'),
        
        [hashtable]$Parameters = @{}
    )

    $isolation = Start-TestIsolation -IsolationName $TestName -IsolateModules:$IsolateModules -IsolateEnvironment:$IsolateEnvironment -IsolateLocation:$IsolateLocation -IsolatePreferences:$IsolatePreferences -PreserveModules $PreserveModules -PreserveEnvironmentVariables $PreserveEnvironmentVariables

    try {
        Write-Verbose "Executing isolated test: $TestName"
        
        # Execute the test script
        $result = & $TestScript @Parameters
        
        Write-Verbose "Isolated test completed successfully: $TestName"
        return $result
        
    } catch {
        Write-Warning "Isolated test failed: $TestName - $($_.Exception.Message)"
        throw
    } finally {
        Stop-TestIsolation -Isolation $isolation
    }
}

# ============================================================================
# MODULE ISOLATION FUNCTIONS
# ============================================================================

function New-ModuleIsolation {
    <#
    .SYNOPSIS
        Creates a new module isolation context
    #>
    [CmdletBinding()]
    param(
        [string[]]$AllowedModules = @(),
        [string[]]$BlockedModules = @(),
        [switch]$ClearAll
    )

    $isolation = @{
        AllowedModules = $AllowedModules
        BlockedModules = $BlockedModules
        ClearAll = $ClearAll.IsPresent
        OriginalModules = Get-Module
    }

    if ($ClearAll) {
        # Remove all modules except core ones
        $coreModules = @('Microsoft.PowerShell.Core', 'Microsoft.PowerShell.Utility', 'Microsoft.PowerShell.Management')
        Get-Module | Where-Object { $_.Name -notin $coreModules } | Remove-Module -Force -ErrorAction SilentlyContinue
    }

    # Remove blocked modules
    foreach ($blockedModule in $BlockedModules) {
        if (Get-Module -Name $blockedModule -ErrorAction SilentlyContinue) {
            Remove-Module $blockedModule -Force -ErrorAction SilentlyContinue
            Write-Verbose "Removed blocked module: $blockedModule"
        }
    }

    return $isolation
}

function Restore-ModuleIsolation {
    <#
    .SYNOPSIS
        Restores modules to their original state
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Isolation
    )

    $currentModules = Get-Module

    # Remove modules that weren't originally loaded
    foreach ($module in $currentModules) {
        if ($module.Name -notin $Isolation.OriginalModules.Name) {
            Remove-Module $module.Name -Force -ErrorAction SilentlyContinue
            Write-Verbose "Removed module: $($module.Name)"
        }
    }

    # Re-import modules that were originally loaded but are now missing
    foreach ($originalModule in $Isolation.OriginalModules) {
        if (-not (Get-Module -Name $originalModule.Name -ErrorAction SilentlyContinue)) {
            try {
                Import-Module $originalModule.Name -Force -ErrorAction Stop
                Write-Verbose "Re-imported module: $($originalModule.Name)"
            } catch {
                Write-Warning "Failed to re-import module $($originalModule.Name): $($_.Exception.Message)"
            }
        }
    }
}

# ============================================================================
# ENVIRONMENT ISOLATION FUNCTIONS
# ============================================================================

function New-EnvironmentIsolation {
    <#
    .SYNOPSIS
        Creates a new environment isolation context
    #>
    [CmdletBinding()]
    param(
        [hashtable]$EnvironmentVariables = @{},
        [string[]]$PreserveVariables = @('PATH', 'HOME', 'USERPROFILE', 'TEMP', 'TMP'),
        [switch]$ClearAll
    )

    $isolation = @{
        OriginalEnvironment = @{}
        EnvironmentVariables = $EnvironmentVariables
        PreserveVariables = $PreserveVariables
        ClearAll = $ClearAll.IsPresent
    }

    # Store original environment
    foreach ($env in [Environment]::GetEnvironmentVariables().GetEnumerator()) {
        $isolation.OriginalEnvironment[$env.Key] = $env.Value
    }

    if ($ClearAll) {
        # Clear all environment variables except preserved ones
        foreach ($env in [Environment]::GetEnvironmentVariables().GetEnumerator()) {
            if ($env.Key -notin $PreserveVariables) {
                [Environment]::SetEnvironmentVariable($env.Key, $null, 'Process')
            }
        }
    }

    # Set custom environment variables
    foreach ($env in $EnvironmentVariables.GetEnumerator()) {
        [Environment]::SetEnvironmentVariable($env.Key, $env.Value, 'Process')
        Write-Verbose "Set environment variable: $($env.Key) = $($env.Value)"
    }

    return $isolation
}

function Restore-EnvironmentIsolation {
    <#
    .SYNOPSIS
        Restores environment variables to their original state
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Isolation
    )

    # Restore original environment variables
    foreach ($env in $Isolation.OriginalEnvironment.GetEnumerator()) {
        [Environment]::SetEnvironmentVariable($env.Key, $env.Value, 'Process')
        Write-Verbose "Restored environment variable: $($env.Key)"
    }

    # Remove any variables that were added during isolation
    $currentEnv = [Environment]::GetEnvironmentVariables()
    foreach ($env in $currentEnv.GetEnumerator()) {
        if (-not $Isolation.OriginalEnvironment.ContainsKey($env.Key)) {
            [Environment]::SetEnvironmentVariable($env.Key, $null, 'Process')
            Write-Verbose "Removed environment variable: $($env.Key)"
        }
    }
}

# ============================================================================
# RESOURCE CLEANUP FUNCTIONS
# ============================================================================

function New-TempDirectoryIsolation {
    <#
    .SYNOPSIS
        Creates a temporary directory for test isolation
    #>
    [CmdletBinding()]
    param(
        [string]$Prefix = "AitherZero-TestIsolation-"
    )

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "$Prefix$(Get-Random)"
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
    
    $script:IsolationState.TempDirectories += $tempDir
    
    Write-Verbose "Created temporary directory: $tempDir"
    return $tempDir
}

function Remove-TempDirectoryIsolation {
    <#
    .SYNOPSIS
        Removes temporary directories created during isolation
    #>
    [CmdletBinding()]
    param(
        [string]$TempDirectory = $null
    )

    if ($TempDirectory) {
        if (Test-Path $TempDirectory) {
            Remove-Item -Path $TempDirectory -Recurse -Force -ErrorAction SilentlyContinue
            Write-Verbose "Removed temporary directory: $TempDirectory"
        }
        $script:IsolationState.TempDirectories = $script:IsolationState.TempDirectories | Where-Object { $_ -ne $TempDirectory }
    } else {
        # Remove all temporary directories
        foreach ($tempDir in $script:IsolationState.TempDirectories) {
            if (Test-Path $tempDir) {
                Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                Write-Verbose "Removed temporary directory: $tempDir"
            }
        }
        $script:IsolationState.TempDirectories = @()
    }
}

function Clear-TestIsolationState {
    <#
    .SYNOPSIS
        Clears all test isolation state and performs cleanup
    #>
    [CmdletBinding()]
    param()

    try {
        # Stop all active isolations
        foreach ($isolation in $script:IsolationState.ActiveIsolations) {
            try {
                Stop-TestIsolation -Isolation $isolation
            } catch {
                Write-Warning "Failed to stop isolation $($isolation.Name): $($_.Exception.Message)"
            }
        }

        # Remove all temporary directories
        Remove-TempDirectoryIsolation

        # Clear isolation state
        $script:IsolationState = @{
            OriginalModules = @()
            OriginalEnvironment = @{}
            OriginalLocation = $null
            OriginalErrorPreference = $null
            OriginalVerbosePreference = $null
            OriginalDebugPreference = $null
            OriginalWarningPreference = $null
            OriginalInformationPreference = $null
            TempDirectories = @()
            ModuleImports = @()
            ActiveIsolations = @()
        }

        Write-Host "Test isolation state cleared" -ForegroundColor Green

    } catch {
        Write-Warning "Error clearing test isolation state: $($_.Exception.Message)"
        throw
    }
}

# ============================================================================
# PESTER INTEGRATION FUNCTIONS
# ============================================================================

function Invoke-PesterWithIsolation {
    <#
    .SYNOPSIS
        Executes Pester tests with isolation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TestPath,
        
        [hashtable]$PesterConfiguration = @{},
        
        [switch]$IsolateModules,
        [switch]$IsolateEnvironment,
        [switch]$IsolateLocation,
        [switch]$IsolatePreferences,
        
        [string[]]$PreserveModules = @('Microsoft.PowerShell.Core', 'Microsoft.PowerShell.Utility', 'Microsoft.PowerShell.Management', 'Pester', 'Logging'),
        [string[]]$PreserveEnvironmentVariables = @('PATH', 'HOME', 'USERPROFILE', 'TEMP', 'TMP')
    )

    $isolation = Start-TestIsolation -IsolationName "Pester-$(Split-Path $TestPath -Leaf)" -IsolateModules:$IsolateModules -IsolateEnvironment:$IsolateEnvironment -IsolateLocation:$IsolateLocation -IsolatePreferences:$IsolatePreferences -PreserveModules $PreserveModules -PreserveEnvironmentVariables $PreserveEnvironmentVariables

    try {
        # Initialize logging system in isolated context to prevent null path errors
        if ($env:PROJECT_ROOT) {
            $loggingPath = Join-Path $env:PROJECT_ROOT "aither-core/modules/Logging"
            if (Test-Path $loggingPath) {
                Import-Module $loggingPath -Force -ErrorAction SilentlyContinue

                if (Get-Command Initialize-LoggingSystem -ErrorAction SilentlyContinue) {
                    Initialize-LoggingSystem -ErrorAction SilentlyContinue
                }
            }
        }
        
        # Ensure Pester is available
        if (-not (Get-Module -Name Pester -ErrorAction SilentlyContinue)) {
            Import-Module Pester -Force
        }

        # Create default Pester configuration
        $config = New-PesterConfiguration
        $config.Run.Path = $TestPath
        $config.Run.PassThru = $true
        $config.Run.Exit = $false

        # Apply custom configuration
        foreach ($setting in $PesterConfiguration.GetEnumerator()) {
            $config.$($setting.Key) = $setting.Value
        }

        # Execute Pester tests
        $result = Invoke-Pester -Configuration $config
        
        return $result
        
    } catch {
        Write-Warning "Pester execution with isolation failed: $($_.Exception.Message)"
        throw
    } finally {
        Stop-TestIsolation -Isolation $isolation
    }
}

# ============================================================================
# EXPORT MEMBERS
# ============================================================================

Export-ModuleMember -Function @(
    'Start-TestIsolation',
    'Stop-TestIsolation',
    'Invoke-IsolatedTest',
    'New-ModuleIsolation',
    'Restore-ModuleIsolation',
    'New-EnvironmentIsolation',
    'Restore-EnvironmentIsolation',
    'New-TempDirectoryIsolation',
    'Remove-TempDirectoryIsolation',
    'Clear-TestIsolationState',
    'Invoke-PesterWithIsolation'
)