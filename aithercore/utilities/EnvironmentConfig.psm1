#Requires -Version 7.0

<#
.SYNOPSIS
    Environment configuration management for AitherZero
.DESCRIPTION
    Provides functions to configure system environment settings including:
    - Windows long path support
    - Environment variables (System, User, Process)
    - Developer mode and other Windows features
    - Cross-platform PATH management
    - Shell integration for Linux/macOS
.NOTES
    Module: EnvironmentConfig
    Domain: Utilities
    Version: 1.0.0
#>

#region Helper Functions

function Write-EnvConfigLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Information', 'Warning', 'Error', 'Success', 'Debug')]
        [string]$Level = 'Information'
    )
    
    # Try to use Write-CustomLog if available
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level
    }
    else {
        $colors = @{
            Information = 'Cyan'
            Warning = 'Yellow'
            Error = 'Red'
            Success = 'Green'
            Debug = 'DarkGray'
        }
        Write-Host "[$Level] $Message" -ForegroundColor $colors[$Level]
    }
}

function Test-IsAdministrator {
    [CmdletBinding()]
    param()
    
    if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT') {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    else {
        # On Unix, check if running as root
        return (id -u) -eq 0
    }
}

#endregion

#region Core Functions

function Get-EnvironmentConfiguration {
    <#
    .SYNOPSIS
        Get current environment configuration status
    
    .DESCRIPTION
        Reads the current state of environment configuration including:
        - Windows features (long path support, developer mode)
        - Environment variables
        - PATH configuration
        - Shell integration (Unix)
    
    .PARAMETER Category
        Specific category to retrieve (Windows, Unix, EnvironmentVariables, Path, All)
    
    .PARAMETER ConfigPath
        Path to configuration file (default: ./config.psd1)
    
    .EXAMPLE
        Get-EnvironmentConfiguration
        
        Get all environment configuration status
    
    .EXAMPLE
        Get-EnvironmentConfiguration -Category Windows
        
        Get Windows-specific configuration status
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('All', 'Windows', 'Unix', 'EnvironmentVariables', 'Path')]
        [string]$Category = 'All',
        
        [string]$ConfigPath
    )
    
    Write-EnvConfigLog "Retrieving environment configuration (Category: $Category)" -Level Information
    
    try {
        # Load configuration
        if (-not $ConfigPath) {
            $ConfigPath = Join-Path $env:AITHERZERO_ROOT 'config.psd1'
        }
        
        if (-not (Test-Path $ConfigPath)) {
            throw "Configuration file not found: $ConfigPath"
        }
        
        # Import configuration using scriptblock evaluation
        $content = Get-Content -Path $ConfigPath -Raw
        $scriptBlock = [scriptblock]::Create($content)
        $config = & $scriptBlock
        
        if (-not $config.EnvironmentConfiguration) {
            Write-EnvConfigLog "No EnvironmentConfiguration section found in config" -Level Warning
            return $null
        }
        
        $envConfig = $config.EnvironmentConfiguration
        $result = @{
            ConfigPath = $ConfigPath
            Status = @{}
        }
        
        # Get Windows configuration status
        if ($Category -in @('All', 'Windows') -and ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT')) {
            $result.Status.Windows = @{
                LongPathSupport = Get-WindowsLongPathStatus
                DeveloperMode = Get-WindowsDeveloperModeStatus
                IsAdministrator = Test-IsAdministrator
            }
        }
        
        # Get environment variables
        if ($Category -in @('All', 'EnvironmentVariables')) {
            $result.Status.EnvironmentVariables = @{
                System = @{}
                User = @{}
                Process = @{}
            }
            
            # Check configured variables
            if ($envConfig.EnvironmentVariables.User) {
                foreach ($key in $envConfig.EnvironmentVariables.User.Keys) {
                    $result.Status.EnvironmentVariables.User[$key] = [Environment]::GetEnvironmentVariable($key, 'User')
                }
            }
            
            if ($envConfig.EnvironmentVariables.Process) {
                foreach ($key in $envConfig.EnvironmentVariables.Process.Keys) {
                    $result.Status.EnvironmentVariables.Process[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
                }
            }
        }
        
        # Get PATH configuration
        if ($Category -in @('All', 'Path')) {
            $result.Status.Path = @{
                User = [Environment]::GetEnvironmentVariable('PATH', 'User') -split [IO.Path]::PathSeparator
                System = [Environment]::GetEnvironmentVariable('PATH', 'Machine') -split [IO.Path]::PathSeparator
                Process = $env:PATH -split [IO.Path]::PathSeparator
            }
        }
        
        # Get Unix configuration
        if ($Category -in @('All', 'Unix') -and ($IsLinux -or $IsMacOS)) {
            $result.Status.Unix = @{
                Shell = $env:SHELL
                ShellConfigFiles = @()
            }
            
            # Detect shell config files
            $shellConfigs = @('.bashrc', '.zshrc', '.config/fish/config.fish')
            foreach ($config in $shellConfigs) {
                $path = Join-Path $env:HOME $config
                if (Test-Path $path) {
                    $result.Status.Unix.ShellConfigFiles += $path
                }
            }
        }
        
        return $result
    }
    catch {
        Write-EnvConfigLog "Error retrieving environment configuration: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Set-EnvironmentConfiguration {
    <#
    .SYNOPSIS
        Apply environment configuration from config file
    
    .DESCRIPTION
        Applies environment configuration settings including:
        - Windows long path support
        - Developer mode
        - Environment variables
        - PATH modifications
        - Shell integration (Unix)
        
        Settings are read from config.psd1 EnvironmentConfiguration section.
    
    .PARAMETER ConfigPath
        Path to configuration file (default: ./config.psd1)
    
    .PARAMETER Category
        Specific category to apply (Windows, Unix, EnvironmentVariables, Path, All)
    
    .PARAMETER DryRun
        Preview changes without applying them
    
    .PARAMETER Force
        Skip confirmation prompts
    
    .EXAMPLE
        Set-EnvironmentConfiguration
        
        Apply all environment configuration from config.psd1
    
    .EXAMPLE
        Set-EnvironmentConfiguration -Category Windows -DryRun
        
        Preview Windows configuration changes without applying
    
    .EXAMPLE
        Set-EnvironmentConfiguration -Force
        
        Apply configuration without confirmation prompts
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ConfigPath,
        
        [ValidateSet('All', 'Windows', 'Unix', 'EnvironmentVariables', 'Path')]
        [string]$Category = 'All',
        
        [switch]$DryRun,
        
        [switch]$Force
    )
    
    Write-EnvConfigLog "Applying environment configuration (Category: $Category, DryRun: $DryRun)" -Level Information
    
    try {
        # Load configuration
        if (-not $ConfigPath) {
            $ConfigPath = Join-Path $env:AITHERZERO_ROOT 'config.psd1'
        }
        
        if (-not (Test-Path $ConfigPath)) {
            throw "Configuration file not found: $ConfigPath"
        }
        
        # Import configuration using scriptblock evaluation
        $content = Get-Content -Path $ConfigPath -Raw
        $scriptBlock = [scriptblock]::Create($content)
        $config = & $scriptBlock
        
        if (-not $config.EnvironmentConfiguration) {
            throw "No EnvironmentConfiguration section found in config"
        }
        
        $envConfig = $config.EnvironmentConfiguration
        $appliedChanges = @()
        
        # Apply Windows configuration
        if ($Category -in @('All', 'Windows') -and ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT')) {
            if ($envConfig.Windows.LongPathSupport.Enabled -and $envConfig.Windows.LongPathSupport.AutoApply) {
                $result = Enable-WindowsLongPathSupport -DryRun:$DryRun -Force:$Force
                if ($result) {
                    $appliedChanges += 'Windows Long Path Support'
                }
            }
            
            if ($envConfig.Windows.DeveloperMode.Enabled -and $envConfig.Windows.DeveloperMode.AutoApply) {
                $result = Enable-WindowsDeveloperMode -DryRun:$DryRun -Force:$Force
                if ($result) {
                    $appliedChanges += 'Windows Developer Mode'
                }
            }
        }
        
        # Apply environment variables
        if ($Category -in @('All', 'EnvironmentVariables')) {
            # User variables
            if ($envConfig.EnvironmentVariables.User) {
                foreach ($key in $envConfig.EnvironmentVariables.User.Keys) {
                    $value = $envConfig.EnvironmentVariables.User[$key]
                    if ($value) {
                        if (-not $DryRun) {
                            [Environment]::SetEnvironmentVariable($key, $value, 'User')
                            Write-EnvConfigLog "Set user environment variable: $key" -Level Success
                        }
                        else {
                            Write-EnvConfigLog "[DRY RUN] Would set user environment variable: $key = $value" -Level Information
                        }
                        $appliedChanges += "User variable: $key"
                    }
                }
            }
            
            # Process variables
            if ($envConfig.EnvironmentVariables.Process) {
                foreach ($key in $envConfig.EnvironmentVariables.Process.Keys) {
                    $value = $envConfig.EnvironmentVariables.Process[$key]
                    if ($value) {
                        if (-not $DryRun) {
                            [Environment]::SetEnvironmentVariable($key, $value, 'Process')
                            Write-EnvConfigLog "Set process environment variable: $key" -Level Success
                        }
                        else {
                            Write-EnvConfigLog "[DRY RUN] Would set process environment variable: $key = $value" -Level Information
                        }
                        $appliedChanges += "Process variable: $key"
                    }
                }
            }
        }
        
        # Apply PATH configuration
        if ($Category -in @('All', 'Path') -and $envConfig.PathConfiguration.AddToPath) {
            if ($envConfig.PathConfiguration.Paths.User.Count -gt 0) {
                $result = Add-PathEntries -Paths $envConfig.PathConfiguration.Paths.User -Scope 'User' -DryRun:$DryRun
                if ($result) {
                    $appliedChanges += 'User PATH entries'
                }
            }
        }
        
        # Unix configuration
        if ($Category -in @('All', 'Unix') -and ($IsLinux -or $IsMacOS)) {
            if ($envConfig.Unix.ShellIntegration.Enabled -and $envConfig.Unix.ShellIntegration.AddToProfile) {
                $result = Add-ShellIntegration -DryRun:$DryRun -Force:$Force
                if ($result) {
                    $appliedChanges += 'Shell integration'
                }
            }
        }
        
        # Summary
        if ($appliedChanges.Count -gt 0) {
            Write-EnvConfigLog "Applied $($appliedChanges.Count) configuration changes:" -Level Success
            foreach ($change in $appliedChanges) {
                Write-EnvConfigLog "  - $change" -Level Information
            }
        }
        else {
            Write-EnvConfigLog "No configuration changes needed" -Level Information
        }
        
        return @{
            Success = $true
            AppliedChanges = $appliedChanges
            DryRun = $DryRun.IsPresent
        }
    }
    catch {
        Write-EnvConfigLog "Error applying environment configuration: $($_.Exception.Message)" -Level Error
        throw
    }
}

#endregion

#region Windows-Specific Functions

function Get-WindowsLongPathStatus {
    <#
    .SYNOPSIS
        Get Windows long path support status
    
    .DESCRIPTION
        Checks if Windows long path support (> 260 characters) is enabled
    
    .EXAMPLE
        Get-WindowsLongPathStatus
    #>
    [CmdletBinding()]
    param()
    
    if (-not ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT')) {
        Write-EnvConfigLog "Long path support is only applicable to Windows" -Level Warning
        return $null
    }
    
    try {
        $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
        $regKey = 'LongPathsEnabled'
        
        if (Test-Path $regPath) {
            $value = Get-ItemProperty -Path $regPath -Name $regKey -ErrorAction SilentlyContinue
            return @{
                Enabled = ($value.$regKey -eq 1)
                RegistryPath = $regPath
                RegistryKey = $regKey
                CurrentValue = $value.$regKey
            }
        }
        else {
            return @{
                Enabled = $false
                RegistryPath = $regPath
                RegistryKey = $regKey
                CurrentValue = $null
            }
        }
    }
    catch {
        Write-EnvConfigLog "Error checking long path status: $($_.Exception.Message)" -Level Error
        return $null
    }
}

function Enable-WindowsLongPathSupport {
    <#
    .SYNOPSIS
        Enable Windows long path support
    
    .DESCRIPTION
        Enables NTFS long path support (> 260 characters) by setting registry key
    
    .PARAMETER DryRun
        Preview changes without applying them
    
    .PARAMETER Force
        Skip confirmation prompts
    
    .EXAMPLE
        Enable-WindowsLongPathSupport
        
        Enable long path support with confirmation
    
    .EXAMPLE
        Enable-WindowsLongPathSupport -Force
        
        Enable without confirmation prompt
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$DryRun,
        [switch]$Force
    )
    
    if (-not ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT')) {
        Write-EnvConfigLog "Long path support is only applicable to Windows" -Level Warning
        return $false
    }
    
    # Check if already enabled
    $status = Get-WindowsLongPathStatus
    if ($status.Enabled) {
        Write-EnvConfigLog "Windows long path support is already enabled" -Level Information
        return $false
    }
    
    # Check for admin rights
    if (-not (Test-IsAdministrator)) {
        Write-EnvConfigLog "Administrator privileges required to enable long path support" -Level Warning
        return $false
    }
    
    if ($DryRun) {
        Write-EnvConfigLog "[DRY RUN] Would enable Windows long path support" -Level Information
        return $true
    }
    
    if (-not $Force) {
        $confirmation = Read-Host "Enable Windows long path support? (y/N)"
        if ($confirmation -ne 'y') {
            Write-EnvConfigLog "Operation cancelled by user" -Level Information
            return $false
        }
    }
    
    try {
        $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
        Set-ItemProperty -Path $regPath -Name 'LongPathsEnabled' -Value 1 -Type DWord
        Write-EnvConfigLog "Windows long path support enabled successfully" -Level Success
        return $true
    }
    catch {
        Write-EnvConfigLog "Error enabling long path support: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Get-WindowsDeveloperModeStatus {
    <#
    .SYNOPSIS
        Get Windows Developer Mode status
    
    .DESCRIPTION
        Checks if Windows Developer Mode is enabled
    
    .EXAMPLE
        Get-WindowsDeveloperModeStatus
    #>
    [CmdletBinding()]
    param()
    
    if (-not ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT')) {
        Write-EnvConfigLog "Developer Mode is only applicable to Windows" -Level Warning
        return $null
    }
    
    try {
        $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
        $regKey = 'AllowDevelopmentWithoutDevLicense'
        
        if (Test-Path $regPath) {
            $value = Get-ItemProperty -Path $regPath -Name $regKey -ErrorAction SilentlyContinue
            return @{
                Enabled = ($value.$regKey -eq 1)
                RegistryPath = $regPath
                RegistryKey = $regKey
                CurrentValue = $value.$regKey
            }
        }
        else {
            return @{
                Enabled = $false
                RegistryPath = $regPath
                RegistryKey = $regKey
                CurrentValue = $null
            }
        }
    }
    catch {
        Write-EnvConfigLog "Error checking developer mode status: $($_.Exception.Message)" -Level Error
        return $null
    }
}

function Enable-WindowsDeveloperMode {
    <#
    .SYNOPSIS
        Enable Windows Developer Mode
    
    .DESCRIPTION
        Enables Windows Developer Mode for sideloading and development features
    
    .PARAMETER DryRun
        Preview changes without applying them
    
    .PARAMETER Force
        Skip confirmation prompts
    
    .EXAMPLE
        Enable-WindowsDeveloperMode
        
        Enable developer mode with confirmation
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$DryRun,
        [switch]$Force
    )
    
    if (-not ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT')) {
        Write-EnvConfigLog "Developer Mode is only applicable to Windows" -Level Warning
        return $false
    }
    
    # Check if already enabled
    $status = Get-WindowsDeveloperModeStatus
    if ($status.Enabled) {
        Write-EnvConfigLog "Windows Developer Mode is already enabled" -Level Information
        return $false
    }
    
    # Check for admin rights
    if (-not (Test-IsAdministrator)) {
        Write-EnvConfigLog "Administrator privileges required to enable Developer Mode" -Level Warning
        return $false
    }
    
    if ($DryRun) {
        Write-EnvConfigLog "[DRY RUN] Would enable Windows Developer Mode" -Level Information
        return $true
    }
    
    if (-not $Force) {
        $confirmation = Read-Host "Enable Windows Developer Mode? (y/N)"
        if ($confirmation -ne 'y') {
            Write-EnvConfigLog "Operation cancelled by user" -Level Information
            return $false
        }
    }
    
    try {
        $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        Set-ItemProperty -Path $regPath -Name 'AllowDevelopmentWithoutDevLicense' -Value 1 -Type DWord
        Write-EnvConfigLog "Windows Developer Mode enabled successfully" -Level Success
        return $true
    }
    catch {
        Write-EnvConfigLog "Error enabling Developer Mode: $($_.Exception.Message)" -Level Error
        throw
    }
}

#endregion

#region Cross-Platform Functions

function Update-EnvironmentVariable {
    <#
    .SYNOPSIS
        Update a single environment variable
    
    .DESCRIPTION
        Sets or updates an environment variable at specified scope
    
    .PARAMETER Name
        Variable name
    
    .PARAMETER Value
        Variable value
    
    .PARAMETER Scope
        Variable scope: Process, User, or Machine (System)
    
    .PARAMETER Force
        Overwrite existing value without confirmation
    
    .EXAMPLE
        Update-EnvironmentVariable -Name 'AITHERZERO_PROFILE' -Value 'Developer' -Scope User
    
    .EXAMPLE
        Update-EnvironmentVariable -Name 'MY_VAR' -Value 'test' -Scope Process -Force
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value,
        
        [ValidateSet('Process', 'User', 'Machine')]
        [string]$Scope = 'Process',
        
        [switch]$Force
    )
    
    # Check admin rights for Machine scope
    if ($Scope -eq 'Machine' -and -not (Test-IsAdministrator)) {
        Write-EnvConfigLog "Administrator privileges required for Machine scope" -Level Warning
        return $false
    }
    
    # Get current value
    $currentValue = [Environment]::GetEnvironmentVariable($Name, $Scope)
    
    if ($currentValue -and -not $Force) {
        Write-EnvConfigLog "Variable $Name already exists with value: $currentValue" -Level Warning
        $confirmation = Read-Host "Overwrite? (y/N)"
        if ($confirmation -ne 'y') {
            Write-EnvConfigLog "Operation cancelled" -Level Information
            return $false
        }
    }
    
    try {
        [Environment]::SetEnvironmentVariable($Name, $Value, $Scope)
        Write-EnvConfigLog "Set $Scope environment variable: $Name = $Value" -Level Success
        return $true
    }
    catch {
        Write-EnvConfigLog "Error setting environment variable: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Add-PathEntries {
    <#
    .SYNOPSIS
        Add entries to PATH environment variable
    
    .DESCRIPTION
        Adds one or more directories to the PATH variable
    
    .PARAMETER Paths
        Array of paths to add
    
    .PARAMETER Scope
        PATH scope: Process, User, or Machine
    
    .PARAMETER DryRun
        Preview changes without applying
    
    .EXAMPLE
        Add-PathEntries -Paths @('C:\Tools', 'C:\MyApp') -Scope User
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Paths,
        
        [ValidateSet('Process', 'User', 'Machine')]
        [string]$Scope = 'User',
        
        [switch]$DryRun
    )
    
    # Check admin for Machine scope
    if ($Scope -eq 'Machine' -and -not (Test-IsAdministrator)) {
        Write-EnvConfigLog "Administrator privileges required for Machine scope" -Level Warning
        return $false
    }
    
    # Get current PATH
    $currentPath = [Environment]::GetEnvironmentVariable('PATH', $Scope)
    $pathEntries = $currentPath -split [IO.Path]::PathSeparator | Where-Object { $_ }
    
    $added = 0
    foreach ($path in $Paths) {
        # Validate path exists
        if (-not (Test-Path $path)) {
            Write-EnvConfigLog "Path does not exist: $path (skipping)" -Level Warning
            continue
        }
        
        # Check if already in PATH
        if ($pathEntries -contains $path) {
            Write-EnvConfigLog "Path already in $Scope PATH: $path" -Level Debug
            continue
        }
        
        if ($DryRun) {
            Write-EnvConfigLog "[DRY RUN] Would add to $Scope PATH: $path" -Level Information
        }
        else {
            $pathEntries += $path
            Write-EnvConfigLog "Added to $Scope PATH: $path" -Level Success
        }
        $added++
    }
    
    if ($added -gt 0 -and -not $DryRun) {
        $newPath = $pathEntries -join [IO.Path]::PathSeparator
        [Environment]::SetEnvironmentVariable('PATH', $newPath, $Scope)
    }
    
    return $added -gt 0
}

function Add-ShellIntegration {
    <#
    .SYNOPSIS
        Add AitherZero integration to shell profiles (Unix)
    
    .DESCRIPTION
        Adds AitherZero initialization code to shell config files
    
    .PARAMETER DryRun
        Preview changes without applying
    
    .PARAMETER Force
        Skip confirmation prompts
    
    .EXAMPLE
        Add-ShellIntegration
    #>
    [CmdletBinding()]
    param(
        [switch]$DryRun,
        [switch]$Force
    )
    
    if (-not ($IsLinux -or $IsMacOS)) {
        Write-EnvConfigLog "Shell integration is only applicable to Linux/macOS" -Level Warning
        return $false
    }
    
    $shellConfig = $null
    $shell = $env:SHELL
    
    # Determine shell config file
    if ($shell -like '*bash*') {
        $shellConfig = Join-Path $env:HOME '.bashrc'
    }
    elseif ($shell -like '*zsh*') {
        $shellConfig = Join-Path $env:HOME '.zshrc'
    }
    elseif ($shell -like '*fish*') {
        $shellConfig = Join-Path $env:HOME '.config/fish/config.fish'
    }
    else {
        Write-EnvConfigLog "Unsupported shell: $shell" -Level Warning
        return $false
    }
    
    if (-not (Test-Path $shellConfig)) {
        Write-EnvConfigLog "Shell config file not found: $shellConfig" -Level Warning
        return $false
    }
    
    # Check if already integrated
    $content = Get-Content $shellConfig -Raw
    if ($content -match 'AITHERZERO_ROOT') {
        Write-EnvConfigLog "AitherZero already integrated in $shellConfig" -Level Information
        return $false
    }
    
    $integrationCode = @"

# AitherZero Integration
export AITHERZERO_ROOT="$env:AITHERZERO_ROOT"
export PATH="`$PATH:`$AITHERZERO_ROOT/automation-scripts"
"@
    
    if ($DryRun) {
        Write-EnvConfigLog "[DRY RUN] Would add to $shellConfig : $integrationCode" -Level Information
        return $true
    }
    
    if (-not $Force) {
        $confirmation = Read-Host "Add AitherZero integration to $shellConfig? (y/N)"
        if ($confirmation -ne 'y') {
            Write-EnvConfigLog "Operation cancelled" -Level Information
            return $false
        }
    }
    
    try {
        Add-Content -Path $shellConfig -Value $integrationCode
        Write-EnvConfigLog "Added AitherZero integration to $shellConfig" -Level Success
        return $true
    }
    catch {
        Write-EnvConfigLog "Error adding shell integration: $($_.Exception.Message)" -Level Error
        throw
    }
}

#endregion

#region Exports

Export-ModuleMember -Function @(
    'Get-EnvironmentConfiguration'
    'Set-EnvironmentConfiguration'
    'Get-WindowsLongPathStatus'
    'Enable-WindowsLongPathSupport'
    'Get-WindowsDeveloperModeStatus'
    'Enable-WindowsDeveloperMode'
    'Update-EnvironmentVariable'
    'Add-PathEntries'
    'Add-ShellIntegration'
)

#endregion
