#Requires -Version 7.0

BeforeAll {
    # Import the module being tested
    $modulePath = Join-Path $PSScriptRoot ".." "ProgressTracking.psm1"
    Import-Module $modulePath -Force -ErrorAction Stop
}

Describe "ProgressTracking Module Tests" {
    Context "Module Loading" {
        It "Should import module successfully" {
            Get-Module ProgressTracking | Should -Not -BeNullOrEmpty
        }
        
        It "Should have valid manifest" {
            $manifestPath = Join-Path $PSScriptRoot ".." "ProgressTracking.psd1"
            Test-Path $manifestPath | Should -Be $true
            
            { Test-ModuleManifest $manifestPath } | Should -Not -Throw
        }
        
        It "Should export expected functions" {
            $expectedFunctions = @(
                'Start-ProgressOperation',
                'Update-ProgressOperation', 
                'Complete-ProgressOperation',
                'Add-ProgressWarning',
                'Add-ProgressError',
                'Write-ProgressLog',
                'Get-ActiveOperations',
                'Start-MultiProgress',
                'Show-SimpleProgress'
            )
            
            foreach ($function in $expectedFunctions) {
                Get-Command $function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "Show-SimpleProgress Function Tests" {
        It "Should display Start progress correctly" {
            { Show-SimpleProgress -Message "Starting test" -Type Start } | Should -Not -Throw
        }
        
        It "Should display Update progress correctly" {
            { Show-SimpleProgress -Message "Updating test" -Type Update } | Should -Not -Throw
        }
        
        It "Should display Complete progress correctly" {
            { Show-SimpleProgress -Message "Completing test" -Type Complete } | Should -Not -Throw
        }
        
        It "Should default to Update type when not specified" {
            { Show-SimpleProgress -Message "Default test" } | Should -Not -Throw
        }
        
        It "Should validate Type parameter values" {
            { Show-SimpleProgress -Message "Invalid test" -Type "Invalid" } | Should -Throw
        }
    }
    
    Context "Progress Operation Tests" {
        It "Should start a progress operation successfully" {
            $operationId = Start-ProgressOperation -OperationName "Test Operation" -TotalSteps 5
            $operationId | Should -Not -BeNullOrEmpty
            $operationId | Should -BeOfType [string]
        }
        
        It "Should update progress operation successfully" {
            $operationId = Start-ProgressOperation -OperationName "Update Test" -TotalSteps 3
            { Update-ProgressOperation -OperationId $operationId -CurrentStep 1 -StepName "First step" } | Should -Not -Throw
            { Update-ProgressOperation -OperationId $operationId -IncrementStep -StepName "Second step" } | Should -Not -Throw
        }
        
        It "Should complete progress operation successfully" {
            $operationId = Start-ProgressOperation -OperationName "Complete Test" -TotalSteps 2
            Update-ProgressOperation -OperationId $operationId -CurrentStep 2 -StepName "Final step"
            { Complete-ProgressOperation -OperationId $operationId } | Should -Not -Throw
        }
        
        It "Should handle invalid operation ID gracefully" {
            $invalidId = [guid]::NewGuid().ToString()
            { Update-ProgressOperation -OperationId $invalidId -CurrentStep 1 } | Should -Not -Throw
        }
    }
    
    Context "Multi-Progress Tests" {
        It "Should start multiple progress operations" {
            $operations = @(
                @{ Name = "Operation 1"; Steps = 3 },
                @{ Name = "Operation 2"; Steps = 5 }
            )
            
            $result = Start-MultiProgress -Title "Multi Test" -Operations $operations
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
            $result["Operation 1"] | Should -Not -BeNullOrEmpty
            $result["Operation 2"] | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Progress Logging Tests" {
        It "Should add warnings to progress operation" {
            $operationId = Start-ProgressOperation -OperationName "Warning Test" -TotalSteps 1
            { Add-ProgressWarning -OperationId $operationId -Warning "Test warning" } | Should -Not -Throw
        }
        
        It "Should add errors to progress operation" {
            $operationId = Start-ProgressOperation -OperationName "Error Test" -TotalSteps 1
            { Add-ProgressError -OperationId $operationId -Error "Test error" } | Should -Not -Throw
        }
        
        It "Should write progress log messages" {
            $operationId = Start-ProgressOperation -OperationName "Log Test" -TotalSteps 1
            { Write-ProgressLog -OperationId $operationId -Message "Test log message" } | Should -Not -Throw
        }
    }
    
    Context "Active Operations Management" {
        It "Should track active operations" {
            $operationId = Start-ProgressOperation -OperationName "Active Test" -TotalSteps 1
            $activeOps = Get-ActiveOperations
            $activeOps | Should -Not -BeNullOrEmpty
            $activeOps.ContainsKey($operationId) | Should -Be $true
        }
        
        It "Should remove operations when completed" {
            $operationId = Start-ProgressOperation -OperationName "Removal Test" -TotalSteps 1
            Complete-ProgressOperation -OperationId $operationId
            $activeOps = Get-ActiveOperations
            $activeOps.ContainsKey($operationId) | Should -Be $false
        }
    }
    
    Context "Integration Tests" {
        It "Should work with Logging module if available" {
            if (Get-Module Logging -ErrorAction SilentlyContinue) {
                $operationId = Start-ProgressOperation -OperationName "Logging Integration" -TotalSteps 1
                { Write-ProgressLog -OperationId $operationId -Message "Integration test" } | Should -Not -Throw
            } else {
                Set-ItResult -Skipped -Because "Logging module not available"
            }
        }
    }
    
    Context "Error Handling" {
        It "Should handle missing operation ID gracefully" {
            { Update-ProgressOperation -OperationId "nonexistent" -CurrentStep 1 } | Should -Not -Throw
        }
        
        It "Should handle invalid parameters gracefully" {
            { Start-ProgressOperation -OperationName "" -TotalSteps 0 } | Should -Not -Throw
        }
    }
    
    Context "Cross-Platform Compatibility" {
        It "Should work on current platform" {
            $platform = if ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } elseif ($IsMacOS) { "macOS" } else { "Unknown" }
            $platform | Should -BeIn @("Windows", "Linux", "macOS")
            
            # Test that basic functionality works regardless of platform
            $operationId = Start-ProgressOperation -OperationName "Platform Test" -TotalSteps 1
            $operationId | Should -Not -BeNullOrEmpty
            Complete-ProgressOperation -OperationId $operationId
        }
    }
}

AfterAll {
    # Clean up any remaining active operations
    $activeOps = Get-ActiveOperations
    foreach ($opId in $activeOps.Keys) {
        Complete-ProgressOperation -OperationId $opId -ErrorAction SilentlyContinue
    }
    
    # Remove the module
    Remove-Module ProgressTracking -Force -ErrorAction SilentlyContinue
}