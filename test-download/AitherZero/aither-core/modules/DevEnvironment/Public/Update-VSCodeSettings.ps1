function Update-VSCodeSettings {
    <#
    .SYNOPSIS
    Updates VS Code settings by merging user settings with default settings.

    .DESCRIPTION
    This function merges default VS Code settings with existing user settings,
    preserving user customizations while ensuring required settings are present.

    .PARAMETER DefaultSettingsPath
    Path to the default settings JSON file.

    .PARAMETER UserSettingsPath
    Path to the user's VS Code settings file. If not specified, uses the default VS Code settings location.

    .PARAMETER BackupUserSettings
    If specified, creates a backup of user settings before merging.

    .EXAMPLE
    Update-VSCodeSettings -DefaultSettingsPath "./configs/vscode-defaults.json"

    .EXAMPLE
    Update-VSCodeSettings -DefaultSettingsPath "./configs/vscode-defaults.json" -BackupUserSettings
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$DefaultSettingsPath,

        [Parameter(Mandatory = $false)]
        [string]$UserSettingsPath,

        [switch]$BackupUserSettings
    )

    begin {
        # Import required modules
        $projectRoot = & "$PSScriptRoot/../../../shared/Find-ProjectRoot.ps1"
        Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force

        Write-CustomLog -Level 'INFO' -Message "Starting VS Code settings update"
    }

    process {
        try {
            # Determine user settings path if not provided
            if (-not $UserSettingsPath) {
                $vsCodeSettingsDir = if ($IsWindows) {
                    Join-Path $env:APPDATA "Code" "User"
                } elseif ($IsMacOS) {
                    Join-Path $HOME "Library" "Application Support" "Code" "User"
                } else {
                    Join-Path $HOME ".config" "Code" "User"
                }

                $UserSettingsPath = Join-Path $vsCodeSettingsDir "settings.json"
            }

            # Load default settings
            Write-CustomLog -Level 'INFO' -Message "Loading default settings from: $DefaultSettingsPath"
            $defaultSettingsContent = Get-Content -Path $DefaultSettingsPath -Raw
            $defaultSettings = $defaultSettingsContent | ConvertFrom-Json -AsHashtable

            # Check if user settings exist
            $userSettings = @{}
            if (Test-Path $UserSettingsPath) {
                # Backup user settings if requested
                if ($BackupUserSettings) {
                    $backupPath = "$UserSettingsPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                    Copy-Item -Path $UserSettingsPath -Destination $backupPath -Force
                    Write-CustomLog -Level 'INFO' -Message "User settings backed up to: $backupPath"
                }

                # Load existing user settings
                Write-CustomLog -Level 'INFO' -Message "Loading user settings from: $UserSettingsPath"
                $userSettingsContent = Get-Content -Path $UserSettingsPath -Raw
                if ($userSettingsContent.Trim()) {
                    $userSettings = $userSettingsContent | ConvertFrom-Json -AsHashtable
                }
            } else {
                Write-CustomLog -Level 'WARNING' -Message "User settings file not found. Will create new file at: $UserSettingsPath"

                # Ensure directory exists
                $settingsDir = Split-Path -Path $UserSettingsPath -Parent
                if (-not (Test-Path $settingsDir)) {
                    New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
                }
            }

            # Merge settings (user settings take precedence)
            $mergedSettings = Merge-HashTables -Default $defaultSettings -Override $userSettings

            # Convert to JSON with proper formatting
            $jsonSettings = $mergedSettings | ConvertTo-Json -Depth 10

            # Save merged settings
            Set-Content -Path $UserSettingsPath -Value $jsonSettings -Force
            Write-CustomLog -Level 'SUCCESS' -Message "VS Code settings updated successfully at: $UserSettingsPath"

            # Return summary of changes
            $result = @{
                UserSettingsPath = $UserSettingsPath
                DefaultSettingsApplied = $defaultSettings.Count
                UserSettingsPreserved = $userSettings.Count
                TotalSettings = $mergedSettings.Count
                BackupCreated = $BackupUserSettings
            }

            return $result

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to update VS Code settings: $($_.Exception.Message)"
            throw
        }
    }
}

function Merge-HashTables {
    <#
    .SYNOPSIS
    Recursively merges two hashtables with override taking precedence.

    .DESCRIPTION
    Private helper function that performs deep merge of hashtables.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Default,

        [Parameter(Mandatory = $true)]
        [hashtable]$Override
    )

    $result = @{}

    # Add all default values
    foreach ($key in $Default.Keys) {
        $result[$key] = $Default[$key]
    }

    # Override with user values
    foreach ($key in $Override.Keys) {
        if ($Override[$key] -is [hashtable] -and $Default.ContainsKey($key) -and $Default[$key] -is [hashtable]) {
            # Recursive merge for nested hashtables
            $result[$key] = Merge-HashTables -Default $Default[$key] -Override $Override[$key]
        } else {
            # Direct override for non-hashtable values
            $result[$key] = $Override[$key]
        }
    }

    return $result
}
