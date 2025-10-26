#Requires -Version 7.0
# Stage: Infrastructure
# Dependencies: OpenTofu, HyperV
# Description: Bootstrap and deploy infrastructure using OpenTofu with comprehensive configuration
# Tags: infrastructure, deployment, opentofu, bootstrap
# Condition: Features -contains 'OpenTofu'

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [hashtable]$Configuration,
    
    [Parameter()]
    [switch]$Bootstrap,
    
    [Parameter()]
    [switch]$PlanOnly,
    
    [Parameter()]
    [switch]$AutoApply
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

    # Load Infrastructure module for bootstrap functionality
    $infraModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/infrastructure/Infrastructure.psm1"
    if (Test-Path $infraModulePath) {
        Import-Module $infraModulePath -Force
        Write-ScriptLog "Infrastructure module loaded successfully"
    } else {
        Write-ScriptLog "Infrastructure module not found: $infraModulePath" -Level 'Warning'
    }

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

    # Bootstrap infrastructure if requested or if directory doesn't exist
    if ($Bootstrap -or (-not (Test-Path $infraDir)) -or ($config.Infrastructure -and $config.Infrastructure.Bootstrap -eq $true)) {
        Write-ScriptLog "Starting infrastructure bootstrap process..."
        
        if (Get-Command Start-InfrastructureBootstrap -ErrorAction SilentlyContinue) {
            $bootstrapResult = Start-InfrastructureBootstrap -Configuration $config
            if (-not $bootstrapResult) {
                throw "Infrastructure bootstrap failed"
            }
            Write-ScriptLog "Infrastructure bootstrap completed successfully"
        } else {
            # Fallback bootstrap process
            Write-ScriptLog "Using fallback bootstrap process..."
            
            if (-not (Test-Path $infraDir)) {
                Write-ScriptLog "Creating infrastructure directory: $infraDir"
                New-Item -ItemType Directory -Path $infraDir -Force | Out-Null
            }

            # Create basic structure
            $basicDirs = @("modules", "environments", "shared")
            foreach ($dir in $basicDirs) {
                $fullPath = Join-Path $infraDir $dir
                if (-not (Test-Path $fullPath)) {
                    Write-ScriptLog "Creating directory: $fullPath"
                    New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
                }
            }
        }
    }

    if (-not (Test-Path $infraDir)) {
        Write-ScriptLog "Infrastructure directory not found after bootstrap: $infraDir" -Level 'Error'
        throw "Infrastructure directory could not be created"
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

        # Validate configuration first
        Write-ScriptLog "Validating infrastructure configuration..."
        & tofu validate
        if ($LASTEXITCODE -ne 0) {
            throw "Infrastructure configuration validation failed"
        }
        Write-ScriptLog "Infrastructure configuration is valid"

        # Plan deployment
        Write-ScriptLog "Planning infrastructure deployment..."
        & tofu plan -out=tfplan

        if ($LASTEXITCODE -ne 0) {
            throw "OpenTofu plan failed"
        }

        # Show plan summary
        Write-ScriptLog "Infrastructure plan created successfully"

        # If PlanOnly switch is set, stop here
        if ($PlanOnly) {
            Write-ScriptLog "Plan-only mode: Infrastructure plan saved to tfplan"
            Write-ScriptLog "To apply: Run 'tofu apply tfplan' in $infraDir"
            return
        }

        # Determine if we should auto-apply
        $shouldAutoApply = $AutoApply -or 
                          ($config.Automation -and $config.Automation.AutoRun -eq $true) -or
                          ($config.Core -and $config.Core.NonInteractive -eq $true)

        if ($shouldAutoApply) {
            Write-ScriptLog "Auto-applying infrastructure..."
            & tofu apply -auto-approve tfplan

            if ($LASTEXITCODE -eq 0) {
                Write-ScriptLog "Infrastructure deployed successfully"
                
                # Get deployment outputs
                Write-ScriptLog "Retrieving infrastructure outputs..."
                $outputs = & tofu output -json 2>&1
                if ($LASTEXITCODE -eq 0 -and $outputs) {
                    try {
                        $outputData = $outputs | ConvertFrom-Json
                        Write-ScriptLog "Infrastructure outputs:"
                        foreach ($key in $outputData.PSObject.Properties.Name) {
                            $value = $outputData.$key.value
                            Write-ScriptLog "  $key = $value"
                        }
                    } catch {
                        Write-ScriptLog "Could not parse infrastructure outputs" -Level 'Warning'
                    }
                }
            } else {
                throw "OpenTofu apply failed"
            }
        } else {
            Write-ScriptLog "Run 'tofu apply tfplan' to deploy infrastructure" -Level 'Warning'
            Write-ScriptLog "Or use -AutoApply switch for automatic deployment"
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