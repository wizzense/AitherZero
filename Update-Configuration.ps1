#Requires -Version 7.0
<#
.SYNOPSIS
    Update and maintain AitherZero configuration automatically
.DESCRIPTION
    Manages configuration updates including:
    - Version tracking and automatic updates
    - Environment-specific settings
    - Backup and restore functionality
    - Validation and migration support
.PARAMETER UpdateConfig
    Update configuration to latest version
.PARAMETER BackupConfig
    Create backup of current configuration
.PARAMETER RestoreConfig
    Restore configuration from backup
.PARAMETER ValidateOnly
    Only validate current configuration
.EXAMPLE
    .\Update-Configuration.ps1 -UpdateConfig
.EXAMPLE
    .\Update-Configuration.ps1 -BackupConfig
#>

[CmdletBinding()]
param(
    [switch]$UpdateConfig,
    [switch]$BackupConfig,
    [string]$RestoreConfig,
    [switch]$ValidateOnly,
    [string]$ConfigPath = "./config.psd1"
)

function Get-ConfigurationVersion {
    [CmdletBinding()]
    param([string]$Path)
    
    try {
        $config = Import-PowerShellDataFile $Path -ErrorAction Stop
        return $config.Core.ConfigVersion ?? '1.0.0'
    } catch {
        return '1.0.0'
    }
}

function Backup-Configuration {
    [CmdletBinding()]
    param([string]$ConfigPath)
    
    if (-not (Test-Path $ConfigPath)) {
        Write-Error "Configuration file not found: $ConfigPath"
        return $false
    }
    
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupPath = "./config.backup.$timestamp.psd1"
    
    try {
        Copy-Item $ConfigPath $backupPath
        Write-Host "Configuration backed up to: $backupPath" -ForegroundColor Green
        return $backupPath
    } catch {
        Write-Error "Failed to backup configuration: $($_.Exception.Message)"
        return $false
    }
}

function Update-ConfigurationFile {
    [CmdletBinding()]
    param(
        [string]$ConfigPath,
        [string]$BackupPath
    )
    
    try {
        $config = Import-PowerShellDataFile $ConfigPath -ErrorAction Stop
        $updated = $false
        
        # Update version tracking
        if (-not $config.Core.ConfigVersion -or $config.Core.ConfigVersion -lt '1.0.0') {
            $config.Core.ConfigVersion = '1.0.0'
            $updated = $true
        }
        
        # Update timestamp
        $config.Core.LastUpdated = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')
        $updated = $true
        
        # Add auto-update settings if missing
        if (-not $config.Core.ContainsKey('AutoUpdateConfig')) {
            $config.Core.AutoUpdateConfig = $true
            $updated = $true
        }
        
        # Ensure proper orchestration defaults
        if (-not $config.Orchestration) {
            $config.Orchestration = @{
                MaxRetries = 3
                EnableRollback = $false
                ExecutionHistory = $true
                CheckpointInterval = 10
                DefaultMode = 'Parallel'
                ValidateBeforeRun = $true
                CacheExecutionPlans = $true
                RetryDelay = 5
                HistoryRetentionDays = 30
            }
            $updated = $true
        }
        
        # Ensure UI settings exist
        if (-not $config.UI) {
            $config.UI = @{
                ShowHints = $true
                MenuStyle = 'Interactive'
                ClearScreenOnStart = $true
                EnableColors = $true
                ProgressBarStyle = 'Classic'
                ShowWelcomeMessage = $true
            }
            $updated = $true
        }
        
        if ($updated) {
            # Convert hashtable back to PSD1 format
            $content = ConvertTo-PowerShellDataFile $config
            Set-Content $ConfigPath $content -Encoding UTF8
            
            Write-Host "Configuration updated successfully" -ForegroundColor Green
            Write-Host "Backup available at: $BackupPath" -ForegroundColor Cyan
        } else {
            Write-Host "Configuration is already up to date" -ForegroundColor Yellow
        }
        
        return $true
    } catch {
        Write-Error "Failed to update configuration: $($_.Exception.Message)"
        
        # Restore backup if update failed
        if ($BackupPath -and (Test-Path $BackupPath)) {
            Copy-Item $BackupPath $ConfigPath -Force
            Write-Host "Configuration restored from backup" -ForegroundColor Yellow
        }
        
        return $false
    }
}

function ConvertTo-PowerShellDataFile {
    [CmdletBinding()]
    param([hashtable]$InputObject, [int]$Depth = 0)
    
    $indent = "    " * $Depth
    $result = @()
    
    if ($Depth -eq 0) {
        $result += "#Requires -Version 7.0"
        $result += ""
        $result += "<#"
        $result += ".SYNOPSIS"
        $result += "    AitherZero Configuration File"
        $result += ".DESCRIPTION"
        $result += "    Main configuration for the AitherZero infrastructure automation platform."
        $result += "    Auto-updated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $result += "#>"
        $result += ""
        $result += "# AitherZero Configuration"
    }
    
    $result += "$indent@{"
    
    foreach ($key in $InputObject.Keys | Sort-Object) {
        $value = $InputObject[$key]
        
        if ($value -is [hashtable]) {
            $result += "$indent    $key = $(ConvertTo-PowerShellDataFile $value ($Depth + 1))"
        } elseif ($value -is [array]) {
            $arrayItems = $value | ForEach-Object {
                if ($_ -is [string]) { "'$_'" } else { $_.ToString() }
            }
            $result += "$indent    $key = @($($arrayItems -join ', '))"
        } elseif ($value -is [string]) {
            $result += "$indent    $key = '$value'"
        } elseif ($value -is [bool]) {
            $result += "$indent    $key = `$$($value.ToString().ToLower())"
        } else {
            $result += "$indent    $key = $value"
        }
    }
    
    $result += "$indent}"
    
    return $result -join "`n"
}

function Test-Configuration {
    [CmdletBinding()]
    param([string]$ConfigPath)
    
    Write-Host "Validating configuration..." -ForegroundColor Cyan
    
    try {
        $config = Import-PowerShellDataFile $ConfigPath -ErrorAction Stop
        Write-Host "✅ Configuration file syntax is valid" -ForegroundColor Green
        
        # Check required sections
        $requiredSections = @('Core', 'InstallationOptions')
        foreach ($section in $requiredSections) {
            if ($config.ContainsKey($section)) {
                Write-Host "✅ Section '$section' found" -ForegroundColor Green
            } else {
                Write-Host "❌ Required section '$section' missing" -ForegroundColor Red
                return $false
            }
        }
        
        # Check version
        $version = $config.Core.ConfigVersion
        if ($version) {
            Write-Host "✅ Configuration version: $version" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Configuration version not set" -ForegroundColor Yellow
        }
        
        Write-Host "Configuration validation completed" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "❌ Configuration validation failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main execution
switch ($true) {
    $ValidateOnly {
        $result = Test-Configuration $ConfigPath
        exit ($result ? 0 : 1)
    }
    
    $BackupConfig {
        $backup = Backup-Configuration $ConfigPath
        if ($backup) {
            Write-Host "Backup completed: $backup" -ForegroundColor Green
            exit 0
        } else {
            exit 1
        }
    }
    
    $RestoreConfig {
        if (-not (Test-Path $RestoreConfig)) {
            Write-Error "Backup file not found: $RestoreConfig"
            exit 1
        }
        
        try {
            Copy-Item $RestoreConfig $ConfigPath -Force
            Write-Host "Configuration restored from: $RestoreConfig" -ForegroundColor Green
            Test-Configuration $ConfigPath | Out-Null
            exit 0
        } catch {
            Write-Error "Failed to restore configuration: $($_.Exception.Message)"
            exit 1
        }
    }
    
    $UpdateConfig {
        $backup = Backup-Configuration $ConfigPath
        if ($backup) {
            $result = Update-ConfigurationFile $ConfigPath $backup
            exit ($result ? 0 : 1)
        } else {
            exit 1
        }
    }
    
    default {
        Write-Host "Use -UpdateConfig, -BackupConfig, -RestoreConfig, or -ValidateOnly" -ForegroundColor Yellow
        Get-Help $MyInvocation.MyCommand.Path -Examples
        exit 0
    }
}