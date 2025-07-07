function Import-ConfigurationProfile {
    <#
    .SYNOPSIS
        Imports a configuration profile from file
    .DESCRIPTION
        Imports configuration profiles from JSON files or other sources
    .PARAMETER Path
        Path to the profile file to import
    .PARAMETER Name
        Override profile name (uses filename if not specified)
    .PARAMETER Force
        Overwrite existing profile without confirmation
    .PARAMETER Source
        Source of the import (File, GitHub, etc.)
    .EXAMPLE
        Import-ConfigurationProfile -Path "./backup.json"
        # Imports profile from file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter()]
        [string]$Name,
        
        [Parameter()]
        [switch]$Force,
        
        [Parameter()]
        [string]$Source = 'File'
    )
    
    try {
        if (-not (Test-Path $Path)) {
            throw "Import file not found: $Path"
        }
        
        # Load profile data
        $profileData = Get-Content -Path $Path -Raw | ConvertFrom-Json
        
        # Determine profile name
        if (-not $Name) {
            $Name = if ($profileData.Name) { 
                $profileData.Name 
            } else { 
                [System.IO.Path]::GetFileNameWithoutExtension($Path) 
            }
        }
        
        # Check if profile already exists
        $existingProfile = Get-ConfigurationProfile -Name $Name -ErrorAction SilentlyContinue
        if ($existingProfile -and -not $Force) {
            $response = Read-Host "Profile '$Name' already exists. Overwrite? (y/N)"
            if ($response -notmatch '^y(es)?$') {
                Write-Host "Import cancelled." -ForegroundColor Yellow
                return $null
            }
        }
        
        # Prepare profile data
        $profileToImport = @{
            Name = $Name
            Description = $profileData.Description ?? "Imported from $Source"
            Settings = $profileData.Settings ?? @{}
            Created = $profileData.Created ?? (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
            LastModified = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            ImportedFrom = $Path
            ImportedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            ImportSource = $Source
        }
        
        # Save imported profile
        $profilePath = Join-Path $script:ConfigProfilePath "$Name.json"
        $profileToImport | ConvertTo-Json -Depth 10 | Set-Content -Path $profilePath -Encoding UTF8
        
        # Log operation
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "Configuration profile imported" -Level INFO -Context @{
                Name = $Name
                Source = $Source
                ImportPath = $Path
                SettingsCount = $profileToImport.Settings.Count
                Overwritten = [bool]$existingProfile
            }
        }
        
        Write-Host "Profile '$Name' imported successfully from: $Path" -ForegroundColor Green
        
        return Get-ConfigurationProfile -Name $Name -IncludeSettings
        
    } catch {
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "Error importing configuration profile" -Level ERROR -Exception $_.Exception -Context @{
                Name = $Name ?? "Unknown"
                Path = $Path
                Source = $Source
            }
        }
        throw
    }
}