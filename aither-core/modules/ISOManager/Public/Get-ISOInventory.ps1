function Get-ISOInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$RepositoryPath,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Windows', 'Linux', 'All')]
        [string]$ISOType = 'All',

        [Parameter(Mandatory = $false)]
        [switch]$IncludeMetadata,

        [Parameter(Mandatory = $false)]
        [switch]$VerifyIntegrity
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting ISO inventory scan"
        
        # Set default repository path if not specified
        if (-not $RepositoryPath) {
            $RepositoryPath = Join-Path $env:TEMP "AitherZero-ISOs"
        }
        
        if (-not (Test-Path $RepositoryPath)) {
            Write-CustomLog -Level 'WARN' -Message "Repository path does not exist: $RepositoryPath"
            return @()
        }
    }

    process {
        try {
            $inventory = @()
            
            # Find all ISO files in the repository
            $isoFiles = Get-ChildItem -Path $RepositoryPath -Filter "*.iso" -Recurse
            
            foreach ($isoFile in $isoFiles) {
                Write-CustomLog -Level 'INFO' -Message "Processing ISO: $($isoFile.Name)"
                
                $isoInfo = @{
                    Name = $isoFile.BaseName
                    FileName = $isoFile.Name
                    FilePath = $isoFile.FullName
                    Size = $isoFile.Length
                    SizeGB = [math]::Round($isoFile.Length / 1GB, 2)
                    Created = $isoFile.CreationTime
                    Modified = $isoFile.LastWriteTime
                    Type = 'Unknown'
                }

                # Determine ISO type based on filename patterns
                $fileName = $isoFile.Name.ToLower()
                if ($fileName -match 'windows|win10|win11|server') {
                    $isoInfo.Type = 'Windows'
                } elseif ($fileName -match 'ubuntu|centos|rhel|debian|fedora|suse|linux') {
                    $isoInfo.Type = 'Linux'
                }

                # Filter by type if specified
                if ($ISOType -ne 'All' -and $isoInfo.Type -ne $ISOType) {
                    continue
                }

                # Include metadata if requested
                if ($IncludeMetadata) {
                    try {
                        $metadata = Get-ISOMetadata -FilePath $isoFile.FullName
                        $isoInfo.Metadata = $metadata
                    } catch {
                        Write-CustomLog -Level 'WARN' -Message "Failed to read metadata for $($isoFile.Name): $($_.Exception.Message)"
                        $isoInfo.Metadata = $null
                    }
                }

                # Verify integrity if requested
                if ($VerifyIntegrity) {
                    try {
                        $integrity = Test-ISOIntegrity -FilePath $isoFile.FullName
                        $isoInfo.IntegrityVerified = $integrity.Valid
                        $isoInfo.Checksum = $integrity.Checksum
                    } catch {
                        Write-CustomLog -Level 'WARN' -Message "Failed to verify integrity for $($isoFile.Name): $($_.Exception.Message)"
                        $isoInfo.IntegrityVerified = $false
                    }
                }

                $inventory += $isoInfo
            }

            Write-CustomLog -Level 'SUCCESS' -Message "Found $($inventory.Count) ISO files in inventory"
            return $inventory
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to generate ISO inventory: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Completed ISO inventory scan"
    }
}
