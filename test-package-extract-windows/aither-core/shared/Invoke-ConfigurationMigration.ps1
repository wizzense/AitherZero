#Requires -Version 7.0

<#
.SYNOPSIS
    Migration system for legacy AitherZero configurations
.DESCRIPTION
    Detects and migrates legacy configuration files to the new consolidated format
.PARAMETER ProjectRoot
    Project root directory
.PARAMETER BackupLegacy
    Whether to backup legacy configurations before migration
.PARAMETER DryRun
    Perform a dry run without making changes
.EXAMPLE
    Invoke-ConfigurationMigration
.EXAMPLE
    Invoke-ConfigurationMigration -DryRun
#>

function Invoke-ConfigurationMigration {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ProjectRoot,

        [Parameter()]
        [switch]$BackupLegacy = $true,

        [Parameter()]
        [switch]$DryRun
    )

    # Find project root if not provided
    if (-not $ProjectRoot) {
        $ProjectRoot = Find-ProjectRoot -StartPath $PSScriptRoot
    }

    Write-Host "🔄 Starting Configuration Migration for AitherZero v0.8.0" -ForegroundColor Cyan
    Write-Host "Project Root: $ProjectRoot" -ForegroundColor Gray

    if ($DryRun) {
        Write-Host "🔍 DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
    }

    try {
        # Detect legacy configurations
        $legacyConfigs = Find-LegacyConfigurations -ProjectRoot $ProjectRoot

        if ($legacyConfigs.Count -eq 0) {
            Write-Host "✅ No legacy configurations found - system is already consolidated" -ForegroundColor Green
            return @{ Success = $true; MigratedConfigs = @(); Message = "No migration needed" }
        }

        Write-Host "📋 Found $($legacyConfigs.Count) legacy configuration(s):" -ForegroundColor Yellow
        foreach ($config in $legacyConfigs) {
            Write-Host "  • $($config.Type): $($config.Path)" -ForegroundColor White
        }

        # Backup legacy configurations if requested
        if ($BackupLegacy -and -not $DryRun) {
            $backupResult = Backup-LegacyConfigurations -LegacyConfigs $legacyConfigs -ProjectRoot $ProjectRoot
            Write-Host "💾 Legacy configurations backed up to: $($backupResult.BackupPath)" -ForegroundColor Green
        }

        # Migrate configurations
        $migrationResults = @()
        foreach ($legacyConfig in $legacyConfigs) {
            $result = Migrate-LegacyConfiguration -LegacyConfig $legacyConfig -ProjectRoot $ProjectRoot -DryRun:$DryRun
            $migrationResults += $result

            if ($result.Success) {
                Write-Host "✅ Migrated: $($legacyConfig.Type) -> $($result.NewPath)" -ForegroundColor Green
            } else {
                Write-Host "❌ Failed to migrate: $($legacyConfig.Type) - $($result.Error)" -ForegroundColor Red
            }
        }

        # Create consolidated configuration
        if (-not $DryRun) {
            $consolidationResult = Create-ConsolidatedConfiguration -ProjectRoot $ProjectRoot -MigrationResults $migrationResults

            if ($consolidationResult.Success) {
                Write-Host "🎯 Consolidated configuration created at: $($consolidationResult.ConfigPath)" -ForegroundColor Green
            } else {
                Write-Host "⚠️ Warning: Failed to create consolidated configuration - $($consolidationResult.Error)" -ForegroundColor Yellow
            }
        }

        # Generate migration report
        $report = Generate-MigrationReport -LegacyConfigs $legacyConfigs -MigrationResults $migrationResults -ProjectRoot $ProjectRoot

        if (-not $DryRun) {
            $reportPath = Join-Path $ProjectRoot "configs" "migration-report-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').json"
            $report | ConvertTo-Json -Depth 10 | Set-Content $reportPath
            Write-Host "📊 Migration report saved to: $reportPath" -ForegroundColor Cyan
        }

        Write-Host "🏁 Configuration migration completed successfully!" -ForegroundColor Green

        return @{
            Success = $true
            MigratedConfigs = $migrationResults
            Report = $report
            Message = "Migration completed successfully"
        }

    } catch {
        Write-Host "💥 Configuration migration failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Error = $_.Exception.Message
            Message = "Migration failed"
        }
    }
}

function Find-LegacyConfigurations {
    [CmdletBinding()]
    param(
        [string]$ProjectRoot
    )

    $legacyConfigs = @()

    # Legacy core configuration
    $legacyCoreConfig = Join-Path $ProjectRoot "aither-core" "default-config.json"
    if (Test-Path $legacyCoreConfig) {
        $legacyConfigs += @{
            Type = "Legacy Core Config"
            Path = $legacyCoreConfig
            Priority = 1
        }
    }

    # Legacy core configs subdirectory
    $legacyCoreConfigsDir = Join-Path $ProjectRoot "aither-core" "configs" "default-config.json"
    if (Test-Path $legacyCoreConfigsDir) {
        $legacyConfigs += @{
            Type = "Legacy Core Configs Dir"
            Path = $legacyCoreConfigsDir
            Priority = 2
        }
    }

    # Check for inconsistent main config (needs normalization)
    $mainConfig = Join-Path $ProjectRoot "configs" "default-config.json"
    if (Test-Path $mainConfig) {
        $content = Get-Content $mainConfig -Raw | ConvertFrom-Json

        # Check if it needs migration (has flat structure or missing sections)
        $needsMigration = $false

        # Check for flat structure indicators
        if ($content.PSObject.Properties.Name -contains "ComputerName" -and
            -not ($content.PSObject.Properties.Name -contains "system")) {
            $needsMigration = $true
        }

        if ($needsMigration) {
            $legacyConfigs += @{
                Type = "Main Config (Needs Structure Update)"
                Path = $mainConfig
                Priority = 0
            }
        }
    }

    return $legacyConfigs | Sort-Object Priority
}

function Backup-LegacyConfigurations {
    [CmdletBinding()]
    param(
        [array]$LegacyConfigs,
        [string]$ProjectRoot
    )

    $backupDir = Join-Path $ProjectRoot "configs" "legacy" "backup-$(Get-Date -Format 'yyyy-MM-dd-HHmmss')"
    New-Item -Path $backupDir -ItemType Directory -Force | Out-Null

    foreach ($config in $LegacyConfigs) {
        $fileName = Split-Path $config.Path -Leaf
        $backupPath = Join-Path $backupDir "$($config.Type.Replace(' ', '-'))-$fileName"
        Copy-Item $config.Path $backupPath -Force
    }

    return @{ BackupPath = $backupDir }
}

function Migrate-LegacyConfiguration {
    [CmdletBinding()]
    param(
        [hashtable]$LegacyConfig,
        [string]$ProjectRoot,
        [switch]$DryRun
    )

    try {
        # Load legacy configuration
        $content = Get-Content $LegacyConfig.Path -Raw | ConvertFrom-Json

        # Convert to standardized structure
        $migratedConfig = Convert-LegacyToStandardized -LegacyContent $content -LegacyType $LegacyConfig.Type

        # Determine target path
        $targetPath = Get-MigrationTargetPath -LegacyConfig $LegacyConfig -ProjectRoot $ProjectRoot

        if (-not $DryRun) {
            # Ensure target directory exists
            $targetDir = Split-Path $targetPath -Parent
            if (-not (Test-Path $targetDir)) {
                New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
            }

            # Save migrated configuration
            $migratedConfig | ConvertTo-Json -Depth 10 | Set-Content $targetPath -Encoding UTF8
        }

        return @{
            Success = $true
            OriginalPath = $LegacyConfig.Path
            NewPath = $targetPath
            Type = $LegacyConfig.Type
        }

    } catch {
        return @{
            Success = $false
            OriginalPath = $LegacyConfig.Path
            Error = $_.Exception.Message
            Type = $LegacyConfig.Type
        }
    }
}

function Convert-LegacyToStandardized {
    [CmdletBinding()]
    param(
        [PSCustomObject]$LegacyContent,
        [string]$LegacyType
    )

    # Create standardized structure
    $standardized = @{
        metadata = @{
            version = "1.0"
            description = "Migrated from $LegacyType"
            migratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            originalType = $LegacyType
        }
        system = @{}
        tools = @{}
        aiTools = @{}
        ui = @{}
        versions = @{}
        infrastructure = @{}
        certificates = @{}
        hyperv = @{}
        directories = @{}
        logging = @{}
        scripts = @{}
        environment = @{}
        security = @{}
    }

    # Map legacy properties to new structure
    foreach ($property in $LegacyContent.PSObject.Properties) {
        $name = $property.Name
        $value = $property.Value

        switch ($name) {
            # System settings
            { $_ -in @('ComputerName', 'SetComputerName', 'DNSServers', 'SetDNSServers', 'TrustedHosts', 'SetTrustedHosts', 'DisableTCPIP6', 'AllowRemoteDesktop', 'ConfigureFirewall', 'FirewallPorts', 'ConfigPXE') } {
                $standardized.system[$name] = $value
            }

            # Tools
            { $_ -match '^Install[A-Z]' } {
                $standardized.tools[$name] = $value
            }

            # AI Tools
            { $_ -match 'Claude|Gemini|Codex' } {
                $standardized.aiTools[$name] = $value
            }

            # UI Preferences
            { $_ -in @('UIPreferences') } {
                if ($value -is [PSCustomObject]) {
                    foreach ($uiProp in $value.PSObject.Properties) {
                        $standardized.ui[$uiProp.Name] = $uiProp.Value
                    }
                }
            }

            # Versions
            { $_ -match 'Version$' } {
                $standardized.versions[$name] = $value
            }

            # Infrastructure
            { $_ -in @('InitializeOpenTofu', 'PrepareHyperVHost', 'RepoUrl', 'LocalPath', 'ConfigFile', 'RunnerScriptName', 'InfraRepoUrl', 'InfraRepoPath') } {
                $standardized.infrastructure[$name] = $value
            }

            # Certificate Authority
            { $_ -eq 'CertificateAuthority' } {
                if ($value -is [PSCustomObject]) {
                    foreach ($certProp in $value.PSObject.Properties) {
                        $standardized.certificates[$certProp.Name] = $certProp.Value
                    }
                }
            }

            # Hyper-V settings
            { $_ -eq 'HyperV' } {
                if ($value -is [PSCustomObject]) {
                    foreach ($hvProp in $value.PSObject.Properties) {
                        $standardized.hyperv[$hvProp.Name] = $hvProp.Value
                    }
                }
            }

            # Directories
            { $_ -eq 'Directories' } {
                if ($value -is [PSCustomObject]) {
                    foreach ($dirProp in $value.PSObject.Properties) {
                        $standardized.directories[$dirProp.Name] = $dirProp.Value
                    }
                }
            }

            # Logging
            { $_ -in @('logging', 'LogLevel', 'LogPath') } {
                if ($name -eq 'logging' -and $value -is [PSCustomObject]) {
                    foreach ($logProp in $value.PSObject.Properties) {
                        $standardized.logging[$logProp.Name] = $logProp.Value
                    }
                } else {
                    $standardized.logging[$name] = $value
                }
            }

            # Scripts
            { $_ -eq 'scripts' } {
                if ($value -is [PSCustomObject]) {
                    foreach ($scriptProp in $value.PSObject.Properties) {
                        $standardized.scripts[$scriptProp.Name] = $scriptProp.Value
                    }
                }
            }

            # Environment
            { $_ -eq 'environment' } {
                if ($value -is [PSCustomObject]) {
                    foreach ($envProp in $value.PSObject.Properties) {
                        $standardized.environment[$envProp.Name] = $envProp.Value
                    }
                }
            }

            # Keep other properties as-is for compatibility
            default {
                # Check if it's a complex object that should be preserved
                if ($value -is [PSCustomObject] -or $value -is [hashtable] -or $value -is [array]) {
                    $standardized[$name] = $value
                } else {
                    # Simple properties go to system section as fallback
                    $standardized.system[$name] = $value
                }
            }
        }
    }

    # Remove empty sections
    $sectionsToRemove = @()
    foreach ($section in $standardized.Keys) {
        if ($section -ne 'metadata' -and $standardized[$section] -is [hashtable] -and $standardized[$section].Count -eq 0) {
            $sectionsToRemove += $section
        }
    }
    foreach ($section in $sectionsToRemove) {
        $standardized.Remove($section)
    }

    return $standardized
}

function Get-MigrationTargetPath {
    [CmdletBinding()]
    param(
        [hashtable]$LegacyConfig,
        [string]$ProjectRoot
    )

    switch ($LegacyConfig.Type) {
        "Main Config (Needs Structure Update)" {
            return Join-Path $ProjectRoot "configs" "default-config.json"
        }
        "Legacy Core Config" {
            return Join-Path $ProjectRoot "configs" "legacy" "core-config-migrated.json"
        }
        "Legacy Core Configs Dir" {
            return Join-Path $ProjectRoot "configs" "legacy" "core-configs-dir-migrated.json"
        }
        default {
            $fileName = Split-Path $LegacyConfig.Path -Leaf
            return Join-Path $ProjectRoot "configs" "legacy" "migrated-$fileName"
        }
    }
}

function Create-ConsolidatedConfiguration {
    [CmdletBinding()]
    param(
        [string]$ProjectRoot,
        [array]$MigrationResults
    )

    try {
        $consolidatedConfigPath = Join-Path $ProjectRoot "configs" "default-config.json"

        # If main config was migrated, it's already in place
        $mainConfigMigration = $MigrationResults | Where-Object { $_.Type -eq "Main Config (Needs Structure Update)" }

        if ($mainConfigMigration -and $mainConfigMigration.Success) {
            return @{
                Success = $true
                ConfigPath = $consolidatedConfigPath
                Message = "Main configuration updated in place"
            }
        }

        # If no main config exists, create a new one from the most complete legacy config
        if (-not (Test-Path $consolidatedConfigPath)) {
            $bestMigration = $MigrationResults | Where-Object { $_.Success } | Select-Object -First 1

            if ($bestMigration) {
                Copy-Item $bestMigration.NewPath $consolidatedConfigPath
                return @{
                    Success = $true
                    ConfigPath = $consolidatedConfigPath
                    Message = "Created new consolidated configuration from $($bestMigration.Type)"
                }
            }
        }

        return @{
            Success = $true
            ConfigPath = $consolidatedConfigPath
            Message = "Configuration already exists and is up to date"
        }

    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Generate-MigrationReport {
    [CmdletBinding()]
    param(
        [array]$LegacyConfigs,
        [array]$MigrationResults,
        [string]$ProjectRoot
    )

    return @{
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        projectRoot = $ProjectRoot
        legacyConfigsFound = $LegacyConfigs.Count
        migrationsAttempted = $MigrationResults.Count
        migrationsSuccessful = ($MigrationResults | Where-Object { $_.Success }).Count
        migrationsFailed = ($MigrationResults | Where-Object { -not $_.Success }).Count
        legacyConfigs = $LegacyConfigs
        migrationResults = $MigrationResults
        recommendations = @(
            "Review migrated configurations in configs/legacy/ directory",
            "Test the new consolidated configuration system",
            "Update any custom scripts to use the new configuration paths",
            "Consider removing legacy configuration files after validation"
        )
    }
}

function Find-ProjectRoot {
    [CmdletBinding()]
    param(
        [string]$StartPath = $PSScriptRoot
    )

    $currentPath = $StartPath
    $rootIndicators = @('.git', 'Start-AitherZero.ps1', 'aither-core')

    while ($currentPath) {
        foreach ($indicator in $rootIndicators) {
            $testPath = Join-Path $currentPath $indicator
            if (Test-Path $testPath) {
                return $currentPath
            }
        }

        $parentPath = Split-Path $currentPath -Parent
        if ($parentPath -eq $currentPath) {
            break
        }
        $currentPath = $parentPath
    }

    return $PWD.Path
}

# Export functions (remove for script usage)
# Export-ModuleMember -Function Invoke-ConfigurationMigration
