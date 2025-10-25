#Requires -Version 7.0
#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.0.0" }

BeforeAll {
    $scriptPath = Join-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) "automation-scripts/0821_Generate-ContinuationPrompt.ps1"

    Mock Write-Host -MockWith {}
    Mock Write-Warning -MockWith {}
    Mock Write-Error -MockWith {}
    Mock Set-Content -MockWith {}
    Mock Get-Item -MockWith { return [PSCustomObject]@{ Length = 2048 } }
    Mock New-Item -MockWith {}
    Mock Test-Path -MockWith { $true }
    Mock Split-Path -MockWith { return ".claude" } -ParameterFilter { $Parent -eq $true }

    # Mock context data
    $mockContext = @{
        SessionId = "test-session-123"
        Timestamp = "2023-01-01 12:00:00"
        Git = @{
            Branch = "main"
            LastCommit = "abc123 Initial commit"
            ModifiedFiles = @{
                "file1.ps1" = @{ Status = "M"; Lines = 100 }
            }
        }
        PowerShell = @{
            RecentErrors = @(
                @{ Message = "Test error"; Script = "test.ps1"; Line = 10 }
            )
        }
        Test = @{
            TestResults = @{ FailedCount = 2 }
            AnalyzerResults = @{ TotalIssues = 3 }
        }
        Project = @{
            Version = "1.0.0"
            TodoList = @(@{ File = "test.ps1"; Line = 5; Text = "TODO: Fix this" })
        }
    }

    Mock Get-Content -MockWith { return $mockContext | ConvertTo-Json -Depth 10 }
    Mock ConvertFrom-Json -MockWith { return $mockContext } -ParameterFilter { $AsHashtable -eq $true }

    # Mock clipboard operations
    Mock Set-Clipboard -MockWith {}
    Mock Get-Command -MockWith { return $true } -ParameterFilter { $Name -eq "xclip" }
    Mock xclip -MockWith {}
}

Describe "0821_Generate-ContinuationPrompt" {
    Context "Parameter Validation" {
        It "Should support WhatIf functionality" {
            { & $scriptPath -WhatIf } | Should -Not -Throw
        }

        It "Should accept custom paths" {
            { & $scriptPath -ContextPath "custom.json" -OutputPath "custom.md" -WhatIf } | Should -Not -Throw
        }

        It "Should accept MaxTokens parameter" {
            { & $scriptPath -MaxTokens 2000 -WhatIf } | Should -Not -Throw
        }
    }

    Context "Context Loading" {
        It "Should fail when context file missing" {
            Mock Test-Path -MockWith { $false }

            { & $scriptPath } | Should -Throw "*Context file not found*"
        }

        It "Should load context from file" {
            & $scriptPath

            Should -Invoke Get-Content -Times 1
            Should -Invoke ConvertFrom-Json -Times 1
        }
    }

    Context "Prompt Generation" {
        It "Should generate prompt sections" {
            & $scriptPath

            Should -Invoke Set-Content -Times 1
        }

        It "Should include session information" {
            & $scriptPath

            Should -Invoke Set-Content -ParameterFilter { $Value -like "*Session ID:*" }
        }

        It "Should include git status" {
            & $scriptPath

            Should -Invoke Set-Content -ParameterFilter { $Value -like "*Git Status*" }
        }

        It "Should include errors when present" {
            & $scriptPath

            Should -Invoke Set-Content -ParameterFilter { $Value -like "*Recent Errors*" }
        }

        It "Should include test status" {
            & $scriptPath

            Should -Invoke Set-Content -ParameterFilter { $Value -like "*Test Status*" }
        }
    }

    Context "Token Management" {
        It "Should estimate token count" {
            & $scriptPath -MaxTokens 4000

            Should -Invoke Get-Content -Times 1
        }

        It "Should compress when exceeding limits" {
            & $scriptPath -MaxTokens 100

            Should -Invoke Write-Warning -ParameterFilter { $Message -like "*exceeds token limit*" }
        }
    }

    Context "Output Options" {
        It "Should save to file" {
            & $scriptPath

            Should -Invoke Set-Content -Times 1
        }

        It "Should copy to clipboard when requested" {
            & $scriptPath -CopyToClipboard

            Should -Invoke Set-Clipboard -Times 1
        }

        It "Should show prompt when requested" {
            & $scriptPath -ShowPrompt

            Should -Invoke Write-Host -ParameterFilter { $Object -match "^=+$" }
        }
    }

    Context "Error Handling" {
        It "Should handle JSON parsing errors" {
            Mock ConvertFrom-Json -MockWith { throw "Invalid JSON" }

            { & $scriptPath } | Should -Throw
        }

        It "Should handle file write errors" {
            Mock Set-Content -MockWith { throw "Write error" }

            { & $scriptPath } | Should -Throw
        }
    }
}
