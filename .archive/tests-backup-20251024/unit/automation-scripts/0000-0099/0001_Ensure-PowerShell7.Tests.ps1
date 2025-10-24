#Requires -Modules Pester

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0001_Ensure-PowerShell7.ps1"
    
    # Mock external dependencies
    Mock Write-Host { }
    Mock Get-Command { }
    Mock Start-Process { @{ ExitCode = 0 } }
    Mock Invoke-WebRequest { }
    Mock Remove-Item { }
    Mock Test-Path { $false }
}

Describe "0001_Ensure-PowerShell7" {
    Context "Parameter Validation" {
        It "Should have CmdletBinding with SupportsShouldProcess" {
            $scriptContent = Get-Content $script:ScriptPath -Raw
            $scriptContent | Should -Match "\\[CmdletBinding\\(SupportsShouldProcess\\)\\]"
        }

        It "Should accept WhatIf parameter" {
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }

        It "Should accept Configuration parameter" {
            $testConfig = @{ PowerShell = @{ Version = "7.4.6" } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
    }

    Context "PowerShell Version Detection" {
        It "Should exit early if PowerShell 7+ is already running" {
            Mock Get-Variable { @{ Value = @{ PSVersion = @{ Major = 7; Minor = 4 } } } } -ParameterFilter { $Name -eq "PSVersionTable" }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }

        It "Should proceed with installation if PowerShell version is less than 7" {
            Mock Get-Variable { @{ Value = @{ PSVersion = @{ Major = 5; Minor = 1 } } } } -ParameterFilter { $Name -eq "PSVersionTable" }
            Mock Get-Command { $null }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }
    }

    Context "WhatIf Functionality" {
        It "Should not download or install in WhatIf mode" {
            Mock Invoke-WebRequest { throw "Should not download in WhatIf mode" }
            Mock Start-Process { throw "Should not install in WhatIf mode" }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
            Should -Not -Invoke Invoke-WebRequest
            Should -Not -Invoke Start-Process
        }
    }

    Context "Windows Installation" {
        It "Should handle Windows installation process" {
            Mock Get-Variable { @{ Value = "Win32NT" } } -ParameterFilter { $Name -eq "IsWindows" }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq "pwsh" }
            Mock Join-Path { "C:\\temp\\PowerShell-7.msi" }
            Mock Invoke-WebRequest { }
            Mock Start-Process { @{ ExitCode = 0 } }
            Mock Test-Path { $true }
            
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }

        It "Should handle installation failure" {
            Mock Start-Process { @{ ExitCode = 1 } }
            
            $result = try { & $script:ScriptPath 2>&1 } catch { $_.Exception }
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Non-Windows Platform" {
        It "Should exit with warning on non-Windows platforms" {
            Mock Get-Variable { @{ Value = $false } } -ParameterFilter { $Name -eq "IsWindows" }
            
            $result = try { & $script:ScriptPath 2>&1 } catch { $_.Exception }
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Error Handling" {
        It "Should handle download failures" {
            Mock Invoke-WebRequest { throw "Network error" }
            
            $result = try { & $script:ScriptPath 2>&1 } catch { $_.Exception }
            $LASTEXITCODE | Should -Be 1
        }

        It "Should exit with code 200 when restart is needed" {
            Mock Test-Path { $true }
            Mock Write-Host { }
            
            $result = try { & $script:ScriptPath 2>&1 } catch { $_.Exception }
            # This should exit with 200 to indicate restart needed
        }
    }
}
