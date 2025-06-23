# PatchManager Demo - Quick Start Examples

# Import project modules
try {
    . "$PSScriptRoot/../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    Import-Module "$projectRoot/aither-core/modules/Logging" -Force -ErrorAction SilentlyContinue
} catch {
    # Mock Write-CustomLog if Logging module is not available
    function Write-CustomLog {
        param([string]$Message, [string]$Level = "INFO")
        Write-Verbose "[$Level] $Message"
    }
}

# Example 1: Basic Demo
Write-CustomLog -Level 'INFO' -Message "Running Basic PatchManager Demo..."
.\demo-patchmanager.ps1 -DemoMode Basic -DryRun

Write-CustomLog -Level 'INFO' -Message ("="*50)

# Example 2: Interactive Advanced Demo
Write-CustomLog -Level 'INFO' -Message "Running Advanced Demo (Interactive)..."
.\demo-patchmanager.ps1 -DemoMode Advanced -Interactive -DryRun

Write-CustomLog -Level 'INFO' -Message ("="*50)

# Example 3: Full Demo Suite
Write-CustomLog -Level 'INFO' -Message "Running Complete Demo Suite..."
.\demo-patchmanager.ps1 -DemoMode All -DryRun

Write-CustomLog -Level 'SUCCESS' -Message "Demo examples completed!"
