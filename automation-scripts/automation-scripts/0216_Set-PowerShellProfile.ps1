#Requires -Version 7.0
# Stage: Development
# Dependencies: None
# Description: Configure PowerShell profile for AitherZero environment

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

Write-ScriptLog "Starting PowerShell profile configuration"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if profile setup is enabled
    $shouldSetup = $false
    $ProfileNameConfig = @{
        Enable = $false
        ProfileScope = 'CurrentUserAllHosts'
        IncludeAliases = $true
        IncludeFunctions = $true
        IncludeModulePaths = $true
        CustomPrompt = $false
        BackupExisting = $true
    }

    if ($config.DevelopmentTools -and $config.DevelopmentTools.PowerShellProfile) {
        $psProfileConfig = $config.DevelopmentTools.PowerShellProfile
        $shouldSetup = $psProfileConfig.Enable -eq $true

        # Override defaults with config
        if ($psProfileConfig.ProfileScope) { $ProfileNameConfig.ProfileScope = $psProfileConfig.ProfileScope }
        if ($null -ne $psProfileConfig.IncludeAliases) { $ProfileNameConfig.IncludeAliases = $psProfileConfig.IncludeAliases }
        if ($null -ne $psProfileConfig.IncludeFunctions) { $ProfileNameConfig.IncludeFunctions = $psProfileConfig.IncludeFunctions }
        if ($null -ne $psProfileConfig.IncludeModulePaths) { $ProfileNameConfig.IncludeModulePaths = $psProfileConfig.IncludeModulePaths }
        if ($null -ne $psProfileConfig.CustomPrompt) { $ProfileNameConfig.CustomPrompt = $psProfileConfig.CustomPrompt }
        if ($null -ne $psProfileConfig.BackupExisting) { $ProfileNameConfig.BackupExisting = $psProfileConfig.BackupExisting }
    }

    if (-not $shouldSetup) {
        Write-ScriptLog "PowerShell profile setup is not enabled in configuration"
        exit 0
    }

    # Determine profile path based on scope
    $ProfileNamePath = switch ($ProfileNameConfig.ProfileScope) {
        'CurrentUserAllHosts' { $ProfileName.CurrentUserAllHosts }
        'CurrentUserCurrentHost' { $ProfileName.CurrentUserCurrentHost }
        'AllUsersAllHosts' { $ProfileName.AllUsersAllHosts }
        'AllUsersCurrentHost' { $ProfileName.AllUsersCurrentHost }
        default { $ProfileName.CurrentUserAllHosts }
    }

    Write-ScriptLog "Profile path: $ProfileNamePath"
    Write-ScriptLog "Profile scope: $($ProfileNameConfig.ProfileScope)"

    # Create profile directory if it doesn't exist
    $ProfileNameDir = Split-Path $ProfileNamePath -Parent
    if (-not (Test-Path $ProfileNameDir)) {
        if ($PSCmdlet.ShouldProcess($ProfileNameDir, 'Create profile directory')) {
            New-Item -ItemType Directory -Path $ProfileNameDir -Force | Out-Null
            Write-ScriptLog "Created profile directory: $ProfileNameDir"
        }
    }

    # Backup existing profile if configured
    if ((Test-Path $ProfileNamePath) -and $ProfileNameConfig.BackupExisting) {
        $backupPath = "$ProfileNamePath.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
        if ($PSCmdlet.ShouldProcess($ProfileNamePath, "Backup to $backupPath")) {
            Copy-Item -Path $ProfileNamePath -Destination $backupPath -Force
            Write-ScriptLog "Backed up existing profile to: $backupPath"
        }
    }

    # Get project root
    $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Write-ScriptLog "Project root: $projectRoot"

    # Build profile content
    $ProfileNameContent = @"
# ==================================================
# AitherZero PowerShell Profile
# Generated on: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# ==================================================

# Set AitherZero environment variables
`$env:AITHERZERO_ROOT = '$projectRoot'
`$env:PROJECT_ROOT = '$projectRoot'

"@

    # Add module paths if configured
    if ($ProfileNameConfig.IncludeModulePaths) {
        $ProfileNameContent += @"

# Add AitherZero modules to PSModulePath
`$aitherModulePath = Join-Path `$env:AITHERZERO_ROOT 'domains'
if (`$env:PSModulePath -notlike "*`$aitherModulePath*") {
    `$env:PSModulePath = "`$aitherModulePath;`$env:PSModulePath"
}

`$legacyModulePath = Join-Path `$env:AITHERZERO_ROOT 'aither-core/modules'
if ((Test-Path `$legacyModulePath) -and (`$env:PSModulePath -notlike "*`$legacyModulePath*")) {
    `$env:PSModulePath = "`$legacyModulePath;`$env:PSModulePath"
}

"@
    }

    # Add aliases if configured
    if ($ProfileNameConfig.IncludeAliases) {
        $ProfileNameContent += @"

# AitherZero aliases
Set-Alias -Name aither -Value (Join-Path `$env:AITHERZERO_ROOT 'Start-AitherZero.ps1') -ErrorAction SilentlyContinue
Set-Alias -Name az0 -Value (Join-Path `$env:AITHERZERO_ROOT 'Start-AitherZero.ps1') -ErrorAction SilentlyContinue

"@
    }

    # Add helper functions if configured
    if ($ProfileNameConfig.IncludeFunctions) {
        $ProfileNameContent += @"

# AitherZero helper functions
function Enter-AitherProject {
    Set-Location `$env:AITHERZERO_ROOT
}
Set-Alias -Name acd -Value Enter-AitherProject

function Get-AitherModules {
    Get-ChildItem -Path (Join-Path `$env:AITHERZERO_ROOT 'domains') -Directory |
        Where-Object { Test-Path (Join-Path `$_.FullName '*.psm1') }
}

function Import-AitherModule {
    param(
        [Parameter(Mandatory)]
        [string]`$ModuleName
    )

    `$modulePath = Join-Path `$env:AITHERZERO_ROOT "domains/*/$ModuleName/$ModuleName.psm1"
    `$moduleFile = Get-Item `$modulePath -ErrorAction SilentlyContinue | Select-Object -First 1

    if (`$moduleFile) {
        Import-Module `$moduleFile -Force
        Write-Host "Imported module: `$ModuleName" -ForegroundColor Green
    } else {
        Write-Host "Module not found: `$ModuleName" -ForegroundColor Red
    }
}

"@
    }

    # Add custom prompt if configured
    if ($ProfileNameConfig.CustomPrompt) {
        $ProfileNameContent += @"

# Custom prompt for AitherZero
function prompt {
    `$currentPath = `$PWD.Path
    `$inAitherProject = `$currentPath -like "`$env:AITHERZERO_ROOT*"

    if (`$inAitherProject) {
        `$relativePath = `$currentPath.Replace(`$env:AITHERZERO_ROOT, '').TrimStart('\', '/')
        if (-not `$relativePath) { `$relativePath = '~' }
        Write-Host "[AitherZero] " -NoNewline -ForegroundColor Cyan
        Write-Host "`$relativePath" -NoNewline -ForegroundColor Green
    } else {
        Write-Host `$currentPath -NoNewline
    }

    Write-Host " PS>" -NoNewline
    return " "
}

"@
    }

    # Add any custom content from configuration
    if ($config.DevelopmentTools.PowerShellProfile.CustomContent) {
        $ProfileNameContent += @"

# Custom content from configuration
$($config.DevelopmentTools.PowerShellProfile.CustomContent)

"@
    }

    # Write profile
    if ($PSCmdlet.ShouldProcess($ProfileNamePath, 'Create/Update PowerShell profile')) {
        Set-Content -Path $ProfileNamePath -Value $ProfileNameContent -Encoding UTF8
        Write-ScriptLog "PowerShell profile created/updated successfully"

        # Display summary
        Write-ScriptLog ""
        Write-ScriptLog "Profile configuration summary:"
        Write-ScriptLog "  - Location: $ProfileNamePath"
        Write-ScriptLog "  - Module paths: $($ProfileNameConfig.IncludeModulePaths)"
        Write-ScriptLog "  - Aliases: $($ProfileNameConfig.IncludeAliases)"
        Write-ScriptLog "  - Helper functions: $($ProfileNameConfig.IncludeFunctions)"
        Write-ScriptLog "  - Custom prompt: $($ProfileNameConfig.CustomPrompt)"
        Write-ScriptLog ""
        Write-ScriptLog "To activate the profile, run: . `$ProfileName"
        Write-ScriptLog "Or start a new PowerShell session"
    }

    exit 0

} catch {
    Write-ScriptLog "Critical error during PowerShell profile setup: $_" -Level 'Error'
    Write-ScriptLog $_.ScriptStackTrace -Level 'Error'
    exit 1
}