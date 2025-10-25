#Requires -Version 7.0

Describe "0530_View-Logs" {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0530_View-Logs.ps1"
        $script:TestLogPath = Join-Path ([System.IO.Path]::GetTempPath()) "test.log"

        # Create test log content
        @(
            "[2024-01-01 12:00:00] [INFO] Application started",
            "[2024-01-01 12:01:00] [ERROR] Database connection failed",
            "[2024-01-01 12:02:00] [WARNING] High memory usage detected",
            "[2024-01-01 12:03:00] [DEBUG] Processing user request"
        ) | Set-Content -Path $script:TestLogPath

        # Mock external dependencies
        Mock -CommandName Import-Module -MockWith { }
        Mock -CommandName Write-CustomLog -MockWith { param($Message, $Level) Write-Host "[$Level] $Message" }
        Mock -CommandName Get-LogFiles -MockWith {
            if ($Type -eq "Application" -or $Type -eq "All") {
                @(@{
                    Name = "aitherzero.log"
                    FullName = $script:TestLogPath
                    Type = "Application"
                    SizeKB = 5.2
                    Length = 5324
                })
            }
            if ($Type -eq "Transcript" -or $Type -eq "All") {
                @(@{
                    Name = "transcript-001.log"
                    FullName = "transcript.log"
                    Type = "Transcript"
                    SizeKB = 2.1
                    Length = 2150
                })
            }
        }
        Mock -CommandName Show-LogDashboard -MockWith { }
        Mock -CommandName Show-LogContent -MockWith { }
        Mock -CommandName Search-Logs -MockWith { }
        Mock -CommandName Get-LoggingStatus -MockWith {
            @{
                ModuleLoaded = $true
                FileLoggingEnabled = $true
                TranscriptActive = $false
                LogPath = $script:TestLogPath
                CurrentLogFile = @{ Length = 5324; LastWriteTime = (Get-Date) }
                Configuration = @{
                    Level = "Information"
                    Targets = @("File", "Console")
                    Path = $script:TestLogPath
                }
            }
        }
        Mock -CommandName Get-LogStatistics -MockWith {
            @{
                TotalLines = 100
                LogLevels = @{
                    Information = 60
                    Warning = 25
                    Error = 10
                    Debug = 5
                }
            }
        }
        Mock -CommandName Write-Host -MockWith { }
        Mock -CommandName Read-Host -MockWith { "test search" }
        Mock -CommandName Initialize-Logging -MockWith { }
    }

    AfterAll {
        if (Test-Path $script:TestLogPath) {
            Remove-Item $script:TestLogPath -Force
        }
    }

    Context "Parameter Validation" {
        It "Should accept Configuration parameter" {
            { & $script:ScriptPath -Configuration @{} -WhatIf } | Should -Not -Throw
        }

        It "Should accept Mode parameter" {
            $validModes = @("Dashboard", "Latest", "Errors", "Transcript", "Search", "Status")
            foreach ($mode in $validModes) {
                { & $script:ScriptPath -Mode $mode -WhatIf } | Should -Not -Throw
            }
        }

        It "Should validate Mode parameter values" {
            { & $script:ScriptPath -Mode "Invalid" -WhatIf } | Should -Throw
        }

        It "Should accept Tail parameter" {
            { & $script:ScriptPath -Tail 50 -WhatIf } | Should -Not -Throw
        }

        It "Should accept Follow switch" {
            { & $script:ScriptPath -Follow -WhatIf } | Should -Not -Throw
        }

        It "Should accept SearchPattern parameter" {
            { & $script:ScriptPath -SearchPattern "error" -WhatIf } | Should -Not -Throw
        }

        It "Should accept Level parameter" {
            $validLevels = @("Trace", "Debug", "Information", "Warning", "Error", "Critical")
            foreach ($level in $validLevels) {
                { & $script:ScriptPath -Level $level -WhatIf } | Should -Not -Throw
            }
        }
    }

    Context "Log Viewing Modes" {
        It "Should display dashboard in interactive mode" {
            Mock -CommandName Test-Path -ParameterFilter { $Path -like "*LogViewer.psm1" } -MockWith { $true }

            & $script:ScriptPath -Mode "Dashboard" -WhatIf 2>&1
            Should -Not -Invoke Show-LogDashboard  # WhatIf mode
        }

        It "Should display latest logs" {
            Mock -CommandName Test-Path -ParameterFilter { $Path -like "*LogViewer.psm1" } -MockWith { $true }

            & $script:ScriptPath -Mode "Latest" -Tail 25 -WhatIf 2>&1
            Should -Not -Invoke Show-LogContent  # WhatIf mode
        }

        It "Should display error logs" {
            Mock -CommandName Test-Path -ParameterFilter { $Path -like "*LogViewer.psm1" } -MockWith { $true }

            & $script:ScriptPath -Mode "Errors" -WhatIf 2>&1
            Should -Not -Invoke Show-LogContent  # WhatIf mode
        }

        It "Should display transcript logs" {
            Mock -CommandName Test-Path -ParameterFilter { $Path -like "*LogViewer.psm1" } -MockWith { $true }

            & $script:ScriptPath -Mode "Transcript" -WhatIf 2>&1
            Should -Not -Invoke Show-LogContent  # WhatIf mode
        }

        It "Should handle search mode" {
            Mock -CommandName Test-Path -ParameterFilter { $Path -like "*LogViewer.psm1" } -MockWith { $true }

            & $script:ScriptPath -Mode "Search" -SearchPattern "error" -WhatIf 2>&1
            Should -Not -Invoke Search-Logs  # WhatIf mode
        }

        It "Should display logging status" {
            Mock -CommandName Test-Path -ParameterFilter { $Path -like "*LogViewer.psm1" } -MockWith { $true }

            & $script:ScriptPath -Mode "Status" -WhatIf 2>&1
            Should -Not -Invoke Get-LoggingStatus  # WhatIf mode
        }
    }

    Context "Non-Interactive Mode" {
        It "Should handle non-interactive dashboard mode" {
            Mock -CommandName Test-Path -ParameterFilter { $Path -like "*LogViewer.psm1" } -MockWith { $true }

            $env:AITHERZERO_NONINTERACTIVE = "true"
            try {
                & $script:ScriptPath -Mode "Dashboard" -WhatIf 2>&1
                Should -Not -Invoke Show-LogDashboard  # Should use non-interactive display
            } finally {
                Remove-Item env:AITHERZERO_NONINTERACTIVE -ErrorAction SilentlyContinue
            }
        }

        It "Should require search pattern in non-interactive search mode" {
            Mock -CommandName Test-Path -ParameterFilter { $Path -like "*LogViewer.psm1" } -MockWith { $true }

            $env:AITHERZERO_NONINTERACTIVE = "true"
            try {
                $result = & $script:ScriptPath -Mode "Search" -WhatIf 2>&1
                $result | Should -Match "requires.*search.*pattern"
            } finally {
                Remove-Item env:AITHERZERO_NONINTERACTIVE -ErrorAction SilentlyContinue
            }
        }
    }

    Context "WhatIf Support" {
        It "Should show log viewer preview with WhatIf" {
            Mock -CommandName Test-Path -ParameterFilter { $Path -like "*LogViewer.psm1" } -MockWith { $true }

            $result = & $script:ScriptPath -WhatIf 2>&1
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should not initialize logging with WhatIf" {
            & $script:ScriptPath -WhatIf -Mode "Dashboard" 2>&1
            Should -Not -Invoke Initialize-Logging
        }
    }

    Context "Error Handling" {
        It "Should handle missing LogViewer module" {
            Mock -CommandName Test-Path -ParameterFilter { $Path -like "*LogViewer.psm1" } -MockWith { $false }

            $result = & $script:ScriptPath -Mode "Status" 2>&1
            $LASTEXITCODE | Should -Be 1
        }

        It "Should handle module import failures" {
            Mock -CommandName Import-Module -MockWith { throw "Module not found" }
            Mock -CommandName Test-Path -ParameterFilter { $Path -like "*LogViewer.psm1" } -MockWith { $true }

            $result = & $script:ScriptPath -Mode "Status" 2>&1
            $LASTEXITCODE | Should -Be 1
        }

        It "Should handle missing log files gracefully" {
            Mock -CommandName Get-LogFiles -MockWith { @() }
            Mock -CommandName Test-Path -ParameterFilter { $Path -like "*LogViewer.psm1" } -MockWith { $true }

            { & $script:ScriptPath -Mode "Latest" } | Should -Not -Throw
        }
    }
}
