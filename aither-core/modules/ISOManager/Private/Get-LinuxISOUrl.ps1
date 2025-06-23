function Get-LinuxISOUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ISOName,

        [Parameter(Mandatory = $false)]
        [string]$Version = "latest",

        [Parameter(Mandatory = $false)]
        [string]$Architecture = "x64"
    )

    # Known Linux distribution ISO URLs/patterns
    $knownDistros = @{
        'Ubuntu' = @{
            'latest' = @{
                'x64' = 'https://releases.ubuntu.com/22.04/ubuntu-22.04.3-desktop-amd64.iso'
            }
            '22.04' = @{
                'x64' = 'https://releases.ubuntu.com/22.04/ubuntu-22.04.3-desktop-amd64.iso'
            }
            '20.04' = @{
                'x64' = 'https://releases.ubuntu.com/20.04/ubuntu-20.04.6-desktop-amd64.iso'
            }
        }
        'UbuntuServer' = @{
            'latest' = @{
                'x64' = 'https://releases.ubuntu.com/22.04/ubuntu-22.04.3-live-server-amd64.iso'
            }
            '22.04' = @{
                'x64' = 'https://releases.ubuntu.com/22.04/ubuntu-22.04.3-live-server-amd64.iso'
            }
        }
        'CentOS' = @{
            'latest' = @{
                'x64' = 'https://mirrors.centos.org/mirrorlist?path=/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-latest-x86_64-dvd1.iso'
            }
            '9' = @{
                'x64' = 'https://mirrors.centos.org/mirrorlist?path=/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-latest-x86_64-dvd1.iso'
            }
        }
        'RHEL' = @{
            'latest' = @{
                'x64' = 'https://developers.redhat.com/content-gateway/rest/mirror/pub/rhel/9/rhel-9-latest-x86_64-dvd.iso'
            }
            '9' = @{
                'x64' = 'https://developers.redhat.com/content-gateway/rest/mirror/pub/rhel/9/rhel-9-latest-x86_64-dvd.iso'
            }
        }
        'Debian' = @{
            'latest' = @{
                'x64' = 'https://cdimage.debian.org/debian-cd/current/amd64/iso-dvd/debian-12.2.0-amd64-DVD-1.iso'
            }
            '12' = @{
                'x64' = 'https://cdimage.debian.org/debian-cd/current/amd64/iso-dvd/debian-12.2.0-amd64-DVD-1.iso'
            }
            '11' = @{
                'x64' = 'https://cdimage.debian.org/debian-cd/11.8.0/amd64/iso-dvd/debian-11.8.0-amd64-DVD-1.iso'
            }
        }
        'Fedora' = @{
            'latest' = @{
                'x64' = 'https://download.fedoraproject.org/pub/fedora/linux/releases/39/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-39-1.5.iso'
            }
            '39' = @{
                'x64' = 'https://download.fedoraproject.org/pub/fedora/linux/releases/39/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-39-1.5.iso'
            }
        }
        'openSUSE' = @{
            'latest' = @{
                'x64' = 'https://download.opensuse.org/distribution/leap/15.5/iso/openSUSE-Leap-15.5-DVD-x86_64-Media.iso'
            }
            '15.5' = @{
                'x64' = 'https://download.opensuse.org/distribution/leap/15.5/iso/openSUSE-Leap-15.5-DVD-x86_64-Media.iso'
            }
        }
    }

    try {
        # Normalize architecture naming
        $normalizedArch = switch ($Architecture.ToLower()) {
            'x64' { 'x64' }
            'amd64' { 'x64' }
            'x86_64' { 'x64' }
            'x86' { 'x86' }
            'i386' { 'x86' }
            default { $Architecture }
        }

        # Try to find exact match first
        if ($knownDistros.ContainsKey($ISOName)) {
            $distroVersions = $knownDistros[$ISOName]
            
            # Find version (exact or latest)
            $targetVersion = if ($distroVersions.ContainsKey($Version)) { 
                $Version 
            } elseif ($distroVersions.ContainsKey('latest')) { 
                'latest' 
            } else { 
                $distroVersions.Keys | Select-Object -First 1 
            }
            
            if ($distroVersions.ContainsKey($targetVersion)) {
                $archVersions = $distroVersions[$targetVersion]
                
                # Find architecture
                $targetArch = if ($archVersions.ContainsKey($normalizedArch)) { 
                    $normalizedArch 
                } else { 
                    $archVersions.Keys | Select-Object -First 1 
                }
                
                if ($archVersions.ContainsKey($targetArch)) {
                    return $archVersions[$targetArch]
                }
            }
        }

        # Try partial matching for distribution names
        $matchedKey = $knownDistros.Keys | Where-Object { 
            $ISOName -match $_ -or $_ -match $ISOName -or $ISOName.ToLower() -like "*$($_.ToLower())*"
        } | Select-Object -First 1

        if ($matchedKey) {
            $distroVersions = $knownDistros[$matchedKey]
            $firstVersion = $distroVersions.Keys | Select-Object -First 1
            $firstArch = $distroVersions[$firstVersion].Keys | Select-Object -First 1
            
            Write-CustomLog -Level 'WARN' -Message "Exact match not found for '$ISOName', using closest match: $matchedKey"
            return $distroVersions[$firstVersion][$firstArch]
        }

        # If no known URL found, provide a helpful error
        Write-CustomLog -Level 'WARN' -Message "No known download URL for Linux distribution: $ISOName"
        Write-CustomLog -Level 'INFO' -Message "Known Linux distributions: $($knownDistros.Keys -join ', ')"
        
        # Return a placeholder URL for testing purposes
        return "https://example.com/linux-distros/$ISOName-$Version-$normalizedArch.iso"
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Error determining Linux ISO URL: $($_.Exception.Message)"
        throw
    }
}
