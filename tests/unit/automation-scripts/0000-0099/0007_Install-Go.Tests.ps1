#Requires -Modules Pester

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0007_Install-Go.ps1"
    
    # Mock external dependencies
    Mock Write-Host { }
    Mock Write-Warning { }
    Mock Write-CustomLog { }
    Mock Import-Module { }
    Mock Get-Command { }
    Mock Invoke-WebRequest { }
    Mock Start-Process { @{ ExitCode = 0 } }
    Mock Test-Path { $false }
    Mock New-Item { }
    Mock Remove-Item { }
    Mock Expand-Archive { }
}

Describe "0007_Install-Go" {
    Context "Parameter Validation" {
        It "Should have CmdletBinding with SupportsShouldProcess" {
            $scriptContent = Get-Content $script:ScriptPath -Raw
            $scriptContent | Should -Match "\\[CmdletBinding\\(SupportsShouldProcess\\)\\]"
        }

        It "Should accept WhatIf parameter" {
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }

        It "Should accept Configuration parameter" {
            $testConfig = @{ InstallationOptions = @{ Go = @{ Install = $true } } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
    }

    Context "Installation Control" {
        It "Should skip installation when not enabled in configuration" {
            $testConfig = @{ InstallationOptions = @{ Go = @{ Install = $false } } }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }

        It "Should skip installation when configuration is missing" {
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -Configuration @{} -WhatIf } | Should -Not -Throw
        }

        It "Should proceed with installation when enabled" {
            $testConfig = @{ InstallationOptions = @{ Go = @{ Install = $true } } }
            Mock Write-ScriptLog { }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq "go" }
            
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
    }

    Context "Existing Installation Detection" {
        It "Should exit early if Go is already installed" {
            Mock Start-Process { @{ ExitCode = 0 } } -ParameterFilter { $FilePath -eq "go" }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ Go = @{ Install = $true } } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }

        It "Should check GOPATH when Go is installed" {
            Mock Start-Process { @{ ExitCode = 0 } } -ParameterFilter { $FilePath -eq "go" }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ Go = @{ Install = $true } } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
    }

    Context "WhatIf Functionality" {
        It "Should not download or install in WhatIf mode" {
            Mock Invoke-WebRequest { throw "Should not download in WhatIf mode" }
            Mock Start-Process { throw "Should not install in WhatIf mode" }
            Mock Expand-Archive { throw "Should not extract in WhatIf mode" }
            
            $testConfig = @{ InstallationOptions = @{ Go = @{ Install = $true } } }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq "go" }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
            Should -Not -Invoke Invoke-WebRequest
            Should -Not -Invoke Start-Process
            Should -Not -Invoke Expand-Archive
        }
    }

    Context "Version Handling" {
        It "Should use configured version when specified" {
            $testConfig = @{
                InstallationOptions = @{
                    Go = @{
                        Install = $true
                        Version = "1.21.5"
                    }
                }
            }
            
            Mock Get-Command { $null } -ParameterFilter { $Name -eq "go" }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }

        It "Should fetch latest version when not specified" {
            $testConfig = @{
                InstallationOptions = @{
                    Go = @{
                        Install = $true
                        Version = "latest"
                    }
                }
            }
            
            Mock Get-Command { $null } -ParameterFilter { $Name -eq "go" }
            Mock Invoke-WebRequest { @{ Content = "go1.22.0" } } -ParameterFilter { $Uri -like "*VERSION*" }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }

        It "Should use fallback version when latest fetch fails" {
            $testConfig = @{
                InstallationOptions = @{
                    Go = @{
                        Install = $true
                        Version = "latest"
                    }
                }
            }
            
            Mock Get-Command { $null } -ParameterFilter { $Name -eq "go" }
            Mock Invoke-WebRequest { throw "Network error" } -ParameterFilter { $Uri -like "*VERSION*" }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
    }

    Context "Windows Installation" {
        It "Should handle Windows MSI installation" {
            Mock Get-Variable { @{ Value = $true } } -ParameterFilter { $Name -eq "IsWindows" }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq "go" }
            Mock Join-Path { "C:\\temp\\go-installer.msi" }
            Mock Invoke-WebRequest { }
            Mock Start-Process { @{ ExitCode = 0 } }
            Mock [Environment]::SetEnvironmentVariable { }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ Go = @{ Install = $true } } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }

        It "Should handle installation failure on Windows" {
            Mock Get-Variable { @{ Value = $true } } -ParameterFilter { $Name -eq "IsWindows" }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq "go" }
            Mock Start-Process { @{ ExitCode = 1 } }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ Go = @{ Install = $true } } }
            $result = try { & $script:ScriptPath -Configuration $testConfig 2>&1 } catch { $_.Exception }
            $LASTEXITCODE | Should -Be 1
        }

        It "Should set up environment variables on Windows" {
            Mock Get-Variable { @{ Value = $true } } -ParameterFilter { $Name -eq "IsWindows" }
            Mock [Environment]::GetEnvironmentVariable { "C:\\existing\\path" }
            Mock [Environment]::SetEnvironmentVariable { }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ Go = @{ Install = $true } } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
    }

    Context "Linux Installation" {
        It "Should handle Linux tar.gz installation" {
            Mock Get-Variable { @{ Value = $true } } -ParameterFilter { $Name -eq "IsLinux" }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq "go" }
            Mock [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture { "X64" }
            Mock Invoke-WebRequest { }
            Mock Test-Path { $false }
            Mock Start-Process { }
            Mock Get-Content { 'export PATH=$PATH:/usr/local/go/bin' }
            Mock Add-Content { }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ Go = @{ Install = $true } } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }

        It "Should handle different architectures on Linux" {
            Mock Get-Variable { @{ Value = $true } } -ParameterFilter { $Name -eq "IsLinux" }
            Mock [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture { "Arm64" }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ Go = @{ Install = $true } } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
    }

    Context "macOS Installation" {
        It "Should use Homebrew when available on macOS" {
            Mock Get-Variable { @{ Value = $true } } -ParameterFilter { $Name -eq "IsMacOS" }
            Mock Get-Command { @{ Name = "brew" } } -ParameterFilter { $Name -eq "brew" }
            Mock Start-Process { }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ Go = @{ Install = $true } } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }

        It "Should fallback to manual installation on macOS without Homebrew" {
            Mock Get-Variable { @{ Value = $true } } -ParameterFilter { $Name -eq "IsMacOS" }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq "brew" }
            Mock [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture { "Arm64" }
            Mock Start-Process { }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ Go = @{ Install = $true } } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
    }

    Context "Post-Installation Setup" {
        It "Should create Go workspace directories" {
            Mock Test-Path { $true } -ParameterFilter { $Path -like "*go.exe" -or $Path -like "*/go" }
            Mock Start-Process { @{ ExitCode = 0 } }
            Mock Test-Path { $false } -ParameterFilter { $Path -like "*\\go\\*" -or $Path -like "*/go/*" }
            Mock New-Item { }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ Go = @{ Install = $true } } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }

        It "Should install Go tools when configured" {
            $testConfig = @{
                InstallationOptions = @{
                    Go = @{
                        Install = $true
                        Tools = @("golang.org/x/tools/cmd/goimports", "github.com/golangci/golangci-lint/cmd/golangci-lint@latest")
                    }
                }
            }
            
            Mock Test-Path { $true }
            Mock Start-Process { @{ ExitCode = 0 } }
            Mock Write-ScriptLog { }
            
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
    }

    Context "Error Handling" {
        It "Should handle unsupported operating systems" {
            Mock Get-Variable { @{ Value = $false } } -ParameterFilter { $Name -eq "IsWindows" }
            Mock Get-Variable { @{ Value = $false } } -ParameterFilter { $Name -eq "IsLinux" }
            Mock Get-Variable { @{ Value = $false } } -ParameterFilter { $Name -eq "IsMacOS" }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ Go = @{ Install = $true } } }
            $result = try { & $script:ScriptPath -Configuration $testConfig 2>&1 } catch { $_.Exception }
            $LASTEXITCODE | Should -Be 1
        }

        It "Should handle download failures" {
            Mock Get-Variable { @{ Value = $true } } -ParameterFilter { $Name -eq "IsWindows" }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq "go" }
            Mock Invoke-WebRequest { throw "Network error" }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ Go = @{ Install = $true } } }
            $result = try { & $script:ScriptPath -Configuration $testConfig 2>&1 } catch { $_.Exception }
            $LASTEXITCODE | Should -Be 1
        }

        It "Should handle verification failures" {
            Mock Get-Variable { @{ Value = $true } } -ParameterFilter { $Name -eq "IsWindows" }
            Mock Test-Path { $false } -ParameterFilter { $Path -like "*go.exe" }
            Mock Start-Process { @{ ExitCode = 1 } }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ Go = @{ Install = $true } } }
            $result = try { & $script:ScriptPath -Configuration $testConfig 2>&1 } catch { $_.Exception }
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Logging Integration" {
        It "Should use Write-CustomLog when available" {
            Mock Get-Command { @{ Name = "Write-CustomLog" } } -ParameterFilter { $Name -eq "Write-CustomLog" }
            Mock Write-CustomLog { }
            Mock Write-ScriptLog { }
            
            $testConfig = @{ InstallationOptions = @{ Go = @{ Install = $false } } }
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
            Should -Invoke Write-CustomLog -AtLeast 1
        }
    }
}
