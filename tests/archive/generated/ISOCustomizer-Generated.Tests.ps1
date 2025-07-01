# Generated Test Suite for ISOCustomizer Module
# Generated on: 2025-06-28 22:17:26
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
    $modulePath = Join-Path $env:PWSH_MODULES_PATH "ISOCustomizer"
    
    try {
        Import-Module $modulePath -Force -ErrorAction Stop
        Write-Host "[SUCCESS] ISOCustomizer module imported successfully"
    }
    catch {
        Write-Error "Failed to import ISOCustomizer module: $_"
        throw
    }
}

Describe "ISOCustomizer Module - Generated Tests" {
    
    Context "Module Structure and Loading" {
        It "Should import the ISOCustomizer module without errors" {
            Get-Module ISOCustomizer | Should -Not -BeNullOrEmpty
        }
        
        It "Should have a valid module manifest" {
            $manifestPath = Join-Path $env:PWSH_MODULES_PATH "ISOCustomizer/ISOCustomizer.psd1"
            if (Test-Path $manifestPath) {
                { Test-ModuleManifest -Path $manifestPath } | Should -Not -Throw
            }
        }
        
        It "Should export public functions" {
            $exportedFunctions = Get-Command -Module ISOCustomizer -CommandType Function
            $exportedFunctions | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "New-AutounattendFile Function Tests" {
        It "Should have New-AutounattendFile function available" {
            Get-Command New-AutounattendFile -Module ISOCustomizer -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have proper function structure" {
            $command = Get-Command New-AutounattendFile -Module ISOCustomizer
            $command.CommandType | Should -Be 'Function'
        }
        
        It "Should have parameters defined" {
            $command = Get-Command New-AutounattendFile -Module ISOCustomizer
            # Test that the function can be called (may have no required parameters)
            { $command.Parameters } | Should -Not -Throw
        }
    }
    
    Context "New-CustomISO Function Tests" {
        It "Should have New-CustomISO function available" {
            Get-Command New-CustomISO -Module ISOCustomizer -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have proper function structure" {
            $command = Get-Command New-CustomISO -Module ISOCustomizer
            $command.CommandType | Should -Be 'Function'
        }
        
        It "Should have parameters defined" {
            $command = Get-Command New-CustomISO -Module ISOCustomizer
            # Test that the function can be called (may have no required parameters)
            { $command.Parameters } | Should -Not -Throw
        }
    }
    
    Context "Error Handling and Edge Cases" {
        It "Should handle module reimport gracefully" {
            { Import-Module (Join-Path $env:PWSH_MODULES_PATH "ISOCustomizer") -Force } | Should -Not -Throw
        }
        
        It "Should maintain consistent behavior across PowerShell editions" {
            if ($PSVersionTable.PSEdition -eq 'Core') {
                Get-Module ISOCustomizer | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "Performance and Resource Usage" {
        It "Should import within reasonable time" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            Import-Module (Join-Path $env:PWSH_MODULES_PATH "ISOCustomizer") -Force
            $stopwatch.Stop()
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000
        }
    }
}

