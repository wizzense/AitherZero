BeforeAll {
    # Mock Write-CustomLog function
    function global:Write-CustomLog {
        param([string]$Message, [string]$Level = "INFO")
        Write-Host "[$Level] $Message"
    }
    
    # Import the DevEnvironment module
    $projectRoot = $env:PROJECT_ROOT
    $devEnvironmentPath = Join-Path $projectRoot "aither-core/modules/DevEnvironment"
    
    try {
        Import-Module $devEnvironmentPath -Force -ErrorAction Stop
        Write-Host "DevEnvironment module imported successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to import DevEnvironment module: $_"
        throw
    }
}

Describe "DevEnvironment Module Tests" {
    Context "Module Import" {
        It "Should import without errors" {
            { Import-Module (Join-Path $projectRoot "aither-core/modules/DevEnvironment") -Force } | Should -Not -Throw
        }
    }
    
    Context "Core Functions" {
        It "Should have exported functions available" {
            $module = Get-Module DevEnvironment
            $module.ExportedFunctions.Keys | Should -Not -BeNullOrEmpty
        }
    }
}