#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Pester tests for ProgressTracking module
.DESCRIPTION
    Automated tests generated for ProgressTracking module covering:
    - Module loading and manifest validation
    - Function availability and parameter validation
    - Basic functionality tests
    - Error handling scenarios
#>

BeforeAll {
    # Import required modules
    . "$PSScriptRoot/../../../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    
    # Import the module being tested
    $modulePath = Join-Path $projectRoot "aither-core/modules/ProgressTracking"
    Import-Module $modulePath -Force
    
    # Import dependencies
    Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
}

Describe "ProgressTracking Module Tests" {
    
    Context "Module Loading and Manifest" {
        
        It "Should import without errors" {
            { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should have a valid manifest" {
            $manifestPath = Join-Path $modulePath "ProgressTracking.psd1"
            Test-Path $manifestPath | Should -Be $true
            { Test-ModuleManifest $manifestPath -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should export expected functions" {
            $module = Get-Module ProgressTracking
            $module | Should -Not -BeNullOrEmpty
            
            $expectedFunctions = @(
                'Add-ProgressError',
                'Add-ProgressWarning',
                'Complete-ProgressOperation',
                'Get-ActiveOperations',
                'Start-MultiProgress',
                'Start-ProgressOperation',
                'Update-ProgressOperation',
                'Write-ProgressLog'
            )
            
            $actualFunctions = $module.ExportedFunctions.Keys | Sort-Object
            $actualFunctions.Count | Should -BeGreaterThan 0
            
            foreach ($func in $expectedFunctions) {
                $actualFunctions | Should -Contain $func
            }
        }
        
        It "Should have required module dependencies" {
            $manifest = Import-PowerShellDataFile $manifestPath
            
            # Check PowerShell version requirement
            if ($manifest.PowerShellVersion) {
                $manifest.PowerShellVersion | Should -Be '7.0'
            }
        }
    }
    
    Context "Function Availability" {
        
        It "Should have all exported functions available" {
            $module = Get-Module ProgressTracking
            $exportedFunctions = $module.ExportedFunctions.Keys
            
            foreach ($function in $exportedFunctions) {
                { Get-Command $function -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }
    
    Context "Add-ProgressError Function Tests" {
        
        It "Should have proper parameter definitions" {
            $command = Get-Command Add-ProgressError
            $command | Should -Not -BeNullOrEmpty
            $command.CommandType | Should -Be 'Function'
        }        
        It "Should execute without errors when given valid parameters" {
            # This is a basic smoke test - implement specific logic based on function purpose
            $command = Get-Command Add-ProgressError
            
            # Skip if function has mandatory parameters (would need specific test data)
            $mandatoryParams = $command.Parameters.Values | 
                Where-Object { #!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Pester tests for ProgressTracking module
.DESCRIPTION
    Automated tests generated for ProgressTracking module covering:
    - Module loading and manifest validation
    - Function availability and parameter validation
    - Basic functionality tests
    - Error handling scenarios
#>

BeforeAll {
    # Import required modules
    . "$PSScriptRoot/../../../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    
    # Import the module being tested
    $modulePath = Join-Path $projectRoot "aither-core/modules/ProgressTracking"
    Import-Module $modulePath -Force
    
    # Import dependencies
    Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
}

Describe "ProgressTracking Module Tests" {
    
    Context "Module Loading and Manifest" {
        
        It "Should import without errors" {
            { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should have a valid manifest" {
            $manifestPath = Join-Path $modulePath "ProgressTracking.psd1"
            Test-Path $manifestPath | Should -Be $true
            { Test-ModuleManifest $manifestPath -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should export expected functions" {
            $module = Get-Module ProgressTracking
            $module | Should -Not -BeNullOrEmpty
            
            $expectedFunctions = @(
                'Add-ProgressError',
                'Add-ProgressWarning',
                'Complete-ProgressOperation',
                'Get-ActiveOperations',
                'Start-MultiProgress',
                'Start-ProgressOperation',
                'Update-ProgressOperation',
                'Write-ProgressLog'
            )
            
            $actualFunctions = $module.ExportedFunctions.Keys | Sort-Object
            $actualFunctions.Count | Should -BeGreaterThan 0
            
            foreach ($func in $expectedFunctions) {
                $actualFunctions | Should -Contain $func
            }
        }
        
        It "Should have required module dependencies" {
            $manifest = Import-PowerShellDataFile $manifestPath
            
            # Check PowerShell version requirement
            if ($manifest.PowerShellVersion) {
                $manifest.PowerShellVersion | Should -Be '7.0'
            }
        }
    }
    
    Context "Function Availability" {
        
        It "Should have all exported functions available" {
            $module = Get-Module ProgressTracking
            $exportedFunctions = $module.ExportedFunctions.Keys
            
            foreach ($function in $exportedFunctions) {
                { Get-Command $function -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }
    
MODULE_FUNCTION_TESTS
    
    Context "Error Handling" {
        
        It "Should handle invalid parameters gracefully" {
            $module = Get-Module ProgressTracking
            $functions = $module.ExportedFunctions.Keys | Select-Object -First 1
            
            if ($functions) {
                # Test with null parameters where applicable
                $function = Get-Command $functions[0]
                $mandatoryParams = $function.Parameters.Values | 
                    Where-Object { $_.Attributes.Mandatory -eq $false }
                
                if ($mandatoryParams) {
                    { & $function.Name -ErrorAction Stop } | Should -Not -Throw
                }
            }
        }
    }
    
    Context "Module Cleanup" {
        
        It "Should remove module cleanly" {
            { Remove-Module ProgressTracking -Force -ErrorAction Stop } | Should -Not -Throw
            Get-Module ProgressTracking | Should -BeNullOrEmpty
        }
        
        It "Should reload without issues" {
            { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw
            Get-Module ProgressTracking | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "ProgressTracking Integration Tests" {
    
    BeforeAll {
        # Setup for integration tests
        $testData = @{
            TestPath = Join-Path $TestDrive "ProgressTracking-Tests"
        }
        
        New-Item -ItemType Directory -Path $testData.TestPath -Force | Out-Null
    }
    
    AfterAll {
        # Cleanup
        if (Test-Path $testData.TestPath) {
            Remove-Item $testData.TestPath -Recurse -Force
        }
    }
    
    Context "Cross-Module Integration" {
        
        It "Should work with Logging module" {
            # All modules should integrate with logging
            { Write-CustomLog -Level 'INFO' -Message "ProgressTracking test" } | Should -Not -Throw
        }
    }
}

Describe "ProgressTracking Performance Tests" {
    
    Context "Function Performance" {
        
        It "Should complete operations within acceptable time limits" {
            $module = Get-Module ProgressTracking
            $functions = $module.ExportedFunctions.Keys | Select-Object -First 1
            
            if ($functions) {
                $executionTime = Measure-Command {
                    # Run a basic operation
                    $function = Get-Command $functions[0]
                    if ($function.Parameters.Count -eq 0) {
                        & $function.Name -ErrorAction SilentlyContinue
                    }
                }
                
                # Most operations should complete within 5 seconds
                $executionTime.TotalSeconds | Should -BeLessThan 5
            }
        }
    }
}.Attributes.Mandatory -eq $true }
            
            if (-not $mandatoryParams) {
                { & $command.Name -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }
    
    Context "Add-ProgressWarning Function Tests" {
        
        It "Should have proper parameter definitions" {
            $command = Get-Command Add-ProgressWarning
            $command | Should -Not -BeNullOrEmpty
            $command.CommandType | Should -Be 'Function'
        }        
        It "Should execute without errors when given valid parameters" {
            # This is a basic smoke test - implement specific logic based on function purpose
            $command = Get-Command Add-ProgressWarning
            
            # Skip if function has mandatory parameters (would need specific test data)
            $mandatoryParams = $command.Parameters.Values | 
                Where-Object { #!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Pester tests for ProgressTracking module
.DESCRIPTION
    Automated tests generated for ProgressTracking module covering:
    - Module loading and manifest validation
    - Function availability and parameter validation
    - Basic functionality tests
    - Error handling scenarios
#>

BeforeAll {
    # Import required modules
    . "$PSScriptRoot/../../../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    
    # Import the module being tested
    $modulePath = Join-Path $projectRoot "aither-core/modules/ProgressTracking"
    Import-Module $modulePath -Force
    
    # Import dependencies
    Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
}

Describe "ProgressTracking Module Tests" {
    
    Context "Module Loading and Manifest" {
        
        It "Should import without errors" {
            { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should have a valid manifest" {
            $manifestPath = Join-Path $modulePath "ProgressTracking.psd1"
            Test-Path $manifestPath | Should -Be $true
            { Test-ModuleManifest $manifestPath -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should export expected functions" {
            $module = Get-Module ProgressTracking
            $module | Should -Not -BeNullOrEmpty
            
            $expectedFunctions = @(
                'Add-ProgressError',
                'Add-ProgressWarning',
                'Complete-ProgressOperation',
                'Get-ActiveOperations',
                'Start-MultiProgress',
                'Start-ProgressOperation',
                'Update-ProgressOperation',
                'Write-ProgressLog'
            )
            
            $actualFunctions = $module.ExportedFunctions.Keys | Sort-Object
            $actualFunctions.Count | Should -BeGreaterThan 0
            
            foreach ($func in $expectedFunctions) {
                $actualFunctions | Should -Contain $func
            }
        }
        
        It "Should have required module dependencies" {
            $manifest = Import-PowerShellDataFile $manifestPath
            
            # Check PowerShell version requirement
            if ($manifest.PowerShellVersion) {
                $manifest.PowerShellVersion | Should -Be '7.0'
            }
        }
    }
    
    Context "Function Availability" {
        
        It "Should have all exported functions available" {
            $module = Get-Module ProgressTracking
            $exportedFunctions = $module.ExportedFunctions.Keys
            
            foreach ($function in $exportedFunctions) {
                { Get-Command $function -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }
    
MODULE_FUNCTION_TESTS
    
    Context "Error Handling" {
        
        It "Should handle invalid parameters gracefully" {
            $module = Get-Module ProgressTracking
            $functions = $module.ExportedFunctions.Keys | Select-Object -First 1
            
            if ($functions) {
                # Test with null parameters where applicable
                $function = Get-Command $functions[0]
                $mandatoryParams = $function.Parameters.Values | 
                    Where-Object { $_.Attributes.Mandatory -eq $false }
                
                if ($mandatoryParams) {
                    { & $function.Name -ErrorAction Stop } | Should -Not -Throw
                }
            }
        }
    }
    
    Context "Module Cleanup" {
        
        It "Should remove module cleanly" {
            { Remove-Module ProgressTracking -Force -ErrorAction Stop } | Should -Not -Throw
            Get-Module ProgressTracking | Should -BeNullOrEmpty
        }
        
        It "Should reload without issues" {
            { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw
            Get-Module ProgressTracking | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "ProgressTracking Integration Tests" {
    
    BeforeAll {
        # Setup for integration tests
        $testData = @{
            TestPath = Join-Path $TestDrive "ProgressTracking-Tests"
        }
        
        New-Item -ItemType Directory -Path $testData.TestPath -Force | Out-Null
    }
    
    AfterAll {
        # Cleanup
        if (Test-Path $testData.TestPath) {
            Remove-Item $testData.TestPath -Recurse -Force
        }
    }
    
    Context "Cross-Module Integration" {
        
        It "Should work with Logging module" {
            # All modules should integrate with logging
            { Write-CustomLog -Level 'INFO' -Message "ProgressTracking test" } | Should -Not -Throw
        }
    }
}

Describe "ProgressTracking Performance Tests" {
    
    Context "Function Performance" {
        
        It "Should complete operations within acceptable time limits" {
            $module = Get-Module ProgressTracking
            $functions = $module.ExportedFunctions.Keys | Select-Object -First 1
            
            if ($functions) {
                $executionTime = Measure-Command {
                    # Run a basic operation
                    $function = Get-Command $functions[0]
                    if ($function.Parameters.Count -eq 0) {
                        & $function.Name -ErrorAction SilentlyContinue
                    }
                }
                
                # Most operations should complete within 5 seconds
                $executionTime.TotalSeconds | Should -BeLessThan 5
            }
        }
    }
}.Attributes.Mandatory -eq $true }
            
            if (-not $mandatoryParams) {
                { & $command.Name -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }
    
    Context "Complete-ProgressOperation Function Tests" {
        
        It "Should have proper parameter definitions" {
            $command = Get-Command Complete-ProgressOperation
            $command | Should -Not -BeNullOrEmpty
            $command.CommandType | Should -Be 'Function'
        }        
        It "Should execute without errors when given valid parameters" {
            # This is a basic smoke test - implement specific logic based on function purpose
            $command = Get-Command Complete-ProgressOperation
            
            # Skip if function has mandatory parameters (would need specific test data)
            $mandatoryParams = $command.Parameters.Values | 
                Where-Object { #!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Pester tests for ProgressTracking module
.DESCRIPTION
    Automated tests generated for ProgressTracking module covering:
    - Module loading and manifest validation
    - Function availability and parameter validation
    - Basic functionality tests
    - Error handling scenarios
#>

BeforeAll {
    # Import required modules
    . "$PSScriptRoot/../../../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    
    # Import the module being tested
    $modulePath = Join-Path $projectRoot "aither-core/modules/ProgressTracking"
    Import-Module $modulePath -Force
    
    # Import dependencies
    Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
}

Describe "ProgressTracking Module Tests" {
    
    Context "Module Loading and Manifest" {
        
        It "Should import without errors" {
            { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should have a valid manifest" {
            $manifestPath = Join-Path $modulePath "ProgressTracking.psd1"
            Test-Path $manifestPath | Should -Be $true
            { Test-ModuleManifest $manifestPath -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should export expected functions" {
            $module = Get-Module ProgressTracking
            $module | Should -Not -BeNullOrEmpty
            
            $expectedFunctions = @(
                'Add-ProgressError',
                'Add-ProgressWarning',
                'Complete-ProgressOperation',
                'Get-ActiveOperations',
                'Start-MultiProgress',
                'Start-ProgressOperation',
                'Update-ProgressOperation',
                'Write-ProgressLog'
            )
            
            $actualFunctions = $module.ExportedFunctions.Keys | Sort-Object
            $actualFunctions.Count | Should -BeGreaterThan 0
            
            foreach ($func in $expectedFunctions) {
                $actualFunctions | Should -Contain $func
            }
        }
        
        It "Should have required module dependencies" {
            $manifest = Import-PowerShellDataFile $manifestPath
            
            # Check PowerShell version requirement
            if ($manifest.PowerShellVersion) {
                $manifest.PowerShellVersion | Should -Be '7.0'
            }
        }
    }
    
    Context "Function Availability" {
        
        It "Should have all exported functions available" {
            $module = Get-Module ProgressTracking
            $exportedFunctions = $module.ExportedFunctions.Keys
            
            foreach ($function in $exportedFunctions) {
                { Get-Command $function -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }
    
MODULE_FUNCTION_TESTS
    
    Context "Error Handling" {
        
        It "Should handle invalid parameters gracefully" {
            $module = Get-Module ProgressTracking
            $functions = $module.ExportedFunctions.Keys | Select-Object -First 1
            
            if ($functions) {
                # Test with null parameters where applicable
                $function = Get-Command $functions[0]
                $mandatoryParams = $function.Parameters.Values | 
                    Where-Object { $_.Attributes.Mandatory -eq $false }
                
                if ($mandatoryParams) {
                    { & $function.Name -ErrorAction Stop } | Should -Not -Throw
                }
            }
        }
    }
    
    Context "Module Cleanup" {
        
        It "Should remove module cleanly" {
            { Remove-Module ProgressTracking -Force -ErrorAction Stop } | Should -Not -Throw
            Get-Module ProgressTracking | Should -BeNullOrEmpty
        }
        
        It "Should reload without issues" {
            { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw
            Get-Module ProgressTracking | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "ProgressTracking Integration Tests" {
    
    BeforeAll {
        # Setup for integration tests
        $testData = @{
            TestPath = Join-Path $TestDrive "ProgressTracking-Tests"
        }
        
        New-Item -ItemType Directory -Path $testData.TestPath -Force | Out-Null
    }
    
    AfterAll {
        # Cleanup
        if (Test-Path $testData.TestPath) {
            Remove-Item $testData.TestPath -Recurse -Force
        }
    }
    
    Context "Cross-Module Integration" {
        
        It "Should work with Logging module" {
            # All modules should integrate with logging
            { Write-CustomLog -Level 'INFO' -Message "ProgressTracking test" } | Should -Not -Throw
        }
    }
}

Describe "ProgressTracking Performance Tests" {
    
    Context "Function Performance" {
        
        It "Should complete operations within acceptable time limits" {
            $module = Get-Module ProgressTracking
            $functions = $module.ExportedFunctions.Keys | Select-Object -First 1
            
            if ($functions) {
                $executionTime = Measure-Command {
                    # Run a basic operation
                    $function = Get-Command $functions[0]
                    if ($function.Parameters.Count -eq 0) {
                        & $function.Name -ErrorAction SilentlyContinue
                    }
                }
                
                # Most operations should complete within 5 seconds
                $executionTime.TotalSeconds | Should -BeLessThan 5
            }
        }
    }
}.Attributes.Mandatory -eq $true }
            
            if (-not $mandatoryParams) {
                { & $command.Name -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }
    
    Context "Get-ActiveOperations Function Tests" {
        
        It "Should have proper parameter definitions" {
            $command = Get-Command Get-ActiveOperations
            $command | Should -Not -BeNullOrEmpty
            $command.CommandType | Should -Be 'Function'
        }        
        It "Should execute without errors when given valid parameters" {
            # This is a basic smoke test - implement specific logic based on function purpose
            $command = Get-Command Get-ActiveOperations
            
            # Skip if function has mandatory parameters (would need specific test data)
            $mandatoryParams = $command.Parameters.Values | 
                Where-Object { #!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Pester tests for ProgressTracking module
.DESCRIPTION
    Automated tests generated for ProgressTracking module covering:
    - Module loading and manifest validation
    - Function availability and parameter validation
    - Basic functionality tests
    - Error handling scenarios
#>

BeforeAll {
    # Import required modules
    . "$PSScriptRoot/../../../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    
    # Import the module being tested
    $modulePath = Join-Path $projectRoot "aither-core/modules/ProgressTracking"
    Import-Module $modulePath -Force
    
    # Import dependencies
    Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
}

Describe "ProgressTracking Module Tests" {
    
    Context "Module Loading and Manifest" {
        
        It "Should import without errors" {
            { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should have a valid manifest" {
            $manifestPath = Join-Path $modulePath "ProgressTracking.psd1"
            Test-Path $manifestPath | Should -Be $true
            { Test-ModuleManifest $manifestPath -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should export expected functions" {
            $module = Get-Module ProgressTracking
            $module | Should -Not -BeNullOrEmpty
            
            $expectedFunctions = @(
                'Add-ProgressError',
                'Add-ProgressWarning',
                'Complete-ProgressOperation',
                'Get-ActiveOperations',
                'Start-MultiProgress',
                'Start-ProgressOperation',
                'Update-ProgressOperation',
                'Write-ProgressLog'
            )
            
            $actualFunctions = $module.ExportedFunctions.Keys | Sort-Object
            $actualFunctions.Count | Should -BeGreaterThan 0
            
            foreach ($func in $expectedFunctions) {
                $actualFunctions | Should -Contain $func
            }
        }
        
        It "Should have required module dependencies" {
            $manifest = Import-PowerShellDataFile $manifestPath
            
            # Check PowerShell version requirement
            if ($manifest.PowerShellVersion) {
                $manifest.PowerShellVersion | Should -Be '7.0'
            }
        }
    }
    
    Context "Function Availability" {
        
        It "Should have all exported functions available" {
            $module = Get-Module ProgressTracking
            $exportedFunctions = $module.ExportedFunctions.Keys
            
            foreach ($function in $exportedFunctions) {
                { Get-Command $function -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }
    
MODULE_FUNCTION_TESTS
    
    Context "Error Handling" {
        
        It "Should handle invalid parameters gracefully" {
            $module = Get-Module ProgressTracking
            $functions = $module.ExportedFunctions.Keys | Select-Object -First 1
            
            if ($functions) {
                # Test with null parameters where applicable
                $function = Get-Command $functions[0]
                $mandatoryParams = $function.Parameters.Values | 
                    Where-Object { $_.Attributes.Mandatory -eq $false }
                
                if ($mandatoryParams) {
                    { & $function.Name -ErrorAction Stop } | Should -Not -Throw
                }
            }
        }
    }
    
    Context "Module Cleanup" {
        
        It "Should remove module cleanly" {
            { Remove-Module ProgressTracking -Force -ErrorAction Stop } | Should -Not -Throw
            Get-Module ProgressTracking | Should -BeNullOrEmpty
        }
        
        It "Should reload without issues" {
            { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw
            Get-Module ProgressTracking | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "ProgressTracking Integration Tests" {
    
    BeforeAll {
        # Setup for integration tests
        $testData = @{
            TestPath = Join-Path $TestDrive "ProgressTracking-Tests"
        }
        
        New-Item -ItemType Directory -Path $testData.TestPath -Force | Out-Null
    }
    
    AfterAll {
        # Cleanup
        if (Test-Path $testData.TestPath) {
            Remove-Item $testData.TestPath -Recurse -Force
        }
    }
    
    Context "Cross-Module Integration" {
        
        It "Should work with Logging module" {
            # All modules should integrate with logging
            { Write-CustomLog -Level 'INFO' -Message "ProgressTracking test" } | Should -Not -Throw
        }
    }
}

Describe "ProgressTracking Performance Tests" {
    
    Context "Function Performance" {
        
        It "Should complete operations within acceptable time limits" {
            $module = Get-Module ProgressTracking
            $functions = $module.ExportedFunctions.Keys | Select-Object -First 1
            
            if ($functions) {
                $executionTime = Measure-Command {
                    # Run a basic operation
                    $function = Get-Command $functions[0]
                    if ($function.Parameters.Count -eq 0) {
                        & $function.Name -ErrorAction SilentlyContinue
                    }
                }
                
                # Most operations should complete within 5 seconds
                $executionTime.TotalSeconds | Should -BeLessThan 5
            }
        }
    }
}.Attributes.Mandatory -eq $true }
            
            if (-not $mandatoryParams) {
                { & $command.Name -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }
    
    Context "Start-MultiProgress Function Tests" {
        
        It "Should have proper parameter definitions" {
            $command = Get-Command Start-MultiProgress
            $command | Should -Not -BeNullOrEmpty
            $command.CommandType | Should -Be 'Function'
        }        
        It "Should execute without errors when given valid parameters" {
            # This is a basic smoke test - implement specific logic based on function purpose
            $command = Get-Command Start-MultiProgress
            
            # Skip if function has mandatory parameters (would need specific test data)
            $mandatoryParams = $command.Parameters.Values | 
                Where-Object { #!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Pester tests for ProgressTracking module
.DESCRIPTION
    Automated tests generated for ProgressTracking module covering:
    - Module loading and manifest validation
    - Function availability and parameter validation
    - Basic functionality tests
    - Error handling scenarios
#>

BeforeAll {
    # Import required modules
    . "$PSScriptRoot/../../../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    
    # Import the module being tested
    $modulePath = Join-Path $projectRoot "aither-core/modules/ProgressTracking"
    Import-Module $modulePath -Force
    
    # Import dependencies
    Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
}

Describe "ProgressTracking Module Tests" {
    
    Context "Module Loading and Manifest" {
        
        It "Should import without errors" {
            { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should have a valid manifest" {
            $manifestPath = Join-Path $modulePath "ProgressTracking.psd1"
            Test-Path $manifestPath | Should -Be $true
            { Test-ModuleManifest $manifestPath -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should export expected functions" {
            $module = Get-Module ProgressTracking
            $module | Should -Not -BeNullOrEmpty
            
            $expectedFunctions = @(
                'Add-ProgressError',
                'Add-ProgressWarning',
                'Complete-ProgressOperation',
                'Get-ActiveOperations',
                'Start-MultiProgress',
                'Start-ProgressOperation',
                'Update-ProgressOperation',
                'Write-ProgressLog'
            )
            
            $actualFunctions = $module.ExportedFunctions.Keys | Sort-Object
            $actualFunctions.Count | Should -BeGreaterThan 0
            
            foreach ($func in $expectedFunctions) {
                $actualFunctions | Should -Contain $func
            }
        }
        
        It "Should have required module dependencies" {
            $manifest = Import-PowerShellDataFile $manifestPath
            
            # Check PowerShell version requirement
            if ($manifest.PowerShellVersion) {
                $manifest.PowerShellVersion | Should -Be '7.0'
            }
        }
    }
    
    Context "Function Availability" {
        
        It "Should have all exported functions available" {
            $module = Get-Module ProgressTracking
            $exportedFunctions = $module.ExportedFunctions.Keys
            
            foreach ($function in $exportedFunctions) {
                { Get-Command $function -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }
    
MODULE_FUNCTION_TESTS
    
    Context "Error Handling" {
        
        It "Should handle invalid parameters gracefully" {
            $module = Get-Module ProgressTracking
            $functions = $module.ExportedFunctions.Keys | Select-Object -First 1
            
            if ($functions) {
                # Test with null parameters where applicable
                $function = Get-Command $functions[0]
                $mandatoryParams = $function.Parameters.Values | 
                    Where-Object { $_.Attributes.Mandatory -eq $false }
                
                if ($mandatoryParams) {
                    { & $function.Name -ErrorAction Stop } | Should -Not -Throw
                }
            }
        }
    }
    
    Context "Module Cleanup" {
        
        It "Should remove module cleanly" {
            { Remove-Module ProgressTracking -Force -ErrorAction Stop } | Should -Not -Throw
            Get-Module ProgressTracking | Should -BeNullOrEmpty
        }
        
        It "Should reload without issues" {
            { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw
            Get-Module ProgressTracking | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "ProgressTracking Integration Tests" {
    
    BeforeAll {
        # Setup for integration tests
        $testData = @{
            TestPath = Join-Path $TestDrive "ProgressTracking-Tests"
        }
        
        New-Item -ItemType Directory -Path $testData.TestPath -Force | Out-Null
    }
    
    AfterAll {
        # Cleanup
        if (Test-Path $testData.TestPath) {
            Remove-Item $testData.TestPath -Recurse -Force
        }
    }
    
    Context "Cross-Module Integration" {
        
        It "Should work with Logging module" {
            # All modules should integrate with logging
            { Write-CustomLog -Level 'INFO' -Message "ProgressTracking test" } | Should -Not -Throw
        }
    }
}

Describe "ProgressTracking Performance Tests" {
    
    Context "Function Performance" {
        
        It "Should complete operations within acceptable time limits" {
            $module = Get-Module ProgressTracking
            $functions = $module.ExportedFunctions.Keys | Select-Object -First 1
            
            if ($functions) {
                $executionTime = Measure-Command {
                    # Run a basic operation
                    $function = Get-Command $functions[0]
                    if ($function.Parameters.Count -eq 0) {
                        & $function.Name -ErrorAction SilentlyContinue
                    }
                }
                
                # Most operations should complete within 5 seconds
                $executionTime.TotalSeconds | Should -BeLessThan 5
            }
        }
    }
}.Attributes.Mandatory -eq $true }
            
            if (-not $mandatoryParams) {
                { & $command.Name -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }
    
    Context "Start-ProgressOperation Function Tests" {
        
        It "Should have proper parameter definitions" {
            $command = Get-Command Start-ProgressOperation
            $command | Should -Not -BeNullOrEmpty
            $command.CommandType | Should -Be 'Function'
        }        
        It "Should validate Style parameter values" {
            $validValues = @("Bar", "Spinner", "Percentage", "Detailed")
            { Start-ProgressOperation -Style "InvalidValue" -ErrorAction Stop } | Should -Throw
        }        
        It "Should execute without errors when given valid parameters" {
            # This is a basic smoke test - implement specific logic based on function purpose
            $command = Get-Command Start-ProgressOperation
            
            # Skip if function has mandatory parameters (would need specific test data)
            $mandatoryParams = $command.Parameters.Values | 
                Where-Object { #!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Pester tests for ProgressTracking module
.DESCRIPTION
    Automated tests generated for ProgressTracking module covering:
    - Module loading and manifest validation
    - Function availability and parameter validation
    - Basic functionality tests
    - Error handling scenarios
#>

BeforeAll {
    # Import required modules
    . "$PSScriptRoot/../../../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    
    # Import the module being tested
    $modulePath = Join-Path $projectRoot "aither-core/modules/ProgressTracking"
    Import-Module $modulePath -Force
    
    # Import dependencies
    Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
}

Describe "ProgressTracking Module Tests" {
    
    Context "Module Loading and Manifest" {
        
        It "Should import without errors" {
            { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should have a valid manifest" {
            $manifestPath = Join-Path $modulePath "ProgressTracking.psd1"
            Test-Path $manifestPath | Should -Be $true
            { Test-ModuleManifest $manifestPath -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should export expected functions" {
            $module = Get-Module ProgressTracking
            $module | Should -Not -BeNullOrEmpty
            
            $expectedFunctions = @(
                'Add-ProgressError',
                'Add-ProgressWarning',
                'Complete-ProgressOperation',
                'Get-ActiveOperations',
                'Start-MultiProgress',
                'Start-ProgressOperation',
                'Update-ProgressOperation',
                'Write-ProgressLog'
            )
            
            $actualFunctions = $module.ExportedFunctions.Keys | Sort-Object
            $actualFunctions.Count | Should -BeGreaterThan 0
            
            foreach ($func in $expectedFunctions) {
                $actualFunctions | Should -Contain $func
            }
        }
        
        It "Should have required module dependencies" {
            $manifest = Import-PowerShellDataFile $manifestPath
            
            # Check PowerShell version requirement
            if ($manifest.PowerShellVersion) {
                $manifest.PowerShellVersion | Should -Be '7.0'
            }
        }
    }
    
    Context "Function Availability" {
        
        It "Should have all exported functions available" {
            $module = Get-Module ProgressTracking
            $exportedFunctions = $module.ExportedFunctions.Keys
            
            foreach ($function in $exportedFunctions) {
                { Get-Command $function -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }
    
MODULE_FUNCTION_TESTS
    
    Context "Error Handling" {
        
        It "Should handle invalid parameters gracefully" {
            $module = Get-Module ProgressTracking
            $functions = $module.ExportedFunctions.Keys | Select-Object -First 1
            
            if ($functions) {
                # Test with null parameters where applicable
                $function = Get-Command $functions[0]
                $mandatoryParams = $function.Parameters.Values | 
                    Where-Object { $_.Attributes.Mandatory -eq $false }
                
                if ($mandatoryParams) {
                    { & $function.Name -ErrorAction Stop } | Should -Not -Throw
                }
            }
        }
    }
    
    Context "Module Cleanup" {
        
        It "Should remove module cleanly" {
            { Remove-Module ProgressTracking -Force -ErrorAction Stop } | Should -Not -Throw
            Get-Module ProgressTracking | Should -BeNullOrEmpty
        }
        
        It "Should reload without issues" {
            { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw
            Get-Module ProgressTracking | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "ProgressTracking Integration Tests" {
    
    BeforeAll {
        # Setup for integration tests
        $testData = @{
            TestPath = Join-Path $TestDrive "ProgressTracking-Tests"
        }
        
        New-Item -ItemType Directory -Path $testData.TestPath -Force | Out-Null
    }
    
    AfterAll {
        # Cleanup
        if (Test-Path $testData.TestPath) {
            Remove-Item $testData.TestPath -Recurse -Force
        }
    }
    
    Context "Cross-Module Integration" {
        
        It "Should work with Logging module" {
            # All modules should integrate with logging
            { Write-CustomLog -Level 'INFO' -Message "ProgressTracking test" } | Should -Not -Throw
        }
    }
}

Describe "ProgressTracking Performance Tests" {
    
    Context "Function Performance" {
        
        It "Should complete operations within acceptable time limits" {
            $module = Get-Module ProgressTracking
            $functions = $module.ExportedFunctions.Keys | Select-Object -First 1
            
            if ($functions) {
                $executionTime = Measure-Command {
                    # Run a basic operation
                    $function = Get-Command $functions[0]
                    if ($function.Parameters.Count -eq 0) {
                        & $function.Name -ErrorAction SilentlyContinue
                    }
                }
                
                # Most operations should complete within 5 seconds
                $executionTime.TotalSeconds | Should -BeLessThan 5
            }
        }
    }
}.Attributes.Mandatory -eq $true }
            
            if (-not $mandatoryParams) {
                { & $command.Name -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }
    
    Context "Update-ProgressOperation Function Tests" {
        
        It "Should have proper parameter definitions" {
            $command = Get-Command Update-ProgressOperation
            $command | Should -Not -BeNullOrEmpty
            $command.CommandType | Should -Be 'Function'
        }        
        It "Should execute without errors when given valid parameters" {
            # This is a basic smoke test - implement specific logic based on function purpose
            $command = Get-Command Update-ProgressOperation
            
            # Skip if function has mandatory parameters (would need specific test data)
            $mandatoryParams = $command.Parameters.Values | 
                Where-Object { #!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Pester tests for ProgressTracking module
.DESCRIPTION
    Automated tests generated for ProgressTracking module covering:
    - Module loading and manifest validation
    - Function availability and parameter validation
    - Basic functionality tests
    - Error handling scenarios
#>

BeforeAll {
    # Import required modules
    . "$PSScriptRoot/../../../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    
    # Import the module being tested
    $modulePath = Join-Path $projectRoot "aither-core/modules/ProgressTracking"
    Import-Module $modulePath -Force
    
    # Import dependencies
    Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
}

Describe "ProgressTracking Module Tests" {
    
    Context "Module Loading and Manifest" {
        
        It "Should import without errors" {
            { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should have a valid manifest" {
            $manifestPath = Join-Path $modulePath "ProgressTracking.psd1"
            Test-Path $manifestPath | Should -Be $true
            { Test-ModuleManifest $manifestPath -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should export expected functions" {
            $module = Get-Module ProgressTracking
            $module | Should -Not -BeNullOrEmpty
            
            $expectedFunctions = @(
                'Add-ProgressError',
                'Add-ProgressWarning',
                'Complete-ProgressOperation',
                'Get-ActiveOperations',
                'Start-MultiProgress',
                'Start-ProgressOperation',
                'Update-ProgressOperation',
                'Write-ProgressLog'
            )
            
            $actualFunctions = $module.ExportedFunctions.Keys | Sort-Object
            $actualFunctions.Count | Should -BeGreaterThan 0
            
            foreach ($func in $expectedFunctions) {
                $actualFunctions | Should -Contain $func
            }
        }
        
        It "Should have required module dependencies" {
            $manifest = Import-PowerShellDataFile $manifestPath
            
            # Check PowerShell version requirement
            if ($manifest.PowerShellVersion) {
                $manifest.PowerShellVersion | Should -Be '7.0'
            }
        }
    }
    
    Context "Function Availability" {
        
        It "Should have all exported functions available" {
            $module = Get-Module ProgressTracking
            $exportedFunctions = $module.ExportedFunctions.Keys
            
            foreach ($function in $exportedFunctions) {
                { Get-Command $function -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }
    
MODULE_FUNCTION_TESTS
    
    Context "Error Handling" {
        
        It "Should handle invalid parameters gracefully" {
            $module = Get-Module ProgressTracking
            $functions = $module.ExportedFunctions.Keys | Select-Object -First 1
            
            if ($functions) {
                # Test with null parameters where applicable
                $function = Get-Command $functions[0]
                $mandatoryParams = $function.Parameters.Values | 
                    Where-Object { $_.Attributes.Mandatory -eq $false }
                
                if ($mandatoryParams) {
                    { & $function.Name -ErrorAction Stop } | Should -Not -Throw
                }
            }
        }
    }
    
    Context "Module Cleanup" {
        
        It "Should remove module cleanly" {
            { Remove-Module ProgressTracking -Force -ErrorAction Stop } | Should -Not -Throw
            Get-Module ProgressTracking | Should -BeNullOrEmpty
        }
        
        It "Should reload without issues" {
            { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw
            Get-Module ProgressTracking | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "ProgressTracking Integration Tests" {
    
    BeforeAll {
        # Setup for integration tests
        $testData = @{
            TestPath = Join-Path $TestDrive "ProgressTracking-Tests"
        }
        
        New-Item -ItemType Directory -Path $testData.TestPath -Force | Out-Null
    }
    
    AfterAll {
        # Cleanup
        if (Test-Path $testData.TestPath) {
            Remove-Item $testData.TestPath -Recurse -Force
        }
    }
    
    Context "Cross-Module Integration" {
        
        It "Should work with Logging module" {
            # All modules should integrate with logging
            { Write-CustomLog -Level 'INFO' -Message "ProgressTracking test" } | Should -Not -Throw
        }
    }
}

Describe "ProgressTracking Performance Tests" {
    
    Context "Function Performance" {
        
        It "Should complete operations within acceptable time limits" {
            $module = Get-Module ProgressTracking
            $functions = $module.ExportedFunctions.Keys | Select-Object -First 1
            
            if ($functions) {
                $executionTime = Measure-Command {
                    # Run a basic operation
                    $function = Get-Command $functions[0]
                    if ($function.Parameters.Count -eq 0) {
                        & $function.Name -ErrorAction SilentlyContinue
                    }
                }
                
                # Most operations should complete within 5 seconds
                $executionTime.TotalSeconds | Should -BeLessThan 5
            }
        }
    }
}.Attributes.Mandatory -eq $true }
            
            if (-not $mandatoryParams) {
                { & $command.Name -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }
    
    Context "Write-ProgressLog Function Tests" {
        
        It "Should have proper parameter definitions" {
            $command = Get-Command Write-ProgressLog
            $command | Should -Not -BeNullOrEmpty
            $command.CommandType | Should -Be 'Function'
        }        
        It "Should validate Level parameter values" {
            $validValues = @("Info", "Warning", "Error", "Success")
            { Write-ProgressLog -Level "InvalidValue" -ErrorAction Stop } | Should -Throw
        }        
        It "Should execute without errors when given valid parameters" {
            # This is a basic smoke test - implement specific logic based on function purpose
            $command = Get-Command Write-ProgressLog
            
            # Skip if function has mandatory parameters (would need specific test data)
            $mandatoryParams = $command.Parameters.Values | 
                Where-Object { #!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Pester tests for ProgressTracking module
.DESCRIPTION
    Automated tests generated for ProgressTracking module covering:
    - Module loading and manifest validation
    - Function availability and parameter validation
    - Basic functionality tests
    - Error handling scenarios
#>

BeforeAll {
    # Import required modules
    . "$PSScriptRoot/../../../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    
    # Import the module being tested
    $modulePath = Join-Path $projectRoot "aither-core/modules/ProgressTracking"
    Import-Module $modulePath -Force
    
    # Import dependencies
    Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
}

Describe "ProgressTracking Module Tests" {
    
    Context "Module Loading and Manifest" {
        
        It "Should import without errors" {
            { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should have a valid manifest" {
            $manifestPath = Join-Path $modulePath "ProgressTracking.psd1"
            Test-Path $manifestPath | Should -Be $true
            { Test-ModuleManifest $manifestPath -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should export expected functions" {
            $module = Get-Module ProgressTracking
            $module | Should -Not -BeNullOrEmpty
            
            $expectedFunctions = @(
                'Add-ProgressError',
                'Add-ProgressWarning',
                'Complete-ProgressOperation',
                'Get-ActiveOperations',
                'Start-MultiProgress',
                'Start-ProgressOperation',
                'Update-ProgressOperation',
                'Write-ProgressLog'
            )
            
            $actualFunctions = $module.ExportedFunctions.Keys | Sort-Object
            $actualFunctions.Count | Should -BeGreaterThan 0
            
            foreach ($func in $expectedFunctions) {
                $actualFunctions | Should -Contain $func
            }
        }
        
        It "Should have required module dependencies" {
            $manifest = Import-PowerShellDataFile $manifestPath
            
            # Check PowerShell version requirement
            if ($manifest.PowerShellVersion) {
                $manifest.PowerShellVersion | Should -Be '7.0'
            }
        }
    }
    
    Context "Function Availability" {
        
        It "Should have all exported functions available" {
            $module = Get-Module ProgressTracking
            $exportedFunctions = $module.ExportedFunctions.Keys
            
            foreach ($function in $exportedFunctions) {
                { Get-Command $function -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }
    
MODULE_FUNCTION_TESTS
    
    Context "Error Handling" {
        
        It "Should handle invalid parameters gracefully" {
            $module = Get-Module ProgressTracking
            $functions = $module.ExportedFunctions.Keys | Select-Object -First 1
            
            if ($functions) {
                # Test with null parameters where applicable
                $function = Get-Command $functions[0]
                $mandatoryParams = $function.Parameters.Values | 
                    Where-Object { $_.Attributes.Mandatory -eq $false }
                
                if ($mandatoryParams) {
                    { & $function.Name -ErrorAction Stop } | Should -Not -Throw
                }
            }
        }
    }
    
    Context "Module Cleanup" {
        
        It "Should remove module cleanly" {
            { Remove-Module ProgressTracking -Force -ErrorAction Stop } | Should -Not -Throw
            Get-Module ProgressTracking | Should -BeNullOrEmpty
        }
        
        It "Should reload without issues" {
            { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw
            Get-Module ProgressTracking | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "ProgressTracking Integration Tests" {
    
    BeforeAll {
        # Setup for integration tests
        $testData = @{
            TestPath = Join-Path $TestDrive "ProgressTracking-Tests"
        }
        
        New-Item -ItemType Directory -Path $testData.TestPath -Force | Out-Null
    }
    
    AfterAll {
        # Cleanup
        if (Test-Path $testData.TestPath) {
            Remove-Item $testData.TestPath -Recurse -Force
        }
    }
    
    Context "Cross-Module Integration" {
        
        It "Should work with Logging module" {
            # All modules should integrate with logging
            { Write-CustomLog -Level 'INFO' -Message "ProgressTracking test" } | Should -Not -Throw
        }
    }
}

Describe "ProgressTracking Performance Tests" {
    
    Context "Function Performance" {
        
        It "Should complete operations within acceptable time limits" {
            $module = Get-Module ProgressTracking
            $functions = $module.ExportedFunctions.Keys | Select-Object -First 1
            
            if ($functions) {
                $executionTime = Measure-Command {
                    # Run a basic operation
                    $function = Get-Command $functions[0]
                    if ($function.Parameters.Count -eq 0) {
                        & $function.Name -ErrorAction SilentlyContinue
                    }
                }
                
                # Most operations should complete within 5 seconds
                $executionTime.TotalSeconds | Should -BeLessThan 5
            }
        }
    }
}.Attributes.Mandatory -eq $true }
            
            if (-not $mandatoryParams) {
                { & $command.Name -ErrorAction Stop } | Should -Not -Throw
            }
        }
    }
    
    
    Context "Error Handling" {
        
        It "Should handle invalid parameters gracefully" {
            $module = Get-Module ProgressTracking
            $functions = $module.ExportedFunctions.Keys | Select-Object -First 1
            
            if ($functions) {
                # Test with null parameters where applicable
                $function = Get-Command $functions[0]
                $mandatoryParams = $function.Parameters.Values | 
                    Where-Object { $_.Attributes.Mandatory -eq $false }
                
                if ($mandatoryParams) {
                    { & $function.Name -ErrorAction Stop } | Should -Not -Throw
                }
            }
        }
    }
    
    Context "Module Cleanup" {
        
        It "Should remove module cleanly" {
            { Remove-Module ProgressTracking -Force -ErrorAction Stop } | Should -Not -Throw
            Get-Module ProgressTracking | Should -BeNullOrEmpty
        }
        
        It "Should reload without issues" {
            { Import-Module $modulePath -Force -ErrorAction Stop } | Should -Not -Throw
            Get-Module ProgressTracking | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "ProgressTracking Integration Tests" {
    
    BeforeAll {
        # Setup for integration tests
        $testData = @{
            TestPath = Join-Path $TestDrive "ProgressTracking-Tests"
        }
        
        New-Item -ItemType Directory -Path $testData.TestPath -Force | Out-Null
    }
    
    AfterAll {
        # Cleanup
        if (Test-Path $testData.TestPath) {
            Remove-Item $testData.TestPath -Recurse -Force
        }
    }
    
    Context "Cross-Module Integration" {
        
        It "Should work with Logging module" {
            # All modules should integrate with logging
            { Write-CustomLog -Level 'INFO' -Message "ProgressTracking test" } | Should -Not -Throw
        }
    }
}

Describe "ProgressTracking Performance Tests" {
    
    Context "Function Performance" {
        
        It "Should complete operations within acceptable time limits" {
            $module = Get-Module ProgressTracking
            $functions = $module.ExportedFunctions.Keys | Select-Object -First 1
            
            if ($functions) {
                $executionTime = Measure-Command {
                    # Run a basic operation
                    $function = Get-Command $functions[0]
                    if ($function.Parameters.Count -eq 0) {
                        & $function.Name -ErrorAction SilentlyContinue
                    }
                }
                
                # Most operations should complete within 5 seconds
                $executionTime.TotalSeconds | Should -BeLessThan 5
            }
        }
    }
}
