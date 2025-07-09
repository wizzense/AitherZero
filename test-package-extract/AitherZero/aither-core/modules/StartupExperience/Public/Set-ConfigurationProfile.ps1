function Set-ConfigurationProfile {
    <#
    .SYNOPSIS
        Updates an existing configuration profile
    .DESCRIPTION
        Modifies settings in an existing configuration profile
    .PARAMETER Name
        Profile name to update
    .PARAMETER Settings
        Settings hashtable to merge with existing settings
    .PARAMETER Description
        Update profile description
    .PARAMETER ReplaceSettings
        Replace all settings instead of merging
    .EXAMPLE
        Set-ConfigurationProfile -Name "dev" -Settings @{ LogLevel = "DEBUG" }
        # Merges new settings with existing ones
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [hashtable]$Settings,

        [Parameter()]
        [string]$Description,

        [Parameter()]
        [switch]$ReplaceSettings
    )

    try {
        $profilePath = Join-Path $script:ConfigProfilePath "$Name.json"

        if (-not (Test-Path $profilePath)) {
            throw "Profile '$Name' does not exist. Use New-ConfigurationProfile to create it."
        }

        # Load existing profile
        $existingProfile = Get-Content -Path $profilePath -Raw | ConvertFrom-Json

        # Update description if provided
        if ($Description) {
            $existingProfile.Description = $Description
        }

        # Update settings
        if ($Settings) {
            if ($ReplaceSettings) {
                $existingProfile.Settings = $Settings
            } else {
                # Merge settings
                if (-not $existingProfile.Settings) {
                    $existingProfile.Settings = @{}
                }

                foreach ($key in $Settings.Keys) {
                    $existingProfile.Settings.$key = $Settings[$key]
                }
            }
        }

        # Update timestamp
        $existingProfile.LastModified = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"

        # Save updated profile
        $existingProfile | ConvertTo-Json -Depth 10 | Set-Content -Path $profilePath -Encoding UTF8

        # Log operation
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "Configuration profile updated" -Level INFO -Context @{
                Name = $Name
                DescriptionUpdated = [bool]$Description
                SettingsUpdated = [bool]$Settings
                ReplaceSettings = $ReplaceSettings.IsPresent
                SettingsCount = if ($Settings) { $Settings.Count } else { 0 }
            }
        }

        return Get-ConfigurationProfile -Name $Name -IncludeSettings

    } catch {
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "Error updating configuration profile" -Level ERROR -Exception $_.Exception -Context @{
                Name = $Name
            }
        }
        throw
    }
}
