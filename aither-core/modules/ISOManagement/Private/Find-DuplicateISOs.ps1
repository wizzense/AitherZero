function Find-DuplicateISOs {
    <#
    .SYNOPSIS
        Finds duplicate ISO files based on checksum comparison.
    
    .DESCRIPTION
        Analyzes an inventory of ISO files to identify duplicates based on
        SHA256 checksum comparison with intelligent deduplication logic.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Inventory
    )
    
    try {
        Write-CustomLog -Level 'INFO' -Message "Analyzing $($Inventory.Count) files for duplicates"
        
        $duplicates = @()
        $checksumGroups = @{}
        
        # Calculate checksums for files that don't have them
        foreach ($item in $Inventory) {
            if (-not $item.Checksum) {
                try {
                    $hash = Get-FileHash -Path $item.FilePath -Algorithm SHA256
                    $item | Add-Member -NotePropertyName 'Checksum' -NotePropertyValue $hash.Hash -Force
                } catch {
                    Write-CustomLog -Level 'WARN' -Message "Failed to calculate checksum for $($item.FileName): $($_.Exception.Message)"
                    continue
                }
            }
            
            # Group by checksum
            if (-not $checksumGroups.ContainsKey($item.Checksum)) {
                $checksumGroups[$item.Checksum] = @()
            }
            $checksumGroups[$item.Checksum] += $item
        }
        
        # Find groups with multiple files (duplicates)
        foreach ($checksum in $checksumGroups.Keys) {
            $group = $checksumGroups[$checksum]
            if ($group.Count -gt 1) {
                # Sort by modification date to keep the newest
                $sortedGroup = $group | Sort-Object Modified -Descending
                
                # Mark all but the first (newest) as duplicates
                for ($i = 1; $i -lt $sortedGroup.Count; $i++) {
                    $duplicate = $sortedGroup[$i]
                    $duplicate | Add-Member -NotePropertyName 'DuplicateOf' -NotePropertyValue $sortedGroup[0].FilePath -Force
                    $duplicates += $duplicate
                }
                
                Write-CustomLog -Level 'INFO' -Message "Found duplicate group: $($group.Count) files with checksum $checksum"
            }
        }
        
        Write-CustomLog -Level 'INFO' -Message "Found $($duplicates.Count) duplicate files"
        return $duplicates
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to find duplicates: $($_.Exception.Message)"
        return @()
    }
}