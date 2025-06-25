# Private helper functions for ISOCustomizer module

function Test-AdminPrivileges {
    <#
    .SYNOPSIS
        Tests if the current session has administrative privileges.
    #>
    try {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Get-OSImageName {
    <#
    .SYNOPSIS
        Gets the correct OS image name for autounattend files.
    #>
    param(
        [string]$OSType,
        [string]$Edition
    )

    $imageNames = @{
        'Server2025' = @{
            'Standard' = 'Windows Server 2025 SERVERSTANDARD'
            'Datacenter' = 'Windows Server 2025 SERVERDATACENTER'
            'Core' = 'Windows Server 2025 SERVERDATACENTERCORE'
        }
        'Server2022' = @{
            'Standard' = 'Windows Server 2022 SERVERSTANDARD'
            'Datacenter' = 'Windows Server 2022 SERVERDATACENTER'
            'Core' = 'Windows Server 2022 SERVERDATACENTERCORE'
        }
        'Server2019' = @{
            'Standard' = 'Windows Server 2019 SERVERSTANDARD'
            'Datacenter' = 'Windows Server 2019 SERVERDATACENTER'
            'Core' = 'Windows Server 2019 SERVERDATACENTERCORE'
        }
        'Windows11' = @{
            'Desktop' = 'Windows 11 Pro'
            'Pro' = 'Windows 11 Pro'
        }
        'Windows10' = @{
            'Desktop' = 'Windows 10 Pro'
            'Pro' = 'Windows 10 Pro'
        }
    }

    if ($imageNames.ContainsKey($OSType) -and $imageNames[$OSType].ContainsKey($Edition)) {
        return $imageNames[$OSType][$Edition]
    }

    # Default fallback
    return "Windows Server 2025 SERVERDATACENTERCORE"
}

function Apply-OfflineRegistryChanges {
    <#
    .SYNOPSIS
        Applies registry changes to an offline Windows image.
    #>
    param(
        [string]$MountPath,
        [hashtable]$Changes
    )

    Write-CustomLog -Level 'INFO' -Message "Applying offline registry changes..."

    foreach ($change in $Changes.GetEnumerator()) {
        $keyPath = $change.Key
        $values = $change.Value

        try {
            # Load the offline registry hives
            $systemHive = Join-Path $MountPath "Windows\System32\config\SYSTEM"
            $softwareHive = Join-Path $MountPath "Windows\System32\config\SOFTWARE"

            # Apply changes using reg.exe for offline registry
            foreach ($value in $values.GetEnumerator()) {
                $regArgs = @(
                    "add",
                    $keyPath,
                    "/v", $value.Key,
                    "/t", "REG_DWORD",  # Assume DWORD for now, could be enhanced
                    "/d", $value.Value,
                    "/f"
                )

                Start-Process -FilePath "reg" -ArgumentList $regArgs -Wait -NoNewWindow
            }

            Write-CustomLog -Level 'INFO' -Message "Applied registry changes for: $keyPath"
        } catch {
            Write-CustomLog -Level 'WARN' -Message "Failed to apply registry changes for: $keyPath - $($_.Exception.Message)"
        }
    }
}

function Get-PredefinedISOConfig {
    <#
    .SYNOPSIS
        Gets predefined ISO configuration for common downloads.
    #>
    param(
        [string]$ISOType,
        [string]$ISOName
    )

    # This could be enhanced to read from configuration files
    $predefinedConfigs = @{
        'WindowsServer2025' = @{
            DownloadURL = 'https://software-download.microsoft.com/...'  # Placeholder
            Hash = ''  # Would need actual hash
            HashAlgorithm = 'SHA256'
        }
        'Ubuntu' = @{
            DownloadURL = 'https://releases.ubuntu.com/22.04/ubuntu-22.04.3-desktop-amd64.iso'
            Hash = ''  # Would need actual hash
            HashAlgorithm = 'SHA256'
        }
    }

    if ($predefinedConfigs.ContainsKey($ISOType)) {
        return $predefinedConfigs[$ISOType]
    }

    return $null
}

function Update-ISOInventory {
    <#
    .SYNOPSIS
        Updates the ISO inventory with new download information.
    #>
    param(
        [string]$FilePath,
        [string]$ISOName,
        [string]$ISOType,
        [string]$DownloadURL
    )

    try {
        $inventoryPath = Join-Path $env:TEMP "AitherZero-ISO-Inventory.json"

        $inventory = @()
        if (Test-Path $inventoryPath) {
            $inventory = Get-Content $inventoryPath -Raw | ConvertFrom-Json
        }

        $newEntry = @{
            ISOName = $ISOName
            ISOType = $ISOType
            FilePath = $FilePath
            DownloadURL = $DownloadURL
            FileSize = (Get-Item $FilePath).Length
            Hash = (Get-FileHash $FilePath -Algorithm SHA256).Hash
            DownloadDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        }

        $inventory += $newEntry

        $inventory | ConvertTo-Json -Depth 10 | Set-Content $inventoryPath

        Write-CustomLog -Level 'INFO' -Message "Updated ISO inventory: $inventoryPath"
    } catch {
        Write-CustomLog -Level 'WARN' -Message "Failed to update ISO inventory: $($_.Exception.Message)"
    }
}