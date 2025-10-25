#Requires -Version 7.0
# Stage: Prepare
# Dependencies: None
# Description: Create required directories for infrastructure

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [hashtable]$Configuration
)

# Initialize logging
$script:LoggingAvailable = $false
try {
    $loggingPath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/core/Logging.psm1"
    if (Test-Path $loggingPath) {
        Import-Module $loggingPath -Force -Global
        $script:LoggingAvailable = $true
    }
} catch {
    # Fallback to basic output if logging module fails to load
    Write-Warning "Could not load logging module: $($_.Exception.Message)"
    $script:LoggingAvailable = $false
}

function Write-ScriptLog {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level
    } else {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $prefix = switch ($Level) {
            'Error' { 'ERROR' }
            'Warning' { 'WARN' }
            'Debug' { 'DEBUG' }
            default { 'INFO' }
        }
        Write-Host "[$timestamp] [$prefix] $Message"
    }
}

Write-ScriptLog "Starting directory setup"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Collect directories to create
    $directoriesToCreate = @()

    # Infrastructure directories
    if ($config.Infrastructure -and $config.Infrastructure.Directories) {
        $dirs = $config.Infrastructure.Directories
        
        if ($dirs.HyperVPath) {
            $directoriesToCreate += $dirs.HyperVPath
        }
        if ($dirs.IsoSharePath) {
            $directoriesToCreate += $dirs.IsoSharePath
        }
        if ($dirs.LocalPath) {
            $directoriesToCreate += $dirs.LocalPath
        }
        if ($dirs.InfraRepoPath) {
            $directoriesToCreate += $dirs.InfraRepoPath
        }
        
        # Legacy paths that might still be referenced
        if ($dirs.HyperVDisks) {
            $directoriesToCreate += $dirs.HyperVDisks
        }
        if ($dirs.HyperVIsos) {
            $directoriesToCreate += $dirs.HyperVIsos
        }
    }

    # Default directories if none specified
    if ($directoriesToCreate.Count -eq 0) {
        Write-ScriptLog "No directories specified in configuration, using defaults" -Level 'Warning'
        
        if ($IsWindows) {
            $directoriesToCreate = @(
                'C:/HyperV',
                'C:/HyperV/VHDs',
                'C:/HyperV/ISOs',
                'C:/iso_share',
                'C:/temp'
            )
        } else {
            $directoriesToCreate = @(
                "$HOME/.aitherzero/vms",
                "$HOME/.aitherzero/isos",
                "$HOME/.aitherzero/temp"
            )
        }
    }

    # Create each directory
    foreach ($dir in $directoriesToCreate) {
        if ([string]::IsNullOrWhiteSpace($dir)) {
            continue
        }
        
        $expandedDir = [System.Environment]::ExpandEnvironmentVariables($dir)
        
        if (-not (Test-Path $expandedDir)) {
            Write-ScriptLog "Creating directory: $expandedDir"
            try {
                New-Item -ItemType Directory -Path $expandedDir -Force | Out-Null
                Write-ScriptLog "Successfully created: $expandedDir"
            } catch {
                Write-ScriptLog "Failed to create directory $expandedDir : $_" -Level 'Error'
                throw
            }
        } else {
            Write-ScriptLog "Directory already exists: $expandedDir" -Level 'Debug'
        }
    }

    # Create logs directory
    $logsPath = if ($config.Logging -and $config.Logging.Path) {
        $config.Logging.Path
    } else {
        './logs'
    }
    
    $expandedLogsPath = if ([System.IO.Path]::IsPathRooted($logsPath)) {
        $logsPath
    } else {
        Join-Path (Split-Path $PSScriptRoot -Parent) $logsPath
    }

    if (-not (Test-Path $expandedLogsPath)) {
        Write-ScriptLog "Creating logs directory: $expandedLogsPath"
        New-Item -ItemType Directory -Path $expandedLogsPath -Force | Out-Null
    }
    
    Write-ScriptLog "Directory setup completed successfully"
    exit 0
    
} catch {
    Write-ScriptLog "Directory setup failed: $_" -Level 'Error'
    exit 1
}
