function Compare-DeploymentSnapshots {
    <#
    .SYNOPSIS
        Compares two deployment snapshots to identify changes
    .DESCRIPTION
        Performs deep comparison between deployment snapshots showing resource
        additions, deletions, modifications, and configuration drift
    .PARAMETER ReferenceSnapshot
        Path or ID of the reference (baseline) snapshot
    .PARAMETER DifferenceSnapshot
        Path or ID of the difference (comparison) snapshot
    .PARAMETER IncludeUnchanged
        Include unchanged resources in output
    .PARAMETER OutputFormat
        Format for comparison output (Table, JSON, Report)
    .EXAMPLE
        Compare-DeploymentSnapshots -ReferenceSnapshot "snapshot-20250629-120000" -DifferenceSnapshot "snapshot-20250629-180000"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ReferenceSnapshot,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DifferenceSnapshot,

        [Parameter()]
        [switch]$IncludeUnchanged,

        [Parameter()]
        [ValidateSet('Table', 'JSON', 'Report')]
        [string]$OutputFormat = 'Table'
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Comparing deployment snapshots"

        # Load snapshots
        $refSnapshot = Get-SnapshotData -Identifier $ReferenceSnapshot
        $diffSnapshot = Get-SnapshotData -Identifier $DifferenceSnapshot

        # Initialize comparison result
        $comparison = @{
            ReferenceId = $refSnapshot.SnapshotId
            DifferenceId = $diffSnapshot.SnapshotId
            ReferenceTime = $refSnapshot.Timestamp
            DifferenceTime = $diffSnapshot.Timestamp
            Summary = @{
                Added = 0
                Removed = 0
                Modified = 0
                Unchanged = 0
            }
            Changes = @{
                Added = @()
                Removed = @()
                Modified = @()
                Unchanged = @()
            }
        }

        # Build resource maps for comparison
        $refResources = @{}
        foreach ($resource in $refSnapshot.Resources) {
            $key = "$($resource.Type).$($resource.Name)"
            $refResources[$key] = $resource
        }

        $diffResources = @{}
        foreach ($resource in $diffSnapshot.Resources) {
            $key = "$($resource.Type).$($resource.Name)"
            $diffResources[$key] = $resource
        }

        # Find removed resources
        foreach ($key in $refResources.Keys) {
            if (-not $diffResources.ContainsKey($key)) {
                $comparison.Changes.Removed += @{
                    Type = $refResources[$key].Type
                    Name = $refResources[$key].Name
                    Details = "Resource removed"
                }
                $comparison.Summary.Removed++
            }
        }

        # Find added and modified resources
        foreach ($key in $diffResources.Keys) {
            if (-not $refResources.ContainsKey($key)) {
                # Added resource
                $comparison.Changes.Added += @{
                    Type = $diffResources[$key].Type
                    Name = $diffResources[$key].Name
                    Details = "Resource added"
                }
                $comparison.Summary.Added++
            }
            else {
                # Compare resource attributes
                $refResource = $refResources[$key]
                $diffResource = $diffResources[$key]

                $changes = Compare-ResourceAttributes -Reference $refResource -Difference $diffResource

                if ($changes.Count -gt 0) {
                    $comparison.Changes.Modified += @{
                        Type = $diffResource.Type
                        Name = $diffResource.Name
                        Changes = $changes
                    }
                    $comparison.Summary.Modified++
                }
                elseif ($IncludeUnchanged) {
                    $comparison.Changes.Unchanged += @{
                        Type = $diffResource.Type
                        Name = $diffResource.Name
                    }
                    $comparison.Summary.Unchanged++
                }
            }
        }

        # Format output
        switch ($OutputFormat) {
            'Table' {
                Write-Host "`nSnapshot Comparison Summary:" -ForegroundColor Cyan
                Write-Host "Reference: $($comparison.ReferenceId) ($($comparison.ReferenceTime))"
                Write-Host "Difference: $($comparison.DifferenceId) ($($comparison.DifferenceTime))"
                Write-Host "`nChanges:" -ForegroundColor Yellow
                Write-Host "  Added:     $($comparison.Summary.Added)" -ForegroundColor Green
                Write-Host "  Removed:   $($comparison.Summary.Removed)" -ForegroundColor Red
                Write-Host "  Modified:  $($comparison.Summary.Modified)" -ForegroundColor Yellow
                if ($IncludeUnchanged) {
                    Write-Host "  Unchanged: $($comparison.Summary.Unchanged)" -ForegroundColor Gray
                }

                if ($comparison.Changes.Added.Count -gt 0) {
                    Write-Host "`nAdded Resources:" -ForegroundColor Green
                    $comparison.Changes.Added | ForEach-Object {
                        Write-Host "  + $($_.Type).$($_.Name)"
                    }
                }

                if ($comparison.Changes.Removed.Count -gt 0) {
                    Write-Host "`nRemoved Resources:" -ForegroundColor Red
                    $comparison.Changes.Removed | ForEach-Object {
                        Write-Host "  - $($_.Type).$($_.Name)"
                    }
                }

                if ($comparison.Changes.Modified.Count -gt 0) {
                    Write-Host "`nModified Resources:" -ForegroundColor Yellow
                    $comparison.Changes.Modified | ForEach-Object {
                        Write-Host "  ~ $($_.Type).$($_.Name)"
                        $_.Changes | ForEach-Object {
                            Write-Host "    $($_.Property): $($_.OldValue) -> $($_.NewValue)" -ForegroundColor DarkYellow
                        }
                    }
                }
            }

            'JSON' {
                $comparison | ConvertTo-Json -Depth 10
            }

            'Report' {
                $reportPath = Join-Path $PSScriptRoot "../../reports"
                if (-not (Test-Path $reportPath)) {
                    New-Item -ItemType Directory -Path $reportPath -Force | Out-Null
                }

                $reportFile = Join-Path $reportPath "snapshot-comparison-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
                $comparison | ConvertTo-Json -Depth 10 | Set-Content -Path $reportFile -Encoding UTF8

                Write-CustomLog -Level 'SUCCESS' -Message "Comparison report saved: $reportFile"
                return $reportFile
            }
        }

        return $comparison
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to compare snapshots: $_"
        throw
    }
}

# Helper function to load snapshot data
function Get-SnapshotData {
    param([string]$Identifier)

    $snapshotPath = Join-Path $PSScriptRoot "../../snapshots"

    # Check if identifier is a path
    if (Test-Path $Identifier) {
        $content = Get-Content $Identifier -Raw
        return $content | ConvertFrom-Json
    }

    # Search for snapshot by ID
    $files = Get-ChildItem -Path $snapshotPath -Filter "*$Identifier*" -File
    if ($files.Count -eq 0) {
        throw "Snapshot not found: $Identifier"
    }
    elseif ($files.Count -gt 1) {
        throw "Multiple snapshots match identifier: $Identifier"
    }

    $content = Get-Content $files[0].FullName -Raw
    return $content | ConvertFrom-Json
}

# Helper function to compare resource attributes
function Compare-ResourceAttributes {
    param($Reference, $Difference)

    $changes = @()

    # Compare instance counts
    if ($Reference.Instances.Count -ne $Difference.Instances.Count) {
        $changes += @{
            Property = "InstanceCount"
            OldValue = $Reference.Instances.Count
            NewValue = $Difference.Instances.Count
        }
    }

    # Compare first instance attributes (simplified)
    if ($Reference.Instances.Count -gt 0 -and $Difference.Instances.Count -gt 0) {
        $refAttrs = $Reference.Instances[0].Attributes
        $diffAttrs = $Difference.Instances[0].Attributes

        # Get all unique property names
        $allProps = @()
        $allProps += if ($refAttrs -is [hashtable]) { $refAttrs.Keys } else { $refAttrs.PSObject.Properties.Name }
        $allProps += if ($diffAttrs -is [hashtable]) { $diffAttrs.Keys } else { $diffAttrs.PSObject.Properties.Name }
        $allProps = $allProps | Select-Object -Unique

        foreach ($prop in $allProps) {
            $refValue = if ($refAttrs -is [hashtable]) { $refAttrs[$prop] } else { $refAttrs.$prop }
            $diffValue = if ($diffAttrs -is [hashtable]) { $diffAttrs[$prop] } else { $diffAttrs.$prop }

            if ($refValue -ne $diffValue) {
                $changes += @{
                    Property = $prop
                    OldValue = $refValue
                    NewValue = $diffValue
                }
            }
        }
    }

    return $changes
}
