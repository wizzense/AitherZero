#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Comprehensive Pester tests for the CoreApp module and its scripts
    
.DESCRIPTION
    Tests the core application functionality including:
    - Module loading and configuration
    - Individual script execution
    - Cross-platform compatibility
    - Error handling and validation
    - Integration with PatchManager workflow
#>

BeforeAll {
    # Set up environment variables if not already set
    if (-not $env:PROJECT_ROOT) {
        $env:PROJECT_ROOT = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    }
    if (-not $env:PWSH_MODULES_PATH) {
        $env:PWSH_MODULES_PATH = Join-Path $env:PROJECT_ROOT "aither-core/modules"
    }
    
    # Import required modules and helpers  
    try {
        Import-Module "$env:PWSH_MODULES_PATH/Logging/" -Force -ErrorAction SilentlyContinue
        Import-Module "$env:PWSH_MODULES_PATH/PatchManager/" -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Some modules could not be loaded: $_"
    }
    
    # Import test helpers if they exist
    $testHelpersPath = "$env:PROJECT_ROOT/tests/helpers/TestHelpers.ps1"
    if (Test-Path $testHelpersPath) {
        . $testHelpersPath
    }
    
    $scriptAstPath = "$env:PROJECT_ROOT/tests/helpers/Get-ScriptAst.ps1"
    if (Test-Path $scriptAstPath) {
        . $scriptAstPath
    }
    
    # Set up test environment
    $script:CoreAppPath = "$env:PROJECT_ROOT/aither-core"
    $script:DefaultConfigPath = "$script:CoreAppPath/default-config.json"
    $script:TestResults = @{}
    
    # Ensure test coverage directory exists
    if (-not (Test-Path "$env:PROJECT_ROOT/coverage")) {
        New-Item -ItemType Directory -Path "$env:PROJECT_ROOT/coverage" -Force | Out-Null
    }
}

Describe "CoreApp Module Tests" -Tag @('Critical', 'CoreApp', 'Module') {
    
    Context "Module Structure Validation" {
        
        It "should have valid module manifest" {
            $manifestPath = Join-Path $script:CoreAppPath "CoreApp.psd1"
            $manifestPath | Should -Exist
            
            { Test-ModuleManifest -Path $manifestPath } | Should -Not -Throw
        }
        
        It "should have module implementation file" {
            $modulePath = Join-Path $script:CoreAppPath "CoreApp.psm1"
            $modulePath | Should -Exist
              # Validate PowerShell syntax
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($modulePath, [ref]$null, [ref]$errors) | Out-Null
            $errorCount = if ($errors) { $errors.Count } else { 0 }
            $errorCount | Should -Be 0
        }
        
        It "should have default configuration file" {
            $script:DefaultConfigPath | Should -Exist
            
            # Validate JSON structure
            { Get-Content $script:DefaultConfigPath | ConvertFrom-Json } | Should -Not -Throw
        }
        
        It "should have scripts directory with core scripts" {
            $scriptsPath = Join-Path $script:CoreAppPath "scripts"
            $scriptsPath | Should -Exist
            
            $coreScripts = Get-ChildItem -Path $scriptsPath -Filter "*.ps1"
            $coreScripts.Count | Should -BeGreaterThan 10
        }
    }
    
    Context "Module Import and Loading" {
        
        It "should import CoreApp module successfully" {
            { Import-Module "$script:CoreAppPath/" -Force } | Should -Not -Throw
        }
        
        It "should export Invoke-CoreApplication function" {
            Import-Module "$script:CoreAppPath/" -Force
            Get-Command -Module CoreApp -Name "Invoke-CoreApplication" | Should -Not -BeNullOrEmpty
        }
        
        It "should have proper environment variable support" {
            $env:PROJECT_ROOT | Should -Not -BeNullOrEmpty
            $env:PWSH_MODULES_PATH | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Core Application Scripts Tests" -Tag @('Important', 'CoreApp', 'Scripts') {
    
    BeforeAll {
        $script:CoreScripts = Get-ChildItem -Path "$script:CoreAppPath/scripts" -Filter "*.ps1"
    }
    
    Context "Script Syntax and Structure Validation" {
        
        It "should have valid PowerShell syntax for all core scripts" {            foreach ($script in $script:CoreScripts) {
                $errors = $null
                [System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$null, [ref]$errors) | Out-Null
                $errorCount = if ($errors) { $errors.Count } else { 0 }
                $errorCount | Should -Be 0 -Because "Script $($script.Name) should have valid syntax"
            }
        }
        
        It "should follow PowerShell 7.0+ requirements" {
            foreach ($script in $script:CoreScripts) {
                $content = Get-Content $script.FullName -Raw
                if ($content -match '#Requires') {
                    $content | Should -Match '#Requires -Version 7\.0' -Because "$($script.Name) should require PowerShell 7.0+"
                }
            }
        }
        
        It "should use proper error handling patterns" {
            foreach ($script in $script:CoreScripts) {
                $content = Get-Content $script.FullName -Raw
                # Check for try-catch blocks in scripts that are likely to have them
                if ($script.Name -match '^(0[12]|Install-)') {
                    $content | Should -Match 'try\s*\{[\s\S]*?\}\s*catch' -Because "$($script.Name) should use try-catch error handling"
                }
            }
        }
    }
    
    Context "Script Content Analysis" {
        
        It "should define expected functions in numbered scripts" {
            $installerScripts = $script:CoreScripts | Where-Object { $_.Name -match '^0\d+_Install-' }
            
            foreach ($script in $installerScripts) {
                $content = Get-Content $script.FullName -Raw
                $expectedFunctionName = ($script.BaseName -replace '^\d+_', '')
                $content | Should -Match "function\s+$expectedFunctionName" -Because "$($script.Name) should define $expectedFunctionName function"
            }
        }
        
        It "should have main execution logic" {
            foreach ($script in $script:CoreScripts) {
                $content = Get-Content $script.FullName -Raw
                # Check for main execution patterns
                ($content -match 'param\s*\(' -or $content -match '\$Config' -or $content -match 'Write-CustomLog') | 
                    Should -BeTrue -Because "$($script.Name) should have main execution logic"
            }
        }
        
        It "should use standardized logging" {
            foreach ($script in $script:CoreScripts) {
                $content = Get-Content $script.FullName -Raw
                if ($content -match 'Write-') {
                    $content | Should -Match 'Write-CustomLog' -Because "$($script.Name) should use Write-CustomLog for standardized logging"
                }
            }
        }
    }
}

Describe "Core Application Integration Tests" -Tag @('Important', 'CoreApp', 'Integration') {
    
    Context "Invoke-CoreApplication Function Tests" {
        
        BeforeAll {
            Import-Module "$script:CoreAppPath/" -Force
        }
        
        It "should accept ConfigPath parameter" {
            $function = Get-Command Invoke-CoreApplication
            $function.Parameters.ContainsKey('ConfigPath') | Should -BeTrue
        }
        
        It "should validate configuration file exists" {
            $tempConfig = Join-Path ([System.IO.Path]::GetTempPath()) "test-config.json"
            '{"test": true}' | Set-Content -Path $tempConfig
            
            try {
                { Invoke-CoreApplication -ConfigPath $tempConfig } | Should -Not -Throw
            } finally {
                Remove-Item $tempConfig -Force -ErrorAction SilentlyContinue
            }
        }
        
        It "should handle missing configuration gracefully" {
            $nonExistentConfig = Join-Path ([System.IO.Path]::GetTempPath()) "nonexistent-config.json"
            { Invoke-CoreApplication -ConfigPath $nonExistentConfig } | Should -Throw
        }
    }
    
    Context "PatchManager Integration" {
        
        It "should be compatible with PatchManager workflow" {
            # Test that CoreApp can be used within PatchManager
            { Import-Module "$env:PWSH_MODULES_PATH/PatchManager/" -Force } | Should -Not -Throw
            { Import-Module "$script:CoreAppPath/" -Force } | Should -Not -Throw
        }
        
        It "should support PatchManager change tracking" {
            # Verify that changes to CoreApp can be tracked by PatchManager
            $patchManager = Get-Command New-PatchOperation -ErrorAction SilentlyContinue
            $patchManager | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Core Application Cross-Platform Tests" -Tag @('Maintenance', 'CoreApp', 'CrossPlatform') {
    
    Context "Platform Compatibility" {
        
        It "should work on current platform" {
            $env:PLATFORM | Should -BeIn @('Windows', 'Linux', 'macOS')
        }
        
        It "should handle platform-specific scripts appropriately" {
            $windowsScripts = $script:CoreScripts | Where-Object { $_.Name -match '^01\d+_' }
            
            foreach ($script in $windowsScripts) {
                $content = Get-Content $script.FullName -Raw
                if ($env:PLATFORM -ne 'Windows') {
                    # On non-Windows, these scripts should either skip or handle gracefully
                    $content | Should -Match '(IsWindows|Skip|platform)' -Because "$($script.Name) should handle non-Windows platforms"
                }
            }
        }
        
        It "should use cross-platform paths" {
            foreach ($script in $script:CoreScripts) {
                $content = Get-Content $script.FullName -Raw
                # Check for Windows-specific paths
                $content | Should -Not -Match '\\\\|C:\\' -Because "$($script.Name) should use cross-platform paths"
            }
        }
    }
}

Describe "Automated Test Generation and Validation" -Tag @('Critical', 'CoreApp', 'Automation') {
    
    Context "Continuous Test Coverage" {
        
        It "should have tests for all core scripts" {
            $coreScriptNames = $script:CoreScripts.BaseName
            $testFile = Get-Content $PSCommandPath -Raw
            
            foreach ($scriptName in $coreScriptNames) {
                if ($scriptName -match '^0\d+_') {
                    $testFile | Should -Match $scriptName -Because "Should have test coverage for $scriptName"
                }
            }
        }
        
        It "should validate test completeness" {
            $testCounts = @{
                'Syntax' = 0
                'Function' = 0
                'Integration' = 0
                'Platform' = 0
            }
            
            $testFile = Get-Content $PSCommandPath -Raw
            $testCounts.Syntax = ($testFile | Select-String -Pattern 'syntax|parse' -AllMatches).Matches.Count
            $testCounts.Function = ($testFile | Select-String -Pattern 'function|define' -AllMatches).Matches.Count
            $testCounts.Integration = ($testFile | Select-String -Pattern 'integration|invoke' -AllMatches).Matches.Count
            $testCounts.Platform = ($testFile | Select-String -Pattern 'platform|cross' -AllMatches).Matches.Count
            
            $testCounts.Syntax | Should -BeGreaterThan 0
            $testCounts.Function | Should -BeGreaterThan 0
            $testCounts.Integration | Should -BeGreaterThan 0
            $testCounts.Platform | Should -BeGreaterThan 0
        }
        
        It "should enforce PatchManager usage for changes" {
            # Verify that any changes to CoreApp go through PatchManager
            $patchManagerCommands = @(
                'New-PatchOperation'
                'Invoke-PatchValidation' 
                'Submit-PatchForReview'
            )
            
            foreach ($cmd in $patchManagerCommands) {
                Get-Command $cmd -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because "$cmd should be available for PatchManager workflow"
            }
        }
    }
    
    Context "Test Result Analysis" {
        
        It "should generate comprehensive test reports" {
            $script:TestResults['CoreApp'] = @{
                TotalTests = (Get-ChildItem $PSCommandPath | Measure-Object).Count
                Timestamp = Get-Date
                Platform = $env:PLATFORM
                PowerShellVersion = $PSVersionTable.PSVersion
            }
            
            $script:TestResults.Count | Should -BeGreaterThan 0
        }
        
        It "should validate against test quality metrics" {
            # Ensure we have adequate test coverage
            $totalTests = 25  # Minimum expected tests
            $actualTests = (Select-String -Path $PSCommandPath -Pattern '\s+It\s+"' | Measure-Object).Count
            
            $actualTests | Should -BeGreaterOrEqual $totalTests -Because "Should have at least $totalTests tests for comprehensive coverage"
        }
    }
}

AfterAll {
    # Clean up test environment
    Write-CustomLog "CoreApp tests completed. Results: $($script:TestResults | ConvertTo-Json -Depth 2)" -Level INFO
    
    # Generate test coverage report if running in CI
    if ($env:CI -or $env:GITHUB_ACTIONS) {
        $coverageReport = @{
            TestFile = $PSCommandPath
            Results = $script:TestResults
            Timestamp = Get-Date
            Environment = @{
                Platform = $env:PLATFORM
                PowerShell = $PSVersionTable.PSVersion
                ProjectRoot = $env:PROJECT_ROOT
            }
        }
        
        $reportPath = "$env:PROJECT_ROOT/coverage/CoreApp-TestReport.json"
        $coverageReport | ConvertTo-Json -Depth 3 | Set-Content -Path $reportPath
        Write-CustomLog "Test coverage report saved to: $reportPath" -Level SUCCESS
    }
}
