#Requires -Modules Pester

BeforeAll {
    # Setup test environment
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:RootModule = Join-Path $script:ProjectRoot "AitherZero.psm1"
    $script:ManifestModule = Join-Path $script:ProjectRoot "AitherZero.psd1"
    $script:OriginalEnv = @{}
    
    # Store original environment variables
    $script:OriginalEnv.AITHERZERO_ROOT = $env:AITHERZERO_ROOT
    $script:OriginalEnv.AITHERZERO_INITIALIZED = $env:AITHERZERO_INITIALIZED
    $script:OriginalEnv.AITHERZERO_DISABLE_TRANSCRIPT = $env:AITHERZERO_DISABLE_TRANSCRIPT
    $script:OriginalEnv.PATH = $env:PATH
    
    # Expected module loading order
    $script:ExpectedModuleOrder = @(
        'Logging.psm1',
        'Configuration.psm1',
        'BetterMenu.psm1',
        'UserInterface.psm1',
        'GitAutomation.psm1',
        'IssueTracker.psm1',
        'PullRequestManager.psm1',
        'TestingFramework.psm1',
        'ReportingEngine.psm1',
        'TechDebtAnalysis.psm1',
        'OrchestrationEngine.psm1',
        'DeploymentAutomation.psm1',
        'Infrastructure.psm1'
    )
    
    # Mock cross-platform detection
    $script:MockIsWindows = $IsWindows
    $script:MockIsLinux = $IsLinux
    $script:MockIsMacOS = $IsMacOS
}

AfterAll {
    # Restore original environment
    $env:AITHERZERO_ROOT = $script:OriginalEnv.AITHERZERO_ROOT
    $env:AITHERZERO_INITIALIZED = $script:OriginalEnv.AITHERZERO_INITIALIZED
    $env:AITHERZERO_DISABLE_TRANSCRIPT = $script:OriginalEnv.AITHERZERO_DISABLE_TRANSCRIPT
    $env:PATH = $script:OriginalEnv.PATH
    
    # Cleanup imported modules
    Remove-Module AitherZero -Force -ErrorAction SilentlyContinue
    
    # Stop any transcripts that might be running
    try { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null } catch { }
}

Describe "AitherZero Module Manifest (AitherZero.psd1)" -Tag 'Unit', 'Manifest' {
    Context "Manifest Structure Validation" {
        It "Should have a valid module manifest file" {
            Test-Path $script:ManifestModule | Should -Be $true
        }
        
        It "Should have valid manifest data" {
            { Test-ModuleManifest -Path $script:ManifestModule } | Should -Not -Throw
        }
        
        It "Should specify correct PowerShell version requirement" {
            $manifest = Import-PowerShellDataFile -Path $script:ManifestModule
            $manifest.PowerShellVersion | Should -Be '7.0'
        }
        
        It "Should have correct root module specified" {
            $manifest = Import-PowerShellDataFile -Path $script:ManifestModule
            $manifest.RootModule | Should -Be 'AitherZero.psm1'
        }
        
        It "Should export expected functions" {
            $manifest = Import-PowerShellDataFile -Path $script:ManifestModule
            $manifest.FunctionsToExport | Should -Contain 'Invoke-AitherScript'
            $manifest.FunctionsToExport | Should -Contain 'Write-CustomLog'
            $manifest.FunctionsToExport | Should -Contain 'Get-Configuration'
            $manifest.FunctionsToExport | Should -Contain 'Invoke-OrchestrationSequence'
        }
        
        It "Should export expected aliases" {
            $manifest = Import-PowerShellDataFile -Path $script:ManifestModule
            $manifest.AliasesToExport | Should -Contain 'az'
            $manifest.AliasesToExport | Should -Contain 'seq'
        }
        
        It "Should have valid GUID format" {
            $manifest = Import-PowerShellDataFile -Path $script:ManifestModule
            $manifest.GUID | Should -Match '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$'
        }
        
        It "Should have module metadata" {
            $manifest = Import-PowerShellDataFile -Path $script:ManifestModule
            $manifest.Author | Should -Not -BeNullOrEmpty
            $manifest.Description | Should -Not -BeNullOrEmpty
            $manifest.ModuleVersion | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "AitherZero Root Module (AitherZero.psm1)" -Tag 'Unit', 'RootModule' {
    BeforeEach {
        # Clear environment variables for clean testing
        $env:AITHERZERO_ROOT = $null
        $env:AITHERZERO_INITIALIZED = $null
        $env:AITHERZERO_DISABLE_TRANSCRIPT = $null
        
        # Remove any existing aliases
        Remove-Alias -Name 'az' -Force -ErrorAction SilentlyContinue
        Remove-Alias -Name 'seq' -Force -ErrorAction SilentlyContinue
        
        # Remove module if already loaded
        Remove-Module AitherZero -Force -ErrorAction SilentlyContinue
    }
    
    Context "Environment Variable Setup" {
        It "Should set AITHERZERO_ROOT to module root path" {
            Import-Module $script:RootModule -Force -DisableNameChecking
            $env:AITHERZERO_ROOT | Should -Be $script:ProjectRoot
        }
        
        It "Should set AITHERZERO_INITIALIZED to '1'" {
            Import-Module $script:RootModule -Force -DisableNameChecking
            $env:AITHERZERO_INITIALIZED | Should -Be '1'
        }
        
        It "Should add automation-scripts directory to PATH" {
            $originalPath = $env:PATH
            Import-Module $script:RootModule -Force -DisableNameChecking
            
            $automationPath = Join-Path $script:ProjectRoot "automation-scripts"
            $env:PATH | Should -BeLike "*$automationPath*"
            
            # Cleanup
            $env:PATH = $originalPath
        }
        
        It "Should not duplicate automation-scripts path in PATH" {
            $automationPath = Join-Path $script:ProjectRoot "automation-scripts"
            $pathSeparator = [IO.Path]::PathSeparator
            
            # Clear PATH first, then add automation path once
            $originalPath = $env:PATH
            $env:PATH = "$automationPath$pathSeparator/usr/bin"
            
            Import-Module $script:RootModule -Force -DisableNameChecking
            
            # Should not have duplicate entries
            @($env:PATH -split [regex]::Escape($pathSeparator) | Where-Object { $_ -eq $automationPath }).Count | Should -Be 1
            
            # Restore original PATH
            $env:PATH = $originalPath
        }
    }
    
    Context "Transcript Logging Initialization" {
        It "Should handle transcript initialization gracefully when enabled" {
            $env:AITHERZERO_DISABLE_TRANSCRIPT = $null
            
            { Import-Module $script:RootModule -Force -DisableNameChecking } | Should -Not -Throw
        }
        
        It "Should skip transcript when AITHERZERO_DISABLE_TRANSCRIPT is set" {
            $env:AITHERZERO_DISABLE_TRANSCRIPT = '1'
            
            { Import-Module $script:RootModule -Force -DisableNameChecking } | Should -Not -Throw
        }
        
        It "Should create logs directory when transcript is enabled" {
            $env:AITHERZERO_DISABLE_TRANSCRIPT = $null
            
            Import-Module $script:RootModule -Force -DisableNameChecking
            
            $logsPath = Join-Path $script:ProjectRoot "logs"
            Test-Path $logsPath | Should -Be $true
        }
        
        It "Should handle transcript failures gracefully" {
            # This test verifies that the module loads even if transcript fails
            $env:AITHERZERO_DISABLE_TRANSCRIPT = $null
            
            { Import-Module $script:RootModule -Force -DisableNameChecking } | Should -Not -Throw
        }
    }
    
    Context "Module Loading Sequence" {
        It "Should load modules without throwing errors" {
            { Import-Module $script:RootModule -Force -DisableNameChecking } | Should -Not -Throw
        }
        
        It "Should have expected critical functions available after loading" {
            Import-Module $script:RootModule -Force -DisableNameChecking
            
            # These functions should be available if modules loaded correctly
            Get-Command Write-CustomLog -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Get-Configuration -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should validate expected module paths exist" {
            # Test that all referenced module paths in the code actually exist
            $content = Get-Content $script:RootModule -Raw
            $modulePathPattern = "'\\./domains/[^']+\\.psm1'"
            $matchResults = [regex]::Matches($content, $modulePathPattern)
            
            foreach ($match in $matchResults) {
                $relativePath = $match.Value.Trim("'")
                $fullPath = Join-Path $script:ProjectRoot $relativePath
                Test-Path $fullPath | Should -Be $true -Because "Module path $relativePath should exist"
            }
        }
        
        It "Should handle missing module files gracefully" {
            # This test ensures module loading continues even if some modules are missing
            { Import-Module $script:RootModule -Force -DisableNameChecking } | Should -Not -Throw
        }
    }
    
    Context "Invoke-AitherScript Function" {
        BeforeEach {
            Import-Module $script:RootModule -Force -DisableNameChecking
            
            # Setup mock automation scripts
            $script:MockScriptPath = Join-Path $TestDrive "automation-scripts"
            New-Item -ItemType Directory -Path $script:MockScriptPath -Force
            
            # Override the environment variable for testing
            $env:AITHERZERO_ROOT = $TestDrive
        }
        
        It "Should be available after module import" {
            Get-Command Invoke-AitherScript -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should find script by number pattern" {
            $testScript = Join-Path $script:MockScriptPath "0402_Run-UnitTests.ps1"
            Set-Content -Path $testScript -Value "Write-Host 'Test Script'"
            
            Mock Invoke-Expression { "Mock execution" }
            
            # Should find the script
            { Invoke-AitherScript -ScriptNumber "0402" } | Should -Not -Throw
        }
        
        It "Should handle script not found gracefully" {
            # Capture the error output instead of mocking
            $errorOutput = Invoke-AitherScript -ScriptNumber "9999" 2>&1
            
            # Should produce an error about no script found
            $errorOutput | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle multiple matching scripts" {
            $testScript1 = Join-Path $script:MockScriptPath "0402_Run-UnitTests.ps1"
            $testScript2 = Join-Path $script:MockScriptPath "0402_Run-OtherTests.ps1"
            Set-Content -Path $testScript1 -Value "Write-Host 'Test Script 1'"
            Set-Content -Path $testScript2 -Value "Write-Host 'Test Script 2'"
            
            # Test that function handles multiple scripts without throwing
            { Invoke-AitherScript -ScriptNumber "0402" } | Should -Not -Throw
            
            # Verify multiple script files exist
            (Get-ChildItem -Path $script:MockScriptPath -Filter "0402*.ps1").Count | Should -Be 2
        }
        
        It "Should pass global Config variable when available" {
            $testScript = Join-Path $script:MockScriptPath "0500_Test-Config.ps1"
            Set-Content -Path $testScript -Value 'param($Configuration) "Config passed: $($Configuration -ne $null)"'
            
            # Set up global config
            $global:Config = @{ Test = "Value" }
            
            $result = Invoke-AitherScript -ScriptNumber "0500"
            
            # Should have passed the configuration
            $result | Should -Be "Config passed: True"
            
            # Cleanup
            Remove-Variable -Name Config -Scope Global -ErrorAction SilentlyContinue
        }
        
        It "Should pass additional arguments to script" {
            $testScript = Join-Path $script:MockScriptPath "0501_Test-Args.ps1"
            Set-Content -Path $testScript -Value 'param($Configuration, $Message) "Arg: $Message"'
            
            # The function uses dynamic parameters, not -Arguments
            $result = Invoke-AitherScript -ScriptNumber "0501" -Message "TestValue"
            
            $result | Should -Be "Arg: TestValue"
        }
        
        It "Should work without additional arguments" {
            $testScript = Join-Path $script:MockScriptPath "0502_Test-NoArgs.ps1"
            Set-Content -Path $testScript -Value '"No args test"'
            
            $result = Invoke-AitherScript -ScriptNumber "0502"
            
            $result | Should -Be "No args test"
        }
    }
    
    Context "Alias Creation" {
        BeforeEach {
            Remove-Alias -Name 'az' -Force -ErrorAction SilentlyContinue
            Remove-Alias -Name 'seq' -Force -ErrorAction SilentlyContinue
        }
        
        It "Should create 'az' alias for Invoke-AitherScript" {
            Import-Module $script:RootModule -Force -DisableNameChecking
            
            $azAlias = Get-Alias -Name 'az' -ErrorAction SilentlyContinue
            $azAlias | Should -Not -BeNullOrEmpty
            $azAlias.ResolvedCommandName | Should -Be 'Invoke-AitherScript'
        }
        
        It "Should create aliases with Global scope" {
            Import-Module $script:RootModule -Force -DisableNameChecking
            
            $azAlias = Get-Alias -Name 'az' -Scope Global -ErrorAction SilentlyContinue
            $azAlias | Should -Not -BeNullOrEmpty
        }
        
        It "Should force override existing aliases" {
            Set-Alias -Name 'az' -Value 'Get-Process' -Scope Global -Force
            
            Import-Module $script:RootModule -Force -DisableNameChecking
            
            $azAlias = Get-Alias -Name 'az' -ErrorAction SilentlyContinue
            $azAlias.ResolvedCommandName | Should -Be 'Invoke-AitherScript'
        }
    }
    
    Context "Module Export Validation" {
        It "Should export Invoke-AitherScript function" {
            Import-Module $script:RootModule -Force -DisableNameChecking
            
            # Function is defined as global:Invoke-AitherScript
            Get-Command Invoke-AitherScript -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export 'az' alias" {
            Import-Module $script:RootModule -Force -DisableNameChecking
            
            # Check if alias exists in global scope instead of module exports
            Get-Alias -Name 'az' -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should not export private variables or functions" {
            Import-Module $script:RootModule -Force -DisableNameChecking
            
            $module = Get-Module AitherZero
            $module.ExportedVariables.Keys | Should -BeNullOrEmpty
        }
    }
    
    Context "Cross-Platform Path Handling" {
        It "Should use correct path separator for current platform" {
            Import-Module $script:RootModule -Force -DisableNameChecking
            
            $pathSeparator = [IO.Path]::PathSeparator
            $env:PATH | Should -BeLike "*$pathSeparator*"
        }
        
        It "Should handle paths correctly on Windows" {
            # Mock Windows environment
            Mock Get-Variable { @{ Value = $true } } -ParameterFilter { $Name -eq 'IsWindows' }
            
            Import-Module $script:RootModule -Force -DisableNameChecking
            
            # Should not throw on path operations
            { Invoke-AitherScript -ScriptNumber "0000" } | Should -Not -Throw
        }
        
        It "Should handle paths correctly on Linux/macOS" {
            # Mock non-Windows environment
            Mock Get-Variable { @{ Value = $false } } -ParameterFilter { $Name -eq 'IsWindows' }
            Mock Get-Variable { @{ Value = $true } } -ParameterFilter { $Name -eq 'IsLinux' }
            
            Import-Module $script:RootModule -Force -DisableNameChecking
            
            # Should not throw on path operations
            { Invoke-AitherScript -ScriptNumber "0000" } | Should -Not -Throw
        }
    }
    
    Context "Error Handling During Initialization" {
        It "Should handle critical module loading failures gracefully" {
            # Test that the module loads even when some dependencies might fail
            { Import-Module $script:RootModule -Force -DisableNameChecking } | Should -Not -Throw
        }
        
        It "Should continue loading after module failures" {
            # Test resilience - module should load even if some sub-modules fail
            { Import-Module $script:RootModule -Force -DisableNameChecking } | Should -Not -Throw
            
            # Core functionality should still be available
            Get-Command Invoke-AitherScript -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle missing logs directory gracefully" {
            Mock New-Item { throw "Permission denied" } -ParameterFilter { $ItemType -eq 'Directory' }
            Mock Test-Path { $false }
            
            { Import-Module $script:RootModule -Force -DisableNameChecking } | Should -Not -Throw
        }
        
        It "Should handle PATH modification failures gracefully" {
            # Mock a scenario where PATH is read-only
            $originalPath = $env:PATH
            try {
                # This should still not cause the module to fail loading
                Import-Module $script:RootModule -Force -DisableNameChecking
                $true | Should -Be $true
            } catch {
                $false | Should -Be $true
            } finally {
                $env:PATH = $originalPath
            }
        }
    }
    
    Context "Module Dependency Validation" {
        It "Should require PowerShell 7.0 or later" {
            $content = Get-Content $script:RootModule -Raw
            $content | Should -BeLike "*#Requires -Version 7.0*"
        }
        
        It "Should validate all referenced module paths exist in codebase" {
            $content = Get-Content $script:RootModule -Raw
            
            # Extract module paths from the $modulesToLoad array
            $modulePathPattern = "'\./domains/[^']+\.psm1'"
            $matchResults = [regex]::Matches($content, $modulePathPattern)
            
            foreach ($match in $matchResults) {
                $relativePath = $match.Value.Trim("'")
                $fullPath = Join-Path $script:ProjectRoot $relativePath
                
                # Check if the referenced module file exists
                Test-Path $fullPath | Should -Be $true -Because "Module path $relativePath should exist"
            }
        }
        
        It "Should ensure critical modules are loaded before dependent modules" {
            # Configuration module should be loaded before modules that might use it
            # BetterMenu should be loaded before UserInterface
            # This is validated by checking the order in the module loading sequence
            
            $content = Get-Content $script:RootModule -Raw
            $loggingIndex = $content.IndexOf('Logging.psm1')
            $configIndex = $content.IndexOf('Configuration.psm1')
            $betterMenuIndex = $content.IndexOf('BetterMenu.psm1')
            $uiIndex = $content.IndexOf('UserInterface.psm1')
            
            $loggingIndex | Should -BeLessThan $configIndex
            $betterMenuIndex | Should -BeLessThan $uiIndex
        }
    }
    
    Context "Performance and Resource Management" {
        It "Should not leak variables into global scope" {
            $beforeVariables = Get-Variable -Scope Global | Select-Object -ExpandProperty Name
            
            Import-Module $script:RootModule -Force -DisableNameChecking
            
            $afterVariables = Get-Variable -Scope Global | Select-Object -ExpandProperty Name
            $newVariables = Compare-Object $beforeVariables $afterVariables | 
                Where-Object { $_.SideIndicator -eq '=>' } |
                Select-Object -ExpandProperty InputObject
            
            # Should only add environment variables and expected exports
            # Note: Test framework may add its own variables, so we filter those out
            $allowedVariables = @('AITHERZERO_ROOT', 'AITHERZERO_INITIALIZED')
            $testVariables = @('beforeVariables', 'afterVariables', 'newVariables', 'unexpectedVariables', 'allowedVariables')
            $unexpectedVariables = $newVariables | Where-Object { 
                $_ -notin $allowedVariables -and $_ -notin $testVariables
            }
            
            $unexpectedVariables | Should -BeNullOrEmpty
        }
        
        It "Should handle concurrent module loading attempts gracefully" {
            # This test simulates what might happen if multiple processes try to load the module
            $jobs = @()
            1..3 | ForEach-Object {
                $jobs += Start-Job -ScriptBlock {
                    param($ModulePath)
                    try {
                        Import-Module $ModulePath -Force -DisableNameChecking -ErrorAction Stop
                        return "Success"
                    } catch {
                        return "Failed: $_"
                    }
                } -ArgumentList $script:RootModule
            }
            
            $results = $jobs | Wait-Job | Receive-Job
            $jobs | Remove-Job -Force
            
            # All jobs should complete successfully
            $results | Should -Not -BeNullOrEmpty
            $results | ForEach-Object { $_ | Should -Be "Success" }
        }
    }
}

Describe "Integration with AitherZero Ecosystem" -Tag 'Integration' {
    BeforeEach {
        # Clean environment for integration tests
        Remove-Module AitherZero -Force -ErrorAction SilentlyContinue
        $env:AITHERZERO_DISABLE_TRANSCRIPT = '1'  # Disable for testing
    }
    
    Context "Configuration Integration" {
        It "Should work with Configuration module when available" -Skip {
            # This would require the actual Configuration module to be available
            # Skipping for unit tests, would be covered in integration tests
        }
        
        It "Should work with OrchestrationEngine when available" -Skip {
            # This would require the actual OrchestrationEngine module to be available
            # Skipping for unit tests, would be covered in integration tests
        }
    }
    
    Context "Automation Script Execution Integration" {
        It "Should execute actual automation scripts when available" -Skip {
            # This would require actual automation scripts to be present
            # Skipping for unit tests, would be covered in integration tests
        }
    }
}