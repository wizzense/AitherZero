function Compare-Configuration {
    <#
    .SYNOPSIS
        Compare two configuration objects
    .DESCRIPTION
        Compares two configuration hashtables and returns differences
    .PARAMETER ReferenceConfiguration
        Reference configuration to compare against
    .PARAMETER DifferenceConfiguration
        Configuration to compare with reference
    .PARAMETER IncludeEqual
        Include properties that are equal in both configurations
    .PARAMETER ModuleName
        Optional module name for context in output
    .EXAMPLE
        $differences = Compare-Configuration -ReferenceConfiguration $config1 -DifferenceConfiguration $config2
    .EXAMPLE
        $comparison = Compare-Configuration -ReferenceConfiguration $oldConfig -DifferenceConfiguration $newConfig -IncludeEqual
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$ReferenceConfiguration,
        
        [Parameter(Mandatory)]
        [hashtable]$DifferenceConfiguration,
        
        [Parameter()]
        [switch]$IncludeEqual,
        
        [Parameter()]
        [string]$ModuleName
    )
    
    try {
        $comparison = @{
            ModuleName = $ModuleName
            ComparedAt = Get-Date
            Added = @{}
            Removed = @{}
            Modified = @{}
            Equal = @{}
            Summary = @{
                AddedCount = 0
                RemovedCount = 0
                ModifiedCount = 0
                EqualCount = 0
            }
        }
        
        # Get all unique keys from both configurations
        $allKeys = @()
        $allKeys += $ReferenceConfiguration.Keys
        $allKeys += $DifferenceConfiguration.Keys
        $allKeys = $allKeys | Select-Object -Unique
        
        foreach ($key in $allKeys) {
            $refHasKey = $ReferenceConfiguration.ContainsKey($key)
            $diffHasKey = $DifferenceConfiguration.ContainsKey($key)
            
            if ($refHasKey -and $diffHasKey) {
                # Both have the key, check if values are different
                $refValue = $ReferenceConfiguration[$key]
                $diffValue = $DifferenceConfiguration[$key]
                
                if ($refValue -is [hashtable] -and $diffValue -is [hashtable]) {
                    # Recursively compare nested hashtables
                    $nestedComparison = Compare-Configuration -ReferenceConfiguration $refValue -DifferenceConfiguration $diffValue -IncludeEqual:$IncludeEqual
                    
                    if ($nestedComparison.Summary.AddedCount -gt 0 -or 
                        $nestedComparison.Summary.RemovedCount -gt 0 -or 
                        $nestedComparison.Summary.ModifiedCount -gt 0) {
                        $comparison.Modified[$key] = @{
                            Reference = $refValue
                            Difference = $diffValue
                            NestedComparison = $nestedComparison
                        }
                        $comparison.Summary.ModifiedCount++
                    } elseif ($IncludeEqual) {
                        $comparison.Equal[$key] = $refValue
                        $comparison.Summary.EqualCount++
                    }
                } else {
                    # Compare primitive values
                    if ($refValue -eq $diffValue) {
                        if ($IncludeEqual) {
                            $comparison.Equal[$key] = $refValue
                            $comparison.Summary.EqualCount++
                        }
                    } else {
                        $comparison.Modified[$key] = @{
                            Reference = $refValue
                            Difference = $diffValue
                        }
                        $comparison.Summary.ModifiedCount++
                    }
                }
            } elseif ($refHasKey -and -not $diffHasKey) {
                # Key exists in reference but not in difference (removed)
                $comparison.Removed[$key] = $ReferenceConfiguration[$key]
                $comparison.Summary.RemovedCount++
            } elseif (-not $refHasKey -and $diffHasKey) {
                # Key exists in difference but not in reference (added)
                $comparison.Added[$key] = $DifferenceConfiguration[$key]
                $comparison.Summary.AddedCount++
            }
        }
        
        # Add overall change indicator
        $comparison.HasChanges = ($comparison.Summary.AddedCount -gt 0 -or 
                                 $comparison.Summary.RemovedCount -gt 0 -or 
                                 $comparison.Summary.ModifiedCount -gt 0)
        
        return $comparison
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to compare configurations: $_"
        throw
    }
}