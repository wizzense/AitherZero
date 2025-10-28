#Requires -Version 7.0

Describe "0512_Schedule-ReportGeneration" {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0512_Schedule-ReportGeneration.ps1"

        # Mock external dependencies
        Mock -CommandName Import-Module -MockWith { }
        Mock -CommandName Write-CustomLog -MockWith { param($Message, $Level) Write-Host "[$Level] $Message" }
        Mock -CommandName Register-ScheduledTask -MockWith { }
        Mock -CommandName Get-ScheduledTask -MockWith { @{ TaskName = "AitherZero-Reports" } }
        Mock -CommandName Unregister-ScheduledTask -MockWith { }
        Mock -CommandName New-ScheduledTaskAction -MockWith { @{ Execute = "powershell.exe" } }
        Mock -CommandName New-ScheduledTaskTrigger -MockWith { @{ Frequency = "Daily" } }
        Mock -CommandName New-ScheduledTaskSettingsSet -MockWith { @{ } }
        Mock -CommandName New-ScheduledTaskPrincipal -MockWith { @{ UserId = "SYSTEM" } }
        Mock -CommandName Write-Host -MockWith { }
        Mock -CommandName Test-Path -MockWith { $true }
    }

    Context "Parameter Validation" {
        It "Should accept Action parameter" {
            { & $script:ScriptPath -Action "Install" -WhatIf } | Should -Not -Throw
            { & $script:ScriptPath -Action "Uninstall" -WhatIf } | Should -Not -Throw
            { & $script:ScriptPath -Action "Status" -WhatIf } | Should -Not -Throw
        }

        It "Should accept Schedule parameter" {
            { & $script:ScriptPath -Schedule "Daily" -WhatIf } | Should -Not -Throw
            { & $script:ScriptPath -Schedule "Weekly" -WhatIf } | Should -Not -Throw
        }

        It "Should accept ReportTypes parameter" {
            { & $script:ScriptPath -ReportTypes @("ProjectReport", "TechDebt") -WhatIf } | Should -Not -Throw
        }
    }

    Context "Task Management" {
        It "Should install scheduled task" {
            if ($IsWindows) {
                & $script:ScriptPath -Action "Install" -WhatIf 2>&1
                Should -Not -Invoke Register-ScheduledTask  # WhatIf mode
            }
        }

        It "Should uninstall scheduled task" {
            if ($IsWindows) {
                & $script:ScriptPath -Action "Uninstall" -WhatIf 2>&1
                Should -Not -Invoke Unregister-ScheduledTask  # WhatIf mode
            }
        }

        It "Should show task status" {
            if ($IsWindows) {
                & $script:ScriptPath -Action "Status" -WhatIf 2>&1
                Should -Not -Invoke Get-ScheduledTask  # WhatIf mode
            }
        }
    }

    Context "WhatIf Support" {
        It "Should show scheduling preview with WhatIf" {
            $result = & $script:ScriptPath -WhatIf -Action "Install" 2>&1
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should not create tasks with WhatIf" {
            & $script:ScriptPath -WhatIf -Action "Install" 2>&1
            Should -Not -Invoke Register-ScheduledTask
        }
    }

    Context "Cross-Platform Handling" {
        It "Should handle non-Windows platforms gracefully" {
            if (-not $IsWindows) {
                $result = & $script:ScriptPath -Action "Install" 2>&1
                $result | Should -Match "Windows.*required|not.*supported"
            }
        }
    }
}
