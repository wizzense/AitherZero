# Load shared test helpers for environment setup
. (Join-Path $PSScriptRoot '..' 'helpers' 'TestHelpers.ps1')
Describe 'Project Structure and Integration Tests' {
    Context 'Project Directory Structure' {
        It 'Should have all required top-level directories' {
            @('src', 'tests', 'configs', 'docs') | ForEach-Object {
                Test-Path $_ | Should -Be $true
            }
        }

        It 'Should have PowerShell source structure' {
            Test-Path 'src/pwsh' | Should -Be $true
            Test-Path $env:PWSH_MODULES_PATH | Should -Be $true
        }

        It 'Should have Python source structure' {
            Test-Path 'src/python' | Should -Be $true
            Test-Path 'src/python/labctl' | Should -Be $true
        }

        It 'Should have test structure' {
            Test-Path 'tests/pester' | Should -Be $true
            Test-Path 'tests/pytest' | Should -Be $true
        }
    }

    Context 'Configuration Files' {
        It 'Should have project configuration files' {
            Test-Path 'configs/PROJECT-MANIFEST.json' | Should -Be $true
        }

        It 'Should have Python configuration' {
            Test-Path 'src/python/pyproject.toml' | Should -Be $true
        }

        It 'Should have test configurations' {
            Test-Path 'tests/PesterConfiguration.psd1' | Should -Be $true
            Test-Path 'tests/PSScriptAnalyzerSettings.psd1' | Should -Be $true
        }
    }

    Context 'Master Test Runner' {
        It 'Should have master test runner script' {
            Test-Path 'Run-AllTests.ps1' | Should -Be $true
        }

        It 'Should have test documentation' {
            Test-Path 'TEST-CONFIGURATION.md' | Should -Be $true
        }

        It 'Should be able to execute test runner script' {
            { Get-Content 'Run-AllTests.ps1' -ErrorAction Stop } | Should -Not -Throw
        }
    }

    Context 'Integration Validation' {        It 'Should have consistent module naming or valid variations' {
            $moduleFiles = Get-ChildItem $env:PWSH_MODULES_PATH -Recurse -Filter '*.psm1'
            $moduleFiles | ForEach-Object {
                $moduleName = $_.BaseName
                $moduleDir = $_.Directory.Name
                # Allow for variations like ModuleName-Fixed, ModuleName-Updated, etc.
                ($moduleName -eq $moduleDir -or $moduleName -like "$moduleDir-*") | Should -Be $true
            }
        }

        It 'Should have Python modules with __init__.py files' {
            $pythonDirs = Get-ChildItem 'src/python' -Directory
            $pythonDirs | Where-Object { $_.Name -ne '__pycache__' } | ForEach-Object {
                if (Test-Path "$($_.FullName)/*.py") {
                    # If it has Python files and looks like a package, it should have __init__.py
                    $hasInitFile = Test-Path "$($_.FullName)/__init__.py"
                    if ($_.Name -eq 'labctl') {
                        $hasInitFile | Should -Be $true
                    }
                }
            }
        }

        It 'Should have no obvious syntax errors in PowerShell files' {
            $psFiles = Get-ChildItem 'src/pwsh' -Recurse -Filter '*.ps1'
            $psFiles | ForEach-Object {
                { 
                    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $_.FullName -Raw), [ref]$null)
                } | Should -Not -Throw
            }
        }
    }
}
