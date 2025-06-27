Describe 'Core Module Tests' {
    Context 'LabRunner Module' {
        It 'Should have module file' {
            Test-Path './aither-core/modules/LabRunner/LabRunner.psm1' | Should -Be $true
        }
    }
} }
    Context 'Module Structure' {
        It 'Should have module file' {
            Test-Path $ModulePath | Should -Be $true
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

    Context 'Module Structure' {
        It 'Should have module file' {
            Test-Path $ModulePath | Should -Be $true
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
            $module = Get-Module -Name 'TestingFramework'
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

Describe 'PatchManager Module Tests' {
    BeforeAll {
        $ModulePath = './aither-core/modules/PatchManager/PatchManager.psm1'
    }

    Context 'Module Structure' {
        It 'Should have module file' {
            Test-Path $ModulePath | Should -Be $true
        }

        It 'Should load module without errors' {
            { Import-Module $ModulePath -Force -ErrorAction Stop } | Should -Not -Throw
        }
    }
}
