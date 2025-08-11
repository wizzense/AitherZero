#Requires -Version 7.0
# Stage: Validation
# Dependencies: None
# Description: Validate environment setup and dependencies
# Tags: validation, testing, health-check

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

Write-ScriptLog "Starting environment validation"

$validationResults = @{
    PowerShell = $false
    Git = $false
    OpenTofu = $false
    HyperV = $false
    Node = $false
    Docker = $false
    Directories = $true
    Network = $true
}

$issues = @()

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }
    
    Write-ScriptLog "Validating core dependencies..."

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $validationResults.PowerShell = $true
        Write-ScriptLog "✓ PowerShell 7+: $($PSVersionTable.PSVersion)" -Level 'Debug'
    } else {
        $issues += "PowerShell 7+ required, found: $($PSVersionTable.PSVersion)"
    }

    # Check Git
    try {
        $gitVersion = & git --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            $validationResults.Git = $true
            Write-ScriptLog "✓ Git: $gitVersion" -Level 'Debug'
        }
    } catch {
        if ($config.InstallationOptions.Git.Required -eq $true) {
            $issues += "Git is required but not found"
        }
    }

    # Check OpenTofu
    try {
        $tofuVersion = & tofu version 2>&1 | Select-Object -First 1
        if ($LASTEXITCODE -eq 0) {
            $validationResults.OpenTofu = $true
            Write-ScriptLog "✓ OpenTofu: $tofuVersion" -Level 'Debug'
        }
    } catch {
        if ($config.InstallationOptions.OpenTofu.Install -eq $true) {
            $issues += "OpenTofu expected but not found"
        }
    }

    # Check Hyper-V (Windows only, and only if configured)
    if ($IsWindows -and $config.InstallationOptions.HyperV.Install -eq $true) {
        try {
            $hyperv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
            if ($hyperv.State -eq 'Enabled') {
                $validationResults.HyperV = $true
                Write-ScriptLog "✓ Hyper-V: Enabled" -Level 'Debug'
                
                # Check Hyper-V service
                $vmms = Get-Service -Name vmms -ErrorAction SilentlyContinue
                if ($vmms.Status -ne 'Running') {
                    $issues += "Hyper-V is enabled but VMMS service is not running"
                }
            } else {
                $issues += "Hyper-V expected but not enabled"
                $validationResults.HyperV = $false
            }
        } catch {
            $issues += "Hyper-V expected but not enabled"
            $validationResults.HyperV = $false
        }
    } elseif ($IsWindows) {
        Write-ScriptLog "Hyper-V: Not configured for installation" -Level 'Debug'
    }

    # Check Node.js (only if configured to be installed)
    if ($config.InstallationOptions.Node.Install -eq $true) {
        try {
            $nodeVersion = & node --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                $validationResults.Node = $true
                Write-ScriptLog "✓ Node.js: $nodeVersion" -Level 'Debug'

                # Check npm
                $npmVersion = & npm --version 2>&1
                Write-ScriptLog "✓ npm: v$npmVersion" -Level 'Debug'
            } else {
                $issues += "Node.js expected but not found"
                $validationResults.Node = $false
            }
        } catch {
            $issues += "Node.js expected but not found"
            $validationResults.Node = $false
        }
    } else {
        # Node.js not required, mark as N/A
        Write-ScriptLog "Node.js: Not configured for installation" -Level 'Debug'
    }

    # Check Docker (only if configured to be installed)
    if ($config.InstallationOptions.DockerDesktop.Install -eq $true) {
        try {
            $dockerVersion = & docker --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                $validationResults.Docker = $true
                Write-ScriptLog "✓ Docker: $dockerVersion" -Level 'Debug'
            } else {
                $issues += "Docker expected but not found"
                $validationResults.Docker = $false
            }
        } catch {
            $issues += "Docker expected but not found"
            $validationResults.Docker = $false
        }
    } else {
        # Docker not required, mark as N/A
        Write-ScriptLog "Docker: Not configured for installation" -Level 'Debug'
    }

    # Check directories (create if missing)
    Write-ScriptLog "Validating directory structure..."

    if ($config.Infrastructure -and $config.Infrastructure.Directories) {
        $validationResults.Directories = $true  # Assume success unless we can't create
        
        foreach ($dirKey in $config.Infrastructure.Directories.Keys) {
            $dirPath = [System.Environment]::ExpandEnvironmentVariables($config.Infrastructure.Directories[$dirKey])
            if (-not (Test-Path $dirPath)) {
                # Try to create the directory
                try {
                    Write-ScriptLog "Creating missing directory: $dirPath" -Level 'Warning'
                    New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
                    Write-ScriptLog "✓ Directory created: $dirPath" -Level 'Debug'
                } catch {
                    $validationResults.Directories = $false
                    $issues += "Cannot create directory: $dirPath - $_"
                    Write-ScriptLog "✗ Failed to create directory: $dirPath" -Level 'Error'
                }
            } else {
                Write-ScriptLog "✓ Directory exists: $dirPath" -Level 'Debug'
            }
        }
    }

    # Check network connectivity
    Write-ScriptLog "Validating network connectivity..."
    
    $testUrls = @(
        'https://github.com',
        'https://registry.npmjs.org',
        'https://api.github.com'
    )

    foreach ($url in $testUrls) {
        try {
            $response = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 5 -UseBasicParsing
            Write-ScriptLog "✓ Network access: $url" -Level 'Debug'
        } catch {
            $validationResults.Network = $false
            $issues += "Cannot reach: $url"
        }
    }

    # Summary
    Write-ScriptLog "`nValidation Summary:"
    Write-ScriptLog "=================="
    
    $passCount = ($validationResults.Values | Where-Object { $_ -eq $true }).Count
    $totalCount = $validationResults.Count
    
    foreach ($key in $validationResults.Keys | Sort-Object) {
        $status = if ($validationResults[$key]) { "✓ PASS" } else { "✗ FAIL" }
        $color = if ($validationResults[$key]) { 'Debug' } else { 'Warning' }
        Write-ScriptLog "$status - $key" -Level $color
    }
    
    Write-ScriptLog "`nResult: $passCount/$totalCount checks passed"

    if ($issues.Count -gt 0) {
        Write-ScriptLog "`nIssues found:" -Level 'Warning'
        foreach ($issue in $issues) {
            Write-ScriptLog "  - $issue" -Level 'Warning'
        }
        
        # Exit with warning code
        exit 2
    } else {
        Write-ScriptLog "`nAll validations passed successfully!" -Level 'Information'
        exit 0
    }
    
} catch {
    Write-ScriptLog "Validation failed with error: $_" -Level 'Error'
    exit 1
}