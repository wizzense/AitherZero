BeforeAll {
    # Mock Write-CustomLog function
    function global:Write-CustomLog {
        param([string]$Message, [string]$Level = "INFO")
        Write-Host "[$Level] $Message"
    }

    # Import shared utilities for proper path detection
    . "$PSScriptRoot/../../../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot

    # Import the UnifiedMaintenance module
    $unifiedMaintenancePath = Join-Path $projectRoot "aither-core/modules/UnifiedMaintenance"

    try {
        Import-Module $unifiedMaintenancePath -Force -ErrorAction Stop
        Write-Host "UnifiedMaintenance module imported successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to import UnifiedMaintenance module: $_"
        throw
    }
}

Describe "UnifiedMaintenance Module Tests" {
    Context "Module Import" {
        It "Should import without errors" {
            { Import-Module (Join-Path $projectRoot "aither-core/modules/UnifiedMaintenance") -Force } | Should -Not -Throw
        }
    }

    Context "Core Functions" {
        It "Should have exported functions available" {
            $module = Get-Module UnifiedMaintenance
            $module.ExportedFunctions.Keys | Should -Not -BeNullOrEmpty
        }
    }
}
