#Requires -Version 7.0
# Stage: Infrastructure
# Dependencies: OpenTofu, HyperV
# Description: Deploy infrastructure using OpenTofu
# Tags: infrastructure, deployment, opentofu
# Condition: Features -contains 'OpenTofu'

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
    # Fallback to basic output
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

Write-ScriptLog "Starting infrastructure deployment"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Get infrastructure directory
    $infraDir = if ($config.Infrastructure -and $config.Infrastructure.WorkingDirectory) {
        $config.Infrastructure.WorkingDirectory
    } else {
        './infrastructure'
    }

    # Resolve path relative to project root
    if (-not [System.IO.Path]::IsPathRooted($infraDir)) {
        $infraDir = Join-Path (Split-Path $PSScriptRoot -Parent) $infraDir
    }

    if (-not (Test-Path $infraDir)) {
        Write-ScriptLog "Infrastructure directory not found: $infraDir" -Level 'Warning'
        Write-ScriptLog "Creating infrastructure directory..."
        New-Item -ItemType Directory -Path $infraDir -Force | Out-Null
    }

    # Check for OpenTofu
    try {
        $tofuVersion = & tofu version 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "OpenTofu not available"
        }
        Write-ScriptLog "Using OpenTofu: $($tofuVersion -split "`n" | Select-Object -First 1)"
    } catch {
        Write-ScriptLog "OpenTofu not found. Please run script 0008 first." -Level 'Error'
        exit 1
    }

    # Change to infrastructure directory
    Push-Location $infraDir
    try {
        # Initialize if needed
        if (-not (Test-Path '.terraform')) {
            Write-ScriptLog "Initializing OpenTofu..."
            & tofu init

            if ($LASTEXITCODE -ne 0) {
                throw "OpenTofu init failed"
            }
        }

        # Create tfvars from configuration
        if ($config.Infrastructure) {
            Write-ScriptLog "Creating terraform.tfvars from configuration..."

            $tfvars = @"
# Generated from AitherZero configuration
hyperv_host = "$($config.Infrastructure.HyperV.Host)"
hyperv_user = "$($config.Infrastructure.HyperV.User)"
hyperv_port = $($config.Infrastructure.HyperV.Port)

vm_path = "$($config.Infrastructure.DefaultVMPath)"
default_memory = "$($config.Infrastructure.DefaultMemory)"
default_cpu = $($config.Infrastructure.DefaultCPU)
"@

            $tfvars | Set-Content -Path 'terraform.tfvars'
        }

        # Plan deployment
        Write-ScriptLog "Planning infrastructure deployment..."
        & tofu plan -out=tfplan

        if ($LASTEXITCODE -ne 0) {
            throw "OpenTofu plan failed"
        }

        # Show plan summary
        Write-ScriptLog "Infrastructure plan created successfully"

        # Auto-apply if in non-interactive mode
        if ($config.Automation -and $config.Automation.AutoRun -eq $true) {
            Write-ScriptLog "Auto-applying infrastructure..."
            & tofu apply -auto-approve tfplan

            if ($LASTEXITCODE -eq 0) {
                Write-ScriptLog "Infrastructure deployed successfully"
            } else {
                throw "OpenTofu apply failed"
            }
        } else {
            Write-ScriptLog "Run 'tofu apply tfplan' to deploy infrastructure" -Level 'Warning'
        }

    } finally {
        Pop-Location
    }

    Write-ScriptLog "Infrastructure deployment completed"
    exit 0

} catch {
    Write-ScriptLog "Infrastructure deployment failed: $_" -Level 'Error'
    exit 1
}