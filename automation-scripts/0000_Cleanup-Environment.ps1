#Requires -Version 7.0
# Stage: Prepare
# Dependencies: None
# Description: Clean up temporary files and prepare environment

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

Write-ScriptLog "Starting environment cleanup"

try {
    # Get configuration values
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Determine paths
    $tempPath = if ($IsWindows) { $env:TEMP } else { '/tmp' }
    $localBase = if ($config.Infrastructure -and $config.Infrastructure.Directories -and $config.Infrastructure.Directories.LocalPath) {
        [System.Environment]::ExpandEnvironmentVariables($config.Infrastructure.Directories.LocalPath)
    } else {
        $tempPath
    }

    # Clean up repository directory if configured (WITH SAFETY GUARDS)
    if ($config.Infrastructure -and $config.Infrastructure.Repositories -and $config.Infrastructure.Repositories.RepoUrl) {
        $repoUrl = $config.Infrastructure.Repositories.RepoUrl
        $repoName = ($repoUrl -split '/')[-1] -replace '\.git$', ''

        if ($repoName) {
            # Only clean up if the path is properly set and not the current project
            if ($localBase -and (Test-Path $localBase)) {
                $repoPath = Join-Path $localBase $repoName

                # Safety check: Don't delete the current AitherZero project!
                $currentProject = Split-Path $PSScriptRoot -Parent
                if ($repoPath -eq $currentProject) {
                    Write-ScriptLog "SAFETY: Refusing to delete current project directory!" -Level 'Warning'
                } elseif ($repoPath -match 'AitherZero' -and (Test-Path (Join-Path $repoPath '.git'))) {
                    Write-ScriptLog "SAFETY: Refusing to delete what appears to be an AitherZero git repository!" -Level 'Warning'
                } elseif (Test-Path $repoPath) {
                    Write-ScriptLog "Removing repository path: $repoPath"
                    Remove-Item -Recurse -Force -Path $repoPath -ErrorAction Stop
                    Write-ScriptLog "Repository cleanup completed"
                } else {
                    Write-ScriptLog "Repository path not found: $repoPath" -Level 'Debug'
                }
            } else {
                Write-ScriptLog "Local base path not properly configured, skipping cleanup" -Level 'Debug'
            }
        }
    }

    # Clean up infrastructure directory
    $infraPath = if ($config.Infrastructure -and $config.Infrastructure.Directories -and $config.Infrastructure.Directories.InfraRepoPath) {
        [System.Environment]::ExpandEnvironmentVariables($config.Infrastructure.Directories.InfraRepoPath)
    } else {
        if ($IsWindows) { 'C:/Temp/base-infra' } else { '/tmp/base-infra' }
    }

    if (Test-Path $infraPath) {
        Write-ScriptLog "Removing infrastructure path: $infraPath"
        Remove-Item -Recurse -Force -Path $infraPath -ErrorAction Stop
        Write-ScriptLog "Infrastructure cleanup completed"
    } else {
        Write-ScriptLog "Infrastructure path not found: $infraPath" -Level 'Debug'
    }

    # Clean up temporary AitherZero files
    $patterns = @(
        'aitherzero-temp-*',
        'tofu_*.cmd',
        'terraform_*.cmd'
    )

    foreach ($pattern in $patterns) {
        $tempFiles = Get-ChildItem -Path $tempPath -Filter $pattern -ErrorAction SilentlyContinue
        foreach ($file in $tempFiles) {
            try {
                Write-ScriptLog "Removing temporary file: $($file.FullName)" -Level 'Debug'
                Remove-Item -Path $file.FullName -Force -ErrorAction Stop
            } catch {
                Write-ScriptLog "Failed to remove $($file.FullName): $_" -Level 'Warning'
            }
        }
    }

    Write-ScriptLog "Environment cleanup completed successfully"
    exit 0

} catch {
    Write-ScriptLog "Environment cleanup failed: $_" -Level 'Error'
    exit 1
}
