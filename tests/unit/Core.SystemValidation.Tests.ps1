#Requires -Version 7.0
<#
.SYNOPSIS
    Core system validation tests for AitherZero
.DESCRIPTION
    Comprehensive tests for core functionality that must pass
    Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
#>

BeforeAll {
    Import-Module $PSScriptRoot/../Enhanced-TestFramework.psm1 -Force
    Initialize-EnhancedTestEnvironment -SkipModuleLoad
}

Describe "AitherZero Core System Validation" -Tags @('Core', 'System', 'Critical') {
    
    Context "Main Module Loading" {
        It "AitherZero.psm1 should exist" {
            $mainModule = Join-Path $PSScriptRoot "../../AitherZero.psm1"
            Test-Path $mainModule | Should -BeTrue
        }
        
        It "AitherZero.psm1 should load without errors" {
            $mainModule = Join-Path $PSScriptRoot "../../AitherZero.psm1"
            { Import-Module $mainModule -Force } | Should -Not -Throw
        }
        
        It "Should set AITHERZERO_INITIALIZED environment variable" {
            $mainModule = Join-Path $PSScriptRoot "../../AitherZero.psm1"
            Import-Module $mainModule -Force
            $env:AITHERZERO_INITIALIZED | Should -Be "1"
        }
    }
    
    Context "Configuration System" {
        BeforeAll {
            $configPath = Join-Path $PSScriptRoot "../../config.psd1"
        }
        
        It "config.psd1 should exist" {
            Test-Path $configPath | Should -BeTrue
        }
        
        It "config.psd1 should be valid PowerShell data file" {
            { Import-PowerShellDataFile -Path $configPath } | Should -Not -Throw
        }
        
        It "Should have required configuration sections" {
            $config = Import-PowerShellDataFile -Path $configPath
            $config.ContainsKey('Core') | Should -BeTrue
            $config.ContainsKey('InstallationOptions') | Should -BeTrue
        }
        
        It "Core section should have required properties" {
            $config = Import-PowerShellDataFile -Path $configPath
            $core = $config.Core
            $core.ContainsKey('Name') | Should -BeTrue
            $core.ContainsKey('Version') | Should -BeTrue
            $core.ContainsKey('Profile') | Should -BeTrue
            $core.Name | Should -Be 'AitherZero'
        }
        
        It "Should validate version format" {
            $config = Import-PowerShellDataFile -Path $configPath
            { [System.Version]::Parse($config.Core.Version) } | Should -Not -Throw
        }
    }
    
    Context "Domain Modules" {
        BeforeAll {
            $domainsPath = Join-Path $PSScriptRoot "../../domains"
            $expectedModules = @('Configuration', 'Logging', 'UserInterface', 'DevTools', 'Orchestration', 'Infrastructure')
        }
        
        It "Domains directory should exist" {
            Test-Path $domainsPath | Should -BeTrue
        }
        
        It "Should have all expected domain modules" {
            foreach ($module in $expectedModules) {
                $modulePath = Get-ChildItem -Path $domainsPath -Filter "$module.psm1" -Recurse | Select-Object -First 1
                $modulePath | Should -Not -BeNullOrEmpty -Because "Module $module.psm1 should exist"
            }
        }
        
        It "Each domain module should load without errors" {
            foreach ($module in $expectedModules) {
                $modulePath = Get-ChildItem -Path $domainsPath -Filter "$module.psm1" -Recurse | Select-Object -First 1
                if ($modulePath) {
                    { Import-Module $modulePath.FullName -Force } | Should -Not -Throw -Because "Module $module should load without errors"
                }
            }
        }
        
        It "Each domain module should export functions" {
            foreach ($module in $expectedModules) {
                $modulePath = Get-ChildItem -Path $domainsPath -Filter "$module.psm1" -Recurse | Select-Object -First 1
                if ($modulePath) {
                    Import-Module $modulePath.FullName -Force
                    $moduleObj = Get-Module $module
                    $moduleObj.ExportedFunctions.Count | Should -BeGreaterThan 0 -Because "Module $module should export functions"
                }
            }
        }
    }
    
    Context "Entry Points" {
        It "bootstrap.ps1 should exist" {
            $bootstrap = Join-Path $PSScriptRoot "../../bootstrap.ps1"
            Test-Path $bootstrap | Should -BeTrue
        }
        
        It "Start-AitherZero.ps1 should exist" {
            $starter = Join-Path $PSScriptRoot "../../Start-AitherZero.ps1"
            Test-Path $starter | Should -BeTrue
        }
        
        It "bootstrap.ps1 should have proper syntax" {
            $bootstrap = Join-Path $PSScriptRoot "../../bootstrap.ps1"
            $content = Get-Content $bootstrap -Raw
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$errors)
            $errors.Count | Should -Be 0 -Because "bootstrap.ps1 should have no parse errors"
        }
        
        It "Start-AitherZero.ps1 should have proper syntax" {
            $starter = Join-Path $PSScriptRoot "../../Start-AitherZero.ps1"
            $content = Get-Content $starter -Raw
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$errors)
            $errors.Count | Should -Be 0 -Because "Start-AitherZero.ps1 should have no parse errors"
        }
        
        It "Should support CLI mode" {
            $starter = Join-Path $PSScriptRoot "../../Start-AitherZero.ps1"
            $content = Get-Content $starter -Raw
            $content | Should -Match 'CLI' -Because "Should support CLI mode for GUI integration"
        }
    }
    
    Context "Automation Scripts" {
        BeforeAll {
            $scriptsPath = Join-Path $PSScriptRoot "../../automation-scripts"
        }
        
        It "automation-scripts directory should exist" {
            Test-Path $scriptsPath | Should -BeTrue
        }
        
        It "Should contain numbered scripts" {
            $scripts = Get-ChildItem $scriptsPath -Filter "*.ps1"
            $scripts.Count | Should -BeGreaterThan 90 -Because "Should have at least 90 automation scripts"
        }
        
        It "Should have no duplicate script numbers" {
            $scripts = Get-ChildItem $scriptsPath -Filter "*.ps1"
            $numbers = $scripts | ForEach-Object { ($_.BaseName -split '_')[0] }
            $duplicates = $numbers | Group-Object | Where-Object Count -gt 1
            $duplicates.Count | Should -Be 0 -Because "All script numbers should be unique"
        }
        
        It "Script numbers should follow naming convention" {
            $scripts = Get-ChildItem $scriptsPath -Filter "*.ps1" | Select-Object -First 10
            foreach ($script in $scripts) {
                $script.BaseName | Should -Match '^\d{4}_.*' -Because "Script names should start with 4-digit number"
            }
        }
    }
    
    Context "Orchestration System" {
        BeforeAll {
            $orchestrationPath = Join-Path $PSScriptRoot "../../orchestration"
        }
        
        It "orchestration directory should exist" {
            Test-Path $orchestrationPath | Should -BeTrue
        }
        
        It "Should have standardized categories" {
            $expectedCategories = @('setup', 'testing', 'development', 'deployment')
            foreach ($category in $expectedCategories) {
                $categoryPath = Join-Path $orchestrationPath $category
                Test-Path $categoryPath | Should -BeTrue -Because "Category $category should exist"
            }
        }
        
        It "Should contain valid JSON playbooks" {
            $playbooks = Get-ChildItem $orchestrationPath -Filter "*.json" -Recurse
            foreach ($playbook in $playbooks) {
                { Get-Content $playbook.FullName | ConvertFrom-Json } | Should -Not -Throw -Because "$($playbook.Name) should be valid JSON"
            }
        }
    }
    
    Context "Testing Infrastructure" {
        It "tests directory should exist" {
            $testsPath = Join-Path $PSScriptRoot ".."
            Test-Path $testsPath | Should -BeTrue
        }
        
        It "TestHelpers.psm1 should exist and load" {
            $helpers = Join-Path $PSScriptRoot "../TestHelpers.psm1"
            Test-Path $helpers | Should -BeTrue
            { Import-Module $helpers -Force } | Should -Not -Throw
        }
        
        It "Enhanced-TestFramework.psm1 should exist and load" {
            $framework = Join-Path $PSScriptRoot "../Enhanced-TestFramework.psm1"
            Test-Path $framework | Should -BeTrue
            { Import-Module $framework -Force } | Should -Not -Throw
        }
        
        It "Should have test directories structure" {
            $testsPath = Join-Path $PSScriptRoot ".."
            $expectedDirs = @('unit', 'integration', 'domains')
            foreach ($dir in $expectedDirs) {
                $dirPath = Join-Path $testsPath $dir
                Test-Path $dirPath | Should -BeTrue -Because "Test directory $dir should exist"
            }
        }
    }
    
    Context "Documentation" {
        It "README.md should exist in project root" {
            $readme = Join-Path $PSScriptRoot "../../README.md"
            Test-Path $readme | Should -BeTrue
        }
        
        It "Should have README.md files in domains" {
            $domainsPath = Join-Path $PSScriptRoot "../../domains"
            Test-Path (Join-Path $domainsPath "README.md") | Should -BeTrue
        }
        
        It "Should have README.md files in automation-scripts" {
            $scriptsPath = Join-Path $PSScriptRoot "../../automation-scripts"
            Test-Path (Join-Path $scriptsPath "README.md") | Should -BeTrue
        }
    }
    
    Context "Performance Requirements" {
        It "Main module should load within acceptable time" {
            $mainModule = Join-Path $PSScriptRoot "../../AitherZero.psm1"
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            Import-Module $mainModule -Force
            $stopwatch.Stop()
            $stopwatch.ElapsedMilliseconds | Should -BeLessOrEqual 10000 -Because "Module should load within 10 seconds"
        }
        
        It "Configuration loading should be fast" {
            $configPath = Join-Path $PSScriptRoot "../../config.psd1"
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            Import-PowerShellDataFile -Path $configPath | Out-Null
            $stopwatch.Stop()
            $stopwatch.ElapsedMilliseconds | Should -BeLessOrEqual 1000 -Because "Configuration should load within 1 second"
        }
    }
    
    Context "Security and Quality" {
        It "Should not contain hardcoded credentials" {
            $allFiles = Get-ChildItem $PSScriptRoot/../.. -Include "*.ps1", "*.psm1" -Recurse
            foreach ($file in $allFiles | Select-Object -First 20) {
                $content = Get-Content $file.FullName -Raw
                $content | Should -Not -Match 'password\s*=\s*["\'']*.*["\'']*' -Because "$($file.Name) should not contain hardcoded passwords"
                $content | Should -Not -Match 'apikey\s*=\s*["\'']*.*["\'']*' -Because "$($file.Name) should not contain hardcoded API keys"
            }
        }
        
        It "Should use approved PowerShell verbs" {
            $approvedVerbs = Get-Verb | Select-Object -ExpandProperty Verb
            $mainModule = Join-Path $PSScriptRoot "../../AitherZero.psm1"
            Import-Module $mainModule -Force
            $commands = Get-Command -Module AitherZero -CommandType Function -ErrorAction SilentlyContinue
            
            foreach ($command in $commands | Select-Object -First 10) {
                $verb = ($command.Name -split '-')[0]
                if ($verb) {
                    $approvedVerbs | Should -Contain $verb -Because "Function $($command.Name) should use approved verb"
                }
            }
        }
    }
}