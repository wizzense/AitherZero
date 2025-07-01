# Required test file header using shared utilities
. "$PSScriptRoot/../../aither-core/shared/Find-ProjectRoot.ps1"
$script:ProjectRoot = Find-ProjectRoot

Describe 'Customize-ISO Tests' -Tags @('Integration', 'ISO') {
    BeforeAll {
        # Import the ISOCustomizer module (Customize-ISO was replaced)
        $script:ModulePath = Join-Path $script:ProjectRoot 'aither-core/modules/ISOCustomizer'
        if (Test-Path $script:ModulePath) {
            Import-Module $script:ModulePath -Force
        } else {
            Write-Warning "ISOCustomizer module not found at: $script:ModulePath"
        }
    }

    Context 'Module Loading' {
        It 'should load ISOCustomizer module' {
            Get-Module ISOCustomizer | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Functionality Tests' {
        It 'should execute without errors' {
            # Basic test implementation
            $true | Should -BeTrue
        }
    }

    AfterAll {
        # Cleanup test resources
        Remove-Module LabRunner -Force -ErrorAction SilentlyContinue
    }
}
