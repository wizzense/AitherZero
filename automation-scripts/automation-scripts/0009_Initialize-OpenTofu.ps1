#Requires -Version 7.0
# Stage: Infrastructure
# Dependencies: OpenTofu
# Description: Initialize OpenTofu in infrastructure directory
# Tags: infrastructure, opentofu, terraform

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [hashtable]$Configuration
)

# Initialize logging
$script:LoggingAvailable = $false
try {
    $loggingPath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/utilities/Logging.psm1"
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

Write-ScriptLog "Starting OpenTofu initialization"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if OpenTofu is available
    try {
        $tofuVersion = & tofu version 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "OpenTofu not available"
        }
        Write-ScriptLog "Using OpenTofu: $($tofuVersion -split "`n" | Select-Object -First 1)" -Level 'Debug'
    } catch {
        Write-ScriptLog "OpenTofu not found. Please run script 0008 first." -Level 'Error'
        exit 1
    }

    # Determine infrastructure path
    $infraPath = if ($config.Infrastructure -and $config.Infrastructure.WorkingDirectory) {
        $config.Infrastructure.WorkingDirectory
    } else {
        './infrastructure'
    }

    # Handle relative paths
    if (-not [System.IO.Path]::IsPathRooted($infraPath)) {
        $infraPath = Join-Path (Split-Path $PSScriptRoot -Parent) $infraPath
    }

    # Also check legacy path
    $legacyInfraPath = if ($config.Infrastructure -and $config.Infrastructure.Directories -and $config.Infrastructure.Directories.InfraRepoPath) {
        [System.Environment]::ExpandEnvironmentVariables($config.Infrastructure.Directories.InfraRepoPath)
    } else {
        $null
    }

    # Find OpenTofu/Terraform files
    $tofuDirectories = @()

    if (Test-Path $infraPath) {
        # Check main directory
        $tfFiles = Get-ChildItem -Path $infraPath -Filter "*.tf" -File -ErrorAction SilentlyContinue
        if ($tfFiles) {
            $tofuDirectories += $infraPath
        }

        # Check subdirectories
        $subDirs = Get-ChildItem -Path $infraPath -Directory -ErrorAction SilentlyContinue
        foreach ($dir in $subDirs) {
            $tfFiles = Get-ChildItem -Path $dir.FullName -Filter "*.tf" -File -ErrorAction SilentlyContinue
            if ($tfFiles) {
                $tofuDirectories += $dir.FullName
            }
        }
    }

    # Check legacy path
    if ($legacyInfraPath -and (Test-Path $legacyInfraPath)) {
        $legacyTofu = Join-Path $legacyInfraPath "opentofu"
        if (Test-Path $legacyTofu) {
            $tfFiles = Get-ChildItem -Path $legacyTofu -Filter "*.tf" -File -ErrorAction SilentlyContinue
            if ($tfFiles) {
                $tofuDirectories += $legacyTofu
            }
        }
    }

    if ($tofuDirectories.Count -eq 0) {
        Write-ScriptLog "No Terraform/OpenTofu files found in infrastructure directories" -Level 'Warning'
        Write-ScriptLog "Searched paths:" -Level 'Debug'
        Write-ScriptLog "  - $infraPath" -Level 'Debug'
        if ($legacyInfraPath) {
            Write-ScriptLog "  - $legacyInfraPath" -Level 'Debug'
        }
        exit 0
    }

    # Initialize each directory
    foreach ($tofuDir in $tofuDirectories) {
        Write-ScriptLog "Initializing OpenTofu in: $tofuDir"

        Push-Location $tofuDir
        try {
            # Check if already initialized
            if (Test-Path '.terraform') {
                Write-ScriptLog "Directory already initialized, running update" -Level 'Debug'
                $initArgs = @('init', '-upgrade')
            } else {
                $initArgs = @('init')
            }

            # Add backend config if specified
            if ($config.Infrastructure -and $config.Infrastructure.Backend) {
                $backend = $config.Infrastructure.Backend
                if ($backend.Type) {
                    $initArgs += "-backend-config=`"type=$($backend.Type)`""
                }
                foreach ($key in $backend.Keys | Where-Object { $_ -ne 'Type' }) {
                    $initArgs += "-backend-config=`"$key=$($backend[$key])`""
                }
            }

            # Run init
            Write-ScriptLog "Running: tofu $($initArgs -join ' ')" -Level 'Debug'

            # Check if tofu is available
            if (-not (Get-Command tofu -ErrorAction SilentlyContinue)) {
                Write-ScriptLog "OpenTofu (tofu) command not found. Please install OpenTofu first." -Level 'Warning'
                continue
            }

            # Execute tofu with proper argument handling
            try {
                if ($initArgs.Count -gt 0) {
                    $result = & tofu @initArgs 2>&1
                } else {
                    $result = & tofu init 2>&1
                }
                $exitCode = $LASTEXITCODE

                if ($result) {
                    Write-ScriptLog "$result" -Level 'Debug'
                }
            } catch {
                Write-ScriptLog "Error executing tofu: $_" -Level 'Error'
                continue
            }

            if ($exitCode -eq 0) {
                Write-ScriptLog "Successfully initialized: $tofuDir"

                # Validate configuration
                Write-ScriptLog "Validating configuration..." -Level 'Debug'
                try {
                    $validateResult = & tofu validate 2>&1
                    $validateExitCode = $LASTEXITCODE

                    if ($validateResult) {
                        Write-ScriptLog "$validateResult" -Level 'Debug'
                    }

                    if ($validateExitCode -eq 0) {
                        Write-ScriptLog "Configuration is valid"
                    } else {
                        Write-ScriptLog "Configuration validation failed" -Level 'Warning'
                    }
                } catch {
                    Write-ScriptLog "Error validating configuration: $_" -Level 'Warning'
                }
            } else {
                Write-ScriptLog "Failed to initialize: $tofuDir" -Level 'Error'
            }

        } catch {
            Write-ScriptLog "Error during initialization: $_" -Level 'Error'
        } finally {
            Pop-Location
        }
    }

    Write-ScriptLog "OpenTofu initialization completed"
    exit 0

} catch {
    Write-ScriptLog "OpenTofu initialization failed: $_" -Level 'Error'
    exit 1
}