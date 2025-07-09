function Get-ConfigurationProfile {
    <#
    .SYNOPSIS
        Retrieves configuration profiles
    .DESCRIPTION
        Gets configuration profiles from storage with filtering and search capabilities
    .PARAMETER Name
        Specific profile name to retrieve
    .PARAMETER Source
        Profile source (Local, GitHub, All)
    .PARAMETER IncludeSettings
        Include full settings in output
    .EXAMPLE
        Get-ConfigurationProfile
        # Gets all local profiles
    .EXAMPLE
        Get-ConfigurationProfile -Name "development"
        # Gets specific profile
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Name,

        [Parameter()]
        [ValidateSet('Local', 'GitHub', 'All')]
        [string]$Source = 'Local',

        [Parameter()]
        [switch]$IncludeSettings
    )

    try {
        $profiles = @()

        # Check local profiles
        if ($Source -in @('Local', 'All')) {
            if (Test-Path $script:ConfigProfilePath) {
                $localProfiles = Get-ChildItem -Path $script:ConfigProfilePath -Filter "*.json" -ErrorAction SilentlyContinue

                foreach ($profileFile in $localProfiles) {
                    try {
                        $profileContent = Get-Content -Path $profileFile.FullName -Raw | ConvertFrom-Json

                        $profile = [PSCustomObject]@{
                            Name = $profileFile.BaseName
                            Source = 'Local'
                            Created = $profileFile.CreationTime
                            Modified = $profileFile.LastWriteTime
                            Description = $profileContent.Description ?? "No description"
                            Settings = if ($IncludeSettings) { $profileContent.Settings } else { $null }
                            Path = $profileFile.FullName
                        }

                        if (-not $Name -or $profile.Name -eq $Name) {
                            $profiles += $profile
                        }
                    } catch {
                        Write-Warning "Failed to load profile '$($profileFile.Name)': $($_.Exception.Message)"
                    }
                }
            }
        }

        # Filter by name if specified
        if ($Name) {
            $profiles = $profiles | Where-Object Name -eq $Name
        }

        # Log operation
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "Retrieved configuration profiles" -Level DEBUG -Context @{
                ProfileCount = $profiles.Count
                Name = $Name ?? "All"
                Source = $Source
                IncludeSettings = $IncludeSettings.IsPresent
            }
        }

        return $profiles

    } catch {
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "Error retrieving configuration profiles" -Level ERROR -Exception $_.Exception
        }
        throw
    }
}
