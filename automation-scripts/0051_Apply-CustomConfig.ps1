#Requires -Version 7.0

<#
.SYNOPSIS
    Applies custom configuration to AitherZero
.DESCRIPTION
    Downloads or loads custom configuration files and applies them to the local AitherZero installation.
    Supports both merging with existing config or replacing entirely.
.PARAMETER ConfigPath
    Path to a local config.psd1 file
.PARAMETER ConfigUrl
    URL to download config.psd1 from
.PARAMETER Merge
    Merge with existing config instead of replacing
.PARAMETER Backup
    Create backup of existing config before applying
.PARAMETER ValidateOnly
    Validate config without applying
.EXAMPLE
    ./0051_Apply-CustomConfig.ps1 -ConfigPath ./my-config.psd1
.EXAMPLE
    ./0051_Apply-CustomConfig.ps1 -ConfigUrl https://mycompany.com/aitherzero.psd1 -Merge
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ParameterSetName = 'File')]
    [ValidateScript({ Test-Path $_ })]
    [string]$ConfigPath,
    
    [Parameter(Mandatory, ParameterSetName = 'Url')]
    [ValidatePattern('^https?://')]
    [string]$ConfigUrl,
    
    [switch]$Merge,
    
    [switch]$Backup = $true,
    
    [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Get project root
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:LocalConfigPath = Join-Path $script:ProjectRoot "config.local.psd1"
$script:MainConfigPath = Join-Path $script:ProjectRoot "config.psd1"

# Import required modules
$configModule = Join-Path $script:ProjectRoot "domains/configuration/Configuration.psm1"
if (Test-Path $configModule) {
    Import-Module $configModule -Force
}

function Write-ConfigLog {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message "[CONFIG] $Message" -Level $Level -Source "ApplyConfig"
    } else {
        $color = switch ($Level) {
            'Error' { 'Red' }
            'Warning' { 'Yellow' }
            'Success' { 'Green' }
            default { 'White' }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
}

function Test-ConfigurationValid {
    param(
        [hashtable]$Config
    )
    
    $errors = @()
    $warnings = @()
    
    # Check for required sections
    $requiredSections = @('Core')
    foreach ($section in $requiredSections) {
        if (-not $Config.ContainsKey($section)) {
            $errors += "Missing required section: $section"
        }
    }
    
    # Validate Core section
    if ($Config.Core) {
        # Check Profile value
        if ($Config.Core.Profile) {
            $validProfiles = @('Minimal', 'Standard', 'Developer', 'Full')
            if ($Config.Core.Profile -notin $validProfiles) {
                $errors += "Invalid Profile: $($Config.Core.Profile). Must be one of: $($validProfiles -join ', ')"
            }
        }
        
        # Check Environment value
        if ($Config.Core.Environment) {
            $validEnvironments = @('Development', 'Testing', 'Staging', 'Production', 'CI')
            if ($Config.Core.Environment -notin $validEnvironments) {
                $warnings += "Non-standard Environment: $($Config.Core.Environment)"
            }
        }
    }
    
    # Validate Automation section
    if ($Config.Automation) {
        if ($null -ne $Config.Automation.MaxConcurrency -and $Config.Automation.MaxConcurrency -lt 1) {
            $errors += "MaxConcurrency must be at least 1"
        }
        
        if ($null -ne $Config.Automation.DefaultTimeout -and $Config.Automation.DefaultTimeout -lt 0) {
            $errors += "DefaultTimeout cannot be negative"
        }
    }
    
    # Validate Testing section
    if ($Config.Testing) {
        if ($Config.Testing.CoverageThreshold) {
            $threshold = $Config.Testing.CoverageThreshold
            if ($threshold -lt 0 -or $threshold -gt 100) {
                $errors += "CoverageThreshold must be between 0 and 100"
            }
        }
    }
    
    return @{
        Valid = $errors.Count -eq 0
        Errors = $errors
        Warnings = $warnings
    }
}

function Merge-Configurations {
    param(
        [hashtable]$Existing,
        [hashtable]$New
    )
    
    $merged = $Existing.Clone()
    
    foreach ($key in $New.Keys) {
        if ($New[$key] -is [hashtable] -and $merged[$key] -is [hashtable]) {
            # Recursively merge hashtables
            $merged[$key] = Merge-Configurations -Existing $merged[$key] -New $New[$key]
        } else {
            # Overwrite with new value
            $merged[$key] = $New[$key]
        }
    }
    
    return $merged
}

function ConvertTo-PrettyPsd1 {
    param(
        [hashtable]$Data,
        [int]$Indent = 0
    )
    
    $spacing = '    ' * $indent
    $output = @()
    
    foreach ($key in $Data.Keys | Sort-Object) {
        $value = $Data[$key]
        
        if ($value -is [hashtable]) {
            $output += "$spacing$key = @{"
            $output += ConvertTo-PrettyPsd1 -Data $value -Indent ($indent + 1)
            $output += "$spacing}"
        }
        elseif ($value -is [array]) {
            if ($value.Count -eq 0) {
                $output += "$spacing$key = @()"
            } else {
                $output += "$spacing$key = @("
                foreach ($item in $value) {
                    if ($item -is [string]) {
                        $output += "$spacing    '$item'"
                    } else {
                        $output += "$spacing    $item"
                    }
                }
                $output += "$spacing)"
            }
        }
        elseif ($value -is [string]) {
            $output += "$spacing$key = '$value'"
        }
        elseif ($value -is [bool]) {
            $output += "$spacing$key = `$$value"
        }
        elseif ($null -eq $value) {
            $output += "$spacing$key = `$null"
        }
        else {
            $output += "$spacing$key = $value"
        }
    }
    
    return $output
}

# Main execution
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host " AitherZero Configuration Manager" -ForegroundColor White
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Blue

# Load custom configuration
Write-ConfigLog "Loading custom configuration..."

$customConfig = $null
try {
    if ($ConfigUrl) {
        Write-ConfigLog "Downloading configuration from: $ConfigUrl"
        
        # Download to temp file
        $tempFile = [System.IO.Path]::GetTempFileName()
        $tempFile = [System.IO.Path]::ChangeExtension($tempFile, '.psd1')
        
        Invoke-WebRequest -Uri $ConfigUrl -OutFile $tempFile -UseBasicParsing
        $customConfig = Import-PowerShellDataFile $tempFile
        
        # Clean up temp file
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        
        Write-ConfigLog "Configuration downloaded successfully" -Level 'Success'
    }
    elseif ($ConfigPath) {
        Write-ConfigLog "Loading configuration from: $ConfigPath"
        $customConfig = Import-PowerShellDataFile $ConfigPath
        Write-ConfigLog "Configuration loaded successfully" -Level 'Success'
    }
} catch {
    Write-ConfigLog "Failed to load configuration: $_" -Level 'Error'
    exit 1
}

# Validate configuration
Write-ConfigLog "Validating configuration..."
$validation = Test-ConfigurationValid -Config $customConfig

if ($validation.Warnings.Count -gt 0) {
    foreach ($warning in $validation.Warnings) {
        Write-ConfigLog "Warning: $warning" -Level 'Warning'
    }
}

if (-not $validation.Valid) {
    Write-ConfigLog "Configuration validation failed:" -Level 'Error'
    foreach ($error in $validation.Errors) {
        Write-ConfigLog "  - $error" -Level 'Error'
    }
    exit 1
}

Write-ConfigLog "Configuration validation passed" -Level 'Success'

# If validate only, stop here
if ($ValidateOnly) {
    Write-Host "`n✅ Configuration is valid!" -ForegroundColor Green
    exit 0
}

# Determine target config file
$targetConfig = if (Test-Path $script:LocalConfigPath) {
    $script:LocalConfigPath
} else {
    $script:LocalConfigPath  # Will create if doesn't exist
}

# Backup existing config if requested
if ($Backup -and (Test-Path $targetConfig)) {
    $backupPath = "$targetConfig.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
    
    if ($PSCmdlet.ShouldProcess($targetConfig, "Create backup at $backupPath")) {
        Copy-Item $targetConfig $backupPath
        Write-ConfigLog "Created backup: $backupPath" -Level 'Success'
    }
}

# Apply configuration
$finalConfig = $customConfig

if ($Merge -and (Test-Path $targetConfig)) {
    Write-ConfigLog "Merging with existing configuration..."
    
    try {
        $existingConfig = Import-PowerShellDataFile $targetConfig
        $finalConfig = Merge-Configurations -Existing $existingConfig -New $customConfig
        Write-ConfigLog "Configuration merged successfully" -Level 'Success'
    } catch {
        Write-ConfigLog "Failed to merge configurations: $_" -Level 'Warning'
        Write-ConfigLog "Will replace instead of merge" -Level 'Warning'
    }
}

# Write configuration
if ($PSCmdlet.ShouldProcess($targetConfig, "Apply custom configuration")) {
    try {
        # Generate PSD1 content
        $psd1Content = @"
#Requires -Version 7.0
<#
.SYNOPSIS
    AitherZero Local Configuration Override
.DESCRIPTION
    This file contains local configuration overrides for AitherZero.
    It was generated by Apply-CustomConfig.ps1 on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    
    Configuration precedence (highest to lowest):
    1. Command-line parameters
    2. Environment variables (AITHERZERO_*)
    3. This file (config.local.psd1)
    4. Main configuration (config.psd1)
.NOTES
    To revert to defaults, delete or rename this file.
#>

@{
$(ConvertTo-PrettyPsd1 -Data $finalConfig -Indent 1 | Out-String)
}
"@
        
        Set-Content -Path $targetConfig -Value $psd1Content -Encoding UTF8
        Write-ConfigLog "Configuration applied successfully to: $targetConfig" -Level 'Success'
        
        # Display summary of changes
        Write-Host "`nConfiguration Summary:" -ForegroundColor Cyan
        
        if ($finalConfig.Core) {
            Write-Host "  Core Settings:" -ForegroundColor White
            if ($finalConfig.Core.Profile) {
                Write-Host "    Profile: $($finalConfig.Core.Profile)" -ForegroundColor Gray
            }
            if ($finalConfig.Core.Environment) {
                Write-Host "    Environment: $($finalConfig.Core.Environment)" -ForegroundColor Gray
            }
        }
        
        if ($finalConfig.Automation) {
            Write-Host "  Automation Settings:" -ForegroundColor White
            if ($finalConfig.Automation.NonInteractive) {
                Write-Host "    NonInteractive: $($finalConfig.Automation.NonInteractive)" -ForegroundColor Gray
            }
            if ($finalConfig.Automation.MaxConcurrency) {
                Write-Host "    MaxConcurrency: $($finalConfig.Automation.MaxConcurrency)" -ForegroundColor Gray
            }
        }
        
        Write-Host "`n✅ Custom configuration applied successfully!" -ForegroundColor Green
        Write-Host "   Configuration will be used on next AitherZero startup." -ForegroundColor Gray
        
    } catch {
        Write-ConfigLog "Failed to write configuration: $_" -Level 'Error'
        exit 1
    }
}

# Test configuration loading
if (Get-Command Get-Configuration -ErrorAction SilentlyContinue) {
    Write-ConfigLog "Testing configuration loading..."
    
    try {
        $testConfig = Get-Configuration
        if ($testConfig) {
            Write-ConfigLog "Configuration loads successfully" -Level 'Success'
        }
    } catch {
        Write-ConfigLog "Warning: Failed to test configuration loading: $_" -Level 'Warning'
    }
}