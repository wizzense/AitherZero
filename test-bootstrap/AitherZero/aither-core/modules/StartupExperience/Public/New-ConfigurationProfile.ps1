function New-ConfigurationProfile {
    <#
    .SYNOPSIS
        Creates a new configuration profile
    .DESCRIPTION
        Creates a new named configuration profile from current or specified configuration
    .PARAMETER Name
        Name of the profile to create
    .PARAMETER Description
        Description of the profile
    .PARAMETER Config
        Configuration object to save (defaults to current)
    .PARAMETER SetAsCurrent
        Set this profile as the current active profile
    .EXAMPLE
        New-ConfigurationProfile -Name "development" -Description "Dev environment setup"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter()]
        [string]$Description,
        
        [Parameter()]
        [PSCustomObject]$Config,
        
        [Parameter()]
        [switch]$SetAsCurrent
    )
    
    try {
        # Validate profile name
        if ($Name -match '[^a-zA-Z0-9\-_]') {
            throw "Profile name can only contain letters, numbers, hyphens, and underscores"
        }
        
        # Get config if not provided
        if (-not $Config) {
            $configPath = Get-CurrentConfigPath
            $Config = Get-Content $configPath -Raw | ConvertFrom-Json
        }
        
        # Create profile metadata
        $profileMetadata = @{
            name = $Name
            description = $Description ?? "Configuration profile created $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
            created = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            lastModified = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            gitRepo = $null
            checksum = Get-ConfigChecksum -Config $Config
        }
        
        # Add profile metadata to config
        if (-not $Config.PSObject.Properties.Name -contains 'profile') {
            $Config | Add-Member -MemberType NoteProperty -Name 'profile' -Value $profileMetadata
        } else {
            $Config.profile = $profileMetadata
        }
        
        # Save profile
        $profilePath = Join-Path $script:ConfigProfilePath "$Name.json"
        $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $profilePath -Encoding UTF8
        
        # Update profile index
        Update-ProfileIndex -Name $Name -Metadata $profileMetadata
        
        # Set as current if requested
        if ($SetAsCurrent) {
            Set-ConfigurationProfile -Name $Name
        }
        
        Write-Host "✅ Configuration profile '$Name' created successfully!" -ForegroundColor Green
        Write-Host "   Path: $profilePath" -ForegroundColor DarkGray
        
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Level 'SUCCESS' -Message "Created configuration profile: $Name"
        }
        
        return $profileMetadata
        
    } catch {
        Write-Error "Failed to create configuration profile: $_"
        throw
    }
}

function Get-ConfigurationProfile {
    <#
    .SYNOPSIS
        Gets a configuration profile
    .DESCRIPTION
        Retrieves a named configuration profile or lists all profiles
    .PARAMETER Name
        Name of the profile to retrieve
    .PARAMETER ListAvailable
        List all available profiles
    .EXAMPLE
        Get-ConfigurationProfile -Name "development"
    .EXAMPLE
        Get-ConfigurationProfile -ListAvailable
    #>
    [CmdletBinding(DefaultParameterSetName = 'Get')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Get')]
        [string]$Name,
        
        [Parameter(Mandatory, ParameterSetName = 'List')]
        [switch]$ListAvailable
    )
    
    try {
        if ($ListAvailable) {
            # Get profile index
            $indexPath = Join-Path $script:ConfigProfilePath '.profile-index.json'
            if (Test-Path $indexPath) {
                $index = Get-Content $indexPath -Raw | ConvertFrom-Json
                
                # Verify profiles still exist
                $validProfiles = @()
                foreach ($profile in $index.profiles.PSObject.Properties) {
                    $profilePath = Join-Path $script:ConfigProfilePath "$($profile.Name).json"
                    if (Test-Path $profilePath) {
                        $validProfiles += [PSCustomObject]@{
                            Name = $profile.Name
                            Description = $profile.Value.description
                            Created = $profile.Value.created
                            LastModified = $profile.Value.lastModified
                            IsCurrent = $profile.Name -eq $script:CurrentProfile
                            HasGitRepo = $null -ne $profile.Value.gitRepo
                        }
                    }
                }
                
                return $validProfiles | Sort-Object Name
            } else {
                # Scan directory for profiles
                $profiles = @()
                Get-ChildItem $script:ConfigProfilePath -Filter '*.json' | Where-Object {
                    $_.Name -ne '.profile-index.json'
                } | ForEach-Object {
                    $profileName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
                    $profiles += [PSCustomObject]@{
                        Name = $profileName
                        Description = "Profile found in directory"
                        Created = $_.CreationTime
                        LastModified = $_.LastWriteTime
                        IsCurrent = $profileName -eq $script:CurrentProfile
                        HasGitRepo = $false
                    }
                }
                
                return $profiles | Sort-Object Name
            }
        } else {
            # Get specific profile
            $profilePath = Join-Path $script:ConfigProfilePath "$Name.json"
            
            if (-not (Test-Path $profilePath)) {
                throw "Profile '$Name' not found"
            }
            
            $config = Get-Content $profilePath -Raw | ConvertFrom-Json
            return $config
        }
        
    } catch {
        Write-Error "Failed to get configuration profile: $_"
        throw
    }
}

function Set-ConfigurationProfile {
    <#
    .SYNOPSIS
        Sets the current configuration profile
    .DESCRIPTION
        Activates a named configuration profile as the current configuration
    .PARAMETER Name
        Name of the profile to activate
    .EXAMPLE
        Set-ConfigurationProfile -Name "development"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    
    try {
        # Verify profile exists
        $profilePath = Join-Path $script:ConfigProfilePath "$Name.json"
        if (-not (Test-Path $profilePath)) {
            throw "Profile '$Name' not found"
        }
        
        # Set as current
        $script:CurrentProfile = $Name
        
        # Update current profile indicator
        $currentPath = Join-Path $script:ConfigProfilePath '.current'
        $Name | Set-Content -Path $currentPath -Encoding UTF8
        
        Write-Host "✅ Switched to configuration profile: $Name" -ForegroundColor Green
        
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Level 'INFO' -Message "Switched to configuration profile: $Name"
        }
        
        return $true
        
    } catch {
        Write-Error "Failed to set configuration profile: $_"
        throw
    }
}

function Remove-ConfigurationProfile {
    <#
    .SYNOPSIS
        Removes a configuration profile
    .DESCRIPTION
        Deletes a named configuration profile
    .PARAMETER Name
        Name of the profile to remove
    .PARAMETER Force
        Skip confirmation prompt
    .EXAMPLE
        Remove-ConfigurationProfile -Name "old-config" -Force
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter()]
        [switch]$Force
    )
    
    try {
        # Prevent removing current profile
        if ($Name -eq $script:CurrentProfile) {
            throw "Cannot remove the current active profile"
        }
        
        # Verify profile exists
        $profilePath = Join-Path $script:ConfigProfilePath "$Name.json"
        if (-not (Test-Path $profilePath)) {
            throw "Profile '$Name' not found"
        }
        
        # Confirm removal
        if (-not $Force) {
            if (-not (Confirm-Action "Remove configuration profile '$Name'?")) {
                Write-Host "Profile removal cancelled" -ForegroundColor Yellow
                return
            }
        }
        
        # Remove profile file
        Remove-Item -Path $profilePath -Force
        
        # Update profile index
        $indexPath = Join-Path $script:ConfigProfilePath '.profile-index.json'
        if (Test-Path $indexPath) {
            $index = Get-Content $indexPath -Raw | ConvertFrom-Json
            if ($index.profiles.PSObject.Properties.Name -contains $Name) {
                $index.profiles.PSObject.Properties.Remove($Name)
                $index | ConvertTo-Json -Depth 10 | Set-Content -Path $indexPath -Encoding UTF8
            }
        }
        
        Write-Host "✅ Configuration profile '$Name' removed" -ForegroundColor Green
        
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Level 'INFO' -Message "Removed configuration profile: $Name"
        }
        
        return $true
        
    } catch {
        Write-Error "Failed to remove configuration profile: $_"
        throw
    }
}

# Helper functions
function Update-ProfileIndex {
    param(
        [string]$Name,
        [PSCustomObject]$Metadata
    )
    
    $indexPath = Join-Path $script:ConfigProfilePath '.profile-index.json'
    
    # Load or create index
    if (Test-Path $indexPath) {
        $index = Get-Content $indexPath -Raw | ConvertFrom-Json
    } else {
        $index = [PSCustomObject]@{
            version = "1.0"
            profiles = [PSCustomObject]@{}
        }
    }
    
    # Update profile entry
    if ($index.profiles.PSObject.Properties.Name -contains $Name) {
        $index.profiles.$Name = $Metadata
    } else {
        $index.profiles | Add-Member -MemberType NoteProperty -Name $Name -Value $Metadata
    }
    
    # Save index
    $index | ConvertTo-Json -Depth 10 | Set-Content -Path $indexPath -Encoding UTF8
}

function Get-ConfigChecksum {
    param(
        [PSCustomObject]$Config
    )
    
    # Simple checksum for change detection
    $json = $Config | ConvertTo-Json -Depth 10 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    return [System.BitConverter]::ToString($hash).Replace('-', '').Substring(0, 16)
}