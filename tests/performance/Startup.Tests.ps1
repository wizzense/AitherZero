Describe 'Startup Performance' -Tags 'Performance' {
    BeforeAll {
        $script:StartScript = Join-Path (Join-Path $PSScriptRoot "..") ".." | Join-Path -ChildPath "Start-AitherZero.ps1"
    }
    
    It 'should start within the performance budget' {
        $measure = Measure-Command {
            & $script:StartScript -WhatIf -NonInteractive
        }
        $measure.TotalSeconds | Should -BeLessOrEqual 5
    }
    
    It 'should handle quick validation efficiently' {
        $measure = Measure-Command {
            & $script:StartScript -WhatIf -NonInteractive -Quiet
        }
        $measure.TotalSeconds | Should -BeLessOrEqual 3
    }
}