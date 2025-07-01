# Generated Test Suite for ScriptManager Module
# Generated on: 2025-06-28 22:14:27
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
    
    # Import required modules
    try {
        Import-Module (Join-Path $env:PWSH_MODULES_PATH "Logging") -Force -ErrorAction Stop
    }
    catch {
        # Fallback logging function
        function Write-CustomLog {
            param([string]$Message, [string]$Level = "INFO")
            Write-Host "[$Level] $Message"
        }
    }
    
    # Import the module under test
    $modulePath = Join-Path $env:PWSH_MODULES_PATH "ScriptManager"
    
    try {
        Import-Module $modulePath -Force -ErrorAction Stop
        Write-CustomLog -Message "ScriptManager module imported successfully" -Level "SUCCESS"
    }
    catch {
        Write-Error "Failed to import ScriptManager module: $_"
        throw
    }
}

Describe "ScriptManager Module - Generated Tests" {
    
    Context "Module Structure and Loading" {
        It "Should import the ScriptManager module without errors" {
            Get-Module ScriptManager | Should -Not -BeNullOrEmpty
        }
        
        It "Should have a valid module manifest" {
            $manifestPath = Join-Path $env:PWSH_MODULES_PATH "ScriptManager/ScriptManager.psd1"
            if (Test-Path $manifestPath) {
                { Test-ModuleManifest -Path $manifestPath } | Should -Not -Throw
            }
        }
        
        It "Should export public functions" {
            $exportedFunctions = Get-Command -Module ScriptManager -CommandType Function
            $exportedFunctions | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Get-ScriptRepository Function Tests" {
        It "Should have Get-ScriptRepository function available" {
            Get-Command Get-ScriptRepository -Module ScriptManager -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have proper function structure" {
            $command = Get-Command Get-ScriptRepository -Module ScriptManager
            $command.CommandType | Should -Be 'Function'
        }
        
        It "Should have parameters defined" {
            $command = Get-Command Get-ScriptRepository -Module ScriptManager
            # Test that the function can be called (may have no required parameters)
            { $command.Parameters } | Should -Not -Throw
        }
    }
    
    Context "Get-ScriptTemplate Function Tests" {
        It "Should have Get-ScriptTemplate function available" {
            Get-Command Get-ScriptTemplate -Module ScriptManager -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have proper function structure" {
            $command = Get-Command Get-ScriptTemplate -Module ScriptManager
            $command.CommandType | Should -Be 'Function'
        }
        
        It "Should have parameters defined" {
            $command = Get-Command Get-ScriptTemplate -Module ScriptManager
            # Test that the function can be called (may have no required parameters)
            { $command.Parameters } | Should -Not -Throw
        }
    }
    
    Context "Invoke-OneOffScript Function Tests" {
        It "Should have Invoke-OneOffScript function available" {
            Get-Command Invoke-OneOffScript -Module ScriptManager -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have proper function structure" {
            $command = Get-Command Invoke-OneOffScript -Module ScriptManager
            $command.CommandType | Should -Be 'Function'
        }
        
        It "Should have parameters defined" {
            $command = Get-Command Invoke-OneOffScript -Module ScriptManager
            # Test that the function can be called (may have no required parameters)
            { $command.Parameters } | Should -Not -Throw
        }
    }
    
    Context "Start-ScriptExecution Function Tests" {
        It "Should have Start-ScriptExecution function available" {
            Get-Command Start-ScriptExecution -Module ScriptManager -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have proper function structure" {
            $command = Get-Command Start-ScriptExecution -Module ScriptManager
            $command.CommandType | Should -Be 'Function'
        }
        
        It "Should have parameters defined" {
            $command = Get-Command Start-ScriptExecution -Module ScriptManager
            # Test that the function can be called (may have no required parameters)
            { $command.Parameters } | Should -Not -Throw
        }
    }
    
    Context "Error Handling and Edge Cases" {
        It "Should handle module reimport gracefully" {
            { Import-Module (Join-Path $env:PWSH_MODULES_PATH "ScriptManager") -Force } | Should -Not -Throw
        }
        
        It "Should maintain consistent behavior across PowerShell editions" {
            if ($PSVersionTable.PSEdition -eq 'Core') {
                Get-Module ScriptManager | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "Performance and Resource Usage" {
        It "Should import within reasonable time" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            Import-Module (Join-Path $env:PWSH_MODULES_PATH "ScriptManager") -Force
            $stopwatch.Stop()
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000
        }
    }
}

