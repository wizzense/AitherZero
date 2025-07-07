function Get-ProjectVersion {
    [CmdletBinding()]
    param()
    
    try {
        # Try to get version from git tags
        $latestTag = git describe --tags --abbrev=0 2>$null
        if ($latestTag -and $latestTag -match '^v?(\d+\.\d+\.\d+)') {
            return $matches[1]
        }
        
        # Fallback: try to detect from package.json or manifest
        if (Test-Path 'package.json') {
            $package = Get-Content 'package.json' | ConvertFrom-Json
            if ($package.version) {
                return $package.version
            }
        }
        
        # Final fallback
        return "1.0.0"
    }
    catch {
        Write-Warning "Could not determine version: $($_.Exception.Message)"
        return "1.0.0"
    }
}
