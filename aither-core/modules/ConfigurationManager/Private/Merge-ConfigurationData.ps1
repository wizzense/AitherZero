# Private helper function for merging configuration data
function Merge-ConfigurationData {
    <#
    .SYNOPSIS
        Merges configuration data with conflict resolution
    .DESCRIPTION
        Private function that handles merging of configuration data from different sources
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$SourceConfiguration,
        
        [Parameter(Mandatory)]
        [hashtable]$TargetConfiguration,
        
        [ValidateSet('Overwrite', 'Preserve', 'Merge', 'Prompt')]
        [string]$ConflictStrategy = 'Merge',
        
        [string]$SourceName = 'Unknown',
        
        [switch]$DeepMerge
    )
    
    try {
        $mergeResult = @{
            Success = $true
            MergedKeys = @()
            Conflicts = @()
            Errors = @()
            SourceName = $SourceName
            Strategy = $ConflictStrategy
        }
        
        foreach ($key in $SourceConfiguration.Keys) {
            $sourceValue = $SourceConfiguration[$key]
            $targetHasKey = $TargetConfiguration.ContainsKey($key)
            
            if (-not $targetHasKey) {
                # No conflict - add new key
                $TargetConfiguration[$key] = $sourceValue
                $mergeResult.MergedKeys += "$key (new)"
                
            } else {
                # Conflict detected
                $targetValue = $TargetConfiguration[$key]
                $conflict = @{
                    Key = $key
                    SourceValue = $sourceValue
                    TargetValue = $targetValue
                    Resolution = $null
                }
                
                switch ($ConflictStrategy) {
                    'Overwrite' {
                        $TargetConfiguration[$key] = $sourceValue
                        $conflict.Resolution = 'Overwrote with source value'
                        $mergeResult.MergedKeys += "$key (overwritten)"
                    }
                    
                    'Preserve' {
                        # Keep target value, do nothing
                        $conflict.Resolution = 'Preserved target value'
                        $mergeResult.MergedKeys += "$key (preserved)"
                    }
                    
                    'Merge' {
                        if ($DeepMerge -and $sourceValue -is [hashtable] -and $targetValue -is [hashtable]) {
                            # Recursive merge for hashtables
                            $deepMergeResult = Merge-ConfigurationData -SourceConfiguration $sourceValue -TargetConfiguration $targetValue -ConflictStrategy $ConflictStrategy -SourceName $SourceName -DeepMerge
                            if ($deepMergeResult.Success) {
                                $conflict.Resolution = 'Deep merged hashtables'
                                $mergeResult.MergedKeys += "$key (deep merged)"
                            } else {
                                $mergeResult.Errors += "Deep merge failed for key '$key': $($deepMergeResult.Errors -join '; ')"
                                $conflict.Resolution = 'Deep merge failed - preserved target'
                            }
                        } elseif ($sourceValue -is [array] -and $targetValue -is [array]) {
                            # Merge arrays by combining unique values
                            $combinedArray = @($targetValue) + @($sourceValue) | Sort-Object -Unique
                            $TargetConfiguration[$key] = $combinedArray
                            $conflict.Resolution = 'Merged arrays (unique values)'
                            $mergeResult.MergedKeys += "$key (array merged)"
                        } else {
                            # For other types, prefer source value in merge mode
                            $TargetConfiguration[$key] = $sourceValue
                            $conflict.Resolution = 'Used source value (type mismatch or simple value)'
                            $mergeResult.MergedKeys += "$key (merged-source)"
                        }
                    }
                    
                    'Prompt' {
                        # In automated mode, we can't actually prompt, so we preserve and log the conflict
                        $conflict.Resolution = 'Requires manual resolution'
                        $mergeResult.MergedKeys += "$key (requires resolution)"
                        Write-ConfigurationLog -Level 'WARNING' -Message "Configuration conflict for key '$key' requires manual resolution"
                    }
                }
                
                $mergeResult.Conflicts += $conflict
            }
        }
        
        Write-ConfigurationLog -Level 'DEBUG' -Message "Merged $($mergeResult.MergedKeys.Count) keys from $SourceName using strategy: $ConflictStrategy"
        
        return $mergeResult
        
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            MergedKeys = @()
            Conflicts = @()
            Errors = @("Merge operation failed: $($_.Exception.Message)")
            SourceName = $SourceName
            Strategy = $ConflictStrategy
        }
    }
}