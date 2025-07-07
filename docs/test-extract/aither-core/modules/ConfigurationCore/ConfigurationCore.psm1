# AitherZero ConfigurationCore Module
# Unified configuration management for the entire platform

#Requires -Version 7.0

using namespace System.IO
using namespace System.Security
using namespace System.Text.Json

# Module-level constants
$script:MODULE_VERSION = '1.0.0'
$script:CONFIG_FILE_VERSION = '1.0'
$script:MAX_BACKUP_COUNT = 10
$script:CONFIG_FILE_PERMISSIONS = if ($IsWindows) { 'Owner' } else { '600' }

# Enhanced configuration store with metadata and security
$script:ConfigurationStore = @{
    Metadata = @{
        Version = $script:CONFIG_FILE_VERSION
        LastModified = Get-Date
        CreatedBy = $env:USERNAME
        Platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } else { 'macOS' }
        PSVersion = $PSVersionTable.PSVersion.ToString()
    }
    Modules = @{}
    Environments = @{
        'default' = @{
            Name = 'default'
            Description = 'Default configuration environment'
            Settings = @{}
            Created = Get-Date
            CreatedBy = $env:USERNAME
        }
    }
    CurrentEnvironment = 'default'
    Schemas = @{}
    HotReload = @{
        Enabled = $false
        Watchers = @{}
        LastReload = $null
    }
    Security = @{
        EncryptionEnabled = $false
        HashValidation = $true
        LastSecurityCheck = Get-Date
    }
    StorePath = $null
}

# Security and validation functions
function Test-ConfigurationSecurity {
    param([hashtable]$Configuration)
    
    $securityIssues = @()
    
    # Check for potentially sensitive data in plain text
    $sensitivePatterns = @(
        '(?i)(password|pwd|secret|key|token|credential)',
        '(?i)(api[_-]?key|access[_-]?token)',
        '(?i)(connection[_-]?string)',
        '(?i)(private[_-]?key|certificate)'
    )
    
    function Test-HashtableForSensitiveData {
        param([hashtable]$Data, [string]$Path = '')
        
        foreach ($key in $Data.Keys) {
            $currentPath = if ($Path) { "$Path.$key" } else { $key }
            $value = $Data[$key]
            
            if ($value -is [hashtable]) {
                Test-HashtableForSensitiveData -Data $value -Path $currentPath
            } elseif ($value -is [string]) {
                foreach ($pattern in $sensitivePatterns) {
                    if ($key -match $pattern -or $value -match $pattern) {
                        $script:securityIssues += "Potentially sensitive data found at: $currentPath"
                    }
                }
            }
        }
    }
    
    Test-HashtableForSensitiveData -Data $Configuration
    return $securityIssues
}

function Get-ConfigurationHash {
    param([hashtable]$Configuration)
    
    try {
        $json = $Configuration | ConvertTo-Json -Depth 20 -Compress
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        $hashAlgorithm = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $hashAlgorithm.ComputeHash($bytes)
        return [System.Convert]::ToBase64String($hashBytes)
    } catch {
        Write-Warning "Failed to compute configuration hash: $_"
        return $null
    } finally {
        if ($hashAlgorithm) {
            $hashAlgorithm.Dispose()
        }
    }
}

# Simplified and reliable function import
function Import-ConfigurationFunctions {
    try {
        # Get function files
        $publicFunctions = @(Get-ChildItem -Path "$PSScriptRoot/Public" -Filter '*.ps1' -ErrorAction SilentlyContinue)
        $privateFunctions = @(Get-ChildItem -Path "$PSScriptRoot/Private" -Filter '*.ps1' -ErrorAction SilentlyContinue)
        
        Write-Verbose "ConfigurationCore: Loading $($privateFunctions.Count) private and $($publicFunctions.Count) public functions"
        
        # Import private functions first
        foreach ($functionFile in $privateFunctions) {
            try {
                . $functionFile.FullName
            } catch {
                Write-Warning "ConfigurationCore: Failed to load private function $($functionFile.Name): $_"
            }
        }
        
        # Import public functions and collect for export
        $functionsToExport = @()
        foreach ($functionFile in $publicFunctions) {
            try {
                . $functionFile.FullName
                $functionName = [System.IO.Path]::GetFileNameWithoutExtension($functionFile.Name)
                if (Get-Command $functionName -ErrorAction SilentlyContinue) {
                    $functionsToExport += $functionName
                }
            } catch {
                Write-Warning "ConfigurationCore: Failed to load public function $($functionFile.Name): $_"
            }
        }
        
        # Export successfully loaded functions
        if ($functionsToExport.Count -gt 0) {
            Export-ModuleMember -Function $functionsToExport
            Write-Verbose "ConfigurationCore: Successfully exported $($functionsToExport.Count) functions"
        } else {
            Write-Warning "ConfigurationCore: No functions available for export"
        }
        
    } catch {
        Write-Error "ConfigurationCore: Critical error during function import: $_"
        throw
    }
}

# Initialize configuration store with enhanced security and error handling
function Initialize-ConfigurationStorePath {
    try {
        # Platform-specific configuration paths with security considerations
        if ($IsWindows) {
            $configDir = Join-Path $env:APPDATA 'AitherZero'
        } elseif ($IsLinux -or $IsMacOS) {
            $configDir = Join-Path $env:HOME '.aitherzero'
        } else {
            throw "Unsupported platform for configuration storage"
        }
        
        $script:ConfigurationStore.StorePath = Join-Path $configDir 'configuration.json'
        
        # Create directory with appropriate permissions
        if (-not (Test-Path $configDir)) {
            $directory = New-Item -ItemType Directory -Path $configDir -Force
            
            # Set directory permissions (Unix-like systems)
            if ($IsLinux -or $IsMacOS) {
                chmod 700 $configDir 2>/dev/null
            }
        }
        
        # Set up backup directory
        $backupDir = Join-Path $configDir 'backups'
        if (-not (Test-Path $backupDir)) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            
            if ($IsLinux -or $IsMacOS) {
                chmod 700 $backupDir 2>/dev/null
            }
        }
        
        Write-Verbose "ConfigurationCore: Storage path initialized at $($script:ConfigurationStore.StorePath)"
        
    } catch {
        Write-Error "ConfigurationCore: Failed to initialize storage path: $_"
        throw
    }
}

# Load existing configuration with validation and migration support
function Import-ExistingConfiguration {
    $configPath = $script:ConfigurationStore.StorePath
    
    if (-not (Test-Path $configPath)) {
        Write-Verbose "ConfigurationCore: No existing configuration found"
        return
    }
    
    try {
        # Read configuration file
        $configContent = Get-Content $configPath -Raw -Encoding UTF8
        
        if ([string]::IsNullOrWhiteSpace($configContent)) {
            Write-Warning "ConfigurationCore: Configuration file is empty"
            return
        }
        
        # Parse JSON with enhanced error handling
        try {
            $storedConfig = $configContent | ConvertFrom-Json -AsHashtable -Depth 20
        } catch [System.Text.Json.JsonException] {
            Write-Warning "ConfigurationCore: Invalid JSON in configuration file, creating backup and starting fresh"
            $backupPath = "$configPath.corrupt.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $configPath $backupPath
            return
        }
        
        if (-not $storedConfig -or $storedConfig.Count -eq 0) {
            Write-Warning "ConfigurationCore: Configuration file contains no data"
            return
        }
        
        # Validate configuration structure
        $requiredKeys = @('Modules', 'Environments', 'CurrentEnvironment')
        foreach ($key in $requiredKeys) {
            if (-not $storedConfig.ContainsKey($key)) {
                Write-Warning "ConfigurationCore: Missing required key '$key', migrating configuration"
                $storedConfig[$key] = $script:ConfigurationStore[$key]
            }
        }
        
        # Ensure default environment exists
        if (-not $storedConfig.Environments.ContainsKey('default')) {
            $storedConfig.Environments['default'] = $script:ConfigurationStore.Environments['default']
        }
        
        # Validate current environment
        if (-not $storedConfig.Environments.ContainsKey($storedConfig.CurrentEnvironment)) {
            Write-Warning "ConfigurationCore: Invalid current environment, resetting to default"
            $storedConfig.CurrentEnvironment = 'default'
        }
        
        # Update metadata
        if (-not $storedConfig.Metadata) {
            $storedConfig.Metadata = $script:ConfigurationStore.Metadata
        }
        $storedConfig.Metadata.LastModified = Get-Date
        
        # Security validation
        $securityIssues = Test-ConfigurationSecurity -Configuration $storedConfig
        if ($securityIssues.Count -gt 0) {
            Write-Warning "ConfigurationCore: Security issues detected in configuration:"
            foreach ($issue in $securityIssues) {
                Write-Warning "  - $issue"
            }
        }
        
        # Apply loaded configuration
        $script:ConfigurationStore = $storedConfig
        $script:ConfigurationStore.StorePath = $configPath
        
        Write-Verbose "ConfigurationCore: Successfully loaded existing configuration"
        
        # Validate hash if available
        if ($storedConfig.Security -and $storedConfig.Security.HashValidation) {
            $currentHash = Get-ConfigurationHash -Configuration $storedConfig
            if ($currentHash) {
                $script:ConfigurationStore.Security.LastHash = $currentHash
            }
        }
        
    } catch {
        Write-Warning "ConfigurationCore: Failed to load existing configuration: $_"
        Write-Warning "ConfigurationCore: Starting with default configuration"
        
        # Create backup of problematic file
        if (Test-Path $configPath) {
            $backupPath = "$configPath.error.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            try {
                Copy-Item $configPath $backupPath
                Write-Verbose "ConfigurationCore: Problematic configuration backed up to $backupPath"
            } catch {
                Write-Warning "ConfigurationCore: Failed to backup problematic configuration: $_"
            }
        }
    }
}

# Clean up old backup files
function Invoke-BackupCleanup {
    try {
        $configDir = Split-Path $script:ConfigurationStore.StorePath -Parent
        $backupDir = Join-Path $configDir 'backups'
        
        if (Test-Path $backupDir) {
            $backupFiles = Get-ChildItem $backupDir -Filter 'config-backup-*.json' | 
                           Sort-Object LastWriteTime -Descending
            
            if ($backupFiles.Count -gt $script:MAX_BACKUP_COUNT) {
                $filesToRemove = $backupFiles | Select-Object -Skip $script:MAX_BACKUP_COUNT
                foreach ($file in $filesToRemove) {
                    try {
                        Remove-Item $file.FullName -Force
                        Write-Verbose "ConfigurationCore: Removed old backup $($file.Name)"
                    } catch {
                        Write-Warning "ConfigurationCore: Failed to remove old backup $($file.Name): $_"
                    }
                }
            }
        }
    } catch {
        Write-Warning "ConfigurationCore: Backup cleanup failed: $_"
    }
}

# Fallback logging function if Write-CustomLog is not available
if (-not (Get-Command 'Write-CustomLog' -ErrorAction SilentlyContinue)) {
    function Write-CustomLog {
        param(
            [string]$Level = 'INFO',
            [string]$Message
        )
        
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $color = switch ($Level) {
            'ERROR' { 'Red' }
            'WARNING' { 'Yellow' }
            'SUCCESS' { 'Green' }
            'DEBUG' { 'Gray' }
            default { 'White' }
        }
        
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    }
}

# Direct function import (most reliable approach)
Write-Verbose "ConfigurationCore: Loading functions directly"

# Get function files
$PublicFunctions = @(Get-ChildItem -Path "$PSScriptRoot/Public" -Filter '*.ps1' -ErrorAction SilentlyContinue)
$PrivateFunctions = @(Get-ChildItem -Path "$PSScriptRoot/Private" -Filter '*.ps1' -ErrorAction SilentlyContinue)

Write-Verbose "ConfigurationCore: Found $($PrivateFunctions.Count) private and $($PublicFunctions.Count) public functions"

# Import private functions
foreach ($FunctionFile in $PrivateFunctions) {
    try {
        . $FunctionFile.FullName
    } catch {
        Write-Warning "Failed to load private function $($FunctionFile.Name): $_"
    }
}

# Import public functions and prepare for export
$FunctionsToExport = @()
foreach ($FunctionFile in $PublicFunctions) {
    try {
        . $FunctionFile.FullName
        $FunctionName = [System.IO.Path]::GetFileNameWithoutExtension($FunctionFile.Name)
        if (Get-Command $FunctionName -ErrorAction SilentlyContinue) {
            $FunctionsToExport += $FunctionName
        }
    } catch {
        Write-Warning "Failed to load public function $($FunctionFile.Name): $_"
    }
}

# Export functions
if ($FunctionsToExport.Count -gt 0) {
    Export-ModuleMember -Function $FunctionsToExport
    Write-Verbose "ConfigurationCore: Exported $($FunctionsToExport.Count) functions"
} else {
    Write-Warning "ConfigurationCore: No functions available for export"
}

# Basic initialization
try {
    # Set storage path
    if ($IsWindows) {
        $configDir = Join-Path $env:APPDATA 'AitherZero'
    } else {
        $configDir = Join-Path $env:HOME '.aitherzero'
    }
    $script:ConfigurationStore.StorePath = Join-Path $configDir 'configuration.json'
    
    Write-Verbose "ConfigurationCore: Module initialization completed"
} catch {
    Write-Warning "ConfigurationCore: Non-critical initialization error: $_"
}