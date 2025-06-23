#Requires -Version 7.0

# Import the centralized Logging module
$loggingImported = $false

# Check if Logging module is already available
if (Get-Module -Name 'Logging' -ErrorAction SilentlyContinue) {
    $loggingImported = $true
    Write-Verbose "Logging module already available"
} else {
    $loggingPaths = @(
        'Logging',  # Try module name first (if in PSModulePath)
        (Join-Path (Split-Path $PSScriptRoot -Parent) "Logging"),  # Relative to modules directory
        (Join-Path $env:PWSH_MODULES_PATH "Logging"),  # Environment path
        (Join-Path $env:PROJECT_ROOT "core-runner/modules/Logging")  # Full project path
    )

    foreach ($loggingPath in $loggingPaths) {
        if ($loggingImported) { break }

        try {
            if ($loggingPath -eq 'Logging') {
                Import-Module 'Logging' -Global -ErrorAction Stop
            } elseif (Test-Path $loggingPath) {
                Import-Module $loggingPath -Global -ErrorAction Stop
            } else {
                continue
            }
            Write-Verbose "Successfully imported Logging module from: $loggingPath"
            $loggingImported = $true
        } catch {
            Write-Verbose "Failed to import Logging from $loggingPath : $_"
        }
    }
}

if (-not $loggingImported) {
    Write-Warning "Could not import Logging module from any of the attempted paths"
    # Fallback: dot-source local logger if centralized not available
    $localLogger = Join-Path $PSScriptRoot "Logger.ps1"
    if (Test-Path $localLogger) {
        . $localLogger
    }
}

# Dot-source utility modules
. $PSScriptRoot/Get-Platform.ps1
. $PSScriptRoot/Network.ps1
. $PSScriptRoot/InvokeOpenTofuInstaller.ps1
. $PSScriptRoot/Format-Config.ps1
. $PSScriptRoot/Expand-All.ps1
. $PSScriptRoot/Menu.ps1
. $PSScriptRoot/Download-Archive.ps1

# Temporary Get-Platform function
function Get-Platform {
    if ($IsWindows) { return 'Windows' }
    elseif ($IsLinux) { return 'Linux' }
    elseif ($IsMacOS) { return 'MacOS' }
    else { return 'Unknown' }
}

function Get-CrossPlatformTempPath {
    <#
    .SYNOPSIS
    Returns the appropriate temporary directory path for the current platform.

    .DESCRIPTION
    Provides a cross-platform way to get the temporary directory, handling cases where
    $env:TEMP might not be set (e.g., on Linux/macOS).
    #>
    if ($env:TEMP) {
        return $env:TEMP
    } else {
        return [System.IO.Path]::GetTempPath()
    }
}

function Invoke-CrossPlatformCommand {
    <#
    .SYNOPSIS
    Safely invokes platform-specific cmdlets with fallback behavior

    .DESCRIPTION
    Checks if a cmdlet is available before invoking it, allowing scripts to be more
    cross-platform compatible. Provides mock-friendly execution for testing.

    .PARAMETER CommandName
    The name of the cmdlet to invoke

    .PARAMETER Parameters
    Hashtable of parameters to pass to the cmdlet

    .PARAMETER MockResult
    Result to return when the cmdlet is not available (for testing/cross-platform compatibility)

    .PARAMETER SkipOnUnavailable
    If true, silently skip execution when cmdlet is unavailable instead of throwing
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [hashtable]$Parameters = @{},

        [object]$MockResult = $null,

        [switch]$SkipOnUnavailable
    )

    if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
        return & $CommandName @Parameters
    } elseif ($MockResult -ne $null) {
        Write-CustomLog "Command '$CommandName' not available, returning mock result" 'WARN'
        return $MockResult
    } elseif ($SkipOnUnavailable) {
        Write-CustomLog "Command '$CommandName' not available, skipping" 'WARN'
        return $null
    } else {
        throw "Command '$CommandName' is not available on this platform"
    }
}

function Invoke-LabStep {
    [CmdletBinding()]
    param(
        [scriptblock]$Body,
        [object]$Config
    )

    # Handle config parameter - can be string path, JSON string, or object
    if ($Config -is [string]) {
        if (Test-Path $Config) {
            $Config = Get-Content -Raw -Path $Config | ConvertFrom-Json
        } else {
            try { $Config = $Config | ConvertFrom-Json } catch {}
        }
    }

    $suppress = $false
    if ($env:LAB_CONSOLE_LEVEL -eq '0') {
        $suppress = $true
    } elseif ($PSCommandPath -and (Split-Path $PSCommandPath -Leaf) -eq 'dummy.ps1') {
        $suppress = $true
    }

    $prevConsole = $null
    if ($suppress) {
        if (Get-Variable -Name ConsoleLevel -Scope Script -ErrorAction SilentlyContinue) {
            $prevConsole = $script:ConsoleLevel
        }
        $script:ConsoleLevel = -1
    }

    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Stop'
    try {
        & $Body $Config
    } catch {
        if (-not $suppress) {
            Write-CustomLog "ERROR: $_" 'ERROR'
        }
        throw
    } finally {
        $ErrorActionPreference = $prevEAP
        if ($suppress -and $null -ne $prevConsole) {
            $script:ConsoleLevel = $prevConsole
        }
    }
}

function Invoke-LabDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        [Parameter(Mandatory)]
        [scriptblock]$Action,
        [string]$Prefix = 'download',
        [string]$Extension
    )

    $ext = if ($Extension) {
        if ($Extension.StartsWith('.')) { $Extension } else { ".$Extension" }
    } else {
        try { [System.IO.Path]::GetExtension($Uri).Split('?')[0] } catch { '' }
    }

    $tempDir = Get-CrossPlatformTempPath
    $path = Join-Path $tempDir ("{0}_{1}{2}" -f $Prefix, [guid]::NewGuid(), $ext)
    Write-CustomLog "Downloading $Uri to $path"

    try {
        Invoke-LabWebRequest -Uri $Uri -OutFile $path -UseBasicParsing
        & $Action $path
    } finally {
        Remove-Item $path -Force -ErrorAction SilentlyContinue
    }
}

function Read-LoggedInput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,
        [switch]$AsSecureString,
        [string]$DefaultValue = ""
    )

    # Check if we're in non-interactive mode (test environment, etc.)
    $IsNonInteractive = ($Host.Name -eq 'Default Host') -or
                      ([Environment]::UserInteractive -eq $false) -or
                      ($env:PESTER_RUN -eq 'true')

    if ($IsNonInteractive) {
        Write-CustomLog "Non-interactive mode detected. Using default value for: $Prompt" 'INFO'
        if ($AsSecureString -and -not [string]::IsNullOrEmpty($DefaultValue)) {
            return ConvertTo-SecureString -String $DefaultValue -AsPlainText -Force
        }
        return $DefaultValue
    }

    if ($AsSecureString) {
        Write-CustomLog "$Prompt (secure input)"
        return Read-Host -Prompt $Prompt -AsSecureString
    }

    $answer = Read-Host -Prompt $Prompt
    Write-CustomLog "$($Prompt): $answer"
    return $answer
}

function Invoke-LabWebRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        [string]$OutFile,
        [switch]$UseBasicParsing
    )

    try {
        Invoke-WebRequest @PSBoundParameters
    } catch {
        Write-CustomLog "Web request failed for $Uri : $_" 'ERROR'
        throw
    }
}

function Invoke-LabNpm {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$Args
    )

    Write-CustomLog "Running npm $($Args -join ' ')" 'INFO'
    npm @Args
}

function Resolve-ProjectPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    $projectRoot = $env:PROJECT_ROOT
    if (-not $projectRoot) {
        $projectRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
    }

    return Join-Path $projectRoot $RelativePath
}

function Get-LabConfig {
    [CmdletBinding()]
    param(
        [string]$Path = 'configs/lab_config.yaml'
    )

    $fullPath = if ([System.IO.Path]::IsPathRooted($Path)) {
        $Path
    } else {
        Resolve-ProjectPath $Path
    }

    if (-not (Test-Path $fullPath)) {
        Write-CustomLog "Config file not found: $fullPath" 'WARN'
        return $null
    }

    try {
        # Simple YAML-like parsing for basic config files
        $content = Get-Content $fullPath -Raw
        $config = @{}

        $content -split "`n" | ForEach-Object {
            $line = $_.Trim()
            if ($line -and -not $line.StartsWith('#')) {
                if ($line -match '^(\w+):\s*(.+)$') {
                    $config[$matches[1]] = $matches[2].Trim('"''')
                }
            }
        }

        return $config
    } catch {
        Write-CustomLog "Failed to parse config file $fullPath : $_" 'ERROR'
        throw
    }
}

# Import nested module for additional functions if available
try {
    Import-Module (Join-Path $PSScriptRoot 'Resolve-ProjectPath.psm1') -Force -ErrorAction Stop
} catch {
    Write-Verbose "Failed to import Resolve-ProjectPath.psm1: $_"
}

# Import all public functions if they exist (temporarily disabled for debugging)
# Import public functions
$publicFunctionsPath = Join-Path $PSScriptRoot "Public"
if (Test-Path $publicFunctionsPath) {
    Get-ChildItem -Path "$publicFunctionsPath/*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            . $_.FullName
        } catch {
            Write-Warning "Failed to import $($_.Name): $_"
        }
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Get-CrossPlatformTempPath',
    'Invoke-CrossPlatformCommand',
    'Invoke-LabStep',
    'Invoke-LabDownload',
    'Read-LoggedInput',
    'Invoke-LabWebRequest',
    'Invoke-LabNpm',
    'Resolve-ProjectPath',
    'Get-LabConfig',
    'Format-Config',
    'Expand-All',
    'Get-MenuSelection',
    'Get-GhDownloadArgs',
    'Invoke-ArchiveDownload',
    'Get-Platform',
    'Invoke-OpenTofuInstaller',
    'Invoke-ParallelLabRunner'
)
