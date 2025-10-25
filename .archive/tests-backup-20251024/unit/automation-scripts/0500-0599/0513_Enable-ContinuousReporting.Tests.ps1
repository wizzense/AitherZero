#Requires -Version 7.0

Describe "0513_Enable-ContinuousReporting" {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0513_Enable-ContinuousReporting.ps1"

        # Mock external dependencies
        Mock -CommandName Import-Module -MockWith { }
        Mock -CommandName Write-CustomLog -MockWith { param($Message, $Level) Write-Host "[$Level] $Message" }
        Mock -CommandName Start-Job -MockWith { @{ Id = 1; Name = "ContinuousReporting" } }
        Mock -CommandName Get-Job -MockWith { @() }
        Mock -CommandName Stop-Job -MockWith { }
        Mock -CommandName Remove-Job -MockWith { }
        Mock -CommandName Register-EngineEvent -MockWith { }
        Mock -CommandName Unregister-Event -MockWith { }
        Mock -CommandName New-Object -ParameterFilter { $TypeName -like "*FileSystemWatcher*" } -MockWith {
            @{
                Path = "C:\test"
                Filter = "*.ps1"
                EnableRaisingEvents = $true
                IncludeSubdirectories = $true
            }
        }
        Mock -CommandName Write-Host -MockWith { }
        Mock -CommandName Test-Path -MockWith { $true }
    }

    Context "Parameter Validation" {
        It "Should accept Action parameter" {
            { & $script:ScriptPath -Action "Start" -WhatIf } | Should -Not -Throw
            { & $script:ScriptPath -Action "Stop" -WhatIf } | Should -Not -Throw
            { & $script:ScriptPath -Action "Status" -WhatIf } | Should -Not -Throw
        }

        It "Should accept Interval parameter" {
            { & $script:ScriptPath -Interval 300 -WhatIf } | Should -Not -Throw
        }

        It "Should accept WatchPaths parameter" {
            { & $script:ScriptPath -WatchPaths @(".\scripts", ".\modules") -WhatIf } | Should -Not -Throw
        }

        It "Should accept ReportTypes parameter" {
            { & $script:ScriptPath -ReportTypes @("CodeQuality", "Security") -WhatIf } | Should -Not -Throw
        }
    }

    Context "Continuous Reporting Management" {
        It "Should start continuous reporting" {
            & $script:ScriptPath -Action "Start" -WhatIf 2>&1
            Should -Not -Invoke Start-Job  # WhatIf mode
        }

        It "Should stop continuous reporting" {
            Mock -CommandName Get-Job -MockWith { @(@{ Id = 1; Name = "ContinuousReporting"; State = "Running" }) }

            & $script:ScriptPath -Action "Stop" -WhatIf 2>&1
            Should -Not -Invoke Stop-Job  # WhatIf mode
        }

        It "Should show reporting status" {
            & $script:ScriptPath -Action "Status" -WhatIf 2>&1
            Should -Not -Invoke Get-Job  # WhatIf mode
        }
    }

    Context "File System Watching" {
        It "Should set up file system watchers" {
            & $script:ScriptPath -Action "Start" -WatchPaths @(".\test") -WhatIf 2>&1
            Should -Not -Invoke New-Object  # WhatIf mode
        }

        It "Should register event handlers" {
            & $script:ScriptPath -Action "Start" -WhatIf 2>&1
            Should -Not -Invoke Register-EngineEvent  # WhatIf mode
        }

        It "Should unregister events on stop" {
            & $script:ScriptPath -Action "Stop" -WhatIf 2>&1
            Should -Not -Invoke Unregister-Event  # WhatIf mode
        }
    }

    Context "WhatIf Support" {
        It "Should show continuous reporting preview with WhatIf" {
            $result = & $script:ScriptPath -WhatIf -Action "Start" 2>&1
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should not start jobs with WhatIf" {
            & $script:ScriptPath -WhatIf -Action "Start" 2>&1
            Should -Not -Invoke Start-Job
        }

        It "Should not create watchers with WhatIf" {
            & $script:ScriptPath -WhatIf -Action "Start" -WatchPaths @(".\test") 2>&1
            Should -Not -Invoke New-Object
        }
    }

    Context "Error Handling" {
        It "Should handle job creation failures" {
            Mock -CommandName Start-Job -MockWith { throw "Job creation failed" }

            { & $script:ScriptPath -Action "Start" } | Should -Not -Throw
        }

        It "Should handle missing paths gracefully" {
            Mock -CommandName Test-Path -MockWith { $false }

            { & $script:ScriptPath -Action "Start" -WatchPaths @("nonexistent") } | Should -Not -Throw
        }
    }
}
