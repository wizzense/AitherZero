Describe 'Core Module Tests' {
    Context 'LabRunner Module' {
        It 'Should have module file' {
            Test-Path './aither-core/modules/LabRunner/LabRunner.psm1' | Should -Be $true
        }
    }
}
