function Import-ISOInventory {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$ImportPath,

        [Parameter(Mandatory = $false)]
        [string]$TargetRepositoryPath,

        [Parameter(Mandatory = $false)]
        [switch]$ValidateFiles,

        [Parameter(Mandatory = $false)]
        [switch]$CreateMissingDirectories
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Importing ISO inventory from: $ImportPath"
    }

    process {
        try {
            # Determine import format based on file extension
            $fileExtension = (Split-Path $ImportPath -Extension).ToLower()
            $format = switch ($fileExtension) {
                '.json' { 'JSON' }
                '.csv' { 'CSV' }
                '.xml' { 'XML' }
                default { throw "Unsupported import format: $fileExtension" }
            }

            Write-CustomLog -Level 'INFO' -Message "Importing from $format format"

            # Read and parse the import file
            $importData = switch ($format) {
                'JSON' {
                    Get-Content $ImportPath -Raw | ConvertFrom-Json
                }
                'CSV' {
                    # For CSV, we need to reconstruct the structure
                    $csvData = Import-Csv $ImportPath
                    @{
                        ExportInfo = @{
                            ImportDate = Get-Date
                            OriginalFormat = 'CSV'
                            TotalISOs = $csvData.Count
                        }
                        Inventory = $csvData
                    }
                }
                'XML' {
                    [xml]$xmlContent = Get-Content $ImportPath -Raw
                    # Convert XML back to PowerShell object (this is complex, simplified approach)
                    $xmlContent
                }
            }

            $inventory = if ($importData.Inventory) { $importData.Inventory } else { $importData }

            if (-not $inventory -or $inventory.Count -eq 0) {
                throw "No inventory data found in import file"
            }

            Write-CustomLog -Level 'INFO' -Message "Found $($inventory.Count) ISO entries in import file"

            $importResults = @{
                TotalEntries = $inventory.Count
                ValidatedFiles = 0
                MissingFiles = 0
                InvalidFiles = 0
                CreatedDirectories = 0
                Errors = @()
            }

            if ($PSCmdlet.ShouldProcess($ImportPath, "Import ISO Inventory")) {
                foreach ($item in $inventory) {
                    try {
                        $filePath = $item.FilePath

                        # Update file path if target repository is specified
                        if ($TargetRepositoryPath) {
                            $fileName = Split-Path $filePath -Leaf
                            $isoType = if ($item.Type) { $item.Type } else { 'Custom' }
                            $filePath = Join-Path $TargetRepositoryPath $isoType $fileName
                        }

                        # Create missing directories if requested
                        if ($CreateMissingDirectories) {
                            $directory = Split-Path $filePath -Parent
                            if ($directory -and -not (Test-Path $directory)) {
                                New-Item -ItemType Directory -Path $directory -Force | Out-Null
                                $importResults.CreatedDirectories++
                                Write-CustomLog -Level 'INFO' -Message "Created directory: $directory"
                            }
                        }

                        # Validate files if requested
                        if ($ValidateFiles) {
                            if (Test-Path $filePath) {
                                $importResults.ValidatedFiles++

                                # Additional validation if checksum is available
                                if ($item.Checksum) {
                                    $actualHash = (Get-FileHash -Path $filePath -Algorithm SHA256).Hash
                                    if ($actualHash -ne $item.Checksum) {
                                        $importResults.InvalidFiles++
                                        $importResults.Errors += "Checksum mismatch for $filePath"
                                        Write-CustomLog -Level 'WARN' -Message "Checksum mismatch for: $filePath"
                                    }
                                }
                            } else {
                                $importResults.MissingFiles++
                                $importResults.Errors += "File not found: $filePath"
                                Write-CustomLog -Level 'WARN' -Message "File not found: $filePath"
                            }
                        }
                    } catch {
                        $importResults.Errors += "Error processing $($item.FileName): $($_.Exception.Message)"
                        Write-CustomLog -Level 'WARN' -Message "Error processing $($item.FileName): $($_.Exception.Message)"
                    }
                }

                # Save import results to metadata if target repository is specified
                if ($TargetRepositoryPath) {
                    $metadataPath = Join-Path $TargetRepositoryPath "Metadata"
                    if (Test-Path $metadataPath) {
                        $importResultsPath = Join-Path $metadataPath "import-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
                        @{
                            ImportInfo = @{
                                ImportDate = Get-Date
                                SourceFile = $ImportPath
                                TargetRepository = $TargetRepositoryPath
                            }
                            Results = $importResults
                            ImportedInventory = $inventory
                        } | ConvertTo-Json -Depth 10 | Set-Content $importResultsPath
                        Write-CustomLog -Level 'INFO' -Message "Import results saved to: $importResultsPath"
                    }
                }

                Write-CustomLog -Level 'SUCCESS' -Message "Imported inventory with $($importResults.ValidatedFiles) validated files"
                return $importResults
            }
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to import ISO inventory: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Completed ISO inventory import"
    }
}
