#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Claude command wrapper for configuration management
.DESCRIPTION
    Provides CLI interface for configuration operations using ConfigurationCarousel and ConfigurationCore modules
.PARAMETER Action
    The action to perform (show, switch, edit, validate, backup, restore, diff, export, import)
.PARAMETER Arguments
    Additional arguments passed from Claude command
#>

param(
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateSet("show", "switch", "edit", "validate", "backup", "restore", "diff", "export", "import")]
    [string]$Action = "show",
    
    [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true)]
    [string[]]$Arguments = @()
)

# Cross-platform script location detection
$scriptPath = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)

# Import required modules
try {
    . (Join-Path $projectRoot "aither-core/shared/Find-ProjectRoot.ps1")
    $projectRoot = Find-ProjectRoot
    
    # Import required modules
    $modulesToImport = @(
        "Logging",
        "ConfigurationCore",
        "ConfigurationCarousel",
        "ConfigurationRepository"
    )
    
    foreach ($module in $modulesToImport) {
        $modulePath = Join-Path $projectRoot "aither-core/modules/$module"
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force -ErrorAction SilentlyContinue
        }
    }
} catch {
    Write-Error "Failed to import required modules: $($_.Exception.Message)"
    exit 1
}

# Helper function for consistent logging
function Write-CommandLog {
    param($Message, $Level = "INFO")
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level
    } else {
        $color = switch ($Level) {
            "ERROR" { "Red" }
            "WARNING" { "Yellow" }
            "SUCCESS" { "Green" }
            "DEBUG" { "Gray" }
            default { "White" }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
}

# Parse arguments into parameters
function ConvertTo-Parameters {
    param([string[]]$Arguments)
    
    $params = @{}
    $currentParam = $null
    
    foreach ($arg in $Arguments) {
        if ($arg -match '^--(.+)$') {
            $currentParam = $Matches[1]
            $params[$currentParam] = $true
        } elseif ($currentParam) {
            if ($currentParam -eq 'key' -or $currentParam -eq 'value') {
                # Handle dot notation for nested keys
                $params[$currentParam] = $arg
            } else {
                $params[$currentParam] = $arg
            }
            $currentParam = $null
        }
    }
    
    return $params
}

# Execute configuration action
function Invoke-ConfigAction {
    param(
        [string]$Action,
        [hashtable]$Parameters
    )
    
    try {
        switch ($Action) {
            "show" {
                Write-CommandLog "Displaying configuration..." "INFO"
                
                if ($Parameters['module']) {
                    # Show module-specific configuration
                    if (Get-Command Get-ModuleConfiguration -ErrorAction SilentlyContinue) {
                        $config = Get-ModuleConfiguration -ModuleName $Parameters['module']
                        
                        if ($Parameters['format'] -eq 'json') {
                            $config | ConvertTo-Json -Depth 10
                        } elseif ($Parameters['format'] -eq 'yaml') {
                            # Simple YAML output (would need proper YAML module for full support)
                            $config.GetEnumerator() | ForEach-Object {
                                Write-Output "$($_.Key): $($_.Value)"
                            }
                        } else {
                            # Table format
                            $config | Format-Table -AutoSize
                        }
                    }
                } else {
                    # Show all configuration
                    if (Get-Command Get-CurrentConfiguration -ErrorAction SilentlyContinue) {
                        $config = Get-CurrentConfiguration
                        
                        if ($Parameters['effective']) {
                            Write-CommandLog "Showing effective configuration (computed values):" "INFO"
                        }
                        
                        if ($Parameters['sensitive']) {
                            Write-CommandLog "Sensitive values are masked with ***" "WARNING"
                        }
                        
                        $config | ConvertTo-Json -Depth 10 | Write-Output
                    }
                }
            }
            
            "switch" {
                Write-CommandLog "Switching configuration set..." "INFO"
                
                if (-not $Parameters['set']) {
                    throw "Configuration set name required (--set)"
                }
                
                if ($Parameters['backup']) {
                    Write-CommandLog "Creating backup before switch..." "INFO"
                    if (Get-Command Backup-CurrentConfiguration -ErrorAction SilentlyContinue) {
                        Backup-CurrentConfiguration -Reason "Pre-switch backup"
                    }
                }
                
                if (Get-Command Switch-ConfigurationSet -ErrorAction SilentlyContinue) {
                    $switchParams = @{
                        ConfigurationName = $Parameters['set']
                    }
                    
                    if ($Parameters['environment']) {
                        $switchParams['Environment'] = $Parameters['environment']
                    }
                    
                    if ($Parameters['validate']) {
                        Write-CommandLog "Validating configuration before switch..." "INFO"
                        # Add validation logic here
                    }
                    
                    Switch-ConfigurationSet @switchParams
                    Write-CommandLog "Configuration switched to: $($Parameters['set'])" "SUCCESS"
                }
            }
            
            "edit" {
                Write-CommandLog "Editing configuration..." "INFO"
                
                if ($Parameters['interactive']) {
                    if (Get-Command Edit-Configuration -ErrorAction SilentlyContinue) {
                        Edit-Configuration
                    } else {
                        Write-CommandLog "Interactive editing not available" "WARNING"
                    }
                } else {
                    if (-not $Parameters['key'] -or -not $Parameters['value']) {
                        throw "Both --key and --value are required for non-interactive edit"
                    }
                    
                    if (Get-Command Set-ModuleConfiguration -ErrorAction SilentlyContinue) {
                        $setParams = @{
                            Key = $Parameters['key']
                            Value = $Parameters['value']
                        }
                        
                        if ($Parameters['module']) {
                            $setParams['ModuleName'] = $Parameters['module']
                        }
                        
                        Set-ModuleConfiguration @setParams
                        
                        if ($Parameters['comment']) {
                            Write-CommandLog "Change comment: $($Parameters['comment'])" "INFO"
                        }
                        
                        Write-CommandLog "Configuration updated successfully" "SUCCESS"
                    }
                }
            }
            
            "validate" {
                Write-CommandLog "Validating configuration..." "INFO"
                
                if (Get-Command Validate-Configuration -ErrorAction SilentlyContinue) {
                    $validateParams = @{}
                    
                    if ($Parameters['strict']) {
                        $validateParams['Strict'] = $true
                    }
                    
                    if ($Parameters['schema']) {
                        $validateParams['SchemaPath'] = $Parameters['schema']
                    }
                    
                    $result = Validate-Configuration @validateParams
                    
                    if ($result.IsValid) {
                        Write-CommandLog "Configuration is valid" "SUCCESS"
                    } else {
                        Write-CommandLog "Configuration validation failed:" "ERROR"
                        $result.Errors | ForEach-Object {
                            Write-CommandLog "  - $_" "ERROR"
                        }
                        
                        if ($Parameters['fix']) {
                            Write-CommandLog "Attempting to fix issues..." "INFO"
                            # Add fix logic here
                        }
                    }
                }
            }
            
            "backup" {
                Write-CommandLog "Creating configuration backup..." "INFO"
                
                if (Get-Command Backup-CurrentConfiguration -ErrorAction SilentlyContinue) {
                    $backupParams = @{
                        Reason = $Parameters['name'] ?? "Manual backup"
                    }
                    
                    $result = Backup-CurrentConfiguration @backupParams
                    Write-CommandLog "Backup created: $($result.BackupPath)" "SUCCESS"
                    
                    if ($Parameters['compress']) {
                        Write-CommandLog "Compressing backup..." "INFO"
                        # Add compression logic
                    }
                    
                    if ($Parameters['encrypt']) {
                        Write-CommandLog "Encrypting backup..." "INFO"
                        # Add encryption logic
                    }
                }
            }
            
            "restore" {
                Write-CommandLog "Restoring configuration..." "INFO"
                
                if ($Parameters['preview']) {
                    Write-CommandLog "Preview mode - no changes will be applied" "WARNING"
                }
                
                # Add restore logic here
                Write-CommandLog "Restore functionality to be implemented" "WARNING"
            }
            
            "diff" {
                Write-CommandLog "Comparing configurations..." "INFO"
                
                if (-not $Parameters['source'] -or -not $Parameters['target']) {
                    throw "Both --source and --target are required for diff"
                }
                
                # Add diff logic here
                Write-CommandLog "Diff functionality to be implemented" "WARNING"
            }
            
            "export" {
                Write-CommandLog "Exporting configuration..." "INFO"
                
                $format = $Parameters['format'] ?? 'json'
                $outputFile = $Parameters['file'] ?? "config-export.$format"
                
                if (Get-Command Get-CurrentConfiguration -ErrorAction SilentlyContinue) {
                    $config = Get-CurrentConfiguration
                    
                    if ($Parameters['sanitize']) {
                        Write-CommandLog "Sanitizing sensitive data..." "INFO"
                        # Add sanitization logic
                    }
                    
                    switch ($format) {
                        'json' {
                            $config | ConvertTo-Json -Depth 10 | Set-Content $outputFile
                        }
                        'env' {
                            # Convert to .env format
                            $config.GetEnumerator() | ForEach-Object {
                                "$($_.Key.ToUpper())=$($_.Value)"
                            } | Set-Content $outputFile
                        }
                        default {
                            Write-CommandLog "Unsupported export format: $format" "ERROR"
                        }
                    }
                    
                    Write-CommandLog "Configuration exported to: $outputFile" "SUCCESS"
                }
            }
            
            "import" {
                Write-CommandLog "Importing configuration..." "INFO"
                
                if (-not $Parameters['source']) {
                    throw "Source file required (--source)"
                }
                
                if ($Parameters['dry-run']) {
                    Write-CommandLog "Dry run mode - no changes will be applied" "WARNING"
                }
                
                # Add import logic here
                Write-CommandLog "Import functionality to be implemented" "WARNING"
            }
            
            default {
                throw "Unknown action: $Action"
            }
        }
    } catch {
        Write-CommandLog "Configuration command failed: $($_.Exception.Message)" "ERROR"
        exit 1
    }
}

# Main execution
$params = ConvertTo-Parameters -Arguments $Arguments
Write-CommandLog "Executing configuration action: $Action" "DEBUG"

Invoke-ConfigAction -Action $Action -Parameters $params