#Requires -Version 7.0

<#
.SYNOPSIS
    Common utility functions for automation scripts

.DESCRIPTION
    Provides reusable helper functions used across automation scripts to eliminate
    code duplication. Includes logging wrappers, project path helpers, and other
    common patterns used by numbered automation scripts (0000-9999).

.NOTES
    Module: ScriptUtilities
    Domain: Automation
    Purpose: Eliminate duplicate code across 125+ automation scripts
#>

# Script-level variables
$script:ProjectRoot = $null
$script:LoggingAvailable = $false

function Initialize-ScriptUtilities {
    <#
    .SYNOPSIS
        Initialize script utilities and detect project root
    .DESCRIPTION
        Sets up the script utilities module by detecting the project root
        and checking for logging module availability
    #>
    [CmdletBinding()]
    param()

    # Try to determine project root from multiple sources
    if (-not $script:ProjectRoot) {
        # Check environment variable first
        if ($env:AITHERZERO_ROOT) {
            $script:ProjectRoot = $env:AITHERZERO_ROOT
        }
        # Try to find from PSScriptRoot (assumes we're in aithercore/automation/)
        elseif ($PSScriptRoot) {
            $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        }
        # Fallback to current directory
        else {
            $script:ProjectRoot = Get-Location
        }
    }

    # Check if logging module is available
    try {
        $loggingPath = Join-Path $script:ProjectRoot "domains/utilities/Logging.psm1"
        if (Test-Path $loggingPath) {
            Import-Module $loggingPath -Force -Global -ErrorAction SilentlyContinue
            $script:LoggingAvailable = $true
        }
    } catch {
        $script:LoggingAvailable = $false
    }
}

function Get-ProjectRoot {
    <#
    .SYNOPSIS
        Get the AitherZero project root path
    .DESCRIPTION
        Returns the root directory of the AitherZero project. Checks multiple
        sources: environment variable, module location, or current directory.
    .OUTPUTS
        System.String - The project root directory path
    .EXAMPLE
        $root = Get-ProjectRoot
        $configPath = Join-Path $root "config.psd1"
    #>
    [CmdletBinding()]
    param()

    if (-not $script:ProjectRoot) {
        Initialize-ScriptUtilities
    }

    return $script:ProjectRoot
}

function Write-ScriptLog {
    <#
    .SYNOPSIS
        Write a log message using centralized logging or fallback
    .DESCRIPTION
        Wrapper function that attempts to use Write-CustomLog from the
        Logging module, falling back to console output if unavailable.
        This eliminates the need for duplicate logging code in every script.
    .PARAMETER Message
        The message to log
    .PARAMETER Level
        Log level: Trace, Debug, Information, Warning, Error, Critical
    .PARAMETER Source
        Optional source identifier (script name)
    .PARAMETER Data
        Optional hashtable of additional structured data
    .EXAMPLE
        Write-ScriptLog -Message "Starting process" -Level Information
    .EXAMPLE
        Write-ScriptLog -Message "Error occurred" -Level Error -Source "0402_Run-UnitTests"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Trace', 'Debug', 'Information', 'Warning', 'Error', 'Critical')]
        [string]$Level = 'Information',

        [Parameter()]
        [string]$Source,

        [Parameter()]
        [hashtable]$Data = @{}
    )

    # Try to use centralized logging
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        $params = @{
            Message = $Message
            Level   = $Level
        }
        if ($Source) { $params['Source'] = $Source }
        if ($Data.Count -gt 0) { $params['Data'] = $Data }

        Write-CustomLog @params
    }
    # Fallback to console output with formatting
    else {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $prefix = switch ($Level) {
            'Critical' { 'CRIT' }
            'Error'    { 'ERROR' }
            'Warning'  { 'WARN' }
            'Debug'    { 'DEBUG' }
            'Trace'    { 'TRACE' }
            default    { 'INFO' }
        }

        $color = switch ($Level) {
            'Critical' { 'Red' }
            'Error'    { 'Red' }
            'Warning'  { 'Yellow' }
            'Debug'    { 'Gray' }
            'Trace'    { 'DarkGray' }
            default    { 'White' }
        }

        $sourcePrefix = if ($Source) { "[$Source] " } else { "" }
        Write-Host "[$timestamp] [$prefix] $sourcePrefix$Message" -ForegroundColor $color

        # Output data if provided
        if ($Data.Count -gt 0) {
            $Data.GetEnumerator() | ForEach-Object {
                Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor DarkGray
            }
        }
    }
}

function Test-IsAdministrator {
    <#
    .SYNOPSIS
        Check if the current session has administrator privileges
    .DESCRIPTION
        Tests whether the current PowerShell session is running with
        administrator/root privileges on Windows, Linux, or macOS.
    .OUTPUTS
        System.Boolean - True if running as administrator, false otherwise
    .EXAMPLE
        if (Test-IsAdministrator) {
            Write-ScriptLog "Running with admin privileges"
        }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($IsWindows) {
        $currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    else {
        # On Linux/macOS, check if running as root
        return (whoami) -eq 'root'
    }
}

function Get-PlatformName {
    <#
    .SYNOPSIS
        Get the current platform name
    .DESCRIPTION
        Returns a friendly platform name: Windows, Linux, or macOS
    .OUTPUTS
        System.String - Platform name
    .EXAMPLE
        $platform = Get-PlatformName
        Write-ScriptLog "Running on $platform"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if ($IsWindows) { return 'Windows' }
    elseif ($IsMacOS) { return 'macOS' }
    elseif ($IsLinux) { return 'Linux' }
    else { return 'Unknown' }
}

function Test-CommandAvailable {
    <#
    .SYNOPSIS
        Check if a command/executable is available
    .DESCRIPTION
        Tests whether a command is available in the current session or PATH
    .PARAMETER Name
        The command name to test
    .OUTPUTS
        System.Boolean - True if command is available, false otherwise
    .EXAMPLE
        if (Test-CommandAvailable -Name 'git') {
            Write-ScriptLog "Git is available"
        }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-GitHubToken {
    <#
    .SYNOPSIS
        Get GitHub authentication token
    .DESCRIPTION
        Retrieves GitHub token from environment variable or gh CLI
    .OUTPUTS
        System.String - GitHub token or null if not available
    .EXAMPLE
        $token = Get-GitHubToken
        if ($token) {
            # Use token for GitHub API calls
        }
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # Try environment variable first
    if ($env:GITHUB_TOKEN) {
        return $env:GITHUB_TOKEN
    }

    # Try gh CLI
    if (Test-CommandAvailable -Name 'gh') {
        try {
            $token = gh auth token 2>$null
            if ($token) {
                return $token
            }
        }
        catch {
            # Silently continue
        }
    }

    return $null
}

function Invoke-WithRetry {
    <#
    .SYNOPSIS
        Execute a script block with retry logic
    .DESCRIPTION
        Executes a script block with configurable retry attempts and delays
    .PARAMETER ScriptBlock
        The script block to execute
    .PARAMETER MaxAttempts
        Maximum number of attempts (default: 3)
    .PARAMETER DelaySeconds
        Delay between attempts in seconds (default: 5)
    .PARAMETER ErrorMessage
        Custom error message prefix
    .OUTPUTS
        Object - The result of the script block execution
    .EXAMPLE
        Invoke-WithRetry -ScriptBlock {
            Invoke-WebRequest -Uri "https://example.com"
        } -MaxAttempts 5 -DelaySeconds 10
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [Parameter()]
        [int]$MaxAttempts = 3,

        [Parameter()]
        [int]$DelaySeconds = 5,

        [Parameter()]
        [string]$ErrorMessage = "Operation failed"
    )

    $attempt = 1
    $lastError = $null

    while ($attempt -le $MaxAttempts) {
        try {
            Write-ScriptLog "Attempt $attempt of $MaxAttempts" -Level Debug
            $result = & $ScriptBlock
            Write-ScriptLog "Operation succeeded on attempt $attempt" -Level Debug
            return $result
        }
        catch {
            $lastError = $_
            Write-ScriptLog "$ErrorMessage (attempt $attempt of $MaxAttempts): $($_.Exception.Message)" -Level Warning

            if ($attempt -lt $MaxAttempts) {
                Write-ScriptLog "Retrying in $DelaySeconds seconds..." -Level Debug
                Start-Sleep -Seconds $DelaySeconds
            }

            $attempt++
        }
    }

    # All attempts failed
    Write-ScriptLog "$ErrorMessage after $MaxAttempts attempts" -Level Error
    throw $lastError
}

function Test-GitRepository {
    <#
    .SYNOPSIS
        Check if the current directory is a Git repository
    .DESCRIPTION
        Tests whether the current directory or project root is a Git repository
    .PARAMETER Path
        Optional path to check (defaults to current location)
    .OUTPUTS
        System.Boolean - True if in a Git repository, false otherwise
    .EXAMPLE
        if (Test-GitRepository) {
            Write-ScriptLog "In a Git repository"
        }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [string]$Path = (Get-Location)
    )

    try {
        $gitDir = Join-Path $Path ".git"
        if (Test-Path $gitDir) {
            return $true
        }

        # Try git command
        if (Test-CommandAvailable -Name 'git') {
            Push-Location $Path
            try {
                $result = git rev-parse --is-inside-work-tree 2>$null
                return $result -eq 'true'
            }
            finally {
                Pop-Location
            }
        }

        return $false
    }
    catch {
        return $false
    }
}

function Get-ScriptMetadata {
    <#
    .SYNOPSIS
        Extract metadata from a script's comment block
    .DESCRIPTION
        Parses the header comment block of a script to extract metadata
        like Stage, Dependencies, Description, Category, Tags
    .PARAMETER Path
        Path to the script file
    .OUTPUTS
        Hashtable - Metadata key-value pairs
    .EXAMPLE
        $metadata = Get-ScriptMetadata -Path "./automation-scripts/0402_Run-UnitTests.ps1"
        Write-Output $metadata.Stage
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $metadata = @{
        Stage = 'Unknown'
        Dependencies = @()
        Description = ''
        Category = ''
        Tags = @()
    }

    if (-not (Test-Path $Path)) {
        return $metadata
    }

    $content = Get-Content -Path $Path -Raw

    # Extract Stage
    if ($content -match '(?m)^#\s*Stage:\s*(.+)$') {
        $metadata.Stage = $matches[1].Trim()
    }

    # Extract Dependencies
    if ($content -match '(?m)^#\s*Dependencies?:\s*(.+)$') {
        $deps = $matches[1].Trim()
        if ($deps -ne 'None' -and $deps -ne '') {
            $metadata.Dependencies = $deps -split '[,;]' | ForEach-Object { $_.Trim() }
        }
    }

    # Extract Description
    if ($content -match '(?m)^#\s*Description:\s*(.+)$') {
        $metadata.Description = $matches[1].Trim()
    }

    # Extract Category
    if ($content -match '(?m)^#\s*Category:\s*(.+)$') {
        $metadata.Category = $matches[1].Trim()
    }

    # Extract Tags
    if ($content -match '(?m)^#\s*Tags?:\s*(.+)$') {
        $tags = $matches[1].Trim()
        $metadata.Tags = $tags -split '[,;]' | ForEach-Object { $_.Trim() }
    }

    return $metadata
}

function Format-Duration {
    <#
    .SYNOPSIS
        Format a TimeSpan into a human-readable string
    .DESCRIPTION
        Converts a TimeSpan object to a friendly string like "2m 30s"
    .PARAMETER TimeSpan
        The TimeSpan to format
    .OUTPUTS
        System.String - Formatted duration string
    .EXAMPLE
        $duration = Measure-Command { Start-Sleep -Seconds 5 }
        Write-ScriptLog "Completed in $(Format-Duration $duration)"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [TimeSpan]$TimeSpan
    )

    if ($TimeSpan.TotalHours -ge 1) {
        return "{0:0}h {1:0}m {2:0}s" -f $TimeSpan.Hours, $TimeSpan.Minutes, $TimeSpan.Seconds
    }
    elseif ($TimeSpan.TotalMinutes -ge 1) {
        return "{0:0}m {1:0}s" -f $TimeSpan.Minutes, $TimeSpan.Seconds
    }
    elseif ($TimeSpan.TotalSeconds -ge 1) {
        return "{0:0.0}s" -f $TimeSpan.TotalSeconds
    }
    else {
        return "{0:0}ms" -f $TimeSpan.TotalMilliseconds
    }
}

function Test-FeatureOrPrompt {
    <#
    .SYNOPSIS
        Tests if a feature is enabled and prompts to enable if needed
    .DESCRIPTION
        Convenience function for automation scripts that combines feature testing
        and prompting. Returns true if the feature is enabled or was successfully
        enabled by the user.
    .PARAMETER FeatureName
        Name of the feature to check
    .PARAMETER Category
        Feature category (e.g., 'Development', 'Infrastructure')
    .PARAMETER Reason
        Description of why the feature is needed
    .PARAMETER ExitOnDisabled
        If true and feature is disabled, exit script with code 0. Default: false
    .EXAMPLE
        if (-not (Test-FeatureOrPrompt -FeatureName 'Node' -Category 'Development' -Reason 'Required for npm packages')) {
            Write-Warning "Node.js feature is not enabled"
            exit 0
        }
    .OUTPUTS
        [bool] True if feature is enabled, false otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FeatureName,
        
        [Parameter(Mandatory)]
        [string]$Category,
        
        [string]$Reason = "This script requires the $FeatureName feature",
        
        [switch]$ExitOnDisabled
    )
    
    # Check if feature is enabled - function should be available from AitherZero module
    try {
        if (Test-FeatureEnabled -FeatureName $FeatureName -Category $Category) {
            return $true
        }
    } catch {
        Write-ScriptLog "Configuration functions not available or error checking feature: $($_.Exception.Message)" -Level 'Warning'
        return $false
    }
    
    # Feature is disabled - try to prompt if possible
    try {
        $enabled = Request-FeatureEnable -FeatureName $FeatureName -Category $Category -Reason $Reason
        if ($enabled) {
            return $true
        }
    } catch {
        Write-ScriptLog "Error prompting for feature (may not be available in this context): $($_.Exception.Message)" -Level 'Debug'
    }
    
    # Feature is disabled and user declined or prompting not available
    if ($ExitOnDisabled) {
        Write-ScriptLog "Feature $Category.$FeatureName is required but not enabled, exiting" -Level 'Warning'
        exit 0
    }
    
    return $false
}

# Initialize on module import
Initialize-ScriptUtilities

# Export all public functions
Export-ModuleMember -Function @(
    'Get-ProjectRoot',
    'Write-ScriptLog',
    'Test-IsAdministrator',
    'Get-PlatformName',
    'Test-CommandAvailable',
    'Get-GitHubToken',
    'Invoke-WithRetry',
    'Test-GitRepository',
    'Get-ScriptMetadata',
    'Format-Duration',
    'Test-FeatureOrPrompt'
)
