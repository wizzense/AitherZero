BeforeAll {
    # Mock Write-CustomLog function
    function global:Write-CustomLog {
        param([string]$Message, [string]$Level = "INFO")
        Write-Host "[$Level] $Message"
    }
    
    # Find project root using robust detection
    $projectRoot = if ($env:PROJECT_ROOT) { 
        $env:PROJECT_ROOT 
    } elseif (Test-Path '/workspaces/AitherLabs') { 
        '/workspaces/AitherLabs' 
    } else { 
        Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))) 
    }
    
    # Import the UnifiedMaintenance module
    $unifiedMaintenancePath = Join-Path $projectRoot "$env:PWSH_MODULES_PATH/UnifiedMaintenance"
    
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
            { Import-Module (Join-Path $projectRoot "$env:PWSH_MODULES_PATH/UnifiedMaintenance") -Force } | Should -Not -Throw
        }
    }
    
    Context "Core Functions" {
        It "Should have exported functions available" {
            $module = Get-Module UnifiedMaintenance
            $module.ExportedFunctions.Keys | Should -Not -BeNullOrEmpty
        }
    }
}
