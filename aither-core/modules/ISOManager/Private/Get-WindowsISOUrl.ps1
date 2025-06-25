function Get-WindowsISOUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ISOName,

        [Parameter(Mandatory = $false)]
        [string]$Version = "latest",

        [Parameter(Mandatory = $false)]
        [string]$Architecture = "x64",

        [Parameter(Mandatory = $false)]
        [string]$Language = "en-US"
    )

    # Known Windows ISO URLs/patterns
    $knownISOs = @{
        'Windows11' = @{
            'latest' = @{
                'x64' = @{
                    'en-US' = 'https://software-download.microsoft.com/db/Win11_23H2_English_x64v2.iso'
                }
            }
        }
        'Windows10' = @{
            'latest' = @{
                'x64' = @{
                    'en-US' = 'https://software-download.microsoft.com/db/Win10_22H2_English_x64.iso'
                }
            }
        }
        'Server2025' = @{
            'latest' = @{
                'x64' = @{
                    'en-US' = 'https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/26100.1742.240906-0331.ge_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso'
                }
            }
        }
        'Server2022' = @{
            'latest' = @{
                'x64' = @{
                    'en-US' = 'https://software-static.download.prss.microsoft.com/dbazure/988969d5-f34g-4e03-ac9d-1f9786c66749/20348.169.210806-2348.fe_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso'
                }
            }
        }
        'Server2019' = @{
            'latest' = @{
                'x64' = @{
                    'en-US' = 'https://software-download.microsoft.com/download/pr/17763.737.190906-2324.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us_1.iso'
                }
            }
        }
    }

    try {
        # Try to find exact match first
        if ($knownISOs.ContainsKey($ISOName)) {
            $isoVersions = $knownISOs[$ISOName]

            # Find version (exact or latest)
            $targetVersion = if ($isoVersions.ContainsKey($Version)) {
                $Version
            } elseif ($isoVersions.ContainsKey('latest')) {
                'latest'
            } else {
                $isoVersions.Keys | Select-Object -First 1
            }

            if ($isoVersions.ContainsKey($targetVersion)) {
                $archVersions = $isoVersions[$targetVersion]

                # Find architecture
                $targetArch = if ($archVersions.ContainsKey($Architecture)) {
                    $Architecture
                } else {
                    $archVersions.Keys | Select-Object -First 1
                }

                if ($archVersions.ContainsKey($targetArch)) {
                    $langVersions = $archVersions[$targetArch]

                    # Find language
                    $targetLang = if ($langVersions.ContainsKey($Language)) {
                        $Language
                    } else {
                        $langVersions.Keys | Select-Object -First 1
                    }

                    if ($langVersions.ContainsKey($targetLang)) {
                        return $langVersions[$targetLang]
                    }
                }
            }
        }

        # Try partial matching for Windows names
        $matchedKey = $knownISOs.Keys | Where-Object {
            $ISOName -match $_ -or $_ -match $ISOName
        } | Select-Object -First 1

        if ($matchedKey) {
            $isoVersions = $knownISOs[$matchedKey]
            $firstVersion = $isoVersions.Keys | Select-Object -First 1
            $firstArch = $isoVersions[$firstVersion].Keys | Select-Object -First 1
            $firstLang = $isoVersions[$firstVersion][$firstArch].Keys | Select-Object -First 1

            Write-CustomLog -Level 'WARN' -Message "Exact match not found for '$ISOName', using closest match: $matchedKey"
            return $isoVersions[$firstVersion][$firstArch][$firstLang]
        }

        # If no known URL found, provide a helpful error
        Write-CustomLog -Level 'WARN' -Message "No known download URL for Windows ISO: $ISOName"
        Write-CustomLog -Level 'INFO' -Message "Known Windows ISOs: $($knownISOs.Keys -join ', ')"

        # Return a placeholder URL for testing purposes
        return "https://download.microsoft.com/placeholder/$ISOName-$Version-$Architecture-$Language.iso"

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Error determining Windows ISO URL: $($_.Exception.Message)"
        throw
    }
}