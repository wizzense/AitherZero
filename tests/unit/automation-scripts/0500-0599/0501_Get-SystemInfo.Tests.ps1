#Requires -Version 7.0

Describe "0501_Get-SystemInfo" {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0501_Get-SystemInfo.ps1"
        
        # Mock external dependencies
        Mock -CommandName Import-Module -MockWith { }
        Mock -CommandName Write-CustomLog -MockWith { param($Message, $Level) Write-Host "[$Level] $Message" }
        Mock -CommandName Get-CimInstance -MockWith {
            if ($ClassName -eq "Win32_OperatingSystem") {
                @{
                    Caption = "Microsoft Windows 11"
                    BuildNumber = "22631"
                    InstallDate = (Get-Date)
                    TotalVisibleMemorySize = 16777216
                    FreePhysicalMemory = 8388608
                }
            } elseif ($ClassName -eq "Win32_Processor") {
                @{ Name = "Intel(R) Core(TM) i7-10700K CPU @ 3.80GHz" }
            }
        }
        Mock -CommandName Get-Content -MockWith {
            if ($Path -eq "/etc/os-release") {
                @("PRETTY_NAME=Ubuntu 22.04", "ID=ubuntu", "VERSION_ID=22.04")
            } elseif ($Path -eq "/proc/meminfo") {
                @("MemTotal:       16384000 kB", "MemFree:         8192000 kB")
            } elseif ($Path -eq "/proc/cpuinfo") {
                @("model name      : Intel(R) Core(TM) i7-10700K CPU @ 3.80GHz")
            } else {
                @()
            }
        }
        Mock -CommandName sw_vers -MockWith { "macOS Monterey 12.6" }
        Mock -CommandName sysctl -MockWith {
            if ($n -eq "machdep.cpu.brand_string") { "Apple M1" }
            elseif ($n -eq "hw.memsize") { "17179869184" }
        }
    }

    Context "Parameter Validation" {
        It "Should accept Configuration parameter" {
            { & $script:ScriptPath -Configuration @{} -WhatIf } | Should -Not -Throw
        }

        It "Should accept AsJson switch" {
            { & $script:ScriptPath -AsJson -WhatIf } | Should -Not -Throw
        }

        It "Should accept OutputFormat parameter" {
            { & $script:ScriptPath -OutputFormat "Detailed" -WhatIf } | Should -Not -Throw
        }

        It "Should validate OutputFormat values" {
            { & $script:ScriptPath -OutputFormat "Invalid" -WhatIf } | Should -Throw
        }
    }

    Context "System Information Collection" {
        It "Should collect basic system information" {
            Mock -CommandName Write-Host -MockWith { }
            
            $result = & $script:ScriptPath -Configuration @{} 2>&1
            $LASTEXITCODE | Should -Be 0
        }

        It "Should detect platform correctly" {
            Mock -CommandName Write-Host -MockWith { }
            
            & $script:ScriptPath -Configuration @{} 2>&1
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Platform:*" }
        }

        It "Should collect memory information" {
            Mock -CommandName Write-Host -MockWith { }
            
            & $script:ScriptPath -Configuration @{} 2>&1
            
            if ($IsWindows) {
                Should -Invoke Get-CimInstance -ParameterFilter { $ClassName -eq "Win32_OperatingSystem" }
            }
        }
    }

    Context "Output Formats" {
        It "Should output JSON when AsJson is specified" {
            $result = & $script:ScriptPath -AsJson 2>&1
            $jsonOutput = $result | Where-Object { $_ -match "^\{.*\}$" -or $_ -match "^\[.*\]$" }
            $jsonOutput | Should -Not -BeNullOrEmpty
        }

        It "Should support Summary format" {
            Mock -CommandName Write-Host -MockWith { }
            
            & $script:ScriptPath -OutputFormat "Summary" 2>&1
            Should -Invoke Write-Host -AtLeast 5
        }

        It "Should support Detailed format" {
            Mock -CommandName Write-Host -MockWith { }
            
            & $script:ScriptPath -OutputFormat "Detailed" 2>&1
            Should -Invoke Write-Host -AtLeast 10
        }

        It "Should support Full format" {
            Mock -CommandName Write-Host -MockWith { }
            
            & $script:ScriptPath -OutputFormat "Full" 2>&1
            Should -Invoke Write-Host -AtLeast 10
        }
    }

    Context "WhatIf Support" {
        It "Should show system info preview with WhatIf" {
            $result = & $script:ScriptPath -WhatIf 2>&1
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should not collect data with WhatIf" {
            & $script:ScriptPath -WhatIf 2>&1
            # WhatIf should not invoke actual system info collection
            Should -Not -Invoke Get-CimInstance
        }
    }
}
