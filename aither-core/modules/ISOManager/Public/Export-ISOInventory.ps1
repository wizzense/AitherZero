function Export-ISOInventory {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$RepositoryPath,

        [Parameter(Mandatory = $true)]
        [string]$ExportPath,

        [Parameter(Mandatory = $false)]
        [ValidateSet('JSON', 'CSV', 'XML')]
        [string]$Format = 'JSON',

        [Parameter(Mandatory = $false)]
        [switch]$IncludeMetadata,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeIntegrity
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Exporting ISO inventory to: $ExportPath"

        # Set default repository path if not specified
        if (-not $RepositoryPath) {
            $RepositoryPath = Join-Path $env:TEMP "AitherZero-ISOs"
        }
    }

    process {
        try {
            # Get the current inventory
            $inventory = Get-ISOInventory -RepositoryPath $RepositoryPath -IncludeMetadata:$IncludeMetadata -VerifyIntegrity:$IncludeIntegrity

            if (-not $inventory -or $inventory.Count -eq 0) {
                Write-CustomLog -Level 'WARN' -Message "No ISOs found in repository: $RepositoryPath"
                return @{
                    Success = $false
                    Message = "No ISOs found to export"
                    ExportPath = $ExportPath
                }
            }

            # Create export metadata
            $exportData = @{
                ExportInfo = @{
                    RepositoryPath = $RepositoryPath
                    ExportDate = Get-Date
                    ExportFormat = $Format
                    TotalISOs = $inventory.Count
                    ExportedBy = $env:USERNAME
                    AitherZeroVersion = "1.0.0"
                }
                Inventory = $inventory
            }

            if ($PSCmdlet.ShouldProcess($ExportPath, "Export ISO Inventory")) {
                # Ensure export directory exists
                $exportDir = Split-Path $ExportPath -Parent
                if ($exportDir -and -not (Test-Path $exportDir)) {
                    New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
                }

                # Export in the specified format
                switch ($Format) {
                    'JSON' {
                        $exportData | ConvertTo-Json -Depth 10 | Set-Content $ExportPath -Encoding UTF8
                    }
                    'CSV' {
                        # Flatten the inventory for CSV export
                        $flatInventory = $inventory | ForEach-Object {
                            $item = $_
                            $flatItem = @{
                                Name = $item.Name
                                FileName = $item.FileName
                                FilePath = $item.FilePath
                                Size = $item.Size
                                SizeGB = $item.SizeGB
                                Type = $item.Type
                                Created = $item.Created
                                Modified = $item.Modified
                            }
                            if ($item.IntegrityVerified) {
                                $flatItem.IntegrityVerified = $item.IntegrityVerified
                                $flatItem.Checksum = $item.Checksum
                            }
                            [PSCustomObject]$flatItem
                        }
                        $flatInventory | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
                    }
                    'XML' {
                        $exportData | ConvertTo-Xml -Depth 10 | Select-Object -ExpandProperty OuterXml | Set-Content $ExportPath -Encoding UTF8
                    }
                }

                Write-CustomLog -Level 'SUCCESS' -Message "Exported inventory of $($inventory.Count) ISOs to: $ExportPath"

                return @{
                    Success = $true
                    ExportPath = $ExportPath
                    Format = $Format
                    TotalISOs = $inventory.Count
                    ExportDate = Get-Date
                }
            }
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to export ISO inventory: $($_.Exception.Message)"
            return @{
                Success = $false
                Error = $_.Exception.Message
                ExportPath = $ExportPath
            }
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Completed ISO inventory export"
    }
}
