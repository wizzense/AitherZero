Describe 'Startup Performance' -Tags 'Performance' {
    It 'should start within the performance budget' {
        $measure = Measure-Command {
            & "$PSScriptRoot/../../Start-AitherZero.ps1" -WhatIf -NonInteractive
        }
        $measure.TotalSeconds | Should -BeLessOrEqual 5
    }
}