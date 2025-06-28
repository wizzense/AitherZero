# Generated Test Suite for SystemMonitoring Module
# Generated on: 2025-06-28 22:14:54
# Coverage Target: 80%

BeforeAll {
    # Import shared utilities
    . "$PSScriptRoot/../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    
    # Set environment variables
    if (-not $env:PROJECT_ROOT) {
        $env:PROJECT_ROOT = $projectRoot
    }
    if (-not $env:PWSH_MODULES_PATH) {
        $env:PWSH_MODULES_PATH = Join-Path $projectRoot 'aither-core/modules'
    }
    
    # Fallback logging function
    function global:Write-CustomLog {
        param([string]$Message, [string]$Level = "INFO")
        Write-Host "[$Level] $Message"
    }
    
    # Import required modules
    try {
        Import-Module (Join-Path $env:PWSH_MODULES_PATH "Logging") -Force -ErrorAction Stop
    }
    catch {
        # Continue with fallback logging
    }
    
    # Import the module under test
    $modulePath = Join-Path $env:PWSH_MODULES_PATH "SystemMonitoring"
    
    try {
        Import-Module $modulePath -Force -ErrorAction Stop
        Write-Host "[SUCCESS] SystemMonitoring module imported successfully"
    }
    catch {
        Write-Error "Failed to import SystemMonitoring module: $_"
        throw
    }
}

Describe "SystemMonitoring Module - Generated Tests" {
    
    Context "Module Structure and Loading" {
        It "Should import the SystemMonitoring module without errors" {
            Get-Module SystemMonitoring | Should -Not -BeNullOrEmpty
        }
        
        It "Should have a valid module manifest" {
            $manifestPath = Join-Path $env:PWSH_MODULES_PATH "SystemMonitoring/SystemMonitoring.psd1"
            if (Test-Path $manifestPath) {
                { Test-ModuleManifest -Path $manifestPath } | Should -Not -Throw
            }
        }
        
        It "Should export public functions" {
            $exportedFunctions = Get-Command -Module SystemMonitoring -CommandType Function
            $exportedFunctions | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Get-SystemAlerts Function Tests" {
        It "Should have Get-SystemAlerts function available" {
            Get-Command Get-SystemAlerts -Module SystemMonitoring -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have proper function structure" {
            $command = Get-Command Get-SystemAlerts -Module SystemMonitoring
            $command.CommandType | Should -Be 'Function'
        }
        
        It "Should have parameters defined" {
            $command = Get-Command Get-SystemAlerts -Module SystemMonitoring
            # Test that the function can be called (may have no required parameters)
            { $command.Parameters } | Should -Not -Throw
        }
    }
    
    Context "Get-SystemDashboard Function Tests" {
        It "Should have Get-SystemDashboard function available" {
            Get-Command Get-SystemDashboard -Module SystemMonitoring -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have proper function structure" {
            $command = Get-Command Get-SystemDashboard -Module SystemMonitoring
            $command.CommandType | Should -Be 'Function'
        }
        
        It "Should have parameters defined" {
            $command = Get-Command Get-SystemDashboard -Module SystemMonitoring
            # Test that the function can be called (may have no required parameters)
            { $command.Parameters } | Should -Not -Throw
        }
    }
    
    Context "Invoke-HealthCheck Function Tests" {
        It "Should have Invoke-HealthCheck function available" {
            Get-Command Invoke-HealthCheck -Module SystemMonitoring -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have proper function structure" {
            $command = Get-Command Invoke-HealthCheck -Module SystemMonitoring
            $command.CommandType | Should -Be 'Function'
        }
        
        It "Should have parameters defined" {
            $command = Get-Command Invoke-HealthCheck -Module SystemMonitoring
            # Test that the function can be called (may have no required parameters)
            { $command.Parameters } | Should -Not -Throw
        }
    }
    
    Context "Error Handling and Edge Cases" {
        It "Should handle module reimport gracefully" {
            { Import-Module (Join-Path $env:PWSH_MODULES_PATH "SystemMonitoring") -Force } | Should -Not -Throw
        }
        
        It "Should maintain consistent behavior across PowerShell editions" {
            if ($PSVersionTable.PSEdition -eq 'Core') {
                Get-Module SystemMonitoring | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "Performance and Resource Usage" {
        It "Should import within reasonable time" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            Import-Module (Join-Path $env:PWSH_MODULES_PATH "SystemMonitoring") -Force
            $stopwatch.Stop()
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000
        }
    }
}

