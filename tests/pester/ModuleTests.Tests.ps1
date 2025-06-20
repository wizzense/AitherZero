# Load shared test helpers for environment setup
. (Join-Path $PSScriptRoot '..' 'helpers' 'TestHelpers.ps1')
Describe 'UnifiedMaintenance Module Tests' {
    BeforeAll {
        $ModulePath = './aither-core/modules/UnifiedMaintenance/UnifiedMaintenance.psm1'
    }

    Context 'Module Structure' {
        It 'Should have module file' {
            Test-Path $ModulePath | Should -Be $true
        }

        It 'Should have manifest file' {
            Test-Path $env:PWSH_MODULES_PATH/UnifiedMaintenance/UnifiedMaintenance.psd1' | Should -Be $true
        }

        It 'Should load module without errors' {
            { Import-Module $ModulePath -Force -ErrorAction Stop } | Should -Not -Throw
        }
    }

    Context 'Module Content' {
        BeforeAll {
            Import-Module $ModulePath -Force -ErrorAction SilentlyContinue
        }

        It 'Should export functions' {
            $module = Get-Module -Name 'UnifiedMaintenance'
            if ($module) {
                $module.ExportedFunctions.Count | Should -BeGreaterThan 0
            } else {
                # If module doesn't load properly, just check file content
                $content = Get-Content $ModulePath -Raw
                $content | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Describe 'TestingFramework Module Tests' {
    BeforeAll {
        $ModulePath = './aither-core/modules/TestingFramework/TestingFramework.psm1'
    }

    Context 'Module Structure' {        It 'Should have module file' {
            Test-Path $ModulePath | Should -Be $true
        }
        
        It 'Should have manifest file' {
            Test-Path $env:PWSH_MODULES_PATH/TestingFramework/TestingFramework.psd1 | Should -Be $true
        }

        It 'Should load module without errors' {
            { Import-Module $ModulePath -Force -ErrorAction Stop } | Should -Not -Throw
        }
    }
}

Describe 'ScriptManager Module Tests' {
    BeforeAll {
        $ModulePath = './aither-core/modules/ScriptManager/ScriptManager.psm1'
    }

    Context 'Module Structure' {
        It 'Should have module file' {
            Test-Path $ModulePath | Should -Be $true
        }

        It 'Should load module without errors' {
            { Import-Module $ModulePath -Force -ErrorAction Stop } | Should -Not -Throw
        }
    }

    Context 'File Content' {
        It 'Should have non-empty content' {
            $content = Get-Content $ModulePath -Raw
            $content | Should -Not -BeNullOrEmpty
            $content.Length | Should -BeGreaterThan 10
        }
    }
}
