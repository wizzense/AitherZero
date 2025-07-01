# Required test file header
. (Join-Path $PSScriptRoot 'helpers' 'TestHelpers.ps1')

Describe 'kicker-git Bootstrap Tests' {
    BeforeAll {
        Import-Module "$env:PWSH_MODULES_PATH/LabRunner/" -Force
        $bootstrapScript = Join-Path $PSScriptRoot '../../kicker-git.ps1'
    }

    Context 'Bootstrap Script Validation' {
        It 'should have kicker-git.ps1 file' {
            $bootstrapScript | Should -Exist
        }

        It 'should have proper parameters' {
            $content = Get-Content $bootstrapScript -Raw
            $content | Should -Match 'param\s*\('
            $content | Should -Match '\$ConfigFile'
            $content | Should -Match '\$SkipGitHubAuth'
            $content | Should -Match '\$TargetBranch'
        }
    }

    Context 'Module Loading' {
        It 'should load required modules' {
            Get-Module LabRunner | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Functionality Tests' {
        It 'should execute WhatIf without errors' {
            # Test WhatIf mode to avoid actual execution
            { & $bootstrapScript -WhatIf } | Should -Not -Throw
        }
    }

    AfterAll {
        # Cleanup test resources
    }
}
